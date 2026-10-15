extends Node

const TRACK_PATH := "res://assets/music/%s.wav"
const VOLUME_DB := -8.0
const SILENT_DB := -60.0
const FADE_TIME := 0.8

const SCENE_TRACKS := {
	"res://scenes/main_menu.tscn": "title",
	"res://scenes/intro.tscn": "intro",
	"res://scenes/world.tscn": "hub",
	"res://manya_minigame/manya_minigame.tscn": "manya",
	"res://ritm/main.tscn": "",
	"res://katya_minigame/katya_minigame.tscn": "katya",
	"res://moyto_minigame/Minigame_Moyto.tscn": "moyto",
	"res://sulus_minigame/sulus_minigame.tscn": "sulus",
}
const DIALOGUE_TRACKS := ["manya", "lenya", "katya", "moyto", "sulus"]

var _players := {}
var _current := ""
var _scene_track := ""
var _scene_path := ""
var _dialogue_track := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == _scene_path:
		return
	_scene_path = scene.scene_file_path
	_dialogue_track = ""
	if SCENE_TRACKS.has(_scene_path):
		_scene_track = SCENE_TRACKS[_scene_path]
		_switch(_scene_track)

func play(track: String) -> void:
	_scene_track = track
	_switch(track)

func stop() -> void:
	play("")

func _switch(track: String, keep_previous := false) -> void:
	if track == _current:
		return
	if _current != "":
		_fade(_players[_current], SILENT_DB, not keep_previous)
	_current = track
	if track == "":
		return
	var player := _get_player(track)
	if not player.playing:
		player.play()
	_fade(player, VOLUME_DB)

func _get_player(track: String) -> AudioStreamPlayer:
	if _players.has(track):
		return _players[track]
	var player := AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load(TRACK_PATH % track)
	if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.volume_db = SILENT_DB
	player.bus = Settings.MUSIC_BUS
	add_child(player)
	_players[track] = player
	return player

func _fade(player: AudioStreamPlayer, to_db: float, stop_after := false) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, FADE_TIME)
	if stop_after:
		tween.tween_callback(func() -> void:
			if _players.get(_current) != player:
				player.stop())

func _on_dialogue_started(resource: DialogueResource) -> void:
	if _scene_track != "hub":
		return
	var who := resource.resource_path.get_file().get_basename()
	if who in DIALOGUE_TRACKS:
		_dialogue_track = who
		_switch(who, true)

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	if _dialogue_track == "":
		return
	_dialogue_track = ""
	_switch(_scene_track)
