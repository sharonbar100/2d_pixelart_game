extends Node
class_name PatrolAIComponent

@export var ledge_check_forward := 12.0
@export var ledge_check_down := 16.0

@onready var entity: GameEntity = owner as GameEntity
var direction := -1.0

func _ready():
	process_physics_priority = -100 # Runs before normal movement, just like human input
	# Verify it is assigned to the input slot
	if not entity or entity.input_component != self: 
		set_physics_process(false)
		return

func _physics_process(_delta: float):
	# If dead, knocked back, or stunned, clear the input
	if entity.is_dead or entity.is_in_knockback or entity.block_input: 
		entity.input_direction = 0.0
		return

	# Turn around if hitting a wall or about to fall off a ledge
	if entity.is_on_wall() or is_near_ledge():
		direction *= -1.0

	# Output the AI's "joystick" direction to the blackboard
	entity.input_direction = direction

func is_near_ledge() -> bool:
	var check_pos = entity.global_position + Vector2(direction * ledge_check_forward, ledge_check_down)
	return not entity.is_solid_tile_at(check_pos)
