extends CharacterBody2D

# --- Health & Adjusted Knockback System ---
signal health_changed(new_health)
@export var max_health = 3
var current_health = 3
var is_invincible = false
var invincibility_timer = 0.0
@export var invincibility_duration = 1.0

@export var knockback_power = 500.0          # Reduced for a fairer hit
@export var knockback_upward_force = -200.0  # Reduced to prevent massive air time
@export var knockback_stun_time = 0.25       # Exposed stun duration
var knockback_timer = 0.0
var is_in_knockback = false

# --- Basic Movement Settings ---
@export var speed = 150.0            
@export var acceleration = 3000.0  
@export var friction = 4000.0        
@export var jump_velocity = -330.0  
@export var gravity_scale = 1.5     

# --- Ladder Settings ---
@export var climb_speed = 130.0 
@export var top_hop_velocity = -200.0 
@export var ladder_grab_width = 5.0  
var is_on_ladder = false
var is_overlapping_ladder = false 
var ladder_ignore_timer = 0.0 
var jumped_from_ladder = false 

# --- Landing Sensitivity ---
@export var shake_threshold = 500.0 
var last_velocity_y = 0.0                 

# --- Dash Settings ---
@export var dash_speed = 273.5      
@export var dash_duration = 0.27    
@export var ground_dash_lift = -5.0 
@export var ladder_dash_nudge = 0.3 
var is_dashing = false
var can_dash = true 
var last_facing_direction = 1.0 
var dash_timer = 0.0
var dash_nudge_active = false 

# --- Precise Movement Tweaks ---
var jump_buffer_duration = 0.1
var jump_buffer_timer = 0.0
var was_in_air = false 
var has_jumped = false 
var block_input = false 

# --- Nodes Reference ---
@onready var camera = $Camera2D
@onready var animator = $AnimatedSprite2D 
var tile_map: Node = null

# --- Listen for the unpause event ---
func _notification(what):
	if what == Node.NOTIFICATION_UNPAUSED:
		block_input = true
		await get_tree().process_frame
		block_input = false

func _ready():
	current_health = max_health
	add_to_group("Player")
	
	tile_map = get_tree().get_first_node_in_group("level_tiles")
	if not tile_map:
		tile_map = get_parent().find_child("*TileMap*", true, false)

func _physics_process(delta: float) -> void:
	if is_invincible:
		if Engine.time_scale > 0.1:
			invincibility_timer -= delta
			animator.visible = int(invincibility_timer * 10) % 2 == 0 
		else:
			animator.visible = true
			
		if invincibility_timer <= 0:
			is_invincible = false
			animator.visible = true
			animator.modulate = Color(1, 1, 1) 
	
	if is_in_knockback:
		knockback_timer -= delta
		if knockback_timer <= 0:
			is_in_knockback = false

	if ladder_ignore_timer > 0:
		ladder_ignore_timer -= delta

	check_ladder_overlap()
	
	if is_dashing:
		handle_dash(delta)
	elif is_in_knockback:
		apply_knockback_physics(delta)
	elif is_on_ladder:
		handle_ladder_movement(delta)
	else:
		handle_standard_movement(delta)
		handle_auto_grab()

	move_and_slide()
	update_animations()

func take_damage(amount: int, source_position: Vector2):
	if is_invincible: return 
	
	is_invincible = true
	invincibility_timer = invincibility_duration 
	current_health -= amount
	health_changed.emit(current_health)
	
	if current_health <= 0:
		die()
		return

	animator.visible = true 
	animator.modulate = Color(10, 10, 10) 
	
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.2, true, false, true).timeout
	Engine.time_scale = 1.0
	
	animator.modulate = Color(1, 1, 1) 

	is_in_knockback = true
	knockback_timer = knockback_stun_time 
	is_on_ladder = false 
	is_dashing = false
	
	var knock_dir = -1.0 if source_position.x > global_position.x else 1.0
	velocity = Vector2(knock_dir * knockback_power, knockback_upward_force)

func apply_knockback_physics(delta: float):
	velocity += get_gravity() * gravity_scale * delta
	velocity.x = move_toward(velocity.x, 0, friction * 0.6 * delta)

func die():
	Engine.time_scale = 1.0 
	get_tree().reload_current_scene()

func check_ladder_overlap():
	if not tile_map: return
	var check_offsets = [
		Vector2(0, -8), Vector2(0, -6), Vector2(0, 0), Vector2(0, 2),
		Vector2(-ladder_grab_width, -6), Vector2(ladder_grab_width, -6)
	]
	is_overlapping_ladder = false
	for offset in check_offsets:
		var map_pos = tile_map.local_to_map(tile_map.to_local(global_position + offset))
		var tile_data = get_tile_data(map_pos)
		if tile_data and tile_data.get_custom_data("is_ladder"):
			is_overlapping_ladder = true
			break 
	if is_on_ladder and not is_overlapping_ladder:
		is_on_ladder = false
		if velocity.y < 0: velocity.y = top_hop_velocity

