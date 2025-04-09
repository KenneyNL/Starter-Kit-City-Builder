extends CanvasLayer

# Time in seconds to display the attribution screen
const DISPLAY_TIME: float = 3.0
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"

func _ready():
	# Set up the timer to automatically transition to the main scene
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = DISPLAY_TIME
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _on_timer_timeout():
	# Fade out the attribution screen
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(change_scene)

func change_scene():
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
