extends Node
## Manages user settings, accessibility options, input rebinding, audio volumes,
## and runtime CSV localization loading so Arabic/English translations work immediately.

const SETTINGS_PATH: String = "user://settings.json"
const LOCALIZATION_CSV_PATH: String = "res://localization/strings.csv"

const SUPPORTED_LOCALES: Array = ["ar", "en"]
const DIRECTIONAL_ACTIONS: Array = [
	"move_left", "move_right", "move_up", "move_down"
]
const REBINDABLE_ACTIONS: Array = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "dash", "attack", "cast_spell", "parry",
	"interact", "grey_eye", "time_shift", "toggle_map", "pause"
]

var locale: String = "ar"
var screen_shake_scale: float = 1.0
var reduce_flash: bool = false
var assist_game_speed: float = 1.0
var gamepad_deadzone: float = 0.2
var master_volume: float = 0.85
var music_volume: float = 0.75
var sfx_volume: float = 0.85
## "Notebook & Ember" accessibility options (docs/UI_DESIGN_PLAN.md §7, §9).
var reduce_motion: bool = false
var hud_always_visible: bool = false
var show_numbers: bool = false
var text_scale: float = 1.0
var keybindings: Dictionary = {}

var _default_keybindings: Dictionary = {}
var _loaded_translations: Array[Translation] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_keybindings()
	load_runtime_translations()
	load_settings()
	apply_all_settings()


func load_runtime_translations() -> void:
	if not FileAccess.file_exists(LOCALIZATION_CSV_PATH):
		push_warning("SettingsManager: localization CSV not found at %s" % LOCALIZATION_CSV_PATH)
		return

	var file: FileAccess = FileAccess.open(LOCALIZATION_CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("SettingsManager: failed to open %s" % LOCALIZATION_CSV_PATH)
		return

	var raw_text: String = file.get_as_text()
	file.close()

	# Strip UTF-8 BOM if present.
	if raw_text.begins_with("\ufeff"):
		raw_text = raw_text.substr(1)

	var rows: Array[PackedStringArray] = _parse_csv(raw_text)
	if rows.size() < 2:
		return

	var header: PackedStringArray = rows[0]
	if header.size() < 2:
		return

	# Clear previously registered runtime translations if reloading.
	for old_tr: Translation in _loaded_translations:
		TranslationServer.remove_translation(old_tr)
	_loaded_translations.clear()

	var translations_by_col: Dictionary = {}
	for col_idx: int in range(1, header.size()):
		var lang_code: String = header[col_idx].strip_edges()
		if lang_code.is_empty():
			continue
		var tr_obj: Translation = Translation.new()
		tr_obj.locale = lang_code
		translations_by_col[col_idx] = tr_obj

	for row_idx: int in range(1, rows.size()):
		var row: PackedStringArray = rows[row_idx]
		if row.is_empty():
			continue
		var key: String = row[0].strip_edges()
		if key.is_empty() or key.begins_with("#"):
			continue
		for col_idx: int in translations_by_col.keys():
			if col_idx < row.size():
				var val: String = row[col_idx]
				var tr_obj: Translation = translations_by_col[col_idx] as Translation
				tr_obj.add_message(StringName(key), StringName(val))

	for tr_obj: Translation in translations_by_col.values():
		TranslationServer.add_translation(tr_obj)
		_loaded_translations.append(tr_obj)


func load_settings() -> bool:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return false

	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return false
	var raw_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(raw_text) != OK or not (json.data is Dictionary):
		push_warning("SettingsManager: corrupt settings.json, using defaults.")
		return false

	var data: Dictionary = json.data as Dictionary
	var loaded_locale: String = str(data.get("locale", "ar"))
	locale = loaded_locale if loaded_locale in SUPPORTED_LOCALES else "ar"
	screen_shake_scale = clampf(float(data.get("screen_shake_scale", 1.0)), 0.0, 1.0)
	reduce_flash = bool(data.get("reduce_flash", false))
	assist_game_speed = clampf(float(data.get("assist_game_speed", 1.0)), 0.7, 1.0)
	gamepad_deadzone = clampf(float(data.get("gamepad_deadzone", 0.2)), 0.1, 0.5)
	master_volume = clampf(float(data.get("master_volume", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 0.75)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.85)), 0.0, 1.0)
	reduce_motion = bool(data.get("reduce_motion", false))
	hud_always_visible = bool(data.get("hud_always_visible", false))
	show_numbers = bool(data.get("show_numbers", false))
	text_scale = _snap_text_scale(float(data.get("text_scale", 1.0)))

	keybindings.clear()
	var saved_keys: Variant = data.get("keybindings", {})
	if saved_keys is Dictionary:
		for action_name: Variant in (saved_keys as Dictionary).keys():
			var act: String = str(action_name)
			if act in REBINDABLE_ACTIONS:
				var code: int = int((saved_keys as Dictionary)[action_name])
				if code > 0:
					keybindings[act] = code
	return true


