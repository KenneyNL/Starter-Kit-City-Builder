extends Node
class_name BuildingConstructionManager

signal construction_completed(position)
signal worker_construction_started
signal worker_construction_ended

const CONSTRUCTION_TIME = 10.0 # seconds to build a building

# References to necessary scenes and resources
var worker_scene: PackedScene
var nav_region: NavigationRegion3D
var builder: Node3D
var building_plot_scene: PackedScene
var final_building_scene: PackedScene

# Keep track of all construction sites
var construction_sites = {}  # position (Vector3) -> construction data (dict)

func _ready():
	# Load the worker character scene - add more fallbacks to ensure we get a valid model
	worker_scene = load("res://people/character-male-a.glb")
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

# Call this method to start construction at a position
func start_construction(position: Vector3, structure_index: int, rotation_basis = null):
	if position in construction_sites:
		return
	
	# Get the current selector rotation if available
	var rotation_index = 0
	if builder and builder.selector:
		# Convert the selector's basis to a GridMap orientation index
		if rotation_basis == null:
			rotation_basis = builder.selector.basis
		
		if builder.gridmap:
			rotation_index = builder.gridmap.get_orthogonal_index_from_basis(rotation_basis)
	
	# Create a construction site entry
	construction_sites[position] = {
		"position": position,
		"structure_index": structure_index,
		"plot": null,
		"worker": null,
		"timer": 0.0,
		"completed": false,
		"rotation_index": rotation_index,  # Store the rotation for later use
		"rotation_basis": rotation_basis   # Store the rotation basis
	}
	
	# Place plot marker (outline/transparent version of the building)
	var plot = building_plot_scene.instantiate()
	plot.name = "Plot_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Make it a transparent outline by applying transparency to all materials
	_make_model_transparent(plot, 0.3)  # More transparent (0.3 instead of 0.5)
	
	# Add to the scene and position it
	builder.add_child(plot)
	plot.global_transform.origin = position
	
	# Apply the rotation from the selector to the plot
	if rotation_basis:
		plot.basis = rotation_basis
	
	plot.scale = Vector3(3.0, 3.0, 3.0)  # Scale to match other buildings
	
	# Store reference
	construction_sites[position]["plot"] = plot
	
	# Find a road position to spawn the worker
	_spawn_worker_for_construction(position)
	
	# Send building_selected dialog to learning companion if available in the current mission
	var mission_manager = builder.get_node_or_null("/root/Main/MissionManager")
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
	
	# Update all construction sites
	for pos in construction_sites.keys():
		var site = construction_sites[pos]
		
		# Skip completed sites
		if site["completed"]:
			continue
			
		# Update timer for active sites
		if site["worker"] != null and site["worker"].is_construction_active:
			site["timer"] += delta
			
			# Check if construction is complete
			if site["timer"] >= CONSTRUCTION_TIME:
				sites_to_complete.append(pos)
	
	# Complete construction for sites that are done
	for pos in sites_to_complete:
		_complete_construction(pos)

# Find a road and spawn a worker there
func _spawn_worker_for_construction(target_position: Vector3):
	# Find closest road tile
	var road_position = _find_nearest_road(target_position)
	
	if road_position == Vector3.ZERO:
		return
		
	# Create the worker
	var worker = _create_worker(road_position, target_position)
	
	# Store in the construction site data
	construction_sites[target_position]["worker"] = worker

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

