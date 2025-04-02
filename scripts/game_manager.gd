extends Node

# This script handles overall game management tasks

var music_player: AudioStreamPlayer
var building_sfx: AudioStreamPlayer

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
	
	# Set up audio
	setup_background_music()
	setup_building_sfx()
	
	# Find the builder and connect to it
	var builder = get_node_or_null("/root/Main/Builder")
	if builder:
		builder.structure_placed.connect(_on_structure_placed)

# This function is called when the controls panel is closed
func _on_controls_panel_closed():
	print("Controls panel closed by player")
	
# Setup background music player
func setup_background_music():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	var music = load("res://sounds/jazz_new_orleans.mp3") 
	if music:
		music_player.stream = music
		music_player.volume_db = -12  # 25% volume (approx)
		music_player.play()
		print("Playing background music: jazz_new_orleans.mp3")
	else:
		print("ERROR: Could not load background music")
		
# Setup building sound effects
func setup_building_sfx():
	building_sfx = AudioStreamPlayer.new()
	add_child(building_sfx)
	
	var sfx = load("res://sounds/building_placing.wav")
	if sfx:
		building_sfx.stream = sfx
		building_sfx.volume_db = -5
		print("Building placement SFX loaded successfully")
	else:
		print("ERROR: Could not load building placement SFX")
		
# Play the building sound effect when a structure is placed
func _on_structure_placed(structure_index, position):
	if building_sfx and building_sfx.stream:
		if building_sfx.playing:
			building_sfx.stop()
		building_sfx.play()
		print("Playing building placement SFX")
