extends Node
class_name AudioBridge

# This script provides a bridge between the Godot SoundManager
# and the React Audio Manager in platform-one

signal bridge_connected(is_connected)

var is_connected: bool = false

	# Connect to the React sound manager if in web environment
	#if OS.has_feature("web"):
		#connect_to_sound_manager()

# Try to connect to the React sound manager
func connect_to_sound_manager() -> bool:
	if not OS.has_feature("web"):
		return false
		
	print("AudioBridge: Attempting to connect to React Sound Manager")
	
	# Check if the JavaScriptBridge is available
	if not Engine.has_singleton("JavaScriptBridge"):
		print("AudioBridge: JavaScriptBridge singleton not available")
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Try to connect using direct function call first
	var direct_connect_script = """
	(function() {
		if (window.connectSoundManager && typeof window.connectSoundManager === 'function') {
			console.log('AudioBridge: Calling connectSoundManager directly');
			return window.connectSoundManager();
		}
		return false;
	})();
	"""
	
	var result = js.eval(direct_connect_script)
	if result == true:
		print("AudioBridge: Connected via direct call to connectSoundManager")
		is_connected = true
		bridge_connected.emit(true)
		return true
	
	# If direct call fails, try via ReactSoundBridge
	var react_bridge_script = """
	(function() {
		if (window.ReactSoundBridge && typeof window.ReactSoundBridge.isAvailable === 'function') {
			console.log('AudioBridge: Found ReactSoundBridge, checking availability');
			if (window.ReactSoundBridge.isAvailable()) {
				console.log('AudioBridge: ReactSoundBridge is available');
				
				// Get initial state
				window.ReactSoundBridge.getSoundState();
				return true;
			}
		}
		return false;
	})();
	"""
	
	result = js.eval(react_bridge_script)
	if result == true:
		print("AudioBridge: Connected via ReactSoundBridge")
		is_connected = true
		bridge_connected.emit(true)
		return true
	
	# If both methods fail, try via postMessage
	var post_message_script = """
	(function() {
		try {
			console.log('AudioBridge: Attempting to connect via postMessage');
			
			// Send a message to the parent window
			if (window.parent) {
				window.parent.postMessage({ 
					type: 'sound_manager',
					action: 'get_state',
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				
				// Set up a listener if not already
				if (!window._audioBridgeListener) {
					window._audioBridgeListener = true;
					window.addEventListener('message', function(event) {
						if (event.data && event.data.type === 'sound_manager_state') {
							console.log('AudioBridge: Received sound manager state');
							if (typeof godot_audio_state_callback === 'function') {
								godot_audio_state_callback(JSON.stringify(event.data));
							}
						}
					});
				}
				
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error connecting via postMessage', e);
			return false;
		}
	})();
	"""
	
	// Set up the callback
	js.set_callback("godot_audio_state_callback", Callable(self, "_on_audio_state_received"))
	
	result = js.eval(post_message_script)
	if result == true:
		print("AudioBridge: Connection attempted via postMessage")
		# Note: We don't set is_connected here, we wait for the callback
		return true
		
	print("AudioBridge: All connection methods failed")
	return false

# Play music through the React sound bridge
func play_music(sound_name: String) -> bool:
	if not is_connected or not OS.has_feature("web"):
		return false
		
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Try direct function call first
	var direct_call_script = """
	(function() {
		if (window.playMusic && typeof window.playMusic === 'function') {
			return window.playMusic('%s');
		} else if (window.ReactSoundBridge && typeof window.ReactSoundBridge.playMusic === 'function') {
			return window.ReactSoundBridge.playMusic('%s');
		}
		return false;
	})();
	""" % [sound_name, sound_name]
	
	var result = js.eval(direct_call_script)
	if result == true:
		return true
		
	# If direct call fails, try postMessage
	var post_message_script = """
	(function() {
		try {
			if (window.parent) {
				window.parent.postMessage({
					type: 'sound_manager',
					action: 'play_music',
					soundName: '%s',
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error sending play_music via postMessage', e);
			return false;
		}
	})();
	""" % sound_name
	
	result = js.eval(post_message_script)
	return result == true

