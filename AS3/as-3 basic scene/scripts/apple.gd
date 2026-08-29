extends Area2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collected_sound: AudioStreamPlayer2D = $CollectedSound

var collected = false
var spawn_position = Vector2.ZERO


func _ready() -> void:
	spawn_position = position


func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	collected = true
	animated_sprite_2d.animation = "collected"
	collected_sound.play()

func is_collected():
	return collected

func reset():
	collected = false
	position = spawn_position
	animated_sprite_2d.animation = "default"
