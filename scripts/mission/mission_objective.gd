extends Resource
class_name MissionObjective

const ObjectiveType = preload("res://configs/data.config.gd").ObjectiveType

@export var type: ObjectiveType
@export var target_count: int = 1
@export var current_count: int = 0
@export var description: String = ""
@export var completed: bool = false

@export_subgroup("Structure")
@export var structure: Structure

func is_completed() -> bool:
	return current_count >= target_count

func progress(amount: int = 1) -> void:
	current_count = min(current_count + amount, target_count)
	completed = is_completed()

# Function to reduce the counter (for demolition)
func regress(amount: int = 1) -> void:
	current_count = max(current_count - amount, 0)
	completed = is_completed()
