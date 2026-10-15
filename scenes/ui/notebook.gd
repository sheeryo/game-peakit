extends CanvasLayer
## Детективный блокнот: печати, улики, сколько осталось до финала.
## Открывается и закрывается по Tab (Esc тоже закрывает). Пока открыт — игра на паузе.

## Разворот и печати — tools/pixel_art/decor.py (art/notebook/).
const NOTEBOOK := preload("res://art/notebook/notebook.png")
const STAMP_PATH := "res://art/notebook/stamp_%s.png"
const STAMP_EMPTY := preload("res://art/notebook/stamp_empty.png")
## Чернила на бумаге
const INK := Color("#3a261c")
const INK_TITLE := Color("#a4561a")
const HINT_COLOR := Color("#9a8a78")

var panel: Control
var stamps_row: GridContainer
var clues_label: RichTextLabel
var footer_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	build_ui()
	panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if panel.visible:
		if event.is_action_pressed("notebook") or event.is_action_pressed("ui_cancel"):
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("notebook") and not GameState.in_dialogue:
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	refresh()
	panel.show()
	Sfx.play("page")
	get_tree().paused = true


func close() -> void:
	panel.hide()
	Sfx.play("page", 0.1)
	get_tree().paused = false


func is_open() -> bool:
	return panel.visible


func refresh() -> void:
	for child in stamps_row.get_children():
		stamps_row.remove_child(child)
		child.queue_free()
	for mascot in GameState.MASCOTS:
		var has := GameState.has_stamp(mascot)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var icon := TextureRect.new()
		icon.texture = load(STAMP_PATH % mascot) if has else STAMP_EMPTY
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		cell.add_child(icon)
		var label := make_label(cell, GameState.MASCOT_INFO[mascot].name, 10, INK if has else HINT_COLOR)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = 52
		stamps_row.add_child(cell)

	var text := ""
	for mascot in GameState.MASCOTS:
		var info: Dictionary = GameState.MASCOT_INFO[mascot]
		if GameState.has_clue(mascot):
			var clue: Dictionary = GameState.CLUES[mascot]
			text += "[b]%s[/b] (%s)\n%s\n" % [clue.title, info.name, clue.text]
		else:
			text += "[color=#%s]??? — помоги: %s, %s[/color]\n" % [
				HINT_COLOR.to_html(false), info.name, info.zone]
	clues_label.text = text.strip_edges()

	var left := GameState.STAMPS_FOR_FINALE - GameState.stamp_count()
	var footer := ""
	if left > 0:
		footer = "До разгадки: ещё %d %s." % [left, plural_stamps(left)]
	else:
		footer = "Печатей хватает! Иди к главной сцене."
	footer += "
Секретные разговоры: %d / %d

Tab — закрыть" % [
		GameState.secret_dialogues.size(), GameState.SECRET_DIALOGUES_TOTAL]
	footer_label.text = footer


func plural_stamps(n: int) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return "печать"
	if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14]:
		return "печати"
	return "печатей"


func build_ui() -> void:
	var root := ColorRect.new()
	root.color = Color(0, 0, 0, 0.5)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = root

	var book := TextureRect.new()
	book.texture = NOTEBOOK
	book.set_anchors_preset(Control.PRESET_CENTER)
	book.offset_left = -NOTEBOOK.get_width() / 2.0
	book.offset_top = -NOTEBOOK.get_height() / 2.0
	book.offset_right = NOTEBOOK.get_width() / 2.0
	book.offset_bottom = NOTEBOOK.get_height() / 2.0
	root.add_child(book)

	# Левая страница: заголовок, печати, сколько до разгадки
	var left := page(book, Rect2(42, 18, 244, 292))
	var title := make_label(left, "Детективный блокнот", 15, INK_TITLE)
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	make_label(left, "Печати", 12, INK).theme_type_variation = &"HeaderLabel"
	stamps_row = GridContainer.new()
	stamps_row.columns = 3
	stamps_row.add_theme_constant_override("h_separation", 22)
	stamps_row.add_theme_constant_override("v_separation", 6)
	stamps_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(stamps_row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	footer_label = make_label(left, "", 11, INK)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Правая страница: улики
	var right := page(book, Rect2(334, 18, 240, 292))
	make_label(right, "Улики", 12, INK).theme_type_variation = &"HeaderLabel"
	clues_label = RichTextLabel.new()
	clues_label.bbcode_enabled = true
	clues_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	clues_label.add_theme_color_override("default_color", INK)
	clues_label.add_theme_font_size_override("normal_font_size", 11)
	clues_label.add_theme_font_size_override("bold_font_size", 11)
	clues_label.add_theme_font_override("bold_font", Brand.HEADER_FONT)
	right.add_child(clues_label)


## Страница блокнота: колонка в прямоугольнике rect (в пикселях разворота).
func page(book: Control, rect: Rect2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = rect.position
	box.size = rect.size
	box.add_theme_constant_override("separation", 6)
	book.add_child(box)
	return box


func make_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
