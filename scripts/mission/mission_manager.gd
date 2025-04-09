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
	if OS.has_feature("web"):
		# Try to find sound manager and init audio
		var sound_manager = get_node_or_null("/root/SoundManager")
		if sound_manager and not sound_manager.audio_initialized:
			# Connect to user input to detect interaction
			get_viewport().gui_focus_changed.connect(_on_gui_focus_for_audio)
			get_tree().get_root().connect("gui_input", _on_gui_input_for_audio)
	
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
	
	# Load third mission if not already in the list
	var third_mission = load("res://mission/third_mission.tres")
	if third_mission:
		var found = false
		for mission in missions:
			if mission.id == "3":
				found = true
				break
		
		if not found:
			missions.append(third_mission)
		
		# Set next_mission_id for second mission to point to third mission
		for mission in missions:
			if mission.id == "2":
				mission.next_mission_id = "3"
	
	# Load fourth mission if not already in the list
	var fourth_mission = load("res://mission/fourth_mission.tres")
	if fourth_mission:
		var found = false
		for mission in missions:
			if mission.id == "4":
				found = true
				break
		
		if not found:
			missions.append(fourth_mission)
		
		# Set next_mission_id for third mission to point to fourth mission
		for mission in missions:
			if mission.id == "3":
				mission.next_mission_id = "4"
	
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
	elif (mission.id == "4" or mission.power_math_content != "") and builder:
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
		return
	
	var mission = active_missions[mission_id]
	
	# Grant rewards
	if mission.rewards.has("cash") and builder:
		builder.map.cash += mission.rewards.cash
		builder.update_cash()
	
	# Remove from active missions
	active_missions.erase(mission_id)
	
	# Send mission completed event to the learning companion
	# This will also send the companion dialog data
	_on_mission_completed_for_companion(mission)
	
	# Start next mission if specified
	if mission.next_mission_id != "":
		for next_mission in missions:
			if next_mission.id == mission.next_mission_id:
				start_mission(next_mission)
				break
	else:
		# This was the last mission - show completion modal and emit all_missions_completed
		# This will also trigger the companion dialog
		_show_completion_modal()
	
	# Emit signal for mission completion
	mission_completed.emit(mission)
	update_mission_ui()

