
extends Node

# ============================================================
# ADVANCED SARSA ENVIRONMENT
# ============================================================
#
# Designed around a 3-apple ordered route:
#
#   Apple 1: upper-left
#       ↓
#   Apple 2: left-most / lower-left
#       ↓
#   Apple 3: middle-bottom/right
#
# Main learning goals:
# - approach the required apple
# - walk when no jump is needed
# - jump primarily for same-level snail encounters
# - detect walls and reverse
# - tolerate exploration/death without excessive death penalty
# - prefer safer progress
# - leave bottom-right danger area
# - punish excessive waiting
# - immediately pursue the remaining objective
# ============================================================


var current_reward: float = 0.0
var score: int = 0
var episode_done: bool = false
var step_in_progress: bool = false

var stuck_steps: int = 0
var collected_apples_seen: int = 0

var bottom_right_stay_steps: int = 0

var previous_target_distance: float = -1.0
var previous_player_x: float = 0.0


# ------------------------------------------------------------
# ACTION TIMING
# ------------------------------------------------------------

const ACTION_FRAMES := 10


# ------------------------------------------------------------
# APPLE REWARDS
# ------------------------------------------------------------
#
# Large completion reward dominates the objective.
# Death is deliberately not enormous so exploration remains
# worthwhile.
# ------------------------------------------------------------

const FIRST_APPLE_REWARD := 60.0
const SECOND_APPLE_REWARD := 90.0
const THIRD_APPLE_REWARD := 120.0

const COMPLETION_REWARD := 300.0


# ------------------------------------------------------------
# GENERAL SHAPING
# ------------------------------------------------------------

const TIME_PENALTY := -0.12
const PROGRESS_REWARD := 0.45
const SAFE_PROGRESS_BONUS := 0.20
const WRONG_DIRECTION_PENALTY := -0.18
const UPWARD_TARGET_PROGRESS_REWARD := 0.30

const STUCK_PENALTY := -2.0


# ------------------------------------------------------------
# WALK / JUMP SHAPING
# ------------------------------------------------------------

# Small encouragement for normal walking.
const WALK_PROGRESS_BONUS := 0.10

# Discourage unnecessary jumping when there is no relevant
# same-level snail.
const UNNECESSARY_JUMP_PENALTY := -0.10
const TARGET_JUMP_BONUS := 0.60

# Encourage jump-over-snail behavior when the snail is on
# approximately the same level and is close/approaching.
const SNAIL_JUMP_BONUS := 0.75

# Small encouragement to wait briefly when a same-level snail
# is approaching. Time penalty still applies.
const GOOD_WAIT_BONUS := 0.20

# Stronger penalty for moving into a dangerous nearby snail
# without jumping.
const CLOSE_SNAIL_NO_JUMP_PENALTY := -0.60


# ------------------------------------------------------------
# WALL SHAPING
# ------------------------------------------------------------

const WALL_HIT_PENALTY := -1.0
const WALL_REVERSE_BONUS := 0.25


# ------------------------------------------------------------
# BOTTOM-RIGHT LOITERING
# ------------------------------------------------------------

const BOTTOM_RIGHT_STEP_PENALTY := -1.25
const BOTTOM_RIGHT_EXTRA_PENALTY := -2.0

const BOTTOM_RIGHT_WARNING_STEPS := 5
const BOTTOM_RIGHT_MAX_STEPS := 15


# ------------------------------------------------------------
# DEATH
# ------------------------------------------------------------

const DEATH_PENALTY := -25.0


# ------------------------------------------------------------
# NODE REFERENCES
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


func _ready() -> void:

	print(
		"=== ADVANCED SARSA RL ENVIRONMENT STARTED ==="
	)

	print(
		"[ADVANCED] Apple collection order: ANY ORDER"
		)

	print(
        "[ADVANCED] Target selection: nearest uncollected apple"
	)

	_refresh_level_references()
	_connect_signals()


# ============================================================
# SIGNALS
# ============================================================

func _connect_signals() -> void:

	if enemies != null:

		_connect_enemy_signals_recursive(
			enemies
		)

	if apples != null:

		_connect_apple_signals_recursive(
			apples
		)


func _connect_enemy_signals_recursive(
	node: Node
) -> void:

	for child in node.get_children():

		if child.has_signal("player_died"):

			if not child.player_died.is_connected(
				_on_player_died
			):

				child.player_died.connect(
					_on_player_died
				)

		_connect_enemy_signals_recursive(
			child
		)


func _connect_apple_signals_recursive(
	node: Node
) -> void:

	for child in node.get_children():

		if child.has_signal("collected"):

			if not child.collected.is_connected(
				_on_apple_collected
			):

				child.collected.connect(
					_on_apple_collected
				)

		_connect_apple_signals_recursive(
			child
		)


# ============================================================
# RESET
# ============================================================

func reset() -> void:

	if step_in_progress:
		return

	current_reward = 0.0
	score = 0
	episode_done = false
	step_in_progress = false

	stuck_steps = 0
	collected_apples_seen = 0
	bottom_right_stay_steps = 0

	previous_target_distance = -1.0
	previous_player_x = 0.0

	if state_tracker.has_method("reset_tracking"):

		state_tracker.reset_tracking()

	get_parent().reset_level()

	_refresh_level_references()
	_connect_signals()


