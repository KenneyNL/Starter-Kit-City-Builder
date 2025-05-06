extends Node

# Signals
signal electricity_updated(usage, production)
signal population_updated(count)

# Variables
var total_population: int = 0
var total_kW_usage: float = 0.0
var total_kW_production: float = 0.0
@export var show_mission_select: bool = false:
	set(value):
		show_mission_select = value
		_update_mission_select_visibility()

# References
var mission_select_menu: Control
var mission_select_button: TextureButton
var building_construction_manager
var population_label: Label
var electricity_label: Label
var electricity_indicator: ColorRect
var population_tooltip: Control
var electricity_tooltip: Control
var controls_panel: PanelContainer
var sound_panel: PanelContainer
var structure_menu: Control
@onready var _builder = get_node_or_null("/root/Main/Builder")

func _ready():
	# Connect to signals from the builder
	if _builder:
		_builder.structure_placed.connect(_on_structure_placed)
		_builder.structure_removed.connect(_on_structure_removed)

	# Initialize UI elements
	population_label = $HBoxContainer/PopulationItem/PopulationLabel
	electricity_label = $HBoxContainer/ElectricityItem/ElectricityValues/ElectricityLabel
	electricity_indicator = $HBoxContainer/ElectricityItem/ElectricityValues/ElectricityIndicator
	population_tooltip = $PopulationTooltip
	electricity_tooltip = $ElectricityTooltip
	mission_select_button = $HBoxContainer/MissionSelectItem/MissionSelectButton
	
	# Get references to panels
	controls_panel = get_node_or_null("/root/Main/CanvasLayer/ControlsPanel")
	sound_panel = get_node_or_null("/root/Main/CanvasLayer/SoundPanel")
	structure_menu = get_node_or_null("/root/Main/CanvasLayer/StructureMenu")
	
	# Setup mission select button
	if mission_select_button:
		if not mission_select_button.pressed.is_connected(_on_mission_select_button_pressed):
			mission_select_button.pressed.connect(_on_mission_select_button_pressed)
	else:
		push_error("Mission select button not found in HUD")
	
	# Setup mission select menu
	_setup_mission_select_menu()
	
	# Setup structure menu
	_setup_structure_menu()
	
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Update mission select visibility based on export variable
	_update_mission_select_visibility()
	
	# Ensure electricity indicator starts with red color
	if electricity_indicator:
		electricity_indicator.color = Color(1, 0, 0)  # Start with red
	
	# Hide the electricity label for now (keeping implementation for later)
	if electricity_label:
		electricity_label.visible = false
	
	# Set tooltips
	if population_tooltip:
		population_tooltip.get_node("Label").text = "Total city population"
	
	if electricity_tooltip:
		electricity_tooltip.get_node("Label").text = "Electricity supply vs demand"
	
	# Hide tooltips initially
	if population_tooltip:
		population_tooltip.visible = false
	
	if electricity_tooltip:
		electricity_tooltip.visible = false
	
	# Update HUD
	update_hud()

# Set up the mission select menu
func _setup_mission_select_menu():
	# Check if the mission select menu already exists
	mission_select_menu = get_node_or_null("/root/Main/CanvasLayer/MissionSelectMenu")
	
	# If not, instantiate and add it
	if not mission_select_menu:
		var mission_select_scene = load("res://scenes/mission_select_menu.tscn")
		if mission_select_scene:
			mission_select_menu = mission_select_scene.instantiate()
			var canvas_layer = get_node_or_null("/root/Main/CanvasLayer")
			if canvas_layer:
				canvas_layer.add_child(mission_select_menu)
				# Make sure it's initially hidden
				mission_select_menu.hide()

# Set up the structure menu
func _setup_structure_menu():
	# Check if the structure menu already exists
	structure_menu = get_node_or_null("/root/Main/CanvasLayer/StructureMenu")
	
	# If not, instantiate and add it
	if not structure_menu:
		var structure_menu_scene = load("res://scenes/structure_menu.tscn")
		if structure_menu_scene:
			structure_menu = structure_menu_scene.instantiate()
			var canvas_layer = get_node_or_null("/root/Main/CanvasLayer")
			if canvas_layer:
				# Use call_deferred to add the child
				canvas_layer.add_child.call_deferred(structure_menu)
				# Set the builder reference after a frame to ensure the node is added
				await get_tree().process_frame
				if _builder:
					structure_menu.builder = _builder
	
# Update mission select visibility based on export variable
func _update_mission_select_visibility():
	if not is_inside_tree():
		# If we're not in the tree yet, wait until we are
		await ready
		
	var mission_select_item = get_node_or_null("HBoxContainer/MissionSelectItem")
	if mission_select_item:
		mission_select_item.visible = show_mission_select
	else:
		push_warning("MissionSelectItem node not found in HUD")
		
# Handle mission select button press
func _on_mission_select_button_pressed():
	print("Mission select button pressed")
	
	# Make sure the menu exists
	if not mission_select_menu:
		_setup_mission_select_menu()
	
	if mission_select_menu:
		print("Toggling mission select menu visibility")
		mission_select_menu.toggle_visibility()
	else:
		push_error("Mission select menu not found after setup attempt")

