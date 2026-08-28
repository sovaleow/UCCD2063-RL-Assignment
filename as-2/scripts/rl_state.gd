extends Node


func get_state(player: Node2D, apples: Node, enemies: Node) -> String:
	var player_x_zone = get_x_zone(player.position.x)
	var player_y_zone = get_y_zone(player.position.y)

	var on_ground = 1 if player.is_on_floor() else 0

	var nearest_apple = get_nearest_node(player, apples)
	var nearest_snail = get_nearest_node(player, enemies)

	# Default apple state if no apple is available
	var apple_x_direction = 1
	var apple_y_direction = 1
	var apple_distance = 2

	var snail_x_direction = 1
	var snail_movement_direction = 1

	if nearest_snail != null:
		if nearest_snail.global_position.x < player.global_position.x:
			snail_x_direction = 0
		elif nearest_snail.global_position.x > player.global_position.x:
			snail_x_direction = 2

		if nearest_snail.direction < 0:
			snail_movement_direction = 0
		elif nearest_snail.direction > 0:
			snail_movement_direction = 2

	if nearest_apple != null:
		apple_x_direction = get_direction(
			player.global_position.x,
			nearest_apple.global_position.x
		)

		apple_y_direction = get_vertical_direction(
			player.global_position,
			nearest_apple.global_position
		)

		apple_distance = get_distance_category(
			player.global_position.distance_to(
				nearest_apple.global_position
			)
		)

	var apples_collected = 0

	for apple in apples.get_children():
		if apple.get("already_collected") == true:
			apples_collected += 1

	# Default snail distance
	var snail_distance = 2

	if nearest_snail != null:
		snail_distance = get_distance_category(
			player.global_position.distance_to(
				nearest_snail.global_position
			)
		)

	return str(
		player_x_zone, ",",
		player_y_zone, ",",
		on_ground, ",",
		apple_x_direction, ",",
		apple_y_direction, ",",
		apple_distance, ",",
		snail_x_direction, ",",
		snail_movement_direction, ",",
		snail_distance, ",",
		apples_collected
	)


# --------------------------------------------------
# Player X position
# --------------------------------------------------

func get_x_zone(x: float) -> int:
	if x < 426:
		return 0
	elif x < 852:
		return 1
	else:
		return 2


# --------------------------------------------------
# Player Y position
# --------------------------------------------------

func get_y_zone(y: float) -> int:
	if y < 300:
		return 2
	elif y < 550:
		return 1
	else:
		return 0


# --------------------------------------------------
# Horizontal direction toward another object
# --------------------------------------------------

func get_direction(player_x: float, target_x: float) -> int:
	if target_x < player_x - 100:
		return 0
	elif target_x > player_x + 100:
		return 2
	else:
		return 1


# --------------------------------------------------
# Vertical direction toward another object
# --------------------------------------------------

func get_vertical_direction(player_pos: Vector2, target_pos: Vector2) -> int:
	var vertical_difference = target_pos.y - player_pos.y

	if vertical_difference < -50:
		return 0 # ABOVE
	elif vertical_difference > 50:
		return 2 # BELOW
	else:
		return 1 # SAME LEVEL
# --------------------------------------------------
# Distance category
# --------------------------------------------------

func get_distance_category(distance: float) -> int:
	if distance < 100:
		return 0
	elif distance < 200:
		return 1
	elif distance < 350:
		return 2
	elif distance < 500:
		return 3
	else:
		return 4
# --------------------------------------------------
# Find nearest object
# --------------------------------------------------

func get_nearest_node(player: Node2D, parent_node: Node) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF

	for child in parent_node.get_children():
		if child is Node2D:

			# Ignore apples that have already been collected
			if child.get("already_collected") == true:
				continue

			var distance = player.position.distance_to(child.position)

			if distance < nearest_distance:
				nearest_distance = distance
				nearest = child

	return nearest