func save_settings() -> bool:
	var payload: Dictionary = {
		"locale": locale,
		"screen_shake_scale": screen_shake_scale,
		"reduce_flash": reduce_flash,
		"assist_game_speed": assist_game_speed,
		"gamepad_deadzone": gamepad_deadzone,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"reduce_motion": reduce_motion,
		"hud_always_visible": hud_always_visible,
		"show_numbers": show_numbers,
		"text_scale": text_scale,
		"keybindings": keybindings.duplicate(true),
	}
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SettingsManager: unable to save settings to %s" % SETTINGS_PATH)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	return true


func apply_all_settings() -> void:
	TranslationServer.set_locale(locale)
	_apply_deadzone()
	_apply_keybindings()
	apply_audio_volumes()
	Engine.time_scale = assist_game_speed
	EventBus.locale_changed.emit(locale)
	EventBus.settings_changed.emit()


func set_locale(new_locale: String) -> void:
	if new_locale not in SUPPORTED_LOCALES:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	save_settings()
	EventBus.locale_changed.emit(locale)
	EventBus.settings_changed.emit()


func toggle_locale() -> void:
	set_locale("en" if locale == "ar" else "ar")


func set_screen_shake_scale(value: float) -> void:
	screen_shake_scale = clampf(value, 0.0, 1.0)
	save_settings()
	EventBus.settings_changed.emit()


func set_reduce_flash(enabled: bool) -> void:
	reduce_flash = enabled
	save_settings()
	EventBus.settings_changed.emit()


func set_assist_game_speed(value: float) -> void:
	assist_game_speed = clampf(value, 0.7, 1.0)
	Engine.time_scale = assist_game_speed
	save_settings()
	EventBus.settings_changed.emit()


func set_gamepad_deadzone(value: float) -> void:
	gamepad_deadzone = clampf(value, 0.1, 0.5)
	_apply_deadzone()
	save_settings()
	EventBus.settings_changed.emit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio_volumes()
	save_settings()
	EventBus.settings_changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_audio_volumes()
	save_settings()
	EventBus.settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_audio_volumes()
	save_settings()
	EventBus.settings_changed.emit()


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	save_settings()
	EventBus.settings_changed.emit()


func set_hud_always_visible(enabled: bool) -> void:
	hud_always_visible = enabled
	save_settings()
	EventBus.settings_changed.emit()


func set_show_numbers(enabled: bool) -> void:
	show_numbers = enabled
	save_settings()
	EventBus.settings_changed.emit()


## Text scale steps: 100% / 125% / 150%. Re-applies typography to the UI via locale_changed.
func set_text_scale(value: float) -> void:
	var snapped_value: float = _snap_text_scale(value)
	if is_equal_approx(snapped_value, text_scale):
		return
	text_scale = snapped_value
	save_settings()
	EventBus.locale_changed.emit(locale)
	EventBus.settings_changed.emit()


func _snap_text_scale(value: float) -> float:
	return clampf(snappedf(value, 0.25), 1.0, 1.5)


func rebind_action_key(action_name: String, keycode: int) -> void:
	if action_name not in REBINDABLE_ACTIONS or keycode <= 0:
		return
	keybindings[action_name] = keycode
	_apply_single_keybinding(action_name, keycode)
	save_settings()
	EventBus.settings_changed.emit()


