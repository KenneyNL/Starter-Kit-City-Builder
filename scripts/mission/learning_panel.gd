extends Control

signal completed
signal panel_opened
signal panel_closed

# Only store user_input and submit_button variables for signal connections
var user_input
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
	
	# Set up user input placeholder
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

# Reset the panel to a clean state
func _reset_panel():
	# Reset answer state
	is_answer_correct = false
	
	# Clear text inputs
	if user_input:
		user_input.text = ""
	
	# Hide feedback label
	var feedback_label = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/UserInputContainer/FeedbackLabel")
	if feedback_label:
		feedback_label.visible = false
	
	# Clean up any TopMargin that might have been added
	var user_input_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/UserInputContainer")
	if user_input_container:
		var top_margin = user_input_container.get_node_or_null("TopMargin")
		if top_margin:
			top_margin.queue_free()
			
		# Reset custom sizing
		user_input_container.custom_minimum_size.y = 0
		user_input_container.size_flags_vertical = Control.SIZE_FILL
	
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
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	
	# Clear power math content from the graph container
	if graph_center_container:
		var power_math_label = graph_center_container.get_node_or_null("PowerMathLabel")
		if power_math_label:
			power_math_label.queue_free()
	
	# Reset company data container
	if company_data_container:
		company_data_container.visible = false
		var company_data_label = company_data_container.get_node_or_null("CompanyDataLabel")
		if company_data_label:
			company_data_label.text = ""

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
	
	# 2. Set company data
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	if company_data_container:
		company_data_container.visible = true
		
		# Check if we need to convert the company data to a horizontal layout
		var company_data_label = company_data_container.get_node_or_null("CompanyDataLabel")
		if company_data_label:
			if mission.company_data.is_empty():
				company_data_label.text = "[center][color=#e06666][font_size=18]No company data available.[/font_size][/color][/center]"
			else:
				# Split the original data to create a horizontal layout
				var data_text = mission.company_data
				
				# Check if we need to reformat to save vertical space
				if graph_image and graph_image.visible and graph_image.custom_minimum_size.y > 400:
					print("Graph is large, reformatting company data to horizontal layout")
					
					# Parse and reformat the company data to be more compact
					# This assumes the data has a typical format with company names and bullet points
					var lines = data_text.split("\n")
					var company_a_name = ""
					var company_a_data = []
					var company_b_name = ""
					var company_b_data = []
					var current_company = -1  # 0 for A, 1 for B
					
					# Parse the data by line
					for line in lines:
						line = line.strip_edges()
						if line == "" or line.length() == 0:
							continue
							
						if "[color=#60c2a8]" in line or "Company A:" in line:
							# Found Company A header
							company_a_name = line
							current_company = 0
						elif "[color=#e06666]" in line or "Company B:" in line:
							# Found Company B header
							company_b_name = line
							current_company = 1
						elif line.begins_with("•") or line.begins_with("-") or line.begins_with("*"):
							# This is a data point
							if current_company == 0:
								company_a_data.append(line)
							elif current_company == 1:
								company_b_data.append(line)
						elif "Enter A or B" in line or "If you need" in line:
							# This is the question part - add to both
							company_a_data.append(line)
							company_b_data.append("")
						elif "Hint:" in line:
							# This is the hint - add to both
							company_a_data.append(line)
							company_b_data.append("")
					
					# Create a horizontal layout with two columns
					var formatted_text = "[center]\n"
					
					# Add Company A
					formatted_text += "[color=#ce5371][b]" + (company_a_name.replace("[b]", "").replace("[/b]", "").replace("[color=#60c2a8]", "").replace("[/color]", "")) + "[/b][/color]\n"
					for point in company_a_data:
						formatted_text += point + "\n"
						
					formatted_text += "\n"
					
					# Add Company B
					formatted_text += "[color=#3182c0][b]" + (company_b_name.replace("[b]", "").replace("[/b]", "").replace("[color=#e06666]", "").replace("[/color]", "")) + "[/b][/color]\n"
					for point in company_b_data:
						formatted_text += point + "\n"
						
					formatted_text += "[/center]"
					
					# Set the formatted text
					company_data_label.text = formatted_text
					company_data_label.custom_minimum_size.y = 140  # Reduce height for horizontal layout
				else:
					# Use original data format
					company_data_label.text = data_text
					

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
	
	# Make sure we have a user input field
	if not user_input:
		push_error("Cannot check answer: user_input is null")
		return
	
	var user_answer = user_input.text.strip_edges().to_upper()  # Convert to uppercase for case-insensitive comparison
	
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
