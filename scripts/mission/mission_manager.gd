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
	
	# Start the first mission if available
	if missions.size() > 0:
		start_mission(missions[0])

func start_mission(mission: MissionData):
	current_mission = mission
	active_missions[mission.id] = mission
	
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
				
				# Check if this is our first residential building in mission 1
				if not character_spawned:
					print("Attempting to spawn character at: ", position)
					_spawn_character_on_road(position)
					
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
		
func _spawn_character_on_road(building_position: Vector3):
	if !character_scene:
		print("No character scene provided!")
		return
		
	if character_spawned:
		print("Character already spawned.")
		return
		
	character_spawned = true
	
	# Find the nearest road to the building
	var gridmap = builder.gridmap
	var nearest_road_position = _find_nearest_road(building_position, gridmap)
	
	if nearest_road_position != Vector3.ZERO:
		print("Found nearest road at: ", nearest_road_position)
		
		# Check if road is horizontal or vertical
		var is_horizontal_road = true
		var connected_road = _find_connected_road(nearest_road_position, gridmap)
		
		if connected_road != Vector3.ZERO:
			# Compare positions to determine if it's an X or Z oriented road
			var diff = connected_road - nearest_road_position
			is_horizontal_road = abs(diff.x) > abs(diff.z)
			print("Connected road diff: ", diff, " - Horizontal road: ", is_horizontal_road)
		
		# Spawn character directly on the road
		var character = character_scene.instantiate()
		get_tree().root.add_child(character) # Add to root to ensure visibility
		
		# Position character just slightly above the road's surface
		character.global_transform.origin = Vector3(nearest_road_position.x, 0.1, nearest_road_position.z)
		
		# Wait for transform to apply
		await get_tree().process_frame
		
		# Set direction based on road orientation
		if is_horizontal_road:
			character.direction = Vector3(1, 0, 0)  # Move along X axis
			if character.character_model:
				character.character_model.rotation.y = 0  # Look right
		else:
			character.direction = Vector3(0, 0, 1)  # Move along Z axis
			if character.character_model:
				character.character_model.rotation.y = PI/2  # Look down the Z axis
		
		# Set up patrol parameters
		character.walk_speed = 3.0  # Moderate speed
		character.patrol_distance = 8.0  # Good distance
		
		# Reset character properties
		character.start_position = character.global_position
		character.target_position = character.start_position + character.direction * character.patrol_distance
		character.initialized = true
		
		# Print debug info
		print("Character spawned with direction: ", character.direction)
		print("Character patrol from: ", character.start_position, " to ", character.target_position)
	else:
		print("No road found near building!")
		
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
	
	# First pass: find all roads
	var road_positions = []
	for x in range(-3, 4):
		for z in range(-3, 4):
			var check_pos = Vector3(position.x + x, 0, position.z + z)
			var cell_item = gridmap.get_cell_item(check_pos)
			
			# Check if cell has a valid road
			if cell_item >= 0 and cell_item < builder.structures.size():
				var structure_type = builder.structures[cell_item].type
				if structure_type == Structure.StructureType.ROAD:
					road_positions.append(check_pos)
	
	print("Found ", road_positions.size(), " road positions")
	
	# Second pass: evaluate roads based on distance and connected length
	for road_pos in road_positions:
		var distance = position.distance_to(road_pos)
		
		# Prioritize roads that are both close and part of a longer road
		if distance < min_distance:
			# Check connected road length
			var road_length = _get_connected_road_length(road_pos, gridmap)
			print("Road at ", road_pos, " has length: ", road_length, " and distance: ", distance)
			
			# Always choose the closest road initially
			if nearest_road == Vector3.ZERO:
				nearest_road = road_pos
				min_distance = distance
				best_road_length = road_length
			# Then prefer longer roads if they're within reasonable distance
			elif road_length > best_road_length and distance < min_distance + 2.0:
				nearest_road = road_pos
				min_distance = distance
				best_road_length = road_length
			# Otherwise just take the closest
			elif distance < min_distance:
				nearest_road = road_pos
				min_distance = distance
				best_road_length = road_length
	
	if nearest_road != Vector3.ZERO:
		print("Selected road at: ", nearest_road, " with length: ", best_road_length)
	
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
