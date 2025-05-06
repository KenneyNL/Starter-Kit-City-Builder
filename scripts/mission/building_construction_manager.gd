extends Node
class_name BuildingConstructionManager

# Constants
const ObjectiveType = preload("res://configs/data.config.gd").ObjectiveType


# Signals
signal construction_completed(position)
signal worker_construction_started
signal worker_construction_ended


const CONSTRUCTION_TIME = 10.0 # seconds to build a building
var debug_timer = 0.0  # Add debug timer


# References to necessary scenes and resources
var worker_scene: PackedScene
var hud_manager: Node
var nav_region: NavigationRegion3D
var builder: Node3D
var gridmap: GridMap
var structures: Array[Structure]
var building_plot_scene: PackedScene
var final_building_scene: PackedScene
var mission_manager: MissionManager

# Keep track of all construction sites
var construction_sites = {}  # position (Vector3) -> construction data (dict)

func _ready():
	print("\n=== Initializing Building Construction Manager ===")
	
	# Load the worker character scene - add more fallbacks to ensure we get a valid model
	builder = get_node_or_null('/root/Main/Builder')
	worker_scene = load("res://people/character-male-a.glb")
	hud_manager = get_node_or_null("/root/Main/CanvasLayer/HUD")
	mission_manager = builder.get_node_or_null("/root/Main/MissionManager")
	
	# Get navigation region
	if builder and builder.nav_region:
		nav_region = builder.nav_region
		print("Found navigation region with ", nav_region.get_child_count(), " children")
		for child in nav_region.get_children():
			print("Nav region child: ", child.name)
	else:
		print("WARNING: No navigation region found!")
	
	if not worker_scene:
		worker_scene = load("res://people/character-female-a.glb")
	if not worker_scene:
		worker_scene = load("res://people/character-female-d.glb")
	if not worker_scene:
		# Create an empty PackedScene as a last resort
		worker_scene = PackedScene.new()
	
	# Load the building plot scene (placeholder during construction)
	building_plot_scene = load("res://models/building-small-a.glb")
	if not building_plot_scene:
		# Create an empty PackedScene as a last resort
		building_plot_scene = PackedScene.new()
	
	# Load the final building scene
	final_building_scene = load("res://models/building-small-a.glb")
	if not final_building_scene:
		# Create an empty PackedScene as a last resort
		final_building_scene = PackedScene.new()
	
	print("=== Building Construction Manager Initialized ===\n")

# Call this method to start construction at a position
func start_construction(position: Vector3, structure_index: int, rotation_basis = null):
	print("\n=== Starting Construction ===")
	print("Position: ", position)
	print("Structure Index: ", structure_index)
	
	if position in construction_sites:
		print("ERROR: Construction site already exists at this position!")
		return
	
	# Get the current selector rotation if available
	var rotation_index = 0
	if builder and builder.selector:
		# Convert the selector's basis to a GridMap orientation index
		if rotation_basis == null:
			rotation_basis = builder.selector.basis
		
		if builder.gridmap:
			rotation_index = builder.gridmap.get_orthogonal_index_from_basis(rotation_basis)
	
	print("Rotation Index: ", rotation_index)
	
	# Create a construction site entry
	construction_sites[position] = {
		"position": position,
		"structure_index": structure_index,
		"plot": null,
		"worker": null,
		"timer": 0.0,
		"completed": false,
		"rotation_index": rotation_index,
		"rotation_basis": rotation_basis
	}
	
	print("Created construction site entry")
	
	# Place plot marker (outline/transparent version of the building)
	var plot
	
	# Use the actual structure model for the transparent preview if available
	if structure_index >= 0 and structure_index < builder.structures.size():
		var structure = builder.structures[structure_index]
		plot = structure.model.instantiate()
		print("Created plot using structure model: ", structure.model.resource_path)
	else:
		# Fallback to default building model
		plot = building_plot_scene.instantiate()
		print("Created plot using fallback model")
		
	plot.name = "Plot_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Make it a transparent outline by applying transparency to all materials
	_make_model_transparent(plot, 0.3)
	print("Applied transparent material to plot")
	
	# Add to the scene and position it
	builder.add_child(plot)
	plot.global_transform.origin = position
	
	# Apply the rotation from the selector to the plot
	if rotation_basis:
		plot.basis = rotation_basis
	
	plot.scale = Vector3(3.0, 3.0, 3.0)
	print("Added plot to scene at position: ", position)
	
	# Store reference
	construction_sites[position]["plot"] = plot
	
	# Always spawn a worker for construction
	_spawn_worker_for_construction(position)
	print("=== Construction Started ===\n")
	
	# Send building_selected dialog to learning companion if available in the current mission
	if mission_manager and mission_manager.current_mission and mission_manager.learning_companion_connected:
		var mission = mission_manager.current_mission
		
		# Check if there's a building_selected dialog for this mission
		if mission.companion_dialog.has("building_selected"):
			const JSBridge = preload("res://scripts/javascript_bridge.gd")
			if JSBridge.has_interface():
				var dialog_data = mission.companion_dialog["building_selected"]
				JSBridge.get_interface().sendCompanionDialog("building_selected", dialog_data)
		
		# For power plant mission (mission 5), send a special dialog
		if structure_index >= 0 and structure_index < builder.structures.size():
			var structure = builder.structures[structure_index]
			if structure.model.resource_path.contains("power_plant") and mission.id == "5":
				const JSBridge = preload("res://scripts/javascript_bridge.gd")
				if JSBridge.has_interface() and mission.companion_dialog.has("building_selected"):
					var dialog_data = mission.companion_dialog["building_selected"]
					JSBridge.get_interface().sendCompanionDialog("building_selected", dialog_data)

