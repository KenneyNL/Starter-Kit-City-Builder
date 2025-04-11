extends Node

# This is a helper script to be attached to mission_manager to handle the direct unlocked panel

# Simplified function to show the unlocked panel without using signals
func show_direct_unlocked_panel(structures, callback_node, callback_method):
	print("Showing direct unlocked panel")
	
	# Load the scene
	var scene = load("res://scenes/direct_unlocked_panel.tscn")
	if not scene:
		push_error("Failed to load direct_unlocked_panel.tscn")
		return
	
	# Instantiate
	var instance = scene.instantiate()
	get_tree().root.add_child(instance)
	
	# Get the main nodes
	var panel = instance.get_node("Control")
	var close_button = instance.get_node("Control/PanelContainer/MarginContainer/VBoxContainer/SimpleCloseButton")
	var items_container = instance.get_node("Control/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer")
	
	# Connect close button directly
	close_button.pressed.connect(func():
		print("Direct panel close button pressed")
		instance.queue_free()
		get_tree().paused = false
		callback_node.call(callback_method)
	)
	
	# Clear sample content
	for child in items_container.get_children():
		child.queue_free()
	
	# Add each structure
	for structure in structures:
		# Create item row
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_container.add_child(row)
		
		# Add texture
		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(100, 100)
		tex_rect.expand_mode = TextureRect.EXPAND_KEEP_ASPECT
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tex_rect)
		
		# Add info container
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		
		# Add name
		var name_label = Label.new()
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.text = get_structure_name(structure)
		info.add_child(name_label)
		
		# Add description
		var desc_label = Label.new()
		desc_label.text = structure.description if structure.has_method("description") else "No description"
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc_label)
		
		# Add separator
		var separator = HSeparator.new()
		items_container.add_child(separator)
	
	# Pause game
	get_tree().paused = true

# Get structure name
func get_structure_name(structure):
	if structure.has_method("model") and structure.model:
		var path = structure.model.resource_path
		var filename = path.get_file().get_basename()
		
		# Convert kebab-case to Title Case
		var words = filename.split("-")
		var title_case = ""
		
		for word in words:
			if word.length() > 0:
				title_case += word[0].to_upper() + word.substr(1) + " "
		
		return title_case.strip_edges()
	
	return "Unknown Structure"