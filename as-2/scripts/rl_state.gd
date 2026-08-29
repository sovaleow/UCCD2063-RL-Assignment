extends Node

# ============================================================
# SARSA ADVANCED STATE
# ============================================================
#
# Designed for the ADVANCED level:
#
# - 3 apples
# - Multiple platforms
# - Multiple routes
# - 3 snails
# - Gaps / vertical navigation
#
# This remains a compact state representation for TABULAR SARSA.
#
# STATE:
# 0  apple_collection_mask
# 1  target_dx
# 2  target_dy
# 3  on_floor
# 4  vertical_motion
# 5  wall_low
# 6  wall_high
# 7  snail_relation
# 8  snail_distance
# 9  danger_zone
#
# apple_collection_mask:
#
#   0 = none collected
#   1 = apple 1 collected
#   2 = apple 2 collected
#   3 = apple 1 + apple 2
#   4 = apple 3 collected
#   5 = apple 1 + apple 3
#   6 = apple 2 + apple 3
#   7 = all 3 collected
#
# ============================================================


# ------------------------------------------------------------
# ADVANCED APPLE POSITIONS
# ------------------------------------------------------------
#
# Based on the current level_root_advanced.tscn:
#
# Apple 1:
# approximately (167, 267)
#
# Apple 2:
# approximately (159, 552)
#
# Apple 3:
# approximately (845, 642)
#
# We use these as fallback positions.
# ------------------------------------------------------------

const APPLE_POSITIONS: Array[Vector2] = [
	Vector2(167.0, 267.0),
	Vector2(159.0, 552.0),
	Vector2(845.0, 642.0)
]


# ------------------------------------------------------------
# GENERAL THRESHOLDS
# ------------------------------------------------------------

const TARGET_X_THRESHOLD := 50.0
const TARGET_Y_THRESHOLD := 50.0

const FLOOR_Y_THRESHOLD := 630.0

const SNAIL_CLOSE_DISTANCE := 80.0
const SNAIL_MEDIUM_DISTANCE := 180.0
const SNAIL_FAR_DISTANCE := 300.0


# ------------------------------------------------------------
# APPLE HELPERS
# ------------------------------------------------------------

func get_all_apples(node: Node) -> Array[Node2D]:

	var result: Array[Node2D] = []

	if node == null:
		return result

	_collect_apples_recursive(node, result)

	return result


func _collect_apples_recursive(
	node: Node,
	result: Array[Node2D]
) -> void:

	for child in node.get_children():

		# Apple scene instances are Node2D.
		# Only accept nodes that expose already_collected.
		if child is Node2D:

			var collected_value: Variant = (
				child.get("already_collected")
			)

			if collected_value != null:
				result.append(child as Node2D)

		# Search recursively because the advanced scene
		# currently contains nested Apple nodes.
		_collect_apples_recursive(
			child,
			result
		)


func is_collected(
	apple: Node2D
) -> bool:

	if apple == null:
		return false

	var value: Variant = (
		apple.get("already_collected")
	)

	if value == null:
		return false

	return bool(value)


# ------------------------------------------------------------
# GET APPLE COLLECTION MASK
# ------------------------------------------------------------

func get_apple_collection_mask(
	apples: Node
) -> int:

	var apple_nodes: Array[Node2D] = (
		get_all_apples(apples)
	)

	var mask := 0

	for i in range(
		min(
			3,
			apple_nodes.size()
		)
	):

		if is_collected(apple_nodes[i]):

			mask |= (
				1 << i
			)

	return mask


# ------------------------------------------------------------
# COUNT COLLECTED APPLES
# ------------------------------------------------------------

func get_collected_apple_count(
	apples: Node
) -> int:

	var mask: int = (
		get_apple_collection_mask(apples)
	)

	var count := 0

	for i in range(3):

		if (mask & (1 << i)) != 0:
			count += 1

	return count


# ------------------------------------------------------------
# NEXT APPLE TARGET
# ------------------------------------------------------------
#
# Select the nearest UNCOLLECTED apple.
#
# This makes the advanced environment less route-dependent
# and allows the agent to navigate the more complex layout.
# ------------------------------------------------------------

func get_next_apple_target(
	player: CharacterBody2D,
	apples: Node
) -> Vector2:

	var apple_nodes: Array[Node2D] = (
		get_all_apples(apples)
	)

	var nearest_target: Vector2 = (
		player.global_position
	)

	var nearest_distance: float = INF

	var found_target := false

	# First use actual apple positions from the scene.
	for apple in apple_nodes:

		if is_collected(apple):
			continue

		var distance: float = (
			player.global_position.distance_to(
				apple.global_position
			)
		)

		if distance < nearest_distance:

			nearest_distance = distance

			nearest_target = (
				apple.global_position
			)

			found_target = true

	# Fallback to the fixed positions if necessary.
	if not found_target:

		for apple_position in APPLE_POSITIONS:

			var distance: float = (
				player.global_position.distance_to(
					apple_position
				)
			)

			if distance < nearest_distance:

				nearest_distance = distance
				nearest_target = apple_position

				found_target = true

	return nearest_target


