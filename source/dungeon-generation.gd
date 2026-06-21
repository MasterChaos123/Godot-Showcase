class_name Dungeons
extends Node2D

# Regions and Grid
var queue : Queue
var caves : Caves
var forest : Forest
var tile_map : TileMapLayer
var astar_grid : AStarGrid2D
var regions : Dictionary = {}

# Player
var player : CharacterBody2D

# Managers
var enemy_manager : EnemyManager

# Noise and Generation
var rng = RandomNumberGenerator.new()
var noise_texture : NoiseTexture2D = NoiseTexture2D.new()

# Tilesets and Tiles
const TILE_ATLAS_ID = 0
const ENT_EXIT_ID = 1

var room_floor_tile : Vector2i = Vector2i(2, 0)
var entrance_exit_tile : Vector2i = Vector2i(0, 0)
var wall_tile : Vector2i = Vector2i(3, 0)

var landmarks : Dictionary = {
	'shop': {'weight': 2, 'unique': true, 'min_size': Vector2i(5, 5), 'max_size': Vector2i(5, 5)},
	'enchanting_room': {'weight': 1, 'unique': true, 'min_size': Vector2i(3, 3), 'max_size': Vector2i(3, 3)},
	'base_room': {'weight': 5, 'unique': false, 'min_size': Vector2i(4, 4), 'max_size': Vector2i(5, 5)}
}

var current_region : int = 0
var floor_number : int = 1

func initialize(caves_ref, forest_ref, player_ref, enemy_manager_ref, tile_map_ref, queue_ref) -> void:
	queue = queue_ref
	caves = caves_ref
	forest = forest_ref
	player = player_ref
	tile_map = tile_map_ref
	enemy_manager = enemy_manager_ref
	
	noise_texture.noise = FastNoiseLite.new()
	astar_grid = AStarGrid2D.new()
	astar_grid.cell_size = tile_map.tile_set.tile_size
	rng.randomize()
	
	regions = {
		0: caves,
		1: forest
	}
	print(regions)

# Generate a new floor when exiting a floor
func new_floor() -> void:
	# When the region is complete (number of floors exceeds 5), progress to the next region
	if floor_number > 5:
		current_region += 1
		floor_number = 1
	
	var region : Node2D = regions[current_region]
	print("Region: " + str(region.name) + " on floor " + str(floor_number))
	
	# Clear data from previous floor
	queue.clear_queue()
	tile_map.clear()
	region.clear_data()
	
	# Create the new floor
	make_grid(region)
	choose_landmarks(4, region)
	generate_landmarks(region)
	generate_entrance_exit(region)
	set_player(region)
	
	# Generate floor from the region
	region.fill_remaining_grid(noise_texture)
	
	# After all the tiles have been filled we can set the region and update the grid.
	astar_grid.region = tile_map.get_used_rect()
	astar_grid.update()
	
	generate_walls(region)
	
	# Clear enemies from previous floor and spawn new ones
	enemy_manager.clear_enemies()
	enemy_manager.choose_enemies(region, 1)
	enemy_manager.spawn_enemies(region)
	
	queue.make_queue()
	
	floor_number += 1
	
