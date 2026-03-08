extends Control

@export_category("Scene Loading")
@export_file("*.tscn") var level_1_scene: String = "res://scenes/levels/level_1.tscn"
@export_file("*.tscn") var hard_level_1_scene: String = "res://scenes/levels/hard_level_1.tscn"
@export_file("*.tscn") var hard_level_2_scene: String = "res://scenes/levels/hard_level_2.tscn"
@export_file("*.tscn") var test_level_scene: String = "res://scenes/levels/test_level.tscn"

@export_category("Background Panning")
@export var scroll_speed: Vector2 = Vector2(20.0, -5.0) 

# Changed to an export so you can assign it safely in the Inspector!
@export_category("UI Settings")
@export var first_button: Button 

@onready var parallax_bg: ParallaxBackground = $ParallaxBackground

func _ready() -> void:
	if is_instance_valid(first_button):
		# call_deferred tells Godot to wait until the end of the frame 
		# (when the UI is fully built) before grabbing focus.
		first_button.call_deferred("grab_focus")

func _process(delta: float) -> void:
	if is_instance_valid(parallax_bg):
		parallax_bg.scroll_offset += scroll_speed * delta

# --- Button Signals ---
func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file(level_1_scene)
	
func _on_hard_level_1_pressed() -> void:
	get_tree().change_scene_to_file(hard_level_1_scene)
	
func _on_hard_level_2_pressed() -> void:
	get_tree().change_scene_to_file(hard_level_2_scene)
	
func _on_test_level_pressed() -> void:
	get_tree().change_scene_to_file(test_level_scene)

func _on_quit_pressed() -> void:
	get_tree().quit()
