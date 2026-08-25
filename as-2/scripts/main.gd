extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_level()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
	
# Connect enemies
func _setup_level() -> void:
	var enemies = $LevelRoot.get_node_or_null("Enemies")
	if enemies:
		for enemy in enemies.get_children():
			if not enemy.player_died.is_connected(_on_player_died):
				enemy.player_died.connect(_on_player_died)

func reset_level() -> void:
	var old_level = $LevelRoot
	var old_index = old_level.get_index()

	# Remove the old level first
	old_level.free()

	# Create a fresh copy of the original level
	var new_level = preload("res://scene/level/level_root.tscn").instantiate()
	new_level.name = "LevelRoot"

	# Add the fresh level
	add_child(new_level)
	move_child(new_level, old_index)

	# Connect the new enemies
	_setup_level()

	print("LEVEL RESET")

# Signal handlers
func _on_player_died(body):
	body.die()
	#print("player die")
