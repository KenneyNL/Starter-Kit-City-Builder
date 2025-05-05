extends Control

# Signal emitted when the panel is closed
signal closed

# Reference to the builder node to access all structures
var builder

func _ready():
	# Make sure this control stays on top and blocks input
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Initially hide the panel - will be shown when called
	visible = false
	
	# Find the builder reference to access structure data
	builder = get_node_or_null("/root/Main/Builder")
	
	print("UnlockedItemsPanel ready")

func setup(unlocked_structures):
	print("Setting up panel with " + str(unlocked_structures.size()) + " structures")
	
	var items_container = $PanelContainer/VBoxContainer/ScrollContainer/ItemsContainer
	if not items_container:
		push_error("Items container not found!")
		return
		
	# Clear any previous items
	for child in items_container.get_children():
		child.queue_free()
	
	# Debug info about structures
	for i in range(unlocked_structures.size()):
		if unlocked_structures[i].model:
			if "title" in unlocked_structures[i]:
				print("  Title: " + unlocked_structures[i].title)
			if "description" in unlocked_structures[i]:
				print("  Description: " + unlocked_structures[i].description)
			if "thumbnail" in unlocked_structures[i]:
				print("  Thumbnail: " + unlocked_structures[i].thumbnail)
		else:
			print("Structure " + str(i) + ": No model")
	
	# Add each unlocked structure
	for structure in unlocked_structures:
		# Skip structures without models
		if not structure.model:
			print("Skipping structure without model")
			continue
			
		# Create the row container
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		items_container.add_child(row)
		
		# Add structure thumbnail
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		
		# Try to get thumbnail from structure thumbnail field
		if "thumbnail" in structure and structure.thumbnail and structure.thumbnail != "Thumbnail":
			# Check if the thumbnail path is valid
			if ResourceLoader.exists(structure.thumbnail):
				print("Loading thumbnail from path: " + structure.thumbnail)
				icon.texture = load(structure.thumbnail)
			else:
				print("Thumbnail path invalid: " + structure.thumbnail)
				# Fall back to getting thumbnail from model
				var model_thumbnail = get_structure_thumbnail(structure)
				if model_thumbnail:
					icon.texture = model_thumbnail
		else:
			# Fall back to getting thumbnail from model
			var model_thumbnail = get_structure_thumbnail(structure)
			if model_thumbnail:
				icon.texture = model_thumbnail
				
		# Apply type-based colors for empty thumbnails
		if not icon.texture:
			if structure.type == Structure.StructureType.ROAD:
				# Use a road icon (fallback)
				icon.modulate = Color(0.7, 0.7, 0.7)
			elif structure.type == Structure.StructureType.RESIDENTIAL_BUILDING:
				# Use building color (fallback)
				icon.modulate = Color(0.2, 0.6, 0.9)
			elif structure.type == Structure.StructureType.POWER_PLANT:
				# Use power plant color (fallback)
				icon.modulate = Color(0.8, 0.3, 0.3)
		
		row.add_child(icon)
		
		# Info container for name and description
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		
		# Structure name - use title field if available
		var name_label = Label.new()
		if "title" in structure and structure.title:
			name_label.text = structure.title
		else:
			name_label.text = get_structure_name(structure)
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
		info.add_child(name_label)
		
		# Structure description
		var desc = Label.new()
		if "description" in structure and structure.description and structure.description != "Description":
			desc.text = structure.description
		else:
			desc.text = "A new structure for your city!"
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.add_child(desc)
		
		# Add separator if not the last item
		if structure != unlocked_structures[-1]:
			var sep = HSeparator.new()
			items_container.add_child(sep)

func show_panel():
	print("show_panel() called")
	visible = true
	# Ensure the game is paused when showing this panel
	# This prevents learning panels from appearing on top of this one
	get_tree().paused = true
	
	# Set higher z-index to ensure it's on top
	z_index = 100
	
	# Notify mission manager if available
	var mission_manager = get_node_or_null("/root/MissionManager")
	if mission_manager and mission_manager.has_method("_on_unlocked_panel_shown"):
		mission_manager._on_unlocked_panel_shown()

func hide_panel():
	print("hide_panel() called")
	visible = false
	
	# We'll let the mission manager handle unpausing in its closed signal handler
	# This ensures proper handling of the mission queue
	# get_tree().paused = false

func _on_close_button_pressed():
	print("Close button pressed!")
	hide_panel()
	closed.emit()
	get_viewport().set_input_as_handled()
	
# New function to show all unlocked structures
func show_all_unlocked_structures():
	if not builder:
		builder = get_node_or_null("/root/Main/Builder")
		if not builder:
			push_error("Cannot find Builder node to get structures")
			return
	
	# Create an array to hold all unlocked structures
	var all_unlocked = []
	
	# Get all unlocked structures from the builder
	var structures = builder.get_structures()
	if not structures:
		print("ERROR: No structures available")
		return
		
	for structure in structures:
		if "unlocked" in structure and structure.unlocked:
			all_unlocked.append(structure)
			
	print("Found " + str(all_unlocked.size()) + " unlocked structures")
	
	# Call the regular setup function with all unlocked structures
	setup(all_unlocked)
	show_panel()

# Try to get a thumbnail for the structure
func get_structure_thumbnail(structure):
	var structure_path = structure.model.resource_path
	
	# Check if we can find a colormap texture for this model
	var colormap_path = structure_path.get_basename() + "_colormap.png"
	if ResourceLoader.exists(colormap_path):
		return load(colormap_path)
	
	# Default case - no icon found
	return null

func get_structure_name(structure):
	var file_name = structure.model.resource_path.get_file().get_basename()
	var names = file_name.split("-")
	var title = ""
	
	for part in names:
		if part.length() > 0:
			title += part[0].to_upper() + part.substr(1) + " "
			
	return title.strip_edges()
