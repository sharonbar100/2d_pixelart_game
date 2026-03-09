extends Node
class_name LadderComponent

@export var climb_speed := 60.0
@export var ladder_horizontal_freedom := 10.0
@export var ladder_catch_forgiveness := 12.0 # Horizontal wiggle room (pixels)

@export_group("Physics Properties")
@export var ladder_hitbox: Node2D 

var ladder_ignore_timer := 0.0
@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = 0 
	if not entity or entity.ladder_component != self:
		set_physics_process(false)
		return
		
	if ladder_hitbox and "disabled" in ladder_hitbox: 
		ladder_hitbox.disabled = true

func _physics_process(delta: float):
	if entity.is_dead or entity.is_in_knockback or entity.is_attacking: return

	if ladder_ignore_timer > 0: ladder_ignore_timer -= delta

	check_ladder_overlap()
	
	if not entity.is_on_ladder and entity.is_overlapping_ladder and ladder_ignore_timer <= 0 and entity.velocity.y >= -10.0:
		var pressing_up = entity.input_vertical < 0
		var pressing_down = entity.input_vertical > 0 and not entity.is_on_floor()
		var auto_catch = not entity.is_on_floor() and entity.velocity.y >= 0 and not entity.is_dashing
		
		if pressing_up or pressing_down or auto_catch:
			entity.is_on_ladder = true
			entity.is_hanging = false
			entity.jumped_from_ladder = false
			entity.velocity = Vector2.ZERO
			snap_to_ladder_x()
			if entity.is_dashing: 
				if entity.dash_component and entity.dash_component.has_method("end_dash"):
					entity.dash_component.end_dash()
				else:
					entity.is_dashing = false 

	if entity.is_on_ladder and not entity.is_dashing:
		var v_dir = entity.input_vertical
		var h_dir = entity.input_direction
		
		# --- CLAMP LOGIC ---
		if v_dir < 0 and not is_ladder_at_offset(Vector2(0, (v_dir * climb_speed * delta) - 1.0)): 
			v_dir = 0
			
		if v_dir > 0 and not entity.is_on_floor() and not is_ladder_at_offset(Vector2(0, (v_dir * climb_speed * delta) + 1.0)):
			v_dir = 0
		# -----------------------
			
		var input_dir = Vector2(h_dir, v_dir)
		if input_dir.length() > 0:
			entity.velocity = input_dir.normalized() * climb_speed
			if h_dir != 0: entity.last_facing_direction = sign(h_dir)
		else:
			entity.velocity = Vector2.ZERO
			
		if entity.velocity.x != 0:
			var bounds = get_ladder_bounds_x(ladder_catch_forgiveness) # FIX: Use forgiveness here so you don't climb off into thin air
			var next_x = entity.global_position.x + (entity.velocity.x * delta)
			if next_x < bounds.x:
				entity.global_position.x = bounds.x
				entity.velocity.x = 0
			elif next_x > bounds.y:
				entity.global_position.x = bounds.y
				entity.velocity.x = 0
				
		if entity.is_on_floor() and v_dir > 0:
			entity.is_on_ladder = false
			
		elif entity.input_jump_pressed and not entity.block_input:
			if entity.input_down_held:
				entity.is_on_ladder = false
				entity.jumped_from_ladder = false
				ladder_ignore_timer = 0.2
				entity.input_jump_pressed = false
			else:
				entity.is_on_ladder = false
				entity.jumped_from_ladder = true
				ladder_ignore_timer = 0.2

# --- UNIVERSAL BOUNDING BOX CALCULATOR ---
func get_collider_rect(collider: Node2D) -> Rect2:
	if collider is CollisionShape2D and collider.shape:
		return collider.shape.get_rect()
		
	elif collider is CollisionPolygon2D and collider.polygon.size() > 0:
		var min_x = collider.polygon[0].x
		var max_x = min_x
		var min_y = collider.polygon[0].y
		var max_y = min_y
		
		for pt in collider.polygon:
			if pt.x < min_x: min_x = pt.x
			if pt.x > max_x: max_x = pt.x
			if pt.y < min_y: min_y = pt.y
			if pt.y > max_y: max_y = pt.y
			
		return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
		
	return Rect2(0, 0, 0, 0)
