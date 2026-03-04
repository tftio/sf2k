extends Node
## Save/load manager singleton (autoloaded as SaveManager).
##
## Handles serializing the full game state to disk and restoring it.
## Supports multiple named save slots stored in Godot's user:// directory.

## Emitted after a successful save.
signal game_saved(slot_name: String)
## Emitted after a successful load.
signal game_loaded(slot_name: String)
## Emitted on save/load error.
signal save_error(message: String)

## Directory within user:// where saves are stored.
const SAVE_DIR: String = "user://saves/"
## File extension for save files.
const SAVE_EXT: String = ".sav"
## Current save format version (for future migration).
const SAVE_VERSION: int = 1
## Maximum number of save slots.
const MAX_SLOTS: int = 10


func _ready() -> void:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Save the current game state to the named slot.
func save_game(slot_name: String) -> bool:
	var path: String = _slot_path(slot_name)
	var data: Dictionary = {
		"save_version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": GameState.serialize(),
	}

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err_msg: String = "Failed to open save file: %s" % path
		save_error.emit(err_msg)
		push_error(err_msg)
		return false

	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

	game_saved.emit(slot_name)
	return true


## Load game state from the named slot.
func load_game(slot_name: String) -> bool:
	var path: String = _slot_path(slot_name)

	if not FileAccess.file_exists(path):
		save_error.emit("Save file not found: %s" % slot_name)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		save_error.emit("Failed to open save file: %s" % path)
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		save_error.emit("Failed to parse save file: %s" % json.get_error_message())
		return false

	var data: Dictionary = json.data
	var version: int = data.get("save_version", 0)
	if version > SAVE_VERSION:
		save_error.emit("Save file is from a newer version (v%d, current v%d)" % [version, SAVE_VERSION])
		return false

	GameState.deserialize(data.get("game_state", {}))
	game_loaded.emit(slot_name)
	return true


## Delete a save slot.
func delete_save(slot_name: String) -> bool:
	var path: String = _slot_path(slot_name)
	if FileAccess.file_exists(path):
		var err: Error = DirAccess.remove_absolute(path)
		return err == OK
	return false


## Get a list of all save slot names that have save files.
func get_save_slots() -> Array[String]:
	var slots: Array[String] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return slots

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXT):
			slots.append(file_name.trim_suffix(SAVE_EXT))
		file_name = dir.get_next()
	dir.list_dir_end()

	slots.sort()
	return slots


## Get metadata about a save slot without fully loading it.
func get_save_info(slot_name: String) -> Dictionary:
	var path: String = _slot_path(slot_name)
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(json_string) != OK:
		return {}

	var data: Dictionary = json.data
	return {
		"slot_name": slot_name,
		"timestamp": data.get("timestamp", "unknown"),
		"save_version": data.get("save_version", 0),
	}


## Auto-save to a dedicated auto-save slot.
func auto_save() -> bool:
	return save_game("autosave")


## Build the full file path for a slot name.
func _slot_path(slot_name: String) -> String:
	return SAVE_DIR + slot_name + SAVE_EXT
