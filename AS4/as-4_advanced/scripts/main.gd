extends Node2D

# ============================================================
# WebSocket RL Server
# ============================================================
var tcp_server: TCPServer = null
var ws_peer: WebSocketPeer = null
var rl_mode = false

const RL_PORT = 9080
# Each RL action persists for six physics ticks. _configure_speed() adjusts the
# tick rate so this remains 0.1 seconds of game time at every supported speed.
const FRAMES_PER_ACTION = 6
const CONTROL_RATE_HZ = 60.0
# Keep Godot's terminal step limit aligned with reinforcement_learning/config.py.
const MAX_STEPS = 1800

# ============================================================
# Step tracking
# ============================================================
var step_count = 0
var last_apple_dist = 0.0
# Number of apples collected during the current action horizon.  Keep this as
# a count so Python cannot mistake two collection signals for one event.
var apples_collected_this_step = 0
var enemy_hit_this_step = false
var fell_off_this_step = false
var action_in_flight = false
var action_ticks_remaining = 0

# ============================================================
# Scene references
# ============================================================
var player = null
var apples: Array = []
var snails: Array = []
var player_start_pos: Vector2
var total_apples = 0
var collected_apples = 0
var resetting_episode = false

# ============================================================
# Game bounds
# ============================================================
const FALL_THRESHOLD = 800.0
const WORLD_WIDTH = 1280.0
const WORLD_HEIGHT = 720.0
const DISTANCE_SHAPING_SCALE = 0.01


func _ready() -> void:
	print("[RL] _ready start")
	# Keep this node (the RL server) processing while the tree is paused so it
	# can receive and apply the next action at any time (lockstep).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Couple the physics tick rate to the engine speed so every physics tick
	# advances exactly 1/CONTROL_RATE_HZ s of game time at ANY time_scale.
	_configure_speed(1.0)
	_setup_level()
	_start_rl_server()
	# Lockstep: freeze the simulation until an RL action arrives.
	get_tree().paused = true
	print("[RL] timing: time_scale=", Engine.time_scale,
		  " physics_ticks=", _physics_ticks_per_second(),
		  " FRAMES_PER_ACTION=", FRAMES_PER_ACTION,
		  " action_physics_ticks=", _physics_ticks_per_action())
	print("[RL] _ready done")


func _setup_level() -> void:
	var level_root = $LevelRoot
	if not level_root:
		print("[RL] ERROR: LevelRoot not found")
		return
	# Freeze gameplay (player, apples, snails) while the tree is paused
	# (lockstep). The RL server node (this script) itself stays ALWAYS.
	level_root.process_mode = Node.PROCESS_MODE_PAUSABLE

	player = level_root.get_node_or_null("Player")
	if player:
		player_start_pos = player.position
		player.rl_control = true
		print("[RL] Player found at ", player_start_pos)
	else:
		print("[RL] ERROR: Player not found")

	var apple_node = level_root.get_node_or_null("Apple")
	if apple_node:
		for child in apple_node.get_children():
			if child is Area2D:
				apples.append(child)
				if child.has_signal("apple_collected") and not child.apple_collected.is_connected(_on_apple_collected):
					child.apple_collected.connect(_on_apple_collected)
	total_apples = apples.size()
	print("[RL] Apples: ", total_apples)

	var enemies_node = level_root.get_node_or_null("Enemies")
	if enemies_node:
		for child in enemies_node.get_children():
			if child is Area2D:
				snails.append(child)
				if child.has_signal("player_died") and not child.player_died.is_connected(_on_player_died):
					child.player_died.connect(_on_player_died)
	print("[RL] Snails: ", snails.size())


func _start_rl_server() -> void:
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(RL_PORT)
	if err == OK:
		print("[RL] TCP server listening on port ", RL_PORT)
	else:
		print("[RL] TCP server FAILED err=", err)


