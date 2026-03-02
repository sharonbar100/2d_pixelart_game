extends Area2D

@export_file("*.tscn") var next_level_scene: String = "res://scenes/ui/main_menu.tscn"

# This line finds your AnimatedSprite2D child node
@onready var animator: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 1. Start the animation
	if animator:
		animator.play("default")
	
	# 2. Safety check for the signal connection to avoid the "already connected" error
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		# 3. Use call_deferred to avoid the "physics callback" error
		# This waits for the physics frame to end before running complete_level
		call_deferred("complete_level")

func complete_level() -> void:
	# 4. Make sure the engine isn't paused (important for GlobalPause menus)
	get_tree().paused = false
	
	if next_level_scene != "":
		# 5. Double-check that the file actually exists to prevent crashing
		if ResourceLoader.exists(next_level_scene):
			get_tree().change_scene_to_file(next_level_scene)
		else:
			print("Error: Scene file not found at ", next_level_scene)
	else:
		print("Warning: No next level scene assigned to flag!")
