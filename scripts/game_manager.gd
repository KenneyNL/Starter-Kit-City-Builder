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
	
	# Use a direct file path for the music file to avoid any loading issues
	var music_path = "res://sounds/jazz_new_orleans.mp3"
	print("Loading music from path: " + music_path)
	
	# Try both direct preload and load for maximum compatibility
	var music = null
	
	# Try preload first - this ensures MP3 is pre-decoded
	print("Attempting to preload music file...")
	music = preload("res://sounds/jazz_new_orleans.mp3")
	
	# Log preload status
	if music:
		print("Music file preloaded successfully: " + str(music))
	else:
		print("Preload failed, falling back to regular load")
		music = load(music_path)
		if music:
			print("Music file loaded successfully via regular load: " + str(music))
		
	# Continue setup if we have the music file
	if music:
		# Double-check the import settings
		print("Music stream info - Class: " + str(music.get_class()))
		
		# Set looping on the AudioStreamMP3 itself
		if music is AudioStreamMP3:
			music.loop = true
			print("Set loop=true on AudioStreamMP3")
		else:
			print("Warning: Music is not AudioStreamMP3, it is " + str(music.get_class()))
		
		music_player.stream = music
		music_player.volume_db = 0  # Full volume for better web playback
		music_player.bus = "Music"  # Use the Music bus
		
		# Direct check of music bus
		var music_bus_idx = AudioServer.get_bus_index("Music")
		if music_bus_idx >= 0:
			print("Music bus found at index: " + str(music_bus_idx))
			# Force bus volume
			AudioServer.set_bus_volume_db(music_bus_idx, 0)
			AudioServer.set_bus_mute(music_bus_idx, false)
			print("Music bus volume set to: " + str(AudioServer.get_bus_volume_db(music_bus_idx)) + "dB")
		else:
			print("WARNING: Music bus not found!")
		
		# Check if we can play audio immediately (desktop) or need to wait (web)
		var can_play_now = true
		if OS.has_feature("web"):
			var sound_manager = get_node_or_null("/root/SoundManager")
			if sound_manager:
				can_play_now = sound_manager.audio_initialized
				print("Web build - audio initialized: " + str(can_play_now))
				
				# Force SoundManager settings
				sound_manager.music_volume = 1.0
				sound_manager.music_muted = false
				sound_manager._apply_music_volume()
				
				# If not initialized, connect to the ready signal
				if not can_play_now:
					sound_manager.audio_ready.connect(_start_background_music)
					print("Background music setup complete, waiting for user interaction")
		
		# Play immediately if allowed
		if can_play_now:
			_start_background_music()
	else:
		print("ERROR: Could not load background music from path: " + music_path)
		
		# Try a fallback sound as music
		print("Attempting to load fallback sound...")
		var fallback_sound = load("res://sounds/building_placing.wav")
		if fallback_sound:
			print("Loaded fallback sound")
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
				print("Playing fallback sound as music")
		else:
			print("Could not load fallback sound either")

