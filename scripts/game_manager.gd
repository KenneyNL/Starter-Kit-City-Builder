extends Node

# This script handles overall game management tasks

var music_player: AudioStreamPlayer
var building_sfx: AudioStreamPlayer
var construction_sfx: AudioStreamPlayer

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
	setup_construction_sfx()
	
	# Find the builder and connect to it
	var builder = get_node_or_null("/root/Main/Builder")
	if builder:
		builder.structure_placed.connect(_on_structure_placed)
		
	# Connect to construction signals via deferred call to make sure everything is ready
	call_deferred("_setup_construction_signals")

# This function is called when the controls panel is closed
func _on_controls_panel_closed():
	print("Controls panel closed by player")
	
# Setup background music player
func setup_background_music():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	var music = load("res://sounds/jazz_new_orleans.mp3") 
	if music:
		# Set looping on the AudioStreamMP3 itself
		if music is AudioStreamMP3:
			music.loop = true
		
		music_player.stream = music
		music_player.volume_db = -12  # 25% volume (approx)
#		music_player.play()
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
		
# Setup construction sound effects
func setup_construction_sfx():
	construction_sfx = AudioStreamPlayer.new()
	add_child(construction_sfx)
	
	var sfx = load("res://sounds/construction.wav")
	if sfx:
		construction_sfx.stream = sfx
		construction_sfx.volume_db = -5  # Louder volume
		print("Construction SFX loaded successfully")
	else:
		print("ERROR: Could not load construction SFX")
		
# Play the building sound effect when a structure is placed
func _on_structure_placed(structure_index, position):
	if building_sfx and building_sfx.stream:
		if building_sfx.playing:
			building_sfx.stop()
		building_sfx.play()
		print("Playing building placement SFX")
	
# Variables for construction sound looping
var construction_active = false
var construction_sound_timer = null

# Play construction sound (called by construction worker)
func play_construction_sound():
	print("GAME MANAGER: Received signal to play construction sound")
	if construction_sfx and construction_sfx.stream:
		construction_active = true
		
		# Create a timer for looping the sound if it doesn't exist
		if not construction_sound_timer:
			construction_sound_timer = Timer.new()
			construction_sound_timer.name = "ConstructionSoundTimer"
			construction_sound_timer.wait_time = 1.95  # Slightly less than the sound duration to avoid gaps
			construction_sound_timer.autostart = false
			construction_sound_timer.one_shot = false
			add_child(construction_sound_timer)
			construction_sound_timer.timeout.connect(_loop_construction_sound)
		
		# Start the sound and the loop timer
		construction_sfx.play()
		construction_sound_timer.start()
		print("GAME MANAGER: Playing construction sound effect with looping")
	else:
		print("GAME MANAGER: Construction sound effect not properly loaded or initialized")

# Function to loop the construction sound
func _loop_construction_sound():
	if construction_active and construction_sfx and construction_sfx.stream:
		construction_sfx.play()
		print("GAME MANAGER: Looping construction sound")
	
# Stop construction sound (called when construction finishes)
func stop_construction_sound():
	construction_active = false
	
	if construction_sound_timer:
		construction_sound_timer.stop()
	
	if construction_sfx and construction_sfx.playing:
		construction_sfx.stop()
		print("GAME MANAGER: Stopped construction sound effect")
	
# Setup construction signals properly
func _setup_construction_signals():
	print("GAME MANAGER DELAYED: Attempting to find construction manager")
	var builder = get_node_or_null("/root/Main/Builder")
	print("GAME MANAGER DELAYED: Found builder:", builder)
	
	if builder and builder.has_method("get") and builder.get("construction_manager"):
		var construction_manager = builder.construction_manager
		print("GAME MANAGER DELAYED: Construction manager found:", construction_manager)
		
		if construction_manager:
			# Disconnect any existing connections first to avoid duplicates
			if construction_manager.worker_construction_started.is_connected(play_construction_sound):
				construction_manager.worker_construction_started.disconnect(play_construction_sound)
			
			if construction_manager.worker_construction_ended.is_connected(stop_construction_sound):
				construction_manager.worker_construction_ended.disconnect(stop_construction_sound)
			
			# Connect signals
			construction_manager.worker_construction_started.connect(play_construction_sound)
			construction_manager.worker_construction_ended.connect(stop_construction_sound)
			print("GAME MANAGER DELAYED: Connected to construction manager signals")
		else:
			print("GAME MANAGER DELAYED: Construction manager is null")
	else:
		print("GAME MANAGER DELAYED: Builder doesn't have construction_manager property")	
