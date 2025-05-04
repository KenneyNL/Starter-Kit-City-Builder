extends Node
class_name MissionLoader

const MissionData = preload("res://scripts/mission/mission_data.gd")
const MissionObjective = preload("res://scripts/mission/mission_objective.gd")

var mission_manager: MissionManager
var builder: Node3D

func _init(manager: MissionManager, builder_ref: Node3D):
	mission_manager = manager
	builder = builder_ref

# Load mission data from JavaScript
func load_from_js(mission_data: Dictionary) -> void:
	print("\n=== Loading Mission Data from JavaScript ===")
	print("Received mission data:", mission_data)
	
	if not mission_data:
		print("WARNING: No mission data received from JavaScript")
		return
		
	print("Converting mission data to Godot objects...")
	if "missions" in mission_data:
		var missions = _convert_missions(mission_data.missions)
		print("Converted missions:", missions)
		print("Number of missions converted: ", missions.size())
		
		if missions.is_empty():
			print("WARNING: No missions were converted from the data")
			return
			
		print("Setting up missions...")
		mission_manager.missions = missions
		print("Missions set in manager. Current missions array size: ", mission_manager.missions.size())
		if mission_manager.missions.size() > 0:
			print("First mission details:")
			print("  Title: ", mission_manager.missions[0].title)
			print("  Description: ", mission_manager.missions[0].description)
			print("  Number of objectives: ", mission_manager.missions[0].objectives.size())
		print("=== Mission Data Loading Complete ===\n")
	else:
		print("WARNING: No 'missions' key found in mission data")

# Unlock the starting structures
func _unlock_starting_structures(structure_paths: Array) -> void:
	print("\n=== Unlocking Starting Structures ===")
	print("Paths to unlock: ", structure_paths)
	
	if not builder:
		push_error("Builder not available")
		return
		
	# Get current structures
	var structures = builder.get_structures()
	if not structures:
		push_error("No structures available")
		return
		
	# Process each path
	for path in structure_paths:
		print("\nProcessing path: ", path)
		
		# Handle both structures/ and models/ paths
		var possible_paths = []
		
		# Add the original path
		possible_paths.append(path)
		
		# Handle .tres to .glb conversion
		if path.ends_with(".tres"):
			# Convert structures/ path to models/ path
			if "structures/" in path:
				possible_paths.append(path.replace("structures/", "models/").replace(".tres", ".glb"))
		
		# Handle .glb to .tres conversion
		if path.ends_with(".glb"):
			# Convert models/ path to structures/ path
			if "models/" in path:
				possible_paths.append(path.replace("models/", "structures/").replace(".glb", ".tres"))
		
		print("Trying possible paths: ", possible_paths)
		
		var found_match = false
		for structure in structures:
			if not structure.model:
				continue
				
			var structure_path = structure.model.resource_path
			
			# Only try exact path matches
			for possible_path in possible_paths:
				if structure_path == possible_path:
					structure.unlocked = true
					found_match = true
					break
			
			if found_match:
				break
				
		if not found_match:
			print("WARNING: No match found for path: ", path)

# Convert mission dictionaries to MissionData objects
func _convert_missions(mission_dicts: Array) -> Array[MissionData]:
	print("Converting mission configurations...")
	var converted: Array[MissionData] = []
	
	for mission_dict in mission_dicts:
		var mission_data = MissionData.new()
		
		# Set basic properties
		mission_data.id = mission_dict.get("id", "")
		mission_data.title = mission_dict.get("title", "")
		mission_data.description = mission_dict.get("description", "")
		
		# Convert objectives
		var objectives: Array[MissionObjective] = []
		for obj in mission_dict.get("objectives", []):
			var objective = MissionObjective.new()
			objective.type = obj.get("type", 0)
			objective.target_count = obj.get("target_count", 0)
			objective.description = obj.get("description", "")
			
			# Load structure resource if specified
			var structure_path = obj.get("structure_path", "")
			if structure_path:
				objective.structure = load(structure_path)
				
			objectives.append(objective)
			
		mission_data.objectives = objectives
		
		# Set rewards
		mission_data.rewards = mission_dict.get("rewards", {})
		
		# Set unlocked items
		var unlocked_items_array: Array[String] = []
		for item in mission_dict.get("unlocked_items", []):
			unlocked_items_array.append(str(item))
		mission_data.unlocked_items = unlocked_items_array
		
		# Set starting structures
		var starting_structures_array: Array[String] = []
		for item in mission_dict.get("starting_structures", []):
			starting_structures_array.append(str(item))
		mission_data.starting_structures = starting_structures_array
		
		# Set additional properties
		mission_data.next_mission_id = mission_dict.get("next_mission_id", "")
		mission_data.graph_path = mission_dict.get("graph_path", "")
		mission_data.full_screen_path = mission_dict.get("full_screen_path", "")
		mission_data.intro_text = mission_dict.get("intro_text", "")
		mission_data.question_text = mission_dict.get("question_text", "")
		mission_data.correct_answer = mission_dict.get("correct_answer", "")
		mission_data.feedback_text = mission_dict.get("feedback_text", "")
		mission_data.incorrect_feedback = mission_dict.get("incorrect_feedback", "")
		mission_data.company_data = mission_dict.get("company_data", "")
		mission_data.power_math_content = mission_dict.get("power_math_content", "")
		mission_data.num_of_user_inputs = mission_dict.get("num_of_user_inputs", 1)
		
		# Convert input labels to Array[String]
		var input_labels_array: Array[String] = []
		for label in mission_dict.get("input_labels", []):
			input_labels_array.append(str(label))
		mission_data.input_labels = input_labels_array
		
		# Set companion dialog
		mission_data.companion_dialog = mission_dict.get("companion_dialog", {})
		
		converted.append(mission_data)
		
	return converted 
