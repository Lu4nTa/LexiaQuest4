class_name Present extends Node2D


# SIGNALS
signal opened
signal collected

# EXPORTS
@export_range(0, 64) var _spriteHoverLimit: int = 20
@export_range(0, 10) var _spriteHoverSpeed: float = 0.5

# CONSTS
const _quizPaths: Dictionary = {
	matchImage = "res://UI/quizzes/quiz-four-choices/Quiz-FourChoices.tscn",
	matchWord = "res://UI/quizzes/syllables/Quiz-Syllables.tscn",
	hangman = "res://UI/quizzes/quiz-hangman/Quiz-Hangman.tscn",
	soundBingo = "res://UI/quizzes/quiz-four-choices/Quiz-FourChoices.tscn",
	writePrompt = "res://UI/quizzes/quiz-write-prompt/Quiz-WritePrompt.tscn",
	wordSearch = "res://UI/quizzes/quiz-word-search/Quiz-WordSearch.tscn",
	phonemeBlend = "res://UI/quizzes/quiz-phoneme-blend/Quiz-PhonemeBlend.tscn",
	customChoice = "res://UI/quizzes/quiz-four-choices/Quiz-FourChoices.tscn",
	audioSequence = "res://UI/quizzes/quiz-four-choices/Quiz-FourChoices.tscn",
	rhymesWithImage = "res://UI/quizzes/quiz-four-choices/Quiz-FourChoices.tscn"
}

# VARS
var quiz: Dictionary = {}: set = _setQuiz

@onready var _sprite: Sprite2D = $Sprite
@onready var _quizNodes: Dictionary = {}
var _spriteHoverDirection: int = 1
var _quiz_open: bool = false
var _quiz_player: Player = null

# METHODS
func _process(_delta):
	_spriteHoverProcess()

func _spriteHoverProcess() -> void:
	if not is_instance_valid(_sprite):
		return

	_sprite.offset.y += _spriteHoverSpeed if _spriteHoverDirection == 1 else -_spriteHoverSpeed

	if ((_spriteHoverDirection == 1 and _spriteHoverLimit <= _sprite.offset.y)
	or (_spriteHoverDirection == -1 and -_spriteHoverLimit >= _sprite.offset.y)):
		_spriteHoverDirection = -_spriteHoverDirection

func _setQuiz(quizValue: Dictionary) -> void:
	quiz = quizValue

	var quizNode
	match quiz.quizType:
		QuizGenerator.QUIZ_TYPES.MATCH_IMAGE:
			quizNode = load(_quizPaths.matchImage).instantiate()
			_quizNodes.matchImage = quizNode

		QuizGenerator.QUIZ_TYPES.STARTS_WITH, QuizGenerator.QUIZ_TYPES.RHYMES_WITH:
			quizNode = load(_quizPaths.matchWord).instantiate()
			_quizNodes.matchWord = quizNode

		QuizGenerator.QUIZ_TYPES.HANGMAN:
			quizNode = load(_quizPaths.hangman).instantiate()
			_quizNodes.hangman = quizNode

		QuizGenerator.QUIZ_TYPES.SOUND_BINGO:
			quizNode = load(_quizPaths.soundBingo).instantiate()
			_quizNodes.soundBingo = quizNode

		QuizGenerator.QUIZ_TYPES.WRITE_PROMPT:
			quizNode = load(_quizPaths.writePrompt).instantiate()
			_quizNodes.writePrompt = quizNode

		QuizGenerator.QUIZ_TYPES.WORD_SEARCH:
			quizNode = load(_quizPaths.wordSearch).instantiate()
			_quizNodes.wordSearch = quizNode

		QuizGenerator.QUIZ_TYPES.PHONEME_BLEND:
			quizNode = load(_quizPaths.phonemeBlend).instantiate()
			_quizNodes.phonemeBlend = quizNode

		QuizGenerator.QUIZ_TYPES.CUSTOM_CHOICE:
			quizNode = load(_quizPaths.customChoice).instantiate()
			_quizNodes.customChoice = quizNode

		QuizGenerator.QUIZ_TYPES.AUDIO_SEQUENCE:
			quizNode = load(_quizPaths.audioSequence).instantiate()
			_quizNodes.audioSequence = quizNode

		QuizGenerator.QUIZ_TYPES.RHYMES_WITH_IMAGE:
			quizNode = load(_quizPaths.rhymesWithImage).instantiate()
			_quizNodes.rhymesWithImage = quizNode

		_:
			assert(false, "The value '%s' does not exist in 'QuizGenerator.QUIZ_TYPES'" % quiz.quizType)

	quizNode.visible = false
	quizNode.connect("correct", Callable(self, "_onQuizCorrectAnswer"))
	quizNode.connect("wrong", Callable(self, "_onQuizWrongAnswer"))
	quizNode.connect("completed", Callable(self, "_onQuizCompleted").bind(quizNode))
	$CanvasLayer.add_child(quizNode)

