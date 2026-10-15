extends Control

const MASCOT := "manya"
const TIME_LIMIT := 90.0
const GRID := 3
const TILE := 80
const GAP := 2
const MIN_SHUFFLED := 6

const CURSOR_COLOR := Brand.ORANGE
const PICKED_COLOR := Brand.RED

const PICTURE := preload("res://assets/manya_sketch.png")

enum State { PLAYING, RESULT }

var state := State.PLAYING
var board: Array[int] = []
var cursor := 0
var picked := -1
var moves := 0
var time_left := TIME_LIMIT
var won := false

var picture: Texture2D = PICTURE
var manya_label: Label
var grid_view: Control
var timer_bar: ProgressBar
var info_label: Label


func _ready() -> void:
	build_ui()
	shuffle_board()
	update_info()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	time_left -= delta
	timer_bar.value = time_left
	if time_left <= 0.0:
		finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	match state:
		State.PLAYING:
			if event.is_action_pressed("up"):
				move_cursor(0, -1)
			elif event.is_action_pressed("down"):
				move_cursor(0, 1)
			elif event.is_action_pressed("left"):
				move_cursor(-1, 0)
			elif event.is_action_pressed("right"):
				move_cursor(1, 0)
			elif event.is_action_pressed("enter"):
				press()
		State.RESULT:
			if event.is_action_pressed("enter"):
				if won:
					GameState.return_to_hub()
				else:
					get_tree().reload_current_scene()
			elif event.is_action_pressed("ui_cancel") and not won:
				get_viewport().set_input_as_handled()
				GameState.return_to_hub()


func shuffle_board() -> void:
	board.clear()
	for i in GRID * GRID:
		board.append(i)
	while misplaced() < MIN_SHUFFLED:
		board.shuffle()


func misplaced() -> int:
	var count := 0
	for i in board.size():
		if board[i] != i:
			count += 1
	return count


func move_cursor(dx: int, dy: int) -> void:
	var x := (cursor % GRID + dx + GRID) % GRID
	var y := (cursor / GRID + dy + GRID) % GRID
	cursor = y * GRID + x
	Sfx.play("ui_move")
	grid_view.queue_redraw()


func press() -> void:
	if picked == -1:
		picked = cursor
		Sfx.play("ui_select")
	elif picked == cursor:
		picked = -1
	else:
		var tile := board[picked]
		board[picked] = board[cursor]
		board[cursor] = tile
		picked = -1
		moves += 1
		Sfx.play("swap")
		if misplaced() == 0:
			finish(true)
			return
	update_info()
	grid_view.queue_redraw()


func update_info() -> void:
	if picked == -1:
		manya_label.text = "Маня: Ой, ветер всё перепутал! Собери мою схему, солнышко!"
	else:
		manya_label.text = "Маня: Куда положим этот кусочек?"
	info_label.text = "Ходов: %d" % moves


func finish(is_win: bool) -> void:
	state = State.RESULT
	won = is_win
	Sfx.play("win" if won else "lose")
	picked = -1
	timer_bar.hide()
	grid_view.queue_redraw()
	if won:
		GameState.add_stamp(MASCOT)
		manya_label.text = "Маня: Ой, получилось! Вот она, моя схема праздника. Держи печать!\nУлика: %s" % \
			GameState.CLUES[MASCOT].title
		info_label.text = "Ходов: %d" % moves
	else:
		manya_label.text = "Маня: Ой, время вышло! Ничего, давай ещё разок."
		info_label.text = ""


func draw_grid() -> void:
	var gap := 0 if won else GAP
	for i in board.size():
		var tile := board[i]
		var src := Rect2((tile % GRID) * TILE, (tile / GRID) * TILE, TILE, TILE)
		var dst := Rect2((i % GRID) * (TILE + gap), (i / GRID) * (TILE + gap), TILE, TILE)
		grid_view.draw_texture_rect_region(picture, dst, src)
		if i == picked:
			grid_view.draw_rect(dst, Color(1, 1, 1, 0.3))
			grid_view.draw_rect(dst.grow(-1), PICKED_COLOR, false, 2.0)
		if i == cursor and state == State.PLAYING:
			grid_view.draw_rect(dst.grow(1), CURSOR_COLOR, false, 2.0)
	if won:
		grid_view.draw_string(Brand.BODY_FONT, Vector2(204, 16), "для С.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.1, 0.1))


func build_ui() -> void:
	Brand.add_backdrop(self, MASCOT, Brand.SALMON.darkened(0.65))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	manya_label = make_label(box, 13)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)

	grid_view = Control.new()
	grid_view.custom_minimum_size = Vector2.ONE * (GRID * TILE + (GRID - 1) * GAP)
	grid_view.draw.connect(draw_grid)
	row.add_child(grid_view)

	var sample_box := VBoxContainer.new()
	sample_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(sample_box)
	make_label(sample_box, 10).text = "Как было:"
	var sample := TextureRect.new()
	sample.texture = picture
	sample.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sample.custom_minimum_size = Vector2.ONE * GRID * TILE / 2
	sample.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sample_box.add_child(sample)

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
