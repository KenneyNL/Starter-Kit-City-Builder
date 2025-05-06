extends Resource
class_name PatternRules

@export var pattern_size: Vector2i = Vector2i(2, 2)  # Size of the pattern grid
@export var rules: Array[PatternRule]  # Array of pattern rules to check 