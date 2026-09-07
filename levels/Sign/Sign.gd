class_name TutorialSign extends Node2D


# SIGNALS


signal playerFinishedLevel
signal playerCrossed(player)


# EXPORTS


@export var _dialogueText: Array[String] = []
@export_range(0, 128, 8) var _hitboxHeight: float = 64: set = _setHitboxHeight
@export_range(0, 5, 0.1) var _promptDelayAfterDialogueExit: float = 0.8
@export var _isLevelEnd: bool = false
@export_range(0, 10, 0.1) var _levelUnlockSfxDelay: float = 1


# VARS

var levelCanEnd: bool = false: set = _setLevelCanEnd

@onready var _dialoguePanel: PanelContainer = $UI/Canvas/Dialogue
@onready var _dialogueBox: DialogueBox = $UI/Canvas/Dialogue/DialogueBox
@onready var _promptPanel: PanelContainer = $UI/Canvas/Prompt
var _hasPlayer: bool = false


# METHODS - NODE PROCESSES


func _ready():
	self._hitboxHeight = _hitboxHeight
	_dialoguePanel.hide()
	_promptPanel.hide()

	if not _isLevelEnd:
		$MinimumPresentsBarrier/CollisionShape2D.disabled = true


# METHODS - SETTERS & GETTERS


func _setHitboxHeight(hitboxHeightValue: float) -> void:
	_hitboxHeight = hitboxHeightValue

	var hitbox: CollisionShape2D = $Area2D/CollisionShape2D
	if hitbox:
		var hitboxShape: RectangleShape2D = hitbox.shape
		# Godot 4: `size` is the FULL height (was `extents`, half-height, in Godot 3)
		hitboxShape.size.y = _hitboxHeight
		hitbox.position.y = -hitboxShape.size.y / 2

func _setLevelCanEnd(levelCanEndValue: bool) -> void:
	if levelCanEnd == levelCanEndValue:
		return

	levelCanEnd = levelCanEndValue

	$MinimumPresentsBarrier/CollisionShape2D.disabled = levelCanEnd
	if levelCanEnd:
		await get_tree().create_timer(_levelUnlockSfxDelay).timeout
		$NextLevelUnlockedSFX.play()


# METHODS - SIGNAL CALLBACKS


func _onPlayerEnteredSignArea(_body):
	_hasPlayer = true

	if not _isLevelEnd and _dialogueText.size():
		_promptPanel.show()
		return

	if levelCanEnd:
		$LevelEndSFX.play()
		emit_signal("playerFinishedLevel")

func _onPlayerExitedSignArea(body):
	_hasPlayer = false
	_dialogueBox.stopAndReset()

	emit_signal("playerCrossed", body)

# Player started reading the sign
func _onPlayerStartedReading(event):
	if (event is InputEventMouseButton
	and event.button_index == MOUSE_BUTTON_LEFT
	and not event.pressed
	and _dialogueText.size()):
		_promptPanel.hide()
		_dialoguePanel.show()
		_dialogueBox.talk(_dialogueText)

func _on_DialogueBox_dialogue_exit():
	_dialoguePanel.hide()
	await get_tree().create_timer(_promptDelayAfterDialogueExit).timeout

	if _hasPlayer:
		_promptPanel.show()
	else:
		_promptPanel.hide()
