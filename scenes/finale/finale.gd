extends Control
## Финал «Я знаю разгадку!»: вопросы ГДЕ / КТО / ЗАЧЕМ, на каждый — ответ
## и улика из блокнота, которая его доказывает. Ошибка без наказания:
## маскот подсказывает, ответ можно переделать (+15 с к времени).
## Сюжет и концовки — docs/GAME.md → «Финал» и «Концовки».

const SELECTED_COLOR := Brand.SELECTED
const NORMAL_COLOR := Brand.TEXT
const MAX_OPTIONS := 5

## Спрайты маскотов (собираются tools/pixel_art/build.py).
const MASCOT_SPRITES := {
	"manya": preload("res://art/characters/manya.png"),
	"lenya": preload("res://art/characters/lenya.png"),
	"katya": preload("res://art/characters/katya.png"),
	"moyto": preload("res://art/characters/moyto.png"),
	"sulus": preload("res://art/characters/sulus.png"),
}

const QUESTION_ORDER := ["where", "who", "why"]

const QUESTIONS := {
	"where": {
		"prompt": "ГДЕ Капсула?",
		"options": ["В картонной ракете за сценой", "Под сценой", "В гардеробе", "На арт-маркете"],
		"correct": 0,
		"wrong": [
			"",
			"Мойто: Под сценой только провода и… ой, мои призы! Капсулы там нет.",
			"Катя: В гардеробе одни костюмы, я всё перерыла! Ищи там, где не ищут.",
			"Маня: Ой, солнышко, у меня только краски и холсты! Посмотри на мой эскиз.",
		],
		"evidence_prompt": "Какая улика доказывает, что Капсула там?",
		"right": "Картонная ракета за музыкальной сценой… Вот где Капсула!",
	},
	"who": {
		"prompt": "КТО спрятал Капсулу?",
		"options": ["Маня", "Леня", "Катя", "Мойто", "Сулус"],
		"correct": 4,
		"wrong": [
			"Маня: Я? Да я весь день с красками! Посмотри, у кого на фото рога и фартук.",
			"Леня: Я?.. Я всё утро разучивал мелодию. Сравни почерк на записках.",
			"Катя: Я?! В моём сундуке были костюмы! А фартук на фото не мой. *подмигивает*",
			"Мойто: Не я! Записку мне подкинули! Клякса на ней не моя, честное слово!",
		],
		"evidence_prompt": "Чем докажешь?",
		"right": "Рога, фартук, клякса… Все смотрят на Сулуса. Он медленно протирает очки.",
	},
	"why": {
		"prompt": "ЗАЧЕМ он это сделал?",
		"options": ["Чтобы фестиваль «Детектив» начался с настоящей загадки",
			"Чтобы забрать реликвии себе", "Чтобы отменить фестиваль"],
		"correct": 0,
		"wrong": [
			"",
			"Сулус: Забрать реликвии? Коллега, они принадлежат всем гостям фестиваля!",
			"Сулус: Отменить фестиваль?! Ни в коем случае! Перечитайте мою лекцию.",
		],
		"evidence_prompt": "Какая улика это объясняет?",
		"right": "«Спрячь предмет на виду, оставь подсказки у друзей…» Это же план всего утра!",
	},
}

const WRONG_EVIDENCE := "Хм… Эта улика тут ни при чём. Загляни в блокнот ещё раз."

## Тексты концовок — в dialogue/backstage.gd (rocket): Капсулу игрок открывает
## сам, за кулисами. Здесь только названия для итогов и лидерборда.
const ENDINGS := {
	"festival": {"title": "Фестиваль удался"},
	"full": {"title": "Полное расследование"},
	"perfect": {"title": "Идеальный детектив"},
}

const TO_BACKSTAGE := "Все бегут за кулисы музыкальной сцены. Открой ракету, детектив!"

enum Phase { MESSAGE, CHOICE, SUMMARY }

var phase := Phase.MESSAGE
var on_continue: Callable
var on_pick: Callable
var choice_count := 0
var selected := 0
var solved := {"where": false, "who": false, "why": false}
var ending_id := ""
var current_question := ""
var evidence_clues: Array = []   # улики, предложенные как доказательство
var speaker := ""                # говорящий маскот подпрыгивает в ряду сверху
var summary_text := ""

var text_label: Label
var option_labels: Array[Label] = []
var hint_label: Label
var mascot_row: Control


