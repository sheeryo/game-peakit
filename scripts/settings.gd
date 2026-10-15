extends Node

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const STEPS := 10
const DEFAULT_VOLUME := 8

const ALLOW_QUIT := true

var music_volume := DEFAULT_VOLUME
var sfx_volume := DEFAULT_VOLUME


func _ready() -> void:
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		music_volume = clampi(config.get_value("audio", "music", DEFAULT_VOLUME), 0, STEPS)
		sfx_volume = clampi(config.get_value("audio", "sfx", DEFAULT_VOLUME), 0, STEPS)
	_apply()


func set_music_volume(value: int) -> void:
	music_volume = clampi(value, 0, STEPS)
	_apply()
	_save()


func set_sfx_volume(value: int) -> void:
	sfx_volume = clampi(value, 0, STEPS)
	_apply()
	_save()


func _apply() -> void:
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SFX_BUS, sfx_volume)


func _set_bus(bus: StringName, value: int) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, value == 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(pow(float(value) / STEPS, 2.0)))


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(PATH)
