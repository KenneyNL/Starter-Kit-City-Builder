extends Control

signal completed
signal panel_opened
signal panel_closed

# Store variables for signal connections
var user_input  # For single input (backward compatibility)
var user_inputs = []  # Array for multiple inputs
var input_labels = []  # Array for input labels
var submit_button

var mission: MissionData
var correct_answer: String = "A"
var is_answer_correct: bool = false

func _ready():
	# Hide panel initially
	visible = false
	
	# Wait for the scene to be ready
	await get_tree().process_frame
	
	# Make sure we're on the right layer
	z_index = 100
	
	# Only get references needed for signal connections
	user_input = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/UserInputContainer/UserInput")
	submit_button = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/SubmitButtonContainer/SubmitButton")
	
	# Clear the user inputs array
	user_inputs = []
	input_labels = []
	
	# Connect button signals if the button exists
	if submit_button != null:
		if not submit_button.is_connected("pressed", Callable(self, "_on_submit_button_pressed")):
			submit_button.pressed.connect(_on_submit_button_pressed)
	else:
		push_error("Submit button not found in learning panel")
	
func show_learning_panel(mission_data: MissionData):
	# Check if the mission data is valid
	if mission_data == null:
		push_error("Invalid mission data provided to learning panel")
		return
	
	mission = mission_data
	
	# First, reset the panel to a clean state
	_reset_panel()
	
	# Use traditional text and graph mode
	_setup_traditional_mode()
	
	# Set up the correct answer from mission data
	if not mission.correct_answer.is_empty():
		correct_answer = mission.correct_answer
	else:
		# Default answer based on mission type
		correct_answer = "1" if not mission.power_math_content.is_empty() else "A"
	
	# Set up user input fields based on mission data
	if mission.num_of_user_inputs > 1:
		_setup_multiple_user_inputs()
	else:
		# Traditional single input
		if user_input:
			user_input.placeholder_text = mission.question_text if not mission.question_text.is_empty() else "Enter your answer"
	
	# Hide the HUD when learning panel is shown
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	if hud:
		hud.visible = false
	
	# Make the panel visible
	visible = true
	
	# Make sure we're on top
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	
	# Make sure we're at the proper z-index
	z_index = 100
	
	# Disable background interaction by creating a fullscreen invisible barrier
	_disable_background_interaction()
	
	# Emit signal to lock building controls
	panel_opened.emit()
	
	print("Panel is now visible = ", visible)
	
# Creates an invisible fullscreen barrier to block clicks on the background
func _disable_background_interaction():
	# Remove any existing barrier
	var existing_barrier = get_node_or_null("BackgroundBarrier")
	if existing_barrier:
		existing_barrier.queue_free()
		
	# Create a new barrier
	var barrier = ColorRect.new()
	barrier.name = "BackgroundBarrier"
	barrier.color = Color(0, 0, 0, 0.01) # Almost transparent
	barrier.anchor_right = 1.0
	barrier.anchor_bottom = 1.0
	barrier.mouse_filter = Control.MOUSE_FILTER_STOP # Block mouse events
	barrier.z_index = -1 # Behind the panel UI
	
	# Add it as the first child of the panel
	add_child(barrier)
	move_child(barrier, 0)
	
	print("Background interaction disabled")

