extends Node

signal music_volume_changed(new_volume)
signal sfx_volume_changed(new_volume)
signal music_muted_changed(is_muted)
signal sfx_muted_changed(is_muted)

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

func _ready():
	print("DEBUG: SoundManager initializing...")
	
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
	
	print("SoundManager initialized with volumes - Music: ", music_volume, ", SFX: ", sfx_volume)

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