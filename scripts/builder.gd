extends Node3D

@export var structures: Array[Structure] = []

var map:DataMap

var index:int = 0 # Index of structure being built

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var cash_display:Label

var plane:Plane # Used for raycasting mouse
var disabled: bool = false # Used to disable building functionality

signal structure_placed(structure_index, position) # For our mission flow

func _ready():
	
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	
	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html
	
	var mesh_library = MeshLibrary.new()
	
	for structure in structures:
		
		var id = mesh_library.get_last_unused_item_id()
		
		mesh_library.create_item(id)
		mesh_library.set_item_mesh(id, get_mesh(structure.model))
		
		# Apply appropriate scaling for buildings and roads
		var transform = Transform3D()
		if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING or structure.type == Structure.StructureType.ROAD:
			# Scale buildings and roads to be consistent (3x)
			transform = transform.scaled(Vector3(3.0, 3.0, 3.0))
		
		mesh_library.set_item_mesh_transform(id, transform)
		
	gridmap.mesh_library = mesh_library
	
	update_structure()
	update_cash()

func _process(delta):
	# Skip all building functionality if disabled
	if disabled:
		# Hide selector when disabled
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
		
		var previous_tile = gridmap.get_cell_item(gridmap_position)
		gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
		
		if previous_tile != index:
			map.cash -= structures[index].price
			update_cash()
			
			# Check if this is a road structure, add navigation region if it is
			if structures[index].type == Structure.StructureType.ROAD:
				add_navigation_region(gridmap_position, gridmap.get_orthogonal_index_from_basis(selector.basis))
			
			# Emit the signal that a structure was placed
			structure_placed.emit(index, gridmap_position)
			
func add_navigation_region(position: Vector3, orientation: int):
	# Remove any existing navigation region at this position first to avoid duplicates
	remove_navigation_region(position)
	
	# Create a new navigation region for the road
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion_" + str(position.x) + "_" + str(position.z)
	
	# Create a NavigationMesh
	var nav_mesh = NavigationMesh.new()
	
	# Set properties
	nav_mesh.agent_radius = 0.25
	nav_mesh.cell_size = 0.001 # Set to match the expected default value
	
	# Add vertices to create a simple quad for the road navigation
	var vertices = PackedVector3Array()
	
	# Create a quad centered at the road position
	vertices.append(Vector3(position.x - 1.0, 0.1, position.z - 1.0))
	vertices.append(Vector3(position.x - 1.0, 0.1, position.z + 1.0))
	vertices.append(Vector3(position.x + 1.0, 0.1, position.z + 1.0))
	vertices.append(Vector3(position.x + 1.0, 0.1, position.z - 1.0))
	
	# Create a polygon from the vertices
	nav_mesh.vertices = vertices
	
	# Create two triangles to form the quad
	var polygons = []
	polygons.append(PackedInt32Array([2, 1, 0])) # First triangle
	polygons.append(PackedInt32Array([0, 3, 2])) # Second triangle
	nav_mesh.polygons = polygons
	
	# Assign the navigation mesh to the region
	nav_region.navigation_mesh = nav_mesh
	
	# Add the region to the scene
	add_child(nav_region)
	print("Added navigation region at: ", position)
	
# Demolish (remove) a structure

func action_demolish(gridmap_position):
	if Input.is_action_just_pressed("demolish"):
		# Check if this is a road before removing it
		var current_item = gridmap.get_cell_item(gridmap_position)
		var is_road = false
		
		if current_item >= 0 and current_item < structures.size():
			is_road = structures[current_item].type == Structure.StructureType.ROAD
		
		# Remove the item from the grid
		gridmap.set_cell_item(gridmap_position, -1)
		
		# If it was a road, also remove the navigation region
		if is_road:
			remove_navigation_region(gridmap_position)
			
func remove_navigation_region(position: Vector3):
	# Look for navigation region nodes with matching names
	var region_name = "NavRegion_" + str(position.x) + "_" + str(position.z)
	
	# Check if we have a child with this name
	if has_node(region_name):
		var nav_region = get_node(region_name)
		nav_region.queue_free()
		print("Removed navigation region at: ", position)
	else:
		print("No navigation region found at: ", position)

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
	if structures[index].type == Structure.StructureType.RESIDENTIAL_BUILDING or structures[index].type == Structure.StructureType.ROAD:
		# Scale buildings and roads to match (3x)
		_model.scale = Vector3(3.0, 3.0, 3.0)
		_model.position.y += 0.0 # No need for Y adjustment with scaling
	else:
		# Standard positioning for other structures
		_model.position.y += 0.25
	
func update_cash():
	cash_display.text = "$" + str(map.cash)

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
