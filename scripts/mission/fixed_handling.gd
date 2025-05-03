extends Node

# Simple function to handle structure unlocking for missions
static func process_structures(structures, mission):
	print("\n=== Processing Structures for Mission: ", mission.id, " ===")
	print("Starting Structures: ", mission.starting_structures)
	print("Unlocked Items: ", mission.unlocked_items)
	
	for structure in structures:
		print("\n--- Processing Structure: ", structure.model.resource_path, " ---")
		print("Initial status: ", structure.unlocked)
		
		# Default is locked
		structure.unlocked = false
		print("After default lock: ", structure.unlocked)
			
		# Handle starting structures (always available for this mission)
		if mission.starting_structures != null:
			print("Checking starting structures: ", mission.starting_structures)
			for item in mission.starting_structures:
				if structure.model.resource_path == item or structure.resource_path == item:
					print("Found matching starting structure: ", item)
					structure.unlocked = true
					print("After starting structures check: ", structure.unlocked)
					break
		
		# Handle unlocked items (unlocked from previous missions)
		if mission.unlocked_items != null:
			print("Checking unlocked items: ", mission.unlocked_items)
			for item in mission.unlocked_items:
				if structure.model.resource_path == item or structure.resource_path == item:
					print("Found matching unlocked item: ", item)
					structure.unlocked = true
					print("After unlocked items check: ", structure.unlocked)
					break
		
		# Check if it's a basic structure
		if basic_structure(structure):
			print("Structure is marked as basic")
			structure.unlocked = true
			print("After basic structure check: ", structure.unlocked)
			
		print("Final status: ", structure.unlocked)
		print("--- End Structure Processing ---\n")

# Simple helper functions to categorize structures
static func basic_structure(structure):
	var path = structure.model.resource_path
	# Only consider the exact road-straight.tres as basic
	return path == "res://structures/road-straight.tres" or path.contains("pavement")
	
static func residential_building(structure):
	var path = structure.model.resource_path
	var res_path = structure.resource_path if structure.has("resource_path") else ""
	var is_residential = path.contains("building-small-a") or res_path.contains("building-small-a")
	print("Checking if residential: ", path, " or ", res_path, " = ", is_residential)
	return is_residential
	
static func curved_road(structure):
	return structure.model.resource_path.contains("road-corner")
	
static func decoration(structure):
	return structure.model.resource_path.contains("grass-trees")
	
static func power_plant(structure):
	return structure.model.resource_path.contains("power_plant")
	
# Ensure builder has an unlocked structure selected
static func select_unlocked(builder):
	var found = false
	
	# Look for an unlocked structure
	for i in range(builder.structures.size()):
		if builder.structures[i].unlocked:
			builder.index = i
			builder.update_structure()
			found = true
			break
			
	# If nothing is unlocked, unlock the first structure
	if not found and builder.structures.size() > 0:
		builder.structures[0].unlocked = true
		builder.index = 0
		builder.update_structure()