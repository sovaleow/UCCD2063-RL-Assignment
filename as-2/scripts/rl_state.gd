extends Node


func get_state(player: Node2D, apples: Node, enemies: Node) -> String:
	var player_x_zone = get_x_zone(player.position.x)
	var player_y_zone = get_y_zone(player.position.y)

	var on_ground = 1 if player.is_on_floor() else 0

	var nearest_apple = get_nearest_node(player, apples)
	var nearest_snail = get_nearest_node(player, enemies)

	var apple_direction = 1
	var apple_distance = 2

	if nearest_apple != null:
		apple_direction = get_direction(player.position.x, nearest_apple.position.x)
		apple_distance = get_distance_category(
			player.position.distance_to(nearest_apple.position)
		)

	var snail_distance = 2

	if nearest_snail != null:
		snail_distance = get_distance_category(
			player.position.distance_to(nearest_snail.position)
		)

	return str(
		player_x_zone, ",",
		player_y_zone, ",",
		on_ground, ",",
		apple_direction, ",",
		apple_distance, ",",
		snail_distance
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
# Direction toward another object
# --------------------------------------------------

func get_direction(player_x: float, target_x: float) -> int:
	if target_x < player_x - 100:
		return 0
	elif target_x > player_x + 100:
		return 2
	else:
		return 1


# --------------------------------------------------
# Distance category
# --------------------------------------------------

func get_distance_category(distance: float) -> int:
	if distance < 200:
		return 0
	elif distance < 500:
		return 1
	else:
		return 2


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
