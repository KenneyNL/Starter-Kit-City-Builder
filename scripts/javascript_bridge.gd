extends Node
class_name JSBridge

# This script provides a bridge to JavaScript functionality
# while gracefully handling platforms that don't support it

# Check if JavaScript is available
static func has_interface() -> bool:
	# Check if running in a web environment
	# Use OS.has_feature("web") for consistency with sound_manager.gd
	if OS.has_feature("web"):
		print("Running in web environment, JavaScript should be available")
		
		# Double-check by evaluating a simple script
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			var test_result = js.eval("!!window && typeof window !== 'undefined'")
			print("JavaScript test result: " + str(test_result))
			return test_result != null
		else:
			print("JavaScriptBridge singleton not available, running in editor or non-web platform")
	else:
		print("Not running in web environment")
	
	return false

# Get the JavaScript interface
static func get_interface():
	if has_interface():
		return JavaScriptGlobal
	return null

# JavaScriptGlobal is a mock class that provides fallback implementations
# for platforms that don't support JavaScript
class JavaScriptGlobal:
	# Check if a JavaScript function exists
	static func has_function(function_name: String) -> bool:
		if not OS.has_feature("web"):
			return false
		
		print("Checking if function exists: " + function_name)	
		var script = "typeof %s === 'function'" % function_name
		
		# Use Engine.get_singleton for consistency with sound_manager.gd
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			var result = js.eval(script)
			
			# If result is null, the JavaScript eval failed
			if result == null:
				print("JavaScript eval failed when checking for function: " + function_name)
				return false
				
			print("Function check result for " + function_name + ": " + str(result))
			return result
		else:
			print("JavaScriptBridge singleton not available")
			return false
		
	# Evaluate JavaScript code
	static func eval(script: String):
		if not OS.has_feature("web"):
			return null
		
		# Use Engine.get_singleton for consistency with sound_manager.gd
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			return js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")
			return null
		
	# Call a JavaScript function with arguments
	static func call_js_function(function_name: String, args = []):
		if not OS.has_feature("web"):
			return null
		
		var formatted_args = []
		for arg in args:
			if arg is String:
				formatted_args.append("\"%s\"" % arg.replace("\"", "\\\""))
			elif arg is Dictionary or arg is Array:
				formatted_args.append(JSON.stringify(arg))
			else:
				formatted_args.append(str(arg))
				
		var script = "%s(%s)" % [function_name, ",".join(formatted_args)]
		
		# Use Engine.get_singleton for consistency with sound_manager.gd
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			return js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")
			return null
		
	# Connect to the learning companion - legacy method with postMessage fallback
	static func connectLearningCompanion(success_callback = null, error_callback = null):
		print("Attempting to connect to learning companion")
		
		if not OS.has_feature("web"):
			print("Skipping learning companion connection on non-web platform")
			if error_callback != null and error_callback.is_valid():
				error_callback.call()
			return
		
		# Always use postMessage approach regardless of function availability
		connectLearningCompanionViaPostMessage(success_callback, error_callback)
	
	# Connect to the learning companion using only postMessage
	static func connectLearningCompanionViaPostMessage(success_callback = null, error_callback = null):
		print("Connecting to learning companion via postMessage")
		
		if not OS.has_feature("web"):
			print("Skipping learning companion connection on non-web platform")
			if error_callback != null and error_callback.is_valid():
				error_callback.call()
			return
		
		# Use postMessage approach exclusively - note: no return statements allowed in the script
		var script = """
		(function() {
			try {
				// Send a message directly to the parent window
				if (window.parent) {
					console.log('Sending connection message to parent window');
					window.parent.postMessage({ 
						type: 'stemCity_connect',
						source: 'godot-game',
						timestamp: Date.now()
					}, '*');
					
					// Set up a global event listener for responses if not already set up
					if (!window._stemCityListenerInitialized) {
						window._stemCityListenerInitialized = true;
						window.addEventListener('message', function(event) {
							console.log('Game received message:', event.data);
							if (event.data && event.data.type === 'stemCity_connect_ack') {
								console.log('Received connection acknowledgment from parent');
							}
						});
					}
					
					// Don't use return statements here - they're not allowed in top-level eval
					var result = true; 
				} else {
					console.log('No parent window found');
					var result = false;
				}
			} catch (e) {
				console.error('Error connecting via postMessage:', e);
				var result = false;
			}
		})();
		"""
		
		# Use Engine.get_singleton for consistency with sound_manager.gd
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			js.eval(script)
			
			# Always consider this a success - we'll use the force connection timer as backup
			print("Sent connection message via postMessage")
			
			# Try to ensure audio is initialized as well since we now have user interaction
			JavaScriptGlobal.ensure_audio_initialized()
			
			if success_callback != null and success_callback.is_valid():
				success_callback.call()
		else:
			print("JavaScriptBridge singleton not available")
			if error_callback != null and error_callback.is_valid():
				error_callback.call()
				
	# The following methods call the JavaScript functions for game events using postMessage
	
	static func onGameStarted():
		if not OS.has_feature("web"):
			return
			
		print("Sending game started event via postMessage")
		var script = """
		(function() {
			try {
				if (window.parent) {
					console.log('Sending gameStarted message to parent window');
					window.parent.postMessage({ 
						type: 'stemCity_gameStarted',
						source: 'godot-game',
						timestamp: Date.now() 
					}, '*');
				} else {
					console.log('No parent window found for gameStarted event');
				}
			} catch (e) {
				console.error('Error sending gameStarted via postMessage:', e);
			}
		})();
		"""
		
		# Use Engine.get_singleton for consistency with sound_manager.gd
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")
				
	static func onMissionStarted(mission_data: Dictionary):
		if not OS.has_feature("web"):
			return
			
		print("Sending mission started event for mission: " + str(mission_data.get("id", "unknown")))
		var mission_json = JSON.stringify(mission_data)
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
		""" % mission_json
		
		# Use Engine.get_singleton for consistency with sound_manager.gd
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")
				
	static func onMissionCompleted(mission_data: Dictionary):
		if not OS.has_feature("web"):
			return
			
		print("Sending mission completed event for mission: " + str(mission_data.get("id", "unknown")))
		var mission_json = JSON.stringify(mission_data)
		var script = """
		(function() {
			try {
				if (window.parent) {
					console.log('Sending missionCompleted message to parent window');
					window.parent.postMessage({ 
						type: 'stemCity_missionCompleted',
						data: %s,
						source: 'godot-game',
						timestamp: Date.now()
					}, '*');
				} else {
					console.log('No parent window found for missionCompleted event');
				}
			} catch (e) {
				console.error('Error sending missionCompleted via postMessage:', e);
			}
		})();
		""" % mission_json
		
		# Use Engine.get_singleton for consistency with sound_manager.gd
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")
				
	static func onAllMissionsCompleted():
		if not OS.has_feature("web"):
			return
			
		print("Sending all missions completed event")
		var script = """
		(function() {
			try {
				if (window.parent) {
					console.log('Sending allMissionsCompleted message to parent window');
					window.parent.postMessage({ 
						type: 'stemCity_allMissionsCompleted',
						source: 'godot-game',
						timestamp: Date.now()
					}, '*');
				} else {
					console.log('No parent window found for allMissionsCompleted event');
				}
			} catch (e) {
				console.error('Error sending allMissionsCompleted via postMessage:', e);
			}
		})();
		"""
		
		# Use Engine.get_singleton for consistency with sound_manager.gd
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge") 
			js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")

	# Handle audio actions via JavaScript
	static func handle_audio_action(action: String, sound_name: String = "", volume: float = -1.0):
		if not OS.has_feature("web"):
			return false
		
		print("Handling audio action via JavaScript bridge: " + action)
		
		var action_data = {
			"action": action,
			"sound": sound_name,
		}
		
		if volume >= 0.0:
			action_data["volume"] = volume
			
		var action_json = JSON.stringify(action_data)
		var script = """
		(function() {
			try {
				if (window.parent) {
					console.log('Sending audio action to parent window:', %s);
					window.parent.postMessage({ 
						type: 'stemCity_audio',
						data: %s,
						source: 'godot-game',
						timestamp: Date.now()
					}, '*');
					return true;
				} else {
					console.log('No parent window found for audio action');
					return false;
				}
			} catch (e) {
				console.error('Error sending audio action via postMessage:', e);
				return false;
			}
		})();
		""" % [action_json, action_json]
		
		if Engine.has_singleton("JavaScriptBridge"):
			var js = Engine.get_singleton("JavaScriptBridge")
			return js.eval(script)
		else:
			print("JavaScriptBridge singleton not available")
			return false
	
	# Helper method to ensure the sound manager's audio is initialized
	# Call this method after user interaction to ensure audio works
	static func ensure_audio_initialized():
		if not OS.has_feature("web"):
			return true # Audio always works on non-web platforms
			
		print("Ensuring audio is initialized via JavaScript bridge")
		
		# Setup audio message listener if it's not already set up
		setup_audio_message_listener()
		
		# Try to initialize audio through the sound manager if it exists
		var sound_manager = _get_sound_manager()
			
		if sound_manager and sound_manager.has_method("init_web_audio_from_js"):
			print("Found SoundManager, calling init_web_audio_from_js")
			sound_manager.init_web_audio_from_js()
			
			# Follow up with direct JavaScript audio context unlocking for extra reliability
			if Engine.has_singleton("JavaScriptBridge"):
				var js = Engine.get_singleton("JavaScriptBridge")
				_run_audio_unlock_script(js)
			
			return true
		else:
			# Fallback: directly try to unlock web audio using JavaScript
			if Engine.has_singleton("JavaScriptBridge"):
				var js = Engine.get_singleton("JavaScriptBridge")
				var result = _run_audio_unlock_script(js)
				return result
			else:
				print("JavaScriptBridge singleton not available for audio initialization")
				return false
				
	# Helper method to run the audio unlocking script with maximum compatibility
	static func _run_audio_unlock_script(js_interface):
		var script = """
		(function() {
			var result = false;
			try {
				// Simple approach to unlock audio
				console.log('Running simplified audio unlock');
				
				// Create audio context if needed
				if (!window._godotAudioContext) {
					window._godotAudioContext = new (window.AudioContext || window.webkitAudioContext)();
				}
				
				var audioCtx = window._godotAudioContext;
				console.log('Audio context state:', audioCtx.state);
				
				// Resume it (for Chrome/Safari)
				if (audioCtx.state === 'suspended') {
					audioCtx.resume();
				}
				
				// Play a short, quiet beep
				var oscillator = audioCtx.createOscillator();
				var gainNode = audioCtx.createGain();
				gainNode.gain.value = 0.01; // Very quiet
				oscillator.connect(gainNode);
				gainNode.connect(audioCtx.destination);
				oscillator.start(0);
				oscillator.stop(0.1);
				
				// Add event listeners for future interactions
				['click', 'touchstart', 'touchend'].forEach(function(event) {
					document.addEventListener(event, function() {
						if (audioCtx.state === 'suspended') {
							audioCtx.resume();
						}
					}, {once: false});
				});
				
				result = audioCtx.state === 'running';
			} catch (e) {
				console.error("JavaScript bridge: Audio unlock error:", e);
				result = false;
			}
			return result;
		})()
		"""
		
		var result = js_interface.eval(script)
		print("JavaScript audio initialization result:", result)
		return result
		
	# Setup audio message listener from JavaScript
	static func setup_audio_message_listener():
		if not OS.has_feature("web"):
			return false
			
		print("Setting up audio message listener via JavaScript bridge")
		
		if not Engine.has_singleton("JavaScriptBridge"):
			print("JavaScriptBridge singleton not available")
			return false
			
		var js = Engine.get_singleton("JavaScriptBridge")
		
		# Register the callback function
		js.set_callback("godot_audio_callback", Callable(_get_sound_manager(), "process_js_audio_state"))
		
		# Set up a listener for audio state messages
		var script = """
		(function() {
			// Set up message listener if not already done
			if (!window.godot_audio_listener_initialized) {
				window.addEventListener('message', function(event) {
					if (event.data && event.data.type === 'stemCity_audio_state') {
						console.log('Godot received audio state:', event.data);
						// Call our Godot callback with the state data
						if (typeof godot_audio_callback === 'function') {
							console.log('Sending audio state to Godot');
							godot_audio_callback(event.data.data);
						} else {
							console.warn('godot_audio_callback is not available');
						}
					}
				});
				
				console.log('Audio message listener initialized');
				window.godot_audio_listener_initialized = true;
				
				// Request initial audio state from parent
				window.parent.postMessage({
					type: 'stemCity_audio',
					data: { action: 'GET_STATE' },
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				
				return true;
			}
			return false;
		})();
		"""
		
		var result = js.eval(script)
		print("Audio message listener setup result: ", result)
		return result
	
	# Helper to get the sound manager instance
	static func _get_sound_manager():
		var sound_manager = null
		
		# Try to find using meta
		if Engine.get_main_loop().has_meta("sound_manager"):
			sound_manager = Engine.get_main_loop().get_meta("sound_manager")
		else:
			# Try to find in scene tree
			var scene_tree = Engine.get_main_loop() as SceneTree
			if scene_tree:
				sound_manager = scene_tree.root.get_node_or_null("/root/SoundManager")
				
		return sound_manager
