@tool
extends Level


# Level 8 — "Miner's Crypt". Same carve-from-solid-rock architecture as Level 6/7.
# Chamber B is now tiered mining shelves (narrow-wide-narrow, plus a spike shelf near the
# ceiling) instead of one flat ledge. Room B also has Teleport Pad A, which leads to
# an isolated bonus room (Room C, off to the side, unreachable any other way) holding 2
# of the 5 presents — Teleport Pad B there leads back. High difficulty: the wall-jump
# shafts are the same proven width as before, but there's more ground to cover and more
# platform variety (crates, ropes) to read before committing to a route.
#
# THEME: "Miner's Crypt" — crates and ropes, cool blue-grey tinted sky.
#
# Every ground tile uses the plain earth texture, no grass edge baked in
# (see `_fixTileSources()`).
#
# 5 presents, quiz mix: Sound Bingo, Phoneme Blend, Starts With, Match Image.
#
# `@tool` + `Engine.is_editor_hint()`: like Level 5, `_buildMap()` runs on scene open in
# the editor too, not only on Play — tiles/decorations are visible right away, same as
# Levels 1-5.


const _TILE: int = 64
const _COLLECTIBLE_TILE: int = 32
const _GROUND_SOURCE: int = 0
const _CENTER_GROUND_SOURCE: int = 9

const _BOUNDS_COLS: Array = [0, 46]
const _BOUNDS_ROWS: Array = [-6, 24]

const _ROOM_A_COLS: Array = [0, 11]
const _ROOM_A_FLOOR: int = 22
const _ROOM_A_CEILING: int = 15

const _SHAFT_1_WALLS: Array = [12, 16]
const _SHAFT_1_ROWS: Array = [7, 22]
const _SHAFT_1_DOORWAY_ROWS: Array = [20, 21]

# Chamber B — tiered mining shelves (crates stacked at different heights) instead of one
# flat ledge: narrow-wide-narrow zigzag, plus a spike shelf up near the ceiling.
const _ROOM_B_COLS: Array = [12, 26]
const _ROOM_B_FLOOR: int = 9
const _ROOM_B_CEILING: int = -2
# [fromCol, toCol, row, addFoundation]
const _PLATFORMS: Array = [
	[16, 17, 7, true], [19, 22, 7, true], [24, 25, 7, true],
	[19, 20, 4, false],
	[3, 5, 20, true], [7, 9, 18, true],	# Chamber A's warm-up chain
]

# Bonus room, reachable only via Teleport Pad — not physically connected to anything.
const _ROOM_C_COLS: Array = [36, 44]
const _ROOM_C_FLOOR: int = 9
const _ROOM_C_CEILING: int = 2

const _SHAFT_2_WALLS: Array = [27, 30]
const _SHAFT_2_ROWS: Array = [-3, 9]
const _SHAFT_2_DOORWAY_ROWS: Array = [7, 8]

const _ALCOVE_COLS: Array = [27, 32]
const _ALCOVE_FLOOR: int = -3
const _ALCOVE_CEILING: int = -6

const _FOUNDATION_DEPTH: int = 2

const _MAX_PRESENTS: int = 5
const _PRESENT_POOL: Array = [
	[3, _ROOM_A_FLOOR],
	[8, _ROOM_A_FLOOR],
	[16, 7],		# on the tiered shelf zigzag (narrow shelf)
	[21, 7],		# on the tiered shelf zigzag (wide shelf)
	[38, _ROOM_C_FLOOR], [42, _ROOM_C_FLOOR],
	[29, _ALCOVE_FLOOR],
]

const _DECORATIONS: Array = [
	[3, 21, 32], [8, 21, 26],
	[16, 6, 26], [20, 6, 32], [24, 6, 26], [19, 3, 47],
	[38, 8, 26], [42, 8, 47],
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
	QuizGenerator.generateMatchImageQuizSet(MatchImageDB.level8)	# ONLY the user's Level 8 quiz set
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
	_carveRoom(_ROOM_C_COLS[0], _ROOM_C_COLS[1], _ROOM_C_FLOOR, _ROOM_C_CEILING)	# isolated, TP-only
	_carveShaft(_SHAFT_2_WALLS[0], _SHAFT_2_WALLS[1], _SHAFT_2_ROWS[0], _SHAFT_2_ROWS[1])
	_carveDoorway(_ROOM_B_COLS[1], _SHAFT_2_WALLS[0], _SHAFT_2_DOORWAY_ROWS[0], _SHAFT_2_DOORWAY_ROWS[1])
	_carveRoom(_ALCOVE_COLS[0], _ALCOVE_COLS[1], _ALCOVE_FLOOR, _ALCOVE_CEILING)
	_carveShaftThroughFloor(_SHAFT_2_WALLS[0] + 1, _SHAFT_2_WALLS[1] - 1, _ALCOVE_FLOOR, _FOUNDATION_DEPTH)

	_fixTileSources()
	_addDecorations()
	print_debug("Level-8: map built. Foreground used cells: %s" % [_foregroundLayer.get_used_cells().size()])

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
	print_debug("Level-8: spawned %s presents directly. _collectibles now has %s children." % [chosenSpots.size(), _collectibles.get_children().size()])
