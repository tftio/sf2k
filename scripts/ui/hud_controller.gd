extends CanvasLayer
## HUD overlay displaying fuel, cargo, credits, location, and status.
##
## Updates reactively via GameState signals. Always visible during gameplay.

@onready var _fuel_bar: ProgressBar = $MarginContainer/VBoxContainer/FuelBar
@onready var _fuel_label: Label = $MarginContainer/VBoxContainer/FuelLabel
@onready var _credits_label: Label = $MarginContainer/VBoxContainer/CreditsLabel
@onready var _cargo_label: Label = $MarginContainer/VBoxContainer/CargoLabel
@onready var _location_label: Label = $MarginContainer/VBoxContainer/LocationLabel
@onready var _status_label: Label = $MarginContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.cargo_changed.connect(_on_cargo_changed)
	GameState.finances_changed.connect(_on_finances_changed)
	GameState.mode_changed.connect(_on_mode_changed)
	_update_all()


## Refresh all HUD elements.
func _update_all() -> void:
	_on_fuel_changed(GameState.fuel)
	_on_cargo_changed()
	_on_finances_changed()
	_update_location()


func _on_fuel_changed(new_fuel: float) -> void:
	if _fuel_bar:
		_fuel_bar.max_value = GameState.max_fuel
		_fuel_bar.value = new_fuel
	if _fuel_label:
		_fuel_label.text = "Fuel: %.0f / %.0f" % [new_fuel, GameState.max_fuel]


func _on_cargo_changed() -> void:
	if _cargo_label:
		var weight: float = GameState.get_cargo_weight()
		var item_count: int = 0
		for key: String in GameState.cargo:
			item_count += GameState.cargo[key]
		_cargo_label.text = "Cargo: %d items (%.0f/%.0f wt)" % [item_count, weight, GameState.max_cargo_weight]


func _on_finances_changed() -> void:
	if _credits_label:
		var debt_str: String = ""
		if GameState.debt > 0:
			debt_str = " | Debt: %d" % GameState.debt
		_credits_label.text = "Credits: %d%s" % [GameState.credits, debt_str]


func _on_mode_changed(_new_mode: GameState.Mode) -> void:
	_update_location()


## Update the location display based on current game state.
func _update_location() -> void:
	if _location_label == null:
		return
	match GameState.current_mode:
		GameState.Mode.SPACE:
			if GameState.is_traveling:
				_location_label.text = "In transit..."
			elif GameState.current_system_index >= 0:
				_location_label.text = "System #%d" % GameState.current_system_index
			else:
				_location_label.text = "Deep space"
		GameState.Mode.PLANET:
			_location_label.text = "Planet surface"
		GameState.Mode.STARBASE:
			_location_label.text = "Docked at starbase"
		_:
			_location_label.text = ""


## Set the status message (temporary notifications).
func show_status(message: String, duration: float = 3.0) -> void:
	if _status_label:
		_status_label.text = message
		# Auto-clear after duration
		get_tree().create_timer(duration).timeout.connect(func() -> void:
			if _status_label:
				_status_label.text = ""
		)
