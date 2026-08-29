extends Area2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

const SPEED := 100.0

var direction := -1.0
var _initial_direction := -1.0

signal player_died


func _ready() -> void:
	_initial_direction = direction
	_update_sprite()


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta


func _on_timer_timeout() -> void:
	direction *= -1.0
	_update_sprite()


func _update_sprite() -> void:
	animated_sprite_2d.flip_h = direction > 0.0


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.alive:
		emit_signal("player_died", body)


func reset_enemy(spawn_position: Vector2) -> void:
	position = spawn_position
	direction = _initial_direction
	
	# Reset the timer so every RL episode starts with
	# the same enemy movement timing.
	if timer:
		timer.stop()
		timer.start()
	
	_update_sprite()
	
func get_velocity_x() -> float:
	return direction * SPEED
