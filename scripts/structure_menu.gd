extends Control

@export var builder: Node3D
@export var base_menu_width: float = 300.0  # Base width for the menu
@export var item_width: float = 280.0  # Width of each item
@export var item_spacing: float = 20.0  # Spacing between items
@export var menu_speed: float = 0.3
@export var visible_menu_width: float = 600.0  # The visible width of the menu panel
@export var item_height: float = 180.0
@export var menu_vertical_offset: float = 40.0

var is_open: bool = false
var selected_index: int = -1
var menu_width: float = base_menu_width  # Will be updated based on items

@onready var toggle_button = $ToggleButton
@onready var menu_panel = $MenuPanel
@onready var items_container = $MenuPanel/ScrollContainer/ItemsContainer

func _ready():
	# Ensure we have a valid builder reference
	if not builder:
		builder = get_node_or_null("/root/Main/Builder")
		if not builder:
			push_error("StructureMenu: Builder node not found!")
			return
			
	# Initialize menu panel position and size
	menu_panel.size.x = base_menu_width
	menu_panel.position.x = -menu_panel.size.x  # Start closed
	
	# Vertically center the toggle button on the menu panel
	toggle_button.anchor_top = 0.5
	toggle_button.anchor_bottom = 0.5
	toggle_button.offset_top = -toggle_button.size.y / 2
	toggle_button.offset_bottom = toggle_button.size.y / 2
	
	# Place toggle button at the left edge of the menu
	toggle_button.position.x = 0
	toggle_button.text = "▶"
	
	# Connect signals
	toggle_button.pressed.connect(_on_toggle_button_pressed)
	
	# Connect to builder's structure update signal if it exists
	if "structure_updated" in builder:
		print("Connecting to builder's structure_updated signal")  # Debug print
		builder.structure_updated.connect(_on_builder_structure_updated)
	
	# Connect to mission manager's structures_unlocked signal
	var mission_manager = get_node_or_null("/root/Main/MissionManager")
	if mission_manager:
		print("Connecting to mission manager's structures_unlocked signal")  # Debug print
		mission_manager.structures_unlocked.connect(_on_structures_unlocked)
	
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	_center_toggle_button()
	
	# Populate the menu
	populate_menu()
	
	# Print debug info
	print("StructureMenu: Builder found: ", builder != null)
	print("StructureMenu: Structures array size: ", builder.structures.size() if builder and "structures" in builder else 0)
	
	# Initialize selection if builder has a current index
	if builder and "index" in builder:
		selected_index = builder.index
		update_selection_highlight()

func _center_toggle_button():
	# Vertically center the toggle button on the menu panel
	var menu_height = menu_panel.size.y
	var button_height = toggle_button.size.y
	toggle_button.position.y = (menu_height - button_height) / 2
	# Horizontally: always at 0 when closed, at menu_panel.size.x when open
	toggle_button.position.x = menu_panel.size.x if is_open else 0

func _on_toggle_button_pressed():
	is_open = !is_open
	var tween = create_tween()
	tween.tween_property(menu_panel, "position:x", 0.0 if is_open else -menu_panel.size.x, menu_speed)
	tween.parallel().tween_property(toggle_button, "position:x", menu_panel.size.x if is_open else 0.0, menu_speed)
	toggle_button.text = "◀" if is_open else "▶"
	_center_toggle_button()

func _on_builder_structure_updated(index):
	print("Builder structure updated signal received. Index: ", index)  # Debug print
	# Update the selected index and highlight
	selected_index = index
	update_selection_highlight()

func populate_menu():
	if not builder or not "structures" in builder:
		push_error("StructureMenu: Builder or structures array not found!")
		return
		
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()
	
	# Count unlocked structures
	var unlocked_count = 0
	for structure in builder.structures:
		if "unlocked" in structure and structure.unlocked:
			unlocked_count += 1
	
	# Calculate menu width and height using the user's formula
	var padding = item_spacing
	menu_width = (unlocked_count * item_width) + ((unlocked_count + 1) * padding)
	var menu_height = item_height + 2 * padding

	# Center the menu panel horizontally and set its size using anchors and offsets
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.offset_left = -menu_width / 2
	menu_panel.offset_right = menu_width / 2
	menu_panel.anchor_top = 0.0
	menu_panel.anchor_bottom = 0.0
	menu_panel.offset_top = 0
	menu_panel.offset_bottom = menu_height
	$MenuPanel/ScrollContainer.size.x = menu_width
	$MenuPanel/ScrollContainer.size.y = menu_height
	$MenuPanel/ScrollContainer.position.y = 0
	$MenuPanel/ScrollContainer.clip_contents = true

	# If menu is closed, keep it offscreen
	if not is_open:
		menu_panel.position.x = -menu_width
		_center_toggle_button()

	# Create a MarginContainer for all-side padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_bottom", padding)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_container.add_child(margin)
	margin.position.y = menu_vertical_offset

	# Create a CenterContainer to center the row both horizontally and vertically
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	# Create a horizontal container for all items
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", padding)
	# DO NOT set row.size_flags_horizontal so it doesn't expand
	center.add_child(row)

	# Add all unlocked structures to the row
	for i in range(builder.structures.size()):
		var structure = builder.structures[i]
		if "unlocked" in structure and structure.unlocked:
			var item = create_structure_item(structure, i)
			row.add_child(item)

	# Update selection highlight after populating
	update_selection_highlight()

