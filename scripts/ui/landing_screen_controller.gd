extends CanvasLayer
## Landing screen controller.
##
## Shows planet information and allows the player to land or abort.
## Displayed when the player approaches a planet in a star system.

## Emitted when the player confirms landing.
signal land_confirmed(planet: PlanetData)
## Emitted when the player aborts landing.
signal land_aborted()

@onready var _name_label: Label = $Panel/VBoxContainer/NameLabel
@onready var _type_label: Label = $Panel/VBoxContainer/TypeLabel
@onready var _gravity_label: Label = $Panel/VBoxContainer/GravityLabel
@onready var _temp_label: Label = $Panel/VBoxContainer/TempLabel
@onready var _hazards_label: Label = $Panel/VBoxContainer/HazardsLabel
@onready var _land_button: Button = $Panel/VBoxContainer/ButtonContainer/LandButton
@onready var _abort_button: Button = $Panel/VBoxContainer/ButtonContainer/AbortButton

## The planet data being shown.
var _planet: PlanetData = null


func _ready() -> void:
	visible = false
	_land_button.pressed.connect(_on_land_pressed)
	_abort_button.pressed.connect(_on_abort_pressed)


## Show the landing screen for a planet.
func show_planet(planet: PlanetData) -> void:
	_planet = planet
	_name_label.text = planet.planet_name
	_type_label.text = "Type: %s" % planet.planet_type_id.capitalize()
	_gravity_label.text = "Gravity: %.1fg" % planet.gravity
	_temp_label.text = "Temperature: %.0f C" % planet.temperature

	var hazards: Array = planet.get_hazards()
	if hazards.is_empty():
		_hazards_label.text = "Hazards: None"
	else:
		_hazards_label.text = "Hazards: %s" % ", ".join(hazards)

	if not planet.is_landable:
		_land_button.disabled = true
		_land_button.text = "NO LANDING"
	else:
		_land_button.disabled = false
		_land_button.text = "LAND"

	visible = true


func _on_land_pressed() -> void:
	visible = false
	if _planet:
		land_confirmed.emit(_planet)


func _on_abort_pressed() -> void:
	visible = false
	land_aborted.emit()
