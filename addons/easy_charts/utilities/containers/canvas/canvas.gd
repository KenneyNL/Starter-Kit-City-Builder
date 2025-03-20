extends Control
class_name Canvas

@onready var _title_lbl: Label = $CanvasContainer/Title
@onready var _x_lbl: Label = $CanvasContainer/DataContainer/PlotContainer/XLabel
@onready var _y_lbl: Label = $CanvasContainer/DataContainer/YLabel
@onready var _legend: FunctionLegend = $CanvasContainer/DataContainer/FunctionLegend

func _ready():
    pass # Replace with function body.

func prepare_canvas(chart_properties: ChartProperties) -> void:
    
    if chart_properties.draw_frame:
        set_color(chart_properties.colors.frame)
        set_frame_visible(true)
    else:
        set_frame_visible(false)
    
    if chart_properties.show_title:
        update_title(chart_properties.title, chart_properties.colors.text)
    else:
        _title_lbl.hide()
    
    if chart_properties.show_x_label:
        update_x_label(chart_properties.x_label, chart_properties.colors.text)
    else:
        _x_lbl.hide()
    
    if chart_properties.show_y_label:
        update_y_label(chart_properties.y_label, chart_properties.colors.text, -90)
    else:
        _y_lbl.hide()
    
    if chart_properties.show_legend:
        _legend.show()
    else:
        hide_legend()

func update_title(text: String, color: Color, rotation: float = 0.0) -> void:
    _title_lbl.show()
    _update_canvas_label(_title_lbl, text, color, rotation)

func update_y_label(text: String, color: Color, rotation: float = 0.0) -> void:
    _y_lbl.show()
    _update_canvas_label(_y_lbl, text, color, rotation)

func update_x_label(text: String, color: Color, rotation: float = 0.0) -> void:
    _x_lbl.show()
    _update_canvas_label(_x_lbl, text, color, rotation)

func _update_canvas_label(canvas_label: Label, text: String, color: Color, rotation: float = 0.0) -> void:
    canvas_label.set_text(text)
    canvas_label.modulate = color
    canvas_label.rotation = rotation

func hide_legend() -> void:
    _legend.hide()

func set_color(color: Color) -> void:
    get("theme_override_styles/panel").set("bg_color", color)

func set_frame_visible(visible: bool) -> void:
    get("theme_override_styles/panel").set("draw_center", visible)
