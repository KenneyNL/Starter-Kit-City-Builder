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
		
		# Setup check for mouse clicks
		# Input events must be connected to the root viewport
		var root = get_tree().get_root()
		if root:
			root.connect("gui_input", _on_input_event)
			print("Connected to input events for audio initialization")
	else:
		# For non-web platforms, we can initialize immediately
		audio_initialized = true
		print("Non-web build: Audio initialized immediately")

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

# Handle input events for web audio initialization
func _on_input_event(event):
	if OS.has_feature("web") and not audio_initialized:
		if event is InputEventMouseButton or event is InputEventKey:
			if event.pressed:
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
	
	# For web browsers, we need a more direct and aggressive approach
	if OS.has_feature("web"):
		# 1. Explicitly unlock audio context by using JavaScript
		JavaScript.eval("""
			// Function to unlock Web Audio
			function unlockAudio() {
				// Get the AudioContext
				var audioCtx = new (window.AudioContext || window.webkitAudioContext)();
				
				// Resume it (modern browsers)
				if (audioCtx.state === 'suspended') {
					audioCtx.resume().then(() => {
						console.log('Audio context resumed successfully');
					});
				}
				
				// Create and play a silent buffer (older browsers)
				var buffer = audioCtx.createBuffer(1, 1, 22050);
				var source = audioCtx.createBufferSource();
				source.buffer = buffer;
				source.connect(audioCtx.destination);
				source.start(0);
				
				console.log('Web Audio unlock attempt complete');
				
				// Also click to unlock for iOS
				document.removeEventListener('click', unlockAudio);
				document.removeEventListener('touchstart', unlockAudio);
				document.removeEventListener('touchend', unlockAudio);
				document.removeEventListener('keydown', unlockAudio);
			}
			
			// Try to unlock now
			unlockAudio();
		""")
	
	# Resume the AudioServer context
	AudioServer.set_bus_mute(0, false) # Unmute master bus
	
	# Play and immediately stop a silent sound to initialize the audio context
	var silent_player = AudioStreamPlayer.new()
	add_child(silent_player)
	
	# Create a very short silent audio stream
	var silent_stream = AudioStreamWAV.new()
	silent_stream.format = AudioStreamWAV.FORMAT_16_BITS
	silent_stream.stereo = true
	silent_stream.data = PackedByteArray([0, 0, 0, 0]) # Minimal silent data
	
	# Play and immediately stop to kickstart audio
	silent_player.stream = silent_stream
	silent_player.volume_db = -80.0
	silent_player.play()
	
	# Wait a moment before stopping (important for some browsers)
	await get_tree().create_timer(0.1).timeout
	silent_player.stop()
	
	# Clean up
	await get_tree().process_frame
	silent_player.queue_free()
	
	# Set the flag to prevent multiple initializations
	audio_initialized = true
	print("Web audio initialized successfully")
	
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