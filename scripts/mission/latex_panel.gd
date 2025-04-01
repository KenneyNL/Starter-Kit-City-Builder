extends Control
class_name LatexPanel

# Signals
signal latex_ready

# Variables
var power_formula_node: Node
var exponent_formula_node: Node
var radius_formula_node: Node

func _ready():
	# Initialize the panel
	set_process(false)

# Creates LaTeX nodes from mission data
func setup_latex_from_mission(mission_data: MissionData):
	# Clear any existing LaTeX nodes
	for child in get_children():
		if child.is_class("LaTeX"):
			child.queue_free()
	
	# Get references to the C# MathRenderer
	var math_renderer = load("res://scripts/MathRenderer.cs").new()
	
	# Power formula
	var power_formula = "Power needed (kilowatts) = 2 \\times \\sqrt{n} + n^{0.8}"
	power_formula_node = math_renderer.CreateLatexNode(power_formula, Color(1,1,1), 28)
	power_formula_node.position = Vector2(50, 50)
	add_child(power_formula_node)
	
	# Example calculation
	var sqrt40_formula = "\\sqrt{40} \\approx 6.32"
	var sqrt40_node = math_renderer.CreateLatexNode(sqrt40_formula, Color(1,1,1), 24)
	sqrt40_node.position = Vector2(50, 120)
	add_child(sqrt40_node)
	
	# Exponent calculation
	var exponent_formula = "40^{0.8} = (2^{5.32})^{0.8} = 2^{(5.32 \\times 0.8)} = 2^{4.26} \\approx 19.14"
	exponent_formula_node = math_renderer.CreateLatexNode(exponent_formula, Color(1,1,1), 24)
	exponent_formula_node.position = Vector2(50, 180)
	add_child(exponent_formula_node)
	
	# Total power needed
	var total_power = "Total\\ power = 12.64 + 19.14 = 31.78\\ kilowatts"
	var total_power_node = math_renderer.CreateLatexNode(total_power, Color(1,1,1), 24)
	total_power_node.position = Vector2(50, 240)
	add_child(total_power_node)
	
	# Radius formula
	var radius_formula = "Radius = 5 \\times \\sqrt{P}"
	radius_formula_node = math_renderer.CreateLatexNode(radius_formula, Color(1,1,1), 24)
	radius_formula_node.position = Vector2(50, 300)
	add_child(radius_formula_node)
	
	# Emit signal once LaTeX has been rendered
	call_deferred("emit_signal", "latex_ready")