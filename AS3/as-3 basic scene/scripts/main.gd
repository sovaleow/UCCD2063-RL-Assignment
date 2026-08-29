extends Node2D

# ============================================================================
# RL environment glue.
#
# One "decision" (env step) spans action_repeat physics ticks so the control
# frequency stays at the configured environment cadence. Agent pacing runs a
# 960 Hz physics clock with a configurable time scale (default 16), and
# RLServer pauses the scene tree between actions, so exactly ACTION_REPEAT
# ticks elapse per decision regardless of frame rate -- fully deterministic.
#
# State vector (19 dims, all roughly in [-2, 2] after normalisation):
#   0- 1  player position        (x / 640, y / 360)
#   2- 3  player velocity        (vx / 300, vy / 850)
#   4- 7  apple deltas           (dx / 640, dy / 360; 0 when collected)
#   8-11  snail deltas           (dx / 640, dy / 360)
#  12-13  apple collected flags  (0/1)
#  14     is_on_floor            (0/1)
#  15-16  snail patrol headings  (-1 / +1)
#  17-18  snail time-to-collision (seconds/2, clamped to [0,1])
# ============================================================================

const MAX_FRAMES: int = 800           # decisions per episode
# The recorded successful routes use one physics tick per RL decision.  A
# previous two-tick default changed the jump arc and made every route replay
# fail before DDQN even started.  RL_TICKS can override this for experiments.
const DEFAULT_ACTION_REPEAT: int = 1

# Reward settings (script-level values the assignment allows us to tune).
# Defaults below; each can be overridden per-instance via environment variables
# so parallel training runs can explore different settings from one codebase.
var step_penalty := 0.0        # RL_STEP_PENALTY   extra per-decision cost
var shaped_scale := 0.1        # (legacy one-sided shaping; unused when PBRS on)
var shaped_clamp := 2.0        # (legacy)
var apple_reward := 150.0      # RL_APPLE_REWARD    per apple
var death_penalty := -2.0      # RL_DEATH_PENALTY   snail contact
var timeout_penalty := -100.0  # RL_TIMEOUT_PENALTY episode budget exhausted
var all_apples_bonus := 800.0  # RL_BONUS           level cleared
var pbrs_scale := 0.05         # RL_PBRS_SCALE      policy-invariant PBRS shaping
var pbrs_gamma := 0.995        # RL_PBRS_GAMMA      must match the agent's gamma
var action_repeat: int = DEFAULT_ACTION_REPEAT

const INV_X := 1.0 / 640.0
const INV_Y := 1.0 / 360.0
const INV_VX := 1.0 / 300.0
const INV_VY := 1.0 / 850.0

var reward: float = 0.0
var done: bool = false
var frame_count: int = 0              # decisions taken this episode
var done_reason: String = ""          # "" | "dead" | "complete" | "timeout"

var apple_nodes: Array = []
var enemy_nodes: Array = []

var _step_state: int = 0              # 0 idle | 1 stepping | 2 result ready
var _repeat_left: int = 0
var _prev_dist_to_apple: float = 0.0
var _previous_collected: int = 0


func _ready() -> void:
	_setup_level()
	_collect_references()
	_configure_engine()


func _configure_engine() -> void:
	var seed_str := OS.get_environment("RL_SEED")
	if seed_str != "":
		seed(int(seed_str))
	# Per-instance reward overrides (used by parallel training experiments).
	step_penalty = _env_f("RL_STEP_PENALTY", step_penalty)
	shaped_scale = _env_f("RL_SHAPED_SCALE", shaped_scale)
	shaped_clamp = _env_f("RL_SHAPED_CLAMP", shaped_clamp)
	apple_reward = _env_f("RL_APPLE_REWARD", apple_reward)
	death_penalty = _env_f("RL_DEATH_PENALTY", death_penalty)
	timeout_penalty = _env_f("RL_TIMEOUT_PENALTY", timeout_penalty)
	all_apples_bonus = _env_f("RL_BONUS", all_apples_bonus)
	pbrs_scale = _env_f("RL_PBRS_SCALE", pbrs_scale)
	pbrs_gamma = _env_f("RL_PBRS_GAMMA", pbrs_gamma)
	var ticks := OS.get_environment("RL_TICKS")
	if ticks != "":
		action_repeat = max(1, int(ticks))


