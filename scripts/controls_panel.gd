extends PanelContainer

signal closed

func _ready():
	# Hide the panel initially - it will be shown when the game starts
	# or when the question mark button is clicked
	visible = false
	
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

func _on_close_button_pressed():
	hide_panel()
	# Emit signal that panel was closed
	closed.emit()
	
	# Consume the event to prevent click-through
	get_viewport().set_input_as_handled()