# Function to create multiple user input fields
func _setup_multiple_user_inputs():
	# Clear any existing user inputs
	user_inputs = []
	input_labels = []
	
	# Get the container where inputs should be added
	var user_input_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/UserInputContainer")
	if not user_input_container:
		push_error("User input container not found")
		return
	
	# If there's an existing single input, hide it
	if user_input and user_input.get_parent() == user_input_container:
		user_input.visible = false
	
	# Create a centering container for better alignment
	var center_container = CenterContainer.new()
	center_container.name = "InputCenterContainer"
	center_container.size_flags_horizontal = Control.SIZE_FILL
	user_input_container.add_child(center_container)
	
	# Add margin around the grid
	var margin_container = MarginContainer.new()
	margin_container.name = "InputMarginContainer"
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	center_container.add_child(margin_container)
	
	# Create a grid container for inputs
	var grid = GridContainer.new()
	grid.name = "MultiInputGrid"
	grid.columns = 2  # Label and input in each row
	grid.size_flags_horizontal = Control.SIZE_FILL
	grid.add_theme_constant_override("h_separation", 15)  # Add horizontal spacing between columns
	grid.add_theme_constant_override("v_separation", 10)  # Add vertical spacing between rows
	margin_container.add_child(grid)
	
	# Create each input field
	for i in range(mission.num_of_user_inputs):
		# Create label
		var label = Label.new()
		label.name = "InputLabel" + str(i)
		label.text = mission.input_labels[i] if i < mission.input_labels.size() else "Input " + str(i+1) + ":"
		label.size_flags_horizontal = Control.SIZE_EXPAND
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT  # Right-align text
		
		# Set larger font size
		var font_size = 26
		label.add_theme_font_size_override("font_size", font_size)
		
		# Add right margin for better spacing
		var style = StyleBoxEmpty.new()
		style.content_margin_right = 10  # Add 10 pixels of right margin
		label.add_theme_stylebox_override("normal", style)
		
		grid.add_child(label)
		input_labels.append(label)
		
		# Create input field
		var input_field = LineEdit.new()
		input_field.name = "UserInput" + str(i)
		input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input_field.placeholder_text = "Enter value"
		input_field.custom_minimum_size.x = 150  # Increase minimum width
		input_field.custom_minimum_size.y = 40   # Set height for the input field
		
		# Style the input field
		input_field.alignment = HORIZONTAL_ALIGNMENT_LEFT  # Left-align text inside the field
		input_field.add_theme_font_size_override("font_size", 26)  # Match label font size
		
		# Connect text submitted signal
		input_field.text_submitted.connect(_on_user_input_text_submitted)
		
		grid.add_child(input_field)
		user_inputs.append(input_field)
	
	# Add spacing after the grid
	var spacer = Control.new()
	spacer.name = "InputSpacer"
	spacer.custom_minimum_size.y = 20
	user_input_container.add_child(spacer)
	
	# Add a hint button below the inputs
	var hint_button_container = HBoxContainer.new()
	hint_button_container.name = "HintButtonContainer"
	hint_button_container.size_flags_horizontal = Control.SIZE_FILL
	hint_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	user_input_container.add_child(hint_button_container)
	
	var hint_button = Button.new()
	hint_button.name = "HintButton"
	hint_button.text = "Need a Hint?"
	hint_button.custom_minimum_size = Vector2(200, 40)
	
	# Style the hint button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(0.376, 0.760, 0.658, 0.5)  # Teal border
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_right = 5
	button_style.corner_radius_bottom_left = 5
	
	hint_button.add_theme_stylebox_override("normal", button_style)
	hint_button.add_theme_font_size_override("font_size", 20)
	hint_button.pressed.connect(_on_hint_button_pressed)
	
	hint_button_container.add_child(hint_button)

# Reset the panel to a clean state
func _reset_panel():
	# Reset answer state
	is_answer_correct = false
	
	# Clear single input if it exists
	if user_input:
		user_input.text = ""
	
	# Clear multiple inputs if they exist
	for input in user_inputs:
		if input:
			input.text = ""
	
	# Hide feedback label
	var feedback_label = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/UserInputContainer/FeedbackLabel")
	if feedback_label:
		feedback_label.visible = false
	
	# Clean up any added UI elements
	var user_input_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/UserInputContainer")
	if user_input_container:
		# Clean up the input center container and all its children
		var input_center_container = user_input_container.get_node_or_null("InputCenterContainer")
		if input_center_container:
			input_center_container.queue_free()
			
		# Clean up input spacer if it exists
		var input_spacer = user_input_container.get_node_or_null("InputSpacer")
		if input_spacer:
			input_spacer.queue_free()
			
		# Clean up any TopMargin that might have been added
		var top_margin = user_input_container.get_node_or_null("TopMargin")
		if top_margin:
			top_margin.queue_free()
			
		# Reset custom sizing
		user_input_container.custom_minimum_size.y = 0
		user_input_container.size_flags_vertical = Control.SIZE_FILL
		
		# Show the default input field if it exists
		if user_input and user_input.get_parent() == user_input_container:
			user_input.visible = true
			
	# Clear the user inputs arrays
	user_inputs = []
	input_labels = []
	
	# Reset submit button
	if submit_button:
		submit_button.text = "SUBMIT"
		
		# Disconnect complete mission signal if connected
		if submit_button.is_connected("pressed", Callable(self, "_on_complete_mission")):
			submit_button.pressed.disconnect(_on_complete_mission)
		
		# Connect submit button signal
		if not submit_button.is_connected("pressed", Callable(self, "_on_submit_button_pressed")):
			submit_button.pressed.connect(_on_submit_button_pressed)

