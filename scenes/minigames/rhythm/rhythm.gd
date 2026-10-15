extends Control
## Ритм-игра Лени «Новая мелодия». Ноты падают по четырём дорожкам (D F J K),
## жми, когда нота на линии. Каждая фраза мелодии кончается ключевой нотой —
## буквой шифра: до = Р, ре = А, ми = К… Над дорожками проявляется «РАКЕТА».
## Трек и карта нот — из tools/music/lenya_song.py (lenya_song.wav, lenya_chart.gd).
## Доиграл до конца с энергией > 0 — печать. Без единого промаха — «Идеальный ритм».

const MASCOT := "lenya"
const Chart := preload("res://scenes/minigames/rhythm/lenya_chart.gd")
const SONG := preload("res://scenes/minigames/rhythm/lenya_song.wav")
const SFX_HIT := preload("res://scenes/minigames/rhythm/sfx_hit.wav")
const SFX_MISS := preload("res://scenes/minigames/rhythm/sfx_miss.wav")
const LENYA := preload("res://art/characters/lenya.png")

const LANE_ACTIONS := ["lane_0", "lane_1", "lane_2", "lane_3"]
const LANE_KEYS := ["D", "F", "J", "K"]
const LANE_COLORS := [Brand.SALMON, Brand.BLUE, Brand.GREEN, Brand.RED]
const KEY_COLOR := Brand.ORANGE

## Геометрия дорожек (в базовом разрешении 640×360)
const LANE_W := 44.0
const HIGHWAY_X := 320.0 - LANE_W * 2
const TOP_Y := 24.0
const HIT_Y := 296.0
## За сколько секунд нота пролетает от верха до линии
const TRAVEL := 1.6

## Окна попадания (секунды) — щедрые: играют все подряд, без обучения
const PERFECT := 0.07
const GOOD := 0.13
const MISS_AFTER := 0.16

## Энергия: при ~65% попаданий песню проходят 9 из 10 (симуляция), при 50% — редко.
const ENERGY_START := 0.7
const ENERGY_PERFECT := 0.05
const ENERGY_GOOD := 0.04
const ENERGY_MISS := -0.08

const LENYA_LINES := [
	[0, "Чувствуешь ритм?"],
	[10, "Да! Вот так!"],
	[20, "Ты слышишь мелодию!"],
	[35, "Лучший концерт!"],
]

enum State { PLAYING, RESULT }

var state := State.PLAYING
var notes: Array = []          # копии нот из карты + "judged", "result"
var next_judge := 0            # первая ещё не оценённая нота (ноты по времени)
var song_time := -1.0
var _clock := 0.0
var _started := false

var energy := ENERGY_START
var score := 0
var combo := 0
var max_combo := 0
var perfect_count := 0
var good_count := 0
var miss_count := 0
var won := false
var letters: Array = []        # по фразам: "" — ещё нет, иначе "hit"/"miss"

var lane_flash := [0.0, 0.0, 0.0, 0.0]
var popups: Array = []         # {text, color, t, lane}
var sparks: Array = []         # {pos, vel, t, color}
var stars: Array = []

var music: AudioStreamPlayer
var sfx_hit: AudioStreamPlayer
var sfx_miss: AudioStreamPlayer
var canvas: Control
var result_label: Label
var hint_label: Label


func _ready() -> void:
	for n in Chart.NOTES:
		var note: Dictionary = n.duplicate()
		note["judged"] = false
		notes.append(note)
	for p in Chart.PHRASES:
		letters.append("")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		stars.append(Vector3(rng.randf_range(0, 640), rng.randf_range(0, 360), rng.randf()))
	build_ui()
	music = make_player(SONG, -3.0, Settings.MUSIC_BUS)
	sfx_hit = make_player(SFX_HIT, -8.0, Settings.SFX_BUS)
	sfx_miss = make_player(SFX_MISS, -6.0, Settings.SFX_BUS)
	music.play()
	_started = true


