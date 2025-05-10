extends Node

# This script handles overall game management tasks, including audio management and UI interactions.
var config = ConfigFile.new()

# Sound manager reference
var sound_manager: Node

var music_player: AudioStreamPlayer
var building_sfx: AudioStreamPlayer
var construction_sfx: AudioStreamPlayer

@onready var generic_text_panel = $CanvasLayer/GenericTextPanel

# Export variables for intro and outro resource
@export var intro_text_resource: GenericText
@export var outro_text_resource: GenericText

# Node references
@onready var building_selector = get_node_or_null("CanvasLayer/BuildingSelector")
@onready var resource_display = get_node_or_null("CanvasLayer/ResourceDisplay")
@onready var game_menu = get_node_or_null("CanvasLayer/GameMenu")

func _ready():
	print("GameManager: Initializing...")
	# Load data from a file.
	var err = config.load("user://config.cfg")
	# If the file didn't load, ignore it.
	if err != OK:
		print("GameManager: No config file found, using defaults")
		config = ConfigFile.new()
		
	# Get sound manager reference
	sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager:
		print("GameManager: Found sound manager, connecting signals")
		# Connect to sound manager signals
		sound_manager.music_volume_changed.connect(_on_music_volume_changed)
		sound_manager.sfx_volume_changed.connect(_on_sfx_volume_changed)
		sound_manager.music_muted_changed.connect(_on_music_muted_changed)
		sound_manager.sfx_muted_changed.connect(_on_sfx_muted_changed)
		
		# Load saved volume settings
		var saved_music_volume = config.get_value("audio", "music_volume", 0.1)
		var saved_sfx_volume = config.get_value("audio", "sfx_volume", 0.1)
		var saved_music_muted = config.get_value("audio", "music_muted", false)
		var saved_sfx_muted = config.get_value("audio", "sfx_muted", false)
		
		print("GameManager: Loading saved settings - Music: ", saved_music_volume, " SFX: ", saved_sfx_volume)
		print("GameManager: Loading saved mute states - Music: ", saved_music_muted, " SFX: ", saved_sfx_muted)
		
		# Apply saved settings
		sound_manager.music_volume = saved_music_volume
		sound_manager.sfx_volume = saved_sfx_volume
		sound_manager.music_muted = saved_music_muted
		sound_manager.sfx_muted = saved_sfx_muted
	else:
		print("GameManager: Warning - Sound manager not found!")
	
	# Register SoundManager in the main loop for JavaScript bridge to find
	Engine.get_main_loop().set_meta("sound_manager", sound_manager)
	
	# Reference to the controls panel and HUD
	var controls_panel = get_node_or_null("CanvasLayer/ControlsPanel")
	var hud = get_node_or_null("CanvasLayer/HUD")
	
	# Set up the HUD's reference to the panels
	if hud and controls_panel:
		hud.controls_panel = controls_panel
	
	# Show intro text if available
	if generic_text_panel and intro_text_resource:
		generic_text_panel.apply_resource_data(intro_text_resource)
		generic_text_panel.show_panel()
		
		generic_text_panel.closed.connect(func():
			if generic_text_panel and generic_text_panel.resource_data and generic_text_panel.resource_data.panel_type == 0 and controls_panel:
				controls_panel.show_panel()
		)
	
	# Connect controls panel closed signal
	if controls_panel:
		controls_panel.closed.connect(_on_controls_panel_closed)
	
	# Check for audio initialization status (important for web)
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
		print("GameManager: Connected to Builder signals")
		
	# Connect to construction signals via deferred call to make sure everything is ready
	call_deferred("_setup_construction_signals")
	
	# Make sure sound buses are properly configured
	call_deferred("_setup_sound_buses")
	
	# Connect the building selector to the builder
	if building_selector:
		if builder:
			building_selector.builder = builder
			print("GameManager: Connected BuildingSelector to Builder")
		else:
			print("GameManager: Warning - Builder not found!")
	else:
		print("GameManager: Warning - BuildingSelector not found!")
	
	# Connect builder's cash display to HUD
	if builder and hud:
		builder.cash_display = hud.get_node("PanelContainer/HBoxContainer/CashItem/CashLabel")
	
	# Start background music
	_start_background_music()
	
	# Connect economy manager signals to HUD
	var economy_manager = get_node_or_null("EconomyManager")
	var hud_manager = get_node_or_null("CanvasLayer/HUD")
	
	if economy_manager and hud_manager:
		economy_manager.money_changed.connect(hud_manager.update_money)
		economy_manager.population_changed.connect(hud_manager.update_population_count)
		economy_manager.energy_balance_changed.connect(hud_manager.update_energy_balance)

	# Initialize managers
	_initialize_managers()
	
	# Connect signals
	_connect_signals()
	
	# Initialize game state
	_initialize_game_state()
	
	# Start the game
	start_game()

