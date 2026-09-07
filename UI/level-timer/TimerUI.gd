class_name TimerUI extends PanelContainer


# VARS
var paused: bool = false: set = _setPaused

@onready var _label: Label = $Label
@onready var _timer: TimerCountUp = $TimerCountUp

# METHODS
func _ready():
	if OS.is_debug_build() and get_parent() == get_tree().root:
		start()

func _process(_delta):
	_label.text = _toFormattedMinuteString(_timer.elapsedTime as int)

func start() -> void:
	_timer.start()

func _setPaused(pausedValue: bool) -> void:
	paused = pausedValue

	_timer.paused = paused

func isRunning() -> bool:
	return _timer.isRunning()

func _toFormattedMinuteString(timeInSeconds: int) -> String:
	var minutes: int = 0

	while(timeInSeconds >= 60):
		timeInSeconds -= 60
		minutes += 1

	var formattedSeconds: String = "0%s" % timeInSeconds if timeInSeconds < 10 else "%s" % timeInSeconds
	return "%s:%s" % [minutes, formattedSeconds]
