extends Node3D

# Worker properties
var model: Node3D
var animation_player: AnimationPlayer
var nav_agent: NavigationAgent3D
var construction_position: Vector3

var is_moving: bool = false
var is_construction_active: bool = false
var construction_finished: bool = false
var movement_speed: float = 2.5 # Default walking speed

# Sound effect properties
var construction_sound: AudioStreamPlayer # Use regular AudioStreamPlayer instead of 3D
var loop_timer: Timer
var my_sound_id: int = 0  # Unique ID for this worker's sound
var sound_initialized: bool = false

# Signals
signal construction_started
signal construction_ended

# Initialize the worker
func initialize(worker_model: Node3D, anim_player: AnimationPlayer, navigation_agent: NavigationAgent3D, target_pos: Vector3):
	model = worker_model
	animation_player = anim_player
	nav_agent = navigation_agent
	construction_position = target_pos
	is_moving = true
	
	# Generate a unique ID for this worker
	my_sound_id = randi()
	print("DEBUG: Worker created with ID: ", my_sound_id)
	
	# Set up sound effects (call after being added to the scene tree)
	call_deferred("setup_sound")
	
	# Start moving after a frame
	call_deferred("set_movement_target", target_pos)
	
# Set up sound for this worker
func setup_sound():
	print("DEBUG: Setting up sound for worker " + str(my_sound_id))
	
	# Create a regular AudioStreamPlayer (not 3D) for better reliability
	construction_sound = AudioStreamPlayer.new()
	construction_sound.name = "ConstructionSound_" + str(my_sound_id)
	add_child(construction_sound)
	print("DEBUG: Created AudioStreamPlayer for worker " + str(my_sound_id))
	
	# Create a timer for looping the sound
	loop_timer = Timer.new()
	loop_timer.name = "SoundLoopTimer_" + str(my_sound_id)
	add_child(loop_timer)
	
	# Load the sound effect
	var sound_resource = load("res://sounds/construction.wav")
	if sound_resource:
		print("DEBUG: Sound file loaded successfully")
		
		# Directly use the sound resource
		construction_sound.stream = sound_resource
		
		# Configure sound settings
		construction_sound.volume_db = -5.0    # Volume level
		construction_sound.bus = "SFX"         # Use the SFX bus
		
		sound_initialized = true
		print("DEBUG: Worker " + str(my_sound_id) + " sound setup completed")
	else:
		push_error("Could not load construction sound effect!")
		print("ERROR: Could not load construction sound effect!")
	
	# Configure timer with slight random variation
	loop_timer.wait_time = randf_range(1.85, 2.05)  # Random loop time
	loop_timer.one_shot = false
	loop_timer.autostart = false
	
	# Connect the timer to the loop function
	loop_timer.timeout.connect(loop_construction_sound)
	print("DEBUG: Timer set up and connected for worker " + str(my_sound_id))
	
	# Check if we need to connect to the audio_ready signal (for web)
	if OS.has_feature("web"):
		var sound_manager = get_node_or_null("/root/SoundManager")
		if sound_manager and not sound_manager.audio_initialized:
			# Connect to the audio_ready signal so we can start playing when audio is ready
			sound_manager.audio_ready.connect(check_and_play_sound)
			print("DEBUG: Worker " + str(my_sound_id) + " connected to audio_ready signal")

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
		ensure_animation_playing()
			
# Make sure the construction animation keeps playing
func ensure_animation_playing():
	# Check if animation isn't playing or is on the wrong animation
	if animation_player and not animation_player.is_playing():
		# Try different animation names (pick-up, pick_up, pickup)
		if animation_player.has_animation("pick-up"):
			animation_player.play("pick-up")
		elif animation_player.has_animation("pick_up"):
			animation_player.play("pick_up")
		elif animation_player.has_animation("pickup"):
			animation_player.play("pickup")

func move_along_path(delta: float):
	# Get movement data
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	# Set velocity directly using the instance's movement_speed
	global_position += direction * movement_speed * delta
	
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
			
# Set movement speed - can be used to vary worker speeds slightly
func set_movement_speed(speed: float):
	movement_speed = speed