# Play sound effect through the React sound bridge
func play_sfx(sound_name: String) -> bool:
	if not is_connected or not OS.has_feature("web"):
		return false
		
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Try direct function call first
	var direct_call_script = """
	(function() {
		if (window.playSfx && typeof window.playSfx === 'function') {
			return window.playSfx('%s');
		} else if (window.ReactSoundBridge && typeof window.ReactSoundBridge.playSfx === 'function') {
			return window.ReactSoundBridge.playSfx('%s');
		}
		return false;
	})();
	""" % [sound_name, sound_name]
	
	var result = js.eval(direct_call_script)
	if result == true:
		return true
		
	# If direct call fails, try postMessage
	var post_message_script = """
	(function() {
		try {
			if (window.parent) {
				window.parent.postMessage({
					type: 'sound_manager',
					action: 'play_sfx',
					soundName: '%s',
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error sending play_sfx via postMessage', e);
			return false;
		}
	})();
	""" % sound_name
	
	result = js.eval(post_message_script)
	return result == true

# Stop music through the React sound bridge
func stop_music() -> bool:
	if not is_connected or not OS.has_feature("web"):
		return false
		
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Try direct function call first
	var direct_call_script = """
	(function() {
		if (window.stopMusic && typeof window.stopMusic === 'function') {
			return window.stopMusic();
		} else if (window.ReactSoundBridge && typeof window.ReactSoundBridge.stopMusic === 'function') {
			return window.ReactSoundBridge.stopMusic();
		}
		return false;
	})();
	"""
	
	var result = js.eval(direct_call_script)
	if result == true:
		return true
		
	# If direct call fails, try postMessage
	var post_message_script = """
	(function() {
		try {
			if (window.parent) {
				window.parent.postMessage({
					type: 'sound_manager',
					action: 'stop_music',
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error sending stop_music via postMessage', e);
			return false;
		}
	})();
	"""
	
	result = js.eval(post_message_script)
	return result == true

# Set music volume through the React sound bridge
func set_music_volume(volume: float) -> bool:
	if not is_connected or not OS.has_feature("web"):
		return false
		
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Try direct function call first
	var direct_call_script = """
	(function() {
		if (window.setMusicVolume && typeof window.setMusicVolume === 'function') {
			return window.setMusicVolume(%f);
		} else if (window.ReactSoundBridge && typeof window.ReactSoundBridge.setMusicVolume === 'function') {
			return window.ReactSoundBridge.setMusicVolume(%f);
		}
		return false;
	})();
	""" % [volume, volume]
	
	var result = js.eval(direct_call_script)
	if result == true:
		return true
		
	# If direct call fails, try postMessage
	var post_message_script = """
	(function() {
		try {
			if (window.parent) {
				window.parent.postMessage({
					type: 'sound_manager',
					action: 'set_music_volume',
					value: %f,
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error sending set_music_volume via postMessage', e);
			return false;
		}
	})();
	""" % volume
	
	result = js.eval(post_message_script)
	return result == true

# Set SFX volume through the React sound bridge
func set_sfx_volume(volume: float) -> bool:
	if not is_connected or not OS.has_feature("web"):
		return false
		
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Try direct function call first
	var direct_call_script = """
	(function() {
		if (window.setSfxVolume && typeof window.setSfxVolume === 'function') {
			return window.setSfxVolume(%f);
		} else if (window.ReactSoundBridge && typeof window.ReactSoundBridge.setSfxVolume === 'function') {
			return window.ReactSoundBridge.setSfxVolume(%f);
		}
		return false;
	})();
	""" % [volume, volume]
	
	var result = js.eval(direct_call_script)
	if result == true:
		return true
		
	# If direct call fails, try postMessage
	var post_message_script = """
	(function() {
		try {
			if (window.parent) {
				window.parent.postMessage({
					type: 'sound_manager',
					action: 'set_sfx_volume',
					value: %f,
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error sending set_sfx_volume via postMessage', e);
			return false;
		}
	})();
	""" % volume
	
	result = js.eval(post_message_script)
	return result == true