# Called by RLServer as soon as an RL client connects (windowed or headless).
# The agent gets a fixed, reproducible simulation clock. Manual play without
# an agent keeps the project's normal engine defaults.
func enable_agent_pacing() -> void:
	Engine.physics_ticks_per_second = 960
	var scale_str := OS.get_environment("RL_TIME_SCALE")
	# 960 Hz * 16x gives one calibrated 1/60 s of game time per physics tick.
	# This matches the recorded routes and the player's original physics.
	var time_scale := 16.0 if scale_str == "" else maxf(float(scale_str), 0.1)
	Engine.time_scale = time_scale
	Engine.max_fps = 960
	print("RL pacing: physics_ticks=%d time_scale=%.1f action_ticks=%d pause=%s snail_clock=%s" % [
		Engine.physics_ticks_per_second, Engine.time_scale, action_repeat,
		OS.get_environment("RL_PAUSE") != "0",
		("render" if OS.get_environment("RL_SNAIL_IDLE") == "1" else "physics")])


func _env_f(key: String, fallback: float) -> float:
	var v := OS.get_environment(key)
	return float(v) if v != "" else fallback


func _collect_references():
	apple_nodes = $LevelRoot/Apple.get_children()
	enemy_nodes = $LevelRoot/Enemies.get_children()


func _setup_level() -> void:
	var enemies = $LevelRoot.get_node_or_null("Enemies")
	if enemies:
		for enemy in enemies.get_children():
			enemy.player_died.connect(_on_player_died)


func _on_player_died(body):
	body.die()


func step(action: int):
	$LevelRoot/Player.set_action(action)
	reward = step_penalty
	frame_count += 1
	_step_state = 1
	# Physics ticks consumed by one decision.  Keep the default at one tick to
	# match the recorded expert routes and the original training cadence.
	_repeat_left = action_repeat
	_prev_dist_to_apple = _route_target_dist()


# Runs once per physics tick (before children, i.e. before Player integrates).
func _physics_process(_delta: float) -> void:
	if _step_state != 1:
		return
	_repeat_left -= 1
	if _repeat_left > 0:
		return
	_step_state = 2
	_evaluate_step()


func _evaluate_step() -> void:
	var player = $LevelRoot/Player

	var collected_count = _count_collected()
	var newly_collected = collected_count - _previous_collected

	# Potential-based reward shaping (Ng et al., 1999) on the ROUTE-ORDERED
	# target distance (_route_target_dist): the far-right apple first, then
	# the middle one, mirroring the recorded successful route.  Approaching
	# pays, retreating costs, and standing still costs (1-gamma)*d, so
	# wandering until timeout is no longer free.  Skipped on the collection
	# step because the target switch makes the potential jump discontinuously
	# there.
	var dist_now: float = _route_target_dist()
	if newly_collected == 0 and dist_now < INF and _prev_dist_to_apple < INF:
		if pbrs_scale > 0.0:
			# Potential-based shaping (policy-invariant): approaching pays,
			# retreating and idling cost.
			var f: float = (_prev_dist_to_apple - pbrs_gamma * dist_now) * pbrs_scale
			reward += clampf(f, -2.5, 2.5)
		else:
			# Legacy one-sided shaping: only closing distance (in px) pays.
			var progress: float = _prev_dist_to_apple - dist_now
			if progress > 0.0:
				reward += clampf(progress * shaped_scale, 0.0, shaped_clamp)

	if newly_collected > 0:
		reward += newly_collected * apple_reward
		_previous_collected = collected_count

	# Death
	if not player.alive:
		reward += death_penalty
		done = true
		done_reason = "dead"
		return

	# All apples collected
	if collected_count >= apple_nodes.size():
		reward += all_apples_bonus
		done = true
		done_reason = "complete"
		return

	# Timeout
	if frame_count >= MAX_FRAMES:
		reward += timeout_penalty
		done = true
		done_reason = "timeout"


