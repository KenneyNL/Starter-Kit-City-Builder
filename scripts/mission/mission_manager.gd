extends Node
class_name MissionManager

# Add the JavaScript bridge for HTML5 export
# This ensures JavaScript is available and degrades gracefully on other platforms
const JSBridge = preload("res://scripts/javascript_bridge.gd")
const ObjectiveType = preload("res://configs/data.config.gd").ObjectiveType
const StructureUnlocking = preload("res://scripts/mission/structure_unlocking.gd")

# Add to the top with other preloads
const MissionLoader = preload("res://scripts/mission/mission_loader.gd")

signal mission_started(mission: MissionData)
signal mission_completed(mission: MissionData)
signal objective_completed(objective: MissionObjective)
signal objective_progress(objective: MissionObjective, new_count: int)
signal game_started()
signal all_missions_completed()
signal structures_unlocked()  # New signal for when structures are unlocked
signal bridge_connection_completed


@export var missions: Array[MissionData] = []
@export var mission_ui: Control
@export var builder: Node3D
@export var character_scene: PackedScene

var current_mission: MissionData
var current_objective: MissionObjective
var active_missions: Dictionary = {}  # mission_id: MissionData
 
var character_spawned: bool = false
var learning_companion_connected: bool = false

# Panel state tracking
var is_unlocked_panel_showing: bool = false
var delayed_mission_start_queue     = []  # Queue of missions to start after unlocked panel closes

# Mission skip variables
var skip_key_presses: int = 0
var last_skip_press_time: float = 0
var skip_key_timeout: float = 1.0  # Reset counter if time between presses exceeds this value
var skip_key_required: int = 5  # Number of key presses needed to skip
const SKIP_KEY = KEY_TAB  # The key to press for skipping missions

# Reference for the learning panel without type hint
var learning_panel
var fullscreen_learning_panel

# Add after other variables
var learning_panel_scene: PackedScene
var mission_loader: MissionLoader
var fullscreen_learning_panel_scene: PackedScene

func _ready() -> void:
	print("\n=== Starting Mission Manager Initialization ===")
	
	# Set up communication with the learning companion first, before ANY other initialization
	print("Attempting to establish JavaScript bridge...")
	await _setup_learning_companion_communication()
	print("JavaScript bridge setup completed")
	
	# Connect to the generic_text_panel closed signal if it exists
	var generic_text_panel = get_node_or_null("/root/Main/CanvasLayer/GenericTextPanel")
	if generic_text_panel and generic_text_panel.has_signal("closed"):
		print("Found generic_text_panel, connecting to closed signal")
		if generic_text_panel.is_connected("closed", _on_learning_panel_closed_for_react):
			generic_text_panel.disconnect("closed", _on_learning_panel_closed_for_react)
		generic_text_panel.closed.connect(_on_learning_panel_closed_for_react)
	
	# Only proceed with other initialization after bridge is established
	print("\n=== Starting Mission Loader Initialization ===")
	# Initialize mission loader
	mission_loader = MissionLoader.new(self, builder)
	print("Mission loader initialized")
	
	# Connect to event bus and builder signals
	print("\n=== Setting up Event Connections ===")
	EventBus.population_update.connect(population_updated)
	EventBus.receive_data_from_browser.connect(_on_init_data_received)
	print("Connected to population update event")

#	init_data_received.connect(_on_init_data_received)	
	# Connect to the JavaScript bridge
#	if OS.has_feature("web"):
#		var js = Engine.get_singleton("JavaScriptBridge")
#		if js:
#			print("Connecting Javascript to ")
#			js.connect("init_data_received", Callable(self, "_on_init_data_received"))

	if builder:
		# Connect to builder signals
		builder.connect("structure_placed", _on_structure_placed)
		print("Connected to structure_placed signal")
		# Connect to construction manager signals
		if builder.construction_manager:
			builder.construction_manager.construction_completed.connect(_on_construction_completed)
			print("Connected to construction_completed signal")
	
	print("\n=== Setting up Learning Panels ===")
	# Find and remove existing learning panel to avoid conflicts
	var old_panel = get_node_or_null("LearningPanel")
	if old_panel:
		old_panel.queue_free()
		print("Removed existing learning panel")
		
	print("\n=== Setting up Connection Timer ===")
	# Create a simple timer to force a learning companion connection in 3 seconds
	# This is a fallback in case the normal connection doesn't work
	var connection_timer = Timer.new()
	connection_timer.wait_time = 3.0
	connection_timer.one_shot = true
	connection_timer.autostart = true
	connection_timer.name = "ConnectionTimer"
	add_child(connection_timer)
	connection_timer.timeout.connect(_force_learning_companion_connection)
	print("Connection timer set up")
	
	print("\n=== Emitting Game Started Signal ===")
	# Emit game_started signal before starting the first mission
	game_started.emit()
	
	# Start the first mission if available
	if missions.size() > 0:
		print("Starting first mission")
		start_mission(missions[0])
	else:
		print("No missions available to start")
	
	print("=== Mission Manager Initialization Complete ===\n")

# Web-specific audio initialization helper methods
func _on_gui_focus_for_audio(_control=null):
	if OS.has_feature("web"):
		_try_init_audio_on_interaction()

func _on_gui_input_for_audio(_event=null):
	if OS.has_feature("web"):
		_try_init_audio_on_interaction()

