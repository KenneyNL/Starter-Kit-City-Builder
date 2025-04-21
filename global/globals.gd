extends Node

@export var population: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
	
func set_population_count(count: int) -> void:
	# Update the population count
	population += count
	
	# Emit the signal to notify other nodes
	EventBus.population_update.emit(population)
	
	# Print the updated population for debugging
