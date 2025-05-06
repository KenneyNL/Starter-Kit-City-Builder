extends Resource
class_name PatternRule

enum RuleType {
	STRUCTURE,  # Check for specific structure
	EMPTY,      # Check for empty space
	ROTATION    # Check structure rotation
}

@export var type: RuleType = RuleType.STRUCTURE
@export var offset: Vector2i
@export var structure: Structure  # Structure to check for if type is STRUCTURE
@export var rotation: int  # Rotation to check for if type is ROTATION 