# Used to handle input for possible audio initialization in web
func _input(event):
	# Process mission skipping
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == SKIP_KEY:  # Use the configured skip key
			var current_time = Time.get_ticks_msec() / 1000.0
			
			# Reset counter if too much time has passed since last press
			if current_time - last_skip_press_time > skip_key_timeout:
				skip_key_presses = 0
			
			# Update time and increment counter
			last_skip_press_time = current_time
			skip_key_presses += 1
			
			# Show progress toward skipping
			if mission_ui and mission_ui.has_method("show_temporary_message"):
				if skip_key_presses < skip_key_required:
					mission_ui.show_temporary_message("Mission skip: " + str(skip_key_presses) + "/" + str(skip_key_required) + " presses", 0.75, Color(1.0, 0.7, 0.2))
				else:
					mission_ui.show_temporary_message("Mission skipped!", 2.0, Color(0.2, 0.8, 0.2))
			
			# Check if we've reached the required number of presses
			if skip_key_presses >= skip_key_required:
				skip_key_presses = 0
				_skip_current_mission()

	# For web builds, use any input to initialize audio
	if OS.has_feature("web"):
		if event is InputEventMouseButton or event is InputEventKey:
			if event.pressed:
				_try_init_audio_on_interaction()

# Helper to try initializing audio on user interaction
func _try_init_audio_on_interaction():
	# Find the sound manager
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager and not sound_manager.audio_initialized:
		sound_manager._initialize_web_audio()
		
		# Also use JavaScript bridge to help with audio
		if JSBridge.has_interface():
			JSBridge.get_interface().ensure_audio_initialized()
		
		# Try to kick-start music if game manager exists
		var game_manager = get_node("/root/GameManager")
		if game_manager and game_manager.has_method("_start_background_music"):
			game_manager._start_background_music()
		
# Function to set up communication with the learning companion
func _setup_learning_companion_communication() -> void:
	print("\n=== Setting up JavaScript Bridge ===")
	# First, check if JavaScript is available
	if JSBridge.has_interface():
		print("JavaScript interface found")
		var js_interface = JSBridge.get_interface()
		if js_interface:
			print("JavaScript interface initialized")
			#init_data_received.connect(_on_init_data_received)
			
			# In web environment, we'll skip audio initialization for now
			if OS.has_feature("web"):
				print("Running in web environment - skipping audio initialization")
			else:
				# Try to initialize audio first since we now have user interaction
				if js_interface.has_method("ensure_audio_initialized"):
					print("Initializing audio...")
					js_interface.ensure_audio_initialized()
					print("Audio initialization complete")
			
			# Connect directly using the simpler postMessage approach
			if js_interface.has_method("connectLearningCompanionViaPostMessage"):
				print("Setting up learning companion connection...")
				
				# Create a safe callback wrapper
				var success_wrapper = func():
					print("Learning companion connection successful")
					learning_companion_connected = true
					# Connect signals to JavaScript callbacks
					game_started.connect(_on_game_started_for_companion)
					mission_started.connect(_on_mission_started_for_companion)
					mission_completed.connect(_on_mission_completed_for_companion)
					all_missions_completed.connect(_on_all_missions_completed_for_companion)
					print("Connected all JavaScript callbacks")
					
					# Request initial mission data if available
					if js_interface.has_method("requestInitialMissionData"):
						print("Requesting initial mission data...")
						js_interface.requestInitialMissionData()
						print("Initial mission data request sent")
					
					# Emit signal that connection is complete
					bridge_connection_completed.emit()
				
				var error_wrapper = func():
					print("Learning companion connection failed")
					learning_companion_connected = false
					# Still emit signal even on failure
					bridge_connection_completed.emit()
				
				# Call the connection method with our wrapped callbacks
				js_interface.connectLearningCompanionViaPostMessage(success_wrapper, error_wrapper)
				
				print("Waiting for learning companion connection...")
				# Wait for the connection to be established
				await bridge_connection_completed
				print("Learning companion connection process complete")
			else:
				print("WARNING: connectLearningCompanionViaPostMessage method not found - continuing without JavaScript bridge")
				bridge_connection_completed.emit()
		else:
			print("WARNING: Failed to get JavaScript interface - continuing without JavaScript bridge")
			bridge_connection_completed.emit()
	else:
		print("WARNING: No JavaScript interface available - continuing without JavaScript bridge")
		bridge_connection_completed.emit()
	print("=== JavaScript Bridge Setup Complete ===\n")

# Helper function to safely find UI elements
func _find_ui_element(path: String, required: bool = true) -> Node:
	var element = get_node_or_null(path)
	if required and not element:
		push_warning("Required UI element not found: " + path)
	return element

# Function to show learning panel with error handling
func _show_learning_panel(mission: MissionData) -> void:
	if not learning_panel:
		push_warning("Learning panel not found")
		return
		
	# Check for required UI elements
	var submit_button = _find_ui_element("LearningPanelFromScene/PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/UserInputContainer/SubmitButton", false)
	if not submit_button:
		push_warning("Submit button not found in learning panel - some functionality may be limited")
		# Continue anyway since this is not critical
	
	# Show the panel
	learning_panel.show_learning_panel(mission)
	
	# We set current_mission when starting a mission, so there's no need to store it again
	# We now use the generic_text_panel.closed signal configured in _ready()

# We use current_mission directly now, no need for _current_learning_mission
	
