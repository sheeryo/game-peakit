extends Node

const SCENES := [
	"res://scenes/main_menu.tscn",
	"res://scenes/intro.tscn",
	"res://scenes/world.tscn",
	"res://ritm/main.tscn",
	"res://moyto_minigame/Minigame_Moyto.tscn",
	"res://katya_minigame/katya_minigame.tscn",
	"res://manya_minigame/manya_minigame.tscn",
	"res://sulus_minigame/sulus_minigame.tscn",
]
const TIME_PER_SCENE := 1.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	print("SMOKE TEST: %s, %s" % [ProjectSettings.get_setting("application/config/name"),
		RenderingServer.get_video_adapter_name()])
	for path in SCENES:
		var error := tree.change_scene_to_file(path)
		await tree.create_timer(TIME_PER_SCENE).timeout
		var loaded: bool = tree.current_scene != null and tree.current_scene.scene_file_path == path
		print("SMOKE %s %s" % ["ok  " if error == OK and loaded else "FAIL", path])
	print("SMOKE user:// = %s" % OS.get_user_data_dir())
	print("SMOKE TEST DONE")
	tree.quit()
