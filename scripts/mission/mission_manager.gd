extends Node
class_name MissionManager

# Add the JavaScript bridge for HTML5 export
# This ensures JavaScript is available and degrades gracefully on other platforms
const JSBridge = preload("res://scripts/javascript_bridge.gd")

signal mission_started(mission: MissionData)
signal mission_completed(mission: MissionData)
signal objective_completed(objective: MissionObjective)
signal objective_progress(objective: MissionObjective, new_count: int)
signal game_started()
signal all_missions_completed()

@export var missions: Array[MissionData] = []
@export var mission_ui: Control
@export var builder: Node3D
@export var character_scene: PackedScene

var current_mission: MissionData
var active_missions: Dictionary = {}  # mission_id: MissionData
 
var character_spawned: bool = false
var learning_companion_connected: bool = false

# Panel state tracking
var is_unlocked_panel_showing = false
var delayed_mission_start_queue = []  # Queue of missions to start after unlocked panel closes

# Mission skip variables
var skip_key_presses: int = 0
var last_skip_press_time: float = 0
var skip_key_timeout: float = 1.0  # Reset counter if time between presses exceeds this value
var skip_key_required: int = 5  # Number of key presses needed to skip
const SKIP_KEY = KEY_TAB  # The key to press for skipping missions

# Reference for the learning panel without type hint
var learning_panel
var fullscreen_learning_panel

func _ready():
	
	if builder:
		# Connect to builder signals
		builder.connect("structure_placed", _on_structure_placed)
	
	# Find and remove existing learning panel to avoid conflicts
	var old_panel = get_node_or_null("LearningPanel")
	if old_panel:
		old_panel.queue_free()
		
	# Load the learning panel scene fresh each time
	var learning_panel_scene = load("res://scenes/learning_panel.tscn")
	if learning_panel_scene:
		learning_panel = learning_panel_scene.instantiate()
		learning_panel.name = "LearningPanelFromScene"
		add_child(learning_panel)
	else:
		print("ERROR: Could not load learning_panel.tscn scene")
	
	# Load the fullscreen learning panel scene
	var fullscreen_panel_scene = load("res://scenes/fullscreen_learning_panel.tscn")
	if fullscreen_panel_scene:
		fullscreen_learning_panel = fullscreen_panel_scene.instantiate()
		fullscreen_learning_panel.name = "FullscreenLearningPanel"
		add_child(fullscreen_learning_panel)
	else:
		print("ERROR: Could not load fullscreen_learning_panel.tscn scene")
		
	# Fall back to existing panels if needed
	if not learning_panel:
		learning_panel = get_node_or_null("/root/Main/LearningPanel")
	
	# Connect signals for both panel types
	if learning_panel:
		learning_panel.completed.connect(_on_learning_completed)
		learning_panel.panel_opened.connect(_on_learning_panel_opened)
		learning_panel.panel_closed.connect(_on_learning_panel_closed)
	else:
		print("WARNING: Regular learning panel not found!")
	
	if fullscreen_learning_panel:
		fullscreen_learning_panel.completed.connect(_on_learning_completed)
		fullscreen_learning_panel.panel_opened.connect(_on_learning_panel_opened)
		fullscreen_learning_panel.panel_closed.connect(_on_learning_panel_closed)
	else:
		print("WARNING: Fullscreen learning panel not found!")
	
	# For web builds, try to proactively initialize audio on load
