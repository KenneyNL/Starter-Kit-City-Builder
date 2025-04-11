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
@export var num_of_user_inputs: int = 1 # Number of user input fields to display
@export var input_labels: Array[String] = [] # Labels for each input field
@export var companion_dialog: Dictionary = {} # Map of event keys to dialog entries for the learning companion
@export var unlocked_items: Array[String] = [] # Array of structure resource paths that get unlocked after mission completion
