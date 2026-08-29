extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $jumpSound
const SPEED = 300.0
const JUMP_VELOCITY = -850.0
var alive = true
var rl_controlled := false
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
		
		# Died from falling off the level (below the visible play area)
	if position.y > 800:
		die()
		return
	
	if not rl_controlled:
		# Handle jump.
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			jump_sound.play()
		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var direction := Input.get_axis("left", "right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		
		# Animation direction 
		if direction == 1.0:
			animated_sprite_2d.flip_h = false
		elif direction == -1.0:
			animated_sprite_2d.flip_h = true
	
	move_and_slide()

func die() -> void:
	death_sound.play()
	animated_sprite_2d.animation = "dying"
	alive = false
	GameState.player_died()

func respawn(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	alive = true
	animated_sprite_2d.animation = "idle"
	
func apply_action(action: int) -> void:
	if not alive:
		return
	rl_controlled = true
	match action:
		GameState.Action.LEFT:
			velocity.x = -SPEED
		GameState.Action.RIGHT:
			velocity.x = SPEED
		GameState.Action.JUMP:
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
		GameState.Action.LEFT_JUMP:
			velocity.x = -SPEED
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
		GameState.Action.RIGHT_JUMP:
			velocity.x = SPEED
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
		_: # NONE
			velocity.x = move_toward(velocity.x, 0, SPEED)
