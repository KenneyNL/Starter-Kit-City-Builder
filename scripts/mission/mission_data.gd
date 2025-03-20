extends Resource
class_name MissionData

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var objectives: Array[MissionObjective] = []
@export var rewards: Dictionary = {"cash": 0}
@export var next_mission_id: String = ""
