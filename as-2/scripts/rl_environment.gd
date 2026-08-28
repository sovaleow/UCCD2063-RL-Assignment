extends Node

# ============================================================
# SARSA V7 ENVIRONMENT
# ============================================================

var current_reward: float = 0.0
var score: int = 0
var episode_done: bool = false

var previous_target_distance: float = -1.0

var step_in_progress: bool = false

const ACTION_FRAMES: int = 15

# ============================================================
# REWARDS
# ============================================================

const FIRST_APPLE_REWARD: float = 30.0
const SECOND_APPLE_REWARD: float = 60.0
const COMPLETION_REWARD: float = 80.0

const LEFT_PLATFORM_BONUS: float = 15.0

const BOTTOM_RIGHT_ENTRY_PENALTY: float = -3.0
const BOTTOM_RIGHT_STAY_PENALTY: float = -1.0

const TIME_PENALTY: float = -0.05

# ============================================================
# TRACKING
# ============================================================

var left_platform_bonus_given: bool = false
var previously_in_bottom_right: bool = false


@onready var state_tracker = $RLState
@onready var player = $"../LevelRoot/Player"
@onready var enemies = $"../LevelRoot/Enemies"
@onready var apples = $"../LevelRoot/Apple"


func _ready() -> void:

	print(
		"=== SARSA V7 RL ENVIRONMENT STARTED ==="
	)

	_connect_signals()


# ============================================================
# SIGNALS
# ============================================================

func _connect_signals() -> void:

	if enemies != null:

		for enemy in enemies.get_children():

			if enemy.has_signal("player_died"):

				if not enemy.player_died.is_connected(
					_on_player_died
				):

					enemy.player_died.connect(
						_on_player_died
					)


	if apples != null:

		for apple in apples.get_children():

			if apple.has_signal("collected"):

				if not apple.collected.is_connected(
					_on_apple_collected
				):

					apple.collected.connect(
						_on_apple_collected
					)


# ============================================================
# RESET
# ============================================================

func reset() -> void:

	if step_in_progress:

		print(
			"RESET IGNORED: step still in progress"
		)

		return


	current_reward = 0.0
	score = 0
	episode_done = false

	previous_target_distance = -1.0

	left_platform_bonus_given = false
	previously_in_bottom_right = false


	get_parent().reset_level()

	_refresh_level_references()

	_connect_signals()


	previous_target_distance = (
		get_target_distance()
	)


# ============================================================
# STEP
# ============================================================

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


	# ========================================================
	# TIME PENALTY
	# ========================================================

	current_reward += TIME_PENALTY


	var score_before: int = score


	# ========================================================
	# SEND ACTION
	# ========================================================

	player.set_rl_action(action)


	# ========================================================
	# RUN GAME FRAMES
	# ========================================================

	for _i in range(ACTION_FRAMES):

		await get_tree().physics_frame

		if episode_done:

			break


	# ========================================================
	# STATE
	# ========================================================

	var state: String = get_state()


	# ========================================================
	# REWARD
	# ========================================================

	var reward: float = (
		consume_reward()
	)


	# ========================================================
	# TARGET DISTANCE SHAPING
	# ========================================================

	var current_distance: float = (
		get_target_distance()
	)


	var apple_collected: bool = (
		score > score_before
	)


	if (
		not apple_collected
		and
		not episode_done
		and
		previous_target_distance >= 0.0
		and
		current_distance >= 0.0
	):

		var distance_change: float = (
			previous_target_distance
			- current_distance
		)


		reward += clampf(
			distance_change * 0.005,
			-0.5,
			0.5
		)


	previous_target_distance = current_distance


	# ========================================================
	# BOTTOM-RIGHT TRAP
	# ========================================================

	var in_bottom_right: bool = (
		is_in_bottom_right()
	)


	if in_bottom_right:

		if not previously_in_bottom_right:

			reward += (
				BOTTOM_RIGHT_ENTRY_PENALTY
			)

			print(
				"[V7] ENTERED BOTTOM-RIGHT: -3"
			)

		else:

			reward += (
				BOTTOM_RIGHT_STAY_PENALTY
			)


	previously_in_bottom_right = (
		in_bottom_right
	)


	# ========================================================
	# LEFT PLATFORM BONUS
	#
	# Only after bottom-middle Apple2 is collected.
	# ========================================================

	if (
		not left_platform_bonus_given
		and
		has_bottom_apple_been_collected()
		and
		is_left_platform()
	):

		reward += (
			LEFT_PLATFORM_BONUS
		)

		left_platform_bonus_given = true

		print(
			"[V7] LEFT PLATFORM BONUS: +15"
		)


	# ========================================================
	# DONE
	# ========================================================

	var done: bool = episode_done

	step_in_progress = false


	print(
		"[SARSA V7] Action=",
		action,
		" | State=",
		state,
		" | Reward=",
		reward,
		" | Done=",
		done,
		" | Score=",
		score
	)


	return {
		"state": state,
		"reward": reward,
		"done": done,
		"score": score
	}