#	if OS.has_feature("web"):
#		# Try to find sound manager and init audio
#		var sound_manager = get_node_or_null("/root/SoundManager")
#		if sound_manager and not sound_manager.audio_initialized:
#			# Connect to user input to detect interaction
#			get_viewport().gui_focus_changed.connect(_on_gui_focus_for_audio)
#			get_tree().get_root().connect("gui_input", _on_gui_input_for_audio)
	
	# Set up communication with the learning companion
	_setup_learning_companion_communication()
	
	# Create a simple timer to force a learning companion connection in 3 seconds
	# This is a fallback in case the normal connection doesn't work
	var connection_timer = Timer.new()
	connection_timer.wait_time = 3.0
	connection_timer.one_shot = true
	connection_timer.autostart = true
	connection_timer.name = "ConnectionTimer"
	add_child(connection_timer)
	connection_timer.timeout.connect(_force_learning_companion_connection)
	print("Created timer to force learning companion connection in 3 seconds")
	
			
	
	# Emit game_started signal before starting the first mission
	game_started.emit()
	
	# Start the first mission if available
	if missions.size() > 0:
		start_mission(missions[0])

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
		print("User interaction detected in MissionManager, attempting audio init")
		sound_manager._initialize_web_audio()
		
		# Also use JavaScript bridge to help with audio
		if JSBridge.has_interface():
			JSBridge.get_interface().ensure_audio_initialized()
		
		# Try to kick-start music if game manager exists
		var game_manager = get_node("/root/GameManager")
		if game_manager and game_manager.has_method("_start_background_music"):
			game_manager._start_background_music()
		
# Function to set up communication with the learning companion
func _setup_learning_companion_communication():
	# First, check if JavaScript is available
	if JSBridge.has_interface():
		print("Setting up learning companion communication via postMessage")
		
		# Try to initialize audio first since we now have user interaction
		JSBridge.get_interface().ensure_audio_initialized()
		
		# Connect directly using the simpler postMessage approach
		JSBridge.get_interface().connectLearningCompanionViaPostMessage(
			# Success callback
			func():
				learning_companion_connected = true
				print("Successfully connected to learning companion")

				# Connect signals to JavaScript callbacks
				game_started.connect(_on_game_started_for_companion)
				mission_started.connect(_on_mission_started_for_companion)
				mission_completed.connect(_on_mission_completed_for_companion)
				all_missions_completed.connect(_on_all_missions_completed_for_companion)

				print("Learning companion event handlers connected")

				# Try to initialize audio again to ensure it works
				JSBridge.get_interface().ensure_audio_initialized(),
			func():
				learning_companion_connected = false
				print("Failed to connect to learning companion via postMessage")

		)
	else:
		print("JavaScript interface for learning companion not available")

