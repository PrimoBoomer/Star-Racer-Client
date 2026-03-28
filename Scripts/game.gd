extends Node

class_name Game

enum Mode {
	WELCOME_PAGE,
	FETCH_LOBBIES,
	CREATING_LOBBY,
	JOINING_LOBBY,
	LOBBY_INTERMISSION,
	IN_RACE,
}

var modes_strings = {
	Mode.WELCOME_PAGE: "WELCOME PAGE",
	Mode.FETCH_LOBBIES: "FETCHING",
	Mode.CREATING_LOBBY: "CREATING",
	Mode.JOINING_LOBBY: "JOINING",
	Mode.LOBBY_INTERMISSION: "INTERMISSION",
	Mode.IN_RACE: "RACING",
}

@export var debug = false
@export var MIN_LIMIT_PLAYERS := 1
@export var MAX_LIMIT_PLAYERS := 6
@export var MIN_PLAYERS_DEFAULT = 2
@export var MAX_PLAYERS_DEFAULT = 4
@export var COLOR_DEFAULT = [1.0, 1.0, 1.0]
@export var tracks = [
	["circuit_one", "Circuit One"],
]

@onready var player_scene: PackedScene = load("res://Scenes/player.tscn")
@onready var opponent_scene: PackedScene = load("res://Scenes/opponent.tscn")

var mode = Mode.WELCOME_PAGE
var track_node: Node3D = null
var car_node: Node3D = null
var paused = false

var regex = RegEx.new()

func _init():
	regex.compile("^[A-Za-z][A-Za-z0-9_]*$")

func _ready() -> void:
	load_settings()
	switch_mode(Mode.FETCH_LOBBIES, false)


func _process(_delta):
	if mode == Mode.IN_RACE:
		if Input.is_action_just_released("pause"):
			%UI.get_play_menu_panel().visible = !%UI.get_play_menu_panel().visible
			self.paused = ! self.paused

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()
		get_tree().quit()

func check_min_players(value: int) -> bool:
	return value >= MIN_LIMIT_PLAYERS and value <= MAX_LIMIT_PLAYERS && value <= %UI.get_max_players()

func check_max_players(value: int) -> bool:
	return value >= MIN_LIMIT_PLAYERS and value <= MAX_LIMIT_PLAYERS and value >= %UI.get_min_players()

func check_lobby_name(lobby_name: String) -> bool:
	return is_valid_name(lobby_name)

func check_nickname(nickname: String) -> bool:
	return is_valid_name(nickname)

func save_settings():
	var config = ConfigFile.new()
	var min_players = %UI.get_min_players()
	if check_min_players(min_players):
		config.set_value("Settings", "min_players", min_players)
	var max_players = %UI.get_max_players()
	if check_max_players(max_players):
		config.set_value("Settings", "max_players", max_players)
	if check_lobby_name(%UI.get_lobby_name()):
		config.set_value("Settings", "lobby_name", %UI.get_lobby_name())
	if check_nickname(%UI.get_nickname()):
		config.set_value("Settings", "nickname", %UI.get_nickname())
	config.set_value("Settings", "car_color", %UI.get_car_color())
	config.save("user://settings.cfg")

func load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		if config.save("user://settings.cfg") != OK:
			printerr("Could not create settings file")
			return

	%UI.set_min_players(int(config.get_value("Settings", "min_players", MIN_PLAYERS_DEFAULT)))
	%UI.set_max_players(int(config.get_value("Settings", "max_players", MAX_PLAYERS_DEFAULT)))
	%UI.set_lobby_name(config.get_value("Settings", "lobby_name", generate_lobbyname()))
	%UI.set_nickname(config.get_value("Settings", "nickname", generate_nickname()))
	var color = Color(config.get_value("Settings", "car_color", COLOR_DEFAULT)[0],
		config.get_value("Settings", "color", COLOR_DEFAULT)[1],
		config.get_value("Settings", "color", COLOR_DEFAULT)[2])
	%UI.set_car_color(color)

