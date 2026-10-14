extends Node2D

# Тут твоя карта нот: время (в секундах) и полоска
const chart = [
	{"time": 4.0000, "lane": 0, "key": false, "phrase": 0},
	{"time": 4.5000, "lane": 1, "key": false, "phrase": 0},
	{"time": 5.0000, "lane": 2, "key": false, "phrase": 0},
	{"time": 5.5000, "lane": 1, "key": false, "phrase": 0},
	{"time": 6.0000, "lane": 2, "key": false, "phrase": 0},
	{"time": 6.5000, "lane": 1, "key": false, "phrase": 0},
	{"time": 7.0000, "lane": 0, "key": true, "phrase": 0},
	{"time": 8.0000, "lane": 1, "key": false, "phrase": 1},
	{"time": 8.5000, "lane": 2, "key": false, "phrase": 1},
	{"time": 9.0000, "lane": 1, "key": false, "phrase": 1},
	{"time": 9.5000, "lane": 0, "key": false, "phrase": 1},
	{"time": 10.0000, "lane": 1, "key": false, "phrase": 1},
	{"time": 10.2500, "lane": 2, "key": false, "phrase": 1},
	{"time": 10.5000, "lane": 3, "key": false, "phrase": 1},
	{"time": 11.0000, "lane": 2, "key": true, "phrase": 1},
	{"time": 12.0000, "lane": 0, "key": false, "phrase": 2},
	{"time": 12.2500, "lane": 1, "key": false, "phrase": 2},
	{"time": 12.5000, "lane": 2, "key": false, "phrase": 2},
	{"time": 13.0000, "lane": 1, "key": false, "phrase": 2},
	{"time": 13.2500, "lane": 0, "key": false, "phrase": 2},
	{"time": 13.5000, "lane": 1, "key": false, "phrase": 2},
	{"time": 14.0000, "lane": 0, "key": false, "phrase": 2},
	{"time": 14.2500, "lane": 1, "key": false, "phrase": 2},
	{"time": 14.5000, "lane": 0, "key": false, "phrase": 2},
	{"time": 14.7500, "lane": 1, "key": false, "phrase": 2},
	{"time": 15.0000, "lane": 0, "key": true, "phrase": 2},
	{"time": 16.0000, "lane": 3, "key": false, "phrase": 3},
	{"time": 16.2500, "lane": 2, "key": false, "phrase": 3},
	{"time": 16.5000, "lane": 1, "key": false, "phrase": 3},
	{"time": 16.7500, "lane": 0, "key": false, "phrase": 3},
	{"time": 17.0000, "lane": 1, "key": false, "phrase": 3},
	{"time": 17.5000, "lane": 3, "key": false, "phrase": 3},
	{"time": 18.0000, "lane": 2, "key": false, "phrase": 3},
	{"time": 18.2500, "lane": 1, "key": false, "phrase": 3},
	{"time": 18.5000, "lane": 2, "key": false, "phrase": 3},
	{"time": 18.7500, "lane": 3, "key": false, "phrase": 3},
	{"time": 19.0000, "lane": 0, "key": true, "phrase": 3},
	{"time": 20.0000, "lane": 2, "key": false, "phrase": 4},
	{"time": 20.2500, "lane": 3, "key": false, "phrase": 4},
	{"time": 20.5000, "lane": 1, "key": false, "phrase": 4},
	{"time": 20.7500, "lane": 2, "key": false, "phrase": 4},
	{"time": 21.0000, "lane": 3, "key": false, "phrase": 4},
	{"time": 21.2500, "lane": 2, "key": false, "phrase": 4},
	{"time": 21.5000, "lane": 1, "key": false, "phrase": 4},
	{"time": 22.0000, "lane": 0, "key": false, "phrase": 4},
	{"time": 22.2500, "lane": 2, "key": false, "phrase": 4},
	{"time": 22.5000, "lane": 3, "key": false, "phrase": 4},
	{"time": 22.7500, "lane": 2, "key": false, "phrase": 4},
	{"time": 23.0000, "lane": 1, "key": true, "phrase": 4},
	{"time": 24.0000, "lane": 0, "key": false, "phrase": 5},
	{"time": 24.2500, "lane": 1, "key": false, "phrase": 5},
	{"time": 24.5000, "lane": 2, "key": false, "phrase": 5},
	{"time": 24.7500, "lane": 3, "key": false, "phrase": 5},
	{"time": 25.0000, "lane": 2, "key": false, "phrase": 5},
	{"time": 25.2500, "lane": 1, "key": false, "phrase": 5},
	{"time": 25.5000, "lane": 0, "key": false, "phrase": 5},
	{"time": 25.7500, "lane": 2, "key": false, "phrase": 5},
	{"time": 26.0000, "lane": 1, "key": false, "phrase": 5},
	{"time": 26.2500, "lane": 3, "key": false, "phrase": 5},
	{"time": 26.5000, "lane": 1, "key": false, "phrase": 5},
	{"time": 26.7500, "lane": 2, "key": false, "phrase": 5},
	{"time": 27.0000, "lane": 3, "key": true, "phrase": 5},
	{"time": 28.0000, "lane": 3, "key": false, "phrase": -1},
	{"time": 28.0000, "lane": 0, "key": false, "phrase": -1},
]

