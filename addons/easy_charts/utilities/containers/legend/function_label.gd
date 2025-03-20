extends HBoxContainer
class_name FunctionLabel

@onready var type_lbl: FunctionTypeLabel = $FunctionType
@onready var name_lbl: Label = $FunctionName

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init_label(function: Function) -> void:
	type_lbl.type = function.get_type()
	type_lbl.color = function.get_color()
	type_lbl.marker = function.get_marker()
	name_lbl.set_text(function.name)
	name_lbl.set("theme_override_colors/font_color", get_parent().chart_properties.colors.text)

func init_clabel(type: int, color: Color, marker: int, name: String) -> void:
	type_lbl.type = type
	type_lbl.color = color
	type_lbl.marker = marker
	name_lbl.set_text(name)
	name_lbl.set("theme_override_colors/font_color", get_parent().chart_properties.colors.text)
