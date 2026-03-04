extends Node2D
## Procedural planet surface generator.
##
## Generates a tile-based 2D surface from the planet's seed, placing terrain,
## resources, and points of interest. Uses a seeded noise function to create
## natural-looking biome distribution.

## Size of the generated surface in tiles.
@export var map_width: int = 64
@export var map_height: int = 64
## Tile size in pixels.
@export var tile_size: int = 16

## The TileMapLayer used to render the surface.
@onready var _tile_map: TileMapLayer = $TileMapLayer

## Generated resource node positions: Array of {position: Vector2i, resource_id: String}.
var resource_nodes: Array[Dictionary] = []
## Landing zone position (where the rover starts).
var landing_zone: Vector2i = Vector2i(32, 32)

## Terrain tile IDs mapped to tile atlas coordinates.
## These correspond to the tileset atlas layout.
const TERRAIN_TILES: Dictionary = {
	"rock": Vector2i(0, 0),
	"dust": Vector2i(1, 0),
	"crater": Vector2i(2, 0),
	"gravel": Vector2i(3, 0),
	"ice": Vector2i(0, 1),
	"snow": Vector2i(1, 1),
	"frozen_lake": Vector2i(2, 1),
	"glacier": Vector2i(3, 1),
	"lava": Vector2i(0, 2),
	"basalt": Vector2i(1, 2),
	"obsidian": Vector2i(2, 2),
	"ash": Vector2i(3, 2),
	"grass": Vector2i(0, 3),
	"forest": Vector2i(1, 3),
	"water": Vector2i(2, 3),
	"sand": Vector2i(3, 3),
	"mountain": Vector2i(0, 4),
	"dune": Vector2i(1, 4),
	"mesa": Vector2i(2, 4),
	"dry_lake": Vector2i(3, 4),
	"acid_pool": Vector2i(0, 5),
	"corroded_rock": Vector2i(1, 5),
	"chemical_deposit": Vector2i(2, 5),
	"vent": Vector2i(3, 5),
}


## Generate the surface for a given planet.
func generate_surface(planet: PlanetData) -> void:
	resource_nodes.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = planet.surface_seed

	# Get tile palette for this planet type
	var type_data: Dictionary = PlanetData._get_planet_type_data(planet.planet_type_id)
	var palette: Array = type_data.get("tile_palette", ["rock", "dust"])

	if palette.is_empty():
		push_warning("No tile palette for planet type: %s" % planet.planet_type_id)
		return

	# Create noise for terrain distribution
	var noise := FastNoiseLite.new()
	noise.seed = planet.surface_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	noise.fractal_octaves = 4

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = planet.surface_seed + 1000
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.15

	# Generate terrain tiles
	for x: int in range(map_width):
		for y: int in range(map_height):
			var noise_val: float = noise.get_noise_2d(float(x), float(y))
			var detail_val: float = detail_noise.get_noise_2d(float(x), float(y))
			var combined: float = (noise_val + detail_val * 0.3) * 0.5 + 0.5
			# Map noise value to palette index
			var tile_idx: int = clampi(
				floori(combined * palette.size()),
				0,
				palette.size() - 1,
			)
			var tile_name: String = palette[tile_idx]
			var atlas_coord: Vector2i = TERRAIN_TILES.get(tile_name, Vector2i(0, 0))
			_tile_map.set_cell(Vector2i(x, y), 0, atlas_coord)

	# Place landing zone near center with clear terrain
	landing_zone = Vector2i(map_width / 2, map_height / 2)
	# Clear a small area around landing zone
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			var clear_pos := Vector2i(landing_zone.x + dx, landing_zone.y + dy)
			var base_tile: String = palette[0] if palette.size() > 0 else "rock"
			_tile_map.set_cell(clear_pos, 0, TERRAIN_TILES.get(base_tile, Vector2i(0, 0)))

	# Place resource nodes
	var resource_density: float = type_data.get("resource_density", 0.3)
	var common_resources: Array = type_data.get("common_resources", [])
	var num_resources: int = floori(map_width * map_height * resource_density * 0.01)

	for _i: int in range(num_resources):
		var rx: int = rng.randi_range(2, map_width - 3)
		var ry: int = rng.randi_range(2, map_height - 3)
		# Don't place on landing zone
		if absf(rx - landing_zone.x) < 3 and absf(ry - landing_zone.y) < 3:
			continue
		if common_resources.size() > 0:
			var res_id: String = common_resources[rng.randi_range(0, common_resources.size() - 1)]
			resource_nodes.append({
				"position": Vector2i(rx, ry),
				"resource_id": res_id,
				"collected": false,
			})


## Get the world position (pixels) of a tile coordinate.
func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos) * tile_size + Vector2(tile_size / 2.0, tile_size / 2.0)


## Get the tile coordinate from a world position.
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / tile_size), floori(world_pos.y / tile_size))


## Check if a tile coordinate is within bounds.
func is_valid_tile(tile_pos: Vector2i) -> bool:
	return tile_pos.x >= 0 and tile_pos.x < map_width and tile_pos.y >= 0 and tile_pos.y < map_height