func reset_keybindings() -> void:
	keybindings.clear()
	for action_name: String in _default_keybindings.keys():
		var code: int = int(_default_keybindings[action_name])
		_apply_single_keybinding(action_name, code)
	save_settings()
	EventBus.settings_changed.emit()


func get_action_key_label(action_name: String) -> String:
	if keybindings.has(action_name):
		return OS.get_keycode_string(int(keybindings[action_name]))
	if InputMap.has_action(action_name):
		for ev: InputEvent in InputMap.action_get_events(action_name):
			if ev is InputEventKey:
				var key_ev: InputEventKey = ev as InputEventKey
				var code: int = key_ev.physical_keycode if key_ev.physical_keycode != 0 else key_ev.keycode
				return OS.get_keycode_string(code)
	return "?"


func apply_audio_volumes() -> void:
	_set_bus_linear_volume("Master", master_volume)
	_set_bus_linear_volume("Music", music_volume)
	_set_bus_linear_volume("SFX", sfx_volume)


func _set_bus_linear_volume(bus_name: String, linear: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))


func _capture_default_keybindings() -> void:
	_default_keybindings.clear()
	for action_name: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action_name):
			continue
		for ev: InputEvent in InputMap.action_get_events(action_name):
			if ev is InputEventKey:
				var key_ev: InputEventKey = ev as InputEventKey
				var code: int = key_ev.physical_keycode if key_ev.physical_keycode != 0 else key_ev.keycode
				if code > 0:
					_default_keybindings[action_name] = code
					break


func _apply_deadzone() -> void:
	for action_name: String in DIRECTIONAL_ACTIONS:
		if InputMap.has_action(action_name):
			InputMap.action_set_deadzone(action_name, gamepad_deadzone)


func _apply_keybindings() -> void:
	for action_name: Variant in keybindings.keys():
		var act: String = str(action_name)
		var code: int = int(keybindings[action_name])
		_apply_single_keybinding(act, code)


func _apply_single_keybinding(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name) or keycode <= 0:
		return
	var existing_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	var preserved_events: Array[InputEvent] = []
	var replaced_primary_key: bool = false

	for ev: InputEvent in existing_events:
		if ev is InputEventKey and not replaced_primary_key:
			var new_key: InputEventKey = InputEventKey.new()
			new_key.keycode = keycode as Key
			new_key.physical_keycode = keycode as Key
			preserved_events.append(new_key)
			replaced_primary_key = true
		else:
			preserved_events.append(ev)

	if not replaced_primary_key:
		var fallback_key: InputEventKey = InputEventKey.new()
		fallback_key.keycode = keycode as Key
		fallback_key.physical_keycode = keycode as Key
		preserved_events.insert(0, fallback_key)

	InputMap.action_erase_events(action_name)
	for ev: InputEvent in preserved_events:
		InputMap.action_add_event(action_name, ev)


func _parse_csv(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var current_row: PackedStringArray = PackedStringArray()
	var current_field: String = ""
	var in_quotes: bool = false
	var idx: int = 0
	var length: int = text.length()

	while idx < length:
		var ch: String = text[idx]
		if in_quotes:
			if ch == "\"":
				if idx + 1 < length and text[idx + 1] == "\"":
					current_field += "\""
					idx += 2
					continue
				in_quotes = false
			else:
				current_field += ch
		else:
			if ch == "\"":
				in_quotes = true
			elif ch == ",":
				current_row.append(current_field)
				current_field = ""
			elif ch == "\r":
				if idx + 1 < length and text[idx + 1] == "\n":
					idx += 1
				current_row.append(current_field)
				current_field = ""
				rows.append(current_row)
				current_row = PackedStringArray()
			elif ch == "\n":
				current_row.append(current_field)
				current_field = ""
				rows.append(current_row)
				current_row = PackedStringArray()
			else:
				current_field += ch
		idx += 1

	if not current_field.is_empty() or not current_row.is_empty():
		current_row.append(current_field)
		rows.append(current_row)

	return rows
