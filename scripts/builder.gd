extends Node3D

@export var structures: Array[Structure] = []

var map:DataMap

var index:int = 0 # Index of structure being built
var nav_region: NavigationRegion3D # Single navigation region for all roads

# Construction manager for building residential buildings with workers
var construction_manager: BuildingConstructionManager

# Create construction manager in _ready function

# Structure selection sound effect is now handled in game_manager.gd

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var cash_display:Label # Reference to cash label in HUD
var hud_manager: Node

var plane:Plane # Used for raycasting mouse
var disabled: bool = false # Used to disable building functionality

signal structure_placed(structure_index, position) # For our mission flow

func _ready():
	
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	hud_manager = get_node_or_null("/root/Main/CanvasLayer/HUD")
	
	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html
	
	var mesh_library = MeshLibrary.new()
	
	# Setup the navigation region if it doesn't exist
	setup_navigation_region()
	
	# Setup construction manager
	construction_manager = BuildingConstructionManager.new()
	construction_manager.name = "BuildingConstructionManager"  # Set a proper node name
	add_child(construction_manager)
	
	# Connect to the construction completion signal
	construction_manager.construction_completed.connect(_on_construction_completed)
	
	# Give the construction manager references it needs
	construction_manager.builder = self
	construction_manager.nav_region = nav_region
	
	# Sound effects now handled in game_manager.gd
	
	for structure in structures:
		
		var id = mesh_library.get_last_unused_item_id()
		
		mesh_library.create_item(id)
		mesh_library.set_item_mesh(id, get_mesh(structure.model))
		
		# Apply appropriate scaling for buildings and roads
		var transform = Transform3D()
		if structure.model.resource_path.contains("power_plant"):
			# Scale power plant model to be much smaller (0.5x)
			transform = transform.scaled(Vector3(0.5, 0.5, 0.5))
		else:
			# Scale buildings and roads to be consistent (3x)
			transform = transform.scaled(Vector3(3.0, 3.0, 3.0))
		
		mesh_library.set_item_mesh_transform(id, transform)
		
	gridmap.mesh_library = mesh_library
	
	# Ensure we start with an unlocked structure
	var found_unlocked = false
	for i in range(structures.size()):
		if "unlocked" in structures[i] and structures[i].unlocked:
			index = i
			found_unlocked = true
			print("Starting with unlocked structure: " + structures[i].model.resource_path)
			break
	
	if not found_unlocked:
		print("WARNING: No unlocked structures found at start!")
	
	update_structure()
	update_cash()

func _process(delta):
	# Skip all building functionality if disabled or game is paused
	if disabled or get_tree().paused:
		# Hide selector when disabled or paused
		if selector.visible:
			selector.visible = false
		return
		
	# Make sure selector is visible
	if !selector.visible:
		selector.visible = true
	
	# Controls
	action_rotate() # Rotates selection 90 degrees
	action_structure_toggle() # Toggles between structures
	
	action_save() # Saving
	action_load() # Loading
	
	# Map position based on mouse
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))

	var gridmap_position = Vector3(round(world_position.x), 0, round(world_position.z))
	selector.position = lerp(selector.position, gridmap_position, delta * 40)
	
	action_build(gridmap_position)
	action_demolish(gridmap_position)

# Function to check if the mouse is over any UI elements
func is_mouse_over_ui() -> bool:
	# Get mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Let's try an extremely simple approach - just check coordinates
	# most HUDs are at top of screen
	if mouse_pos.y < 100:
		# Mouse is likely in the HUD area at top of screen
		return true
	
	# Get HUD dimensions for debug
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	if hud:
		var hud_rect = hud.get_global_rect()
		
		# Get HBoxContainer dimensions - this is the actual content area
		var hbox = hud.get_node_or_null("HBoxContainer")
		if hbox:
			var hbox_rect = hbox.get_global_rect()
			
			# Simple approach - just check if within actual HUD content area
			if hbox_rect.has_point(mouse_pos):
				return true
		
		# Skip the complex recursion for now since it's not working
		
	# Check mission panel
	var mission_panel = get_node_or_null("/root/Main/MissionManager/MissionPanel")
	if mission_panel and mission_panel.visible:
		var panel_rect = mission_panel.get_global_rect()
		if panel_rect.has_point(mouse_pos):
			return true
	
	# Check learning panel too
	var learning_panel = get_node_or_null("/root/Main/MissionManager/LearningPanel")
	if learning_panel and learning_panel.visible:
		var panel_rect = learning_panel.get_global_rect()
		if panel_rect.has_point(mouse_pos):
			return true
	
	# Check controls panel
	var controls_panel = get_node_or_null("/root/Main/CanvasLayer/ControlsPanel")
	if controls_panel and controls_panel.visible:
		var panel_rect = controls_panel.get_global_rect()
		if panel_rect.has_point(mouse_pos):
			return true
	
	return false

