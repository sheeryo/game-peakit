extends CanvasLayer
## Меню паузы — autoload `PauseMenu`. Esc (или клик по плашке «Esc — меню»
## в правом верхнем углу) ставит игру на паузу: «Продолжить», «Вернуться
## на фестиваль» (в мини-играх), «Громкость», «Главное меню», «Выйти из игры».
## Не открывается на титульном экране и в заставке, во время диалога
## и поверх блокнота. Сцена, которой Esc нужен самой, помечает его
## обработанным (get_viewport().set_input_as_handled()) — тогда меню молчит.
## Титульный экран открывает отсюда только страницы «Громкость» и «Выйти?»
## (open_volume, open_quit) — без паузы.

const SELECTED_COLOR := Brand.SELECTED
const NORMAL_COLOR := Brand.TEXT
## Сцены без меню: там Esc не нужен или ещё нечего ставить на паузу.
const NO_MENU_SCENES := [GameState.TITLE_SCENE, GameState.INTRO_SCENE, GameState.ENDING_SCENE]

enum Page { MAIN, VOLUME, QUIT }

var _panel: PanelContainer
var _title: Label
var _items_box: VBoxContainer
var _hint: Label
var _corner: Label
## Пункты страницы: {text: Callable → String, on_enter: Callable, on_side: Callable (шаг ±1)}
var _items: Array = []
var _selected := 0
var _page := Page.MAIN
## Открыто с титульного экрана: «Назад» закрывает меню, паузы нет.
var _from_title := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_build_ui()
	_panel.hide()
	# Автосброс по бездействию или R при открытом меню — меню закрыть
	GameState.run_reset.connect(_panel.hide)


func _process(_delta: float) -> void:
	# Плашка видна, пока меню можно открыть
	_corner.visible = not is_open() and _can_open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if is_open():
		if event.is_action_pressed("ui_cancel"):
			_back()
		elif event.is_action_pressed("up"):
			_select((_selected + _items.size() - 1) % _items.size())
		elif event.is_action_pressed("down"):
			_select((_selected + 1) % _items.size())
		elif event.is_action_pressed("left"):
			_side(-1)
		elif event.is_action_pressed("right"):
			_side(1)
		elif event.is_action_pressed("enter"):
			_activate(_selected)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _can_open():
		open()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


func _can_open() -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path in NO_MENU_SCENES:
		return false
	# Блокнот тоже ставит паузу — поверх него меню не нужно
	return not GameState.in_dialogue and not get_tree().paused


## Меню паузы в игре.
func open() -> void:
	_from_title = false
	_panel.show()
	Sfx.play("ui_open")
	get_tree().paused = true
	_show_page(Page.MAIN)


## Страницы для титульного экрана — без паузы.
func open_volume() -> void:
	_open_page(Page.VOLUME)


func open_quit() -> void:
	_open_page(Page.QUIT)


func _open_page(page: Page) -> void:
	_from_title = true
	_panel.show()
	Sfx.play("ui_open")
	_show_page(page)


func close() -> void:
	_panel.hide()
	Sfx.play("ui_close")
	if not _from_title:
		get_tree().paused = false


func _back() -> void:
	if _page == Page.MAIN or _from_title:
		close()
	else:
		Sfx.play("ui_close")
		_show_page(Page.MAIN)


