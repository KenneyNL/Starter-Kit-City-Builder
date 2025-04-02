extends Node3D

# Worker properties
var model: Node3D
var animation_player: AnimationPlayer
var nav_agent: NavigationAgent3D
var construction_position: Vector3

var is_moving: bool = false
var is_construction_active: bool = false
var construction_finished: bool = false

# Initialize the worker
func initialize(worker_model: Node3D, anim_player: AnimationPlayer, navigation_agent: NavigationAgent3D, target_pos: Vector3):
	model = worker_model
	animation_player = anim_player
	nav_agent = navigation_agent
	construction_position = target_pos
	is_moving = true
	
	# Start moving after a frame
	call_deferred("set_movement_target", target_pos)

func _physics_process(delta: float):
	if construction_finished:
		return
		
	if is_moving:
		if nav_agent.is_navigation_finished():
			# Reached destination
			is_moving = false
			
			if not is_construction_active and not construction_finished:
				# Start construction
				start_construction()
		else:
			# Continue moving
			move_along_path(delta)
	elif is_construction_active:
		# Make sure we keep the construction animation looping
		_ensure_construction_animation_playing()
		
# Make sure the construction animation keeps playing
func _ensure_construction_animation_playing():
	# Every 0.5 seconds check if the animation is still playing (determined by a timer logic)
	if not animation_player:
		return
	
	# Check if animation isn't playing or is on the wrong animation
	if not animation_player.is_playing() or (
		animation_player.current_animation != "pick-up" and
		animation_player.current_animation != "pick_up" and
		animation_player.current_animation != "pickup"):
		
		# Try to restart the animation
		if animation_player.has_animation("pick-up"):
			animation_player.play("pick-up")
			print("Restarted pick-up animation")
		elif animation_player.has_animation("pick_up"):
			animation_player.play("pick_up")
		elif animation_player.has_animation("pickup"):
			animation_player.play("pickup")

func move_along_path(delta: float):
	# Get movement data
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Set velocity directly
	var speed = 2.5 # walking speed
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

func start_construction():
	is_construction_active = true
	
	# Construction sound code removed
	
	# Print all available animations for debugging
	if animation_player:
		print("Available animations for worker: ")
		var anim_list = animation_player.get_animation_list()
		for anim_name in anim_list:
			print("- " + anim_name)
	
	# Try to force the animation to loop using different approaches
	if animation_player:
		# First try with the actual animation name "pick-up"
		if animation_player.has_animation("pick-up"):
			print("Found animation: pick-up")
			
			# Try to get the animation resource
			var animation = animation_player.get_animation("pick-up")
			if animation:
				# Set the loop mode if possible
				animation.loop_mode = 1  # LOOP_LINEAR
				print("Set loop mode for pick-up animation")
			
			# Set speed scale to make it look more natural
			animation_player.speed_scale = 1.0
			
			# Play it on repeat
			animation_player.play("pick-up")
			# Force looping by continuously queuing the same animation
			animation_player.queue("pick-up")
			animation_player.queue("pick-up")
			animation_player.queue("pick-up")
			print("Started pick-up animation loop")
			
			# Schedule to check on animation status in 1 second
			var timer = get_tree().create_timer(1.0)
			timer.timeout.connect(_check_animation_status)
			
		# Try alternative spellings if needed
		elif animation_player.has_animation("pick_up"):
			animation_player.play("pick_up")
			animation_player.queue("pick_up")
			print("Started pick_up animation loop")
		elif animation_player.has_animation("pickup"):
			animation_player.play("pickup")
			animation_player.queue("pickup")
			print("Started pickup animation loop")
		elif animation_player.has_animation("idle"):
			animation_player.play("idle")
			print("No pickup animation, using idle")
		else:
			print("No suitable animations found. Available animations: ", animation_player.get_animation_list())

# Helper to check animation status
func _check_animation_status():
	if animation_player and is_construction_active:
		print("Animation status check - current animation: ", animation_player.current_animation)
		print("Is playing: ", animation_player.is_playing())
		
		# Force animation to continue if needed
		if not animation_player.is_playing() or animation_player.current_animation != "pick-up":
			if animation_player.has_animation("pick-up"):
				animation_player.play("pick-up")
				print("Restarted pick-up animation from timer callback")

func finish_construction():
	is_construction_active = false
	construction_finished = true
	
	# Construction sound code removed
	
	# Find a road to walk back to
	var road_position = _find_random_road()
	if road_position != Vector3.ZERO:
		set_movement_target(road_position)
		is_moving = true
	
	# Start removal timer
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_remove_worker)

func _remove_worker():
	queue_free()

# Find a random road to walk back to
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
		# If we can't find roads from our parent, use our current position
		print("Worker couldn't find parent navigation region, using current position")
		return global_position
	
	# Pick a random road
	if not roads.is_empty():
		return roads[randi() % roads.size()]
	
	# Fallback to current position if no roads found
	return global_position