# Retrieve the mesh from a PackedScene, used for dynamically creating a MeshLibrary

func get_mesh(packed_scene):
	# Instantiate the scene to access its properties
	var scene_instance = packed_scene.instantiate()
	var mesh_instance = null
	
	# Find the first MeshInstance3D in the scene
	for child in scene_instance.get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break
	
	# If no direct child is a MeshInstance3D, search recursively
	if mesh_instance == null:
		mesh_instance = find_mesh_instance(scene_instance)
	
	var mesh = null
	if mesh_instance:
		mesh = mesh_instance.mesh.duplicate()
	
	# Clean up
	scene_instance.queue_free()
	
	return mesh

# Helper function to find a MeshInstance3D recursively
func find_mesh_instance(node):
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		
		var result = find_mesh_instance(child)
		if result:
			return result
	
	return null

# Build (place) a structure

func action_build(gridmap_position):
	if Input.is_action_just_pressed("build"):
		# Check if the mouse is over any UI elements before building
		if is_mouse_over_ui():
			return
			
		# Check if the current structure is unlocked before allowing placement
		if "unlocked" in structures[index] and not structures[index].unlocked:
			print("Cannot build locked structure: " + structures[index].model.resource_path)
			return
		
		var previous_tile = gridmap.get_cell_item(gridmap_position)
		
		# For roads, we don't add to the gridmap, but still track it in our data
		var is_road = structures[index].type == Structure.StructureType.ROAD
		# For residential buildings, we use the construction manager in mission 3
		var is_residential = structures[index].type == Structure.StructureType.RESIDENTIAL_BUILDING
		# For power plants, we handle them specially
		var is_power_plant = structures[index].model.resource_path.contains("power_plant")
			# For grass and trees (terrain), we need special handling
		var is_terrain = structures[index].type == Structure.StructureType.TERRAIN
		
		# Check if we're in mission 3 (when we should use construction workers)
		var use_worker_construction = true
		var mission_manager = get_node_or_null("/root/Main/MissionManager")
		# Sound effects are handled via game_manager.gd through the structure_placed signal
		
		if is_road:
			# For roads, we'll need to track in our data without using the GridMap
			# But for now, we won't add it to the GridMap visually, just add to NavRegion3D
			
			# If there's already a road at this position, we need to clear it
			if previous_tile >= 0 and previous_tile < structures.size() and structures[previous_tile].type == Structure.StructureType.ROAD:
				# Remove any existing road 
				_remove_road_from_navregion(gridmap_position)
			
			# Create a visible road model as a child of the NavRegion3D
			_add_road_to_navregion(gridmap_position, index)
			
			# Rebake the navigation mesh after adding the road
			rebake_navigation_mesh()
			
			# Make sure any existing NPCs are children of the navigation region
			_move_characters_to_navregion()
		elif is_power_plant:
			#add_power_plant(gridmap_position, index)
			
			# We still set the cell item for collision detection
			gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
		elif is_terrain:
			# Special handling for terrain (grass and trees)
			_add_terrain(gridmap_position, index)
			
			# We still set the cell item for collision detection
			gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
		elif is_residential and use_worker_construction:
			# For residential buildings in mission 3, use construction workers
			# Pass the current selector basis to preserve rotation
			var selector_basis = selector.basis
			construction_manager.start_construction(gridmap_position, index, selector_basis)
			
			# Don't place the building immediately - it will be placed when construction completes
			# We leave gridmap empty for now
			
			# For mission 3, don't update objectives immediately - wait for construction to finish
			# See _update_mission_objective_on_completion in building_construction_manager.gd
		else:
			# For non-road structures or not in mission 3, add to the gridmap as usual
			gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
		
		if previous_tile != index:
			map.cash -= structures[index].price
			update_cash()
			
			# Emit the signal that a structure was placed
			structure_placed.emit(index, gridmap_position)

