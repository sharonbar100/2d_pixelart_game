extends Node
class_name HealthComponent

signal health_changed(current_hp, max_hp)

@export var max_health := 3
@export var invincibility_duration := 1.0

@export_group("Hit Effects")
@export var use_hit_pause := false 
@export var use_flash := true 
@export var flash_duration := 0.1 
# NEW: High-intensity white is (10, 10, 10), but you can pick anything!
@export var flash_color := Color(10.0, 10.0, 10.0, 1.0) 

var current_health := 3
var invincibility_timer := 0.0
var flash_timer := 0.0

@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = -20 
	
	if not entity or entity.health_component != self:
		set_physics_process(false)
		return
		
	current_health = max_health
	
	if entity.hurtbox_area:
		entity.hurtbox_area.monitoring = true
		entity.hurtbox_area.monitorable = false
		if not entity.hurtbox_area.area_entered.is_connected(_on_hurtbox_area_entered):
			entity.hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)

func _on_hurtbox_area_entered(area: Area2D):
	if entity.is_dead or entity.is_invincible: return
	
	if area.is_in_group("Hitbox"):
		var incoming_damage = area.get_meta("damage") if area.has_meta("damage") else 1
		
		if area.has_meta("source_entity"):
			var source = area.get_meta("source_entity")
			if source == entity: return 
		
		take_damage(incoming_damage, area.global_position)

func _physics_process(delta: float):
	if entity.is_dead: return

	# 1. Handle Visual Flash (Color Change)
	if flash_timer > 0:
		flash_timer -= delta
		if entity.animator and use_flash:
			entity.animator.modulate = flash_color # Uses your custom color!
		
		if flash_timer <= 0:
			if entity.animator: entity.animator.modulate = Color(1, 1, 1) # Back to normal

	# 2. Handle Invincibility State & Flicker (Visibility)
	if entity.is_invincible:
		invincibility_timer -= delta
		
		if entity.animator and use_flash: 
			entity.animator.visible = int(invincibility_timer * 15) % 2 == 0
			
		if invincibility_timer <= 0:
			entity.is_invincible = false
			if entity.animator:
				entity.animator.visible = true
				# Safety check: Ensure modulate is reset if the flash ended exactly with i-frames
				entity.animator.modulate = Color(1, 1, 1) 

	check_spike_overlap()

func check_spike_overlap():
	if entity.is_invincible or entity.is_in_knockback or entity.is_dead or not entity.hurtbox_shape: return
	
	var shape_rect = entity.hurtbox_shape.shape.get_rect()
	var global_rect = Rect2(entity.hurtbox_shape.global_position + shape_rect.position, shape_rect.size)
	
	for layer in entity.all_layers:
		if not is_instance_valid(layer): continue
		
		var top_left = layer.local_to_map(layer.to_local(global_rect.position))
		var bottom_right = layer.local_to_map(layer.to_local(global_rect.end))
		
		for x in range(top_left.x, bottom_right.x + 1):
			for y in range(top_left.y, bottom_right.y + 1):
				var cell = Vector2i(x, y)
				var tile = layer.get_cell_tile_data(cell)
				if tile and tile.get_custom_data("is_spike"):
					take_damage(1, layer.to_global(layer.map_to_local(cell)))
					return

func take_damage(amount: int, source_position: Vector2):
	if entity.is_dead: return # Removed i-frame check here so damage logic still runs
	if entity.is_invincible: return # But we still skip damage if currently invincible
	
	if invincibility_duration > 0:
		entity.is_invincible = true
		invincibility_timer = invincibility_duration
	
	flash_timer = flash_duration
	current_health -= amount
	
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()
		return

	if use_hit_pause:
		Engine.time_scale = 0.05
		get_tree().create_timer(0.2, true, false, true).timeout.connect(_reset_time_scale)

	entity.is_in_knockback = true
	entity.is_on_ladder = false
	entity.is_hanging = false
	entity.is_dashing = false
	entity.is_attacking = false
	
	if entity.knockback_component: 
		entity.knockback_component.apply_knockback(source_position)

func _reset_time_scale():
	Engine.time_scale = 1.0

func die():
	entity.is_dead = true
	Engine.time_scale = 1.0
	
	if entity.is_in_group("Player"): 
		get_tree().call_deferred("reload_current_scene")
	else: 
		entity.queue_free()
