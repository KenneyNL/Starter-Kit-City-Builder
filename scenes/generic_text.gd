extends PanelContainer

signal closed

@export var resource_data:GenericText

@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var body_label = $MarginContainer/VBoxContainer/ScrollContainer/ControlsGrid/VBoxContainer/BodyText
@onready var close_button = $MarginContainer/VBoxContainer/CloseButtonContainer/CloseButton

func _ready():
	# Hide the panel initially - it will be shown when the game starts
	# or when the question mark button is clicked
	visible = false
	
	if resource_data:
		apply_resource_data(resource_data)
	
	# Make sure this control blocks mouse input from passing through
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_panel():
	visible = true
	# Pause the game (optional, depending on desired behavior)
	get_tree().paused = true

func hide_panel():
	visible = false
	# Resume the game
	get_tree().paused = false

func apply_resource_data(data:GenericText):
	if data:
		resource_data = data
		title_label.text = data.title
		body_label.text = data.body_text
		close_button.text = data.button_text

func _on_close_button_pressed():
	hide_panel()
	# Emit signal that panel was closed
	closed.emit()
	
	# Consume the event to prevent click-through
	get_viewport().set_input_as_handled()
