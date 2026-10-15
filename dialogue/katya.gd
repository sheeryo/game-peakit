extends RefCounted
## Диалоги Кати (косплей-дефиле).


func start(d: DialogueBox) -> void:
	if not GameState.has_met("katya"):
		GameState.mark_met("katya")
		await d.say("Катя", "О, новое лицо! Отличный образ, детектив, тебе идёт!")

	if GameState.has_clue("lenya") and not GameState.has_secret("katya_melody"):
		GameState.add_secret_dialogue("katya_melody")
		await d.say("Катя", "Ой, дай гляну на ноты! Та-ра-ра-рам…")
		await d.say("Катя", "Стоп! Я её уже слышала! Сулус насвистывал эту мелодию утром, когда я бежала на репетицию.")
		return

	if GameState.has_stamp("katya"):
		await d.say("Катя", "Фото с репетиции у тебя! Присмотрись к заднему плану, там кто-то с рогами и в фартуке. *подмигивает*")
		return

	await d.say("Катя", "Да, я утром бегала с сундуком! С костюмами, конечно. Что ещё может быть в сундуке?")
	await d.say("Катя", "Беда! Костюмы «Ретро», «Цирк» и «Космос» перепутались, а через минуту репетиция дефиле!")
	await d.say("Катя", "Поможешь собрать образы? Я говорю тему, ты одеваешь манекен.")
	var answer := await d.ask("Катя", "Стрелки вверх-вниз выбирают деталь, влево-вправо меняют её. Enter — показать мне!",
		["Помогу!", "Потом"])
	if answer == 0:
		GameState.request_minigame("katya")
	else:
		await d.say("Катя", "Ладно, но не затягивай! *подмигивает*")
