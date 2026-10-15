extends RefCounted
## Главная сцена: вход в финал «Я знаю разгадку!».


func start(d: DialogueBox) -> void:
	if not GameState.can_open_finale():
		await d.say("", "Главная сцена. Здесь откроют фестиваль, когда найдётся Капсула.")
		await d.say("", "Чтобы разгадать тайну, нужно три печати. В блокноте сейчас %d." % GameState.stamp_count())
		await d.say("", "Загляни к маскотам и помоги им!")
		return

	await d.say("", "Главная сцена. Над ней горит табличка «Я знаю разгадку!»")
	var answer := await d.ask("", "Маскоты уже собираются вокруг. Готов назвать разгадку?",
		["Я знаю разгадку!", "Ещё поищу улики"])
	if answer == 0:
		GameState.request_finale()
