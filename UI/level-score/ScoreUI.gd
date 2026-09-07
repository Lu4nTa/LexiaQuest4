class_name ScoreUI extends PanelContainer

# VARS
var maxScore: int = 0: set = _setMaxScore
var score: int = 0: set = _setScore

@onready var _label: Label = $HBoxContainer/Label

# METHODS
func _setMaxScore(maxScoreValue: int) -> void:
	if maxScoreValue < 0:
		maxScoreValue = 0

	maxScore = maxScoreValue

	if score > maxScore:
		self.score = maxScore
	_label.text = _updateLabel()

func _setScore(scoreValue: int) -> void:
	if scoreValue < 0:
		scoreValue = 0
	elif scoreValue > maxScore:
		scoreValue = maxScore

	score = scoreValue

	_label.text = _updateLabel()

func _updateLabel() -> String:
	return "%s / %s" % [score, maxScore]