# Process active construction sites
func _process(delta):
	var sites_to_complete = []
	debug_timer += delta  # Track total time
	
	# Update all construction sites
	for pos in construction_sites.keys():
		var site = construction_sites[pos]
		
		# Skip completed sites
		if site["completed"]:
			continue
		
		# Get the structure's build time
		var build_time = CONSTRUCTION_TIME  # Default fallback
		if site["structure_index"] >= 0 and site["structure_index"] < builder.structures.size():
			var structure = builder.structures[site["structure_index"]]
			if "build_time" in structure:
				build_time = structure.build_time
			
		# Update timer for all active sites, regardless of worker status
		site["timer"] += delta
		
		# Update the construction preview shader progress
		if site["plot"] != null:
			var progress = site["timer"] / build_time
			progress = clamp(progress, 0.0, 1.0)
			
			# Find all mesh instances and update their materials
			var mesh_instances = []
			_find_all_mesh_instances(site["plot"], mesh_instances)
			for mesh_instance in mesh_instances:
				for i in range(mesh_instance.get_surface_override_material_count()):
					var material = mesh_instance.get_surface_override_material(i)
					if material and material is ShaderMaterial:
						material.set_shader_parameter("progress", progress)
						material.set_shader_parameter("alpha", 0.3)
			
		# Check if construction is complete
		if site["timer"] >= build_time:
			sites_to_complete.append(pos)
	
	# Complete construction for sites that are done
	for pos in sites_to_complete:
		print("\n=== Completing Construction ===")
		print("Position: ", pos)
		_complete_construction(pos)

# Find a road and spawn a worker there
func _spawn_worker_for_construction(target_position: Vector3):
	print("\n=== Attempting to Spawn Worker ===")
	print("Target Position: ", target_position)
	
	# Find closest road tile
	var road_position = _find_nearest_road(target_position)
	
	if road_position == Vector3.ZERO:
		print("ERROR: No road found for worker spawn at target position: ", target_position)
		print("Checking navigation region...")
		if nav_region:
			print("Nav region has ", nav_region.get_child_count(), " children")
			for child in nav_region.get_children():
				print("Child: ", child.name)
		else:
			print("Nav region is null!")
		# Don't force completion - let the timer run normally
		return
		
	print("Found road position: ", road_position)
	print("Distance to target: ", road_position.distance_to(target_position))
	
	# Create the worker
	var worker = _create_worker(road_position, target_position)
	
	if worker == null:
		print("ERROR: Failed to create worker for construction at: ", target_position)
		# Don't force completion - let the timer run normally
		return
		
	# Store in the construction site data
	construction_sites[target_position]["worker"] = worker
	print("Worker spawned successfully")
	print("=== Worker Spawn Complete ===\n")

