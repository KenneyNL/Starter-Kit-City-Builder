extends Node

signal music_volume_changed(new_volume)
signal sfx_volume_changed(new_volume)
signal music_muted_changed(is_muted)
signal sfx_muted_changed(is_muted)
signal audio_ready # Signal emitted when audio is initialized (important for web)

# Sound bridges for web builds
var react_sound_bridge = null # Will be instantiated from a script
var audio_bridge = null # Will be instantiated from a script

# Volume ranges from 0.0 to 1.0
var music_volume: float = 0.0
var sfx_volume: float = 0.1

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

# Sound files dictionary - mapping simplified names to file paths
const SOUND_FILES = {
	"jazzNewOrleans": "res://sounds/jazz_new_orleans.mp3",
	"lofiChillJazz": "res://sounds/lofi-chill-jazz-272869.mp3",
	"buildingPlacing": "res://sounds/building_placing.wav",
	"construction": "res://sounds/construction.wav",
	"powerDrill": "res://sounds/power_drill.mp3"
}

# Current music track
var current_music: String = ""

# Currently playing audio streams (for direct Godot playback)
var music_player: AudioStreamPlayer = null
var sfx_players: Dictionary = {}

func _ready():
	# Create music player for all platforms
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# For web builds, we'll use Audio Bridge
	if false:
		pass
#	if OS.has_feature("web"):
#		# Set a flag to track initialization
#		audio_initialized = false
#		
#		print("Web build detected, Audio bridges will be used")
#		
#		# Connect to the input events to detect user interaction as fallback
#		get_viewport().connect("gui_focus_changed", _on_user_interaction)
#		
#		# Try to use a custom Node for audio bridge functionality
#		# Instead of relying on class_name registration or preload
#		audio_bridge = Node.new()
#		audio_bridge.name = "AudioBridge"
#		add_child(audio_bridge)
#		
#		# Set up the necessary properties
#		audio_bridge.set_script(load("res://scripts/audio_bridge.gd"))
#		
#		# Connect to the signal after the script is loaded
#		if audio_bridge.has_signal("bridge_connected"):
#			audio_bridge.bridge_connected.connect(_on_audio_bridge_connected)
#		
#		# We also create the ReactSoundBridge for backward compatibility
#		# But using the same approach as AudioBridge to avoid class_name dependency
#		react_sound_bridge = Node.new()
#		react_sound_bridge.name = "ReactSoundBridge"
#		add_child(react_sound_bridge)
#		
#		# Set up the necessary properties
#		react_sound_bridge.set_script(load("res://scripts/react_sound_bridge.gd"))
#		
#		# Connect to the signal after the script is loaded
#		if react_sound_bridge.has_signal("audio_ready"):
#			react_sound_bridge.audio_ready.connect(_on_react_audio_ready)
#		
#		# Signal that we're using web audio (don't create audio buses)
#		await get_tree().process_frame
#		audio_initialized = true
#		audio_ready.emit()
#		
#		# Store a reference to this object in the main loop for JavaScript callbacks
#		Engine.get_main_loop().set_meta("sound_manager", self)
	else:
		# For non-web platforms, set up standard Godot audio
		# Set up the audio buses
		_setup_audio_buses()
		
		# Set the music player bus
		music_player.bus = MUSIC_BUS_NAME
		
		# Apply initial volume settings
		_apply_music_volume()
		
		# For non-web platforms, we can initialize immediately
		audio_initialized = true
		
		# Emit the audio ready signal
		audio_ready.emit()

# Setup audio buses (doesn't start audio playback)
func _setup_audio_buses():
	# Initialize audio bus indices
	music_bus_index = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	sfx_bus_index = AudioServer.get_bus_index(SFX_BUS_NAME)
	
	# If the buses don't exist yet, create them
	if music_bus_index == -1:
		# Create music bus
		music_bus_index = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(music_bus_index, MUSIC_BUS_NAME)
		AudioServer.set_bus_send(music_bus_index, "Master")
	
	if sfx_bus_index == -1:
		# Create SFX bus
		sfx_bus_index = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(sfx_bus_index, SFX_BUS_NAME)
		AudioServer.set_bus_send(sfx_bus_index, "Master")
	
	# Verify buses were created correctly
	music_bus_index = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	sfx_bus_index = AudioServer.get_bus_index(SFX_BUS_NAME)
	
	# Apply initial settings
	_apply_music_volume()
	_apply_sfx_volume()
	
	# Make sure buses aren't muted by default
	if music_bus_index != -1:
		AudioServer.set_bus_mute(music_bus_index, false)
	
	if sfx_bus_index != -1:
		AudioServer.set_bus_mute(sfx_bus_index, false)