# Sets up the traditional mode with separate title, text, and graph elements
func _setup_traditional_mode():
	# Set the mission title
	var mission_title_label = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/TitleContainer/MissionTitleLabel")
	if mission_title_label:
		mission_title_label.text = mission.title.to_upper()
	else:
		push_error("MissionTitleLabel node not found")
	
	# Set the intro text
	var intro_text = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/IntroText")
	if intro_text:
		intro_text.text = mission.intro_text if not mission.intro_text.is_empty() else "Welcome to this mission!"
	else:
		push_error("IntroText node not found")
	
	# Set the description text
	var description_text = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/DescriptionText") 
	if description_text:
		description_text.text = mission.description
	else:
		push_error("DescriptionText node not found")
		
	# Set up mission-specific content for construction or power mission
	_setup_mission_specific_content()
	
	# Send question_shown dialog to learning companion if available
	if mission.companion_dialog.has("question_shown"):
		var dialog_data = mission.companion_dialog["question_shown"]
		const JSBridge = preload("res://scripts/javascript_bridge.gd")
		if JSBridge.has_interface():
			JSBridge.get_interface().sendCompanionDialog("question_shown", dialog_data)
	
	print("Setup traditional mode complete")

# Set up mission-specific content based on the mission type
func _setup_mission_specific_content():
	# Clear existing content first
	_clear_existing_content()
	
	# Decide which content to show
	if mission.power_math_content.is_empty():
		# This is a construction company mission
		_setup_construction_mission()
	else:
		# This is a power math mission
		_setup_power_math_mission()

# Clear existing content before setting up new content
func _clear_existing_content():
	# Find the main containers
	var graph_center_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer")
	var question_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	
	# Clear power math content from the graph container
	if graph_center_container:
		var power_math_label = graph_center_container.get_node_or_null("PowerMathLabel")
		if power_math_label:
			power_math_label.queue_free()
	
	# Reset the container that will hold our question text (previously used for company data)
	if question_container:
		question_container.visible = false
		var text_label = question_container.get_node_or_null("CompanyDataLabel")
		if text_label:
			text_label.text = ""

# Set up construction company mission content
func _setup_construction_mission():
	print("Setting up construction company mission")
	
	# 1. Show the graph image
	var graph_image = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer/GraphImage")
	if graph_image:
		if mission.graph_path.is_empty():
			graph_image.visible = false
		else:
			# Load and show the graph
			var graph_texture = load(mission.graph_path)
			if graph_texture:
				# Set the texture
				graph_image.texture = graph_texture
				
				# Configure proper scaling based on the image:
				# - Get the image size
				var image_size = graph_texture.get_size()
				print("Image dimensions: " + str(image_size.x) + "x" + str(image_size.y))
				
				# - Determine if we need to adjust scaling based on image dimensions
				var target_width = 1000  # Match the custom_minimum_size from the scene
				var target_height = 500
				
				# - Adjust the expansion mode based on image size relative to target size
				if image_size.x < target_width * 0.5 or image_size.y < target_height * 0.5:
					# Small image - use SCALE expansion mode to make it larger
					graph_image.expand_mode = 1  # SCALE
					graph_image.stretch_mode = 5  # KEEP_ASPECT_CENTERED
					print("Using SCALE expansion for small image")
				else:
					# Larger image - use KEEP_SIZE or KEEP_WIDTH expansion mode
					graph_image.expand_mode = 2  # KEEP_WIDTH
					graph_image.stretch_mode = 5  # KEEP_ASPECT_CENTERED
					print("Using KEEP_WIDTH expansion for larger image")
				
				# Set custom minimum size if needed
				if image_size.x > 800:
					# For larger images, use reasonable dimensions
					graph_image.custom_minimum_size = Vector2(min(1000, max(800, image_size.x)), min(500, max(400, image_size.y)))
				else:
					# For smaller images, scale them up
					graph_image.custom_minimum_size = Vector2(1000, 500)
				
				graph_image.visible = true
				print("Successfully loaded graph image for construction mission: " + mission.graph_path)
			else:
				graph_image.visible = false
				print("Failed to load graph image")
	
	# 2. Set question text instead of company data
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	if company_data_container:
		company_data_container.visible = true
		
		# Get the label where we'll display the question text
		var company_data_label = company_data_container.get_node_or_null("CompanyDataLabel")
		if company_data_label:
			# Create a formatted question text
			var formatted_text = "[center]\n"
			
			# Add the question text in a centered, clear format
			if not mission.question_text.is_empty():
				formatted_text += "[color=#dddddd][font_size=26]" + mission.question_text + "[/font_size][/color]"
			
			formatted_text += "\n[/center]"
			
			# Set the formatted text
			company_data_label.text = formatted_text
			company_data_label.custom_minimum_size.y = 80  # Reduce height for just question text
					

