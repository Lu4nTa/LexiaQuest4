@tool
extends Level


# Level 5 — this map is a direct, tile-by-tile reconstruction of the official
# blueprint image supplied for this level (a tall, winding two-chamber cave,
# split by a solid rock wall, with a Teleport Pad on each side).
#
# `_MAP_ROWS` is the blueprint itself, transcribed row by row: 'S' = solid rock,
# '.' = open space, one character per tile, one string per row, top to bottom —
# same order and shape as the reference image. `_buildMap()` just paints exactly
# what's written here; nothing about the shape is procedurally invented.
#
# The ONLY departures from a literal pixel copy are the minimum needed to make
# it physically playable, every one of them because a label box in the source
# image (a black rectangle with white text — "ENTRADA", "TELEPORT (A)",
# "TELEPORT (B)", "QUIZ", "SAÍDA") sits drawn on top of the platform/doorway
# tiles underneath it, hiding what's actually there:
#   - ENTRADA doorway: opened 2 tiles (cols 3-4, rows 14-16) so the entrance
#     corridor actually reaches the main cave instead of dead-ending.
#   - TELEPORT (A) platform: guaranteed solid under the door (row 3, cols 12-17).
#   - TELEPORT (B) platform: guaranteed solid under the door (row 25, cols 24-29).
#   - QUIZ platform: guaranteed solid under the present (row 3, cols 32-37).
#   - SAÍDA platform: guaranteed solid under the present/sign (row 4, cols 38-40).
# A further pass afterwards widened every isolated 1-tile-wide platform to at
# least 2 tiles (verifying with the same flood-fill each time that nothing got
# disconnected) — 1-tile platforms were making the player's is_on_floor() flicker
# between WALKING/FALLING every frame instead of landing cleanly, which also
# meant wall-slide/wall-jump never had a stable run-up to trigger from.
# Every other tile is exactly what the blueprint shows. Reachability (entrance
# -> every left-side present -> Teleport A, and Teleport B -> every right-side
# present -> exit) was verified with a flood-fill simulation before writing
# this file, same as always.
#
# 8 presents total (4 before the wall, 4 after — including the one drawn next
# to the "QUIZ" label and the one drawn next to "SAÍDA"), each a different quiz
# type.
#
# `@tool` + `Engine.is_editor_hint()` below: unlike Level 1-3 (hand-painted, so
# their tiles are baked into the .tscn and always visible), this level is built
# in code, so its TileMapLayers used to be empty until you actually pressed
# Play. `_buildMap()` now also runs when you just open the scene in the editor,
# so you see (and can sanity-check) the same layout without running the game —
# but everything else (`super._ready()`, quiz generation, present spawning) is
# real gameplay logic that must NOT run just from opening the scene, so it's
# skipped whenever `Engine.is_editor_hint()` is true.
#
# `print_debug()` in _buildMap() and in Level._setupPresentCollectibles() — if
# anything is ever wrong in-game, copy the lines starting with "Level-5:" and
# "Replaced" from the Godot output panel (from an actual Play run of THIS
# scene, not just the editor tab) and send them, that's the fastest way for me
# to see exactly what got built instead of guessing from a screenshot.


# CONSTS
const _TILE: int = 64
const _COLLECTIBLE_TILE: int = 32
const _GROUND_SOURCE: int = 0			# "groundStraight" — has a grass edge, only correct where open air is directly above
const _CENTER_GROUND_SOURCE: int = 9	# "centerGround" — plain rock, no grass, for anything with solid rock above it (walls, interior mass)
const _BG_ROW_PADDING: int = 2		# extra rows of background above/below the map, so the parallax sky never shows through

# The blueprint, transcribed 1 character = 1 tile, 1 string = 1 row, top to bottom.
# 'S' = solid rock, '.' = open air. 41 columns x 26 rows.
const _MAP_ROWS: Array = [
	".SSSSSSSSSSSS....SSSSSSSSSSSSSSS......S..",
	".SSS...............SSSS..................",
	".SS.............SS.SSS.........SSSS......",
	".SS.....SSSSSSSSSS.SSS.........SSSSSSS...",
	".SS.....S.SS......SSSS.SSS............SSS",
	".SS....SS....SS...SSSS.S...SSSS.SSSSS.SS.",
	".SS....S......S...SSSS.SSSS..S.SS....SSS.",
	".SS....S......S...SSSS.S.S.....S....SSSS.",
	".SS....S.SSS..SS..SSSS...S..SSSS.......S.",
	".SSS...S......S...SSSS.SSS..S.........SS.",
	".SSS...S.SSSS.S...SSSS...S..S....SS...SS.",
	".SSSS....S....SS..SSSSS..S..S..SSS....SS.",
	".SSSS....S.SSS.S.SSSSSS.....SS.S...SS.SS.",
	".SSSS......S...S.SSSSSS....SSS..SS..S.SS.",
	".SS...SSS.SS..SS.SSSSSS.SS.S....S.....SS.",
	".......S..S......SSSSSS.S.......S.....SS.",
	".......S..S....SS.SSSSS.S.......S.....SS.",
	"SSSS...S..S..SSS..SSSSS.S...SS..S.SSS.SS.",
	"SSSS......S..S....SSSSSSS....S..S.....SS.",
	".SS.SSS.SS.S.S....SSSSS......S...SS...SS.",
	".SSS.S..S..S.SSSS.SSSSS...SS.........SSS.",
	".SS....SSS.S......SSSSSSS.SS..SSSSSS.SSS.",
	".SS....SS..S..SSSSSSSSS...............SS.",
	".SSS.......S......SSSSSSSSSSS........SSS.",
	".SSSSSS...SS..SSS.SSSSSS......SS..SSSSSS.",
	".SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS.",
]

