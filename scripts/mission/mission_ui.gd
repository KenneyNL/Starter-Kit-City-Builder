extends Control
class_name MissionUI

@export var mission_title_label: Label
@export var mission_description_label: Label
@export var objectives_container: VBoxContainer

# Use a Label node directly instead of a scene
# This assumes the ObjectiveLabel node is set up correctly and can be duplicated

func update_mission_display(mission: MissionData):
	if not mission:
		visible = false
		return
	
	visible = true
	mission_title_label.text = mission.title
	mission_description_label.text = mission.description
	
	# Clear previous objectives
	for child in objectives_container.get_children():
		child.queue_free()
	
	# Add new objectives
	for objective in mission.objectives:
		# Duplicate the ObjectiveLabel from the scene
		var label = $"../ObjectiveLabel".duplicate()
		objectives_container.add_child(label)
		
		# Format the objective text
		var status = "✓" if objective.completed else " "
		var progress = ""
		
		if objective.target_count > 1:
			progress = " (%d/%d)" % [objective.current_count, objective.target_count]
		
		label.text = "[%s] %s%s" % [status, objective.description, progress]
		
		# Style completed objectives differently
		if objective.completed:
			label.add_theme_color_override("font_color", Color(0, 0.7, 0, 1))  # Green
