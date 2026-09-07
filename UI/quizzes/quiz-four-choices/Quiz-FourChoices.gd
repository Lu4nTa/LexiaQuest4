extends PanelContainer


# PRELOADS & CONSTS

# SIGNALS
signal correct
signal wrong
signal completed

# EXPORTS
@export var _debugTarget: String = "ball"
@export var _debugExtraAnswers: Array[String] = ["bull", "beach", "tall"]

# VARS
@onready var _explanation: RichTextLabel = $QuizArea/VBoxContainer/Explanation
@onready var _targetImage: TextureRect = $QuizArea/VBoxContainer/HBoxContainer/Image/TextureRect
@onready var _answerList: VBoxContainer = $QuizArea/VBoxContainer/HBoxContainer/Answers
var _target: String
var _audioMode: bool = false	# true when showing an audio prompt (Sound Bingo) instead of an image
var _promptWordForAudio: String = ""	# word whose pronunciation is played as the quiz prompt

const _IMAGE_MODE_EXPLANATION: String = "[center]Seleciona a palavra que representa a imagem[/center]"
const _AUDIO_MODE_EXPLANATION: String = "[center]Ouve o som e escolhe a resposta correta[/center]"
const _SEQUENCE_MODE_EXPLANATION: String = "[center]Ouve a sequência de sons e escolhe a ordem correta[/center]"

# METHODS
func _init():
	randomize()

func _ready():
	_setButtonSignalConnections()

	# If the quiz scene itself is played, automatically use debug values
	if OS.is_debug_build() and get_parent() == get_tree().root:
		prepareQuiz(_debugTarget, _debugExtraAnswers)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	var answerButtons: Array = _answerList.get_children()
	for i in range(answerButtons.size()):
		if event.is_action_pressed("quiz_choice_%s" % (i + 1)):
			_on_AnswerButton_pressed(answerButtons[i])
			return

func _setButtonSignalConnections() -> void:
	for button in _answerList.get_children():
		button.connect("pressed", Callable(self, "_on_AnswerButton_pressed").bind(button))

# Resets every optional element to its default hidden state. Called at the start of
# every `prepareX()` method, so switching from one quiz type/instance to the next never
# leaves a stray replay button or image visible.
func _resetOptionalUI() -> void:
	_targetImage.visible = false

# Sets the question/explanation text AND forces its wrap width from the ACTUAL current
# viewport size, instead of trusting the Control's inherited/editor-time size.
#
# Why this exists: `bbcode_text` is set the instant a quiz opens, which can be before
# the surrounding Containers have finished their first real layout pass on THIS
# specific viewport (this scene is instanced at runtime into a CanvasLayer, not run
# standalone) — a RichTextLabel wraps text using whatever `size.x` it has at that exact
# moment, so if that's stale it can compute wrapping for the wrong width and the result
# spills off-screen instead of wrapping. Setting `size.x` explicitly, from the real
# viewport, removes that guesswork entirely: dyslexic readers need the FULL sentence
# visible, never cut off, so this cannot be left to layout timing.
func _setExplanationText(bbcodeText: String) -> void:
	var margins: float = 120.0	# QuizArea's left+right theme margins (50 + 50) plus a little breathing room
	var availableWidth: float = get_viewport_rect().size.x - margins
	if availableWidth < 200.0:	# sanity floor — never collapse to an unreadably narrow column
		availableWidth = 200.0

	_explanation.custom_minimum_size.x = availableWidth
	_explanation.size.x = availableWidth
	_explanation.bbcode_text = bbcodeText

# Assigns the quiz with a target word/image and several possible answers
# Generates the quiz UI based on the provided values
# Assumes that the provided target word has a matching image asset
# Expects the elements of `extraAnswersArray` to be of type `String`
# `imageWord`: optional — if set, the picture shown is for THIS word instead of
#              `targetWord` (used by the "Rhymes With Image" quiz, where the picture and
#              the correct answer are two different words)
# `questionText`: optional — overrides the default "Seleciona a palavra..." explanation
func prepareQuiz(targetWord: String, extraAnswersArray: Array, questionText: String = "", imageWord: String = "") -> void:
	_resetOptionalUI()
	_audioMode = false
	_target = targetWord
	var wordForImageAndAudio: String = imageWord if imageWord != "" else targetWord
	_promptWordForAudio = wordForImageAndAudio
	_targetImage.visible = true
	_setExplanationText(("[center]%s[/center]" % questionText) if questionText != "" else _IMAGE_MODE_EXPLANATION)

	_targetImage.texture = _loadImageTexture(wordForImageAndAudio)
	_targetImage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_targetImage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_prepareAnswers(targetWord, extraAnswersArray)

	if questionText.to_lower().contains("listen"):
		WordAudio.speakText(questionText)
	else:
		WordAudio.playWord(wordForImageAndAudio)	# Hear the word as soon as the quiz opens

	print_debug("Quiz Four Choices: Quiz prepared with _target word/image '%s'" % targetWord)

