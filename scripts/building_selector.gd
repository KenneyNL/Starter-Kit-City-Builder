extends PanelContainer

const GenericText = preload("res://resources/generic_text_panel.resource.gd")

signal closed

@export var resource_data: GenericText

@onready var main_button: Button = $MainButton
@onready var selection_panel: Panel = $SelectionPanel
@onready var ground_options = $SelectionPanel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/GroundSection/GroundOptions
@onready var building_options = $SelectionPanel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/BuildingSection/BuildingOptions
@onready var search_bar: LineEdit = $SelectionPanel/MarginContainer/VBoxContainer/SearchBar
@onready var filter_buttons: HBoxContainer = $SelectionPanel/MarginContainer/VBoxContainer/FilterButtons
@onready var description_panel: Panel = $SelectionPanel/MarginContainer/VBoxContainer/DescriptionPanel
@onready var title_label: Label = $SelectionPanel/MarginContainer/VBoxContainer/DescriptionPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $SelectionPanel/MarginContainer/VBoxContainer/DescriptionPanel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var price_label: Label = $SelectionPanel/MarginContainer/VBoxContainer/DescriptionPanel/MarginContainer/VBoxContainer/StatsContainer/PriceLabel
@onready var population_label: Label = $SelectionPanel/MarginContainer/VBoxContainer/DescriptionPanel/MarginContainer/VBoxContainer/StatsContainer/PopulationLabel
@onready var power_label: Label = $SelectionPanel/MarginContainer/VBoxContainer/DescriptionPanel/MarginContainer/VBoxContainer/StatsContainer/PowerLabel
@onready var click_blocker: ColorRect = $ClickBlocker

var builder: Node
var current_selection: int = 0
var is_panel_visible: bool = false
var current_filter: String = "All"
var search_text: String = ""
var slide_tween: Tween
var tween: Tween

func _ready() -> void:
	# Hide the panel initially
	visible = false
	
	# Make sure this control blocks mouse input from passing through
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Initialize the panel state
	if selection_panel:
		selection_panel.visible = false
		selection_panel.position = Vector2(0, 0)  # Reset position
		selection_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		selection_panel.size = Vector2(300, get_viewport_rect().size.y)  # Set a fixed width
	
	# Set up click blocker
	if click_blocker:
		click_blocker.visible = false
		click_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		click_blocker.size = get_viewport_rect().size
		click_blocker.position = Vector2.ZERO
		click_blocker.z_index = 1000  # Ensure it's above everything else
	
	# Create background panel for the main button
	var button_bg = ColorRect.new()
	button_bg.color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	button_bg.size = Vector2(40, 40)  # Slightly larger than the button
	button_bg.position = Vector2(-5, -5)  # Offset to center the button
	button_bg.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks on background
	add_child(button_bg)
	button_bg.z_index = -1  # Place behind the button
	
	if main_button:
		main_button.text = "▶"
		main_button.mouse_filter = Control.MOUSE_FILTER_STOP
		# Set initial position to stick to the right side
		main_button.position.x = 0
		# Center the button vertically
		main_button.position.y = get_viewport_rect().size.y / 2 - 20
		# Style the button
		main_button.add_theme_color_override("font_color", Color(1, 1, 1))  # White text
		main_button.add_theme_font_size_override("font_size", 24)  # Larger font
	
	# Connect signals
	if main_button and not main_button.pressed.is_connected(_on_main_button_pressed):
		main_button.pressed.connect(_on_main_button_pressed)
	if search_bar and not search_bar.text_changed.is_connected(_on_search_text_changed):
		search_bar.text_changed.connect(_on_search_text_changed)
	
	for button in filter_buttons.get_children():
		if button is Button and not button.pressed.is_connected(_on_filter_button_pressed.bind(button.text)):
			button.pressed.connect(_on_filter_button_pressed.bind(button.text))
	
	# Set mouse filters for containers
	if ground_options:
		ground_options.mouse_filter = Control.MOUSE_FILTER_STOP
	if building_options:
		building_options.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create initial buttons if builder is set
	if builder:
		_create_filter_buttons()
		_create_option_buttons()
	
	# Apply resource data if available
	if resource_data:
		apply_resource_data(resource_data)

