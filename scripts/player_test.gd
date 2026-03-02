extends CharacterBody2D

# --- Health & Adjusted Knockback System ---
signal health_changed(new_health)
@export var max_health = 3
var current_health = 3
var is_invincible = false
var invincibility_timer = 0.0
@export var invincibility_duration = 1.0

@export var knockback_power = 500.0          
@export var knockback_upward_force = -200.0  
@export var knockback_stun_time = 0.25       
var knockback_timer = 0.0
var is_in_knockback = false

# --- Basic Movement Settings ---
@export var speed = 130.0                
@export var acceleration = 2500.0  
@export var friction = 5000.0      
@export var air_acceleration = 1500.0 
@export var jump_velocity = -260.0 
@export var gravity_scale = 1.0    

# --- Ladder Settings ---
@export var climb_speed = 60.0 
var is_on_ladder = false
var is_overlapping_ladder = false 
var ladder_ignore_timer = 0.0 
var jumped_from_ladder = false 

# --- Landing Sensitivity ---
@export var shake_threshold = 500.0 
var last_velocity_y = 0.0                     

# --- Dash Settings ---
@export var dash_speed = 288       
@export var dash_duration = 0.25    
@export var ground_dash_lift = -5.0 
@export var ladder_dash_nudge = 0.3 
var is_dashing = false
var can_dash = true 
var last_facing_direction = 1.0 
var dash_timer = 0.0
var dash_nudge_active = false 

# --- Attack Settings ---
@export var attack_lunge_speed = 50.0 
var is_attacking = false
var enemies_hit_this_attack = [] 
@onready var attack_area = $AttackArea 

# --- Precise Movement Tweaks ---
var jump_buffer_duration = 0.1
var jump_buffer_timer = 0.0
var was_in_air = false 
var has_jumped = false 
var block_input = false 

# --- Nodes Reference ---
@onready var animator = $AnimatedSprite2D 
@onready var ladder_hitbox = $LadderHitbox 

# UPDATED: Area2D and CollisionShape References for Hurtbox
@onready var hurtbox = $Hurtbox 
@onready var hurtbox_shape = $Hurtbox/CollisionShape2D 

var all_layers: Array[TileMapLayer] = []

func _notification(what):
	if what == Node.NOTIFICATION_UNPAUSED:
		block_input = true
		await get_tree().process_frame
		block_input = false

func _ready():
	current_health = max_health
	add_to_group("Player")
	GlobalHealthBar.activate(max_health, current_health)
	
	if ladder_hitbox:
		ladder_hitbox.disabled = true
		
	# REMOVED the disabling of the Hurtbox. As an Area2D, it naturally passes through walls.
	
	if animator:
		animator.animation_looped.connect(_on_animation_looped)
		animator.animation_finished.connect(_on_animation_finished)
		animator.frame_changed.connect(_on_frame_changed)
		animator.play("idle")
	
	attack_area.monitoring = false 
	find_all_tile_layers(get_tree().root)

func find_all_tile_layers(node: Node):
	for child in node.get_children():
		if child is TileMapLayer:
			all_layers.append(child)
		find_all_tile_layers(child)

func _exit_tree():
	GlobalHealthBar.deactivate()

func _on_animation_looped():
	if animator and animator.animation == "climb_y":
		animator.frame = 5

func _on_frame_changed():
	if is_attacking and animator.animation == "attack":
		if animator.frame == 3:
			attack_area.monitoring = true
		else:
			attack_area.monitoring = false

func _on_animation_finished():
	if animator.animation == "attack":
		is_attacking = false
		attack_area.monitoring = false
		enemies_hit_this_attack.clear() 

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
	check_spike_overlap()
	
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_dashing and not is_on_ladder:
		perform_attack()
	
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
	
	if is_attacking:
		check_attack_hitbox()

func perform_attack():
	is_attacking = true
	enemies_hit_this_attack.clear()
	velocity.x += last_facing_direction * attack_lunge_speed
	animator.play("attack")

func check_attack_hitbox():
	if not attack_area.monitoring: return
	
	var targets = attack_area.get_overlapping_bodies()
	for body in targets:
		if body.is_in_group("Enemy") and body not in enemies_hit_this_attack:
			if body.has_method("take_damage"):
				body.take_damage(1, global_position)
				enemies_hit_this_attack.append(body)

func take_damage(amount: int, source_position: Vector2):
	if is_invincible: return 
	
	is_invincible = true
	invincibility_timer = invincibility_duration 
	current_health -= amount
	
	health_changed.emit(current_health)
	GlobalHealthBar.update_health(current_health)
	
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
	is_attacking = false 
	enemies_hit_this_attack.clear()
	
	var knock_dir = -1.0 if source_position.x > global_position.x else 1.0
	velocity = Vector2(knock_dir * knockback_power, knockback_upward_force)

func apply_knockback_physics(delta: float):
	velocity += get_gravity() * gravity_scale * delta
	velocity.x = move_toward(velocity.x, 0, friction * 0.6 * delta)

