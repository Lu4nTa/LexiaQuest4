class_name StartScreenUI extends Control


# SIGNALS
signal startGame
signal exitGame

# EXPORTS
@export var enabled: bool = false: set = _setEnabled

# METHODS
func _ready():
	_setEnabled(enabled)

func _setEnabled(enabledValue: bool) -> void:
	enabled = enabledValue

	var startButton: Button = $Start/Button
	if startButton:
		startButton.disabled = not enabled
		startButton.mouse_default_cursor_shape = CURSOR_POINTING_HAND if enabled else CURSOR_ARROW
	var exitButton: Button = $Exit/Button
	if exitButton:
		exitButton.disabled = not enabled
		exitButton.mouse_default_cursor_shape = CURSOR_POINTING_HAND if enabled else CURSOR_ARROW

# SIGNAL CALLBACKS
func _on_StartButton_pressed():
	emit_signal("startGame")


func _on_ExitButton_pressed():
	emit_signal("exitGame")
