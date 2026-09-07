class_name StartScreen extends Node2D


# CONSTS
const _firstLevelPath: String = "res://levels/Level-1/Level-1.tscn"

# VARS
@onready var _animation: AnimationPlayer = $AnimationPlayer
@onready var _startScreenUI: StartScreenUI = $CanvasLayer/StartScreenUI

# METHODS
func _input(event):
	# Left mouse button clicked during animation
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _animation.is_playing():
			_animation.advance(6)
			get_viewport().set_input_as_handled()

	# Pressed Enter during animation
	if event.is_action_pressed("ui_accept"):
		if _animation.is_playing():
			_animation.advance(6)
			get_viewport().set_input_as_handled()

func _ready():
	# Sky is now a fullscreen CanvasLayer/TextureRect and must not be scaled by code.
	pass

# SIGNAL CALLBACKS
func _on_AnimationPlayer_animation_finished(_anim_name):
	_startScreenUI.enabled = true

func _on_StartScreenUI_startGame():
	var code: int = get_tree().change_scene_to_file(_firstLevelPath)

	if OK != code:
		var error: String = "Can't open resource path for first level" if ERR_CANT_OPEN else "Couldn't instantiate level scene"
		push_error(error)
		print_stack()
		get_tree().quit()

func _on_StartScreenUI_exitGame():
	get_tree().quit()
