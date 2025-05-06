extends Node

# Process structure unlocking based on mission data
static func process_mission_structures(structures: Array[Structure], mission_data):
	print("\n=== Processing Mission Structures ===")
	print("Mission ID: ", mission_data.id)
	
	# Don't lock all structures at start - only unlock new ones
	var paths_to_unlock = []
	
	# Only add starting structures - unlocked_items are handled when mission completes
	if mission_data.starting_structures.size() > 0:
		print("\nProcessing starting structures: ", mission_data.starting_structures)
		paths_to_unlock.append_array(mission_data.starting_structures)
	
	# Process all paths to unlock
	print("\nAttempting to unlock ", paths_to_unlock.size(), " structures")
	for path in paths_to_unlock:
		unlock_structure_by_path(structures, path)
			
	# Print final unlock status
	print("\nFinal structure status:")
	for i in range(structures.size()):
		var structure = structures[i]
		if structure.model:
			print("Structure ", i, ": ", structure.model.resource_path, " - Unlocked: ", structure.unlocked if "unlocked" in structure else "no unlock property")
	
	print("=== Structure Processing Complete ===\n")

# Helper function to unlock a structure by its resource path
static func unlock_structure_by_path(structures: Array[Structure], path: String):
	print("\nTrying to unlock structure with path: ", path)
	
	# Print all structures and their current unlock status
	print("\nCurrent structure status:")
	for i in range(structures.size()):
		var structure = structures[i]
		if structure.model:
			print("Structure ", i, ": ", structure.model.resource_path, " - Unlocked: ", structure.unlocked if "unlocked" in structure else "no unlock property")
	
	print("\nStarting structure matching...")
	for structure in structures:
		if not structure.model:
			continue
			
		var structure_path = structure.model.resource_path
		# Try exact path match first
		if structure_path == path:
			structure.unlocked = true
			break
		
		# Try converting between structures/ and models/ paths
		if path.ends_with(".tres") and "structures/" in path:
			var glb_path = path.replace("structures/", "models/").replace(".tres", ".glb")
			if structure_path == glb_path:
				print("Found converted path match (tres->glb), unlocking")
				structure.unlocked = true
				break
				
		if path.ends_with(".glb") and "models/" in path:
			var tres_path = path.replace("models/", "structures/").replace(".glb", ".tres")
			if structure_path == tres_path:
				print("Found converted path match (glb->tres), unlocking")
				structure.unlocked = true
				break 
				
	# Print final unlock status for all structures
	print("\nFinal structure status after matching:")
	for i in range(structures.size()):
		var structure = structures[i]
		if structure.model:
			print("Structure ", i, ": ", structure.model.resource_path, " - Unlocked: ", structure.unlocked if "unlocked" in structure else "no unlock property") 
