extends Node

# This script provides an accurate counter for mission 3's residential buildings
# Instead of polling, it listens for signals when buildings are constructed or demolished

func _ready():
	# Wait a moment for the game to initialize
	await get_tree().create_timer(1.0).timeout
	
	# Get builder reference
	var builder = get_node_or_null("/root/Main/Builder")
	if builder:
		# Connect to structure placed and removed signals
		builder.structure_placed.connect(_on_structure_placed)
		builder.structure_removed.connect(_on_structure_removed)
		builder.construction_manager.construction_completed.connect(_on_construction_completed)
		
		# Do initial count on mission start
		update_mission_3_count()
	else:
		print("ERROR: Could not find Builder node for signal connections")

# Called when a structure is placed
func _on_structure_placed(structure_index, position):
	# We don't need immediate action - residential counts are updated after construction
	pass

# Called when a structure is removed
func _on_structure_removed(structure_index, position):
	var builder = get_node_or_null("/root/Main/Builder")
	if builder and structure_index >= 0 and structure_index < builder.structures.size():
		if builder.structures[structure_index].type == 1:  # Residential building
			print("Residential building demolished at " + str(position) + ", updating mission count")
			# Wait one frame to make sure the GridMap is updated
			await get_tree().process_frame
			# Update the count
			update_mission_3_count()

# Called when construction is completed
func _on_construction_completed(position):
	update_mission_3_count()

# Updates the mission 3 objective count based on actual residential buildings
func update_mission_3_count():
	# Find the mission manager
	var mission_manager = get_node_or_null("/root/Main/MissionManager")
	if not mission_manager:
		print("ERROR: Could not find MissionManager")
		return
		
	# Check if we're in mission 3
	if mission_manager.current_mission and mission_manager.current_mission.id == "3":
		# Count the actual number of residential buildings
		var count = count_residential_buildings()
		
		# Get the current objective count
		var current_count = 0
		for objective in mission_manager.current_mission.objectives:
			if objective.type == 3:  # BUILD_RESIDENTIAL type
				current_count = objective.current_count
				break
				
		# Only update if the counts don't match
		if current_count != count:
			# Reset the objective count to match the actual number
			mission_manager.reset_objective_count(3, count)  # 3 is the BUILD_RESIDENTIAL type
			print("Updated mission 3 objective count to match actual building count: " + str(count))
	
func count_residential_buildings():
	# Find the builder
	var builder = get_node_or_null("/root/Main/Builder")
	if not builder:
		print("ERROR: Could not find Builder")
		return 0
		
	# Find the gridmap
	var gridmap = builder.gridmap
	if not gridmap:
		print("ERROR: Could not find GridMap")
		return 0
		
	# Count residential buildings in the gridmap
	var residential_count = 0
	var found_positions = []
	
	print("COUNTING: Starting residential building count")
	
	# First count buildings in the gridmap
	for cell in gridmap.get_used_cells():
		var structure_index = gridmap.get_cell_item(cell)
		if structure_index >= 0 and structure_index < builder.structures.size():
			if builder.structures[structure_index].type == 1:  # 1 is RESIDENTIAL_BUILDING type
				residential_count += 1
				found_positions.append(Vector2(cell.x, cell.z))
				print("COUNTING: Found residential building in GridMap at " + str(cell))
	
	print("COUNTING: Found " + str(residential_count) + " buildings in GridMap")
				
	# Also count completed buildings that might not be in the gridmap
	if builder.has_node("NavRegion3D"):
		var nav_region = builder.get_node("NavRegion3D")
		var nav_buildings = 0
		
		for child in nav_region.get_children():
			if child.name.begins_with("Building_"):
				var parts = child.name.split("_")
				if parts.size() >= 3:
					var x = int(parts[1])
					var z = int(parts[2])
					var pos = Vector2(x, z)
					
					# Only count if we haven't already counted this position
					if not pos in found_positions:
						residential_count += 1
						nav_buildings += 1
						found_positions.append(pos)
						print("COUNTING: Found building model in NavRegion3D at " + str(pos))
		
		print("COUNTING: Found " + str(nav_buildings) + " additional buildings in NavRegion3D")
	
	# Also count any buildings under construction
	if builder.construction_manager:
		var construction_count = 0
		for position in builder.construction_manager.construction_sites:
			var site = builder.construction_manager.construction_sites[position]
			if site.structure_index >= 0 and site.structure_index < builder.structures.size():
				if builder.structures[site.structure_index].type == 1 and site.completed:  # Only count completed residential buildings
					# Check if there's actually a building at this position in the GridMap
					var cell_item = builder.gridmap.get_cell_item(position)
					if cell_item >= 0:  # Only count if there's still a building in the GridMap
						var pos = Vector2(position.x, position.z)
						if not pos in found_positions:
							residential_count += 1
							construction_count += 1
							found_positions.append(pos)
							print("COUNTING: Found completed construction site at " + str(position))
					else:
						print("COUNTING: Ignoring completed construction site at " + str(position) + " because no building found in GridMap")
						
		print("COUNTING: Found " + str(construction_count) + " buildings from construction sites")
	
	print("COUNTING: Final total - " + str(residential_count) + " residential buildings")
	return residential_count
