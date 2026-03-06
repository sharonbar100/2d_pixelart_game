extends Node
class_name MovementComponent

@export var speed := 130.0
@export var acceleration := 2500.0
@export var friction := 5000.0
@export var air_acceleration := 2500.0
@export var shake_threshold := 500.0

@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = 20
	if not entity or entity.movement_component != self: 
		set_physics_process(false)

func _physics_process(delta: float):
	if entity.is_dead or entity.is_in_knockback or entity.is_dashing or entity.is_on_ladder or entity.is_hanging:
		return

	# Handle landing detection (since gravity handles the actual falling now)
	if not entity.is_on_floor():
		entity.was_in_air = true
		entity.last_velocity_y = entity.velocity.y
	else:
		if entity.was_in_air:
			if entity.last_velocity_y > shake_threshold:
				get_tree().call_group("Camera", "apply_shake", 6.0)
			entity.was_in_air = false
		entity.jumped_from_ladder = false

	var direction := entity.input_direction
	if direction != 0:
		if not entity.is_attacking:
			entity.last_facing_direction = sign(direction)
			
		var current_accel = acceleration if entity.is_on_floor() else air_acceleration
		entity.velocity.x = move_toward(entity.velocity.x, direction * speed, current_accel * delta)
	else:
		if entity.is_on_floor(): 
			entity.velocity.x = move_toward(entity.velocity.x, 0, friction * delta)
		else: 
			entity.velocity.x = move_toward(entity.velocity.x, 0, air_acceleration * delta)