func setup_navigation_region():
	# Create a single NavigationRegion3D for the entire map if it doesn't exist
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavRegion3D"
		
		# Create and assign a NavigationMesh resource
		var nav_mesh = NavigationMesh.new()
		nav_region.navigation_mesh = nav_mesh
		
		# Configure NavigationMesh parameters for our roads
		nav_mesh.cell_size = 0.25
		nav_mesh.cell_height = 0.25
		nav_mesh.agent_height = 1.5
		nav_mesh.agent_radius = 0.25
		
		add_child(nav_region)
		

# Sound effects are now handled in game_manager.gd


# Rebake navigation mesh to update the navigation data
func rebake_navigation_mesh():
	# Make sure we have a navigation region first
	if not nav_region:
		setup_navigation_region()
	
	# Bake the navigation mesh for the entire map
	nav_region.bake_navigation_mesh()

# Demolish (remove) a structure

signal structure_removed(structure_index, position)

func action_demolish(gridmap_position):
	if Input.is_action_just_pressed("demolish"):
		# Check if the mouse is over any UI elements
		if is_mouse_over_ui():
			return
			
		# Check if there's a road at this position
		var is_road = false
		var road_name = "Road_" + str(int(gridmap_position.x)) + "_" + str(int(gridmap_position.z))
		
		if nav_region and nav_region.has_node(road_name):
			is_road = true
		
		# Check if there's a power plant at this position
		var is_power_plant = false
		var power_plant_name = "PowerPlant_" + str(int(gridmap_position.x)) + "_" + str(int(gridmap_position.z))
		
		if has_node(power_plant_name):
			is_power_plant = true
			
		# Check if there's terrain at this position
		var is_terrain = false
		var terrain_name = "Terrain_" + str(int(gridmap_position.x)) + "_" + str(int(gridmap_position.z))
		
		if has_node(terrain_name):
			is_terrain = true
		
		# Or check the GridMap for non-road structures
		var current_item = gridmap.get_cell_item(gridmap_position)
		var is_building = current_item >= 0
		
		# Check for building model in the scene as a direct child of builder
		var building_model_name = "Building_" + str(int(gridmap_position.x)) + "_" + str(int(gridmap_position.z))
		var has_building_model = has_node(building_model_name)
		
		# Store structure index before removal for signaling
		var structure_index = -1
		
		# Clean up any construction site at this position before demolishing
		if construction_manager and is_building:
			construction_manager.handle_demolition(gridmap_position)
		
		# Remove the appropriate item
		if is_road:
			# Find the road structure index
			for i in range(structures.size()):
				if structures[i].type == Structure.StructureType.ROAD:
					structure_index = i
					break
					
			# Remove the road model from the NavRegion3D
			_remove_road_from_navregion(gridmap_position)
			# Rebake the navigation mesh after removing the road
			rebake_navigation_mesh()
			# Make sure any existing NPCs are children of the navigation region
			_move_characters_to_navregion()
		elif is_power_plant:
			# Find the power plant structure index
			for i in range(structures.size()):
				if structures[i].type == Structure.StructureType.POWER_PLANT:
					structure_index = i
					break
					
			# Remove the power plant model
			_remove_power_plant(gridmap_position)
			# Also remove from gridmap
			gridmap.set_cell_item(gridmap_position, -1)
		elif is_terrain:
			# Find the terrain structure index
			for i in range(structures.size()):
				if structures[i].type == Structure.StructureType.TERRAIN:
					structure_index = i
					break
					
			# Remove the terrain model
			_remove_terrain(gridmap_position)
			# Also remove from gridmap
			gridmap.set_cell_item(gridmap_position, -1)
		elif is_building:
			# Get the structure index from the gridmap
			structure_index = current_item
			# Remove the building from the gridmap
			gridmap.set_cell_item(gridmap_position, -1)
			
			# Also remove any direct building model in the scene
			_remove_building_model(gridmap_position)
			
			# Check if this was a residential building to remove a resident model
			if structures[structure_index].type == Structure.StructureType.RESIDENTIAL_BUILDING:
				_remove_resident_for_building(gridmap_position)
		
		# Emit signal that structure was removed
		if structure_index >= 0:
			structure_removed.emit(structure_index, gridmap_position)
			
			# For mission 3, update mission objective when a residential building is demolished
			if structures[structure_index].type == Structure.StructureType.RESIDENTIAL_BUILDING:
				_update_mission_objective_on_demolish()
			
