extends RefCounted
class_name ECUtilities

var alphabet : String = "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z"

func _ready():
	pass

static func _map_domain(value: float, from_domain: Dictionary, to_domain: Dictionary) -> float:
	return remap(value, from_domain.lb, from_domain.ub, to_domain.lb, to_domain.ub) 

static func _format_value(value: float, is_decimal: bool) -> String:
	return ("%.2f" if is_decimal else "%s") % snapped(value, 0.01) 

### Utility Inner functions ###

static func _contains_string(array: Array) -> bool:
	for value in array:
		if value is String:
			return true
	return false

static func _is_decimal(value: float) -> bool:
	return abs(fmod(value, 1)) > 0.0

static func _has_decimals(values: Array) -> bool:
	var temp: Array = values.duplicate(true)
	
	for dim in temp:
		for val in dim:
			if val is String:
				return false
			if abs(fmod(val, 1)) > 0.0:
				return true
	
	return false

static func _find_min_max(values: Array) -> Dictionary:
	var temp: Array = values.duplicate(true)
	var _min: float
	var _max: float
	
	var min_ts: Array
	var max_ts: Array
	for dim in temp:
		min_ts.append(dim.min())
		max_ts.append(dim.max())
	_min = min_ts.min()
	_max = max_ts.max()
	
	return { min = _min, max = _max }

static func _sample_values(values: Array, from_domain: Dictionary, to_domain: Dictionary) -> PackedFloat32Array:
	if values.is_empty():
		printerr("Trying to plot an empty dataset!")
		return PackedFloat32Array()
	
	# We are not considering String values here!!!
	
	var sampled: PackedFloat32Array = []
	
	for value in values:
		sampled.push_back(_map_domain(value, from_domain, to_domain))
	
	return sampled

static func _round_min(val: float) -> float:
	return round(val) if abs(val) < 10 else floor(val / 10.0) * 10.0

static func _round_max(val: float) -> float:
	return round(val) if abs(val) < 10 else ceil(val / 10.0) * 10.0