func make_player(stream: AudioStream, volume: float, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


## Секунда трека. По звуку, если он играет (с поправкой на задержку вывода),
## иначе — по своему таймеру (нет звуковой карты, headless).
func current_song_time(delta: float) -> float:
	_clock += delta
	if music.playing:
		var audio_time := music.get_playback_position() + AudioServer.get_time_since_last_mix() \
			- AudioServer.get_output_latency()
		if audio_time > 0.0:
			_clock = audio_time
	# время не идёт назад, даже если звук «дёрнулся»
	return maxf(song_time, _clock)


func _process(delta: float) -> void:
	if state == State.PLAYING:
		song_time = current_song_time(delta)
		judge_missed()
		if song_time >= Chart.SONG_LENGTH - 0.3 and next_judge >= notes.size():
			finish(true)
	for i in 4:
		lane_flash[i] = maxf(0.0, lane_flash[i] - delta * 5.0)
	for p in popups:
		p.t += delta
	popups = popups.filter(func(p): return p.t < 0.6)
	for s in sparks:
		s.t += delta
		s.pos += s.vel * delta
		s.vel.y += 300.0 * delta
	sparks = sparks.filter(func(s): return s.t < 0.4)
	canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# echo — автоповтор зажатой клавиши, не считаем (BUG-002)
	if event is InputEventKey and event.echo:
		return
	match state:
		State.PLAYING:
			for lane in LANE_ACTIONS.size():
				if event.is_action_pressed(LANE_ACTIONS[lane]):
					press_lane(lane)
					return
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


#region Оценка нот

func press_lane(lane: int) -> void:
	lane_flash[lane] = 1.0
	# ближайшая неоценённая нота этой дорожки в окне попадания
	var best := -1
	var best_diff := GOOD
	for i in range(next_judge, notes.size()):
		var note: Dictionary = notes[i]
		if note.time - song_time > GOOD:
			break
		if note.judged or note.lane != lane:
			continue
		var diff := absf(note.time - song_time)
		if diff <= best_diff:
			best = i
			best_diff = diff
	# Нажатие мимо нот не наказываем: дети жмут всё подряд
	if best == -1:
		return
	judge(best, "perfect" if best_diff <= PERFECT else "good")


func judge_missed() -> void:
	for i in range(next_judge, notes.size()):
		var note: Dictionary = notes[i]
		if state != State.PLAYING or note.time + MISS_AFTER > song_time:
			break
		if not note.judged:
			judge(i, "miss")
	while next_judge < notes.size() and notes[next_judge].judged:
		next_judge += 1


func judge(i: int, result: String) -> void:
	var note: Dictionary = notes[i]
	note.judged = true
	note["result"] = result
	match result:
		"perfect":
			perfect_count += 1
			combo += 1
			score += 100 + combo * 2
			energy += ENERGY_PERFECT
			popup("Отлично!", KEY_COLOR, note.lane)
		"good":
			good_count += 1
			combo += 1
			score += 60 + combo
			energy += ENERGY_GOOD
			popup("Хорошо", Color(0.6, 0.9, 1.0), note.lane)
		"miss":
			miss_count += 1
			combo = 0
			energy += ENERGY_MISS
			popup("Мимо", Color(1.0, 0.4, 0.4), note.lane)
	max_combo = maxi(max_combo, combo)
	energy = clampf(energy, 0.0, 1.0)
	if result == "miss":
		sfx_miss.play()
	else:
		sfx_hit.play()
		burst(note.lane, KEY_COLOR if note.key else LANE_COLORS[note.lane])
	if note.key and note.phrase >= 0:
		letters[note.phrase] = "miss" if result == "miss" else "hit"
	if energy <= 0.0:
		finish(false)
	while next_judge < notes.size() and notes[next_judge].judged:
		next_judge += 1


func popup(text: String, color: Color, lane: int) -> void:
	popups.append({"text": text, "color": color, "t": 0.0, "lane": lane})


func burst(lane: int, color: Color) -> void:
	var center := Vector2(lane_x(lane) + LANE_W / 2, HIT_Y)
	for k in 8:
		var angle := -PI * (0.15 + 0.7 * k / 7.0)
		sparks.append({"pos": center, "vel": Vector2.from_angle(angle) * randf_range(60, 140),
			"t": 0.0, "color": color})


func accuracy() -> float:
	var judged := perfect_count + good_count + miss_count
	return 1.0 if judged == 0 else (perfect_count + good_count * 0.6) / judged


func rank() -> String:
	var acc := accuracy()
	return "S" if acc >= 0.95 else "A" if acc >= 0.85 else "B" if acc >= 0.7 else "C"

#endregion

#region Конец

func finish(is_win: bool) -> void:
	if state == State.RESULT:
		return
	state = State.RESULT
	won = is_win
	music.stop()
	Sfx.play("win" if won else "lose")
	var lines: Array[String] = []
	if won:
		GameState.add_stamp(MASCOT)
		for p in letters.size():
			if letters[p] == "":
				letters[p] = "hit"
		lines.append("Леня: Ноты складываются в буквы… Р-А-К-Е-Т-А. Чувствуешь?")
		lines.append("Ранг %s    Точность %d%%    Лучшее комбо %d" % [rank(), roundi(accuracy() * 100), max_combo])
		lines.append("Отлично: %d    Хорошо: %d    Мимо: %d" % [perfect_count, good_count, miss_count])
		if miss_count == 0:
			lines.append("Идеальный ритм!")
		lines.append("Печать Лени! Улика: %s" % GameState.CLUES[MASCOT].title)
		lines.append("\nEnter — вернуться на фестиваль")
	else:
		lines.append("Сбился с ритма…")
		lines.append("Леня: Ничего. Главное — чувствовать. Попробуем ещё раз?")
		lines.append("\nEnter — ещё раз    Esc — на фестиваль")
	result_label.text = "\n".join(lines)
	result_label.show()
	hint_label.text = ""

#endregion

#region Отрисовка

func lane_x(lane: int) -> float:
	return HIGHWAY_X + lane * LANE_W


func note_y(t: float) -> float:
	return HIT_Y - (t - song_time) / TRAVEL * (HIT_Y - TOP_Y)


func draw_scene() -> void:
	var font := Brand.BODY_FONT
	var beat := fmod(maxf(song_time, 0.0), 60.0 / Chart.BPM) / (60.0 / Chart.BPM)
	var on_beat := beat < 0.15 and state == State.PLAYING

	# звёзды «Космоса» мерцают в такт
	for s in stars:
		var a := 0.3 + 0.5 * absf(sin(s.z * 10.0 + song_time * 2.0))
		canvas.draw_rect(Rect2(s.x, s.y, 1, 1), Color(1, 1, 1, a))

	# Леня на сцене слева
	var stage := Rect2(36, 250, 140, 16)
	canvas.draw_rect(stage, Color(0.45, 0.3, 0.2))
	canvas.draw_rect(Rect2(36, 266, 140, 6), Color(0.3, 0.2, 0.14))
	var bounce := -3.0 if on_beat else 0.0
	canvas.draw_texture_rect(LENYA, Rect2(42, 122 + bounce, 128, 128), false)
	canvas.draw_string(font, Vector2(16, 296), lenya_line(), HORIZONTAL_ALIGNMENT_CENTER, 180, 10)

	# дорожки
	for lane in 4:
		var x := lane_x(lane)
		var base: Color = LANE_COLORS[lane]
		canvas.draw_rect(Rect2(x, TOP_Y, LANE_W, HIT_Y - TOP_Y + 20), Color(base, 0.08 + lane_flash[lane] * 0.25))
		canvas.draw_line(Vector2(x, TOP_Y), Vector2(x, HIT_Y + 20), Color(1, 1, 1, 0.12))
		# приёмник на линии
		var receptor := Rect2(x + 4, HIT_Y - 7, LANE_W - 8, 14)
		canvas.draw_rect(receptor, Color(base, 0.35 + lane_flash[lane] * 0.6), false, 2.0)
		canvas.draw_string(font, Vector2(x, HIT_Y + 34), LANE_KEYS[lane], HORIZONTAL_ALIGNMENT_CENTER,
			LANE_W, 14, Color(base, 0.9))
	canvas.draw_line(Vector2(HIGHWAY_X - 6, HIT_Y), Vector2(HIGHWAY_X + LANE_W * 4 + 6, HIT_Y),
		Color(1, 1, 1, 0.9 if on_beat else 0.5), 2.0)

	# ноты
	for i in range(next_judge, notes.size()):
		var note: Dictionary = notes[i]
		var y := note_y(note.time)
		if y < TOP_Y - 16:
			break
		if note.judged:
			continue
		var x := lane_x(note.lane)
		var color: Color = KEY_COLOR if note.key else LANE_COLORS[note.lane]
		# ключевая нота (буква шифра) — крупнее и с белой рамкой
		var rect := Rect2(x + 3, y - 9, LANE_W - 6, 18) if note.key else Rect2(x + 5, y - 6, LANE_W - 10, 12)
		canvas.draw_rect(rect, color)
		canvas.draw_rect(rect, Color.WHITE if note.key else Color(0.1, 0.07, 0.1), false, 1.0)
		canvas.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 2)), Color(1, 1, 1, 0.5))

	for s in sparks:
		canvas.draw_rect(Rect2(s.pos, Vector2(2, 2)), Color(s.color, 1.0 - s.t / 0.4))
	for p in popups:
		var x := lane_x(p.lane) - 20
		canvas.draw_string(font, Vector2(x, HIT_Y - 20 - p.t * 30), p.text, HORIZONTAL_ALIGNMENT_CENTER,
			LANE_W + 40, 12, Color(p.color, 1.0 - p.t / 0.6))

	draw_panel(font)
	draw_countdown(font)