# ------------------------------------------------------------
# ROUTE / PROGRESS STAGE
# ------------------------------------------------------------
#
# Instead of assuming a fixed platform route, stage is based
# primarily on how many apples have been collected.
#
# 0 = no apples
# 1 = one apple
# 2 = two apples
# 3 = all apples
# ------------------------------------------------------------

func get_route_stage(
	player: CharacterBody2D,
	apples: Node
) -> int:

	var collected: int = (
		get_collected_apple_count(apples)
	)

	return collected


# ------------------------------------------------------------
# TARGET POSITION
# ------------------------------------------------------------

func get_target_position(
	player: CharacterBody2D,
	apples: Node
) -> Vector2:

	var mask: int = (
		get_apple_collection_mask(apples)
	)

	# All apples collected.
	if mask == 7:

		return (
			player.global_position
		)

	# Otherwise target the nearest uncollected apple.
	return get_next_apple_target(
		player,
		apples
	)


# ------------------------------------------------------------
# MAIN STATE
# ------------------------------------------------------------

func get_state(
	player: CharacterBody2D,
	apples: Node,
	enemies: Node
) -> String:

	var apple_mask: int = (
		get_apple_collection_mask(apples)
	)

	var target: Vector2 = (
		get_target_position(
			player,
			apples
		)
	)

	var pos: Vector2 = (
		Vector2(player.global_position)
	)


	# --------------------------------------------------------
	# TARGET DIRECTION
	# --------------------------------------------------------

	var target_dx: int = (
		get_x_direction(
			pos.x,
			target.x
		)
	)

	var target_dy: int = (
		get_y_direction(
			pos,
			target
		)
	)


	# --------------------------------------------------------
	# PLAYER GROUND STATE
	# --------------------------------------------------------

	var on_floor: int = (
		1
		if player.is_on_floor()
		else 0
	)


	# --------------------------------------------------------
	# VERTICAL MOVEMENT
	# --------------------------------------------------------

	var vertical_motion: int = (
		get_vertical_motion(
			player
		)
	)


	# --------------------------------------------------------
	# WALL SENSORS
	# --------------------------------------------------------

	var wall_low: int = (
		get_wall_sensor(
			player,
			target_dx,
			12.0
		)
	)

	var wall_high: int = (
		get_wall_sensor(
			player,
			target_dx,
			-28.0
		)
	)


	# --------------------------------------------------------
	# SNAIL
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# DANGER
	# --------------------------------------------------------

	var danger_zone: int = (
		get_danger_zone(
			pos
		)
	)


	# --------------------------------------------------------
	# RETURN STATE
	# --------------------------------------------------------

	return str(
		apple_mask, ",",
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
# X DIRECTION
# ------------------------------------------------------------

func get_x_direction(
	player_x: float,
	target_x: float
) -> int:

	if target_x < player_x - TARGET_X_THRESHOLD:
		return -1

	if target_x > player_x + TARGET_X_THRESHOLD:
		return 1

	return 0


# ------------------------------------------------------------
# Y DIRECTION
# ------------------------------------------------------------

func get_y_direction(
	player_pos: Vector2,
	target_pos: Vector2
) -> int:

	var dy: float = (
		target_pos.y
		- player_pos.y
	)

	if dy < -TARGET_Y_THRESHOLD:
		return -1

	if dy > TARGET_Y_THRESHOLD:
		return 1

	return 0


# ------------------------------------------------------------
# VERTICAL MOTION
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
# WALL SENSOR DIRECTION
# ------------------------------------------------------------

func get_sensor_direction(
	target_dx: int
) -> float:

	if target_dx < 0:
		return -1.0

	return 1.0


# ------------------------------------------------------------
# WALL SENSOR
# ------------------------------------------------------------

func get_wall_sensor(
	player: CharacterBody2D,
	target_dx: int,
	y_offset: float
) -> int:

	var direction: float = (
		get_sensor_direction(
			target_dx
		)
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
# FIND NEAREST SNAIL
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


# ------------------------------------------------------------
# SNAIL DISTANCE CATEGORY
# ------------------------------------------------------------

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

	if distance < SNAIL_CLOSE_DISTANCE:
		return 1

	if distance < SNAIL_MEDIUM_DISTANCE:
		return 2

	if distance < SNAIL_FAR_DISTANCE:
		return 3

	return 0


# ------------------------------------------------------------
# SNAIL RELATION
# ------------------------------------------------------------
#
# 0 = no useful snail information
# 1 = snail facing player
# 2 = snail facing away
# 3 = very close / uncertain
# ------------------------------------------------------------

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


	# Player is to the right of snail.
	if dx > 20.0:

		if snail_direction > 0.0:
			return 1

		return 2


	# Player is to the left of snail.
	if snail_direction < 0.0:
		return 1

	return 2


# ------------------------------------------------------------
# DANGER ZONES
# ------------------------------------------------------------
#
# These are intentionally simple.
#
# 0 = safe
# 1 = bottom-left warning
# 2 = bottom-left trap
# 3 = bottom-right warning
# 4 = bottom-right trap
#
# The advanced map can use these areas to discourage the
# agent from wasting time at the corners.
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
