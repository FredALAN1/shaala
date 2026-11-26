extends Node
## Persistent runtime game state for SHAALA (شعلة).
## Tracks progression, vitals, flame resource, memories, notebook pages, eras, and shortcuts.

const DEFAULT_ROOM_ID: String = "desert_camp_01"
const DEFAULT_SPAWN_ID: String = "start"
const DEFAULT_SHRINE_ROOM_ID: String = "desert_camp_01"
const DEFAULT_SHRINE_ID: String = "shrine_desert_camp"
const DEFAULT_ERA: String = "2054"
const MAX_RESOURCE: float = 100.0
const DAGGER_TIER_1_THRESHOLD: float = 35.0
const DAGGER_TIER_2_THRESHOLD: float = 70.0

var current_room_id: String = DEFAULT_ROOM_ID
var current_spawn_id: String = DEFAULT_SPAWN_ID
var last_shrine_room_id: String = DEFAULT_SHRINE_ROOM_ID
var last_shrine_id: String = DEFAULT_SHRINE_ID
var current_era: String = DEFAULT_ERA

var unlocked_abilities: Dictionary = {"flame_spell": true}
var collected_orbs: Array[String] = []
var collected_pages: Array[String] = []
var collected_page_entries: Dictionary = {}
var defeated_bosses: Array[String] = []
var opened_shortcuts: Array[String] = []
var explored_rooms: Array[String] = [DEFAULT_ROOM_ID]
var story_flags: Dictionary = {}

var player_max_hp: int = 5
var player_hp: int = 5
var player_resource: float = 0.0
var player_max_resource: float = MAX_RESOURCE
var playtime_seconds: float = 0.0

var grey_eye_active: bool = false
var is_gameplay_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if is_gameplay_active:
		playtime_seconds += delta


func has_ability(ability_id: String) -> bool:
	return bool(unlocked_abilities.get(ability_id, false))


func unlock_ability(ability_id: String) -> void:
	if ability_id.is_empty():
		return
	if has_ability(ability_id):
		return
	unlocked_abilities[ability_id] = true
	EventBus.ability_unlocked.emit(ability_id)


func get_dagger_tier() -> int:
	if player_resource < DAGGER_TIER_1_THRESHOLD:
		return 0
	if player_resource < DAGGER_TIER_2_THRESHOLD:
		return 1
	return 2


func add_resource(delta: float) -> void:
	player_resource = clampf(player_resource + delta, 0.0, player_max_resource)
	EventBus.player_resource_changed.emit(player_resource, player_max_resource, get_dagger_tier())


func spend_resource(cost: float) -> bool:
	if cost < 0.0 or player_resource < cost:
		return false
	player_resource = clampf(player_resource - cost, 0.0, player_max_resource)
	EventBus.player_resource_changed.emit(player_resource, player_max_resource, get_dagger_tier())
	return true


func damage_player(amount: int) -> void:
	if amount <= 0 or player_hp <= 0:
		return
	player_hp = maxi(player_hp - amount, 0)
	EventBus.player_health_changed.emit(player_hp, player_max_hp)


