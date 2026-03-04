extends RefCounted
class_name PlanetData
## Data class representing a single planet within a star system.
##
## Generated deterministically from galaxy seed, star index, and planet index.
## Holds planet type, properties, and the seed used for surface generation.

## Planet type ID (references planet_types.json).
var planet_type_id: String = ""
## Display name for this planet.
var planet_name: String = ""
## Orbital index within the star system (0 = closest to star).
var orbit_index: int = 0
## Star system this planet belongs to.
var star_index: int = 0
## Surface gravity multiplier (1.0 = Earth-like).
var gravity: float = 1.0
## Surface temperature in Celsius.
var temperature: float = 20.0
## Whether the planet has an atmosphere.
var has_atmosphere: bool = false
## Seed for surface terrain generation.
var surface_seed: int = 0
## Whether this planet can be landed on.
var is_landable: bool = true

## Planet type data loaded from JSON (cached).
static var _planet_types_cache: Array = []

## Roman numeral suffixes for planet naming.
const ROMAN_NUMERALS: Array[String] = [
	"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
]


## Generate a planet deterministically from seeds and indices.
static func generate(galaxy_seed: int, star_idx: int, planet_idx: int, star_name: String) -> PlanetData:
	var data := PlanetData.new()
	data.star_index = star_idx
	data.orbit_index = planet_idx
	data.surface_seed = galaxy_seed * 37 + star_idx * 7919 + planet_idx * 104729

	var rng := RandomNumberGenerator.new()
	rng.seed = data.surface_seed

	# Planet type: weighted by distance from star (inner = hotter types)
	data.planet_type_id = _pick_planet_type(rng, planet_idx)

	# Name: star name + roman numeral
	if planet_idx < ROMAN_NUMERALS.size():
		data.planet_name = "%s %s" % [star_name, ROMAN_NUMERALS[planet_idx]]
	else:
		data.planet_name = "%s %d" % [star_name, planet_idx + 1]

	# Properties from type data
	var type_data: Dictionary = _get_planet_type_data(data.planet_type_id)
	data.has_atmosphere = type_data.get("atmosphere", false)
	data.is_landable = type_data.get("landing_difficulty", 0.0) >= 0.0

	var grav_range: Array = type_data.get("gravity_range", [0.5, 1.0])
	data.gravity = rng.randf_range(grav_range[0], grav_range[1])

	var temp_range: Array = type_data.get("temperature_range", [-50, 50])
	data.temperature = rng.randf_range(temp_range[0], temp_range[1])

	return data


## Load planet types from JSON if not cached.
static func _load_planet_types() -> void:
	if _planet_types_cache.size() > 0:
		return
	var file: FileAccess = FileAccess.open("res://data/planet_types.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load planet_types.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_planet_types_cache = json.data.get("planet_types", [])
	file.close()


## Pick a planet type based on orbit position.
## Inner orbits favor hot types, outer orbits favor cold types.
static func _pick_planet_type(rng: RandomNumberGenerator, orbit_idx: int) -> String:
	_load_planet_types()

	# Weight types by orbit: inner = volcanic/barren, mid = temperate, outer = ice/gas
	var roll: float = rng.randf()
	match orbit_idx:
		0, 1:
			# Inner orbits
			if roll < 0.3:
				return "volcanic"
			elif roll < 0.6:
				return "barren"
			elif roll < 0.8:
				return "toxic"
			else:
				return "desert"
		2, 3:
			# Mid orbits (habitable zone)
			if roll < 0.3:
				return "temperate"
			elif roll < 0.5:
				return "desert"
			elif roll < 0.7:
				return "barren"
			else:
				return "toxic"
		_:
			# Outer orbits
			if roll < 0.35:
				return "gas_giant"
			elif roll < 0.6:
				return "ice"
			elif roll < 0.8:
				return "barren"
			else:
				return "toxic"


## Get the full data dictionary for a planet type ID.
static func _get_planet_type_data(type_id: String) -> Dictionary:
	_load_planet_types()
	for pt: Dictionary in _planet_types_cache:
		if pt.get("id", "") == type_id:
			return pt
	return {}


## Get the resource IDs commonly found on this planet type.
func get_common_resources() -> Array:
	var type_data: Dictionary = _get_planet_type_data(planet_type_id)
	return type_data.get("common_resources", [])


## Get the hazards present on this planet type.
func get_hazards() -> Array:
	var type_data: Dictionary = _get_planet_type_data(planet_type_id)
	return type_data.get("hazards", [])
