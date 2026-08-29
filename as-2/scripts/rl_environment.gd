extends Node

# ============================================================
# ADVANCED SARSA RL ENVIRONMENT
# ============================================================
#
# REQUIRED APPLE ORDER:
#
#   Apple 1 = upper-left
#       ↓
#   Apple 2 = left-most
#       ↓
#   Apple 3 = middle-bottom
#       ↓
#   SUCCESS
#
# The agent is NOT allowed to choose the nearest apple as
# its objective. An out-of-order collection is treated as a
# failed episode with a strong negative reward.
#
# Bottom-right corner:
# - negative reward for staying there
# - stronger penalty after several consecutive steps
# - episode ends only after prolonged loitering
#
# ============================================================


var current_reward: float = 0.0
var score: int = 0
var episode_done: bool = false
var step_in_progress: bool = false

var stuck_steps: int = 0
var collected_apples_seen: int = 0

# Consecutive Python/RL steps spent in the bottom-right region.
var bottom_right_stay_steps: int = 0


# ------------------------------------------------------------
# ACTION TIMING
# ------------------------------------------------------------

const ACTION_FRAMES := 10


# ------------------------------------------------------------
# APPLE REWARDS
# ------------------------------------------------------------

const FIRST_APPLE_REWARD := 50.0
const SECOND_APPLE_REWARD := 75.0
const THIRD_APPLE_REWARD := 100.0
const COMPLETION_REWARD := 150.0


# ------------------------------------------------------------
# INVALID APPLE ORDER
# ------------------------------------------------------------

const WRONG_APPLE_PENALTY := -40.0


# ------------------------------------------------------------
# GENERAL REWARDS
# ------------------------------------------------------------

const TIME_PENALTY := -0.05
const ROUTE_PROGRESS_REWARD := 0.15
const WRONG_DIRECTION_PENALTY := -0.10


# ------------------------------------------------------------
# STUCK
# ------------------------------------------------------------

const STUCK_CHECK_LIMIT := 3
const STUCK_MIN_MOVEMENT := 18.0
const GENERAL_STUCK_PENALTY := -4.0


# ------------------------------------------------------------
# BOTTOM-RIGHT LOITERING
# ------------------------------------------------------------

# The agent should learn that staying in the circled area is bad.
const BOTTOM_RIGHT_STEP_PENALTY := -1.0
const BOTTOM_RIGHT_EXTRA_PENALTY := -3.0

const BOTTOM_RIGHT_WARNING_STEPS := 5
const BOTTOM_RIGHT_MAX_STEPS := 15


# ------------------------------------------------------------
# DEATH
# ------------------------------------------------------------

const DEATH_PENALTY := -30.0


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
		"[ADVANCED] Target order: "
		+ "Apple 1 (upper-left) -> "
		+ "Apple 2 (left-most) -> "
		+ "Apple 3 (middle-bottom)"
	)

	print(
		"[ADVANCED] Bottom-right loitering penalty enabled."
	)

	_refresh_level_references()
	_connect_signals()


# ============================================================
# SIGNAL CONNECTIONS
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

	current_reward += TIME_PENALTY


	var position_before := (
		Vector2(player.global_position)
	)

	var target_before := get_target_position()


	player.set_rl_action(action)


	for _i in range(ACTION_FRAMES):

		await get_tree().physics_frame

		if episode_done:
			break


	var position_after := (
		Vector2(player.global_position)
	)


	var reward := consume_reward()


	# ========================================================
	# PROGRESS TOWARD THE REQUIRED APPLE
	# ========================================================

	if not episode_done:

		var before_distance := (
			position_before.distance_to(
				target_before
			)
		)

		var after_distance := (
			position_after.distance_to(
				target_before
			)
		)

		if after_distance < before_distance - 5.0:

			reward += ROUTE_PROGRESS_REWARD

		elif after_distance > before_distance + 20.0:

			reward += WRONG_DIRECTION_PENALTY


	# ========================================================
	# STUCK DETECTION
	# ========================================================

	var movement := (
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

		reward += GENERAL_STUCK_PENALTY

		stuck_steps = 0

		print(
			"[ADVANCED] STUCK: -4"
		)


	# ========================================================
	# BOTTOM-RIGHT LOITERING
	# ========================================================

	if not episode_done:

		reward += handle_bottom_right_loitering()


	step_in_progress = false


	return {
		"state": get_state(),
		"reward": reward,
		"done": episode_done,
		"score": score
	}


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

		# Reset consecutive counter when the agent leaves.
		bottom_right_stay_steps = 0

		return 0.0


	bottom_right_stay_steps += 1


	var penalty := BOTTOM_RIGHT_STEP_PENALTY


	# After 5 consecutive steps, make the penalty stronger.
	if (
		bottom_right_stay_steps
		> BOTTOM_RIGHT_WARNING_STEPS
	):

		penalty += BOTTOM_RIGHT_EXTRA_PENALTY


	# Prolonged loitering becomes a failure.
	if (
		bottom_right_stay_steps
		>= BOTTOM_RIGHT_MAX_STEPS
	):

		penalty += -10.0

		episode_done = true

		print(
			"[ADVANCED] BOTTOM-RIGHT LOITERING: "
			+ str(bottom_right_stay_steps)
			+ " steps -> FAILURE"
		)

	else:

		print(
			"[ADVANCED] BOTTOM-RIGHT PENALTY: "
			+ str(penalty)
			+ " ("
			+ str(bottom_right_stay_steps)
			+ " consecutive steps)"
		)


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

	if (
		current_count
		<= collected_apples_seen
	):
		return

	collected_apples_seen = current_count

	# --------------------------------------------------------
	# FIRST APPLE
	# --------------------------------------------------------

	if current_count == 1:

		add_reward(
			FIRST_APPLE_REWARD
		)

		score = 10

		print(
			"[ADVANCED] FIRST APPLE COLLECTED: +50"
		)

	# --------------------------------------------------------
	# SECOND APPLE
	# --------------------------------------------------------

	elif current_count == 2:

		add_reward(
			SECOND_APPLE_REWARD
		)

		score = 20

		print(
			"[ADVANCED] SECOND APPLE COLLECTED: +75"
		)

	# --------------------------------------------------------
	# THIRD / LAST APPLE
	# --------------------------------------------------------

	elif current_count == 3:

		add_reward(
			THIRD_APPLE_REWARD
		)

		score = 30

		print(
			"[ADVANCED] THIRD APPLE COLLECTED: +100"
		)

		add_reward(
			COMPLETION_REWARD
		)

		episode_done = true

		print(
			"[ADVANCED] ALL 3 APPLES COLLECTED: "
			+ "+150 -> SUCCESS"
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
		"[ADVANCED] PLAYER DIED: -30 -> FAILURE"
	)


# ============================================================
# STATE
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
# REFRESH REFERENCES
# ============================================================

func _refresh_level_references() -> void:

	player = $"../LevelRoot/Player"
	enemies = $"../LevelRoot/Enemies"
	apples = $"../LevelRoot/Apple"
