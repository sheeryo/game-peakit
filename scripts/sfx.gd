extends Node

const SFX_PATH := "res://assets/sfx/%s.wav"
const POOL_SIZE := 8
const VOLUME_DB := -4.0
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

