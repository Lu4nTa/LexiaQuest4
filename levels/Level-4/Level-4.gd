@tool
extends Level


# Level 4 — introduces the Teleport Pad mechanic.
#
# SIMPLIFIED FROM THE PREVIOUS 3-STOREY VERSION: that version kept producing real bugs
# (staircases built backwards, blocking whole routes) that I couldn't catch without
# actually running the game — three rounds of "fixed it" that still weren't fixed for you
# is three too many. This version has NO staircases and only ONE tunnel height, which
# removes that entire category of bug. It's still a big cave (131 tiles wide, wider than
# the 3-storey version was), split by a solid rock WALL with a Teleport Pad on each side,
# with several raised ledges and hidden pits along the way for exploring — just without
# the tier-crossing logic that kept breaking.
#
# Every ledge/pit column is allocated by a single sequential pass with a mandatory gap
# between features (so nothing can ever silently overlap), and reachability is verified
# with a standalone simulation before writing this file, same as always.
#
# Presents are spawned directly as `Present` nodes in `_spawnPresents()`, NOT by painting
# tiles on "Collectible Tiles" and letting `Level._setupPresentCollectibles()` scan for
# them — that tile-paint-then-scan approach was found to unreliably find 0 tiles in some
# editor sessions (same bug, same fix applied in Level 5), which set the minimum-presents
# requirement to 0 and made the "you can proceed" sound and sign unlock instantly on
# level load. Spawning the Present nodes directly sidesteps that tile-detection step
# entirely, so it can't happen here either now.
#
# `print_debug()` calls are sprinkled through map building — if anything is ever still
# wrong, please copy the lines starting with "Level-4:" from the Godot output panel and
# send them to me; that tells me exactly what actually got built, instead of me guessing
# again.
#
# 5 presents total (3 before the wall, 2 after), each with a DIFFERENT quiz type. The
# level ends with a normal exit sign like the other levels (the fancier gate is saved for
# a true final level later).
#
# ADDED: a wall-jump chimney (cols 34-38, between the 3rd ledge and the wall) — Level 4
# previously had zero verticality, which didn't fit "Wall Jump como mecânica principal"
# once Levels 6-10 made real wall-jumping the game's main mechanic. It's a fully optional
# side climb with a capped platform on top, built the same "walls solid, interior carved"
# way Levels 6-10 are, so there's no undefined void to fling the player into.


# CONSTS
const _TILE: int = 64
const _COLLECTIBLE_TILE: int = 32
const _GROUND_SOURCE: int = 0			# "groundStraight" — has a grass edge, only correct where open air is directly above
const _CENTER_GROUND_SOURCE: int = 9	# "centerGround" — plain rock, no grass, for anything with solid rock above it (walls, interior mass)

const _CEILING_ROW: int = 6
const _AIR_ROWS: Array = [7, 8, 9]
const _FLOOR_ROW: int = 10
const _FOUNDATION_ROWS: Array = [11, 12]
const _LEDGE_ROW: int = 8		# always 2 tiles above the floor
const _PIT_ROW: int = 11		# always 1 tile below the floor

const _ROCK_FROM_COL: int = 0
const _ROCK_TO_COL: int = 131
const _WALL_COLS: Array = [69, 70, 71, 72]
const _LEFT_ZONE: Array = [1, 66]
const _RIGHT_ZONE: Array = [73, 131]

# [fromCol, toCol, stepUpCol, stepDownCol]
const _LEDGES: Array = [
	[7, 11, 6, 12], [17, 21, 16, 22], [27, 31, 26, 32], [41, 45, 40, 46], [55, 59, 54, 60],
	[80, 84, 79, 85], [90, 94, 89, 95], [100, 104, 99, 105], [118, 122, 117, 123],
]

const _ALCOVES: Array = [2, 50, 109, 113]

const _MAX_PRESENTS: int = 5	# spawn at most this many, randomly chosen from the pool in `_spawnPresents()`