# ============================================================
# STEP
# ============================================================

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


	# --------------------------------------------------------
	# BEFORE ACTION
	# --------------------------------------------------------

	var position_before := (
		Vector2(player.global_position)
	)

	var target_before := (
		get_target_position()
	)

	var target_distance_before := (
		position_before.distance_to(
			target_before
		)
	)



	# Time penalty every step.
	current_reward += TIME_PENALTY


	# --------------------------------------------------------
	# ACTION
	# --------------------------------------------------------

	player.set_rl_action(action)


	for _i in range(ACTION_FRAMES):

		await get_tree().physics_frame

		if episode_done:
			break


	# --------------------------------------------------------
	# AFTER ACTION
	# --------------------------------------------------------

	var position_after := (
		Vector2(player.global_position)
	)

	var target_after := (
		get_target_position()
	)

	var target_distance_after := (
		position_after.distance_to(
			target_after
		)
	)


	var reward := consume_reward()


	# ========================================================
	# 1. APPROACH TARGET
	# ========================================================

	var distance_change := (
		target_distance_before
		- target_distance_after
	)


	if distance_change > 4.0:

		reward += PROGRESS_REWARD


		# Additional safe-progress bonus when the agent is
		# moving toward its target without being in immediate
		# snail danger.
		if not _snail_is_immediately_dangerous():

			reward += SAFE_PROGRESS_BONUS


		# Normal walking is mildly preferred.
		if (
			action == 1
			or action == 2
		):

			reward += WALK_PROGRESS_BONUS


	elif distance_change < -20.0:

		reward += WRONG_DIRECTION_PENALTY

	# ========================================================
	# 1B. UPWARD TARGET PROGRESS
	# ========================================================

	var target_position_for_vertical := get_target_position()

	var target_y_direction_for_vertical: int = (
		state_tracker.get_target_y_direction(
			player,
			target_position_for_vertical
		)
	)

	if (
		target_y_direction_for_vertical < 0
		and position_after.y < position_before.y - 5.0
	):
		reward += UPWARD_TARGET_PROGRESS_REWARD

	# ========================================================
	# 2. JUMP SHAPING
	# ========================================================
	#
	# 4 = LEFT + JUMP
	# 5 = RIGHT + JUMP
	# ========================================================

	if action == 4 or action == 5:

		var target_position := get_target_position()

		var target_x_direction: int = (
			state_tracker.get_target_x_direction(
				player,
				target_position
			)
		)

		var target_y_direction: int = (
			state_tracker.get_target_y_direction(
				player,
				target_position
			)
		)

		var target_requires_upward_jump := (
			target_y_direction < 0
		)

		var jump_toward_target := (
			(action == 4 and target_x_direction < 0)
			or
			(action == 5 and target_x_direction > 0)
		)

		if (
			target_requires_upward_jump
			and jump_toward_target
		):

			reward += TARGET_JUMP_BONUS

		elif _good_snail_jump_opportunity():

			reward += SNAIL_JUMP_BONUS

		else:

			reward += UNNECESSARY_JUMP_PENALTY
	# ========================================================
	# 3. WAITING FOR APPROACHING SNAIL
	# ========================================================

	if action == 0 and _good_wait_opportunity():

		reward += GOOD_WAIT_BONUS


	# ========================================================
	# 4. WALKING INTO A CLOSE SNAIL
	# ========================================================

	if (
		(action == 1 or action == 2)
		and _snail_is_immediately_dangerous()
		and not _good_snail_jump_opportunity()
	):

		reward += CLOSE_SNAIL_NO_JUMP_PENALTY


	# ========================================================
	# 5. WALL DETECTION / REVERSE
	# ========================================================

	reward += (
		_handle_wall_behavior(
			action
		)
	)


	# ========================================================
	# 6. STUCK
	# ========================================================

	var movement := (
		position_before.distance_to(
			position_after
		)
	)

	if movement < 15.0 and not episode_done:

		stuck_steps += 1

	else:

		stuck_steps = 0


	if (
		stuck_steps >= 3
		and not episode_done
	):

		reward += STUCK_PENALTY

		stuck_steps = 0


	# ========================================================
	# 7. BOTTOM-RIGHT
	# ========================================================

	if not episode_done:

		reward += (
			handle_bottom_right_loitering()
		)


	# Make the state tracker compare the next frame against
	# this frame.
	previous_target_distance = target_distance_after
	previous_player_x = position_after.x


	step_in_progress = false


	return {
		"state": get_state(),
		"reward": reward,
		"done": episode_done,
		"score": score
	}


# ============================================================
# SNAIL HELPERS
# ============================================================

func _get_nearest_snail() -> Node2D:

	if enemies == null:
		return null

	var nearest: Node2D = null
	var nearest_distance := INF

	for child in enemies.get_children():

		if not child is Node2D:
			continue

		var snail := child as Node2D

		var distance := (
			player.global_position.distance_to(
				snail.global_position
			)
		)

		if distance < nearest_distance:

			nearest_distance = distance
			nearest = snail


	return nearest


