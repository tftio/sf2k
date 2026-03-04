extends Node
## Main scene controller -- entry point for the game.
##
## Manages scene switching between game modes (space, planet, starbase, menu).
## Holds the currently active scene under the CurrentScene node.

@onready var _current_scene_parent: Node = $CurrentScene
@onready var _mode_switch: Node = $ModeSwitch

## Packed scenes for each mode.
var _space_scene: PackedScene = preload("res://scenes/space/space.tscn")
var _planet_scene: PackedScene = preload("res://scenes/planet/planet_surface.tscn")

## The currently active scene instance.
var _active_scene: Node = null


func _ready() -> void:
	# Start a new game with a random seed (placeholder -- will add menu later)
	var seed_val: int = randi()
	GameState.new_game(seed_val)
	_switch_to_space()


## Switch to the 3D space navigation scene.
func _switch_to_space() -> void:
	_clear_current_scene()
	var space_instance: Node = _space_scene.instantiate()
	_current_scene_parent.add_child(space_instance)
	_active_scene = space_instance
	GameState.current_mode = GameState.Mode.SPACE

	# Connect signals for scene transitions
	if space_instance.has_signal("arrived_at_system"):
		space_instance.arrived_at_system.connect(_on_arrived_at_system)


## Switch to the 2D planet surface scene.
func _switch_to_planet(planet: PlanetData) -> void:
	await _mode_switch.transition_out()
	_clear_current_scene()
	var planet_instance: Node = _planet_scene.instantiate()
	_current_scene_parent.add_child(planet_instance)
	_active_scene = planet_instance
	GameState.current_mode = GameState.Mode.PLANET

	# Initialize planet scene with data
	if planet_instance.has_method("setup_planet"):
		planet_instance.setup_planet(planet)

	# Connect lift-off signal
	if planet_instance.has_signal("lift_off"):
		planet_instance.lift_off.connect(_on_planet_lift_off)

	await _mode_switch.transition_in()


## Remove the current active scene.
func _clear_current_scene() -> void:
	if _active_scene:
		_active_scene.queue_free()
		_active_scene = null


## Called when the player arrives at a star system.
func _on_arrived_at_system(system_index: int) -> void:
	# For now, auto-save on arrival
	SaveManager.auto_save()


## Called when the player lifts off from a planet.
func _on_planet_lift_off() -> void:
	_mode_switch.transition_out()
	_clear_current_scene()
	var space_instance: Node = _space_scene.instantiate()
	_current_scene_parent.add_child(space_instance)
	_active_scene = space_instance
	GameState.current_mode = GameState.Mode.SPACE
	GameState.current_planet_index = -1
	_mode_switch.transition_in()
