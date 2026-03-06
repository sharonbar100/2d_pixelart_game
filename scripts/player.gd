class_name Player extends CharacterBody2D

# ==========================================
# --- DRAG & DROP LEGO COMPONENTS ---
# ==========================================
@export_category("Components")
@export var health_comp: HealthComponent
@export var input_comp: InputComponent
@export var move_comp: MovementComponent
@export var attack_comp: AttackComponent
@export var dash_comp: DashComponent
@export var anim_comp: AnimationComponent

# ==========================================
# --- ENVIRONMENT NODES ---
# ==========================================
@export var hurtbox_shape: CollisionShape2D
@export var ladder_hitbox: CollisionShape2D

var state: String = "normal" 
var facing_dir: float = 1.0

# --- Environment Settings ---
@export var climb_speed = 60.0 
@export var ladder_horizontal_freedom = 10.0 
@export var tile_size = 16.0 
@export var ledge_check_distance = 8.0 
@export var ledge_check_upward_reach = 8.0 
@export var ledge_snap_offset_y = 13.0 
@export var ledge_snap_offset_x = 5.0 
@export var player_top_tile_offset = Vector2(0, -8.0)

var all_layers: Array[TileMapLayer] = []
var ladder_ignore_timer = 0.0 
var ledge_drop_timer = 0.0

func _ready():
	add_to_group("Player")
	
	if health_comp:
		health_comp.took_damage.connect(_on_damage)
		health_comp.died.connect(_on_died)
		# GlobalHealthBar call commented out safely in case it doesn't exist
		# GlobalHealthBar.activate(health_comp.max_health, health_comp.max_health)
	
	if ladder_hitbox: ladder_hitbox.disabled = true
	var interactable_nodes = get_tree().get_nodes_in_group("InteractableLayers")
	for node in interactable_nodes:
		if node is TileMapLayer: all_layers.append(node)

# ==========================================
# --- STATE MACHINE (THE BRAIN) ---
# ==========================================
func _physics_process(delta: float):
	if state == "dead": return

	# 1. SAFE INPUT GATHERING (Defaults to false/0 if InputComponent is missing)
	var move_x = 0.0
	var move_y = 0.0
	var jump_just_pressed = false
	var jump_released = false
	var dash_just_pressed = false
	var attack_just_pressed = false
	var move_up_pressed = false
	var move_down_pressed = false

	if input_comp:
		input_comp.update_inputs()
		move_x = input_comp.move_dir.x
		move_y = input_comp.move_dir.y
		jump_just_pressed = input_comp.jump_just_pressed
		jump_released = input_comp.jump_released
		dash_just_pressed = input_comp.dash_just_pressed
		attack_just_pressed = input_comp.attack_just_pressed
		move_up_pressed = input_comp.move_up_pressed
		move_down_pressed = input_comp.move_down_pressed

	if move_x != 0: facing_dir = sign(move_x)
	if ladder_ignore_timer > 0: ladder_ignore_timer -= delta
	if ledge_drop_timer > 0: ledge_drop_timer -= delta

	check_spikes()

	# 2. STATE TRANSITIONS
	if state in ["normal", "air"]:
		if attack_just_pressed and attack_comp:
			state = "attacking"
			attack_comp.start_attack(facing_dir)
		elif dash_just_pressed and dash_comp and dash_comp.can_dash:
			state = "dashing"
			dash_comp.start_dash(facing_dir)
		elif check_ledge_grab():
			state = "hanging"
		elif check_auto_grab(move_up_pressed, move_down_pressed):
			state = "climbing"
			if dash_comp: dash_comp.can_dash = true

	# 3. EXECUTE STATE
	match state:
		"normal", "air":
			if move_comp:
				move_comp.apply_gravity(delta)
				move_comp.handle_horizontal_movement(delta, move_x)
				if jump_just_pressed: move_comp.apply_jump()
				if jump_released: move_comp.apply_jump_cut()
			
			state = "air" if not is_on_floor() else "normal"
			if is_on_floor() and dash_comp: dash_comp.can_dash = true
			
		"dashing":
			if dash_comp:
				if not dash_comp.process_dash(delta, jump_just_pressed): 
					state = "air"
					if jump_just_pressed and move_comp: move_comp.apply_jump()
				dash_comp.apply_dash_corner_correction(delta)
			else: state = "air" # Fallback if missing
			
		"attacking":
			if attack_comp:
				attack_comp.check_hitbox()
				if not attack_comp.is_attacking: state = "normal"
			else: state = "normal"
				
		"climbing":
			handle_ladder_movement(delta, move_x, move_y, dash_just_pressed, jump_just_pressed)
			if jump_just_pressed or (is_on_floor() and move_y > 0):
				state = "air"
				
		"hanging":
			velocity = Vector2.ZERO
			if jump_just_pressed:
				if move_comp: move_comp.apply_jump()
				ledge_drop_timer = 0.2
				state = "air"
			elif move_down_pressed:
				ledge_drop_timer = 0.2
				state = "air"
				
		"knockback":
			if move_comp:
				move_comp.apply_gravity(delta)
				velocity.x = move_toward(velocity.x, 0, move_comp.friction * 0.6 * delta)

	move_and_slide()
	
	# Safe Animation Update
	if anim_comp:
		var is_invincible = health_comp.is_invincible if health_comp else false
		var inv_timer = health_comp.invincibility_timer if health_comp else 0.0
		anim_comp.update_animations(state, velocity, facing_dir, is_invincible, inv_timer)

