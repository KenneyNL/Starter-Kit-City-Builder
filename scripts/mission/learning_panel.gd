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
var using_fullscreen_mode: bool = false

func _ready():
	# Hide panel initially
	visible = false
	
	# Wait for the scene to be ready
	await get_tree().process_frame
	
	# Make sure we're on the right layer
	z_index = 100
	
	# Only get references needed for signal connections
	user_input = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer/UserInput")
	submit_button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/SubmitButtonContainer/SubmitButton")
	
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
	
	# Check if we should use full-screen image mode
	if not mission.full_screen_path.is_empty():
		# Use full-screen image mode with just the image and user input
		_setup_fullscreen_mode()
	else:
		# Use traditional text and graph mode
		_setup_traditional_mode()
	
	# Set up the correct answer from mission data
	if not mission.correct_answer.is_empty():
		correct_answer = mission.correct_answer
	else:
		# Default answer based on mission type
		correct_answer = "1" if not mission.power_math_content.is_empty() else "A"
	
	# Set up user input placeholder (needed in both modes)
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
	
	# Emit signal to lock building controls
	panel_opened.emit()
	
	print("Panel is now visible = ", visible, ", Full-screen mode: ", using_fullscreen_mode)

# Reset the panel to a clean state
func _reset_panel():
	# Reset answer state
	is_answer_correct = false
	using_fullscreen_mode = false
	
	# Clear text inputs
	if user_input:
		user_input.text = ""
	
	# Hide feedback label
	var feedback_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer/FeedbackLabel")
	if feedback_label:
		feedback_label.visible = false
	
	# Clean up any TopMargin that might have been added
	var user_input_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer")
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
			
	# Remove any existing fullscreen container
	var main_content = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent")
	if main_content:
		var fullscreen_container = main_content.get_node_or_null("FullScreenContainer")
		if fullscreen_container:
			fullscreen_container.queue_free()

# Creates a floating answer button outside the normal hierarchy
func _create_floating_answer_button():
	print("Creating floating answer button")
	
	# Remove any existing floating button
	var existing = get_node_or_null("FloatingAnswerButton")
	if existing:
		existing.queue_free()
	
	# Create a highly visible button
	var answer_button = Button.new()
	answer_button.name = "FloatingAnswerButton"
	answer_button.text = "ANSWER THE QUESTION"
	answer_button.custom_minimum_size = Vector2(500, 120)
	
	# Add directly to learning panel as a child (outside normal hierarchy)
	add_child(answer_button)
	
	# Position at bottom center of screen
	answer_button.anchor_left = 0.5
	answer_button.anchor_top = 1.0
	answer_button.anchor_right = 0.5
	answer_button.anchor_bottom = 1.0
	answer_button.offset_left = -250  # Half of width
	answer_button.offset_top = -170
	answer_button.offset_right = 250
	answer_button.offset_bottom = -50
	
	# Add visual style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 0.5, 0, 1)  # Bright orange
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.border_color = Color(1, 1, 1, 1)  # White border
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 10
	
	answer_button.add_theme_stylebox_override("normal", style)
	answer_button.add_theme_stylebox_override("hover", style)
	answer_button.add_theme_stylebox_override("pressed", style)
	answer_button.add_theme_font_size_override("font_size", 36)
	
	# Make sure it's above everything
	answer_button.z_index = 1000
	
	# Connect signal
	answer_button.pressed.connect(_on_answer_button_pressed)
	
	print("Floating button created and positioned")

