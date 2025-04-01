extends Node

# This script handles overall game management tasks

func _ready():
	# Reference to the controls panel and HUD
	var controls_panel = $CanvasLayer/ControlsPanel
	var hud = $CanvasLayer/HUD
	
	# Set up the HUD's reference to the controls panel
	hud.controls_panel = controls_panel
	
	# Auto-show controls at start
	if controls_panel:
		controls_panel.show_panel()
		
		# Connect the closed signal to handle when player closes the controls
		controls_panel.closed.connect(_on_controls_panel_closed)

# This function is called when the controls panel is closed
func _on_controls_panel_closed():
	print("Controls panel closed by player")