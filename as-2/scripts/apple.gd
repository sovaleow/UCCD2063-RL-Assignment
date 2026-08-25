extends Area2D

signal collected

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collected_sound: AudioStreamPlayer2D = $CollectedSound

var already_collected: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if already_collected:
		return

	if body is CharacterBody2D:
		already_collected = true

		animated_sprite_2d.animation = "collected"
		collected_sound.play()

		# Disable the collision so the apple cannot be collected again
		$CollisionShape2D.set_deferred("disabled", true)

		collected.emit()