func switch_mode(next_mode: Mode, server_up: bool):
	assert(next_mode != self.mode)

	if self.mode == Mode.IN_RACE || self.mode == Mode.LOBBY_INTERMISSION:
		if next_mode == Mode.WELCOME_PAGE:
			self.track_node.visible = false
			self.car_node.visible = false
			for n in $Track.get_children():
				$Track.remove_child(n)

	if next_mode == Mode.IN_RACE:
		self.track_node.visible = true
		self.car_node.visible = true
		
	if !%Network.switch_mode(next_mode):
		return

	%UI.switch_mode(next_mode, server_up)
	
	if OS.has_feature("debug"):
		print("### %s -> %s ###" % [ self.modes_strings[ self.mode], self.modes_strings[next_mode]])
		
	self.mode = next_mode

func switch_to_track(track_id: int, race_ongoing: bool):
	if track_id >= self.tracks.size():
		printerr("bad track id %d" % track_id)
		return
	%UI.set_intermission_lobby_name(%UI.get_lobby_name())
	%UI.set_intermission_track_name("Current track: %s" % self.tracks[track_id][1])

	var track_scene: PackedScene = load("res://Tracks/" + self.tracks[track_id][0] + "/level.tscn")
	self.track_node = track_scene.instantiate()
	var physical_node: Node3D = self.track_node.get_node_or_null("Physical")
	assert(physical_node)
	var spawn_node: Node3D = physical_node.get_node_or_null("Spawn")
	assert(spawn_node)
	$Track.add_child(self.track_node)
	
	self.car_node = player_scene.instantiate()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = %UI.get_car_color()
	var body = self.car_node.get_node("Body")
	(body as MeshInstance3D).mesh.surface_set_material(0, mat)
	(body.get_node("WheelFixedLeft") as MeshInstance3D).mesh.surface_set_material(0, mat)
	(body.get_node("WheelFixedRight") as MeshInstance3D).mesh.surface_set_material(0, mat)
	(body.get_node("WheelTurnLeft") as MeshInstance3D).mesh.surface_set_material(0, mat)
	(body.get_node("WheelTurnRight") as MeshInstance3D).mesh.surface_set_material(0, mat)
	car_node.name = %UI.get_nickname()
	$Track.add_child(self.car_node)

	var camera_node: Camera3D = car_node.get_node_or_null("Camera")
	camera_node.make_current()
	if race_ongoing:
		switch_mode(Mode.IN_RACE, true)
	else:
		switch_mode(Mode.LOBBY_INTERMISSION, true)

func on_connection():
	var request = {}
	if mode == Mode.FETCH_LOBBIES:
		request = {"Request": "FetchLobbyList"}
	elif mode == Mode.JOINING_LOBBY:
		request = {"Request": {"JoinLobby": {"lobby_id": %UI.get_lobby_name(),
					   "nickname": %UI.get_nickname(), "color": %UI.get_car_color_array()}}}
	elif mode == Mode.CREATING_LOBBY:
		request = {"Request": {"CreateLobby": {"lobby_id": %UI.get_lobby_name(),
				   "nickname": %UI.get_nickname(), "min_players": %UI.get_min_players(),
					"max_players": %UI.get_max_players(), "color": %UI.get_car_color_array()}}}
		switch_mode(Mode.JOINING_LOBBY, true)
	var result = %Network.socket.send_text(JSON.stringify(request))
	if result != OK:
		printerr("Could not send request %s" % request)

func on_server_message(message: Dictionary) -> bool:
	if OS.has_feature("debug") && self.debug:
		print(message)
	if self.mode == Mode.FETCH_LOBBIES:
		if !message.has("Response") || !message["Response"].has("LobbyList"):
			printerr("Unexpected response for a fetch lobbies list")
			return false
		%UI.refresh(message["Response"]["LobbyList"])
		return false
	elif self.mode == Mode.JOINING_LOBBY:
		if !message.has("Response") || !message["Response"].has("LobbyJoined") \
			|| !message["Response"]["LobbyJoined"].has("success"):
			printerr("Unexpected response for a join lobby")
			return false
		if message["Response"]["LobbyJoined"]["success"] != true:
			%InfoLabel.text = "Could not join lobby: %d" % message["Response"]["LobbyJoined"]["info"]
			return false
		switch_to_track(int(message["Response"]["LobbyJoined"]["info"]), message["Response"]["LobbyJoined"]["race_ongoing"])
	elif self.mode == Mode.LOBBY_INTERMISSION || self.mode == Mode.IN_RACE:
		handle_lobby(message)
	return true

