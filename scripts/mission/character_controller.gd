extends CharacterBody3D
class_name CharacterController

enum MovementState {
	IDLE,
	WALKING,
	TURNING,
	WAITING
}

@export var walk_speed = 2.0
@export var patrol_distance = 8.0
@export var character_model: Node3D
@export var wait_time_min = 2.0
@export var wait_time_max = 5.0

var current_state = MovementState.WALKING
var start_position: Vector3
var target_position: Vector3
var direction: Vector3 = Vector3(1, 0, 0)  # X-axis movement by default
var initialized: bool = false
var debug_counter = 0
var animation_player: AnimationPlayer = null
var road_positions = []
var wait_timer: float = 0.0
var current_wait_time: float = 0.0
var turn_timer: float = 0.0
var turn_progress: float = 0.0

func _ready():
	# Initialize animation player
	animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		animation_player.play("walk")
		print("Walk animation started")
	
	# Wait a frame to make sure position is set
	await get_tree().process_frame
	
	# Store initial position
	start_position = global_position
	print("Character starting at: ", start_position)
	
	# Initial target position is patrol_distance ahead
	target_position = start_position + direction * patrol_distance
	print("Initial target: ", target_position)
	
	# Initialize
	initialized = true

func _physics_process(delta):
	if !initialized:
		return
	
	debug_counter += 1
	
	# Debug logging every 2 seconds
	if debug_counter % 120 == 0:
		print("Character at: ", global_position)
		print("Moving toward: ", target_position)
		print("Distance: ", global_position.distance_to(target_position))
		print("Current state: ", MovementState.keys()[current_state])
	
	match current_state:
		MovementState.WALKING:
			# Set velocity in the current direction
			velocity = direction * walk_speed
			
			# Move the character
			move_and_slide()
			
			# Play animation constantly
			if animation_player and !animation_player.is_playing():
				animation_player.play("walk")
			
			# Check for target reached - only if we're close to it in the XZ plane
			var distance_to_target = Vector2(global_position.x, global_position.z).distance_to(Vector2(target_position.x, target_position.z))
			
			if distance_to_target < 0.5:
				# Snap to exact position
				global_position = Vector3(target_position.x, global_position.y, target_position.z)
				
				# Decide if we'll wait or turn immediately
				if randf() < 0.4:  # 40% chance to wait
					# Enter waiting state
					current_state = MovementState.WAITING
					current_wait_time = randf_range(wait_time_min, wait_time_max)
					wait_timer = 0.0
					if animation_player:
						animation_player.play("idle")
					velocity = Vector3.ZERO
					print("Waiting for ", current_wait_time, " seconds")
				else:
					# Enter turning state
					current_state = MovementState.TURNING
					turn_timer = 0.0
					turn_progress = 0.0
					velocity = Vector3.ZERO
					print("Starting turn animation")
		
		MovementState.WAITING:
			# Character is standing still
			velocity = Vector3.ZERO
			
			# Count down wait time
			wait_timer += delta
			if wait_timer >= current_wait_time:
				# Enter turning state
				current_state = MovementState.TURNING
				turn_timer = 0.0
				turn_progress = 0.0
				print("Waiting completed, starting turn")
		
		MovementState.TURNING:
			# Perform turning animation over 0.5 seconds
			turn_timer += delta
			turn_progress = min(turn_timer / 0.5, 1.0)
			
			# Character is stationary during turn
			velocity = Vector3.ZERO
			
			# Update model rotation smoothly
			if character_model:
				var start_y = character_model.rotation.y
				var target_y
				
				# Calculate target rotation based on new direction (which will be opposite)
				if direction.x < 0:
					target_y = 0  # Will face right after turn
				elif direction.x > 0:
					target_y = PI  # Will face left after turn 
				elif direction.z < 0:
					target_y = PI/2  # Will face forward after turn
				elif direction.z > 0:
					target_y = -PI/2  # Will face back after turn
				
				# Interpolate rotation
				character_model.rotation.y = lerp(start_y, target_y, turn_progress)
			
			# When turning is complete
			if turn_progress >= 1.0:
				# Set new direction
				direction = -direction
				
				# Set new target
				if direction.x != 0:  # Moving along X axis
					target_position = Vector3(start_position.x + direction.x * patrol_distance, 
									   start_position.y, 
									   start_position.z)
				else:  # Moving along Z axis
					target_position = Vector3(start_position.x, 
									   start_position.y, 
									   start_position.z + direction.z * patrol_distance)
				
				# Return to walking state
				current_state = MovementState.WALKING
				if animation_player:
					animation_player.play("walk")
				print("Turn complete. New direction: ", direction)
				print("New target: ", target_position)
		
		MovementState.IDLE:
			# Idle state - do nothing
			velocity = Vector3.ZERO