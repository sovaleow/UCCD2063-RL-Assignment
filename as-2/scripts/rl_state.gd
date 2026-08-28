extends Node

# ============================================================
# SARSA V7 - COMPACT SCENE-AWARE STATE
# ============================================================
#
# Apple order:
#
#   1. Bottom-middle Apple2 = (845, 642)
#   2. Left Apple            = (133, 549)
#
# State:
#
#   0  scene_region
#   1  target_apple
#   2  x_direction
#   3  y_direction
#   4  distance_category
#   5  on_floor
#   6  vertical_motion
#   7  ground_ahead
#   8  obstacle_ahead
#   9  snail_state
#   10 route_progress
#   11 bottom_right_danger
#
# ============================================================


# ============================================================
# KNOWN APPLE POSITIONS
# ============================================================

const LEFT_APPLE_POSITION: Vector2 = Vector2(
	133.0,
	549.0
)

const BOTTOM_APPLE_POSITION: Vector2 = Vector2(
	845.0,
	642.0
)


# ============================================================
# SCENE REGIONS
# ============================================================
#
# 0 = upper / starting area
# 1 = upper-middle
# 2 = bottom-right danger
# 3 = bottom-middle apple
# 4 = lower-middle
# 5 = lower-left
# 6 = left apple
#
# ============================================================

func get_scene_region(pos: Vector2) -> int:

	# Left apple area
	if (
		pos.x <= 220.0
		and
		pos.y >= 480.0
	):
		return 6


	# Lower-left platform
	if (
		pos.x > 220.0
		and
		pos.x <= 450.0
		and
		pos.y >= 450.0
	):
		return 5


	# Lower-middle area
	if (
		pos.x > 450.0
		and
		pos.x < 700.0
		and
		pos.y >= 450.0
	):
		return 4


	# Bottom-middle apple area
	if (
		pos.x >= 700.0
		and
		pos.x < 950.0
		and
		pos.y >= 550.0
	):
		return 3


	# Bottom-right trap
	if (
		pos.x >= 950.0
		and
		pos.y >= 550.0
	):
		return 2


	# Upper-middle
	if (
		pos.x >= 450.0
		and
		pos.x < 950.0
	):
		return 1


	return 0


# ============================================================
# FIND APPLE
# ============================================================

func find_apple(
	apples: Node,
	apple_name: String
) -> Node2D:

	if apples == null:
		return null

	for child in apples.get_children():

		if child is Node2D:

			if child.name == apple_name:

				return child as Node2D

	return null


# ============================================================
# TARGET APPLE
# ============================================================
#
# 0 = bottom-middle
# 1 = left
# 2 = complete
#
# ============================================================

func get_target_apple(
	apples: Node
) -> int:

	var bottom_apple: Node2D = find_apple(
		apples,
		"Apple2"
	)

	var left_apple: Node2D = find_apple(
		apples,
		"Apple"
	)


	var bottom_collected: bool = false
	var left_collected: bool = false


	if bottom_apple != null:

		bottom_collected = (
			bottom_apple.get("already_collected")
			== true
		)


	if left_apple != null:

		left_collected = (
			left_apple.get("already_collected")
			== true
		)


	# First target
	if not bottom_collected:

		return 0


	# Second target
	if not left_collected:

		return 1


	# Finished
	return 2


# ============================================================
# ROUTE PROGRESS
# ============================================================
#
# 0 = starting route to bottom apple
# 1 = approaching bottom apple
# 2 = bottom apple area
# 3 = bottom apple collected, returning left
# 4 = left platform
# 5 = left apple area
# 6 = both apples
#
# ============================================================

func get_route_progress(
	player: Node2D,
	apples: Node
) -> int:

	var pos: Vector2 = player.global_position

	var target: int = get_target_apple(
		apples
	)


	# --------------------------------------------------------
	# BOTH APPLES
	# --------------------------------------------------------

	if target == 2:

		return 6


	# --------------------------------------------------------
	# TARGET = BOTTOM APPLE
	# --------------------------------------------------------

	if target == 0:

		if get_scene_region(pos) == 3:

			return 2

		if (
			pos.distance_to(
				BOTTOM_APPLE_POSITION
			) < 250.0
		):

			return 1

		return 0


	# --------------------------------------------------------
	# TARGET = LEFT APPLE
	# --------------------------------------------------------

	if target == 1:

		var region: int = get_scene_region(pos)

		if region == 6:

			return 5

		if region == 5:

			return 4

		return 3


	return 0


# ============================================================
# MAIN STATE
# ============================================================

