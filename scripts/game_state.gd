extends Node

signal stamp_added(mascot: String)
signal run_reset

const TITLE_SCENE := "res://scenes/main_menu.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"
const HUB_SCENE := "res://scenes/world.tscn"
const STAMPS_FOR_FINALE := 3
const RESTART_HOLD_TIME := 1.0
const MISTAKE_PENALTY := 15.0
const SECRET_DIALOGUES_TOTAL := 5

const MASCOTS := ["manya", "lenya", "katya", "moyto", "sulus"]
const MASCOT_INFO := {
	"manya": {"name": "Маня", "zone": "Арт-маркет"},
	"lenya": {"name": "Леня", "zone": "Музыкальная сцена"},
	"katya": {"name": "Катя", "zone": "Косплей-дефиле"},
	"moyto": {"name": "Мойто", "zone": "Конкурсы"},
	"sulus": {"name": "Сулус", "zone": "Лекторий"},
}
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
const MINIGAMES := {
	"manya": "res://manya_minigame/manya_minigame.tscn",
	"lenya": "res://ritm/main.tscn",
	"katya": "res://katya_minigame/katya_minigame.tscn",
	"moyto": "res://moyto_minigame/Minigame_Moyto.tscn",
	"sulus": "res://sulus_minigame/sulus_minigame.tscn",
}

var stamps: Array[String] = []
var clues: Array[String] = []
var met: Array[String] = []
var secret_dialogues: Array[String] = []
var mistakes := 0
var run_time := 0.0
var run_active := false
var hub_return_position = null
var in_dialogue := false
var pending_minigame := ""
var finale_ending := ""
var _restart_held := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DialogueManager.dialogue_started.connect(func(_r): in_dialogue = true)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if "--smoke-test" in OS.get_cmdline_user_args():
		add_child(preload("res://scripts/smoke_test.gd").new())
	reset_run()
	run_active = false

func _process(delta: float) -> void:
	if run_active:
		run_time += delta
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
	cancel_dialogue()
	finale_ending = ""
	mistakes = 0
	run_time = 0.0
	run_active = true
	hub_return_position = null
	run_reset.emit()

func cancel_dialogue() -> void:
	for balloon in get_tree().get_nodes_in_group("dialogue_balloon"):
		balloon.queue_free()
	in_dialogue = false

func go_to_title() -> void:
	reset_run()
	run_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)

func restart() -> void:
	reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE)

func add_stamp(stamp_name: String) -> void:
	var mascot := stamp_name.to_lower()
	if mascot not in MASCOTS or mascot in stamps:
		return
	stamps.append(mascot)
	if mascot not in clues:
		clues.append(mascot)
	stamp_added.emit(mascot)

func has_stamp(mascot: String) -> bool:
	return mascot in stamps

func stamp_count() -> int:
	return stamps.size()

func can_open_finale() -> bool:
	return stamps.size() >= STAMPS_FOR_FINALE

func has_clue(mascot: String) -> bool:
	return mascot in clues

func clues_answering(question: String) -> int:
	var count := 0
	for mascot in clues:
		if question in CLUES[mascot].answers:
			count += 1
	return count

func mark_met(mascot: String) -> void:
	if mascot not in met:
		met.append(mascot)

func has_met(mascot: String) -> bool:
	return mascot in met

func has_secret(id: String) -> bool:
	return id in secret_dialogues

func add_secret_dialogue(id: String) -> void:
	if id not in secret_dialogues:
		secret_dialogues.append(id)

func secrets_required() -> int:
	return SECRET_DIALOGUES_TOTAL if MINIGAMES.has("sulus") else SECRET_DIALOGUES_TOTAL - 1

func finish_run(ending: String) -> void:
	run_active = false
	finale_ending = ending

func add_mistake() -> void:
	mistakes += 1

func score_time() -> float:
	return run_time + mistakes * MISTAKE_PENALTY

func has_minigame(mascot: String) -> bool:
	return MINIGAMES.has(mascot)

func request_minigame(mascot: String) -> void:
	pending_minigame = mascot

func request_title() -> void:
	pending_minigame = "title"

func start_minigame(mascot: String) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as Node2D
	hub_return_position = player.global_position if player else Vector2.ZERO
	get_tree().change_scene_to_file(MINIGAMES[mascot])

func return_to_hub() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	in_dialogue = false
	if pending_minigame == "":
		return
	var next := pending_minigame
	pending_minigame = ""
	if next == "title":
		go_to_title.call_deferred()
	else:
		start_minigame.call_deferred(next)
