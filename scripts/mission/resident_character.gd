extends Node3D

# Resident properties
var model: Node3D
var animation_player: AnimationPlayer
var nav_agent: NavigationAgent3D
var home_position: Vector3

var is_moving: bool = false
var destination: Vector3 = Vector3.ZERO
var wait_timer: float = 0.0
var wait_duration: float = 3.0  # How long to wait between movements

# Initialize the resident
func initialize(resident_model: Node3D, anim_player: AnimationPlayer, navigation_agent: NavigationAgent3D, building_pos: Vector3):
	model = resident_model
	animation_player = anim_player
	nav_agent = navigation_agent
	home_position = building_pos
	
	# Start patrolling after a short delay
	wait_timer = 2.0  # Wait 2 seconds before starting
	
	print("Resident initialized at ", global_position)

func _physics_process(delta: float):
	if is_moving:
		if nav_agent.is_navigation_finished():
			# Reached destination, start waiting
			is_moving = false
			wait_timer = 0.0
			
			# Play idle animation
			if animation_player and animation_player.has_animation("idle"):
				animation_player.play("idle")
				
			print("Resident reached destination, waiting...")
		else:
			# Continue moving
			move_along_path(delta)
	else:
		# Handle waiting between movements
		wait_timer += delta
		if wait_timer >= wait_duration:
			find_new_destination()

func move_along_path(delta: float):
	# Get movement data
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Set velocity directly
	var speed = 1.5  # walking speed (slower than workers)
	global_position += direction * speed * delta
	
	# Make character face the direction of movement
	if direction.length() > 0.01:
		# Look at the destination
		var look_target = global_position + Vector3(direction.x, 0, direction.z)
		model.look_at(look_target, Vector3.UP)
		# Rotate 180 degrees to face forward
		model.rotate_y(PI)
	
	# Play walking animation
	if animation_player and animation_player.has_animation("walk"):
		if not animation_player.is_playing() or animation_player.current_animation != "walk":
			animation_player.play("walk")

func set_movement_target(target: Vector3):
	if nav_agent:
		nav_agent.set_target_position(target)
		is_moving = true
		
		# Play walking animation
		if animation_player and animation_player.has_animation("walk"):
			animation_player.play("walk")
			
		print("Resident moving to ", target)

func find_new_destination():
	# Find a road to walk to
	var road_position = _find_random_road()
	
	if road_position != Vector3.ZERO:
		# Set target and start moving
		set_movement_target(road_position)
		
		# Set a random wait duration for next stop
		wait_duration = randf_range(2.0, 6.0)
	else:
		# If no road found, try again later
		wait_timer = 0.0
		print("No road found for resident to walk to")

# Find a random road to walk to
func _find_random_road() -> Vector3:
	var roads = []
	var parent = get_parent()
	
	# Check if the parent is actually the navigation region
	if parent and parent.name == "NavRegion3D":
		# Collect all road nodes
		for child in parent.get_children():
			if child.name.begins_with("Road_"):
				# Extract position
				var pos_parts = child.name.split("_")
				if pos_parts.size() >= 3:
					var road_pos = Vector3(int(pos_parts[1]), 0, int(pos_parts[2]))
					roads.append(road_pos)
	else:
		# If we can't find roads from our parent, try going back home
		print("Resident couldn't find parent navigation region")
		return home_position
	
	# Pick a random road
	if not roads.is_empty():
		return roads[randi() % roads.size()]
	
	# Fallback to home position if no roads found
	return home_position