# Sets up the full-screen mode where a single image contains all mission information
func _setup_fullscreen_mode():
	using_fullscreen_mode = true
	
	# First, hide the traditional elements
	_hide_traditional_elements()
	
	# Get the main content container
	var main_content = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent")
	if not main_content:
		push_error("Main content container not found")
		return
		
	# Clear any existing fullscreen content
	var existing_fullscreen = main_content.get_node_or_null("FullScreenContainer")
	if existing_fullscreen:
		existing_fullscreen.queue_free()
	
	# Create the container for the fullscreen content - using VBoxContainer for overall layout
	var fullscreen_container = VBoxContainer.new()
	fullscreen_container.name = "FullScreenContainer"
	fullscreen_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fullscreen_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Check if the path ends with .png, .jpg, etc. (image file)
	if mission.full_screen_path.ends_with(".png") or mission.full_screen_path.ends_with(".jpg") or \
	   mission.full_screen_path.ends_with(".jpeg") or mission.full_screen_path.ends_with(".webp"):
		# Create a control node that will take up the full width and most of the height
		var image_container = Control.new()
		image_container.name = "ImageContainer"
		image_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		image_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Set this container to take up a large portion but not fixed height
		image_container.size_flags_stretch_ratio = 3.0 # Give priority in layout
		
		# This is an image path - use TextureRect with anchors to fill the container
		var fullscreen_image = TextureRect.new()
		fullscreen_image.name = "FullScreenImage"
		
		# Use anchors to make the texture fill the parent container
		fullscreen_image.anchor_right = 1.0  # Stretch to parent's right edge
		fullscreen_image.anchor_bottom = 1.0 # Stretch to parent's bottom edge
		fullscreen_image.offset_right = 0    # No offset from anchor
		fullscreen_image.offset_bottom = 0   # No offset from anchor
		
		# Configure the image to stretch to fill the available space
		fullscreen_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Use SCALE stretch mode to stretch without preserving aspect ratio
		fullscreen_image.stretch_mode = TextureRect.STRETCH_SCALE
		
		# Initialize with default dimensions that work well for the LaTeX content
		# (These will be adjusted later based on screen size)
		# Since we're using a modal for input, we can use dimensions optimized for the LaTeX content
		fullscreen_image.custom_minimum_size = Vector2(500, 2500)
		
		# Load the texture
		var texture = load(mission.full_screen_path)
		if texture:
			fullscreen_image.texture = texture
			
			# Get image dimensions for logging
			var image_size = texture.get_size()
			print("Loaded fullscreen image: " + mission.full_screen_path + " with dimensions: " + str(image_size.x) + "x" + str(image_size.y))
			
			# Use STRETCH to make text larger and more readable
			fullscreen_image.stretch_mode = TextureRect.STRETCH_SCALE
			print("Using STRETCH_SCALE to increase text size for better readability")
			
			# Adapt size based on screen resolution for responsive layout
			var viewport_size = get_viewport().size
			var base_height = 2500
			var base_width = 500
			
			# If the screen is small, adjust proportionally
			if viewport_size.y < 1080:
				base_height = 2000
				print("Small screen detected, using reduced height")
			elif viewport_size.y > 1440:
				base_height = 3000
				print("Large screen detected, using increased height")
			
			# Set the custom minimum size based on screen size
			fullscreen_image.custom_minimum_size = Vector2(base_width, base_height)
			print("Using responsive size for LaTeX content: " + str(base_width) + "x" + str(base_height))
		else:
			push_error("Failed to load fullscreen image: " + mission.full_screen_path)
		
		# Add the image directly to the container for maximum size
		image_container.add_child(fullscreen_image)
		
		# Add the image container to the main fullscreen container
		fullscreen_container.add_child(image_container)
	else:
		# This is likely a text-based format, use RichTextLabel
		var fullscreen_text = RichTextLabel.new()
		fullscreen_text.name = "FullScreenText"
		fullscreen_text.custom_minimum_size = Vector2(1600, 800) # Larger to make text more readable
		fullscreen_text.bbcode_enabled = true
		fullscreen_text.fit_content = true
		
		# Make text expand to fill available space
		fullscreen_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fullscreen_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Add a margin container to give the text some padding
		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 20)
		margin_container.add_theme_constant_override("margin_right", 20)
		margin_container.add_theme_constant_override("margin_top", 20)
		margin_container.add_theme_constant_override("margin_bottom", 20)
		
		# Format the power math content as rich text
		var formatted_text = ""
		
		# If it's a path to a text file, try to load it
		if mission.full_screen_path.ends_with(".txt"):
			var file = FileAccess.open(mission.full_screen_path, FileAccess.READ)
			if file:
				formatted_text = file.get_as_text()
				file.close()
				print("Loaded text file content from: " + mission.full_screen_path)
			else:
				push_error("Failed to load text file: " + mission.full_screen_path)
				formatted_text = "Error loading content."
		else:
			# Use the power_math_content from the mission data
			formatted_text = mission.power_math_content
			print("Using power_math_content for fullscreen display")
		
		# Apply formatting to the text for better appearance
		formatted_text = _format_fullscreen_text(formatted_text)
		fullscreen_text.text = formatted_text
		
		# Set font sizes for better readability
		fullscreen_text.add_theme_font_size_override("normal_font_size", 40)
		fullscreen_text.add_theme_font_size_override("bold_font_size", 48)
		fullscreen_text.add_theme_font_size_override("italics_font_size", 40)
		fullscreen_text.add_theme_font_size_override("bold_italics_font_size", 40)
		fullscreen_text.add_theme_font_size_override("mono_font_size", 40)
		
		# Add the text to the margin container
		margin_container.add_child(fullscreen_text)
		fullscreen_container.add_child(margin_container)
	
	# Add the container to the main content at the top
	main_content.add_child(fullscreen_container)
	main_content.move_child(fullscreen_container, 0)
	
	# Make sure the user input area is still visible and properly positioned
	var user_input_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer")
	if user_input_container:
		user_input_container.visible = true
		
		# Give the input container a fixed size for consistent layout
		user_input_container.custom_minimum_size.y = 100 # Reduced height for more space for image
		user_input_container.size_flags_vertical = Control.SIZE_SHRINK_END
		
		# Clean up any existing top margin
		var existing_margin = user_input_container.get_node_or_null("TopMargin")
		if existing_margin:
			existing_margin.queue_free()
			
		# No spacer needed since we'll use a modal approach with a button overlay
		
		# Create an answer button overlay instead of showing input fields directly
		_create_answer_button_overlay(fullscreen_container)
		
			# Hide the regular input container and submit button since we use the modal approach
	if user_input_container:
		user_input_container.visible = false
				
			# Also hide the submit button container
		var submit_button_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/SubmitButtonContainer")
		if submit_button_container:
				submit_button_container.visible = false
				print("Submit button container hidden")

	# Hide any graph containers since we're displaying a full screen image
	var graph_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer")
	if graph_container:
		graph_container.visible = false
	
	# Create a floating answer button as a direct child of the panel
		_create_floating_answer_button()
		
		print("Setup fullscreen mode complete")

