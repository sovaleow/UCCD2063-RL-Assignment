extends Node2D

const PLAYER_SPAWN := Vector2(217, 337)

var _apple_scene: PackedScene = preload("res://scene/apple.tscn")
var _apple_positions: Array[Vector2] = []
var _enemy_positions: Array[Vector2] = []
var _apple_parent: Node2D
var _enemy_parent: Node2D

func _ready() -> void:
	_setup_level()

func _setup_level() -> void:
	_enemy_parent = $LevelRoot.get_node_or_null("Enemies")
	if _enemy_parent:
		for enemy in _enemy_parent.get_children():
			if enemy.has_signal("player_died") and not enemy.player_died.is_connected(_on_player_died):
				enemy.player_died.connect(_on_player_died)
			if _enemy_positions.size() < _enemy_parent.get_child_count():
				_enemy_positions.append(enemy.position)

	_apple_parent = $LevelRoot.get_node_or_null("Apple")
	if _apple_parent and _apple_positions.is_empty():
		for apple in _apple_parent.get_children():
			_apple_positions.append(apple.position)

	GameState.register_apples(_apple_positions.size())

func _on_player_died(body) -> void:
	body.die()

func reset_level() -> void:
	var player = $LevelRoot.get_node_or_null("Player")
	if player:
		player.respawn(PLAYER_SPAWN)

	if _enemy_parent:
		for i in range(min(_enemy_positions.size(), _enemy_parent.get_child_count())):
			var enemy = _enemy_parent.get_child(i)
			if enemy.has_method("reset_enemy"):
				enemy.reset_enemy(_enemy_positions[i])
			else:
				enemy.position = _enemy_positions[i]

	if _apple_parent:
		for apple in _apple_parent.get_children():
			apple.queue_free()
		for pos in _apple_positions:
			var new_apple = _apple_scene.instantiate()
			new_apple.position = pos
			_apple_parent.add_child(new_apple)

	GameState.reset()
