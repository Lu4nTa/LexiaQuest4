extends PanelContainer


# PRELOADS & CONSTS
const _buttonQuizScene: PackedScene = preload("res://UI/Button/Quiz/Button-Quiz.tscn")

# SIGNALS
signal correct
signal wrong
signal completed

# EXPORTS
@export var _startsWithText: String = "Seleciona as palavras que comecem com:"
@export var _rhymesWithText: String = "Seleciona as palavras que rimem com:"
@export var _minNumColumns: int = 1	# TODO
@export var _maxNumColumns: int = 4	# TODO
@export var _debugTarget: String = "fa"
@export var _debugCorrectAnswers: Array = [
	"family",
	"favourite",
	"father"
]
@export var _debugWrongAnswers: Array = [
	"language",
	"feather",
	"football"
]

# VARS
@onready var _explanationLabel: RichTextLabel = $QuizArea/VBoxContainer/Exercise/Explanation
@onready var _targetLabel: RichTextLabel = $QuizArea/VBoxContainer/Exercise/Target
@onready var _answerGrid: GridContainer = $QuizArea/VBoxContainer/Answers
var _numCorrectAnswersLeft: int

func _init():
	randomize()

func _ready():
	# If the quiz scene itself is played, automatically use debug values
	if OS.is_debug_build() and get_parent() == get_tree().root:
		prepareQuiz(_debugTarget, _debugCorrectAnswers, _debugWrongAnswers, QuizGenerator.QUIZ_TYPES.STARTS_WITH)

# Assigns the quiz with a target word part and several possible answers
# Generates the quiz UI based on the provided values
# Assumes that at least 1 of the provided answers is correct
# Expects the elements of `correctAnswers` and `wrongAnswers` to be of type `String`
# `quizType` must be one of the values in the `SYLLABLES_QUIZ_TYPES` enumeration
func prepareQuiz(targetWordPart: String, correctAnswers: Array, wrongAnswers: Array, quizType) -> void:
	_targetLabel.bbcode_text = "[center][b]%s[/b][/center]" % targetWordPart
	_numCorrectAnswersLeft = len(correctAnswers)

	# Set explanation label's content
	match quizType:
		QuizGenerator.QUIZ_TYPES.STARTS_WITH:
			_explanationLabel.bbcode_text = "[center]%s[/center]" % _startsWithText

		QuizGenerator.QUIZ_TYPES.RHYMES_WITH:
			_explanationLabel.bbcode_text = "[center]%s[/center]" % _rhymesWithText

		QuizGenerator.QUIZ_TYPES.MATCH_IMAGE, QuizGenerator.QUIZ_TYPES.HANGMAN:
			assert(false, "The value '%s' from 'QuizGenerator.QUIZ_TYPES' can't be used in 'Quiz-Syllables'" % quizType)

		_:
			assert(false, "The value '%s' does not exist in 'QuizGenerator.QUIZ_TYPES'" % quizType)

	# Clear answer grid
	# (this quiz scene is instanced once per level and reused for each activity)
	for gridChild in _answerGrid.get_children():
		gridChild.free()

	# Generate answer buttons and place them on the tree
	var buttonsArray: Array = _generateAnswerButtons(correctAnswers, wrongAnswers)
	for node in buttonsArray:
		_answerGrid.add_child(node)

	print_debug("Quiz Syllables: Quiz prepared with target syllable '%s'" % targetWordPart)

# Instance `Button-Quiz` scenes and assign them the provided answers
func _generateAnswerButtons(correctAnswers: Array, wrongAnswers: Array) -> Array:
	var answerButtons: Array = []

	for answer in correctAnswers:
		var newButton: ButtonQuiz = _buttonQuizScene.instantiate()
		newButton.text = answer
		newButton.isCorrect = true
		newButton.connect("pressed", Callable(self, "_on_AnswerButton_pressed").bind(newButton))
		answerButtons.append(newButton)

	for answer in wrongAnswers:
		var newButton: ButtonQuiz = _buttonQuizScene.instantiate()
		newButton.text = answer
		newButton.isCorrect = false
		newButton.connect("pressed", Callable(self, "_on_AnswerButton_pressed").bind(newButton))
		answerButtons.append(newButton)

	answerButtons.shuffle()
	return answerButtons

func _validateAnswer(button: ButtonQuiz) -> bool:
	return button.isCorrect

# Reveals the unchosen wrong answers after quiz completion
func _revealRemainingAnswers() -> void:
	for button in _answerGrid.get_children():
		if not button.disabled:
			button.revealState(false)

# SIGNAL CALLBACKS
func _on_AnswerButton_pressed(button: ButtonQuiz) -> void:
	button.revealState(true)

	if _validateAnswer(button):
		_numCorrectAnswersLeft -= 1
		emit_signal("correct")
		print_debug("Quiz Syllables: Answer '%s' was correct" % button.text)

		if not _numCorrectAnswersLeft:
			_revealRemainingAnswers()
			emit_signal("completed")
			print_debug("Quiz Syllables: Quiz complete")
	else:
		emit_signal("wrong")
		print_debug("Quiz Syllables: Answer '%s' was wrong" % button.text)
