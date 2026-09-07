extends Level


# METHODS
func _ready():
	super._ready()
	QuizGenerator.clearQuizSets()
	QuizGenerator.generateStartsWithQuizSet(3, 3)
	setupPresentQuizzes()
