extends Control

# Reference to the builder node
@export var builder: Node3D

# Menu properties
@export var menu_width: float = 300.0
@export var menu_speed: float = 0.3

# Menu state
var is_open: bool = false
var selected_index: int = -1

# References to UI elements
@onready var toggle_button = $ToggleButton
@onready var menu_panel = $MenuPanel
@onready var items_container = $MenuPanel/ScrollContainer/ItemsContainer

func _ready():
	# Initialize menu state
	menu_panel.position.x = -menu_width
	menu_panel.size.x = menu_width
	
	# Connect toggle button
	toggle_button.pressed.connect(_on_toggle_button_pressed)
	
	# Initial population
	populate_menu()
	
	# Connect to mission manager for updates
	var mission_manager = get_node_or_null("/root/Main/MissionManager")
	if mission_manager:
		mission_manager.mission_started.connect(_on_mission_started)
		mission_manager.mission_completed.connect(_on_mission_completed)

func _on_toggle_button_pressed():
	is_open = !is_open
	
	# Animate menu
	var tween = create_tween()
	tween.tween_property(menu_panel, "position:x", 0.0 if is_open else -menu_width, menu_speed)
	
	# Update toggle button text
	toggle_button.text = "◀" if is_open else "▶"

func populate_menu():
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()
	
	# Add unlocked structures
	for i in range(builder.structures.size()):
		var structure = builder.structures[i]
		if "unlocked" in structure and structure.unlocked:
			create_structure_item(structure, i)

func create_structure_item(structure, index):
	var item = PanelContainer.new()
	item.custom_minimum_size = Vector2(menu_width - 20, 100)
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
	
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(menu_width - 20, 100)
	item.add_child(hbox)
	
	# Thumbnail
	var thumbnail = TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(80, 80)
	thumbnail.expand_mode = TextureRect.EXPAND_FILL_WIDTH
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Try to load thumbnail
	if "thumbnail" in structure and structure.thumbnail:
		var texture = load(structure.thumbnail)
		if texture:
			thumbnail.texture = texture
	else:
		# Try to get thumbnail from model path
		var model_path = structure.model.resource_path
		var colormap_path = model_path.get_basename() + "_colormap.png"
		if ResourceLoader.exists(colormap_path):
			thumbnail.texture = load(colormap_path)
	
	hbox.add_child(thumbnail)
	
	# Info container
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)
	
	# Structure name
	var name_label = Label.new()
	if "title" in structure and structure.title:
		name_label.text = structure.title
	else:
		name_label.text = get_structure_name(structure)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	info.add_child(name_label)
	
	# Structure cost
	var cost_label = Label.new()
	cost_label.text = "Cost: $" + str(structure.price)
	cost_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	info.add_child(cost_label)
	
	# Structure description
	var desc = Label.new()
	if "description" in structure and structure.description:
		desc.text = structure.description
	else:
		desc.text = "A structure for your city!"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	
	# Connect click handler
	item.gui_input.connect(func(event): _on_item_gui_input(event, index))
	
	# Add to container
	items_container.add_child(item)
	
	# Add separator if not last item
	if index < builder.structures.size() - 1:
		var sep = HSeparator.new()
		items_container.add_child(sep)

func _on_item_gui_input(event, index):
	if event is InputEventMouseButton and event.pressed and event.button_index == MouseButton.LEFT:
		select_structure(index)

func select_structure(index):
	if index >= 0 and index < builder.structures.size():
		builder.index = index
		builder.update_structure()
		
		# Update selection highlight
		for i in range(items_container.get_child_count()):
			var child = items_container.get_child(i)
			if child is PanelContainer:
				var style = child.get_theme_stylebox("panel") as StyleBoxFlat
				if i/2 == index:  # Divide by 2 because of separators
					style.border_color = Color(0.9, 0.9, 0.2)
				else:
					style.border_color = Color(0.3, 0.3, 0.3)

func get_structure_name(structure):
	var file_name = structure.model.resource_path.get_file().get_basename()
	var names = file_name.split("-")
	var title = ""
	
	for part in names:
		if part.length() > 0:
			title += part[0].to_upper() + part.substr(1) + " "
			
	return title.strip_edges()

func _on_mission_started(mission):
	# Update menu when a new mission starts
	populate_menu()

func _on_mission_completed(mission):
	# Update menu when a mission is completed (new structures may be unlocked)
	populate_menu() 
