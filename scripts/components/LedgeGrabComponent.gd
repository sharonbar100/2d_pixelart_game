extends Node
class_name LedgeGrabComponent

@export var tile_size := 16.0
@export var ledge_check_upward_reach := 8.0

@export_group("Art Adjustments")
@export var ledge_snap_offset_y := 0.0
@export var ledge_snap_offset_x := 0.0

@export_group("Physics Properties")
@export var body_collider: Node2D 
@export var extra_wall_reach := 2.0 

@export_group("Debug")
@export var debug_ledge_mode := false 

var ledge_drop_timer := 0.0
@onready var entity: GameEntity = owner as GameEntity

class LedgeDebugDrawer extends Node2D:
	var parent_component: Node
	
	func _process(_delta):
		queue_redraw()
		
	func _draw():
		if parent_component and parent_component.has_method("draw_debug_lines"):
			parent_component.draw_debug_lines(self)

func _ready():
	process_physics_priority = 5
	if not entity or entity.ledge_component != self: 
		set_physics_process(false)
		return
		
	if debug_ledge_mode:
		var drawer = LedgeDebugDrawer.new()
		drawer.parent_component = self
		add_child(drawer)

func _physics_process(delta: float):
	if entity.is_dead: return
	if ledge_drop_timer > 0: ledge_drop_timer -= delta

	if entity.is_hanging:
		entity.velocity = Vector2.ZERO
		
		if entity.input_jump_pressed and not entity.block_input:
			entity.is_hanging = false
			# THE FIX: Removed ledge_drop_timer = 0.2!
			# Because velocity.y becomes < 0 instantly upon jumping, 
			# it naturally prevents re-grabbing until you start falling again.
			
		elif entity.input_down_pressed:
			entity.is_hanging = false
			# Kept the timer here because dropping means your velocity is instantly >= 0,
			# so you would instantly re-grab the ledge without it.
			ledge_drop_timer = 0.2
			
	elif not entity.is_in_knockback and not entity.is_attacking and not entity.is_dashing and not entity.is_on_ladder:
		check_ledge_grab()

# --- DYNAMIC SIZE HELPERS ---

func get_collider_rect() -> Rect2:
	if body_collider is CollisionShape2D and body_collider.shape:
		return body_collider.shape.get_rect()
		
	elif body_collider is CollisionPolygon2D and body_collider.polygon.size() > 0:
		var min_x = body_collider.polygon[0].x
		var max_x = min_x
		var min_y = body_collider.polygon[0].y
		var max_y = min_y
		
		for pt in body_collider.polygon:
			if pt.x < min_x: min_x = pt.x
			if pt.x > max_x: max_x = pt.x
			if pt.y < min_y: min_y = pt.y
			if pt.y > max_y: max_y = pt.y
			
		return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
		
	return Rect2(0, 0, 0, 0) # Fallback

func get_entity_top_pos() -> Vector2:
	if body_collider:
		var rect = get_collider_rect()
		if rect.size != Vector2.ZERO:
			var local_top_y = body_collider.position.y + rect.position.y
			return entity.global_position + Vector2(0, local_top_y)
			
	return entity.global_position + Vector2(0, -8.0) 

func get_wall_check_x() -> float:
	var half_width = 8.0 
	if body_collider:
		var rect = get_collider_rect()
		if rect.size != Vector2.ZERO:
			half_width = rect.size.x / 2.0
		
	var collider_center_x = entity.global_position.x + (body_collider.position.x if body_collider else 0.0)
	return collider_center_x + (entity.last_facing_direction * (half_width + extra_wall_reach))

# ----------------------------

func check_ledge_grab():
	if entity.is_on_floor() or entity.velocity.y < 0 or entity.is_overlapping_ladder or ledge_drop_timer > 0: return
		
	var top_pos = get_entity_top_pos()
	var wall_x = get_wall_check_x()
	
	var check_points = [
		Vector2(wall_x, top_pos.y - ledge_check_upward_reach),
		Vector2(wall_x, top_pos.y - (ledge_check_upward_reach / 2.0)),
		Vector2(wall_x, top_pos.y)
	]
	
	var hit_pos = Vector2.ZERO
	var tile_hit = false
	for pt in check_points:
		if entity.is_solid_tile_at(pt):
			hit_pos = pt
			tile_hit = true
			break
			
	if not tile_hit: return
		
	var tile_center = entity.get_solid_tile_center(hit_pos)
	var ledge_y = tile_center.y - (tile_size / 2.0)
	var vertical_dist = top_pos.y - ledge_y
	
	if vertical_dist > ledge_check_upward_reach or vertical_dist < -4.0: return
	if entity.is_solid_tile_at(Vector2(tile_center.x, ledge_y - (tile_size / 2.0))): return
	if entity.is_solid_tile_at(top_pos + Vector2(0, -tile_size)): return
		
	entity.is_hanging = true
	entity.velocity = Vector2.ZERO
	
	entity.global_position.y = ledge_y + ledge_snap_offset_y
	entity.global_position.x = (tile_center.x - (entity.last_facing_direction * (tile_size / 2.0))) - (entity.last_facing_direction * ledge_snap_offset_x)

# --- DELEGATED DEBUG DRAWING ---
func draw_debug_lines(canvas: Node2D):
	if not entity: return

	var global_top_pos = get_entity_top_pos()
	var global_wall_x = get_wall_check_x()
	
	var local_top_pos = canvas.to_local(global_top_pos)
	var local_wall_x = canvas.to_local(Vector2(global_wall_x, 0)).x
	
	var pt_bottom = Vector2(local_wall_x, local_top_pos.y)
	var pt_mid = Vector2(local_wall_x, local_top_pos.y - (ledge_check_upward_reach / 2.0))
	var pt_top = Vector2(local_wall_x, local_top_pos.y - ledge_check_upward_reach)

	canvas.draw_line(pt_bottom, pt_top, Color.RED, 2.0)
	canvas.draw_circle(pt_bottom, 2.0, Color.YELLOW)
	canvas.draw_circle(pt_mid, 2.0, Color.YELLOW)
	canvas.draw_circle(pt_top, 2.0, Color.YELLOW)
	canvas.draw_circle(local_top_pos, 2.0, Color.GREEN)
