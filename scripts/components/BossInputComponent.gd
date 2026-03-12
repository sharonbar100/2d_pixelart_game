extends Node
class_name BossAIComponent

enum State { DORMANT, IDLE, SLAM_TRACK, SLAM_DOWN, SWEEP, FIREBALL, FIREBALL_WAVES, RECOVERY }

@export_group("Aggro Settings")
@export var aggro_area: Area2D
@export var auto_aggro_on_start := false

@export_group("State Toggles")
@export var enable_idle := true
@export var enable_slam := true
@export var enable_sweep := true
@export var enable_fireball := true
@export var enable_fireball_waves := true

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

@export_group("Idle & Flight Settings")
@export var idle_move_speed := 50.0
@export var idle_duration := 3.0
@export var detection_range := 40.0 
@export var default_flight_height := 75.0 
@export var height_adjust_speed := 3.0

@export_group("Recovery Settings")
@export var recovery_duration := 2.5
@export var recovery_flight_height := 20.0 
@export var slam_causes_recovery := true
@export var sweep_causes_recovery := true
@export var fireball_causes_recovery := false
@export var fireball_waves_causes_recovery := true

@export_group("Down Slam Settings")
@export var slam_height := 60.0      
@export var tracking_duration := 1.5 
@export var max_tracking_speed := 300.0
@export var tracking_acceleration := 1200.0
@export var slam_fall_speed := 800.0 
@export var slam_bounce_strength := 250.0 # NEW: Control how high he bounces off the floor

@export_group("Floor Sweep Settings")
@export var sweep_height := 20.0     
@export var sweep_speed := 250.0      
@export var sweep_prep_time := 0.8    
@export var sweep_distance := 300.0   
@export_range(0.0, 1.0) var sweep_bounce_multiplier := 0.7 # NEW: Control horizontal wall bounce
@export var sweep_bounce_height := 150.0 # NEW: Control vertical wall pop-up

@export_group("Targeted Fireball Settings")
@export var fireball_scene: PackedScene
@export var fireball_duration := 4.0
@export var fireball_fire_rate := 0.8
@export var fireball_tracking_speed := 3.0

@export_group("Fireball Spiral Settings")
@export var waves_count := 4
@export var fireballs_per_wave := 6
@export var wave_fire_rate := 0.5     
@export var spiral_outward_speed := 50.0 
@export var spiral_spin_speed := 2.0  

# Internal State
@onready var entity: GameEntity = owner as GameEntity
var player: GameEntity
var current_state: State = State.DORMANT
var state_timer := 0.0
var hover_time := 0.0
var hover_phase := 0.0 
var current_hover_amp := 0.0 
var current_dir := Vector2(1, -0.5) 
var current_facing := 1.0 
var sweep_dir := 1.0
var fire_timer := 0.0 
var waves_fired := 0

# Base Position Caching for Visuals and Combat Areas
var initial_sprite_pos := Vector2.ZERO
var initial_hurtbox_pos := Vector2.ZERO
var initial_attackbox_pos := Vector2.ZERO

func _ready():
	if entity.gravity_component: entity.gravity_component.set_physics_process(false)
	if entity.movement_component: entity.movement_component.set_physics_process(false)
	if entity.jump_component: entity.jump_component.set_physics_process(false)
	
	current_hover_amp = hover_amplitude
	player = get_tree().get_first_node_in_group("Player") as GameEntity
	
	if entity.animator: 
		initial_sprite_pos = entity.animator.position
		current_facing = sign(entity.animator.scale.x)
		entity.animator.play("idle")
		
	if entity.hurtbox_area:
		initial_hurtbox_pos = entity.hurtbox_area.position
	if entity.attack_area:
		initial_attackbox_pos = entity.attack_area.position
	
	if aggro_area:
		aggro_area.body_entered.connect(_on_aggro_area_entered)
	
	if auto_aggro_on_start:
		change_state(State.IDLE)
	else:
		change_state(State.DORMANT)

func _physics_process(delta: float):
	if entity.is_dead: return
	
	hover_time += delta
	apply_visual_offsets(delta)
	handle_facing(delta)
	
	match current_state:
		State.DORMANT: pass 
		State.IDLE: process_idle(delta)
		State.SLAM_TRACK: process_slam_track(delta)
		State.SLAM_DOWN: process_slam_down(delta)
		State.SWEEP: process_sweep(delta)
		State.FIREBALL: process_fireball(delta)
		State.FIREBALL_WAVES: process_fireball_waves(delta)
		State.RECOVERY: process_recovery(delta)

func _on_aggro_area_entered(body: Node2D):
	if current_state == State.DORMANT and (body is GameEntity or body.is_in_group("Player")):
		change_state(State.IDLE)
		if aggro_area.body_entered.is_connected(_on_aggro_area_entered):
			aggro_area.body_entered.disconnect(_on_aggro_area_entered)

