extends FunctionPlotter
class_name PiePlotter

signal point_entered(slice_mid_point, function, props)
signal point_exited(slice_mid_point, function)

var radius_multiplayer: float = 1.0

#### INTERNAL
var box: Rect2
var radius: float

var slices: Array = []
var slices_dirs: PackedVector2Array = []

var focused_point: Point

func _init(function: Function) -> void:
	super(function)
	pass

func _draw() -> void:
	super._draw()
	box = get_box()
	radius = min(box.size.x, box.size.y) * 0.5 * radius_multiplayer
	var total: float = get_total()
	var ratios: PackedFloat32Array = get_ratios(total)
	sample(radius, box.get_center(), total, ratios)
	_draw_pie()
	_draw_labels(radius, box.get_center(), ratios)

func get_total() -> float:
	# Calculate total and ratios
	var total: float = 0.0
	for value in function.__x:
		total += float(value)
	return total

func get_ratios(total: float) -> PackedFloat32Array:
	var ratios: PackedFloat32Array = []
	for value in function.__x:
		ratios.push_back(value / total * 100)
	return ratios

func sample(radius: float, center: Vector2, total: float, ratios: PackedFloat32Array) -> void:
	# Calculate directions
	slices.clear()
	slices_dirs = []
	
	var start_angle: float = 0.0
	for ratio in ratios:
		var end_angle: float = start_angle + (2 * PI * float(ratio) * 0.01)
		slices.append(
			_calc_circle_arc_poly(
				center,
				radius,
				start_angle,
				end_angle
			)
		)
		start_angle = end_angle
	
	for slice in slices:
		var mid_point: Vector2 = (slice[-1] + slice[1]) / 2
		draw_circle(mid_point, 5, Color.WHITE)
		slices_dirs.append(center.direction_to(mid_point))

func _calc_circle_arc_poly(center: Vector2, radius: float, angle_from: float, angle_to: float) -> PackedVector2Array:
	var nb_points: int = 64
	var points_arc: PackedVector2Array = PackedVector2Array()
	points_arc.push_back(center)
	
	for i in range(nb_points + 1):
		var angle_point: float = - (PI / 2) + angle_from + i * (angle_to - angle_from) / nb_points
		points_arc.push_back(center + (Vector2.RIGHT.rotated(angle_point).normalized() * radius))
	
	return points_arc

func _draw_pie() -> void:
	for i in slices.size():
		draw_colored_polygon(slices[i], function.get_gradient().sample(float(i) / float(slices.size() - 1)))
		draw_polyline(slices[i], Color.WHITE, 2.0, true)

func _draw_labels(radius: float, center: Vector2, ratios: PackedFloat32Array) -> void:
	for i in slices_dirs.size():
		var ratio_lbl: String = "%.1f%%" % ratios[i]
		var value_lbl: String = "(%s)" % function.__x[i]
		var position: Vector2 = center + slices_dirs[i] * radius * 0.5
		var ratio_lbl_size: Vector2 = get_chart_properties().get_string_size(ratio_lbl)
		var value_lbl_size: Vector2 = get_chart_properties().get_string_size(value_lbl)
		draw_string(
			get_chart_properties().font,
			position - Vector2(ratio_lbl_size.x / 2, 0),
			ratio_lbl,
			HORIZONTAL_ALIGNMENT_CENTER,
			ratio_lbl_size.x,
			16,
			Color.WHITE,
			3,
			TextServer.DIRECTION_AUTO,
			TextServer.ORIENTATION_HORIZONTAL
		)
		draw_string(
			get_chart_properties().font,
			position - Vector2(value_lbl_size.x / 2, - value_lbl_size.y),
			value_lbl,
			HORIZONTAL_ALIGNMENT_CENTER,
			value_lbl_size.x,
			16,
			Color.WHITE,
			3,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_HORIZONTAL
		)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		for i in slices.size():
			if Geometry2D.is_point_in_polygon(get_relative_position(event.position), slices[i]):
				var point: Point = Point.new(self.box.get_center() + slices_dirs[i] * self.radius * 0.5, { x = function.__x[i], y = function.__y[i] })
				if focused_point == point:
					return
				else:
					focused_point = point
					emit_signal("point_entered", focused_point, function, { interpolation_index = float(i) / float(slices.size() - 1)})
					return
		# Mouse is not in any slice's box
		emit_signal("point_exited", focused_point, function)
		focused_point = null
