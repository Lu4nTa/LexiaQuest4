class_name EndScreenUI extends Control


# SIGNALS
signal nextLevel
signal restartLevel
signal backToStartScreen

# EXPORTS
@export var enabled: bool = false: set = _setEnabled
@export_multiline var message: String = "Your message here...": set = _setMessage
@export var showNextLevelButton: bool = true: set = _setShowNextLevelButton

# VARS
@onready var _messageLabel: RichTextLabel = $VBoxContainer/MarginContainer/Message
@onready var _nextLevelButton: Button = $VBoxContainer/Options/Next
@onready var _restartLevelButton: Button = $VBoxContainer/Options/Restart
@onready var _backButton: Button = $VBoxContainer/Options/Back

# METHODS
func _ready():
	# Call setters
	# (UI nodes won't be affected if setters are called before they're ready,
	# which can happen if exported variables have non-default values)
	_setEnabled(enabled)
	_setMessage(message)
	_setShowNextLevelButton(showNextLevelButton)

func _setMessage(messageValue: String) -> void:
	message = messageValue

	if _messageLabel:
		_messageLabel.bbcode_text = "[center]%s[/center]" % message

func _setShowNextLevelButton(showNextLevelButtonValue: bool) -> void:
	showNextLevelButton = showNextLevelButtonValue

	if _nextLevelButton:
		_nextLevelButton.visible = showNextLevelButton

func _setEnabled(enabledValue: bool) -> void:
	enabled = enabledValue

	if _nextLevelButton:
		_nextLevelButton.disabled = not enabled
		_nextLevelButton.mouse_default_cursor_shape = CURSOR_POINTING_HAND if enabled else CURSOR_ARROW
	if _restartLevelButton:
		_restartLevelButton.disabled = not enabled
		_restartLevelButton.mouse_default_cursor_shape = CURSOR_POINTING_HAND if enabled else CURSOR_ARROW
	if _backButton:
		_backButton.disabled = not enabled
		_backButton.mouse_default_cursor_shape = CURSOR_POINTING_HAND if enabled else CURSOR_ARROW

func _on_Next_pressed():
	emit_signal("nextLevel")

func _on_Restart_pressed():
	emit_signal("restartLevel")

func _on_Back_pressed():
	emit_signal("backToStartScreen")
