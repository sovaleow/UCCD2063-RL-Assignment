extends Area2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 100.0
var direction = -1.0
var start_position: Vector2

signal player_died


func _ready() -> void:
	start_position = position


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta


func _on_timer_timeout() -> void:
	direction *= -1
	animated_sprite_2d.flip_h = !animated_sprite_2d.flip_h


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.alive:
		emit_signal("player_died", body)


func reset() -> void:
	position = start_position
	direction = -1.0
	animated_sprite_2d.flip_h = false
	$Timer.stop()
	$Timer.start()
