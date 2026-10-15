extends Node
## Autoload `Sfx`: короткие звуки интерфейса, шагов и «голоса» в диалогах.
## Звуки — audio/sfx/<имя>.wav (tools/music/game_audio.py).
##   Sfx.play("ui_select")       — звук по имени
##   Sfx.voice("Маня")           — писк голоса на букву (имя говорящего или id)
## Играют и на паузе (меню, блокнот).

const SFX_PATH := "res://audio/sfx/%s.wav"
const POOL_SIZE := 8
const VOLUME_DB := -4.0
## Имя в диалоге → голос. Остальные говорящие — голос гостя, "" — рассказчик.
const VOICES := {
	"Маня": "manya", "Леня": "lenya", "Катя": "katya", "Мойто": "moyto", "Сулус": "sulus",
	"": "narrator",
}

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME_DB
		player.bus = Settings.SFX_BUS
		add_child(player)
		_pool.append(player)


## pitch_jitter — случайный разброс высоты (0.05 = ±5 %), чтобы повторы не звучали одинаково.
func play(sound: String, pitch_jitter := 0.0, volume_db := VOLUME_DB) -> void:
	var stream: AudioStream = _cache.get(sound)
	if stream == null:
		var path := SFX_PATH % sound
		if not ResourceLoader.exists(path):
			push_warning("Sfx: нет звука %s" % path)
			return
		stream = load(path)
		_cache[sound] = stream
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Голос говорящего: по имени из диалога («Маня») или по id («narrator»).
func voice(speaker: String) -> void:
	var id: String = VOICES.get(speaker, speaker if speaker in VOICES.values() else "guest")
	play("voice_" + id, 0.06, VOLUME_DB - 6.0)
