extends Control
class_name MissionUI

@export var mission_title_label: Label
@export var mission_description_label: Label
@export var objectives_container: VBoxContainer

# Variable for temporary message display
var temp_message_label: Label
var temp_message_timer: Timer

# Use a Label node directly instead of a scene
# This assumes the ObjectiveLabel node is set up correctly and can be duplicated

func update_mission_display(mission: MissionData):
	if not mission:
		visible = false
		return
	
	visible = true
	mission_title_label.text = mission.title
	mission_description_label.text = mission.description
	
	# Make sure panel sizes itself to fit content
	await get_tree().process_frame
	custom_minimum_size.y = 0  # Let it resize naturally
	
	# Clear previous objectives
	for child in objectives_container.get_children():
		child.queue_free()
	
	# Add new objectives
	for objective in mission.objectives:
		# Duplicate the ObjectiveLabel from the scene
		var label = $"../ObjectiveLabel".duplicate()
		objectives_container.add_child(label)
		
		# Make font size larger and ensure text wrapping
		label.add_theme_font_size_override("font_size", 16)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Format the objective text
		var status = "✓" if objective.completed else "□"  # Changed to checkbox style
		var progress = ""
		
		if objective.target_count > 1:
			progress = " (%d/%d)" % [objective.current_count, objective.target_count]
		
		label.text = "%s %s%s" % [status, objective.description, progress]
		
		# Style completed objectives differently
		if objective.completed:
			label.add_theme_color_override("font_color", Color(0, 0.8, 0.2, 1))  # Brighter green

# Method to show a temporary message on the screen
func show_temporary_message(message: String, duration: float = 2.0, color: Color = Color.WHITE):
	# Create or get the temporary message label
	if not temp_message_label:
		temp_message_label = Label.new()
		temp_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		temp_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		temp_message_label.add_theme_font_size_override("font_size", 24)
		temp_message_label.set_anchors_preset(Control.PRESET_CENTER)
		
		# Add it to the top of our UI
		add_child(temp_message_label)
		
		# Create a timer for automatic hiding
		temp_message_timer = Timer.new()
		temp_message_timer.one_shot = true
		temp_message_timer.timeout.connect(_on_temp_message_timer_timeout)
		add_child(temp_message_timer)
	
	# Set message properties
	temp_message_label.text = message
	temp_message_label.add_theme_color_override("font_color", color)
	
	# Position the message at the top center of the screen
	var viewport_size = get_viewport_rect().size
	temp_message_label.position = Vector2(viewport_size.x / 2 - temp_message_label.size.x / 2, 50)
	
	# Show the message
	temp_message_label.visible = true
	
	# Start the timer
	temp_message_timer.start(duration)

# Timer timeout handler
func _on_temp_message_timer_timeout():
	if temp_message_label:
		temp_message_label.visible = false
