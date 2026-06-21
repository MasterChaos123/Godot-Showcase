class_name EnemyManager
extends Node2D

@export var enemies_node : Node2D

func choose_enemies(region : Node2D, amount : int, rng : RandomNumberGenerator) -> void:
	var enemies : Array = region.enemies.keys()
	var weights : Array = []
	
	# Collect weights of all the enemies to manipulate
	for enemy in region.enemies:
		weights.append(region.enemies[enemy]["weight"])
		
	print("Weight of all enemies: " + str(weights))
	
	for i in range(amount):
		# Choose a room and generate a size for it
		var chosen = enemies[rng.rand_weighted(weights)]
		region.floor["enemies"]["enemy_" + str(i)] = {"type": chosen, "health": region.enemies[chosen]["health"]}
		
	print("Enemies: " + str(region.floor["enemies"]))

func spawn_enemies(region : Node2D, rng : RandomNumberGenerator, tile_map : TileMapLayer) -> void:
	var enemies = region.floor["enemies"]
	var location : Vector2i
	
	for enemy in enemies:
		var scene = region.enemies[enemies[enemy]["type"]]["scene"]
		#print(str(enemy) + str(enemies[enemy]["type"]))
		#print("Enemy scene: " + str(region.enemies[enemies[enemy]["type"]]["scene"]))
		while true:
			var invalid : bool = false
			
			# Check if the location is valid
			location = Vector2i(rng.randi_range(0, region.floor["floor_size"].x - 1), rng.randi_range(0, region.floor["floor_size"].y - 1))
			if !region.floor["enemy_grid"].has(location):
				invalid = true
			
			# If the location from above was indeed valid then we can create an instance of the enemy and place it while removing the tile
			if !invalid:
				var enemy_instance = scene.instantiate()
				enemy_instance.global_position = to_global(tile_map.map_to_local(location))
				print("Enemy location: " + str(tile_map.local_to_map(enemy_instance.global_position)))
				region.floor["enemy_grid"].erase(location)
				enemies_node.call_deferred("add_child", enemy_instance)
				break
