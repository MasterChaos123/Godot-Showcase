class_name EnemyManager
extends Node2D

@export var enemies_node : Node2D

func _process(_delta: float) -> void:
	pass
	
# Choose enemies based on weight to spawn into the dungeon
func choose_enemies(region : Node2D, amount : int) -> void:
	var enemies : Array = region.enemies.keys()
	var weights : Array = []
	
	# Collect weights of all the enemies to manipulate
	for enemy in region.enemies:
		weights.append(region.enemies[enemy]["weight"])
	
	for i in range(amount):
		var chosen = enemies[Dungeon.rng.rand_weighted(weights)]
		var scene = region.enemies[chosen]["scene"]
		var enemy_instance = scene.instantiate()
		#enemy_instance.health = region.enemies[chosen]["health"]
		enemies_node.add_child(enemy_instance)
		region.floor["enemies"]["enemy_" + str(i)] = {"type": chosen, "health": region.enemies[chosen]["health"]}

# After choosing the enemies to spawn, we find a valid location for them to start at
func spawn_enemies(region : Node2D) -> void:
	var location : Vector2i
	
	for enemy in enemies_node.get_children():
		while true:
			var invalid : bool = false
			
			# Check if the location is valid
			location = Vector2i(Dungeon.rng.randi_range(0, region.floor["floor_size"].x - 1), Dungeon.rng.randi_range(0, region.floor["floor_size"].y - 1))
			if !region.floor["grid"].has(location):
				invalid = true
			else:
				if region.floor["grid"][location]["tile"] == "wall" and region.floor["grid"][location]["tile"] == "door":
					invalid = true
					
			# If the location from above was indeed valid then we can create an instance of the enemy and place it while removing the tile
			if !invalid:
				enemy.global_position = to_global(Dungeon.tile_map.map_to_local(location))
				enemy.location = location
				print("Enemy spawn location: " + str(location))
				region.floor["grid"][location]["entity"] = enemy
				#region.floor["grid"].erase(location)
				#print(region.floor["grid"])
				break

# Every floor, enemies are cleared to allow new ones to spawn
func clear_enemies() -> void:
	for child in enemies_node.get_children():
		Dungeon.regions[Dungeon.current_region].floor["grid"][child.location]["entity"] = null
		enemies_node.remove_child(child)

func handle_enemies(turns : int) -> void:
	for enemy in enemies_node.get_children():
		enemy.state_machine.states[enemy.state_machine.current_state].act(turns)
