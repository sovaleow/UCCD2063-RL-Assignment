extends CharacterBody2D

enum RLAction {
	IDLE,
	LEFT,
	RIGHT,
	JUMP,
	LEFT_JUMP,
	RIGHT_JUMP
}

var use_agent = false
var current_action = RLAction.IDLE

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $jumpSound

const SPEED = 300.0
const JUMP_VELOCITY = -850.0
var alive = true
var spawn_position = Vector2.ZERO
@onready var death_sound: AudioStreamPlayer2D = $DeathSound


func _ready() -> void:
	spawn_position = position


func set_action(action: int):
	current_action = action


func _physics_process(delta: float) -> void:
	if !alive:
		return

	if velocity.x > 1 or velocity.x < -1:
		animated_sprite_2d.animation = "running"
	else:
		animated_sprite_2d.animation = "idle"

	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.animation = "jumping"

	var jump = false
	if use_agent:
		jump = current_action in [
			RLAction.JUMP,
			RLAction.LEFT_JUMP,
			RLAction.RIGHT_JUMP
		]
	else:
		jump = Input.is_action_just_pressed("jump")
	if jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()

	var direction = 0
	if use_agent:
		match current_action:
			RLAction.LEFT:
				direction = -1
			RLAction.RIGHT:
				direction = 1
			RLAction.LEFT_JUMP:
				direction = -1
			RLAction.RIGHT_JUMP:
				direction = 1
	else:
		direction = Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if direction == 1.0:
		animated_sprite_2d.flip_h = false
	elif direction == -1.0:
		animated_sprite_2d.flip_h = true


func die() -> void:
	death_sound.play()
	animated_sprite_2d.animation = "dying"
	alive = false


func reset():
	position = spawn_position
	velocity = Vector2.ZERO
	alive = true
	animated_sprite_2d.animation = "idle"
