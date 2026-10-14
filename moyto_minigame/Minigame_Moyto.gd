extends Control

var current_round = 0
var total_rounds = 5
var best_time = 0.0
var elapsed_time = 0.0
var game_active = false
var round_list = ["catch", "quiz", "timing", "catch", "quiz"]

@onready var score_label = $ScoreLabel
@onready var best_label = $BestLabel
@onready var time_label = $TimeLabel
@onready var round_timer = $RoundTimer
@onready var game_area = $GameArea
@onready var result_screen = $ResultScreen
@onready var result_label = $ResultScreen/ResultLabel
@onready var restart_button = $ResultScreen/RestartButton

func _ready():
	load_best_time()
	update_ui()
	result_screen.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	round_timer.timeout.connect(_on_round_timeout)
	start_game()

func _process(delta):
	if game_active:
		elapsed_time += delta
		update_time_label()

func start_game():
	current_round = 0
	elapsed_time = 0.0
	game_active = true
	update_ui()
	start_round()

func start_round():
	clear_game_area()
	if current_round >= total_rounds:
		end_game()
		return
	var minigame = round_list[current_round]
	match minigame:
		"catch": start_catch()
		"quiz": start_quiz()
		"timing": start_timing()
	round_timer.wait_time = 5.0
	round_timer.start()

func start_catch():
	var catch_button = Button.new()
	catch_button.text = "!"
	catch_button.custom_minimum_size = Vector2(80, 80)
	catch_button.position = Vector2(
		randf_range(50, game_area.size.x - 130),
		randf_range(50, game_area.size.y - 130)
	)
	catch_button.pressed.connect(_on_catch_pressed)
	game_area.add_child(catch_button)

func _on_catch_pressed():
	round_timer.stop()
	complete_round()

func start_quiz():
	var items = [
		{"name": "Шляпа", "emoji": "Ш", "correct": false},
		{"name": "Лупа", "emoji": "Л", "correct": false},
		{"name": "Блокнот", "emoji": "Б", "correct": false},
		{"name": "Ракета", "emoji": "Р", "correct": true}
	]
	items.shuffle()
	var start_x = 100
	var start_y = 100
	var spacing = 150
	for i in range(items.size()):
		var btn = Button.new()
		btn.text = items[i]["emoji"] + "\n" + items[i]["name"]
		btn.custom_minimum_size = Vector2(120, 120)
		btn.position = Vector2(start_x + i * spacing, start_y)
		btn.pressed.connect(_on_quiz_item_pressed.bind(items[i]["correct"]))
		game_area.add_child(btn)

func _on_quiz_item_pressed(is_correct: bool):
	round_timer.stop()
	if is_correct:
		complete_round()
	else:
		clear_game_area()
		show_moyto_support()
		await get_tree().create_timer(1.5).timeout
		start_round()

func start_timing():
	var label = Label.new()
	label.text = "Нажми вовремя (скоро)"
	label.position = Vector2(200, 150)
	game_area.add_child(label)
	await get_tree().create_timer(2.0).timeout
	complete_round()

func _on_round_timeout():
	clear_game_area()
	show_moyto_support()
	await get_tree().create_timer(1.5).timeout
	start_round()

func show_moyto_support():
	var support_label = Label.new()
	support_label.text = "Мойто: «Почти! Давай ещё разок!»"
	support_label.position = Vector2(50, 10)
	game_area.add_child(support_label)

func complete_round():
	current_round += 1
	update_ui()
	start_round()

func update_ui():
	score_label.text = "Пройдено: " + str(current_round) + "/" + str(total_rounds)
	if best_time > 0:
		best_label.text = "Лучшее: " + format_time(best_time)
	else:
		best_label.text = "Лучшее: —"

func update_time_label():
	time_label.text = "Время: " + format_time(elapsed_time)

func format_time(t):
	var minutes = int(t / 60)
	var seconds = int(t) % 60
	return str(minutes) + ":" + str(seconds).pad_zeros(2)

func clear_game_area():
	for child in game_area.get_children():
		child.queue_free()

func end_game():
	game_active = false
	round_timer.stop()
	clear_game_area()
	if best_time == 0 or elapsed_time < best_time:
		best_time = elapsed_time
		save_best_time()
	result_label.text = "Мойто доволен!\nТы справился!\n\nВремя: " + format_time(elapsed_time) + "\nЛучшее: " + format_time(best_time)
	result_screen.visible = true

func _on_restart_pressed():
	result_screen.visible = false
	start_game()

func save_best_time():
	var file = FileAccess.open("user://moyto_best.save", FileAccess.WRITE)
	file.store_var(best_time)

func load_best_time():
	if FileAccess.file_exists("user://moyto_best.save"):
		var file = FileAccess.open("user://moyto_best.save", FileAccess.READ)
		best_time = file.get_var()
