@tool
extends Level


# Level 6 — "Mossy Hollow". Two landings (rooms) connected by a wall-jump shaft. Landing
# B is a proper "varanda encadeada" (chained balcony): 3 staggered floating balconies,
# each a plain 2-tile hop up from the one before, instead of one flat ledge — Landing A
# gets a shorter 2-step warm-up chain of its own. A tighter bonus shaft off Landing B
# holds the 5th present — climbing it is the level's "master the wall-jump" moment.
#
# ARCHITECTURE: unlike the flat corridor levels (4/5/7/8/9/10), this one is genuinely
# vertical, so it's built the opposite way round from them: the WHOLE bounding box is
# filled solid first (`_buildSolidMass()`), and every room/shaft/doorway is CARVED out
# of that mass. The first version of this level built rooms and shafts as separate
# "islands" added onto empty space — which meant the space *around* them was totally
# undefined (no collision at all), so an imprecise wall-jump could fling the player
# straight out of a shaft into that undefined void with nothing to catch them, and they'd
# drift for the rest of the level. Carving from solid rock, like every other level here
# already does, means there is no undefined void anywhere: it's either an intentional
# open path or solid rock, never nothing.
#
# Shaft widths were picked from a standalone empirical test (a synthetic vertical shaft
# + a script that holds toward the wall and taps jump on a timer, exactly like a person
# alternating input): widths from 2 to 10 tiles all let the player climb steadily, so a
# comfortable 3-tile interior was used for the main shaft and a tighter 2-tile interior
# for the bonus shaft. The climb was then re-simulated inside this actual level (not
# just the synthetic rig) to confirm the player really reaches each landing.
#
# THEME: "Mossy Hollow" — bushes, grass and a tree scattered through both rooms
# (Details.tres, decoration only, no collision), soft green-tinted sky.
#
# Presents are spawned directly as `Present` nodes (see Level 4/5 for why tile-painting
# + scanning was unreliable). Every ground tile uses the plain earth texture (no grass
# edge baked into the tile itself — see `_fixTileSources()`).
#
# Teleport A/B: an isolated Teleport Nook (cols 38-43) with no doorway or shaft to it at
# all — the only way in is through the pad on Landing B's floor. Holds 1 of the 5
# presents, same "teleport with a real job" pattern as Levels 4/5/8/10.
#
# 5 presents, quiz mix: Match Image, Starts With, Rhymes With, Sound Bingo.
#
# `@tool` + `Engine.is_editor_hint()`: like Level 5, `_buildMap()` now runs when you
# just open this scene in the editor — not only when you press Play — so the tiles,
# decorations and Teleport Nook are visible right away in the Foreground/Background/
# Details TileMapLayers, same as Levels 1-5. Everything else (quiz generation, present
# spawning, camera bounds) is real gameplay logic and is skipped in the editor.

# CONSTS
const _TILE: int = 64
const _COLLECTIBLE_TILE: int = 32
const _GROUND_SOURCE: int = 0
const _CENTER_GROUND_SOURCE: int = 9

# Overall bounding box that gets filled solid before anything is carved.
const _BOUNDS_COLS: Array = [0, 36]
const _BOUNDS_ROWS: Array = [-4, 24]	# [top, bottom] — negative rows are just further up, no issue

# Landing A (entrance room)
const _ROOM_A_COLS: Array = [0, 9]
const _ROOM_A_FLOOR: int = 22
const _ROOM_A_CEILING: int = 17

# Main shaft (A -> B). Stops one row short of Landing B's floor (row 8, not 9) so
# Landing B's own floor doesn't seal the top of the shaft.
const _SHAFT_1_WALLS: Array = [10, 14]		# interior is 11-13
const _SHAFT_1_ROWS: Array = [8, 22]		# [top, bottom]
const _SHAFT_1_DOORWAY_ROWS: Array = [20, 21]

# Landing B (mid room, wider — several staggered floating balconies chained across it,
# a "varanda encadeada" (chained balcony) climb instead of one flat ledge)
const _ROOM_B_COLS: Array = [10, 30]
const _ROOM_B_FLOOR: int = 9
const _ROOM_B_CEILING: int = 4
# [fromCol, toCol, row] — each one is a normal 2-tile hop up from the floor below it
const _PLATFORMS: Array = [
	[16, 19, 7], [22, 25, 7], [27, 28, 7],	# Landing B's balcony chain
	[3, 5, 20], [6, 8, 18],					# Landing A's short warm-up chain
]

# Bonus shaft off Landing B (tighter — the "master the wall-jump" section)
const _SHAFT_2_WALLS: Array = [31, 34]		# interior is 32-33
const _SHAFT_2_ROWS: Array = [1, 9]
const _SHAFT_2_DOORWAY_ROWS: Array = [7, 8]

# Bonus alcove at the top of shaft 2, holding the 5th present
const _ALCOVE_COLS: Array = [31, 36]
const _ALCOVE_FLOOR: int = 2
const _ALCOVE_CEILING: int = -2

