extends Node2D

# Список логических задач
var questions = [
	{
		"question": "У отца Мэри 5 дочерей: Чача, Чече, Чичи, Чочо. Как зовут пятую?",
		"options": ["Чучу", "Мэри", "Алиса", "Маша"],
		"correct": 1 # Индекс правильного ответа (Мэри)
	},
	{
		"question": "Что всегда идет вперед и никогда не возвращается назад?",
		"options": ["Время", "Поезд", "Река", "Ветер"],
		"correct": 0
	},
	{
		"question": "Шел человек в город, а навстречу ему три товарища. Сколько человек шли в город?",
		"options": ["Четыре", "Один", "Три", "Ни одного"],
		"correct": 1 # Иллюзия: шли только навстречу, а человек один
	}
]

var current_index = 0

@onready var question_label = $QuestionLabel
@onready var buttons = [$VBoxContainer/Button, $VBoxContainer/Button2, $VBoxContainer/Button3, $VBoxContainer/Button4]
@onready var feedback_label = $FeedbackLabel

func _ready():
	load_question()

	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_answer_pressed.bind(i))

func load_question():
	if current_index < questions.size():
		var q = questions[current_index]
		question_label.text = q.question
		feedback_label.text = ""
		for i in range(buttons.size()):
			buttons[i].text = q.options[i]
	else:
		GameState.complete_minigame("puzzle")
		GameState.add_stamp("sulus")
		
		print("Все логические задачи решены!")
		get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_answer_pressed(index):
	var q = questions[current_index]
	if index == q.correct:
		feedback_label.text = "Верно!"
		current_index += 1
		# Делаем небольшую паузу перед следующим вопросом или сразу загружаем
		await get_tree().create_timer(0.8).timeout
		load_question()
	else:
		feedback_label.text = "Неправильно, попробуй еще раз!"
