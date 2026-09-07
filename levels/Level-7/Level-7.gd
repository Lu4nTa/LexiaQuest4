@tool
extends Level


# Level 7 — "Ember Depths". Two chambers connected by a wall-jump shaft, taller ceilings
# than Level 6 ("2 câmaras com teto mais alto"). Chamber B's ledge is now a jagged
# zigzag: narrow-wide-narrow platforms climbing in a 2-tile-hop chain, plus an optional
# "spike" platform jutting up near the ceiling for a harder bonus reach. A second shaft
# leads to a high alcove with the 5th present.
#
# THEME: "Ember Depths" — rock clusters, warm orange-tinted sky.
#
# Presents are spawned directly as `Present` nodes (see Level 4/5). Every ground tile
# uses the plain earth texture, no grass edge baked in (see `_fixTileSources()`).
#
# Teleport A/B: an isolated Teleport Nook (cols 36-41), reachable only via the pad on
# Chamber B's floor — holds 1 of the 5 presents.
#
# 5 presents, quiz mix: Word Search, Rhymes With, Hangman, Write Prompt.
#
# `@tool` + `Engine.is_editor_hint()`: like Level 5, `_buildMap()` runs on scene open in
# the editor too, not only on Play — tiles/decorations/Teleport Nook are visible right
# away, same as Levels 1-5.


const _TILE: int = 64
const _COLLECTIBLE_TILE: int = 32
const _GROUND_SOURCE: int = 0
const _CENTER_GROUND_SOURCE: int = 9

const _BOUNDS_COLS: Array = [0, 34]
const _BOUNDS_ROWS: Array = [-6, 24]

const _ROOM_A_COLS: Array = [0, 11]
const _ROOM_A_FLOOR: int = 22
const _ROOM_A_CEILING: int = 11	# taller than Level 6's rooms — "2 câmaras com teto mais alto"

const _SHAFT_1_WALLS: Array = [12, 16]
const _SHAFT_1_ROWS: Array = [7, 22]
const _SHAFT_1_DOORWAY_ROWS: Array = [20, 21]

# Chamber B — taller ceiling + a jagged, zigzagging platform chain (narrow-wide-narrow,
# then a "spike" up near the ceiling) instead of one flat ledge.
const _ROOM_B_COLS: Array = [12, 28]
const _ROOM_B_FLOOR: int = 9
const _ROOM_B_CEILING: int = -2
# [fromCol, toCol, row, addFoundation]
const _PLATFORMS: Array = [
	[16, 17, 7, true], [19, 22, 7, true], [24, 25, 7, true],	# main zigzag, all a 2-tile hop up
	[19, 20, 4, false],											# spike jutting up near the ceiling
	[3, 5, 20, true], [7, 9, 18, true],						# Chamber A's warm-up chain
]

const _SHAFT_2_WALLS: Array = [29, 32]
const _SHAFT_2_ROWS: Array = [-3, 9]
const _SHAFT_2_DOORWAY_ROWS: Array = [7, 8]

const _ALCOVE_COLS: Array = [29, 34]
const _ALCOVE_FLOOR: int = -3
const _ALCOVE_CEILING: int = -6

# Teleport Nook — isolated pocket, no doorway/shaft to it, reachable ONLY via Teleport
# Pad. Solid rock (cols 34-35) separates it from the bonus alcove on purpose.
const _TP_NOOK_COLS: Array = [36, 41]
const _TP_NOOK_FLOOR: int = 9
const _TP_NOOK_CEILING: int = 2
const _TP_A_COL: int = 27	# Chamber B's floor, clear of both the shaft opening (cols 13-15) and the ledge

const _FOUNDATION_DEPTH: int = 2

const _MAX_PRESENTS: int = 5
const _PRESENT_POOL: Array = [
	[3, _ROOM_A_FLOOR], [8, 18],		# 2nd one on Chamber A's warm-up chain
	[24, _ROOM_B_FLOOR],				# Chamber B floor, clear of shaft/ledge
	[21, 7],							# on the zigzag's wide platform
	[17, 7],							# on the zigzag's narrow platform
	[38, _TP_NOOK_FLOOR],
	[32, _ALCOVE_FLOOR],				# atop the bonus shaft — needs the tighter wall-jump climb
]

