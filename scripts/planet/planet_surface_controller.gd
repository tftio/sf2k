extends Node2D
## Controller for the planet surface scene.
##
## Coordinates the surface generator, rover, and UI.
## Handles planet setup and lift-off transitions.

## Emitted when the player lifts off from the planet.
signal lift_off()

@onready var _surface_gen: Node2D = $SurfaceGenerator
@onready var _rover: CharacterBody2D = $Rover


func _ready() -> void:
	if _rover.has_signal("lift_off_requested"):
		_rover.lift_off_requested.connect(_on_lift_off_requested)
	if _rover.has_signal("resource_collected"):
		_rover.resource_collected.connect(_on_resource_collected)


## Initialize the planet surface with data.
func setup_planet(planet: PlanetData) -> void:
	GameState.current_planet_index = planet.orbit_index
	_surface_gen.generate_surface(planet)
	_rover.setup(_surface_gen, planet)


func _on_lift_off_requested() -> void:
	lift_off.emit()


func _on_resource_collected(resource_id: String, quantity: int) -> void:
	# HUD will update via GameState signals
	pass
