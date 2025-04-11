extends Node

# Simple function to handle structure unlocking for missions
static func process_structures(structures, mission_id):
	for structure in structures:
		# Default is locked
		structure.unlocked = false
		
		# Handle basic structures (always available)
		if basic_structure(structure):
			structure.unlocked = true
			
		# Handle mission-specific structures
		if mission_id == "1":
			# Mission 1: Unlock residential buildings
			if residential_building(structure):
				structure.unlocked = true
				
		elif mission_id == "2" or mission_id == "3":
			# Missions 2-3: Unlock curved roads and decoration
			if curved_road(structure) or decoration(structure):
				structure.unlocked = true
				
		elif mission_id == "4" or mission_id == "5":
			# Missions 4-5: Unlock power plants
			if power_plant(structure):
				structure.unlocked = true

# Simple helper functions to categorize structures
static func basic_structure(structure):
	var path = structure.model.resource_path
	return path.contains("road-straight") or path.contains("pavement")
	
static func residential_building(structure):
	return structure.model.resource_path.contains("building-small-a")
	
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