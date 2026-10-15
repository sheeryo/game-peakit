extends "res://scenes/ui/intro.gd"
## Кат-сцена концовки: игрок открыл ракету за кулисами (dialogue/backstage.gd).
## Кадры — рисунки дизайнера команды (art/cutscene/finale_*.png, 150×75, ×3):
## маскоты по очереди в луче прожектора. Какая концовка — GameState.finale_ending.
## Enter — дальше, Esc — пропустить. Потом — итоги финала (scenes/finale/).

const MANYA := preload("res://art/cutscene/finale_manya.png")
const LENYA := preload("res://art/cutscene/finale_lenya.png")
const KATYA := preload("res://art/cutscene/finale_katya.png")
const MOYTO := preload("res://art/cutscene/finale_moyto.png")
const SULUS := preload("res://art/cutscene/finale_sulus.png")
## «Фестиваль удался»: Сулус в тени кулис — кто это был, загадка.
const SHADOW := Color(0.42, 0.36, 0.48)


func _ready() -> void:
	slides = [
		[MANYA, "Маня: Ой, солнышко, Капсула нашлась! Пластинка, красный нос, картонный шлем — всё на месте!"],
		[LENYA, "Леня: Чувствуешь? Теперь фестиваль звучит как надо."],
		[KATYA, "Катя: Все на подиум! Фестиваль «Детектив» открывается!"],
		[MOYTO, "Мойто: Ура-а! Конкурсы, призы — всё начинается!"],
	]
	if GameState.finale_ending == "festival":
		slides.append([SULUS, "А в тени кулис кто-то с рогами довольно кивает…", SHADOW])
		slides.append([SULUS, "Кто это был? Это так и осталось загадкой.", SHADOW])
	else:
		slides.append([SULUS, "Сулус: Браво, детектив! Признаюсь, Капсулу спрятал я."])
		slides.append([SULUS, "Сулус: Фестиваль «Детектив» должен начинаться с настоящей загадки. Это была проверка, и вы её прошли!"])
		slides.append([SULUS, "Сулус: Объявляю вас почётным детективом Хотона!"])
		slides.append([SULUS, "Ты кладёшь лупу в Капсулу, рядом с пластинкой, красным носом и картонным шлемом."])
		if GameState.finale_ending == "perfect":
			slides.append([SULUS, "Сулус: И ещё кое-что, коллега. У Капсулы двойное дно."])
			slides.append([MANYA, "Внутри — письмо с самого первого фестиваля Хотона, 2023 года. Маскоты читают его вместе и улыбаются."])
			slides.append([SULUS, "Твоё расследование впишут в Книгу детективов Хотона."])
		elif GameState.finale_why:
			slides.append([SULUS, "Сулус: Впрочем, кое-какие секреты наши друзья вам ещё не рассказали…"])
	super()


func _done() -> void:
	set_process_unhandled_input(false)
	# finale_ending уже задан — финал сразу покажет итоги
	get_tree().change_scene_to_file(GameState.FINALE_SCENE)
