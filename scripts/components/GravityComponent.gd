extends Node
class_name GravityComponent

@export var gravity_scale := 0.85
@export var max_fall_speed := 380.0

@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = 30 # Runs after movement/jumping to finalize vertical speed
	if not entity or entity.gravity_component != self: 
		set_physics_process(false)

func _physics_process(delta: float):
	# Don't apply standard gravity if we are doing special physics
	if entity.is_dead or entity.is_in_knockback or entity.is_dashing or entity.is_on_ladder or entity.is_hanging:
		return

	if not entity.is_on_floor():
		entity.velocity += entity.get_gravity() * gravity_scale * delta
		if entity.velocity.y > max_fall_speed:
			entity.velocity.y = max_fall_speed
