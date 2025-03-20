extends RefCounted
class_name Point

var position: Vector2
var value: Dictionary

func _init(position: Vector2, value: Dictionary) -> void:
    self.position = position
    self.value = value

func _to_string() -> String:
    return "Value: %s\nPosition: %s" % [self.value, self.position]