# Find nearest road (simplified version of what's in mission_manager.gd)
func _find_nearest_road(position: Vector3) -> Vector3:
	var nearest_road = Vector3.ZERO
	var min_distance = 100.0
	
	# Get the navigation region
	if not nav_region and builder and builder.nav_region:
		nav_region = builder.nav_region
		
	if nav_region:
		# Look for road nodes in the navigation region
		for child in nav_region.get_children():
			if child.name.begins_with("Road_"):
				# Extract position from the road name (format: "Road_X_Z")
				var pos_parts = child.name.split("_")
				if pos_parts.size() >= 3:
					var road_x = int(pos_parts[1])
					var road_z = int(pos_parts[2])
					var road_pos = Vector3(road_x, 0, road_z)
					
					# Calculate distance
					var distance = position.distance_to(road_pos)
					if distance < min_distance:
						nearest_road = road_pos
						min_distance = distance
	
	return nearest_road

# Create and configure a construction worker
func _create_worker(spawn_position: Vector3, target_position: Vector3):
	# Load the worker script 
	var worker_script = load("res://scripts/mission/construction_worker.gd")
	if not worker_script:
		return null
	
	# Create the worker node with the script
	var worker_node = Node3D.new()
	worker_node.set_script(worker_script)
	# Give each worker a unique name to avoid conflicts with their sound effects
	worker_node.name = "Worker_" + str(int(target_position.x)) + "_" + str(int(target_position.z)) + "_" + str(randi())
	
	# Add the worker to the scene
	if nav_region:
		nav_region.add_child(worker_node)
	else:
		builder.add_child(worker_node)
	
	# Connect signals for construction sounds
	worker_node.construction_started.connect(_on_worker_construction_started)
	worker_node.construction_ended.connect(_on_worker_construction_ended)
	
	# Position the worker
	worker_node.global_transform.origin = Vector3(spawn_position.x, 0.1, spawn_position.z)
	
	# Create the model
	var model = worker_scene.instantiate()
	worker_node.add_child(model)
	
	# Create an animation player if needed
	var anim_player
	if model.has_node("AnimationPlayer"):
		anim_player = model.get_node("AnimationPlayer")
	else:
		anim_player = AnimationPlayer.new()
		worker_node.add_child(anim_player)
		
	# Create navigation agent
	var navigation_agent = NavigationAgent3D.new()
	worker_node.add_child(navigation_agent)
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5
	
	# Initialize the worker script
	worker_node.initialize(model, anim_player, navigation_agent, target_position)
	
	# Introduce a tiny random delay before the worker reaches the construction site
	# This helps stagger the sound effects and make them more natural
	if worker_node.has_method("set_movement_speed"):
		# Randomize movement speed slightly to stagger arrivals 
		worker_node.set_movement_speed(randf_range(2.3, 2.7))
	
	return worker_node

# Signal handlers for worker construction sounds 
# Now needed ONLY for mission-triggering logic, not for sound
func _on_worker_construction_started():
	# Forward the signal for mission managers/other systems that need it
	# Workers now handle their own sounds independently
	worker_construction_started.emit()

# Signal handler for construction ended signals
# Now needed ONLY for mission-triggering logic, not for sound
func _on_worker_construction_ended():
	# Forward the signal for mission managers/other systems that need it
	worker_construction_ended.emit()

func update_population(count: int):
	Globals.set_population_count(count)
	


	
# Complete construction at a position
func _complete_construction(position: Vector3):
	print("\n=== Completing Construction Process ===")
	print("Position: ", position)
	
	if not position in construction_sites:
		print("ERROR: No construction site found at position!")
		return
		
	var site = construction_sites[position]
	print("Found construction site")
	
	# Verify the timer has reached the build time
	var build_time = CONSTRUCTION_TIME
	if site["structure_index"] >= 0 and site["structure_index"] < builder.structures.size():
		var structure = builder.structures[site["structure_index"]]
		if "build_time" in structure:
			build_time = structure.build_time
	
	if site["timer"] < build_time:
		print("WARNING: Construction completing before timer is done!")
		return
	
	# Mark as completed
	site["completed"] = true
	print("Marked as completed")
	
	# Stop worker and send back to a road
	if site["worker"] != null:
		print("Stopping worker")
		if site["worker"].has_method("finish_construction"):
			site["worker"].finish_construction()
		else:
			# If for some reason the method isn't found, clean up the worker
			site["worker"].queue_free()
			site["worker"] = null
	
	# Remove placeholder plot
	if site["plot"] != null:
		print("Removing plot")
		site["plot"].queue_free()
		site["plot"] = null
	
	# Place the final building
	print("Placing final building")
	_place_final_building(position, site["structure_index"])
	
	# Check if we should spawn a resident (only for residential buildings)
	var mission_manager = builder.get_node_or_null("/root/Main/MissionManager")
	var should_spawn_resident = false
	
	# Only spawn residents for residential buildings
	var structure = builder.structures[site["structure_index"]]
	if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
		should_spawn_resident = true
	
	# Spawn a resident from the new residential building if appropriate
	if should_spawn_resident:
		print("Spawning resident")
		_spawn_resident_from_building(position)
 	
	if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING and structure.population_count > 0:
		update_population(structure.population_count)
	
	# Emit completion signal
	print("Emitting completion signal")
	construction_completed.emit(position)
	
	# Remove from construction sites
	print("Removing from construction sites")
	construction_sites.erase(position)
	print("=== Construction Process Complete ===\n")

