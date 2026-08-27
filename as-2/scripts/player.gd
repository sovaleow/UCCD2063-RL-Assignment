extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $jumpSound


const SPEED = 300.0
const JUMP_VELOCITY = -850.0
var alive = true
var rl_controlled: bool = false
var rl_action: int = 0
@onready var death_sound: AudioStreamPlayer2D = $DeathSound

func _physics_process(delta: float) -> void:
	
	if !alive:
		return
		
	# Add animation 
	if velocity.x > 1 or velocity.x < -1:
		animated_sprite_2d.animation = "running"
	else:
		animated_sprite_2d.animation = "idle"		
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.animation = "jumping"

	# Handle jump and movement
	var direction := 0.0
	var jump_pressed := false

	if rl_controlled:
		# RL action mapping
		match rl_action:
			0:
				# Idle
				direction = 0.0

			1:
				# Left
				direction = -1.0

			2:
				# Right
				direction = 1.0

			3:
				# Jump
				jump_pressed = true

			4:
				# Left + jump
				direction = -1.0
				jump_pressed = true

			5:
				# Right + jump
				direction = 1.0
				jump_pressed = true

	else:
		# Human keyboard control
		if Input.is_action_just_pressed("jump"):
			jump_pressed = true

		direction = Input.get_axis("left", "right")


	# Perform jump
	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()


	# Perform horizontal movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	# Animation direction 
	if direction == 1.0:
		animated_sprite_2d.flip_h = false
	elif direction == -1.0:
		animated_sprite_2d.flip_h = true
		
func die() -> void:
	death_sound.play()
	animated_sprite_2d.animation = "dying"
	alive = false
	
func set_rl_action(action: int) -> void:
	rl_controlled = true
	rl_action = action
		
