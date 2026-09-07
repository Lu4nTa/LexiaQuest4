class_name Player extends CharacterBody2D


# PRELOADS
const _dustCloudScene: PackedScene =  preload("res://player/dust-cloud/DustCloud.tscn")

# SIGNALS
signal died

# EXPORTS
# Vertical movement properties
@export_range(0, 50) var ACCEL_GRAVITY: int = 35	# In 1 frame, how many pixels the player will accelerate downwards
@export_range(-3000, 0, 10) var MAX_SPEED_UP: int = -1500
@export_range(0, 3000, 10) var MAX_SPEED_DOWN: int = 1500
@export_range(-2000, 0, 10) var ACCEL_JUMP: int = -500
# Horizontal movement properties
@export_range(0, 50) var ACCEL_WALK: int = 20	# In 1 frame, how many pixels the player will accelerate horizontaly when walking
@export_range(0, 1, 0.05) var ACCEL_WALK_FRICTION: float = 0.6	# In 1 frame, percentage of horizontal ground speed the player will keep after friction is applied
@export_range(0, 1, 0.05) var ACCEL_AIR_FRICTION: float = 0.9	# In 1 frame, percentage of horizontal aerial speed the player will keep after friction is applied
@export_range(0, 500, 10) var MAX_SPEED_WALK: int = 280
# Wall sliding properties
@export_range(0, 50) var ACCEL_WALL_SLIDE: int = 10
@export_range(0, 500, 10) var MAX_SPEED_WALL_SLIDE: int = 150

# ENUMS
enum STATES {WALKING, FALLING, WALL_SLIDING}

# VARS
# NOTE (Godot 4): `velocity` no longer needs to be declared here — CharacterBody2D
# already provides a built-in `velocity: Vector2` property that `move_and_slide()` reads and updates.
var paused: bool = false
var quiz_locked: bool = false

@onready var _wallSlidingDetector: WallSlidingDetector = $WallSlidingDetector
@onready var _hitbox: CollisionShape2D = $CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite
@onready var _jumpSFX: AudioStreamPlayer = $JumpSFX
@onready var _animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var _dustCloudTimer: Timer = $DustCloudTimer
@onready var _wallJumpFrictionTimer: Timer = $WallJumpFrictionTimer
var _canWallSlide: bool = true
var _previousState = null
var _state = STATES.FALLING: set = _setState

# METHODS
func _ready():
	_sprite.animation = "idle"
	_sprite.speed_scale = 1
	_sprite.play()

func _input(event: InputEvent):
	if paused or quiz_locked:
		return

	if event is InputEventKey:
		if event.is_action_pressed("jump"):
			_jump()

func _physics_process(delta: float):
	if paused or quiz_locked:
		velocity = Vector2.ZERO
		return

	# Apply input-based movement velocities and relevant friction
	_applyMovement(delta)

	# Move player and resolve collisions.
	# Godot 4: `move_and_slide()` takes no arguments and reads/updates the built-in
	# `velocity` property directly; `up_direction` defaults to Vector2(0, -1), same as before.
	move_and_slide()

	# Change player state to most appropriate
	_changeState()

	# Check if wall-sliding can be enabled
	_checkCanWallSlideProcess()

func _process(_delta: float):
	if paused or quiz_locked:
		return

	_dustCloudsProcess()

func _setState(stateValue):
	_previousState = _state

	_state = stateValue

	print_debug("New state: ", _state)

# Hard movement lock used while a quiz is open. It is independent of the
# Level signal so a Present can freeze the player before the quiz UI is shown.
func lock_for_quiz() -> void:
	# Freeze only the Player's gameplay callbacks. Do NOT change process_mode:
	# keeping the normal inherited process mode makes the unlock deterministic.
	quiz_locked = true
	paused = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process_input(false)
	set_process(false)
	if is_instance_valid(_sprite):
		_sprite.animation = "idle"
		_sprite.speed_scale = 1.0

func unlock_from_quiz() -> void:
	# Restore the normal Player processing after the quiz is actually closed.
	velocity = Vector2.ZERO
	quiz_locked = false
	paused = false
	set_process(true)
	set_physics_process(true)
	set_process_input(true)
	# Re-evaluate the state on the next physics frame instead of leaving the
	# Player stuck in a previous wall/falling state.
	_state = STATES.WALKING if is_on_floor() else STATES.FALLING
	_previousState = _state

# Triggers player death
func kill() -> void:
	paused = true

	# Play death animation and SFX
	# "died" signal is emitted when animation is over
	_animationPlayer.play("Death")
	$DeathSFX.play()

