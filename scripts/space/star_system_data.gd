extends RefCounted
class_name StarSystemData
## Data class representing a single star system in the galaxy.
##
## Generated deterministically from the galaxy seed and the system's index.
## Holds the star type, position, name, and list of planets.

## Star type ID (references star_types.json).
var star_type_id: String = ""
## Human-readable system name.
var system_name: String = ""
## Position in 3D galaxy space.
var position: Vector3 = Vector3.ZERO
## Index of this system in the galaxy array.
var index: int = -1
## Number of planets orbiting this star.
var planet_count: int = 0
## Whether this system has a starbase.
var has_starbase: bool = false
## Seed for this specific system's procedural content.
var system_seed: int = 0

## Star type data loaded from JSON (cached after first access).
static var _star_types_cache: Array = []

## Greek letter prefixes for star naming.
const NAME_PREFIXES: Array[String] = [
	"Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta",
	"Theta", "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi",
	"Omicron", "Pi", "Rho", "Sigma", "Tau", "Upsilon",
]

## Constellation-style suffixes for star naming.
const NAME_SUFFIXES: Array[String] = [
	"Centauri", "Eridani", "Cygni", "Draconis", "Leonis",
	"Orionis", "Pavonis", "Tauri", "Ursae", "Velorum",
	"Aquilae", "Bootis", "Carinae", "Fornacis", "Gruis",
	"Hydrae", "Indi", "Lyrae", "Muscae", "Normae",
	"Ophiuchi", "Persei", "Reticuli", "Serpentis", "Tucanae",
]


## Generate a star system deterministically from galaxy seed and index.
static func generate(galaxy_seed: int, system_index: int) -> StarSystemData:
	var data := StarSystemData.new()
	data.index = system_index
	data.system_seed = galaxy_seed * 31 + system_index * 7919

	var rng := RandomNumberGenerator.new()
	rng.seed = data.system_seed

	# Position: distribute in a roughly disk-shaped galaxy
	var angle: float = rng.randf() * TAU
	var radius: float = rng.randf_range(10.0, 500.0)
	# Slight vertical spread for 3D effect
	var height: float = rng.randf_range(-30.0, 30.0)
	data.position = Vector3(
		cos(angle) * radius,
		height,
		sin(angle) * radius,
	)

	# Star type: weighted by rarity
	data.star_type_id = _pick_star_type(rng)

	# Name: Greek prefix + constellation suffix
	var prefix_idx: int = rng.randi_range(0, NAME_PREFIXES.size() - 1)
	var suffix_idx: int = rng.randi_range(0, NAME_SUFFIXES.size() - 1)
	data.system_name = "%s %s" % [NAME_PREFIXES[prefix_idx], NAME_SUFFIXES[suffix_idx]]

	# Planet count: based on star type max_planets
	var star_data: Dictionary = _get_star_type_data(data.star_type_id)
	var max_p: int = star_data.get("max_planets", 4)
	data.planet_count = rng.randi_range(0, max_p)

	# Starbase: small chance, higher near center of galaxy
	var center_dist: float = data.position.length()
	var starbase_chance: float = 0.15 if center_dist < 150.0 else 0.05
	data.has_starbase = rng.randf() < starbase_chance

	return data


## Load star types from JSON if not already cached.
static func _load_star_types() -> void:
	if _star_types_cache.size() > 0:
		return
	var file: FileAccess = FileAccess.open("res://data/star_types.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load star_types.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_star_types_cache = json.data.get("star_types", [])
	file.close()


## Pick a star type weighted by rarity.
static func _pick_star_type(rng: RandomNumberGenerator) -> String:
	_load_star_types()
	var total_weight: float = 0.0
	for st: Dictionary in _star_types_cache:
		total_weight += st.get("rarity", 0.1)

	var roll: float = rng.randf() * total_weight
	var accumulated: float = 0.0
	for st: Dictionary in _star_types_cache:
		accumulated += st.get("rarity", 0.1)
		if roll <= accumulated:
			return st.get("id", "class_g")
	return "class_g"


## Get the full data dictionary for a star type ID.
static func _get_star_type_data(type_id: String) -> Dictionary:
	_load_star_types()
	for st: Dictionary in _star_types_cache:
		if st.get("id", "") == type_id:
			return st
	return {}


## Get the display color for this system's star.
func get_star_color() -> Color:
	var star_data: Dictionary = _get_star_type_data(star_type_id)
	var hex: String = star_data.get("color", "#ffffff")
	return Color.from_string(hex, Color.WHITE)
