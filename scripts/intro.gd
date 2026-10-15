extends Control

const STAGE := preload("res://assets/cutscene/intro_stage.png")
const RELICS := [
	preload("res://assets/cutscene/intro_relics_0.png"),
	preload("res://assets/cutscene/intro_relics_1.png"),
	preload("res://assets/cutscene/intro_relics_2.png"),
	preload("res://assets/cutscene/intro_relics_3.png"),
]
const LETTER := preload("res://assets/cutscene/intro_letter.png")
const BACKGROUND := Color("#1b0c00")
const CHARS_PER_SECOND := 40.0
const FRAME_SIZE := Vector2(450, 225)
const FADE_TIME := 0.4
const APPEAR_TIME := 0.25

var slides := [
	[STAGE, "Каждый год в Якутске проходит фестиваль «Хотон»."],
	[STAGE, "Гостей встречают маскоты: Маня, Леня, Катя, Мойто и Сулус."],
	[RELICS[0], "От каждого фестиваля остаётся реликвия."],
	[RELICS[1], "С «Ретро» — виниловая пластинка."],
	[RELICS[2], "С «Цирка» — красный клоунский нос."],
	[RELICS[3], "С «Космоса» — картонный шлем."],
	[RELICS[3], "Все реликвии хранятся в Капсуле Хотона. Её открывают в начале каждого фестиваля."],
	[RELICS[0], "Но сегодня, за два часа до открытия фестиваля «Детектив», Капсула пропала…"],
	[LETTER, "На подставке нашли только записку:
«Настоящий детектив найдёт меня до открытия»."],
]

var _index := -1
var _typing := false
var _shown := 0.0
var _frame: Control
var _picture: TextureRect
var _text: Label
var _tween: Tween


func _ready() -> void:
	_build_ui()
	_next()


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown += CHARS_PER_SECOND * delta
	var count := int(_shown)
	_text.visible_characters = count
	if count >= _text.text.length():
		_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	var is_cancel := event.is_action_pressed("ui_cancel")
	if not is_cancel and not event.is_action_pressed("enter"):
		return
	get_viewport().set_input_as_handled()
	if is_cancel:
		_done()
	elif _typing:
		_finish_typing()
	else:
		_next()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1


func _next() -> void:
	_index += 1
	if _index >= slides.size():
		_done()
		return
	var slide: Array = slides[_index]
	var previous: Texture2D = _picture.texture
	var texture: Texture2D = slide[0]
	if _tween:
		_tween.kill()
	if texture == previous:
		_frame.modulate = Color.WHITE
	elif previous in RELICS and texture in RELICS:
		_tween = create_tween()
		_picture.texture = texture
		Sfx.play("swap")
		_frame.modulate = Color(1.6, 1.6, 1.6)
		_tween.tween_property(_frame, "modulate", Color.WHITE, APPEAR_TIME)
	else:
		_tween = create_tween()
		_tween.tween_property(_frame, "modulate:a", 0.0, FADE_TIME if previous else 0.0)
		_tween.tween_callback(func() -> void: _picture.texture = texture)
		_tween.tween_property(_frame, "modulate", Color.WHITE, FADE_TIME)
	_text.text = slide[1]
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true


func _done() -> void:
	set_process_unhandled_input(false)
	GameState.restart()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_frame.offset_left = -FRAME_SIZE.x / 2.0
	_frame.offset_right = FRAME_SIZE.x / 2.0
	_frame.offset_top = 20
	_frame.offset_bottom = 20 + FRAME_SIZE.y
	_frame.modulate.a = 0.0
	add_child(_frame)

	_picture = TextureRect.new()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(_picture)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = -100
	panel.offset_bottom = -12
	panel.add_theme_stylebox_override("panel", Brand.panel_style())
	add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 14)
	_text.add_theme_color_override("font_color", Brand.CREAM)
	box.add_child(_text)
