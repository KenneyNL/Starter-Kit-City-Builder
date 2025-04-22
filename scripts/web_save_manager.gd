extends Node

const SAVE_KEY = "stem_city_save_data"

func save_map(map: DataMap) -> void:
	if OS.has_feature("web"):
		# For web builds, use localStorage
		var save_data = {
			"cash": map.cash,
			"structures": []
		}
		
		# Convert structures to a format that can be serialized
		for structure in map.structures:
			save_data.structures.append({
				"position": {"x": structure.position.x, "y": structure.position.y},
				"orientation": structure.orientation,
				"structure": structure.structure
			})
		
		# Convert to JSON and save to localStorage
		var json = JSON.stringify(save_data)
		print("Saving game data: ", json)  # Debug log
		
		# Try to save to localStorage
		var result = JavaScriptBridge.eval("""
			try {
				localStorage.setItem('%s', '%s');
				return 'success';
			} catch(e) {
				console.error('Error saving game:', e);
				return 'error:' + e.message;
			}
		""" % [SAVE_KEY, json])
		
		if result != "success":
			push_error("Failed to save game: " + result)
	else:
		# For desktop builds, use the existing ResourceSaver
		var result = ResourceSaver.save(map, "user://map.res")
		if result != OK:
			push_error("Failed to save game: " + str(result))

func load_map() -> DataMap:
	if OS.has_feature("web"):
		# For web builds, load from localStorage
		var map = DataMap.new()
		var json = JavaScriptBridge.eval("""
			try {
				return localStorage.getItem('%s');
			} catch(e) {
				console.error('Error loading game:', e);
				return null;
			}
		""" % SAVE_KEY)
		
		print("Loaded game data: ", json)  # Debug log
		
		if json and json != "null":
			var save_data = JSON.parse_string(json)
			if save_data:
				map.cash = save_data.cash
				map.structures.clear()
				
				for structure_data in save_data.structures:
					var data_structure = DataStructure.new()
					data_structure.position = Vector2i(structure_data.position.x, structure_data.position.y)
					data_structure.orientation = structure_data.orientation
					data_structure.structure = structure_data.structure
					map.structures.append(data_structure)
			else:
				push_error("Failed to parse save data")
		else:
			print("No save data found, starting new game")
		
		return map
	else:
		# For desktop builds, use the existing ResourceLoader
		if ResourceLoader.exists("user://map.res"):
			var map = ResourceLoader.load("user://map.res")
			if map:
				return map
			else:
				push_error("Failed to load map resource")
		return DataMap.new() 