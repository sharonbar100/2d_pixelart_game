extends Node
class_name BossAIComponent

enum State { IDLE, PICK_ATTACK, SLAM_TRACK, SLAM_DOWN, SWEEP }

@export_group("State Toggles")
@export var enable_idle := true
@export var enable_slam := true
@export var enable_sweep := true

@export_group("Hover Visuals")
@export var hover_amplitude := 10.0
@export var hover_speed := 2.5
@export var turn_speed := 10.0

@export_group("Wobble Settings")
@export var wobble_max_strength := 5.0
@export var wobble_speed := 60.0
@export_range(0.0, 1.0) var wobble_start_threshold := 0.5

@export_group("Anti-Jitter Settings")
@export var facing_deadzone := 12.0 
@export var lock_facing_during_slam := true 

@export_group("Idle Settings")
@export var idle_move_speed := 50.0
@export var idle_duration := 3.0
@export var detection_range := 40.0 

@export_group("Down Slam Settings")
@export var slam_height := 60.0      
@export var tracking_duration := 1.5 
@export var max_tracking_speed := 300.0 # Fast but capped
@export var tracking_acceleration := 1200.0 # How fast he hits max speed
@export var slam_fall_speed := 800.0 

@export_group("Floor Sweep Settings")
@export var sweep_height := 20.0     
@export var sweep_speed := 250.0      
@export var sweep_prep_time := 0.8    
@export var sweep_distance := 300.0   

# Internal State
@onready var entity: GameEntity = owner as GameEntity
var player: GameEntity
var current_state: State = State.IDLE
var state_timer := 0.0
var hover_time := 0.0
var current_dir := Vector2(1, -0.5) 
var initial_sprite_y := 0.0
var current_facing := 1.0 
var sweep_dir := 1.0

func _ready():
	if entity.gravity_component: entity.gravity_component.set_physics_process(false)
	if entity.movement_component: entity.movement_component.set_physics_process(false)
	if entity.jump_component: entity.jump_component.set_physics_process(false)
	
	player = get_tree().get_first_node_in_group("Player") as GameEntity
	if entity.animator: 
		initial_sprite_y = entity.animator.position.y
		current_facing = sign(entity.animator.scale.x)
	
	current_state = get_next_valid_state(State.IDLE)
	change_state(current_state)

func _physics_process(delta: float):
	if entity.is_dead: return
	
	hover_time += delta
	apply_visual_offsets(delta)
	handle_facing(delta)
	
	match current_state:
		State.IDLE: process_idle(delta)
		State.PICK_ATTACK: process_pick_attack()
		State.SLAM_TRACK: process_slam_track(delta)
		State.SLAM_DOWN: process_slam_down(delta)
		State.SWEEP: process_sweep(delta)

func change_state(new_state: State):
	current_state = get_next_valid_state(new_state)
	state_timer = 0.0
	
	if current_state == State.SWEEP:
		sweep_dir = -1.0 if player and player.global_position.x < entity.global_position.x else 1.0
		current_facing = sweep_dir

func get_next_valid_state(target: State) -> State:
	if target == State.IDLE and not enable_idle:
		return State.PICK_ATTACK
	if target == State.PICK_ATTACK:
		if not enable_slam and not enable_sweep: return State.IDLE
	return target

func process_pick_attack():
	var pool = []
	if enable_slam: pool.append(State.SLAM_TRACK)
	if enable_sweep: pool.append(State.SWEEP)
	
	if pool.is_empty():
		change_state(State.IDLE)
	else:
		change_state(pool.pick_random())

# --- Logic Processing ---

func process_idle(delta: float):
	state_timer += delta
	check_boundaries()
	
	var target_vel = current_dir.normalized() * idle_move_speed
	entity.velocity = entity.velocity.move_toward(target_vel, 2.0)
	
	if state_timer >= idle_duration:
		change_state(State.PICK_ATTACK)

