extends Node
## TCP bridge between Python PPO and the Godot game.
## The server returns the next state, shaped reward, terminal status and score.

@export var player_path: NodePath
@export var apples_path: NodePath
@export var enemies_path: NodePath
@export var port: int = 9999

const APPLE_REWARD := 25.0
const WIN_BONUS := 100.0
const DEATH_PENALTY := 20.0
const STEP_PENALTY := 0.03
const PROGRESS_COEF := 0.002
const MAX_PROGRESS_REWARD := 0.05
const ACTION_REPEAT := 4

# Small bonus for tolerating proximity to the enemy without dying that step.
# It's deliberately much smaller than APPLE_REWARD/WIN_BONUS, and only slightly
# larger than STEP_PENALTY, so being near the enemy is roughly break-even
# rather than strictly costly — it gives the agent *some* positive signal
# for the risky region instead of only ever hearing "this is dangerous."
const DANGER_RADIUS := 150.0
const RISK_TOLERANCE_BONUS := 0.02

var _player: CharacterBody2D
var _apples: Node2D
var _enemies: Node2D
var _server := TCPServer.new()
var _client: StreamPeerTCP
var _recv_buffer := ""
var _prev_apples_collected := 0
var _prev_apple_distance := -1.0

func _ready() -> void:
	_resolve_scene_nodes()

	if _player == null or _apples == null or _enemies == null:
		push_error("RL server could not resolve required game nodes. " +
			"Player=%s Apples=%s Enemies=%s" % [_player, _apples, _enemies])
		set_process(false)
		return

	var err := _server.listen(port)
	if err != OK:
		print("Failed to start RL server: ", err)
	else:
		print("RL env server listening on port ", port)

func _resolve_scene_nodes() -> void:
	# First try the NodePaths configured in the Inspector.
	_player = get_node_or_null(player_path) as CharacterBody2D
	_apples = get_node_or_null(apples_path) as Node2D
	_enemies = get_node_or_null(enemies_path) as Node2D

	# Fallback to the node structure used by this project.
	# env_server.gd is attached below the main scene root.
	var root := get_parent()
	if root:
		if _player == null:
			_player = root.get_node_or_null("LevelRoot/Player") as CharacterBody2D
		if _apples == null:
			_apples = root.get_node_or_null("LevelRoot/Apple") as Node2D
		if _enemies == null:
			_enemies = root.get_node_or_null("LevelRoot/Enemies") as Node2D

	print("RL nodes: player=", _player, " apples=", _apples, " enemies=", _enemies)

func _process(_delta: float) -> void:
	if _server.is_connection_available():
		_client = _server.take_connection()
		_recv_buffer = ""
		print("Python client connected")

	if _client and _client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if _client.get_available_bytes() > 0:
			_recv_buffer += _client.get_utf8_string(_client.get_available_bytes())
			_process_buffered_commands()

func _process_buffered_commands() -> void:
	while true:
		var newline_pos := _recv_buffer.find("\n")
		if newline_pos < 0:
			break

		# Use find()/substr() instead of split() so an empty line cannot
		# cause an out-of-bounds access when split() removes empty entries.
		var line: String = _recv_buffer.substr(0, newline_pos).strip_edges()
		_recv_buffer = _recv_buffer.substr(newline_pos + 1)

		if not line.is_empty():
			await _handle_command(line)

func _handle_command(raw: String) -> void:
	var json := JSON.new()
	if json.parse(raw) != OK:
		print("Invalid JSON command: ", raw)
		return

	var msg = json.get_data()
	if typeof(msg) != TYPE_DICTIONARY:
		print("Invalid command payload: expected JSON object, got ", typeof(msg))
		return

	var cmd = msg.get("cmd", "")

	match cmd:
		"reset":
			get_parent().reset_level()
			_prev_apples_collected = 0
			_prev_apple_distance = _nearest_apple_distance()
			_send_state(0.0, false)
		"step":
			var action := clampi(int(msg.get("action", 0)), 0, 5)
			var reward := 0.0

			# One RL decision is applied for several physics frames. This makes
			# movement and jump actions meaningful instead of requiring PPO to
			# choose the same action at 60+ consecutive steps.
			for _i in range(ACTION_REPEAT):
				_player.apply_action(action)
				await get_tree().physics_frame
				if GameState.done:
					break

			reward = _compute_reward()
			_send_state(reward, GameState.done)
		_:
			print("Unknown command: ", cmd)

func _nearest_apple_distance() -> float:
	if _player == null or _apples == null:
		return -1.0

	var nearest := -1.0
	for apple in _apples.get_children():
		if "collected" in apple and apple.collected:
			continue
		var distance := _player.position.distance_to(apple.position)
		if nearest < 0.0 or distance < nearest:
			nearest = distance
	return nearest

func _nearest_enemy_distance() -> float:
	if _player == null or _enemies == null:
		return -1.0

	var nearest := -1.0
	for enemy in _enemies.get_children():
		var distance := _player.position.distance_to(enemy.position)
		if nearest < 0.0 or distance < nearest:
			nearest = distance
	return nearest

func _compute_reward() -> float:
	var reward := -STEP_PENALTY

	var apples_this_step := GameState.apples_collected - _prev_apples_collected
	if apples_this_step > 0:
		reward += APPLE_REWARD * apples_this_step
	_prev_apples_collected = GameState.apples_collected

	# Very small bounded shaping. It should help local navigation, but it must
	# never compete with the actual objective of collecting every apple.
	var current_distance := _nearest_apple_distance()
	if _prev_apple_distance >= 0.0 and current_distance >= 0.0 and not GameState.done:
		var progress := (_prev_apple_distance - current_distance) * PROGRESS_COEF
		reward += clamp(progress, -MAX_PROGRESS_REWARD, MAX_PROGRESS_REWARD)
	_prev_apple_distance = current_distance

	# Reward tolerating proximity to the enemy, as long as the player survives
	# the step. Without this, the only feedback the agent ever gets about the
	# danger zone is negative (the death penalty), so it has no incentive to
	# linger there long enough to discover a safe path through it.
	if not GameState.done:
		var enemy_dist := _nearest_enemy_distance()
		if enemy_dist >= 0.0 and enemy_dist < DANGER_RADIUS:
			reward += RISK_TOLERANCE_BONUS

	if GameState.done:
		if GameState.won:
			reward += WIN_BONUS
		else:
			reward -= DEATH_PENALTY
			print("Death | apples_collected=", GameState.apples_collected, " pos=", _player.position)

	return reward

func _send_state(reward: float, done: bool) -> void:
	if _client == null or _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return

	if _player == null or _apples == null or _enemies == null:
		print("Cannot send state: required game nodes are null")
		return

	var state = GameState.get_state(_player, _apples, _enemies)
	var response := {
		"state": state,
		"reward": reward,
		"done": done,
		"won": GameState.won,
		"score": GameState.score
	}
	var text := JSON.stringify(response) + "\n"
	_client.put_data(text.to_utf8_buffer())