func _show_page(page: Page) -> void:
	_page = page
	_items = []
	match page:
		Page.MAIN:
			_title.text = "Пауза"
			_add_item("Продолжить", close)
			var path := get_tree().current_scene.scene_file_path
			if path in GameState.MINIGAMES.values() or (path == GameState.BACKSTAGE_SCENE \
					and GameState.finale_ending == ""):
				_add_item("Вернуться на фестиваль", _leave.bind(GameState.return_to_hub))
			_add_item("Громкость", _show_page.bind(Page.VOLUME))
			_add_item("Главное меню", _leave.bind(GameState.go_to_title))
			if Settings.ALLOW_QUIT:
				_add_item("Выйти из игры", _show_page.bind(Page.QUIT))
			_hint.text = "↑↓ — выбрать    Enter — ок    Esc — назад"
		Page.VOLUME:
			_title.text = "Громкость"
			_items.append({
				"text": func() -> String: return "Музыка   " + _bar(Settings.music_volume),
				"on_enter": func() -> void: pass,
				"on_side": func(step: int) -> void: Settings.set_music_volume(Settings.music_volume + step),
			})
			_items.append({
				"text": func() -> String: return "Звуки     " + _bar(Settings.sfx_volume),
				"on_enter": func() -> void: pass,
				"on_side": _change_sfx_volume,
			})
			_add_item("Назад", _back)
			_hint.text = "↑↓ — выбрать    ←→ — тише / громче    Esc — назад"
		Page.QUIT:
			_title.text = "Выйти из игры?"
			_add_item("Нет", _back)
			_add_item("Да, выйти", get_tree().quit)
			_hint.text = "↑↓ — выбрать    Enter — ок    Esc — назад"
	for child in _items_box.get_children():
		_items_box.remove_child(child)
		child.queue_free()
	for i in _items.size():
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 13)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_item_input.bind(i))
		label.mouse_entered.connect(_select.bind(i))
		_items_box.add_child(label)
	_selected = 0
	_refresh()


func _add_item(text: String, on_enter: Callable) -> void:
	_items.append({
		"text": func() -> String: return text,
		"on_enter": on_enter,
		"on_side": Callable(),
	})


## Громкость звуков — сразу пискнуть, чтобы было слышно, какая она стала.
func _change_sfx_volume(step: int) -> void:
	Settings.set_sfx_volume(Settings.sfx_volume + step)
	Sfx.play("voice_manya")


func _bar(value: int) -> String:
	return "◀ " + "■".repeat(value) + "□".repeat(Settings.STEPS - value) + " ▶"


func _leave(go: Callable) -> void:
	_panel.hide()
	get_tree().paused = false
	go.call()


func _select(i: int) -> void:
	if i != _selected and is_open():
		Sfx.play("ui_move")
	_selected = i
	_refresh()


func _refresh() -> void:
	for j in _items_box.get_child_count():
		var label: Label = _items_box.get_child(j)
		label.text = ("> " if j == _selected else "   ") + (_items[j].text as Callable).call()
		label.modulate = SELECTED_COLOR if j == _selected else NORMAL_COLOR


func _side(step: int) -> void:
	var on_side: Callable = _items[_selected].on_side
	if on_side.is_valid():
		on_side.call(step)
		_refresh()


func _activate(i: int) -> void:
	Sfx.play("ui_select")
	(_items[i].on_enter as Callable).call()


func _on_item_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_select(i)
			_activate(i)
		# Колесо мыши — громкость на ползунке
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(i)
			_side(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(i)
			_side(-1)


func _on_corner_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _can_open():
		open()


func _build_ui() -> void:
	_corner = Label.new()
	_corner.text = "Esc — меню"
	_corner.add_theme_font_size_override("font_size", 10)
	Brand.style_hud_label(_corner)
	_corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner.offset_left = -80
	_corner.offset_right = -8
	_corner.offset_top = 6
	_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corner.mouse_filter = Control.MOUSE_FILTER_STOP
	_corner.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_corner.gui_input.connect(_on_corner_input)
	add_child(_corner)

	# Затемнение под меню
	var root := ColorRect.new()
	root.color = Color(0, 0, 0, 0.0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(240, 0)
	var style := Brand.panel_style()
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)
	# Затемнение показывается вместе с панелью
	_panel.visibility_changed.connect(func() -> void: root.color.a = 0.55 if _panel.visible else 0.0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", Brand.ORANGE)
	box.add_child(_title)

	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", 4)
	box.add_child(_items_box)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", Brand.MUTED)
	box.add_child(_hint)
