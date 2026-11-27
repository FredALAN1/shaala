extends Node
## Top-level game & room orchestration controller attached to scenes/main.tscn.
## Loads rooms from data/rooms.json with smooth fade transitions, mounts UI & Player,
## handles shrine respawns on death, pause/map toggles, and impact hitstop.

const ROOMS_DATA_PATH: String = "res://data/rooms.json"
const PLAYER_SCENE_PATH: String = "res://scenes/player/player.tscn"
const UI_ROOT_SCENE_PATH: String = "res://scenes/ui/ui_root.tscn"
const ORBIT_SPIRE_SCENE_PATH: String = "res://scenes/rooms/m1/pillar_orbit_spire.tscn"

const FADE_OUT_DURATION: float = 0.22
const FADE_IN_DURATION: float = 0.26
const REDUCED_FADE_DURATION: float = 0.08
const DEATH_RESPAWN_DELAY: float = 0.85

@onready var _world_root: Node2D = $WorldRoot
@onready var _room_container: Node2D = $WorldRoot/RoomContainer
@onready var _player_container: Node2D = $WorldRoot/PlayerContainer
@onready var _room_camera: RoomCamera = $WorldRoot/RoomCamera
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var _dev_mode: Node = get_node_or_null("DevModeOverlay")

var _rooms_data: Dictionary = {}
var _current_room: RoomBase = null
var _player: Node2D = null
var _ui_root: Node = null
var _is_transitioning: bool = false
var _hitstop_token: int = 0

var _orbit_spire_node: Node3D = null
var _in_3d_orbit: bool = false
var _saved_2d_room_id: String = ""
var _saved_2d_area_id: String = ""
var _saved_2d_title_key: String = ""
var _saved_2d_player_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("room_manager")

	_load_rooms_registry()
	_mount_ui_root()
	_connect_events()

	AudioManager.set_music_mood("title")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_orbit_demo"):
		if not GameState.is_gameplay_active or _is_transitioning:
			return
		get_viewport().set_input_as_handled()
		if _in_3d_orbit:
			exit_3d_orbit_spire()
		else:
			enter_3d_orbit_spire()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_gameplay_active or _is_transitioning:
		return
	# UIRoot owns pause/map input when mounted (respecting vignettes and key rebinding).
	if _ui_root != null:
		return

	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		var next_paused: bool = not get_tree().paused
		get_tree().paused = next_paused
		EventBus.pause_toggled.emit(next_paused)
	elif event.is_action_pressed("toggle_map") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		EventBus.map_toggled.emit()


func start_new_game() -> void:
	if _is_transitioning:
		return
	get_tree().paused = false
	GameState.reset_new_game()
	GameState.is_gameplay_active = true
	_fade_rect.color.a = 1.0
	_spawn_fresh_player()
	_notify_ui_gameplay_started()
	await _transition_to_room(GameState.current_room_id, GameState.current_spawn_id)


func continue_game() -> void:
	if _is_transitioning:
		return
	if not SaveManager.load_game():
		await start_new_game()
		return
	get_tree().paused = false
	GameState.is_gameplay_active = true
	_fade_rect.color.a = 1.0
	_spawn_fresh_player()
	_notify_ui_gameplay_started()

	var target_room: String = GameState.current_room_id
	var target_spawn: String = GameState.current_spawn_id
	if not _rooms_data.has(target_room):
		target_room = GameState.last_shrine_room_id
		target_spawn = GameState.last_shrine_id
	await _transition_to_room(target_room, target_spawn)


func quit_to_title() -> void:
	if _is_transitioning:
		return
	if _dev_mode != null and _dev_mode.has_method("close_dev_mode"):
		_dev_mode.call("close_dev_mode")
	_teardown_3d_orbit_immediate()
	get_tree().paused = false
	Engine.time_scale = SettingsManager.assist_game_speed
	GameState.is_gameplay_active = false
	EventBus.interaction_prompt_changed.emit(false, "")
	_clear_world()
	AudioManager.set_music_mood("title")
	if _ui_root != null and _ui_root.has_method("show_title_screen"):
		_ui_root.call("show_title_screen")


