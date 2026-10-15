extends RefCounted
## Диалоги Сулуса (лекторий).


func start(d: DialogueBox) -> void:
	if not GameState.has_met("sulus"):
		GameState.mark_met("sulus")
		await d.say("Сулус", "А, коллега! Добро пожаловать в лекторий.")

	if GameState.stamp_count() >= 3 and not GameState.has_secret("sulus_hypothesis"):
		GameState.add_secret_dialogue("sulus_hypothesis")
		await d.say("Сулус", "Вы собрали столько улик… Позвольте, я протру очки.")
		await d.say("Сулус", "Хм. Интересная гипотеза… для лекции. Исключительно для лекции.")
		return

	if GameState.has_stamp("sulus"):
		await d.say("Сулус", "Страница из моей лекции у вас? Ах, какая рассеянность с моей стороны.")
		return

	await d.say("Сулус", "Прошу прощения, коллега, не мешайте: я готовлю лекцию «Как мыслит детектив».")
	await d.say("Сулус", "Пропала Капсула? Какая любопытная гипотеза. Наблюдайте, сопоставляйте, делайте выводы.")
	await d.say("Сулус", "Впрочем, проверим вашу логику, коллега. Слушатели никак не рассядутся по местам!")
	var answer := await d.ask("Сулус", "Прочтите условия и пересадите всех. Стрелки выбирают стул, Enter меняет двоих местами. Потом — «Готово».",
		["Проверим!", "Потом"])
	if answer == 0:
		GameState.request_minigame("sulus")
	else:
		await d.say("Сулус", "Разумеется. Логика не терпит спешки.")