func show_panel() -> void:
	visible = true
	is_panel_visible = true
	selection_panel.visible = true
	click_blocker.visible = true
	main_button.text = "◀"
	
	# Create tween for smooth animation
	if tween:
		tween.kill()
	tween = create_tween()
	
	# Panel is opening
	selection_panel.position.x = -selection_panel.size.x
	tween.tween_property(selection_panel, "position:x", 0, 0.2)
	tween.parallel().tween_property(main_button, "position:x", selection_panel.size.x, 0.2)
	
	# Pause the game when the panel is open
	get_tree().paused = true

func hide_panel() -> void:
	is_panel_visible = false
	
	# Create tween for smooth animation
	if tween:
		tween.kill()
	tween = create_tween()
	
	# Panel is closing
	tween.tween_property(selection_panel, "position:x", -selection_panel.size.x, 0.2)
	tween.parallel().tween_property(main_button, "position:x", 0, 0.2)
	tween.tween_callback(func():
		selection_panel.visible = false
		click_blocker.visible = false
		main_button.text = "▶"
		visible = false
		# Resume the game when the panel is closed
		get_tree().paused = false
		# Emit signal that panel was closed
		closed.emit()
	)

func _on_main_button_pressed() -> void:
	if !selection_panel or !main_button or !click_blocker:
		return
		
	if !is_panel_visible:
		show_panel()
	else:
		hide_panel()

func _create_filter_buttons():
	if not filter_buttons or not builder:
		return
	
	# Clear existing buttons
	for child in filter_buttons.get_children():
		child.queue_free()
	
	# Create "All" button
	var all_button = Button.new()
	all_button.text = "All"
	all_button.toggle_mode = true
	all_button.button_pressed = true
	all_button.flat = true
	all_button.pressed.connect(_on_filter_button_pressed.bind("All"))
	filter_buttons.add_child(all_button)
	
	# Get unique structure types
	var structure_types = {}
	for structure in builder.get_structures():
		if structure.type == Structure.StructureType.LANDSCAPE:
			structure_types["Ground"] = true
		else:
			structure_types["Buildings"] = true
	
	# Create buttons for each structure type
	for type_name in structure_types.keys():
		var button = Button.new()
		button.text = type_name
		button.toggle_mode = true
		button.flat = true
		button.pressed.connect(_on_filter_button_pressed.bind(type_name))
		filter_buttons.add_child(button)

func _create_option_buttons():
	# Clear existing buttons
	if ground_options:
		for child in ground_options.get_children():
			child.queue_free()
	if building_options:
		for child in building_options.get_children():
			child.queue_free()
	
	# Get structures from builder
	if not builder:
		print("ERROR: No builder reference in building selector")
		return
		
	var structures = builder.get_structures()
	if not structures or structures.size() == 0:
		print("WARNING: No structures available in builder")
		return
	
	# Create ground options (grass, pavement, etc.)
	var ground_structures = []
	var building_structures = []
	
	# Sort structures by type and apply filters
	for structure in structures:
		if not structure:
			continue
			
		# Apply search filter
		if search_text != "" and not structure.title.to_lower().contains(search_text.to_lower()):
			continue
			
		# Apply type filter
		if current_filter != "All":
			match current_filter:
				"Ground":
					if structure.type != Structure.StructureType.LANDSCAPE:
						continue
				"Buildings":
					if structure.type == Structure.StructureType.LANDSCAPE:
						continue
		
		# Add to appropriate list
		if structure.type == Structure.StructureType.LANDSCAPE:
			ground_structures.append(structure)
		else:
			building_structures.append(structure)
	
	# Set up grid layout for ground options
	if ground_options:
		ground_options.columns = 4
		ground_options.add_theme_constant_override("h_separation", 10)
		ground_options.add_theme_constant_override("v_separation", 10)
	
	# Create buttons for ground structures
	for i in range(ground_structures.size()):
		var button = _create_option_button(ground_structures[i], i)
		if ground_options:
			ground_options.add_child(button)
	
	# Set up grid layout for building options
	if building_options:
		building_options.columns = 4
		building_options.add_theme_constant_override("h_separation", 10)
		building_options.add_theme_constant_override("v_separation", 10)
	
	# Create buttons for building structures
	for i in range(building_structures.size()):
		var button = _create_option_button(building_structures[i], i + ground_structures.size())
		if building_options:
			building_options.add_child(button)
	
	# Hide sections if they have no options
	var ground_section = $SelectionPanel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/GroundSection
	var building_section = $SelectionPanel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/BuildingSection
	
	if ground_section:
		ground_section.visible = ground_structures.size() > 0
	if building_section:
		building_section.visible = building_structures.size() > 0
		
	# Force update the layout
	if ground_options:
		ground_options.queue_redraw()
	if building_options:
		building_options.queue_redraw()

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