# This function is no longer used - floating button is created directly instead
func _create_answer_button_overlay(parent_container):
	# This function is intentionally empty as we're now using _create_floating_answer_button instead
	pass

# Shows the answer modal dialog
func _on_answer_button_pressed():
	# Create a modal overlay
	var modal = ColorRect.new()
	modal.name = "AnswerModal"
	modal.color = Color(0.1, 0.1, 0.2, 0.9)  # Dark transparent background
	modal.anchor_right = 1.0
	modal.anchor_bottom = 1.0
	
	# Create a panel container for the modal content
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(600, 300)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	panel_style.border_width_left = 5
	panel_style.border_width_top = 5
	panel_style.border_width_right = 5
	panel_style.border_width_bottom = 5
	panel_style.border_color = Color(1, 1, 1, 1.0)  # White border to match floating button
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.shadow_color = Color(0, 0, 0, 0.7)
	panel_style.shadow_size = 10
	
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Create a margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	# Create a vertical container for the content
	var v_box = VBoxContainer.new()
	v_box.custom_minimum_size = Vector2(500, 0)
	v_box.add_theme_constant_override("separation", 15)
	
	# Add a title label
	var title_label = Label.new()
	if not mission.question_text.is_empty():
		title_label.text = mission.question_text
	else:
		title_label.text = "How many power plants are needed to power 40 houses? (Enter a number)"
	
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))  # White text
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Create an input field
	var input_field = LineEdit.new()
	input_field.name = "ModalInput"
	input_field.placeholder_text = "Type your answer here..."
	input_field.custom_minimum_size = Vector2(0, 50)
	input_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_field.add_theme_font_size_override("font_size", 24)
	input_field.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))  # White text
	input_field.add_theme_color_override("caret_color", Color(1, 1, 1, 1.0))  # White cursor
	input_field.add_theme_color_override("font_placeholder_color", Color(0.7, 0.7, 0.7, 0.7))  # Light gray for placeholder
	
	# Style the input field
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.2, 0.2, 0.3, 1.0)  # Darker background
	input_style.border_width_left = 2
	input_style.border_width_top = 2
	input_style.border_width_right = 2
	input_style.border_width_bottom = 2
	input_style.border_color = Color(1, 1, 1, 0.3)  # Subtle white border
	input_style.corner_radius_top_left = 10
	input_style.corner_radius_top_right = 10
	input_style.corner_radius_bottom_right = 10
	input_style.corner_radius_bottom_left = 10
	
	input_field.add_theme_stylebox_override("normal", input_style)
	
	# Create a feedback label
	var feedback_label = Label.new()
	feedback_label.name = "ModalFeedback"
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 24)
	feedback_label.visible = false
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Create buttons
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	
	var submit_button = Button.new()
	submit_button.name = "ModalSubmit"
	submit_button.text = "SUBMIT"
	submit_button.custom_minimum_size = Vector2(200, 60)
	
	var close_button = Button.new()
	close_button.name = "ModalClose"
	close_button.text = "CANCEL"
	close_button.custom_minimum_size = Vector2(200, 60)
	
	# Style the submit button to match the floating button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(1, 0.5, 0, 1.0)  # Bright orange to match floating button
	button_style.border_width_left = 3
	button_style.border_width_top = 3
	button_style.border_width_right = 3
	button_style.border_width_bottom = 3
	button_style.border_color = Color(1, 1, 1, 1.0)  # White border
	button_style.corner_radius_top_left = 20
	button_style.corner_radius_top_right = 20
	button_style.corner_radius_bottom_right = 20
	button_style.corner_radius_bottom_left = 20
	button_style.shadow_color = Color(0, 0, 0, 0.5)
	button_style.shadow_size = 5
	
	submit_button.add_theme_stylebox_override("normal", button_style)
	submit_button.add_theme_stylebox_override("hover", button_style)
	submit_button.add_theme_stylebox_override("pressed", button_style)
	submit_button.add_theme_font_size_override("font_size", 24)
	submit_button.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))  # White text
	
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.3, 0.3, 0.5, 1.0)  # Darker color but consistent with theme
	close_style.border_width_left = 3
	close_style.border_width_top = 3
	close_style.border_width_right = 3
	close_style.border_width_bottom = 3
	close_style.border_color = Color(0.8, 0.8, 0.8, 1.0)  # Light gray border
	close_style.corner_radius_top_left = 20
	close_style.corner_radius_top_right = 20
	close_style.corner_radius_bottom_right = 20
	close_style.corner_radius_bottom_left = 20
	close_style.shadow_color = Color(0, 0, 0, 0.5)
	close_style.shadow_size = 5
	
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.add_theme_stylebox_override("hover", close_style)
	close_button.add_theme_stylebox_override("pressed", close_style)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))  # White text
	
	# Add buttons to the container
	button_container.add_child(submit_button)
	button_container.add_child(close_button)
	
	# Add elements to the vertical container
	v_box.add_child(title_label)
	v_box.add_child(input_field)
	v_box.add_child(feedback_label)
	v_box.add_child(Control.new()) # Spacer
	v_box.add_child(button_container)
	
	# Assemble the hierarchy
	margin.add_child(v_box)
	panel.add_child(margin)
	
	# Center the panel in the modal
	var center_container = CenterContainer.new()
	center_container.anchor_right = 1.0
	center_container.anchor_bottom = 1.0
	center_container.add_child(panel)
	
	modal.add_child(center_container)
	
	# Add the modal to the scene
	add_child(modal)
	
	# Connect signals
	submit_button.pressed.connect(_on_modal_submit_pressed.bind(input_field, feedback_label, modal))
	close_button.pressed.connect(_on_modal_close_pressed.bind(modal))
	input_field.text_submitted.connect(_on_modal_text_submitted.bind(input_field, feedback_label, modal))
	
	# Set focus to the input field
	input_field.grab_focus()

