extends Node

# ============================================================
# SARSA V14 - ROUTE + REWARD ENVIRONMENT
# ============================================================
#
# Route:
# START
#   -> MIDDLE UPPER PLATFORM
#   -> LEFT SIDE OF MIDDLE PLATFORM
#   -> DESCEND
#   -> BOTTOM APPLE
#   -> LEFT PLATFORM
#   -> LEFT APPLE
#   -> SUCCESS
#
# The reward system is deliberately simple:
# 1. Large rewards for meaningful route milestones.
# 2. Small directional shaping only.
# 3. Strong penalties for known traps.
# 4. Strong penalty for returning to the middle platform
#    after the bottom apple.
# ============================================================


var current_reward: float = 0.0
var score: int = 0
var episode_done: bool = false
var step_in_progress: bool = false


# ------------------------------------------------------------
# ACTION TIMING
# ------------------------------------------------------------

const ACTION_FRAMES: int = 10


# ------------------------------------------------------------
# POSITIVE REWARDS
# ------------------------------------------------------------

const MIDDLE_PLATFORM_REWARD: float = 15.0
const LEFT_DESCENT_REWARD: float = 15.0
const BOTTOM_FLOOR_REWARD: float = 10.0

const FIRST_APPLE_REWARD: float = 50.0
const LEFT_PLATFORM_REWARD: float = 30.0
const SECOND_APPLE_REWARD: float = 100.0
const COMPLETION_REWARD: float = 100.0


# ------------------------------------------------------------
# SMALL DIRECTIONAL SHAPING
# ------------------------------------------------------------

const ROUTE_PROGRESS_REWARD: float = 0.10
const WRONG_ROUTE_DIRECTION_PENALTY: float = -0.10


# ------------------------------------------------------------
# STAGNATION
# ------------------------------------------------------------

const START_STAY_LIMIT: int = 5
const START_STAY_PENALTY: float = -2.0

const MIDDLE_STAY_LIMIT: int = 5
const MIDDLE_STAY_PENALTY: float = -4.0

const STUCK_CHECK_LIMIT: int = 3
const STUCK_MIN_MOVEMENT: float = 18.0
const GENERAL_STUCK_PENALTY: float = -4.0


# ------------------------------------------------------------
# DANGER
# ------------------------------------------------------------

const RIGHT_CORNER_WARNING_PENALTY: float = -10.0
const LEFT_CORNER_WARNING_PENALTY: float = -5.0

const RIGHT_CORNER_PENALTY: float = -75.0
const LEFT_CORNER_PENALTY: float = -30.0

const RETURN_TO_MIDDLE_PENALTY: float = -20.0
const WRONG_SIDE_AFTER_APPLE_PENALTY: float = -2.0

const TIME_PENALTY: float = -0.05
const DEATH_PENALTY: float = -30.0


# ------------------------------------------------------------
# MILESTONE FLAGS
# ------------------------------------------------------------

var middle_platform_bonus_given: bool = false
var left_descent_bonus_given: bool = false
var bottom_floor_bonus_given: bool = false
var left_platform_bonus_given: bool = false


# ------------------------------------------------------------
# STAGNATION COUNTERS
# ------------------------------------------------------------

var start_stay_steps: int = 0
var middle_stay_steps: int = 0
var stuck_steps: int = 0


# ------------------------------------------------------------
# REFERENCES
# ------------------------------------------------------------

@onready var state_tracker: Node = $RLState

@onready var player: CharacterBody2D = (
	$"../LevelRoot/Player"
)

@onready var enemies: Node = (
	$"../LevelRoot/Enemies"
)

@onready var apples: Node = (
	$"../LevelRoot/Apple"
)


# ------------------------------------------------------------
# READY
# ------------------------------------------------------------

func _ready() -> void:

	print(
        "=== SARSA V14 RL ENVIRONMENT STARTED ==="
	)

	_connect_signals()


# ------------------------------------------------------------
# SIGNALS
# ------------------------------------------------------------

func _connect_signals() -> void:

	if enemies != null:

		for enemy in enemies.get_children():

			if enemy.has_signal(
                "player_died"
			):

				if not enemy.player_died.is_connected(
					_on_player_died
				):

					enemy.player_died.connect(
						_on_player_died
					)

	if apples != null:

		for apple in apples.get_children():

			if apple.has_signal(
                "collected"
			):

				if not apple.collected.is_connected(
					_on_apple_collected
				):

					apple.collected.connect(
						_on_apple_collected
					)


# ------------------------------------------------------------
# RESET
# ------------------------------------------------------------

func reset() -> void:

	if step_in_progress:
		return

	current_reward = 0.0
	score = 0
	episode_done = false
	step_in_progress = false

	middle_platform_bonus_given = false
	left_descent_bonus_given = false
	bottom_floor_bonus_given = false
	left_platform_bonus_given = false

	start_stay_steps = 0
	middle_stay_steps = 0
	stuck_steps = 0

	get_parent().reset_level()

	_refresh_level_references()

	_connect_signals()


# ------------------------------------------------------------
# STEP
# ------------------------------------------------------------