# This function handles showing graph or table data after panel closes
func _on_learning_panel_closed_for_react() -> void:
	# For generic text panel, we don't need to disconnect since the signal connection is handled in _ready
	
	# We now use the current_mission property directly instead of _current_learning_mission
	print("Panel closed, checking for graph/table data to display")
	
	# Check if we have a current mission
	if not current_mission:
		print("No current mission")
		return
		
	print("Current mission: ", current_mission.id, ", open_react_graph: ", current_mission.open_react_graph, ", open_react_table: ", current_mission.open_react_table)
	
	# Send React data via the autoloaded JavaScriptBridge node
	if current_mission.open_react_graph:
		print("Opening React graph with data:", current_mission.react_data)
		JSBridge.send_open_graph(current_mission.react_data)
	elif current_mission.open_react_table:
		print("Opening React table with data:", current_mission.react_table_data)
		JSBridge.send_open_table({"table_data":current_mission.react_table_data, "description": current_mission.intro_text})
	
	# We're now using current_mission directly, so no need to clear anything

# Function to start mission with error handling
func start_mission(mission: MissionData):
	if not mission:
		push_error("Cannot start mission: mission is null")
		return
		
	current_mission = mission
	
	# Process structure unlocking
	if builder:
		var structures = builder.get_structures()
		if structures:
			# Only unlock starting structures at mission start
			if mission.starting_structures.size() > 0:
				for structure_path in mission.starting_structures:
					if not ResourceLoader.exists(structure_path):
						push_error("Structure not found: " + structure_path)
						continue
					mission_loader._unlock_starting_structures([structure_path])
				builder.update_structure()  # Update the current structure display
				
				# Emit signal that structures have been unlocked
				structures_unlocked.emit()
	
	# Set first objective as current
	if mission.objectives.size() > 0:
		current_objective = mission.objectives[0]
		# Find the index of the current objective in the array
		var objective_index = 0
		for i in range(mission.objectives.size()):
			if mission.objectives[i] == current_objective:
				objective_index = i
				break
		
	# Update UI
	if mission_ui:
		mission_ui.update_mission_display(mission)
		
	# Show intro text if available
	if mission.intro_text:
		_show_learning_panel(mission)
			
	# Add mission to active missions
	active_missions[mission.id] = mission
			
	# Emit signal that mission has started
	mission_started.emit(mission)

func complete_mission(mission_id: String):
	if not active_missions.has(mission_id):
		return
	
	var mission = active_missions[mission_id]
	
	# Grant rewards
	if mission.rewards.has("cash") and builder:
		builder.map.cash += mission.rewards.cash
		builder.update_cash()
	
	# Handle structure unlocking when mission is completed
	_handle_structure_unlocking(mission)
	
	# Keep a copy of the mission for UI display during transition
	var completed_mission = mission
	
	# Emit mission completed signal
	mission_completed.emit(mission)
	
	# Only remove from active missions after we're ready to show the next one
	await get_tree().create_timer(2.0).timeout
	active_missions.erase(mission_id)
	
	var next_mission = get_next_mission(mission_id)
	if next_mission:
		if is_unlocked_panel_showing:
			print("Unlock panel showing, queueing next mission start.")
			delayed_mission_start_queue.append(next_mission)
		else:
			print("Starting next mission: " + str(next_mission.id))
			start_mission(next_mission)
	else:
		print("No more missions to start.")
		all_missions_completed.emit()
		await get_tree().create_timer(2.0).timeout

func update_objective_progress(structure:Structure = null):
	print("\n=== Updating Objective Progress ===")
	print("Objective type: ", current_objective.type)
	print("Current count: ", current_objective.current_count)
	print("Target count: ", current_objective.target_count)
	
	if current_objective.type == ObjectiveType.BUILD_RESIDENTIAL:
		print("Updating BUILD_RESIDENTIAL objective")
		print("Structure population count: ", structure.population_count)
		current_objective.current_count += structure.population_count
		print("New count: ", current_objective.current_count)
		if current_objective.target_count <= current_objective.current_count:
			current_objective.completed = true
			objective_completed.emit(current_objective)
			var dialog_key = "objective_completed_" + str(current_objective.type)
			_send_companion_dialog(dialog_key, current_mission)
			update_current_objective(current_mission)
	elif current_objective.type == ObjectiveType.BUILD_STRUCTURE:
		print("Updating BUILD_STRUCTURE objective")
		current_objective.current_count += 1
		print("New count: ", current_objective.current_count)
		if current_objective.target_count <= current_objective.current_count:
			current_objective.completed = true
			objective_completed.emit(current_objective)
			var dialog_key = "objective_completed_" + str(current_objective.type)
			_send_companion_dialog(dialog_key, current_mission)
			update_current_objective()
	elif current_objective.type == ObjectiveType.REACH_POPULATION:
		if Globals.population >= current_objective.target_count:
			current_objective.completed = true
			objective_completed.emit(current_objective)
			var dialog_key = "objective_completed_" + str(current_objective.type)
			_send_companion_dialog(dialog_key, current_mission)
			update_current_objective()

	objective_progress.emit(current_objective, current_objective.current_count)
	
	# Force UI update after objective progress
	if mission_ui:
		mission_ui.update_mission_display(current_mission)

func is_structure_of_current_mission(structure:Structure):
	if not current_mission:
		return false
		
	# Handle BUILD_STRUCTURE objective type
	if current_objective.type == ObjectiveType.BUILD_STRUCTURE:
		# Check if the placed structure matches the objective's structure exactly
		if current_objective.structure and structure.model:
			return current_objective.structure.resource_path == structure.model.resource_path
			
	return false

