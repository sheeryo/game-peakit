extends CharacterBody2D

const SPEED = 240
const STEP_TIME := 0.15
const BOB_PIXELS := 1.0

const TEX_RIGHT = preload("res://assets/character/mcright.png")
const TEX_LEFT = preload("res://assets/character/mcleft.png")
const TEX_UP = preload("res://assets/character/mcup.png")
const TEX_DOWN = preload("res://assets/character/mcdown.png")

@export var camera_limits := Rect2i(-713, -716, 2403, 1427)
@export var camera_zoom := Vector2.ONE

@onready var actionable_finder: Area2D = $Direction/ActionableFinder
@onready var direction_node: Node2D = $Direction
@onready var sprite: Sprite2D = $Sprite2D

var _step_time := 0.0
var _rest_position := Vector2.ZERO


func _ready() -> void:
	_rest_position = sprite.position
	var camera: Camera2D = $Camera2D
	camera.zoom = camera_zoom
	camera.limit_left = camera_limits.position.x
	camera.limit_top = camera_limits.position.y
	camera.limit_right = camera_limits.end.x
	camera.limit_bottom = camera_limits.end.y
	var in_hub: bool = get_parent().scene_file_path == GameState.HUB_SCENE
	if in_hub and GameState.hub_return_position != null:
		global_position = GameState.hub_return_position
		GameState.hub_return_position = null


func get_input() -> void:
	if GameState.in_dialogue:
		velocity = Vector2.ZERO
		return

	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * SPEED

	if input_direction != Vector2.ZERO:
		direction_node.rotation = input_direction.angle()

		if abs(input_direction.x) > abs(input_direction.y):
			if input_direction.x > 0:
				sprite.texture = TEX_RIGHT
			else:
				sprite.texture = TEX_LEFT
		else:
			if input_direction.y > 0:
				sprite.texture = TEX_DOWN
			else:
				sprite.texture = TEX_UP


func animate_step(delta: float) -> void:
	if velocity == Vector2.ZERO:
		_step_time = 0.0
		sprite.position = _rest_position
		return
	var phase_before := int(_step_time / STEP_TIME)
	_step_time += delta
	var phase := int(_step_time / STEP_TIME)
	var up := phase % 2 == 1
	sprite.position = _rest_position + (Vector2.UP * BOB_PIXELS if up else Vector2.ZERO)
	if phase != phase_before and not up:
		Sfx.play("step_%d" % (phase / 2 % 2), 0.08, -10.0)


func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
	animate_step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.in_dialogue:
		return
	if event.is_action_pressed("enter") and not event.is_echo():
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			get_viewport().set_input_as_handled()
			actionables[0].action()