# Potential-based reward shaping target, ORDERED like the successful route:
# apple_nodes[0] (far-right apple) until collected, then apple_nodes[1]
# (middle apple).  A nearest-uncollected potential pulls the agent to the
# middle apple first and strands it there (observed: agent camps and jumps
# in front of it, never walking to the far-right apple), while the route
# takes the far-right apple first and returns for the middle one.  Ordered
# targeting reproduces the route order in the shaping gradient.
func _route_target_dist() -> float:
	var player = $LevelRoot/Player
	for apple in apple_nodes:
		if not apple.is_collected():
			return player.position.distance_to(apple.position)
	return INF


func _count_collected() -> int:
	var n = 0
	for apple in apple_nodes:
		if apple.is_collected():
			n += 1
	return n


func is_step_ready() -> bool:
	return _step_state == 2


func reset():
	_previous_collected = 0
	reward = 0.0
	done = false
	frame_count = 0
	_step_state = 0
	_repeat_left = 0
	_prev_dist_to_apple = 0.0
	done_reason = ""

	$LevelRoot/Player.reset()

	for apple in apple_nodes:
		apple.reset()

	for enemy in enemy_nodes:
		enemy.reset()


func get_state() -> Array:
	var player = $LevelRoot/Player

	var apple1 = apple_nodes[0] if apple_nodes.size() > 0 else null
	var apple2 = apple_nodes[1] if apple_nodes.size() > 1 else null
	var enemy1 = enemy_nodes[0] if enemy_nodes.size() > 0 else null
	var enemy2 = enemy_nodes[1] if enemy_nodes.size() > 1 else null

	# Uncollected apples report their relative offset; collected ones report 0
	# (the collected flags below carry that information instead of a 9999 marker).
	var apple1_dx := 0.0
	var apple1_dy := 0.0
	var apple2_dx := 0.0
	var apple2_dy := 0.0

	if apple1 and not apple1.is_collected():
		apple1_dx = (apple1.position.x - player.position.x) * INV_X
		apple1_dy = (apple1.position.y - player.position.y) * INV_Y

	if apple2 and not apple2.is_collected():
		apple2_dx = (apple2.position.x - player.position.x) * INV_X
		apple2_dy = (apple2.position.y - player.position.y) * INV_Y

	return [
		player.position.x * INV_X,
		player.position.y * INV_Y,

		player.velocity.x * INV_VX,
		player.velocity.y * INV_VY,

		apple1_dx,
		apple1_dy,

		apple2_dx,
		apple2_dy,

		(enemy1.position.x - player.position.x) * INV_X if enemy1 else 0.0,
		(enemy1.position.y - player.position.y) * INV_Y if enemy1 else 0.0,

		(enemy2.position.x - player.position.x) * INV_X if enemy2 else 0.0,
		(enemy2.position.y - player.position.y) * INV_Y if enemy2 else 0.0,

		1.0 if (apple1 and apple1.is_collected()) else 0.0,
		1.0 if (apple2 and apple2.is_collected()) else 0.0,

		1.0 if player.is_on_floor() else 0.0,

		# Patrol headings (+1/-1): let the network time jumps across the
		# snails instead of inferring direction from a 4-frame window.
		(enemy1.direction if enemy1 else 0.0),
		(enemy2.direction if enemy2 else 0.0),

		# Time-to-collision with each snail assuming current velocities,
		# normalised to [0,1] over 2 s (1 = no threat / not approaching).
		# Makes the jump-timing rule linearly separable for the network.
		_snail_ttc(enemy1, player),
		_snail_ttc(enemy2, player),
	]


func _snail_ttc(snail, player) -> float:
	if snail == null:
		return 1.0
	var ndx: float = snail.position.x - player.position.x
	var ndy: float = absf(snail.position.y - player.position.y)
	if ndy >= 36.0:
		return 1.0
	var rel: float = player.velocity.x - snail.direction * 100.0
	if ndx * rel <= 0.0:
		return 1.0                              # not approaching
	return clampf(absf(ndx) / maxf(absf(rel), 40.0) / 2.0, 0.0, 1.0)


func get_reward() -> float:
	return reward


func is_done() -> bool:
	return done


func get_done_reason() -> String:
	return done_reason


func get_apples() -> int:
	return _count_collected()