func _on_structure_placed(structure_index, position):
	# Get the structure that was placed
	if structure_index < 0 or structure_index >= builder.structures.size():
		return
		
	var structure = builder.structures[structure_index]
	
	# Check if this structure is needed for the current objective
	if current_mission and current_objective:
		# Handle structure-based objectives
		if current_objective.type == ObjectiveType.BUILD_STRUCTURE:
			# Check if the structure matches the objective's required structure exactly
			print(current_objective.structure.resource_path)
			print(structure.model.resource_path)
			if current_objective.structure and structure.model and current_objective.structure.resource_path == structure.resource_path:
				# For buildings, we'll update progress after construction completes
				if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
					# Connect to the construction_completed signal if it exists
					if builder.has_signal("construction_completed"):
						if not builder.is_connected("construction_completed", _on_construction_completed):
							builder.construction_completed.connect(_on_construction_completed)
				else:
					# For non-building structures, update progress immediately
					update_objective_progress(structure)
		elif current_objective.type == ObjectiveType.BUILD_RESIDENTIAL and structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
			# For residential buildings, update progress after construction completes
			if builder.has_signal("construction_completed"):
				if not builder.is_connected("construction_completed", _on_construction_completed):
					builder.construction_completed.connect(_on_construction_completed)

# Handle construction completion
func _on_construction_completed(position: Vector3):
	if not current_mission or not current_objective:
		return
		
	# Find the structure at this position
	var structure = null
	if builder and builder.gridmap:
		var cell = builder.gridmap.get_cell_item(position)
		if cell >= 0 and cell < builder.structures.size():
			structure = builder.structures[cell]
	
	if structure:
		print("\n=== Checking Structure for Objective ===")
		print("Structure type: ", structure.type)
		print("Structure model: ", structure.model.resource_path if structure.model else "null")
		print("Current objective type: ", current_objective.type)
		print("Current objective structure: ", current_objective.structure.resource_path if current_objective.structure else "null")
		
		# Check if this structure counts for our current objective
		if current_objective.type == ObjectiveType.BUILD_STRUCTURE:
			# Check if the structure matches the objective's required structure
			if current_objective.structure and structure.model:
				var model_name = structure.model.resource_path.get_file().get_basename()
				var structure_name = current_objective.structure.resource_path.get_file().get_basename()
				if model_name == structure_name:
					print("Structure matches BUILD_STRUCTURE objective")
					update_objective_progress(structure)
				else:
					print("Structure does not match BUILD_STRUCTURE objective")
		elif current_objective.type == ObjectiveType.BUILD_RESIDENTIAL:
			# Check both the structure type AND the specific structure required
			if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING and current_objective.structure and structure.model:
				var model_name = structure.model.resource_path.get_file().get_basename()
				var structure_name = current_objective.structure.resource_path.get_file().get_basename()
				if model_name == structure_name:
					print("Structure matches BUILD_RESIDENTIAL objective")
					update_objective_progress(structure)
				else:
					print("Structure does not match BUILD_RESIDENTIAL objective")
		else:
			print("Structure does not match any objective criteria")

# Only used for mission 3, to disable builder functionality during the companion dialog
func _on_learning_panel_opened():
	if builder:
		builder.disabled = true

# Only used for mission 3, to re-enable builder functionality after dialog is complete
func _on_learning_panel_closed():
	if builder:
		builder.disabled = false
	
func _on_learning_completed(mission):
	if mission:
		# If the mission has a learning objective, mark it as completed
		for objective in mission.objectives:
			if objective.type == MissionObjective.ObjectiveType.LEARNING:
				objective.current_count = objective.target_count  # Set to target count
				objective.completed = true
				objective_completed.emit(objective)
				
				# Update the UI
				update_mission_ui()
				
				# Explicitly complete the mission after a short delay
				await get_tree().create_timer(1.0).timeout
				complete_mission(mission.id)
				break
				
	# Set a callback to dismiss learning panel if needed
	await get_tree().create_timer(1.0).timeout
	_check_learning_panel_state()
	
func _check_learning_panel_state():
	# Check if the learning panel should be auto-closed
	var should_auto_close = true
	
	if current_mission:
		# If the mission is still active (not completed), may need to keep panel open
		var mission = current_mission
		
		# If power_math_content is non-empty, this is a "calculator" mission
		# that should keep the panel open until the user completes the mission
		if mission.power_math_content != "":
			should_auto_close = false
		
		# Check if all learning objectives are complete but other objectives remain
		var learning_objectives_complete = true
		var other_objectives_incomplete = false
		
		for objective in mission.objectives:
			if objective.type == MissionObjective.ObjectiveType.LEARNING:
				learning_objectives_complete = learning_objectives_complete and objective.completed
			else:
				other_objectives_incomplete = other_objectives_incomplete or not objective.completed
		
		# If all learning is complete but we still have other objectives, auto close
		if learning_objectives_complete and other_objectives_incomplete:
			should_auto_close = true

	# Automatically close the panel if appropriate
	if should_auto_close:
		if learning_panel and learning_panel.visible:
			learning_panel.hide_learning_panel()
		if fullscreen_learning_panel and fullscreen_learning_panel.visible:
			fullscreen_learning_panel.hide_fullscreen_panel()