# Teleport Nook — isolated pocket with no doorway/shaft to it at all, reachable ONLY via
# Teleport Pad. Teleport A sits on Landing B's floor; Teleport B sits in the Nook. Solid
# rock (cols 36-37) is left between Landing B/the bonus alcove and the Nook on purpose,
# so there is no walking path in — matches Levels 4/5/8/10's "teleport with a real job".
const _TP_NOOK_COLS: Array = [38, 43]
const _TP_NOOK_FLOOR: int = 9
const _TP_NOOK_CEILING: int = 4
const _TP_A_COL: int = 15	# on Landing B's floor, clear of the ledge (cols 20-27)

const _FOUNDATION_DEPTH: int = 2	# rows of solid rock below every floor

# [col, platformRow]
const _MAX_PRESENTS: int = 5	# spawn at most this many per level, randomly chosen from the pool below
# Pool of validated safe spots (floor solid, headroom clear) — more than `_MAX_PRESENTS`
# on purpose, so which ones actually spawn is randomized. Each spawned Present is still
# its own independent node under "Collectibles" (see `_spawnPresents()`), so they can be
# dragged by hand in the editor afterwards if you want to fine-tune the layout.
const _PRESENT_POOL: Array = [
	[2, _ROOM_A_FLOOR],	# main path, right by the entrance
	[6, _ROOM_A_FLOOR],	# main path, further along
	[7, 18],			# on Landing A's warm-up balcony chain (cols 6-8, row 18)
	[3, 20],			# on Landing A's warm-up balcony chain (cols 3-5, row 20)
	[17, 7],			# on Landing B's balcony chain (cols 16-19)
	[23, 7],			# on Landing B's balcony chain (cols 22-25) — rewards climbing it
	[40, _TP_NOOK_FLOOR],	# in the Teleport Nook — rewards using the pad
	[34, _ALCOVE_FLOOR],	# atop the bonus shaft — needs the tighter wall-jump climb
]

# [col, row, source_id] on the "Details" tileset (0=bush, 19-25=grass_1-7, 30=tree)
const _DECORATIONS: Array = [
	[4, 21, 30], [8, 21, 19],
	[7, 17, 19], [4, 19, 0],			# on Landing A's warm-up balcony chain
	[12, 8, 0], [17, 6, 21], [23, 6, 19], [27, 6, 20],	# on Landing B's balcony chain
	[33, 1, 19], [35, 1, 0],
	[39, 8, 20], [42, 8, 0],
]


# VARS
@onready var _foregroundLayer: TileMapLayer = $Foreground/Layer0
@onready var _backgroundLayer: TileMapLayer = $Background/Layer0
@onready var _detailsLayer: TileMapLayer = $Details/Layer0


# METHODS
func _ready():
	_buildMap()	# paints the rock/background/decorations; safe to run in the editor too
	_spawnPresents()	# also safe in the editor — spawns as real, ownable/movable child nodes

	if Engine.is_editor_hint():
		return	# editor preview: only paint the map + presents, don't run any actual gameplay logic

	_setCameraBounds()
	_adjustSkyScale()
	get_viewport().size_changed.connect(_adjustSkyScale)

	QuizGenerator.clearQuizSets()
	QuizGenerator.generateCustomChoiceQuizSet(CustomChoiceDB.level6)	# ONLY the user's Level 6 quiz set
	QuizGenerator.randomizeQuizSets()
	setupPresentQuizzes()


# METHODS - MAP BUILDING
func _buildMap() -> void:
	_foregroundLayer.visible = true
	_backgroundLayer.visible = true
	_detailsLayer.visible = true
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
		_buildPlatform(platform[0], platform[1], platform[2])
	_carveShaft(_SHAFT_2_WALLS[0], _SHAFT_2_WALLS[1], _SHAFT_2_ROWS[0], _SHAFT_2_ROWS[1])
	_carveDoorway(_ROOM_B_COLS[1], _SHAFT_2_WALLS[0], _SHAFT_2_DOORWAY_ROWS[0], _SHAFT_2_DOORWAY_ROWS[1])
	_carveRoom(_ALCOVE_COLS[0], _ALCOVE_COLS[1], _ALCOVE_FLOOR, _ALCOVE_CEILING)
	_carveShaftThroughFloor(_SHAFT_2_WALLS[0] + 1, _SHAFT_2_WALLS[1] - 1, _ALCOVE_FLOOR, _FOUNDATION_DEPTH)
	_carveRoom(_TP_NOOK_COLS[0], _TP_NOOK_COLS[1], _TP_NOOK_FLOOR, _TP_NOOK_CEILING)	# isolated, TP-only

	_fixTileSources()
	_addDecorations()

	print_debug("Level-6: map built. Foreground used cells: %s" % [_foregroundLayer.get_used_cells().size()])

