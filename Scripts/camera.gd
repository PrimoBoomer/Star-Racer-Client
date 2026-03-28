extends Camera3D

@export var sensitivity := 2.5
@export var return_speed := 3.0
@export var distance := 8.0
@export var height := 2.0
@export var follow_speed := 6.0
@export var velocity_influence := 2.0

var yaw := 0.0
var pitch := 0.25
var current_pos: Vector3

func _ready():
	current_pos = global_transform.origin

func _process(_delta):
	var game = $"/root/Root/Game"
	if game == null or game.mode != Game.Mode.IN_RACE:
		return

	