# Skip to the next mission (for debug/testing)
func _skip_current_mission():
	if current_mission:
		# Get the next mission ID
		var next_mission_id = current_mission.next_mission_id
		
		# Complete the current mission
		
		# Force all objectives to be complete
		for objective in current_mission.objectives:
			objective.current_count = objective.target_count
			objective.completed = true
		
		# Complete the mission
		complete_mission(current_mission.id)

# Called when the unlocked panel is shown - used for additional state tracking
func _on_unlocked_panel_shown():
	# Update panel state
	is_unlocked_panel_showing = true
	
	# This ensures that learning panels won't appear while this panel is visible
	if learning_panel and learning_panel.visible:
		learning_panel.hide_learning_panel()
	
	if fullscreen_learning_panel and fullscreen_learning_panel.visible:
		fullscreen_learning_panel.hide_fullscreen_panel()

# Helper function to process any delayed mission starts after panel closes
func _process_delayed_mission_starts():
	if delayed_mission_start_queue.size() > 0:
		# Get the first mission in the queue
		var next_mission = delayed_mission_start_queue.pop_front()
		
		# Clear the rest of the queue - we only start the next mission
		# This prevents multiple mission starts if there were more queued
		delayed_mission_start_queue.clear()
		
		# Start the mission
		if next_mission:
			# Use a short delay to ensure the UI is fully updated
			await get_tree().create_timer(0.5).timeout
			start_mission(next_mission)

# Function to spawn a character at a residential building
func _spawn_character_on_road(building_position: Vector3):
	if not character_scene:
		return
		
	if not builder:
		return
		
	# Find the nearest road to the building
	var nearby_road = _find_nearest_road(building_position, builder.gridmap)
	if nearby_road == Vector3.ZERO:
		return
	
	# Check if the road is associated with a navigation mesh
	var has_navigation = false
	
	# Get the navigation region
	var nav_region = builder.nav_region
	if nav_region:
		has_navigation = true
	
	# Create the character
	var character = character_scene.instantiate()
	character.name = "Resident_" + str(int(building_position.x)) + "_" + str(int(building_position.z))
	
	# Add the character either to the NavRegion3D or directly to the scene
	if nav_region:
		nav_region.add_child(character)
	else:
		# Add to the builder as fallback
		builder.add_child(character)
	
	# Position the character on the road
	character.global_transform.origin = nearby_road
	character.global_transform.origin.y = 0.0  # Make sure the character is at ground level
	
	# Store the home position for the character
	if character.get("home_position") != null:
		character.home_position = building_position
	
	# If the character has a population_manager reference, set it
	if character.get("population_manager") != null:
		var population_manager = get_node_or_null("/root/Main/PopulationManager")
		if population_manager:
			character.population_manager = population_manager
	
	# If the character has a gridmap reference, set it
	if character.get("gridmap") != null:
		character.gridmap = builder.gridmap
	
	# If the character has random colors, apply them
	if character.has_method("randomize_colors"):
		character.randomize_colors()
		
	# Add to a group for easier finding later
	character.add_to_group("characters")
	
	# Assume that the character has a move_to method if it's a navigation agent
	if character.has_method("move_to"):
		# Find a patrol target for the character
		var patrol_target = _find_patrol_target(nearby_road, builder.gridmap, 10.0)
		character.move_to(patrol_target)
		
	# Set character as spawned to prevent multiple spawns
	character_spawned = true
	
	# Make sure the character has auto-patrol is enabled if the character supports it
	if character.get("auto_patrol") != null:
		character.auto_patrol = true
		
	# Set a starting movement target if not moving
	await get_tree().create_timer(2.0).timeout
	if character.get("is_moving") != null and !character.is_moving:
		if character.has_method("pick_random_target"):
			character.pick_random_target()
		
func _find_patrol_target(start_position: Vector3, gridmap: GridMap, max_distance: float) -> Vector3:
	# With the navigation mesh system, we can simplify this to just return a point
	# some distance away, and the navigation system will handle finding a path
	
	# Find a suitable target for navigation patrol
	var directions = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	
	# Get the navigation region
	var nav_region = builder.nav_region
	if nav_region:
		# Try all four directions to find any road we can navigate to
		for direction in directions:
			for distance in range(1, int(max_distance) + 1):
				var check_pos = start_position + direction * distance
				var road_name = "Road_" + str(int(check_pos.x)) + "_" + str(int(check_pos.z))
				
				# Check if there's a road at this position in the NavRegion3D
				if nav_region.has_node(road_name):
					return check_pos
	
	# If all else fails, just return a point 5 units away in a random direction
	var random_direction = Vector3(
		randf_range(-1.0, 1.0),
		0.0,
		randf_range(-1.0, 1.0)
	).normalized() * 5.0
	
	return start_position + random_direction
		
# Function to find a connected road piece to determine orientation
func _find_connected_road(road_position: Vector3, gridmap: GridMap) -> Vector3:
	var directions = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	
	# First check for horizontal roads (left/right)
	for direction in [Vector3.RIGHT, Vector3.LEFT]:
		var check_pos = road_position + direction
		var cell_item = gridmap.get_cell_item(check_pos)
		
		# If it's a valid cell and a road
		if cell_item >= 0 and cell_item < builder.structures.size():
			if builder.structures[cell_item].type == Structure.StructureType.ROAD:
				# Prioritize horizontal roads
				return check_pos
	
	# Then check for vertical roads (forward/back)
	for direction in [Vector3.FORWARD, Vector3.BACK]:
		var check_pos = road_position + direction
		var cell_item = gridmap.get_cell_item(check_pos)
		
		# If it's a valid cell and a road
		if cell_item >= 0 and cell_item < builder.structures.size():
			if builder.structures[cell_item].type == Structure.StructureType.ROAD:
				return check_pos
				
	return Vector3.ZERO
			