func start_mission(mission: MissionData):
	# Check that the mission data is valid
	if mission == null:
		push_error("Null mission data provided to start_mission")
		return
	
	# If the unlocked items panel is currently showing, queue this mission to start later
	if is_unlocked_panel_showing:
		print("Unlocked items panel is showing, queueing mission start: " + mission.id)
		delayed_mission_start_queue.append(mission)
		return
		
	current_mission = mission
	active_missions[mission.id] = mission
	
	# Send mission started event to the learning companion
	# This will also send the companion dialog data
	_on_mission_started_for_companion(mission)
	
	# Fix for mission 3 to ensure accurate count
	if mission.id == "3":
		# Reset the residential building count to 0 to avoid any double counting
		for objective in mission.objectives:
			if objective.type == MissionObjective.ObjectiveType.BUILD_RESIDENTIAL:
				objective.current_count = 0
				objective.completed = false
				
		# Load and run the fix script to count actual buildings
		var FixMissionScript = load("res://scripts/fix_mission.gd")
		if FixMissionScript:
			var fix_node = Node.new()
			fix_node.set_script(FixMissionScript)
			fix_node.name = "FixMissionHelper"
			add_child(fix_node)
	
	# Add decorative structures and curved roads
	# Use more robust checking - fallback to ID for backward compatibility
	var is_construction_or_expansion = (mission.id == "2" or mission.id == "3")
	if is_construction_or_expansion and builder:
		# Check if we need to add the road-corner and decoration structures
		var has_road_corner = false
		var has_grass_trees_tall = false
		var has_grass = false
		
		# Look through existing structures to see if we already have them
		for structure in builder.structures:
			if structure.model.resource_path.contains("road-corner"):
				has_road_corner = true
			elif structure.model.resource_path.contains("grass-trees-tall"):
				has_grass_trees_tall = true
			elif structure.model.resource_path.contains("grass") and not structure.model.resource_path.contains("trees"):
				has_grass = true
		
		# Add the road-corner if missing
		if not has_road_corner:
			var road_corner = load("res://structures/road-corner.tres")
			if road_corner:
				builder.structures.append(road_corner)
		
		# Add the grass-trees-tall if missing
		if not has_grass_trees_tall:
			var grass_trees_tall = load("res://structures/grass-trees-tall.tres")
			if grass_trees_tall:
				builder.structures.append(grass_trees_tall)
		
		# Add the grass if missing
		if not has_grass:
			var grass = load("res://structures/grass.tres")
			if grass:
				builder.structures.append(grass)
	
	# Special handling for power plant mission: add power plant
	# Use more robust checking for power missions - check power_math_content as well
	elif (mission.id == "5" or mission.power_math_content != "") and builder:
		# Check if we need to add the power plant
		var has_power_plant = false
		
		# Look through existing structures to see if we already have it
		for structure in builder.structures:
			if structure.model.resource_path.contains("power_plant"):
				has_power_plant = true
				break
		
		# Add the power plant if missing
		if not has_power_plant:
			var power_plant = load("res://structures/power-plant.tres")
			if power_plant:
				builder.structures.append(power_plant)
		
		# Update the mesh library to include the new structures
		if builder.gridmap and builder.gridmap.mesh_library:
			var mesh_library = builder.gridmap.mesh_library
			
			# Update mesh library for any new structures
			for i in range(builder.structures.size()):
				var structure = builder.structures[i]
				if i >= mesh_library.get_item_list().size():
					var id = mesh_library.get_last_unused_item_id()
					mesh_library.create_item(id)
					mesh_library.set_item_mesh(id, builder.get_mesh(structure.model))
					
					# Apply appropriate scaling for all road types, buildings, and terrain
					var transform = Transform3D()
					if structure.model.resource_path.contains("power_plant"):
						# Scale power plant model to be much smaller (0.5x)
						transform = transform.scaled(Vector3(0.5, 0.5, 0.5))
					elif (structure.type == Structure.StructureType.RESIDENTIAL_BUILDING
					   or structure.type == Structure.StructureType.ROAD
					   or structure.type == Structure.StructureType.TERRAIN
					   or structure.model.resource_path.contains("grass")):
						# Scale buildings, roads, and decorative terrain to be consistent (3x)
						transform = transform.scaled(Vector3(3.0, 3.0, 3.0))
					
					mesh_library.set_item_mesh_transform(id, transform)
			
			# Make sure the builder's structure selector is updated
			builder.update_structure()
	
	# Check if mission has a learning objective
	var has_learning_objective = false
	# Make sure mission has valid objectives data
	if mission != null and mission.objectives != null:
		for objective in mission.objectives:
			if objective != null and objective.type == MissionObjective.ObjectiveType.LEARNING:
				has_learning_objective = true
				break
	
	# Show learning panel if mission has a learning objective
	if has_learning_objective:
		# Determine which panel to use based on whether full_screen_path is provided
		if not mission.full_screen_path.is_empty():
			# Use fullscreen panel for fullscreen missions
			if fullscreen_learning_panel:
				fullscreen_learning_panel.show_fullscreen_panel(mission)
			else:
				print("ERROR: Fullscreen learning panel not available but mission requires it")
		else:
			# Use regular panel for traditional missions
			if learning_panel:
				learning_panel.show_learning_panel(mission)
			else:
				print("ERROR: Regular learning panel not available")
	
	# Emit signal and update UI
	mission_started.emit(mission)
	update_mission_ui()

