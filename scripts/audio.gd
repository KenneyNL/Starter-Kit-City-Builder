extends Node

# Code adapted from KidsCanCode

var num_players = 12
var bus = "master"

var available = []  # The available players.
var queue = []  # The queue of {path, volume} dictionaries.

func _ready():
	for i in num_players:
		var p = AudioStreamPlayer.new()
		add_child(p)

		available.append(p)

		p.volume_db = -10
		p.finished.connect(_on_stream_finished.bind(p))
		p.bus = bus

func _on_stream_finished(stream):
	available.append(stream)

func play(sound_path: String, volume_db: float = -10.0):
	# Path (or multiple, separated by commas)
	var sounds = sound_path.split(",")
	var chosen = "res://" + sounds[randi() % sounds.size()].strip_edges()
	queue.append({
		"path": chosen,
		"volume": volume_db
	})

func _process(_delta):
	if not queue.is_empty() and not available.is_empty():
		var item = queue.pop_front()
		var player = available.pop_front()

		player.stream = load(item["path"])
		player.volume_db = item["volume"]
		player.pitch_scale = randf_range(0.9, 1.1)
		player.play()
