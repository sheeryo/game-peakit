extends Area2D

@export var dialogue_resourse: DialogueResource
@export var dialogue_start: String = "start"

var _started := false


func action() -> void:
	if _started or GameState.in_dialogue or GameState.has_met("manya"):
		return
	_started = true
	DialogueManager.show_dialogue_balloon(dialogue_resourse, dialogue_start)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		action()
