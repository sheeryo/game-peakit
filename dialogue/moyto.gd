extends RefCounted
## Диалоги Мойто (конкурсы).


func start(d: DialogueBox) -> void:
	if not GameState.has_met("moyto"):
		GameState.mark_met("moyto")
		await d.say("Мойто", "Ой! Кто здесь?! А, это ты… Я ничего не прячу! Совсем ничего!")

	if GameState.has_clue("sulus") and not GameState.has_secret("moyto_handwriting"):
		GameState.add_secret_dialogue("moyto_handwriting")
		await d.say("Мойто", "Это страница из лекции? Внимание, вопрос: чей это почерк?")
		await d.say("Мойто", "Это же тот же почерк, что на записке! И клякса та же!")
		return

	if GameState.has_stamp("moyto"):
		await d.say("Мойто", "Ладно, признаюсь! За спиной я прятал призы для конкурсов. Сюрприз же!")
		await d.say("Мойто", "А записку-загадку я не писал, честно-честно! Её кто-то приколол на мою доску.")
		return

	await d.say("Мойто", "Внимание, вопрос! Хочешь сыграть в викторину? Ответишь на три вопроса из пяти, и печать твоя!")
	var answer := await d.ask("Мойто", "Выбирай ответ стрелками и жми Enter. Только быстро, время идёт!",
		["Играем!", "Потом"])
	if answer == 0:
		GameState.request_minigame("moyto")
	else:
		await d.say("Мойто", "Эх! Ну ладно, я подожду. Только не смотри, что у меня за спиной!")
