extends Area2D

signal player_died

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var speed: float = 100.0

# Distance checked in front of the snail for an outer wall.
@export var wall_check_distance: float = 28.0

# Distance checked downward from the snail's front foot.
@export var floor_check_distance: float = 24.0

# How far downward we search for the platform.
@export var floor_check_depth: float = 50.0

# World limits for the 1280x720 level.
# These are a final safety net only; platform edge detection
# should normally turn the snail first.
const WORLD_LEFT := 32.0
const WORLD_RIGHT := 1248.0

const PLATFORM_COLLISION_MASK := 1

var direction: float = -1.0
var starting_direction: float = -1.0

# Prevents a stale overlap from killing the player immediately
# after an RL reset.
var collision_active: bool = true
var reset_cooldown: float = 0.0


func _ready() -> void:
	starting_direction = direction
	monitoring = true
	monitorable = true
	collision_mask = PLATFORM_COLLISION_MASK
	_update_facing()


func _physics_process(delta: float) -> void:

	# After a reset, wait until at least one physics update has
	# refreshed the Area2D overlap state.
	if reset_cooldown > 0.0:
		reset_cooldown -= delta

		if reset_cooldown <= 0.0:
			collision_active = true
			monitoring = true

		return


	if not collision_active:
		return


	# --------------------------------------------------------
	# REAL PLAYER OVERLAP CHECK
	# --------------------------------------------------------
	# Only check the player while collision is active.
	for body in get_overlapping_bodies():

		if _is_player(body):
			_kill_player(body)
			return


	# --------------------------------------------------------
	# TURN BEFORE WALL / EDGE
	# --------------------------------------------------------

	if _should_turn():
		_turn_around()


	# --------------------------------------------------------
	# MOVE
	# --------------------------------------------------------

	var old_x := global_position.x

	position.x += direction * speed * delta


	# --------------------------------------------------------
	# HARD WORLD BOUNDS
	# --------------------------------------------------------

	if global_position.x < WORLD_LEFT:
		global_position.x = WORLD_LEFT
		direction = 1.0
		_update_facing()

	elif global_position.x > WORLD_RIGHT:
		global_position.x = WORLD_RIGHT
		direction = -1.0
		_update_facing()


	# Prevent tiny numerical overshoot.
	if abs(global_position.x - old_x) > speed * delta + 0.5:
		global_position.x = old_x


func _is_player(body: Node2D) -> bool:
	if body == null:
		return false

	if body.name != "Player":
		return false

	if not body.has_method("die"):
		return false

	var alive_value: Variant = body.get("alive")

	if alive_value == null:
		return false

	return bool(alive_value)


func _kill_player(body: Node2D) -> void:

	if not collision_active:
		return

	collision_active = false

	# We may be inside body_entered(), so monitoring must be
	# changed deferred to avoid "Function blocked during in/out signal".
	set_deferred("monitoring", false)

	# Kill the actual player.
	body.die()

	# Notify the RL environment.
	player_died.emit(body)

	print(
		"[SNAIL] PLAYER HIT -> PLAYER DIED at "
		+ str(body.global_position)
	)


func _should_turn() -> bool:

	var space_state := get_world_2d().direct_space_state

	# --------------------------------------------------------
	# 1. PLATFORM UNDER THE FRONT OF THE SNAIL
	# --------------------------------------------------------

	var front_x := (
		global_position.x
		+ direction * floor_check_distance
	)

	var floor_start := Vector2(
		front_x,
		global_position.y + 10.0
	)

	var floor_end := Vector2(
		front_x,
		global_position.y + 10.0 + floor_check_depth
	)

	var floor_query := PhysicsRayQueryParameters2D.create(
		floor_start,
		floor_end
	)

	floor_query.collision_mask = PLATFORM_COLLISION_MASK
	floor_query.exclude = [get_rid()]

	var floor_hit := space_state.intersect_ray(
		floor_query
	)

	if floor_hit.is_empty():
		return true


	# --------------------------------------------------------
	# 2. WALL DIRECTLY AHEAD
	# --------------------------------------------------------

	var wall_start := Vector2(
		global_position.x,
		global_position.y
	)

	var wall_end := Vector2(
		global_position.x
		+ direction * wall_check_distance,
		global_position.y
	)

	var wall_query := PhysicsRayQueryParameters2D.create(
		wall_start,
		wall_end
	)

	wall_query.collision_mask = PLATFORM_COLLISION_MASK
	wall_query.exclude = [get_rid()]

	var wall_hit := space_state.intersect_ray(
		wall_query
	)

	if not wall_hit.is_empty():
		return true


	return false


func _turn_around() -> void:
	direction *= -1.0
	_update_facing()


func _update_facing() -> void:

	if animated_sprite_2d != null:
		animated_sprite_2d.flip_h = (
			direction > 0.0
		)


func reset_enemy() -> void:

	# Disable collision during the reset frame so stale
	# Area2D overlap information cannot kill the player.
	collision_active = false
	set_deferred("monitoring", false)

	direction = starting_direction
	reset_cooldown = 0.10

	set_process(true)
	set_physics_process(true)

	_update_facing()


func _on_body_entered(body: Node2D) -> void:

	# Ignore signal callbacks during the reset cooldown.
	if reset_cooldown > 0.0:
		return

	if _is_player(body):
		_kill_player(body)


func _on_timer_timeout() -> void:
	# Kept for compatibility with the existing Timer connection.
	# Snails now turn based on platform/wall detection.
	pass