# SIGNAL CALLBACKS
func _onPlayerTouched(_body: Node):
	if quiz.is_empty() or not (_body is Player) or _quiz_open:
		return

	_quiz_open = true
	# Store the exact player that opened this present and lock it BEFORE any
	# quiz UI/audio work starts. The Present also unlocks this player directly
	# when the quiz closes, so we do not depend on Level signal ordering.
	_quiz_player = _body as Player
	_quiz_player.lock_for_quiz()

	$OpenSFX.play()
	emit_signal("opened")

	match quiz.quizType:
		QuizGenerator.QUIZ_TYPES.MATCH_IMAGE:
			_quizNodes.matchImage.prepareQuiz(quiz.target, quiz.extraAnswers)
			_quizNodes.matchImage.visible = true

		QuizGenerator.QUIZ_TYPES.STARTS_WITH:
			_quizNodes.matchWord.prepareQuiz(quiz.target, quiz.correctAnswers, quiz.wrongAnswers, quiz.quizType)
			_quizNodes.matchWord.visible = true

		QuizGenerator.QUIZ_TYPES.RHYMES_WITH:
			_quizNodes.matchWord.prepareQuiz(quiz.target, quiz.correctAnswers, quiz.wrongAnswers, quiz.quizType)
			_quizNodes.matchWord.visible = true

		QuizGenerator.QUIZ_TYPES.HANGMAN:
			_quizNodes.hangman.prepareQuiz(quiz.target, quiz.hiddenTarget, quiz.answers)
			_quizNodes.hangman.visible = true

		QuizGenerator.QUIZ_TYPES.SOUND_BINGO:
			_quizNodes.soundBingo.prepareAudioQuiz(quiz.promptWord, quiz.target, quiz.wrongAnswers)
			_quizNodes.soundBingo.visible = true

		QuizGenerator.QUIZ_TYPES.WRITE_PROMPT:
			_quizNodes.writePrompt.prepareQuiz(quiz.target, quiz.numOfHintChars)
			_quizNodes.writePrompt.visible = true

		QuizGenerator.QUIZ_TYPES.WORD_SEARCH:
			_quizNodes.wordSearch.prepareQuiz(quiz.gridSize, quiz.letters, quiz.words)
			_quizNodes.wordSearch.visible = true

		QuizGenerator.QUIZ_TYPES.PHONEME_BLEND:
			_quizNodes.phonemeBlend.prepareQuiz(quiz.word, quiz.correctOrder, quiz.syllables)
			_quizNodes.phonemeBlend.visible = true

		QuizGenerator.QUIZ_TYPES.CUSTOM_CHOICE:
			_quizNodes.customChoice.prepareCustomChoiceQuiz(quiz.question, quiz.options, quiz.correctIndex)
			_quizNodes.customChoice.visible = true

		QuizGenerator.QUIZ_TYPES.AUDIO_SEQUENCE:
			_quizNodes.audioSequence.prepareSequenceQuiz(quiz.sequence, quiz.options, quiz.correctIndex)
			_quizNodes.audioSequence.visible = true

		QuizGenerator.QUIZ_TYPES.RHYMES_WITH_IMAGE:
			_quizNodes.rhymesWithImage.prepareQuiz(quiz.target, quiz.wrongAnswers, quiz.get("question", ""), quiz.image)
			_quizNodes.rhymesWithImage.visible = true

		_:
			assert(false, "The value '%s' does not exist in 'QuizGenerator.QUIZ_TYPES'" % quiz.quizType)

func _onQuizCorrectAnswer():
	$CorrectSFX.play()

func _onQuizWrongAnswer():
	$WrongSFX.play()

func _onQuizCompleted(quizNode):
	# Close the quiz first, then immediately release the player. The previous
	# implementation waited on a 2-second timer before unlocking, which made
	# the player appear permanently frozen after a correct answer.
	quizNode.visible = false
	quizNode.queue_free()

	if is_instance_valid(_quiz_player):
		_quiz_player.unlock_from_quiz()

	$CollectedSFX.play()
	$Area2D.queue_free()
	$Sprite.texture = load("res://assets/Sprites/presents/Present-Open.png")
	_quiz_player = null
	_quiz_open = false
	emit_signal("collected")