func complete_mission(mission_id: String):
	if not active_missions.has(mission_id):
		print("ERROR: Mission " + mission_id + " not found in active_missions!")
		return
	
	var mission = active_missions[mission_id]
	print("Completing mission: " + mission.id + " - " + mission.title)
	
	# Grant rewards
	if mission.rewards.has("cash") and builder:
		builder.map.cash += mission.rewards.cash
		builder.update_cash()
		print("Granted " + str(mission.rewards.cash) + " cash reward")
	
	# Handle structure unlocking when mission is completed
	print("Handling structure unlocking for mission: " + mission.id)
	_handle_structure_unlocking(mission)
	
	# Remove from active missions
	active_missions.erase(mission_id)
	
	# Figure out if there's a next mission
	var next_mission: MissionData
	if mission.next_mission_id:
		# Find mission with that ID
		for m in missions:
			if m.id == mission.next_mission_id:
				next_mission = m
				break
				
	# Emit mission completed signal
	mission_completed.emit(mission)
	
	# Start the next mission if one is available
	if next_mission:
		# Start the next mission after a short delay
		await get_tree().create_timer(2.0).timeout
		start_mission(next_mission)
	else:
		all_missions_completed.emit()
		print("No more missions available - all complete!")
		
		# Send the "end" event to the companion
		await get_tree().create_timer(2.0).timeout
	
func update_objective_progress(mission_id, objective_type, count_change = 1):
	if not active_missions.has(mission_id):
		return
		
	var mission = active_missions[mission_id]
	for objective in mission.objectives:
		if objective.type == objective_type:
			objective.current_count += count_change
			
			# Only update to completed if we've reached the target
			if objective.current_count >= objective.target_count and not objective.completed:
				objective.completed = true
				objective_completed.emit(objective)
				
				# Send dialog event if available
				var dialog_key = "objective_completed_" + str(objective.type)
				_send_companion_dialog(dialog_key, mission)
			
			# Update UI
			update_mission_ui()
			
			# Emit progress signal for objective
			objective_progress.emit(objective, objective.current_count)
			
			# Check if the mission is complete
			check_mission_completion(mission_id)
			break
			
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
		print("ERROR: No current mission to reset objective count for")
		return
		
	var mission_id = current_mission.id
	if not active_missions.has(mission_id):
		print("ERROR: Current mission ID " + mission_id + " not found in active_missions!")
		return
		
	var mission = active_missions[mission_id]
	for objective in mission.objectives:
		if objective.type == objective_type:
			print("Resetting objective count for type " + str(objective_type) + " from " + str(objective.current_count) + " to " + str(new_count))
			objective.current_count = new_count
			
			# Update completion status based on new count
			objective.completed = objective.current_count >= objective.target_count
			
			# If newly completed, emit signal
			if objective.completed and objective.current_count >= objective.target_count:
				objective_completed.emit(objective)
				
				# Send dialog event if available
				var dialog_key = "objective_completed_" + str(objective.type)
				_send_companion_dialog(dialog_key, mission)
			
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

func _on_structure_placed(structure_index, position):
	# Get the structure that was placed
	if structure_index < 0 or structure_index >= builder.structures.size():
		return
		
	var structure = builder.structures[structure_index]
	print("Structure placed: " + structure.model.resource_path)
	
	# Update objectives based on structure type
	if current_mission:
		if structure.type == Structure.StructureType.ROAD:
			update_objective_progress(current_mission.id, MissionObjective.ObjectiveType.BUILD_ROAD)
		elif structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
			# Note: for mission 3, the objective update happens after construction is complete
			# See builder.gd -> _on_construction_completed
			
			# Special check for mission 1 since we might need to manually spawn a character
			if current_mission.id == "1" and not character_spawned:
				# Only spawn a new character if:
				# 1. This is mission 1
				# 2. We haven't spawned a character yet
				# 3. All objectives except character spawning are complete
				
				# Check if all non-character objectives are complete
				var spawn_character = true
				for objective in current_mission.objectives:
						spawn_character = false
						break
				
				if spawn_character:
					# This will be done after construction completes in mission_manager._on_construction_completed
					print("Character will be spawned after construction completes")
				else:
					# Update the objective progress for building a residential structure
					update_objective_progress(current_mission.id, MissionObjective.ObjectiveType.BUILD_RESIDENTIAL)
			else:
				# Normal case - not mission 1 or character already spawned
				update_objective_progress(current_mission.id, MissionObjective.ObjectiveType.BUILD_RESIDENTIAL)
		elif structure.type == Structure.StructureType.POWER_PLANT:
			# For mission 5, we update the economy/power objective when a power plant is built
			if current_mission.id == "6":
				update_objective_progress(current_mission.id, MissionObjective.ObjectiveType.ECONOMY)
			
	# Check for power plant unlocking in normal gameplay
	if structure.type == Structure.StructureType.POWER_PLANT:
		# This should increase the city's power production
		var power_produced = structure.kW_production
		if power_produced > 0:
			# Get the HUD if available
			var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
			if hud:
				# Update the power display
				hud.total_kW_production += power_produced
				hud.update_hud()
				
