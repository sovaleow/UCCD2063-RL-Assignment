extends Area2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 100.0
const FLIP_PERIOD = 2.0
var direction = -1.0
signal player_died

var spawn_position = Vector2.ZERO
var spawn_direction = -1.0
var patrol_elapsed := 0.0
var idle_clock := false


func _ready() -> void:
	spawn_position = position
	spawn_direction = direction
	# RLServer pauses the scene between actions.  The player and collision
	# detection advance on the physics clock, so the snail must use that clock
	# as well; otherwise at high physics rates it may get no render-frame
	# update between two agent actions and appear almost stationary.
	# RL_SNAIL_IDLE=1 keeps the old render-clock behaviour for comparison only.
	idle_clock = OS.get_environment("RL_SNAIL_IDLE") == "1"
	var patrol_timer := get_node_or_null("Timer")
	if idle_clock:
		set_physics_process(false)
		set_process(true)
		if patrol_timer != null:
			patrol_timer.start(FLIP_PERIOD)
	else:
		set_process(false)
		set_physics_process(true)
		if patrol_timer != null:
			patrol_timer.stop()


func _process(delta: float) -> void:
	if idle_clock:
		position.x += direction * SPEED * delta


func _physics_process(delta: float) -> void:
	if idle_clock:
		return
	position.x += direction * SPEED * delta
	patrol_elapsed += delta
	while patrol_elapsed >= FLIP_PERIOD:
		patrol_elapsed -= FLIP_PERIOD
		_on_timer_timeout()


func _on_timer_timeout() -> void:
	direction *= -1
	animated_sprite_2d.flip_h = !animated_sprite_2d.flip_h


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body.alive:
		emit_signal("player_died", body)


func reset():
	position = spawn_position
	direction = spawn_direction
	animated_sprite_2d.flip_h = spawn_direction == -1.0
	if idle_clock:
		var patrol_timer := get_node_or_null("Timer")
		if patrol_timer != null:
			patrol_timer.stop()
			patrol_timer.start(FLIP_PERIOD)
	else:
		patrol_elapsed = 0.0
		if OS.get_environment("RL_RANDOMIZE_PHASE") == "1":
			patrol_elapsed = randf_range(0.0, FLIP_PERIOD)
