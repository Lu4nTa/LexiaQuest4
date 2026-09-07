@tool
extends Level


# Level 10 — "Golden Sanctum", the final level. Four rooms: entrance, a mid hall with a
# tiered platform chain and a Teleport Pad leading to a secret side vault (2 presents,
# unreachable any other way), and finally a tall grand chamber with two SYMMETRIC tiers
# of pillar-flanked platforms (matching the reference blueprint's grand-final look)
# before the special gate exit. Two wall-jump shafts (one tighter, near the end, for the
# level's real test of mastery) plus the teleport detour. Same carve-from-solid-rock
# architecture as Levels 6-9.
#
# THEME: "Golden Sanctum" — the richest decoration of any level, warm golden-tinted sky.
# Every ground tile uses the plain earth texture, no grass edge baked in
# (see `_fixTileSources()`).
#
# 5 presents, quiz mix pulls from across the whole game (Word Search, Hangman, Sound
# Bingo, Phoneme Blend, Rhymes With) as a proper finale.
#
# `@tool` + `Engine.is_editor_hint()`: like Level 5, `_buildMap()` runs on scene open in
# the editor too, not only on Play — tiles/decorations are visible right away, same as
# Levels 1-5.


const _TILE: int = 64
const _COLLECTIBLE_TILE: int = 32
const _GROUND_SOURCE: int = 0
const _CENTER_GROUND_SOURCE: int = 9

const _BOUNDS_COLS: Array = [0, 48]
const _BOUNDS_ROWS: Array = [-14, 24]

const _ROOM_A_COLS: Array = [0, 11]
const _ROOM_A_FLOOR: int = 22
const _ROOM_A_CEILING: int = 15

const _SHAFT_1_WALLS: Array = [12, 16]
const _SHAFT_1_ROWS: Array = [8, 22]
const _SHAFT_1_DOORWAY_ROWS: Array = [20, 21]

const _ROOM_B_COLS: Array = [12, 28]
const _ROOM_B_FLOOR: int = 9
const _ROOM_B_CEILING: int = 2
# [fromCol, toCol, row, addFoundation]
const _PLATFORMS: Array = [
	[16, 17, 7, true], [19, 22, 7, true], [24, 25, 7, true],
	[19, 20, 4, false],
]

# Secret vault, reachable only via Teleport Pad
const _VAULT_COLS: Array = [38, 46]
const _VAULT_FLOOR: int = 9
const _VAULT_CEILING: int = 2

const _SHAFT_2_WALLS: Array = [29, 32]	# tighter than shaft 1 — the finale's wall-jump test
const _SHAFT_2_ROWS: Array = [-5, 9]
const _SHAFT_2_DOORWAY_ROWS: Array = [7, 8]

const _ROOM_C_COLS: Array = [29, 46]
const _ROOM_C_FLOOR: int = -5
const _ROOM_C_CEILING: int = -12	# taller — room for 2 symmetric tiers of pillar-flanked platforms
# [fromCol, toCol, row, addFoundation] — symmetric pair on each side of the hall
const _ROOM_C_PLATFORMS: Array = [
	[33, 35, -7, true], [40, 42, -7, true],
	[33, 35, -10, false], [40, 42, -10, false],
]

const _FOUNDATION_DEPTH: int = 2

const _MAX_PRESENTS: int = 5
const _PRESENT_POOL: Array = [
	[3, _ROOM_A_FLOOR],
	[8, _ROOM_A_FLOOR],
	[17, 7], [21, 7],		# on Chamber B's tiered platform chain
	[40, _VAULT_FLOOR], [44, _VAULT_FLOOR],
	[34, -7], [41, -7],		# Chamber C's symmetric tiers, left and right
]

const _DECORATIONS: Array = [
	[3, 21, 30], [8, 21, 0],
	[16, 6, 27], [20, 6, 32], [24, 6, 26],
	[33, -8, 30], [34, -11, 0], [40, -8, 27], [41, -11, 19],
	[40, 8, 26], [44, 8, 19],
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
	QuizGenerator.generateCustomChoiceQuizSet(CustomChoiceDB.level10)	# EXACT Level 10 content, untouched
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
	_carveRoom(_VAULT_COLS[0], _VAULT_COLS[1], _VAULT_FLOOR, _VAULT_CEILING)	# isolated, TP-only
	_carveShaft(_SHAFT_2_WALLS[0], _SHAFT_2_WALLS[1], _SHAFT_2_ROWS[0], _SHAFT_2_ROWS[1])
	_carveDoorway(_ROOM_B_COLS[1], _SHAFT_2_WALLS[0], _SHAFT_2_DOORWAY_ROWS[0], _SHAFT_2_DOORWAY_ROWS[1])
	_carveRoom(_ROOM_C_COLS[0], _ROOM_C_COLS[1], _ROOM_C_FLOOR, _ROOM_C_CEILING)
	_carveShaftThroughFloor(_SHAFT_2_WALLS[0] + 1, _SHAFT_2_WALLS[1] - 1, _ROOM_C_FLOOR, _FOUNDATION_DEPTH)
	for platform in _ROOM_C_PLATFORMS:
		_buildPlatform(platform[0], platform[1], platform[2], platform[3])

	_fixTileSources()
	_addDecorations()
	print_debug("Level-10: map built. Foreground used cells: %s" % [_foregroundLayer.get_used_cells().size()])

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
	print_debug("Level-10: spawned %s presents directly. _collectibles now has %s children." % [chosenSpots.size(), _collectibles.get_children().size()])
