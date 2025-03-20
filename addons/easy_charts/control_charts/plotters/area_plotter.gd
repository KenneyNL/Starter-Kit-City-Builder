extends LinePlotter
class_name AreaPlotter

func _init(function: Function) -> void:
	super(function)
	pass

func _draw_areas() -> void:
	var box: Rect2 = get_box()
	var fp_augmented: PackedVector2Array = []
	match function.get_interpolation():
		Function.Interpolation.LINEAR:
			fp_augmented = points_positions
		Function.Interpolation.STAIR:
			fp_augmented = _get_stair_points()
		Function.Interpolation.SPLINE:
			fp_augmented = _get_spline_points()
		Function.Interpolation.NONE, _:
			return
	
	fp_augmented.push_back(Vector2(fp_augmented[-1].x, box.end.y + 80))
	fp_augmented.push_back(Vector2(fp_augmented[0].x, box.end.y + 80))
	
	var base_color: Color = function.get_color()
	var colors: PackedColorArray = []
	for point in fp_augmented:
		base_color.a = remap(point.y, box.end.y, box.position.y, 0.0, 0.5)
		colors.push_back(base_color)
	draw_polygon(fp_augmented, colors)

func _draw() -> void:
	super._draw()
	_draw_areas()