func _on_music_volume_changed(new_volume: float):
	print("GameManager: Music volume changed to ", new_volume)
	config.set_value("audio", "music_volume", new_volume)
	var err = config.save("user://config.cfg")
	if err != OK:
		print("GameManager: Error saving music volume: ", err)

func _on_sfx_volume_changed(new_volume: float):
	print("GameManager: SFX volume changed to ", new_volume)
	config.set_value("audio", "sfx_volume", new_volume)
	var err = config.save("user://config.cfg")
	if err != OK:
		print("GameManager: Error saving SFX volume: ", err)

func _on_music_muted_changed(is_muted: bool):
	print("GameManager: Music mute changed to ", is_muted)
	config.set_value("audio", "music_muted", is_muted)
	var err = config.save("user://config.cfg")
	if err != OK:
		print("GameManager: Error saving music mute: ", err)

func _on_sfx_muted_changed(is_muted: bool):
	print("GameManager: SFX mute changed to ", is_muted)
	config.set_value("audio", "sfx_muted", is_muted)
	var err = config.save("user://config.cfg")
	if err != OK:
		print("GameManager: Error saving SFX mute: ", err)

# Initialize all game audio - called immediately on desktop, after user interaction for web
func _initialize_game_audio():
	# Set up all audio systems
	setup_background_music()
	setup_building_sfx()
	setup_construction_sfx()

# This function is called when the controls panel is closed
func _on_controls_panel_closed():
	pass

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
		music_player.bus = "Music"  # Use the Music bus
		
		# Set initial volume
		if sound_manager:
			music_player.volume_db = sound_manager.linear_to_db(sound_manager.music_volume)
		
		# Check if we can play audio immediately (desktop) or need to wait (web)
		var can_play_now = true
		if OS.has_feature("web"):
			var sound_manager = get_node_or_null("/root/SoundManager")
			if sound_manager:
				can_play_now = sound_manager.audio_initialized
				
				# If not initialized, connect to the ready signal
				if not can_play_now:
					sound_manager.audio_ready.connect(_start_background_music)
		
		# Play immediately if allowed
		if can_play_now:
			_start_background_music()
	else:
		print("GameManager: Warning - Could not load music file!")
		# Try a fallback sound as music
		var fallback_sound = load("res://sounds/building_placing.wav")
		if fallback_sound:
			music_player.stream = fallback_sound
			music_player.bus = "Music"
			
			# Set initial volume
			if sound_manager:
				music_player.volume_db = sound_manager.linear_to_db(sound_manager.music_volume)
			
			# Check if we can play immediately
			var can_play_now = true
			if OS.has_feature("web"):
				var sound_manager = get_node_or_null("/root/SoundManager")
				if sound_manager:
					can_play_now = sound_manager.audio_initialized
			
			if can_play_now:
				music_player.play()
		else:
			print("GameManager: Error - Could not load fallback sound!")

# Start background music playing (called directly or via signal)
func _start_background_music():
	if music_player and music_player.stream and not music_player.playing:
		# For web builds, use a simple approach to starting audio
		if OS.has_feature("web"):
			# Make sure we start from the beginning
			music_player.stop()
			music_player.seek(0.0)
			
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


func _on_mission_manager_all_missions_completed() -> void:
	if generic_text_panel and outro_text_resource:
		generic_text_panel.apply_resource_data(outro_text_resource)
		generic_text_panel.show_panel()


func _on_mission_manager_mission_started(mission: MissionData) -> void:
	var mission_manager: Node = get_node_or_null("/root/Main/MissionManager")
	if mission_manager and mission_manager.mission_ui:
		mission_manager.mission_ui.update_mission_display(mission)
		
	var mission_text = GenericText.new()
	mission_text.panel_type = 2
	mission_text.title = mission.title
	mission_text.body_text = mission.description
	mission_text.button_text = "Start Mission"
	
	print(generic_text_panel)
	if generic_text_panel:
		generic_text_panel.apply_resource_data(mission_text)
		generic_text_panel.show_panel()
		

func _initialize_managers():
	print("GameManager: Initializing managers")
	# Initialize any required managers here
	pass

func _connect_signals():
	print("GameManager: Connecting signals")
	# Connect any required signals here
	pass

func _initialize_game_state():
	print("GameManager: Initializing game state")
	# Initialize game state here
	pass

func start_game():
	print("GameManager: Starting game")
	# Start game logic here
	pass
