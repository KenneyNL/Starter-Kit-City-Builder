extends Node

# JavaScript global class for handling JavaScript functionality
class_name JavaScript

# Check if JavaScript is available
static func has_interface() -> bool:
	# Check if running in a web environment
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