# Set up power math mission content
func _setup_power_math_mission():
	print("Setting up power math mission")
	
	# 1. Check if we have a graph image to display
	var graph_image = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer/GraphImage")
	if graph_image:
		# Only show the graph image if a path is specified in the mission
		if not mission.graph_path.is_empty():
			# Try loading the graph image
			var graph_texture = load(mission.graph_path)
			if graph_texture:
				# Set the texture
				graph_image.texture = graph_texture
				
				# Configure proper scaling based on the image:
				# - Get the image size
				var image_size = graph_texture.get_size()
				print("Image dimensions: " + str(image_size.x) + "x" + str(image_size.y))
				
				# - Determine if we need to adjust scaling based on image dimensions
				var target_width = 1000  # Match the custom_minimum_size from the scene
				var target_height = 500
				
				# - Adjust the expansion mode based on image size relative to target size
				if image_size.x < target_width * 0.5 or image_size.y < target_height * 0.5:
					# Small image - use SCALE expansion mode to make it larger
					graph_image.expand_mode = 1  # SCALE
					graph_image.stretch_mode = 5  # KEEP_ASPECT_CENTERED
					print("Using SCALE expansion for small image")
				else:
					# Larger image - use KEEP_SIZE or KEEP_WIDTH expansion mode
					graph_image.expand_mode = 2  # KEEP_WIDTH
					graph_image.stretch_mode = 5  # KEEP_ASPECT_CENTERED
					print("Using KEEP_WIDTH expansion for larger image")
				
				# Set custom minimum size if needed
				if image_size.x > 800:
					# For larger images, use reasonable dimensions
					graph_image.custom_minimum_size = Vector2(min(1000, max(800, image_size.x)), min(500, max(400, image_size.y)))
				else:
					# For smaller images, scale them up
					graph_image.custom_minimum_size = Vector2(1000, 500)
				
				graph_image.visible = true
				print("Successfully loaded graph image for power mission: " + mission.graph_path)
			else:
				graph_image.visible = false
				print("Failed to load graph image for power mission: " + mission.graph_path)
		else:
			graph_image.visible = false
			print("No graph path specified for power mission")
	
	# 2. Hide company data container
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	if company_data_container:
		company_data_container.visible = false
	
	# 3. Add power math content if we're not showing a graph
	var graph_center_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer")
	if graph_center_container:
		# Only show power math content if we don't have a graph image or if it's not visible
		if mission.graph_path.is_empty() or not graph_image or not graph_image.visible:
			# Create power math label
			var power_math_label = graph_center_container.get_node_or_null("PowerMathLabel")
			if power_math_label:
				power_math_label.queue_free()
				
			# Create new label for the power math content
			power_math_label = RichTextLabel.new()
			power_math_label.name = "PowerMathLabel"
			power_math_label.custom_minimum_size = Vector2(1000, 500)  # Smaller size to match new dimensions
			power_math_label.bbcode_enabled = true
			power_math_label.fit_content = true
			graph_center_container.add_child(power_math_label)
			
			# Set the power math content
			if mission.power_math_content.is_empty():
				power_math_label.text = "No power math content available."
			else:
				power_math_label.text = mission.power_math_content
				
			power_math_label.visible = true
			print("Added power math content as text")

func hide_learning_panel():
	visible = false
	
	# Show the HUD again when learning panel is hidden
	var hud = get_node_or_null("/root/Main/CanvasLayer/HUD")
	if hud:
		hud.visible = true
	
	# Remove the barrier and re-enable background interaction
	var barrier = get_node_or_null("BackgroundBarrier")
	if barrier:
		barrier.queue_free()
	
	# Unpause the game tree if it was paused
	if get_tree().paused:
		get_tree().paused = false
	
	# Emit signal to unlock building controls
	panel_closed.emit()