func get_state(
	player: Node2D,
	apples: Node,
	enemies: Node
) -> String:

	var pos: Vector2 = player.global_position


	# ========================================================
	# TARGET
	# ========================================================

	var target: int = get_target_apple(
		apples
	)


	var target_position: Vector2 = pos


	if target == 0:

		target_position = BOTTOM_APPLE_POSITION

	elif target == 1:

		target_position = LEFT_APPLE_POSITION


	# ========================================================
	# SCENE REGION
	# ========================================================

	var scene_region: int = get_scene_region(
		pos
	)


	# ========================================================
	# TARGET DIRECTION
	# ========================================================

	var x_direction: int = get_x_direction(
		pos.x,
		target_position.x
	)

	var y_direction: int = get_y_direction(
		pos,
		target_position
	)


	# ========================================================
	# DISTANCE
	# ========================================================

	var distance_category: int = (
		get_distance_category(
			pos.distance_to(
				target_position
			)
		)
	)


	# ========================================================
	# FLOOR
	# ========================================================

	var on_floor: int = 0

	if player.is_on_floor():

		on_floor = 1


	# ========================================================
	# PLAYER VELOCITY
	# ========================================================

	var vertical_motion: int = 1


	var body: CharacterBody2D = (
		player as CharacterBody2D
	)


	if body != null:

		if body.velocity.y < -60.0:

			vertical_motion = 0

		elif body.velocity.y > 60.0:

			vertical_motion = 2


	# ========================================================
	# LOCAL SENSORS
	# ========================================================

	var ground_ahead: int = (
		get_ground_ahead_sensor(
			player,
			x_direction
		)
	)


	var obstacle_ahead: int = (
		get_obstacle_sensor(
			player,
			x_direction
		)
	)


	# ========================================================
	# SNAIL
	# ========================================================

	var snail_state: int = (
		get_snail_state(
			player,
			enemies
		)
	)


	# ========================================================
	# ROUTE
	# ========================================================

	var route_progress: int = (
		get_route_progress(
			player,
			apples
		)
	)


	# ========================================================
	# BOTTOM-RIGHT DANGER
	# ========================================================

	var bottom_right_danger: int = 0

	if scene_region == 2:

		bottom_right_danger = 1


	# ========================================================
	# COMPACT STATE
	# ========================================================

	return str(
		scene_region, ",",
		target, ",",
		x_direction, ",",
		y_direction, ",",
		distance_category, ",",
		on_floor, ",",
		vertical_motion, ",",
		ground_ahead, ",",
		obstacle_ahead, ",",
		snail_state, ",",
		route_progress, ",",
		bottom_right_danger
	)


# ============================================================
# X DIRECTION
# ============================================================

func get_x_direction(
	player_x: float,
	target_x: float
) -> int:

	if target_x < player_x - 80.0:

		return 0

	elif target_x > player_x + 80.0:

		return 2

	return 1


# ============================================================
# Y DIRECTION
# ============================================================

func get_y_direction(
	player_pos: Vector2,
	target_pos: Vector2
) -> int:

	var difference: float = (
		target_pos.y
		- player_pos.y
	)


	if difference < -60.0:

		return 0

	elif difference > 60.0:

		return 2

	return 1


# ============================================================
# DISTANCE CATEGORY
# ============================================================

func get_distance_category(
	distance: float
) -> int:

	if distance < 100.0:

		return 0

	elif distance < 200.0:

		return 1

	elif distance < 350.0:

		return 2

	elif distance < 500.0:

		return 3

	return 4


# ============================================================
# SNAIL STATE
# ============================================================
#
# 0 = no nearby snail
# 1 = snail facing player
# 2 = snail moving away / back toward player
# 3 = neutral / side
#
# ============================================================

func get_snail_state(
	player: Node2D,
	enemies: Node
) -> int:

	if enemies == null:

		return 0


	var nearest_snail: Node2D = null
	var nearest_distance: float = INF


	for child in enemies.get_children():

		if not child is Node2D:

			continue


		var snail: Node2D = child as Node2D


		var distance: float = (
			player.global_position.distance_to(
				snail.global_position
			)
		)


		if distance < nearest_distance:

			nearest_distance = distance
			nearest_snail = snail


	if nearest_snail == null:

		return 0


	if nearest_distance > 300.0:

		return 0


	var snail_direction_variant = (
		nearest_snail.get("direction")
	)


	if snail_direction_variant == null:

		return 3


	var snail_direction: float = (
		float(snail_direction_variant)
	)


	var player_x: float = (
		player.global_position.x
	)

	var snail_x: float = (
		nearest_snail.global_position.x
	)


	# Player right of snail
	if player_x > snail_x:

		if snail_direction > 0.0:

			return 1

		elif snail_direction < 0.0:

			return 2


	# Player left of snail
	elif player_x < snail_x:

		if snail_direction < 0.0:

			return 1

		elif snail_direction > 0.0:

			return 2


	return 3


# ============================================================
# GROUND AHEAD
# ============================================================

func get_ground_ahead_sensor(
	player: Node2D,
	direction_to_target: int
) -> int:

	var body: CharacterBody2D = (
		player as CharacterBody2D
	)


	if body == null:

		return 1


	var direction: float = 1.0


	if direction_to_target == 0:

		direction = -1.0


	var start: Vector2 = (
		body.global_position
		+ Vector2(
			direction * 80.0,
			25.0
		)
	)


	var end: Vector2 = (
		start
		+ Vector2(
			0.0,
			140.0
		)
	)


	var query: PhysicsRayQueryParameters2D = (
		PhysicsRayQueryParameters2D.create(
			start,
			end
		)
	)


	query.collision_mask = 1

	query.exclude = [
		body.get_rid()
	]


	var result: Dictionary = (
		body.get_world_2d()
		.direct_space_state
		.intersect_ray(query)
	)


	if result.is_empty():

		return 0


	return 1


# ============================================================
# OBSTACLE AHEAD
# ============================================================

func get_obstacle_sensor(
	player: Node2D,
	direction_to_target: int
) -> int:

	var body: CharacterBody2D = (
		player as CharacterBody2D
	)


	if body == null:

		return 0


	var direction: float = 1.0


	if direction_to_target == 0:

		direction = -1.0


	var start: Vector2 = (
		body.global_position
		+ Vector2(
			direction * 20.0,
			15.0
		)
	)


	var end: Vector2 = (
		start
		+ Vector2(
			direction * 80.0,
			0.0
		)
	)


	var query: PhysicsRayQueryParameters2D = (
		PhysicsRayQueryParameters2D.create(
			start,
			end
		)
	)


	query.collision_mask = 1

	query.exclude = [
		body.get_rid()
	]


	var result: Dictionary = (
		body.get_world_2d()
		.direct_space_state
		.intersect_ray(query)
	)


	if result.is_empty():

		return 0


	return 1