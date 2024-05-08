extends Node3D

@export var structures: Array[Structure] = []

var map:DataMap

var index:int = 0 # Index of structure being built
var build_height:int = 0 

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var cash_display:Label

var plane:Plane # Used for raycasting mouse

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
		mesh_library.set_item_mesh_transform(id, Transform3D())
		
	gridmap.mesh_library = mesh_library
	
	update_structure()
	update_cash()

func _process(delta):
	
	# Controls
	
	action_rotate() # Rotates selection 90 degrees
	action_structure_toggle() # Toggles between structures
	
	action_save() # Saving
	action_load() # Loading
	
	# Map position based on mouse
	
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))
	
	var gridmap_position = Vector3(round(world_position.x), 0 + build_height, round(world_position.z))
	selector.position = lerp(selector.position, gridmap_position, delta * 40)
	
	change_build_height()
	
	action_build(gridmap_position)
	action_demolish(gridmap_position)
	action_demolish(gridmap_position)
	
	
func change_build_height():
	if Input.is_action_just_pressed("increase_build_height"):
		print("buildheight=",build_height)
		build_height += 1
	elif Input.is_action_just_pressed("decrease_build_height"):
		build_height = (build_height > 0) if (build_height - 1) else 0
		print("buildheight=",build_height)

	
# Retrieve the mesh from a PackedScene, used for dynamically creating a MeshLibrary

func get_mesh(packed_scene):
	var scene_state:SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)
					
					return prop_value.duplicate()

# Build (place) a structure

func action_build(gridmap_position):
	if Input.is_action_just_pressed("build"):

		print("build height is ", build_height)
		var previous_tile = gridmap.get_cell_item(gridmap_position)
		var gridmap_position_up = Vector3(gridmap_position.x, gridmap_position.y + 1, gridmap_position.z)
		
		if (previous_tile == index):
			print("set structure position at", gridmap_position_up)
			gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
		else:
			print("set structure position at", gridmap_position)
			gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
	
		if previous_tile != index:
			map.cash -= structures[index].price
			update_cash()

# Demolish (remove) a structure

func action_demolish(gridmap_position):
	if Input.is_action_just_pressed("demolish"):
		gridmap.set_cell_item(gridmap_position, -1)

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
	_model.position.y += 0.25
	
func update_cash():
	cash_display.text = "$" + str(map.cash)

# Saving/load

func cursorUp(gridmap_position, delta):
	if Input.is_action_just_pressed("cursorUp"):
		print("cursorup")
		selector.position = lerp(selector.position, gridmap_position, delta * 40)
		
		return Vector3(gridmap_position.x, gridmap_position.y + 1, gridmap_position.z)
	
	return
		


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
