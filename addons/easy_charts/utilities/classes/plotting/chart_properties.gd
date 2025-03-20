extends RefCounted
class_name ChartProperties

var title: String
var x_label: String
var y_label: String

## {n}_scale defines in how many sectors the grid will be divided.
var x_scale: float = 5.0
var y_scale: float = 2.0

var x_tick_size: float = 7
var x_ticklabel_space: float = 5
var y_tick_size: float = 7
var y_ticklabel_space: float = 5

## Scale type, 0 = linear | 1 = logarithmic
var x_scale_type: int = 0
var y_scale_type: int = 0

var draw_borders: bool = true
var draw_frame: bool = true
var draw_background: bool = true
var draw_bounding_box: bool = true
var draw_vertical_grid: bool = true
var draw_horizontal_grid: bool = true
var draw_ticks: bool = true
var draw_origin: bool = false
var draw_grid_box: bool = true 
var show_tick_labels: bool = true
var show_x_label: bool = true
var show_y_label: bool = true
var show_title: bool = true

## If true will show the legend of your Chart on the right side of the frame.
var show_legend: bool = false

## If true will make the Chart interactive, i.e. the DataTooltip will be displayed when 
## hovering points with your mouse, and mouse_entered and mouse_exited signal will be emitted.
var interactive: bool = false

## If true, will smooth the domain lower and upper bounds to the closest rounded value,
## instead of using precise values.
var smooth_domain: bool = false

## If > 0, will limit the amount of points plotted in a Chart, discarding older values.
## [b]Note:[/b] this parameter will not make the Chart remove points from your Function objects,
## instead older points will be just ignored. This will make your Function object x and y arrays 
## grow linearly, but won't interfere with your own data.
## If you instead prefer to improve performances by completely remove older data from your Function
## object, consider calling the Function.remove_point(0) method before adding a new point and plotting
## again.
var max_samples: int = 100

## Dictionary of colors for all of the Chart elements.
var colors: Dictionary = {
    frame = Color.WHITE_SMOKE,
    background = Color.WHITE,
    borders = Color.RED,
    bounding_box = Color.BLACK,
    grid = Color.GRAY,
    ticks = Color.BLACK,
    text = Color.BLACK,
    origin = Color.DIM_GRAY
}

var font: FontFile = load("res://addons/easy_charts/utilities/assets/OpenSans-VariableFont_wdth,wght.ttf")
var font_size: int = 13

func _init() -> void:
    ThemeDB.set_fallback_font(font)
    ThemeDB.set_fallback_font_size(font_size)

func get_string_size(text: String) -> Vector2:
    return font.get_string_size(text)
