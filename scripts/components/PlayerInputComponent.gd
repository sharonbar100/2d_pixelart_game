extends Node
class_name PlayerInputComponent

@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = -100 
	if not entity or entity.input_component != self:
		set_physics_process(false)

func _physics_process(_delta: float):
	if entity.is_dead or entity.block_input:
		entity.input_direction = 0.0
		entity.input_vertical = 0.0
		entity.input_jump_pressed = false
		entity.input_jump_released = false
		entity.input_dash_pressed = false
		entity.input_dash_held = false 
		entity.input_attack_pressed = false
		entity.input_down_pressed = false
		entity.input_up_held = false
		entity.input_down_held = false
		return

	entity.input_direction = Input.get_axis("move_left", "move_right")
	entity.input_vertical = Input.get_axis("move_up", "move_down")
	entity.input_jump_pressed = Input.is_action_just_pressed("jump")
	entity.input_jump_released = Input.is_action_just_released("jump")
	entity.input_dash_pressed = Input.is_action_just_pressed("dash")
	entity.input_dash_held = Input.is_action_pressed("dash")
	entity.input_attack_pressed = Input.is_action_just_pressed("attack")
	
	# Keep just_pressed for quick events, but we also have held now for camera/drops
	entity.input_down_pressed = Input.is_action_just_pressed("move_down")
	entity.input_up_held = Input.is_action_pressed("move_up")
	entity.input_down_held = Input.is_action_pressed("move_down")
