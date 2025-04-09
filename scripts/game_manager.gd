extends Node

# This script handles overall game management tasks

var music_player: AudioStreamPlayer
var building_sfx: AudioStreamPlayer
var construction_sfx: AudioStreamPlayer

func _ready():
	# Register SoundManager in the main loop for JavaScript bridge to find
	Engine.get_main_loop().set_meta("sound_manager", get_node_or_null("/root/SoundManager"))
	
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
	# Set up all audio systems
	setup_background_music()
	setup_building_sfx()
	setup_construction_sfx()

# This function is called when the controls panel is closed
func _on_controls_panel_closed():
	# This is the perfect place to initialize audio for web builds
	# since we know the user has interacted with the game
	if OS.has_feature("web"):
		# Force initialize the sound manager (will have no effect if already initialized)
		var sound_manager = get_node_or_null("/root/SoundManager")
		if sound_manager and not sound_manager.audio_initialized:
			sound_manager._initialize_web_audio()
		
		# Make sure our music is playing
		if music_player and music_player.stream and not music_player.playing:
			music_player.play()

# Function to set up the sound buses
func _setup_sound_buses():
	# Wait a moment to ensure SoundManager is ready
	await get_tree().process_frame
	
	# Get reference to SoundManager singleton
	var sound_manager = get_node_or_null("/root/SoundManager")
	if !sound_manager:
		return
	
	# Move audio players to the appropriate buses
	if music_player:
		music_player.bus = "Music"
	
	if building_sfx:
		building_sfx.bus = "SFX"
	
	if construction_sfx:
		construction_sfx.bus = "SFX"

# Setup background music player
func setup_background_music():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Set this to make the music player ignore the game tree's pause state
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Use a direct file path for the music file to avoid any loading issues
	var music_path = "res://sounds/jazz_new_orleans.mp3"
	
	# Try both direct preload and load for maximum compatibility
	var music = null
	
	# Try preload first - this ensures MP3 is pre-decoded
	music = preload("res://sounds/jazz_new_orleans.mp3")
	
	# If preload failed, try regular load
	if !music:
		music = load(music_path)
		
	# Continue setup if we have the music file
	if music:
		# Set looping on the AudioStreamMP3 itself
		if music is AudioStreamMP3:
			music.loop = true
		
		music_player.stream = music
		music_player.volume_db = 0  # Full volume for better web playback
		music_player.bus = "Music"  # Use the Music bus
		
		# Direct check of music bus
		var music_bus_idx = AudioServer.get_bus_index("Music")
		if music_bus_idx >= 0:
			# Force bus volume
			AudioServer.set_bus_volume_db(music_bus_idx, 0)
			AudioServer.set_bus_mute(music_bus_idx, false)
		
		# Check if we can play audio immediately (desktop) or need to wait (web)
		var can_play_now = true
		if OS.has_feature("web"):
			var sound_manager = get_node_or_null("/root/SoundManager")
			if sound_manager:
				can_play_now = sound_manager.audio_initialized
				
				# Force SoundManager settings
				sound_manager.music_volume = 1.0
				sound_manager.music_muted = false
				sound_manager._apply_music_volume()
				
				# If not initialized, connect to the ready signal
				if not can_play_now:
					sound_manager.audio_ready.connect(_start_background_music)
		
		# Play immediately if allowed
		if can_play_now:
			_start_background_music()
	else:
		# Try a fallback sound as music
		var fallback_sound = load("res://sounds/building_placing.wav")
		if fallback_sound:
			music_player.stream = fallback_sound
			music_player.volume_db = 0
			music_player.bus = "Music"
			
			# Check if we can play immediately
			var can_play_now = true
			if OS.has_feature("web"):
				var sound_manager = get_node_or_null("/root/SoundManager")
				if sound_manager:
					can_play_now = sound_manager.audio_initialized
			
			if can_play_now:
				music_player.play()

# Start background music playing (called directly or via signal)
func _start_background_music():
	if music_player and music_player.stream and not music_player.playing:
		# For web builds, use a simple approach to starting audio
		if OS.has_feature("web"):
			# Make sure we start from the beginning
			music_player.stop()
			music_player.seek(0.0)
			
			# Set reasonable volume
			music_player.volume_db = -10  # Normal volume for web
			music_player.bus = "Music" 
			
			# Make sure buses are unmuted
			AudioServer.set_bus_mute(0, false) # Master
			
			# Music bus
			var music_bus_idx = AudioServer.get_bus_index("Music")
			if music_bus_idx >= 0:
				AudioServer.set_bus_mute(music_bus_idx, false)
			
			# Play the music
			music_player.play()
			
			# Simple JavaScript to ensure audio context is running
			if Engine.has_singleton("JavaScriptBridge"):
				var js = Engine.get_singleton("JavaScriptBridge")
				js.eval("""
				(function() {
					try {
						if (window._godotAudioContext && window._godotAudioContext.state === 'suspended') {
							console.log('GameManager: Resuming audio context');
							window._godotAudioContext.resume();
						}
					} catch(e) {
						console.error('GameManager: Error in audio context check:', e);
					}
				})()
				""")
		else:
			# Standard approach for desktop builds
			music_player.play()
			
# This retry audio function has been removed in favor of the simpler approach
	
# This helper has been removed in favor of a simpler approach
		
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

# Variables for construction sound looping
var construction_active = false
var construction_sound_timer = null

# These functions remain for backward compatibility with mission logic
# but they don't actually play sounds anymore since workers handle their own sounds

# Compatibility function for mission triggers
func play_construction_sound():
	# We don't play any sounds from here anymore - workers handle their own sounds
	# but we need to keep this function for backward compatibility
	pass
	
# Compatibility function for mission triggers  
func _loop_construction_sound():
	# This function exists only for backward compatibility
	pass
	
# Compatibility function for mission triggers
func stop_construction_sound():
	# We don't stop any sounds from here anymore - workers handle their own sounds
	# but we need to keep this function for backward compatibility
	pass
	
# Removed duplicate _retry_music_play function that was here
	
# Setup construction signals properly
func _setup_construction_signals():
	var builder = get_node_or_null("/root/Main/Builder")
	
	if builder and builder.has_method("get") and builder.get("construction_manager"):
		var construction_manager = builder.construction_manager
		
		if construction_manager:
			# Disconnect any existing connections first to avoid duplicates
			if construction_manager.worker_construction_started.is_connected(play_construction_sound):
				construction_manager.worker_construction_started.disconnect(play_construction_sound)
			
			if construction_manager.worker_construction_ended.is_connected(stop_construction_sound):
				construction_manager.worker_construction_ended.disconnect(stop_construction_sound)
			
			# Connect signals
			construction_manager.worker_construction_started.connect(play_construction_sound)
			construction_manager.worker_construction_ended.connect(stop_construction_sound)
