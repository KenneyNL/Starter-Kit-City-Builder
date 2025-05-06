extends PanelContainer
class_name LearningPanelMain

signal completed
signal panel_opened
signal panel_closed

# Scene nodes
var title_label
var description_label
var graph_container
var question_label
var answer_field
var check_button
var complete_button
var feedback_label

var mission: MissionData
var correct_answer: String = "A"
var is_answer_correct: bool = false

func _ready():
	print("Learning panel (Main) _ready() called")
	# Hide panel initially
	visible = false
	
	# Wait for the scene to be ready
	await get_tree().process_frame
	
	# Initialize node references using direct paths
	title_label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
	description_label = get_node_or_null("MarginContainer/VBoxContainer/DescriptionPanel/MarginContainer/DescriptionLabel")
	graph_container = get_node_or_null("MarginContainer/VBoxContainer/GraphContainer")
	question_label = get_node_or_null("MarginContainer/VBoxContainer/AnswerContainer/QuestionLabel")
	answer_field = get_node_or_null("MarginContainer/VBoxContainer/AnswerContainer/AnswerField")
	check_button = get_node_or_null("MarginContainer/VBoxContainer/AnswerContainer/CheckButton")
	complete_button = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/CompleteButton")
	feedback_label = get_node_or_null("MarginContainer/VBoxContainer/AnswerContainer/FeedbackLabel")
	
	# Print out which nodes were found and which weren't
	print("Learning Panel Nodes Found: ")
	print("- title_label: ", title_label != null)
	print("- description_label: ", description_label != null)
	print("- graph_container: ", graph_container != null)
	print("- question_label: ", question_label != null)
	print("- answer_field: ", answer_field != null)
	print("- check_button: ", check_button != null)
	print("- complete_button: ", complete_button != null)
	print("- feedback_label: ", feedback_label != null)
	
	# Connect button signals
	if check_button:
		if not check_button.pressed.is_connected(_on_check_button_pressed):
			check_button.pressed.connect(_on_check_button_pressed)
	
	if answer_field:
		if not answer_field.text_submitted.is_connected(_on_answer_field_text_submitted):
			answer_field.text_submitted.connect(_on_answer_field_text_submitted)
	
	if complete_button:
		if not complete_button.pressed.is_connected(_on_complete_button_pressed):
			complete_button.pressed.connect(_on_complete_button_pressed)

func show_learning_panel(mission_data: MissionData):
	# Check if the mission data is valid
	if mission_data == null:
		push_error("Invalid mission data provided to learning panel")
		return
	
	mission = mission_data
	
	print("Learning panel show_learning_panel called for mission: ", mission.id)
	
	# Set mission title
	if title_label:
		title_label.text = mission.title
	
	# Use a unified setup function that works for any mission type
	_setup_mission_content()
	
	# Reset answer state
	is_answer_correct = false
	if answer_field:
		answer_field.text = ""
	
	if feedback_label:
		feedback_label.visible = false
	
	if complete_button:
		complete_button.disabled = true
		complete_button.text = "Complete"
	
	# Make panel visible
	visible = true
	
	# Emit signal to lock building controls
	panel_opened.emit()
	
	print("Panel is now visible = ", visible)

# Generic function that sets up mission content based on the data available in the mission resource
func _setup_mission_content():
	# Make sure mission is valid
	if mission == null:
		push_error("Mission is null in _setup_mission_content")
		return
	
	# Set description text
	if description_label:
		if not mission.description.is_empty():
			description_label.text = mission.description
		else:
			description_label.text = "No mission description available. Please add a description to the mission data."
	
	# Update question text
	if question_label:
		if not mission.question_text.is_empty():
			question_label.text = mission.question_text
		else:
			question_label.text = "This mission has no question. Please add question_text to the mission data."

	# Set input placeholder
	if answer_field:
		answer_field.placeholder_text = "Enter your answer here"

	# Set the correct answer
	if not mission.correct_answer.is_empty():
		correct_answer = mission.correct_answer
	else:
		# Default to an unlikely answer if none provided
		correct_answer = "NO_ANSWER_PROVIDED"
		push_error("No correct_answer provided in mission data for mission: " + mission.id)
		
	# Clear the graph container and set up appropriate content
	if graph_container:
		# Clear existing content
		for child in graph_container.get_children():
			child.queue_free()
		
		# Decide what content to display based on available mission data
		if mission.power_math_content != "":
			_setup_math_content()
		elif mission.company_data != "" or mission.graph_path != "":
			_setup_company_data()
		else:
			# If no specific content, display a generic container
			var label = Label.new()
			label.text = "No content data available for this mission. Add power_math_content, company_data, or graph_path to the mission."
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			graph_container.add_child(label)

