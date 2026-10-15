extends Control

const MASCOT := "lenya"
const Chart := preload("res://ritm/lenya_chart.gd")
const SONG := preload("res://assets/music/lenya_song.wav")
const SFX_HIT := preload("res://assets/sfx/sfx_hit.wav")
const SFX_MISS := preload("res://assets/sfx/sfx_miss.wav")
const LENYA := preload("res://assets/character/lenya.png")
const LANE_ACTIONS := ["lane_0", "lane_1", "lane_2", "lane_3"]
const LANE_COLORS := [Brand.SALMON, Brand.BLUE, Brand.GREEN, Brand.RED]
const KEY_COLOR := Brand.ORANGE
const LANE_W := 44.0
const HIGHWAY_X := 320.0 - LANE_W * 2
const TOP_Y := 24.0
const HIT_Y := 296.0
const TRAVEL := 1.6
const PERFECT := 0.07
const GOOD := 0.13
const MISS_AFTER := 0.16
const ENERGY_START := 0.7
const ENERGY_PERFECT := 0.05
const ENERGY_GOOD := 0.04
const ENERGY_MISS := -0.08

enum State { PLAYING, RESULT }
var state := State.PLAYING
var notes: Array = []
var next_judge := 0
var song_time := -1.0
var _clock := 0.0
var energy := ENERGY_START
var score := 0
var combo := 0
var max_combo := 0
var perfect_count := 0
var good_count := 0
var miss_count := 0
var won := false
var letters: Array = []
var lane_flash := [0.0, 0.0, 0.0, 0.0]
var music: AudioStreamPlayer
var sfx_hit: AudioStreamPlayer
var sfx_miss: AudioStreamPlayer
var canvas: Control
var result_label: Label

func _ready() -> void:
	for n in Chart.NOTES:
		var note: Dictionary = n.duplicate()
		note["judged"] = false
		notes.append(note)
	for p in Chart.PHRASES:
		letters.append("")
	build_ui()
	music = make_player(SONG, -3.0, Settings.MUSIC_BUS)
	sfx_hit = make_player(SFX_HIT, -8.0, Settings.SFX_BUS)
	sfx_miss = make_player(SFX_MISS, -6.0, Settings.SFX_BUS)
	music.play()

