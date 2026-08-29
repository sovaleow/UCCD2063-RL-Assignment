extends Area2D

signal collected

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collected_sound: AudioStreamPlayer2D = $CollectedSound
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var already_collected: bool = false


func _ready() -> void:
	# Always start as a visible, collectible apple.
	reset_apple()


func _process(_delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if already_collected:
		return

	if body is CharacterBody2D:
		already_collected = true

		animated_sprite_2d.play("collected")
		collected_sound.play()

		collision_shape.set_deferred(
			"disabled",
			true
		)

		collected.emit()


# ============================================================
# RESET APPLE
# ============================================================

func reset_apple() -> void:
	already_collected = false

	visible = true
	set_process(true)

	if collision_shape != null:
		collision_shape.set_deferred(
			"disabled",
			false
		)

	if animated_sprite_2d != null:
		animated_sprite_2d.visible = true
		animated_sprite_2d.play("default")
