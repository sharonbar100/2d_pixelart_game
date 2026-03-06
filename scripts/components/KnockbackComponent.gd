extends Node
class_name KnockbackComponent

@export var knockback_power := 250.0
@export var knockback_upward_force := -200.0
@export var knockback_stun_time := 0.25

# REFACTOR: Internal physics logic. It does not fetch info from movement nodes.
@export var knockback_gravity_scale := 0.85
@export var knockback_friction := 3000.0
@export var knockback_air_drag := 500.0

var knockback_timer := 0.0
@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = -10
	if not entity or entity.knockback_component != self: 
		set_physics_process(false)

func _physics_process(delta: float):
	if not entity.is_in_knockback or entity.is_dead: 
		return

	knockback_timer -= delta
	var hit_ground_early = entity.is_on_floor() and entity.velocity.y >= 0 and knockback_timer < (knockback_stun_time - 0.05)
	
	if knockback_timer <= 0 or hit_ground_early:
		entity.is_in_knockback = false
		return

	entity.velocity += entity.get_gravity() * knockback_gravity_scale * delta
	
	if entity.is_on_floor():
		entity.velocity.x = move_toward(entity.velocity.x, 0, knockback_friction * delta)
	else:
		entity.velocity.x = move_toward(entity.velocity.x, 0, knockback_air_drag * delta)

func apply_knockback(source_position: Vector2):
	entity.is_in_knockback = true 
	knockback_timer = knockback_stun_time
	var knock_dir = -1.0 if source_position.x > entity.global_position.x else 1.0
	entity.velocity = Vector2(knock_dir * knockback_power, knockback_upward_force)
