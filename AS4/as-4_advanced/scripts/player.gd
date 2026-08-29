extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $jumpSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound

const SPEED = 300.0
# Preserve the original player jump physics.
const JUMP_VELOCITY = -850.0
var alive = true

# RL control signals — set by main.gd each action
var rl_control = false
var rl_direction = 0.0       # -1=left, 0=keep, 1=right
var rl_jump_pressed = false   # true to trigger jump once


func _physics_process(delta: float) -> void:
	if not alive:
		return

	# Original animation order.
	if velocity.x > 1 or velocity.x < -1:
		animated_sprite_2d.animation = "running"
	else:
		animated_sprite_2d.animation = "idle"

	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.animation = "jumping"

	if rl_control:
		_apply_rl_input()
	else:
		_apply_keyboard_input()

	move_and_slide()

	if velocity.x > 1:
		animated_sprite_2d.flip_h = false
	elif velocity.x < -1:
		animated_sprite_2d.flip_h = true


func _apply_keyboard_input() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()

	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)


func _apply_rl_input() -> void:
	# Jump — fires once then clears
	if rl_jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()
	rl_jump_pressed = false

	# Use the original movement/deceleration behavior for RL control too.
	if rl_direction != 0:
		velocity.x = rl_direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)


func die() -> void:
	if not alive:
		return
	death_sound.play()
	animated_sprite_2d.animation = "dying"
	alive = false


func reset() -> void:
	alive = true
	velocity = Vector2.ZERO
	animated_sprite_2d.animation = "idle"
	animated_sprite_2d.flip_h = false
	rl_direction = 0.0
	rl_jump_pressed = false
