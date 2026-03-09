extends CharacterBody2D
class_name GameEntity

# ==========================================
# --- PHYSICAL NODES (Assign in Inspector) ---
# ==========================================
@export_group("Entity Nodes")
@export var animator: AnimatedSprite2D
@export var main_collider: CollisionShape2D
@export var attack_area: Area2D
@export var hurtbox_area: Area2D          
@export var hurtbox_shape: CollisionShape2D 

# ==========================================
# --- MODULE SLOTS (Assign in Inspector) ---
# ==========================================
@export_group("Entity Modules")
@export var input_component: Node 
@export var movement_component: Node
@export var jump_component: Node
@export var gravity_component: Node
@export var dash_component: Node
@export var attack_component: Node
@export var health_component: Node
@export var knockback_component: Node
@export var animation_component: Node
@export var ladder_component: Node
@export var ledge_component: Node

# --- Shared State Blackboard ---
var is_dead := false
var is_invincible := false
var is_in_knockback := false
var is_on_ladder := false
var is_overlapping_ladder := false
var is_hanging := false
var is_dashing := false
var is_attacking := false

var block_input := false
var last_facing_direction := 1.0
var was_in_air := false
var jumped_from_ladder := false
var last_velocity_y := 0.0

# --- Input Buffer ---
var input_direction := 0.0
var input_vertical := 0.0
var input_jump_pressed := false
var input_jump_released := false
var input_dash_pressed := false
var input_dash_held := false
var input_attack_pressed := false
var input_down_pressed := false
var input_up_held := false     # NEW: For Camera panning up
var input_down_held := false   # NEW: For Camera panning down

var all_layers: Array[TileMapLayer] = []

func _notification(what):
	if what == Node.NOTIFICATION_UNPAUSED:
		block_input = true
		await get_tree().process_frame
		block_input = false

func _ready():
	process_physics_priority = 100 
	
	is_dead = false
	add_to_group("Entity")
	if self.name == "Player": add_to_group("Player")
		
	all_layers.clear()
	var interactable_nodes = get_tree().get_nodes_in_group("InteractableLayers")
	for node in interactable_nodes:
		if node is TileMapLayer:
			all_layers.append(node)

func _physics_process(_delta: float) -> void:
	if is_dead: return
	move_and_slide()

func is_solid_tile_at(pos: Vector2) -> bool:
	for layer in all_layers:
		if not is_instance_valid(layer) or not layer.tile_set: continue
		if layer.tile_set.get_physics_layers_count() == 0: continue
			
		var map_pos = layer.local_to_map(layer.to_local(pos))
		var tile_data = layer.get_cell_tile_data(map_pos)
		if tile_data and tile_data.get_collision_polygons_count(0) > 0:
			return true
	return false

func get_solid_tile_center(pos: Vector2) -> Vector2:
	for layer in all_layers:
		if not is_instance_valid(layer) or not layer.tile_set: continue
		if layer.tile_set.get_physics_layers_count() == 0: continue
			
		var map_pos = layer.local_to_map(layer.to_local(pos))
		var tile_data = layer.get_cell_tile_data(map_pos)
		if tile_data and tile_data.get_collision_polygons_count(0) > 0:
			var center_local = layer.map_to_local(map_pos)
			return layer.to_global(center_local)
	return pos
