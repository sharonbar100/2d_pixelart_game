extends Node
class_name AttackComponent

@export var attack_damage := 1
@export var active_hitbox_frames: Array[int] = [2] 

@onready var entity: GameEntity = owner as GameEntity
var attack_shape # Will hold the CollisionShape2D

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

func _physics_process(_delta: float):
	if entity.is_dead: return

	if Input.is_action_just_pressed("attack") and not entity.is_attacking and not entity.is_dashing and not entity.is_on_ladder and not entity.is_hanging:
		entity.is_attacking = true
		if entity.animator: entity.animator.play("attack")

func _on_frame_changed():
	if entity.is_attacking and entity.animator and entity.animator.animation == "attack":
		var is_deadly_frame = entity.animator.frame in active_hitbox_frames
		if attack_shape: 
			attack_shape.set_deferred("disabled", not is_deadly_frame)

func _on_animation_finished():
	if entity.animator and entity.animator.animation == "attack":
		entity.is_attacking = false
		if attack_shape: 
			attack_shape.set_deferred("disabled", true)
