extends Node

signal music_volume_changed(new_volume)
signal sfx_volume_changed(new_volume)
signal music_muted_changed(is_muted)
signal sfx_muted_changed(is_muted)
signal audio_ready # Signal emitted when audio is initialized (important for web)

# Volume ranges from 0.0 to 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.8

# Mute states
var music_muted: bool = false
var sfx_muted: bool = false

# Bus indices for easier reference
var music_bus_index: int
var sfx_bus_index: int

# Default bus names
const MUSIC_BUS_NAME = "Music"
const SFX_BUS_NAME = "SFX"

var audio_initialized: bool = false

func _ready():
	print("DEBUG: SoundManager initializing...")
	
	# Setup audio buses (this doesn't actually start any audio playback)
	_setup_audio_buses()
	
	# For web builds, we need to detect user interaction to initialize audio
	if OS.has_feature("web"):
		print("Web build detected: Waiting for user interaction to initialize audio")
		
		# Set a flag to track initialization
		audio_initialized = false
		
		# Connect to the input events to detect user interaction
		# We'll use both mouse and keyboard events to be thorough
		get_viewport().connect("gui_focus_changed", _on_user_interaction)
		
		# We won't use connect("gui_input") as it causes errors in HTML5
		# Instead, we'll rely on the _input method
		print("Using _input method for web audio initialization")
	else:
		# For non-web platforms, we can initialize immediately
		audio_initialized = true
		print("Non-web build: Audio initialized immediately")

# Process input events for web audio initialization
func _input(event):
	if OS.has_feature("web") and not audio_initialized:
		if event is InputEventMouseButton or event is InputEventKey:
			if event.pressed:
				_initialize_web_audio()

# Setup audio buses (doesn't start audio playback)
func _setup_audio_buses():
	# Initialize audio bus indices
	music_bus_index = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	sfx_bus_index = AudioServer.get_bus_index(SFX_BUS_NAME)
	
	print("DEBUG: Initial bus indices - Music: ", music_bus_index, ", SFX: ", sfx_bus_index)
	
	# If the buses don't exist yet, create them
	if music_bus_index == -1:
		# Create music bus
		music_bus_index = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(music_bus_index, MUSIC_BUS_NAME)
		AudioServer.set_bus_send(music_bus_index, "Master")
		print("DEBUG: Created Music bus at index ", music_bus_index)
	
	if sfx_bus_index == -1:
		# Create SFX bus
		sfx_bus_index = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(sfx_bus_index, SFX_BUS_NAME)
		AudioServer.set_bus_send(sfx_bus_index, "Master")
		print("DEBUG: Created SFX bus at index ", sfx_bus_index)
	
	# Verify buses were created correctly
	music_bus_index = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	sfx_bus_index = AudioServer.get_bus_index(SFX_BUS_NAME)
	print("DEBUG: Final bus indices - Music: ", music_bus_index, ", SFX: ", sfx_bus_index)
	
	# Apply initial settings
	_apply_music_volume()
	_apply_sfx_volume()
	
	# Make sure buses aren't muted by default
	if music_bus_index != -1:
		AudioServer.set_bus_mute(music_bus_index, false)
	
	if sfx_bus_index != -1:
		AudioServer.set_bus_mute(sfx_bus_index, false)

# Called when any user interaction happens in web builds
func _on_user_interaction(_arg=null):
	if OS.has_feature("web") and not audio_initialized:
		_initialize_web_audio()

# If this method is called from JavaScript, it will help the game to 
# initialize audio properly in web builds
func init_web_audio_from_js():
	if OS.has_feature("web") and not audio_initialized:
		print("Audio initialization requested from JS")
		_initialize_web_audio()