# Handles the modal submission
func _on_modal_submit_pressed(input_field, feedback_label, modal):
	var user_answer = input_field.text.strip_edges().to_upper()
	
	# Check if the answer is correct
	if user_answer == correct_answer:
		is_answer_correct = true
		
		# Show positive feedback
		feedback_label.text = "Correct! You've solved this problem successfully."
		feedback_label.add_theme_color_override("font_color", Color(0, 0.9, 0.2))
		feedback_label.visible = true
		
		# Auto-complete after a short delay
		get_tree().create_timer(1.0).timeout.connect(func(): _on_modal_complete_mission(modal))
	else:
		# Show negative feedback
		feedback_label.text = "Not quite right. Please try again."
		feedback_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		feedback_label.visible = true

# Handles text submitted in the modal
func _on_modal_text_submitted(text, input_field, feedback_label, modal):
	_on_modal_submit_pressed(input_field, feedback_label, modal)

# Handles closing the modal
func _on_modal_close_pressed(modal):
	modal.queue_free()

# Completes the mission from the modal
func _on_modal_complete_mission(modal):
	if is_answer_correct:
		# Complete the learning objective
		for objective in mission.objectives:
			if objective.type == MissionObjective.ObjectiveType.LEARNING:
				objective.progress(objective.target_count)
		
		# Hide the modal and panel
		modal.queue_free()
		hide_learning_panel()
		
		# Emit completed signal
		completed.emit()

