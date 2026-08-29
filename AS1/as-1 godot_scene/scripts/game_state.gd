extends Node
## Tracks episode-level state: score, apples remaining, done/won.

signal episode_ended(won: bool)

enum Action { NONE, LEFT, RIGHT, JUMP, LEFT_JUMP, RIGHT_JUMP }

var score: int = 0
var apples_total: int = 0
var apples_collected: int = 0
var done: bool = false 
var won: bool = false

func register_apples(count: int) -> void:
	apples_total = count
	apples_collected = 0

func collect_apple() -> void:
	if done:
		return
	score += 1
	apples_collected += 1
	if apples_collected >= apples_total and apples_total > 0:
		_end_episode(true)

func player_died() -> void:
	if done:
		return
	_end_episode(false)

func _end_episode(did_win: bool) -> void:
	done = true
	won = did_win
	episode_ended.emit(did_win)

func reset() -> void:
	score = 0
	apples_collected = 0
	done = false
	won = false

# Returns a 12-dimensional state vector:
# [x, y, vel_x, vel_y, on_floor, apple_dx, apple_dy, enemy_dx, enemy_dy, enemy_vx, apples_collected, apples_total]
# dx/dy are signed (target - player), so the agent gets direction, not just distance.
# enemy_vx is the nearest enemy's current x-velocity, so the agent can anticipate its motion
# instead of only seeing a single-frame snapshot of its position.
func get_state(player: Node2D, apples_parent: Node2D, enemies_parent: Node2D) -> Array:
	var state := []
	if player == null:
		push_error("GameState.get_state() received a null player")
		return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, float(apples_collected), float(apples_total)]

	state.append(player.position.x)
	state.append(player.position.y)
	state.append(player.velocity.x)
	state.append(player.velocity.y)
	state.append(1.0 if player.is_on_floor() else 0.0)

	var nearest_apple_dist := -1.0
	var apple_dx := 0.0
	var apple_dy := 0.0
	if apples_parent:
		for apple in apples_parent.get_children():
			if "collected" in apple and apple.collected:
				continue
			var apple_d = player.position.distance_to(apple.position)
			if nearest_apple_dist < 0.0 or apple_d < nearest_apple_dist:
				nearest_apple_dist = apple_d
				apple_dx = apple.position.x - player.position.x
				apple_dy = apple.position.y - player.position.y
	state.append(apple_dx)
	state.append(apple_dy)

	var nearest_enemy_dist := -1.0
	var enemy_dx := 0.0
	var enemy_dy := 0.0
	var enemy_vx := 0.0
	if enemies_parent:
		for enemy in enemies_parent.get_children():
			var enemy_d = player.position.distance_to(enemy.position)
			if nearest_enemy_dist < 0.0 or enemy_d < nearest_enemy_dist:
				nearest_enemy_dist = enemy_d
				enemy_dx = enemy.position.x - player.position.x
				enemy_dy = enemy.position.y - player.position.y
				enemy_vx = enemy.get_velocity_x() if enemy.has_method("get_velocity_x") else 0.0
	state.append(enemy_dx)
	state.append(enemy_dy)
	state.append(enemy_vx)

	state.append(float(apples_collected))
	state.append(float(apples_total))
	return state