func draw_panel(font: Font) -> void:
	var x := 440.0
	canvas.draw_string(font, Vector2(x, 40), "Шифр в нотах:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(1, 1, 1, 0.8))
	for p in letters.size():
		var cell := Rect2(x + p * 28, 50, 24, 28)
		canvas.draw_rect(cell, Color(1, 1, 1, 0.08))
		canvas.draw_rect(cell, Color(1, 1, 1, 0.35), false, 1.0)
		if letters[p] != "":
			var color := KEY_COLOR if letters[p] == "hit" else Color(0.6, 0.6, 0.65)
			canvas.draw_string(font, Vector2(cell.position.x, cell.position.y + 21), Chart.PHRASES[p].letter,
				HORIZONTAL_ALIGNMENT_CENTER, 24, 18, color)
			canvas.draw_string(font, Vector2(cell.position.x - 2, cell.position.y + 40), Chart.PHRASES[p].note,
				HORIZONTAL_ALIGNMENT_CENTER, 28, 8, Color(1, 1, 1, 0.6))

	canvas.draw_string(font, Vector2(x, 130), "Очки: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	canvas.draw_string(font, Vector2(x, 152), "Комбо: %d" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		KEY_COLOR if combo >= 10 else Color.WHITE)
	canvas.draw_string(font, Vector2(x, 174), "Точность: %d%%" % roundi(accuracy() * 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))

	canvas.draw_string(font, Vector2(x, 206), "Энергия", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	var bar := Rect2(x, 212, 160, 10)
	canvas.draw_rect(bar, Color(1, 1, 1, 0.1))
	var fill_color := Color(0.4, 0.9, 0.5) if energy > 0.3 else Color(1.0, 0.4, 0.35)
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * energy, bar.size.y)), fill_color)
	canvas.draw_rect(bar, Color(1, 1, 1, 0.4), false, 1.0)

	# прогресс песни
	var progress := clampf(song_time / Chart.SONG_LENGTH, 0.0, 1.0)
	canvas.draw_rect(Rect2(x, 240, 160, 3), Color(1, 1, 1, 0.1))
	canvas.draw_rect(Rect2(x, 240, 160 * progress, 3), Color(0.55, 0.7, 0.95))


