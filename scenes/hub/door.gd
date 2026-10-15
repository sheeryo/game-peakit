extends Area2D
## Проход между локациями: из хаба за кулисы и обратно.
## Игрок находит его через ActionableFinder (слой 5 «Actionables»), как маскота.

enum Target { BACKSTAGE, HUB }

@export var target := Target.BACKSTAGE
@export var label := "За кулисы"
@export var prompt := "Enter — пройти"
## Пока Капсула не открыта в финале, выйти из-за кулис нельзя.
@export var closed_in_finale := false

var _player_near := false


func _ready() -> void:
	body_entered.connect(func(body: Node2D) -> void: _set_near(body, true))
	body_exited.connect(func(body: Node2D) -> void: _set_near(body, false))


func action() -> void:
	if _is_closed():
		Sfx.play("wrong")
		return
	Sfx.play("door")
	if target == Target.BACKSTAGE:
		GameState.go_to_backstage()
	else:
		GameState.return_to_hub()


func _is_closed() -> bool:
	return closed_in_finale and GameState.finale_ending != ""


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := Brand.BODY_FONT
	draw_string(font, Vector2(-60, -34), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 11)
	if _player_near and not GameState.in_dialogue:
		var text := "Сначала открой ракету!" if _is_closed() else prompt
		draw_string(font, Vector2(-100, -48), text, HORIZONTAL_ALIGNMENT_CENTER, 200, 10)


func _set_near(body: Node2D, near: bool) -> void:
	if body.name == "Player":
		_player_near = near
