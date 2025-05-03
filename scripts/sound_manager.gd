extends Node

# Signals for audio management
signal music_volume_changed(new_volume: float)
signal sfx_volume_changed(new_volume: float)
signal music_muted_changed(is_muted: bool)
signal sfx_muted_changed(is_muted: bool)
signal audio_ready

# Volume settings - start at 50% volume
var music_volume: float = 0.5:
	set(value):
		var clamped_value = clampf(value, 0.0, 1.0)
		music_volume = clamped_value
		var db_value = linear_to_db(clamped_value)
		print("Setting music volume: ", clamped_value, " (", db_value, " dB)")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db_value)
		music_volume_changed.emit(clamped_value)

var sfx_volume: float = 0.5:
	set(value):
		var clamped_value = clampf(value, 0.0, 1.0)
		sfx_volume = clamped_value
		var db_value = linear_to_db(clamped_value)
		print("Setting SFX volume: ", clamped_value, " (", db_value, " dB)")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db_value)
		sfx_volume_changed.emit(clamped_value)

# Mute settings
var music_muted: bool = false:
	set(value):
		music_muted = value
		print("Setting music mute: ", value)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), value)
		music_muted_changed.emit(value)

var sfx_muted: bool = false:
	set(value):
		sfx_muted = value
		print("Setting SFX mute: ", value)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), value)
		sfx_muted_changed.emit(value)

# Audio initialization status (important for web)
var audio_initialized: bool = false

# Sound file paths
const MUSIC_PATH = "res://audio/music/"
const SFX_PATH = "res://audio/sfx/"

func _ready():
	print("SoundManager: Initializing...")
	# Create audio buses first
	_initialize_audio()
	
	# For web platform, we need to wait for user interaction before enabling audio
	if OS.has_feature("web"):
		print("SoundManager: Web platform detected, waiting for user interaction")
		# Connect to the JavaScript bridge
		JavaScriptBridge.eval("""
			window.addEventListener('click', function() {
				window.godotAudioInitialized = true;
				window.dispatchEvent(new Event('godotAudioReady'));
			}, { once: true });
		""")
		
		# Wait for the audio_ready event from JavaScript
		JavaScriptBridge.eval("""
			window.addEventListener('godotAudioReady', function() {
				window.godotInterface.call('_on_audio_ready');
			});
		""")
	else:
		print("SoundManager: Desktop platform, audio initialization complete")
		audio_ready.emit()

func _on_audio_ready():
	print("SoundManager: Audio ready signal received")
	audio_ready.emit()

func _initialize_audio():
	print("SoundManager: Initializing audio buses")
	
	# Create audio buses if they don't exist
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		print("SoundManager: Creating Music bus")
		AudioServer.add_bus()
		music_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus_index, "Music")
		AudioServer.set_bus_send(music_bus_index, "Master")
		
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index == -1:
		print("SoundManager: Creating SFX bus")
		AudioServer.add_bus()
		sfx_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_bus_index, "SFX")
		AudioServer.set_bus_send(sfx_bus_index, "Master")
	
	# Get the final bus indices after creation
	music_bus_index = AudioServer.get_bus_index("Music")
	sfx_bus_index = AudioServer.get_bus_index("SFX")
	
	# Verify bus indices are valid
	if music_bus_index == -1 or sfx_bus_index == -1:
		push_error("SoundManager: Failed to create audio buses")
		return
	
	# Apply current volume settings
	print("SoundManager: Applying initial volume settings")
	music_volume = music_volume
	sfx_volume = sfx_volume
	
	# Apply current mute settings
	print("SoundManager: Applying initial mute settings")
	music_muted = music_muted
	sfx_muted = sfx_muted
	
	# Mark audio as initialized
	audio_initialized = true
	print("SoundManager: Audio initialization complete")

# Volume control functions
func set_music_volume(volume: float):
	print("SoundManager: Setting music volume to ", volume)
	music_volume = volume

func set_sfx_volume(volume: float):
	print("SoundManager: Setting SFX volume to ", volume)
	sfx_volume = volume

func toggle_music_mute():
	print("SoundManager: Toggling music mute")
	music_muted = !music_muted

func toggle_sfx_mute():
	print("SoundManager: Toggling SFX mute")
	sfx_muted = !sfx_muted

# Helper function to convert linear volume to decibels
# Maps 0.0-1.0 to -30dB to 0dB for a more usable range
func linear_to_db(linear: float) -> float:
	if linear <= 0:
		return -80.0
	# Map 0.0-1.0 to -30dB to 0dB
	return (linear * 30.0) - 30.0

# Helper function to convert decibels to linear volume
func db_to_linear(db: float) -> float:
	if db <= -30:
		return 0.0
	return (db + 30.0) / 30.0
