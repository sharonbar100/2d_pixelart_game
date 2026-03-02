extends Camera2D

@export var target: Node2D # Assign your Player to this in the Inspector!
@export var smooth_speed: float = 8.0 

# --- Horizontal Look-Ahead ---
@export var look_ahead_distance: float = 25.0 
@export var look_ahead_speed: float = 130.0 

# --- Vertical Look-Ahead ---
@export var base_vertical_offset: float = -30.0 # Your standard camera height
@export var jump_look_up: float = -100.0 # How much EXTRA the camera moves up when jumping
@export var vertical_shift_speed: float = 0.0 # How fast the camera returns when falling

var target_position: Vector2
var current_look_ahead_x: float = 0.0 
var current_vertical_offset: float = 0.0 
var shake_amount: float = 0.0
var default_offset: Vector2 = offset

func _ready():
	# This ensures the camera isn't affected by any weird parent scaling/moving
	set_as_top_level(true) 
	current_vertical_offset = base_vertical_offset
	
	if is_instance_valid(target):
		global_position = target.global_position

func _physics_process(delta):
	if not is_instance_valid(target):
		return
		
	# 1. Establish the base target position
	target_position = target.global_position
	
	# 2. Dynamic Vertical Shift (The Jump Look-Ahead)
	var target_v_offset = base_vertical_offset
	
	# We check if the player is moving upward (negative Y velocity in Godot)
	if "velocity" in target:
		# We use a small threshold (-50) so walking up tiny slopes doesn't trigger the jump camera
		if target.velocity.y < -50.0: 
			target_v_offset = base_vertical_offset + jump_look_up
			
	# move_toward smoothly transitions the offset. When the player starts falling, 
	# target_v_offset drops back to normal, and the camera gently returns before they land.
	current_vertical_offset = move_toward(current_vertical_offset, target_v_offset, vertical_shift_speed * delta)
	target_position.y += current_vertical_offset
	
	# 3. Linear Horizontal Look-Ahead
	if "last_facing_direction" in target:
		var target_look_ahead_x = look_ahead_distance * target.last_facing_direction
		current_look_ahead_x = move_toward(current_look_ahead_x, target_look_ahead_x, look_ahead_speed * delta)
		target_position.x += current_look_ahead_x
	
	# 4. Smoothly Lerp to the final combined target position
	var weight = clamp(smooth_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(target_position, weight)
	
	# 5. Pixel-Perfect Snapping
	# This prevents the camera from landing on a decimal which causes pixel art to distort.
	global_position = global_position.round()

func _process(delta):
	# Screen Shake Logic
	if shake_amount > 0:
		offset = Vector2(randf_range(-1.0, 1.0) * shake_amount, randf_range(-1.0, 1.0) * shake_amount)
		# Fade out the shake over time
		shake_amount = move_toward(shake_amount, 0.0, 20.0 * delta)
	else:
		offset = default_offset

# This function is called by the Player's group signal when they land hard
func apply_shake(amount: float):
	shake_amount = amount
