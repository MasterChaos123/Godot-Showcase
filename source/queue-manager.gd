class_name Queue
extends Node2D

@export var player : CharacterBody2D
@export var enemies : Node2D
@export var enemy_manager : EnemyManager

var queue : Array = []
var combat_queues : Dictionary = {}
var combat_queue : Array = []

var turn : Node2D = null
var turn_combat : Node2D = null

func make_queue() -> void:
	queue.append(player)
	player.playerFinishedMoving.connect(_on_player_finished_moving)
	for enemy in enemies.get_children():
		queue.append(enemy)
		enemy.enemyActed.connect(_on_enemy_acted)
		enemy.area_2d.body_entered.connect(_on_enemy_body_entered.bind(enemy))
	print("Queue: " + str(queue))
		
	turn = queue[0]
	turn.canAct = true

func clear_queue() -> void:
	queue.clear()

func assign_actions(moves : int, current_entity) -> void:
	for entity in queue:
		if entity != current_entity:
			entity.moves = moves
	for entity in queue:
		print(str(entity.name) + "'s number of moves: " + str(entity.moves))
		
	for entity in queue:
		if entity.is_in_group("Enemies"):
			entity.state_machine.states[entity.state_machine.current_state].act(entity.moves)
	
func update_queue() -> void:
	queue[0].moves -= 1
	queue[0].canAct = false
	var prev_entity = queue.pop_front()
	turn = queue[0]
	turn.canAct = true
	queue.push_back(prev_entity)
	print(str(turn.name + str("'s ") + "turn to act."))
	print("Updated queue: " + str(queue))
	
func _on_player_finished_moving() -> void:
	var assign : bool = true
	print("Player finished moving.")
	
	for entity in queue:
		if entity.moves != 0 and entity != player:
			assign = false
			break
	
	if assign == true:
		assign_actions(player.moves, player)
		
	update_queue()

func _on_enemy_acted(enemy) -> void:
	print("Enemy finished acting.")
	update_queue()

func sort_by_speed(a, b) -> bool:
	if a.stats.speed > b.stats.speed:
		return true
	return false
	
func _on_enemy_body_entered(body, enemy) -> void:
	if body.is_in_group("Players"):
		player.state_machine.change_state("Combat")
	if player.combat_queue == null and enemy.combat_queue == null:
		print("Creating a new combat queue.")
		combat_queues["queue_" + str(combat_queues.size() + 1)] = []
		combat_queues["queue_1"].append(enemy)
		combat_queues["queue_1"].append(player)
		combat_queues["queue_1"].sort_custom(sort_by_speed)
	print(combat_queues)
		#print("Played found. Stop all movement.")
		#combat_queue.append(player)
	#print("Combat queue: " + str(combat_queue))
	#combat_queue.sort_custom(sort_by_speed)
	#print("Combat queue after sort: " + str(combat_queue))