# Process sound state received from JavaScript
func process_js_audio_state(state: Dictionary):
	# Update local state based on received data
	if state.has("musicVolume"):
		music_volume = state.musicVolume
	if state.has("sfxVolume"):
		sfx_volume = state.sfxVolume
	if state.has("musicMuted"):
		music_muted = state.musicMuted
	if state.has("sfxMuted"):
		sfx_muted = state.sfxMuted
	if state.has("currentMusic"):
		current_music = state.currentMusic
	
	# Emit signals about changes
	music_volume_changed.emit(music_volume)
	sfx_volume_changed.emit(sfx_volume)
	music_muted_changed.emit(music_muted)
	sfx_muted_changed.emit(sfx_muted)

# Called when ReactSoundBridge reports it's ready
func _on_react_audio_ready():
	print("ReactSoundBridge reports ready")
	audio_initialized = true
	
	# Update local state from React
	if react_sound_bridge != null:
		if react_sound_bridge.get("music_volume") != null:
			music_volume = react_sound_bridge.music_volume
		if react_sound_bridge.get("sfx_volume") != null:
			sfx_volume = react_sound_bridge.sfx_volume
		if react_sound_bridge.get("music_muted") != null:
			music_muted = react_sound_bridge.music_muted
		if react_sound_bridge.get("sfx_muted") != null:
			sfx_muted = react_sound_bridge.sfx_muted
		if react_sound_bridge.get("current_music") != null:
			current_music = react_sound_bridge.current_music
	
	# Emit the audio ready signal
	audio_ready.emit()

# Called when AudioBridge connects to the platform-one sound manager
func _on_audio_bridge_connected(is_connected: bool):
	print("AudioBridge connected: ", is_connected)
	
	if is_connected:
		audio_initialized = true
		
		# Request the sound state from the platform-one sound manager
		if audio_bridge.has_method("get_sound_state"):
			audio_bridge.get_sound_state()
		
		# Emit the audio ready signal
		audio_ready.emit()

# Called when any user interaction happens in web builds
func _on_user_interaction(_arg=null):
	if OS.has_feature("web") and not audio_initialized:
		_initialize_web_audio()

# Process input events directly
func _input(event):
	if OS.has_feature("web") and not audio_initialized:
		if event is InputEventMouseButton or event is InputEventKey:
			if event.pressed:
				_initialize_web_audio()
				
# If this method is called from JavaScript, it will help the game to 
# initialize audio properly in web builds
func init_web_audio_from_js():
	pass
	#if OS.has_feature("web") and not audio_initialized:
		#_initialize_web_audio()

# Initialize audio for web builds
func _initialize_web_audio():
	if audio_initialized:
		return
		
	# For web builds, we notify JavaScript to initialize audio
#	if OS.has_feature("web"):
#		JSBridge.JavaScriptGlobal.handle_audio_action("INITIALIZE_AUDIO")
#		
#		# We don't need to create any dummy players, as JavaScript will handle the audio
#		audio_initialized = true
#		audio_ready.emit()
#		return
	
	# For non-web platforms, initialize Godot audio (this shouldn't get called)
#	if not OS.has_feature("web"):
		# Set the flag to prevent multiple initializations
		audio_initialized = true
		audio_ready.emit()

# Play background music
func play_music(sound_name: String, loop: bool = true):
	if not audio_initialized:
		return
		
	# Store the current music name
	current_music = sound_name
	
	# For web builds, try multiple bridge options