func _snail_is_same_y() -> bool:

	var snail := _get_nearest_snail()

	if snail == null:
		return false

	return (
		absf(
			snail.global_position.y
			- player.global_position.y
		) <= 55.0
	)


func _snail_distance() -> float:

	var snail := _get_nearest_snail()

	if snail == null:
		return INF

	return (
		player.global_position.distance_to(
			snail.global_position
		)
	)


func _snail_is_approaching() -> bool:

	var value: Variant = (
		state_tracker.call(
			"get_snail_approach_state",
			player,
			enemies
		)
	)

	return int(value) == 1


func _snail_is_immediately_dangerous() -> bool:

	return (
		_snail_is_same_y()
		and _snail_distance() <= 110.0
	)


func _good_snail_jump_opportunity() -> bool:

	if not _snail_is_same_y():
		return false

	var distance := _snail_distance()

	if distance > 150.0:
		return false

	return (
		_snail_is_approaching()
		or distance <= 70.0
	)


func _good_wait_opportunity() -> bool:

	if not _snail_is_same_y():
		return false

	var distance := _snail_distance()

	if distance < 60.0:
		return false

	if distance > 170.0:
		return false

	return _snail_is_approaching()


# ============================================================
# WALL BEHAVIOR
# ============================================================

func _handle_wall_behavior(
	action: int
) -> float:

	var reward: float = 0.0

	var wall_low: int = int(
		state_tracker.get_wall_low(player)
	)

	var wall_high: int = int(
		state_tracker.get_wall_high(player)
	)

	var target_x: int = (
		state_tracker.get_target_x_direction(
			player,
			get_target_position()
		)
	)

	# A low obstacle directly ahead should discourage
	# continuing into it.
	if wall_low == 1:

		if (
			(target_x < 0 and action == 1)
			or (target_x > 0 and action == 2)
		):
			reward += WALL_HIT_PENALTY

		# Encourage changing direction when a low obstacle
		# blocks the intended direction.
		if (
			target_x < 0
			and action == 2
		):
			reward += WALL_REVERSE_BONUS

		if (
			target_x > 0
			and action == 1
		):
			reward += WALL_REVERSE_BONUS

	# A low obstacle with free space above it is a useful
	# jump situation.
	if (
		wall_low == 1
		and wall_high == 0
		and (action == 4 or action == 5)
	):
		reward += 0.35

	return reward


# ============================================================
# BOTTOM-RIGHT LOITERING
# ============================================================

func handle_bottom_right_loitering() -> float:

	var pos := Vector2(
		player.global_position
	)

	var in_bottom_right := (
		pos.x >= 950.0
		and pos.y >= 580.0
	)

	if not in_bottom_right:

		bottom_right_stay_steps = 0

		return 0.0


	bottom_right_stay_steps += 1

	var penalty := (
		BOTTOM_RIGHT_STEP_PENALTY
	)


	if (
		bottom_right_stay_steps
		> BOTTOM_RIGHT_WARNING_STEPS
	):

		penalty += (
			BOTTOM_RIGHT_EXTRA_PENALTY
		)

	# Do not terminate the episode just because the player
	# passes through this region. The agent may legitimately
	# need to cross the right side while navigating to the
	# next apple.
	#
	# The penalty increases while it remains in the region,
	# so SARSA learns to leave it rather than repeatedly
	# waiting there.


	return penalty


# ============================================================
# APPLE COLLECTION
# ============================================================

func _on_apple_collected() -> void:

	var current_count: int = (
		state_tracker.get_collected_apple_count(
			apples
		)
	)

	if current_count <= collected_apples_seen:
		return

	collected_apples_seen = current_count

	# --------------------------------------------------------
	# APPLES CAN BE COLLECTED IN ANY ORDER
	# --------------------------------------------------------

	if current_count == 1:

		add_reward(
			FIRST_APPLE_REWARD
		)

		score = 10

		print(
			"[ADVANCED] 1 APPLE COLLECTED: +60"
		)

	elif current_count == 2:

		add_reward(
			SECOND_APPLE_REWARD
		)

		score = 20

		print(
			"[ADVANCED] 2 APPLES COLLECTED: +90"
		)

	elif current_count == 3:

		add_reward(
			THIRD_APPLE_REWARD
		)

		score = 30

		add_reward(
			COMPLETION_REWARD
		)

		episode_done = true

		print(
			"[ADVANCED] ALL 3 APPLES COLLECTED: "
			+ "+300 COMPLETION -> SUCCESS"
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
		"[ADVANCED] PLAYER DIED: -25 -> "
		+ "EPISODE FAILURE"
	)


# ============================================================
# STATE ACCESS
# ============================================================

func get_state() -> String:

	return state_tracker.get_state(
		player,
		apples,
		enemies
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

	var reward := current_reward

	current_reward = 0.0

	return reward


# ============================================================
# REFERENCES
# ============================================================

func _refresh_level_references() -> void:

	player = $"../LevelRoot/Player"
	enemies = $"../LevelRoot/Enemies"
	apples = $"../LevelRoot/Apple"
