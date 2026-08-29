
extends Node

const TARGET_THRESHOLD := 45.0
const SNAIL_CLOSE := 85.0
const SNAIL_MEDIUM := 200.0
const SAME_Y_THRESHOLD := 55.0
const WALL_CHECK_DISTANCE := 75.0

var previous_snail_id: int = 0
var previous_snail_distance: float = -1.0
var snail_approach_state: int = 0


func reset_tracking() -> void:
	previous_snail_id = 0
	previous_snail_distance = -1.0
	snail_approach_state = 0


func get_ordered_apples(apples: Node) -> Array:
	var result: Array = []

	if apples == null:
		return result

	_collect_apples(apples, result)

	return result


func _collect_apples(node: Node, result: Array) -> void:
	for child in node.get_children():
		if child is Node2D and child.has_method("reset_apple"):
			result.append(child)

		_collect_apples(child, result)


func is_collected(apple: Node2D) -> bool:
	if apple == null:
		return false

	var value: Variant = apple.get("already_collected")

	if value == null:
		return false

	return bool(value)


func get_apple_collection_mask(apples: Node) -> int:
	var ordered: Array = get_ordered_apples(apples)
	var mask: int = 0

	for i in range(min(3, ordered.size())):
		var apple: Node2D = ordered[i]

		if not is_collected(apple):
			continue

		mask |= 1 << i

	return mask


func get_collected_apple_count(apples: Node) -> int:
	var ordered: Array = get_ordered_apples(apples)
	var count: int = 0

	for i in range(min(3, ordered.size())):
		if is_collected(ordered[i]):
			count += 1

	return count


func get_route_stage(
	_player: CharacterBody2D,
	apples: Node
) -> int:

	return get_collected_apple_count(apples)

func get_target_position(
	player: CharacterBody2D,
	apples: Node
) -> Vector2:

	var ordered: Array = get_ordered_apples(apples)

	var nearest: Node2D = null
	var nearest_distance: float = INF

	for apple in ordered:

		if apple == null:
			continue

		if is_collected(apple):
			continue

		var distance: float = (
			player.global_position.distance_to(
				apple.global_position
			)
		)

		if distance < nearest_distance:

			nearest_distance = distance
			nearest = apple

	if nearest != null:
		return nearest.global_position

	return player.global_position

func get_target_x_direction(
	player: CharacterBody2D,
	target: Vector2
) -> int:
	var dx: float = target.x - player.global_position.x

	if dx < -TARGET_THRESHOLD:
		return -1
	if dx > TARGET_THRESHOLD:
		return 1

	return 0


func get_target_y_direction(
	player: CharacterBody2D,
	target: Vector2
) -> int:
	var dy: float = target.y - player.global_position.y

	if dy < -TARGET_THRESHOLD:
		return -1
	if dy > TARGET_THRESHOLD:
		return 1

	return 0


func get_target_distance(
	player: CharacterBody2D,
	target: Vector2
) -> int:
	var distance: float = player.global_position.distance_to(target)

	if distance < 120.0:
		return 0
	if distance < 300.0:
		return 1

	return 2


func _wall_ray(
	player: CharacterBody2D,
	direction: float,
	y_offset: float
) -> bool:
	var start: Vector2 = (
		player.global_position
		+ Vector2(direction * 15.0, y_offset)
	)

	var end: Vector2 = (
		start
		+ Vector2(direction * WALL_CHECK_DISTANCE, 0.0)
	)

	var query := PhysicsRayQueryParameters2D.create(
		start,
		end
	)

	query.collision_mask = 1
	query.exclude = [player.get_rid()]

	var result: Dictionary = (
		player
		.get_world_2d()
		.direct_space_state
		.intersect_ray(query)
	)

	return not result.is_empty()


func get_wall_low(player: CharacterBody2D) -> int:
	var direction: float = (
		1.0 if player.velocity.x >= 0.0 else -1.0
	)

	return int(
		_wall_ray(player, direction, 8.0)
	)


func get_wall_high(player: CharacterBody2D) -> int:
	var direction: float = (
		1.0 if player.velocity.x >= 0.0 else -1.0
	)

	return int(
		_wall_ray(player, direction, -32.0)
	)


