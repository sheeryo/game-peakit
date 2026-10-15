extends Node
## Autoload `Music`: фоновая музыка с плавной сменой треков.
## Треки — audio/music/<имя>.wav (tools/music/game_audio.py), зациклены.
## Сам выбирает трек по текущей сцене (SCENE_TRACKS); во время разговора
## с маскотом в хабе играет его тема, потом хаб продолжается с того же места.
## Сцена может включить свой трек сама: Music.play("intro"), Music.stop().

const TRACK_PATH := "res://audio/music/%s.wav"
const VOLUME_DB := -8.0
const SILENT_DB := -60.0
const FADE_TIME := 0.8

## Сцена → трек. Мини-игры — темы маскотов; ритм-игра играет песню Лени сама.
const SCENE_TRACKS := {
	"res://scenes/ui/title.tscn": "title",
	"res://scenes/ui/intro.tscn": "intro",
	"res://scenes/world.tscn": "hub",
	"res://scenes/backstage/backstage.tscn": "backstage",
	"res://scenes/finale/finale.tscn": "finale",
	"res://scenes/ui/ending.tscn": "finale",
	"res://scenes/minigames/art/sketch_puzzle.tscn": "manya",
	"res://scenes/minigames/rhythm/rhythm.tscn": "",
	"res://scenes/minigames/cosplay/cosplay.tscn": "katya",
	"res://scenes/minigames/quiz/quiz.tscn": "moyto",
	"res://scenes/minigames/logic/seating.tscn": "sulus",
}
## Разговоры маскотов со своей темой: файл диалога → трек.
const DIALOGUE_TRACKS := ["manya", "lenya", "katya", "moyto", "sulus"]

## Трек → плеер. Плеер не останавливается, а приглушается: вернулись — играет дальше.
var _players := {}
var _current := ""
## Трек сцены (без учёта разговора)
var _scene_track := ""
var _scene_path := ""
var _dialogue_track := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Dialogue.started.connect(_on_dialogue_started)
	Dialogue.ended.connect(_on_dialogue_ended)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == _scene_path:
		return
	_scene_path = scene.scene_file_path
	_dialogue_track = ""
	if SCENE_TRACKS.has(_scene_path):
		_scene_track = SCENE_TRACKS[_scene_path]
		# За кулисами в финале — музыка финала
		if _scene_track == "backstage" and GameState.finale_ending != "":
			_scene_track = "finale"
		_switch(_scene_track)


## Включить трек (пустая строка — тишина).
func play(track: String) -> void:
	_scene_track = track
	_switch(track)


func stop() -> void:
	play("")


## keep_previous — прежний трек не останавливать, а только приглушить
## (хаб под разговором): потом он продолжится с того же места.
func _switch(track: String, keep_previous := false) -> void:
	if track == _current:
		return
	if _current != "":
		_fade(_players[_current], SILENT_DB, not keep_previous)
	_current = track
	if track == "":
		return
	var player: AudioStreamPlayer = _players.get(track)
	if player == null:
		player = AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load(TRACK_PATH % track)
		# Петля на весь трек (на случай, если импорт не прочёл её из WAV)
		if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		player.stream = stream
		player.volume_db = SILENT_DB
		player.bus = Settings.MUSIC_BUS
		add_child(player)
		_players[track] = player
	if not player.playing:
		player.play()
	_fade(player, VOLUME_DB)


func _fade(player: AudioStreamPlayer, to_db: float, stop_after := false) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, FADE_TIME)
	if stop_after:
		tween.tween_callback(func() -> void:
			if _players.get(_current) != player:
				player.stop())


func _on_dialogue_started() -> void:
	if _scene_track != "hub":
		return
	var path := Dialogue.current_script_path()
	var who := path.get_file().get_basename()
	if who in DIALOGUE_TRACKS:
		_dialogue_track = who
		_switch(who, true)


func _on_dialogue_ended() -> void:
	if _dialogue_track == "":
		return
	_dialogue_track = ""
	_switch(_scene_track)