func step(
	action: int
) -> Dictionary:

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

	current_reward += TIME_PENALTY

	var position_before: Vector2 = (
		Vector2(player.global_position)
	)

	var score_before: int = score

	player.set_rl_action(action)

	for _i: int in range(
		ACTION_FRAMES
	):

		await get_tree().physics_frame

		if episode_done:
			break

	var position_after: Vector2 = (
		Vector2(player.global_position)
	)

	var reward: float = (
		consume_reward()
	)


	# ========================================================
	# SMALL HORIZONTAL ROUTE SHAPING
	# ========================================================
	# No Euclidean distance reward.
	# Only helps the agent move toward the current stage target.
	# ========================================================

	if not episode_done:

		var target: Vector2 = (
			get_target_position()
		)

		var before_dx: float = absf(
			position_before.x
			- target.x
		)

		var after_dx: float = absf(
			position_after.x
			- target.x
		)

		if after_dx < before_dx - 5.0:

			reward += (
				ROUTE_PROGRESS_REWARD
			)

		elif after_dx > before_dx + 20.0:

			reward += (
				WRONG_ROUTE_DIRECTION_PENALTY
			)


	# ========================================================
	# STAGNATION
	# ========================================================

	reward += (
		get_stagnation_penalty()
	)


	# ========================================================
	# DANGEROUS AREAS
	# ========================================================

	reward += (
		handle_danger_zones()
	)


	# ========================================================
	# ROUTE MILESTONES
	# ========================================================

	reward += (
		handle_route_waypoints()
	)


	# ========================================================
	# GENERAL STUCK DETECTION
	# ========================================================

	var movement: float = (
		position_before.distance_to(
			position_after
		)
	)

	if (
		movement < STUCK_MIN_MOVEMENT
		and not episode_done
	):

		stuck_steps += 1

	else:

		stuck_steps = 0


	if (
		stuck_steps >= STUCK_CHECK_LIMIT
		and not episode_done
	):

		reward += (
			GENERAL_STUCK_PENALTY
		)

		stuck_steps = 0

		print(
            "[V14] GENERAL STUCK: -4"
		)


	# Collecting an apple resets stagnation counters.
	if score != score_before:

		start_stay_steps = 0
		middle_stay_steps = 0
		stuck_steps = 0


	step_in_progress = false


	return {
		"state": get_state(),
		"reward": reward,
		"done": episode_done,
		"score": score
	}


# ============================================================
# STAGNATION
# ============================================================

func get_stagnation_penalty() -> float:

	var penalty: float = 0.0

	var pos: Vector2 = (
		Vector2(player.global_position)
	)

	var stage: int = (
		get_route_stage()
	)


	# --------------------------------------------------------
	# START
	# --------------------------------------------------------

	var in_start_area: bool = (
		stage == 0
		and pos.x >= 220.0
		and pos.x <= 600.0
		and pos.y <= 360.0
	)

	if in_start_area:
		start_stay_steps += 1
	else:
		start_stay_steps = 0


	if start_stay_steps > START_STAY_LIMIT:

		penalty += (
			START_STAY_PENALTY
		)

		print(
            "[V14] START TOO LONG: -2"
		)


	# --------------------------------------------------------
	# MIDDLE UPPER PLATFORM
	# --------------------------------------------------------

	var in_middle: bool = (
		is_on_middle_platform(pos)
	)

	if (
		in_middle
		and score == 0
	):

		middle_stay_steps += 1

	else:

		middle_stay_steps = 0


	if middle_stay_steps > MIDDLE_STAY_LIMIT:

		penalty += (
			MIDDLE_STAY_PENALTY
		)

		print(
            "[V14] MIDDLE TOO LONG: -4"
		)


	return penalty


# ============================================================
# DANGER HANDLING
# ============================================================

func handle_danger_zones() -> float:

	var reward: float = 0.0

	var pos: Vector2 = (
		Vector2(player.global_position)
	)


	# --------------------------------------------------------
	# BOTTOM-RIGHT
	# --------------------------------------------------------

	if (
		pos.x >= 1050.0
		and pos.y >= 630.0
	):

		if pos.x < 1120.0:

			reward += (
				RIGHT_CORNER_WARNING_PENALTY
			)

			print(
                "[V14] RIGHT CORNER WARNING: -10"
			)

		else:

			reward += (
				RIGHT_CORNER_PENALTY
			)

			episode_done = true

			print("[V14] BOTTOM-RIGHT TRAP: -75 -> EPISODE FAILED")

			return reward


	# --------------------------------------------------------
	# BOTTOM-LEFT
	# --------------------------------------------------------

	if (
		pos.x <= 220.0
		and pos.y >= 630.0
	):

		if pos.x > 120.0:

			reward += (
				LEFT_CORNER_WARNING_PENALTY
			)

			print(
                "[V14] LEFT CORNER WARNING: -5"
			)

		else:

			reward += (
				LEFT_CORNER_PENALTY
			)

			episode_done = true

			print(
                "[V14] BOTTOM-LEFT TRAP: -30 -> EPISODE FAILED"
			)

			return reward


	# --------------------------------------------------------
	# RETURN TO MIDDLE AFTER FIRST APPLE
	# --------------------------------------------------------

	if (
		score >= 10
		and is_on_middle_platform(pos)
	):

		reward += (
			RETURN_TO_MIDDLE_PENALTY
		)

		print(
            "[V14] RETURNED TO MIDDLE: -20"
		)


	# --------------------------------------------------------
	# FAR RIGHT AFTER FIRST APPLE
	# --------------------------------------------------------

	if (
		score >= 10
		and is_bottom_floor(pos)
		and pos.x > 900.0
	):

		reward += (
			WRONG_SIDE_AFTER_APPLE_PENALTY
		)


	return reward


