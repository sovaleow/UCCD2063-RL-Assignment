extends Area2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collected_sound: AudioStreamPlayer2D = $CollectedSound

signal apple_collected

var is_collected = false


func _on_body_entered(body: Node2D) -> void:
	animated_sprite_2d.animation = "collected"
	collected_sound.play()
	# Preserve the original gameplay response while reporting only the first
	# collection in an episode to the RL server.
	if is_collected:
		return
	is_collected = true
	emit_signal("apple_collected")


func reset() -> void:
	is_collected = false
	animated_sprite_2d.animation = "default"