func change_state(new_state: State):
	current_state = new_state
	state_timer = 0.0
	fire_timer = 0.0
	waves_fired = 0
	
	if current_state == State.SWEEP:
		sweep_dir = -1.0 if is_instance_valid(player) and player.global_position.x < entity.global_position.x else 1.0
		current_facing = sweep_dir

	# --- Animation Switching ---
	if entity.animator:
		if current_state == State.FIREBALL:
			entity.animator.play("shoot")
		elif current_state == State.RECOVERY: 
			entity.animator.play("recover")
		else:
			entity.animator.play("idle")

func pick_next_attack():
	var pool = []
	if enable_slam: pool.append(State.SLAM_TRACK)
	if enable_sweep: pool.append(State.SWEEP)
	if enable_fireball and fireball_scene: pool.append(State.FIREBALL)
	if enable_fireball_waves and fireball_scene: pool.append(State.FIREBALL_WAVES)
	
	if pool.is_empty() or not enable_idle: 
		change_state(State.IDLE) 
	else:
		change_state(pool.pick_random())

# --- Logic Processing ---

func process_idle(delta: float):
	state_timer += delta
	check_boundaries()
	
	var target_vel_x = current_dir.x * idle_move_speed
	entity.velocity.x = move_toward(entity.velocity.x, target_vel_x, 15.0)
	
	if is_instance_valid(player):
		var target_y = player.global_position.y - default_flight_height
		var target_vel_y = (target_y - entity.global_position.y) * height_adjust_speed
		entity.velocity.y = move_toward(entity.velocity.y, target_vel_y, 15.0)
	else:
		entity.velocity.y = move_toward(entity.velocity.y, 0.0, 10.0)
	
	if state_timer >= idle_duration:
		pick_next_attack()

func process_sweep(delta: float):
	state_timer += delta
	
	if state_timer < sweep_prep_time:
		var target_y = player.global_position.y - sweep_height if is_instance_valid(player) else entity.global_position.y
		entity.velocity.y = (target_y - entity.global_position.y) * 5.0
		entity.velocity.x = move_toward(entity.velocity.x, 0.0, 15.0)
	else:
		entity.velocity.x = sweep_dir * sweep_speed
		
		# Only check for state change once he's actually moving
		if state_timer >= sweep_prep_time + (sweep_distance / sweep_speed) or entity.is_on_wall():
			
			# Organic Wall Recoil! 
			# If he slams into a wall, he violently bounces off and pops up slightly
			if entity.is_on_wall():
				entity.velocity.x = -sweep_dir * (sweep_speed * sweep_bounce_multiplier) 
				entity.velocity.y = -sweep_bounce_height 
				
			change_state(State.RECOVERY if sweep_causes_recovery else State.IDLE)

func process_slam_track(delta: float):
	state_timer += delta
	if not is_instance_valid(player): 
		change_state(State.IDLE)
		return
	
	var diff_x = player.global_position.x - entity.global_position.x
	var target_vel_x = clamp(diff_x * 8.0, -max_tracking_speed, max_tracking_speed)
	entity.velocity.x = move_toward(entity.velocity.x, target_vel_x, tracking_acceleration * delta)
	
	var target_y = player.global_position.y - slam_height
	entity.velocity.y = (target_y - entity.global_position.y) * 5.0
	
	if state_timer >= tracking_duration:
		entity.velocity.x = 0
		entity.velocity.y = 0 
		change_state(State.SLAM_DOWN)

func process_slam_down(_delta: float):
	entity.velocity.x = move_toward(entity.velocity.x, 0.0, 20.0)
	entity.velocity.y = slam_fall_speed
	
	if entity.is_on_floor():
		# Organic Floor Recoil!
		# The boss physically bounces off the floor when he hits it
		entity.velocity.y = -slam_bounce_strength
		change_state(State.RECOVERY if slam_causes_recovery else State.IDLE)

func process_fireball(delta: float):
	state_timer += delta
	fire_timer += delta
	
	entity.velocity.x = move_toward(entity.velocity.x, 0.0, 15.0)
	
	if is_instance_valid(player):
		entity.velocity.y = (player.global_position.y - entity.global_position.y) * fireball_tracking_speed
	else:
		entity.velocity.y = move_toward(entity.velocity.y, 0.0, 10.0)
		
	if fire_timer >= fireball_fire_rate:
		fire_timer = 0.0
		shoot_fireball()
		
	if state_timer >= fireball_duration:
		change_state(State.RECOVERY if fireball_causes_recovery else State.IDLE)

