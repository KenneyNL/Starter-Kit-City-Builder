extends Resource
class_name MissionObjective

enum ObjectiveType {
	BUILD_STRUCTURE,
	BUILD_SPECIFIC_STRUCTURE,
	BUILD_ROAD,
	BUILD_RESIDENTIAL,
	BUILD_COMMERCIAL,
	BUILD_INDUSTRIAL,
	REACH_CASH_AMOUNT,
	LEARNING,
	CUSTOM,
	MEET_CHARACTER,
	ECONOMY
}

@export var type: ObjectiveType
@export var target_count: int = 1
@export var current_count: int = 0
@export var description: String = ""
@export var structure_index: int = -1  # For BUILD_SPECIFIC_STRUCTURE type
@export var completed: bool = false

func is_completed() -> bool:
	return current_count >= target_count

func progress(amount: int = 1) -> void:
	current_count = min(current_count + amount, target_count)
	completed = is_completed()

# Function to reduce the counter (for demolition)
func regress(amount: int = 1) -> void:
	current_count = max(current_count - amount, 0)
	completed = is_completed()
