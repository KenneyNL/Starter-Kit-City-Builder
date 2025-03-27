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
	mission = mission_data
	
	print("Learning panel show_learning_panel called for mission: ", mission.id)
	
	# Set mission title
	if title_label:
		title_label.text = mission.title
	
	# Set custom content based on mission ID
	if mission.id == "4":
		# Mission 4: Power Plant Mission
		if description_label:
			description_label.text = "Your growing city needs electricity! The city's power demand follows a pattern based on the number of houses.\n\nYou need to solve exponential and radical expressions to determine how many power plants to build and where to place them for optimal energy distribution."
		
		# Add power math content to the graph container
		_setup_power_plant_math()
		
		# Update question
		if question_label:
			question_label.text = "How many power plants do you need to power 40 houses?"
		
		# Update input placeholder
		if answer_field:
			answer_field.placeholder_text = "Enter number"
		
		# Set the correct answer
		correct_answer = "1"
		
	else:
		# Mission 2: Construction Companies
		if description_label:
			description_label.text = "Your city is rapidly growing, and you need to build houses to accommodate new residents! Two different construction companies offer to help:\n\nStudy their data, find the unit rates, write equations, and determine which company would require fewer workers to build 40 houses in a week."
		
		# Add construction company data
		_setup_construction_companies()
		
		# Update question
		if question_label:
			question_label.text = "Which company requires fewer workers to build 40 houses in a week? (A or B)"
		
		# Update input placeholder
		if answer_field:
			answer_field.placeholder_text = "Enter A or B"
		
		# Set the correct answer
		correct_answer = "A"
	
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

func _setup_power_plant_math():
	if graph_container:
		# Clear any existing children
		for child in graph_container.get_children():
			child.queue_free()
		
		# Create rich text label for power plant math
		var math_label = RichTextLabel.new()
		math_label.bbcode_enabled = true
		math_label.fit_content = true
		math_label.custom_minimum_size = Vector2(800, 250)
		math_label.size_flags_horizontal = Control.SIZE_FILL
		math_label.size_flags_vertical = Control.SIZE_FILL
		
		math_label.text = """[center][color=#60c2a8][font_size=22]POWERING YOUR CITY WITH MATH[/font_size][/color]

[font_size=16]Your city has grown to 40 houses and now needs electricity!
We'll use radicals and exponents to determine the power needs.

[color=#60c2a8]UNDERSTANDING THE POWER FORMULA:[/color]
Power needed (kilowatts) = 2 × √n + n⁰·⁸
where n is the number of houses in your city.

[color=#60c2a8]CALCULATING THE POWER DEMAND:[/color]
Step 1: Calculate the square root part.
2 × √40 = 2 × 6.32 = 12.64 kilowatts

Step 2: Calculate the exponent part.
To find 40⁰·⁸:
40⁰·⁸ = (2⁵·³²)⁰·⁸ = 2⁵·³²ˣ⁰·⁸ = 2⁴·²⁶ ≈ 19.14 kilowatts

Step 3: Find the total power needed.
Total power needed = 12.64 + 19.14 = 31.78 kilowatts

[color=#60c2a8]POWER PLANT INFORMATION:[/color]
• Each power plant generates 40 kilowatts of electricity
• A power plant can distribute electricity within a radius of:
  Radius = 5 × √P = 5 × √40 = 5 × 6.32 ≈ 31.6 grid units[/font_size][/center]
"""
		
		graph_container.add_child(math_label)

func _setup_construction_companies():
	if graph_container:
		# Clear any existing children
		for child in graph_container.get_children():
			child.queue_free()
		
		# Create a center container
		var center = CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_FILL
		center.size_flags_vertical = Control.SIZE_FILL
		graph_container.add_child(center)
		
		# Create VBox for the data
		var vbox = VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(800, 250)
		center.add_child(vbox)
		
		# Try to load the graph image
		var graph_texture = load("res://images/mission_2.png")
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
		
		data_label.text = """[center][font_size=16][b][color=#60c2a8]Company A: City Builders Inc.[/color][/b]
• 2 workers build 8 houses per week
• 4 workers build 16 houses per week
• 6 workers build 24 houses per week
• 10 workers build 40 houses per week

[b][color=#e06666]Company B: Urban Growth Solutions[/color][/b]
• 3 workers build 9 houses per week
• 6 workers build 18 houses per week
• 9 workers build 27 houses per week
• 12 workers build 36 houses per week[/font_size][/center]
"""
		
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
			if mission.id == "4":
				feedback_label.text = "Correct! With a power demand of 31.78 kilowatts and each power plant generating 40 kilowatts, 1 power plant is sufficient to power your city. You can now place a power plant within 31.6 grid units of your houses to ensure everyone has electricity!"
			else:
				feedback_label.text = "Correct! Company A (City Builders Inc.) would require fewer workers to build 40 houses. Company A builds at a rate of 4 houses per worker per week, while Company B builds at a rate of 3 houses per worker per week. For 40 houses, Company A needs 10 workers while Company B needs about 13.33 workers."
			
			feedback_label.add_theme_color_override("font_color", Color(0, 0.7, 0.2))
		
		# Enable complete button
		if complete_button:
			complete_button.disabled = false
	else:
		if feedback_label:
			if mission.id == "4":
				feedback_label.text = "Not quite right. Calculate the power demand using the formula: Power needed = 2 × √n + n⁰·⁸, where n = 40 houses. Then compare this to the output of one power plant (40 kilowatts)."
			else:
				feedback_label.text = "Not quite right. Look carefully at the data for both companies. Compare their rates: Company A builds 4 houses per worker per week, while Company B builds 3 houses per worker per week. Calculate how many workers each would need for 40 houses."
			
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