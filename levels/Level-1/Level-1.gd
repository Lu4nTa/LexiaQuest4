extends Level


# METHODS
func _ready():
	super._ready()
	QuizGenerator.clearQuizSets()
	QuizGenerator.generateMatchImageQuizSet()
	setupPresentQuizzes()