# ============================================================
# Main loop
# ============================================================
func _process(_delta: float) -> void:
	if not rl_mode:
		_check_for_connection()
		return

	if ws_peer == null:
		return

	ws_peer.poll()
	var state = ws_peer.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if action_in_flight:
			# _finish_action() is called from _physics_process at the exact end of
			# the action horizon, so there is nothing to do here.
			return

		while ws_peer.get_available_packet_count() > 0:
			var packet = ws_peer.get_packet()
			var msg_str = packet.get_string_from_utf8()
			var msg = JSON.parse_string(msg_str)
			if msg == null or not msg is Dictionary:
				print('[RL] Bad message: ', msg_str)
				continue

			var msg_type = msg.get('type', '')
			print('[RL] step=', step_count, ' received ', msg_type)

			if msg_type == 'reset':
				_handle_reset()
			elif msg_type == 'action':
				_handle_action(msg)
			elif msg_type == 'set_speed':
				_handle_set_speed(msg)
			elif msg_type == 'close':
				_close_rl_session()
			else:
				print('[RL] Unknown type: ', msg_type)

	elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
		print('[RL] WS closed (state=', state, ')')
		_close_rl_session()


func _physics_process(_delta: float) -> void:
	if not action_in_flight:
		return
	if player != null and player.position.y > FALL_THRESHOLD:
		fell_off_this_step = true
	if action_ticks_remaining <= 0:
		# Exactly FRAMES_PER_ACTION physics steps have fully simulated since the
		# action was applied. Snapshot and reply now, regardless of how many
		# physics ticks occur per rendered frame at high speed.
		_finish_action()
		return
	action_ticks_remaining -= 1

func _check_for_connection() -> void:
	if not tcp_server.is_connection_available():
		return
	var stream = tcp_server.take_connection()
	ws_peer = WebSocketPeer.new()
	ws_peer.accept_stream(stream)
	rl_mode = true
	step_count = 0
	print("[RL] Client connected, handshaking...")


func _close_rl_session() -> void:
	print("[RL] Closing session")
	if ws_peer:
		ws_peer.close()
	ws_peer = null
	rl_mode = false


# ============================================================
# Message handlers
# ============================================================
func _handle_reset() -> void:
	print("[RL] -> handle_reset")
	resetting_episode = true
	# Unpause briefly so the freshly respawned player's physics settles, then
	# freeze again before returning the state (lockstep).
	get_tree().paused = false
	_reset_scene()
	action_in_flight = false
	action_ticks_remaining = 0
	step_count = 0
	# Let a couple of physics frames run so the state returned by this reset
	# reflects the freshly respawned player's actual physics (floor contact,
	# settled velocity, near_gap) instead of the previous episode's last
	# physics frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	# A collection callback deferred by the previous episode can arrive during
	# the settling frames. Reapply the reset after those callbacks have drained,
	# then allow one frame for the collision shapes to re-enable.
	for apple in apples:
		apple.reset()
	collected_apples = 0
	apples_collected_this_step = 0
	await get_tree().physics_frame
	get_tree().paused = true
	resetting_episode = false
	var s = _get_state()
	var i = _get_info()
	print("[RL] <- reset response  px=", s.get("px", "?"), " py=", s.get("py", "?"))
	_send_json({"state": s, "reward": 0.0, "done": false, "info": i})


func _handle_action(msg: Dictionary) -> void:
	step_count += 1
	var action = int(msg.get('action', 0))
	print('[RL] -> action=', action, ' step=', step_count,
		  ' pos=(', player.position.x if player else -1, ',', player.position.y if player else -1, ')')

	# Clear event flags before applying this action. They will be populated by
	# collision/physics callbacks during this action's horizon.
	apples_collected_this_step = 0
	enemy_hit_this_step = false
	fell_off_this_step = false

	_apply_action(action)
	action_ticks_remaining = _physics_ticks_per_action()
	action_in_flight = true
	# Unlock the simulation for exactly one action horizon; _physics_process
	# re-pauses it the moment the horizon completes (lockstep).
	get_tree().paused = false


