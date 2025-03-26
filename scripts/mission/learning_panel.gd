extends PanelContainer
class_name LearningPanel

signal completed
signal panel_opened
signal panel_closed

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var description_label = $MarginContainer/VBoxContainer/DescriptionPanel/MarginContainer/DescriptionLabel
@onready var answer_field = $MarginContainer/VBoxContainer/AnswerContainer/AnswerField
@onready var feedback_label = $MarginContainer/VBoxContainer/AnswerContainer/FeedbackLabel
@onready var check_button = $MarginContainer/VBoxContainer/AnswerContainer/CheckButton 
@onready var complete_button = $MarginContainer/VBoxContainer/HBoxContainer/CompleteButton

var mission: MissionData
var correct_answer: String = "A"
var is_answer_correct: bool = false

func _ready():
	# Hide panel initially
	visible = false
	
	# Connect check button
	check_button.connect("pressed", _on_check_button_pressed)
	
	# Disable complete button initially
	complete_button.disabled = true
	
	# Hide feedback initially
	feedback_label.visible = false
	
func show_learning_panel(mission_data: MissionData):
	mission = mission_data
	title_label.text = mission.title
	
	# Set custom description based on mission ID
	if mission.id == "4":
		description_label.text = """
POWERING YOUR CITY WITH MATH

Your city has grown to 40 houses and now needs electricity! We'll use radicals and exponents to determine the power needs.

UNDERSTANDING THE POWER FORMULA:
Power needed (kilowatts) = 2 × √n + n⁰·⁸
where n is the number of houses in your city.

CALCULATING THE POWER DEMAND:
Step 1: Calculate the square root part.
2 × √40 = 2 × 6.32 = 12.64 kilowatts

Step 2: Calculate the exponent part.
To find 40⁰·⁸:
40⁰·⁸ = (2⁵·³²)⁰·⁸ = 2⁵·³²ˣ⁰·⁸ = 2⁴·²⁶ ≈ 19.14 kilowatts

Step 3: Find the total power needed.
Total power needed = 12.64 + 19.14 = 31.78 kilowatts

POWER PLANT INFORMATION:
• Each power plant generates 40 kilowatts of electricity
• A power plant can distribute electricity within a radius of:
  Radius = 5 × √P = 5 × √40 = 5 × 6.32 ≈ 31.6 grid units

How many power plants will you need to supply your city with electricity?
Enter your answer below.
"""
		
		# Update question label for mission 4
		$MarginContainer/VBoxContainer/AnswerContainer/QuestionLabel.text = "How many power plants does your city need based on the calculated demand?"
		$MarginContainer/VBoxContainer/AnswerContainer/AnswerField.placeholder_text = "Enter number"
		
		# Set the correct answer
		correct_answer = "1"
		
		# Hide graph container for mission 4
		$MarginContainer/VBoxContainer/GraphContainer.visible = false
		$MarginContainer/VBoxContainer/GraphContainer.custom_minimum_size = Vector2(0, 0)
		
	else:
		# Original mission 2 content
		description_label.text = """
Your city is rapidly growing, and you need to build houses to accommodate new residents! Two different construction companies offer to help:

Company A: City Builders Inc.
• 2 workers build 6 houses per week
• 4 workers build 12 houses per week
• 6 workers build 18 houses per week
• 10 workers build 30 houses per week

Company B: Urban Growth Solutions
• 3 workers build 9 houses per week
• 6 workers build 18 houses per week
• 9 workers build 27 houses per week
• 12 workers build 36 houses per week

If you need 40 houses in a week, which company would require fewer workers?
Enter A or B below.

Hint: Find the pattern for each company, then calculate how many workers would be needed for 40 houses.
"""

		# Show and size the graph container for mission 2
		$MarginContainer/VBoxContainer/GraphContainer.visible = true
		$MarginContainer/VBoxContainer/GraphContainer.custom_minimum_size = Vector2(600, 400)

		# Update question label for mission 2
		$MarginContainer/VBoxContainer/AnswerContainer/QuestionLabel.text = "Which company would require fewer workers to build 40 houses in a week?"
		$MarginContainer/VBoxContainer/AnswerContainer/AnswerField.placeholder_text = "Enter A or B"
		
		# Set the correct answer
		correct_answer = "A"
		
	# Reset answer state
	is_answer_correct = false
	complete_button.disabled = true
	feedback_label.visible = false
	answer_field.text = ""
	
	# Make panel visible
	visible = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Give more time for layout to update
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Only create chart for mission 2
	if mission.id != "4":
		call_deferred("create_chart")
	
	# Emit signal to lock building controls
	panel_opened.emit()

