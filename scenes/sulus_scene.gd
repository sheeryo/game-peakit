extends Area2D

@export_file("*.tscn") var next_scene: String = "res://sulus_minigame/sulus_minigame.tscn" 
var is_player_inside = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		is_player_inside = true

func _on_body_exited(body):
	if body.name == "Player":
		is_player_inside = false

func action():
	if is_player_inside and Input.is_action_just_pressed("enter"):
		get_tree().change_scene_to_file(next_scene)