func _find_nearest_road(position: Vector3, gridmap: GridMap) -> Vector3:
	# Check a 6x6 grid around the building for better coverage
	var nearest_road = Vector3.ZERO
	var min_distance = 100.0
	var best_road_length = 0.0
	
	# First pass: find all roads based on their presence in the NavRegion3D
	var road_positions = []
	
	# Get the navigation region
	var nav_region = builder.nav_region
	if nav_region:
		# Look for road nodes in the navigation region
		for child in nav_region.get_children():
			if child.name.begins_with("Road_"):
				# Extract position from the road name (format: "Road_X_Z")
				var pos_parts = child.name.split("_")
				if pos_parts.size() >= 3:
					var road_x = int(pos_parts[1])
					var road_z = int(pos_parts[2])
					var road_pos = Vector3(road_x, 0, road_z)
					
					# Check if this road is within range
					if abs(road_pos.x - position.x) <= 3 and abs(road_pos.z - position.z) <= 3:
						road_positions.append(road_pos)
	
	# If we didn't find any roads in NavRegion3D, fall back to the old method
	if road_positions.size() == 0:
		for x in range(-3, 4):
			for z in range(-3, 4):
				var check_pos = Vector3(position.x + x, 0, position.z + z)
				var road_name = "Road_" + str(int(check_pos.x)) + "_" + str(int(check_pos.z))
				
				# Check if there's a road at this position in the NavRegion3D
				if nav_region and nav_region.has_node(road_name):
					road_positions.append(check_pos)
	
	# Second pass: evaluate roads based on distance and connected length
	for road_pos in road_positions:
		var distance = position.distance_to(road_pos)
		
		# Always choose the closest road initially
		if nearest_road == Vector3.ZERO:
			nearest_road = road_pos
			min_distance = distance
		# Otherwise just take the closest
		elif distance < min_distance:
			nearest_road = road_pos
			min_distance = distance
	
	return nearest_road
	
func _get_connected_road_length(road_position: Vector3, gridmap: GridMap) -> float:
	# Simple function to find the length of a connected road
	var road_length = 1.0
	var directions = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	
	# Check in all four directions
	for direction in directions:
		var check_pos = road_position
		var connected_roads = 0
		
		# Check up to 10 cells in this direction
		for i in range(1, 11):
			check_pos += direction
			var cell_item = gridmap.get_cell_item(check_pos)
			
			# Check if it's a road
			if cell_item >= 0 and builder.structures[cell_item].type == Structure.StructureType.ROAD:
				connected_roads += 1
			else:
				break
				
		road_length = max(road_length, connected_roads + 1)
	
	return road_length

# This function handles structure unlocking when a mission is completed
func _handle_structure_unlocking(mission):
	if not builder:
		print("[Unlock] No builder found, aborting unlocking.")
		return
	
	var structures = builder.get_structures()
	print("[Unlock] Builder has ", structures.size(), " structures.")
	
	var unlocked_structures = []
	
	# Check for explicitly defined unlocked items in mission
	if mission is Resource and "unlocked_items" in mission and mission.unlocked_items.size() > 0:
		print("[Unlock] Mission unlocked_items: ", mission.unlocked_items)
		var items = mission.unlocked_items
		for item_path in items:
			print("[Unlock] Checking item_path: ", item_path)
			var found = false
			var item_base = item_path.get_file().get_basename()
			for structure in structures:
				if structure.model:
					var model_base = structure.model.resource_path.get_file().get_basename()
					print("[Unlock]   Structure model: ", structure.model.resource_path, " base: ", model_base, " unlocked: ", (structure.unlocked if "unlocked" in structure else "N/A"))
					if item_base == model_base:
						print("[Unlock]   Base name match found!")
						if "unlocked" in structure:
							structure.unlocked = true
							unlocked_structures.append(structure)
							Globals.structure_unlocked(structure)
						found = true
			if not found:
				print("[Unlock]   No match found for item_path: ", item_path)
	else:
		print("[Unlock] No unlocked_items in mission or mission is not a Resource.")
	
	# Update builder's current structure if needed
	var found_unlocked = false
	for i in range(structures.size()):
		var structure = structures[i]
		if "unlocked" in structure and structure.unlocked:
			if not (structures[builder.index].unlocked if "unlocked" in structures[builder.index] else false):
				builder.index = i
				builder.update_structure()
			found_unlocked = true
			break
	
	print("[Unlock] unlocked_structures size: ", unlocked_structures.size())
	# Show the unlocked items panel if we unlocked anything
	if unlocked_structures.size() > 0:
		print("[Unlock] Emitting structures_unlocked signal and showing panel.")
		structures_unlocked.emit()
		builder._on_structures_unlocked()
		_show_unlocked_items_panel(unlocked_structures)
	else:
		print("[Unlock] No new structures unlocked.")

