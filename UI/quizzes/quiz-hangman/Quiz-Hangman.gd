extends PanelContainer


# PRELOADS & CONSTS
const _buttonLetterScene: PackedScene = preload("res://UI/Button/Letter/Button-Letter.tscn")

# SIGNALS
signal correct
signal wrong
signal completed

# EXPORTS
@export var _minNumColumns: int = 1
@export var _maxNumColumns: int = 4
@export var _debugTarget: String = "ball"
@export_range(0, 10) var _debugHintChars: int = 1
@export_range(2, 10) var _debugNumAnswers: int = 8

# VARS
@onready var _targetImage: TextureRect = $QuizArea/HBoxContainer/LeftSide/Image/TextureRect
@onready var _targetLabel: Label = $QuizArea/HBoxContainer/RightSide/VBoxContainer/Target
@onready var _answerGrid: GridContainer = $QuizArea/HBoxContainer/RightSide/VBoxContainer/Answers
var _target: String
var _missingLetters: Array = []
var _rng: RandomNumberGenerator

# METHODS
func _init():
	randomize()

func _ready():
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	# If the quiz scene itself is played, automatically use debug values
	if OS.is_debug_build() and get_parent() == get_tree().root:
		var debugHiddenTarget: String = _debugGenerateTargetWithHintLetters(_debugTarget, _debugHintChars)
		var debugAnswers: Array = _debugGenerateHangmanAnswers(_debugTarget, debugHiddenTarget, _debugNumAnswers)
		prepareQuiz(_debugTarget, debugHiddenTarget, debugAnswers)

# Generates target word with hidden characters and some hint characters
# Only used when debugging the quiz's scene
func _debugGenerateTargetWithHintLetters(targetWord: String, numOfHintChars: int) -> String:
	var shownTargetWord: String = "_".repeat(targetWord.length())
	var chosenHintCharsIndexes: Array = []

	while chosenHintCharsIndexes.size() < numOfHintChars:
		# Choose character index that hasn't been chosen yet
		var charIndex: int = _rng.randi_range(0, targetWord.length()-1)
		while chosenHintCharsIndexes.has(charIndex):
			charIndex = _rng.randi_range(0, targetWord.length()-1)

		# Display target word's character at the chosen index
		shownTargetWord[charIndex] = targetWord[charIndex]
		chosenHintCharsIndexes.append(charIndex)

	return shownTargetWord

# Generates character answers for a "Hangman" quiz
# `targetWord` is the full target word (no hidden characters)
# `hiddenTargetWord` is the version of `targetWord` with hidden characters
# `numOfAnswers` is the total number of answers (necessary correct + random wrong) to be generated
# Only used when debugging the quiz's scene
func _debugGenerateHangmanAnswers(targetWord: String, hiddenTargetWord: String, numOfAnswers: int) -> Array:
	var answerChars: Array = []	# Holds the possible answers

	# Get hint character indexes
	var hintCharIndexes: Array = _getHintCharIndexes(targetWord, hiddenTargetWord)

	# Add target word's characters to possible answers, except for the hint characters
	for i in range(0, targetWord.length()):
		if not i in hintCharIndexes:
			answerChars.append(targetWord[i])

	# Randomize and add extra characters
	var numOfExtraChars = numOfAnswers - len(answerChars)
	while numOfExtraChars:
		var randomASCII: int = _rng.randi_range(97, 122)	# ASCII values for range a-z
		answerChars.append(String.chr(randomASCII))
		numOfExtraChars -= 1

	answerChars.shuffle()
	return answerChars

