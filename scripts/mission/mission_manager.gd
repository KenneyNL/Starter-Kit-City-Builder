extends Node
class_name MissionManager

signal mission_started(mission: MissionData)
signal mission_completed(mission: MissionData)
signal objective_completed(objective: MissionObjective)
signal objective_progress(objective: MissionObjective, new_count: int)

@export var missions: Array[MissionData] = []
@export var mission_ui: Control
@export var builder: Node3D
@export var character_scene: PackedScene

var current_mission: MissionData
var active_missions: Dictionary = {}  # mission_id: MissionData
var learning_panel: LearningPanel
var character_spawned: bool = false

# Mission skip variables
var skip_key_presses: int = 0
var last_skip_press_time: float = 0
var skip_key_timeout: float = 1.0  # Reset counter if time between presses exceeds this value
var skip_key_required: int = 5  # Number of key presses needed to skip
const SKIP_KEY = KEY_TAB  # The key to press for skipping missions

func _ready():
	if builder:
		# Connect to builder signals
		builder.connect("structure_placed", _on_structure_placed)
	
	# Get reference to learning panel
	learning_panel = get_node("LearningPanel")
	if learning_panel:
		learning_panel.completed.connect(_on_learning_completed)
		learning_panel.panel_opened.connect(_on_learning_panel_opened)
		learning_panel.panel_closed.connect(_on_learning_panel_closed)
	
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
	
	# Start the first mission if available
	if missions.size() > 0:
		start_mission(missions[0])

func start_mission(mission: MissionData):
	current_mission = mission
	active_missions[mission.id] = mission
	
	# Special handling for mission 3: add additional structures
	if mission.id == "3" and builder:
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
				print("Adding road-corner structure for mission 3")
				builder.structures.append(road_corner)
		
		# Add the grass-trees-tall if missing
		if not has_grass_trees_tall:
			var grass_trees_tall = load("res://structures/grass-trees-tall.tres")
			if grass_trees_tall:
				print("Adding grass-trees-tall structure for mission 3")
				builder.structures.append(grass_trees_tall)
		
		# Add the grass if missing
		if not has_grass:
			var grass = load("res://structures/grass.tres")
			if grass:
				print("Adding grass structure for mission 3")
				builder.structures.append(grass)
	
	# Special handling for mission 4: add power plant
	elif mission.id == "4" and builder:
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
				print("Adding power plant structure for mission 4")
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
			
			print("Updated mesh library for mission 3 with new structures")
			
			# Make sure the builder's structure selector is updated
			builder.update_structure()
	
	# Check if mission has a learning objective
	var has_learning_objective = false
	for objective in mission.objectives:
		if objective.type == MissionObjective.ObjectiveType.LEARNING:
			has_learning_objective = true
			break
	
	# Show learning panel if mission has a learning objective
	if has_learning_objective and learning_panel:
		learning_panel.show_learning_panel(mission)
	
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
	
	# Start next mission if specified
	if mission.next_mission_id != "":
		for next_mission in missions:
			if next_mission.id == mission.next_mission_id:
				start_mission(next_mission)
				break
	
	# Emit signal for mission completion
	mission_completed.emit(mission)
	update_mission_ui()

func check_mission_progress(mission_id: String) -> bool:
	if not active_missions.has(mission_id):
		return false
	
	var mission = active_missions[mission_id]
	var all_completed = true
	
	for objective in mission.objectives:
		if not objective.completed:
			all_completed = false
			break
	
	if all_completed:
		complete_mission(mission_id)
		return true
	
	return false

func update_objective_progress(mission_id: String, objective_type: int, amount: int = 1, structure_index: int = -1):
	if not active_missions.has(mission_id):
		return
	
	var mission = active_missions[mission_id]
	
	for objective in mission.objectives:
		if objective.completed:
			continue
			
		if objective.type == objective_type:
			# For specific structure objectives, check structure index
			if objective.type == MissionObjective.ObjectiveType.BUILD_SPECIFIC_STRUCTURE:
				if structure_index != objective.structure_index:
					continue
			
			# Update progress
			var old_count = objective.current_count
			objective.progress(amount)
			
			# Emit signal if progress changed
			if old_count != objective.current_count:
				objective_progress.emit(objective, objective.current_count)
			
			# Check if objective was just completed
			if objective.completed and old_count != objective.current_count:
				objective_completed.emit(objective)
	
	# Check if mission is now complete
	check_mission_progress(mission_id)
	update_mission_ui()

func _on_structure_placed(structure_index: int, position: Vector3):
	if structure_index < 0 or structure_index >= builder.structures.size():
		return
		
	var structure = builder.structures[structure_index]
	
	for mission_id in active_missions:
		# Update generic structure objective
		update_objective_progress(mission_id, MissionObjective.ObjectiveType.BUILD_STRUCTURE)
		
		# Update based on structure type
		match structure.type:
			Structure.StructureType.ROAD:
				update_objective_progress(mission_id, MissionObjective.ObjectiveType.BUILD_ROAD)
			Structure.StructureType.RESIDENTIAL_BUILDING:
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
		
func _on_learning_completed():
	# Check current mission for progress
	if current_mission:
		check_mission_progress(current_mission.id)
		