func _on_user_input_text_submitted(submitted_text):
	_check_answer()

func _on_submit_button_pressed():
	_check_answer()

func _check_answer():
	# Make sure mission is valid
	if mission == null:
		push_error("Mission is null in _check_answer")
		return
	
	var user_answer = ""
	
	# Handle multiple inputs if present
	if mission.num_of_user_inputs > 1 and not user_inputs.is_empty():
		var answers = []
		for input in user_inputs:
			if input:
				answers.append(input.text.strip_edges())
		user_answer = ",".join(answers)
	# Fall back to single input
	elif user_input:
		user_answer = user_input.text.strip_edges()
	else:
		push_error("Cannot check answer: no user input fields available")
		return
	
	# Convert to uppercase for case-insensitive comparison when appropriate
	if not "," in correct_answer:  # Don't uppercase comma-separated values
		user_answer = user_answer.to_upper()
	
	# Get the feedback label
	var feedback_label = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/UserInputContainer/FeedbackLabel")
	if not feedback_label:
		push_error("Feedback label not found")
		return
	
	# Make feedback visible
	feedback_label.visible = true
	
	if user_answer == correct_answer:
		is_answer_correct = true
		
		# Show feedback text
		if not mission.feedback_text.is_empty():
			feedback_label.text = mission.feedback_text
		else:
			feedback_label.text = "Correct! You've solved this problem successfully."
		
		feedback_label.add_theme_color_override("font_color", Color(0, 0.7, 0.2))
		
		# Send correct answer dialog to learning companion if available
		if mission.companion_dialog.has("correct_answer"):
			var dialog_data = mission.companion_dialog["correct_answer"]
			const JSBridge = preload("res://scripts/javascript_bridge.gd")
			if JSBridge.has_interface():
				JSBridge.get_interface().sendCompanionDialog("correct_answer", dialog_data)
		
		# Change submit button to "Complete" button
		if submit_button:
			submit_button.text = "COMPLETE"
			
			# Disconnect submit and connect complete signals
			if submit_button.is_connected("pressed", Callable(self, "_on_submit_button_pressed")):
				submit_button.pressed.disconnect(_on_submit_button_pressed)
			
			if not submit_button.is_connected("pressed", Callable(self, "_on_complete_mission")):
				submit_button.pressed.connect(_on_complete_mission)
	else:
		# Show incorrect feedback
		if not mission.incorrect_feedback.is_empty():
			feedback_label.text = mission.incorrect_feedback
		else:
			feedback_label.text = "Not quite right. Please try again."
		
		feedback_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		
		# Send incorrect answer dialog to learning companion if available
		if mission.companion_dialog.has("incorrect_answer"):
			var dialog_data = mission.companion_dialog["incorrect_answer"]
			const JSBridge = preload("res://scripts/javascript_bridge.gd")
			if JSBridge.has_interface():
				JSBridge.get_interface().sendCompanionDialog("incorrect_answer", dialog_data)

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

func _on_hint_button_pressed():
	print("Hint button pressed")
	
	# First hint request
	if mission.companion_dialog.has("hint_request"):
		var dialog_data = mission.companion_dialog["hint_request"]
		const JSBridge = preload("res://scripts/javascript_bridge.gd")
		if JSBridge.has_interface():
			JSBridge.get_interface().sendCompanionDialog("hint_request", dialog_data)
	
	# Additional hint if available and first hint was already shown
	# We'll use a timer to ensure there's a delay between hints
	var second_hint_timer = Timer.new()
	second_hint_timer.wait_time = 6.0  # Wait 6 seconds before showing second hint
	second_hint_timer.one_shot = true
	second_hint_timer.autostart = true
	add_child(second_hint_timer)
	
	# Connect the timeout signal
	second_hint_timer.timeout.connect(func():
		if mission.companion_dialog.has("hint_second"):
			var dialog_data = mission.companion_dialog["hint_second"]
			const JSBridge = preload("res://scripts/javascript_bridge.gd")
			if JSBridge.has_interface():
				JSBridge.get_interface().sendCompanionDialog("hint_second", dialog_data)
		
		# Clean up the timer
		second_hint_timer.queue_free()
	)
