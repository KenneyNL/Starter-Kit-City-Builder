extends PanelContainer

# Import GenericText resource type
const GenericText = preload("res://resources/generic_text_panel.resource.gd")

signal closed

# Resource data property for compatibility with generic panel system
@export var resource_data: GenericText

# References to UI controls
@onready var music_slider = $MarginContainer/VBoxContainer/MusicSection/MusicControls/MusicSlider
@onready var sfx_slider = $MarginContainer/VBoxContainer/SFXSection/SFXControls/SFXSlider
@onready var music_mute_button = $MarginContainer/VBoxContainer/MusicSection/MusicControls/MusicMuteButton
@onready var sfx_mute_button = $MarginContainer/VBoxContainer/SFXSection/SFXControls/SFXMuteButton
@onready var music_value_label = $MarginContainer/VBoxContainer/MusicSection/MusicControls/MusicValueLabel
@onready var sfx_value_label = $MarginContainer/VBoxContainer/SFXSection/SFXControls/SFXValueLabel

func _ready():
	# Hide the panel initially
	visible = false
	
	# Make sure this control blocks mouse input from passing through
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect to SoundManager signals
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager:
		sound_manager.music_volume_changed.connect(_on_music_volume_changed)
		sound_manager.sfx_volume_changed.connect(_on_sfx_volume_changed)
		sound_manager.music_muted_changed.connect(_on_music_muted_changed)
		sound_manager.sfx_muted_changed.connect(_on_sfx_muted_changed)
		
		# Initialize UI with current values
		music_slider.value = sound_manager.music_volume
		sfx_slider.value = sound_manager.sfx_volume
		music_mute_button.button_pressed = sound_manager.music_muted
		sfx_mute_button.button_pressed = sound_manager.sfx_muted
		
		# Update labels
		_update_music_label(sound_manager.music_volume)
		_update_sfx_label(sound_manager.sfx_volume)
	else:
		print("ERROR: SoundManager not found!")

func show_panel():
	visible = true
	# Pause the game when the sound panel is open to prevent
	# accidental building placement while adjusting sound
	get_tree().paused = true

func hide_panel():
	visible = false
	# Resume the game when the panel is closed
	get_tree().paused = false

func _on_close_button_pressed():
	hide_panel()
	# Emit signal that panel was closed
	closed.emit()
	
	# Consume the event to prevent click-through
	get_viewport().set_input_as_handled()

# Handle slider changes
func _on_music_slider_value_changed(value):
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager:
		sound_manager.set_music_volume(value)
		_update_music_label(value)

func _on_sfx_slider_value_changed(value):
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager:
		sound_manager.set_sfx_volume(value)
		_update_sfx_label(value)

# Handle mute button toggling
func _on_music_mute_button_toggled(toggled_on):
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager:
		sound_manager.music_muted = toggled_on

func _on_sfx_mute_button_toggled(toggled_on):
	var sound_manager = get_node_or_null("/root/SoundManager")
	if sound_manager:
		sound_manager.sfx_muted = toggled_on

# Update UI from SoundManager events
func _on_music_volume_changed(new_volume):
	music_slider.value = new_volume
	_update_music_label(new_volume)

func _on_sfx_volume_changed(new_volume):
	sfx_slider.value = new_volume
	_update_sfx_label(new_volume)

func _on_music_muted_changed(is_muted):
	music_mute_button.button_pressed = is_muted

func _on_sfx_muted_changed(is_muted):
	sfx_mute_button.button_pressed = is_muted

# Helper functions to update labels
func _update_music_label(value: float):
	music_value_label.text = str(int(value * 100)) + "%"

func _update_sfx_label(value: float):
	sfx_value_label.text = str(int(value * 100)) + "%"

# Function to apply resource data (required for compatibility with generic panel system)
func apply_resource_data(data):
	# This function is required for compatibility with the generic panel system
	# but doesn't need to do anything for the sound panel
	pass
