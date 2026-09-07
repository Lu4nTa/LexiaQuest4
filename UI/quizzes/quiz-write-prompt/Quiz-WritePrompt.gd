extends PanelContainer


# PRELOADS & CONSTS

# SIGNALS
signal correct
signal wrong
signal completed

# EXPORTS
@export var debugTarget: String = "ball"
@export_range(0, 10) var debugHintChars: int = 1

# VARS
@onready var targetImage: TextureRect = $QuizArea/HBoxContainer/LeftSide/Image/TextureRect
@onready var targetLabel: Label = $QuizArea/HBoxContainer/RightSide/VBoxContainer/Target
@onready var answerLine: LineEdit = $QuizArea/HBoxContainer/RightSide/VBoxContainer/Answer
var target: String

func _ready():
	_setFocus()

	if OS.is_debug_build() and get_parent() == get_tree().root:
		prepareQuiz(debugTarget, debugHintChars)

func prepareQuiz(targetWord: String, numOfHintChars: int) -> void:
	self.target = targetWord

	# Set target image
	var imagePath: String = "res://assets/Database/Images/%s.jpg" % targetWord
	targetImage.texture = load(imagePath)
	targetImage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	targetImage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# Restrict `numOfHintChars` and set target word display with random hint characters
	var targetHalfLength: int = target.length() >> 1
	if numOfHintChars < 0:
		numOfHintChars = 0
	elif numOfHintChars > targetHalfLength:
		numOfHintChars = targetHalfLength
	targetLabel.text = _generateTargetWithHintLetters(targetWord, numOfHintChars)
	WordAudio.playWord(targetWord)	# Hear the word as soon as the quiz opens

func _generateTargetWithHintLetters(targetWord: String, numOfHintChars: int) -> String:
	var shownTargetWord: String = "_".repeat(targetWord.length())
	var chosenHintCharsIndexes: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	while chosenHintCharsIndexes.size() < numOfHintChars:
		# Choose character index that hasn't been chosen yet
		var charIndex: int = rng.randi_range(0, targetWord.length()-1)
		while chosenHintCharsIndexes.has(charIndex):
			charIndex = rng.randi_range(0, targetWord.length()-1)

		# Display target word's character at the chosen index
		shownTargetWord[charIndex] = targetWord[charIndex]
		chosenHintCharsIndexes.append(charIndex)

	return shownTargetWord

func _setFocus() -> void:
	answerLine.grab_focus()

func _validateAnswer() -> bool:
	return answerLine.text == target

func _on_Answer_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action_pressed("ui_accept"):
			if _validateAnswer():
				emit_signal("correct")
				emit_signal("completed")

				print_debug("Quiz Write Prompt was correct")
			else:
				emit_signal("wrong")

				print_debug("Quiz Write Prompt was wrong")