# Shows a panel with the newly unlocked items
func _show_unlocked_items_panel(unlocked_structures):
	print("\n=== Showing Unlocked Items Panel ===")
	print("Number of unlocked structures: ", unlocked_structures.size())
	
	# Check if panel is already showing
	if is_unlocked_panel_showing:
		print("Panel already showing, returning")
		return
		
	# Set panel state to showing - prevents mission starts while panel is visible
	is_unlocked_panel_showing = true
	
	# Check if there's already an unlocked items panel in the scene and remove it
	var existing_panels = []
	
	# Check in HUD
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	if hud:
		for child in hud.get_children():
			if child.name.contains("UnlockedItems") or (child is Control and child.get_script() != null and "unlocked" in child.get_script().resource_path.to_lower()):
				existing_panels.append(child)
	
	# Check in CanvasLayer
	var canvas = get_node_or_null("/root/Main/CanvasLayer")
	if canvas:
		for child in canvas.get_children():
			if child.name.contains("UnlockedItems") or (child is Control and child.get_script() != null and "unlocked" in child.get_script().resource_path.to_lower()):
				existing_panels.append(child)
	
	# Remove any existing panels
	for panel in existing_panels:
		print("Removing existing panel: ", panel.name)
		panel.queue_free()
	
	# Wait a short delay before showing the panel
	await get_tree().create_timer(0.5).timeout
	
	# Load the panel scene
	var unlocked_panel_scene = load("res://scenes/unlocked_items_panel.tscn")
	if unlocked_panel_scene:
		print("Loaded unlocked items panel scene")
		var unlocked_panel = unlocked_panel_scene.instantiate()
		
		# Always add to canvas if available
		if canvas:
			canvas.add_child(unlocked_panel)
		else:
			# Final fallback to root
			print("Adding panel to root")
			get_tree().root.add_child(unlocked_panel)
		
		# Wait for panel to be added
		await get_tree().process_frame
		
		# Make sure the panel is visible and on top
		unlocked_panel.z_index = 100
		unlocked_panel.show()
		
		# Setup and show the panel
		print("Setting up panel with structures")
		unlocked_panel.setup(unlocked_structures)
		unlocked_panel.show_panel()
		
		# Connect the closed signal
		unlocked_panel.closed.connect(func():
			print("Unlocked panel closed")
			# Reset the panel showing state
			is_unlocked_panel_showing = false
			
			# Make sure the game is unpaused
			get_tree().paused = false
			
			# Update the mission UI with the current objective
			if mission_ui and current_mission:
				mission_ui.update_mission_display(current_mission)
			
			# Process any delayed mission starts
			_process_delayed_mission_starts()
		)
	else:
		push_error("Failed to load unlocked items panel scene")

# Public function to show all unlocked structures when requested
func show_unlocked_structures_panel():
	if not builder:
		return
		
	var all_unlocked = []
	for structure in builder.structures:
		if "unlocked" in structure and structure.unlocked:
			all_unlocked.append(structure)
		
	# Pause the game when showing the panel
	get_tree().paused = true
	_show_unlocked_items_panel(all_unlocked)

# Functions for communication with learning companion
func _on_game_started_for_companion():
	if learning_companion_connected and JSBridge.has_interface():
		var js_interface = JSBridge.get_interface()
		if js_interface and js_interface.has_method("onGameStarted"):
			js_interface.onGameStarted()

func _on_mission_started_for_companion(mission):
	if learning_companion_connected and JSBridge.has_interface():
		var js_interface = JSBridge.get_interface()
		if js_interface and js_interface.has_method("sendCompanionDialog"):
			# Only send dialog if it exists and is valid
			if mission.companion_dialog and mission.companion_dialog.has("mission_started"):
				var dialog_data = mission.companion_dialog["mission_started"]
				if dialog_data:
					js_interface.sendCompanionDialog("mission_started", dialog_data)

func _on_mission_completed_for_companion(mission):
	if learning_companion_connected and JSBridge.has_interface():
		var js_interface = JSBridge.get_interface()
		if js_interface and js_interface.has_method("sendCompanionDialog"):
			# Only send dialog if it exists and is valid
			if mission.companion_dialog and mission.companion_dialog.has("mission_completed"):
				var dialog_data = mission.companion_dialog["mission_completed"]
				if dialog_data:
					js_interface.sendCompanionDialog("mission_completed", dialog_data)

func _on_all_missions_completed_for_companion():
	if learning_companion_connected and JSBridge.has_interface():
		var js_interface = JSBridge.get_interface()
		if js_interface and js_interface.has_method("sendAllMissionsCompleted"):
			js_interface.sendAllMissionsCompleted()

# Helper function to send dialog to the companion
func _send_companion_dialog(dialog_key, mission):
	if learning_companion_connected and JSBridge.has_interface():
		var js_interface = JSBridge.get_interface()
		if js_interface and js_interface.has_method("sendCompanionDialog"):
			# Only send dialog if it exists and is valid
			if mission.companion_dialog and mission.companion_dialog.has(dialog_key):
				var dialog_data = mission.companion_dialog[dialog_key]
				if dialog_data:
					js_interface.sendCompanionDialog(dialog_key, dialog_data)
					return true
	return false
	
