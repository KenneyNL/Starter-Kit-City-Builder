extends Control

# Signal when a mission is selected
signal mission_selected(mission_id: String)

# Reference to the mission manager
var mission_manager: MissionManager
var builder: Node3D

# Dictionary to store unlockable items for each mission
var mission_unlocks: Dictionary = {}

func _ready():
	# Find mission manager
	mission_manager = get_node_or_null("/root/Main/MissionManager")
	builder = get_node_or_null("/root/Main/Builder")
	
	if not mission_manager:
		push_error("Mission select menu: MissionManager not found")
		hide()
		return
		
	if not builder:
		push_error("Mission select menu: Builder not found")
		hide()
		return
	
	# Set up the mission button container
	var container = $ScrollContainer/MissionContainer
	
	# Clear any existing children
	for child in container.get_children():
		child.queue_free()
	
	# Build the dictionary of unlockable items per mission
	_build_mission_unlocks_dictionary()
	
	# Add mission buttons
	for mission in mission_manager.missions:
		var button = Button.new()
		button.text = mission.id + ": " + mission.title
		button.custom_minimum_size = Vector2(300, 40)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Connect button press to handler
		button.connect("pressed", _on_mission_button_pressed.bind(mission.id))
		
		container.add_child(button)

# Function to build the dictionary of unlockable items per mission
func _build_mission_unlocks_dictionary():
	mission_unlocks.clear()
	
	# Add empty arrays for each mission
	for mission in mission_manager.missions:
		mission_unlocks[mission.id] = []
	
	# Fill in the unlockable items for each mission
	for mission in mission_manager.missions:
		if "unlocked_items" in mission and mission.unlocked_items.size() > 0:
			mission_unlocks[mission.id] = mission.unlocked_items

# Called when a mission button is pressed
func _on_mission_button_pressed(mission_id: String):
	print("Mission selected: " + mission_id)
	
	# Unlock all structures from previous missions
	_unlock_structures_up_to_mission(mission_id)
	
	# Find the mission by ID
	var selected_mission = null
	for mission in mission_manager.missions:
		if mission.id == mission_id:
			selected_mission = mission
			break
	
	if selected_mission:
		# First cancel any active missions
		for id in mission_manager.active_missions.keys():
			mission_manager.active_missions.erase(id)
		
		# Start the selected mission
		mission_manager.start_mission(selected_mission)
		
		# Emit signal
		mission_selected.emit(mission_id)
		
		# Hide the menu
		hide()

# Function to unlock all structures up to and including the selected mission
func _unlock_structures_up_to_mission(mission_id: String):
	print("Unlocking structures up to mission: " + mission_id)
	
	var found_mission = false
	var structures_to_unlock = []
	
	# Collect all unlockable structures up to the selected mission
	for mission in mission_manager.missions:
		# Add this mission's unlockables to the list
		if "unlocked_items" in mission and mission.unlocked_items.size() > 0:
			for item_path in mission.unlocked_items:
				structures_to_unlock.append(item_path)
		
		# If we've reached our target mission, stop
		if mission.id == mission_id:
			found_mission = true
			break
	
	if not found_mission:
		push_error("Mission ID not found: " + mission_id)
		return
	
	# Unlock the collected structures
	for item_path in structures_to_unlock:
		_unlock_structure(item_path)
	
	# Make sure the builder updates to reflect the unlocked structures
	_update_builder_structures()

# Function to unlock a specific structure by path
func _unlock_structure(item_path: String):
	print("\nAttempting to unlock structure: " + item_path)
	
	# Get structures from builder
	var structures = builder.get_structures()
	if not structures:
		print("ERROR: No structures available")
		return
	
	# Convert .tres path to .glb path for comparison
	var glb_path = item_path.replace(".tres", ".glb")
	print("Looking for matching structure with paths:")
	print("Original path: " + item_path)
	print("GLB path: " + glb_path)
	
	# Find the structure in builder's structures
	var found = false
	for structure in structures:
		if structure.model:
			# Check for exact match with either path
			if structure.model.resource_path == item_path or structure.model.resource_path == glb_path:
				if "unlocked" in structure:
					structure.unlocked = true
					found = true
					break
			
			# Check for base name match (without extension)
			elif structure.model.resource_path.get_basename() == item_path.get_basename():
				if "unlocked" in structure:
					structure.unlocked = true
					found = true
					break
	
	if not found:
		print("WARNING: No matching structure found for: " + item_path)

# Function to update the builder after unlocking structures
func _update_builder_structures():
	if builder:
		var structures = builder.get_structures()
		if not structures:
			print("ERROR: No structures available")
			return
			
		# Find a valid unlocked structure to set as current
		var found_unlocked = false
		for i in range(structures.size()):
			if "unlocked" in structures[i] and structures[i].unlocked:
				builder.index = i
				builder.update_structure()
				found_unlocked = true
				break
				
		if not found_unlocked and structures.size() > 0:
			# Force unlock the first structure as fallback
			if "unlocked" in structures[0]:
				structures[0].unlocked = true
				builder.index = 0
				builder.update_structure()

# Function to toggle the menu visibility
func toggle_visibility():
	visible = !visible
	
	# If becoming visible, refresh mission list
	if visible:
		_ready()
