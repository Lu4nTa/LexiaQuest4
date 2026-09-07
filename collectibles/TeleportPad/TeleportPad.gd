class_name TeleportPad extends Node2D


# A touchable portal that teleports the player to another `TeleportPad`'s position.
# Two pads are meant to be linked to each other (`_linkedPad` on each pointing at the other),
# so the player can freely go back and forth between them ("avançar" and "voltar").
#
# SETUP: place two `TeleportPad` instances in the level, then, on EACH one, set its
# `_linkedPad` export to point at the OTHER pad's `NodePath` (e.g. "../TeleportPadB").


# SIGNALS
signal teleportedPlayer


# EXPORTS
@export var _linkedPad: NodePath
@export_range(0, 3, 0.1) var _cooldownSeconds: float = 0.6	# briefly ignores re-entry after a teleport, on BOTH pads, so the player doesn't instantly bounce back and forth


# VARS
@onready var _area: Area2D = $Area2D
var _isOnCooldown: bool = false


# METHODS - NODE PROCESSES
func _ready():
	_area.connect("body_entered", Callable(self, "_onBodyEntered"))


# METHODS - PUBLIC
# Called by the linked pad right after it teleports the player here, so this pad
# doesn't immediately teleport them right back
func startCooldown() -> void:
	if _isOnCooldown:
		return

	_isOnCooldown = true
	await get_tree().create_timer(_cooldownSeconds).timeout
	_isOnCooldown = false


# METHODS - SIGNAL CALLBACKS
func _onBodyEntered(body: Node) -> void:
	if _isOnCooldown or not body is Player:
		return

	if _linkedPad.is_empty():
		push_warning("TeleportPad '%s': _linkedPad is not set, nothing to teleport to" % name)
		return

	var targetPad: TeleportPad = get_node(_linkedPad)
	if not targetPad:
		push_warning("TeleportPad '%s': could not find the linked pad at path '%s'" % [name, _linkedPad])
		return

	body.global_position = targetPad.global_position
	emit_signal("teleportedPlayer")

	# Both pads pause briefly, so the player can walk away from either end without
	# bouncing straight back
	startCooldown()
	targetPad.startCooldown()