func die():
	Engine.time_scale = 1.0 
	get_tree().reload_current_scene()

func is_ladder_at_offset(offset: Vector2) -> bool:
	if not ladder_hitbox or not ladder_hitbox.shape: 
		return false
		
	var shape_rect = ladder_hitbox.shape.get_rect()
	var global_rect = Rect2(ladder_hitbox.global_position + shape_rect.position + offset, shape_rect.size)
	
	for layer in all_layers:
		if not is_instance_valid(layer): continue
		
		var top_left = layer.local_to_map(layer.to_local(global_rect.position))
		var bottom_right = layer.local_to_map(layer.to_local(global_rect.end))
		
		for x in range(top_left.x, bottom_right.x + 1):
			for y in range(top_left.y, bottom_right.y + 1):
				var tile_data = layer.get_cell_tile_data(Vector2i(x, y))
				if tile_data and tile_data.get_custom_data("is_ladder"):
					return true 
	return false

func check_ladder_overlap():
	is_overlapping_ladder = is_ladder_at_offset(Vector2.ZERO)
	if is_on_ladder and not is_overlapping_ladder:
		is_on_ladder = false
		if velocity.y < 0: velocity.y = 0

func check_spike_overlap():
	if is_invincible or is_in_knockback:
		return
		
	# UPDATED: Now dynamically checks the shape inside your new Hurtbox Area2D
	if not hurtbox_shape or not hurtbox_shape.shape: 
		return
		
	var shape_rect = hurtbox_shape.shape.get_rect()
	var global_rect = Rect2(hurtbox_shape.global_position + shape_rect.position, shape_rect.size)
	
	for layer in all_layers:
		if not is_instance_valid(layer): continue
		
		var top_left = layer.local_to_map(layer.to_local(global_rect.position))
		var bottom_right = layer.local_to_map(layer.to_local(global_rect.end))
		
		for x in range(top_left.x, bottom_right.x + 1):
			for y in range(top_left.y, bottom_right.y + 1):
				var cell_coords = Vector2i(x, y)
				var tile_data = layer.get_cell_tile_data(cell_coords)
				
				if tile_data and tile_data.get_custom_data("is_spike"):
					var local_pos = layer.map_to_local(cell_coords)
					var tile_global_pos = layer.to_global(local_pos)
					
					take_damage(1, tile_global_pos)
					return 

func handle_auto_grab():
	if is_overlapping_ladder and ladder_ignore_timer <= 0 and velocity.y >= -10.0:
		var pressing_up = Input.is_action_pressed("move_up")
		var pressing_down = Input.is_action_pressed("move_down") and not is_on_floor()
		var auto_catch = not is_on_floor() and velocity.y >= 0
		
		if pressing_up or pressing_down or auto_catch:
			is_on_ladder = true
			has_jumped = false 
			jumped_from_ladder = false 
			can_dash = true 
			velocity = Vector2.ZERO

func handle_ladder_movement(delta: float) -> void:
	var v_dir = Input.get_axis("move_up", "move_down")
	var h_dir = Input.get_axis("move_left", "move_right")
	var next_y_movement = v_dir * climb_speed * delta
	
	if v_dir < 0 and not is_ladder_at_offset(Vector2(0, next_y_movement - 1.0)):
		v_dir = 0
		
	var input_dir = Vector2(h_dir, v_dir)
	if input_dir.length() > 0:
		velocity = input_dir.normalized() * climb_speed
		if h_dir != 0: last_facing_direction = sign(h_dir)
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
		ladder_ignore_timer = 0.2

func handle_standard_movement(delta: float) -> void:
	var gravity = get_gravity() * gravity_scale
	if not is_on_floor():
		velocity += gravity * delta
		was_in_air = true
		last_velocity_y = velocity.y 
	else:
		if was_in_air:
			if last_velocity_y > shake_threshold:
				get_tree().call_group("Camera", "apply_shake", 6.0) 
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

	if Input.is_action_just_released("jump") and velocity.y < 0: 
		velocity.y *= 0.5 

	var direction := Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		last_facing_direction = sign(direction) 
		var current_accel = acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, direction * speed, current_accel * delta)
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, friction * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, air_acceleration * delta) 

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
	attack_area.scale.x = last_facing_direction
		
	var target_anim = animator.animation 
	
	if is_in_knockback: 
		target_anim = "fall"
	elif is_attacking:
		target_anim = "attack"
	elif is_dashing: 
		target_anim = "dash"
	elif is_on_ladder:
		if velocity == Vector2.ZERO: target_anim = "hang"
		elif velocity.y != 0: target_anim = "climb_y"
		else: target_anim = "climb_x"
	elif not is_on_floor(): 
		target_anim = "jump" if velocity.y < 0 else "fall"
	else: 
		target_anim = "walk" if velocity.x != 0 else "idle"
	
	if animator.animation != target_anim: 
		animator.play(target_anim)
	
	if is_on_ladder and target_anim != "hang":
		if velocity.length() < 5.0: animator.pause() 
		elif not animator.is_playing(): animator.play()
