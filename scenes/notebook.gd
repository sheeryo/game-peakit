extends CanvasLayer

const NOTEBOOK := preload("res://assets/notebook/notebook.png")
const INK := Color("#3a261c")
const INK_TITLE := Color("#a4561a")
const HINT_COLOR := Color("#9a8a78")

var panel: Control
var goals_label: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	build_ui()
	panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if panel.visible:
		if event.is_action_pressed("notebook") or event.is_action_pressed("ui_cancel"):
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("notebook") and not GameState.in_dialogue:
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	refresh()
	panel.show()
	Sfx.play("page")
	get_tree().paused = true


func close() -> void:
	panel.hide()
	Sfx.play("page", 0.1)
	get_tree().paused = false


func is_open() -> bool:
	return panel.visible


func refresh() -> void:
	var text := ""
	for mascot in GameState.MASCOTS:
		var info: Dictionary = GameState.MASCOT_INFO[mascot]
		var line := "Помочь: %s (%s)" % [info.name, info.zone]
		if GameState.has_stamp(mascot):
			text += "[color=#%s]%s — готово[/color]\n" % [HINT_COLOR.to_html(false), line]
		else:
			text += line + "\n"
	text += "\n"
	if GameState.can_open_finale():
		text += "[b]Назвать разгадку у главной сцены[/b]"
	else:
		text += "Собрать хотя бы три улики и прийти к главной сцене"
	goals_label.text = text


func build_ui() -> void:
	var root := ColorRect.new()
	root.color = Color(0, 0, 0, 0.5)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = root

	var book := TextureRect.new()
	book.texture = NOTEBOOK
	book.set_anchors_preset(Control.PRESET_CENTER)
	book.offset_left = -NOTEBOOK.get_width() / 2.0
	book.offset_top = -NOTEBOOK.get_height() / 2.0
	book.offset_right = NOTEBOOK.get_width() / 2.0
	book.offset_bottom = NOTEBOOK.get_height() / 2.0
	root.add_child(book)

	var left := page(book, Rect2(42, 18, 244, 292))
	var title := make_label(left, "Детективный блокнот", 15, INK_TITLE)
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	make_label(left, "Задачи", 12, INK).theme_type_variation = &"HeaderLabel"
	goals_label = RichTextLabel.new()
	goals_label.bbcode_enabled = true
	goals_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	goals_label.add_theme_color_override("default_color", INK)
	goals_label.add_theme_font_size_override("normal_font_size", 11)
	goals_label.add_theme_font_size_override("bold_font_size", 11)
	goals_label.add_theme_font_override("bold_font", Brand.HEADER_FONT)
	left.add_child(goals_label)


func page(book: Control, rect: Rect2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = rect.position
	box.size = rect.size
	box.add_theme_constant_override("separation", 6)
	book.add_child(box)
	return box


func make_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
