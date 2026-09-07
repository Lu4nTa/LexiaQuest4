extends Node

# QuizKeyboardNav (autoload)
#
# Solves the "two input schemes" problem (WASD/arrows for platforming,
# mouse for quizzes) by letting quiz answers be navigated with the SAME
# keys already used to move the character, plus Enter/Space to confirm.
#
# HOW IT WORKS
# `ui_left/right/up/down` are already mapped to Arrow Keys AND W/A/S/D
# (see project.godot [input]). Godot's `BaseButton` already activates
# on the `ui_accept` action (Enter / Space / gamepad A) whenever it has
# focus. So the only missing piece was assigning `focus_neighbor_*` on
# each answer button — that's what this helper does, given the buttons
# in the order they were generated and how many columns they form.
#
# USAGE (called from a quiz's `prepareQuiz`, after answer buttons exist):
#     QuizKeyboardNav.wireGridNavigation(_answerGrid.get_children(), _answerGrid.columns)

func wireGridNavigation(buttons: Array, columns: int) -> void:
	if buttons.is_empty():
		return
	if columns <= 0:
		columns = buttons.size()

	var numRows: int = int(ceil(float(buttons.size()) / columns))

	for i in range(buttons.size()):
		var button: Control = buttons[i]
		if not (button is Control):
			continue
		button.focus_mode = Control.FOCUS_ALL

		# This division is intentionally integer (floor) division — it converts a flat
		# button index into a grid row number.
		@warning_ignore("integer_division")
		var row: int = i / columns
		var col: int = i % columns

		var leftIndex: int = row * columns + ((col - 1 + columns) % columns)
		var rightIndex: int = row * columns + ((col + 1) % columns)
		_setNeighbour(button, buttons, leftIndex, "left")
		_setNeighbour(button, buttons, rightIndex, "right")

		var upRow: int = (row - 1 + numRows) % numRows
		var downRow: int = (row + 1) % numRows
		var upIndex: int = upRow * columns + col
		if upIndex >= buttons.size():
			upIndex -= columns
		var downIndex: int = downRow * columns + col
		if downIndex >= buttons.size():
			downIndex = col
		_setNeighbour(button, buttons, upIndex, "top")
		_setNeighbour(button, buttons, downIndex, "bottom")

	# Auto-focus the first answer so keyboard-only players can start choosing immediately
	buttons[0].grab_focus()

func _setNeighbour(button: Control, buttons: Array, index: int, side: String) -> void:
	if index < 0 or index >= buttons.size():
		return
	var path: NodePath = button.get_path_to(buttons[index])
	match side:
		"left":
			button.focus_neighbor_left = path
		"right":
			button.focus_neighbor_right = path
		"top":
			button.focus_neighbor_top = path
		"bottom":
			button.focus_neighbor_bottom = path
