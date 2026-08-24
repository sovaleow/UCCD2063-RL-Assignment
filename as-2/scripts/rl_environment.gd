extends Node

var score: int = 0
var episode_done: bool = false

@onready var player = $"../LevelRoot/Player"
@onready var enemies = $"../LevelRoot/Enemies"
@onready var apples = $"../LevelRoot/Apple"


func _ready() -> void:
	print("RL Environment STARTED")
	print("Player position: ", player.position)


func reset() -> void:
	score = 0
	episode_done = false

	print("Environment reset")


func step(action: int) -> Dictionary:
	if episode_done:
		return {
			"state": get_state(),
			"reward": 0.0,
			"done": true,
			"score": score
		}

	# Send action to the player
	player.set_rl_action(action)

	# For now we give a small default reward
	var reward := 0.0

	return {
		"state": get_state(),
		"reward": reward,
		"done": episode_done,
		"score": score
	}


func get_state() -> Dictionary:
	return {
		"player_x": player.position.x,
		"player_y": player.position.y,
		"alive": player.alive
	}


func get_score() -> int:
	return score


func is_done() -> bool:
	return episode_done
	
func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_1):
		print("KEY 1 DETECTED")
		step(1)

	if Input.is_key_pressed(KEY_2):
		print("KEY 2 DETECTED")
		step(2)

	if Input.is_key_pressed(KEY_3):
		print("KEY 3 DETECTED")
		step(3)

	if Input.is_key_pressed(KEY_4):
		print("KEY 4 DETECTED")
		step(4)

	if Input.is_key_pressed(KEY_5):
		print("KEY 5 DETECTED")
		step(5)
	if Input.is_key_pressed(KEY_1):
		step(1)

	if Input.is_key_pressed(KEY_2):
		step(2)

	if Input.is_key_pressed(KEY_3):
		step(3)

	if Input.is_key_pressed(KEY_4):
		step(4)

	if Input.is_key_pressed(KEY_5):
		step(5)
