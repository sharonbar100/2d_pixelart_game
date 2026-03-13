extends CanvasLayer

@export var force_show_on_pc: bool = false 

func _ready() -> void:
	# 1. Check if we are on a mobile device or forcing it for testing
	if OS.has_feature("mobile") or force_show_on_pc:
		# Automatically make all buttons support thumb-sliding!
		_enable_passby_press_for_all()
		
		# 2. Listen for controller connections/disconnections
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
		
		# 3. Check the current controller state right at startup
		_update_visibility_based_on_controller()
	else:
		# Hide and remove from memory if playing on a normal PC
		hide()
		queue_free()

# --- Controller Detection Logic ---
func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_visibility_based_on_controller()

func _update_visibility_based_on_controller() -> void:
	var connected_joypads = Input.get_connected_joypads()
	
	# If the array has items, at least one controller is connected
	if connected_joypads.size() > 0:
		hide()
	else:
		show()

# --- Touch Control Setup Helpers ---
func _enable_passby_press_for_all() -> void:
	var all_touch_buttons = _get_all_touch_buttons(self)
	
	for button in all_touch_buttons:
		# This is the magic that allows smooth thumb sliding between buttons!
		button.passby_press = true
		
		# A helpful warning just in case you forgot to type the action name in the Inspector
		if button.action == "":
			print("WARNING: Touch button '", button.name, "' has no Action assigned in the inspector!")

func _get_all_touch_buttons(node: Node) -> Array[TouchScreenButton]:
	var found_buttons: Array[TouchScreenButton] = []
	
	for child in node.get_children():
		if child is TouchScreenButton:
			found_buttons.append(child)
		
		# Recursively check children of children (e.g. if you put buttons inside a Control node)
		if child.get_child_count() > 0:
			found_buttons.append_array(_get_all_touch_buttons(child))
			
	return found_buttons