func _handle_set_speed(msg: Dictionary) -> void:
	var speed = float(msg.get('speed', 1.0))
	_configure_speed(speed)


func _finish_action() -> void:
	# These flags now describe the action that was just executed.
	var apples_this_step = apples_collected_this_step
	var got_apple = apples_this_step > 0
	var got_hit = enemy_hit_this_step
	var fell = fell_off_this_step or (player != null and player.position.y > FALL_THRESHOLD)
	apples_collected_this_step = 0
	enemy_hit_this_step = false
	fell_off_this_step = false

	var s = _get_state()
	var r = _calculate_reward(got_apple, got_hit, fell)
	# Store the post-action distance for the next transition's shaping reward.
	last_apple_dist = _safe_dist_to_apple()
	var d = _check_done()
	var i = _get_info()
	i['apple_collected'] = got_apple
	i['apples_collected_this_step'] = apples_this_step
	i['enemy_hit'] = got_hit
	i['fell_off'] = fell

	print('[RL] <- response  reward=', r, ' done=', d,
		  ' apple=', got_apple, ' hit=', got_hit,
		  ' pos=(', player.position.x if player else -1, ',', player.position.y if player else -1, ')')
	_send_json({'state': s, 'reward': r, 'done': d, 'info': i})
	action_in_flight = false
	action_ticks_remaining = 0
	# Freeze the simulation again until the next action arrives (lockstep).
	get_tree().paused = true



# ============================================================
# Action execution
# ============================================================
func _apply_action(action: int) -> void:
	if player == null:
		return
	# 0=stop 1=right 2=left 3=jump(keep dir) 4=right+jump 5=left+jump
	match action:
		0:
			player.rl_direction = 0.0
			player.rl_jump_pressed = false
		1:
			player.rl_direction = 1.0
			player.rl_jump_pressed = false
		2:
			player.rl_direction = -1.0
			player.rl_jump_pressed = false
		3:
			player.rl_jump_pressed = true
		4:
			player.rl_direction = 1.0
			player.rl_jump_pressed = true
		5:
			player.rl_direction = -1.0
			player.rl_jump_pressed = true


# ============================================================
# State extraction
# ============================================================
func _physics_ticks_per_second() -> int:
	return Engine.physics_ticks_per_second


func _physics_ticks_per_action() -> int:
	# _configure_speed locks the tick rate to CONTROL_RATE_HZ * time_scale, so
	# every tick is exactly 1/CONTROL_RATE_HZ s and FRAMES_PER_ACTION ticks is
	# the same game-time duration at every engine speed.
	return FRAMES_PER_ACTION


# Keep the per-tick game time fixed at 1/CONTROL_RATE_HZ s regardless of the
# engine speed. Without this, Engine.time_scale stretches each physics tick
# (e.g. one tick = 0.2 s of game time at 12x), so a fixed tick count per
# action spans different amounts of game time at different speeds.
func _configure_speed(time_scale: float) -> void:
	time_scale = max(time_scale, 0.0001)
	Engine.time_scale = time_scale
	Engine.physics_ticks_per_second = int(round(CONTROL_RATE_HZ * time_scale))
	# Allow enough physics steps per rendered frame to keep up at high speed;
	# otherwise the engine caps physics and the game runs in slow motion.
	Engine.max_physics_steps_per_frame = max(8, int(ceil(CONTROL_RATE_HZ * time_scale / 30.0)))
	print("[RL] speed=", time_scale, " physics_ticks=", Engine.physics_ticks_per_second,
		  " max_steps_per_frame=", Engine.max_physics_steps_per_frame)