# -----------------------------------------

func check_ladder_overlap():
	entity.is_overlapping_ladder = is_ladder_at_offset(Vector2.ZERO)
	
	if not entity.is_overlapping_ladder and not entity.is_on_floor():
		entity.is_overlapping_ladder = is_ladder_at_offset(Vector2.ZERO, ladder_catch_forgiveness)

	if entity.is_on_ladder and not entity.is_overlapping_ladder:
		entity.is_on_ladder = false
		if entity.velocity.y < 0: entity.velocity.y = 0

func is_ladder_at_offset(offset: Vector2, width_forgiveness: float = 0.0) -> bool:
	if not ladder_hitbox: return false
	
	var shape_rect = get_collider_rect(ladder_hitbox)
	if shape_rect.size == Vector2.ZERO: return false
	
	var global_rect = Rect2(ladder_hitbox.global_position + shape_rect.position + offset, shape_rect.size)
	
	if width_forgiveness > 0:
		global_rect.position.x -= width_forgiveness
		global_rect.size.x += width_forgiveness * 2
	
	for layer in entity.all_layers:
		if not is_instance_valid(layer): continue
		var top_left = layer.local_to_map(layer.to_local(global_rect.position))
		var bottom_right = layer.local_to_map(layer.to_local(global_rect.end))
		for x in range(top_left.x, bottom_right.x + 1):
			for y in range(top_left.y, bottom_right.y + 1):
				var tile = layer.get_cell_tile_data(Vector2i(x, y))
				if tile and tile.get_custom_data("is_ladder"): return true
	return false

func snap_to_ladder_x():
	var bounds = get_ladder_bounds_x(ladder_catch_forgiveness) # FIX: Actually use the forgiveness width when snapping
	entity.global_position.x = clamp(entity.global_position.x, bounds.x, bounds.y)

# FIX: Added 'width_forgiveness' parameter so it can locate tiles outside the strict hitbox
func get_ladder_bounds_x(width_forgiveness: float = 0.0) -> Vector2:
	if not ladder_hitbox: return Vector2(-INF, INF)
	
	var shape_rect = get_collider_rect(ladder_hitbox)
	if shape_rect.size == Vector2.ZERO: return Vector2(-INF, INF)
	
	var global_rect = Rect2(ladder_hitbox.global_position + shape_rect.position, shape_rect.size)
	
	# FIX: Apply the forgiveness here so we actually find the tile we are snapping to
	if width_forgiveness > 0:
		global_rect.position.x -= width_forgiveness
		global_rect.size.x += width_forgiveness * 2
	
	for layer in entity.all_layers:
		if not is_instance_valid(layer): continue
		var top_left = layer.local_to_map(layer.to_local(global_rect.position))
		var bottom_right = layer.local_to_map(layer.to_local(global_rect.end))
		for x in range(top_left.x, bottom_right.x + 1):
			for y in range(top_left.y, bottom_right.y + 1):
				var cell = Vector2i(x, y)
				var tile = layer.get_cell_tile_data(cell)
				if tile and tile.get_custom_data("is_ladder"):
					var min_x = cell.x
					var max_x = cell.x
					while layer.get_cell_tile_data(Vector2i(min_x - 1, cell.y)) and layer.get_cell_tile_data(Vector2i(min_x - 1, cell.y)).get_custom_data("is_ladder"): min_x -= 1
					while layer.get_cell_tile_data(Vector2i(max_x + 1, cell.y)) and layer.get_cell_tile_data(Vector2i(max_x + 1, cell.y)).get_custom_data("is_ladder"): max_x += 1
					var min_pos = layer.to_global(layer.map_to_local(Vector2i(min_x, cell.y)))
					var max_pos = layer.to_global(layer.map_to_local(Vector2i(max_x, cell.y)))
					return Vector2(min_pos.x - ladder_horizontal_freedom, max_pos.x + ladder_horizontal_freedom)
	return Vector2(-INF, INF)
