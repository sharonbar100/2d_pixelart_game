extends Node
class_name JumpComponent

@export var jump_velocity := -250.0
@export var jump_buffer_duration := 0.1
@export var variable_jump_multiplier := 0.5

var jump_buffer_timer := 0.0
var has_jumped := false

@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = 25 
	if not entity or entity.jump_component != self: 
		set_physics_process(false)

func _physics_process(delta: float):
	# FIX: Move the Observer reset logic ABOVE the early return guard!
	# Now it will constantly reset `has_jumped` to false while you are safely on a ledge/ladder.
	if entity.is_on_floor() or entity.is_hanging or entity.is_on_ladder:
		has_jumped = false

	# Now we can safely pause the rest of the jump processing
	if entity.is_dead or entity.is_in_knockback or entity.is_dashing or entity.is_on_ladder or entity.is_hanging:
		return

	if entity.input_jump_pressed and not entity.block_input:
		jump_buffer_timer = jump_buffer_duration
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and not has_jumped:
		perform_jump()

	if entity.input_jump_released and entity.velocity.y < 0:
		entity.velocity.y *= variable_jump_multiplier

func perform_jump():
	entity.velocity.y = jump_velocity
	has_jumped = true
	jump_buffer_timer = 0
