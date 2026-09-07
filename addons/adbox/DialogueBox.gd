"""
 _______
|   _   |
|  |_|  |
|       |
|       |
|   _   |
|__| |__|
 ______   ___   _______  ___      _______  _______  __   __  _______
|      | |   | |   _   ||   |    |       ||       ||  | |  ||       |
|  _    ||   | |  |_|  ||   |    |   _   ||    ___||  | |  ||    ___|
| | |   ||   | |       ||   |    |  | |  ||   | __ |  |_|  ||   |___
| |_|   ||   | |       ||   |___ |  |_|  ||   ||  ||       ||    ___|
|       ||   | |   _   ||       ||       ||   |_| ||       ||   |___
|______| |___| |__| |__||_______||_______||_______||_______||_______|
 _______  _______  __   __
|  _    ||       ||  |_|  |
| |_|   ||   _   ||       |
|       ||  | |  ||       |
|  _   | |  |_|  | |     |
| |_|   ||       ||   _   |
|_______||_______||__| |__|

Easy to use dialogue box for all kind of games with not many features
Follow the tutorial in README.md to implement

v. 0.1

Author: Max Schmitt
		from
		Divirad - Kepper, Lösing, Schmitt GbR
"""

@icon("res://addons/adbox/icon.png")
extends NinePatchRect
class_name DialogueBox

@export var message_sound: AudioStreamWAV
@export var font: Font
@export var action_name: String
@export var characterRevealDelay: float = 0.2
@export var margin_top_bottom: int = 15
@export var margin_left_right: int = 15

var _text = []
var _textIndex : int

var _waitingForInput : bool = false

var _audio : AudioStreamPlayer

var textBox : RichTextLabel
var _characterRevealTimer : Timer
var _percent_addition : float	# % that each character composes in the current piece of text (`1/text.length()`)

signal dialogue_exit

func _enter_tree():
	textBox = load("res://addons/adbox/textbox.tscn").instantiate()
	textBox.add_theme_font_override("normal_font", font)
	textBox.bbcode_enabled = true
	textBox.fit_content = true
	textBox.mouse_filter = MOUSE_FILTER_IGNORE

	_characterRevealTimer = Timer.new()
	_characterRevealTimer.wait_time = characterRevealDelay
	_characterRevealTimer.connect("timeout", Callable(self, "_onCharacterRevealTimerTimeout"))

	add_child(textBox)
	add_child(_characterRevealTimer)

	message_sound.loop_mode = message_sound.LOOP_DISABLED
	message_sound.loop_begin = 0
	message_sound.loop_end = 0

	_audio = AudioStreamPlayer.new()
	_audio.stream = message_sound
	_audio.volume_db = -12
	add_child(_audio)

	size_flags_vertical = SIZE_EXPAND_FILL


# METHODS - PUBLIC


# Setup `DialogueBox` and reveal first piece of text
func talk(textarray : Array):
	"""
	Use this function to activate the DialogueBox
	"""
	_text = textarray
	_textIndex = 0
	_startRevealingCurrentText()

# Stop and reset `DialogueBox`
# Emits `dialogue_exit`, same as when `DialogueBox` runs out of text to display
func stopAndReset():
	textBox.visible_ratio = 0.0
	_textIndex = 0
	_audio.stop()
	_characterRevealTimer.stop()
	emit_signal("dialogue_exit")


# METHODS - PRIVATE


# Setup and start the revealing process of the current piece of text
# `DialogueBox` will not be waiting for input during the first `characterRevealTimer` countdown
func _startRevealingCurrentText():
	textBox.bbcode_text = _text[_textIndex]
	textBox.visible_ratio = 0.0
	_percent_addition = 1 / float(textBox.text.length())
	_characterRevealTimer.wait_time = characterRevealDelay

	_waitingForInput = false

	_characterRevealTimer.start()

# YOU WON'T BELIEVE THIS SIMPLE TRICK THEY *DON'T* WANT YOU TO KNOW
# This forces `DialogueBox` to update it's size to fit the text it contains
func _resizeControlNodes() -> void:
	# Shrink label
	var textBox: RichTextLabel = get_node("TextBox")
	textBox.size.y = textBox.custom_minimum_size.y

	# Set `DialogueBox`'s minimum size to its label's size (which fits itself to its content)
	# This forces `DialogueBox` to grow to fit the minimum size
	custom_minimum_size.y = textBox.size.y


# METHODS - SIGNAL CALLBACKS


# The "heart" of the character revealing process. Reveals 1 character after each `characterRevealTimer` countdown
# Timer will stop after the entire text is revealed
func _onCharacterRevealTimerTimeout():
	_resizeControlNodes()

	# If some of the text is hidden, show a bit more and play audio SFX
	if textBox.visible_ratio < 1:
		textBox.visible_ratio += _percent_addition
		_audio.play(0)
	# If text is in full display, stop audio SFX (in case it's still playing)
	# and stop character reveal timer
	else:
		_audio.stop()
		_characterRevealTimer.stop()

	_waitingForInput = true

func _on_Dialogue_gui_input(event):
	if (event is InputEventMouseButton
	and event.button_index == MOUSE_BUTTON_LEFT
	and not event.pressed
	and _waitingForInput):
		# If some text is still hidden, reveal it completely
		if textBox.visible_ratio != 1:
			textBox.visible_ratio = 1.0
			_resizeControlNodes()
			return

		# If not at the last piece of text, start revealing the next one
		if _textIndex < len(_text) - 1:
			_textIndex += 1
			_startRevealingCurrentText()
		# If at the last piece of text, stop and reset the `DialogueBox`
		elif textBox.visible_ratio == 1:
			stopAndReset()