# This function is no longer needed since we're using a single NavRegion3D
# Keeping it for compatibility, but it doesn't do anything now
func remove_navigation_region(position: Vector3):
	# With our new approach using a single nav region, we just rebake
	# the entire navigation mesh when roads are added or removed

	rebake_navigation_mesh()

# Rotates the 'cursor' 90 degrees

func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.rotate_y(deg_to_rad(90))

# Toggle between structures to build

func action_structure_toggle():
	if Input.is_action_just_pressed("structure_next"):
		# Find the next unlocked structure
		var next_index = index
		var tried_indices = []
		
		while tried_indices.size() < structures.size():
			next_index = wrap(next_index + 1, 0, structures.size())
			if tried_indices.has(next_index):
				break  # We've already tried this index, avoid infinite loop
			
			tried_indices.append(next_index)
			
			# Check if this structure is unlocked
			if "unlocked" in structures[next_index] and structures[next_index].unlocked:
				index = next_index
				break
	
	if Input.is_action_just_pressed("structure_previous"):
		# Find the previous unlocked structure
		var prev_index = index
		var tried_indices = []
		
		while tried_indices.size() < structures.size():
			prev_index = wrap(prev_index - 1, 0, structures.size())
			if tried_indices.has(prev_index):
				break  # We've already tried this index, avoid infinite loop
			
			tried_indices.append(prev_index)
			
			# Check if this structure is unlocked
			if "unlocked" in structures[prev_index] and structures[prev_index].unlocked:
				index = prev_index
				break

	update_structure()

# Update the structure visual in the 'cursor'
func update_structure():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		
	# Create new structure preview in selector
	var _model = structures[index].model.instantiate()
	selector_container.add_child(_model)
	
	# Get reference to the selector sprite
	var selector_sprite = selector.get_node("Sprite")
	
	# Apply appropriate scaling based on structure type
	if structures[index].model.resource_path.contains("power_plant"):
		# Scale power plant model to be much smaller (0.5x)
		_model.scale = Vector3(0.5, 0.5, 0.5)
		# Center the power plant model within the selector
		_model.position = Vector3(-3.0, 0.0, 3.0)  # Reset position
	else:
		# Scale buildings, roads, and decorative terrain to match (3x)
		_model.scale = Vector3(3.0, 3.0, 3.0)
		_model.position.y += 0.0 # No need for Y adjustment with scaling
	
	# Get the selector scale from the structure resource
	var scale_factor = structures[index].selector_scale
	selector_sprite.scale = Vector3(scale_factor, scale_factor, scale_factor)
		
	# Sound effects are now handled in game_manager.gd
	
func update_cash():
	cash_display.text = "$" + str(map.cash)
	