var hitzone_scene = preload("res://ritm/hit_zone.tscn")
var hitzones = []   # сюда сохраним ссылки на 4 полоски
var score = 0
var combo = 0
var max_combo = 0
const POINTS_PERFECT = 100
const POINTS_GOOD = 50
var note_scene = preload("res://ritm/Note.tscn")
var Hp = 10
var game_ended = false # Флаг, чтобы победа срабатывала только 1 раз

# Ноды для звуков
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var miss_sound: AudioStreamPlayer = $MissSound

func _ready():
	for i in range(4):
		var hz = hitzone_scene.instantiate()
		hz.lane = i
		hz.position.x = 440 + i * 100 - 40
		hz.position.y = 600 - 60
		$Hitzones.add_child(hz)
		hitzones.append(hz)

	# Запускаем музыку
	$AudioStreamPlayer.play()
	
	# Спавним все ноты из карты
	$HpBar.size.x = 120 * Hp
	for n in chart:
		var note = note_scene.instantiate()
		note.hit_time = n.time
		note.lane = n.lane
		note.song = $AudioStreamPlayer
		$Lanes.add_child(note)
	update_ui()

func _process(delta):
	if game_ended:
		return

	# Обработка падения нот мимо
	for note in $Lanes.get_children():
		if note.position.y > 700:
			note.queue_free()
			print("Пропустил")
			Health(-1)
			combo = 0
			
			if miss_sound and miss_sound.stream:
				miss_sound.play()
				
			update_ui()

	# Проверка на победу: музыка не играет и в узле $Lanes больше не осталось нот
	if not $AudioStreamPlayer.playing and $Lanes.get_child_count() == 0:
		win_game()

func win_game():
	game_ended = true
	GameState.complete_minigame("ritm")
	GameState.add_stamp("lenya")
	print("Победа! Возврат на карту мира.")
	# Путь к вашей сцене world.tscn (проверьте, совпадает ли папка)
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _input(event):
	if game_ended:
		return
		
	if event is InputEventKey and event.pressed:
		var lane = -1
		if event.keycode == KEY_D: lane = 0
		if event.keycode == KEY_F: lane = 1
		if event.keycode == KEY_J: lane = 2
		if event.keycode == KEY_K: lane = 3
		if lane >= 0:
			check_hit(lane)

func check_hit(lane):
	var now = $AudioStreamPlayer.get_playback_position()
	var best_note = null
	var best_diff = 999.0
	if lane < hitzones.size():
		hitzones[lane].flash()
		
	for note in $Lanes.get_children():
		if note.lane == lane:
			var diff = abs(note.hit_time - now)
			if diff < best_diff:
				best_diff = diff
				best_note = note

	if best_note and best_diff < 0.15:
		best_note.queue_free()
		print("Хорошо", best_diff)
		Health(1)
		
		if hit_sound and hit_sound.stream:
			hit_sound.play()
			
		var points = 0
		if best_diff < 0.05:
			points = POINTS_PERFECT
		else:
			points = POINTS_GOOD
		
		combo += 1
		if combo > max_combo:
			max_combo = combo
		score += points
		update_ui()
	else:
		combo = 0
		print("Мимо")
		Health(-1)
		
		if miss_sound and miss_sound.stream:
			miss_sound.play()
			
		update_ui()

func Health(dmg):
	if game_ended:
		return
	Hp = Hp + dmg
	$HpBar.size.x = 120 * Hp
	if Hp < 1:
		game_ended = true
		print("You lose")
		get_tree().change_scene_to_file("res://scenes/lenya_game_over.tscn")
	
func update_ui():
	if has_node("CanvasLayer/score"):
		$CanvasLayer/score.text = "Очки: " + str(score)
	if has_node("CanvasLayer/combo"):
		$CanvasLayer/combo.text = "x" + str(combo) if combo > 1 else ""