# ============================================================
# STATE
# ============================================================

func get_state() -> String:

	return state_tracker.get_state(
		player,
		apples,
		enemies
	)


# ============================================================
# SCORE
# ============================================================

func get_score() -> int:

	return score


func is_done() -> bool:

	return episode_done


# ============================================================
# REWARD
# ============================================================

func add_reward(
	amount: float
) -> void:

	current_reward += amount


func consume_reward() -> float:

	var reward: float = current_reward

	current_reward = 0.0

	return reward


# ============================================================
# APPLE COLLECTED
# ============================================================

func _on_apple_collected() -> void:

	if score == 0:

		add_reward(
			FIRST_APPLE_REWARD
		)

		print(
			"BOTTOM/APPLE 1 COLLECTED: +30"
		)

	else:

		add_reward(
			SECOND_APPLE_REWARD
		)

		print(
			"APPLE 2 COLLECTED: +60"
		)


	score += 10


	if score >= 20:

		add_reward(
			COMPLETION_REWARD
		)

		episode_done = true

		print(
			"ALL 2 APPLES COLLECTED "
			+ "- COMPLETION BONUS +80"
		)


# ============================================================
# DEATH
# ============================================================

func _on_player_died(_body) -> void:

	add_reward(-20.0)

	episode_done = true

	print(
		"PLAYER DIED: -20"
	)


# ============================================================
# TARGET DISTANCE
# ============================================================

func get_target_distance() -> float:

	if player == null or apples == null:

		return -1.0


	var bottom_apple: Node2D = null
	var left_apple: Node2D = null


	for child in apples.get_children():

		if not child is Node2D:

			continue


		var apple: Node2D = child as Node2D


		if apple.name == "Apple2":

			bottom_apple = apple

		elif apple.name == "Apple":

			left_apple = apple


	# First target
	if (
		bottom_apple != null
		and
		bottom_apple.get(
			"already_collected"
		) != true
	):

		return player.global_position.distance_to(
			bottom_apple.global_position
		)


	# Second target
	if (
		left_apple != null
		and
		left_apple.get(
			"already_collected"
		) != true
	):

		return player.global_position.distance_to(
			left_apple.global_position
		)


	return -1.0


# ============================================================
# BOTTOM APPLE
# ============================================================

func has_bottom_apple_been_collected() -> bool:

	if apples == null:

		return false


	for child in apples.get_children():

		if child.name == "Apple2":

			return (
				child.get(
					"already_collected"
				)
				== true
			)


	return false


# ============================================================
# BOTTOM-RIGHT TRAP
# ============================================================

func is_in_bottom_right() -> bool:

	if player == null:

		return false


	return (
		player.global_position.x >= 950.0
		and
		player.global_position.y >= 550.0
	)


# ============================================================
# LEFT PLATFORM
# ============================================================

func is_left_platform() -> bool:

	if player == null:

		return false


	if not player.is_on_floor():

		return false


	var pos: Vector2 = player.global_position


	return (
		pos.x >= 250.0
		and
		pos.x <= 450.0
		and
		pos.y >= 480.0
		and
		pos.y <= 570.0
	)


# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:

	if not event is InputEventKey:

		return


	if (
		not event.pressed
		or
		event.echo
	):

		return


	if step_in_progress:

		return


	match event.keycode:

		KEY_0:
			step(0)

		KEY_1:
			step(1)

		KEY_2:
			step(2)

		KEY_3:
			step(3)

		KEY_4:
			step(4)

		KEY_5:
			step(5)

		KEY_R:
			reset()


# ============================================================
# REFRESH
# ============================================================

func _refresh_level_references() -> void:

	player = $"../LevelRoot/Player"

	enemies = $"../LevelRoot/Enemies"

	apples = $"../LevelRoot/Apple"