# Function to add a road model as a child of the navigation region
func _add_road_to_navregion(position: Vector3, structure_index: int):
	# Make sure we have a navigation region
	if not nav_region:
		setup_navigation_region()
		
	# Create a unique name for this road based on its position
	var road_name = "Road_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Check if a road with this name already exists
	if nav_region.has_node(road_name):
		return
	
	# Instantiate the road model - get the actual model based on road type
	var road_model
	var model_path = structures[structure_index].model.resource_path
	if model_path.contains("road-straight"):
		# Use the specific road-straight model that works with navmesh
		road_model = load("res://models/road-straight.glb").instantiate()
	elif model_path.contains("road-corner"):
		# Use the specific road-corner model
		road_model = load("res://models/road-corner.glb").instantiate()
	else:
		# Fall back to the structure's model for other road types
		road_model = structures[structure_index].model.instantiate()
	
	road_model.name = road_name
	
	# Add the road model to the NavRegion3D
	nav_region.add_child(road_model)
	
	# Create the transform directly matching the exact one from pathing.tscn
	var transform = Transform3D()
	
	# Set scale first
	transform.basis = Basis().scaled(Vector3(3.0, 3.0, 3.0))
	
	# Then apply rotation from the selector to preserve the rotation the player chose
	transform.basis = transform.basis * selector.basis
	
	# Set position
	transform.origin = position
	transform.origin.y = -0.065  # From the pathing scene y offset
	
	# Apply the complete transform in one go
	road_model.transform = transform
	


# Function to add a power plant as a direct child of the builder
func _add_power_plant(position: Vector3, structure_index: int):
	# Create a unique name for this power plant based on its position
	var power_plant_name = "PowerPlant_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Check if a power plant with this name already exists
	if has_node(power_plant_name):
		return
	
	# Instantiate the power plant model
	var power_plant_model = structures[structure_index].model.instantiate()
	power_plant_model.name = power_plant_name
	
	# Add the power plant model directly to the builder (this node)
	add_child(power_plant_model)
	
	# Create the transform
	var transform = Transform3D()
	
	# Set scale (using the smaller 0.5x scale)
	transform.basis = Basis().scaled(Vector3(0.5, 0.5, 0.5))
	
	# Apply rotation from the selector to preserve the rotation the player chose
	transform.basis = transform.basis * selector.basis
	
	# Set position with offset to center the model at the grid position
	transform.origin = position
	
	# Apply position offset to center the model (matching the preview)
	# These offsets need to be transformed based on the current rotation
	var offset = selector.basis * Vector3(0.25, 0, -0.25)
	transform.origin += offset
	
	# Apply the complete transform in one go
	power_plant_model.transform = transform
	

# Function to remove a power plant
func _remove_power_plant(position: Vector3):
	# Get the power plant name based on its position
	var power_plant_name = "PowerPlant_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Check if a power plant with this name exists
	if has_node(power_plant_name):
		# Get the power plant and remove it
		var power_plant = get_node(power_plant_name)
		power_plant.queue_free()
		
	else:
		# No power plant found
		pass

# Function to remove a resident model when a residential building is demolished
func _remove_resident_for_building(position: Vector3):
	# First, check if we have a nav region reference
	if not nav_region and has_node("NavRegion3D"):
		nav_region = get_node("NavRegion3D")
	
	if nav_region:
		# Look for resident with matching position in the name
		var resident_name = "Resident_" + str(int(position.x)) + "_" + str(int(position.z))
		
		# First try to find by exact name
		var found = false
		for child in nav_region.get_children():
			if child.name.begins_with(resident_name):
				child.queue_free()
				found = true
				
				# Update the HUD population count
				var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
				if hud:
					_on_update_population(-1)
				
				break
				
func _on_update_population(count: int):
	hud_manager.population_updated.emit(count)
# Function to update mission objectives when residential building is demolished
func _update_mission_objective_on_demolish():
	# Get reference to mission manager
	var mission_manager = get_node_or_null("/root/Main/MissionManager")
	
	if mission_manager and mission_manager.current_mission:
			# For other missions, use the normal method
			var mission_id = mission_manager.current_mission.id
			mission_manager.update_objective_progress(mission_id, MissionObjective.ObjectiveType, -1)
		
# Function to remove terrain (grass or trees)
func _remove_terrain(position: Vector3):
	# Get the terrain name based on its position
	var terrain_name = "Terrain_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Check if terrain with this name exists
	if has_node(terrain_name):
		# Get the terrain and remove it
		var terrain = get_node(terrain_name)
		terrain.queue_free()
	else:
		# No terrain found
		pass