func create_structure_item(structure, index):
	var item = PanelContainer.new()
	item.custom_minimum_size = Vector2(item_width, item_height)
	item.size_flags_horizontal = 0  # Prevent horizontal expansion
	item.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	
	var style = item.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	
	# Store the structure index in the item for reference
	item.set_meta("structure_index", index)
	
	# Main container for vertical layout
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(item_width, item_height)
	vbox.size_flags_horizontal = 0  # Prevent horizontal expansion
	vbox.add_theme_constant_override("separation", item_spacing)
	item.add_child(vbox)
	
	# Thumbnail container
	var thumbnail_container = CenterContainer.new()
	thumbnail_container.custom_minimum_size = Vector2(128, 128)
	thumbnail_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(thumbnail_container)
	
	# Thumbnail
	var thumbnail = TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(128, 128)
	thumbnail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumbnail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Try to load thumbnail
	if "thumbnail" in structure and structure.thumbnail != null:
		var texture = load(structure.thumbnail)
		if texture is Texture2D:
			var image = texture.get_image()
			image.resize(128, 128)
			var scaled_texture = ImageTexture.create_from_image(image)
			thumbnail.texture = scaled_texture
			print("Structure ", index, " thumbnail loaded: ", structure.thumbnail)
			print("Texture size: ", scaled_texture.get_size())
			print("Thumbnail size: ", thumbnail.size)
			print("Thumbnail container size: ", thumbnail_container.size)
		else:
			print("Warning: Thumbnail is not a Texture2D: ", structure.thumbnail, " (type: ", typeof(texture), ")")
	
	thumbnail_container.add_child(thumbnail)
	
	# Debug print after adding to container
	print("After adding to container:")
	print("Thumbnail size: ", thumbnail.size)
	print("Thumbnail container size: ", thumbnail_container.size)
	print("Thumbnail custom_minimum_size: ", thumbnail.custom_minimum_size)
	print("Container custom_minimum_size: ", thumbnail_container.custom_minimum_size)
	
	# Info container
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	vbox.add_child(info)
	
	# Structure name
	var name_label = Label.new()
	if "title" in structure and structure.title != null:
		name_label.text = structure.title
	else:
		name_label.text = "Structure " + str(index)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(name_label)
	
	# Structure cost
	var cost_label = Label.new()
	if "price" in structure:
		cost_label.text = "Cost: $" + str(structure.price)
	else:
		cost_label.text = "Cost: $0"
	cost_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(cost_label)
	
	# Connect click handler
	item.gui_input.connect(func(event): _on_item_gui_input(event, index))
	
	# Add to container
	items_container.add_child(item)
	
	# Add separator if not last item
	if index < builder.structures.size() - 1:
		var sep = HSeparator.new()
		items_container.add_child(sep)

func _on_item_gui_input(event, index):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_structure(index)

func select_structure(index):
	if not builder or not "structures" in builder:
		return
		
	if index >= 0 and index < builder.structures.size():
		print("Selecting structure index: ", index)  # Debug print
		# Update builder's selected structure
		builder.index = index
		if "update_structure" in builder:
			builder.update_structure()
		
		# Update our selected index
		selected_index = index
		
		# Update visual feedback
		update_selection_highlight()

func update_selection_highlight():
	print("Updating selection highlight. Selected index: ", selected_index)  # Debug print
	# Update selection highlight for all items
	for i in range(items_container.get_child_count()):
		var child = items_container.get_child(i)
		if child is PanelContainer:
			var style = child.get_theme_stylebox("panel") as StyleBoxFlat
			var item_index = child.get_meta("structure_index")
			if item_index == selected_index:
				print("Highlighting item: ", item_index)  # Debug print
				# Selected item
				style.border_color = Color(0.9, 0.9, 0.2)  # Yellow border
				style.bg_color = Color(0.3, 0.3, 0.3, 0.8)  # Slightly lighter background
			else:
				# Unselected item
				style.border_color = Color(0.3, 0.3, 0.3)
				style.bg_color = Color(0.2, 0.2, 0.2, 0.8)

func get_structure_name(structure):
	var file_name = structure.model.resource_path.get_file().get_basename()
	var names = file_name.split("-")
	var title = ""
	
	for part in names:
		if part.length() > 0:
			title += part[0].to_upper() + part.substring(1) + " "
	
	return title.strip_edges()

func is_mouse_over_menu() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	return menu_panel.get_global_rect().has_point(mouse_pos) or toggle_button.get_global_rect().has_point(mouse_pos) 

# Add new function to handle structure unlocking
func _on_structures_unlocked():
	print("Structures unlocked signal received, updating menu")
	populate_menu() 
