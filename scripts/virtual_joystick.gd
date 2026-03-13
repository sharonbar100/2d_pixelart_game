extends Control
class_name VirtualJoystick

@export_group("Input Actions")
@export var action_left := "move_left"
@export var action_right := "move_right"
@export var action_up := "move_up"
@export var action_down := "move_down"

@export_group("Joystick Settings")
@export var max_distance := 30.0  # How many pixels the knob can visually move from the center
@export var deadzone := 0.2       # Percentage (0.0 to 1.0) before a direction registers
@export var is_floating := true   # If true, it snaps to where the player touches!

@onready var base: TextureRect = $Base
@onready var knob: TextureRect = $Base/Knob

var touch_index: int = -1
var base_default_pos: Vector2

func _ready() -> void:
	base_default_pos = base.position
	
	# Hide the joystick if it's set to floating mode
	if is_floating:
		base.hide()

# --- NEW: The Sticky Input Fix! ---
func _exit_tree() -> void:
	# This runs right before the scene changes or the player dies.
	# It guarantees that we let go of all buttons, even if the player's thumb is still on the glass!
	Input.action_release(action_left)
	Input.action_release(action_right)
	Input.action_release(action_up)
	Input.action_release(action_down)

func _input(event: InputEvent) -> void:
	# 1. Handle the initial thumb press
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			
			# Check if the touch happened inside this Control's area (the left half of the screen)
			if get_global_rect().has_point(event.position):
				touch_index = event.index
				
				if is_floating:
					# Snap the base exactly to where the thumb landed!
					base.global_position = event.position - (base.size / 2.0)
					base.show()
					
				_update_joystick(event.position)

		# 2. Handle the thumb lifting off the screen
		elif not event.pressed and event.index == touch_index:
			_reset_joystick()

	# 3. Handle the thumb dragging around
	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	# Find the center of the base circle
	var center = base.global_position + (base.size / 2.0)
	var direction = touch_pos - center
	var distance = direction.length()

	# Clamp the knob visually so it doesn't leave the base circle
	if distance > max_distance:
		direction = direction.normalized() * max_distance

	knob.global_position = center + direction - (knob.size / 2.0)

	# Calculate a normalized input vector (-1.0 to 1.0)
	var input_vector = direction / max_distance

	# Tell Godot's Input Map what is happening!
	_simulate_actions(input_vector)

func _reset_joystick() -> void:
	touch_index = -1
	knob.position = (base.size / 2.0) - (knob.size / 2.0) # Snap knob back to center

	if is_floating:
		base.hide()
		base.position = base_default_pos

	# Let go of all simulated buttons
	Input.action_release(action_left)
	Input.action_release(action_right)
	Input.action_release(action_up)
	Input.action_release(action_down)

func _simulate_actions(vector: Vector2) -> void:
	# Horizontal Actions (Left / Right)
	if vector.x < -deadzone:
		Input.action_press(action_left)
		Input.action_release(action_right)
	elif vector.x > deadzone:
		Input.action_press(action_right)
		Input.action_release(action_left)
	else:
		Input.action_release(action_left)
		Input.action_release(action_right)

	# Vertical Actions (Up / Down)
	if vector.y < -deadzone:
		Input.action_press(action_up)
		Input.action_release(action_down)
	elif vector.y > deadzone:
		Input.action_press(action_down)
		Input.action_release(action_up)
	else:
		Input.action_release(action_up)
		Input.action_release(action_down)
