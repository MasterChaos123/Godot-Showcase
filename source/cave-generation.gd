class_name Dungeon
extends Node2D

@export var caves : Caves
@export var forest : Forest
@export var tile_map : TileMapLayer
@export var player : CharacterBody2D
@export var enemy_manager : EnemyManager
@export var noise_texture : NoiseTexture2D

var regions : Dictionary = {}

# Tilesets
const TILE_ATLAS_ID = 0
const ENT_EXIT_ID = 1

var room_floor_tile : Vector2i = Vector2i(2, 0)
var floor_tile: Vector2i = Vector2i(1, 0)
var water_tile: Vector2i = Vector2i(0, 0)
var entrance_exit_tile : Vector2i = Vector2i(0, 0)

var rng = RandomNumberGenerator.new()

var landmarks : Dictionary = {
	'shop': {'weight': 2, 'unique': true, 'min_size': Vector2i(5, 5), 'max_size': Vector2i(5, 5)},
	'enchanting_room': {'weight': 1, 'unique': true, 'min_size': Vector2i(3, 3), 'max_size': Vector2i(3, 3)},
	'base_room': {'weight': 5, 'unique': false, 'min_size': Vector2i(4, 4), 'max_size': Vector2i(5, 5)}
}

var current_region : int = 0
var floor_number : int = 1

func _ready() -> void:
	rng.randomize()
	
	regions = {
		0: caves,
		1: forest
	}
	print(regions)
	new_floor()

func new_floor() -> void:
	# When the region is complete (number of floors exceeds 5), progress to the next region
	if floor_number > 5:
		current_region += 1
		floor_number = 1
	
	var region : Node2D = regions[current_region]
	print("Region: " + str(region.name) + " on floor " + str(floor_number))
	
	make_grid(region)
	choose_landmarks(5, region)
	generate_landmarks(region)
	generate_entrance_exit(region)
	set_player(region)
	
	# Generate floor from the region
	region.fill_remaining_grid(noise_texture, rng)
	
	# Clean enemies from previous floor and spawn new ones
	for child in get_parent().find_child("Enemies").get_children():
		get_parent().find_child("Enemies").remove_child(child)
	enemy_manager.choose_enemies(region, 5, rng)
	enemy_manager.spawn_enemies(region, rng, tile_map)
	
	floor_number += 1
	
# Make the actual grid to manipulate for each floor.
func make_grid(region) -> void:
	var floor_size = region.floor["floor_size"]
	for x in range(floor_size.x):
		for y in range(floor_size.y):
			region.floor["grid"][Vector2i(x, y)] = null
			region.floor["enemy_grid"][Vector2i(x, y)] = null

# Get random landmarks to generate on the floor. This generation is done based on weights.
func choose_landmarks(amount : int, region : Node):
	var rooms : Array = landmarks.keys()
	var weights : Array = []
	
	# Collect weights of all the landmarks to manipulate
	for landmark in landmarks:
		weights.append(landmarks[landmark]['weight'])
	
	for i in range(amount):
		# Choose a room and generate a size for it
		var chosen = rooms[rng.rand_weighted(weights)]
		var size = Vector2i(randi_range(landmarks[chosen]['min_size'].x, landmarks[chosen]['max_size'].x), randi_range(landmarks[chosen]['min_size'].y, landmarks[chosen]['max_size'].y))
		region.floor["rooms"]["room_" + str(i)] = {"type": chosen, "interior": {}, "size": size}
		
		# Zero out the weight of rooms that are unique as they should only appear once on a floor
		if landmarks[chosen]['unique']:
			weights[rooms.find(chosen)] = 0

# With the chosen landmarks, find a location in the grid to place them without causing overlaps.
func generate_landmarks(region : Node) -> void:
	var rooms = region.floor["rooms"]
	
	# Create actual areas for the landmarks to manipulate them
	for i in rooms:
		var area : Array[Vector2i]
		for x in rooms[i]["size"].x:
			for y in rooms[i]["size"].y:
				area.append(Vector2i(x, y))
		
		while true:
			var invalid : bool = false
			var location : Dictionary = {}
			var offset : Vector2i = Vector2i(rng.randi_range(0, (region.floor["floor_size"].x - 1 - abs(area[0].x - area[-1].x))), rng.randi_range(0, (region.floor["floor_size"].y - 1 - abs(area[0].y - area[-1].y))))
			
			for x in area.size():
				location[area[x]+offset] = null
				
			# Check if all tiles of the landmark are in valid places, otherwise we must relocate them
			for vector in location:
				if !region["floor"]["grid"].has(vector):
					invalid = true
					break
				if region["floor"]["padding"].has(vector):
					#print("Padding is here. Moving room: " + str(chosen_rooms[i]["name"]))
					invalid = true
					break
			
			# If the location is valid, then we can proceed with placing the tiles of the landmark 
			# and remove them from the grid as they are taken.
			if !invalid:
				for vector in location:
					tile_map.set_cell(vector, TILE_ATLAS_ID, room_floor_tile)
					region["floor"]["rooms"][i]["interior"][vector] = true # <-- Change this to update interior for rooms
					region["floor"]["grid"].erase(vector)
					
				# Generate padding
				var vectors = region["floor"]["rooms"][i]["interior"].keys()
				var start_top = vectors[0]-Vector2i(0, 3)
				var start_left = vectors[0]-Vector2i(3, 0)
				var end_bottom = vectors[-1]+Vector2i(0, 3)
				var end_right = vectors[-1]+Vector2i(3, 0)
				
				#print(vectors)
				#print("Top: " + str(start_top) + " Left: " + str(start_left) + " Bottom: " + str(end_bottom) + " Right: " + str(end_right))
				
				# For top and bottom
				for _i in range(rooms[i]["size"].x):
					region["floor"]["padding"][start_top+Vector2i(_i, 0)] = null
					region["floor"]["padding"][end_bottom-Vector2i(_i, 0)] = null
				
				for _j in range(rooms[i]["size"].y):
					region["floor"]["padding"][start_left+Vector2i(0, _j)] = null
					region["floor"]["padding"][end_right-Vector2i(0, _j)] = null
				break

# Place the entrance and exit within the dungeon.
func generate_entrance_exit(region : Node):
	var available_tiles : Array = region["floor"]["grid"].keys()
	var chosen_tile : Vector2i = Vector2i()
	
	# Entrance
	chosen_tile = available_tiles[rng.randi() % available_tiles.size()]
	
	if region["floor"]["grid"].has(chosen_tile):
		tile_map.set_cell(chosen_tile, ENT_EXIT_ID, entrance_exit_tile)
		region["floor"]["grid"].erase(chosen_tile)
		available_tiles.erase(chosen_tile)
		region["floor"]["entrance"] = chosen_tile
		
	# Exit
	chosen_tile = available_tiles[rng.randi() % available_tiles.size()]
	
	if region["floor"]["grid"].has(chosen_tile):
		tile_map.set_cell(chosen_tile, ENT_EXIT_ID, entrance_exit_tile)
		region["floor"]["grid"].erase(chosen_tile)
		available_tiles.erase(chosen_tile)
		region["floor"]["exit"] = chosen_tile

# Spawn the player on top of the entrance tile.
func set_player(region : Node):
	player.global_position = to_global(tile_map.map_to_local(region["floor"]["entrance"]))