# Tries `res://assets/Database/Images/<word>.png` first, then `.jpg`, so hand-uploaded
# PNGs (which is what most of these images arrive as) don't need converting.
func _loadImageTexture(word: String) -> Texture2D:
	for extension in ["png", "jpg"]:
		var path: String = "res://assets/Database/Images/%s.%s" % [word, extension]
		if ResourceLoader.exists(path):
			return load(path)

	push_warning("Quiz Four Choices: no image found for '%s' (checked .png and .jpg)" % word)
	return null

# Audio-prompt variant used by the "Sound Bingo" quiz: instead of an image, the child
# hears `promptWord`'s pronunciation and must pick the matching letter/digraph (`correctAnswer`)
func prepareAudioQuiz(promptWord: String, correctAnswer: String, wrongAnswers: Array) -> void:
	_resetOptionalUI()
	_audioMode = true
	_target = correctAnswer
	_promptWordForAudio = promptWord
	_setExplanationText(_AUDIO_MODE_EXPLANATION)

	_prepareAnswers(correctAnswer, wrongAnswers)
	WordAudio.playWord(promptWord)

	print_debug("Quiz Four Choices (audio mode): Quiz prepared for sound in '%s', target letter(s) '%s'" % [promptWord, correctAnswer])

# "Custom Choice" variant: a fully hand-authored question (own question text, own
# options, own correct answer) — no image, no audio prompt (unless the question is
# phrased as a listening prompt, in which case it's read aloud via TTS). Used for the
# mirror-letter (b/d/p/q) drills, the "spot the different letter" search, and the
# Level 10 word-maze challenges.
func prepareCustomChoiceQuiz(question: String, options: Array, correctIndex: int) -> void:
	_resetOptionalUI()
	_audioMode = false
	_promptWordForAudio = ""
	_setExplanationText("[center]%s[/center]" % question)
	_target = options[correctIndex]

	var wrongAnswers: Array = options.duplicate()
	wrongAnswers.remove_at(correctIndex)
	_prepareAnswers(_target, wrongAnswers)

	# Questions phrased as a listening prompt ("Listen...") get read aloud via TTS —
	# these have no image/audio prompt of their own otherwise, so without this they'd be
	# a "Listen and answer" quiz with nothing to actually listen to.
	if question.to_lower().contains("listen"):
		WordAudio.speakText(question)

	print_debug("Quiz Four Choices (custom choice): '%s' — correct answer '%s'" % [question, _target])

# "Audio Sequence" variant: plays each letter/word in `sequence` one after another, then
# shows a small "repeat" button (🔊) the child can tap as many times as needed before
# answering, plus the usual MC options describing possible orderings.
func prepareSequenceQuiz(sequence: Array, options: Array, correctIndex: int) -> void:
	_resetOptionalUI()
	_audioMode = true	# reuses the "P" key / no-image layout, same as Sound Bingo
	_promptWordForAudio = ""
	_setExplanationText(_SEQUENCE_MODE_EXPLANATION)
	_target = options[correctIndex]

	var wrongAnswers: Array = options.duplicate()
	wrongAnswers.remove_at(correctIndex)
	_prepareAnswers(_target, wrongAnswers)

	WordAudio.playSequence(sequence)

	print_debug("Quiz Four Choices (audio sequence): sequence %s — correct answer '%s'" % [sequence, _target])

# Shared answer-button setup used by every `prepareX()` method
func _prepareAnswers(targetAnswer: String, extraAnswersArray: Array) -> void:
	var allAnswers: Array = extraAnswersArray.duplicate()
	allAnswers.append(targetAnswer)

	allAnswers.shuffle()
	var answerButtons: Array = _answerList.get_children()
	for i in range(min(4, allAnswers.size())):
		var answer: String = allAnswers[i]
		var buttonQuiz: ButtonQuiz = answerButtons[i]
		buttonQuiz.setUp(answer, answer == targetAnswer)

	# Let players answer with arrow keys + Enter/Space, same as moving the character
	QuizKeyboardNav.wireGridNavigation(answerButtons, 1)

func _validateAnswer(button: ButtonQuiz) -> bool:
	return button.isCorrect

# Reveals the unchosen wrong answers after quiz completion
func _revealRemainingAnswers() -> void:
	for buttonQuiz in _answerList.get_children():
		if not buttonQuiz.disabled:
			buttonQuiz.revealState(false)

# SIGNAL CALLBACKS
func _on_AnswerButton_pressed(button: ButtonQuiz) -> void:
	button.revealState(true)

	if _validateAnswer(button):
		_revealRemainingAnswers()
		emit_signal("correct")
		emit_signal("completed")
		print_debug("Quiz Four Choices: Answer '%s' was correct" % button.text)
	else:
		emit_signal("wrong")
		print_debug("Quiz Four Choices: Answer '%s' was wrong" % button.text)

