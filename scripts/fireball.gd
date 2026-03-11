extends Area2D
class_name Fireball

@export var speed := 250.0
var direction := Vector2.RIGHT 

# --- SPIRAL SETTINGS ---
var is_spiraling := false
var spiral_center := Vector2.ZERO
var spiral_angle := 0.0
var spiral_radius := 10.0
var spiral_speed_outward := 60.0 
var spiral_speed_rotate := 2.5   

# NEW: Maximum distance before a spiraling fireball deletes itself
var max_spiral_radius := 400.0 

var pass_through_walls := false 

@export_group("Trail Settings")
@export var trail_spawn_rate := 0.05 
@export var trail_duration := 0.3    

var trail_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	var notifier = $VisibleOnScreenNotifier2D
	
	# NEW: ONLY connect the screen exit deletion if this is a standard straight fireball!
	if notifier and not is_spiraling:
		notifier.screen_exited.connect(queue_free)
		
	if sprite and not is_spiraling:
		sprite.flip_h = direction.x < 0 

func _physics_process(delta: float):
	if is_spiraling:
		spiral_radius += spiral_speed_outward * delta
		spiral_angle += spiral_speed_rotate * delta
		global_position = spiral_center + Vector2(cos(spiral_angle), sin(spiral_angle)) * spiral_radius
		rotation = spiral_angle 
		
		# NEW: Clean up the spiraling fireball once it is safely far away from the arena
		if spiral_radius > max_spiral_radius:
			queue_free()
	else:
		position += direction * speed * delta
	
	trail_timer += delta
	if trail_timer >= trail_spawn_rate:
		trail_timer = 0.0
		spawn_trail_ghost()

func spawn_trail_ghost():
	if not sprite or not sprite.sprite_frames: return
	
	var ghost = Sprite2D.new()
	var tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.texture = tex
	
	ghost.global_position = global_position
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.rotation = rotation 
	
	get_tree().current_scene.add_child(ghost)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true) 
	
	tween.tween_property(ghost, "scale", Vector2.ZERO, trail_duration)
	tween.tween_property(ghost, "modulate:a", 0.0, trail_duration)
	tween.chain().tween_callback(ghost.queue_free)

func _on_body_entered(_body: Node2D):
	if not pass_through_walls:
		queue_free()

func _on_area_entered(area: Area2D):
	if area.owner is GameEntity and area.owner.is_in_group("Player"):
		queue_free()
