extends FunctionPlotter
class_name ScatterPlotter

signal point_entered(point, function)
signal point_exited(point, function)

var points: Array[Point]
var points_positions: PackedVector2Array
var focused_point: Point

var point_size: float

func _init(function: Function) -> void:
    super(function)
    self.point_size = function.props.get("point_size", 3.0)

func _draw() -> void:
    super._draw()
    
    var box: Rect2 = get_box()
    var x_sampled_domain: Dictionary = { lb = box.position.x, ub = box.end.x }
    var y_sampled_domain: Dictionary = { lb = box.end.y, ub = box.position.y }
    sample(x_sampled_domain, y_sampled_domain)
    
    if function.get_marker() != Function.Marker.NONE:
        for point in points:
            # Don't plot points outside domain upper and lower bounds!
            if point.position.y <= y_sampled_domain.lb and point.position.y >= y_sampled_domain.ub: 
                draw_function_point(point.position)

func sample(x_sampled_domain: Dictionary, y_sampled_domain: Dictionary) -> void:
    points = []
    points_positions = []
    var lower_bound: int = max(0, function.__x.size() - get_chart_properties().max_samples) \
    #disable sample display limits
        if get_chart_properties().max_samples > 0 \
        else 0
    for i in range(lower_bound, function.__x.size()):
        var _position: Vector2 = Vector2(
            ECUtilities._map_domain(float(function.__x[i]), x_domain, x_sampled_domain),
            ECUtilities._map_domain(float(function.__y[i]), y_domain, y_sampled_domain)
        )
        points.push_back(Point.new(_position, { x = function.__x[i], y = function.__y[i] }))
        points_positions.push_back(_position)

func draw_function_point(point_position: Vector2) -> void:
    match function.get_marker():
        Function.Marker.SQUARE:
            draw_rect(
                Rect2(point_position - (Vector2.ONE * point_size), (Vector2.ONE * point_size * 2)), 
                function.get_color(), true, 1.0
            )
        Function.Marker.TRIANGLE:
            draw_colored_polygon(
                PackedVector2Array([
                    point_position + (Vector2.UP * point_size * 1.3),
                    point_position + (Vector2.ONE * point_size * 1.3),
                    point_position - (Vector2(1, -1) * point_size * 1.3)
                ]), function.get_color(), [], null
            )
        Function.Marker.CROSS:
            draw_line(
                point_position - (Vector2.ONE * point_size),
                point_position + (Vector2.ONE * point_size),
                function.get_color(), point_size, true
            )
            draw_line(
                point_position + (Vector2(1, -1) * point_size),
                point_position + (Vector2(-1, 1) * point_size),
                function.get_color(), point_size / 2, true
            )
        Function.Marker.CIRCLE, _:
            draw_circle(point_position, point_size, function.get_color())

func _input(event: InputEvent) -> void:
    if event is InputEventMouse:
        for point in points:
            if Geometry2D.is_point_in_circle(get_relative_position(event.position), point.position, self.point_size * 4):
                if focused_point == point:
                    return
                else:
                    focused_point = point
                    emit_signal("point_entered", point, function)
                    return
        # Mouse is not in any point's box
        emit_signal("point_exited", focused_point, function)
        focused_point = null