func _on_search_text_changed(new_text: String) -> void:
	search_text = new_text
	_create_option_buttons()

func _on_filter_button_pressed(filter: String) -> void:
	current_filter = filter
	_create_option_buttons()

func _on_option_selected(index: int):
	if not builder:
		print("ERROR: No builder reference in building selector")
		return
		
	var structures = builder.get_structures()
	if not structures or index < 0 or index >= structures.size():
		print("ERROR: Invalid structure index: ", index)
		return
		
	current_selection = index
	_update_button_states()
	
	# Update the builder's current selection
	builder.index = index
	builder.update_structure()
	
	# Update the main button text
	main_button.text = "Selected: " + _get_structure_name(index)
	
	# Update description panel
	_update_description_panel(index)

func _update_button_states():
	# Update all buttons to show which one is selected
	if not ground_options or not building_options:
		return
		
	var all_buttons = []
	
	# Add ground options buttons if they exist
	for child in ground_options.get_children():
		if child is Button:
			all_buttons.append(child)
	
	# Add building options buttons if they exist
	for child in building_options.get_children():
		if child is Button:
			all_buttons.append(child)
	
	# Update button states
	for i in range(all_buttons.size()):
		if all_buttons[i] is Button:
			all_buttons[i].button_pressed = (i == current_selection)

func _get_structure_name(index: int) -> String:
	var structures = builder.get_structures()
	if structures and index >= 0 and index < structures.size():
		var structure = structures[index]
		return structure.title
	return "Unknown"

func _update_description_panel(index: int):
	var structures = builder.get_structures()
	if not structures or index < 0 or index >= structures.size():
		title_label.text = "No Building Selected"
		description_label.text = "Select a building to view its details"
		price_label.text = "Price: $0"
		population_label.text = "Population: 0"
		power_label.text = "Power: 0 kW"
		return
	
	var structure = structures[index]
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

func apply_resource_data(data: GenericText) -> void:
	if data:
		if title_label:
			title_label.text = data.title
		if description_label:
			description_label.text = data.body_text

# Override _gui_input to ensure we're handling all input
func _gui_input(event: InputEvent) -> void:
	if is_panel_visible:
		# When panel is visible, accept all input to prevent it from reaching the game
		get_viewport().set_input_as_handled()

# Override _input to catch all input events
func _input(event: InputEvent) -> void:
	if is_panel_visible and (event is InputEventMouseButton or event is InputEventMouseMotion):
		# When panel is visible, accept all mouse input to prevent it from reaching the game
		get_viewport().set_input_as_handled()
		
		# If it's a mouse button press, mark it as handled
		if event is InputEventMouseButton:
			event.pressed = false

# Override _unhandled_input to catch any remaining input events
func _unhandled_input(event: InputEvent) -> void:
	if is_panel_visible:
		get_viewport().set_input_as_handled()
		if event is InputEventMouseButton:
			event.pressed = false

# Override _get_global_rect to ensure the builder's UI check detects us
func _get_global_rect() -> Rect2:
	if is_panel_visible:
		return Rect2(Vector2.ZERO, get_viewport_rect().size)
	return Rect2(Vector2.ZERO, Vector2.ZERO)

# Add a method to check if the mouse is over our panel
func is_mouse_over_building_selector() -> bool:
	if is_panel_visible:
		var mouse_pos = get_viewport().get_mouse_position()
		var rect = get_global_rect()
		return rect.has_point(mouse_pos)
	return false 
