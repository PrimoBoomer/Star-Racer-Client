extends Node

var socket: WebSocketPeer = null
var opened = false
var timeout_timer = 0

func terminate():
	if self.socket:
		self.socket.close()

func _process(delta: float) -> void:
	if ! self.socket:
		return

	self.socket.poll()
	
	var socket_state = self.socket.get_ready_state()
	
	if socket_state == WebSocketPeer.STATE_CONNECTING:
		self.timeout_timer += delta
		if self.timeout_timer > 3:
			terminate()
	elif socket_state == WebSocketPeer.STATE_CLOSED:
		self.socket = null
		%Game.switch_mode(Game.Mode.WELCOME_PAGE, !(self.timeout_timer > 3))
	elif socket_state == WebSocketPeer.STATE_OPEN:
		if !opened:
			%Game.on_connection()
			opened = true
		while self.socket.get_available_packet_count() > 0:
			var message = JSON.parse_string(self.socket.get_packet().get_string_from_utf8())
			if !%Game.on_server_message(message):
				terminate()

func switch_mode(next_mode: Game.Mode):
	if %Game.mode == Game.Mode.WELCOME_PAGE:
		if next_mode == Game.Mode.FETCH_LOBBIES \
		   || next_mode == Game.Mode.JOINING_LOBBY \
		   || next_mode == Game.Mode.CREATING_LOBBY:
			return %Network.connect_to_server()
	if %Game.mode == Game.Mode.IN_RACE \
	   || %Game.mode == Game.Mode.LOBBY_INTERMISSION:
		if next_mode == Game.Mode.WELCOME_PAGE:
			terminate()
	return true

func connect_to_server() -> bool:
	if self.socket:
		printerr("Can't connect: already connected")
		return false

	var host = ""
	if OS.has_feature("web"):
		host = "wss://" + JavaScriptBridge.eval("window.location.hostname")
	else:
		host = "ws://127.0.0.1:8080"

	self.socket = WebSocketPeer.new()
	self.socket.inbound_buffer_size = 1000000
	self.socket.outbound_buffer_size = 1000000
	self.socket.max_queued_packets = 10000
	
	if socket.connect_to_url(host) != OK:
		printerr("Could not connect")
		return false

	opened = false
	self.timeout_timer = 0
	return true
