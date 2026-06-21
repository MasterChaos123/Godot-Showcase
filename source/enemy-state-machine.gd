class_name EnemyStateMachine
extends Node2D

var states : Dictionary = {}
var current_state : String = ""

func _ready() -> void:
	for child in self.get_children():
		if child is State:
			states[child.name] = child
	print("States: " + str(states))
	current_state = "Wander"
	change_state(current_state)

func _process(_delta: float) -> void:
	states[current_state].process(_delta)
	
func change_state(state : String) -> void:
	var next_state = state
	
	if current_state != next_state:
		states[current_state].exit()
		current_state = next_state
		states[current_state].enter()
