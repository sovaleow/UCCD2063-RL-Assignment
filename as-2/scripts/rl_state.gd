extends Node

# ============================================================
# SARSA V14 - SCENE-AWARE STATE
# ============================================================
#
# ROUTE:
# START
#   -> MIDDLE UPPER PLATFORM
#   -> LEFT SIDE OF MIDDLE PLATFORM
#   -> DESCEND FROM LEFT SIDE
#   -> BOTTOM APPLE
#   -> LEFT PLATFORM
#   -> LEFT APPLE
#   -> SUCCESS
#
# IMPORTANT:
# - Bottom-right corner is a trap and should be avoided.
# - Bottom-left corner is also treated as a trap.
# - After the bottom apple, returning to the middle platform
#   is a bad route.
#
# State is compact because this is TABULAR SARSA.
#
# state:
# 0 route_stage
# 1 target_dx
# 2 target_dy
# 3 on_floor
# 4 vertical_motion
# 5 wall_low
# 6 wall_high
# 7 snail_relation
# 8 snail_distance
# 9 danger_zone
# ============================================================


# ------------------------------------------------------------
# LEVEL COORDINATES
# ------------------------------------------------------------
# These are based on the coordinates already used in the
# current project. Adjust these only when verified against
# the actual scene/collision geometry.
# ------------------------------------------------------------

const MIDDLE_TARGET: Vector2 = Vector2(830.0, 500.0)
const MIDDLE_LEFT_TARGET: Vector2 = Vector2(700.0, 500.0)
const LEFT_DESCENT_TARGET: Vector2 = Vector2(700.0, 620.0)

const BOTTOM_APPLE_POSITION: Vector2 = Vector2(845.0, 642.0)
const LEFT_PLATFORM_TARGET: Vector2 = Vector2(430.0, 550.0)
const LEFT_APPLE_POSITION: Vector2 = Vector2(133.0, 549.0)


# ------------------------------------------------------------
# APPLE HELPERS
# ------------------------------------------------------------

func find_apple(
	apples: Node,
	apple_name: String
) -> Node2D:

	if apples == null:
		return null

	for child in apples.get_children():

		if child is Node2D and child.name == apple_name:
			return child as Node2D

	return null


func is_collected(
	apple: Node2D
) -> bool:

	if apple == null:
		return false

	return apple.get("already_collected") == true


func get_bottom_apple_collected(
	apples: Node
) -> bool:

	return is_collected(
		find_apple(
			apples,
            "Apple2"
		)
	)


func get_left_apple_collected(
	apples: Node
) -> bool:

	return is_collected(
		find_apple(
			apples,
            "Apple"
		)
	)


# ------------------------------------------------------------
# ROUTE STAGE
# ------------------------------------------------------------

func get_route_stage(
	player: CharacterBody2D,
	apples: Node
) -> int:

	var pos: Vector2 = Vector2(
		player.global_position
	)

	var bottom_collected: bool = (
		get_bottom_apple_collected(apples)
	)

	var left_collected: bool = (
		get_left_apple_collected(apples)
	)

	# Both apples collected.
	if bottom_collected and left_collected:
		return 6

	# --------------------------------------------------------
	# BEFORE BOTTOM APPLE
	# --------------------------------------------------------

	if not bottom_collected:

		if is_on_middle_platform(pos):

			# Right / centre side of middle platform.
			if pos.x > 780.0:
				return 1

			# Left side: descend from here.
			return 2

		# Bottom floor before first apple.
		if is_bottom_floor(pos):
			return 3

		# Start / upper area.
		return 0

	# --------------------------------------------------------
	# AFTER BOTTOM APPLE
	# --------------------------------------------------------

	# First objective after Apple 1 is the LEFT PLATFORM.
	if not is_left_platform(player):
		return 4

	# Standing on left platform.
	return 5


# ------------------------------------------------------------
# CURRENT TARGET
# ------------------------------------------------------------

func get_target_position(
	player: CharacterBody2D,
	apples: Node
) -> Vector2:

	var stage: int = get_route_stage(
		player,
		apples
	)

	match stage:

		# START -> MIDDLE UPPER PLATFORM
		0:
			return MIDDLE_TARGET

		# MIDDLE UPPER -> LEFT
		1:
			return MIDDLE_LEFT_TARGET

		# LEFT SIDE -> DESCEND
		2:
			return LEFT_DESCENT_TARGET

		# BOTTOM FLOOR -> BOTTOM APPLE
		3:
			return BOTTOM_APPLE_POSITION

		# BOTTOM APPLE -> LEFT PLATFORM
		4:
			return LEFT_PLATFORM_TARGET

		# LEFT PLATFORM -> LEFT APPLE
		5:
			return LEFT_APPLE_POSITION

		# COMPLETE
		_:
			return Vector2(
				player.global_position
			)


# ------------------------------------------------------------
# MAIN STATE
# ------------------------------------------------------------

