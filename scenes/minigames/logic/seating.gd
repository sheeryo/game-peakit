extends Control
## Мини-игра Сулуса «Рассади слушателей»: логическая головоломка.
## Сулус даёт условия, игрок рассаживает маскотов по стульям и жмёт «Готово».
## Три ряда (два на 3 места, один на 4) за две минуты — печать.
## Управление: ←→ — стул, Enter — взять / поменять местами, Enter на «Готово» — проверить.

const MASCOT := "sulus"
const TIME_LIMIT := 120.0
const FEEDBACK_TIME := 1.5

const CURSOR_COLOR := Brand.ORANGE
const PICKED_COLOR := Brand.RED

## Имена, цвета стульев и спрайты маскотов.
const NAMES := {"manya": "Маня", "lenya": "Леня", "katya": "Катя", "moyto": "Мойто"}
const COLORS := {
	"manya": Brand.SALMON,
	"lenya": Brand.BLUE,
	"katya": Brand.GREEN,
	"moyto": Brand.RED,
}
const SPRITES := {
	"manya": preload("res://art/characters/manya.png"),
	"lenya": preload("res://art/characters/lenya.png"),
	"katya": preload("res://art/characters/katya.png"),
	"moyto": preload("res://art/characters/moyto.png"),
}

## Условие: [тип, маскот, маскот или номер стула (с нуля), текст].
## У каждой задачи ровно одно решение (проверено перебором).
const PUZZLES_SMALL := [
	{"mascots": ["manya", "lenya", "moyto"], "clues": [
		["at", "lenya", 1, "Леня сидит посередине."],
		["right_after", "moyto", "lenya", "Мойто сидит сразу справа от Лени."],
	]},
	{"mascots": ["katya", "moyto", "manya"], "clues": [
		["not_edge", "katya", null, "Катя не сидит с краю."],
		["left_of", "manya", "moyto", "Маня сидит левее Мойто."],
	]},
	{"mascots": ["lenya", "katya", "manya"], "clues": [
		["at", "manya", 2, "Маня сидит с правого края."],
		["not_next_to", "lenya", "manya", "Леня не сидит рядом с Маней."],
	]},
	{"mascots": ["moyto", "lenya", "katya"], "clues": [
		["edge", "katya", null, "Катя сидит с краю."],
		["next_to", "moyto", "katya", "Мойто сидит рядом с Катей."],
		["left_of", "lenya", "katya", "Леня сидит левее Кати."],
	]},
]
const PUZZLES_BIG := [
	{"mascots": ["manya", "lenya", "katya", "moyto"], "clues": [
		["at", "katya", 0, "Катя сидит с левого края."],
		["next_to", "moyto", "katya", "Мойто сидит рядом с Катей."],
		["not_at", "manya", 3, "Маня не сидит с правого края."],
	]},
	{"mascots": ["manya", "lenya", "katya", "moyto"], "clues": [
		["at", "lenya", 1, "Леня сидит вторым слева."],
		["right_after", "manya", "lenya", "Маня сидит сразу справа от Лени."],
		["not_next_to", "katya", "manya", "Катя не сидит рядом с Маней."],
	]},
	{"mascots": ["manya", "lenya", "katya", "moyto"], "clues": [
		["edge", "moyto", null, "Мойто сидит с краю."],
		["edge", "manya", null, "Маня тоже сидит с краю."],
		["not_at", "manya", 0, "Маня не сидит с левого края."],
		["left_of", "katya", "lenya", "Катя сидит левее Лени."],
	]},
]

enum State { PLAYING, FEEDBACK, RESULT }

var state := State.PLAYING
var puzzles: Array = []
var puzzle_index := 0
var seats: Array = []        # маскоты по стульям слева направо
var cursor := 0              # seats.size() — кнопка «Готово»
var picked := -1
var time_left := TIME_LIMIT
var feedback_left := 0.0
var mistakes := 0
var won := false

var sulus_label: Label
var clue_labels: Array[Label] = []
var seat_row: HBoxContainer
var seat_labels: Array[Label] = []
var done_label: Label
var timer_bar: ProgressBar
var info_label: Label


func _ready() -> void:
	build_ui()
	var small := PUZZLES_SMALL.duplicate()
	small.shuffle()
	puzzles = [small[0], small[1], PUZZLES_BIG.pick_random()]
	start_puzzle()


func _process(delta: float) -> void:
	if state == State.RESULT:
		return
	time_left -= delta
	timer_bar.value = time_left
	if time_left <= 0.0:
		finish(false)
		return
	if state == State.FEEDBACK:
		feedback_left -= delta
		if feedback_left <= 0.0:
			next_puzzle()


func _unhandled_input(event: InputEvent) -> void:
	# echo — автоповтор зажатой клавиши, не считаем
	if event is InputEventKey and event.echo:
		return
	match state:
		State.PLAYING:
			if event.is_action_pressed("left"):
				move_cursor(-1)
			elif event.is_action_pressed("right"):
				move_cursor(1)
			elif event.is_action_pressed("enter"):
				press()
		State.RESULT:
			if event.is_action_pressed("enter"):
				if won:
					GameState.return_to_hub()
				else:
					get_tree().reload_current_scene()
			elif event.is_action_pressed("ui_cancel") and not won:
				# Esc здесь — сразу на фестиваль, меню паузы не открываем
				get_viewport().set_input_as_handled()
				GameState.return_to_hub()