# Initialize audio for web builds - simplified approach following Mozilla guidelines
func _initialize_web_audio():
	if audio_initialized:
		return
		
	print("User interaction detected: Initializing web audio...")
	
	# Resume the AudioServer context immediately
	AudioServer.set_bus_mute(0, false) # Unmute master bus
	
	# Force unmute all buses to make sure audio can be heard
	if music_bus_index != -1:
		AudioServer.set_bus_mute(music_bus_index, false)
		AudioServer.set_bus_volume_db(music_bus_index, 0) # Full volume
	if sfx_bus_index != -1:
		AudioServer.set_bus_mute(sfx_bus_index, false)
		AudioServer.set_bus_volume_db(sfx_bus_index, 0) # Full volume
	
	# Skip JavaScript code in editor, only run it in actual web export
	var js_result = false
	if OS.has_feature("web"):
		# Simple JavaScript to unlock audio context
		print("Running JavaScript to unlock audio context...")
		var js_code = """
		(function() {
			try {
				// Target desktop and mobile browsers with a simple approach
				console.log('Starting simple audio unlock process');
				
				// Create audio context
				if (!window._godotAudioContext) {
					window._godotAudioContext = new (window.AudioContext || window.webkitAudioContext)();
				}
				
				var audioCtx = window._godotAudioContext;
				console.log('Audio context state:', audioCtx.state);
				
				// Resume it
				if (audioCtx.state === 'suspended') {
					audioCtx.resume().then(function() {
						console.log('Audio context resumed successfully');
					});
				}
				
				// Play a simple, short beep to kickstart audio
				var oscillator = audioCtx.createOscillator();
				var gainNode = audioCtx.createGain();
				gainNode.gain.value = 0.1; // Quiet beep
				oscillator.connect(gainNode);
				gainNode.connect(audioCtx.destination);
				oscillator.start(0);
				oscillator.stop(0.1); // Very short
				
				// Add listeners to handle ongoing user gestures
				['click', 'touchstart', 'touchend'].forEach(function(event) {
					document.addEventListener(event, function() {
						// If context is still suspended, try resuming it again
						if (audioCtx.state === 'suspended') {
							audioCtx.resume().then(function() {
								console.log('Audio context resumed on user gesture');
							});
						}
					}, {once: false});
				});
				
				return audioCtx.state;
			} catch(e) {
				console.error('Error initializing audio:', e);
				return 'error';
			}
		})()
		"""
		
		# Safely evaluate JavaScript code
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			js_result = js.eval(js_code)
			print("JavaScript audio context state: ", js_result)
		else:
			print("JavaScriptBridge singleton not available")
	else:
		print("Skipping JavaScript code in editor/debug mode")
	
	# Create a single silent sound to test audio system
	var test_player = AudioStreamPlayer.new()
	add_child(test_player)
	
	# Create a simple tone
	var test_stream = AudioStreamWAV.new()
	test_stream.format = AudioStreamWAV.FORMAT_16_BITS
	test_stream.stereo = true
	
	# Simple silent data
	var data = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	test_stream.data = data
	
	# Configure player
	test_player.stream = test_stream
	test_player.volume_db = -80.0 # Silent
	test_player.bus = "Master"
	
	# Play the test sound
	test_player.play()
	
	# Wait a small amount of time
	await get_tree().create_timer(0.1).timeout
	
	# Clean up
	test_player.stop()
	test_player.queue_free()
	
	# Mark as initialized
	audio_initialized = true
	print("Web audio initialized successfully")
	
	# Set volumes to reasonable defaults
	music_volume = 0.8
	sfx_volume = 0.8
	music_muted = false
	sfx_muted = false
	
	# Ensure all audio buses are correctly configured
	_apply_music_volume()
	_apply_sfx_volume()
	
	# Notify any waiting game systems that audio is now available
	audio_ready.emit()

# Set music volume (0.0 to 1.0)
func set_music_volume(volume: float):
	music_volume = clampf(volume, 0.0, 1.0)
	_apply_music_volume()
	music_volume_changed.emit(music_volume)
	print("Music volume set to: ", music_volume)

# Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float):
	sfx_volume = clampf(volume, 0.0, 1.0)
	_apply_sfx_volume()
	sfx_volume_changed.emit(sfx_volume)
	print("SFX volume set to: ", sfx_volume)

# Toggle music mute state
func toggle_music_mute():
	music_muted = !music_muted
	_apply_music_volume()
	music_muted_changed.emit(music_muted)
	print("Music mute toggled to: ", music_muted)

# Toggle SFX mute state
func toggle_sfx_mute():
	sfx_muted = !sfx_muted
	_apply_sfx_volume()
	sfx_muted_changed.emit(sfx_muted)
	print("SFX mute toggled to: ", sfx_muted)

# Apply music volume settings to the bus
func _apply_music_volume():
	if music_bus_index != -1:
		if music_muted:
			AudioServer.set_bus_mute(music_bus_index, true)
		else:
			AudioServer.set_bus_mute(music_bus_index, false)
			# Convert from linear to decibels (approximately -80dB to 0dB)
			var db_value = linear_to_db(music_volume)
			AudioServer.set_bus_volume_db(music_bus_index, db_value)

# Apply SFX volume settings to the bus
func _apply_sfx_volume():
	if sfx_bus_index != -1:
		if sfx_muted:
			AudioServer.set_bus_mute(sfx_bus_index, true)
		else:
			AudioServer.set_bus_mute(sfx_bus_index, false)
			# Convert from linear to decibels
			var db_value = linear_to_db(sfx_volume)
			AudioServer.set_bus_volume_db(sfx_bus_index, db_value)

# Helper function to convert linear volume to decibels with a more usable range
func linear_to_db(linear_value: float) -> float:
	if linear_value <= 0:
		return -80.0  # Very low but not -INF
	return 20.0 * log(linear_value) / log(10.0)
