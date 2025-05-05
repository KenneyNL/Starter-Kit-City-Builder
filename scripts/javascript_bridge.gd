extends Node

# Make this a singleton
static var instance = null

# Signals
signal init_data_received(data)
signal init_check_received
signal mission_progress_updated(data)
signal mission_completed(data)
signal open_react_graph(data)
signal open_react_table(data)

# Variables
static var _interface = null
var _init_data = null
var _init_check_received = false
static var _pending_signals = []
var _my_js_callback = JavaScriptBridge.create_callback(receive_init_data)
var window = null

func _init():
	instance = self

# This script provides a bridge to JavaScript functionality
# while gracefully handling platforms that don't support it

func _ready():
	# Connect signals when the node is initialized
	if OS.has_feature("web"):
		window = JavaScriptBridge.get_interface("window")
		# Wait for the interface to be available
		await get_tree().process_frame
		receive_init_data("test")

		# Set up message listener and interface
		

		# Set up the interface
		_interface = JavaScript.get_interface()
		print("JavaScript interface initialized")

		# Set up callbacks in JavaScript
		JavaScriptBridge.eval("""
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


		# Process any pending signals
		_process_pending_signals()


func receive_init_data(missions_data):
	# First, let's properly log the missions_data itself
	print("Received missions data:", JSON.stringify(missions_data))

	# To get URL information, we need to extract specific properties from window.location
	if window and window.location:
		# Access specific properties of the location object
		var href = JavaScriptBridge.eval("window.location.href")
		var search = JavaScriptBridge.eval("window.location.search")
		var hostname = JavaScriptBridge.eval("window.location.hostname")

		print("URL href:", href)
		print("URL search params:", search)
		print("URL hostname:", hostname)

		# Parse URL parameters more directly
		var params_str = JavaScriptBridge.eval("""
			(function() {
				var result = {};
				var params = new URLSearchParams(window.location.search);
				params.forEach(function(value, key) {
					result[key] = value;
				});
				return JSON.stringify(result);
			})()
		""")

		# Parse the JSON string to get a Dictionary
		var params = JSON.parse_string(params_str)
		print("URL parameters:", params)

		# Now access and process the missions parameter if it exists
		if params and "missions" in params:
			var missions_json = params["missions"]
			var missions = JSON.parse_string(missions_json)
			print("Missions from URL:", missions)
			var mission_data = {"missions": missions}
			Globals.receive_data_from_browser(mission_data)

	# Also process the directly passed missions_data
	if missions_data and missions_data != "test":
		print("Processing passed missions data")
		emit_signal("init_data_received", missions_data)

	
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
	
# Helper method to convert Godot Dictionary to JSON string
static func JSON_stringify(data) -> String:
	return JSON.stringify(data)

#static func send_signal(signal_name: String, data = null):
#	if JavaScript.has_interface():
#		if _interface and _interface.has_method("emit_signal"):
#			_interface.emit_signal(signal_name, data)
#		else:
#			_pending_signals.append({"signal_name": signal_name, "data": data})
#	else:
#		_pending_signals.append({"signal_name": signal_name, "data": data})

#func send_mission_progress(mission_id: String, objective_index: int, current_count: int, target_count: int):
#	send_signal("mission_progress_updated", {
#		"mission_id": mission_id,
#		"objective_index": objective_index,
#		"current_count": current_count,
#		"target_count": target_count
#	})
#
#func send_mission_completed(mission_id: String):
#	send_signal("mission_completed", {
#		"mission_id": mission_id
#	})

static func send_open_graph(graph_data: Dictionary):
	# Format the message to match what React expects
	var message = {
		"source": "godot-game",
		"type": "open_react_graph",
		"data": graph_data
	}
	
	# First, emit the Godot signal for internal listeners

	
	# Then, send the message directly to React via postMessage for external listeners
	if OS.has_feature("web"):
#		send_signal("open_react_graph", graph_data)
		var message_json = JSON_stringify(message)
		var script = """
		(function() {
			try {
				if (window.parent) {
					console.log('Sending missionStarted message to parent window');
					window.parent.postMessage({ 
						type: 'open_react_graph',
						data: %s,
						source: 'godot-game',
						timestamp: Date.now()
					}, '*');
				} else {
					console.log('No parent window found for missionStarted event');
				}
			} catch (e) {
				console.error('Error sending missionStarted via postMessage:', e);
			}
		})();
		""" % message_json

		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")
	else:
		# For non-web platforms, add to pending signals
		_pending_signals.append({"signal_name": "open_react_graph", "data": graph_data})

static func send_open_table(table_data: Dictionary):
	# Format the message to match what React expects
	var message = {
		"source": "godot-game", 
		"type": "open_react_table",
		"data": table_data
	}
	
	# First, emit the Godot signal for internal listeners
#	emit_signal("open_react_table", table_data)
	
	# Then, send the message directly to React via postMessage for external listeners
	if OS.has_feature("web"):
		var message_json = JSON_stringify(message)
		var script = """
		(function() {
			try {
				if (window.parent) {
					console.log('Sending missionStarted message to parent window');
					window.parent.postMessage({ 
						type: 'stemCity_missionStarted',
						data: %s,
						source: 'godot-game',
						timestamp: Date.now()
					}, '*');
				} else {
					console.log('No parent window found for missionStarted event');
				}
			} catch (e) {
				console.error('Error sending missionStarted via postMessage:', e);
			}
		})();
		""" % message_json
		
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")
		
	else:
		# For non-web platforms, add to pending signals
		_pending_signals.append({"signal_name": "open_react_table", "data": table_data})

#func send_companion_dialog(dialog_type: String, dialog_data: Dictionary):
#	send_signal("companion_dialog", {
#		"type": dialog_type,
#		"data": dialog_data
#	})
#
#func send_audio_action(action: String, data: Dictionary = {}):
#	send_signal("audio_action", {
#		"action": action,
#		"data": data
#	})

# Static wrappers so send_open_ functions can be called on the class directly
#static func send_open_graph(graph_data: Dictionary) -> void:
#	if instance:
#		instance.send_open_graph(graph_data)
#	else:
#		push_error("JavaScriptBridge not initialized; cannot send_open_graph")

#static func send_open_table(table_data: Dictionary) -> void:
#	if instance:
#		instance.send_open_table(table_data)
#	else:
#		push_error("JavaScriptBridge not initialized; cannot send_open_table")
