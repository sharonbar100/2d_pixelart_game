@tool
extends Area2D
class_name TileModifierRegion

@export var main_terrain: TileMapLayer:
	set(value):
		main_terrain = value
		_update_ghost_tilesets()

@export_group("Ghost Layers")
@export var tiles_to_add_layer: TileMapLayer:
	set(value):
		tiles_to_add_layer = value
		_update_ghost_tilesets()

@export var tiles_to_remove_layer: TileMapLayer:
	set(value):
		tiles_to_remove_layer = value
		_update_ghost_tilesets()

var saved_tiles_to_add: Array[Dictionary] = []
var saved_tiles_to_remove: Array[Vector2i] = []
var has_triggered := false

# --- EDITOR MAGIC ---
# This runs automatically whenever you assign a layer in the Inspector
func _update_ghost_tilesets():
	if Engine.is_editor_hint():
		if main_terrain and main_terrain.tile_set:
			if tiles_to_add_layer:
				tiles_to_add_layer.tile_set = main_terrain.tile_set
			if tiles_to_remove_layer:
				tiles_to_remove_layer.tile_set = main_terrain.tile_set

# --- GAMEPLAY LOGIC ---
func _ready():
	# If we are in the Godot Editor, STOP here! Do not run the game code.
	if Engine.is_editor_hint():
		return 
		
	body_entered.connect(_on_body_entered)
	
	if not main_terrain:
		print("WARNING: Main Terrain not assigned to ", name)
		return

	# 1. Memorize and hide the tiles we want to ADD
	if tiles_to_add_layer:
		for cell in tiles_to_add_layer.get_used_cells():
			var source_id = tiles_to_add_layer.get_cell_source_id(cell)
			var atlas_coord = tiles_to_add_layer.get_cell_atlas_coords(cell)
			var alt_tile = tiles_to_add_layer.get_cell_alternative_tile(cell)
			
			saved_tiles_to_add.append({
				"pos": cell,
				"source": source_id,
				"atlas": atlas_coord,
				"alt": alt_tile
			})
		
		tiles_to_add_layer.clear()

	# 2. Memorize and hide the tiles we want to REMOVE
	if tiles_to_remove_layer:
		saved_tiles_to_remove = tiles_to_remove_layer.get_used_cells()
		tiles_to_remove_layer.clear()

func _on_body_entered(body: Node2D):
	if Engine.is_editor_hint() or has_triggered: 
		return
	
	if body is GameEntity and body.is_in_group("Player"):
		modify_tiles()
		has_triggered = true
		
		# Safely disable the trigger so it doesn't fire again
		set_deferred("monitoring", false)

func modify_tiles():
	if not main_terrain: return
	
	# Add the new tiles
	for data in saved_tiles_to_add:
		main_terrain.set_cell(data["pos"], data["source"], data["atlas"], data["alt"])
	
	# Delete the marked tiles
	for cell in saved_tiles_to_remove:
		main_terrain.set_cell(cell, -1)
