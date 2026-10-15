extends Node
## Autoload `Dialogue`: запускает разговоры. Своя замена плагину Dialogue Manager.
##
## Разговор — обычная функция в файле dialogue/<кто>.gd, например:
##   func start(d: DialogueBox) -> void:
##       await d.say("Маня", "Ой, гость!")
##       if await d.ask("Маня", "Поможешь?", ["Помогу!", "Потом"]) == 0:
##           GameState.request_minigame("manya")
## Условия — обычные if по GameState. Запуск: Dialogue.start(скрипт, "start").

signal started
signal ended

const BOX_SCENE := preload("res://scenes/ui/dialogue_box.tscn")

## Идёт ли разговор
var active := false

var _box: DialogueBox
## Файл идущего разговора (dialogue/<кто>.gd) — по нему Music включает тему маскота.
var _script_path := ""
var _entry := ""


func _ready() -> void:
	_box = BOX_SCENE.instantiate()
	add_child(_box)


## Запустить разговор: функцию `entry` из скрипта диалога. Второй разговор
## поверх первого не открывается.
func start(dialogue_script: Script, entry: String = "start") -> void:
	if active:
		return
	active = true
	_script_path = dialogue_script.resource_path
	_entry = entry
	started.emit()
	var lines: Object = dialogue_script.new()
	await lines.call(entry, _box)
	_box.hide()
	active = false
	ended.emit()


## Файл идущего разговора, например "res://dialogue/manya.gd"; пусто — разговора нет.
func current_script_path() -> String:
	return _script_path if active else ""


## Функция идущего разговора ("start", "guest_3"…) — по ней окно ищет портрет гостя.
func current_entry() -> String:
	return _entry if active else ""


## Оборвать разговор (рестарт, выход на титульный экран). Окно пересоздаётся:
## недоговорённый диалог ждал сигнала старого окна и вместе с ним исчезает.
func cancel() -> void:
	if not active:
		return
	_box.queue_free()
	_box = BOX_SCENE.instantiate()
	add_child(_box)
	active = false
	ended.emit()