# Assigns the quiz with a target word and several possible answer letters to complete the word
# Generates the quiz UI based on the provided values
# Assumes that all correct letters are provided
# `hiddenTargetWord` is a version of `targetWord` with its characters replaced with underscores, with some exceptions (the hint characters)
# `answers` contains all the characters (necessary correct + random characters)
func prepareQuiz(targetWord: String, hiddenTargetWord: String, answers: Array) -> void:
	_target = targetWord
	_targetLabel.text = hiddenTargetWord
	var imagePath: String = "res://assets/Database/Images/%s.jpg" % targetWord
	var img := Image.new()
	if img.load(imagePath) == OK:
		_targetImage.texture = ImageTexture.create_from_image(img)
	else:
		_targetImage.texture = load(imagePath)

	var hintCharIndexes: Array = _getHintCharIndexes(targetWord, hiddenTargetWord)
	_missingLetters = _getMissingLetters(targetWord, hintCharIndexes)

	# Clear answer grid
	# (this quiz scene is instanced once per level and reused for each activity)
	for gridChild in _answerGrid.get_children():
		gridChild.free()

	# Generate answer buttons and place them on the tree
	var buttonsArray: Array = _generateAnswerButtons(answers)
	for node in buttonsArray:
		_answerGrid.add_child(node)

	# Calculate new appropriate grid size (floored half of the number of answers)
	var newNumOfColumns: int = len(answers) >> 1
	if newNumOfColumns < _minNumColumns:
		newNumOfColumns = _minNumColumns
	elif newNumOfColumns > _maxNumColumns:
		newNumOfColumns = _maxNumColumns
	_answerGrid.columns = newNumOfColumns

	print_debug("Quiz Hangman: Quiz prepared with target word '%s' and revealed label '%s'" % [targetWord, _targetLabel.text])

# Creates an `Array` with the indexes of the `targetWord`'s characters that weren't hidden (the hint characters)
func _getHintCharIndexes(targetWord: String, hiddenTargetWord: String) -> Array:
	var hintCharIndexes: Array = []
	for i in targetWord.length():
		if not hiddenTargetWord[i] == '_':
			hintCharIndexes.append(i)
	return hintCharIndexes

# Creates an array with the unique letters that were *not* revealed in the target label
func _getMissingLetters(targetWord: String, hintCharIndexes: Array) -> Array:
	var missingLettersArray: Array = []
	for i in range(targetWord.length()):
		if not i in hintCharIndexes and not targetWord[i] in _missingLetters:
			missingLettersArray.append(targetWord[i])

	return missingLettersArray

func _generateAnswerButtons(answers: Array) -> Array:
	var answerButtons: Array = []	# Holds the buttons with the possible answers

	for answer in answers:
		# Generate duplicate buttons and assign them values
		var newButton: ButtonLetter = _buttonLetterScene.instantiate()
		newButton.setUp(answer)
		newButton.connect("pressed", Callable(self, "_on_AnswerButton_pressed").bind(newButton))
		answerButtons.append(newButton)

	return answerButtons

# Check if chosen character exists in the target word and is hidden in the target word's label
# Return the index of the matching letter or `-1` if none match
func _getAnswerIndexInTarget(answer: String) -> int:
	for i in range(_target.length()):
		if answer == _target[i] and _targetLabel.text[i] == "_":
			return i

	return -1

func _validateTargetIsComplete() -> bool:
	return _target == _targetLabel.text

# Reveals the unchosen answers after quiz completion
func _revealRemainingAnswers() -> void:
	for button in _answerGrid.get_children():
		if not button.disabled:
			if button.text in _missingLetters:
				button.setPossible()
			else:
				button.setWrong(false)

# SIGNAL CALLBACKS
func _on_AnswerButton_pressed(button: ButtonLetter) -> void:
	var answerIndexInTarget: int = _getAnswerIndexInTarget(button.text)
	if not answerIndexInTarget == -1:
		button.setCorrect()
		_targetLabel.text[answerIndexInTarget] = button.text	# Reveal it in target word's label
		emit_signal("correct")
		print_debug("Quiz Hangman: Letter '%s' was correct" % button.text)

		if _validateTargetIsComplete():
			_revealRemainingAnswers()
			emit_signal("completed")
			print_debug("Quiz Hangman: Target '%s' completed" % _target)
		return

	button.setWrong(true)
	emit_signal("wrong")
	print_debug("Quiz Hangman: Letter '%s' was wrong" % button.text)