# Toggle music mute through the React sound bridge
func toggle_music_mute() -> bool:
	if not is_connected or not OS.has_feature("web"):
		return false
		
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Try direct function call first
	var direct_call_script = """
	(function() {
		if (window.toggleMusicMute && typeof window.toggleMusicMute === 'function') {
			return window.toggleMusicMute();
		} else if (window.ReactSoundBridge && typeof window.ReactSoundBridge.toggleMusicMute === 'function') {
			return window.ReactSoundBridge.toggleMusicMute();
		}
		return false;
	})();
	"""
	
	var result = js.eval(direct_call_script)
	if result == true:
		return true
		
	# If direct call fails, try postMessage
	var post_message_script = """
	(function() {
		try {
			if (window.parent) {
				window.parent.postMessage({
					type: 'sound_manager',
					action: 'toggle_music_mute',
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error sending toggle_music_mute via postMessage', e);
			return false;
		}
	})();
	"""
	
	result = js.eval(post_message_script)
	return result == true

# Toggle SFX mute through the React sound bridge
func toggle_sfx_mute() -> bool:
	if not is_connected or not OS.has_feature("web"):
		return false
		
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Try direct function call first
	var direct_call_script = """
	(function() {
		if (window.toggleSfxMute && typeof window.toggleSfxMute === 'function') {
			return window.toggleSfxMute();
		} else if (window.ReactSoundBridge && typeof window.ReactSoundBridge.toggleSfxMute === 'function') {
			return window.ReactSoundBridge.toggleSfxMute();
		}
		return false;
	})();
	"""
	
	var result = js.eval(direct_call_script)
	if result == true:
		return true
		
	# If direct call fails, try postMessage
	var post_message_script = """
	(function() {
		try {
			if (window.parent) {
				window.parent.postMessage({
					type: 'sound_manager',
					action: 'toggle_sfx_mute',
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error sending toggle_sfx_mute via postMessage', e);
			return false;
		}
	})();
	"""
	
	result = js.eval(post_message_script)
	return result == true

# Request sound state from the React sound bridge
func get_sound_state() -> bool:
	if not OS.has_feature("web"):
		return false
		
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
		
	var js = Engine.get_singleton("JavaScriptBridge")
	
	# Set up the callback if not already
	js.set_callback("godot_audio_state_callback", Callable(self, "_on_audio_state_received"))
	
	# Try direct function call first
	var direct_call_script = """
	(function() {
		if (window.getSoundState && typeof window.getSoundState === 'function') {
			var state = window.getSoundState();
			if (typeof godot_audio_state_callback === 'function') {
				godot_audio_state_callback(JSON.stringify(state));
			}
			return true;
		} else if (window.ReactSoundBridge && typeof window.ReactSoundBridge.getSoundState === 'function') {
			return window.ReactSoundBridge.getSoundState();
		}
		return false;
	})();
	"""
	
	var result = js.eval(direct_call_script)
	if result == true:
		return true
		
	# If direct call fails, try postMessage
	var post_message_script = """
	(function() {
		try {
			if (window.parent) {
				window.parent.postMessage({
					type: 'sound_manager',
					action: 'get_state',
					source: 'godot-game',
					timestamp: Date.now()
				}, '*');
				return true;
			}
			return false;
		} catch (e) {
			console.error('AudioBridge: Error sending get_state via postMessage', e);
			return false;
		}
	})();
	"""
	
	result = js.eval(post_message_script)
	return result == true

# Called when sound state is received from React
func _on_audio_state_received(state_json: String):
	print("AudioBridge: Received audio state: ", state_json)
	
	# Parse JSON
	var json = JSON.new()
	var error = json.parse(state_json)
	
	if error == OK:
		var state = json.get_data()
		
		# Mark the bridge as connected
		if not is_connected:
			is_connected = true
			bridge_connected.emit(true)
			
		# Emit the data for other components to use
		emit_signal("sound_state_received", state)
	else:
		print("AudioBridge: Error parsing audio state JSON: ", error)
