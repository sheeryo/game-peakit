extends CanvasLayer

const PORTRAIT_PATH := "res://assets/portraits/%s.png"
const TALK_BOB_PERIOD := 0.24

@export var dialogue_resource: DialogueResource
@export var start_from_cue: String = ""
@export var auto_start: bool = false
@export var will_block_other_input: bool = true
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_accept"

@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer
@onready var balloon: Control = %Balloon
@onready var portrait_box: Control = %PortraitBox
@onready var portrait: TextureRect = %Portrait
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var will_hide_balloon: bool = false
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()
var _bob_time := 0.0

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

var mutation_cooldown: Timer = Timer.new()


func _ready() -> void:
	add_to_group("dialogue_balloon")
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(delta: float) -> void:
	if not is_instance_valid(dialogue_line):
		return
	var waiting: bool = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and not dialogue_line.has_tag("voice")
	if dialogue_label.is_typing:
		_bob_time += delta
		var up: bool = fmod(_bob_time, TALK_BOB_PERIOD) < TALK_BOB_PERIOD / 2.0
		portrait.position.y = -2.0 if up else 0.0
	else:
		portrait.position.y = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if will_block_other_input:
		if responses_menu.visible and event.is_pressed() and not event.is_echo():
			if event.is_action("up") and not event.is_action("ui_up"):
				_move_response_focus(-1)
			elif event.is_action("down") and not event.is_action("ui_down"):
				_move_response_focus(1)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		await dialogue_line.refresh()
		if visible_ratio < 1:
			dialogue_label.skip_typing()


func start(with_dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_cue, temporary_game_states)
	show()


func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	var texture := portrait_for(dialogue_line)
	portrait.texture = texture
	portrait_box.visible = texture != null
	_bob_time = 0.0

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.has_tag("voice"):
		audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
		audio_stream_player.play()
		await audio_stream_player.finished
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


func portrait_for(line: DialogueLine) -> Texture2D:
	if line.character.is_empty() and not line.has_tag("portrait"):
		return null
	var id := line.get_tag_value("portrait")
	if id.is_empty():
		for mascot in GameState.MASCOT_INFO:
			if GameState.MASCOT_INFO[mascot].name == line.character:
				id = mascot
	var path := PORTRAIT_PATH % id
	if id.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)


func _move_response_focus(step: int) -> void:
	var items: Array = responses_menu.get_menu_items()
	if items.is_empty():
		return
	var current := 0
	for i in items.size():
		if items[i].has_focus():
			current = i
	var target: Control = items[(current + step + items.size()) % items.size()]
	target.grab_focus()


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action) and not event.is_echo()
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input:
		return
	if dialogue_line.responses.size() > 0:
		return

	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and not event.is_echo() and get_viewport().gui_get_focus_owner() == balloon:
			next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)
