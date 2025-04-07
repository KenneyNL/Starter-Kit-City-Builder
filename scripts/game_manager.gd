extends Node

# This script handles overall game management tasks

var music_player: AudioStreamPlayer
var building_sfx: AudioStreamPlayer
var construction_sfx: AudioStreamPlayer

func _ready():
	# Reference to the controls panel, sound panel, and HUD
	var controls_panel = $CanvasLayer/ControlsPanel
	var sound_panel = $CanvasLayer/SoundPanel
	var hud = $CanvasLayer/HUD
	
	# Set up the HUD's reference to the panels
	hud.controls_panel = controls_panel
	hud.sound_panel = sound_panel
	
	# Auto-show controls at start
	if controls_panel:
		controls_panel.show_panel()
		
		# Connect the closed signal to handle when player closes the controls
		controls_panel.closed.connect(_on_controls_panel_closed)
	
	# Check for audio initialization status (important for web)
	var sound_manager = get_node_or_null("/root/SoundManager")
	var can_initialize_audio = true
	
	if OS.has_feature("web") and sound_manager:
		can_initialize_audio = sound_manager.audio_initialized
		
		if not can_initialize_audio:
			# For web, wait for the audio_ready signal before initializing audio
			sound_manager.audio_ready.connect(_initialize_game_audio)
			print("Web platform detected: Deferring audio setup until user interaction")
	
	# Set up audio if allowed (immediate for desktop, after interaction for web)
	if can_initialize_audio:
		_initialize_game_audio()
	
	# Find the builder and connect to it
	var builder = get_node_or_null("/root/Main/Builder")
	if builder:
		builder.structure_placed.connect(_on_structure_placed)
		
	# Connect to construction signals via deferred call to make sure everything is ready
	call_deferred("_setup_construction_signals")
	
	# Make sure sound buses are properly configured
	call_deferred("_setup_sound_buses")

# Initialize all game audio - called immediately on desktop, after user interaction on web
func _initialize_game_audio():
	print("Initializing all game audio...")
	
	# Set up all audio systems
	setup_background_music()
	setup_building_sfx()
	setup_construction_sfx()
	
	print("All game audio initialized successfully")

# This function is called when the controls panel is closed
func _on_controls_panel_closed():
	print("Controls panel closed by player")
	
# Function to set up the sound buses
func _setup_sound_buses():
	# Wait a moment to ensure SoundManager is ready
	await get_tree().process_frame
	
	# Get reference to SoundManager singleton
	var sound_manager = get_node_or_null("/root/SoundManager")
	if !sound_manager:
		print("ERROR: SoundManager singleton not found!")
		return
	
	# Move audio players to the appropriate buses
	if music_player:
		music_player.bus = "Music"
	
	if building_sfx:
		building_sfx.bus = "SFX"
	
	if construction_sfx:
		construction_sfx.bus = "SFX"
	
	print("Sound buses configured successfully")

# Setup background music player
func setup_background_music():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Set this to make the music player ignore the game tree's pause state
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var music = load("res://sounds/jazz_new_orleans.mp3") 
	if music:
		# Set looping on the AudioStreamMP3 itself
		if music is AudioStreamMP3:
			music.loop = true
		
		music_player.stream = music
		music_player.volume_db = -12  # 25% volume (approx)
		music_player.bus = "Music"  # Use the Music bus
		
		# Check if we can play audio immediately (desktop) or need to wait (web)
		var can_play_now = true
		if OS.has_feature("web"):
			var sound_manager = get_node_or_null("/root/SoundManager")
			if sound_manager:
				can_play_now = sound_manager.audio_initialized
				
				# If not initialized, connect to the ready signal
				if not can_play_now:
					sound_manager.audio_ready.connect(_start_background_music)
					print("Background music setup complete, waiting for user interaction")
		
		# Play immediately if allowed
		if can_play_now:
			_start_background_music()
	else:
		print("ERROR: Could not load background music")

# Start background music playing (called directly or via signal)
func _start_background_music():
	if music_player and music_player.stream and not music_player.playing:
		# For web builds, use a more aggressive approach to starting audio
		if OS.has_feature("web"):
			# Make sure the sound is playing from the beginning
			music_player.stop()
			music_player.seek(0.0)
			
			# Force the music to be audible
			music_player.volume_db = -12  # Original volume
			music_player.bus = "Music"
			
			# Make sure the bus isn't muted
			var sound_manager = get_node_or_null("/root/SoundManager")
			if sound_manager:
				sound_manager._apply_music_volume()
				
			# Play with a slight delay for better browser compatibility
			get_tree().create_timer(0.1).timeout.connect(func(): 
				music_player.play()
				print("Started playing background music (web build)")
			)
		else:
			# Standard approach for desktop builds
			music_player.play()
			print("Started playing background music")
		
# Setup building sound effects
func setup_building_sfx():
	building_sfx = AudioStreamPlayer.new()
	add_child(building_sfx)
	
	# Set this to make the sound effects player ignore the game tree's pause state
	building_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var sfx = load("res://sounds/building_placing.wav")
	if sfx:
		building_sfx.stream = sfx
		building_sfx.volume_db = -5
		building_sfx.bus = "SFX"  # Use the SFX bus
		print("Building placement SFX loaded successfully")
	else:
		print("ERROR: Could not load building placement SFX")
		
# Setup construction sound effects
# Note: Now mainly used for backward compatibility
# Individual workers handle their own construction sounds
func setup_construction_sfx():
	construction_sfx = AudioStreamPlayer.new()
	add_child(construction_sfx)
	
	# Set this to make the sound effects player ignore the game tree's pause state
	construction_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var sfx = load("res://sounds/construction.wav")
	if sfx:
		construction_sfx.stream = sfx
		construction_sfx.volume_db = -8  # Reduced volume since workers have their own sounds
		construction_sfx.bus = "SFX"  # Use the SFX bus
		print("Main construction SFX loaded (for backward compatibility)")
	else:
		print("ERROR: Could not load construction SFX")
		
# Play the building sound effect when a structure is placed
func _on_structure_placed(structure_index, position):
	# Check web audio initialized status if needed
	var can_play_audio = true
	if OS.has_feature("web"):
		var sound_manager = get_node_or_null("/root/SoundManager")
		if sound_manager:
			can_play_audio = sound_manager.audio_initialized
	
	# Only play if audio is initialized (always true on desktop, depends on user interaction for web)
	if can_play_audio and building_sfx and building_sfx.stream:
		if building_sfx.playing:
			building_sfx.stop()
		building_sfx.play()
		print("Playing building placement SFX")
	elif OS.has_feature("web"):
		print("Structure placed but audio not yet initialized")
	
# Variables for construction sound looping
var construction_active = false
var construction_sound_timer = null

# These functions remain for backward compatibility with mission logic
# but they don't actually play sounds anymore since workers handle their own sounds

# Compatibility function for mission triggers
func play_construction_sound():
	print("GAME MANAGER: Received construction_started signal (for compatibility only)")
	# We don't play any sounds from here anymore - workers handle their own sounds
	# but we need to keep this function for backward compatibility
	
# Compatibility function for mission triggers  
func _loop_construction_sound():
	# This function exists only for backward compatibility
	pass
	
# Compatibility function for mission triggers
func stop_construction_sound():
	print("GAME MANAGER: Received construction_ended signal (for compatibility only)")
	# We don't stop any sounds from here anymore - workers handle their own sounds
	# but we need to keep this function for backward compatibility
	
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