func _get_state() -> Dictionary:
	if player == null:
		return _empty_state()

	var s = {}
	s["px"] = clamp(player.position.x / WORLD_WIDTH, 0.0, 1.0)
	s["py"] = clamp(player.position.y / WORLD_HEIGHT, 0.0, 1.0)
	s["on_ground"] = 1 if player.is_on_floor() else 0
	s["vx_sign"] = 1 if player.velocity.x > 50 else (-1 if player.velocity.x < -50 else 0)

	var ai = _nearest_uncollected_apple()
	if ai != null:
		var dx = ai["pos"].x - player.position.x
		var dy = ai["pos"].y - player.position.y
		s["apple_dir_x"] = 1 if dx > 30 else (-1 if dx < -30 else 0)
		s["apple_dir_y"] = 1 if dy < -30 else (-1 if dy > 30 else 0)
		s["apple_dist"] = clamp(ai["dist"] / 1500.0, 0.0, 1.0)
	else:
		s["apple_dir_x"] = 0
		s["apple_dir_y"] = 0
		s["apple_dist"] = 0.0

	var ei = _nearest_enemy()
	if ei != null:
		s["enemy_timing"] = _enemy_timing(ei)
	else:
		s["enemy_timing"] = 0

	s["apples_collected"] = _count_collected_apples()
	s["alive"] = 1 if player.alive else 0
	s["near_gap"] = _detect_gap_nearby()
	return s


func _empty_state() -> Dictionary:
	return {"px": 0.0, "py": 0.0, "on_ground": 0, "vx_sign": 0,
			"apple_dir_x": 0, "apple_dir_y": 0, "apple_dist": 0.0,
			"enemy_timing": 0,
			"apples_collected": 0, "alive": 0, "near_gap": 0}


func _nearest_uncollected_apple():
	if player == null:
		return null
	var best_dist = INF
	var best_pos = Vector2.ZERO
	for apple in apples:
		if apple.is_collected:
			continue
		var dist = player.position.distance_to(apple.position)
		if dist < best_dist:
			best_dist = dist
			best_pos = apple.position
	if best_dist == INF:
		return null
	return {"pos": best_pos, "dist": best_dist}


func _nearest_enemy():
	if player == null:
		return null
	var best_dist = INF
	var best_pos = Vector2.ZERO
	var best_direction = 0.0
	for snail in snails:
		var dist = player.position.distance_to(snail.position)
		if dist < best_dist:
			best_dist = dist
			best_pos = snail.position
			best_direction = snail.direction
	if best_dist == INF:
		return null
	return {"dist": best_dist, "pos": best_pos, "direction": best_direction}


func _enemy_timing(enemy_info: Dictionary) -> int:
	# 0 = far; 1..10 encode five relative-x zones and the snail's
	# left/right movement direction. This lets the agent learn whether to
	# continue, wait, or jump as the snail approaches.
	if enemy_info["dist"] >= 350.0:
		return 0

	var dx = enemy_info["pos"].x - player.position.x
	var x_zone = 0
	if dx < -240.0:
		x_zone = 0
	elif dx < -80.0:
		x_zone = 1
	elif dx < 80.0:
		x_zone = 2
	elif dx < 240.0:
		x_zone = 3
	else:
		x_zone = 4

	var motion = 0 if enemy_info["direction"] < 0.0 else 1
	return 1 + x_zone * 2 + motion


func _count_collected_apples() -> int:
	return collected_apples


func _safe_dist_to_apple() -> float:
	var info = _nearest_uncollected_apple()
	return info["dist"] if info != null else 0.0


# Cast a ray ahead of the player to check for walkable ground.
# Returns 1 if no ground is found ahead (gap/cliff), 0 otherwise.
# Uses physics queries instead of hardcoded positions — generalizable
# to any level layout.
func _detect_gap_nearby() -> int:
	if player == null or not player.is_on_floor():
		return 0

	var space_state = get_world_2d().direct_space_state
	var check_ahead = 70.0   # how far ahead to probe
	var check_down = 150.0    # how far down to search for ground

	# Check in the direction the player is currently moving,
	# or both directions if standing still.
	var vx = player.velocity.x
	var dirs: Array = []
	if abs(vx) > 30:
		dirs = [1 if vx > 0 else -1]
	else:
		dirs = [-1, 1]

	for d in dirs:
		var from_pos = player.position + Vector2(d * check_ahead, -30)
		var to_pos = from_pos + Vector2(0, check_down)
		var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1)
		var result = space_state.intersect_ray(query)
		if result.is_empty():
			return 1   # no ground ahead → gap

	return 0


