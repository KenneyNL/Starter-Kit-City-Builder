extends Node

# This is a helper function to handle structure unlocking
# We're putting it in a separate file to avoid syntax issues in mission_manager.gd

# Unlocks basic structures and locks special ones
func process_structures(structures_array):
	# Start with all unlocked
	for structure in structures_array:
		# Basic structures are always unlocked
		if basic_structure(structure):
			structure.unlocked = true
		# Special structures start locked unless mission-specific
		elif special_structure(structure):
			structure.unlocked = false
		else:
			# Default to unlocked for other structures
			structure.unlocked = true

# Check if this is a mission-dependent structure type that should be unlocked
func unlock_by_mission(structures_array, mission_id):
	if mission_id == "1":
		# Only basic structures in mission 1
		return
	
	if mission_id == "2" or mission_id == "3":
		# Unlock decorations and curved roads
		for structure in structures_array:
			if structure.model.resource_path.contains("road-corner") or structure.model.resource_path.contains("grass-trees-tall"):
				structure.unlocked = true
				
	if mission_id == "4" or mission_id == "5":
		# Unlock power plants
		for structure in structures_array:
			if structure.model.resource_path.contains("power_plant"):
				structure.unlocked = true

# Check if a structure is one of the basic types (always available)
func basic_structure(structure):
	return (structure.model.resource_path.contains("road-straight") or 
	       structure.model.resource_path.contains("building-small-a") or
	       structure.model.resource_path.contains("pavement") or
	       structure.model.resource_path.contains("grass.glb"))

# Check if a structure is a special type (requires unlocking)
func special_structure(structure):
	return (structure.model.resource_path.contains("road-corner") or 
	       structure.model.resource_path.contains("grass-trees-tall") or
	       structure.model.resource_path.contains("power_plant"))
	       
# Ensure an unlocked structure is selected
func select_unlocked_structure(builder):
	# Find the first unlocked structure
	var found_unlocked = false
	for i in range(builder.structures.size()):
		if builder.structures[i].unlocked:
			builder.index = i
			builder.update_structure()
			found_unlocked = true
			break
			
	# If no structures are unlocked, unlock a basic one
	if not found_unlocked and builder.structures.size() > 0:
		builder.structures[0].unlocked = true
		builder.index = 0
		builder.update_structure()