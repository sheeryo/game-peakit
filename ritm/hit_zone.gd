extends ColorRect
var key_letters = ["D", "F", "J", "K"]
var lane = 0
var base_color = Color(1, 1, 1, 0.25)   # обычный вид
var flash_color = Color(1, 1, 1, 0.8)    # при нажатии
var flash_timer = 0.0

func _ready():
	color = base_color
	$Label1.text = "e213123"+key_letters[lane]

func _process(delta):
	# Плавно возвращаем цвет обратно после вспышки
	if flash_timer > 0:
		flash_timer -= delta
		color = base_color.lerp(flash_color, flash_timer / 0.15)
	else:
		color = base_color

func flash():
	flash_timer = 0.15
	color = flash_color
