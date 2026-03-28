extends RigidBody3D

@export var force := 100.0
@export var torque := 20.0

@onready var init_rot_wheel = %WheelTurnLeft.rotation_degrees.y
var delta_rot_wheel = 0
var limit_rot_wheel = 30

func _ready() -> void:
	%EngineAudio.play()
	%EngineAudio.stream_paused = true

func _physics_process(delta: float) -> void:
	if $"/root/Root/Game".mode != Game.Mode.IN_RACE \
	   || $"/root/Root/Game".paused:
		return
	
	%EngineAudio.stream_paused = false
	
	var max_speed := 7.0
	var speed_ratio := linear_velocity.length() / max_speed
	
	var accel = Input.get_action_strength("forward")
	var drift = Input.get_action_strength("handbrake")

	var rpm = speed_ratio * 0.7 + accel * 0.3 + drift * 0.2
	rpm = clamp(rpm, 0, 1)


	%EngineAudio.pitch_scale = lerp(0.001, 0.01, speed_ratio)
	%EngineAudio.volume_db = lerp(-25, -20, speed_ratio)
	
	var forward_dir = - transform.basis.z
	#assert(forward_dir.is_normalized())


	if !Input.is_action_pressed("left") and !Input.is_action_pressed("right"):
		if delta_rot_wheel > 0:
			delta_rot_wheel -= delta * 50
			if delta_rot_wheel < 0:
				delta_rot_wheel = 0
		elif delta_rot_wheel < 0:
			delta_rot_wheel += delta * 50
			if delta_rot_wheel > 0:
				delta_rot_wheel = 0
		%WheelTurnLeft.rotation_degrees.y = init_rot_wheel + delta_rot_wheel
		%WheelTurnRight.rotation_degrees.y = init_rot_wheel + delta_rot_wheel

	if Input.is_action_pressed("handbrake"):
		if linear_velocity.length() < 0.1:
			return

	if Input.is_action_pressed("handbrake"):
		apply_central_force(-forward_dir * force * 400)
	
	var right_dir = transform.basis.x
	var lateral_speed = right_dir.dot(linear_velocity)

	# coefficient à tweak (plus grand = plus arcade)
	var grip = 4.0

	apply_central_force(-right_dir * lateral_speed * grip)
	if Input.is_action_pressed("forward"):
		apply_central_force(forward_dir * force * 400)
		
	if Input.is_action_pressed("backward"):
		apply_central_force(-forward_dir * force * 400)
		
	var speed = linear_velocity.length()
	var steer_strength = clamp(speed / max_speed, 0.0, 1.0)
	
	if Input.is_action_pressed("handbrake"):
		steer_strength = 1.0

	if Input.is_action_pressed("left") && !Input.is_action_pressed("right"):
		var vec = Vector3.UP
		if Input.is_action_pressed("backward"):
			vec = - vec


		apply_torque(vec * torque * steer_strength * 400)

		delta_rot_wheel += delta * 100
		if delta_rot_wheel > limit_rot_wheel:
			delta_rot_wheel = limit_rot_wheel
		%WheelTurnLeft.rotation_degrees.y = init_rot_wheel + delta_rot_wheel
		%WheelTurnRight.rotation_degrees.y = init_rot_wheel + delta_rot_wheel
	
	if Input.is_action_pressed("right") && !Input.is_action_pressed("left"):
		var vec = Vector3.DOWN
		if Input.is_action_pressed("backward"):
			vec = - vec

		apply_torque(vec * torque * steer_strength * 400)

		delta_rot_wheel -= delta * 100
		if delta_rot_wheel < -limit_rot_wheel:
			delta_rot_wheel = - limit_rot_wheel
		%WheelTurnLeft.rotation_degrees.y = init_rot_wheel + delta_rot_wheel
		%WheelTurnRight.rotation_degrees.y = init_rot_wheel + delta_rot_wheel
