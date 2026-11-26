extends Node
## Atomic JSON save/load manager for SHAALA (شعلة).
## Persists GameState at user://saves/slot_0.json with schema_version=1.

const SAVE_DIR_NAME: String = "saves"
const SAVE_PATH: String = "user://saves/slot_0.json"
const TEMP_SAVE_PATH: String = "user://saves/slot_0.json.tmp"
const SCHEMA_VERSION: int = 1


func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var size_bytes: int = file.get_length()
	file.close()
	return size_bytes > 2


func save_game() -> bool:
	var user_dir: DirAccess = DirAccess.open("user://")
	if user_dir == null:
		push_warning("SaveManager: cannot access user:// directory.")
		return false
	if not user_dir.dir_exists(SAVE_DIR_NAME):
		var mk_err: Error = user_dir.make_dir_recursive(SAVE_DIR_NAME)
		if mk_err != OK:
			push_warning("SaveManager: failed to create saves directory (err=%d)." % mk_err)
			return false

	var payload: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"state": GameState.to_save_dict(),
	}

	var serialized: String = JSON.stringify(payload, "\t")
	var tmp_file: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if tmp_file == null:
		push_warning("SaveManager: cannot open temporary save file for writing.")
		return false

	tmp_file.store_string(serialized)
	tmp_file.flush()
	tmp_file.close()

	var abs_tmp: String = ProjectSettings.globalize_path(TEMP_SAVE_PATH)
	var abs_dest: String = ProjectSettings.globalize_path(SAVE_PATH)
	var rename_err: Error = DirAccess.rename_absolute(abs_tmp, abs_dest)
	if rename_err != OK:
		# On platforms where rename does not overwrite existing targets, replace safely.
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(abs_dest)
		rename_err = DirAccess.rename_absolute(abs_tmp, abs_dest)
		if rename_err != OK:
			push_warning("SaveManager: atomic rename failed (err=%d)." % rename_err)
			return false

	return true


func load_game() -> bool:
	if not has_save():
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var raw_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(raw_text) != OK or not (json.data is Dictionary):
		push_warning("SaveManager: save file is corrupted or unreadable.")
		return false

	var root: Dictionary = json.data as Dictionary
	var version: int = int(root.get("schema_version", 0))
	if version < 1:
		push_warning("SaveManager: unsupported save schema version %d." % version)
		return false

	var state_data: Variant = root.get("state", {})
	if not (state_data is Dictionary):
		return false

	GameState.from_save_dict(state_data as Dictionary)
	return true


func delete_save() -> bool:
	var removed_any: bool = false
	if FileAccess.file_exists(SAVE_PATH):
		var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		removed_any = (err == OK)
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE_PATH))
	return removed_any


func get_save_metadata() -> Dictionary:
	if not has_save():
		return {"exists": false}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"exists": false}
	var json: JSON = JSON.new()
	var ok: bool = json.parse(file.get_as_text()) == OK and json.data is Dictionary
	file.close()
	if not ok:
		return {"exists": false}
	var root: Dictionary = json.data as Dictionary
	var state: Dictionary = root.get("state", {}) as Dictionary if root.get("state", {}) is Dictionary else {}
	return {
		"exists": true,
		"schema_version": int(root.get("schema_version", SCHEMA_VERSION)),
		"saved_at_unix": int(root.get("saved_at_unix", 0)),
		"room_id": str(state.get("current_room_id", GameState.DEFAULT_ROOM_ID)),
		"playtime_seconds": float(state.get("playtime_seconds", 0.0)),
	}
