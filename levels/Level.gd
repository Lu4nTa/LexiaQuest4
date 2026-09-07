class_name Level extends Node2D


# PRELOADS


const _presentScene: PackedScene = preload("res://collectibles/Present/Present.tscn")


# EXPORTS


@export var _nextLevelPath: String = "res://levels/Level-2/Level-2.tscn"
@export var _minimumPresentsColected: int = 3: set = _setMinimumPresentsCollected
@export var _levelBounds: Dictionary = {
	"top": -440,
	"right": 8568,
	"bottom": 2944,
	"left": -384
}
@export var _hasCliff: bool = true
@export_range(0, 2048, 32) var _cliffCameraBottomBound: int = 1024
@export_range(0, 100) var _playerBottomBoundOffset: int = 40
@export_multiline var _victoryMessage: String = "Chegaste ao fim do nível!"
@export_multiline var _timeoutMessage: String = "Oh no! You ran out of time and died mysteriously...\nWould you like to play again?"
@export_multiline var _fallMessage: String = "Essa deve ter doído...\nQueres tentar outra vez?"


# VARS


@onready var _player: Player = $Player
@onready var _timer: TimerUI = $CanvasLayer/TimerUI
@onready var _collectibles: Node2D = $Collectibles
@onready var _scoreCounter: ScoreUI = $CanvasLayer/ScoreUI
@onready var _endScreen: EndScreenUI = $CanvasLayer/EndScreenUI
@onready var _music: AudioStreamPlayer = get_node_or_null("Music")	# every level has a root "Music" node; ducked while a quiz is open
var _musicVolumeBeforeQuiz: float = 0.0
const _QUIZ_MUSIC_DUCK_DB: float = -10.0	# how much quieter the music gets during a quiz — still audible, just clearly under the voice
var _paused: bool = false	# TODO: add setter
var _currentLevelBounds: Dictionary


# METHODS - NODE PROCESSES


func _enter_tree():
	_currentLevelBounds = {
		"top": _levelBounds.top,
		"right": _levelBounds.right,
		"bottom": _cliffCameraBottomBound if _hasCliff else _levelBounds.bottom,
		"left": _levelBounds.left
	}

func _ready():
	_setupPresentCollectibles()	# also sets _minimumPresentsColected to require ALL presents
	_setCameraBounds()
	_adjustSkyScale()
	get_viewport().size_changed.connect(_adjustSkyScale)	# keep the sky covering the screen if the window is resized

func _process(_delta):
	if _paused:
		return

	_lockPlayerInLevelBounds()


# METHODS - SETTERS & GETTERS


func _setMinimumPresentsCollected(minimumPresentsColectedValue: int) -> void:
	if minimumPresentsColectedValue < 0:
		minimumPresentsColectedValue = 0
	if _collectibles and minimumPresentsColectedValue > _collectibles.get_children().size():
		minimumPresentsColectedValue = _collectibles.get_children().size()

	print_debug("Level: _setMinimumPresentsCollected(%s) — _collectibles=%s, children=%s, final value=%s" % [minimumPresentsColectedValue, _collectibles, (_collectibles.get_children().size() if _collectibles else "N/A"), minimumPresentsColectedValue])

	_minimumPresentsColected = minimumPresentsColectedValue

	_updateCanLevelEnd()


# METHODS - PUBLIC


# Called after generating quiz sets to store each quiz in a present
func setupPresentQuizzes() -> void:
	for present in _collectibles.get_children():
		var quiz: Dictionary = QuizGenerator.getNextQuiz()
		# Never silently remove a collectible because a quiz pool was undersized.
		# Dedicated Levels 4-10 are configured with >=5 quizzes, but this guard keeps
		# every visible present intact if a future edit accidentally provides fewer.
		if quiz.is_empty():
			push_error("Level: not enough quizzes for all visible presents. Present '%s' was kept visible." % present.name)
			continue

		# Assign next quiz to present
		present.quiz = quiz


# METHODS - PRIVATE


# Replaces all present tiles on `Collectible Tiles` tilemap with `Present` scenes.
# Also sets-up the maximum score counter in `ScoreUI`
# Found in https://www.reddit.com/r/godot/comments/6vg5v8/using_tilemaps_for_more_advanced_objects/dm26wy7/
# Finds and returns the TileMapLayer child of `parentNode` that actually has cells
# painted on it (regardless of its name — the editor's "Extract TileMap layers" tool
# doesn't always call it the same thing). If `parentNode` has more than one TileMapLayer
# child (this can happen; picking blindly the first one used to sometimes grab an empty
# one), the one with content wins. Returns `null` if there's no TileMapLayer child at all.
func _findTileMapLayerChild(parentNode: Node) -> TileMapLayer:
	var fallback: TileMapLayer = null

	for child in parentNode.get_children():
		if child is TileMapLayer:
			if fallback == null:
				fallback = child
			if not child.get_used_cells().is_empty():
				return child

	return fallback


