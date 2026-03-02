extends CanvasLayer

@onready var hearts_box = $HeartsBox
var heart_texture = preload("res://assets/sprites/ui/healthbar_heart.png")

@export_group("Sizing & Spacing")
@export var heart_display_size = Vector2(10, 10)
@export var heart_spacing = 2 

@export_group("Effects & Colors")
@export var empty_heart_color = Color(0.2, 0.2, 0.2, 0.6)
@export var low_health_color = Color(1, 0.3, 0.3)
@export var flash_color = Color(2, 2, 2, 1)

@export_group("Shake Settings")
@export var max_shake_intensity = 4.0
# This prevents the shake from going past the screen edge if you 
# positioned the UI close to the left.
@export var left_limit_offset = 2.0 

var is_pulsing = false
var original_pos : Vector2

func _ready():
	visible = false
	if hearts_box:
		# Remember exactly where you placed it in the editor
		original_pos = hearts_box.position

func activate(max_hp: int, current_hp: int):
	visible = true 
	hearts_box.add_theme_constant_override("separation", heart_spacing)
	
	# Reset position and color immediately
	hearts_box.position = original_pos
	hearts_box.modulate = Color.WHITE
	
	# Clear old hearts
	for child in hearts_box.get_children():
		child.queue_free()
		
	# Wait one frame for the engine to finish clearing nodes
	await get_tree().process_frame
	
	for i in range(max_hp):
		var rect = TextureRect.new()
		rect.texture = heart_texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = heart_display_size
		rect.pivot_offset = heart_display_size / 2
		
		# Set initial state
		if i < current_hp:
			rect.modulate = Color.WHITE
			rect.scale = Vector2.ONE
		else:
			rect.modulate = empty_heart_color
			rect.scale = Vector2(0.8, 0.8)
			
		hearts_box.add_child(rect)
	
	update_health(current_hp, true) 

func update_health(current_hp: int, skip_shake: bool = false):
	var hearts = hearts_box.get_children()
	
	if not skip_shake:
		apply_impact_shake()
	
	for i in range(hearts.size()):
		var heart = hearts[i]
		if not heart is TextureRect: continue
		
		if i < current_hp:
			heart.modulate = Color.WHITE
			heart.scale = Vector2.ONE
		else:
			heart.modulate = empty_heart_color
			heart.scale = Vector2(0.8, 0.8)
			
	if current_hp == 1:
		start_low_health_pulse()
	else:
		stop_low_health_pulse()

func apply_impact_shake():
	var shake_tween = create_tween()
	var intensity = max_shake_intensity
	
	# Flash the whole bar white
	hearts_box.modulate = flash_color
	
	for i in range(4):
		var rand_x = randf_range(-intensity, intensity)
		var rand_y = randf_range(-intensity, intensity)
		
		# Clamping ensures the X doesn't go too far left of its 'Home' position
		var clamped_x = clamp(rand_x, -left_limit_offset, intensity)
		var offset = Vector2(clamped_x, rand_y)
		
		shake_tween.tween_property(hearts_box, "position", original_pos + offset, 0.02)
		intensity *= 0.5 
	
	# Always return to the editor-defined original position
	shake_tween.tween_property(hearts_box, "position", original_pos, 0.02)
	shake_tween.parallel().tween_property(hearts_box, "modulate", Color.WHITE, 0.1)

func start_low_health_pulse():
	if is_pulsing or hearts_box.get_child_count() == 0: return
	is_pulsing = true
	var first_heart = hearts_box.get_child(0)
	
	var pulse = create_tween().set_loops()
	pulse.tween_property(first_heart, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(first_heart, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(first_heart, "modulate", low_health_color, 0.25)
	pulse.parallel().tween_property(first_heart, "modulate", Color.WHITE, 0.25)

func stop_low_health_pulse():
	is_pulsing = false
	if hearts_box and hearts_box.get_child_count() > 0:
		var first_heart = hearts_box.get_child(0)
		var reset = create_tween()
		reset.tween_property(first_heart, "scale", Vector2.ONE, 0.1)
		reset.tween_property(first_heart, "modulate", Color.WHITE, 0.1)

func deactivate():
	visible = false
	stop_low_health_pulse()