func draw_countdown(font: Font) -> void:
	if state != State.PLAYING:
		return
	var first: float = Chart.PHRASES[0].start
	var beat_len := 60.0 / Chart.BPM
	var text := ""
	if song_time < first - beat_len * 4:
		text = "Новая мелодия Лени"
	elif song_time < first:
		var left := ceili((first - song_time) / beat_len)
		text = "Играй!" if left <= 1 else str(left - 1)
	if text != "":
		canvas.draw_string(font, Vector2(HIGHWAY_X - 40, 150), text, HORIZONTAL_ALIGNMENT_CENTER,
			LANE_W * 4 + 80, 20, KEY_COLOR)
		canvas.draw_string(font, Vector2(HIGHWAY_X - 60, 180), "Жми D F J K, когда нота на линии",
			HORIZONTAL_ALIGNMENT_CENTER, LANE_W * 4 + 120, 10, Color(1, 1, 1, 0.8))


func lenya_line() -> String:
	var line: String = LENYA_LINES[0][1]
	for entry in LENYA_LINES:
		if combo >= entry[0]:
			line = entry[1]
	if energy < 0.25 and state == State.PLAYING:
		line = "Слушай бас!"
	return line

#endregion


func build_ui() -> void:
	var background := ColorRect.new()
	background.color = Brand.BLUE.darkened(0.78)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(draw_scene)
	add_child(canvas)

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(170, 336)
	hint_label.size = Vector2(300, 20)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 11)
	add_child(hint_label)

	result_label = Label.new()
	result_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 13)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Brand.BROWN_DEEP, 0.92)
	result_label.add_theme_stylebox_override("normal", style)
	result_label.hide()
	add_child(result_label)