func set_movement_target(target: Vector3):
	if nav_agent:
		nav_agent.set_target_position(target)
		is_moving = true
		
		# Play walking animation
		if animation_player and animation_player.has_animation("walk"):
			animation_player.play("walk")

func start_construction():
	print("DEBUG: Worker " + str(my_sound_id) + " starting construction")
	is_construction_active = true
	
	# Check if we can play sound (for web platform)
	var can_play_sound = true
	if OS.has_feature("web"):
		var sound_manager = get_node_or_null("/root/SoundManager")
		if sound_manager:
			can_play_sound = sound_manager.audio_initialized
	
	# Start playing construction sound if possible
	if can_play_sound and sound_initialized and construction_sound and construction_sound.stream:
		play_sound()
	elif OS.has_feature("web"):
		print("DEBUG: Worker " + str(my_sound_id) + " waiting for audio initialization")
	
	# Emit signal for compatibility with existing system
	construction_started.emit()
	
	# Start construction animation
	if animation_player:
		if animation_player.has_animation("pick-up"):
			animation_player.play("pick-up")
		elif animation_player.has_animation("pick_up"):
			animation_player.play("pick_up")
		elif animation_player.has_animation("pickup"):
			animation_player.play("pickup")
		elif animation_player.has_animation("idle"):
			animation_player.play("idle")

# Helper to play construction sound
func play_sound():
	if is_construction_active and construction_sound and construction_sound.stream:
		# Set random pitch for variety
		construction_sound.pitch_scale = randf_range(0.9, 1.1)
		
		# Play the sound
		construction_sound.play()
		print("DEBUG: Playing sound for worker " + str(my_sound_id))
		
		# Start the loop timer
		loop_timer.start()

# Called when audio becomes available in web builds
func check_and_play_sound():
	print("DEBUG: Audio now ready for worker " + str(my_sound_id))
	if is_construction_active and not construction_finished:
		play_sound()

# Loop the construction sound independently
func loop_construction_sound():
	if is_construction_active and construction_sound and construction_sound.stream:
		# Stop the sound if it's still playing (to prevent overlap)
		if construction_sound.playing:
			construction_sound.stop()
				
		# Slight random pitch variation on each loop
		construction_sound.pitch_scale = randf_range(0.9, 1.1)
		
		# Play the sound again
		construction_sound.play()
		print("DEBUG: Looping sound for worker " + str(my_sound_id))
	else:
		print("DEBUG: Cannot loop sound - either worker not active or sound not set up")

func finish_construction():
	print("DEBUG: Worker " + str(my_sound_id) + " finishing construction")
	is_construction_active = false
	construction_finished = true
	
	# Stop the construction sound
	if construction_sound and construction_sound.playing:
		construction_sound.stop()
		print("DEBUG: Stopped sound for worker " + str(my_sound_id))
	
	# Stop the sound loop timer
	if loop_timer and loop_timer.is_inside_tree():
		loop_timer.stop()
		print("DEBUG: Stopped timer for worker " + str(my_sound_id))
	
	# Emit signal for compatibility
	construction_ended.emit()
	
	# Find a road to walk back to
	var road_position = find_random_road()
	if road_position != Vector3.ZERO:
		set_movement_target(road_position)
		is_moving = true
	
	# Start removal timer
	var removal_timer = get_tree().create_timer(5.0)
	removal_timer.timeout.connect(remove_worker)

func remove_worker():
	# Make sure sounds are stopped and cleaned up
	if construction_sound:
		if construction_sound.playing:
			construction_sound.stop()
		construction_sound.queue_free()
		construction_sound = null
		print("DEBUG: Cleaned up sound for worker " + str(my_sound_id))
	
	if loop_timer:
		if loop_timer.is_inside_tree() and loop_timer.time_left > 0:
			loop_timer.stop()
		loop_timer.queue_free()
		loop_timer = null
		print("DEBUG: Cleaned up timer for worker " + str(my_sound_id))
	
	print("DEBUG: Worker " + str(my_sound_id) + " removed from game")
	queue_free()

# Find a random road to walk back to
func find_random_road() -> Vector3:
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
