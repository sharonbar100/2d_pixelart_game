extends Node
class_name ContactDamageComponent

@export var damage := 1
@onready var entity: GameEntity = owner as GameEntity

func _ready():
	if not entity or entity.attack_component != self: 
		set_physics_process(false)
		return
		
	if entity.attack_area:
		entity.attack_area.add_to_group("Hitbox")
		entity.attack_area.set_meta("damage", damage)
		entity.attack_area.set_meta("source_entity", entity)
		
		# FIX: The enemy body is always deadly, so it must always be monitorable
		entity.attack_area.monitorable = true
		entity.attack_area.monitoring = false # It doesn't need to look, it just needs to be touched