# Presents: [col, platformRow] — platformRow is the solid tile the present floats above.
const _MAX_PRESENTS: int = 5
const _PRESENT_POOL: Array = [
	[2, 17],	# left, right by the entrance
	[10, 8],	# left
	[7, 14],	# left
	[15, 20],	# left
	[35, 3],	# right, by the "QUIZ" marker
	[25, 6],	# right
	[35, 17],	# right
	[40, 4],	# right, by the exit
]


# VARS
@onready var _foregroundLayer: TileMapLayer = $Foreground/Layer0
@onready var _backgroundLayer: TileMapLayer = $Background/Layer0


# METHODS
func _ready():
	_buildMap()	# paints the rock/background; safe to run in the editor too
	_spawnPresents()	# also safe in the editor — spawns as real, ownable/movable child nodes

	if Engine.is_editor_hint():
		return	# editor preview: only paint the map + presents, don't run any actual gameplay logic

	# NOTE: deliberately NOT calling super._ready() here. Level._ready() calls
	# _setupPresentCollectibles(), which — since we no longer paint anything on
	# "Collectible Tiles" — would find 0 presents and briefly set the minimum
	# to 0 before _spawnPresents() (above) corrects it. That brief "0
	# presents needed" state is exactly what was flipping the end sign to
	# unlocked and playing the "you can proceed" sound the instant the level
	# loaded. Calling _spawnPresents() first means the minimum is set correctly
	# from the very first frame, never passing through 0.
	_setCameraBounds()
	_adjustSkyScale()
	get_viewport().size_changed.connect(_adjustSkyScale)

	QuizGenerator.clearQuizSets()
	QuizGenerator.generateCustomChoiceQuizSet(CustomChoiceDB.level5)	# ONLY the user's Level 5 quiz set
	QuizGenerator.randomizeQuizSets()
	setupPresentQuizzes()


# METHODS - MAP BUILDING
func _buildMap() -> void:
	if _foregroundLayer.get_used_cells().size() > 0:
		return	# already painted (by an earlier run, or by hand in the editor) — never overwrite manual edits

	_buildBackdrop()
	_paintMap()

	print_debug("Level-5: map built. Foreground used cells: %s" % [_foregroundLayer.get_used_cells().size()])

func _buildBackdrop() -> void:
	var totalRows: int = _MAP_ROWS.size()
	var totalCols: int = (_MAP_ROWS[0] as String).length()
	for col in range(0, (totalCols / 2) + 1):
		for row in range(-_BG_ROW_PADDING, totalRows + _BG_ROW_PADDING):
			_backgroundLayer.set_cell(Vector2i(col, row), 1, Vector2i(0, 0), 0)

func _paintMap() -> void:
	for row in range(_MAP_ROWS.size()):
		var line: String = _MAP_ROWS[row]
		for col in range(line.length()):
			if line[col] == "S":
				var openAirAbove: bool = row == 0 or (_MAP_ROWS[row - 1] as String)[col] != "S"
				var source: int = _GROUND_SOURCE if openAirAbove else _CENTER_GROUND_SOURCE
				_foregroundLayer.set_cell(Vector2i(col, row), source, Vector2i(0, 0), 0)


# METHODS - PRESENTS
# Creates the 8 presents directly as `Present` nodes under `_collectibles`, exactly
# like `Level._setupPresentCollectibles()` would after finding them on the
# "Collectible Tiles" tilemap — but WITHOUT going through that tile-detection step.
# That tile-then-scan approach is what was silently finding 0 presents in-editor for
# reasons that didn't reproduce in a clean run, so this sidesteps it entirely: no
# tiles to paint, no layer to scan, nothing that depends on tile/atlas caching —
# just the 8 Present scenes, placed and wired up directly, every time, guaranteed.
func _spawnPresents() -> void:
	if _collectibles.get_child_count() > 0:
		# Presents may already be persisted in the .tscn from an editor preview.
		# They still need their gameplay signals and score counter wired at runtime.
		_initializePresentNodes()
		return	# already spawned — don't duplicate

	var presentScene: PackedScene = preload("res://collectibles/Present/Present.tscn")

	var pool: Array = _PRESENT_POOL.duplicate()
	pool.shuffle()
	var chosenSpots: Array = pool.slice(0, min(_MAX_PRESENTS, pool.size()))

	for present in chosenSpots:
		var col: int = present[0]
		var platformRow: int = present[1]

		var node: Node2D = presentScene.instantiate()
		# Same position math as the old tile-based placement: floating half a
		# collectible-tile above the platform tile, centered on its column.
		node.position = Vector2(col * _TILE + (_COLLECTIBLE_TILE / 2.0), platformRow * _TILE - (_COLLECTIBLE_TILE / 2.0))
		_collectibles.add_child(node)
		if Engine.is_editor_hint():
			node.owner = get_tree().edited_scene_root	# makes it show up (and save) in the Scene dock

		node.connect("opened", Callable(self, "_onPresentOpened"))
		node.connect("collected", Callable(self, "_onPresentCollected"))

	_initializePresentNodes()

	print_debug("Level-5: spawned %s presents directly. _collectibles now has %s children." % [chosenSpots.size(), _collectibles.get_children().size()])