func make_player(stream: AudioStream, volume: float, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player

func current_song_time(delta: float) -> float:
	_clock += delta
	if music.playing:
		var audio_time := music.get_playback_position() + AudioServer.get_time_since_last_mix() \
			- AudioServer.get_output_latency()
		if audio_time > 0.0:
			_clock = audio_time
	return maxf(song_time, _clock)

func _process(delta: float) -> void:
	if state == State.PLAYING:
		song_time = current_song_time(delta)
		judge_missed()
		if song_time >= Chart.SONG_LENGTH - 0.3 and next_judge >= notes.size():
			finish(true)
	for i in 4:
		lane_flash[i] = maxf(0.0, lane_flash[i] - delta * 5.0)
	canvas.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
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
				get_viewport().set_input_as_handled()
				GameState.return_to_hub()

func press_lane(lane: int) -> void:
	lane_flash[lane] = 1.0
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
	match result:
		"perfect":
			perfect_count += 1
			combo += 1
			score += 100 + combo * 2
			energy += ENERGY_PERFECT
		"good":
			good_count += 1
			combo += 1
			score += 60 + combo
			energy += ENERGY_GOOD
		"miss":
			miss_count += 1
			combo = 0
			energy += ENERGY_MISS
	max_combo = maxi(max_combo, combo)
	energy = clampf(energy, 0.0, 1.0)
	if result == "miss":
		sfx_miss.play()
	else:
		sfx_hit.play()
	if note.key and note.phrase >= 0:
		letters[note.phrase] = "miss" if result == "miss" else "hit"
	if energy <= 0.0:
		finish(false)
	while next_judge < notes.size() and notes[next_judge].judged:
		next_judge += 1

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
		lines.append("Леня: Ноты складываются в буквы… Р-А-К-Е-Т-А. Чувствуешь?")
		lines.append("Очки: %d    Лучшее комбо: %d" % [score, max_combo])
		lines.append("Улика: %s" % GameState.CLUES[MASCOT].title)
	else:
		lines.append("Сбился с ритма…")
		lines.append("Леня: Ничего. Главное — чувствовать. Попробуем ещё раз?")
	result_label.text = "\n".join(lines)
	result_label.show()

func lane_x(lane: int) -> float:
	return HIGHWAY_X + lane * LANE_W

func note_y(t: float) -> float:
	return HIT_Y - (t - song_time) / TRAVEL * (HIT_Y - TOP_Y)

func draw_scene() -> void:
	var font := Brand.BODY_FONT
	var beat := fmod(maxf(song_time, 0.0), 60.0 / Chart.BPM) / (60.0 / Chart.BPM)
	var on_beat := beat < 0.15 and state == State.PLAYING

	# Спрайт
	var bounce := -3.0 if on_beat else 0.0
	canvas.draw_texture_rect(LENYA, Rect2(42, 122 + bounce, 128, 128), false)

	# Дорожки
	for lane in 4:
		var x := lane_x(lane)
		var base: Color = LANE_COLORS[lane]
		canvas.draw_rect(Rect2(x, TOP_Y, LANE_W, HIT_Y - TOP_Y + 20), Color(base, 0.08 + lane_flash[lane] * 0.25))
		canvas.draw_line(Vector2(x, TOP_Y), Vector2(x, HIT_Y + 20), Color(1, 1, 1, 0.12))
		var receptor := Rect2(x + 4, HIT_Y - 7, LANE_W - 8, 14)
		canvas.draw_rect(receptor, Color(base, 0.35 + lane_flash[lane] * 0.6), false, 2.0)

	# Линия попадания
	canvas.draw_line(Vector2(HIGHWAY_X - 6, HIT_Y), Vector2(HIGHWAY_X + LANE_W * 4 + 6, HIT_Y),
		Color(1, 1, 1, 0.9 if on_beat else 0.5), 2.0)

	# Ноты (без линии-подсветки)
	for i in range(next_judge, notes.size()):
		var note: Dictionary = notes[i]
		var y := note_y(note.time)
		if y < TOP_Y - 16:
			break
		if note.judged:
			continue
		var x := lane_x(note.lane)
		var color: Color = KEY_COLOR if note.key else LANE_COLORS[note.lane]
		var rect := Rect2(x + 3, y - 9, LANE_W - 6, 18) if note.key else Rect2(x + 5, y - 6, LANE_W - 10, 12)
		canvas.draw_rect(rect, color)
		canvas.draw_rect(rect, Color.WHITE if note.key else Color(0.1, 0.07, 0.1), false, 1.0)

	draw_panel(font)

func draw_panel(font: Font) -> void:
	var x := 440.0
	canvas.draw_string(font, Vector2(x, 130), "Очки: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	canvas.draw_string(font, Vector2(x, 152), "Комбо: %d" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		KEY_COLOR if combo >= 10 else Color.WHITE)
	canvas.draw_string(font, Vector2(x, 184), "Здоровье", HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var bar := Rect2(x, 192, 160, 10)
	canvas.draw_rect(bar, Color(1, 1, 1, 0.1))
	var fill_color := Color(0.4, 0.9, 0.5) if energy > 0.3 else Color(1.0, 0.4, 0.35)
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * energy, bar.size.y)), fill_color)
	canvas.draw_rect(bar, Color(1, 1, 1, 0.4), false, 1.0)

func build_ui() -> void:
	var background := ColorRect.new()
	background.color = Brand.BLUE.darkened(0.78)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(draw_scene)
	add_child(canvas)
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