func get_vertical_motion(player: CharacterBody2D) -> int:
	if player.velocity.y < -60.0:
		return 0
	if player.velocity.y > 60.0:
		return 2

	return 1


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

		var snail: Node2D = child as Node2D
		var distance: float = player.global_position.distance_to(
			snail.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = snail

	return nearest


func update_snail_tracking(
	player: CharacterBody2D,
	enemies: Node
) -> void:
	var snail: Node2D = get_nearest_snail(player, enemies)

	if snail == null:
		previous_snail_id = 0
		previous_snail_distance = -1.0
		snail_approach_state = 0
		return

	var snail_id: int = snail.get_instance_id()
	var current_distance: float = (
		player.global_position.distance_to(
			snail.global_position
		)
	)

	if (
		snail_id != previous_snail_id
		or previous_snail_distance < 0.0
	):
		snail_approach_state = 0
	else:
		var change: float = (
			current_distance
			- previous_snail_distance
		)

		if change < -5.0:
			snail_approach_state = 1
		elif change > 5.0:
			snail_approach_state = 2
		else:
			snail_approach_state = 3

	previous_snail_id = snail_id
	previous_snail_distance = current_distance


func get_snail_approach_state(
	_player: CharacterBody2D,
	_enemies: Node
) -> int:
	return snail_approach_state


func get_snail_relative_x(
	player: CharacterBody2D,
	enemies: Node
) -> int:
	var snail: Node2D = get_nearest_snail(player, enemies)

	if snail == null:
		return 0

	var dx: float = snail.global_position.x - player.global_position.x

	if dx < -200.0:
		return 0
	if dx < -50.0:
		return 1
	if dx > 200.0:
		return 4
	if dx > 50.0:
		return 3

	return 2


func get_snail_relative_y(
	player: CharacterBody2D,
	enemies: Node
) -> int:
	var snail: Node2D = get_nearest_snail(player, enemies)

	if snail == null:
		return 0

	var dy: float = snail.global_position.y - player.global_position.y

	if dy < -120.0:
		return 0
	if dy < -SAME_Y_THRESHOLD:
		return 1
	if dy > 120.0:
		return 4
	if dy > SAME_Y_THRESHOLD:
		return 3

	return 2


func get_snail_same_y(
	player: CharacterBody2D,
	enemies: Node
) -> int:
	var snail: Node2D = get_nearest_snail(player, enemies)

	if snail == null:
		return 0

	return int(
		absf(
			snail.global_position.y
			- player.global_position.y
		) <= SAME_Y_THRESHOLD
	)


func get_snail_distance(
	player: CharacterBody2D,
	enemies: Node
) -> int:
	var snail: Node2D = get_nearest_snail(player, enemies)

	if snail == null:
		return 0

	var distance: float = player.global_position.distance_to(
		snail.global_position
	)

	if distance <= SNAIL_CLOSE:
		return 1
	if distance <= SNAIL_MEDIUM:
		return 2

	return 3


func get_danger_zone(pos: Vector2) -> int:
	return int(
		pos.x >= 950.0
		and pos.y >= 580.0
	)


func get_state(
	player: CharacterBody2D,
	apples: Node,
	enemies: Node
) -> String:
	var target: Vector2 = get_target_position(
		player,
		apples
	)

	var stage: int = get_route_stage(
		player,
		apples
	)

	var target_x: int = get_target_x_direction(
		player,
		target
	)

	var target_y: int = get_target_y_direction(
		player,
		target
	)

	var target_distance: int = get_target_distance(
		player,
		target
	)

	var wall_low: int = get_wall_low(player)
	var wall_high: int = get_wall_high(player)

	var snail_x: int = get_snail_relative_x(
		player,
		enemies
	)

	var snail_y: int = get_snail_relative_y(
		player,
		enemies
	)

	var snail_same_y: int = get_snail_same_y(
		player,
		enemies
	)

	var snail_distance: int = get_snail_distance(
		player,
		enemies
	)

	var ground: int = int(player.is_on_floor())
	var vertical: int = get_vertical_motion(player)
	var danger: int = get_danger_zone(player.global_position)

	return str(
		stage, ",",
		target_x, ",",
		target_y, ",",
		target_distance, ",",
		wall_low, ",",
		wall_high, ",",
		snail_x, ",",
		snail_y, ",",
		snail_same_y, ",",
		snail_distance, ",",
		snail_approach_state, ",",
		ground, ",",
		vertical, ",",
		danger
	)
