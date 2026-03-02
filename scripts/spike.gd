extends Area2D

@export var damage_amount: int = 1

func _ready() -> void:
	# Connect the signal via code, or you can do this through the Node tab in the editor
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check if the colliding body is the Player (or anything else that can take damage)
	if body.has_method("take_damage"):
		# Trigger your existing damage and knockback system!
		body.take_damage(damage_amount, global_position)
