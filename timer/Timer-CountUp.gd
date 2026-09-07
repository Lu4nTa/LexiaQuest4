class_name TimerCountUp extends Node


# VARS
var elapsedTime: float = 0: get = _getElapsedTime	# Elapsed time, in seconds
var paused: bool = false	# If `true`, timer will not count up the time and `start()` won't do anything

var _running: bool = false	# If `true`, timer was started while `paused` was `false` and it's now counting up the time

# METHODS
func _process(delta):
	if not paused and _running:
		elapsedTime += delta

func _getElapsedTime() -> float:
	return elapsedTime

# Start the timer
# If timer is already running, reset elapsed time
# Nothing happens if timer is paused
func start() -> void:
	if not paused:
		elapsedTime = 0
		_running = true

func isRunning() -> bool:
	return _running and not paused
