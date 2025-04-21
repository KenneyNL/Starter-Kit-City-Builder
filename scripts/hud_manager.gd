extends Node

# Signals

signal electricity_updated(usage, production)
# Variables
var total_population: int = 0
var total_kW_usage: float = 0.0
var total_kW_production: float = 0.0

# References
var buildeJuj
var building_construction_manager
var population_label: Label
var electricity_label: Label
var electricity_indicator: ColorRect
var population_tooltip: Control
var electricity_tooltip: Control
var controls_panel: PanelContainer
var sound_panel: PanelContainer
var builder:Node

func _ready():
	# Connect to signals from the builder
	builder = get_node_or_null("/root/Main/Builder")
	if builder:
		builder.structure_placed.connect(_on_structure_placed)
		builder.structure_removed.connect(_on_structure_removed)


#	EventBus.population_update.connect(set_population_count)
		
	# Initialize UI elements
	population_label = $HBoxContainer/PopulationItem/PopulationLabel
	electricity_label	 = $HBoxContainer/ElectricityItem/ElectricityValues/ElectricityLabel
	electricity_indicator = $HBoxContainer/ElectricityItem/ElectricityValues/ElectricityIndicator
	population_tooltip = $PopulationTooltip
	electricity_tooltip = $ElectricityTooltip


	
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
	
	
func _process(delta):
	# Update the population label if it changes
	if population_label and Globals.population != total_population:
		total_population = Globals.population
		population_label.text = str(total_population)


# Called when a structure is placed
func _on_structure_placed(structure_index, position):
	if !builder or structure_index < 0 or structure_index >= builder.structures.size():
		return
	
	var structure = builder.structures[structure_index]
	
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
	if !builder or structure_index < 0 or structure_index >= builder.structures.size():
		return
	
	var structure = builder.structures[structure_index]
	
	# Update population (but only for non-residential buildings in mission 3)
	# For residential buildings in mission 3, we handle population separately in builder._remove_resident_for_building
	var skip_population_update = false
	var mission_manager = get_node_or_null("/root/Main/MissionManager")
	
	if mission_manager and mission_manager.current_mission:
		if mission_manager.current_mission.id == "3" and structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
			# Only update population for one resident, since we're removing them one by one
			# We don't do total reset based on structure.population_count
			skip_population_update = true
			# We decrement by 1 in builder._remove_resident_for_building instead
			
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
