extends Resource
class_name Structure

enum StructureType {
	ROAD,
	RESIDENTIAL_BUILDING,
	COMMERCIAL_BUILDING,
	INDUSTRIAL_BUILDING,
	SPECIAL_BUILDING,
	DECORATION,
	TERRAIN,
	POWER_PLANT
}


@export_subgroup("Gameplay")
@export var title: String = "" 

@export_subgroup("Model")
@export var model:PackedScene # Model of the structure

@export_subgroup("Gameplay")
@export var type:StructureType
@export var price:int # Price of the structure when building

@export_subgroup("Population")
@export var population_count:int = 0 # How many residents this structure adds

@export_subgroup("Electricity")
@export var kW_usage:float = 0.0 # How much electricity this structure uses
@export var kW_production:float = 0.0 # How much electricity this structure produces

@export_subgroup("Visual")
@export var selector_scale:float = 1.0 # Scale factor for the selector when this structure is selected

@export_subgroup("Game Progression")
@export var unlocked:bool = false # Whether this structure is available to the player

@export_subgroup("Game Progression")
@export var description: String = "Description" # Whether this structure is available to the player


@export_subgroup("Game Progression")
@export var thumbnail: String = "Thumbnail" # Whether this structure is available to the player
