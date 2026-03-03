extends CharacterBody2D

# --- Health Settings ---
@export var max_health = 3
var health = 3

# --- Movement Settings ---
@export var speed = 40.0
@export var gravity_scale = 1.5
@export var direction = -1.0 

# --- Knockback Settings ---
@export var knockback_power = 250.0
@export var knockback_upward_force = -150.0
@export var knockback_duration = 0.2
var knockback_timer = 0.0
var is_in_knockback = false

# --- Nodes Reference ---
@onready var pivot = $Pivot
@onready var ledge_check = $Pivot/LedgeCheck
@onready var wall_check = $Pivot/WallCheck
@onready var animator = $AnimatedSprite2D
@onready var hitbox = $Hitbox 

func _ready():
	health = max_health
	add_to_group("Enemy")
	update_visuals_and_sensors()

func _physics_process(delta: float) -> void:
	# 1. Handle Gravity
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta

	# 2. Handle Knockback Timer
	if is_in_knockback:
		knockback_timer -= delta
		# Apply friction so they don't slide forever
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		
		if knockback_timer <= 0:
			is_in_knockback = false
	
	# 3. Handle Regular Movement (Only if NOT in knockback)
	else:
		if is_on_floor():
			if wall_check.is_colliding() or not ledge_check.is_colliding():
				flip_enemy()
			
			velocity.x = direction * speed
			
			if animator:
				animator.play("walk")

	move_and_slide()
	check_for_player_damage()

func take_damage(amount: int, source_position: Vector2):
	health -= amount
	
	# Start Knockback
	is_in_knockback = true
	knockback_timer = knockback_duration
	
	# Calculate Direction (away from the player)
	var knock_dir = 1.0 if source_position.x < global_position.x else -1.0
	velocity = Vector2(knock_dir * knockback_power, knockback_upward_force)
	
	# Visual Feedback
	if animator and animator.sprite_frames.has_animation("hurt"):
		animator.play("hurt")
	
	# Flash White
	modulate = Color(10, 10, 10) 
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)

	if health <= 0:
		die()

func die():
	queue_free()

func check_for_player_damage():
	var overlapping_areas = hitbox.get_overlapping_areas()
	for area in overlapping_areas:
		# --- FIX: Indestructible Tree Climber ---
		# This will check the area, then its parent, then its grandparent, 
		# until it finds the root Player node that has the take_damage function.
		var target = area
		while target != null:
			if target.has_method("take_damage"):
				target.take_damage(1, global_position)
				break # We found the player and hit them, stop looking!
			target = target.get_parent()

func flip_enemy():
	direction *= -1.0
	update_visuals_and_sensors()
	global_position.x += direction * 2

func update_visuals_and_sensors():
	if pivot:
		pivot.scale.x = direction 
	if animator:
		animator.flip_h = (direction > 0)
