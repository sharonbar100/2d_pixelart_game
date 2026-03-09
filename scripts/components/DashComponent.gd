extends Node
class_name DashComponent

@export var dash_distance_tiles := 4.0
@export var dash_duration := 0.25
@export var ladder_dash_nudge := 0.3
@export var dash_corner_correction := 8
@export var tile_size := 16.0

var dash_start_x := 0.0
var target_dash_distance := 0.0
var dash_timer := 0.0
var dash_nudge_active := false
var can_dash := true

@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = 10 
	if not entity or entity.dash_component != self: 
		set_physics_process(false)

func _physics_process(delta: float):
	if entity.is_dead or entity.is_in_knockback: return

	if entity.is_on_floor() or entity.is_hanging or entity.is_on_ladder:
		can_dash = true

	if entity.input_dash_pressed and can_dash and not entity.block_input and not entity.is_dashing and not entity.is_hanging:
		start_dash()

	if entity.is_dashing:
		handle_dash(delta)
		if entity.is_dashing: apply_dash_corner_correction(delta)

func start_dash():
	if entity.is_on_ladder:
		entity.global_position.y += ladder_dash_nudge
		dash_nudge_active = true
		entity.is_on_ladder = false
		if entity.ladder_component: entity.ladder_component.ladder_ignore_timer = 0.1
		
	entity.is_dashing = true
	can_dash = false 
	dash_start_x = entity.global_position.x
	target_dash_distance = dash_distance_tiles * tile_size
	dash_timer = dash_duration
	
	var calculated_dash_speed = target_dash_distance / dash_duration
	entity.velocity.x = entity.last_facing_direction * calculated_dash_speed
	entity.velocity.y = 0 

func handle_dash(delta: float) -> void:
	if entity.input_jump_pressed and not entity.block_input:
		end_dash()
		if entity.jump_component: entity.jump_component.perform_jump()
		entity.was_in_air = true
		return

	dash_timer -= delta
	entity.velocity.y = 0
	
	var distance_traveled = abs(entity.global_position.x - dash_start_x)
	if distance_traveled >= target_dash_distance:
		if not entity.is_on_wall():
			entity.global_position.x = dash_start_x + (entity.last_facing_direction * target_dash_distance)
		end_dash()
		return

	if dash_timer <= 0.0 or not entity.input_dash_held:
		end_dash()
		return

	var calculated_dash_speed = target_dash_distance / dash_duration
	entity.velocity.x = entity.last_facing_direction * calculated_dash_speed

func apply_dash_corner_correction(delta: float):
	var motion = entity.velocity * delta
	if entity.test_move(entity.global_transform, motion):
		for i in range(1, dash_corner_correction + 1):
			if not entity.test_move(entity.global_transform.translated(Vector2(0, i)), motion):
				entity.global_position.y += i
				return
		for i in range(1, dash_corner_correction + 1):
			if not entity.test_move(entity.global_transform.translated(Vector2(0, -i)), motion):
				entity.global_position.y -= i
				return

func end_dash():
	if dash_nudge_active:
		entity.global_position.y -= ladder_dash_nudge
		dash_nudge_active = false
		
	entity.is_dashing = false
	
	# FIX: Look ahead and check if we are finishing the dash right on top of a ladder!
	var catching_ladder = false
	if entity.ladder_component and not entity.is_on_floor():
		entity.ladder_component.check_ladder_overlap()
		if entity.is_overlapping_ladder:
			catching_ladder = true
	
	# If we are over a ladder, halt horizontal velocity entirely so we don't accidentally
	# walk out of the forgiveness zone before the ladder component grabs us next frame.
	if catching_ladder:
		entity.velocity.x = 0
		entity.velocity.y = 0 
	else:
		var current_input_dir = entity.input_direction
		var base_speed = entity.movement_component.speed if entity.movement_component else 0.0
		entity.velocity.x = current_input_dir * base_speed
