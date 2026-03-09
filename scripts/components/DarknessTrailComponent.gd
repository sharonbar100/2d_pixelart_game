extends Node2D
class_name ShadowBodyComponent

@export_group("Head & Body Shape")
@export var head_radius := 8.0     # Radius of the head spawn circle (16px diameter)
@export var tail_length := 38.0    # Total length of the shadow body
@export var body_taper := 1.8      # Higher = sharper V-shape at the bottom

@export_group("Density & Performance")
@export var particles_per_second := 2000.0 
@export var max_particles := 3500

@export_group("Fluid Physics")
@export var converge_speed := 12.0 # How fast particles pull "inward" toward the center
@export var fall_speed := 15.0     # Vertical drift
@export var sway_amount := 5.0
@export var sway_speed := 3.5

@onready var entity: GameEntity = owner as GameEntity

class ShadowPixel:
	var pos: Vector2
	var spawn_offset: Vector2 # Where it started inside the head-circle
	var life: float
	var max_life: float
	var active: bool = false
	var noise_seed: float

var pool: Array[ShadowPixel] = []
var emit_timer := 0.0

func _ready():
	set_as_top_level(true)
	for i in range(max_particles):
		pool.append(ShadowPixel.new())
	
	# Initial burst to fill the body volume instantly
	for i in range(max_particles / 1.2):
		spawn_particle(true)

func _physics_process(delta: float):
	if not entity or entity.is_dead: 
		update_particles(delta)
		queue_redraw()
		return
	
	emit_timer += delta
	var wait_time = 1.0 / particles_per_second
	while emit_timer >= wait_time:
		spawn_particle(false)
		emit_timer -= wait_time
	
	update_particles(delta)
	queue_redraw()

func spawn_particle(is_initial: bool):
	for p in pool:
		if not p.active:
			p.active = true
			p.max_life = randf_range(0.9, 1.5)
			p.life = p.max_life if not is_initial else randf_range(0.1, 1.5)
			p.noise_seed = randf() * TAU
			
			# FULL CIRCLE VOLUME SPAWN:
			# sqrt(randf) ensures an even distribution across the whole circle area
			var angle = randf() * TAU
			var r = sqrt(randf()) * head_radius
			p.spawn_offset = Vector2(cos(angle), sin(angle))
			# We multiply by radius here to define the initial local "birth" spot
			var local_pos = p.spawn_offset * r
			
			var head_center = entity.global_position
			
			if is_initial:
				# Distribute particles down the body length for the first frame
				var age_sim = 1.0 - (p.life / p.max_life)
				p.pos = head_center + Vector2(local_pos.x, local_pos.y + (age_sim * tail_length))
			else:
				p.pos = head_center + local_pos
				
			return

func update_particles(delta: float):
	var time = Time.get_ticks_msec() * 0.001
	var head_pos = entity.global_position

	for p in pool:
		if not p.active: continue
		
		p.life -= delta
		if p.life <= 0:
			p.active = false
			continue
		
		var age = 1.0 - (p.life / p.max_life)
		
		# 1. THE INWARD TAPER (Convergence)
		# Particles pull toward the vertical center (X=0) as they get older
		# We use pow() to make the "neck" transition smoother
		var taper_factor = lerp(1.0, 0.1, pow(age, body_taper))
		
		# 2. SWAY LOGIC
		var sway = sin(time * sway_speed + (age * 4.0) + p.noise_seed) * sway_amount * age
		
		# 3. CALCULATE TARGET
		# The X position is the head center + original spawn offset squeezed by the taper
		var target_x = head_pos.x + (p.spawn_offset.x * head_radius * taper_factor) + sway
		
		# The Y position drops down from the head
		var target_y = head_pos.y + (p.spawn_offset.y * head_radius * taper_factor) + (age * tail_length)
		
		# 4. MOVE TO TARGET
		# High speed at the top, lower speed/lag at the bottom for fluid feel
		var follow_weight = lerp(converge_speed, converge_speed * 0.4, age)
		p.pos.x = lerp(p.pos.x, target_x, follow_weight * delta)
		p.pos.y = lerp(p.pos.y, target_y, follow_weight * delta)

func _draw():
	var color = Color.BLACK
	
	for p in pool:
		if not p.active: continue
		
		var age = 1.0 - (p.life / p.max_life)
		
		# JAGGED DITHERING (Matches boss01.png tail)
		if age > 0.85:
			# Randomly hide pixels at the tail tip to make it look "ripped"
			if randf() > (1.0 - age) * 6.0: continue
		
		# SNAP TO PIXEL GRID
		var draw_pos = p.pos.floor()
		
		# Draw the 1x1 pixel
		draw_rect(Rect2(draw_pos, Vector2(1, 1)), color)