# ==========================================
# --- SIGNALS ---
# ==========================================
func _on_damage(amount, source_pos):
	state = "knockback"
	if dash_comp: dash_comp.is_dashing = false
	if attack_comp: attack_comp.is_attacking = false
	
	var knock_dir = -1.0 if source_pos.x > global_position.x else 1.0
	velocity = Vector2(knock_dir * 500.0, -200.0)
	
	if anim_comp: anim_comp.trigger_damage_flash()
	await get_tree().create_timer(0.25).timeout
	if state == "knockback": state = "air"

func _on_died():
	state = "dead"
	set_physics_process(false)
	get_tree().call_deferred("reload_current_scene")

# ==========================================
# --- ENVIRONMENT LOGIC ---
# ==========================================
func handle_ladder_movement(delta: float, move_x: float, move_y: float, dash_pressed: bool, jump_pressed: bool):
	if move_y < 0 and not is_ladder_at_offset(Vector2(0, move_y * climb_speed * delta - 1.0)): move_y = 0
		
	if Vector2(move_x, move_y).length() > 0:
		velocity = Vector2(move_x, move_y).normalized() * climb_speed
	else: velocity = Vector2.ZERO
		
	if dash_pressed and dash_comp and dash_comp.can_dash:
		state = "dashing"
		dash_comp.start_dash(facing_dir)
		ladder_ignore_timer = 0.1
	elif jump_pressed:
		if move_comp: move_comp.apply_jump()
		ladder_ignore_timer = 0.2

func check_auto_grab(move_up_pressed: bool, move_down_pressed: bool) -> bool:
	if state != "climbing" and is_ladder_at_offset(Vector2.ZERO) and ladder_ignore_timer <= 0 and velocity.y >= -10.0:
		if move_up_pressed or (move_down_pressed and not is_on_floor()) or (not is_on_floor() and velocity.y >= 0):
			velocity = Vector2.ZERO
			var bounds = get_ladder_bounds_x()
			global_position.x = clamp(global_position.x, bounds.x, bounds.y)
			return true
	return false

func check_ledge_grab() -> bool:
	if is_on_floor() or velocity.y < 0 or is_ladder_at_offset(Vector2.ZERO) or ledge_drop_timer > 0: return false
	var pt_top = global_position + player_top_tile_offset
	var wall_x = pt_top.x + (facing_dir * ledge_check_distance)
	for pt in [Vector2(wall_x, pt_top.y - ledge_check_upward_reach), Vector2(wall_x, pt_top.y)]:
		if is_solid_tile_at(pt):
			var tile_center = get_solid_tile_center(pt)
			var ledge_y = tile_center.y - (tile_size / 2.0)
			if pt_top.y - ledge_y <= ledge_check_upward_reach and pt_top.y - ledge_y >= -4.0:
				velocity = Vector2.ZERO
				global_position.y = ledge_y + ledge_snap_offset_y
				global_position.x = (tile_center.x - (facing_dir * (tile_size / 2.0))) - (facing_dir * ledge_snap_offset_x)
				return true
	return false

func check_spikes():
	var is_inv = health_comp.is_invincible if health_comp else false
	if is_inv or state == "knockback" or not hurtbox_shape: return
	
	var rect = Rect2(hurtbox_shape.global_position + hurtbox_shape.shape.get_rect().position, hurtbox_shape.shape.get_rect().size)
	for layer in all_layers:
		var tl = layer.local_to_map(layer.to_local(rect.position))
		var br = layer.local_to_map(layer.to_local(rect.end))
		for x in range(tl.x, br.x + 1):
			for y in range(tl.y, br.y + 1):
				var cell = Vector2i(x, y)
				var data = layer.get_cell_tile_data(cell)
				if data and data.get_custom_data("is_spike"):
					if health_comp: health_comp.take_damage(1, layer.to_global(layer.map_to_local(cell)))
					return

func is_solid_tile_at(pos: Vector2) -> bool:
	for layer in all_layers:
		if layer.get_cell_tile_data(layer.local_to_map(layer.to_local(pos))): return true
	return false

func get_solid_tile_center(pos: Vector2) -> Vector2:
	for layer in all_layers:
		var map_pos = layer.local_to_map(layer.to_local(pos))
		if layer.get_cell_tile_data(map_pos): return layer.to_global(layer.map_to_local(map_pos))
	return pos

func is_ladder_at_offset(offset: Vector2) -> bool:
	if not ladder_hitbox: return false
	var rect = Rect2(ladder_hitbox.global_position + ladder_hitbox.shape.get_rect().position + offset, ladder_hitbox.shape.get_rect().size)
	for layer in all_layers:
		var tl = layer.local_to_map(layer.to_local(rect.position))
		var br = layer.local_to_map(layer.to_local(rect.end))
		for x in range(tl.x, br.x + 1):
			for y in range(tl.y, br.y + 1):
				var data = layer.get_cell_tile_data(Vector2i(x, y))
				if data and data.get_custom_data("is_ladder"): return true
	return false

func get_ladder_bounds_x() -> Vector2:
	if not ladder_hitbox: return Vector2(-INF, INF)
	var rect = Rect2(ladder_hitbox.global_position + ladder_hitbox.shape.get_rect().position, ladder_hitbox.shape.get_rect().size)
	for layer in all_layers:
		var tl = layer.local_to_map(layer.to_local(rect.position))
		var br = layer.local_to_map(layer.to_local(rect.end))
		for x in range(tl.x, br.x + 1):
			for y in range(tl.y, br.y + 1):
				var data = layer.get_cell_tile_data(Vector2i(x, y))
				if data and data.get_custom_data("is_ladder"):
					var pos = layer.to_global(layer.map_to_local(Vector2i(x, y)))
					return Vector2(pos.x - ladder_horizontal_freedom, pos.x + ladder_horizontal_freedom)
	return Vector2(-INF, INF)
