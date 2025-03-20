extends RefCounted
class_name ArrayOperations

static func add_int(array: Array, _int: int) -> Array:
	var t: Array = array.duplicate(true)
	for ti in t.size():
		t[ti] = int(t[ti] + _int)
	return t

static func add_float(array: Array, _float: float) -> Array:
	var t: Array = array.duplicate(true)
	for ti in t.size():
		t[ti] = float(t[ti] + _float)
	return t

static func multiply_int(array: Array, _int: int) -> Array:
	var t: Array = array.duplicate(true)
	for ti in t.size():
		t[ti] = int(t[ti] * _int)
	return t

static func multiply_float(array: Array, _float: float) -> PackedFloat32Array:
	var t: PackedFloat32Array = array.duplicate(true)
	for ti in t.size():
		t[ti] = float(t[ti] * _float)
	return t

static func pow(array: Array, _int: int) -> Array:
	var t: Array = array.duplicate(true)
	for ti in t.size():
		t[ti] = float(pow(t[ti], _int))
	return t

static func cos(array: Array) -> Array:
	var t: Array = array.duplicate(true)
	for val in array.size():
		t[val] = cos(t[val])
	return t

static func sin(array: Array) -> Array:
	var t: Array = array.duplicate(true)
	for val in array.size():
		t[val] = sin(t[val])
	return t

static func affix(array: Array, _string: String) -> Array:
	var t: Array = array.duplicate(true)
	for val in array.size():
		t[val] = str(t[val]) + _string
	return t

static func suffix(array: Array, _string: String) -> Array:
	var t: Array = array.duplicate(true)
	for val in array.size():
		t[val] = _string + str(t[val])
	return t