# Helper function to format full-screen text with rich text markup
func _format_fullscreen_text(text: String) -> String:
	var lines = text.split("\n")
	var formatted_text = ""
	var in_section = false
	var section_title = ""
	
	for line in lines:
		if line.begins_with("======="):
			# This is a section header marker
			if in_section:
				# End the previous section
				formatted_text += "[/color]\n\n"
				in_section = false
			else:
				# Start a new section with the next line as title
				in_section = true
				continue
		elif in_section and section_title.is_empty():
			# This is the title line after a section marker
			section_title = line.strip_edges()
			formatted_text += "[color=#4FC1A6][font_size=44][b]" + section_title + "[/b][/font_size][/color]\n\n"
			in_section = false
		elif line.strip_edges().to_upper() == line.strip_edges() and line.length() > 10:
			# This looks like a main title (all caps and reasonably long)
			formatted_text += "[color=#4FC1A6][font_size=56][b]" + line + "[/b][/font_size][/color]\n\n"
		elif line.begins_with("•") or line.begins_with("-") or line.begins_with("*"):
			# This is a bullet point
			formatted_text += "[color=#E8E8E8]" + line + "[/color]\n"
		elif line.begins_with("  -") or line.begins_with("   -"):
			# This is a sub-bullet point
			formatted_text += "[color=#CCCCCC]" + line + "[/color]\n"
		elif line.strip_edges().begins_with("Power needed"):
			# This is the formula line - highlight it
			formatted_text += "[center][color=#FFDD99][font_size=42]" + line + "[/font_size][/color][/center]\n"
		elif line.strip_edges().begins_with("where"):
			# This is the formula explanation
			formatted_text += "[center][color=#FFDD99][font_size=38][i]" + line + "[/i][/font_size][/color][/center]\n\n"
		elif line.strip_edges().begins_with("Radius"):
			# This is a radius formula
			formatted_text += "[color=#FFDD99][font_size=38]" + line + "[/font_size][/color]\n"
		elif line.strip_edges().begins_with("1.") or line.strip_edges().begins_with("2.") or line.strip_edges().begins_with("3."):
			# This is a numbered task step
			formatted_text += "[color=#E8E8E8][font_size=40][b]" + line + "[/b][/font_size][/color]\n"
		else:
			# Regular text
			formatted_text += "[color=#E8E8E8][font_size=40]" + line + "[/font_size][/color]\n"
			
	return formatted_text