# Function to remove building model from scene
func _remove_building_model(position: Vector3):
	# Try multiple possible naming patterns
	var building_patterns = [
		"Building_" + str(int(position.x)) + "_" + str(int(position.z)),
		"building-small-a_" + str(int(position.x)) + "_" + str(int(position.z)),
		"building-small-b_" + str(int(position.x)) + "_" + str(int(position.z)),
		"building-small-c_" + str(int(position.x)) + "_" + str(int(position.z)),
		"building-small-d_" + str(int(position.x)) + "_" + str(int(position.z)),
		"building-garage_" + str(int(position.x)) + "_" + str(int(position.z))
	]
	
	# Check if we can find the building model with any of the pattern names
	var found = false
	for pattern in building_patterns:
		if has_node(pattern):
			# Get the building and remove it
			var building = get_node(pattern)
			building.queue_free()
			found = true
			break
	
	# If not found as direct child, try to find by position in navigation region
	if !found and nav_region:
		for child in nav_region.get_children():
			# Skip non-building nodes
			if !child.name.begins_with("Building") and !child.name.begins_with("building"):
				continue
				
			# Check if this building is at our position (with some tolerance)
			var pos_diff = (child.global_transform.origin - position).abs()
			if pos_diff.x < 0.5 and pos_diff.z < 0.5:
				child.queue_free()
				found = true
				break
	
	# If still not found, search the entire scene
	if !found:
		var main = get_node_or_null("/root/Main")
		if main:
			for child in main.get_children():
				# Skip non-building nodes
				if !child.name.begins_with("Building") and !child.name.begins_with("building"):
					continue
					
				# Check if this building is at our position (with some tolerance)
				var pos_diff = (child.global_transform.origin - position).abs()
				if pos_diff.x < 0.5 and pos_diff.z < 0.5:
					child.queue_free()
					found = true
					break
	
	# If STILL not found, try one last approach - scan for gridmap children
	if !found and gridmap:
		for child in gridmap.get_children():
			# Check if this is any model at our position (with some tolerance)
			var pos_diff = (child.global_transform.origin - position).abs()
			if pos_diff.x < 0.5 and pos_diff.z < 0.5:
				child.queue_free()
				found = true
				break

# Function to remove a road model from the navigation region
func _remove_road_from_navregion(position: Vector3):
	# Make sure we have a navigation region
	if not nav_region:
		return
		
	# Get the road name based on its position
	var road_name = "Road_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Check if a road with this name exists
	if nav_region.has_node(road_name):
		# Get the road and remove it
		var road = nav_region.get_node(road_name)
		road.queue_free()
	else:
		# No road found
		pass
		
# Function to add all existing roads to the navigation region
func _add_existing_roads_to_navregion():
	# Make sure we have a navigation region
	if not nav_region:
		setup_navigation_region()
		
	# Clean up any existing road models in the navigation region
	for child in nav_region.get_children():
		if child.name.begins_with("Road_"):
			child.queue_free()
	
	# Find all road cells in the gridmap
	var added_count = 0
	
	# We need to convert any existing roads in the GridMap to our new system
	# Find existing road cells and add them to the NavRegion3D, then clear from GridMap
	for cell in gridmap.get_used_cells():
		var structure_index = gridmap.get_cell_item(cell)
		if structure_index >= 0 and structure_index < structures.size():
			if structures[structure_index].type == Structure.StructureType.ROAD:
				# Add this road to the NavRegion3D
				_add_road_to_navregion(cell, structure_index)
				# Remove from the GridMap since we're now handling roads differently
				gridmap.set_cell_item(cell, -1)
				added_count += 1
				
# Function to move all character NPCs to be children of the navigation region
func _move_characters_to_navregion():
	# Make sure we have a navigation region
	if not nav_region:
		setup_navigation_region()
		
	# Find all characters in the scene
	var characters = get_tree().get_nodes_in_group("characters")
	for character in characters:
		# Skip if already a child of nav_region
		if character.get_parent() == nav_region:
			continue
			
		# Get current global position and parent
		var original_parent = character.get_parent()
		var global_pos = character.global_transform.origin
		
		# Reparent to the navigation region
		if original_parent:
			original_parent.remove_child(character)
		nav_region.add_child(character)
		
		# Restore global position
		character.global_transform.origin = global_pos
	

