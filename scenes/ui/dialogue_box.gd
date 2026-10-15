class_name DialogueBox
extends CanvasLayer
## Окно диалога — обычная сцена (scenes/ui/dialogue_box.tscn): панель внизу экрана,
## имя говорящего, текст с эффектом печатной машинки и варианты ответа.
##
## Им управляют файлы диалогов (dialogue/*.gd) через две функции:
##   await d.say("Маня", "Привет!")                    — показать реплику, ждать Enter
##   var i := await d.ask("Маня", "Поможешь?", ["Да", "Потом"])  — вопрос с выбором, вернёт номер
## Enter во время печати показывает реплику целиком, второй Enter листает дальше.

signal advanced
signal chosen(index: int)

## Скорость печати, символов в секунду
const CHARS_PER_SECOND := 50.0
const SELECTED_COLOR := Brand.SELECTED
const NORMAL_COLOR := Brand.TEXT
## Портреты (как в Undertale): art/portraits/<кто>.png, 48×40, в окне ×2.
## Собираются из спрайтов tools/pixel_art/portraits.py.
const PORTRAIT_PATH := "res://art/portraits/%s.png"
## Пока печатается реплика, портрет покачивается — «говорит».
const TALK_BOB_PERIOD := 0.24

@onready var name_label: Label = %NameLabel
@onready var text_label: Label = %TextLabel
@onready var choices_box: VBoxContainer = %Choices
@onready var hint_label: Label = %HintLabel
@onready var portrait: TextureRect = %Portrait

var _typing := false
var _shown_chars := 0.0
## Варианты ответа, пока игрок выбирает; пусто — выбора нет
var _options: Array = []
var _selected := 0
## После печати сразу показать варианты (для ask)
var _options_after_typing: Array = []
var _speaker := ""
## Сколько букв уже «озвучено» писком голоса
var _voiced := 0


func _ready() -> void:
	hide()


## Реплика: печатается, потом ждёт Enter. speaker = "" — слова рассказчика.
func say(speaker: String, text: String) -> void:
	_show_line(speaker, text)
	await advanced


## Вопрос: печатается, потом показывает варианты. Возвращает номер выбранного.
func ask(speaker: String, text: String, options: Array) -> int:
	_options_after_typing = options
	_show_line(speaker, text)
	return await chosen


func _show_line(speaker: String, text: String) -> void:
	show()
	_speaker = speaker
	_voiced = 0
	portrait.texture = _portrait_for(speaker)
	portrait.visible = portrait.texture != null
	name_label.text = speaker
	name_label.visible = speaker != ""
	text_label.text = text
	text_label.visible_characters = 0
	_shown_chars = 0.0
	_typing = true
	_clear_options()
	hint_label.text = ""


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown_chars += CHARS_PER_SECOND * delta
	var bob := fmod(_shown_chars / CHARS_PER_SECOND, TALK_BOB_PERIOD) < TALK_BOB_PERIOD / 2
	portrait.position.y = -2.0 if bob else 0.0
	text_label.visible_characters = int(_shown_chars)
	_voice_letters(int(_shown_chars))
	if _shown_chars >= text_label.text.length():
		_finish_typing()


## Голос как в Undertale: писк на каждую вторую букву (пробелы и знаки молчат).
func _voice_letters(shown: int) -> void:
	shown = mini(shown, text_label.text.length())
	while _voiced < shown:
		var ch := text_label.text[_voiced]
		_voiced += 1
		if _voiced % 2 == 0 and ch.strip_edges() != "" and not ch in ".,!?…—-«»*":
			Sfx.voice(_speaker)
			return


## Портрет говорящего: маскот — по имени; гость или косплеер — по разговору
## (функция guest_N в dialogue/guests.gd). Рассказчик — без портрета.
func _portrait_for(speaker: String) -> Texture2D:
	if speaker == "":
		return null
	var id := Dialogue.current_entry()
	for mascot in GameState.MASCOT_INFO:
		if GameState.MASCOT_INFO[mascot].name == speaker:
			id = mascot
	var path := PORTRAIT_PATH % id
	return load(path) if ResourceLoader.exists(path) else null


func _finish_typing() -> void:
	_typing = false
	portrait.position.y = 0.0
	text_label.visible_characters = -1
	if _options_after_typing.is_empty():
		hint_label.text = "Enter — дальше"
	else:
		_show_options(_options_after_typing)
		_options_after_typing = []


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.echo:
		return
	if not _options.is_empty():
		if event.is_action_pressed("up"):
			_select((_selected + _options.size() - 1) % _options.size())
		elif event.is_action_pressed("down"):
			_select((_selected + 1) % _options.size())
		elif event.is_action_pressed("enter"):
			var picked := _selected
			Sfx.play("ui_select")
			_clear_options()
			chosen.emit(picked)
	elif event.is_action_pressed("enter"):
		if _typing:
			_finish_typing()
		else:
			advanced.emit()
	# Пока окно открыто, ввод больше никому не достаётся
	get_viewport().set_input_as_handled()


func _show_options(options: Array) -> void:
	_options = options
	for option in options:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		choices_box.add_child(label)
	_select(0)
	hint_label.text = "↑↓ — выбрать    Enter — ответить"


func _select(i: int) -> void:
	if i != _selected and not _options.is_empty():
		Sfx.play("ui_move")
	_selected = i
	for j in choices_box.get_child_count():
		var label: Label = choices_box.get_child(j)
		label.text = ("> " if j == i else "   ") + str(_options[j])
		label.modulate = SELECTED_COLOR if j == i else NORMAL_COLOR


func _clear_options() -> void:
	_options = []
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
