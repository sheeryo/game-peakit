extends Node
## Локальный лидерборд, топ-5. Autoload `Leaderboard`, файл user://leaderboard.cfg.
## Сортировка: больше печатей выше, при равенстве — меньше время (с штрафами).
## Имён нет (решено 2026-10-15): запись — печати, время и пройденная концовка.

const PATH := "user://leaderboard.cfg"
const SIZE := 5

## [{stamps, time, ending}]; ending — название концовки («Полное расследование»)
var entries: Array = []


func _ready() -> void:
	load_entries()


func load_entries() -> void:
	entries.clear()
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for i in SIZE:
		var section := "entry_%d" % i
		if not config.has_section(section):
			break
		# Старые записи с именем («name») читаются, имя просто не показывается
		entries.append({
			"stamps": config.get_value(section, "stamps", 0),
			"time": config.get_value(section, "time", 0.0),
			"ending": config.get_value(section, "ending", ""),
		})
	entries.sort_custom(is_better)


func save_entries() -> void:
	var config := ConfigFile.new()
	for i in entries.size():
		var section := "entry_%d" % i
		for key in entries[i]:
			config.set_value(section, key, entries[i][key])
	config.save(PATH)


static func is_better(a: Dictionary, b: Dictionary) -> bool:
	if a.stamps != b.stamps:
		return a.stamps > b.stamps
	return a.time < b.time


## Попадёт ли результат в топ.
func qualifies(stamps: int, time: float) -> bool:
	if entries.size() < SIZE:
		return true
	return is_better({"stamps": stamps, "time": time}, entries[-1])


## Добавляет результат, возвращает место (0..SIZE-1) или -1, если не попал.
func add(stamps: int, time: float, ending: String) -> int:
	var entry := {"stamps": stamps, "time": time, "ending": ending}
	entries.append(entry)
	entries.sort_custom(is_better)
	entries.resize(mini(entries.size(), SIZE))
	save_entries()
	return entries.find(entry)


func clear() -> void:
	entries.clear()
	save_entries()


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [floori(total / 60.0), total % 60]


## Строки топа: «1.  ●●●●○  4:12  «Полное расследование»». highlight — строка с меткой «<».
func format_lines(highlight := -1) -> Array[String]:
	var lines: Array[String] = []
	for i in SIZE:
		if i < entries.size():
			var entry: Dictionary = entries[i]
			var stamps := "●".repeat(entry.stamps) + "○".repeat(5 - entry.stamps)
			var mark := "  <" if i == highlight else ""
			var ending: String = "«%s»" % entry.ending if entry.ending != "" else ""
			lines.append("%d.   %s   %s   %s%s" % [i + 1, stamps, format_time(entry.time), ending, mark])
		else:
			lines.append("%d. ---" % (i + 1))
	return lines