# Function to handle building demolition at a position
func handle_demolition(position: Vector3):
	# Check if this position has a construction site entry
	if position in construction_sites:
		# Clean up any resources
		var site = construction_sites[position]
		
		# Clean up plot if it exists
		if site["plot"] != null:
			site["plot"].queue_free()
			
		# Clean up worker if it exists
		if site["worker"] != null:
			site["worker"].queue_free()
			
		# Remove the entry from the dictionary
		construction_sites.erase(position)
		
	

# Place the final building at the construction site
func _place_final_building(position: Vector3, structure_index: int):
	print("\n=== Placing Final Building ===")
	print("Position: ", position)
	print("Structure Index: ", structure_index)
	
	# Create the final building using the actual selected structure model
	var building
	if structure_index >= 0 and structure_index < builder.structures.size():
		building = builder.structures[structure_index].model.instantiate()
		print("Created building using structure model: ", builder.structures[structure_index].model.resource_path)
	else:
		# Fallback to default building model
		building = final_building_scene.instantiate()
		print("Created building using fallback model")
	
	building.name = "Building_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Add to scene at the correct position and scale
	builder.add_child(building)
	building.global_transform.origin = position
	
	# Apply the saved rotation if available
	if position in construction_sites:
		var site = construction_sites[position]
		if "rotation_basis" in site and site["rotation_basis"]:
			building.basis = site["rotation_basis"]
	
	building.scale = Vector3(3.0, 3.0, 3.0)
	print("Added building to scene")
	
	# Add to gridmap for collision detection and mission tracking
	if builder.gridmap:
		print("Adding to gridmap")
		builder.gridmap.set_cell_item(position, structure_index, builder.gridmap.get_orthogonal_index_from_basis(building.basis))
	
	# Send placement_success dialog to learning companion if available in the current mission
	if mission_manager and mission_manager.current_mission and mission_manager.learning_companion_connected:
		var mission = mission_manager.current_mission
		
		# Check if we have dialog for successful placement
		if mission.companion_dialog.has("placement_success"):
			const JSBridge = preload("res://scripts/javascript_bridge.gd")
			if JSBridge.has_interface():
				var dialog_data = mission.companion_dialog["placement_success"]
				JSBridge.get_interface().sendCompanionDialog("placement_success", dialog_data)
		
		# For power plant mission (mission 5), check if we placed a power plant
		if structure_index >= 0 and structure_index < builder.structures.size():
			var structure = builder.structures[structure_index]
			if structure.model.resource_path.contains("power_plant") and mission.id == "5":
				const JSBridge = preload("res://scripts/javascript_bridge.gd")
				if JSBridge.has_interface() and mission.companion_dialog.has("placement_success"):
					var dialog_data = mission.companion_dialog["placement_success"]
					JSBridge.get_interface().sendCompanionDialog("placement_success", dialog_data)
			
				
			
# Make a model semi-transparent with outline effect
func _make_model_transparent(model: Node3D, alpha: float):
	# Load the construction preview shader material
	var preview_material = load("res://models/Materials/construction_preview.tres")
	if not preview_material:
		push_error("Failed to load construction preview material")
		return
		
	# Find all mesh instances
	var mesh_instances = []
	_find_all_mesh_instances(model, mesh_instances)
	
	# Apply the preview material to each mesh instance
	for mesh_instance in mesh_instances:
		var materials_count = mesh_instance.get_surface_override_material_count()
		
		for i in range(materials_count):
			# Clone the preview material to avoid affecting other instances
			var new_material = preview_material.duplicate()
			
			# Set the alpha value from the parameter
			new_material.set_shader_parameter("alpha", alpha)
			
			# Apply the material
			mesh_instance.set_surface_override_material(i, new_material)

