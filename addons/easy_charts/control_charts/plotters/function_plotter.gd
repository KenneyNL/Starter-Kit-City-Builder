extends Control
class_name FunctionPlotter

var function: Function
var x_domain: Dictionary
var y_domain: Dictionary

func _init(function: Function) -> void:
    self.function = function

func _ready() -> void:
    set_process_input(get_chart_properties().interactive)

func update_values(x_domain: Dictionary, y_domain: Dictionary) -> void:
    self.visible = self.function.get_visibility()
    if not self.function.get_visibility():
        return
    self.x_domain = x_domain
    self.y_domain = y_domain
    queue_redraw()

func _draw() -> void:
    return

func get_box() -> Rect2:
    return get_parent().get_parent().get_plot_box()

func get_chart_properties() -> ChartProperties:
    return get_parent().get_parent().chart_properties

func get_relative_position(position: Vector2) -> Vector2:
    return position - global_position
