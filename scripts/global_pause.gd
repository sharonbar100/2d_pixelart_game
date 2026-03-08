extends CanvasLayer

@onready var resume_btn = $VBoxContainer/ResumeButton
@onready var menu_btn = $VBoxContainer/MenuButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	resume_btn.pressed.connect(_on_resume_pressed)
	menu_btn.pressed.connect(_on_main_menu_pressed)

func _input(event):
	# If the game is running and we press the exact "pause_game" button
	if not get_tree().paused and event.is_action_pressed("pause_game"):
		pause_game()
		
	# If the game is ALREADY paused and we press the exact "unpause_game" button
	elif get_tree().paused and event.is_action_pressed("unpause_game"):
		resume_game()

func pause_game():
	get_tree().paused = true
	visible = true
	resume_btn.grab_focus() # Keep the controller support!

func resume_game():
	get_tree().paused = false
	visible = false

func _on_resume_pressed():
	# The button just uses the new resume function directly
	resume_game()

func _on_main_menu_pressed():
	get_tree().paused = false
	hide()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu_pixel.tscn")
	
