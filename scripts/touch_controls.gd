extends CanvasLayer

@export var force_show_on_pc: bool = false 

# --- References for Diagonal Buttons ---
@export var up_left_button: TouchScreenButton
@export var up_right_button: TouchScreenButton

func _ready() -> void:
	# 1. Check if we are on a mobile device or forcing it for testing
	if OS.has_feature("mobile") or force_show_on_pc:
		_enable_passby_press_for_all()
		_setup_diagonal_buttons()
		
		# 2. Listen for controller connections/disconnections
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
		
		# 3. Check the current controller state right at startup
		_update_visibility_based_on_controller()
	else:
		# Hide and remove from memory if playing on a normal PC
		hide()
		queue_free()

# --- NEW: Controller Detection Logic ---
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_update_visibility_based_on_controller()

func _update_visibility_based_on_controller() -> void:
	var connected_joypads = Input.get_connected_joypads()
	
	# If the array has items, at least one controller is connected
	if connected_joypads.size() > 0:
		hide()
	else:
		show()

# --- Multi-Action Input Simulation ---
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

# --- Touch Control Setup Helpers ---
func _enable_passby_press_for_all() -> void:
	var all_touch_buttons = _get_all_touch_buttons(self)
	
	for button in all_touch_buttons:
		button.passby_press = true

func _get_all_touch_buttons(node: Node) -> Array[TouchScreenButton]:
	var found_buttons: Array[TouchScreenButton] = []
	
	for child in node.get_children():
		if child is TouchScreenButton:
			found_buttons.append(child)
		
		if child.get_child_count() > 0:
			found_buttons.append_array(_get_all_touch_buttons(child))
			
	return found_buttons
