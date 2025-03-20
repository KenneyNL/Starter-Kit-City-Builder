extends Resource
class_name Structure

enum StructureType {
	ROAD,
	RESIDENTIAL_BUILDING,
	COMMERCIAL_BUILDING,
	INDUSTRIAL_BUILDING,
	SPECIAL_BUILDING,
	DECORATION,
	TERRAIN
}


@export_subgroup("Model")
@export var model:PackedScene # Model of the structure

@export_subgroup("Gameplay")
@export var type:StructureType
@export var price:int # Price of the structure when building
