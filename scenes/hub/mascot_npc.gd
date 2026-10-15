extends Area2D
## Маскот в хабе: зона, спрайт маскота (art/characters/<mascot>.png) и разговор по Enter.
## Используется и для главной сцены (mascot = "stage"), гостей фестиваля
## (mascot = "guest_N", спрайт art/characters/guest_N.png) и предметов за кулисами.
## Игрок находит его через ActionableFinder (слой 5 «Actionables») и вызывает action().

@export var mascot := "manya"
@export var display_name := "Маня"
@export var zone_name := "Арт-маркет"
@export var color := Color.WHITE
## Файл диалога (dialogue/<кто>.gd) и функция в нём, с которой начать разговор.
@export var dialogue_script: Script
@export var dialogue_start := "start"
## Начать разговор сразу при входе в хаб, если ещё не знакомы (Маня у входа).
@export var auto_start := false
## Подсказка, когда игрок рядом.
@export var prompt := "Enter — поговорить"
## Рисовать круг зоны. У гостей и предметов его нет.
@export var show_zone := true

const BODY_RADIUS := 16.0
const ZONE_RADIUS := 80.0
const STAMP_COLOR := Brand.ORANGE
const SPRITE_PATH := "res://art/characters/%s.png"
## «Дыхание» спрайта: период в секундах.
const BOB_PERIOD := 1.2

var _player_near := false
## Спрайт маскота; у главной сцены его нет — её рисует декорация в хабе.
var _sprite: Texture2D
var _time := 0.0
var _zone: Node2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_time = randf() * BOB_PERIOD
	var path := SPRITE_PATH % mascot
	if ResourceLoader.exists(path):
		_sprite = load(path)
	if not show_zone:
		return
	# Круг зоны — на земле, под игроком и декорациями (хаб сортируется по Y)
	_zone = Node2D.new()
	_zone.z_index = -1
	_zone.draw.connect(_draw_zone)
	add_child(_zone)
	if auto_start and not GameState.has_met(mascot):
		action.call_deferred()


func action() -> void:
	Dialogue.start(dialogue_script, dialogue_start)


func _process(delta: float) -> void:
	_time += delta
	# Подсказка «Enter» прячется на время разговора, спрайт «дышит»
	queue_redraw()


func _draw_zone() -> void:
	var zone_color := color
	zone_color.a = 0.15
	_zone.draw_circle(Vector2.ZERO, ZONE_RADIUS, zone_color)


func _draw() -> void:
	var font := Brand.BODY_FONT
	# Название зоны — у нижнего края круга: сверху его закрыли бы декорации
	if show_zone:
		draw_string(Brand.HEADER_FONT, Vector2(-ZONE_RADIUS, ZONE_RADIUS - 6), zone_name,
			HORIZONTAL_ALIGNMENT_CENTER, ZONE_RADIUS * 2, 12)

	# Ноги спрайта — на нижнем краю тела, чтобы сортировка по Y была честной
	var head_y := -BODY_RADIUS
	if _sprite:
		var bob := 1.0 if fmod(_time, BOB_PERIOD) < BOB_PERIOD / 2 else 0.0
		var sprite_size := _sprite.get_size()
		var top_left := Vector2(-floorf(sprite_size.x / 2), BODY_RADIUS - sprite_size.y + bob)
		draw_texture(_sprite, top_left)
		head_y = top_left.y
		draw_string(font, Vector2(-60, BODY_RADIUS + 14), display_name,
			HORIZONTAL_ALIGNMENT_CENTER, 120, 11)

	if GameState.has_stamp(mascot):
		draw_circle(Vector2(BODY_RADIUS, head_y + 4), 5, STAMP_COLOR)

	if _player_near and not GameState.in_dialogue:
		draw_string(font, Vector2(-100, head_y - 4), prompt,
			HORIZONTAL_ALIGNMENT_CENTER, 200, 10)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_near = false