func _ready() -> void:
	build_ui()
	# Вернулись из-за кулис: Капсула открыта — сразу итоги
	if GameState.finale_ending != "":
		ending_id = GameState.finale_ending
		show_summary()
		return
	var intro := ["Маскоты собрались у главной сцены. Все смотрят на тебя, детектив!"]
	# Зоны Сулуса нет — страницу лекции он отдаёт сам (только при 4+ печатях,
	# иначе забег на 3 печати получил бы больше, чем положено по таблице концовок)
	if not GameState.has_clue("sulus") and not GameState.has_minigame("sulus") \
			and GameState.stamp_count() >= 4:
		GameState.give_clue("sulus")
		intro.append("Сулус: Ой, это выпало из моих записей… Коллега, не поднимете?")
		intro.append("Новая улика: %s." % GameState.CLUES.sulus.title)
	say_lines(intro, ask.bind("where"))


func _unhandled_input(event: InputEvent) -> void:
	# echo — автоповтор зажатой клавиши, не считаем
	if event is InputEventKey and event.echo:
		return
	match phase:
		Phase.MESSAGE:
			if event.is_action_pressed("enter"):
				on_continue.call()
		Phase.CHOICE:
			if event.is_action_pressed("up"):
				select((selected + choice_count - 1) % choice_count)
			elif event.is_action_pressed("down"):
				select((selected + 1) % choice_count)
			elif event.is_action_pressed("enter"):
				pick(selected)
			elif event is InputEventKey and event.pressed:
				var digit: int = event.physical_keycode - KEY_1
				if digit >= 0 and digit < choice_count:
					pick(digit)
		Phase.SUMMARY:
			if event.is_action_pressed("enter"):
				GameState.go_to_title()


#region Вопросы

func ask(question: String) -> void:
	if question == "who" and GameState.clues_answering("who") < 2:
		say("Пока не хватает улик, чтобы назвать имя.", show_ending)
		return
	if question == "why" and GameState.clues_answering("why") == 0:
		show_ending()
		return
	current_question = question
	var data: Dictionary = QUESTIONS[question]
	show_choice(data.prompt, data.options, _on_answer_picked)


func _on_answer_picked(i: int) -> void:
	var data: Dictionary = QUESTIONS[current_question]
	if i == data.correct:
		ask_evidence()
	else:
		GameState.add_mistake()
		Sfx.play("wrong")
		say(data.wrong[i], ask.bind(current_question))


func ask_evidence() -> void:
	evidence_clues = GameState.MASCOTS.filter(GameState.has_clue)
	var titles: Array = evidence_clues.map(func(m: String) -> String: return GameState.CLUES[m].title)
	show_choice(QUESTIONS[current_question].evidence_prompt, titles, _on_evidence_picked)


func _on_evidence_picked(i: int) -> void:
	if current_question in GameState.CLUES[evidence_clues[i]].answers:
		solved[current_question] = true
		Sfx.play("stamp")
		say(QUESTIONS[current_question].right, next_question.bind(current_question))
	else:
		GameState.add_mistake()
		Sfx.play("wrong")
		say(WRONG_EVIDENCE, ask_evidence)


func next_question(question: String) -> void:
	var i := QUESTION_ORDER.find(question)
	if i + 1 < QUESTION_ORDER.size():
		ask(QUESTION_ORDER[i + 1])
	else:
		show_ending()

#endregion

#region Концовки

func show_ending() -> void:
	GameState.finish_run()
	if solved.who and solved.why and GameState.secret_dialogues.size() >= GameState.secrets_required():
		ending_id = "perfect"
	elif solved.who:
		ending_id = "full"
	else:
		ending_id = "festival"
	GameState.finale_ending = ending_id
	GameState.finale_why = solved.why
	say(TO_BACKSTAGE, get_tree().change_scene_to_file.bind(GameState.BACKSTAGE_SCENE))


func show_summary() -> void:
	hide_options()
	highlight_speaker("")
	summary_text = "Концовка: «%s»\nВремя: %s    Ошибок: %d (+%d с за каждую)\nПечатей: %d / %d    Секретных разговоров: %d / %d" % [
		ENDINGS[ending_id].title, Leaderboard.format_time(GameState.score_time()),
		GameState.mistakes, int(GameState.MISTAKE_PENALTY),
		GameState.stamp_count(), GameState.MASCOTS.size(),
		GameState.secret_dialogues.size(), GameState.secrets_required()]
	# Имён нет: результат, попавший в топ-5, записывается сразу
	var place := -1
	if Leaderboard.qualifies(GameState.stamp_count(), GameState.score_time()):
		place = Leaderboard.add(GameState.stamp_count(), GameState.score_time(),
			ENDINGS[ending_id].title)
	show_records(place)


