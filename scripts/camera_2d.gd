extends Camera2D

@export_category("Follow Settings")
@export var follow_speed: float = 4.0      # Overall "laziness" of the camera
@export var look_ahead_dist: float = 48.0   # Horizontal lead
@export var jump_bias_amount: float = 30.0  # How much to shift up/down during airtime
@export var bias_lerp_speed: float = 3.0    # How fast the shift happens

var true_pos: Vector2
var current_v_bias: float = 0.0

func _ready() -> void:
	top_level = true 
	true_pos = global_position

func _physics_process(delta: float) -> void:
	var player = get_parent()
	if not player: return

	# 1. Horizontal Target (Directional Lead)
	var target_pos = player.global_position
	var move_dir = sign(player.velocity.x)
	if move_dir != 0:
		target_pos.x += move_dir * look_ahead_dist

	# 2. Vertical Bias (Jumping/Falling Logic)
	# If moving up (negative Y), bias becomes negative (camera moves up)
	# If moving down (positive Y), bias becomes positive (camera moves down)
	if not player.is_on_floor():
		var air_direction = sign(player.velocity.y)
		current_v_bias = lerp(current_v_bias, air_direction * jump_bias_amount, bias_lerp_speed * delta)
	else:
		# Return to center when on the ground
		current_v_bias = lerp(current_v_bias, 0.0, bias_lerp_speed * delta)
	
	target_pos.y += current_v_bias

	# 3. Subpixel Smoothing
	# Using lerp here ensures the camera doesn't "jitter" between pixels
	true_pos = true_pos.lerp(target_pos, follow_speed * delta)

	# 4. Apply Position
	global_position = true_pos
