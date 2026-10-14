extends CharacterBody2D

const SPEED = 240
@onready var actionable_finder: Area2D = $Direction/ActionableFinder
@onready var direction_node: Node2D = $Direction

var input_vector: Vector2 = Vector2.ZERO
var is_in_dialogue: bool = false

func _ready():
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	
func get_input():
	var input_direction = Input.get_vector("left","right","up","down")
	velocity = input_direction * SPEED
	
	if input_direction != Vector2.ZERO:
		direction_node.rotation = input_direction.angle()
	if is_in_dialogue:
		velocity = Vector2.ZERO
		return
		
func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()

func _unhandled_input(_event: InputEvent) -> void:
	if is_in_dialogue: return
	if Input.is_action_just_pressed("enter"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()
			return
			
func _on_dialogue_started(_resourse: DialogueResource) -> void:
	is_in_dialogue = true
	print("dialogue is ", is_in_dialogue)
	
func _on_dialogue_ended(_resourse: DialogueResource) -> void:
	is_in_dialogue = false
	print("dialogue is ", is_in_dialogue)