func show_records(highlight: int) -> void:
	phase = Phase.SUMMARY
	var record := "\nНовый рекорд — %d место!" % (highlight + 1) if highlight >= 0 else ""
	# Итоги и топ-5 — мельче, иначе не влезают в панель
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.text = summary_text + record + "\n\nЛучшие детективы\n" + "\n".join(Leaderboard.format_lines(highlight))
	hint_label.text = "Enter — на титульный экран"

#endregion

#region Показ текста и выбора

func say(text: String, then: Callable) -> void:
	phase = Phase.MESSAGE
	on_continue = then
	hide_options()
	text_label.text = text
	hint_label.text = "Enter — дальше    Tab — блокнот"
	highlight_speaker(text)


func say_lines(lines: Array, then: Callable) -> void:
	if lines.is_empty():
		then.call()
		return
	say(lines[0], say_lines.bind(lines.slice(1), then))


func show_choice(prompt: String, options: Array, picked: Callable) -> void:
	phase = Phase.CHOICE
	on_pick = picked
	choice_count = options.size()
	text_label.text = prompt
	hint_label.text = "↑↓ — выбрать    Enter — ответить    Tab — блокнот"
	highlight_speaker("")
	for i in option_labels.size():
		option_labels[i].visible = i < choice_count
		if i < choice_count:
			option_labels[i].set_meta("text", "%d. %s" % [i + 1, options[i]])
	select(0)


func select(i: int) -> void:
	if i != selected and phase == Phase.CHOICE:
		Sfx.play("ui_move")
	selected = i
	for j in choice_count:
		var arrow := "> " if j == selected else "   "
		option_labels[j].text = arrow + option_labels[j].get_meta("text")
		option_labels[j].modulate = SELECTED_COLOR if j == selected else NORMAL_COLOR


func pick(i: int) -> void:
	phase = Phase.MESSAGE   # чтобы повторный Enter не выбрал дважды
	on_pick.call(i)


func hide_options() -> void:
	for label in option_labels:
		label.hide()


func highlight_speaker(text: String) -> void:
	speaker = ""
	for mascot in GameState.MASCOTS:
		if text.begins_with(GameState.MASCOT_INFO[mascot].name + ":"):
			speaker = mascot
	mascot_row.queue_redraw()

#endregion

#region Интерфейс

func draw_mascots() -> void:
	var font := Brand.BODY_FONT
	var count := GameState.MASCOTS.size()
	var step := mascot_row.size.x / count
	for i in count:
		var mascot: String = GameState.MASCOTS[i]
		var center := Vector2(step * (i + 0.5), 56)
		if mascot == speaker:
			center.y -= 8
		var sprite: Texture2D = MASCOT_SPRITES[mascot]
		# ноги — на линии center.y + 18, как раньше нижний край кружка
		mascot_row.draw_texture(sprite, center + Vector2(-floorf(sprite.get_width() / 2.0),
			18 - sprite.get_height()))
		mascot_row.draw_string(font, center + Vector2(-50, 32), GameState.MASCOT_INFO[mascot].name,
			HORIZONTAL_ALIGNMENT_CENTER, 100, 11)


func build_ui() -> void:
	var background := ColorRect.new()
	background.color = Brand.BROWN_DEEP
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	mascot_row = Control.new()
	mascot_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mascot_row.offset_left = 80
	mascot_row.offset_right = -80
	mascot_row.offset_bottom = 100
	mascot_row.draw.connect(draw_mascots)
	add_child(mascot_row)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 112
	panel.offset_right = -24
	panel.offset_bottom = -12
	var style := StyleBoxFlat.new()
	style.bg_color = Brand.BROWN_DARK
	style.border_color = Brand.ORANGE
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 13)
	box.add_child(text_label)

	for i in MAX_OPTIONS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.hide()
		box.add_child(label)
		option_labels.append(label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.modulate = Color(0.6, 0.6, 0.6)
	hint_label.add_theme_font_size_override("font_size", 10)
	box.add_child(hint_label)

#endregion
