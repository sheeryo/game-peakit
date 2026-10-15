extends CanvasLayer

@onready var stamps_label: Label = $StampsLabel


func _ready() -> void:
	Brand.style_hud_label(stamps_label)
	GameState.stamp_added.connect(_on_stamp_added)
	update_text()


func _on_stamp_added(_mascot: String) -> void:
	update_text()


func update_text() -> void:
	var text := "Печати: %d / %d" % [GameState.stamp_count(), GameState.MASCOTS.size()]

	if GameState.can_open_finale():
		text += "\nМожно идти к главной сцене!"

	stamps_label.text = text
