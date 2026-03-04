extends Node
## Global game state singleton (autoloaded as GameState).
##
## Holds all persistent state: galaxy seed, player location, fuel, cargo,
## credits, debt, discoveries, and current game mode. Other systems read
## and write through this node rather than storing state locally.

## Emitted when the game mode changes (space, planet, starbase, menu).
signal mode_changed(new_mode: StringName)
## Emitted when fuel level changes.
signal fuel_changed(new_fuel: float)
## Emitted when cargo contents change.
signal cargo_changed()
## Emitted when credits or debt change.
signal finances_changed()
## Emitted when a new star system is discovered.
signal system_discovered(system_index: int)

## Game modes
enum Mode {
	MENU,
	SPACE,
	PLANET,
	STARBASE,
}

## Galaxy seed -- determines the entire galaxy layout and all procedural content.
## Set once at new-game and never changed.
var galaxy_seed: int = 0

## Current game mode.
var current_mode: Mode = Mode.MENU:
	set(value):
		current_mode = value
		mode_changed.emit(value)

## Index of the star system the player is currently in (or traveling to).
var current_system_index: int = -1

## Index of the planet the player is on (-1 if in space).
var current_planet_index: int = -1

## Ship fuel level (0.0 to max_fuel).
var fuel: float = 100.0:
	set(value):
		fuel = clampf(value, 0.0, max_fuel)
		fuel_changed.emit(fuel)

## Maximum fuel capacity (upgradeable later).
var max_fuel: float = 100.0

## Player credits.
var credits: int = 500:
	set(value):
		credits = value
		finances_changed.emit()

## Debt owed (from rescue/recovery).
var debt: int = 0:
	set(value):
		debt = value
		finances_changed.emit()

## Cargo hold: resource_id -> quantity.
var cargo: Dictionary = {}

## Maximum cargo capacity in weight units.
var max_cargo_weight: float = 50.0

## Set of discovered star system indices.
var discovered_systems: Dictionary = {}

## Ship position in 3D galaxy space (used for floating-origin calculations).
var ship_position: Vector3 = Vector3.ZERO

## Whether the player is currently traveling between systems.
var is_traveling: bool = false

## Total number of star systems in the galaxy.
const GALAXY_SIZE: int = 200

## Fuel cost per unit of distance traveled.
const FUEL_COST_PER_UNIT: float = 0.1


func _ready() -> void:
	pass


## Start a new game with the given galaxy seed.
func new_game(seed_value: int) -> void:
	galaxy_seed = seed_value
	current_mode = Mode.SPACE
	current_system_index = 0
	current_planet_index = -1
	fuel = max_fuel
	credits = 500
	debt = 0
	cargo = {}
	discovered_systems = {}
	ship_position = Vector3.ZERO
	is_traveling = false
	# Discover the starting system
	discover_system(0)


## Mark a star system as discovered.
func discover_system(system_index: int) -> void:
	if not discovered_systems.has(system_index):
		discovered_systems[system_index] = true
		system_discovered.emit(system_index)


## Add a resource to cargo. Returns the amount actually added (may be less
## if cargo is full).
func add_cargo(resource_id: String, quantity: int, weight_per_unit: float) -> int:
	var current_weight: float = get_cargo_weight()
	var available_weight: float = max_cargo_weight - current_weight
	var max_addable: int = floori(available_weight / weight_per_unit) if weight_per_unit > 0.0 else quantity
	var actual_add: int = mini(quantity, max_addable)
	if actual_add > 0:
		if cargo.has(resource_id):
			cargo[resource_id] += actual_add
		else:
			cargo[resource_id] = actual_add
		cargo_changed.emit()
	return actual_add


## Remove a resource from cargo. Returns the amount actually removed.
func remove_cargo(resource_id: String, quantity: int) -> int:
	if not cargo.has(resource_id):
		return 0
	var actual_remove: int = mini(quantity, cargo[resource_id])
	cargo[resource_id] -= actual_remove
	if cargo[resource_id] <= 0:
		cargo.erase(resource_id)
	cargo_changed.emit()
	return actual_remove


## Calculate total weight of cargo currently held.
func get_cargo_weight() -> float:
	# For now, use a simple weight lookup. In the future this will
	# reference the resources.json data.
	var total: float = 0.0
	for resource_id: String in cargo:
		# Default weight of 1.0 per unit; will be data-driven later
		total += cargo[resource_id] * 1.0
	return total


## Consume fuel for traveling a given distance. Returns true if enough fuel.
func consume_fuel(distance: float) -> bool:
	var cost: float = distance * FUEL_COST_PER_UNIT
	if fuel >= cost:
		fuel -= cost
		return true
	return false


## Serialize game state to a dictionary for saving.
func serialize() -> Dictionary:
	return {
		"galaxy_seed": galaxy_seed,
		"current_mode": current_mode,
		"current_system_index": current_system_index,
		"current_planet_index": current_planet_index,
		"fuel": fuel,
		"max_fuel": max_fuel,
		"credits": credits,
		"debt": debt,
		"cargo": cargo.duplicate(),
		"max_cargo_weight": max_cargo_weight,
		"discovered_systems": discovered_systems.keys(),
		"ship_position": {"x": ship_position.x, "y": ship_position.y, "z": ship_position.z},
		"is_traveling": is_traveling,
	}


## Restore game state from a serialized dictionary.
func deserialize(data: Dictionary) -> void:
	galaxy_seed = data.get("galaxy_seed", 0)
	current_mode = data.get("current_mode", Mode.MENU) as Mode
	current_system_index = data.get("current_system_index", -1)
	current_planet_index = data.get("current_planet_index", -1)
	fuel = data.get("fuel", 100.0)
	max_fuel = data.get("max_fuel", 100.0)
	credits = data.get("credits", 500)
	debt = data.get("debt", 0)
	cargo = data.get("cargo", {})
	max_cargo_weight = data.get("max_cargo_weight", 50.0)
	is_traveling = data.get("is_traveling", false)

	discovered_systems = {}
	var disc_list: Array = data.get("discovered_systems", [])
	for idx: int in disc_list:
		discovered_systems[idx] = true

	var pos_data: Dictionary = data.get("ship_position", {})
	ship_position = Vector3(
		pos_data.get("x", 0.0),
		pos_data.get("y", 0.0),
		pos_data.get("z", 0.0),
	)
