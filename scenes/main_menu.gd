extends Control

const LOGO := preload("res://assets/ui/logo_hoton.png")

const WHITE_SHADER := "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a); }"

var menu_items: Array = []
var menu_labels: Array[Label] = []
var selected := 0
var _blink := 0.0


func _ready() -> void:
	build_ui()


func _process(delta: float) -> void:
	_blink += delta
	for i in menu_labels.size():
		menu_labels[i].modulate.a = 0.55 + 0.45 * cos(_blink * 4.0) if i == selected else 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if PauseMenu.is_open():
		return
	if event.is_action_pressed("up"):
		select((selected + menu_items.size() - 1) % menu_items.size())
	elif event.is_action_pressed("down"):
		select((selected + 1) % menu_items.size())
	elif event.is_action_pressed("enter"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_select")
		(menu_items[selected][1] as Callable).call()


func select(i: int) -> void:
	if i != selected:
		Sfx.play("ui_move")
	selected = i
	for j in menu_labels.size():
		menu_labels[j].text = menu_items[j][0]
		menu_labels[j].add_theme_color_override("font_color", Brand.ORANGE if j == i else Brand.CREAM)


func start_game() -> void:
	get_tree().change_scene_to_file(GameState.INTRO_SCENE)


func build_ui() -> void:
	var background := ColorRect.new()
	background.color = Brand.BROWN_DEEP
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(200, 100)
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var white := ShaderMaterial.new()
	white.shader = Shader.new()
	white.shader.code = WHITE_SHADER
	logo.material = white
	box.add_child(logo)

	make_label(box, "Дело о пропавшей Капсуле", 16).theme_type_variation = &"HeaderLabel"
	menu_items = [["Начать", start_game], ["Громкость", PauseMenu.open_volume]]
	if Settings.ALLOW_QUIT:
		menu_items.append(["Выход", PauseMenu.open_quit])
	for item in menu_items:
		menu_labels.append(make_label(box, "", 13))
	select(0)


func make_label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
