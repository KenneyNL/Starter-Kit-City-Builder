extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $"character-female-d2/AnimationPlayer"
@onready var character_model: Node3D = $"character-female-d2"

var is_moving: bool = false
var wait_timer: float = 0.0
var waiting_time: float = 3.0
var last_position: Vector3 = Vector3.ZERO
var auto_patrol: bool = true # Set to true to automatically patrol between points
var movement_speed: float = 2.5 # Walking speed
var stuck_timer: float = 0.0 # Timer to detect if character is stuck
var stuck_threshold: float = 5.0 # Time before considering character stuck

func _ready() -> void:
	# Set navigation parameters
	navigation_agent_3d.path_desired_distance = 0.5
	navigation_agent_3d.target_desired_distance = 0.5
	
	# Connect navigation signal if using Godot's navigation velocity system
	if navigation_agent_3d.has_signal("velocity_computed"):
		navigation_agent_3d.velocity_computed.connect(_on_velocity_computed)
	
	# Store initial position
	last_position = global_position
	
	if animation_player:
		# Start with idle animation
		animation_player.play("idle")
	
	# Force an immediate target set to get the character moving
	call_deferred("_start_initial_movement")

# Called after scene is ready to start movement
func _start_initial_movement():
	await get_tree().process_frame
	pick_random_target()
	print("Initial movement target set for character at ", global_position)

# Force movement to a specific target
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var random_position := Vector3.ZERO
		random_position.x = randf_range(-5,5)
		random_position.z = randf_range(-5,5) # Changed to z-axis since we're in 3D space
		set_movement_target(random_position)
		print("User forced new movement target: ", random_position)

# Set the target position for navigation
func set_movement_target(target: Vector3) -> void:
	navigation_agent_3d.set_target_position(target)
	is_moving = true
	stuck_timer = 0.0
	
	if animation_player and animation_player.current_animation != "walk":
		animation_player.play("walk")
		
	print("Set movement target to: ", target)

func _physics_process(delta:float)->void:
	# Check if character is stuck
	var moved = (global_position - last_position).length() > 0.01
	if is_moving and !moved:
		stuck_timer += delta
		if stuck_timer > stuck_threshold:
			# Character is stuck, pick a new random target
			print("Character stuck at ", global_position, ", picking new target")
			pick_random_target()
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	
	# Always update the last position
	last_position = global_position
	
	# Check for auto patrol behavior
	if auto_patrol:
		if !is_moving:
			# Count down the wait timer
			wait_timer += delta
			if wait_timer >= waiting_time:
				wait_timer = 0.0
				pick_random_target()
				print("Auto patrol timer triggered new target")
	
	# Handle navigation logic
	if navigation_agent_3d.is_navigation_finished():
		# Character reached destination, switch to idle
		if is_moving:
			is_moving = false
			if animation_player:
				animation_player.play("idle")
				
			# Reset wait timer for next automatic movement
			wait_timer = 0.0
			waiting_time = randf_range(2.0, 5.0)
			print("Character reached destination, waiting for ", waiting_time, " seconds")
		return
	
	# If we're still moving, proceed with navigation
	if is_moving:
		# Get movement data
		var destination = navigation_agent_3d.get_next_path_position()
		var local_destination = destination - global_position
		var direction = local_destination.normalized()
		
		# Make character face the direction of movement
		if direction.length() > 0.01:
			# Look at the destination with a 180-degree rotation to face forward
			var look_target = global_position + Vector3(direction.x, 0, direction.z)
			
			# First make the character model look at the target
			character_model.look_at(look_target, Vector3.UP)
			
			# Then rotate it 180 degrees around the Y axis to fix backward facing
			character_model.rotate_y(PI)
		
		# Play walking animation when moving
		if not animation_player.current_animation == "walk":
			animation_player.play("walk")
		
		# Calculate velocity - try both methods of movement
		if navigation_agent_3d.avoidance_enabled and has_method("_on_velocity_computed"):
			# Use Godot's navigation velocity system
			var desired_velocity = direction * movement_speed
			navigation_agent_3d.set_velocity(desired_velocity)
		else:
			# Direct movement
			velocity = direction * movement_speed
			move_and_slide()

# Called when the navigation system has computed the velocity
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	# Apply the computed velocity to the character
	velocity = safe_velocity
	move_and_slide()

# Picks a random target position that should be navigable
func pick_random_target() -> void:
	# Try to find a valid target position
	var max_attempts = 10
	var attempt = 0
	var found_valid_point = false
	var target_pos = Vector3.ZERO
	
	while attempt < max_attempts and !found_valid_point:
		# Generate a random direction and distance
		var random_direction = Vector3(
			randf_range(-1.0, 1.0),
			0.0,
			randf_range(-1.0, 1.0)
		).normalized()
		
		var random_distance = randf_range(3.0, 10.0)
		target_pos = global_position + random_direction * random_distance
		
		# Try to get a position on the navigation mesh
		if navigation_agent_3d.get_navigation_map() != RID():
			# If we have a valid navigation map, try to get a position on it
			found_valid_point = true
		
		attempt += 1
	
	# If we couldn't find a valid point, just pick a close one
	if !found_valid_point:
		target_pos = global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		print("Couldn't find valid navigation point, choosing nearby point: ", target_pos)
	
	set_movement_target(target_pos)