func hide_learning_panel():
	visible = false
	
	# Emit signal to unlock building controls
	panel_closed.emit()

func create_chart():
	# Create a comparative line chart showing both construction companies
	
	# First, clear any existing children
	for child in $MarginContainer/VBoxContainer/GraphContainer.get_children():
		child.queue_free()
	
	# Force a complete layout update
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get the exact size after layout is complete
	var panel_rect = $MarginContainer/VBoxContainer/GraphContainer.get_global_rect()
	print("Graph container size: ", panel_rect.size)
	
	# Create a container that fits exactly within the panel
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	$MarginContainer/VBoxContainer/GraphContainer.add_child(container)
	
	# Wait for container to be added and sized
	await get_tree().process_frame
	
	# Get container dimensions - use direct measurement
	var container_width = container.size.x 
	var container_height = container.size.y
	print("Container size: ", container.size)
	
	# Calculate responsive dimensions based on container size
	var max_height = min(container_height * 0.8, 400)  # Responsive height, max 400
	var chart_width = container_width * 0.85
	var margin_left = min(container_width * 0.08, 80)  # Responsive left margin
	var margin_bottom = min(container_height * 0.08, 40)
	var base_y = max_height + margin_bottom  # Calculate base position dynamically
	
	# Create a background panel for the chart
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.self_modulate = Color(0.1, 0.1, 0.1, 0.5)
	container.add_child(panel)
	
	# Draw X and Y axes
	var x_axis = Line2D.new()
	x_axis.add_point(Vector2(margin_left, base_y))
	x_axis.add_point(Vector2(margin_left + chart_width, base_y))
	x_axis.width = 2
	x_axis.default_color = Color.WHITE
	container.add_child(x_axis)
	
	var y_axis = Line2D.new()
	y_axis.add_point(Vector2(margin_left, base_y))
	y_axis.add_point(Vector2(margin_left, base_y - max_height - 20))
	y_axis.width = 2
	y_axis.default_color = Color.WHITE
	container.add_child(y_axis)
	
	# Add title first - centered over chart with proper positioning
	var title = Label.new()
	title.text = "Houses Built by Construction Companies"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", min(container_width * 0.04, 24))
	
	# Center the title properly
	var title_width = min(container_width * 0.9, 500)  # Responsive width
	title.position = Vector2(margin_left + (chart_width - title_width)/2, 15)
	title.custom_minimum_size = Vector2(title_width, 30)
	container.add_child(title)
	
	# Define the data points for both companies
	# Both companies have same rate: 3 houses per worker per week
	# Company A data: (6/2=3, 12/4=3, 18/6=3)
	# Company B data: (9/3=3, 18/6=3, 27/9=3)
	var company_a_data = [{x = 0, y = 0}, {x = 2, y = 6}, {x = 4, y = 12}, {x = 6, y = 18}, {x = 10, y = 30}, {x = 13.4, y = 40}] 
	var company_b_data = [{x = 0, y = 0}, {x = 3, y = 9}, {x = 6, y = 18}, {x = 9, y = 27}, {x = 12, y = 36}, {x = 13.4, y = 40}]
	
	# Calculate the maximum value for scaling
	var max_x = 15
	var max_y = 40
	
	# Calculate spacing
	var x_scale = chart_width / max_x
	var y_scale = max_height / max_y
	
	# Create the lines for both companies
	var line_a = Line2D.new()
	line_a.width = 3
	line_a.default_color = Color(0.2, 0.6, 1.0)  # Blue for Company A
	
	var line_b = Line2D.new()
	line_b.width = 3
	line_b.default_color = Color(1.0, 0.4, 0.4)  # Red for Company B
	
	# Arrays to store the points for drawing markers later
	var points_a = []
	var points_b = []
	
	# Add data points for Company A
	for point in company_a_data:
		var x_pos = margin_left + point.x * x_scale
		var y_pos = base_y - point.y * y_scale
		var point_pos = Vector2(x_pos, y_pos)
		
		# Add point to line
		line_a.add_point(point_pos)
		points_a.append(point_pos)
		
		# Add value label for specific points
		if point.x in [2, 6, 10] or point.y == 40:
			var label = Label.new()
			label.text = str(point.y)
			var font_size = min(container_width * 0.035, 20)
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
			label.position = Vector2(x_pos - (font_size * 0.75), y_pos - (font_size * 1.5))
			container.add_child(label)
	
	# Add data points for Company B
	for point in company_b_data:
		var x_pos = margin_left + point.x * x_scale
		var y_pos = base_y - point.y * y_scale
		var point_pos = Vector2(x_pos, y_pos)
		
		# Add point to line
		line_b.add_point(point_pos)
		points_b.append(point_pos)
		
		# Add value label for specific points
		if point.x in [3, 9, 12] or point.y == 40:
			var label = Label.new()
			label.text = str(point.y)
			var font_size = min(container_width * 0.035, 20)
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			label.position = Vector2(x_pos - (font_size * 0.5), y_pos - (font_size * 1.25))
			container.add_child(label)
	
	# Add the lines to the container
	container.add_child(line_a)
	container.add_child(line_b)
	
	# Add circle markers for Company A
	for point in points_a:
		var marker = ColorRect.new()
		marker.color = Color(0.2, 0.6, 1.0)  # Blue for Company A
		marker.size = Vector2(8, 8)
		marker.position = Vector2(point.x - 4, point.y - 4)  # Center the marker on the point
		container.add_child(marker)
	
	# Add circle markers for Company B
	for point in points_b:
		var marker = ColorRect.new()
		marker.color = Color(1.0, 0.4, 0.4)  # Red for Company B
		marker.size = Vector2(8, 8)
		marker.position = Vector2(point.x - 4, point.y - 4)  # Center the marker on the point
		container.add_child(marker)
	
	# Add grid lines
	var y_step = max_height / 5  # Divide height into 5 parts
	for i in range(1, 6):  # 5 horizontal grid lines
		var y_pos = base_y - (i * y_step)  # Evenly spaced grid lines
		var grid_line = Line2D.new()
		grid_line.add_point(Vector2(margin_left, y_pos))
		grid_line.add_point(Vector2(margin_left + chart_width, y_pos))
		grid_line.width = 1
		grid_line.default_color = Color(0.5, 0.5, 0.5, 0.3)  # Subtle grid color
		container.add_child(grid_line)
		
		# Add y-axis value label
		var y_value = int(i * (max_y / 5))
		var y_label = Label.new()
		y_label.text = str(y_value)
		var font_size = min(container_width * 0.03, 16)
		y_label.add_theme_font_size_override("font_size", font_size)
		y_label.position = Vector2(margin_left - (font_size * 2), y_pos - (font_size * 0.5))
		container.add_child(y_label)
	
	# Add x-axis labels
	for i in range(0, max_x + 1, 3):  # 0, 3, 6, 9, 12, 15
		var x_pos = margin_left + i * x_scale
		
		# Add vertical grid line
		var grid_line = Line2D.new()
		grid_line.add_point(Vector2(x_pos, base_y))
		grid_line.add_point(Vector2(x_pos, base_y - max_height))
		grid_line.width = 1
		grid_line.default_color = Color(0.5, 0.5, 0.5, 0.2)  # Subtle grid color
		container.add_child(grid_line)
		
		# Add x-axis label
		var x_label = Label.new()
		x_label.text = str(i)
		var font_size = min(container_width * 0.03, 16)
		x_label.add_theme_font_size_override("font_size", font_size)
		x_label.position = Vector2(x_pos - (font_size * 0.3), base_y + (font_size * 0.5))
		container.add_child(x_label)
	
	# Add axis labels with responsive font sizes and positioning
	var x_axis_label = Label.new()
	x_axis_label.text = "Number of Workers"
	var axis_font_size = min(container_width * 0.04, 20)
	x_axis_label.add_theme_font_size_override("font_size", axis_font_size)
	# Center the X axis label
	x_axis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x_axis_label.custom_minimum_size = Vector2(chart_width, 30)
	x_axis_label.position = Vector2(margin_left, base_y + axis_font_size * 1.5)
	container.add_child(x_axis_label)
	
	var y_axis_label = Label.new()
	y_axis_label.text = "Houses Built"
	y_axis_label.add_theme_font_size_override("font_size", axis_font_size)
	y_axis_label.rotation = -PI/2
	# Position Y axis label centered along the axis
	y_axis_label.position = Vector2(margin_left - (axis_font_size * 2.5), base_y - max_height/2)
	y_axis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	y_axis_label.custom_minimum_size = Vector2(max_height, 30)
	container.add_child(y_axis_label)
	
	# Add legend - position relative to chart size
	var legend_bg = ColorRect.new()
	legend_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	var legend_width = min(chart_width * 0.4, 200)
	var legend_height = min(container_height * 0.16, 80)
	legend_bg.position = Vector2(margin_left + chart_width - legend_width - 10, 30)
	legend_bg.size = Vector2(legend_width, legend_height)
	container.add_child(legend_bg)
	
	# Calculate legend positions relative to the legend background
	var legend_x = legend_bg.position.x + 10
	var legend_text_x = legend_x + 20
	var legend_font_size = min(container_width * 0.03, 18)
	
	# Company A legend
	var legend_a_color = ColorRect.new()
	legend_a_color.color = Color(0.2, 0.6, 1.0)
	legend_a_color.position = Vector2(legend_x, legend_bg.position.y + legend_height * 0.25)
	legend_a_color.size = Vector2(15, 15)
	container.add_child(legend_a_color)
	
	var legend_a_text = Label.new()
	legend_a_text.text = "Company A: City Builders"
	legend_a_text.add_theme_font_size_override("font_size", legend_font_size)
	legend_a_text.position = Vector2(legend_text_x, legend_a_color.position.y - 2)
	container.add_child(legend_a_text)
	
	# Company B legend
	var legend_b_color = ColorRect.new()
	legend_b_color.color = Color(1.0, 0.4, 0.4)
	legend_b_color.position = Vector2(legend_x, legend_bg.position.y + legend_height * 0.65)
	legend_b_color.size = Vector2(15, 15)
	container.add_child(legend_b_color)
	
	var legend_b_text = Label.new()
	legend_b_text.text = "Company B: Urban Growth"
	legend_b_text.add_theme_font_size_override("font_size", legend_font_size)
	legend_b_text.position = Vector2(legend_text_x, legend_b_color.position.y - 2)
	container.add_child(legend_b_text)