func handle_auto_grab():
	if is_overlapping_ladder and ladder_ignore_timer <= 0:
		var pressing_v = Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")
		
		# UPDATED: Only automatically catch the ladder if falling downward. 
		# Upward jumps will bypass the auto-catch unless the player explicitly presses up/down.
		var auto_catch = not is_on_floor() and velocity.y >= 0
		
		if pressing_v or auto_catch:
			is_on_ladder = true
			has_jumped = false 
			jumped_from_ladder = false 
			velocity = Vector2.ZERO
			can_dash = true 

func get_tile_data(map_pos: Vector2i) -> TileData:
	if tile_map is TileMap: return tile_map.get_cell_tile_data(0, map_pos)
	elif tile_map: return tile_map.get_cell_tile_data(map_pos)
	return null

func handle_ladder_movement(_delta: float) -> void:
	var v_dir = Input.get_axis("move_up", "move_down")
	var h_dir = Input.get_axis("move_left", "move_right")
	
	var input_dir = Vector2(h_dir, v_dir)
	
	if input_dir.length() > 0:
		velocity = input_dir.normalized() * climb_speed
		if h_dir != 0:
			last_facing_direction = sign(h_dir)
	else:
		velocity = Vector2.ZERO
	
	if Input.is_action_just_pressed("dash") and can_dash and not block_input:
		start_dash()
	elif is_on_floor() and v_dir > 0: 
		is_on_ladder = false
	elif Input.is_action_just_pressed("jump") and not block_input:
		velocity.y = jump_velocity
		has_jumped = true 
		is_on_ladder = false 
		jumped_from_ladder = true 
		ladder_ignore_timer = 0.1 

func handle_standard_movement(delta: float) -> void:
	var gravity = get_gravity() * gravity_scale
	if not is_on_floor():
		velocity += gravity * delta
		was_in_air = true
		last_velocity_y = velocity.y 
	else:
		if was_in_air:
			if last_velocity_y > shake_threshold:
				if camera and camera.has_method("apply_shake"): camera.apply_shake(6.0) 
			was_in_air = false
		can_dash = true 
		has_jumped = false 
		jumped_from_ladder = false 

	if Input.is_action_just_pressed("dash") and can_dash and not block_input:
		start_dash()
		return 

	if Input.is_action_just_pressed("jump") and not block_input: 
		jump_buffer_timer = jump_buffer_duration
	else: 
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and not has_jumped:
		velocity.y = jump_velocity
		has_jumped = true 
		jump_buffer_timer = 0

	if Input.is_action_just_released("jump") and velocity.y < 0: velocity.y *= 0.5 

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		last_facing_direction = sign(direction) 
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_dash(delta: float) -> void:
	dash_timer -= delta
	velocity.y = 0
	
	if Input.is_action_just_pressed("jump") and not has_jumped and not block_input:
		end_dash()
		velocity.y = jump_velocity
		has_jumped = true 
		was_in_air = true
		return
		
	if not Input.is_action_pressed("dash") or dash_timer <= 0: end_dash()

func start_dash():
	if is_on_ladder:
		global_position.y += ladder_dash_nudge
		dash_nudge_active = true
		is_on_ladder = false
		ladder_ignore_timer = 0.1
	
	is_dashing = true
	can_dash = false 
	dash_timer = dash_duration
	
	if is_on_floor():
		var space_above = not test_move(global_transform, Vector2(0, ground_dash_lift))
		if space_above: global_position.y += ground_dash_lift
		
	velocity.y = 0 
	velocity.x = last_facing_direction * dash_speed

func end_dash():
	if dash_nudge_active:
		global_position.y -= ladder_dash_nudge
		dash_nudge_active = false
		
	is_dashing = false
	dash_timer = 0
	velocity.x = last_facing_direction * speed

func update_animations():
	if not animator: return
	animator.flip_h = last_facing_direction < 0
	
	if is_in_knockback:
		animator.play("fall") 
	elif is_dashing:
		animator.play("dash")
	elif is_on_ladder:
		if animator.animation != "climb": animator.play("climb")
		if velocity.length() > 0: animator.play() 
		else: animator.pause() 
	elif not is_on_floor():
		animator.play("jump" if velocity.y < 0 else "fall")
	else:
		animator.play("walk" if velocity.x != 0 else "idle")
