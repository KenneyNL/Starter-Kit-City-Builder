# This example shows how to instantiate a Chart node at runtime and plot a single function

extends Control

@onready var chart_scn: PackedScene = load("res://addons/easy_charts/control_charts/chart.tscn")
var chart: Chart

# This Chart will plot 1 function
var f1: Function

func _ready():
	chart = chart_scn.instantiate()
	$VBoxContainer.add_child(chart)
	
	# Let's create our @x values
	var x: Array = ArrayOperations.multiply_float(range(-10, 11, 1), 0.5)
	
	# And our y values. It can be an n-size array of arrays.
	# NOTE: `x.size() == y.size()` or `x.size() == y[n].size()`
	var y: Array = ArrayOperations.multiply_int(ArrayOperations.cos(x), 20)
	
	# Let's add values to our functions
	f1 = Function.new(x, y, "Pressure", { marker = Function.Marker.CIRCLE })
	
	# Set fixed Y domain
	chart.set_y_domain(-50, 50)
	
	# Now let's plot our data
	chart.plot([f1])
	
	# Uncommenting this line will show how real time data plotting works
	set_process(false)


var new_val: float = 4.5

func _process(delta: float):
	# This function updates the values of a function and then updates the plot
	new_val += 5
	
	# we can use the `Function.add_point(x, y)` method to update a function
	f1.add_point(new_val, cos(new_val) * 20)
	chart.queue_redraw() # This will force the Chart to be updated


func _on_CheckButton_pressed():
	set_process(not is_processing())