func heal_player(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = mini(player_hp + amount, player_max_hp)
	EventBus.player_health_changed.emit(player_hp, player_max_hp)


func collect_orb(orb_id: String, ability_id: String, vignette_key: String) -> void:
	if not orb_id.is_empty() and orb_id not in collected_orbs:
		collected_orbs.append(orb_id)
	if not ability_id.is_empty():
		unlock_ability(ability_id)
	EventBus.memory_orb_collected.emit(orb_id, ability_id, vignette_key)


func collect_page(page_id: String, title_key: String, body_key: String) -> void:
	if not page_id.is_empty() and page_id not in collected_pages:
		collected_pages.append(page_id)
	if not page_id.is_empty():
		collected_page_entries[page_id] = {
			"title_key": title_key,
			"body_key": body_key,
		}
	EventBus.notebook_page_collected.emit(page_id, title_key, body_key)


func mark_room_explored(room_id: String) -> void:
	if not room_id.is_empty() and room_id not in explored_rooms:
		explored_rooms.append(room_id)


func mark_boss_defeated(boss_id: String) -> void:
	if not boss_id.is_empty() and boss_id not in defeated_bosses:
		defeated_bosses.append(boss_id)


func is_boss_defeated(boss_id: String) -> bool:
	return boss_id in defeated_bosses


func set_shortcut_opened(shortcut_id: String) -> void:
	if not shortcut_id.is_empty() and shortcut_id not in opened_shortcuts:
		opened_shortcuts.append(shortcut_id)


func is_shortcut_opened(shortcut_id: String) -> bool:
	return shortcut_id in opened_shortcuts


func set_story_flag(flag_id: String, value: Variant = true) -> void:
	if flag_id.is_empty():
		return
	story_flags[flag_id] = value


func has_story_flag(flag_id: String) -> bool:
	return bool(story_flags.get(flag_id, false))


func rest_at_shrine(shrine_id: String, room_id: String) -> void:
	if not shrine_id.is_empty():
		last_shrine_id = shrine_id
	if not room_id.is_empty():
		last_shrine_room_id = room_id
		current_room_id = room_id
		current_spawn_id = shrine_id
	player_hp = player_max_hp
	EventBus.player_health_changed.emit(player_hp, player_max_hp)
	EventBus.shrine_rested.emit(last_shrine_id, last_shrine_room_id)


func set_era(era: String) -> void:
	if era != "2034" and era != "2054":
		return
	if current_era == era:
		return
	current_era = era
	EventBus.era_changed.emit(current_era)


func set_grey_eye_active(active: bool) -> void:
	if active and not has_ability("grey_eye"):
		return
	if grey_eye_active == active:
		return
	grey_eye_active = active
	EventBus.grey_eye_toggled.emit(grey_eye_active)


func reset_new_game() -> void:
	current_room_id = DEFAULT_ROOM_ID
	current_spawn_id = DEFAULT_SPAWN_ID
	last_shrine_room_id = DEFAULT_SHRINE_ROOM_ID
	last_shrine_id = DEFAULT_SHRINE_ID
	current_era = DEFAULT_ERA

	unlocked_abilities = {"flame_spell": true}
	collected_orbs = []
	collected_pages = []
	collected_page_entries = {}
	defeated_bosses = []
	opened_shortcuts = []
	explored_rooms = [DEFAULT_ROOM_ID]
	story_flags = {}

	player_max_hp = 5
	player_hp = 5
	player_resource = 0.0
	player_max_resource = MAX_RESOURCE
	playtime_seconds = 0.0
	grey_eye_active = false

	EventBus.player_health_changed.emit(player_hp, player_max_hp)
	EventBus.player_resource_changed.emit(player_resource, player_max_resource, get_dagger_tier())
	EventBus.era_changed.emit(current_era)
	EventBus.grey_eye_toggled.emit(grey_eye_active)


func to_save_dict() -> Dictionary:
	return {
		"current_room_id": current_room_id,
		"current_spawn_id": current_spawn_id,
		"last_shrine_room_id": last_shrine_room_id,
		"last_shrine_id": last_shrine_id,
		"current_era": current_era,
		"unlocked_abilities": unlocked_abilities.duplicate(true),
		"collected_orbs": Array(collected_orbs),
		"collected_pages": Array(collected_pages),
		"collected_page_entries": collected_page_entries.duplicate(true),
		"defeated_bosses": Array(defeated_bosses),
		"opened_shortcuts": Array(opened_shortcuts),
		"explored_rooms": Array(explored_rooms),
		"story_flags": story_flags.duplicate(true),
		"player_max_hp": player_max_hp,
		"player_hp": player_hp,
		"player_resource": player_resource,
		"playtime_seconds": playtime_seconds,
	}


func from_save_dict(data: Dictionary) -> void:
	current_room_id = str(data.get("current_room_id", DEFAULT_ROOM_ID))
	current_spawn_id = str(data.get("current_spawn_id", DEFAULT_SPAWN_ID))
	last_shrine_room_id = str(data.get("last_shrine_room_id", DEFAULT_SHRINE_ROOM_ID))
	last_shrine_id = str(data.get("last_shrine_id", DEFAULT_SHRINE_ID))
	var saved_era: String = str(data.get("current_era", DEFAULT_ERA))
	current_era = saved_era if (saved_era == "2034" or saved_era == "2054") else DEFAULT_ERA

	var saved_abilities: Variant = data.get("unlocked_abilities", {"flame_spell": true})
	if saved_abilities is Dictionary:
		unlocked_abilities = (saved_abilities as Dictionary).duplicate(true)
	else:
		unlocked_abilities = {"flame_spell": true}
	if not unlocked_abilities.has("flame_spell"):
		unlocked_abilities["flame_spell"] = true

	collected_orbs = _to_string_array(data.get("collected_orbs", []))
	collected_pages = _to_string_array(data.get("collected_pages", []))
	var saved_entries: Variant = data.get("collected_page_entries", {})
	collected_page_entries = (saved_entries as Dictionary).duplicate(true) if saved_entries is Dictionary else {}
	defeated_bosses = _to_string_array(data.get("defeated_bosses", []))
	opened_shortcuts = _to_string_array(data.get("opened_shortcuts", []))
	explored_rooms = _to_string_array(data.get("explored_rooms", [DEFAULT_ROOM_ID]))
	if explored_rooms.is_empty():
		explored_rooms.append(DEFAULT_ROOM_ID)

	var saved_flags: Variant = data.get("story_flags", {})
	story_flags = (saved_flags as Dictionary).duplicate(true) if saved_flags is Dictionary else {}

	player_max_hp = maxi(int(data.get("player_max_hp", 5)), 1)
	player_hp = clampi(int(data.get("player_hp", player_max_hp)), 1, player_max_hp)
	player_max_resource = MAX_RESOURCE
	player_resource = clampf(float(data.get("player_resource", 0.0)), 0.0, player_max_resource)
	playtime_seconds = maxf(float(data.get("playtime_seconds", 0.0)), 0.0)
	grey_eye_active = false

	EventBus.player_health_changed.emit(player_hp, player_max_hp)
	EventBus.player_resource_changed.emit(player_resource, player_max_resource, get_dagger_tier())
	EventBus.era_changed.emit(current_era)
	EventBus.grey_eye_toggled.emit(grey_eye_active)


func _to_string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for item: Variant in raw as Array:
			var s: String = str(item)
			if not s.is_empty() and s not in result:
				result.append(s)
	return result