# Hides the traditional text and graph elements
func _hide_traditional_elements():
	# Hide title
	var title_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/TitleContainer")
	if title_container:
		title_container.visible = false
	
	# Hide intro text
	var intro_text = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/IntroText")
	if intro_text:
		intro_text.visible = false
	
	# Hide description text
	var description_text = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/DescriptionText")
	if description_text:
		description_text.visible = false
	
	# In full-screen image mode, we always hide the graph container
	var graph_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer")
	if graph_container:
		graph_container.visible = false

# Sets up the traditional mode with separate title, text, and graph elements
func _setup_traditional_mode():
	using_fullscreen_mode = false
	
	# Show traditional elements
	_show_traditional_elements()
	
	# Remove any fullscreen image if it exists
	var main_content = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent")
	if main_content:
		var fullscreen_container = main_content.get_node_or_null("FullScreenContainer")
		if fullscreen_container:
			fullscreen_container.queue_free()
	
	# Set the mission title
	var mission_title_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/TitleContainer/MissionTitleLabel")
	if mission_title_label:
		mission_title_label.text = mission.title.to_upper()
	else:
		push_error("MissionTitleLabel node not found")
	
	# Set the intro text
	var intro_text = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/IntroText")
	if intro_text:
		intro_text.text = mission.intro_text if not mission.intro_text.is_empty() else "Welcome to this mission!"
	else:
		push_error("IntroText node not found")
	
	# Set the description text
	var description_text = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/DescriptionText") 
	if description_text:
		description_text.text = mission.description
	else:
		push_error("DescriptionText node not found")
		
	# Set up mission-specific content for construction or power mission
	_setup_mission_specific_content()
	
	print("Setup traditional mode complete")

# Shows the traditional text and graph elements
func _show_traditional_elements():
	# Show title
	var title_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/TitleContainer")
	if title_container:
		title_container.visible = true
	
	# Show intro text
	var intro_text = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/IntroText")
	if intro_text:
		intro_text.visible = true
	
	# Show description text
	var description_text = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/DescriptionText")
	if description_text:
		description_text.visible = true
	
	# Show graph container
	var graph_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer")
	if graph_container:
		graph_container.visible = true

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
	var graph_center_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer")
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	
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
	var graph_image = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer/GraphImage")
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
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
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
					var formatted_text = "[center][columns=2]\n"
					
					# Add Company A
					formatted_text += "[color=#60c2a8][b]" + (company_a_name.replace("[b]", "").replace("[/b]", "").replace("[color=#60c2a8]", "").replace("[/color]", "")) + "[/b][/color]\n"
					for point in company_a_data:
						formatted_text += point + "\n"
						
					formatted_text += "[next]\n"
					
					# Add Company B
					formatted_text += "[color=#e06666][b]" + (company_b_name.replace("[b]", "").replace("[/b]", "").replace("[color=#e06666]", "").replace("[/color]", "")) + "[/b][/color]\n"
					for point in company_b_data:
						formatted_text += point + "\n"
						
					formatted_text += "[/columns][/center]"
					
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
	var graph_image = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer/GraphImage")
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
	var company_data_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/CompanyDataContainer")
	if company_data_container:
		company_data_container.visible = false
	
	# 3. Add power math content if we're not showing a graph
	var graph_center_container = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/GraphContainer/GraphCenterContainer")
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
	var feedback_label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/MainContent/UserInputContainer/FeedbackLabel")
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


# For testing the modal functionality directly
func spawn_test_button():
	var test_button = Button.new()
	test_button.text = "TEST MODAL"
	test_button.custom_minimum_size = Vector2(200, 80)
	test_button.pressed.connect(func(): _on_answer_button_pressed())
	add_child(test_button)
	print("Test button added")