# Start background music playing (called directly or via signal)
func _start_background_music():
	if music_player and music_player.stream and not music_player.playing:
		# For web builds, use a more aggressive approach to starting audio
		if OS.has_feature("web"):
			print("Starting background music (web build) - music player status before:")
			print("- Playing: " + str(music_player.playing))
			print("- Stream: " + str(music_player.stream))
			print("- Volume: " + str(music_player.volume_db))
			print("- Bus: " + str(music_player.bus))
			
			# Make sure we start from the beginning
			music_player.stop()
			music_player.seek(0.0)
			
			# Force the music to be audible - use even louder volume for web
			music_player.volume_db = 0  # Full volume for web
			music_player.bus = "Music"
			
			# Force all audio buses to be unmuted and at good volume
			# Master bus
			AudioServer.set_bus_mute(0, false)
			AudioServer.set_bus_volume_db(0, 0)  # Full volume for master
			
			# Music bus
			var music_bus_idx = AudioServer.get_bus_index("Music")
			if music_bus_idx >= 0:
				print("Music bus found at index: " + str(music_bus_idx))
				# Force unmute and good volume
				AudioServer.set_bus_mute(music_bus_idx, false) 
				AudioServer.set_bus_volume_db(music_bus_idx, 0)  # Set to maximum (0dB)
				print("- Music bus mute: " + str(AudioServer.is_bus_mute(music_bus_idx)))
				print("- Music bus volume: " + str(AudioServer.get_bus_volume_db(music_bus_idx)))
			else:
				print("WARNING: Music bus not found!")
				
			# Make sure sound manager settings aren't overriding
			var sound_manager = get_node_or_null("/root/SoundManager")
			if sound_manager:
				# Force good settings
				sound_manager.music_volume = 1.0
				sound_manager.music_muted = false
				sound_manager._apply_music_volume()
				print("SoundManager settings:")
				print("- Music volume: " + str(sound_manager.music_volume))
				print("- Music muted: " + str(sound_manager.music_muted))
			
			# Use JavaScript to directly ensure audio is unlocked and play a louder beep
			if Engine.has_singleton("JavaScriptBridge"):
				var js = Engine.get_singleton("JavaScriptBridge")
				var js_result = js.eval("""
				(function() {
					try {
						// Force audio context to resume
						if (window._godotAudioContext) {
							console.log('GameManager: Current audio context state:', window._godotAudioContext.state);
							if (window._godotAudioContext.state === 'suspended') {
								console.log('GameManager: Forcing audio context resume before music');
								window._godotAudioContext.resume();
							}
							
							// Play a quick sound to kickstart audio with higher volume
							var oscillator = window._godotAudioContext.createOscillator();
							var gainNode = window._godotAudioContext.createGain();
							gainNode.gain.value = 0.3; // More audible beep
							oscillator.connect(gainNode);
							gainNode.connect(window._godotAudioContext.destination);
							oscillator.frequency.value = 440; // A4 note
							oscillator.start(0);
							oscillator.stop(0.3); // Longer beep
							
							// Play a second tone with different frequency after a short delay
							setTimeout(function() {
								var oscillator2 = window._godotAudioContext.createOscillator();
								var gainNode2 = window._godotAudioContext.createGain();
								gainNode2.gain.value = 0.3;
								oscillator2.connect(gainNode2);
								gainNode2.connect(window._godotAudioContext.destination);
								oscillator2.frequency.value = 880; // One octave higher
								oscillator2.start(0);
								oscillator2.stop(0.3);
							}, 400);
							
							// Attempt to find audio elements and manipulate them directly
							var audioElements = document.querySelectorAll('audio');
							console.log('Found', audioElements.length, 'audio elements');
							audioElements.forEach(function(audio, index) {
								console.log('Audio element', index, 'volume:', audio.volume, 'muted:', audio.muted);
								// Set volume to maximum
								audio.volume = 1.0;
								audio.muted = false;
								audio.play().catch(function(e) {
									console.log('Could not autoplay audio element:', e);
								});
							});
							
							return window._godotAudioContext.state;
						} else {
							console.log('GameManager: No audio context found!');
							return "no_context";
						}
					} catch(e) {
						console.error('GameManager: Error resuming audio context:', e);
						return "error: " + e.message;
					}
				})()
				""")
				print("JavaScript audio context state: " + str(js_result))
			
			# Initial play attempt - with higher volume
			music_player.volume_db = 0  # Maximum volume
			music_player.play()
			print("Playing background music NOW (web build)")
			
			# Schedule multiple retries with increasing volume
			_retry_audio_playback()
		else:
			# Standard approach for desktop builds
			music_player.play()
			print("Started playing background music")
			