# Spawn a resident from a newly constructed building
func _spawn_resident_from_building(position: Vector3):
	# Make sure we have a valid nav_region reference
	if not nav_region and builder and builder.nav_region:
		nav_region = builder.nav_region
		
	if not nav_region:
		return
	
	# Find a road to spawn near
	var road_position = _find_nearest_road(position)
	if road_position == Vector3.ZERO:
		road_position = position + Vector3(0, 0, 1) # Fallback to in front of the building
	
	# Use the pre-made character pathing scene (the same one that works in mission 1)
	var character_scene = load("res://scenes/character_pathing.tscn")
	if not character_scene:
		return
		
	var resident = character_scene.instantiate()
	resident.name = "Resident_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Make sure the script is set correctly (the same script that works in mission 1)
	resident.set_script(load("res://scripts/NavigationNPC.gd"))
	
	# Add to a group for management
	resident.add_to_group("characters")
	
	# Add to the nav_region and position correctly
	nav_region.add_child(resident)
	resident.global_transform.origin = Vector3(road_position.x, 0.1, road_position.z)
	
	# Set collision shape
	if resident.has_node("CollisionShape3D"):
		var collision = resident.get_node("CollisionShape3D")
		var capsule_shape = CapsuleShape3D.new()
		capsule_shape.radius = 0.3
		capsule_shape.height = 1.0
		collision.shape = capsule_shape
	
	# Make sure the navigation agent is configured correctly
	if resident.has_node("NavigationAgent3D"):
		var nav_agent = resident.get_node("NavigationAgent3D")
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		
		# Calculate a target position
		var target_position = _find_random_road()
		if target_position == Vector3.ZERO:
			target_position = position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
			
		# Set the target
		nav_agent.set_target_position(target_position)
	
	# Use a timer to give the system time to initialize
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(func():
		# Start the character moving after initialization
		if resident:
			if resident.has_method("set_movement_target"):
				var target_position = _find_random_road()
				if target_position == Vector3.ZERO:
					target_position = position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
					
				resident.set_movement_target(target_position)
			
			if resident.has_method("_start_initial_movement"):
				# Call deferred to ensure the navigation system is ready
				resident.call_deferred("_start_initial_movement")
	)

# Find a random road to use as a target
func _find_random_road() -> Vector3:
	var roads = []
	
	# Check if we have a valid navigation region
	if not nav_region and builder and builder.nav_region:
		nav_region = builder.nav_region
	
	if nav_region:
		# Collect all road nodes
		for child in nav_region.get_children():
			if child.name.begins_with("Road_"):
				# Extract position from the road name (format: "Road_X_Z")
				var pos_parts = child.name.split("_")
				if pos_parts.size() >= 3:
					var road_x = int(pos_parts[1])
					var road_z = int(pos_parts[2])
					var road_pos = Vector3(road_x, 0, road_z)
					roads.append(road_pos)
	
	# Pick a random road
	if not roads.is_empty():
		return roads[randi() % roads.size()]
	
	# Fallback to a zero position if no roads found
	return Vector3.ZERO

# Create the resident script if it doesn't exist
func _create_resident_script():
	var script_content = """extends Node3D

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

func _physics_process(delta: float):
	if is_moving:
		if nav_agent.is_navigation_finished():
			# Reached destination, start waiting
			is_moving = false
			wait_timer = 0.0
			
			# Play idle animation
			if animation_player and animation_player.has_animation("idle"):
				animation_player.play("idle")
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
		return home_position
	
	# Pick a random road
	if not roads.is_empty():
		return roads[randi() % roads.size()]
	
	# Fallback to home position if no roads found
	return home_position
"""
	
	# Create the file with the script content
	var file = FileAccess.open("res://scripts/mission/resident_character.gd", FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()

# Helper to find all MeshInstance3D nodes
func _find_all_mesh_instances(node: Node, result: Array):
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		_find_all_mesh_instances(child, result)