func start_puzzle() -> void:
	state = State.PLAYING
	var puzzle: Dictionary = puzzles[puzzle_index]
	seats = puzzle.mascots.duplicate()
	# Не начинаем с уже решённой рассадки
	while broken_clue() == -1:
		seats.shuffle()
	for i in clue_labels.size():
		clue_labels[i].text = "• " + puzzle.clues[i][3] if i < puzzle.clues.size() else ""
	sulus_label.text = "Сулус: Коллега, рассадите слушателей согласно условиям."
	info_label.text = "Ряд %d из %d    ←→ — стул   Enter — взять / поменять   «Готово» — проверить" % [
		puzzle_index + 1, puzzles.size()]
	cursor = 0
	picked = -1
	build_seats()


func move_cursor(step: int) -> void:
	var count := seats.size() + 1
	cursor = (cursor + step + count) % count
	Sfx.play("ui_move")
	update_seats()


func press() -> void:
	if cursor == seats.size():
		check()
		return
	if picked == -1:
		picked = cursor
		Sfx.play("ui_select")
	elif picked != cursor:
		var mascot: String = seats[picked]
		seats[picked] = seats[cursor]
		seats[cursor] = mascot
		picked = -1
		Sfx.play("swap")
	else:
		picked = -1
	update_seats()


func check() -> void:
	picked = -1
	var broken := broken_clue()
	if broken == -1:
		state = State.FEEDBACK
		feedback_left = FEEDBACK_TIME
		Sfx.play("correct")
		sulus_label.text = "Сулус: Безупречная логика, коллега!"
	else:
		mistakes += 1
		Sfx.play("wrong")
		sulus_label.text = "Сулус: Хм, перечитайте условие: «%s»" % \
			puzzles[puzzle_index].clues[broken][3].trim_suffix(".")
	update_seats()


## Номер первого нарушенного условия, -1 — всё верно.
func broken_clue() -> int:
	var clues: Array = puzzles[puzzle_index].clues
	for i in clues.size():
		if not clue_holds(clues[i]):
			return i
	return -1


func clue_holds(clue: Array) -> bool:
	var last := seats.size() - 1
	var a := seats.find(clue[1])
	var b: int = clue[2] if clue[2] is int else seats.find(clue[2])
	match clue[0]:
		"at":
			return a == b
		"not_at":
			return a != b
		"edge":
			return a == 0 or a == last
		"not_edge":
			return a != 0 and a != last
		"next_to":
			return absi(a - b) == 1
		"not_next_to":
			return absi(a - b) != 1
		"right_after":
			return a == b + 1
		"left_of":
			return a < b
	push_error("Неизвестное условие: %s" % clue[0])
	return false


func next_puzzle() -> void:
	puzzle_index += 1
	if puzzle_index >= puzzles.size():
		finish(true)
	else:
		start_puzzle()


func finish(is_win: bool) -> void:
	state = State.RESULT
	won = is_win
	Sfx.play("win" if won else "lose")
	picked = -1
	cursor = -1
	update_seats()
	timer_bar.hide()
	for label in clue_labels:
		label.text = ""
	if won:
		GameState.add_stamp(MASCOT)
		sulus_label.text = "Сулус: Браво, коллега! Вот ваша печать.\nОй, а это страница из моей лекции… Возьмите, мне она совершенно не нужна."
		clue_labels[0].text = "Улика: %s" % GameState.CLUES[MASCOT].title
		info_label.text = "Enter — вернуться на фестиваль"
	else:
		sulus_label.text = "Сулус: Лекция начинается, а слушатели не рассажены… Попробуем ещё раз?"
		info_label.text = "Enter — ещё раз    Esc — вернуться на фестиваль"


func build_seats() -> void:
	for label in seat_labels:
		seat_row.remove_child(label)
		label.queue_free()
	seat_labels.clear()
	for i in seats.size():
		var label := Label.new()
		label.custom_minimum_size = Vector2(76, 92)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.position = Vector2(6, 2)
		label.add_child(portrait)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.1))
		seat_row.add_child(label)
		seat_row.move_child(label, i)
		seat_labels.append(label)
	update_seats()


func update_seats() -> void:
	for i in seat_labels.size():
		var mascot: String = seats[i]
		seat_labels[i].text = NAMES[mascot]
		seat_labels[i].get_node("Portrait").texture = SPRITES[mascot]
		seat_labels[i].add_theme_stylebox_override("normal", make_box(COLORS[mascot], i))
	done_label.add_theme_stylebox_override("normal", make_box(Color(0.3, 0.45, 0.3), seats.size()))


func make_box(color: Color, index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(4)
	if index == picked:
		style.border_color = PICKED_COLOR
		style.set_border_width_all(3)
		style.bg_color = color.lightened(0.3)
	elif index == cursor and state == State.PLAYING:
		style.border_color = CURSOR_COLOR
		style.set_border_width_all(2)
	return style


func build_ui() -> void:
	Brand.add_backdrop(self, MASCOT, Brand.BROWN.darkened(0.45))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	sulus_label = make_label(box, 13)

	for i in 4:
		var label := make_label(box, 12)
		label.modulate = Color(0.9, 0.95, 0.85)
		clue_labels.append(label)

	seat_row = HBoxContainer.new()
	seat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seat_row.add_theme_constant_override("separation", 8)
	box.add_child(seat_row)

	done_label = Label.new()
	done_label.text = "Готово"
	done_label.custom_minimum_size = Vector2(76, 92)
	done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	done_label.add_theme_font_size_override("font_size", 12)
	seat_row.add_child(done_label)

	timer_bar = ProgressBar.new()
	timer_bar.max_value = TIME_LIMIT
	timer_bar.value = TIME_LIMIT
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(200, 6)
	timer_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(timer_bar)

	info_label = make_label(box, 10)


func make_label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
