extends Control

const MASCOT := "katya"
const TIME_LIMIT := 60.0
const FEEDBACK_TIME := 1.5
const MANNEQUIN_SCALE := 2
const LAYERS_PATH := "res://assets/cosplay/%s.png"
const KATYA := preload("res://assets/character/katya.png")

const SELECTED_COLOR := Brand.SELECTED
const NORMAL_COLOR := Brand.TEXT

const THEMES := {
	"retro": {"name": "Ретро", "order": "Хочу ретро! Как на дискотеке восьмидесятых!"},
	"circus": {"name": "Цирк", "order": "Хочу цирк! Чтобы все улыбались!"},
	"space": {"name": "Космос", "order": "Хочу космос! Как на нашем общем фото!"},
}

const SLOTS := [
	{"id": "head", "name": "Голова", "items": [
		{"name": "Кудрявый парик", "theme": "retro"},
		{"name": "Клоунский колпак", "theme": "circus"},
		{"name": "Картонный шлем", "theme": "space"},
		{"name": "Шляпа детектива", "theme": "detective"},
	]},
	{"id": "costume", "name": "Костюм", "items": [
		{"name": "Яркая куртка", "theme": "retro"},
		{"name": "Костюм в горошек", "theme": "circus"},
		{"name": "Скафандр из картона", "theme": "space"},
		{"name": "Плащ детектива", "theme": "detective"},
	]},
	{"id": "accessory", "name": "Аксессуар", "items": [
		{"name": "Кассетный плеер", "theme": "retro"},
		{"name": "Красный нос", "theme": "circus"},
		{"name": "Ракета-рюкзак", "theme": "space"},
		{"name": "Лупа", "theme": "detective"},
	]},
]

enum State { PLAYING, FEEDBACK, RESULT }

var state := State.PLAYING
var orders: Array = []
var order_index := 0
var choice := [0, 0, 0]
var selected_slot := 0
var time_left := TIME_LIMIT
var feedback_left := 0.0
var mistakes := 0
var won := false

var katya_label: Label
var slot_labels: Array[Label] = []
var timer_bar: ProgressBar
var info_label: Label
var mannequin: Control
var layers := {}


func _ready() -> void:
	layers.mannequin = load(LAYERS_PATH % "mannequin")
	for slot in SLOTS:
		for item in slot.items:
			var key: String = "%s_%s" % [slot.id, item.theme]
			layers[key] = load(LAYERS_PATH % key)
	build_ui()
	orders = THEMES.keys()
	orders.shuffle()
	start_order()


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
			next_order()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	match state:
		State.PLAYING:
			if event.is_action_pressed("up"):
				select_slot((selected_slot + SLOTS.size() - 1) % SLOTS.size())
			elif event.is_action_pressed("down"):
				select_slot((selected_slot + 1) % SLOTS.size())
			elif event.is_action_pressed("left"):
				change_item(-1)
			elif event.is_action_pressed("right"):
				change_item(1)
			elif event.is_action_pressed("enter"):
				submit()
		State.RESULT:
			if event.is_action_pressed("enter"):
				if won:
					GameState.return_to_hub()
				else:
					get_tree().reload_current_scene()
			elif event.is_action_pressed("ui_cancel") and not won:
				get_viewport().set_input_as_handled()
				GameState.return_to_hub()


func start_order() -> void:
	state = State.PLAYING
	var order_theme: Dictionary = THEMES[orders[order_index]]
	katya_label.text = "Катя: %s" % order_theme.order
	info_label.text = "Образ %d из %d" % [
		order_index + 1, orders.size()]
	for i in SLOTS.size():
		choice[i] = randi() % SLOTS[i].items.size()
	select_slot(0)


func select_slot(i: int) -> void:
	if i != selected_slot:
		Sfx.play("ui_move")
	selected_slot = i
	update_slots()


func change_item(step: int) -> void:
	var count: int = SLOTS[selected_slot].items.size()
	choice[selected_slot] = (choice[selected_slot] + step + count) % count
	Sfx.play("swap")
	update_slots()


func current_item(slot: int) -> Dictionary:
	return SLOTS[slot].items[choice[slot]]


func update_slots() -> void:
	for i in SLOTS.size():
		var arrow := "> " if i == selected_slot else "   "
		slot_labels[i].text = "%s%s:  < %s >" % [arrow, SLOTS[i].name, current_item(i).name]
		slot_labels[i].modulate = SELECTED_COLOR if i == selected_slot else NORMAL_COLOR
	mannequin.queue_redraw()


func submit() -> void:
	var theme_id: String = orders[order_index]
	var wrong_slot := -1
	for i in SLOTS.size():
		if current_item(i).theme != theme_id:
			wrong_slot = i
			break
	if wrong_slot == -1:
		state = State.FEEDBACK
		feedback_left = FEEDBACK_TIME
		Sfx.play("correct")
		katya_label.text = "Катя: Да! Это настоящий «%s»! *подмигивает*" % THEMES[theme_id].name
	else:
		mistakes += 1
		Sfx.play("wrong")
		var item := current_item(wrong_slot)
		if item.theme == "detective":
			katya_label.text = "Катя: %s? Это же для нового фестиваля! Мне нужен «%s»." % [
				item.name, THEMES[theme_id].name]
		else:
			katya_label.text = "Катя: Почти! Только %s сюда не подходит." % SLOTS[wrong_slot].name.to_lower()
		select_slot(wrong_slot)


func next_order() -> void:
	order_index += 1
	if order_index >= orders.size():
		finish(true)
	else:
		start_order()


func finish(is_win: bool) -> void:
	state = State.RESULT
	won = is_win
	Sfx.play("win" if won else "lose")
	timer_bar.hide()
	if won:
		GameState.add_stamp(MASCOT)
		var text := "Катя: Шикарное дефиле! Держи печать!\nУлика: %s" % GameState.CLUES[MASCOT].title
		if mistakes == 0:
			text += "\nМастер косплея: все образы с первого раза!"
		katya_label.text = text
		info_label.text = ""
	else:
		katya_label.text = "Катя: Время вышло! Дефиле начинается без нас…"
		info_label.text = ""


func draw_mannequin() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(MANNEQUIN_SCALE * 64, MANNEQUIN_SCALE * 64))
	mannequin.draw_texture_rect(layers.mannequin, rect, false)
	for slot in [1, 2, 0]:
		var key: String = "%s_%s" % [SLOTS[slot].id, current_item(slot).theme]
		mannequin.draw_texture_rect(layers[key], rect, false)


func build_ui() -> void:
	Brand.add_backdrop(self, MASCOT, Brand.GREEN.darkened(0.7))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	katya_label = make_label(box, 13)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)

	var katya := TextureRect.new()
	katya.texture = KATYA
	katya.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	katya.custom_minimum_size = Vector2(128, 128)
	katya.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(katya)

	mannequin = Control.new()
	mannequin.custom_minimum_size = Vector2(MANNEQUIN_SCALE * 64, MANNEQUIN_SCALE * 64)
	mannequin.draw.connect(draw_mannequin)
	row.add_child(mannequin)

	var slots_box := VBoxContainer.new()
	slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_box.custom_minimum_size.x = 250
	slots_box.add_theme_constant_override("separation", 10)
	row.add_child(slots_box)
	for i in SLOTS.size():
		var label := make_label(slots_box, 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_labels.append(label)

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
