extends Control

signal completed
signal panel_opened
signal panel_closed

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
	
	# Connect button signal
	var answer_button = get_node_or_null("FloatingAnswerButton")
	if answer_button:
		answer_button.pressed.connect(_on_answer_button_pressed)
	else:
		push_error("Answer button not found in fullscreen learning panel")
	
func show_fullscreen_panel(mission_data: MissionData):
	# Check if the mission data is valid
	if mission_data == null:
		push_error("Invalid mission data provided to fullscreen learning panel")
		return
	
	mission = mission_data
	
	# Reset answer state
	is_answer_correct = false
	
	# Set the background to the specified color
	self.color = Color(0.098, 0.078, 0.172, 0.95) # #19142cf2
	
	# Set the mission title
	var mission_title_label = get_node_or_null("PanelContainer/MarginContainer/ContentScrollContainer/ContentContainer/TitleContainer/MissionTitleLabel")
	if mission_title_label:
		mission_title_label.text = mission.title.to_upper()
	
	# Get reference to the mission content rich text label
	var mission_content = get_node_or_null("PanelContainer/MarginContainer/ContentScrollContainer/ContentContainer/RichTextContainer/MissionContent")
	
	# Check if we have fullscreen content to display
	if not mission.full_screen_path.is_empty():
		# First, try to load as image if it's an image path
		if mission.full_screen_path.ends_with(".png") or mission.full_screen_path.ends_with(".jpg") or mission.full_screen_path.ends_with(".jpeg"):
			# We'll use BBCode to embed the image properly
			if mission_content:
				mission_content.text = "[center][img={width}x0]{path}[/img][/center]".format(
					{"path": mission.full_screen_path, "width": get_viewport().size.x * 0.9}
				)
				print("Using BBCode to display image with auto width: " + mission.full_screen_path)
		
		# If it's a text file, load it and use proper formatting
		elif mission.full_screen_path.ends_with(".txt"):
			var file = FileAccess.open(mission.full_screen_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				
				if mission_content:
					# Format the content with proper styling
					mission_content.text = _format_content(content)
					print("Loaded text content from file: " + mission.full_screen_path)
			else:
				push_error("Failed to load text from file: " + mission.full_screen_path)
				if mission_content:
					mission_content.text = "Error loading content from " + mission.full_screen_path
	elif not mission.power_math_content.is_empty():
		# If we have power math content, use that instead
		if mission_content:
			mission_content.text = _format_content(mission.power_math_content)
			print("Using power math content for display")
	else:
		push_error("No content provided to fullscreen learning panel")
		if mission_content:
			mission_content.text = "No content available."
	
	# Set up the correct answer from mission data
	if not mission.correct_answer.is_empty():
		correct_answer = mission.correct_answer
	else:
		# Default answer based on mission type
		correct_answer = "1" if not mission.power_math_content.is_empty() else "A"
	
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
	
	# Disable background interaction
	_disable_background_interaction()
	
	# Style the scrollbar for better appearance
	await get_tree().process_frame
	var scroll_container = get_node_or_null("PanelContainer/MarginContainer/ContentScrollContainer")
	if scroll_container and scroll_container.get_v_scroll_bar():
		var scrollbar_grabber_style = StyleBoxFlat.new()
		scrollbar_grabber_style.bg_color = Color(0.376, 0.760, 0.658, 0.5)
		scrollbar_grabber_style.corner_radius_top_left = 5
		scrollbar_grabber_style.corner_radius_top_right = 5
		scrollbar_grabber_style.corner_radius_bottom_right = 5
		scrollbar_grabber_style.corner_radius_bottom_left = 5
		scroll_container.get_v_scroll_bar().add_theme_stylebox_override("grabber", scrollbar_grabber_style)
		print("Applied scrollbar styling")
	
	# Emit signal to lock building controls
	panel_opened.emit()
	
	print("Fullscreen panel is now visible")

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
	panel_style.border_color = Color(1, 1, 1, 1.0)  # White border
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
	
	# Style the submit button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(1, 0.5, 0, 1.0)  # Bright orange
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
	if is_instance_valid(modal) and modal != null:
		modal.queue_free()
	else:
		print("Warning: Attempted to close a null modal")

# Completes the mission from the modal
func _on_modal_complete_mission(modal):
	if is_answer_correct:
		# Complete the learning objective
		for objective in mission.objectives:
			if objective.type == MissionObjective.ObjectiveType.LEARNING:
				objective.progress(objective.target_count)
		
		# Hide the modal and panel
		if is_instance_valid(modal) and modal != null:
			modal.queue_free()
		else:
			print("Warning: Attempted to close a null modal in complete_mission")
			
		hide_fullscreen_panel()
		
		# Emit completed signal
		completed.emit()

func hide_fullscreen_panel():
	visible = false
	
	# Show the HUD again when panel is hidden
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
	
# Helper function to format content with rich text markup
func _format_content(text: String) -> String:
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
			formatted_text += "[center][color=#4FC1A6][font_size=60]" + line + "[/font_size][/color][/center]\n\n"
		elif line.begins_with("THE POWER DEMAND FORMULA:") or "FORMULA:" in line:
			# This is the formula line - center it and make it stand out
			formatted_text += "[center][color=#4FC1A6][font_size=40]THE POWER DEMAND FORMULA:[/font_size][/color] Power needed (kilowatts) = 2 × √n + n⁰·⁶ Where n is the number of houses in your city.[/center]\n\n"
		elif line.begins_with("HINTS FOR SOLVING:") or "HINTS" in line:
			# This is the hints section
			formatted_text += "[color=#4FC1A6][font_size=40]HINTS FOR SOLVING:[/font_size][/color]\n\n"
		elif line.begins_with("•") or line.begins_with("-") or line.begins_with("*"):
			# This is a bullet point
			formatted_text += line + "\n\n"
		elif line.strip_edges().begins_with("Power needed"):
			# This is the formula line - highlight it
			formatted_text += "[center][color=#FFDD99][font_size=42]" + line + "[/font_size][/color][/center]\n\n"
		elif line.strip_edges().begins_with("where"):
			# This is the formula explanation
			formatted_text += "[center][color=#FFDD99][font_size=38][i]" + line + "[/i][/font_size][/color][/center]\n\n"
		elif line.strip_edges().begins_with("Radius"):
			# This is a radius formula
			formatted_text += "[color=#FFDD99][font_size=38]" + line + "[/font_size][/color]\n\n"
		elif line.strip_edges().begins_with("1.") or line.strip_edges().begins_with("2.") or line.strip_edges().begins_with("3."):
			# This is a numbered task step
			formatted_text += "[color=#E8E8E8][font_size=40][b]" + line + "[/b][/font_size][/color]\n\n"
		elif line.strip_edges().length() > 0:
			# Regular text with content
			formatted_text += line + "\n\n"
				
	return formatted_text
