extends Node

# TCP bridge between the Godot game and the Python trainer.
#
# Port can be overridden with the RL_PORT environment variable so several
# Godot instances (windowed play vs headless training) never collide.
#
# While an action is being computed by Python the scene tree is PAUSED, so the
# simulation advances exactly one decision's worth of physics ticks between
# actions no matter how long the round trip takes. This node runs in
# PROCESS_MODE_ALWAYS so it keeps serving sockets while paused.

var port: int = 5000
var server: TCPServer
var peer: StreamPeerTCP = null
var pending: bool = false
# Freeze the sim between actions (deterministic: exactly one 1/60 s game-step
# per decision regardless of Python's reaction time). RL_PAUSE=0 switches to
# continuous simulation instead (faster but jittery per-decision timing).
var pause_between := OS.get_environment("RL_PAUSE") != "0"


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var env_port := OS.get_environment("RL_PORT")
	if env_port != "":
		port = int(env_port)
	server = TCPServer.new()
	var err = server.listen(port)
	if err == OK:
		print("RL Server :", port)
	else:
		print("Listen fail:", err)


func _physics_process(_delta):
	if peer == null:
		if server.is_connection_available():
			peer = server.take_connection()
			peer.set_no_delay(true)  # low-latency step/reply loop
			pending = false
			get_tree().paused = false
			var main = get_parent()
			main.enable_agent_pacing()   # match the pacing used during training
			main.reset()
			main.get_node("LevelRoot/Player").use_agent = true
		return

	# Refresh socket state; without poll() a closed client is never detected
	# and the server deadlocks on a stale peer.
	peer.poll()
	var s = peer.get_status()
	if s != StreamPeerTCP.STATUS_CONNECTED:
		peer = null
		pending = false
		get_tree().paused = false
		return

	var main = get_parent()

	if pending:
		if main.is_step_ready():
			pending = false
			_send(main)
			if pause_between:
				get_tree().paused = true   # freeze sim until the next action
		return

	if peer.get_available_bytes() > 0:
		var msg = peer.get_utf8_string(peer.get_available_bytes())
		var data = JSON.parse_string(msg)
		if data == null or not data.has("action"):
			return
		# NOTE: a {"speed": N} field from the client is intentionally IGNORED.
		# Accelerating the physics clock caused catch-up tick leakage that
		# froze/broke decision timing. Keep engine defaults for now.
		var action = int(data["action"])
		get_tree().paused = false      # resume simulation for this action
		if action == -1:
			main.reset()
			_send(main)
			if pause_between:
				get_tree().paused = true
		else:
			main.step(action)
			pending = true


func _send(main):
	var data = {
		"state": main.get_state(),
		"reward": main.get_reward(),
		"done": main.is_done(),
		"apples": main.get_apples(),
		"reason": main.get_done_reason(),
	}
	peer.put_data(JSON.stringify(data).to_utf8_buffer())
