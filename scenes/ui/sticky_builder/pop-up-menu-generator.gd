extends MenuButton
class_name MenuItemGenerator

# Export a filter type property that uses the Structure.StructureType enum
@export var filter_type: Structure.StructureType
# Private variable to store loaded structures
var _structures = []
# Icons for locked/unlocked status (set these in _ready)
var _lock_icon: Texture2D
var _unlock_icon: Texture2D

func _ready():
	# Connect the signal for item selection
	get_popup().id_pressed.connect(_on_item_selected)
	
	# Add to group for easy refreshing of all structure menus
	add_to_group("structure_menus")
	
	# Load icons (you'll need to create or find these icons)
	_lock_icon = load("res://sprites/sticky_builder_icons/lock.png") if ResourceLoader.exists("res://sprites/sticky_builder_icons/lock.png") else null
	if(_lock_icon):
		_lock_icon = _get_scaled_icon(_lock_icon,32)
	# Load all structures and populate the menu
	_load_structures()
	_populate_menu()

# Load all structure resources from the structures directory
func _load_structures():
	_structures.clear()
	
	var dir = DirAccess.open("res://structures")
	if not dir:
		push_error("Failed to access the structures directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var structure = load("res://structures/" + file_name)
			
			# Only add structures that match our filter type
			if structure is Structure and structure.type == filter_type:
					_structures.append(structure)
		
		file_name = dir.get_next()
	
	# Sort structures by size category first (small to large), then by title
	_structures.sort_custom(func(a, b): 
		# First compare by size category
		if a.size_category != b.size_category:
			return a.size_category < b.size_category
		# If same size category, sort by title
		return a.title < b.title)

# Populate the menu with the loaded structures
func _populate_menu():
	var popup = get_popup()
	popup.clear()
	
	var current_size_category = -1
	
	for i in range(_structures.size()):
		var structure = _structures[i]
		# Add separator between size categories
		if structure.size_category != current_size_category:
			if i > 0:
				popup.add_separator()
			current_size_category = structure.size_category
			
			# Add size category header (optional)
			#var category_name = ""
			#match current_size_category:
				#Structure.SizeCategory.SMALL: category_name = "Small"
				#Structure.SizeCategory.MEDIUM: category_name = "Medium"
				#Structure.SizeCategory.LARGE: category_name = "Large"
			#
			#if category_name != "":
				#popup.add_item(category_name, -1)
				#popup.set_item_disabled(popup.item_count - 1, true)
		
		# Add the structure item with price in the name
		var item_text = structure.title
		if structure.price > 0:
			item_text += " ($" + str(structure.price) + ")"
			
		
		# Add lock/unlock icon if we're showing all structures
		if not structure.unlocked:
			if _lock_icon:
				
				popup.add_icon_item(_lock_icon, item_text)
				popup.set_item_disabled(popup.item_count - 1, true)
		else:
			popup.add_item(item_text, i)
		
				

# Handle the menu item selection
func _on_item_selected(id: int):
	if id >= 0 and id < _structures.size():
		var selected_structure = _structures[id]
		# Get the original structure index in the builder's structure array
		var structure_resource_path = selected_structure.resource_path
		Globals.set_structure(selected_structure)

# Method to manually refresh the menu items
func refresh():
	_load_structures()
	_populate_menu()

# Method to unlock a structure by resource path and refresh the menu
func unlock_structure(resource_path: String):
	var structure = load(resource_path)
	if structure is Structure and not structure.unlocked:
		structure.unlocked = true
		structure.resource_changed.emit()
		
		# Save the resource
		ResourceSaver.save(structure, resource_path)
		
		# Refresh the menu
		refresh()
		
		return true
	
	return false
	
func _get_scaled_icon(texture: Texture2D, target_height: int) -> Texture2D:
	if texture == null:
		return null
	
	var img = texture.get_image()
	var scale = target_height / float(img.get_height())
	var new_width = int(img.get_width() * scale)
	
	img.resize(new_width, target_height, Image.INTERPOLATE_LANCZOS)
	
	var new_texture = ImageTexture.create_from_image(img)
	return new_texture