func _buildBackdrop() -> void:
	for col in range(0, (_BOUNDS_COLS[1] / 2) + 1):
		for row in range(_BOUNDS_ROWS[0] - 2, _BOUNDS_ROWS[1] + 3):
			_backgroundLayer.set_cell(Vector2i(col, row), 1, Vector2i(0, 0), 0)

# Fills the whole bounding box solid. Everything else carves INTO this — nowhere in the
# level is ever "undefined" (no collision at all); it's either intentionally open or rock.
func _buildSolidMass() -> void:
	for col in range(_BOUNDS_COLS[0], _BOUNDS_COLS[1] + 1):
		for row in range(_BOUNDS_ROWS[0], _BOUNDS_ROWS[1] + 1):
			_foregroundLayer.set_cell(Vector2i(col, row), _GROUND_SOURCE, Vector2i(0, 0), 0)

# Carves a room's interior out of the solid mass, then re-solidifies its floor (and a
# foundation beneath it) — walls, ceiling and everything outside fromCol/toCol stay solid
# automatically, since they were never touched.
func _carveRoom(fromCol: int, toCol: int, floorRow: int, ceilingRow: int) -> void:
	for col in range(fromCol + 1, toCol):
		for row in range(ceilingRow + 1, floorRow):
			_foregroundLayer.erase_cell(Vector2i(col, row))
		_foregroundLayer.set_cell(Vector2i(col, floorRow), _GROUND_SOURCE, Vector2i(0, 0), 0)
		for depth in range(1, _FOUNDATION_DEPTH + 1):
			_foregroundLayer.set_cell(Vector2i(col, floorRow + depth), _GROUND_SOURCE, Vector2i(0, 0), 0)

# Carves a vertical wall-jump shaft's interior out of the solid mass — the walls on
# either side stay solid automatically.
func _carveShaft(wallColFrom: int, wallColTo: int, rowTop: int, rowBottom: int) -> void:
	for row in range(rowTop, rowBottom + 1):
		for col in range(wallColFrom + 1, wallColTo):
			_foregroundLayer.erase_cell(Vector2i(col, row))

# Punches an opening through the (otherwise double-thick, room-wall + shaft-wall)
# boundary between a room and its shaft, so the two interiors actually connect.
func _carveDoorway(roomWallCol: int, shaftWallCol: int, rowFrom: int, rowTo: int) -> void:
	for row in range(rowFrom, rowTo + 1):
		_foregroundLayer.erase_cell(Vector2i(roomWallCol, row))
		_foregroundLayer.erase_cell(Vector2i(shaftWallCol, row))

# Punches a shaft's interior back open where a room's floor + foundation, built AFTER
# the shaft, painted straight across it and resealed it. Without this, a shaft that
# arrives underneath a wide room gets capped by that room's own floor.
func _carveShaftThroughFloor(interiorFromCol: int, interiorToCol: int, floorRow: int, foundationDepth: int) -> void:
	for col in range(interiorFromCol, interiorToCol + 1):
		_foregroundLayer.erase_cell(Vector2i(col, floorRow))
		for depth in range(1, foundationDepth + 1):
			_foregroundLayer.erase_cell(Vector2i(col, floorRow + depth))

func _buildPlatform(fromCol: int, toCol: int, row: int, addFoundation: bool = true) -> void:
	# A short floating balcony. `addFoundation` gives it 1 extra solid row underneath for
	# visual thickness — turn it off for a platform stacked closely above another one, so
	# its foundation doesn't eat the lower platform's headroom.
	for col in range(fromCol, toCol + 1):
		_foregroundLayer.set_cell(Vector2i(col, row), _GROUND_SOURCE, Vector2i(0, 0), 0)
		if addFoundation:
			_foregroundLayer.set_cell(Vector2i(col, row + 1), _GROUND_SOURCE, Vector2i(0, 0), 0)
		_foregroundLayer.erase_cell(Vector2i(col, row - 1))
		_foregroundLayer.erase_cell(Vector2i(col, row - 2))

func _fixTileSources() -> void:
	# Every foreground tile uses the plain earth texture (centerGround, no grass edge) —
	# uniform "terra sem relva" everywhere, top surfaces included. Grass/bushes are still
	# added separately as Details-layer decoration on top, they're just not baked into
	# the ground tile itself anymore.
	for cell in _foregroundLayer.get_used_cells():
		_foregroundLayer.set_cell(cell, _CENTER_GROUND_SOURCE, Vector2i(0, 0), 0)

func _addDecorations() -> void:
	for decoration in _DECORATIONS:
		_detailsLayer.set_cell(Vector2i(decoration[0], decoration[1]), decoration[2], Vector2i(0, 0), 0)


# METHODS - PRESENTS
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
			node.owner = get_tree().edited_scene_root	# makes it show up (and save) in the Scene dock

		node.connect("opened", Callable(self, "_onPresentOpened"))
		node.connect("collected", Callable(self, "_onPresentCollected"))

	_initializePresentNodes()

	print_debug("Level-6: spawned %s presents directly. _collectibles now has %s children." % [chosenSpots.size(), _collectibles.get_children().size()])