#	if OS.has_feature("web"):
#		# Try AudioBridge first (platform-one integration)
#		if audio_bridge != null and audio_bridge.get("is_connected") == true:
#			print("Using AudioBridge to play music: ", sound_name)
#			if audio_bridge.has_method("play_music") and audio_bridge.play_music(sound_name):
#				return
#		
#		# Fall back to JavaScript Bridge
#		print("Using JavaScriptBridge to play music: ", sound_name)
#		JSBridge.JavaScriptGlobal.handle_audio_action("PLAY_MUSIC", sound_name)
#		return
	
	# For native builds, use Godot audio
	if not SOUND_FILES.has(sound_name):
		return
		
	# Get the file path
	var file_path = SOUND_FILES[sound_name]
	
	# Load the audio stream
	var stream = load(file_path)
	if stream == null:
		return
	
	# Stop current music if playing
	if music_player.playing:
		music_player.stop()
	
	# Set up and play the music
	music_player.stream = stream
	music_player.bus = MUSIC_BUS_NAME
	
	# Set looping if supported by the stream
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = loop
	
	# Ensure volume is set correctly before playing
	_apply_music_volume()
	
	# Play the music
	music_player.play()

# Play a sound effect
func play_sfx(sound_name: String):
	if not audio_initialized:
		return
		
	# For web builds, try multiple bridge options
	#if OS.has_feature("web"):
		## Try AudioBridge first (platform-one integration)
		#if audio_bridge != null and audio_bridge.get("is_connected") == true:
			#print("Using AudioBridge to play sfx: ", sound_name)
			#if audio_bridge.has_method("play_sfx") and audio_bridge.play_sfx(sound_name):
				#return
		#
		## Fall back to JavaScript Bridge
		#print("Using JavaScriptBridge to play sfx: ", sound_name)
		#JSBridge.JavaScriptGlobal.handle_audio_action("PLAY_SFX", sound_name)
		#return
	
	# For native builds, use Godot audio
	if not SOUND_FILES.has(sound_name):
		return
		
	# Get the file path
	var file_path = SOUND_FILES[sound_name]
	
	# Load the audio stream
	var stream = load(file_path)
	if stream == null:
		return
	
	# Create or reuse a player for this sound
	var player: AudioStreamPlayer
	if not sfx_players.has(sound_name):
		player = AudioStreamPlayer.new()
		add_child(player)
		sfx_players[sound_name] = player
	else:
		player = sfx_players[sound_name]
		if player.playing:
			player.stop()
	
	# Set up and play the sound
	player.stream = stream
	if sfx_muted:
		player.volume_db = linear_to_db(0)
	else:
		player.volume_db = linear_to_db(sfx_volume)
	player.bus = SFX_BUS_NAME
	player.play()

# Stop background music
func stop_music():
	if not audio_initialized:
		return
		
	# For web builds, try multiple bridge options
	#if OS.has_feature("web"):
		## Try AudioBridge first (platform-one integration)
		#if audio_bridge != null and audio_bridge.get("is_connected") == true:
			#print("Using AudioBridge to stop music")
			#if audio_bridge.has_method("stop_music") and audio_bridge.stop_music():
				#current_music = ""
				#return
		#
		## Fall back to JavaScript Bridge
		#print("Using JavaScriptBridge to stop music")
		#JSBridge.JavaScriptGlobal.handle_audio_action("STOP_MUSIC")
		#current_music = ""
		#return
	
	# For native builds, use Godot audio
	if music_player and music_player.playing:
		music_player.stop()
	
	current_music = ""

# Set music volume (0.0 to 1.0)
func set_music_volume(volume: float):
	music_volume = clampf(volume, 0.0, 1.0)
	
	# For web builds, try multiple bridge options
	if false:
		pass
#	if OS.has_feature("web"):
#		# Try AudioBridge first (platform-one integration)
#		if audio_bridge != null and audio_bridge.get("is_connected") == true:
#			print("Using AudioBridge to set music volume: ", music_volume)
#			if audio_bridge.has_method("set_music_volume"):
#				audio_bridge.set_music_volume(music_volume)
#		else:
#			# Fall back to JavaScript Bridge
#			print("Using JavaScriptBridge to set music volume: ", music_volume)
#			JSBridge.JavaScriptGlobal.handle_audio_action("SET_MUSIC_VOLUME", "", music_volume)
	else:
		# Apply to local Godot audio system
		_apply_music_volume()
	
	# Emit signal
	music_volume_changed.emit(music_volume)

# Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float):
	sfx_volume = clampf(volume, 0.0, 1.0)
	
	# For web builds, try multiple bridge options
#	if OS.has_feature("web"):
	if false:
		pass
