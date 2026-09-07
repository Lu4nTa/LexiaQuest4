class_name DustCloud extends Node2D


# EXPORTS
@export_range(0, 10) var _rotationSpeed: float = PI

# VARS
@onready var _sprite: Sprite2D = $Sprite
@onready var _animation: AnimationPlayer = $AnimationPlayer

func _ready():
	_animation.play("DustCloudAnimation")

func _process(delta: float):
	_sprite.rotate(_rotationSpeed * delta)

func _on_AnimationPlayer_animation_finished(_anim_name):
	queue_free()
