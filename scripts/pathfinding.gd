extends CharacterBody3D


const SPEED = 5.0
const ACCEL = 10

@onready var nav:NavigationAgent3D = $NavigationAgent3D

func _physics_process(delta: float) -> void:
	var direction = Vector3()
	nav.target_position = Global.target.global_position
	
	direction = nav.get_next_path_position() - global_position
	direction = direction.normalized()
	
	velocity = velocity.lerp(direction * SPEED, ACCEL * delta)

	move_and_slide()
