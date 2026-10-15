extends RefCounted
## Диалоги Лени (музыкальная сцена).


func start(d: DialogueBox) -> void:
	if not GameState.has_met("lenya"):
		GameState.mark_met("lenya")
		await d.say("Леня", "Привет… Чувствуешь? Утро, тишина, а скоро здесь будет музыка.")

	if GameState.has_clue("manya") and not GameState.has_secret("lenya_sketch"):
		GameState.add_secret_dialogue("lenya_sketch")
		await d.say("Леня", "Это эскиз Мани? Ракета за сценой…")
		await d.say("Леня", "Ракета! Значит, мелодия была не просто так…")
		await d.say("Леня", "Помню ретро-год: тогда тоже все искали пластинку, а она играла у всех под носом.")
		return

	if GameState.has_stamp("lenya"):
		await d.say("Леня", "Мелодия до сих пор звучит у меня в голове… Чувствуешь?")
		await d.say("Леня", "Странные в ней ноты. Если записать их буквами, выходит «РАКЕТА». Совпадение?")
		return

	await d.say("Леня", "Мне утром кто-то оставил новую мелодию. Без подписи.")
	await d.say("Леня", "Сыграть её одному не выходит. Поможешь?")
	var answer := await d.ask("Леня", "Жми D, F, J, K, когда нота доходит до линии. Главное — чувствовать ритм.",
		["Сыграть!", "Потом"])
	if answer == 0:
		GameState.request_minigame("lenya")
	else:
		await d.say("Леня", "Хорошо… Мелодия подождёт.")