func _process(delta):
	# Update the population label if it changes
	if population_label and Globals.population != total_population:
		total_population = Globals.population
		population_label.text = str(total_population)


# Called when a structure is placed
func _on_structure_placed(structure_index, position):
	if !_builder or structure_index < 0 or structure_index >= _builder.structures.size():
		return
	
	var structure = _builder.structures[structure_index]
	
	# Only update population for non-residential buildings or if we're NOT in the construction mission
	var is_residential = structure.type == Structure.StructureType.RESIDENTIAL_BUILDING
	var mission_manager = get_node_or_null("/root/Main/MissionManager")
	var using_construction = false
	if mission_manager and mission_manager.current_mission:
		var mission_id = mission_manager.current_mission.id
		using_construction = (mission_id == "3" or mission_id == "1")
		
	# Always update electricity usage/production
	total_kW_usage += structure.kW_usage
	total_kW_production += structure.kW_production
	
	# Update HUD
	update_hud()
	
	# Emit signals
	electricity_updated.emit(total_kW_usage, total_kW_production)
	
# Called when a structure is removed
func _on_structure_removed(structure_index, position):
	if !_builder or structure_index < 0 or structure_index >= _builder.structures.size():
		return
	
	var structure = _builder.structures[structure_index]
	
	# Update population (but only for non-residential buildings in mission 3)
	# For residential buildings in mission 3, we handle population separately in _builder._remove_resident_for_building
	var skip_population_update = false
	var mission_manager = get_node_or_null("/root/Main/MissionManager")
	
	if mission_manager and mission_manager.current_mission:
		if mission_manager.current_mission.id == "3" and structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
			# Only update population for one resident, since we're removing them one by one
			# We don't do total reset based on structure.population_count
			skip_population_update = true
			# We decrement by 1 in _builder._remove_resident_for_building instead
			
	if !skip_population_update:
		total_population = max(0, total_population - structure.population_count)
	
	# Update electricity
	total_kW_usage = max(0, total_kW_usage - structure.kW_usage)
	total_kW_production = max(0, total_kW_production - structure.kW_production)
	
	# Update HUD
	update_hud()
	
	# Emit signals
	electricity_updated.emit(total_kW_usage, total_kW_production)
	
	
# Update Population
func set_population_count(count: int):
	total_population += count
	population_label.text = str(total_population)
	
#	# Emit signal
#	increased_population.emit(added_population)
	
# Updates the HUD elements
func update_hud():
	# Update population label
	if population_label:
		population_label.text = str(total_population)
	
	# Update electricity label and indicator
	if electricity_label:
		# Default to red for the electricity indicator
		var indicator_color = Color(1, 0, 0)  # Red
		
		if total_kW_usage > 0:
			# If we have usage, check if production meets or exceeds it
			
			# Only set to green if we meet or exceed demand
			if total_kW_production >= total_kW_usage:
				indicator_color = Color(0, 1, 0)  # Green
			else:
				# Not enough power - keep it red
				indicator_color = Color(1, 0, 0)  # Red
				
			# Update electricity label text (hidden for now but kept for future use)
			electricity_label.text = str(total_kW_usage) + "/" + str(total_kW_production) + " kW"
		else:
			# If no usage but we have production, show green
			if total_kW_production > 0:
				indicator_color = Color(0, 1, 0)  # Green
				electricity_label.text = "0/" + str(total_kW_production) + " kW"
			else:
				# No usage and no production - show neutral color (gray)
				indicator_color = Color(0.7, 0.7, 0.7)  # Gray
				electricity_label.text = "0/0 kW"
		
		# Hide the text label for now, but keep implementation for later
		electricity_label.visible = false
		
		# Update the color of the indicator rectangle
		if electricity_indicator:
			electricity_indicator.color = indicator_color

# Tooltip handling
func _on_population_icon_mouse_entered():
	if population_tooltip:
		population_tooltip.visible = true

func _on_population_icon_mouse_exited():
	if population_tooltip:
		population_tooltip.visible = false

func _on_electricity_icon_mouse_entered():
	if electricity_tooltip:
		electricity_tooltip.visible = true

func _on_electricity_icon_mouse_exited():
	if electricity_tooltip:
		electricity_tooltip.visible = false
		
# Called when the sound button is pressed
func _on_sound_button_pressed():
	# Consume the event to prevent click-through to the world
	get_viewport().set_input_as_handled()
	
	if sound_panel:
		sound_panel.show_panel()

# Called when the help button is pressed
func _on_help_button_pressed():
	# Consume the event to prevent click-through to the world
	get_viewport().set_input_as_handled()
	
	if controls_panel:
		controls_panel.show_panel()

# Called when the music volume is changed
func _on_music_volume_changed(new_volume):
	pass  # Sound panel handles this through signals

# Called when the sfx volume is changed
func _on_sfx_volume_changed(new_volume):
	pass  # Sound panel handles this through signals

# Called when the music is muted
func _on_music_muted_changed(is_muted):
	pass  # Sound panel handles this through signals

# Called when the sfx is muted
func _on_sfx_muted_changed(is_muted):
	pass  # Sound panel handles this through signals

func is_mouse_over_structure_menu() -> bool:
	if structure_menu and structure_menu.has_method("is_mouse_over_menu"):
		return structure_menu.is_mouse_over_menu()
	return false