# Wall-jump chimney — Level 4 previously had NO verticality at all (flat corridor with
# only ledges/pits), which doesn't match "Wall Jump como mecânica principal". This is a
# self-contained tower bolted onto the flat corridor, clear of every ledge/pit/alcove:
# solid walls on both sides (interior 3 tiles, the same proven width used in Levels
# 6-10) rising from the main corridor up to a small capped platform. Purely optional —
# skip it and keep walking, or wall-jump up it just because you can.
const _CHIMNEY_WALL_COLS: Array = [34, 38]		# interior is 35-37
const _CHIMNEY_ROWS: Array = [-5, 9]			# [top, bottom] — bottom meets the corridor's air band
const _CHIMNEY_TOP_FLOOR: int = -2
const _CHIMNEY_TOP_CEILING: int = -5


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
	# _setupPresentCollectibles(), which scans "Collectible Tiles" for painted
	# tiles — since we no longer paint anything there, it would find 0 and
	# briefly set the minimum to 0 before _spawnPresents() corrects it, which
	# is exactly what was flipping the end sign to unlocked and playing the
	# "you can proceed" sound the instant the level loaded. Calling
	# _spawnPresents() first (above) means the minimum is set correctly from
	# the very first frame, never passing through 0.
	_setCameraBounds()
	_adjustSkyScale()
	get_viewport().size_changed.connect(_adjustSkyScale)

	QuizGenerator.clearQuizSets()
	QuizGenerator.generateCustomChoiceQuizSet(CustomChoiceDB.level4)	# mirror-letter (b/d/p/q) quiz set — see Custom-Choice.gd
	QuizGenerator.randomizeQuizSets()
	setupPresentQuizzes()


# METHODS - MAP BUILDING
func _buildMap() -> void:
	_foregroundLayer.visible = true
	_backgroundLayer.visible = true
	if _foregroundLayer.get_used_cells().size() > 0:
		return	# already painted (by an earlier run, or by hand in the editor) — never overwrite manual edits

	_buildBackdrop()
	_buildRockMass()
	_carveZone(_LEFT_ZONE[0], _LEFT_ZONE[1])
	_carveZone(_RIGHT_ZONE[0], _RIGHT_ZONE[1])
	# `_WALL_COLS` are deliberately left un-carved: that solid rock IS the wall

	for ledge in _LEDGES:
		_buildLedge(ledge[0], ledge[1], ledge[2], ledge[3])
	for col in _ALCOVES:
		_buildAlcove(col)
	_buildChimney()

	_fixTileSources()

	print_debug("Level-4: map built. Foreground used cells: %s" % [_foregroundLayer.get_used_cells().size()])

func _buildBackdrop() -> void:
	var bgColsFrom: int = _ROCK_FROM_COL / 2
	var bgColsTo: int = _ROCK_TO_COL / 2
	for col in range(bgColsFrom, bgColsTo + 1):
		for row in range(_CHIMNEY_ROWS[0] - 1, _FOUNDATION_ROWS[-1] + 1):
			_backgroundLayer.set_cell(Vector2i(col, row), 1, Vector2i(0, 0), 0)

func _buildRockMass() -> void:
	for col in range(_ROCK_FROM_COL, _ROCK_TO_COL + 1):
		_foregroundLayer.set_cell(Vector2i(col, _CEILING_ROW), _GROUND_SOURCE, Vector2i(0, 0), 0)
		for row in _AIR_ROWS:
			_foregroundLayer.set_cell(Vector2i(col, row), _GROUND_SOURCE, Vector2i(0, 0), 0)
		_foregroundLayer.set_cell(Vector2i(col, _FLOOR_ROW), _GROUND_SOURCE, Vector2i(0, 0), 0)
		for row in _FOUNDATION_ROWS:
			_foregroundLayer.set_cell(Vector2i(col, row), _GROUND_SOURCE, Vector2i(0, 0), 0)

func _carveZone(fromCol: int, toCol: int) -> void:
	for col in range(fromCol, toCol + 1):
		for row in _AIR_ROWS:
			_foregroundLayer.erase_cell(Vector2i(col, row))

func _buildLedge(fromCol: int, toCol: int, stepUpCol: int, stepDownCol: int) -> void:
	for col in range(fromCol, toCol + 1):
		_foregroundLayer.set_cell(Vector2i(col, _LEDGE_ROW), _GROUND_SOURCE, Vector2i(0, 0), 0)
		_foregroundLayer.erase_cell(Vector2i(col, _LEDGE_ROW - 1))
	_foregroundLayer.set_cell(Vector2i(stepUpCol, _FLOOR_ROW - 1), _GROUND_SOURCE, Vector2i(0, 0), 0)
	_foregroundLayer.set_cell(Vector2i(stepDownCol, _FLOOR_ROW - 1), _GROUND_SOURCE, Vector2i(0, 0), 0)

func _buildAlcove(col: int) -> void:
	_foregroundLayer.erase_cell(Vector2i(col, _FLOOR_ROW))
	_foregroundLayer.set_cell(Vector2i(col, _PIT_ROW), _GROUND_SOURCE, Vector2i(0, 0), 0)

