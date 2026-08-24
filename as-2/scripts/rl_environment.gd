extends Node

var score: int = 0
var episode_done: bool = false

@onready var state_tracker = $RLState
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
	player.set_rl_action(action)

	var state = get_state()

	print(
		"Action: ",
		action,
		" | State: ",
		state
	)

	return {
		"state": state,
		"reward": 0.0,
		"done": episode_done,
		"score": score
	}

func get_state() -> String:
	return state_tracker.get_state(
		player,
		apples,
		enemies
	)

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
