extends Node

# Resource parameters
var money: float = 1000.0
var population: int = 0
var energy_consumption: float = 0.0
var energy_production: float = 0.0

# Economic parameters
var money_per_population: float = 1.0  # Money earned per population per second
var base_energy_cost: float = 0.1      # Base energy cost per population
var tax_rate: float = 0.1              # Tax rate on population income

# Building costs
var building_costs := {
	"small_house": 100,
	"medium_house": 250,
	"large_house": 500,
	"power_plant": 1000,
	"road": 50
}

# Building effects
var building_population := {
	"small_house": 10,
	"medium_house": 25,
	"large_house": 50
}

var building_energy := {
	"power_plant": 100.0,  # Energy produced per second
	"small_house": 5.0,    # Energy consumed per second
	"medium_house": 12.0,
	"large_house": 25.0
}

# Signals
signal money_changed(new_amount: float)
signal population_changed(new_population: int)
signal energy_balance_changed(production: float, consumption: float)

func _ready():
	# Start the economy tick
	$EconomyTimer.start()

func _process(_delta):
	# Update energy balance
	energy_consumption = calculate_total_energy_consumption()
	emit_signal("energy_balance_changed", energy_production, energy_consumption)

func calculate_total_energy_consumption() -> float:
	var total := 0.0
	for building_type in building_energy:
		if building_type != "power_plant":  # Skip power plants as they produce energy
			total += building_energy[building_type] * get_building_count(building_type)
	return total

func get_building_count(building_type: String) -> int:
	var builder = get_node_or_null("/root/Main/Builder")
	if not builder:
		return 0
		
	var count = 0
	for structure in builder.structures:
		if structure.model and structure.model.resource_path.contains(building_type):
			count += 1
	return count

func can_afford_building(building_type: String) -> bool:
	return money >= building_costs.get(building_type, 0)

func purchase_building(building_type: String) -> bool:
	if can_afford_building(building_type):
		money -= building_costs[building_type]
		emit_signal("money_changed", money)
		
		# Update population if it's a house
		if building_type in building_population:
			population += building_population[building_type]
			emit_signal("population_changed", population)
		
		# Update energy if it's a power plant
		if building_type == "power_plant":
			energy_production += building_energy["power_plant"]
		
		return true
	return false

func _on_economy_timer_timeout():
	# Calculate income from population
	var income = population * money_per_population * tax_rate
	money += income
	emit_signal("money_changed", money) 