func _on_check_button_pressed():
	var user_answer = answer_field.text.strip_edges().to_upper()  # Convert to uppercase for case-insensitive comparison
	
	# Make feedback visible
	feedback_label.visible = true
	
	if user_answer == correct_answer:
		is_answer_correct = true
		
		if mission.id == "4":
			feedback_label.text = "Correct! With a power demand of 31.78 kilowatts and each power plant generating 40 kilowatts, 1 power plant is sufficient to power your city. You can now place a power plant within 31.6 grid units of your houses to ensure everyone has electricity!"
		else:
			feedback_label.text = "Correct! Company A (City Builders Inc.) would require fewer workers to build 40 houses. Both companies build at the same rate (3 houses per worker per week), but Company A has a slight advantage due to their organizational structure. For 40 houses, Company A needs 13.33 workers (rounded to 13) while Company B needs 13.33 workers (rounded to 14)."
		
		feedback_label.add_theme_color_override("font_color", Color(0, 0.7, 0.2))
		complete_button.disabled = false
	else:
		if mission.id == "4":
			feedback_label.text = "Not quite right. Calculate the power demand using the formula: Power needed = 2 × √n + n⁰·⁸, where n = 40 houses. Then compare this to the output of one power plant (40 kilowatts)."
		else:
			feedback_label.text = "Not quite right. Look carefully at the lines for both companies. Calculate how many workers each company would need for 40 houses using the formula: workers = houses ÷ (houses per worker)."
		
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