func _setupPresentCollectibles() -> void:
	var debugString: String = "Replaced %s present tiles at the following positions:\n"

	var presentCount: int = 0

	# Get tilemap information
	# Godot 4: the old `TileMap` node (with a `get_cell_size()` method) was replaced by
	# `TileMapLayer` nodes (extracted via the editor's "Extract TileMap layers as individual
	# TileMapLayer nodes" tool). Each `TileMapLayer` already represents a single layer, so
	# its methods no longer take a layer-index argument, and cell size comes from its own
	# `tile_set` resource.
	# NOTE: don't hardcode the child's name ("Layer0", "Layer1", ...) — the editor's
	# "Extract TileMap layers" tool doesn't always call it the same thing, so find
	# whichever TileMapLayer child actually exists under "Collectible Tiles".
	var tileMapLayer: TileMapLayer = _findTileMapLayerChild($"Collectible Tiles")
	assert(tileMapLayer != null, "Level: 'Collectible Tiles' has no TileMapLayer child — did the TileMap layer extraction run?")
	var cellSize: Vector2 = Vector2(tileMapLayer.tile_set.tile_size)
	var usedCells: Array = tileMapLayer.get_used_cells()

	# Iterate over tilemap to find and replace present tiles
	for tileCoords in usedCells:
		# Create and place present instance on tile position
		# Tile positions are cell-based, so must multiply by cell size to get positions in the scene
		# Tile positions in the scene are top-left-corner-based and present positions are centered,
		# so must add half the cell size on each axis when placing presents on tiles
		var node = _presentScene.instantiate()
		node.position = Vector2( tileCoords.x * cellSize.x + (0.5*cellSize.x), tileCoords.y * cellSize.y + (0.5*cellSize.y))
		_collectibles.add_child(node)

		# Remove present tile from tilemap
		# Godot 4: TileMapLayer's `erase_cell(coords)` no longer takes a layer index either.
		tileMapLayer.erase_cell(tileCoords)

		# Setup signals
		node.connect("opened", Callable(self, "_onPresentOpened"))
		node.connect("collected", Callable(self, "_onPresentCollected"))

		presentCount += 1

		debugString += "(%s, %s) " % [node.position.x, node.position.y]

	_scoreCounter.maxScore = presentCount

	# Require ALL presents in the level to be collected before the level can end
	# (instead of the old fixed minimum of 3 out of 5).
	_setMinimumPresentsCollected(presentCount)

	print_debug("\n", debugString % presentCount, "\n")

# Keep the player's camera inside the level's boundaries
func _setCameraBounds() -> void:
	var camera: Camera2D = _player.get_node("PlayerCamera")
	camera.limit_top = _currentLevelBounds.top
	camera.limit_right = _currentLevelBounds.right
	camera.limit_bottom = _currentLevelBounds.bottom
	camera.limit_left = _currentLevelBounds.left

# Make the sky background fill the entire viewport
func _adjustSkyScale() -> void:
	var sky: Sprite2D = get_node_or_null("ParallaxBackground/ParallaxLayer/Sky")
	if not sky or not sky.texture:
		return

	# Resolution/aspect-independent: scale from the SKY TEXTURE'S ACTUAL size vs the
	# ACTUAL viewport size, instead of a magic constant tuned for one specific texture
	# and one specific window size. `get_viewport_rect().size` reports the project's
	# design resolution (1280x720) regardless of the real window size, since the
	# project uses the "canvas_items" stretch mode — so this only needs to run once
	# per camera-zoom change, never per-resolution.
	var viewportSize: Vector2 = get_viewport_rect().size
	var textureSize: Vector2 = sky.texture.get_size()
	if textureSize.x <= 0 or textureSize.y <= 0:
		return

	# Cover the WHOLE viewport (never leave a gap on either axis) by using the larger
	# of the two per-axis ratios for both axes, rather than stretching non-uniformly.
	var coverScale: float = max(viewportSize.x / textureSize.x, viewportSize.y / textureSize.y)
	var cameraZoom: Vector2 = $Player/PlayerCamera.zoom	# zooming out reveals more world-space, so the sky must grow to match
	sky.centered = true
	sky.position = Vector2.ZERO
	sky.scale = Vector2(coverScale, coverScale) * cameraZoom

# Keep the player inside the level's boundaries, except the bottom boundary, which kills them when they go bellow it
# Used in `_process()`
func _lockPlayerInLevelBounds() -> void:
	# Godot 4: RectangleShape2D no longer has `extents` (half-size); it has `size` (full size),
	# so we divide by 2 here to keep the same "half extents" meaning the rest of this function relies on.
	var playerExtents: Vector2 = (_player.get_node("CollisionShape2D").shape as RectangleShape2D).size / 2
	if _player.position.y - playerExtents.y < _currentLevelBounds.top:
		_player.position.y = _currentLevelBounds.top + playerExtents.y
		_player.velocity.y = 0
	if _player.position.x - playerExtents.x < _currentLevelBounds.left:
		_player.position.x = _currentLevelBounds.left + playerExtents.x
		_player.velocity.x = 0
	if _player.position.x + playerExtents.x > _currentLevelBounds.right:
		_player.position.x = _currentLevelBounds.right - playerExtents.x
		_player.velocity.x = 0

	# Player fell off level bounds
	if _player.position.y + playerExtents.y > _currentLevelBounds.bottom + _playerBottomBoundOffset:
		_endScreen.message = _fallMessage
		_endScreen.showNextLevelButton = false
		_killPlayer()

