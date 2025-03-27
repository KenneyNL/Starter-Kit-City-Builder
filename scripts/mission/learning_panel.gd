extends Control

signal completed
signal panel_opened
signal panel_closed

# Scene nodes - these might be null if scene structure doesn't match
var mission_title_label
var intro_text
var description_text
var graph_image
var user_input
var submit_button

var mission: MissionData
var correct_answer: String = "A"
var is_answer_correct: bool = false

func _ready():
	print("LearningPanel _ready() called")
	# Hide panel initially
	visible = false
	
	# Wait for the scene to be ready
	await get_tree().process_frame
	
	# Make sure we're on the right layer
	z_index = 100
	
	# Initialize node references using direct paths
	mission_title_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/TitleContainer/MissionTitleLabel")
	intro_text = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/IntroText")
	description_text = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/DescriptionText")
	graph_image = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer/GraphImage")
	user_input = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer/UserInput")
	submit_button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/SubmitButtonContainer/SubmitButton")
	
	print("Initialized learning panel with path: ", get_path())
	
	# Connect button signals if the button exists
	if submit_button != null:
		if not submit_button.is_connected("pressed", Callable(self, "_on_submit_button_pressed")):
			submit_button.pressed.connect(_on_submit_button_pressed)
	else:
		push_error("Submit button not found in learning panel")
	
func show_learning_panel(mission_data: MissionData):
	mission = mission_data
	
	print("Learning panel show_learning_panel called for mission: ", mission.id)
	
	# First, reset the panel to a clean state
	_reset_panel()
	
	# Set the mission title from the resource
	if mission_title_label:
		mission_title_label.text = mission.title.to_upper()
		print("Set mission title to: ", mission_title_label.text)
	
	# Based on mission ID, set up the appropriate content
	if mission.id == "4":
		_setup_power_plant_mission()
	else:
		_setup_construction_mission()
	
	# Set up common elements
	_setup_common_elements()
	
	# Make panel visible and bring to front
	visible = true
	
	# Make sure we're on top 
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)
		
	# Make sure we're at the proper z-index
	z_index = 100
	
	# Emit signal to lock building controls
	panel_opened.emit()
	
	print("Panel is now visible = ", visible)

# Reset the panel to a clean state
func _reset_panel():
	# Reset answer state
	is_answer_correct = false
	
	# Clear text inputs
	if user_input:
		user_input.text = ""
	
	# Hide feedback label
	var feedback_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer/FeedbackLabel")
	if feedback_label:
		feedback_label.visible = false
	
	# Reset submit button
	if submit_button:
		submit_button.text = "SUBMIT"
		
		# Disconnect complete mission signal if connected
		if submit_button.is_connected("pressed", Callable(self, "_on_complete_mission")):
			submit_button.pressed.disconnect(_on_complete_mission)
		
		# Connect submit button signal
		if not submit_button.is_connected("pressed", Callable(self, "_on_submit_button_pressed")):
			submit_button.pressed.connect(_on_submit_button_pressed)

# Set up the power plant mission content
func _setup_power_plant_mission():
	# Set the text content from the mission resource
	if intro_text:
		intro_text.text = "Your growing city needs electricity! The city's power demand follows a pattern based on the number of houses."
	
	if description_text:
		description_text.text = "You need to solve exponential and radical expressions to determine how many power plants to build and where to place them for optimal energy distribution."
	
	# Set the correct answer
	correct_answer = "1"
	
	# Update input placeholder
	if user_input:
		user_input.placeholder_text = "Enter number of power plants needed"
	
	# Hide company data
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	if company_data_container:
		company_data_container.visible = false
	
	# Add power math content
	_add_power_math_content()

# Set up the construction companies mission content
func _setup_construction_mission():
	# Set the text content from the mission resource
	if intro_text:
		intro_text.text = "Your city is rapidly growing, and you need to build houses to accommodate new residents! Two different construction companies offer to help."
	
	if description_text:
		description_text.text = "Study the company data below, find the unit rates (houses per worker), and determine which company would require fewer workers to build 40 houses in a week."
	
	# Set the correct answer
	correct_answer = "A"
	
	# Update input placeholder
	if user_input:
		user_input.placeholder_text = "Enter A or B"
	
	# Hide any power math content
	var power_math_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer/PowerMathLabel")
	if power_math_label:
		power_math_label.visible = false
		power_math_label.queue_free()
	
	# Show and set up company data
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	if company_data_container:
		company_data_container.visible = true
		
		var company_data_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer/CompanyDataLabel")
		if company_data_label:
			company_data_label.text = """[center][b][color=#60c2a8]Company A: City Builders Inc.[/color][/b]
• 2 workers build 8 houses per week
• 4 workers build 16 houses per week
• 6 workers build 24 houses per week
• 10 workers build 40 houses per week

[b][color=#e06666]Company B: Urban Growth Solutions[/color][/b]
• 3 workers build 9 houses per week
• 6 workers build 18 houses per week
• 9 workers build 27 houses per week
• 12 workers build 36 houses per week[/center]"""

