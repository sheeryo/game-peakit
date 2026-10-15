extends Node
## Состояние текущего забега: печати, улики, секретные диалоги, таймер.
## Autoload `GameState`. Сбрасывается через reset_run().

signal stamp_added(mascot: String)
signal run_reset

const TITLE_SCENE := "res://scenes/ui/title.tscn"
## Заставка-завязка между титульным экраном и хабом.
const INTRO_SCENE := "res://scenes/ui/intro.tscn"
const HUB_SCENE := "res://scenes/world.tscn"
const FINALE_SCENE := "res://scenes/finale/finale.tscn"
## Кат-сцена концовки: открыли ракету за кулисами → кадры → итоги финала.
const ENDING_SCENE := "res://scenes/ui/ending.tscn"
const BACKSTAGE_SCENE := "res://scenes/backstage/backstage.tscn"
const STAMPS_FOR_FINALE := 3
const RESTART_HOLD_TIME := 1.0
const MISTAKE_PENALTY := 15.0
## Посетитель ушёл: столько секунд без ввода — и обратно на титульный экран.
const IDLE_RESET_TIME := 60.0
const IDLE_WARNING_TIME := 50.0

## Маскоты в порядке отображения в блокноте.
const MASCOTS := ["manya", "lenya", "katya", "moyto", "sulus"]

const MASCOT_INFO := {
	"manya": {"name": "Маня", "zone": "Арт-маркет"},
	"lenya": {"name": "Леня", "zone": "Музыкальная сцена"},
	"katya": {"name": "Катя", "zone": "Косплей-дефиле"},
	"moyto": {"name": "Мойто", "zone": "Конкурсы"},
	"sulus": {"name": "Сулус", "zone": "Лекторий"},
}

## Сколько всего секретных диалогов (см. docs/GAME.md).
const SECRET_DIALOGUES_TOTAL := 5

## Улики: на какой вопрос финала отвечают (where / who / why). См. docs/GAME.md.
const CLUES := {
	"manya": {"title": "Эскиз «схема праздника»", "answers": ["where"],
		"text": "Карта фестиваля. Ракета за сценой обведена кружком, подпись «для С.»"},
	"lenya": {"title": "Партитура с шифром", "answers": ["where"],
		"text": "Ноты складываются в буквы: Р-А-К-Е-Т-А."},
	"katya": {"title": "Фото с репетиции дефиле", "answers": ["where", "who"],
		"text": "На заднем плане кто-то в картонном шлеме, с рогами и в фартуке, несёт сундучок за сцену."},
	"moyto": {"title": "Записка-загадка", "answers": ["who"],
		"text": "«Что главное для детектива?» Почерк крупный, с кляксой."},
	"sulus": {"title": "Страница лекции", "answers": ["who", "why"],
		"text": "«Как придумать хорошую загадку: 1) спрячь предмет на виду; 2) оставь подсказки у друзей…» Тот же почерк с кляксой."},
}

## Мини-игры по маскотам. Кого нет в списке — у того мини-игра ещё не готова.
const MINIGAMES := {
	"manya": "res://scenes/minigames/art/sketch_puzzle.tscn",
	"lenya": "res://scenes/minigames/rhythm/rhythm.tscn",
	"katya": "res://scenes/minigames/cosplay/cosplay.tscn",
	"moyto": "res://scenes/minigames/quiz/quiz.tscn",
	"sulus": "res://scenes/minigames/logic/seating.tscn",
}

var stamps: Array[String] = []
## Собранные улики. Обычно приходят вместе с печатью; страницу лекции Сулус
## может отдать в финале сам, если его зона не готова (см. docs/GAME.md).
var clues: Array[String] = []
## С кем игрок уже поговорил в этом забеге.
var met: Array[String] = []
var secret_dialogues: Array[String] = []
var mistakes := 0
var run_time := 0.0
var run_active := false

## Где стоял игрок в хабе перед уходом в мини-игру.
var hub_return_position = null

## Идёт диалог — игрок не ходит.
var in_dialogue := false
## Мини-игра, которую попросили запустить из диалога; стартует, когда диалог закроется.
var pending_minigame := ""

## Концовка, разгаданная на главной сцене: "festival" / "full" / "perfect".
## Пока не пусто, игрок за кулисами открывает ракету, потом — итоги в финале.
var finale_ending := ""
## Разгадан ли ЗАЧЕМ (для подсказки Сулуса про секреты в «Полном расследовании»).
var finale_why := false

var _restart_held := 0.0
var _idle_time := 0.0
var _idle_warning: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Dialogue.started.connect(_on_dialogue_started)
	Dialogue.ended.connect(_on_dialogue_ended)
	_create_idle_warning()
	if "--smoke-test" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/smoke_test.gd").new())
	reset_run()
	# Пока не нажали «Начать» на титульном экране, таймер не идёт
	run_active = false


func _process(delta: float) -> void:
	if run_active:
		run_time += delta

	_update_idle(delta)

	if Input.is_action_pressed("restart"):
		_restart_held += delta
		if _restart_held >= RESTART_HOLD_TIME:
			_restart_held = 0.0
			restart()
	else:
		_restart_held = 0.0


