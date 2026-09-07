extends Node

# Rewards (autoload)
#
# Minimal persistent unlock system. A reward is unlocked the first time a
# player collects all 5 presents in a level (see `Level.gd`'s
# `_onPresentCollected`), and stays unlocked across sessions via a save
# file in `user://`.
#
# This is intentionally just the DATA layer (unlock + save/load). Wiring
# unlocked rewards to actual cosmetic art (e.g. hats on the player sprite,
# items in a "virtual room" scene) needs matching art assets, which this
# scaffold does not include — see `equipHat()` below for the hook point.

signal rewardUnlocked(rewardId)

const SAVE_PATH: String = "user://rewards.save"

var _unlocked: Dictionary = {}

func _ready() -> void:
	_load()

func hasReward(rewardId: String) -> bool:
	return _unlocked.get(rewardId, false)

# Unlocks `rewardId` (idempotent) and persists it immediately.
func unlockReward(rewardId: String) -> void:
	if hasReward(rewardId):
		return
	_unlocked[rewardId] = true
	_save()
	emit_signal("rewardUnlocked", rewardId)
	print_debug("Rewards: unlocked '%s'" % rewardId)

func getAllUnlocked() -> Array:
	return _unlocked.keys()

func _save() -> void:
	# Godot 4: the `File` class was replaced by `FileAccess`, opened via static methods
	# instead of `.new()` + `.open()`.
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Rewards: couldn't open save file for writing (error %s)" % FileAccess.get_open_error())
		return
	# Godot 4: the global `to_json()`/`parse_json()` functions were replaced by the `JSON` class.
	file.store_string(JSON.stringify(_unlocked))
	file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Rewards: couldn't open save file for reading (error %s)" % FileAccess.get_open_error())
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_unlocked = parsed
	else:
		push_warning("Rewards: save file was unreadable/corrupted, starting fresh")
