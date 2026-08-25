extends Node

var current_reward: float = 0.0
var score: int = 0
var episode_done: bool = false

const ACTION_FRAMES: int = 10
var step_in_progress: bool = false
@onready var state_tracker = $RLState
@onready var player = $"../LevelRoot/Player"
@onready var enemies = $"../LevelRoot/Enemies"
@onready var apples = $"../LevelRoot/Apple"


func _ready() -> void:
	print("=== RL ENVIRONMENT STARTED ===")

	# Connect enemy death signals
	for enemy in enemies.get_children():
		if enemy.has_signal("player_died"):
			enemy.player_died.connect(_on_player_died)

	# Connect apple collection signals
	for apple in apples.get_children():
		if apple.has_signal("collected"):
			apple.collected.connect(_on_apple_collected)


func reset() -> void:
	if step_in_progress:
		print("RESET IGNORED: step still in progress")
		return

	current_reward = 0.0
	score = 0
	episode_done = false

	get_parent().reset_level()

	_refresh_level_references()

	# Reconnect RL signals
	for enemy in enemies.get_children():
		if enemy.has_signal("player_died"):
			if not enemy.player_died.is_connected(_on_player_died):
				enemy.player_died.connect(_on_player_died)

	for apple in apples.get_children():
		if apple.has_signal("collected"):
			if not apple.collected.is_connected(_on_apple_collected):
				apple.collected.connect(_on_apple_collected)

	print("Environment reset")

func step(action: int) -> Dictionary:
	if episode_done:
		return {
			"state": get_state(),
			"reward": 0.0,
			"done": true,
			"score": score
		}

	if step_in_progress:
		return {
			"state": get_state(),
			"reward": 0.0,
			"done": episode_done,
			"score": score
		}

	step_in_progress = true

	# Small penalty for taking another step
	current_reward -= 0.01

	# Give the player the RL action
	player.set_rl_action(action)

	# Let the action affect the game
	for i in range(ACTION_FRAMES):
		await get_tree().physics_frame

		if episode_done:
			break

	step_in_progress = false

	var state = get_state()
	var reward = consume_reward()

	var result := {
		"state": state,
		"reward": reward,
		"done": episode_done,
		"score": score
	}

	print(
		"Action: ", action,
		" | State: ", state,
		" | Reward: ", reward,
		" | Done: ", episode_done,
		" | Score: ", score
	)

	return result


func get_state() -> String:
	return state_tracker.get_state(
		player,
		apples,
		enemies
	)


func get_score() -> int:
	return score


func is_done() -> bool:
	return episode_done


func add_reward(amount: float) -> void:
	current_reward += amount


func consume_reward() -> float:
	var reward := current_reward
	current_reward = 0.0
	return reward


func _on_apple_collected() -> void:
	add_reward(10.0)
	score += 10

	print("APPLE COLLECTED: +10")


func _on_player_died(_body) -> void:
	add_reward(-10.0)
	episode_done = true

	print("PLAYER DIED: -10")


# Temporary manual RL action testing
func _process(_delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if step_in_progress:
		return

	match event.keycode:
		KEY_1:
			print("KEY 1 DETECTED")
			step(1)

		KEY_2:
			print("KEY 2 DETECTED")
			step(2)

		KEY_3:
			print("KEY 3 DETECTED")
			step(3)

		KEY_4:
			print("KEY 4 DETECTED")
			step(4)

		KEY_5:
			print("KEY 5 DETECTED")
			step(5)

		KEY_R:
			reset()
func _refresh_level_references() -> void:
	player = $"../LevelRoot/Player"
	enemies = $"../LevelRoot/Enemies"
	apples = $"../LevelRoot/Apple"
