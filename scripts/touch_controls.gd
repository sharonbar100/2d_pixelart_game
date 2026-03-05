extends CanvasLayer

@export var force_show_on_pc: bool = false 

# --- NEW: References for Diagonal Buttons ---
@export var up_left_button: TouchScreenButton
@export var up_right_button: TouchScreenButton

func _ready() -> void:
	# 1. Check if we are on a mobile device or forcing it for testing
	if OS.has_feature("mobile") or force_show_on_pc:
		show()
		_enable_passby_press_for_all()
		_setup_diagonal_buttons() # Initialize diagonal logic
	else:
		# Hide and remove from memory if playing on a normal PC
		hide()
		queue_free()

# --- NEW: Multi-Action Input Simulation ---
func _setup_diagonal_buttons() -> void:
	# Wire up the Up-Left button
	if up_left_button:
		up_left_button.pressed.connect(func(): _trigger_diagonal("move_up", "move_left", true))
		up_left_button.released.connect(func(): _trigger_diagonal("move_up", "move_left", false))
		
	# Wire up the Up-Right button
	if up_right_button:
		up_right_button.pressed.connect(func(): _trigger_diagonal("move_up", "move_right", true))
		up_right_button.released.connect(func(): _trigger_diagonal("move_up", "move_right", false))

func _trigger_diagonal(action_y: String, action_x: String, is_pressed: bool) -> void:
	# Manually push standard Input map actions so the Player script catches them
	if is_pressed:
		Input.action_press(action_y)
		Input.action_press(action_x)
	else:
		Input.action_release(action_y)
		Input.action_release(action_x)

# 2. Automatically find all touch buttons and enable slide-to-press
func _enable_passby_press_for_all() -> void:
	var all_touch_buttons = _get_all_touch_buttons(self)
	
	for button in all_touch_buttons:
		# passby_press is the magic property that allows you to drag your 
		# finger onto a button to press it, without lifting your finger!
		button.passby_press = true

# 3. Helper function to search the entire CanvasLayer tree for TouchScreenButtons
func _get_all_touch_buttons(node: Node) -> Array[TouchScreenButton]:
	var found_buttons: Array[TouchScreenButton] = []
	
	for child in node.get_children():
		if child is TouchScreenButton:
			found_buttons.append(child)
		
		# If this child has its own children (like if you put buttons inside a Control node),
		# search those too using recursion.
		if child.get_child_count() > 0:
			found_buttons.append_array(_get_all_touch_buttons(child))
			
	return found_buttons
