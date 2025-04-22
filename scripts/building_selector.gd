extends Control

@onready var main_button = $MainButton
@onready var selection_panel = $SelectionPanel
@onready var ground_options = $SelectionPanel/ScrollContainer/VBoxContainer/GroundSection/GroundOptions
@onready var building_options = $SelectionPanel/ScrollContainer/VBoxContainer/BuildingSection/BuildingOptions
@onready var search_bar = $SelectionPanel/SearchBar
@onready var filter_buttons = $SelectionPanel/FilterButtons
@onready var description_panel = $SelectionPanel/DescriptionPanel
@onready var title_label = $SelectionPanel/DescriptionPanel/VBoxContainer/TitleLabel
@onready var description_label = $SelectionPanel/DescriptionPanel/VBoxContainer/DescriptionLabel
@onready var price_label = $SelectionPanel/DescriptionPanel/VBoxContainer/StatsContainer/PriceLabel
@onready var population_label = $SelectionPanel/DescriptionPanel/VBoxContainer/StatsContainer/PopulationLabel
@onready var power_label = $SelectionPanel/DescriptionPanel/VBoxContainer/StatsContainer/PowerLabel

@export var builder: Node:
	set(value):
		_builder = value
		if is_inside_tree():  # Only create buttons if node is ready
			_create_option_buttons()
	get:
		return _builder

var _builder: Node
var current_selection: int = 0
var is_panel_visible: bool = false
var current_filter: String = "All"
var search_text: String = ""

func _ready():
	# Connect the main button signal
	main_button.pressed.connect(_on_main_button_pressed)
	
	# Connect search bar signal
	search_bar.text_changed.connect(_on_search_text_changed)
	
	# Connect filter button signals
	for button in filter_buttons.get_children():
		if button is Button:
			button.pressed.connect(_on_filter_button_pressed.bind(button.text))
	
	# Initially hide the selection panel
	selection_panel.visible = false
	
	# Make sure the panel doesn't pass through mouse events
	selection_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ground_options.mouse_filter = Control.MOUSE_FILTER_STOP
	building_options.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create the building and ground option buttons
	_create_option_buttons()

func _create_option_buttons():
	# Clear existing buttons
	for child in ground_options.get_children():
		child.queue_free()
	for child in building_options.get_children():
		child.queue_free()
	
	# Get structures from builder
	if not _builder or not _builder.structures:
		return
	
	# Create ground options (grass, pavement, etc.)
	var ground_structures = []
	var building_structures = []
	
	# Sort structures by type and apply filters
	for structure in _builder.structures:
		# Apply search filter
		if search_text != "" and not structure.title.to_lower().contains(search_text.to_lower()):
			continue
			
		# Apply type filter
		if current_filter != "All":
			match current_filter:
				"Residential":
					if structure.type != Structure.StructureType.RESIDENTIAL_BUILDING:
						continue
				"Commercial":
					if structure.type != Structure.StructureType.COMMERCIAL_BUILDING:
						continue
				"Industrial":
					if structure.type != Structure.StructureType.INDUSTRIAL_BUILDING:
						continue
		
		if structure.type == Structure.StructureType.TERRAIN:
			ground_structures.append(structure)
		else:
			building_structures.append(structure)
	
	# Set up grid layout for ground options
	ground_options.columns = 4  # Set number of columns
	ground_options.add_theme_constant_override("h_separation", 10)  # Horizontal spacing
	ground_options.add_theme_constant_override("v_separation", 10)  # Vertical spacing
	
	# Create buttons for ground structures
	for i in range(ground_structures.size()):
		var button = _create_option_button(ground_structures[i], i)
		ground_options.add_child(button)
	
	# Set up grid layout for building options
	building_options.columns = 4  # Set number of columns
	building_options.add_theme_constant_override("h_separation", 10)  # Horizontal spacing
	building_options.add_theme_constant_override("v_separation", 10)  # Vertical spacing
	
	# Create buttons for building structures
	for i in range(building_structures.size()):
		var button = _create_option_button(building_structures[i], i + ground_structures.size())
		building_options.add_child(button)
	
	# Hide sections if they have no options
	$SelectionPanel/ScrollContainer/VBoxContainer/GroundSection.visible = ground_structures.size() > 0
	$SelectionPanel/ScrollContainer/VBoxContainer/BuildingSection.visible = building_structures.size() > 0

