extends Area2D

@export var tilemap_layer: TileMapLayer 

@export_group("Tile Assets")
@export var wall_atlas_coords := Vector2i(1, 0) 
@export var source_id := 0

@export_group("Tiles to ADD (Close Door)")
@export var door_tiles: Array[Vector2i] = [Vector2i(10, 5), Vector2i(10, 6)]

@export_group("Tiles to REMOVE")
@export var remove_tiles: Array[Vector2i] = [Vector2i(12, 5), Vector2i(12, 6), Vector2i(12, 7)]

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if not tilemap_layer:
		print("WARNING: TileMapLayer not assigned to ", name)

func _on_body_entered(body: Node2D):
	# Check for player using GameEntity class or group
	if body is GameEntity or body.is_in_group("Player"):
		print("Player entered arena trigger.")
		modify_arena()
		
		# Disconnecting prevents it from running twice
		if body_entered.is_connected(_on_body_entered):
			body_entered.disconnect(_on_body_entered) 

func modify_arena():
	if not tilemap_layer: 
		print("Error: No TileMapLayer assigned!")
		return
	
	# 1. ADD TILES (Close the entrance)
	for tile_pos in door_tiles:
		tilemap_layer.set_cell(tile_pos, source_id, wall_atlas_coords)
	
	# 2. REMOVE TILES (Clear a path or delete decorative tiles)
	for tile_pos in remove_tiles:
		# Setting source_id to -1 deletes the tile
		tilemap_layer.set_cell(tile_pos, -1)
		
	print("Arena modified: Door closed and path cleared.")