func process_fireball_waves(delta: float):
	state_timer += delta
	fire_timer += delta
	
	entity.velocity.x = move_toward(entity.velocity.x, 0.0, 15.0)
	if is_instance_valid(player):
		var target_y = player.global_position.y - default_flight_height
		var target_vel_y = (target_y - entity.global_position.y) * height_adjust_speed
		entity.velocity.y = move_toward(entity.velocity.y, target_vel_y, 15.0)
	else:
		entity.velocity.y = move_toward(entity.velocity.y, 0.0, 10.0)
	
	if fire_timer >= wave_fire_rate and waves_fired < waves_count:
		fire_timer = 0.0
		shoot_fireball_circle()
		waves_fired += 1
		
	if waves_fired >= waves_count and fire_timer > 1.0:
		change_state(State.RECOVERY if fireball_waves_causes_recovery else State.IDLE)

func process_recovery(delta: float):
	state_timer += delta
	
	# Exhausted Drift
	# He lazily floats backward away from the player to create space while vulnerable
	var target_vel_x = 0.0
	if is_instance_valid(player):
		var dir_away = sign(entity.global_position.x - player.global_position.x)
		if dir_away == 0: dir_away = 1.0
		target_vel_x = dir_away * 30.0 # Slow retreat speed
	
	# Smooth Skidding
	# move_toward allows him to physically skid to a halt from his sweep, 
	# and allows his wall/floor bounces to play out organically before he settles into the drift
	entity.velocity.x = move_toward(entity.velocity.x, target_vel_x, 200.0 * delta)
	
	if is_instance_valid(player):
		var target_y = player.global_position.y - recovery_flight_height
		var target_vel_y = (target_y - entity.global_position.y) * (height_adjust_speed * 0.4)
		entity.velocity.y = lerp(entity.velocity.y, target_vel_y, delta * 3.0)
	else:
		entity.velocity.y = lerp(entity.velocity.y, 0.0, delta * 3.0)
	
	if state_timer >= recovery_duration:
		change_state(State.IDLE)

func shoot_fireball():
	if not fireball_scene: return
	
	var fireball = fireball_scene.instantiate() as Fireball
	fireball.global_position = entity.global_position
	fireball.direction = Vector2(current_facing, 0)
	
	get_tree().current_scene.add_child(fireball)

func shoot_fireball_circle():
	if not fireball_scene: return
	
	var angle_step = TAU / fireballs_per_wave
	var wave_offset = waves_fired * (angle_step / 2.0)
	
	for i in range(fireballs_per_wave):
		var angle = (i * angle_step) + wave_offset
		
		var fireball = fireball_scene.instantiate() as Fireball
		
		fireball.is_spiraling = true
		fireball.pass_through_walls = true 
		fireball.spiral_center = entity.global_position
		fireball.spiral_angle = angle
		fireball.spiral_radius = 20.0 
		fireball.spiral_speed_outward = spiral_outward_speed
		fireball.spiral_speed_rotate = spiral_spin_speed
		
		get_tree().current_scene.add_child(fireball)

# --- Visuals & Helpers ---

func apply_visual_offsets(delta: float):
	var offset := Vector2.ZERO
	
	var is_recovering = current_state == State.RECOVERY
	var target_amp = hover_amplitude * (0.3 if is_recovering else 1.0)
	var target_speed = hover_speed * (0.5 if is_recovering else 1.0)
	
	current_hover_amp = lerp(current_hover_amp, target_amp, delta * 4.0)
	hover_phase += target_speed * delta
	
	if current_state != State.DORMANT and current_state != State.SLAM_DOWN:
		offset.y += sin(hover_phase) * current_hover_amp
	
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
		
	elif current_state == State.FIREBALL_WAVES:
		is_wobbling = true
		intensity = wobble_max_strength * 0.8

	if is_wobbling:
		offset.x += sin(hover_time * wobble_speed) * intensity
		offset.y += cos(hover_time * wobble_speed * 1.1) * intensity
		
	if entity.animator: 
		entity.animator.position = initial_sprite_pos + offset
	if entity.hurtbox_area: 
		entity.hurtbox_area.position = initial_hurtbox_pos + offset
	if entity.attack_area: 
		entity.attack_area.position = initial_attackbox_pos + offset

func handle_facing(delta: float):
	if not is_instance_valid(player) or not entity.animator or current_state == State.DORMANT: return
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
	var dirs = {"left": Vector2.LEFT, "right": Vector2.RIGHT} 
	
	for key in dirs:
		var q = PhysicsRayQueryParameters2D.create(
			entity.global_position, 
			entity.global_position + (dirs[key] * detection_range), 
			1 
		)
		
		if space.intersect_ray(q):
			match key:
				"left": current_dir.x = 1.0
				"right": current_dir.x = -1.0
			break
