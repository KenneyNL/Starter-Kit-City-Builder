extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var random_position := Vector3.ZERO
		random_position.x = randf_range(-5,5)
		random_position.y = randf_range(-5,5)
		navigation_agent_3d.set_target_position(random_position)
		

func _physics_process(delta:float)->void:
	var destination = navigation_agent_3d.get_next_path_position()
	var local_destination = destination - global_position
	var direction = local_destination.normalized()
	
	velocity = direction * 5
	move_and_slide()
	
