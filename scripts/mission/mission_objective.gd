extends Resource
class_name MissionObjective

const PatternRule = preload("res://scripts/mission/pattern_rule.gd")
const PatternRules = preload("res://scripts/mission/pattern_rules.gd")

enum ObjectiveType {
	BUILD = 0,
	POPULATION = 1,
	POWER = 2,
	PATTERN = 3,  # Pattern matching type
	LEARNING = 4  # Learning objective type
}

@export var type: ObjectiveType = ObjectiveType.BUILD
@export var target_count: int = 0
@export var current_count: int = 0
@export var description: String = ""
@export var completed: bool = false
@export var structure: Structure  # The structure to build/check for
@export var pattern_rules: PatternRules  # Rules for pattern matching

func check_pattern(builder: Node) -> bool:
	if type != ObjectiveType.PATTERN || !pattern_rules:
		return false
		
	# Get the grid from the builder
	var grid = builder.get_node("Grid")
	if !grid:
		return false
		
	# Scan the grid for the pattern
	var grid_size = grid.get_grid_size()
	for x in range(grid_size.x - pattern_rules.pattern_size.x + 1):
		for y in range(grid_size.y - pattern_rules.pattern_size.y + 1):
			if check_pattern_at_position(grid, Vector2i(x, y)):
				return true
	
	return false

func check_pattern_at_position(grid: Node, start_pos: Vector2i) -> bool:
	# Check each position in the pattern
	for rule in pattern_rules.rules:
		var check_pos = start_pos + rule.offset
		var cell = grid.get_cell(check_pos.x, check_pos.y)
		
		# Check if the cell matches the rule
		if !cell:
			return false
			
		match rule.type:
			PatternRule.RuleType.STRUCTURE:
				if !cell.has_structure(rule.structure):
					return false
			PatternRule.RuleType.EMPTY:
				if cell.has_any_structure():
					return false
			PatternRule.RuleType.ROTATION:
				if cell.get_rotation() != rule.rotation:
					return false
	
	return true

func update_progress(builder: Node) -> void:
	match type:
		ObjectiveType.BUILD:
			if structure:
				current_count = builder.count_structure(structure)
		ObjectiveType.POPULATION:
			current_count = builder.get_total_population()
		ObjectiveType.POWER:
			current_count = builder.get_total_power()
		ObjectiveType.PATTERN:
			completed = check_pattern(builder)
			if completed:
				current_count = target_count
		ObjectiveType.LEARNING:
			# Learning objectives are completed through UI interaction
			pass
	
	completed = (type == ObjectiveType.PATTERN && completed) || (type == ObjectiveType.LEARNING && completed) || current_count >= target_count

func is_completed() -> bool:
	return completed

# Function to reduce the counter (for demolition)
func regress(amount: int = 1) -> void:
	current_count = max(current_count - amount, 0)
	completed = is_completed()