# Add power math content to the panel
func _add_power_math_content():
	var graph_center_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer")
	
	# Remove any existing power math label
	var existing_power_math = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer/PowerMathLabel")
	if existing_power_math:
		existing_power_math.queue_free()
	
	# Create new power math label
	if graph_center_container:
		var power_math_label = RichTextLabel.new()
		power_math_label.name = "PowerMathLabel"
		power_math_label.custom_minimum_size = Vector2(1200, 600)
		power_math_label.bbcode_enabled = true
		power_math_label.fit_content = true
		graph_center_container.add_child(power_math_label)
		
		power_math_label.text = """[center][color=#60c2a8][font_size=42]POWERING YOUR CITY WITH MATH[/font_size][/color]

[font_size=32]Your city has grown to 40 houses and now needs electricity!
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
		power_math_label.visible = true

# Set up common elements for all mission types
func _setup_common_elements():
	# Get or create feedback label
	var feedback_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer/FeedbackLabel")
	var user_input_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer")
	
	if not feedback_label and user_input_container:
		feedback_label = Label.new()
		feedback_label.name = "FeedbackLabel"
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feedback_label.custom_minimum_size = Vector2(800, 120)
		feedback_label.add_theme_font_size_override("font_size", 32)
		feedback_label.visible = false
		user_input_container.add_child(feedback_label)
	
	# Handle graph display based on mission's graph_path property
	if graph_image:
		if mission.graph_path.is_empty():
			graph_image.visible = false
		else:
			# Show graph and load texture from path if it exists
			var graph_texture = load(mission.graph_path)
			if graph_texture:
				graph_image.texture = graph_texture
				graph_image.visible = true
			else:
				graph_image.visible = false

func hide_learning_panel():
	visible = false
	
	# Emit signal to unlock building controls
	panel_closed.emit()

func _on_user_input_text_submitted(submitted_text):
	_check_answer()

func _on_submit_button_pressed():
	_check_answer()

func _check_answer():
	# Make sure we have a user input field
	if not user_input:
		push_error("Cannot check answer: user_input is null")
		return
		
	var user_answer = user_input.text.strip_edges().to_upper()  # Convert to uppercase for case-insensitive comparison
	
	# Get or create feedback label
	var feedback_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer/FeedbackLabel")
	var user_input_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer")
	
	if not feedback_label and user_input_container:
		feedback_label = Label.new()
		feedback_label.name = "FeedbackLabel"
		feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feedback_label.custom_minimum_size = Vector2(800, 120)
		feedback_label.add_theme_font_size_override("font_size", 32)
		user_input_container.add_child(feedback_label)
	
	# Skip if feedback label couldn't be created
	if not feedback_label:
		push_error("Cannot create feedback label")
		return
		
	# Make feedback visible
	feedback_label.visible = true
	
	if user_answer == correct_answer:
		is_answer_correct = true
		
		if mission.id == "4":
			feedback_label.text = "Correct! With a power demand of 31.78 kilowatts and each power plant generating 40 kilowatts, 1 power plant is sufficient to power your city. You can now place a power plant within 31.6 grid units of your houses to ensure everyone has electricity!"
		else:
			feedback_label.text = "Correct! Company A (City Builders Inc.) would require fewer workers to build 40 houses. Company A builds at a rate of 4 houses per worker per week, while Company B builds at a rate of 3 houses per worker per week. For 40 houses, Company A needs 10 workers while Company B needs about 13.33 workers."
		
		feedback_label.add_theme_color_override("font_color", Color(0, 0.7, 0.2))
		
		# Change submit button to "Complete" button if it exists
		if submit_button:
			submit_button.text = "COMPLETE"
			
			# Safely disconnect and reconnect signals using Godot 4 syntax
			if submit_button.is_connected("pressed", Callable(self, "_on_submit_button_pressed")):
				submit_button.pressed.disconnect(_on_submit_button_pressed)
			
			if not submit_button.is_connected("pressed", Callable(self, "_on_complete_mission")):
				submit_button.pressed.connect(_on_complete_mission)
	else:
		if mission.id == "4":
			feedback_label.text = "Not quite right. Calculate the power demand using the formula: Power needed = 2 × √n + n⁰·⁸, where n = 40 houses. Then compare this to the output of one power plant (40 kilowatts)."
		else:
			feedback_label.text = "Not quite right. Look carefully at the data for both companies. Compare their rates: Company A builds 4 houses per worker per week, while Company B builds 3 houses per worker per week. Calculate how many workers each would need for 40 houses."
		
		feedback_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

func _on_complete_mission():
	if is_answer_correct:
		# Complete the learning objective
		for objective in mission.objectives:
			if objective.type == MissionObjective.ObjectiveType.LEARNING:
				objective.progress(objective.target_count)
		
		# Hide the panel
		hide_learning_panel()
		
		# Emit signal
		completed.emit()
