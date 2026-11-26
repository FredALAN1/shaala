extends Node
## Global typed signal bus decoupling core systems, player, enemies, interactables, and UI.

signal room_transition_requested(target_room_id: String, target_spawn_id: String)
signal room_loaded(room_id: String, area_id: String, room_title_key: String)

signal player_health_changed(current: int, maximum: int)
signal player_resource_changed(current: float, maximum: float, dagger_tier: int)
signal player_died()
signal player_respawn_requested()

signal ability_unlocked(ability_id: String)
signal memory_orb_collected(orb_id: String, ability_id: String, vignette_key: String)
signal notebook_page_collected(page_id: String, title_key: String, body_key: String)
signal shrine_rested(shrine_id: String, room_id: String)

signal dialogue_requested(lines: Array)
signal vignette_requested(title_key: String, lines: Array, ability_id: String)
signal interaction_prompt_changed(visible: bool, prompt_key: String)

signal boss_encounter_started(boss_id: String, name_key: String, max_hp: int)
signal boss_health_changed(boss_id: String, current_hp: int, max_hp: int, phase: int)
signal boss_defeated(boss_id: String)

signal era_changed(era: String)
signal grey_eye_toggled(active: bool)

signal locale_changed(locale: String)
signal settings_changed()

signal camera_shake_requested(intensity: float, duration: float)
signal hitstop_requested(duration: float)

signal pause_toggled(paused: bool)
signal map_toggled()
