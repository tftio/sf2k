extends CharacterBody2D
## Player-controlled rover for planet surface exploration.
##
## Handles movement, collision, resource scanning/collection,
## and environmental hazard effects.

## Emitted when the rover collects a resource.
signal resource_collected(resource_id: String, quantity: int)
## Emitted when the rover scans and finds something nearby.
signal scan_complete(results: Array)
## Emitted when the rover takes environmental damage.
signal hazard_damage(hazard_type: String, amount: float)
## Emitted when the player initiates lift-off.
signal lift_off_requested()

## Rover movement speed in pixels per second.
@export var move_speed: float = 100.0
## Scan radius in tiles.
@export var scan_radius: int = 5
## Collection range in tiles.
@export var collection_range: int = 1

## Reference to the surface generator for resource/terrain queries.
var surface_generator: Node = null
## Current planet data.
var planet_data: PlanetData = null
## Rover hull integrity (0 to max).
var hull: float = 100.0
var max_hull: float = 100.0

## Hazard damage rates per second by type.
const HAZARD_DAMAGE: Dictionary = {
	"radiation": 2.0,
	"cold": 1.5,
	"heat": 3.0,
	"toxic_gas": 2.5,
	"acid": 4.0,
}


func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	_handle_movement()
	_apply_hazards(delta)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_collect_resource()
	elif event.is_action_pressed("scan"):
		_scan_area()
	elif event.is_action_pressed("lift_off"):
		lift_off_requested.emit()


## Handle WASD/arrow movement input.
func _handle_movement() -> void:
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0

	velocity = input_dir.normalized() * move_speed


## Apply environmental hazard damage based on planet type.
func _apply_hazards(delta: float) -> void:
	if planet_data == null:
		return
	var hazards: Array = planet_data.get_hazards()
	for hazard: String in hazards:
		var dmg_rate: float = HAZARD_DAMAGE.get(hazard, 0.0)
		if dmg_rate > 0.0:
			var damage: float = dmg_rate * delta
			hull -= damage
			hull = maxf(hull, 0.0)
			hazard_damage.emit(hazard, damage)
			if hull <= 0.0:
				# Emergency lift-off when hull depleted
				lift_off_requested.emit()
				return


## Scan the area around the rover for resources.
func _scan_area() -> void:
	if surface_generator == null:
		return
	var rover_tile: Vector2i = surface_generator.world_to_tile(global_position)
	var found: Array = []

	for node: Dictionary in surface_generator.resource_nodes:
		if node.get("collected", false):
			continue
		var node_pos: Vector2i = node.get("position", Vector2i.ZERO)
		var dist: int = absi(node_pos.x - rover_tile.x) + absi(node_pos.y - rover_tile.y)
		if dist <= scan_radius:
			found.append({
				"resource_id": node.get("resource_id", ""),
				"position": node_pos,
				"distance": dist,
			})

	scan_complete.emit(found)


## Try to collect a resource at the rover's current position.
func _try_collect_resource() -> void:
	if surface_generator == null:
		return
	var rover_tile: Vector2i = surface_generator.world_to_tile(global_position)

	for i: int in range(surface_generator.resource_nodes.size()):
		var node: Dictionary = surface_generator.resource_nodes[i]
		if node.get("collected", false):
			continue
		var node_pos: Vector2i = node.get("position", Vector2i.ZERO)
		var dist: int = absi(node_pos.x - rover_tile.x) + absi(node_pos.y - rover_tile.y)
		if dist <= collection_range:
			var res_id: String = node.get("resource_id", "")
			# Add to game state cargo (weight 1.0 default for now)
			var added: int = GameState.add_cargo(res_id, 1, 1.0)
			if added > 0:
				surface_generator.resource_nodes[i]["collected"] = true
				resource_collected.emit(res_id, added)
			return


## Initialize the rover on a planet surface.
func setup(gen: Node, planet: PlanetData) -> void:
	surface_generator = gen
	planet_data = planet
	hull = max_hull
	# Position at landing zone
	if gen:
		global_position = gen.tile_to_world(gen.landing_zone)