func _create_option_button(structure: Structure, index: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(70, 70)  # Reduced from 80x80
	button.toggle_mode = true
	button.button_group = ButtonGroup.new()
	button.tooltip_text = structure.description
	
	# Create container for button contents
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.AlignmentMode.ALIGNMENT_CENTER
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 2)  # Reduce spacing between elements
	button.add_child(container)
	
	# Create preview container
	var preview_container = Control.new()
	preview_container.custom_minimum_size = Vector2(50, 50)  # Reduced from 64x64
	container.add_child(preview_container)
	
	# Add preview image or model
	if structure.thumbnail and structure.thumbnail != "Thumbnail" and ResourceLoader.exists(structure.thumbnail):
		var preview = TextureRect.new()
		var texture = load(structure.thumbnail)
		preview.texture = texture
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.custom_minimum_size = Vector2(50, 50)  # Force minimum size
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL  # Maintain aspect ratio while fitting width
		preview_container.add_child(preview)
	else:
		var viewport = SubViewport.new()
		viewport.size = Vector2i(50, 50)  # Reduced from 64x64
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.transparent_bg = true
		preview_container.add_child(viewport)
		
		var camera = Camera3D.new()
		camera.position = Vector3(0, 0, 2)
		camera.look_at(Vector3.ZERO)
		viewport.add_child(camera)
		
		if structure.model:
			var model = structure.model.instantiate()
			viewport.add_child(model)
	
	# Add structure name
	var name_label = Label.new()
	name_label.text = structure.title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.max_lines_visible = 2
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(name_label)
	
	# Add price label
	var price_label = Label.new()
	price_label.text = "$" + str(structure.price)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(price_label)
	
	# Add lock overlay if structure is locked
	if not structure.unlocked:
		var lock_overlay = ColorRect.new()
		lock_overlay.color = Color(0, 0, 0, 0.5)
		lock_overlay.size = preview_container.size
		preview_container.add_child(lock_overlay)
		
		var lock_icon = TextureRect.new()
		lock_icon.texture = load("res://textures/lock.png")
		lock_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lock_icon.stretch_mode = TextureRect.StretchMode.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.size = Vector2(30, 30)  # Reduced from 40x40
		lock_icon.position = Vector2(10, 10)  # Adjusted position
		preview_container.add_child(lock_icon)
		
		# Disable button if structure is locked
		button.disabled = true
	
	button.pressed.connect(_on_option_selected.bind(index))
	return button

func _on_main_button_pressed():
	is_panel_visible = !is_panel_visible
	selection_panel.visible = is_panel_visible
	
	if is_panel_visible:
		# Update button states to show current selection
		_update_button_states()

func _on_search_text_changed(new_text: String):
	search_text = new_text
	_create_option_buttons()

func _on_filter_button_pressed(filter_name: String):
	# Update filter buttons
	for button in filter_buttons.get_children():
		if button is Button:
			button.button_pressed = (button.text == filter_name)
	
	current_filter = filter_name
	_create_option_buttons()

func _on_option_selected(index: int):
	if not _builder:
		print("ERROR: No builder reference in building selector")
		return
		
	if not _builder.structures or index < 0 or index >= _builder.structures.size():
		print("ERROR: Invalid structure index: ", index)
		return
		
	current_selection = index
	_update_button_states()
	
	# Update the builder's current selection
	_builder.index = index
	_builder.update_structure()
	
	# Update the main button text
	main_button.text = "Selected: " + _get_structure_name(index)
	
	# Update description panel
	_update_description_panel(index)

func _update_button_states():
	# Update all buttons to show which one is selected
	var all_buttons = ground_options.get_children() + building_options.get_children()
	for i in range(all_buttons.size()):
		all_buttons[i].button_pressed = (i == current_selection)

func _get_structure_name(index: int) -> String:
	if _builder and _builder.structures and index >= 0 and index < _builder.structures.size():
		var structure = _builder.structures[index]
		return structure.title
	return "Unknown"

func _update_description_panel(index: int):
	if not _builder or not _builder.structures or index < 0 or index >= _builder.structures.size():
		title_label.text = "No Building Selected"
		description_label.text = "Select a building to view its details"
		price_label.text = "Price: $0"
		population_label.text = "Population: 0"
		power_label.text = "Power: 0 kW"
		return
	
	var structure = _builder.structures[index]
	title_label.text = structure.title
	description_label.text = structure.description
	price_label.text = "Price: $" + str(structure.price)
	population_label.text = "Population: " + str(structure.population_count)
	
	var power_text = "Power: "
	if structure.kW_production > 0:
		power_text += "+" + str(structure.kW_production) + " kW"
	elif structure.kW_usage > 0:
		power_text += "-" + str(structure.kW_usage) + " kW"
	else:
		power_text += "0 kW"
	power_label.text = power_text 