const _DECORATIONS: Array = [
	[3, 21, 26], [9, 21, 27],
	[16, 6, 26], [20, 6, 28], [24, 6, 27], [19, 3, 26],
	[31, -4, 26],
	[38, 8, 27], [40, 8, 26],
]


@onready var _foregroundLayer: TileMapLayer = $Foreground/Layer0
@onready var _backgroundLayer: TileMapLayer = $Background/Layer0
@onready var _detailsLayer: TileMapLayer = $Details/Layer0


func _ready():
	_buildMap()	# paints the rock/background/decorations; safe to run in the editor too
	_spawnPresents()	# also safe in the editor — spawns as real, ownable/movable child nodes

	if Engine.is_editor_hint():
		return	# editor preview: only paint the map + presents, don't run any actual gameplay logic

	_setCameraBounds()
	_adjustSkyScale()
	get_viewport().size_changed.connect(_adjustSkyScale)

	QuizGenerator.clearQuizSets()
	QuizGenerator.generateAudioSequenceQuizSet(AudioSequenceDB.level7)	# ONLY the user's Level 7 quiz set
	QuizGenerator.randomizeQuizSets()
	setupPresentQuizzes()


func _buildMap() -> void:
	if _foregroundLayer.get_used_cells().size() > 0:
		return	# already painted (by an earlier run, or by hand in the editor) — never overwrite manual edits

	_buildBackdrop()
	_buildSolidMass()

	_carveRoom(_ROOM_A_COLS[0], _ROOM_A_COLS[1], _ROOM_A_FLOOR, _ROOM_A_CEILING)
	_carveShaft(_SHAFT_1_WALLS[0], _SHAFT_1_WALLS[1], _SHAFT_1_ROWS[0], _SHAFT_1_ROWS[1])
	_carveDoorway(_ROOM_A_COLS[1], _SHAFT_1_WALLS[0], _SHAFT_1_DOORWAY_ROWS[0], _SHAFT_1_DOORWAY_ROWS[1])
	_carveRoom(_ROOM_B_COLS[0], _ROOM_B_COLS[1], _ROOM_B_FLOOR, _ROOM_B_CEILING)
	_carveShaftThroughFloor(_SHAFT_1_WALLS[0] + 1, _SHAFT_1_WALLS[1] - 1, _ROOM_B_FLOOR, _FOUNDATION_DEPTH)
	for platform in _PLATFORMS:
		_buildPlatform(platform[0], platform[1], platform[2], platform[3])
	_carveShaft(_SHAFT_2_WALLS[0], _SHAFT_2_WALLS[1], _SHAFT_2_ROWS[0], _SHAFT_2_ROWS[1])
	_carveDoorway(_ROOM_B_COLS[1], _SHAFT_2_WALLS[0], _SHAFT_2_DOORWAY_ROWS[0], _SHAFT_2_DOORWAY_ROWS[1])
	_carveRoom(_ALCOVE_COLS[0], _ALCOVE_COLS[1], _ALCOVE_FLOOR, _ALCOVE_CEILING)
	_carveShaftThroughFloor(_SHAFT_2_WALLS[0] + 1, _SHAFT_2_WALLS[1] - 1, _ALCOVE_FLOOR, _FOUNDATION_DEPTH)
	_carveRoom(_TP_NOOK_COLS[0], _TP_NOOK_COLS[1], _TP_NOOK_FLOOR, _TP_NOOK_CEILING)	# isolated, TP-only

	_fixTileSources()
	_addDecorations()
	print_debug("Level-7: map built. Foreground used cells: %s" % [_foregroundLayer.get_used_cells().size()])

func _buildBackdrop() -> void:
	for col in range(0, (_BOUNDS_COLS[1] / 2) + 1):
		for row in range(_BOUNDS_ROWS[0] - 2, _BOUNDS_ROWS[1] + 3):
			_backgroundLayer.set_cell(Vector2i(col, row), 1, Vector2i(0, 0), 0)