#		# Try AudioBridge first (platform-one integration)
#		if audio_bridge != null and audio_bridge.get("is_connected") == true:
#			print("Using AudioBridge to set sfx volume: ", sfx_volume)
#			if audio_bridge.has_method("set_sfx_volume"):
#				audio_bridge.set_sfx_volume(sfx_volume)
#		else:
#			# Fall back to JavaScript Bridge
#			print("Using JavaScriptBridge to set sfx volume: ", sfx_volume)
#			JSBridge.JavaScriptGlobal.handle_audio_action("SET_SFX_VOLUME", "", sfx_volume)
	else:
		# Apply to local Godot audio system
		_apply_sfx_volume()
	
	# Emit signal
	sfx_volume_changed.emit(sfx_volume)

# Toggle music mute state
func toggle_music_mute():
	music_muted = !music_muted
	
	# For web builds, try multiple bridge options
#	if OS.has_feature("web"):
	if false:
		pass
#		# Try AudioBridge first (platform-one integration)
#		if audio_bridge != null and audio_bridge.get("is_connected") == true:
#			print("Using AudioBridge to toggle music mute: ", music_muted)
#			if audio_bridge.has_method("toggle_music_mute"):
#				audio_bridge.toggle_music_mute()
#		else:
#			# Fall back to JavaScript Bridge
#			print("Using JavaScriptBridge to toggle music mute: ", music_muted)
#			JSBridge.JavaScriptGlobal.handle_audio_action("TOGGLE_MUSIC_MUTE")
	else:
		# Apply to local Godot audio system
		_apply_music_volume()
	
	# Emit signal
	music_muted_changed.emit(music_muted)

# Toggle SFX mute state
func toggle_sfx_mute():
	sfx_muted = !sfx_muted
	
	# For web builds, try multiple bridge options
#	if OS.has_feature("web"):
	if false:
		pass
#		# Try AudioBridge first (platform-one integration)
#		if audio_bridge != null and audio_bridge.get("is_connected") == true:
#			print("Using AudioBridge to toggle sfx mute: ", sfx_muted)
#			if audio_bridge.has_method("toggle_sfx_mute"):
#				audio_bridge.toggle_sfx_mute()
#		else:
#			# Fall back to JavaScript Bridge
#			print("Using JavaScriptBridge to toggle sfx mute: ", sfx_muted)
#			JSBridge.JavaScriptGlobal.handle_audio_action("TOGGLE_SFX_MUTE")
	else:
		# Apply to local Godot audio system
		_apply_sfx_volume()
	
	# Emit signal
	sfx_muted_changed.emit(sfx_muted)

# Apply music volume settings
func _apply_music_volume():
	# Skip for web builds - JavaScript Bridge handles volume
#	if OS.has_feature("web"):
#		return
	
	# For non-web builds, use the audio buses
	if music_bus_index != -1:
		if music_muted:
			AudioServer.set_bus_mute(music_bus_index, true)
		else:
			AudioServer.set_bus_mute(music_bus_index, false)
			# Convert from linear to decibels (approximately -80dB to 0dB)
			var db_value = linear_to_db(music_volume)
			AudioServer.set_bus_volume_db(music_bus_index, db_value)
				
	# Update music player volume if it exists
	if music_player != null:
		if music_muted:
			music_player.volume_db = linear_to_db(0)
		else:
			var db_value = linear_to_db(music_volume)
			music_player.volume_db = db_value

# Apply SFX volume settings
func _apply_sfx_volume():
	# Skip for web builds - JavaScript Bridge handles volume
#	if OS.has_feature("web"):
#		return
	
	# For non-web builds, use the audio buses
	if sfx_bus_index != -1:
		if sfx_muted:
			AudioServer.set_bus_mute(sfx_bus_index, true)
		else:
			AudioServer.set_bus_mute(sfx_bus_index, false)
			# Convert from linear to decibels
			var db_value = linear_to_db(sfx_volume)
			AudioServer.set_bus_volume_db(sfx_bus_index, db_value)
				
	# Update all sfx player volumes
	for player in sfx_players.values():
		if player != null:
			if sfx_muted:
				player.volume_db = linear_to_db(0)
			else:
				player.volume_db = linear_to_db(sfx_volume)

# Helper function to convert linear volume to decibels with a more usable range
func linear_to_db(linear_value: float) -> float:
	if linear_value <= 0:
		return -80.0  # Very low but not -INF
	# Map 0.0-1.0 to -30dB to 0dB for a more usable range
	var db_value = (linear_value * 30.0) - 30.0
	return db_value
