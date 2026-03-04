extends Control
## Star map overlay controller.
##
## Displays a 2D top-down view of all star systems in the galaxy.
## Shows discovered systems highlighted, fuel range as a circle,
## and allows click-to-navigate.

## Emitted when the player selects a destination system on the map.
signal destination_selected(system_index: int)
## Emitted when the map is closed.
signal map_closed()

## Zoom level for the map display.
@export var zoom: float = 1.0
## Minimum and maximum zoom.
@export var min_zoom: float = 0.2
@export var max_zoom: float = 5.0
## Size of star dots on the map.
@export var star_dot_radius: float = 4.0

## Map pan offset (for scrolling the view).
var _pan_offset: Vector2 = Vector2.ZERO
## Whether the map is currently being dragged.
var _is_dragging: bool = false
## Last mouse position for drag calculation.
var _drag_start: Vector2 = Vector2.ZERO
## Cached reference to star systems data.
var _star_systems: Array = []
## Currently hovered system index.
var _hovered_system: int = -1


func _ready() -> void:
	visible = false


func _draw() -> void:
	if not visible:
		return

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.08, 0.9))

	var center: Vector2 = size / 2.0

	# Draw fuel range circle
	if GameState.current_system_index >= 0:
		var fuel_range: float = GameState.fuel / GameState.FUEL_COST_PER_UNIT
		var range_radius: float = fuel_range * zoom * 0.5
		draw_arc(
			center + _pan_offset,
			range_radius,
			0.0,
			TAU,
			64,
			Color(0.2, 0.4, 0.8, 0.3),
			1.5,
		)

	# Draw star systems
	for i: int in range(_star_systems.size()):
		var system: Dictionary = _star_systems[i]
		var pos: Vector2 = _galaxy_to_screen(system.get("position", Vector3.ZERO))
		var is_discovered: bool = GameState.discovered_systems.has(i)
		var is_current: bool = i == GameState.current_system_index

		# Color: bright if discovered, dim if not
		var color: Color = Color.from_string(system.get("color", "#ffffff"), Color.WHITE)
		if not is_discovered:
			color = color * 0.3
			color.a = 0.5

		var radius: float = star_dot_radius
		if is_current:
			# Draw highlight ring around current system
			draw_arc(pos, radius + 4.0, 0.0, TAU, 32, Color.WHITE, 1.0)
			radius *= 1.5
		elif i == _hovered_system:
			radius *= 1.3
			draw_arc(pos, radius + 2.0, 0.0, TAU, 32, Color(0.8, 0.8, 1.0, 0.5), 1.0)

		draw_circle(pos, radius, color)

		# Draw system name for discovered systems when zoomed in
		if is_discovered and zoom > 1.5:
			var name_text: String = system.get("name", "")
			draw_string(
				ThemeDB.fallback_font,
				pos + Vector2(radius + 4, 4),
				name_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				10,
				Color(0.7, 0.7, 0.8),
			)

	# Title
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10, 24),
		"STAR MAP",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE,
	)

	# Instructions
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10, size.y - 10),
		"Click star to navigate | Scroll to zoom | Drag to pan | M to close",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(0.5, 0.5, 0.6),
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 1.1, min_zoom, max_zoom)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom / 1.1, min_zoom, max_zoom)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
			_drag_start = event.position

	elif event is InputEventMouseMotion:
		if _is_dragging:
			_pan_offset += event.relative
			queue_redraw()
		else:
			_update_hover(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_star_map"):
		toggle_map()


## Toggle the star map visibility.
func toggle_map() -> void:
	visible = not visible
	if visible:
		_center_on_current_system()
		queue_redraw()
	else:
		map_closed.emit()


## Set the star systems data for display.
func set_star_systems(systems: Array) -> void:
	_star_systems = systems
	if visible:
		queue_redraw()


## Load star systems from StarSystemData objects.
func load_from_system_data(systems: Array) -> void:
	_star_systems.clear()
	for system: StarSystemData in systems:
		_star_systems.append({
			"position": system.position,
			"color": "#%s" % system.get_star_color().to_html(false),
			"name": system.system_name,
			"index": system.index,
		})
	if visible:
		queue_redraw()


## Convert a 3D galaxy position to 2D screen coordinates.
func _galaxy_to_screen(galaxy_pos: Vector3) -> Vector2:
	var center: Vector2 = size / 2.0
	# Project 3D to 2D (top-down, ignore Y)
	var map_pos := Vector2(galaxy_pos.x, galaxy_pos.z) * zoom * 0.5
	return center + map_pos + _pan_offset


## Convert screen coordinates back to galaxy 2D position.
func _screen_to_galaxy(screen_pos: Vector2) -> Vector2:
	var center: Vector2 = size / 2.0
	var local: Vector2 = (screen_pos - center - _pan_offset) / (zoom * 0.5)
	return local


## Center the map view on the player's current system.
func _center_on_current_system() -> void:
	if GameState.current_system_index >= 0 and GameState.current_system_index < _star_systems.size():
		var sys: Dictionary = _star_systems[GameState.current_system_index]
		var pos: Vector3 = sys.get("position", Vector3.ZERO)
		_pan_offset = -Vector2(pos.x, pos.z) * zoom * 0.5


## Handle click to select a destination system.
func _handle_click(click_pos: Vector2) -> void:
	var best_index: int = -1
	var best_dist: float = star_dot_radius * 3.0

	for i: int in range(_star_systems.size()):
		var sys: Dictionary = _star_systems[i]
		var screen_pos: Vector2 = _galaxy_to_screen(sys.get("position", Vector3.ZERO))
		var dist: float = click_pos.distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best_index = i

	if best_index >= 0 and best_index != GameState.current_system_index:
		destination_selected.emit(best_index)
		visible = false
		map_closed.emit()


## Update which system is hovered for highlight.
func _update_hover(mouse_pos: Vector2) -> void:
	var old_hover: int = _hovered_system
	_hovered_system = -1
	var best_dist: float = star_dot_radius * 3.0

	for i: int in range(_star_systems.size()):
		var sys: Dictionary = _star_systems[i]
		var screen_pos: Vector2 = _galaxy_to_screen(sys.get("position", Vector3.ZERO))
		var dist: float = mouse_pos.distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			_hovered_system = i

	if _hovered_system != old_hover:
		queue_redraw()
