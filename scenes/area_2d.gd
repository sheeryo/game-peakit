extends Area2D

@export var dialogue_resourse: DialogueResource
@export var dialogue_start: String = "start"
var has_triggered: bool = false

func action() -> void:
	DialogueManager.show_example_dialogue_balloon(dialogue_resourse, dialogue_start)
	
func _on_body_entered(body: Node2D) -> void:
	if has_triggered: return
	if body.is_in_group("player") or body.name == "Player":
		has_triggered = true
		action()
