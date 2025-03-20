extends RefCounted
class_name Bar

#var rect: Rect2
#var value: Pair
#
#func _init(rect: Rect2, value: Pair = Pair.new()) -> void:
#	self.value = value
#	self.rect = rect

func _to_string() -> String:
	return "Value: %s\nRect: %s" % [self.value, self.rect]