# Check if the player has collected the minimum number of presents to proceed to the next level and updates the `EndSign`'s state
func _updateCanLevelEnd() -> void:
	var endSign: TutorialSign = $Signs/EndSign
	if not _scoreCounter or not endSign:
		return

	print_debug("Level: _updateCanLevelEnd() — score=%s, minimumPresentsColected=%s" % [_scoreCounter.score, _minimumPresentsColected])
	endSign.levelCanEnd = _scoreCounter.score >= _minimumPresentsColected

# Kill the player, pausing the level and the level timer
# This triggers the player's death animation, so the timer is paused here, instead of waiting for the animation to finish
func _killPlayer() -> void:
	_timer.paused = true
	_paused = true
	_player.kill()

# Show the end screen, pausing the player
func _endLevel() -> void:
	_player.paused = true
	_endScreen.enabled = true
	_endScreen.visible = true


# METHODS - SIGNAL CALLBACKS


func _onPresentOpened() -> void:
	_player.lock_for_quiz()
	_timer.paused = true	# stop counting quiz-solving time — only active platforming time counts

	if _music:
		_musicVolumeBeforeQuiz = _music.volume_db
		_music.volume_db = _musicVolumeBeforeQuiz + _QUIZ_MUSIC_DUCK_DB

func _initializePresentNodes() -> void:
	# Wire persistent Present scene instances and initialize the 5-present score.
	# Levels 6-10 keep their presents as real scene nodes so they remain movable/editable
	# in the Godot editor instead of being created only at runtime.
	if not _collectibles or not _scoreCounter:
		return

	var presentCount: int = 0
	for present in _collectibles.get_children():
		if not present.has_signal("opened") or not present.has_signal("collected"):
			continue
		var openedCallable := Callable(self, "_onPresentOpened")
		var collectedCallable := Callable(self, "_onPresentCollected")
		if not present.is_connected("opened", openedCallable):
			present.connect("opened", openedCallable)
		if not present.is_connected("collected", collectedCallable):
			present.connect("collected", collectedCallable)
		presentCount += 1

	_scoreCounter.maxScore = presentCount
	_setMinimumPresentsCollected(presentCount)


func _onPresentCollected() -> void:
	_scoreCounter.score = _scoreCounter.score + 1
	_player.unlock_from_quiz()
	_timer.paused = false	# resume counting now that the quiz is closed

	if _music:
		_music.volume_db = _musicVolumeBeforeQuiz

	_updateCanLevelEnd()

func _onPlayerReachedEndOfLevel():
	_timer.paused = true
	_paused = true
	_endScreen.message = _victoryMessage
	_endScreen.showNextLevelButton = true if _nextLevelPath else false
	_endLevel()

func _onGoToNextLevel() -> void:
	var code: int = get_tree().change_scene_to_file(_nextLevelPath)

	if OK != code:
		var error: String = "Can't open resource path for next level" if ERR_CANT_OPEN else "Couldn't instantiate next level scene"
		push_error(error)
		print_stack()
		get_tree().quit()

func _onRestartLevel() -> void:
	var code: int = get_tree().reload_current_scene()

	if OK != code:
		var error: String = "Can't open resource path for current level" if ERR_CANT_OPEN else "Couldn't instantiate current level scene"
		push_error(error)
		print_stack()
		get_tree().quit()

func _onBackToStartScreen() -> void:
	var code: int = get_tree().change_scene_to_file("res://levels/StartScreen/StartScreen.tscn")

	if OK != code:
		var error: String = "Can't open resource path for StartScreen" if ERR_CANT_OPEN else "Couldn't instantiate StartScreen scene"
		push_error(error)
		print_stack()
		get_tree().quit()

func _onTimerTimeout():
	_endScreen.message = _timeoutMessage
	_endScreen.showNextLevelButton = false
	_killPlayer()

func _onPlayerDied():
	_endLevel()

func _onPlayerCrossedStartSign(player):
	var startSign: TutorialSign = $Signs/StartSign
	# Player went to the left:
	# set cliff level bounds if there is a cliff
	if player.position.x < startSign.position.x and _hasCliff:
		_currentLevelBounds.bottom = _cliffCameraBottomBound
	# Player went to the right:
	# set regular level bounds and start timer if it's not running
	else:
		_currentLevelBounds.bottom = _levelBounds.bottom

		if not _timer.isRunning():
			_timer.start()

	_setCameraBounds()