func enter_3d_orbit_spire() -> void:
	if _is_transitioning or _in_3d_orbit or not GameState.is_gameplay_active:
		return
	if not ResourceLoader.exists(ORBIT_SPIRE_SCENE_PATH):
		push_warning("RoomManager: 3D orbit spire scene not found at %s" % ORBIT_SPIRE_SCENE_PATH)
		return

	_is_transitioning = true
	if _dev_mode != null and _dev_mode.has_method("close_dev_mode"):
		_dev_mode.call("close_dev_mode")
	_set_player_controls(false)
	EventBus.interaction_prompt_changed.emit(false, "")

	var fade_out_sec: float = REDUCED_FADE_DURATION if SettingsManager.reduce_flash else FADE_OUT_DURATION
	var fade_in_sec: float = REDUCED_FADE_DURATION if SettingsManager.reduce_flash else FADE_IN_DURATION
	await _tween_fade(1.0, fade_out_sec)

	_saved_2d_room_id = GameState.current_room_id
	_saved_2d_area_id = _current_room.area_id if _current_room != null else "empty_riyadh"
	_saved_2d_title_key = _current_room.room_title_key if _current_room != null else "AREA_EMPTY_RIYADH"
	_saved_2d_player_pos = _player.global_position if (_player != null and is_instance_valid(_player)) else RoomBase.FALLBACK_SPAWN_POSITION

	_world_root.visible = false
	_world_root.process_mode = Node.PROCESS_MODE_DISABLED
	_room_camera.enabled = false

	var packed: PackedScene = load(ORBIT_SPIRE_SCENE_PATH) as PackedScene
	if packed == null:
		_restore_2d_world_nodes()
		await _tween_fade(0.0, fade_in_sec)
		_set_player_controls(true)
		_is_transitioning = false
		return

	var instance: Node = packed.instantiate()
	if instance is Node3D:
		_orbit_spire_node = instance as Node3D
		add_child(_orbit_spire_node)
		if _orbit_spire_node.has_signal("exit_requested"):
			_orbit_spire_node.connect("exit_requested", _on_orbit_spire_exit_requested)
		_in_3d_orbit = true
	else:
		instance.queue_free()
		_restore_2d_world_nodes()

	await _tween_fade(0.0, fade_in_sec)
	_is_transitioning = false


func exit_3d_orbit_spire(target_room_id: String = "", target_spawn_id: String = "") -> void:
	if _is_transitioning or not _in_3d_orbit:
		return

	_is_transitioning = true
	EventBus.interaction_prompt_changed.emit(false, "")

	var fade_out_sec: float = REDUCED_FADE_DURATION if SettingsManager.reduce_flash else FADE_OUT_DURATION
	var fade_in_sec: float = REDUCED_FADE_DURATION if SettingsManager.reduce_flash else FADE_IN_DURATION
	await _tween_fade(1.0, fade_out_sec)

	if _orbit_spire_node != null and is_instance_valid(_orbit_spire_node):
		_orbit_spire_node.queue_free()
		_orbit_spire_node = null
		await get_tree().process_frame

	_in_3d_orbit = false
	_restore_2d_world_nodes()
	_reset_player_depth_plane()

	if not target_room_id.is_empty() and target_room_id != _saved_2d_room_id and _rooms_data.has(target_room_id):
		_is_transitioning = false
		await _transition_to_room(target_room_id, target_spawn_id)
		return

	if _player != null and is_instance_valid(_player):
		_player.global_position = _saved_2d_player_pos
		if _player is CharacterBody2D:
			(_player as CharacterBody2D).velocity = Vector2.ZERO
		if _current_room != null:
			_room_camera.set_bounds(_current_room.get_camera_bounds())
		_room_camera.set_target(_player, true)

	EventBus.room_loaded.emit(_saved_2d_room_id, _saved_2d_area_id, _saved_2d_title_key)

	await _tween_fade(0.0, fade_in_sec)
	_set_player_controls(true)
	_is_transitioning = false


func _on_orbit_spire_exit_requested(target_room_id: String, target_spawn_id: String) -> void:
	exit_3d_orbit_spire(target_room_id, target_spawn_id)


func _restore_2d_world_nodes() -> void:
	_world_root.visible = true
	_world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	_room_camera.enabled = true
	_room_camera.make_current()


func _teardown_3d_orbit_immediate() -> void:
	if _orbit_spire_node != null and is_instance_valid(_orbit_spire_node):
		_orbit_spire_node.queue_free()
		_orbit_spire_node = null
	_in_3d_orbit = false
	_restore_2d_world_nodes()


func _reset_player_depth_plane() -> void:
	if _player != null and is_instance_valid(_player):
		_player.scale = Vector2.ONE
		_player.modulate = Color.WHITE
		_player.z_index = 0