# Shows a modal when all missions are complete
func _show_completion_modal():
	# Emit signal that all missions are completed
	all_missions_completed.emit()
	
	# Create the modal overlay
	var modal = ColorRect.new()
	modal.name = "CompletionModal"
	modal.color = Color(0.1, 0.1, 0.2, 0.9)  # Dark transparent background
	modal.anchor_right = 1.0
	modal.anchor_bottom = 1.0
	
	# Create a panel container for the modal content
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(800, 500)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	panel_style.border_width_left = 5
	panel_style.border_width_top = 5
	panel_style.border_width_right = 5
	panel_style.border_width_bottom = 5
	panel_style.border_color = Color(0.376, 0.760, 0.658, 1.0)  # Teal border
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.shadow_color = Color(0, 0, 0, 0.7)
	panel_style.shadow_size = 10
	
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Create a margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	
	# Create a vertical container for the content
	var v_box = VBoxContainer.new()
	v_box.custom_minimum_size = Vector2(700, 0)
	v_box.add_theme_constant_override("separation", 30)
	
	# Add a title label
	var title_label = Label.new()
	title_label.text = "CONGRATULATIONS!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.376, 0.760, 0.658, 1.0))  # Teal text
	
	# Add a description label
	var desc_label = Label.new()
	desc_label.text = "You've completed all the missions in STEM City!\n\nYou can continue building and expanding your city or try different activities."
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 32)
	desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Create a continue button
	var continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "CONTINUE BUILDING"
	continue_button.custom_minimum_size = Vector2(400, 80)
	
	# Style the continue button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.376, 0.760, 0.658, 0.25)  # Teal with transparency
	button_style.border_width_left = 3
	button_style.border_width_top = 3
	button_style.border_width_right = 3
	button_style.border_width_bottom = 3
	button_style.border_color = Color(0.376, 0.760, 0.658, 1.0)  # Teal border
	button_style.corner_radius_top_left = 15
	button_style.corner_radius_top_right = 15
	button_style.corner_radius_bottom_right = 15
	button_style.corner_radius_bottom_left = 15
	
	continue_button.add_theme_stylebox_override("normal", button_style)
	continue_button.add_theme_stylebox_override("hover", button_style)
	continue_button.add_theme_stylebox_override("pressed", button_style)
	continue_button.add_theme_font_size_override("font_size", 32)
	continue_button.add_theme_color_override("font_color", Color(0.376, 0.760, 0.658, 1.0))  # Teal text
	continue_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1.0))  # White text on hover
	
	# Center the continue button
	var button_container = CenterContainer.new()
	button_container.add_child(continue_button)
	
	# Add elements to the vertical container
	v_box.add_child(title_label)
	v_box.add_child(desc_label)
	v_box.add_child(button_container)
	
	# Assemble the hierarchy
	margin.add_child(v_box)
	panel.add_child(margin)
	
	# Center the panel in the modal
	var center_container = CenterContainer.new()
	center_container.anchor_right = 1.0
	center_container.anchor_bottom = 1.0
	center_container.add_child(panel)
	
	modal.add_child(center_container)
	
	# Add the modal to the scene
	var canvas_layer = get_node("/root/Main/CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(modal)
	else:
		add_child(modal)
	
	# Connect button signal - use a specific method for clarity and debugging
	continue_button.pressed.connect(_on_completion_continue_button_pressed.bind(modal))

# Handler for the mission completion continue button
func _on_completion_continue_button_pressed(modal_to_close):
	if is_instance_valid(modal_to_close) and modal_to_close is Node and modal_to_close.is_inside_tree():
		modal_to_close.queue_free()
	else:
		push_error("Invalid modal reference or modal already removed")

# Event handler functions for learning companion communication
func _on_game_started_for_companion():
	# If learning companion is not connected, just log but still proceed
	# This allows the game to start in the editor
	if not learning_companion_connected:
		print("Learning companion not connected, skipping companion events for game start")
		return
		
	print("Sending game started event to learning companion")
	if JSBridge.has_interface():
		JSBridge.get_interface().onGameStarted()
		

func _on_mission_started_for_companion(mission: MissionData):
	# If learning companion is not connected, just log but still proceed with mission
	# This allows missions to load in the editor
	if not learning_companion_connected:
		print("Learning companion not connected, skipping companion events for mission: " + mission.id)
		return
		
	print("Sending mission started event to learning companion for mission: " + mission.id)
	if JSBridge.has_interface():
		# Convert mission data to a format that can be passed to JavaScript
		var mission_data = {
			"id": mission.id,
			"title": mission.title,
			"description": mission.description,
			"intro_text": mission.intro_text,
		}
		JSBridge.get_interface().onMissionStarted(mission_data)
		
		# Send mission started dialog if available in mission data
		if mission.companion_dialog.has("mission_started"):
			var dialog_data = mission.companion_dialog["mission_started"]
			JSBridge.get_interface().sendCompanionDialog("mission_started", dialog_data)
		else:
			# Fallback dialog if not defined in mission data
			var fallback_dialog = {
				"text": "Starting Mission " + mission.id + ": " + mission.title + ". Let's do this!",
				"animation": "excited",
				"duration": 3000
			}
			JSBridge.get_interface().sendCompanionDialog("mission_started", fallback_dialog)

func _on_mission_completed_for_companion(mission: MissionData):
	# If learning companion is not connected, just log but still proceed with mission
	# This allows missions to complete in the editor
	if not learning_companion_connected:
		print("Learning companion not connected, skipping companion events for mission completion: " + mission.id)
		return
		
	print("Sending mission completed event to learning companion for mission: " + mission.id)
	if JSBridge.has_interface():
		# Convert mission data to a format that can be passed to JavaScript
		var mission_data = {
			"id": mission.id,
			"title": mission.title,
			"description": mission.description,
		}
		JSBridge.get_interface().onMissionCompleted(mission_data)
		
		# Send mission completed dialog if available in mission data
		if mission.companion_dialog.has("mission_completed"):
			var dialog_data = mission.companion_dialog["mission_completed"]
			JSBridge.get_interface().sendCompanionDialog("mission_completed", dialog_data)
		else:
			# Fallback dialog if not defined in mission data
			var fallback_dialog = {
				"text": "Great job completing Mission " + mission.id + "! You're making excellent progress!",
				"animation": "happy",
				"duration": 3000
			}
			JSBridge.get_interface().sendCompanionDialog("mission_completed", fallback_dialog)

func _on_all_missions_completed_for_companion():
	# If learning companion is not connected, just log but still proceed
	# This allows all missions to complete in the editor
	if not learning_companion_connected:
		print("Learning companion not connected, skipping companion events for all missions completed")
		return
		
	print("Sending all missions completed event to learning companion")
	if JSBridge.has_interface():
		JSBridge.get_interface().onAllMissionsCompleted()
		
		# Send all_missions_completed dialog to learning companion if current mission has it
		if current_mission != null and current_mission.companion_dialog.has("all_missions_completed"):
			var dialog_data = current_mission.companion_dialog["all_missions_completed"]
			JSBridge.get_interface().sendCompanionDialog("all_missions_completed", dialog_data)
		else:
			# Use fallback dialog if not defined in mission
			var dialog_data = {
				"text": "Congratulations! You've completed all the missions in STEM City! You're a master city planner!",
				"animation": "excited",
				"duration": 0  # No reset, stay excited
			}
			JSBridge.get_interface().sendCompanionDialog("all_missions_completed", dialog_data)

# Function to force learning companion connection after a delay
func _force_learning_companion_connection():
	print("Forcing learning companion connection after delay")
	
	# Set the connection flag to true even if the connection might have failed
	learning_companion_connected = true
	
	# Try to ensure audio is initialized as well
	if JSBridge:
		if JSBridge.has_interface():
			JSBridge.get_interface().ensure_audio_initialized()
	
	# Emit game started event
	_on_game_started_for_companion()
	
	print("Force-sent game started event to learning companion")

func check_mission_progress(mission_id: String) -> bool:
	if not active_missions.has(mission_id):
		return false
	
	var mission = active_missions[mission_id]
	var all_completed = true
	
	for i in range(mission.objectives.size()):
		var objective = mission.objectives[i]
		if not objective.completed:
			all_completed = false
	
	if all_completed:
		complete_mission(mission_id)
		return true
	
	return false

func update_objective_progress(mission_id: String, objective_type: int, amount: int = 1, structure_index: int = -1):
	if not active_missions.has(mission_id):
		return
	
	var mission = active_missions[mission_id]
	
	for objective in mission.objectives:
		if objective.type == objective_type:
			# For specific structure objectives, check structure index
			if objective.type == MissionObjective.ObjectiveType.BUILD_SPECIFIC_STRUCTURE:
				if structure_index != objective.structure_index:
					continue
			
			# Track old count for comparison
			var old_count = objective.current_count
			
			# Update progress (positive or negative)
			if amount > 0:
				objective.progress(amount)
			else:
				# For negative amounts (like when demolishing buildings)
				objective.regress(abs(amount))
				# Ensure completed flag is updated properly
				objective.completed = objective.is_completed()
			
			# Emit signal if progress changed
			if old_count != objective.current_count:
				objective_progress.emit(objective, objective.current_count)
				
				# Check for progress milestones (25%, 50%, 75%) but only if learning companion is connected
				if learning_companion_connected and objective.target_count > 0:
					var progress_percentage = (float(objective.current_count) / float(objective.target_count)) * 100.0
					var milestone_keys = [
						["mission_progress_25", 25.0, false],
						["mission_progress_50", 50.0, false],
						["mission_progress_75", 75.0, false]
					]
					
					# Check each milestone
					for milestone in milestone_keys:
						var key = milestone[0]
						var threshold = milestone[1]
						var old_percentage = (float(old_count) / float(objective.target_count)) * 100.0
						
						# Only trigger if we just crossed this threshold
						if old_percentage < threshold and progress_percentage >= threshold:
							if mission.companion_dialog.has(key) and JSBridge.has_interface():
								print("Sending progress milestone dialog: " + key)
								var dialog_data = mission.companion_dialog[key]
								JSBridge.get_interface().sendCompanionDialog(key, dialog_data)
			
			# Check if objective was just completed
			if objective.completed and old_count != objective.current_count:
				objective_completed.emit(objective)
				
				# Only send dialog if learning companion is connected
				if learning_companion_connected:
					# Send objective-specific dialog to learning companion if available
					var objective_key = "objective_completed_" + str(objective.type)
					if mission.companion_dialog.has(objective_key):
						var dialog_data = mission.companion_dialog[objective_key]
						if JSBridge.has_interface():
							JSBridge.get_interface().sendCompanionDialog(objective_key, dialog_data)
					# Or send generic objective completion dialog if available
					elif mission.companion_dialog.has("objective_completed"):
						var dialog_data = mission.companion_dialog["objective_completed"]
						if JSBridge.has_interface():
							JSBridge.get_interface().sendCompanionDialog("objective_completed", dialog_data)
	
	# Check if mission is now complete
	check_mission_progress(mission_id)
	update_mission_ui()

func _on_structure_placed(structure_index: int, position: Vector3):
	if structure_index < 0 or structure_index >= builder.structures.size():
		return
		
	var structure = builder.structures[structure_index]
	
	# Check if this is a residential building in mission 3 (which uses construction workers)
	var skip_residential_count = false
	if structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
		if current_mission and current_mission.id == "3":
			# Skip residential count updates - will be handled after construction completes
			skip_residential_count = true
	
	# Special handling for power plant (Mission 5)
	if structure.model.resource_path.contains("power_plant"):
		for mission_id in active_missions:
			if active_missions[mission_id].id == "5":
				var mission = active_missions[mission_id]
				for objective in mission.objectives:
					if not objective.completed:
						objective.progress(objective.target_count)
						objective_progress.emit(objective, objective.current_count)
						objective_completed.emit(objective)
				
				# Force mission completion check
				check_mission_progress(mission_id)
	
	for mission_id in active_missions:
		# Update generic structure objective
		update_objective_progress(mission_id, MissionObjective.ObjectiveType.BUILD_STRUCTURE)
		
		# Update based on structure type
		match structure.type:
			Structure.StructureType.ROAD:
				update_objective_progress(mission_id, MissionObjective.ObjectiveType.BUILD_ROAD)
			Structure.StructureType.RESIDENTIAL_BUILDING:
				# Only update residential count if we're not in mission 3 or 1
				if not skip_residential_count:
					update_objective_progress(mission_id, MissionObjective.ObjectiveType.BUILD_RESIDENTIAL)
					
				# We don't spawn characters here anymore - this is handled by the builder.gd
				# for both direct placement and worker construction
					
			Structure.StructureType.COMMERCIAL_BUILDING:
				update_objective_progress(mission_id, MissionObjective.ObjectiveType.BUILD_COMMERCIAL)
			Structure.StructureType.INDUSTRIAL_BUILDING:
				update_objective_progress(mission_id, MissionObjective.ObjectiveType.BUILD_INDUSTRIAL)
		
		# If it's a specific structure, check that too
		update_objective_progress(
			mission_id, 
			MissionObjective.ObjectiveType.BUILD_SPECIFIC_STRUCTURE,
			1,
			structure_index
		)

func update_mission_ui():
	if mission_ui and current_mission:
		mission_ui.update_mission_display(current_mission)
		
# Reset the count of a specific objective type in the current mission
func reset_objective_count(objective_type: int, new_count: int = 0):
	if not current_mission:
		return
		
	for objective in current_mission.objectives:
		if objective.type == objective_type:
			objective.current_count = new_count
			objective.completed = objective.is_completed()
			objective_progress.emit(objective, objective.current_count)
			
	update_mission_ui()

func _on_learning_completed():
	# Check current mission for progress
	if current_mission != null and current_mission.id != "":
		check_mission_progress(current_mission.id)
		
func _on_learning_panel_opened():
	# Disable building controls
	if builder:
		builder.disabled = true
		
func _on_learning_panel_closed():
	# Re-enable building controls
	if builder:
		builder.disabled = false
		
# Method to skip the current mission
func _skip_current_mission():
	if not current_mission:
		return
		
	var mission_id = current_mission.id
	
	# Auto-complete all objectives in the current mission
	for objective in current_mission.objectives:
		objective.progress(objective.target_count - objective.current_count)
	
	# If there's a learning panel open, close it
	if learning_panel and learning_panel.visible:
		learning_panel.hide_learning_panel()
	
	# If there's a fullscreen learning panel open, close it
	if fullscreen_learning_panel and fullscreen_learning_panel.visible:
		fullscreen_learning_panel.hide_fullscreen_panel()
	
	# Complete the mission
	complete_mission(mission_id)
		
func _spawn_character_on_road(building_position: Vector3):
	if !character_scene:
		return
		
	# Check if a character has already been spawned
	var existing_characters = get_tree().get_nodes_in_group("characters")
	if existing_characters.size() > 0 or character_spawned:
		character_spawned = true
		return
		
	# Mark as spawned to prevent multiple spawns
	character_spawned = true
	
	# Find the nearest road to the building
	var gridmap = builder.gridmap
	var nearest_road_position = _find_nearest_road(building_position, gridmap)
	
	if nearest_road_position != Vector3.ZERO:
		# Make sure there are no existing characters
		for existing in get_tree().get_nodes_in_group("characters"):
			existing.queue_free()
		
		# Use the pre-made character pathing scene
		var character = load("res://scenes/character_pathing.tscn").instantiate()
		
		# Override with our improved navigation script
		character.set_script(load("res://scripts/NavigationNPC.gd"))
		
		# Add to a group for management
		character.add_to_group("characters")
		
		# Find the NavRegion3D (should have been created by builder)
		var nav_region = builder.nav_region
		if nav_region:
			# Add character as a child of the NavRegion3D
			nav_region.add_child(character)
		else:
			# Fallback to root if NavRegion3D doesn't exist
			get_tree().root.add_child(character)
		
		# Position character just slightly above the road's surface
		character.global_transform.origin = Vector3(nearest_road_position.x, 0.1, nearest_road_position.z)
		
		# Set an initial target to get the character moving
		var target_position = _find_patrol_target(nearest_road_position, gridmap, 8.0)
		
		# Allow the character to initialize
		await get_tree().process_frame
		
		# Make sure the navigation agent is properly set up
		if character.has_node("NavigationAgent3D"):
			var nav_agent = character.get_node("NavigationAgent3D")
			nav_agent.path_desired_distance = 0.5
			nav_agent.target_desired_distance = 0.5
			
			# Set target position
			nav_agent.set_target_position(target_position)
		
		# Make the character start moving
		if character.has_method("set_movement_target"):
			character.set_movement_target(target_position)
		
func _setup_character_for_navigation(character, initial_target):
	# Access character's script to set up navigation
	if character.has_node("character-female-d2"):
		var model = character.get_node("character-female-d2")
		
		# Set up animation
		if model.has_node("AnimationPlayer"):
			var anim_player = model.get_node("AnimationPlayer")
			anim_player.play("walk")
			
	# Configure navigation agent parameters
	if character.has_node("NavigationAgent3D"):
		var nav_agent = character.get_node("NavigationAgent3D")
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		
		# Force movement to start immediately
		if character.has_method("set_movement_target"):
			# Wait a bit to make sure the navigation mesh is ready
			await get_tree().create_timer(1.0).timeout
			character.set_movement_target(initial_target)
	
	# Ensure auto-patrol is enabled if the character supports it
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
