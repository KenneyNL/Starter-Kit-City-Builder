extends Control

func _on_button_pressed():
	pass # Replace with function body.


func _on_game_pressed():
	Global.autoload = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_home_pressed():
	Global.autoload = true
	get_tree().change_scene_to_file("res://scenes/home.tscn")
