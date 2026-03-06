extends Node
class_name AnimationComponent

@onready var entity: GameEntity = owner as GameEntity

func _ready():
	process_physics_priority = 110
	if not entity or entity.animation_component != self:
		set_physics_process(false)
		return
		
	if entity.animator:
		entity.animator.animation_looped.connect(_on_animation_looped)
		entity.animator.play("idle")

func _physics_process(_delta: float):
	if entity.is_dead or not entity.animator: return
	
	if entity.attack_area: entity.attack_area.scale.x = entity.last_facing_direction
		
	var target_anim = entity.animator.animation
	var is_facing_left = entity.last_facing_direction < 0
	
	if entity.is_in_knockback: target_anim = "fall"
	elif entity.is_attacking: target_anim = "attack"
	elif entity.is_dashing: target_anim = "dash"
	elif entity.is_hanging: target_anim = "ledge_idle"
	elif entity.is_on_ladder:
		if entity.velocity == Vector2.ZERO: target_anim = "hang"
		elif entity.velocity.y != 0: target_anim = "climb_y"
		else: target_anim = "climb_x"
	elif not entity.is_on_floor():
		target_anim = "jump" if entity.velocity.y < 0 else "fall"
	else:
		target_anim = "walk" if entity.velocity.x != 0 else "idle"
	
	entity.animator.flip_h = not is_facing_left if entity.is_hanging else is_facing_left
	if entity.animator.animation != target_anim: entity.animator.play(target_anim)
	
	if entity.is_on_ladder and target_anim != "hang":
		if entity.velocity.length() < 5.0: entity.animator.pause()
		elif not entity.animator.is_playing(): entity.animator.play()

func _on_animation_looped():
	if entity.animator and entity.animator.animation == "climb_y":
		entity.animator.frame = 5
