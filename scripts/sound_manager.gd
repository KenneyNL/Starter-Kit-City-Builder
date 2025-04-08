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

# Initialize audio for web builds
func _initialize_web_audio():
	if audio_initialized:
		return
		
	print("User interaction detected: Initializing web audio...")
	
	# Resume the AudioServer context immediately
	AudioServer.set_bus_mute(0, false) # Unmute master bus
	
	# Force unmute all buses to make sure audio can be heard
	if music_bus_index != -1:
		AudioServer.set_bus_mute(music_bus_index, false)
		AudioServer.set_bus_volume_db(music_bus_index, 0)  # Maximum volume
	if sfx_bus_index != -1:
		AudioServer.set_bus_mute(sfx_bus_index, false)
		AudioServer.set_bus_volume_db(sfx_bus_index, 0)  # Maximum volume
	
	# Skip JavaScript code in editor, only run it in actual web export
	var js_result = false
	if OS.has_feature("web"):
		# 1. Use JavaScriptBridge to unlock web audio with enhanced compatibility
		print("Running JavaScript to unlock audio context...")
		# This is wrapped in a try-catch to handle any errors and prevent crashes
		var js_code = """
		(function() {
			var result = false;
			try {
				// Enhanced Web Audio unlock for browsers
				
				// Detect if running inside an iframe and gain focus
				if (window.parent !== window) {
					window.focus();
				}
				
				// Get all audio elements and start playing them
				var audioElements = document.querySelectorAll('audio');
				console.log('Found ' + audioElements.length + ' audio elements');
				audioElements.forEach(function(audio, index) {
					console.log('Audio element ' + index + ' - volume:', audio.volume, 'muted:', audio.muted);
					// Set volume to max and unmute
					audio.volume = 1.0;
					audio.muted = false;
					// Try to play any existing audio elements
					audio.play().catch(function(e) {
						console.log('Could not autoplay audio element:', e);
					});
				});
				
				// Store a global reference to reuse
				if (!window._godotAudioContext) {
					console.log('Creating new AudioContext');
					window._godotAudioContext = new (window.AudioContext || window.webkitAudioContext)();
				}
				var audioCtx = window._godotAudioContext;
				console.log('AudioContext initial state:', audioCtx.state);
				
				// Resume the context (for Chrome/Edge/Safari)
				if (audioCtx && audioCtx.state === 'suspended') {
					console.log('Audio context is suspended, attempting to resume...');
					audioCtx.resume();
				}
				
				// Create a more audible tone to kickstart audio
				var oscillator = audioCtx.createOscillator();
				var gainNode = audioCtx.createGain();
				gainNode.gain.value = 0.2; // Audible but not too loud
				oscillator.connect(gainNode);
				gainNode.connect(audioCtx.destination);
				oscillator.frequency.value = 440; // A4 note
				oscillator.start(0);
				oscillator.stop(0.5); // Short duration
				
				// Play a second tone with different frequency after a short delay
				setTimeout(function() {
					var oscillator2 = audioCtx.createOscillator();
					var gainNode2 = audioCtx.createGain();
					gainNode2.gain.value = 0.2;
					oscillator2.connect(gainNode2);
					gainNode2.connect(audioCtx.destination);
					oscillator2.frequency.value = 880; // One octave higher
					oscillator2.start(0);
					oscillator2.stop(0.5);
				}, 600);
				
				// Also play a buffer (for iOS Safari)
				var buffer = audioCtx.createBuffer(1, 8000, 22050);
				// Fill the buffer with a simple sine wave
				var bufferData = buffer.getChannelData(0);
				for (var i = 0; i < bufferData.length; i++) {
					bufferData[i] = Math.sin(i * 0.05) * 0.2;
				}
				var source = audioCtx.createBufferSource();
				source.buffer = buffer;
				source.connect(audioCtx.destination);
				source.start(0);
				
				// Auto-unlock listeners when user interacts
				var unlockEvents = ['touchstart', 'touchend', 'mousedown', 'keydown'];
				
				function unlockOnInteraction() {
					unlockEvents.forEach(function(event) {
						document.removeEventListener(event, unlockOnInteraction);
					});
					
					// Try to resume again on direct user interaction
					if (audioCtx.state === 'suspended') {
						audioCtx.resume();
					}
				}
				
				unlockEvents.forEach(function(event) {
					document.addEventListener(event, unlockOnInteraction, false);
				});
				
				console.log('Web Audio unlock attempts completed. AudioContext state:', audioCtx.state);
				
				// Store result in a global variable instead of returning
				window._godotAudioResult = audioCtx.state === 'running';
				result = window._godotAudioResult;
			} catch (e) {
				console.error('Web Audio unlock error:', e);
				window._godotAudioResult = false;
				result = false;
			}
			
			return result;
		})()
		"""
		
		# Safely evaluate JavaScript code
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			js_result = js.eval(js_code)
			print("JavaScript result: ", js_result)
		else:
			print("JavaScriptBridge singleton not available")
	else:
		print("Skipping JavaScript code in editor/debug mode")
	
	# Play multiple sounds at different volumes to initialize the audio context
	# This approach helps across different browsers
	var silent_players = []
	
	# Create multiple silent players with different configurations
	for i in range(5):  # Increased from 3 to 5 players
		var silent_player = AudioStreamPlayer.new()
		add_child(silent_player)
		silent_players.append(silent_player)
		
		# Create a very short audio stream
		var silent_stream = AudioStreamWAV.new()
		silent_stream.format = AudioStreamWAV.FORMAT_16_BITS
		silent_stream.stereo = true
		
		# Use slightly different data for each player
		var data = PackedByteArray()
		for j in range(100):  # Larger buffer
			# Create a simple sine wave pattern with different frequencies
			data.append(int((sin(j * (0.1 + i * 0.05)) * 127) + 128) % 256)
			data.append(int((sin(j * (0.1 + i * 0.05)) * 127) + 128) % 256)
		
		silent_stream.data = data
		
		# Configure each player slightly differently
		silent_player.stream = silent_stream
		silent_player.volume_db = -40.0 + (i * 10.0)  # Gradually increasing volume
		silent_player.pitch_scale = 0.5 + (i * 0.5)  # Different pitch scales
		silent_player.bus = "Master"  # Force master bus
		
		# Play each player
		silent_player.play()
	
	# Wait a moment before stopping (important for some browsers)
	await get_tree().create_timer(0.5).timeout  # Increased wait time
	
	# Stop all silent players
	for player in silent_players:
		player.stop()
	
	# Wait a frame to ensure everything is processed
	await get_tree().process_frame
	
	# Try playing on the actual audio buses with more audible tones
	var test_players = []
	
	# Test play on each important bus
	for bus_index, bus_name in enumerate(["Master", "Music", "SFX"]):
		var test_player = AudioStreamPlayer.new()
		add_child(test_player)
		test_players.append(test_player)
		
		# Create test audio with audible tones
		var test_stream = AudioStreamWAV.new()
		test_stream.format = AudioStreamWAV.FORMAT_16_BITS
		test_stream.stereo = true
		
		# Create a slightly audible tone
		var data = PackedByteArray()
		# Create a simple sawtooth wave with different frequencies per bus
		var frequency = 440.0 * (1.0 + bus_index * 0.5)  # Different frequency per bus
		for j in range(4000):  # Larger buffer for longer sound
			var value = int(((j % int(22050/frequency)) / (22050/frequency) * 200) + 28)
			data.append(value)
			data.append(value)
		
		test_stream.data = data
		
		# Configure test player
		test_player.stream = test_stream
		test_player.volume_db = -20.0  # More audible for testing
		test_player.bus = bus_name
		
		# Play test sound
		test_player.play()
		
		print("Playing test tone on " + bus_name + " bus")
	
	# Wait again before cleanup - longer for audible confirmation
	await get_tree().create_timer(0.8).timeout
	
	# Stop all test players
	for player in test_players:
		player.stop()
	
	# Clean up all players
	await get_tree().process_frame
	for player in silent_players + test_players:
		player.queue_free()
	
	# Set the flag to prevent multiple initializations
	audio_initialized = true
	print("Web audio initialized successfully")
	
	# Force highest volumes
	music_volume = 1.0
	sfx_volume = 1.0
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