func _on_learning_panel_opened():
	# Disable building controls
	if builder:
		builder.disabled = true
		
func _on_learning_panel_closed():
	# Re-enable building controls
	if builder:
		builder.disabled = false
		
# Method to process keyboard input for mission skipping
func _input(event):
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
			
			# Print feedback to console
			if skip_key_presses < skip_key_required:
				print("Mission skip: " + str(skip_key_presses) + "/" + str(skip_key_required) + " key presses")
			
			# Check if we've reached the required number of presses
			if skip_key_presses >= skip_key_required:
				skip_key_presses = 0
				_skip_current_mission()
				
# Method to skip the current mission
func _skip_current_mission():
	if not current_mission:
		print("No mission to skip")
		return
		
	var mission_id = current_mission.id
	print("Skipping mission " + mission_id)
	
	# Auto-complete all objectives in the current mission
	for objective in current_mission.objectives:
		objective.progress(objective.target_count - objective.current_count)
	
	# If there's a learning panel open, close it
	if learning_panel and learning_panel.visible:
		learning_panel.hide_learning_panel()
	
	# Complete the mission
	complete_mission(mission_id)
		
func _spawn_character_on_road(building_position: Vector3):
	if !character_scene:
		print("No character scene provided!")
		return
		
	# Check if a character has already been spawned
	var existing_characters = get_tree().get_nodes_in_group("characters")
	if existing_characters.size() > 0 or character_spawned:
		print("Character already spawned, not spawning again.")
		character_spawned = true
		return
		
	# Mark as spawned to prevent multiple spawns
	character_spawned = true
	
	# Find the nearest road to the building
	var gridmap = builder.gridmap
	var nearest_road_position = _find_nearest_road(building_position, gridmap)
	
	if nearest_road_position != Vector3.ZERO:
		print("Found nearest road at: ", nearest_road_position)
		
		# Make sure there are no existing characters
		for existing in get_tree().get_nodes_in_group("characters"):
			existing.queue_free()
			print("Cleaned up existing character")
		
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
			print("Added character as child of NavRegion3D")
		else:
			# Fallback to root if NavRegion3D doesn't exist
			get_tree().root.add_child(character)
			print("WARNING: NavRegion3D not found, adding character to root")
		
		# Position character just slightly above the road's surface
		character.global_transform.origin = Vector3(nearest_road_position.x, 0.1, nearest_road_position.z)
		
		# Set an initial target to get the character moving
		var target_position = _find_patrol_target(nearest_road_position, gridmap, 8.0)
		print("Initial target set to: ", target_position)
		
		# Allow the character to initialize
		await get_tree().process_frame
		
		# Make sure the navigation agent is properly set up
		if character.has_node("NavigationAgent3D"):
			var nav_agent = character.get_node("NavigationAgent3D")
			nav_agent.path_desired_distance = 0.5
			nav_agent.target_desired_distance = 0.5
			
			# Set target position
			nav_agent.set_target_position(target_position)
			print("Navigation target set")
		
		# Make the character start moving
		if character.has_method("set_movement_target"):
			character.set_movement_target(target_position)
			print("Movement target set for character")
		else:
			print("Character does not have set_movement_target method!")
	else:
		print("No road found near building!")
		
func _setup_character_for_navigation(character, initial_target):
	# Access character's script to set up navigation
	if character.has_node("character-female-d2"):
		var model = character.get_node("character-female-d2")
		
		# Set up animation
		if model.has_node("AnimationPlayer"):
			var anim_player = model.get_node("AnimationPlayer")
			anim_player.play("walk")
			print("Animation player started")
		else:
			print("No animation player found in character model!")
			
	# Configure navigation agent parameters
	if character.has_node("NavigationAgent3D"):
		var nav_agent = character.get_node("NavigationAgent3D")
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		print("Navigation agent configured")
		
		# Force movement to start immediately
		if character.has_method("set_movement_target"):
			# Wait a bit to make sure the navigation mesh is ready
			await get_tree().create_timer(1.0).timeout
			character.set_movement_target(initial_target)
			print("Initial target set for character: ", initial_target)
	
	# Ensure auto-patrol is enabled if the character supports it
	if character.get("auto_patrol") != null:
		character.auto_patrol = true
		print("Auto patrol enabled for character")
		
	# Set a starting movement target if not moving
	await get_tree().create_timer(2.0).timeout
	if character.get("is_moving") != null and !character.is_moving:
		if character.has_method("pick_random_target"):
			character.pick_random_target()
			print("Forcing initial movement with pick_random_target()")
		
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
					print("Found target road at ", check_pos)
					return check_pos
	
	# If all else fails, just return a point 5 units away in a random direction
	var random_direction = Vector3(
		randf_range(-1.0, 1.0),
		0.0,
		randf_range(-1.0, 1.0)
	).normalized() * 5.0
	
	print("No road found, using random target")
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
	
	print("Searching for road near position: ", position)
	print("Available structures: ", builder.structures.size())
	
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
	
	print("Found ", road_positions.size(), " road positions")
	
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
	
	if nearest_road != Vector3.ZERO:
		print("Selected road at: ", nearest_road)
	
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