func get_state(
	player: CharacterBody2D,
	apples: Node,
	enemies: Node
) -> String:

	var stage: int = get_route_stage(
		player,
		apples
	)

	var target: Vector2 = get_target_position(
		player,
		apples
	)

	var pos: Vector2 = Vector2(
		player.global_position
	)

	var target_dx: int = get_x_direction(
		pos.x,
		target.x
	)

	var target_dy: int = get_y_direction(
		pos,
		target
	)

	var on_floor: int = (
		1 if player.is_on_floor()
		else 0
	)

	var vertical_motion: int = (
		get_vertical_motion(player)
	)

	var wall_low: int = get_wall_sensor(
		player,
		target_dx,
		12.0
	)

	var wall_high: int = get_wall_sensor(
		player,
		target_dx,
		-28.0
	)

	var snail_relation: int = (
		get_snail_relation(
			player,
			enemies
		)
	)

	var snail_distance: int = (
		get_snail_distance_category(
			player,
			enemies
		)
	)

	var danger_zone: int = (
		get_danger_zone(pos)
	)

	return str(
		stage, ",",
		target_dx, ",",
		target_dy, ",",
		on_floor, ",",
		vertical_motion, ",",
		wall_low, ",",
		wall_high, ",",
		snail_relation, ",",
		snail_distance, ",",
		danger_zone
	)


# ------------------------------------------------------------
# DIRECTION
# ------------------------------------------------------------

func get_x_direction(
	player_x: float,
	target_x: float
) -> int:

	if target_x < player_x - 50.0:
		return -1

	if target_x > player_x + 50.0:
		return 1

	return 0


func get_y_direction(
	player_pos: Vector2,
	target_pos: Vector2
) -> int:

	var dy: float = (
		target_pos.y
		- player_pos.y
	)

	if dy < -50.0:
		return -1

	if dy > 50.0:
		return 1

	return 0


# ------------------------------------------------------------
# PLAYER MOTION
# ------------------------------------------------------------

func get_vertical_motion(
	player: CharacterBody2D
) -> int:

	if player.velocity.y < -60.0:
		return 0       # rising

	if player.velocity.y > 60.0:
		return 2       # falling

	return 1           # stable


# ------------------------------------------------------------
# WALL LOW / HIGH
# ------------------------------------------------------------

func get_sensor_direction(
	target_dx: int
) -> float:

	if target_dx < 0:
		return -1.0

	return 1.0


func get_wall_sensor(
	player: CharacterBody2D,
	target_dx: int,
	y_offset: float
) -> int:

	var direction: float = (
		get_sensor_direction(target_dx)
	)

	var start: Vector2 = (
		player.global_position
		+ Vector2(
			direction * 18.0,
			y_offset
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
		player.get_rid()
	]

	var result: Dictionary = (
		player
		.get_world_2d()
		.direct_space_state
		.intersect_ray(query)
	)

	return (
		1
		if not result.is_empty()
		else 0
	)


# ------------------------------------------------------------
# SNAIL
# ------------------------------------------------------------

func get_nearest_snail(
	player: CharacterBody2D,
	enemies: Node
) -> Node2D:

	if enemies == null:
		return null

	var nearest: Node2D = null
	var nearest_distance: float = INF

	for child in enemies.get_children():

		if not child is Node2D:
			continue

		var snail: Node2D = (
			child as Node2D
		)

		var distance: float = (
			player.global_position.distance_to(
				snail.global_position
			)
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = snail

	return nearest


func get_snail_distance_category(
	player: CharacterBody2D,
	enemies: Node
) -> int:

	var snail: Node2D = (
		get_nearest_snail(
			player,
			enemies
		)
	)

	if snail == null:
		return 0

	var distance: float = (
		player.global_position.distance_to(
			snail.global_position
		)
	)

	if distance < 80.0:
		return 1

	if distance < 180.0:
		return 2

	if distance < 300.0:
		return 3

	return 0


func get_snail_relation(
	player: CharacterBody2D,
	enemies: Node
) -> int:

	var snail: Node2D = (
		get_nearest_snail(
			player,
			enemies
		)
	)

	if snail == null:
		return 0

	var dx: float = (
		player.global_position.x
		- snail.global_position.x
	)

	if absf(dx) < 20.0:
		return 3

	var direction_value: Variant = (
		snail.get("direction")
	)

	if direction_value == null:
		return 3

	var snail_direction: float = (
		float(direction_value)
	)

	# Player is right of snail.
	if dx > 20.0:

		if snail_direction > 0.0:
			return 1       # snail facing player

		return 2           # snail back toward player

	# Player is left of snail.
	if snail_direction < 0.0:
		return 1           # snail facing player

	return 2               # snail back toward player


# ------------------------------------------------------------
# DANGER ZONES
# ------------------------------------------------------------

func get_danger_zone(
	pos: Vector2
) -> int:

	# Bottom-left warning.
	if (
		pos.x <= 220.0
		and pos.x > 120.0
		and pos.y >= 630.0
	):
		return 1

	# Bottom-left trap.
	if (
		pos.x <= 120.0
		and pos.y >= 630.0
	):
		return 2

	# Bottom-right warning.
	if (
		pos.x >= 1050.0
		and pos.x < 1120.0
		and pos.y >= 630.0
	):
		return 3

	# Bottom-right trap.
	if (
		pos.x >= 1120.0
		and pos.y >= 630.0
	):
		return 4

	return 0


# ------------------------------------------------------------
# LEVEL GEOMETRY
# ------------------------------------------------------------

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


func is_left_platform(
	player: CharacterBody2D
) -> bool:

	if not player.is_on_floor():
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
