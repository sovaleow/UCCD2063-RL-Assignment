extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $jumpSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -850.0

# ============================================================
# LEFT APPLE TARGET
# ============================================================

const LEFT_APPLE_TARGET: Vector2 = Vector2(133.0, 549.0)

# ============================================================
# CHECKPOINTS
# ============================================================

const CHECKPOINT_1: Vector2 = Vector2(800.0, 400.0)
const CHECKPOINT_2: Vector2 = Vector2(500.0, 400.0)

const CHECKPOINT_TOLERANCE_X: float = 60.0
const CHECKPOINT_TOLERANCE_Y: float = 80.0

# ============================================================
# CONTROL
# ============================================================

var alive: bool = true
var rl_controlled: bool = false
var rl_action: int = 0

# TRUE = automatic left-apple diagnostic test
# FALSE = normal RL / human control
var left_apple_test_mode: bool = false

# ============================================================
# NAVIGATION
# ============================================================

var navigation_stage: int = 0

# ============================================================
# JUMP
# ============================================================

var jump_cooldown: int = 0

# ============================================================
# DEBUG
# ============================================================

var debug_timer: int = 0


func _physics_process(delta: float) -> void:

	if not alive:
		return

	# ========================================================
	# GRAVITY
	# ========================================================

	if not is_on_floor():
		velocity += get_gravity() * delta


	# ========================================================
	# JUMP COOLDOWN
	# ========================================================

	if jump_cooldown > 0:
		jump_cooldown -= 1


	debug_timer += 1

	var direction: float = 0.0
	var jump_pressed: bool = false


	# ========================================================
	# LEFT APPLE TEST MODE
	# ========================================================

	if left_apple_test_mode:

		# ====================================================
		# STAGE 0
		# ====================================================

		if navigation_stage == 0:

			direction = -1.0

			# Initial jump from starting platform.
			if (
				is_on_floor()
				and jump_cooldown == 0
				and global_position.x > 850.0
			):
				jump_pressed = true

			# Checkpoint 1 reached.
			if (
				abs(global_position.x - CHECKPOINT_1.x)
				<= CHECKPOINT_TOLERANCE_X
				and
				abs(global_position.y - CHECKPOINT_1.y)
				<= CHECKPOINT_TOLERANCE_Y
			):

				navigation_stage = 1

				print(
					"[LEFT ROUTE] CHECKPOINT 1 REACHED"
				)


		# ====================================================
		# STAGE 1
		# ====================================================

		elif navigation_stage == 1:

			direction = -1.0

			# Jump toward the next platform.
			if (
				is_on_floor()
				and jump_cooldown == 0
				and global_position.x <= 650.0
				and global_position.x >= 450.0
			):
				jump_pressed = true

			# Checkpoint 2 reached.
			if (
				abs(global_position.x - CHECKPOINT_2.x)
				<= CHECKPOINT_TOLERANCE_X
				and
				abs(global_position.y - CHECKPOINT_2.y)
				<= CHECKPOINT_TOLERANCE_Y
			):

				navigation_stage = 2

				print(
					"[LEFT ROUTE] CHECKPOINT 2 REACHED"
				)


		# ====================================================
		# STAGE 2
		#
		# Continue moving left.
		#
		# When the player lands on the final platform,
		# move to Stage 3.
		# ====================================================

		elif navigation_stage == 2:

			direction = -1.0

			if (
				is_on_floor()
				and global_position.x <= 430.0
			):

				navigation_stage = 3

				print(
					"[LEFT ROUTE] FINAL PLATFORM LANDED"
				)


		# ====================================================
		# STAGE 3
		#
		# Diagnostic mode:
		#
		# Keep moving LEFT.
		#
		# Whenever the player lands, JUMP again.
		#
		# This intentionally makes the player repeatedly jump
		# through the final area.
		# ====================================================

		elif navigation_stage == 3:

			# Always move toward the left apple.
			direction = -1.0

			# Jump every time we land.
			if (
				is_on_floor()
				and jump_cooldown == 0
			):

				jump_pressed = true

				print(
					"[LEFT ROUTE] "
					+ "JUMP THROUGH FINAL AREA at "
					+ str(global_position)
				)


			# ------------------------------------------------
			# LEFT APPLE TARGET AREA
			# ------------------------------------------------

			if (
				abs(
					global_position.x
					- LEFT_APPLE_TARGET.x
				) <= 45.0
				and
				abs(
					global_position.y
					- LEFT_APPLE_TARGET.y
				) <= 70.0
			):

				direction = 0.0

				print(
					"[LEFT ROUTE] "
					+ "LEFT APPLE TARGET AREA REACHED!"
				)


		# ====================================================
		# DEBUG OUTPUT
		# ====================================================

		if debug_timer >= 15:

			debug_timer = 0

			print(
				"[LEFT ROUTE] "
				+ "Stage="
				+ str(navigation_stage)
				+ " Player=("
				+ str(round(global_position.x))
				+ ", "
				+ str(round(global_position.y))
				+ ")"
				+ " Floor="
				+ str(is_on_floor())
			)


	# ========================================================
	# NORMAL RL MODE
	# ========================================================

	elif rl_controlled:

		match rl_action:

			# 0 = IDLE
			0:
				direction = 0.0

			# 1 = LEFT
			1:
				direction = -1.0

			# 2 = RIGHT
			2:
				direction = 1.0

			# 3 = JUMP
			3:
				direction = 0.0
				jump_pressed = true

			# 4 = LEFT + JUMP
			4:
				direction = -1.0
				jump_pressed = true

			# 5 = RIGHT + JUMP
			5:
				direction = 1.0
				jump_pressed = true

			_:
				direction = 0.0


	# ========================================================
	# HUMAN CONTROL
	# ========================================================

	else:

		if Input.is_action_just_pressed("jump"):
			jump_pressed = true

		direction = Input.get_axis(
			"left",
			"right"
		)


	# ========================================================
	# EXECUTE JUMP
	# ========================================================

	if (
		jump_pressed
		and is_on_floor()
		and jump_cooldown == 0
	):

		velocity.y = JUMP_VELOCITY

		jump_sound.play()

		jump_cooldown = 20

		print(
			"[LEFT ROUTE] JUMP at "
			+ str(global_position)
		)


	# ========================================================
	# HORIZONTAL MOVEMENT
	# ========================================================

	if direction != 0.0:

		velocity.x = direction * SPEED

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
		)


	# ========================================================
	# MOVE
	# ========================================================

	move_and_slide()


	# ========================================================
	# ANIMATION
	# ========================================================

	if not is_on_floor():

		animated_sprite_2d.animation = "jumping"

	elif abs(velocity.x) > 1.0:

		animated_sprite_2d.animation = "running"

	else:

		animated_sprite_2d.animation = "idle"


	# ========================================================
	# FACE DIRECTION
	# ========================================================

	if direction > 0.0:

		animated_sprite_2d.flip_h = false

	elif direction < 0.0:

		animated_sprite_2d.flip_h = true


# ============================================================
# DEATH
# ============================================================

func die() -> void:

	death_sound.play()

	animated_sprite_2d.animation = "dying"

	alive = false

	print(
		"[LEFT ROUTE] PLAYER DIED at "
		+ str(global_position)
	)


# ============================================================
# RL ACTION
# ============================================================

func set_rl_action(action: int) -> void:

	rl_controlled = true

	if action < 0 or action > 5:

		rl_action = 0

	else:

		rl_action = action