#	# Check for residential building placement to update population
#	if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
#		# This should increase the city's population
#		var population_added = structure.population_count
#		if population_added > 0:
#			# Get the HUD if available
#			var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
#			if hud:
#				# Update the population display
#				hud.total_population += population_added
#				hud.update_hud()
#				
#				# Emit signal for population update
#				hud.population_updated.emit(hud.total_population)

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
		print("Learning completed for mission: " + mission.id)
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
		print("Skipping mission: " + current_mission.id)
		
		# Force all objectives to be complete
		for objective in current_mission.objectives:
			objective.current_count = objective.target_count
			objective.completed = true
		
		# Complete the mission
		complete_mission(current_mission.id)
	else:
		print("No current mission to skip")

# Called when the unlocked panel is shown - used for additional state tracking
func _on_unlocked_panel_shown():
	# Update panel state
	is_unlocked_panel_showing = true
	
	# This ensures that learning panels won't appear while this panel is visible
	if learning_panel and learning_panel.visible:
		learning_panel.hide_learning_panel()
	
	if fullscreen_learning_panel and fullscreen_learning_panel.visible:
		fullscreen_learning_panel.hide_fullscreen_panel()
		
	print("Unlocked panel shown, game paused")

# Helper function to process any delayed mission starts after panel closes
func _process_delayed_mission_starts():
	if delayed_mission_start_queue.size() > 0:
		print("Processing " + str(delayed_mission_start_queue.size()) + " delayed mission starts")
		
		# Get the first mission in the queue
		var next_mission = delayed_mission_start_queue.pop_front()
		
		# Clear the rest of the queue - we only start the next mission
		# This prevents multiple mission starts if there were more queued
		delayed_mission_start_queue.clear()
		
		# Start the mission
		if next_mission:
			print("Starting delayed mission: " + next_mission.id)
			# Use a short delay to ensure the UI is fully updated
			await get_tree().create_timer(0.5).timeout
			start_mission(next_mission)