func process_sweep(delta: float):
	state_timer += delta
	
	if state_timer < sweep_prep_time:
		var target_y = player.global_position.y - sweep_height if player else entity.global_position.y
		entity.global_position.y = lerp(entity.global_position.y, target_y, delta * 5.0)
		entity.velocity = entity.velocity.move_toward(Vector2.ZERO, 15.0)
	else:
		entity.velocity = Vector2(sweep_dir * sweep_speed, 0)
		if state_timer >= sweep_prep_time + (sweep_distance / sweep_speed) or entity.is_on_wall():
			change_state(State.IDLE)

func process_slam_track(delta: float):
	state_timer += delta
	if not player: 
		change_state(State.IDLE)
		return
	
	# ORGANIC TRACKING LOGIC
	# 1. Calculate horizontal difference
	var diff_x = player.global_position.x - entity.global_position.x
	
	# 2. Set target horizontal velocity based on distance
	# If we are far, move at max speed. If close, slow down (damping).
	var target_vel_x = clamp(diff_x * 8.0, -max_tracking_speed, max_tracking_speed)
	
	# 3. Apply horizontal movement with acceleration
	entity.velocity.x = move_toward(entity.velocity.x, target_vel_x, tracking_acceleration * delta)
	
	# 4. Vertical positioning (still smooth lerp as vertical precision is less jarring)
	var target_y = player.global_position.y - slam_height
	entity.global_position.y = lerp(entity.global_position.y, target_y, delta * 5.0)
	
	if state_timer >= tracking_duration:
		# Briefly zero X velocity so he drops straight down
		entity.velocity.x = 0
		change_state(State.SLAM_DOWN)

func process_slam_down(_delta: float):
	entity.velocity = Vector2(0, slam_fall_speed)
	
	if entity.is_on_floor():
		change_state(State.IDLE)

# --- Visuals & Helpers ---

func apply_visual_offsets(_delta: float):
	if not entity.animator: return
	
	var final_offset_y = initial_sprite_y
	var offset_x = 0.0
	
	if current_state == State.IDLE:
		final_offset_y += sin(hover_time * hover_speed) * hover_amplitude
	
	var is_wobbling = false
	var intensity = 0.0
	
	if current_state == State.SLAM_TRACK:
		var progress = state_timer / tracking_duration
		if progress >= wobble_start_threshold:
			is_wobbling = true
			intensity = ((progress - wobble_start_threshold) / (1.0 - wobble_start_threshold)) * wobble_max_strength
			
	elif current_state == State.SWEEP and state_timer < sweep_prep_time:
		is_wobbling = true
		intensity = (state_timer / sweep_prep_time) * (wobble_max_strength * 1.5)

	if is_wobbling:
		offset_x = sin(hover_time * wobble_speed) * intensity
		final_offset_y += cos(hover_time * wobble_speed * 1.1) * intensity
		
	entity.animator.position.x = offset_x
	entity.animator.position.y = final_offset_y

func handle_facing(delta: float):
	if not player or not entity.animator: return
	if current_state == State.SLAM_DOWN: return
	
	if current_state == State.SWEEP:
		entity.animator.scale.x = lerp(entity.animator.scale.x, current_facing, delta * turn_speed)
		return

	if lock_facing_during_slam and current_state == State.SLAM_TRACK: return

	var diff_x = player.global_position.x - entity.global_position.x
	if abs(diff_x) > facing_deadzone:
		current_facing = -1.0 if diff_x < 0 else 1.0

	entity.animator.scale.x = lerp(entity.animator.scale.x, current_facing, delta * turn_speed)

func check_boundaries():
	var space = entity.get_world_2d().direct_space_state
	var dirs = {"up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT, "down": Vector2.DOWN}
	for key in dirs:
		var q = PhysicsRayQueryParameters2D.create(entity.global_position, entity.global_position + (dirs[key] * detection_range), 1)
		if space.intersect_ray(q):
			match key:
				"up": current_dir.y = randf_range(0.3, 0.7)
				"down": current_dir.y = randf_range(-0.3, -0.7)
				"left": current_dir.x = 1.0
				"right": current_dir.x = -1.0
			break