func get_current_room() -> RoomBase:
	return _current_room


func get_player() -> Node2D:
	return _player


func get_camera() -> RoomCamera:
	return _room_camera


func get_room_metadata(room_id: String) -> Dictionary:
	if _rooms_data.has(room_id) and _rooms_data[room_id] is Dictionary:
		return _rooms_data[room_id] as Dictionary
	return {}


func _connect_events() -> void:
	EventBus.room_transition_requested.connect(_on_room_transition_requested)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawn_requested.connect(_on_player_respawn_requested)
	EventBus.hitstop_requested.connect(_on_hitstop_requested)
	EventBus.pause_toggled.connect(_on_pause_toggled)


func _load_rooms_registry() -> void:
	_rooms_data.clear()
	if not FileAccess.file_exists(ROOMS_DATA_PATH):
		push_warning("RoomManager: missing %s" % ROOMS_DATA_PATH)
		return
	var file: FileAccess = FileAccess.open(ROOMS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK or not (json.data is Dictionary):
		push_warning("RoomManager: invalid JSON in %s" % ROOMS_DATA_PATH)
		return

	var root: Dictionary = json.data as Dictionary
	var rooms_raw: Variant = root.get("rooms", {})
	if rooms_raw is Dictionary:
		_rooms_data = (rooms_raw as Dictionary).duplicate(true)
	elif rooms_raw is Array:
		for entry: Variant in rooms_raw as Array:
			if entry is Dictionary and (entry as Dictionary).has("id"):
				var dict_entry: Dictionary = entry as Dictionary
				_rooms_data[str(dict_entry["id"])] = dict_entry


func _mount_ui_root() -> void:
	if not ResourceLoader.exists(UI_ROOT_SCENE_PATH):
		push_warning("RoomManager: UI root scene not found at %s" % UI_ROOT_SCENE_PATH)
		return
	var packed: PackedScene = load(UI_ROOT_SCENE_PATH) as PackedScene
	if packed == null:
		return
	_ui_root = packed.instantiate()
	if _ui_root is CanvasLayer:
		add_child(_ui_root)
	else:
		_ui_layer.add_child(_ui_root)

	if _ui_root.has_signal("new_game_requested"):
		_ui_root.connect("new_game_requested", start_new_game)
	if _ui_root.has_signal("continue_game_requested"):
		_ui_root.connect("continue_game_requested", continue_game)
	if _ui_root.has_signal("quit_to_title_requested"):
		_ui_root.connect("quit_to_title_requested", quit_to_title)


func _notify_ui_gameplay_started() -> void:
	if _ui_root == null:
		return
	if _ui_root.has_method("show_gameplay_hud"):
		_ui_root.call("show_gameplay_hud")
	elif _ui_root.has_method("show_gameplay_ui"):
		_ui_root.call("show_gameplay_ui")
	elif _ui_root.has_method("hide_title_screen"):
		_ui_root.call("hide_title_screen")


func _spawn_fresh_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		_player = null

	if not ResourceLoader.exists(PLAYER_SCENE_PATH):
		push_warning("RoomManager: player scene not found at %s" % PLAYER_SCENE_PATH)
		return
	var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	if instance is Node2D:
		_player = instance as Node2D
		_player_container.add_child(_player)


func _clear_world() -> void:
	if _current_room != null and is_instance_valid(_current_room):
		_current_room.queue_free()
		_current_room = null
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		_player = null
	_room_camera.set_target(null, false)


func _on_room_transition_requested(target_room_id: String, target_spawn_id: String) -> void:
	if _is_transitioning:
		return
	await _transition_to_room(target_room_id, target_spawn_id)


func _transition_to_room(target_room_id: String, target_spawn_id: String) -> void:
	if _is_transitioning:
		return
	if not _rooms_data.has(target_room_id):
		push_warning("RoomManager: unknown room_id '%s'" % target_room_id)
		return

	_is_transitioning = true
	_set_player_controls(false)
	EventBus.interaction_prompt_changed.emit(false, "")

	var fade_out_sec: float = REDUCED_FADE_DURATION if SettingsManager.reduce_flash else FADE_OUT_DURATION
	var fade_in_sec: float = REDUCED_FADE_DURATION if SettingsManager.reduce_flash else FADE_IN_DURATION

	await _tween_fade(1.0, fade_out_sec)

	# Unload existing room cleanly.
	if _current_room != null and is_instance_valid(_current_room):
		_current_room.queue_free()
		_current_room = null
		await get_tree().process_frame

	var meta: Dictionary = _rooms_data[target_room_id] as Dictionary
	var scene_path: String = str(meta.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("RoomManager: room scene not found at %s" % scene_path)
		await _tween_fade(0.0, fade_in_sec)
		_set_player_controls(true)
		_is_transitioning = false
		return

	var room_scene: PackedScene = load(scene_path) as PackedScene
	if room_scene == null:
		await _tween_fade(0.0, fade_in_sec)
		_set_player_controls(true)
		_is_transitioning = false
		return

	var room_instance: Node = room_scene.instantiate()
	_room_container.add_child(room_instance)

	var resolved_room_id: String = target_room_id
	var resolved_area_id: String = str(meta.get("area_id", ""))
	var resolved_title_key: String = str(meta.get("title_key", ""))
	var spawn_pos: Vector2 = RoomBase.FALLBACK_SPAWN_POSITION
	var bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)

	if room_instance is RoomBase:
		_current_room = room_instance as RoomBase
		if not _current_room.room_id.is_empty():
			resolved_room_id = _current_room.room_id
		if not _current_room.area_id.is_empty():
			resolved_area_id = _current_room.area_id
		if not _current_room.room_title_key.is_empty():
			resolved_title_key = _current_room.room_title_key
		_current_room.apply_era(GameState.current_era)
		if _dev_mode != null and _dev_mode.has_method("load_custom_room_items"):
			_dev_mode.call("load_custom_room_items", _current_room)
		spawn_pos = _current_room.get_spawn_position(target_spawn_id)
		bounds = _current_room.get_camera_bounds()

	GameState.current_room_id = resolved_room_id
	GameState.current_spawn_id = target_spawn_id
	GameState.mark_room_explored(resolved_room_id)

	if _player == null or not is_instance_valid(_player):
		_spawn_fresh_player()

	if _player != null and is_instance_valid(_player):
		_reset_player_depth_plane()
		_player.global_position = spawn_pos
		if _player is CharacterBody2D:
			(_player as CharacterBody2D).velocity = Vector2.ZERO
		_room_camera.set_bounds(bounds)
		_room_camera.set_target(_player, true)
	else:
		_room_camera.set_bounds(bounds)

	EventBus.room_loaded.emit(resolved_room_id, resolved_area_id, resolved_title_key)

	await _tween_fade(0.0, fade_in_sec)
	_set_player_controls(true)
	_is_transitioning = false


func _tween_fade(target_alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return
	if duration <= 0.001 or is_equal_approx(_fade_rect.color.a, target_alpha):
		_fade_rect.color.a = target_alpha
		return
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", target_alpha, duration)
	await tween.finished


func _set_player_controls(enabled: bool) -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", enabled)


func _on_player_died() -> void:
	if _is_transitioning:
		return
	AudioManager.play_sfx("player_death")
	await get_tree().create_timer(DEATH_RESPAWN_DELAY, true, false, true).timeout
	EventBus.player_respawn_requested.emit()


func _on_player_respawn_requested() -> void:
	if _is_transitioning or not GameState.is_gameplay_active:
		return
	GameState.player_hp = GameState.player_max_hp
	EventBus.player_health_changed.emit(GameState.player_hp, GameState.player_max_hp)

	if _player != null and is_instance_valid(_player) and _player.has_method("respawn"):
		_player.call("respawn")
	else:
		_spawn_fresh_player()

	var shrine_room: String = GameState.last_shrine_room_id
	var shrine_spawn: String = GameState.last_shrine_id
	if not _rooms_data.has(shrine_room):
		shrine_room = GameState.DEFAULT_ROOM_ID
		shrine_spawn = GameState.DEFAULT_SPAWN_ID
	await _transition_to_room(shrine_room, shrine_spawn)


func _on_hitstop_requested(duration: float) -> void:
	var clamped: float = clampf(duration, 0.01, 0.25)
	if SettingsManager.reduce_flash:
		clamped *= 0.5
	_hitstop_token += 1
	var my_token: int = _hitstop_token
	Engine.time_scale = 0.05
	await get_tree().create_timer(clamped, true, false, true).timeout
	if my_token == _hitstop_token:
		Engine.time_scale = SettingsManager.assist_game_speed


func _on_pause_toggled(paused: bool) -> void:
	if get_tree().paused != paused:
		get_tree().paused = paused
