extends CanvasLayer
## Handles visual transitions between game modes (space <-> planet).
##
## Provides fade-to-black and fade-from-black transitions.

## Duration of fade transitions in seconds.
@export var fade_duration: float = 0.5

@onready var _overlay: ColorRect = $ColorRect


func _ready() -> void:
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fade to black (call before switching scenes).
func transition_out() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color", Color(0, 0, 0, 1), fade_duration)
	await tween.finished


## Fade from black (call after new scene is ready).
func transition_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color", Color(0, 0, 0, 0), fade_duration)
	await tween.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
