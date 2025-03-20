@icon("res://addons/easy_charts/utilities/icons/linechart.svg")
extends PanelContainer
class_name Chart

@onready var _canvas: Canvas = $Canvas
@onready var plot_box: PlotBox = $"%PlotBox"
@onready var grid_box: GridBox = $"%GridBox"
@onready var functions_box: Control = $"%FunctionsBox"
@onready var function_legend: FunctionLegend = $"%FunctionLegend"

var functions: Array = []
var x: Array = []
var y: Array = []

var x_labels_function: Callable = Callable()
var y_labels_function: Callable = Callable()

var x_domain: Dictionary = {}
var y_domain: Dictionary = {}

var chart_properties: ChartProperties = null

###########

func _ready() -> void:
	if theme == null:
		theme = Theme.new()

func plot(functions: Array[Function], properties: ChartProperties = ChartProperties.new()) -> void:
	self.functions = functions
	self.chart_properties = properties
	
	theme.set("default_font", self.chart_properties.font)
	_canvas.prepare_canvas(self.chart_properties)
	plot_box.chart_properties = self.chart_properties
	function_legend.chart_properties = self.chart_properties
	
	load_functions(functions)

func get_function_plotter(function: Function) -> FunctionPlotter:
	var plotter: FunctionPlotter
	match function.get_type():
		Function.Type.LINE:
			plotter = LinePlotter.new(function)
		Function.Type.AREA:
			plotter = AreaPlotter.new(function)
		Function.Type.PIE:
			plotter = PiePlotter.new(function)
		Function.Type.BAR:
			plotter = BarPlotter.new(function)
		Function.Type.SCATTER, _:
			plotter = ScatterPlotter.new(function)
	return plotter

func load_functions(functions: Array[Function]) -> void:
	self.x = []
	self.y = []
	
	function_legend.clear()

	# Remove existing function_plotters
	for function_plotter in functions_box.get_children():
		functions_box.remove_child(function_plotter)
		function_plotter.queue_free()
	
	for function in functions:
		# Load x and y values
		self.x.append(function.__x)
		self.y.append(function.__y)
		
		# Create FunctionPlotter
		var function_plotter: FunctionPlotter = get_function_plotter(function)
		function_plotter.connect("point_entered", Callable(plot_box, "_on_point_entered"))
		function_plotter.connect("point_exited", Callable(plot_box, "_on_point_exited"))
		functions_box.add_child(function_plotter)
		
		# Create legend
		match function.get_type():
			Function.Type.PIE:
				for i in function.__x.size():
					var interp_color: Color = function.get_gradient().sample(float(i) / float(function.__x.size()))
					function_legend.add_label(function.get_type(), interp_color, Function.Marker.NONE, function.__y[i])
			_:
				function_legend.add_function(function)

func _draw() -> void:
	if (x.size() == 0) or (y.size() == 0) or (x.size() == 1 and x[0].is_empty()) or (y.size() == 1 and y[0].is_empty()):
		printerr("Cannot plot an empty function!")
		return
	
	var is_x_fixed: bool = x_domain.get("fixed", false)
	var is_y_fixed: bool = y_domain.get("fixed", false)
	
	# GridBox
	if not is_x_fixed or not is_y_fixed :
		if chart_properties.max_samples > 0 :
			var _x: Array = []
			var _y: Array = []
			
			_x.resize(x.size())
			_y.resize(y.size())
			
			for i in x.size():
				if not is_x_fixed:
					_x[i] = x[i].slice(max(0, x[i].size() - chart_properties.max_samples), x[i].size())
				if not is_y_fixed:
					_y[i] = y[i].slice(max(0, y[i].size() - chart_properties.max_samples), y[i].size())
			
			if not is_x_fixed:
				x_domain = calculate_domain(_x)
			if not is_y_fixed:
				y_domain = calculate_domain(_y)
		else:
			if not is_x_fixed:
				x_domain = calculate_domain(x)
			if not is_y_fixed:
				y_domain = calculate_domain(y)
	
	# Update values for the PlotBox in order to propagate them to the children
	update_plotbox(x_domain, y_domain, x_labels_function, y_labels_function)
	
	# Update GridBox
	update_gridbox(x_domain, y_domain, x_labels_function, y_labels_function)
	
	# Update each FunctionPlotter in FunctionsBox
	for function_plotter in functions_box.get_children():
		if function_plotter is FunctionPlotter:
			function_plotter.visible = function_plotter.function.get_visibility()
			if function_plotter.function.get_visibility():
				function_plotter.update_values(x_domain, y_domain)

func calculate_domain(values: Array) -> Dictionary:
	for value_array in values:
		if ECUtilities._contains_string(value_array):
			return { lb = 0.0, ub = (value_array.size() - 1), has_decimals = false , fixed = false }
	var min_max: Dictionary = ECUtilities._find_min_max(values)
	
	if not chart_properties.smooth_domain:
		return { lb = min_max.min, ub = min_max.max, has_decimals = ECUtilities._has_decimals(values), fixed = false }
	else:
		return { lb = ECUtilities._round_min(min_max.min), ub = ECUtilities._round_max(min_max.max), has_decimals = ECUtilities._has_decimals(values) , fixed = false }

func set_x_domain(lb: Variant, ub: Variant) -> void:
	x_domain = { lb = lb, ub = ub, has_decimals = ECUtilities._has_decimals([lb, ub]), fixed = true }

func set_y_domain(lb: Variant, ub: Variant) -> void:
	y_domain = { lb = lb, ub = ub, has_decimals = ECUtilities._has_decimals([lb, ub]), fixed = true }

func update_plotbox(x_domain: Dictionary, y_domain: Dictionary, x_labels_function: Callable, y_labels_function: Callable) -> void:
	plot_box.box_margins = calculate_plotbox_margins(x_domain, y_domain)
	plot_box.set_labels_functions(x_labels_function, y_labels_function)

func update_gridbox(x_domain: Dictionary, y_domain: Dictionary, x_labels_function: Callable, y_labels_function: Callable) -> void:
	grid_box.set_domains(x_domain, y_domain)
	grid_box.set_labels_functions(x_labels_function, y_labels_function)
	grid_box.queue_redraw()

func calculate_plotbox_margins(x_domain: Dictionary, y_domain: Dictionary) -> Vector2:
	var plotbox_margins: Vector2 = Vector2(
		chart_properties.x_tick_size,
		chart_properties.y_tick_size
	)
	
	if chart_properties.show_tick_labels:
		var x_ticklabel_size: Vector2
		var y_ticklabel_size: Vector2
		
		var y_max_formatted: String = ECUtilities._format_value(y_domain.ub, y_domain.has_decimals)
		if y_domain.lb < 0: # negative number
			var y_min_formatted: String = ECUtilities._format_value(y_domain.lb, y_domain.has_decimals)
			if y_min_formatted.length() >= y_max_formatted.length():
				y_ticklabel_size = chart_properties.get_string_size(y_min_formatted)
			else:
				y_ticklabel_size = chart_properties.get_string_size(y_max_formatted)
		else:
			y_ticklabel_size = chart_properties.get_string_size(y_max_formatted)
		
		plotbox_margins.x += y_ticklabel_size.x + chart_properties.x_ticklabel_space
		plotbox_margins.y += ThemeDB.fallback_font_size + chart_properties.y_ticklabel_space
	
	return plotbox_margins