# Function to spawn a character at a residential building
func _spawn_character_on_road(building_position: Vector3):
	if not character_scene:
		print("ERROR: No character scene provided for spawning")
		return
		
	if not builder:
		print("ERROR: Builder reference missing, can't spawn character")
		return
		
	# Find the nearest road to the building
	var nearby_road = _find_nearest_road(building_position, builder.gridmap)
	if nearby_road == Vector3.ZERO:
		print("ERROR: Could not find a road near the building to spawn character")
		return
		
	print("Spawning character on road at: " + str(nearby_road))
	
	# Check if the road is associated with a navigation mesh
	var has_navigation = false
	
	# Get the navigation region
	var nav_region = builder.nav_region
	if nav_region:
		has_navigation = true
	
	if not has_navigation:
		print("WARNING: No navigation mesh found near spawn point")
		
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
	
	# Update the objective progress for meeting a character
	if current_mission and current_mission.id == "1":
		update_objective_progress(current_mission.id, MissionObjective.ObjectiveType.MEET_CHARACTER)
	
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
		print("ERROR: Builder is null, can't unlock structures")
		return
	
	print("Builder has " + str(builder.structures.size()) + " structures")
	
	var unlocked_structures = []
	
	# Check mission properties
	print("Mission properties check:")
	print("- mission is Resource: " + str(mission is Resource))
	if mission is Resource:
		print("- 'unlocked_items' in mission: " + str("unlocked_items" in mission))
		if "unlocked_items" in mission:
			print("- unlocked_items size: " + str(mission.unlocked_items.size()))
			print("- unlocked_items content: " + str(mission.unlocked_items))
	
	# Check for explicitly defined unlocked items in mission
	if mission is Resource and "unlocked_items" in mission and mission.unlocked_items.size() > 0:
		print("Found unlocked_items in mission: " + mission.id)
		print("Unlocked items: " + str(mission.unlocked_items))
		
		var items = mission.unlocked_items
		for item_path in items:
			print("Looking for structure with path: " + item_path)
			var found = false
			
			# DEBUG: Print all builder structures for comparison
			print("Available builder structures:")
			for i in range(builder.structures.size()):
				var s = builder.structures[i]
				if s.model:
					print(str(i) + ": " + s.model.resource_path + " (type: " + str(s.type) + ")")
				else:
					print(str(i) + ": <no model>")
			
			# Find the structure in builder's structures that matches this path
			for structure in builder.structures:
				if structure.model:
					# Try exact match
					if structure.model.resource_path == item_path:
						found = true
						print("EXACT MATCH: " + structure.model.resource_path)
						
						# Make sure structure has the unlocked property before setting it
						if "unlocked" in structure:
							structure.unlocked = true
							unlocked_structures.append(structure)
							print("SUCCESS: Unlocked structure: " + structure.model.resource_path)
						else:
							print("WARNING: Structure doesn't have an 'unlocked' property")
					
					# Try matching just the filename part
					elif structure.model.resource_path.get_file() == item_path.get_file():
						found = true
						print("FILENAME MATCH: " + structure.model.resource_path + " = " + item_path.get_file())
						
						# Make sure structure has the unlocked property before setting it
						if "unlocked" in structure:
							structure.unlocked = true
							unlocked_structures.append(structure)
							print("SUCCESS: Unlocked structure: " + structure.model.resource_path)
						else:
							print("WARNING: Structure doesn't have an 'unlocked' property") 
							
					# Try contains match for more flexible path matching (handles directory differences)
					elif item_path.get_file() in structure.model.resource_path:
						found = true
						print("CONTAINS MATCH: " + structure.model.resource_path + " contains " + item_path.get_file())
						
						# Make sure structure has the unlocked property before setting it
						if "unlocked" in structure:
							structure.unlocked = true
							unlocked_structures.append(structure)
							print("SUCCESS: Unlocked structure: " + structure.model.resource_path)
						else:
							print("WARNING: Structure doesn't have an 'unlocked' property")
			
			if not found:
				print("ERROR: Couldn't find any structure with path: " + item_path)
	
	# If we already have explicit unlocked items defined, skip the hardcoded rules
	var has_explicit_unlocks = mission is Resource and "unlocked_items" in mission and mission.unlocked_items.size() > 0
	
	# Check for power plant unlocking in power-related missions (only if no explicit unlocks)
	if (not has_explicit_unlocks) and (mission.id == "4" or mission.id == "5" or mission.power_math_content != ""):
		print("Using hardcoded power plant unlocks for mission: " + mission.id)
		for structure in builder.structures:
			if structure.model and structure.model.resource_path.contains("power_plant"):
				# Make sure structure has the unlocked property before setting it
				if "unlocked" in structure:
					structure.unlocked = true
					# Only add to unlocked_structures if not already there
					if not unlocked_structures.has(structure):
						unlocked_structures.append(structure)
				else:
					print("WARNING: Power plant structure doesn't have an 'unlocked' property")
	
	# Check for curved roads and decorations in city expansion missions (only if no explicit unlocks)
	if (not has_explicit_unlocks) and (mission.id == "2" or mission.id == "3"):
		print("Using hardcoded curved roads and decorations for mission: " + mission.id)
		for structure in builder.structures:
			if structure.model and (structure.model.resource_path.contains("road-corner") or structure.model.resource_path.contains("grass-trees-tall")):
				# Make sure structure has the unlocked property before setting it
				if "unlocked" in structure:
					structure.unlocked = true
					# Only add to unlocked_structures if not already there
					if not unlocked_structures.has(structure):
						unlocked_structures.append(structure)
				else:
					print("WARNING: Road/decoration structure doesn't have an 'unlocked' property")
	
	# Make sure the builder starts with a valid unlocked structure selected
	var found_unlocked = false
	for i in range(builder.structures.size()):
		var structure = builder.structures[i]
		if "unlocked" in structure and structure.unlocked:
			builder.index = i
			builder.update_structure()
			found_unlocked = true
			break
			
	# If no structures are unlocked, unlock ONLY the road for the first mission
	if not found_unlocked and builder.structures.size() > 0:
		# Find and unlock only the straight road structure
		var road_index = -1
		for i in range(builder.structures.size()):
			var structure = builder.structures[i]
			if structure.model and structure.model.resource_path.contains("road-straight"):
				if "unlocked" in structure:
					structure.unlocked = true
					road_index = i
					print("Unlocked initial road structure: " + structure.model.resource_path)
					break
					
		# Set builder to use the road as the initial structure
		if road_index >= 0:
			builder.index = road_index
			builder.update_structure()
		else:
			# Fallback to first structure if road not found
			var structure = builder.structures[0]
			if "unlocked" in structure:
				structure.unlocked = true
				builder.index = 0
				builder.update_structure()
			else:
				print("WARNING: First structure doesn't have an 'unlocked' property")
	
	# Show the unlocked items panel if we unlocked anything
	print("Unlocked " + str(unlocked_structures.size()) + " structures in total")
	if unlocked_structures.size() > 0:
		print("Showing unlocked items panel...")
		# Make sure all structures in the unlock list are properly marked as unlocked
		for structure in unlocked_structures:
			if "unlocked" in structure:
				structure.unlocked = true
				print("Confirmed structure is unlocked: " + structure.model.resource_path)
		
		# If we have no structures explicitly unlocked from mission data,
		# show all currently unlocked structures
		if unlocked_structures.size() == 0 and builder.structures.size() > 0:
			var all_unlocked = []
			for structure in builder.structures:
				if "unlocked" in structure and structure.unlocked:
					all_unlocked.append(structure)
			
			if all_unlocked.size() > 0:
				print("No new structures, showing all " + str(all_unlocked.size()) + " unlocked structures")
				unlocked_structures = all_unlocked
		
		_show_unlocked_items_panel(unlocked_structures)
	else:
		print("No structures unlocked, not showing panel")

