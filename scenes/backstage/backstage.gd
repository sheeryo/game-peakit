extends Node2D
## Закулисье музыкальной сцены: картонная ракета с «Космоса», коробки Мойто,
## прожекторы. Сюда можно зайти из хаба в любой момент — ракета заклеена.
## В финале (GameState.finale_ending не пуст) маскоты ждут у ракеты,
## игрок сам открывает её — диалог dialogue/backstage.gd (функция rocket) → итоги.

const MASCOT_SPRITE := "res://art/characters/%s.png"
## Где стоят маскоты в финале: вокруг ракеты (она в (150, -60)).
const FINALE_SPOTS := {
	"manya": Vector2(55, -15),
	"lenya": Vector2(100, 45),
	"katya": Vector2(205, 45),
	"moyto": Vector2(250, -10),
	"sulus": Vector2(265, -85),
}
## «Фестиваль удался»: Сулус в тени кулис — кто это был, загадка.
const SHADOW_SPOT := Vector2(320, -120)
const SHADOW_COLOR := Color(0.25, 0.22, 0.3)

@onready var hint_label: Label = $Hint/HintLabel


func _ready() -> void:
	Brand.style_hud_label(hint_label)
	if GameState.finale_ending == "":
		hint_label.text = "За кулисами музыкальной сцены\nTab — блокнот"
		return
	hint_label.text = "Подойди к ракете и нажми Enter"
	for mascot in FINALE_SPOTS:
		var sprite := Sprite2D.new()
		sprite.texture = load(MASCOT_SPRITE % mascot)
		sprite.centered = false
		sprite.offset = Vector2(-floorf(sprite.texture.get_width() / 2.0), -sprite.texture.get_height())
		sprite.position = FINALE_SPOTS[mascot]
		if mascot == "sulus" and GameState.finale_ending == "festival":
			sprite.position = SHADOW_SPOT
			sprite.modulate = SHADOW_COLOR
		$Mascots.add_child(sprite)