# ============================================================
# ROUTE MILESTONES
# ============================================================

func handle_route_waypoints() -> float:

	var reward: float = 0.0

	var pos: Vector2 = (
		Vector2(player.global_position)
	)

	var stage: int = (
		get_route_stage()
	)


	# --------------------------------------------------------
	# MIDDLE UPPER PLATFORM
	# --------------------------------------------------------

	if (
		not middle_platform_bonus_given
		and score == 0
		and stage >= 1
	):

		reward += (
			MIDDLE_PLATFORM_REWARD
		)

		middle_platform_bonus_given = true

		print(
            "[V14] MIDDLE UPPER PLATFORM: +15"
		)


	# --------------------------------------------------------
	# LEFT SIDE OF MIDDLE
	# --------------------------------------------------------

	if (
		not left_descent_bonus_given
		and score == 0
		and stage >= 2
		and not is_bottom_floor(pos)
	):

		reward += (
			LEFT_DESCENT_REWARD
		)

		left_descent_bonus_given = true

		print(
            "[V14] LEFT SIDE OF MIDDLE: +15"
		)


	# --------------------------------------------------------
	# SAFE BOTTOM FLOOR
	# --------------------------------------------------------

	if (
		not bottom_floor_bonus_given
		and score == 0
		and stage >= 3
		and is_bottom_floor(pos)
		and pos.x > 220.0
		and pos.x < 1050.0
	):

		reward += (
			BOTTOM_FLOOR_REWARD
		)

		bottom_floor_bonus_given = true

		print(
            "[V14] SAFE BOTTOM FLOOR: +10"
		)


	# --------------------------------------------------------
	# LEFT APPLE PLATFORM
	# --------------------------------------------------------

	if (
		score >= 10
		and not left_platform_bonus_given
		and is_left_platform()
	):

		reward += (
			LEFT_PLATFORM_REWARD
		)

		left_platform_bonus_given = true

		print(
            "[V14] LEFT APPLE PLATFORM: +30"
		)


	return reward


# ============================================================
# STATE / ROUTE
# ============================================================

func get_state() -> String:

	return state_tracker.get_state(
		player,
		apples,
		enemies
	)


func get_route_stage() -> int:

	return state_tracker.get_route_stage(
		player,
		apples
	)


func get_target_position() -> Vector2:

	return state_tracker.get_target_position(
		player,
		apples
	)


func get_score() -> int:

	return score


func is_done() -> bool:

	return episode_done


# ============================================================
# REWARD BUFFER
# ============================================================

func add_reward(
	amount: float
) -> void:

	current_reward += amount


func consume_reward() -> float:

	var reward: float = (
		current_reward
	)

	current_reward = 0.0

	return reward


# ============================================================
# APPLES
# ============================================================

func _on_apple_collected() -> void:

	if score == 0:

		add_reward(
			FIRST_APPLE_REWARD
		)

		print(
            "[V14] BOTTOM APPLE: +50"
		)

	else:

		add_reward(
			SECOND_APPLE_REWARD
		)

		print(
            "[V14] LEFT APPLE: +100"
		)

	score += 10


	if score >= 20:

		add_reward(
			COMPLETION_REWARD
		)

		episode_done = true

		print(
            "[V14] BOTH APPLES: +100 -> SUCCESS"
		)


# ============================================================
# DEATH
# ============================================================

func _on_player_died(
	_body: Node
) -> void:

	add_reward(
		DEATH_PENALTY
	)

	episode_done = true

	print(
        "[V14] PLAYER DIED: -30"
	)


# ============================================================
# GEOMETRY
# ============================================================

func is_bottom_floor(
	pos: Vector2
) -> bool:

	return pos.y >= 630.0


func is_on_middle_platform(
	pos: Vector2
) -> bool:

	return (
		pos.x >= 700.0
		and pos.x <= 960.0
		and pos.y >= 430.0
		and pos.y < 560.0
	)


func is_left_platform() -> bool:

	if (
		player == null
		or not player.is_on_floor()
	):

		return false

	var pos: Vector2 = (
		Vector2(player.global_position)
	)

	return (
		pos.x >= 20.0
		and pos.x <= 620.0
		and pos.y >= 520.0
		and pos.y <= 620.0
	)


# ============================================================
# REFRESH REFERENCES
# ============================================================

func _refresh_level_references() -> void:

	player = $"../LevelRoot/Player"
	enemies = $"../LevelRoot/Enemies"
	apples = $"../LevelRoot/Apple"
