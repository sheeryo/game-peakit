extends RefCounted
## Закулисье: ракета, коробки «ПРИЗЫ», прожектор. В финале ракету открывает игрок —
## тексты концовок — в кат-сцене scenes/ui/ending.gd.


func rocket(d: DialogueBox) -> void:
	if GameState.finale_ending == "":
		await d.say("", "Большая картонная ракета с фестиваля «Космос». Дверца заклеена скотчем.")
		await d.say("", "Изнутри что-то тихо звякнуло… Или показалось?")
		if GameState.has_clue("manya") or GameState.has_clue("lenya"):
			await d.say("", "Та самая ракета, что на эскизе Мани и в нотах Лени!")
			await d.say("", "Но без доказательств её не откроешь. Расскажи разгадку на главной сцене.")
		else:
			await d.say("", "Надо бы узнать о ней побольше. Поспрашивай маскотов.")
		return

	# Финал: когда разговор закончится — кат-сцена концовки (scenes/ui/ending.gd), потом итоги
	GameState.request_ending()
	await d.say("", "Ты открываешь картонную ракету…")


func crates(d: DialogueBox) -> void:
	if GameState.has_stamp("moyto"):
		await d.say("", "Коробки с надписью «ПРИЗЫ». Вот что прятал Мойто! Сюрприз для конкурсов.")
	else:
		await d.say("", "Коробки с надписью «ПРИЗЫ». Мойто с утра так нервничал… Может, он прятал именно их?")


func spotlight(d: DialogueBox) -> void:
	await d.say("", "Прожектор для концертов Лени. Сейчас выключен, ракета стоит в тени.")