# New function to retry all audio in web builds
func _retry_audio_playback():
	if not OS.has_feature("web"):
		return
		
	# Create a timer to retry audio multiple times
	var retry_timer = Timer.new()
	retry_timer.name = "AudioRetryTimer"
	retry_timer.wait_time = 1.0
	retry_timer.one_shot = false
	add_child(retry_timer)
	
	# Counter for retry attempts
	var retry_count = 0
	var max_retries = 10  # Increased retries
	
	# Connect retry function to timer
	retry_timer.timeout.connect(func():
		retry_count += 1
		print("Audio retry attempt " + str(retry_count) + "/" + str(max_retries))
		
		# Stop after max retries
		if retry_count >= max_retries:
			retry_timer.stop()
			retry_timer.queue_free()
			return
		
		# Try to unlock audio with JavaScript on every retry
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			var js_result = js.eval("""
			(function() {
				try {
					if (window._godotAudioContext) {
						console.log('Retry attempt ' + %d + ': Audio context state:', window._godotAudioContext.state);
						window._godotAudioContext.resume();
						
						// Try different audio approaches on different retries
						var freq = 440 * (1 + (%d * 0.1));
						var osc = window._godotAudioContext.createOscillator();
						var gain = window._godotAudioContext.createGain();
						gain.gain.value = 0.25;
						osc.frequency.value = freq;
						osc.connect(gain);
						gain.connect(window._godotAudioContext.destination);
						osc.start();
						osc.stop(0.3);
						
						// Find HTML audio elements and try to manipulate them directly
						var audioElements = document.querySelectorAll('audio');
						console.log('Found', audioElements.length, 'audio elements on retry attempt');
						audioElements.forEach(function(audio, index) {
							audio.volume = 1.0;
							audio.muted = false;
							audio.play().catch(function(e) {});
						});
						
						return window._godotAudioContext.state;
					} else {
						return "no_context";
					}
				} catch(e) {
					console.error('Error in retry JS:', e);
					return "error";
				}
			})();
			""" % [retry_count, retry_count])
			print("JavaScript audio retry result (" + str(retry_count) + "): " + str(js_result))
		
		# Try to restart all audio players
		if music_player and music_player.stream:
			# Always keep volume at maximum for retries
			music_player.volume_db = 0
			
			# Ensure music bus is also at maximum
			var music_bus_idx = AudioServer.get_bus_index("Music")
			if music_bus_idx >= 0:
				AudioServer.set_bus_mute(music_bus_idx, false)
				AudioServer.set_bus_volume_db(music_bus_idx, 0)  # Full volume
			
			# On some attempts, try reloading the music
			if retry_count % 3 == 0:  # Every 3rd retry
				print("Attempting to reload music file on retry " + str(retry_count))
				var reloaded_music = load("res://sounds/jazz_new_orleans.mp3")
				if reloaded_music:
					print("Reloaded music successfully")
					if reloaded_music is AudioStreamMP3:
						reloaded_music.loop = true
					music_player.stream = reloaded_music
			
			# Force play again
			music_player.stop()
			music_player.play()
			print("Retrying music playback with maximum volume")
			
			# Try playing a simpler sound on alternate attempts
			if retry_count % 2 == 0:  # Every 2nd retry
				print("Trying alternate sound on retry " + str(retry_count))
				var alt_player = AudioStreamPlayer.new()
				add_child(alt_player)
				alt_player.name = "AltAudioTest" + str(retry_count)
				var alt_sound = load("res://sounds/building_placing.wav")
				if alt_sound:
					alt_player.stream = alt_sound
					alt_player.volume_db = 0
					alt_player.bus = "Music"
					alt_player.play()
					# This player will clean itself up after playing
					alt_player.finished.connect(func(): alt_player.queue_free())
	)
	
	# Start the timer
	retry_timer.start()
	
# Helper function to retry music playback for web builds
func _retry_individual_audio_play(player: AudioStreamPlayer, attempt: int, max_attempts: int):
	if !player.playing and attempt < max_attempts:
		print("Retrying individual audio playback, attempt %d/%d" % [attempt, max_attempts])
		
		# Force set volume and unmute
		player.volume_db = -5 + (attempt * 2)  # Increase volume with each attempt
		
		# For the bus
		var music_bus_idx = AudioServer.get_bus_index("Music")
		if music_bus_idx >= 0:
			AudioServer.set_bus_mute(music_bus_idx, false)
			AudioServer.set_bus_volume_db(music_bus_idx, -5 + (attempt * 2))
			print("Music bus volume set to " + str(AudioServer.get_bus_volume_db(music_bus_idx)) + "dB")
		
		# Try to play again
		player.play()
		
		# Schedule another retry if needed
		if attempt < max_attempts - 1:
			get_tree().create_timer(0.6).timeout.connect(
				Callable(self, "_retry_individual_audio_play").bind(player, attempt + 1, max_attempts)
			)
		
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
	
# Removed duplicate _retry_music_play function that was here
	
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
