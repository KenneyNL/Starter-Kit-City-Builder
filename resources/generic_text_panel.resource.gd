extends Resource

class_name GenericText

@export_enum("intro", "outro") var panel_type
@export var title: String = "Welcome to Stem City"
@export_multiline var body_text: String = "Some sample body"
@export var button_text: String = "Close"
