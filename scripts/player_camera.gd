extends Camera2D

@export_group("Targeting")
@export var target: Node2D
@export var smooth_speed: float = 8.0 

@export_group("Horizontal Look-Ahead")
@export var look_ahead_distance: float = 25.0 
@export var look_ahead_speed: float = 130.0 

@export_group("Vertical Look-Ahead")
@export var base_vertical_offset: float = -30.0 
@export var jump_look_up: float = -100.0 
@export var vertical_shift_speed: float = 5.0 

@export_group("Peeking")
@export var peek_up_distance: float = -50.0
@export var peek_down_distance: float = 50.0
@export var peek_left_distance: float = -50.0
@export var peek_right_distance: float = 50.0
@export var peek_delay: float = 0.7 # How long to hold before camera pans
@export var peek_pan_speed: float = 130.0

@export_group("Health UI Settings")
@export var hearts_container: HBoxContainer 
@export var heart_texture: Texture2D = preload("res://assets/sprites/ui/healthbar_heart.png")
@export var heart_size := Vector2(10, 10)
@export var empty_heart_modulate := Color(0.2, 0.2, 0.2, 0.6)

var target_position: Vector2
var current_look_ahead_x: float = 0.0 
var current_vertical_offset: float = 0.0 
var shake_amount: float = 0.0
var default_offset: Vector2 = offset

# Peeking variables
var peek_timer: float = 0.0
var current_peek_offset: Vector2 = Vector2.ZERO

func _ready():
	set_as_top_level(true) 
	current_vertical_offset = base_vertical_offset
	
	if is_instance_valid(target):
		global_position = target.global_position
		_connect_to_target_health()

func _connect_to_target_health():
	if not target or not "health_component" in target: 
		if hearts_container: hearts_container.get_parent().visible = false
		return
	
	var hc = target.health_component
	if hc:
		hc.health_changed.connect(_update_health_ui)
		_update_health_ui(hc.current_health, hc.max_health)
		hearts_container.get_parent().visible = true

func _update_health_ui(current: int, max_hp: int):
	if not hearts_container: return
	
	for child in hearts_container.get_children():
		child.queue_free()
	
	for i in range(max_hp):
		var rect = TextureRect.new()
		rect.texture = heart_texture
		rect.custom_minimum_size = heart_size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		if i >= current:
			rect.modulate = empty_heart_modulate
			rect.scale = Vector2(0.8, 0.8)
		
		hearts_container.add_child(rect)

func _physics_process(delta):
	if not is_instance_valid(target): return
		
	target_position = target.global_position
	
	# 1. Vertical Shift
	var target_v_offset = base_vertical_offset
	if "velocity" in target and target.velocity.y < -50.0: 
		target_v_offset = base_vertical_offset + jump_look_up
			
	current_vertical_offset = move_toward(current_vertical_offset, target_v_offset, vertical_shift_speed * delta)
	target_position.y += current_vertical_offset
	
	# 2. Horizontal Look-Ahead
	if "last_facing_direction" in target:
		var target_look_ahead_x = look_ahead_distance * target.last_facing_direction
		current_look_ahead_x = move_toward(current_look_ahead_x, target_look_ahead_x, look_ahead_speed * delta)
		target_position.x += current_look_ahead_x
		
	# 3. Peeking (Using get_real_velocity() to ignore component overrides)
	var target_peek := Vector2.ZERO
	var is_peeking_input = false
	
	var current_vel = target.get_real_velocity() if target.has_method("get_real_velocity") else target.get("velocity")
	
	# If the physical resulting velocity is near zero, the player is effectively stopped
	if current_vel != null and abs(current_vel.x) < 5.0 and abs(current_vel.y) < 5.0:
		
		# Read directly from the entity's input blackboard
		var up_held = target.get("input_up_held") == true
		var down_held = target.get("input_down_held") == true
		var dir = target.get("input_direction")
		
		if up_held:
			is_peeking_input = true
			peek_timer += delta
			if peek_timer >= peek_delay: target_peek.y = peek_up_distance
			
		elif down_held:
			is_peeking_input = true
			peek_timer += delta
			if peek_timer >= peek_delay: target_peek.y = peek_down_distance
			
		elif dir != null and dir < -0.5: # Holding Left
			is_peeking_input = true
			peek_timer += delta
			if peek_timer >= peek_delay: target_peek.x = peek_left_distance
			
		elif dir != null and dir > 0.5: # Holding Right
			is_peeking_input = true
			peek_timer += delta
			if peek_timer >= peek_delay: target_peek.x = peek_right_distance

	if not is_peeking_input:
		peek_timer = 0.0 
		
	# Apply peek offsets
	current_peek_offset.x = move_toward(current_peek_offset.x, target_peek.x, peek_pan_speed * delta)
	current_peek_offset.y = move_toward(current_peek_offset.y, target_peek.y, peek_pan_speed * delta)
	
	target_position += current_peek_offset
	
	# 4. Lerp & Snap
	global_position = global_position.lerp(target_position, smooth_speed * delta)
	global_position = global_position.round()

func _process(delta):
	if shake_amount > 0:
		offset = Vector2(randf_range(-1.0, 1.0) * shake_amount, randf_range(-1.0, 1.0) * shake_amount)
		shake_amount = move_toward(shake_amount, 0.0, 20.0 * delta)
	else:
		offset = default_offset

func apply_shake(amount: float):
	shake_amount = amount
