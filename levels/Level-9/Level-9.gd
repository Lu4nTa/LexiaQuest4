@tool
extends Level


# Level 9 — "Deep Grove". Three vertical zones, but this time the player descends
# through them (Room A near the top, Room B in the middle, Room C at the very bottom) —
# each connecting shaft is a safe, wall-contained drop rather than a climb, so the
# feeling is of getting steadily deeper into the world. Room B's ledge is now a tiered
# platform chain (narrow-wide-narrow, plus a spike near the ceiling), and Room C has its
# own small elevated shelf — "3 câmaras altas" (3 tall chambers), each genuinely
# different from the last, not the same box resized. A tighter bonus shaft climbs UP
# from Room C to a high alcove for the 5th present — the one moment that demands real
# wall-jump mastery, right when the player might expect the level to be "over" since
# they've reached the bottom. Same carve-from-solid-rock architecture as Levels 6-8.
#
# THEME: "Deep Grove" — trees and grass throughout, muted purple-tinted sky. Every
# ground tile uses the plain earth texture, no grass edge baked in (see
# `_fixTileSources()`).
#
# Teleport A/B: an isolated Teleport Nook (cols 40-45) past Room C's far wall, reachable
# only via the pad on Room B's floor — holds 1 of the 5 presents.
#
# 5 presents, quiz mix: Match Image, Hangman, Word Search, Rhymes With.
#
# `@tool` + `Engine.is_editor_hint()`: like Level 5, `_buildMap()` runs on scene open in
# the editor too, not only on Play — tiles/decorations/Teleport Nook are visible right
# away, same as Levels 1-5.


const _TILE: int = 64
const _COLLECTIBLE_TILE: int = 32
const _GROUND_SOURCE: int = 0
const _CENTER_GROUND_SOURCE: int = 9

const _BOUNDS_COLS: Array = [0, 45]
const _BOUNDS_ROWS: Array = [-3, 38]

const _ROOM_A_COLS: Array = [0, 11]
const _ROOM_A_FLOOR: int = 6
const _ROOM_A_CEILING: int = -1

const _SHAFT_1_WALLS: Array = [12, 16]
const _SHAFT_1_ROWS: Array = [6, 20]
const _SHAFT_1_DOORWAY_ROWS: Array = [5, 6]	# includes Room A's floor row, where the shaft actually begins

const _ROOM_B_COLS: Array = [12, 26]
const _ROOM_B_FLOOR: int = 20
const _ROOM_B_CEILING: int = 13
# [fromCol, toCol, row, addFoundation]
const _PLATFORMS: Array = [
	[16, 17, 18, true], [19, 22, 18, true], [24, 25, 18, true],
	[19, 20, 15, false],
]
const _ROOM_C_PLATFORM: Array = [26, 28, 32]	# small elevated shelf, clear of both shafts

const _SHAFT_2_WALLS: Array = [20, 24]
const _SHAFT_2_ROWS: Array = [20, 34]
const _SHAFT_2_DOORWAY_ROWS: Array = [19, 20]

const _ROOM_C_COLS: Array = [20, 36]
const _ROOM_C_FLOOR: int = 34
const _ROOM_C_CEILING: int = 27

# Bonus shaft — climbs UP from Room C, tighter than the descent shafts, the level's
# "master the wall-jump" moment.
const _SHAFT_3_WALLS: Array = [30, 33]	# interior is 31-32
const _SHAFT_3_ROWS: Array = [26, 34]
const _SHAFT_3_DOORWAY_ROWS: Array = [32, 33]

const _ALCOVE_COLS: Array = [30, 35]
const _ALCOVE_FLOOR: int = 26
const _ALCOVE_CEILING: int = 23

# Teleport Nook — isolated pocket beyond Room C's far wall, no doorway/shaft to it,
# reachable ONLY via Teleport Pad. Solid rock (cols 36-39) separates it on purpose.
const _TP_NOOK_COLS: Array = [40, 45]
const _TP_NOOK_FLOOR: int = 34
const _TP_NOOK_CEILING: int = 27
const _TP_A_COL: int = 18	# Room B's floor, clear of the shaft opening (13-15) and the platform chain

const _FOUNDATION_DEPTH: int = 2

const _MAX_PRESENTS: int = 5
const _PRESENT_POOL: Array = [
	[3, _ROOM_A_FLOOR], [8, _ROOM_A_FLOOR],
	[42, _TP_NOOK_FLOOR],
	[18, 18], [21, 18],		# on Room B's tiered platform chain
	[26, 32],				# on Room C's elevated shelf
	[33, _ALCOVE_FLOOR],	# atop the bonus shaft — the level's "master the wall-jump" moment
]

const _DECORATIONS: Array = [
	[3, 5, 30], [9, 5, 19],
	[14, 19, 30], [17, 17, 22], [21, 17, 19], [24, 17, 22],
	[27, 31, 19],
	[24, 33, 19], [30, 33, 30], [33, 25, 19],
	[41, 33, 22], [44, 33, 30],
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
	QuizGenerator.generateRhymesWithImageQuizSet(RhymesWithImageDB.level9)	# ONLY the user's Level 9 quiz set
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
	_carveRoom(_ROOM_C_COLS[0], _ROOM_C_COLS[1], _ROOM_C_FLOOR, _ROOM_C_CEILING)
	_carveShaftThroughFloor(_SHAFT_2_WALLS[0] + 1, _SHAFT_2_WALLS[1] - 1, _ROOM_C_FLOOR, _FOUNDATION_DEPTH)
	_carveShaft(_SHAFT_3_WALLS[0], _SHAFT_3_WALLS[1], _SHAFT_3_ROWS[0], _SHAFT_3_ROWS[1])
	_carveDoorway(_ROOM_C_COLS[1], _SHAFT_3_WALLS[0], _SHAFT_3_DOORWAY_ROWS[0], _SHAFT_3_DOORWAY_ROWS[1])
	_carveRoom(_ALCOVE_COLS[0], _ALCOVE_COLS[1], _ALCOVE_FLOOR, _ALCOVE_CEILING)
	_carveShaftThroughFloor(_SHAFT_3_WALLS[0] + 1, _SHAFT_3_WALLS[1] - 1, _ALCOVE_FLOOR, _FOUNDATION_DEPTH)
	_buildPlatform(_ROOM_C_PLATFORM[0], _ROOM_C_PLATFORM[1], _ROOM_C_PLATFORM[2])	# clear of both Room C shafts
	_carveRoom(_TP_NOOK_COLS[0], _TP_NOOK_COLS[1], _TP_NOOK_FLOOR, _TP_NOOK_CEILING)	# isolated, TP-only

	_fixTileSources()
	_addDecorations()
	print_debug("Level-9: map built. Foreground used cells: %s" % [_foregroundLayer.get_used_cells().size()])

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
		return

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
	print_debug("Level-9: spawned %s presents directly. _collectibles now has %s children." % [chosenSpots.size(), _collectibles.get_children().size()])
