extends Node

# Make this a singleton
static var instance = null

# Signals

signal init_check_received
signal mission_progress_updated(data)
signal mission_completed(data)
signal open_react_graph(data)
signal open_react_table(data)

# Variables
var _interface = null
var _init_data = null
var _init_check_received = false
var _pending_signals = []

func _init():
	instance = self

# This script provides a bridge to JavaScript functionality
# while gracefully handling platforms that don't support it

func _ready():
	# Connect signals when the node is initialized
	if OS.has_feature("web"):
		# Wait for the interface to be available
		await get_tree().process_frame
		
		# Set up message listener and interface
		JavaScript.JavaScriptGlobal.eval("""
			// Create the Godot interface
			window.godot_interface = {
				_callbacks: {},
				emit_signal: function(signal_name, data) {
					console.log('Emitting signal:', signal_name, 'with data:', data);
					if (window.godot_interface._callbacks[signal_name]) {
						window.godot_interface._callbacks[signal_name](data);
					}
				}
			};
			
			// Set up message listener
			window.addEventListener('message', function(event) {
				console.log('Received message:', event.data);
				
				// Handle the message
				if (event.data && event.data.type) {
					switch(event.data.type) {
						case 'cityBuilder_init':
							console.log('Received init data:', event.data.data);
							window.godot_interface.emit_signal('init_data_received', event.data.data);
							break;
						case 'cityBuilder_init_check':
							console.log('Received init check');
							window.godot_interface.emit_signal('init_check_received');
							break;
						case 'mission_progress_updated':
							window.godot_interface.emit_signal('mission_progress_updated', event.data.data);
							break;
						case 'mission_completed':
							window.godot_interface.emit_signal('mission_completed', event.data.data);
							break;
						case 'open_react_graph':
							window.godot_interface.emit_signal('open_react_graph', event.data.data);
							break;
						case 'open_react_table':
							window.godot_interface.emit_signal('open_react_table', event.data.data);
							break;
					}
				}
			});
		""")
		
		# Set up the interface
		_interface = JavaScript.get_interface()
		print("JavaScript interface initialized")
		
		# Set up callbacks in JavaScript
		JavaScript.JavaScriptGlobal.eval("""
			window.godot_interface._callbacks.init_data_received = function(data) {
				console.log('Emitting init_data_received signal with data:', data);
				// Don't re-emit the signal to avoid recursion
				window.godot_interface._callbacks.init_data_received = null;
			};
			window.godot_interface._callbacks.init_check_received = function() {
				console.log('Emitting init_check_received signal');
				// Don't re-emit the signal to avoid recursion
				window.godot_interface._callbacks.init_check_received = null;
			};
			window.godot_interface._callbacks.mission_progress_updated = function(data) {
				window.godot_interface.emit_signal('mission_progress_updated', data);
			};
			window.godot_interface._callbacks.mission_completed = function(data) {
				window.godot_interface.emit_signal('mission_completed', data);
			};
			window.godot_interface._callbacks.open_react_graph = function(data) {
				window.godot_interface.emit_signal('open_react_graph', data);
			};
			window.godot_interface._callbacks.open_react_table = function(data) {
				window.godot_interface.emit_signal('open_react_table', data);
			};
		""")
		print("JavaScript callbacks set up")
		
		# Send init data from URL parameters if present
		JavaScript.JavaScriptGlobal.eval("""
			(function() {
				var params = new URLSearchParams(window.location.search);
				if (params.has('missions')) {
					try {
						var missions = JSON.parse(decodeURIComponent(params.get('missions')));
						console.log('Sending init data from URL:', missions);
						window.godot_interface.emit_signal('init_data_received', missions);
					} catch (e) {
						console.error('Failed to parse missions param:', e);
					}
				}
			})();
		""")
		
		# Process any pending signals
		_process_pending_signals()

func _process_pending_signals():
	if _pending_signals.size() > 0:
		print("Processing pending signals...")
		for signal_data in _pending_signals:
			emit_signal(signal_data.signal_name, signal_data.data)
		_pending_signals.clear()
		print("All pending signals processed")

# Static methods for interface checks
static func has_interface() -> bool:
	return JavaScript.has_interface()

static func get_interface():
	return JavaScript.get_interface()

func send_signal(signal_name: String, data = null):
	if JavaScript.has_interface():
		if _interface and _interface.has_method("emit_signal"):
			_interface.emit_signal(signal_name, data)
		else:
			_pending_signals.append({"signal_name": signal_name, "data": data})
	else:
		_pending_signals.append({"signal_name": signal_name, "data": data})

func send_mission_progress(mission_id: String, objective_index: int, current_count: int, target_count: int):
	send_signal("mission_progress_updated", {
		"mission_id": mission_id,
		"objective_index": objective_index,
		"current_count": current_count,
		"target_count": target_count
	})

func send_mission_completed(mission_id: String):
	send_signal("mission_completed", {
		"mission_id": mission_id
	})

func send_open_graph(graph_data: Dictionary):
	send_signal("open_react_graph", graph_data)

func send_open_table(table_data: Dictionary):
	send_signal("open_react_table", table_data)

func send_companion_dialog(dialog_type: String, dialog_data: Dictionary):
	send_signal("companion_dialog", {
		"type": dialog_type,
		"data": dialog_data
	})

func send_audio_action(action: String, data: Dictionary = {}):
	send_signal("audio_action", {
		"action": action,
		"data": data
	})