func reset_run() -> void:
	stamps.clear()
	clues.clear()
	met.clear()
	secret_dialogues.clear()
	in_dialogue = false
	pending_minigame = ""
	# Недоговорённый разговор закрываем (рестарт, автосброс)
	Dialogue.cancel()
	finale_ending = ""
	finale_why = false
	mistakes = 0
	run_time = 0.0
	run_active = true
	_idle_time = 0.0
	hub_return_position = null
	run_reset.emit()


func _input(event: InputEvent) -> void:
	# Любое нажатие или движение мыши — посетитель на месте
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton 			or (event is InputEventMouseMotion and event.relative.length() > 2.0):
		_idle_time = 0.0


func _update_idle(delta: float) -> void:
	var on_title := get_tree().current_scene != null 			and get_tree().current_scene.scene_file_path == TITLE_SCENE
	if on_title:
		_idle_time = 0.0
	else:
		_idle_time += delta
	_idle_warning.visible = _idle_time >= IDLE_WARNING_TIME
	if _idle_warning.visible:
		_idle_warning.text = "Ты ещё здесь? Нажми любую клавишу.
Через %d с игра начнётся заново." % ceili(IDLE_RESET_TIME - _idle_time)
	if _idle_time >= IDLE_RESET_TIME:
		go_to_title()


func _create_idle_warning() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_idle_warning = Label.new()
	_idle_warning.set_anchors_preset(Control.PRESET_CENTER)
	_idle_warning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_idle_warning.grow_vertical = Control.GROW_DIRECTION_BOTH
	_idle_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle_warning.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Brand.BROWN_DEEP
	style.border_color = Brand.ORANGE
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	_idle_warning.add_theme_stylebox_override("normal", style)
	_idle_warning.hide()
	layer.add_child(_idle_warning)


## На титульный экран: забег сбрасывается, таймер стоит до «Начать».
func go_to_title() -> void:
	reset_run()
	run_active = false
	_idle_time = 0.0
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


## Полный рестарт забега с возвратом в хаб.
func restart() -> void:
	reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE)


func add_stamp(mascot: String) -> void:
	if mascot in stamps:
		return
	stamps.append(mascot)
	give_clue(mascot)
	stamp_added.emit(mascot)


func has_stamp(mascot: String) -> bool:
	return mascot in stamps


func stamp_count() -> int:
	return stamps.size()


func can_open_finale() -> bool:
	return stamps.size() >= STAMPS_FOR_FINALE


func give_clue(mascot: String) -> void:
	if not mascot in clues:
		clues.append(mascot)


func has_clue(mascot: String) -> bool:
	return mascot in clues


## Сколько собранных улик отвечает на вопрос: "where", "who" или "why".
func clues_answering(question: String) -> int:
	var count := 0
	for mascot in clues:
		if question in CLUES[mascot].answers:
			count += 1
	return count


func mark_met(mascot: String) -> void:
	if not mascot in met:
		met.append(mascot)


func has_met(mascot: String) -> bool:
	return mascot in met


func has_secret(id: String) -> bool:
	return id in secret_dialogues


func add_secret_dialogue(id: String) -> void:
	if not id in secret_dialogues:
		secret_dialogues.append(id)


## Сколько секретных диалогов нужно для «Идеального детектива».
## Без зоны Сулуса страницу лекции до финала не получить, а значит
## и секрет Мойто про почерк недоступен.
func secrets_required() -> int:
	return SECRET_DIALOGUES_TOTAL if has_minigame("sulus") else SECRET_DIALOGUES_TOTAL - 1


## Забег окончен (концовка) — таймер больше не идёт.
func finish_run() -> void:
	run_active = false


func add_mistake() -> void:
	mistakes += 1


## Время для лидерборда: реальное + штраф за ошибки в финале.
func score_time() -> float:
	return run_time + mistakes * MISTAKE_PENALTY


func has_minigame(mascot: String) -> bool:
	return MINIGAMES.has(mascot)


## Вызывается из диалога: `do GameState.request_minigame("lenya")`.
func request_minigame(mascot: String) -> void:
	pending_minigame = mascot


## Вызывается из диалога главной сцены: `do GameState.request_finale()`.
func request_finale() -> void:
	pending_minigame = "finale"


## Вызывается из диалога ракеты за кулисами, когда Капсула открыта:
## после диалога — экран итогов финала.
func request_ending() -> void:
	pending_minigame = "ending"


## Проход за кулисы из хаба: игрок вернётся на то же место.
func go_to_backstage() -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as Node2D
	go_to_minigame(BACKSTAGE_SCENE, player.global_position if player else Vector2.ZERO)


func start_minigame(mascot: String) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as Node2D
	var player_position: Vector2 = player.global_position if player else Vector2.ZERO
	var scene_path: String = FINALE_SCENE if mascot == "finale" else MINIGAMES[mascot]
	go_to_minigame(scene_path, player_position)


func _on_dialogue_started() -> void:
	in_dialogue = true


func _on_dialogue_ended() -> void:
	in_dialogue = false
	if pending_minigame != "":
		var mascot := pending_minigame
		pending_minigame = ""
		if mascot == "ending":
			get_tree().change_scene_to_file.call_deferred(ENDING_SCENE)
		else:
			start_minigame.call_deferred(mascot)


func go_to_minigame(scene_path: String, player_position: Vector2) -> void:
	hub_return_position = player_position
	get_tree().change_scene_to_file(scene_path)


func return_to_hub() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)
