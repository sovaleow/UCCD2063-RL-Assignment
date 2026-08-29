extends Node2D

func _ready() -> void:
	_setup_level()


func _setup_level() -> void:
	var enemies = $LevelRoot.get_node_or_null("Enemies")

	if enemies:
		for enemy in enemies.get_children():
			if enemy.has_signal("player_died"):
				if not enemy.player_died.is_connected(
					_on_player_died
				):
					enemy.player_died.connect(
						_on_player_died
					)


func reset_level() -> void:
	var old_level = $LevelRoot
	var old_index = old_level.get_index()

	old_level.free()

	var new_level = preload(
        "res://scene/level/level_root_advanced.tscn"
	).instantiate()

	new_level.name = "LevelRoot"

	add_child(new_level)
	move_child(new_level, old_index)

	_setup_level()

	print("ADVANCED LEVEL RESET")


func _on_player_died(body):
	body.die()