# ============================================================
# Reward
# ============================================================
func _calculate_reward(got_apple: bool, got_hit: bool, fell: bool) -> float:
	var reward = -0.1
	var new_dist = _safe_dist_to_apple()
	if last_apple_dist > 0 and new_dist > 0:
		# Symmetric progress shaping: a retreat must cost the same magnitude
		# that an equivalent approach earns. The old +1/-0.5 asymmetry made
		# back-and-forth platform loops profitable without collecting apples.
		var distance_delta = last_apple_dist - new_dist
		reward += clamp(distance_delta * DISTANCE_SHAPING_SCALE, -1.0, 1.0)
	if got_apple:
		reward += 100.0
	if got_hit:
		reward -= 50.0
	if fell:
		reward -= 30.0
	if total_apples > 0 and _count_collected_apples() >= total_apples:
		reward += 300.0
	return reward



func _check_done() -> bool:
	if total_apples > 0 and _count_collected_apples() >= total_apples:
		print("[RL] DONE: all apples collected"); return true
	if player == null:
		print("[RL] DONE: player null"); return true
	if not player.alive:
		print("[RL] DONE: player dead"); return true
	if player.position.y > FALL_THRESHOLD:
		print("[RL] DONE: fell off y=", player.position.y); return true
	if step_count >= MAX_STEPS:
		print("[RL] DONE: maximum steps reached"); return true
	return false


func _get_info() -> Dictionary:
	return {
		"apples_collected": _count_collected_apples(),
		"total_apples": total_apples,
		"player_alive": 1 if (player != null and player.alive) else 0,
		"player_x": player.position.x if player else 0,
		"player_y": player.position.y if player else 0,
		"max_steps_reached": step_count >= MAX_STEPS,
	}


# ============================================================
# Scene reset
# ============================================================
func _reset_scene() -> void:
	if player:
		player.position = player_start_pos
		player.reset()
	for apple in apples:
		apple.reset()
	for snail in snails:
		snail.reset()
	collected_apples = 0
	apples_collected_this_step = 0
	enemy_hit_this_step = false
	fell_off_this_step = false
	# The first reward of the new episode must not be compared against the
	# previous episode's apple distance.
	last_apple_dist = 0.0
	print("[RL] Scene reset done")


# ============================================================
# Signal handlers
# ============================================================
func _on_apple_collected() -> void:
	if resetting_episode:
		return
	# Keep an episode-local count independent of deferred collision-shape
	# updates, so reset timing cannot expose a stale apple state.
	if collected_apples < total_apples:
		collected_apples += 1
		apples_collected_this_step += 1
	print("[RL] Apple collected!")


func _on_player_died(body) -> void:
	# Ghost-kill guard: a snail body_entered/player_died event from the tail
	# of the previous episode can be delivered after the reset has already
	# respawned the player. At that moment the respawned player is far from
	# every snail, so a death signal with no snail actually in contact is a
	# stale event — ignore it instead of killing the new episode at spawn.
	var nearest = _nearest_enemy()
	if nearest == null or nearest["dist"] > 100.0:
		return
	body.die()
	enemy_hit_this_step = true
	print("[RL] Player died!")


# ============================================================
# JSON messaging
# ============================================================
func _send_json(data: Dictionary) -> void:
	if ws_peer == null:
		print("[RL] _send_json: ws_peer is null!")
		return
	if ws_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("[RL] _send_json: ws not OPEN (state=", ws_peer.get_ready_state(), ")")
		return
	var json_str = JSON.stringify(data)
	var err = ws_peer.send_text(json_str)
	if err != OK:
		print("[RL] _send_json: send_text FAILED err=", err)
