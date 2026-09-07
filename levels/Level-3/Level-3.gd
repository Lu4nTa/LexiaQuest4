extends Level


# METHODS
func _ready():
	super._ready()
	QuizGenerator.clearQuizSets()
	QuizGenerator.generateRhymesWithQuizSet(3, 3)
	QuizGenerator.generateHangmanQuizSet(0.15)
	QuizGenerator.generateSoundBingoQuizSet(3)
	QuizGenerator.generateWritePromptQuizSet(0.3)
	QuizGenerator.randomizeQuizSets()
	setupPresentQuizzes()