# Shows a panel with the newly unlocked items
func _show_unlocked_items_panel(unlocked_structures):
	print("Showing unlocked items panel with " + str(unlocked_structures.size()) + " structures")
	
	# Set panel state to showing - prevents mission starts while panel is visible
	is_unlocked_panel_showing = true
	
	# Check if there's already an unlocked items panel in the scene and remove it
	var existing_panels = []
	
	# Check in HUD
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	if hud:
		for child in hud.get_children():
			if child.name.contains("UnlockedItems") or (child is Control and child.get_script() != null and "unlocked" in child.get_script().resource_path.to_lower()):
				print("Found existing panel in HUD: " + child.name)
				existing_panels.append(child)
	
	# Check in CanvasLayer
	var canvas = get_node_or_null("/root/Main/CanvasLayer")
	if canvas:
		for child in canvas.get_children():
			if child.name.contains("UnlockedItems") or (child is Control and child.get_script() != null and "unlocked" in child.get_script().resource_path.to_lower()):
				print("Found existing panel in CanvasLayer: " + child.name)
				existing_panels.append(child)
	
	# Remove any existing panels
	for panel in existing_panels:
		print("Removing existing panel: " + panel.name)
		panel.queue_free()
	
	# Wait a short delay before showing the panel
	await get_tree().create_timer(0.5).timeout
	
	# Load the panel scene
	var unlocked_panel_scene = load("res://scenes/unlocked_items_panel.tscn")
	if unlocked_panel_scene:
		print("Successfully loaded unlocked_items_panel.tscn")
		var unlocked_panel = unlocked_panel_scene.instantiate()
		
		# Always add to HUD if available
		if hud:
			print("Adding panel to HUD")
			hud.add_child(unlocked_panel)
		else:
			# Fallback to CanvasLayer if HUD not available
			if canvas:
				print("Adding panel to CanvasLayer")
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
		unlocked_panel.setup(unlocked_structures)
		unlocked_panel.show_panel()
		
		# Connect the closed signal
		unlocked_panel.closed.connect(func():
			print("Unlocked panel was closed")
			# Reset the panel showing state
			is_unlocked_panel_showing = false
			
			# Make sure the game is unpaused
			get_tree().paused = false
			
			# Process any delayed mission starts
			_process_delayed_mission_starts()
		)
	else:
		push_error("Could not load unlocked_items_panel scene")
		# Even if we couldn't load the panel, make sure to reset the state
		is_unlocked_panel_showing = false
	
