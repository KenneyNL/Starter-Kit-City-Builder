extends Resource
class_name MissionData

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var objectives: Array[MissionObjective] = []
@export var rewards: Dictionary = {"cash": 0}
@export var next_mission_id: String = ""
@export var graph_path: String = "" # Path to graph resource if one exists
@export var full_screen_path: String = "" # Path to a full-screen image containing all mission information
@export var intro_text: String = "" # Introduction text shown in the learning panel
@export var question_text: String = "" # Question displayed to the player
@export var correct_answer: String = "" # The expected correct answer
@export var feedback_text: String = "" # Feedback text shown when answer is correct
@export var incorrect_feedback: String = "" # Feedback text shown when answer is incorrect
@export var company_data: String = "" # Company data for mission 2
@export var power_math_content: String = "" # Power math content for mission 4
