extends PanelContainer


# "Syllable Blend" quiz (QuizGenerator.QUIZ_TYPES.PHONEME_BLEND).
# The child hears the whole word, sees its syllables shown out of order as tiles, and
# must tap them in the correct order to rebuild the word — practising blending sound
# chunks back together, the skill the literature review highlighted as the strongest
# lever for decoding (see assets/Database/Syllable-Blend.gd for the research note).


# PRELOADS & CONSTS
const _buttonLetterScene: PackedScene = preload("res://UI/Button/Letter/Button-Letter.tscn")

# SIGNALS
signal correct
signal wrong
signal completed

# VARS
@onready var _wordHint: Label = $QuizArea/VBoxContainer/WordHint
@onready var _syllableRow: HBoxContainer = $QuizArea/VBoxContainer/SyllableRow

var _word: String = ""
var _correctOrder: Array = []
var _syllableButtons: Array = []
var _progress: int = 0		# how many syllables have been correctly tapped so far


# METHODS
func _ready():
	# If the quiz scene itself is played, automatically use a freshly generated puzzle
	if OS.is_debug_build() and get_parent() == get_tree().root:
		QuizGenerator.clearQuizSets()
		QuizGenerator.generatePhonemeBlendQuizSet()
		var debugQuiz: Dictionary = QuizGenerator.getNextQuiz()
		if not debugQuiz.is_empty():
			prepareQuiz(debugQuiz.word, debugQuiz.correctOrder, debugQuiz.syllables)


func prepareQuiz(word: String, correctOrder: Array, shuffledSyllables: Array) -> void:
	_word = word
	_correctOrder = correctOrder
	_progress = 0
	_updateHint()
	_buildSyllableButtons(shuffledSyllables)
	WordAudio.playWord(word)

	print_debug("Quiz Syllable Blend: quiz prepared for '%s', syllables %s" % [word, shuffledSyllables])

# Shows how much of the word has been correctly rebuilt so far, e.g. "rab _ _"
func _updateHint() -> void:
	var pieces: Array = []
	for i in range(_correctOrder.size()):
		pieces.append(_correctOrder[i] if i < _progress else "_")
	_wordHint.text = " ".join(pieces)

func _buildSyllableButtons(shuffledSyllables: Array) -> void:
	for child in _syllableRow.get_children():
		child.queue_free()
	_syllableButtons.clear()

	for i in range(shuffledSyllables.size()):
		var button: ButtonLetter = _buttonLetterScene.instantiate()
		_syllableRow.add_child(button)
		button.setUp(shuffledSyllables[i])
		button.connect("pressed", Callable(self, "_onSyllableButtonPressed").bind(i, shuffledSyllables[i]))
		_syllableButtons.append(button)

func _onSyllableButtonPressed(index: int, syllableText: String) -> void:
	if _progress >= _correctOrder.size():
		return

	var expected: String = _correctOrder[_progress]

	if syllableText == expected:
		_syllableButtons[index].setCorrect()
		_progress += 1
		_updateHint()
		emit_signal("correct")

		if _progress == _correctOrder.size():
			print_debug("Quiz Syllable Blend: completed '%s'" % _word)
			emit_signal("completed")
	else:
		emit_signal("wrong")
		print_debug("Quiz Syllable Blend: wrong syllable '%s' for '%s'" % [syllableText, _word])

