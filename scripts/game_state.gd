extends Node
## Этот скрипт должен быть добавлен в Autoload (Автозагрузку) под именем GameState

# Сигнал отправляет имя маскота, чтобы интерфейс мог его использовать (например, для эффектов)
signal stamp_added(mascot_name: String)

const STAMPS_FOR_FINALE = 3
const MASCOTS = ["manya", "lenya", "katya", "moyto", "sulus"]

var completed_minigames = {
	"ritm": false,
	"puzzle": false
}

var stamps: Array[String] = []

func complete_minigame(name: String):
	if completed_minigames.has(name):
		completed_minigames[name] = true
		print('completed', name)
	else:
		print('unknown minigame')

func add_stamp(stamp_name: String):
	var formatted_name = stamp_name.to_lower()
	if not formatted_name in MASCOTS:
		print('unknown mascot stamp')
		return
	if not formatted_name in stamps:
		stamps.append(formatted_name)
		print("Получен штамп! Всего штампов:", stamps.size())
		# Оповещаем интерфейс и передаем имя маскота
		stamp_added.emit(formatted_name)

func is_minigame_completed(name: String) -> bool:
	return completed_minigames.get(name, false)
	
func are_all_minigames_completed() -> bool:
	for game in completed_minigames.values():
		if not game:
			return false
	return true

func stamp_count() -> int:
	return stamps.size()

func can_open_finale() -> bool:
	return stamp_count() >= STAMPS_FOR_FINALE
