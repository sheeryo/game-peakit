extends Area2D

@export var dialogue_resource: DialogueResource
@export var dialogue_start := "start"


func action() -> void:
	if GameState.in_dialogue or dialogue_resource == null:
		return
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)