# Make the actual grid to manipulate for each floor.
func make_grid(region) -> void:
	var floor_size = region.floor["floor_size"]
	for x in range(floor_size.x):
		for y in range(floor_size.y):
			#region.floor["room_grid"][Vector2i(x, y)] = null
			region.floor["grid"][Vector2i(x, y)] = {"tile" : null, "entity": null}

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
				if !region["floor"]["grid"].has(vector) or region["floor"]["grid"][vector]["tile"] != null:
					invalid = true
					break
			
			# If the location is valid, then we can proceed with placing the tiles of the landmark 
			# and remove them from the grid as they are taken.
			if !invalid:
				for vector in location:
					tile_map.set_cell(vector, TILE_ATLAS_ID, room_floor_tile)
					region["floor"]["rooms"][i]["interior"][vector] = null # <-- Change this to update interior for rooms
					region["floor"]["grid"][vector]["tile"] = "room_floor"
				
				# Generate walls
				var walls : Array = []
				for tile in region["floor"]["rooms"][i]["interior"]:
					var surrounding_tiles : Array = [
						Vector2i(tile.x, tile.y+1),
						Vector2i(tile.x, tile.y-1),
						Vector2i(tile.x-1, tile.y),
						Vector2i(tile.x+1, tile.y),
						Vector2i(tile.x-1, tile.y+1),
						Vector2i(tile.x+1, tile.y+1),
						Vector2i(tile.x-1, tile.y-1),
						Vector2i(tile.x+1, tile.y-1),
					]
					
					for surrounding_tile in surrounding_tiles:
						if tile_map.get_cell_source_id(surrounding_tile) == -1 and region["floor"]["grid"].has(surrounding_tile):
							tile_map.set_cell(surrounding_tile, TILE_ATLAS_ID, wall_tile)
							region["floor"]["grid"][surrounding_tile]["tile"] = "wall"
							walls.append(surrounding_tile)
					
				var door_tile = walls[rng.randi_range(0, walls.size() - 1)]
				if region["floor"]["grid"].has(door_tile) and region["floor"]["grid"][door_tile]["tile"] == "wall":
					tile_map.set_cell(door_tile, TILE_ATLAS_ID, room_floor_tile)
					region["floor"]["grid"][door_tile]["tile"] = "door"
						
				# Generate padding
				var padding : int = 3
				for tile in region["floor"]["grid"]:
					if region["floor"]["grid"][tile]["tile"] == "wall":
						for j in range(1, padding + 1):
							var surrounding_tiles : Array = [
								Vector2i(tile.x, tile.y+j),
								Vector2i(tile.x, tile.y-j),
								Vector2i(tile.x-j, tile.y),
								Vector2i(tile.x+j, tile.y),
								Vector2i(tile.x-j, tile.y+j),
								Vector2i(tile.x+j, tile.y+j),
								Vector2i(tile.x-j, tile.y-j),
								Vector2i(tile.x+j, tile.y-j),
							]
							
							for surrounding_tile in surrounding_tiles:
								if region.floor["grid"].has(surrounding_tile) and tile_map.get_cell_source_id(surrounding_tile) == -1:
									region.floor["grid"][surrounding_tile]["tile"] = "padding"
				break

# Place the entrance and exit within the dungeon.
func generate_entrance_exit(region : Node):
	var available_tiles : Array = region["floor"]["grid"].keys()
	var chosen_tile : Vector2i = Vector2i()
	
	# Entrance
	chosen_tile = available_tiles[rng.randi() % available_tiles.size()]
	
	if region["floor"]["grid"].has(chosen_tile):
		tile_map.set_cell(chosen_tile, ENT_EXIT_ID, entrance_exit_tile)
		region["floor"]["grid"][chosen_tile]["tile"] = "entrance"
		available_tiles.erase(chosen_tile)
		region["floor"]["entrance"] = chosen_tile
		
	# Exit
	chosen_tile = available_tiles[rng.randi() % available_tiles.size()]
	
	if region["floor"]["grid"].has(chosen_tile):
		tile_map.set_cell(chosen_tile, ENT_EXIT_ID, entrance_exit_tile)
		region["floor"]["grid"][chosen_tile]["tile"] = "exit"
		available_tiles.erase(chosen_tile)
		region["floor"]["exit"] = chosen_tile

# Spawn the player on top of the entrance tile.
func set_player(region : Node):
	player.location = region["floor"]["entrance"]
	regions[current_region].floor["grid"][region["floor"]["entrance"]]["entity"] = player
	player.global_position = to_global(tile_map.map_to_local(player.location))
	
	print("Entrance location: " + str(region["floor"]["entrance"]))
	print("Player's current location: " + str(player.location))
	#print("Grid: " + str(regions[current_region].floor["grid"]))

func generate_walls(region : Node) -> void:
	var rooms = region.floor["rooms"]
	
	for tile in region["floor"]["grid"]:
		#print(region["floor"]["grid"][tile])
		if typeof(region["floor"]["grid"][tile]["tile"]) == TYPE_STRING:
			if region["floor"]["grid"].has(tile) and region["floor"]["grid"][tile]["tile"] == "wall":
				astar_grid.set_point_solid(tile)
