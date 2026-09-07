extends PanelContainer


# PRELOADS & CONSTS
const _buttonLetterScene: PackedScene = preload("res://UI/Button/Letter/Button-Letter.tscn")

# SIGNALS
signal correct
signal wrong
signal completed

# VARS
@onready var _wordListLabel: Label = $QuizArea/VBoxContainer/WordList
@onready var _letterGrid: GridContainer = $QuizArea/VBoxContainer/LetterGridScroll/LetterGrid
var _gridSize: int
var _letters: Array = []
var _wordsToFind: Array = []	# remaining words (Dictionaries with `word` and `path`), in find order
var _currentWordIndex: int = 0
var _selectionProgress: Array = []	# indexes already correctly selected for the current word
var _letterButtons: Array = []
var _usedIndexes: Array = []	# indexes permanently spent by already-completed words (can't be reused)

# METHODS
func _ready():
	# If the quiz scene itself is played, automatically use a freshly generated puzzle
	if OS.is_debug_build() and get_parent() == get_tree().root:
		QuizGenerator.clearQuizSets()
		QuizGenerator.generateWordSearchQuizSet(5)
		var debugQuiz: Dictionary = QuizGenerator.getNextQuiz()
		if not debugQuiz.is_empty():
			prepareQuiz(debugQuiz.gridSize, debugQuiz.letters, debugQuiz.words)

# Assigns the quiz with a letter grid and the list of words hidden inside it
# `words` is an `Array` of `Dictionaries` with `word` (`String`) and `path` (`Array` of cell indexes, in order)
func prepareQuiz(gridSize: int, letters: Array, words: Array) -> void:
	_gridSize = gridSize
	_letters = letters
	_wordsToFind = words.duplicate(true)
	_currentWordIndex = 0
	_selectionProgress.clear()
	_usedIndexes.clear()

	_letterGrid.columns = gridSize

	# Clear grid (this quiz scene is instanced once per level and reused for each activity)
	for gridChild in _letterGrid.get_children():
		gridChild.free()
	_letterButtons.clear()

	for i in range(letters.size()):
		var button: ButtonLetter = _buttonLetterScene.instantiate()
		button.setUp(String(letters[i]).to_upper())
		button.connect("pressed", Callable(self, "_onLetterButtonPressed").bind(i))
		_letterGrid.add_child(button)
		_letterButtons.append(button)

	QuizKeyboardNav.wireGridNavigation(_letterButtons, gridSize)
	_updatePrompt()

	print_debug("Quiz Word Search: prepared with %s word(s) to find" % _wordsToFind.size())

# Updates the label that tells the child which word to look for next
func _updatePrompt() -> void:
	if _currentWordIndex >= _wordsToFind.size():
		return

	var targetWord: String = _wordsToFind[_currentWordIndex].word
	_wordListLabel.text = "Encontra: %s" % targetWord.to_upper()
	WordAudio.playWord(targetWord)

# Puts a wrongly-selected letter's appearance back to normal (it stays clickable)
func _resetSelectionProgress() -> void:
	for index in _selectionProgress:
		_letterButtons[index].setUp(String(_letters[index]).to_upper())
	_selectionProgress.clear()

# SIGNAL CALLBACKS
func _onLetterButtonPressed(index: int) -> void:
	if _currentWordIndex >= _wordsToFind.size():
		return

	# Ignore clicks on cells already spent (by this word or an earlier one)
	if index in _usedIndexes or index in _selectionProgress:
		return

	var target: Dictionary = _wordsToFind[_currentWordIndex]
	var expectedLetter: String = target.word[_selectionProgress.size()]
	var pressedLetter: String = String(_letters[index])

	if pressedLetter.to_upper() == expectedLetter.to_upper():
		_selectionProgress.append(index)
		_letterButtons[index].setCorrect()
		emit_signal("correct")

		if _selectionProgress.size() == target.word.length():
			print_debug("Quiz Word Search: found word '%s'" % target.word)
			_usedIndexes.append_array(_selectionProgress)
			_selectionProgress.clear()
			_currentWordIndex += 1

			if _currentWordIndex >= _wordsToFind.size():
				emit_signal("completed")
			else:
				_updatePrompt()
	else:
		emit_signal("wrong")
		print_debug("Quiz Word Search: wrong letter for '%s'" % target.word)
		_resetSelectionProgress()