func update_opponent_car(player: Variant):
	var new_position = Vector3(player[2][0], player[2][1], player[2][2])
	var new_direction = Vector3(player[3][0], player[3][1], player[3][2])
	var opponent_car_node: StaticBody3D = %Track.get_node_or_null(player[0])

	if !opponent_car_node:
		opponent_car_node = opponent_scene.instantiate()
		opponent_car_node.name = player[0]
		var mat = StandardMaterial3D.new()
		
		mat.albedo_color = Color(player[4][0], player[4][1], player[4][2])
		mat.albedo_color = Color(Color.REBECCA_PURPLE)
		(opponent_car_node.get_node("Body") as MeshInstance3D).mesh.surface_set_material(0, mat)
		(opponent_car_node.get_node("WheelFixedLeft") as MeshInstance3D).mesh.surface_set_material(0, mat)
		(opponent_car_node.get_node("WheelFixedRight") as MeshInstance3D).mesh.surface_set_material(0, mat)
		(opponent_car_node.get_node("WheelTurnLeft") as MeshInstance3D).mesh.surface_set_material(0, mat)
		(opponent_car_node.get_node("WheelTurnRight") as MeshInstance3D).mesh.surface_set_material(0, mat)
		%Track.add_child(opponent_car_node, true)
	opponent_car_node.position = new_position
	opponent_car_node.look_at(new_position + new_direction, Vector3.UP)

func handle_lobby(message: Variant):
	if message.has("Event"):
		if message["Event"].has("RaceAboutToStart"):
			var start_position = message["Event"]["RaceAboutToStart"][1]
			self.car_node.position = Vector3(float(start_position[0]), float(start_position[1]), float(start_position[2]))
			self.car_node.rotation_degrees.y = float(message["Event"]["RaceAboutToStart"][0])
		if message["Event"].has("RaceStarted"):
			switch_mode(Mode.IN_RACE, true)
		if message["Event"].has("Countdown"):
			var startin = int(message["Event"]["Countdown"]["time"])
			var start_position = Vector3(float(message["Event"]["Countdown"]["position"][0]),
				float(message["Event"]["Countdown"]["position"][1] + 2.0),
				float(message["Event"]["Countdown"]["position"][2]))
			self.car_node.position = start_position
			%InfoLabel.text = "Start in %d..." % startin
	elif message.has("State"):
		if message["State"].has("Players"):
			var players = message["State"]["Players"] as Array
			%UI.set_intermission_players_count("%d/%d (%d players minimum)" % [players.size(), %UI.get_max_players(), %UI.get_min_players()])
			%UI.set_intermission_players_list(players)
			for player in players:
				if player[1] && player[0] != %UI.get_nickname():
					update_opponent_car(player)
		elif message["State"].has("WaitingForPlayers"):
			var missing = int(message["State"]["WaitingForPlayers"])
			%InfoLabel.text = "Waiting for %d player%s" % [missing, ("" if missing == 1 else "s")]


func is_valid_name(name_to_check: String) -> bool:
	if name_to_check.length() < 3 or name_to_check.length() > 20:
		return false
	return regex.search(name_to_check) != null
	
func generate_nickname() -> String:
	var prefixes = [
		"Neo", "Dark", "Ultra", "Mega", "Hyper", "Shadow", "Cyber", "Iron", "Ghost"
	]
	
	var cores = [
		"Fox", "Wolf", "Tiger", "Eagle", "Viper", "Falcon", "Blade", "Storm", "Nova"
	]
	
	var suffixes = [
		"", "X", "99", "Pro", "HD", "Prime", "Z", "One"
	]
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var prefix = prefixes[rng.randi_range(0, prefixes.size() - 1)]
	var core = cores[rng.randi_range(0, cores.size() - 1)]
	var suffix = suffixes[rng.randi_range(0, suffixes.size() - 1)]
	
	return prefix + core + suffix

func generate_lobbyname() -> String:
	var adjectives = [
		"Red", "Blue", "Green", "Yellow", "Purple", "Orange", "Silver", "Golden", "Black"
	]
	
	var nouns = [
		"Comet", "Meteor", "Asteroid", "Nebula", "Galaxy", "Star", "Planet", "Rocket", "Satellite"
	]
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var adjective = adjectives[rng.randi_range(0, adjectives.size() - 1)]
	var noun = nouns[rng.randi_range(0, nouns.size() - 1)]
	
	return adjective + noun
