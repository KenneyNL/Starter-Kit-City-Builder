extends Node3D

@export var structures: Array[Structure] = []

var map:DataMap

var index:int = 0 # Index of structure being built
var nav_region: NavigationRegion3D # Single navigation region for all roads

# Construction manager for building residential buildings with workers
var construction_manager: BuildingConstructionManager


@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var cash_display:Label # Reference to cash label in HUD

var plane:Plane # Used for raycasting mouse
var disabled: bool = false # Used to disable building functionality

signal structure_placed(structure_index, position) # For our mission flow

func _ready():
	
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	
	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html
	
	var mesh_library = MeshLibrary.new()
	
	# Setup the navigation region if it doesn't exist
	setup_navigation_region()
	
	# Setup construction manager
	construction_manager = BuildingConstructionManager.new()
	add_child(construction_manager)
	
	# Connect to the construction completion signal
	construction_manager.construction_completed.connect(_on_construction_completed)
	
	# Give the construction manager references it needs
	construction_manager.builder = self
	construction_manager.nav_region = nav_region
	
	for structure in structures:
		
		var id = mesh_library.get_last_unused_item_id()
		
		mesh_library.create_item(id)
		mesh_library.set_item_mesh(id, get_mesh(structure.model))
		
		# Apply appropriate scaling for buildings and roads
		var transform = Transform3D()
		if structure.model.resource_path.contains("power_plant"):
			# Scale power plant model to be much smaller (0.5x)
			transform = transform.scaled(Vector3(0.5, 0.5, 0.5))
		elif structure.type == Structure.StructureType.RESIDENTIAL_BUILDING or structure.type == Structure.StructureType.ROAD:
			# Scale buildings and roads to be consistent (3x)
			transform = transform.scaled(Vector3(3.0, 3.0, 3.0))
		
		mesh_library.set_item_mesh_transform(id, transform)
		
	gridmap.mesh_library = mesh_library
	
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
	# Get the viewport
	var viewport = get_viewport()
	if not viewport:
		return false
		
	# Get mouse position
	var mouse_pos = viewport.get_mouse_position()
	
	# Check if mouse is over any UI elements
	# Find the HUD node
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	if hud and hud.get_global_rect().has_point(mouse_pos):
		print("Mouse over HUD")
		return true
		
	# Also check if mouse is over mission panel
	var mission_panel = get_node_or_null("/root/Main/MissionManager/MissionPanel")
	if mission_panel and mission_panel.visible and mission_panel.get_global_rect().has_point(mouse_pos):
		print("Mouse over mission panel")
		return true
		
	# Check learning panel too
	var learning_panel = get_node_or_null("/root/Main/MissionManager/LearningPanel") 
	if learning_panel and learning_panel.visible and learning_panel.get_global_rect().has_point(mouse_pos):
		print("Mouse over learning panel")
		return true
		
	# Check controls panel
	var controls_panel = get_node_or_null("/root/Main/CanvasLayer/ControlsPanel")
	if controls_panel and controls_panel.visible and controls_panel.get_global_rect().has_point(mouse_pos):
		print("Mouse over controls panel")
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
		var use_worker_construction = false
		var mission_manager = get_node_or_null("/root/Main/MissionManager")
		if mission_manager and mission_manager.current_mission:
			var mission_id = mission_manager.current_mission.id
			if mission_id == "3" or (mission_id == "1" and is_residential):
				use_worker_construction = true
		
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
			# Special handling for power plants - add directly as a child of the builder
			_add_power_plant(gridmap_position, index)
			
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


# Rebake navigation mesh to update the navigation data
func rebake_navigation_mesh():
	# Make sure we have a navigation region first
	if not nav_region:
		setup_navigation_region()
	
	# Bake the navigation mesh for the entire map
	nav_region.bake_navigation_mesh()
	print("Navigation mesh rebaked")
	
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
		
		# Store structure index before removal for signaling
		var structure_index = -1
		
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
		
		# Emit signal that structure was removed
		if structure_index >= 0:
			structure_removed.emit(structure_index, gridmap_position)
			
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
		index = wrap(index + 1, 0, structures.size())
	
	if Input.is_action_just_pressed("structure_previous"):
		index = wrap(index - 1, 0, structures.size())

	update_structure()

# Update the structure visual in the 'cursor'

func update_structure():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		
	# Create new structure preview in selector
	var _model = structures[index].model.instantiate()
	selector_container.add_child(_model)
	
	# Apply appropriate scaling based on structure type
	if structures[index].model.resource_path.contains("power_plant"):
		# Scale power plant model to be much smaller (0.5x)
		_model.scale = Vector3(0.5, 0.5, 0.5)
		_model.position.y += 0.0 # No need for Y adjustment with scaling
	elif (structures[index].type == Structure.StructureType.RESIDENTIAL_BUILDING
	   or structures[index].type == Structure.StructureType.ROAD
	   or structures[index].type == Structure.StructureType.TERRAIN
	   or structures[index].model.resource_path.contains("grass")):
		# Scale buildings, roads, and decorative terrain to match (3x)
		_model.scale = Vector3(3.0, 3.0, 3.0)
		_model.position.y += 0.0 # No need for Y adjustment with scaling
	else:
		# Standard positioning for other structures
		_model.position.y += 0.25
	
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
	
	# Set position
	transform.origin = position
	
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
		print("No power plant found at position ", position)
		
# Function to remove terrain (grass or trees)
func _remove_terrain(position: Vector3):
	# Get the terrain name based on its position
	var terrain_name = "Terrain_" + str(int(position.x)) + "_" + str(int(position.z))
	
	# Check if terrain with this name exists
	if has_node(terrain_name):
		# Get the terrain and remove it
		var terrain = get_node(terrain_name)
		terrain.queue_free()
		print("Removed terrain at position ", position)
	else:
		print("No terrain found at position ", position)

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
		print("Removed road at position ", position, " from NavRegion3D")
	else:
		print("No road found at position ", position, " in NavRegion3D")
		
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
	print("Finding and adding all existing roads to NavRegion3D...")
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
				
	print("Added ", added_count, " existing roads to NavRegion3D")
	
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
	
	print("Added terrain at position ", position, " as direct child of builder")

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
		print("Construction completed: added building to gridmap at ", position, " with rotation index ", rotation_index)
		
		# Check if we need to spawn a character for mission 1
		var mission_manager = get_node_or_null("/root/Main/MissionManager")
		if mission_manager:
			# We DON'T re-emit the structure_placed signal here, because we already
			# emitted it when construction started in action_build()
			# This prevents double-counting buildings in the HUD
			
			# Now check if we need to manually handle mission 1 character spawning
			if mission_manager.current_mission and mission_manager.current_mission.id == "1" and not mission_manager.character_spawned:
				print("This is the first residential building in mission 1, spawning character")
				mission_manager.character_spawned = true
				mission_manager._spawn_character_on_road(position)
			
			# NOTE: We removed the structure_placed signal emission here to fix the population double-counting
		else:
			# We don't emit the signal anymore to prevent double-counting
			pass
	else:
		print("ERROR: No residential building structure found!")
	
	# Make sure all characters (including newly spawned residents) are children of NavRegion3D
	_move_characters_to_navregion()
	
	# Make sure the navigation mesh is updated
	rebake_navigation_mesh()
	
	

# Saving/load

func action_save():
	if Input.is_action_just_pressed("save"):
		print("Saving map...")
		
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
		print("Loading map...")
		
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