# Builds the wall-jump chimney: solid walls on both sides, capped top platform. Unlike
# the rest of Level 4 (a single flat air band), this is carved the same way Levels 6-10
# are — walls painted solid first, interior explicitly erased — so there's no undefined
# void for an imprecise wall-jump to fling the player into.
func _buildChimney() -> void:
	for row in range(_CHIMNEY_ROWS[0], _CHIMNEY_ROWS[1] + 1):
		_foregroundLayer.set_cell(Vector2i(_CHIMNEY_WALL_COLS[0], row), _GROUND_SOURCE, Vector2i(0, 0), 0)
		_foregroundLayer.set_cell(Vector2i(_CHIMNEY_WALL_COLS[1], row), _GROUND_SOURCE, Vector2i(0, 0), 0)
		for col in range(_CHIMNEY_WALL_COLS[0] + 1, _CHIMNEY_WALL_COLS[1]):
			_foregroundLayer.erase_cell(Vector2i(col, row))
	# cap the top so the player lands on the platform instead of sailing into open air
	for col in range(_CHIMNEY_WALL_COLS[0], _CHIMNEY_WALL_COLS[1] + 1):
		_foregroundLayer.set_cell(Vector2i(col, _CHIMNEY_TOP_CEILING), _GROUND_SOURCE, Vector2i(0, 0), 0)
	for col in range(_CHIMNEY_WALL_COLS[0] + 1, _CHIMNEY_WALL_COLS[1]):
		_foregroundLayer.set_cell(Vector2i(col, _CHIMNEY_TOP_FLOOR), _GROUND_SOURCE, Vector2i(0, 0), 0)
		_foregroundLayer.set_cell(Vector2i(col, _CHIMNEY_TOP_FLOOR + 1), _GROUND_SOURCE, Vector2i(0, 0), 0)

# Runs after the whole shape (rock mass, carving, ledges, alcoves) is finished. A tile
# only gets the grass-edge texture if there's genuinely open air directly above it right
# now (a real walkable top surface) — everything else (wall faces, interior mass, the
# underside of ledges) gets the plain rock texture instead. Doing this as a final pass,
# rather than deciding per-tile while building, means it's correct regardless of the
# order features were carved/added in.
func _fixTileSources() -> void:
	for cell in _foregroundLayer.get_used_cells():
		var above: Vector2i = Vector2i(cell.x, cell.y - 1)
		var openAirAbove: bool = _foregroundLayer.get_cell_source_id(above) == -1
		var source: int = _GROUND_SOURCE if openAirAbove else _CENTER_GROUND_SOURCE
		_foregroundLayer.set_cell(cell, source, Vector2i(0, 0), 0)


# METHODS - PRESENTS
# Creates the 5 presents directly as `Present` nodes under `_collectibles`, exactly
# like `Level._setupPresentCollectibles()` would after finding them on the
# "Collectible Tiles" tilemap — but WITHOUT going through that tile-detection step.
# See the comment at the top of the file for why.
func _spawnPresents() -> void:
	if _collectibles.get_child_count() > 0:
		# Presents may already be persisted in the .tscn from an editor preview.
		# They still need their gameplay signals and score counter wired at runtime.
		_initializePresentNodes()
		return	# already spawned — don't duplicate

	var presentScene: PackedScene = preload("res://collectibles/Present/Present.tscn")
	var pool: Array = [
		[2, _PIT_ROW],			# left, hidden in a pit
		[17, _LEDGE_ROW],		# left, on a ledge
		[36, _FLOOR_ROW],		# left, out in the open
		[52, _FLOOR_ROW],		# left, further along
		[90, _LEDGE_ROW],		# right, on a ledge — different quiz type
		[100, _FLOOR_ROW],		# right, out in the open
		[113, _PIT_ROW],		# right, hidden in a pit — different quiz type
	]
	pool.shuffle()
	var chosenSpots: Array = pool.slice(0, min(_MAX_PRESENTS, pool.size()))

	for present in chosenSpots:
		var col: int = present[0]
		var platformRow: int = present[1]

		var node: Node2D = presentScene.instantiate()
		node.position = Vector2(col * _TILE + (_COLLECTIBLE_TILE / 2.0), platformRow * _TILE - (_COLLECTIBLE_TILE / 2.0))
		_collectibles.add_child(node)
		if Engine.is_editor_hint():
			node.owner = get_tree().edited_scene_root	# makes it show up (and save) in the Scene dock

		node.connect("opened", Callable(self, "_onPresentOpened"))
		node.connect("collected", Callable(self, "_onPresentCollected"))

	_initializePresentNodes()

	print_debug("Level-4: spawned %s presents directly. _collectibles now has %s children." % [chosenSpots.size(), _collectibles.get_children().size()])
