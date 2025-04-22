extends Node3D

var camera_position:Vector3
var camera_rotation:Vector3

@onready var camera = $Camera

# Plane for mouse intersection
var ground_plane := Plane(Vector3.UP, 0)

func _ready():
	camera_rotation = rotation_degrees # Initial rotation
	pass

func _process(delta):
	# Set position and rotation to targets
	position = position.lerp(camera_position, delta * 8)
	rotation_degrees = rotation_degrees.lerp(camera_rotation, delta * 6)
	
	handle_input(delta)

func get_mouse_world_position() -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var intersection = ground_plane.intersects_ray(from, dir)
	if intersection:
		return intersection
	# If no intersection, return a point in front of the camera
	return camera.global_position + (-camera.global_transform.basis.z * 10)

func _input(event):
	# Rotate camera using mouse (hold 'middle' mouse button)
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("camera_rotate"):
			camera_rotation += Vector3(0, -event.relative.x / 10, 0)

func handle_input(_delta):
	# Rotation
	var input := Vector3.ZERO
	
	input.x = Input.get_axis("camera_left", "camera_right")
	input.z = Input.get_axis("camera_forward", "camera_back")
	
	input = input.rotated(Vector3.UP, rotation.y).normalized()
	
	camera_position += input / 4
	
	# Back to center
	if Input.is_action_pressed("camera_center"):
		camera_position = Vector3()