# Complete construction at a position
func _complete_construction(position: Vector3):
	if not position in construction_sites:
		return
		
	var site = construction_sites[position]
	
	# Mark as completed
	site["completed"] = true
	
	# Remove placeholder plot
	if site["plot"] != null:
		site["plot"].queue_free()
		site["plot"] = null
	
	# Stop worker and send back to a road
	if site["worker"] != null:
		if site["worker"].has_method("finish_construction"):
			site["worker"].finish_construction()
		else:
			# If for some reason the method isn't found, clean up the worker
			site["worker"].queue_free()
			site["worker"] = null
	
	# Place the final building
	_place_final_building(position, site["structure_index"])
	
	# Update mission objective now that construction is complete
	_update_mission_objective_on_completion(site["structure_index"])
	
	# Check if we should spawn a resident
	var mission_manager = builder.get_node_or_null("/root/Main/MissionManager")
	var should_spawn_resident = true
	
	# Don't spawn a resident for the first building in mission 1
	# (let the mission manager handle that case to avoid double spawning)
	if mission_manager and mission_manager.current_mission and mission_manager.current_mission.id == "1" and !mission_manager.character_spawned:
		should_spawn_resident = false
	
	# Spawn a resident from the new building (except for first building in mission 1)
	if should_spawn_resident:
		_spawn_resident_from_building(position)
		
	# Update population in the HUD when construction is complete
	# Try different possible paths to find the HUD
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	
	# If not found, try to find it by group (we added the HUD to "hud" group)
	if not hud:
		var hud_nodes = get_tree().get_nodes_in_group("hud")
		if hud_nodes.size() > 0:
			hud = hud_nodes[0]
	
	# If not found, try other common paths
	if not hud:
		var scene_root = get_tree().get_root()
		for child in scene_root.get_children():
			if child.name == "Main":
				if child.has_node("CanvasLayer/HUD"):
					hud = child.get_node("CanvasLayer/HUD")
					break
	
	# Last resort - try to find using builder's cash_display
	if not hud and builder and builder.cash_display:
		var parent = builder.cash_display.get_parent()
		while parent and parent.get_parent():
			if "HUD" in parent.name:
				hud = parent
				break
			parent = parent.get_parent()
	
	if hud and site["structure_index"] >= 0 and site["structure_index"] < builder.structures.size():
		var structure = builder.structures[site["structure_index"]]
		
		if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING and structure.population_count > 0:
			hud.total_population += structure.population_count
			hud.update_hud()
			hud.population_updated.emit(hud.total_population)
	
	# Emit completion signal
	construction_completed.emit(position)

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

# Function to update mission objective when construction is complete
func _update_mission_objective_on_completion(structure_index: int):
	# Get reference to mission manager
	var mission_manager = builder.get_node_or_null("/root/Main/MissionManager")
	
	if mission_manager and mission_manager.current_mission:
		# Check if this is a residential building
		if structure_index >= 0 and structure_index < builder.structures.size():
			var structure = builder.structures[structure_index]
			
			if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
				# For mission 3, we'll rely on the fix_mission.gd script to maintain an accurate count
				# This prevents double counting, as we just need to make sure buildings are counted
				# based on their actual presence in the scene
				if mission_manager.current_mission.id == "3":
					# Instead of directly updating, we'll wait for the fix script to apply the proper count
					pass
				
				# Special handling for mission 1
				elif mission_manager.current_mission.id == "1":
					# For mission 1, we need to make sure the objectives are updated
					mission_manager.update_objective_progress(
						mission_manager.current_mission.id,
						MissionObjective.ObjectiveType.BUILD_RESIDENTIAL
					)
					
					# Trigger an immediate progress check
					mission_manager.check_mission_progress(mission_manager.current_mission.id)

# Place the final building at the construction site
func _place_final_building(position: Vector3, structure_index: int):
	# Create the final building
	var building = final_building_scene.instantiate()
	building.name = "Building_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Add to scene at the correct position and scale
	builder.add_child(building)
	building.global_transform.origin = position
	
	# Apply the saved rotation if available
	if position in construction_sites:
		var site = construction_sites[position]
		if "rotation_basis" in site and site["rotation_basis"]:
			building.basis = site["rotation_basis"]
	
	building.scale = Vector3(3.0, 3.0, 3.0)  # Scale to match other buildings
	
	# Send placement_success dialog to learning companion if available in the current mission
	var mission_manager = builder.get_node_or_null("/root/Main/MissionManager")
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
	# Find all mesh instances
	var mesh_instances = []
	_find_all_mesh_instances(model, mesh_instances)
	
	# Adjust the materials for each mesh instance
	for mesh_instance in mesh_instances:
		var materials_count = mesh_instance.get_surface_override_material_count()
		
		for i in range(materials_count):
			var material = mesh_instance.get_surface_override_material(i)
			if not material:
				# If no override material, try to get the mesh material
				if mesh_instance.mesh and i < mesh_instance.mesh.get_surface_count():
					material = mesh_instance.mesh.surface_get_material(i)
			
			if material:
				# Clone the material to avoid affecting other instances
				var new_material = material.duplicate()
				
				# Set up transparency
				new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				new_material.albedo_color.a = alpha
				
				# Make it look more like an outline/hologram
				new_material.emission_enabled = true
				new_material.emission = Color(0.2, 0.5, 0.8, 1.0)  # Light blue emission
				new_material.emission_energy = 0.5
				
				# Optional: add a subtle outline effect
				if new_material is StandardMaterial3D:
					new_material.outline_enabled = true
					new_material.outline_width = 3.0
					new_material.outline_color = Color(0.0, 0.6, 1.0)
				
				# Apply modified material
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