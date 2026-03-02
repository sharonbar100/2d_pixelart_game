extends CanvasLayer

@onready var heart_container = $HeartContainer # Make sure your HBoxContainer is named this!

# Load your heart texture here! 
# Drag your heart.png from the FileSystem into this slot in the Inspector, 
# OR replace "res://icon.svg" with the path to your heart image.
var heart_texture = preload("res://icon.svg") 

func _ready():
	var player = get_tree().get_first_node_in_group("Player") # Ensure your player is in group "Player"
	if not player:
		# Fallback search if you haven't set up Groups yet
		player = get_parent().find_child("Player", true, false)
	
	if player:
		player.health_changed.connect(update_hearts)
		update_hearts(player.max_health)

func update_hearts(current_health: int):
	# 1. Clear existing hearts
	for child in heart_container.get_children():
		child.queue_free()
	
	# 2. Add new hearts based on current health
	for i in range(current_health):
		var heart = TextureRect.new()
		heart.texture = heart_texture
		heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		heart.custom_minimum_size = Vector2(32, 32) # Size of the hearts
		heart_container.add_child(heart)
