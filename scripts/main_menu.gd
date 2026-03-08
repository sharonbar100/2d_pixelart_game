extends Control

@export_file("*.tscn") var level_1_scene: String = "res://scenes/levels/level_1.tscn"
@export_file("*.tscn") var hard_level_1_scene: String = "res://scenes/levels/hard_level_1.tscn"
@export_file("*.tscn") var hard_level_2_scene: String = "res://scenes/levels/hard_level_2.tscn"
@export_file("*.tscn") var test_level_scene: String = "res://scenes/levels/test_level.tscn"

# Reference to the first button to focus it on start
@onready var first_button: Button = $"VBoxContainer/Level_1"

func _ready() -> void:
	# This is essential for controller/keyboard support
	first_button.grab_focus()

func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file(level_1_scene)
	
func _on_hard_level_1_pressed() -> void:
	get_tree().change_scene_to_file(hard_level_1_scene)
	
func _on_test_level_pressed() -> void:
	get_tree().change_scene_to_file(test_level_scene)

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_hard_level_2_pressed() -> void:
	get_tree().change_scene_to_file(hard_level_2_scene)
