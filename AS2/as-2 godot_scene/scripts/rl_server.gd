extends Node

const PORT: int = 8765

var server := TCPServer.new()
var peer: WebSocketPeer
var client_connected: bool = false
var step_in_progress: bool = false

@onready var environment = get_parent()


func _ready() -> void:
	var error = server.listen(PORT)

	if error != OK:
		print("RL SERVER FAILED TO START: ", error)
		return

	print("=== RL SERVER STARTED ON PORT ", PORT, " ===")


func _process(_delta: float) -> void:
	# Accept a new Python connection
	if not client_connected and server.is_connection_available():
		var stream = server.take_connection()

		peer = WebSocketPeer.new()
		var error = peer.accept_stream(stream)

		if error != OK:
			print("RL SERVER: Failed to accept connection")
			peer = null
			return

		client_connected = true
		print("RL CLIENT CONNECTED")

	# Nothing else to do until Python connects
	if not client_connected:
		return

	peer.poll()

	# Check whether the client disconnected
	var state = peer.get_ready_state()

	if state == WebSocketPeer.STATE_CLOSED:
		print("RL CLIENT DISCONNECTED")
		client_connected = false
		peer = null
		return

	# Don't accept another action while the current action is running
	if step_in_progress:
		return

	# Process incoming messages
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		var message = packet.get_string_from_utf8()

		_handle_message(message)


func _handle_message(message: String) -> void:
	var data = JSON.parse_string(message)

	if data == null:
		_send_error("Invalid JSON")
		return

	if not data.has("type"):
		_send_error("Message missing type")
		return

	match data["type"]:
		"reset":
			_handle_reset()

		"step":
			if not data.has("action"):
				_send_error("Step message missing action")
				return

			_handle_step(int(data["action"]))

		_:
			_send_error("Unknown message type: " + str(data["type"]))


func _handle_reset() -> void:
	if step_in_progress:
		_send_error("Cannot reset while step is in progress")
		return

	environment.reset()

	var response = {
		"type": "reset",
		"state": environment.get_state(),
		"reward": 0.0,
		"done": false,
		"score": environment.get_score()
	}

	_send(response)

	print("RL RESET")


func _handle_step(action: int) -> void:
	if action < 0 or action > 5:
		_send_error("Invalid action: " + str(action))
		return

	step_in_progress = true

	var result = await environment.step(action)

	step_in_progress = false

	_send({
		"type": "step",
		"state": result["state"],
		"reward": result["reward"],
		"done": result["done"],
		"score": result["score"]
	})


func _send(data: Dictionary) -> void:
	if peer == null:
		return

	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	peer.send_text(JSON.stringify(data))


func _send_error(message: String) -> void:
	_send({
		"type": "error",
		"message": message
	})
