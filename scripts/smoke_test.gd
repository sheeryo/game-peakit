extends Node
## Дымовой тест сборки: по очереди открывает все сцены и выходит.
## Запуск: HotonGame.console.exe -- --smoke-test
## Ошибки загрузки (регистр путей, пропавшие ресурсы) видны в выводе как ERROR.
## В конце печатает «SMOKE TEST DONE». Запускается из GameState, посетителю недоступен.

const SCENES := [
	"res://scenes/ui/title.tscn",
	"res://scenes/ui/intro.tscn",
	"res://scenes/world.tscn",
	"res://scenes/backstage/backstage.tscn",
	"res://scenes/minigames/rhythm/rhythm.tscn",
	"res://scenes/minigames/quiz/quiz.tscn",
	"res://scenes/minigames/cosplay/cosplay.tscn",
	"res://scenes/minigames/art/sketch_puzzle.tscn",
	"res://scenes/minigames/logic/seating.tscn",
	"res://scenes/finale/finale.tscn",
	"res://scenes/ui/ending.tscn",
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