# Helper function to update the current objective to the next incomplete one
func update_current_objective(mission = null):
	# If no mission was provided, use the current mission
	if mission == null:
		mission = current_mission
	
	if not mission:
		return
	
	# Find the next incomplete objective
	var found_current = false
	for objective in mission.objectives:
		# If we haven't found the current objective yet, keep looking
		if not found_current:
			if objective == current_objective:
				found_current = true
			continue
		
		# Once we've found the current objective, look for the next incomplete one
		if not objective.completed:
			current_objective = objective
			
			# Force UI update
			if mission_ui:
				mission_ui.update_mission_display(mission)
			return
			
	# If we didn't find a next incomplete objective, check if all are complete
	var all_complete = true
	for objective in mission.objectives:
		if not objective.completed:
			all_complete = false
			break
			
	if all_complete:
		complete_mission(mission.id)

# Fallback to force a connection if the normal method doesn't work
func _force_learning_companion_connection():
	if not learning_companion_connected and JSBridge.has_interface():
		learning_companion_connected = true
		
		# Connect signals
		game_started.connect(_on_game_started_for_companion)
		mission_started.connect(_on_mission_started_for_companion)
		mission_completed.connect(_on_mission_completed_for_companion)
		all_missions_completed.connect(_on_all_missions_completed_for_companion)
		
		# Send initial event if we've already started
		if current_mission:
			_on_mission_started_for_companion(current_mission)

func population_updated(new_population: Variant) -> void:
	if current_mission and current_objective and current_objective.type == ObjectiveType.REACH_POPULATION:
		# Update the current count to match the actual population
		current_objective.current_count = new_population
		
		# Check if objective is complete
		if current_objective.current_count >= current_objective.target_count:
			current_objective.completed = true
			objective_completed.emit(current_objective)
			update_current_objective(current_mission)
		
		# Emit progress signal
		objective_progress.emit(current_objective, current_objective.current_count)
		
		# Update the mission UI
		if mission_ui:
			mission_ui.update_mission_display(current_mission)

func check_objective_completion(mission_id, objective_type):
	if not active_missions.has(mission_id):
		return false
		
	var mission = active_missions[mission_id]
	for objective in mission.objectives:
		if objective.type == objective_type:
			return objective.completed
	
	return false
	
# Function to reset an objective's count to a specific value
func reset_objective_count(objective_type, new_count):
	if not current_mission:
		return
		
	var mission_id = current_mission.id
	if not active_missions.has(mission_id):
		return
		
	var mission = active_missions[mission_id]
	for objective in mission.objectives:
		if objective.type == objective_type:
			objective.current_count = new_count
			
			# Update completion status based on new count
			objective.completed = objective.current_count >= objective.target_count
			
			# If newly completed, emit signal
			if objective.completed and objective.current_count >= objective.target_count:
				objective_completed.emit(objective)
				
				# Send dialog event if available
				var dialog_key = "objective_completed_" + str(objective.type)
				_send_companion_dialog(dialog_key, mission)
				
				# Update current objective to next incomplete one
				update_current_objective(mission)
			
			# Update UI
			update_mission_ui()
			
			# Emit progress signal for objective
			objective_progress.emit(objective, objective.current_count)
			
			# Check if the mission is complete
			check_mission_completion(mission_id)
			break

func check_mission_completion(mission_id):
	if not active_missions.has(mission_id):
		return
		
	var mission = active_missions[mission_id]
	var all_complete = true
	
	for objective in mission.objectives:
		if not objective.completed:
			all_complete = false
			break
	
	if all_complete:
		# All objectives complete, complete the mission
		complete_mission(mission_id)
		return true
		
	return false

func update_mission_ui():
	if mission_ui:
		mission_ui.update_missions(active_missions)

# Add new function to load custom configurations
func load_mission_config(config: MissionData) -> void:
	if mission_loader:
		# Convert the mission data to a dictionary format
		var mission_dict = {
			"missions": [{
				"id": config.id,
				"title": config.title,
				"description": config.description,
				"objectives": config.objectives,
				"rewards": config.rewards,
				"next_mission_id": config.next_mission_id,
				"graph_path": config.graph_path,
				"full_screen_path": config.full_screen_path,
				"intro_text": config.intro_text,
				"question_text": config.question_text,
				"correct_answer": config.correct_answer,
				"feedback_text": config.feedback_text,
				"incorrect_feedback": config.incorrect_feedback,
				"company_data": config.company_data,
				"power_math_content": config.power_math_content,
				"num_of_user_inputs": config.num_of_user_inputs,
				"input_labels": config.input_labels,
				"companion_dialog": config.companion_dialog,
				"unlocked_items": config.unlocked_items,
				"starting_structures": config.starting_structures
			}]
		}
		mission_loader.load_from_js(mission_dict)

func _on_init_data_received(data):
	print("Godot received mission data: ", data)
	print("Type: ", typeof(data), " Keys: ", data.keys() if typeof(data) == TYPE_DICTIONARY else "")
	
	if typeof(data) == TYPE_STRING:
		var parsed = JSON.parse_string(data)
		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed
		else:
			print("Failed to parse mission data string!")
	
	if not data:
		push_error("Received empty initialization data")
		return
		
	if not data.has("missions"):
		push_error("No missions found in initialization data")
		return
		
	# Use mission loader helper to populate missions
	mission_loader.load_from_js(data)
	# Start the first loaded mission if available
	if missions.size() > 0:
		print("Starting first mission: ", missions[0].id)
		start_mission(missions[0])
	else:
		push_error("No missions available to start")

func get_next_mission(current_mission_id):
	for i in range(missions.size()):
		if missions[i].id == current_mission_id and i + 1 < missions.size():
			return missions[i + 1]
	return null