# Function to add terrain (grass or trees) as a direct child
func _add_terrain(position: Vector3, structure_index: int):
	# Create a unique name for this terrain element based on its position
	var terrain_name = "Terrain_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Check if terrain with this name already exists
	if has_node(terrain_name):
		return
	
	# Instantiate the terrain model
	var terrain_model = structures[structure_index].model.instantiate()
	terrain_model.name = terrain_name
	
	# Add the terrain model directly to the builder (this node)
	add_child(terrain_model)
	
	# Create the transform
	var transform = Transform3D()
	
	# Set scale (using 3.0 scale as per other terrain elements)
	transform.basis = Basis().scaled(Vector3(3.0, 3.0, 3.0))
	
	# Apply rotation from the selector to preserve the rotation the player chose
	transform.basis = transform.basis * selector.basis
	
	# Set position
	transform.origin = position
	
	# Apply the complete transform in one go
	terrain_model.transform = transform

# Callback for when construction is completed
func _on_construction_completed(position: Vector3):
	# We need to find a residential structure index to add to gridmap
	var residential_index = -1
	for i in range(structures.size()):
		if structures[i].type == Structure.StructureType.RESIDENTIAL_BUILDING:
			residential_index = i
			break
	
	if residential_index >= 0:
		# Get the rotation index from the construction manager if available
		var rotation_index = 0
		
		# Try to get the rotation index from the construction manager
		if construction_manager and construction_manager.construction_sites.has(position):
			var site = construction_manager.construction_sites[position]
			if site.has("rotation_index"):
				rotation_index = site["rotation_index"]
			
		
		# Add the completed residential building to the gridmap with the correct rotation
		gridmap.set_cell_item(position, residential_index, rotation_index)
		
		# Check if we need to spawn a character for mission 1
		var mission_manager = get_node_or_null("/root/Main/MissionManager")
		if mission_manager:
			# We DON'T re-emit the structure_placed signal here, because we already
			# emitted it when construction started in action_build()
			# This prevents double-counting buildings in the HUD
			
			# Now check if we need to manually handle mission 1 character spawning
			if mission_manager.current_mission and mission_manager.current_mission.id == "1" and not mission_manager.character_spawned:
				mission_manager.character_spawned = true
				mission_manager._spawn_character_on_road(position)
			
			# NOTE: We removed the structure_placed signal emission here to fix the population double-counting
		else:
			# We don't emit the signal anymore to prevent double-counting
			pass
	else:
		# No residential building structure found
		pass
	
	# Make sure all characters (including newly spawned residents) are children of NavRegion3D
	_move_characters_to_navregion()
	
	# Make sure the navigation mesh is updated
	rebake_navigation_mesh()
	
	# Note that mission objective updates are now handled in the construction manager
	# to ensure they only occur after construction is complete
	
	

# Saving/load

func action_save():
	if Input.is_action_just_pressed("save"):
		map.structures.clear()
		for cell in gridmap.get_used_cells():
			
			var data_structure:DataStructure = DataStructure.new()
			
			data_structure.position = Vector2i(cell.x, cell.z)
			data_structure.orientation = gridmap.get_cell_item_orientation(cell)
			data_structure.structure = gridmap.get_cell_item(cell)
			
			map.structures.append(data_structure)
			
		ResourceSaver.save(map, "user://map.res")
	
func action_load():
	if Input.is_action_just_pressed("load"):
		gridmap.clear()
		
		map = ResourceLoader.load("user://map.res")
		if not map:
			map = DataMap.new()
		for cell in map.structures:
			gridmap.set_cell_item(Vector3i(cell.position.x, 0, cell.position.y), cell.structure, cell.orientation)
			
		update_cash()
		
		# Find and add all roads to the NavRegion3D
		_add_existing_roads_to_navregion()
		
		# After loading the map, rebake the navigation mesh to include all roads
		rebake_navigation_mesh()
		
		# Make sure any existing NPCs are children of the navigation region
		_move_characters_to_navregion()