# Helper function to set up math content
func _setup_math_content():
	if not graph_container:
		return
		
	# Create rich text label for math content
	var math_label = RichTextLabel.new()
	math_label.bbcode_enabled = true
	math_label.fit_content = true
	math_label.custom_minimum_size = Vector2(800, 250)
	math_label.size_flags_horizontal = Control.SIZE_FILL
	math_label.size_flags_vertical = Control.SIZE_FILL
	
	if not mission.power_math_content.is_empty():
		math_label.text = mission.power_math_content
	else:
		math_label.text = "[center][color=#e06666][font_size=18]No math content available in mission data.[/font_size][/color][/center]"
	
	graph_container.add_child(math_label)

# Helper function to set up company data
func _setup_company_data():
	if not graph_container:
		return
	
	# Create a center container
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_FILL
	center.size_flags_vertical = Control.SIZE_FILL
	graph_container.add_child(center)
	
	# Create VBox for the data
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(800, 250)
	center.add_child(vbox)
	
	# Try to load the graph image from mission data or fallback
	var graph_path = mission.graph_path
	if graph_path.is_empty():
		graph_path = "res://images/mission_2.png"
		
	var graph_texture = load(graph_path)
	if graph_texture:
		var img = TextureRect.new()
		img.texture = graph_texture
		img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(800, 160)
		vbox.add_child(img)
	
	# Create company data label
	var data_label = RichTextLabel.new()
	data_label.bbcode_enabled = true
	data_label.fit_content = true
	data_label.custom_minimum_size = Vector2(800, 90)
	
	if not mission.company_data.is_empty():
		data_label.text = mission.company_data
	else:
		data_label.text = "[center][color=#e06666][font_size=18]No company data available in mission data.[/font_size][/color][/center]"
	
	vbox.add_child(data_label)

func hide_learning_panel():
	visible = false
	
	# Emit signal to unlock building controls
	panel_closed.emit()

func _on_answer_field_text_submitted(submitted_text):
	_check_answer()

func _on_check_button_pressed():
	_check_answer()

func _check_answer():
	if not answer_field:
		push_error("Cannot check answer: answer_field is null")
		return
	
	var user_answer = answer_field.text.strip_edges().to_upper()
	
	if feedback_label:
		feedback_label.visible = true
	
	if user_answer == correct_answer:
		is_answer_correct = true
		
		if feedback_label:
			# Use feedback text from mission data, or a generic message
			if not mission.feedback_text.is_empty():
				feedback_label.text = mission.feedback_text
			else:
				feedback_label.text = "Correct! Great job solving this problem."
			
			feedback_label.add_theme_color_override("font_color", Color(0, 0.7, 0.2))
		
		# Enable complete button
		if complete_button:
			complete_button.disabled = false
	else:
		if feedback_label:
			# Use incorrect feedback text from mission data, or a generic message
			if not mission.incorrect_feedback.is_empty():
				feedback_label.text = mission.incorrect_feedback
			else:
				feedback_label.text = "Not quite right. Please try again."
			
			feedback_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

func _on_complete_button_pressed():
	if is_answer_correct:
		# Complete the learning objective
		for objective in mission.objectives:
			if objective.type == MissionObjective.ObjectiveType.LEARNING:
				objective.progress(objective.target_count)
		
		# Hide the panel
		hide_learning_panel()
		
		# Emit signal
		completed.emit()