func _buildSolidMass() -> void:
	for col in range(_BOUNDS_COLS[0], _BOUNDS_COLS[1] + 1):
		for row in range(_BOUNDS_ROWS[0], _BOUNDS_ROWS[1] + 1):
			_foregroundLayer.set_cell(Vector2i(col, row), _GROUND_SOURCE, Vector2i(0, 0), 0)

func _carveRoom(fromCol: int, toCol: int, floorRow: int, ceilingRow: int) -> void:
	for col in range(fromCol + 1, toCol):
		for row in range(ceilingRow + 1, floorRow):
			_foregroundLayer.erase_cell(Vector2i(col, row))
		_foregroundLayer.set_cell(Vector2i(col, floorRow), _GROUND_SOURCE, Vector2i(0, 0), 0)
		for depth in range(1, _FOUNDATION_DEPTH + 1):
			_foregroundLayer.set_cell(Vector2i(col, floorRow + depth), _GROUND_SOURCE, Vector2i(0, 0), 0)

func _carveShaft(wallColFrom: int, wallColTo: int, rowTop: int, rowBottom: int) -> void:
	for row in range(rowTop, rowBottom + 1):
		for col in range(wallColFrom + 1, wallColTo):
			_foregroundLayer.erase_cell(Vector2i(col, row))

func _carveDoorway(roomWallCol: int, shaftWallCol: int, rowFrom: int, rowTo: int) -> void:
	for row in range(rowFrom, rowTo + 1):
		_foregroundLayer.erase_cell(Vector2i(roomWallCol, row))
		_foregroundLayer.erase_cell(Vector2i(shaftWallCol, row))

func _carveShaftThroughFloor(interiorFromCol: int, interiorToCol: int, floorRow: int, foundationDepth: int) -> void:
	for col in range(interiorFromCol, interiorToCol + 1):
		_foregroundLayer.erase_cell(Vector2i(col, floorRow))
		for depth in range(1, foundationDepth + 1):
			_foregroundLayer.erase_cell(Vector2i(col, floorRow + depth))

func _buildPlatform(fromCol: int, toCol: int, row: int, addFoundation: bool = true) -> void:
	for col in range(fromCol, toCol + 1):
		_foregroundLayer.set_cell(Vector2i(col, row), _GROUND_SOURCE, Vector2i(0, 0), 0)
		if addFoundation:
			_foregroundLayer.set_cell(Vector2i(col, row + 1), _GROUND_SOURCE, Vector2i(0, 0), 0)
		_foregroundLayer.erase_cell(Vector2i(col, row - 1))
		_foregroundLayer.erase_cell(Vector2i(col, row - 2))

func _fixTileSources() -> void:
	# Every foreground tile uses the plain earth texture (centerGround, no grass edge).
	for cell in _foregroundLayer.get_used_cells():
		_foregroundLayer.set_cell(cell, _CENTER_GROUND_SOURCE, Vector2i(0, 0), 0)

func _addDecorations() -> void:
	for decoration in _DECORATIONS:
		_detailsLayer.set_cell(Vector2i(decoration[0], decoration[1]), decoration[2], Vector2i(0, 0), 0)


func _spawnPresents() -> void:
	if _collectibles.get_child_count() > 0:
		_initializePresentNodes()
		return	# already spawned (editor re-runs _ready() on every reload/edit) — don't duplicate

	var presentScene: PackedScene = preload("res://collectibles/Present/Present.tscn")
	var pool: Array = _PRESENT_POOL.duplicate()
	pool.shuffle()
	var chosenSpots: Array = pool.slice(0, min(_MAX_PRESENTS, pool.size()))

	for present in chosenSpots:
		var col: int = present[0]
		var platformRow: int = present[1]
		var node: Node2D = presentScene.instantiate()
		node.position = Vector2(col * _TILE + (_COLLECTIBLE_TILE / 2.0), platformRow * _TILE - (_COLLECTIBLE_TILE / 2.0))
		_collectibles.add_child(node)
		if Engine.is_editor_hint():
			node.owner = get_tree().edited_scene_root
		node.connect("opened", Callable(self, "_onPresentOpened"))
		node.connect("collected", Callable(self, "_onPresentCollected"))
	_initializePresentNodes()
	print_debug("Level-7: spawned %s presents directly. _collectibles now has %s children." % [chosenSpots.size(), _collectibles.get_children().size()])