# Calculate and apply player horizontal movement changes made by their inputs.
# Only meant to be used in `_physics_process()`.
func _applyMovement(_delta: float) -> void:
	var pressingRight: bool = Input.is_action_pressed("move_right")
	var pressingLeft: bool = Input.is_action_pressed("move_left")
	var intendedDirection: int = int(pressingRight) - int(pressingLeft)	# -1 (left), 0 (both/none) or 1 (right)

	match _state:
		STATES.WALKING, STATES.FALLING:
			# Apply gravity
			velocity.y += ACCEL_GRAVITY

			# Apply movement acceleration in the player's intended direction
			# If player is pressing both movement keys or none, don't apply movement acceleration
			velocity.x += ACCEL_WALK * intendedDirection

			# Apply friction influence
			if STATES.WALL_SLIDING != _previousState or not _wallJumpFrictionTimer.time_left:
				_applyHorizontalFriction(intendedDirection)

			# Clamp vertical and horizontal movement
			velocity.y = clamp(velocity.y, MAX_SPEED_UP, MAX_SPEED_DOWN)
			velocity.x = clamp(velocity.x, -MAX_SPEED_WALK, MAX_SPEED_WALK)

			# Change sprite direction
			_changeSpriteDirection(intendedDirection)

			# Change sprite animation state
			_changeSpriteAnimation()

		STATES.WALL_SLIDING:
			velocity.y += ACCEL_WALL_SLIDE if velocity.y > 0 else ACCEL_GRAVITY

			# Clamp vertical movement
			velocity.y = clamp(velocity.y, MAX_SPEED_UP, MAX_SPEED_WALL_SLIDE)

		# This method should have instructions for every state
		_:
			assert(false, "The value '%s' does not exist in 'Player.STATES'" % _state)

# Calculates and applies the friction to be applied to the player.
# No friction is applied if the player is moving in the same direction as their current velocity.
# `intended_direction` must be an integer of value -1, 0 or 1, each representing a movement direction intended by the player, respectively: left, both/none and right.
# Only meant to be used in `_physics_process()`.
func _applyHorizontalFriction(intended_direction: int) -> void:
	# If player wants to move in the same direction as their current movement, don't apply friction
	if intended_direction * velocity.x > 0:
		return

	if abs(velocity.x) > 1:
		velocity.x *= ACCEL_WALK_FRICTION if STATES.WALKING == _state else ACCEL_AIR_FRICTION
	else:
		velocity.x = 0

func _changeSpriteDirection(intendedDirection: int) -> void:
	if 0 != intendedDirection:
		_sprite.flip_h = bool(1 - intendedDirection)

func _changeSpriteAnimation() -> void:
	var absVelocityX: float = abs(velocity.x)

	match _state:
		STATES.WALKING:
			if velocity.x:
				_sprite.animation = "walking"
				_sprite.speed_scale = absVelocityX/MAX_SPEED_WALK
			else:
				_sprite.animation = "idle"
				_sprite.speed_scale = 1

		STATES.FALLING:
			_sprite.animation = "falling"
			_sprite.speed_scale = 1

		_:
			_sprite.animation = "idle"
			_sprite.speed_scale = 1

# Checks some conditions to determine which state the player should be in and applies it.
# Only meant to be used in `_physics_process()`.
func _changeState() -> void:
	if STATES.WALKING != _state and is_on_floor():
		self._state = STATES.WALKING
		_wallJumpFrictionTimer.stop()

	elif (STATES.WALL_SLIDING != _state
	and STATES.WALKING != _state
	and _wallSlidingDetector.getCollisionSide()
	and _canWallSlide):
		self._state = STATES.WALL_SLIDING
		velocity.x = 0

	elif STATES.FALLING != _state and not is_on_floor() and not _wallSlidingDetector.getCollisionSide():
		self._state = STATES.FALLING

# Controls the creation of dust clouds when wall-sliding
func _dustCloudsProcess() -> void:
	if STATES.WALL_SLIDING == _state and not _dustCloudTimer.time_left:
		var dustCloud: DustCloud = _dustCloudScene.instantiate()
		# Godot 4: `.size` is the full width/height (was `.extents`, half-width/height, in Godot 3) —
		# dividing by 4 here (instead of the old /2) keeps the exact same offset as before.
		var positionX: float = global_position.x + ((_hitbox.shape.size.x / 4) * _wallSlidingDetector.getCollisionSide())
		var positionY: float = global_position.y + (_hitbox.shape.size.y / 4)
		dustCloud.global_position = Vector2(positionX, positionY)
		get_tree().current_scene.add_child(dustCloud)

		_dustCloudTimer.start(_dustCloudTimer.wait_time)

		print_debug("Created dust cloud (%s, %s)" % [dustCloud.global_position.x, dustCloud.global_position.y])

# Contains all the jumping and wall-jumping logic
func _jump() -> void:
	match _state:
		# Jump
		STATES.WALKING:
			velocity.y = ACCEL_JUMP
			self._state = STATES.FALLING
			_jumpSFX.play()

		# Wall jump
		STATES.WALL_SLIDING:
			var wallCollisionSide: int = _wallSlidingDetector.getCollisionSide()

			self._state = STATES.FALLING
			velocity.y = ACCEL_JUMP
			velocity.x = -MAX_SPEED_WALK if 1 == wallCollisionSide else MAX_SPEED_WALK
			_changeSpriteDirection(-wallCollisionSide)
			_canWallSlide = false
			_jumpSFX.play()

			_wallJumpFrictionTimer.start()

		# Nothing happens
		_:
			pass

# Checks if wall-sliding detectors are no longer colliding with the previous wall
# Only meant to be used in `_physics_process()`
func _checkCanWallSlideProcess() -> void:
	if not _canWallSlide and not _wallSlidingDetector.getCollisionSide():
		_canWallSlide = true

func _on_AnimationPlayer_animation_finished(anim_name:String):
	match anim_name:
		"Death":
			emit_signal("died")

		_:
			pass
