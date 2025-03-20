extends RefCounted
class_name Function

enum Type {
    SCATTER,
    LINE,
    AREA,
    PIE,
    BAR
}

enum Interpolation {
    NONE,
    LINEAR,
    STAIR,
    SPLINE
}

# TODO: add new markers, like an empty circle, an empty box, etc.
enum Marker {
    NONE,
    CIRCLE,
    TRIANGLE,
    SQUARE,
    CROSS
}

var __x: Array
var __y: Array
var name: String
var props: Dictionary = {}

func _init(x: Array, y: Array, name: String = "", props: Dictionary = {}) -> void:
    self.__x = x.duplicate()
    self.__y = y.duplicate()
    self.name = name
    if not props.is_empty() and props != null:
        self.props = props

func get_point(index: int) -> Array:
    return [self.__x[index], self.__y[index]]

func add_point(x: float, y: float) -> void:
    self.__x.append(x)
    self.__y.append(y)

func set_point(index: int, x: float, y: float) -> void:
    self.__x[index] = x
    self.__y[index] = y

func remove_point(index: int) -> void:
    self.__x.remove_at(index)
    self.__y.remove_at(index)

func pop_back_point() -> void:
    self.__x.pop_back()
    self.__y.pop_back()

func pop_front_point() -> void:
    self.__x.pop_front()
    self.__y.pop_front()

func count_points() -> int:
    return self.__x.size()

func get_color() -> Color:
    return props.get("color", Color.DARK_SLATE_GRAY)

func get_gradient() -> Gradient:
    return props.get("gradient", Gradient.new())

func get_marker() -> int:
    return props.get("marker", Marker.NONE)

func get_type() -> int:
    return props.get("type", Type.SCATTER)

func get_interpolation() -> int:
    return props.get("interpolation", Interpolation.LINEAR)

func get_line_width() -> float:
    return props.get("line_width", 2.0)

func get_visibility() -> bool:
    return props.get("visible", true)

func copy() -> Function:
    return Function.new(
        self.__x.duplicate(),
        self.__y.duplicate(),
        self.name,
        self.props.duplicate(true)
    )
