extends Node
class_name AttackComponent

@export var attack_damage := 1
@export var active_hitbox_frames: Array[int] = [0, 1, 2] 

@export_group("Responsiveness")
@export var attack_buffer_duration := 0.15 
@export var b_reverse_frames := 2 # How many animation frames you have to turn around AFTER pressing attack

@onready var entity: GameEntity = owner as GameEntity
var attack_shape: CollisionShape2D
var attack_buffer_timer := 0.0

func _ready():
	process_physics_priority = -5
	if not entity or entity.attack_component != self:
		set_physics_process(false)
		return
		
	if entity.attack_area: 
		entity.attack_area.monitoring = false
		entity.attack_area.monitorable = true 
		
		entity.attack_area.add_to_group("Hitbox")
		entity.attack_area.set_meta("damage", attack_damage)
		entity.attack_area.set_meta("source_entity", entity)
		
		for child in entity.attack_area.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				attack_shape = child
				attack_shape.disabled = true
				break
		
	if entity.animator:
		entity.animator.frame_changed.connect(_on_frame_changed)
		entity.animator.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float):
	if entity.is_dead: return

	# 1. Handle Input Buffering
	if Input.is_action_just_pressed("attack"):
		attack_buffer_timer = attack_buffer_duration
	else:
		attack_buffer_timer -= delta

	# 2. Check if we are allowed to attack
	var can_attack = not entity.is_attacking and not entity.is_dashing and not entity.is_on_ladder and not entity.is_hanging
	
	if attack_buffer_timer > 0 and can_attack:
		perform_attack()

	# 3. LATE TURNAROUND (B-REVERSE WINDOW)
	# If the player pressed the direction a tiny fraction of a second AFTER the attack button
	if entity.is_attacking and entity.animator and entity.animator.animation == "attack":
		# As long as we are in the early startup frames of the attack
		if entity.animator.frame <= b_reverse_frames:
			if entity.input_direction != 0 and sign(entity.input_direction) != entity.last_facing_direction:
				# Instantly flip the character
				entity.last_facing_direction = sign(entity.input_direction)
				
				# Force immediate visual and physical hitbox flip
				if entity.attack_area: 
					entity.attack_area.scale.x = entity.last_facing_direction
				if entity.animator: 
					entity.animator.flip_h = entity.last_facing_direction < 0

func perform_attack():
	attack_buffer_timer = 0.0
	entity.is_attacking = true
	
	# INITIAL INSTANT TURNAROUND
	# If the direction is already held when the button is pressed
	if entity.input_direction != 0:
		entity.last_facing_direction = sign(entity.input_direction)
		
	# Immediate update before physics or animation steps
	if entity.attack_area: 
		entity.attack_area.scale.x = entity.last_facing_direction
	if entity.animator: 
		entity.animator.flip_h = entity.last_facing_direction < 0

	# Play animation
	if entity.animator: 
		entity.animator.play("attack")
		
	# FRAME 1 HITBOX
	# Instantly turn on the hitbox so it connects on the exact frame
	if attack_shape and 0 in active_hitbox_frames:
		attack_shape.disabled = false

func _on_frame_changed():
	if entity.is_attacking and entity.animator and entity.animator.animation == "attack":
		var is_deadly_frame = entity.animator.frame in active_hitbox_frames
		if attack_shape: 
			attack_shape.disabled = not is_deadly_frame

func _on_animation_finished():
	if entity.animator and entity.animator.animation == "attack":
		entity.is_attacking = false
		if attack_shape: 
			attack_shape.disabled = true