# Public function to show all unlocked structures when requested
func show_unlocked_structures_panel():
	if not builder:
		print("Cannot show unlocked structures - builder not found")
		return
		
	var all_unlocked = []
	for structure in builder.structures:
		if "unlocked" in structure and structure.unlocked:
			all_unlocked.append(structure)
		
	print("Showing panel with all " + str(all_unlocked.size()) + " unlocked structures")
	# Pause the game when showing the panel
	get_tree().paused = true
	_show_unlocked_items_panel(all_unlocked)

# Functions for communication with learning companion
func _on_game_started_for_companion():
	if learning_companion_connected and JSBridge.has_interface():
		print("Sending gameStarted event to learning companion")
		JSBridge.get_interface().sendGameStarted()

func _on_mission_started_for_companion(mission):
	if learning_companion_connected and JSBridge.has_interface():
		print("Sending missionStarted event to learning companion for mission: " + mission.id)
		
		# Only send dialog if it exists
		if mission.companion_dialog.has("mission_started"):
			var dialog_data = mission.companion_dialog["mission_started"]
			JSBridge.get_interface().sendCompanionDialog("mission_started", dialog_data)

func _on_mission_completed_for_companion(mission):
	if learning_companion_connected and JSBridge.has_interface():
		print("Sending missionCompleted event to learning companion for mission: " + mission.id)
		
		# Only send dialog if it exists
		if mission.companion_dialog.has("mission_completed"):
			var dialog_data = mission.companion_dialog["mission_completed"]
			JSBridge.get_interface().sendCompanionDialog("mission_completed", dialog_data)

func _on_all_missions_completed_for_companion():
	if learning_companion_connected and JSBridge.has_interface():
		print("Sending allMissionsCompleted event to learning companion")
		JSBridge.get_interface().sendAllMissionsCompleted()

# Helper function to send dialog to the companion
func _send_companion_dialog(dialog_key, mission):
	if learning_companion_connected and JSBridge.has_interface() and mission.companion_dialog.has(dialog_key):
		var dialog_data = mission.companion_dialog[dialog_key]
		JSBridge.get_interface().sendCompanionDialog(dialog_key, dialog_data)
		return true
	return false

# Fallback to force a connection if the normal method doesn't work
func _force_learning_companion_connection():
	if not learning_companion_connected and JSBridge.has_interface():
		print("Forcing learning companion connection")
		learning_companion_connected = true
		
		# Connect signals
		game_started.connect(_on_game_started_for_companion)
		mission_started.connect(_on_mission_started_for_companion)
		mission_completed.connect(_on_mission_completed_for_companion)
		all_missions_completed.connect(_on_all_missions_completed_for_companion)
		
		# Send initial event if we've already started
		if current_mission:
			_on_mission_started_for_companion(current_mission)
