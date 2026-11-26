class_name DevModeController
extends CanvasLayer
## In-game Developer Mode & Live Level Editor (toggle with F1 during gameplay).
## Supports placing/moving/erasing blocks, surfaces, wind zones, enemies, bosses,
## and interactables, free-cam pan/zoom, live play/pause (F2), quick-test cheats,
## and per-room JSON save/auto-load under user://custom_levels/<room_id>.json.

const CUSTOM_LEVELS_DIR: String = "custom_levels"
const CUSTOM_LEVELS_PREFIX: String = "user://custom_levels"
const SCHEMA_VERSION: int = 1

const TOOL_PLACE: int = 0
const TOOL_MOVE: int = 1
const TOOL_ERASE: int = 2

const TAB_BLOCKS: int = 0
const TAB_ENEMIES: int = 1
const TAB_PROPS: int = 2
const TAB_CHEATS: int = 3

const GRID_SNAP_STEPS: Array = [0, 16, 32, 64]

const BLOCK_PALETTE: Array = [
	{"id": "sand_dune_ground", "kind": "block", "style": "sand_dune_ground", "key": "DEV_BLK_SAND_DUNE", "scene": "res://scenes/world/playable_block.tscn", "w": 256.0, "h": 64.0},
	{"id": "deep_sand_pit", "kind": "deep_sand", "style": "deep_sand_pit", "key": "DEV_BLK_DEEP_SAND", "scene": "res://scenes/world/deep_sand_zone.tscn", "w": 280.0, "h": 44.0},
	{"id": "collapsed_building", "kind": "block", "style": "collapsed_building", "key": "DEV_BLK_COLLAPSED_BLDG", "scene": "res://scenes/world/playable_block.tscn", "w": 288.0, "h": 72.0},
	{"id": "najdi_mudbrick_ruin", "kind": "block", "style": "najdi_mudbrick_ruin", "key": "DEV_BLK_NAJDI_RUIN", "scene": "res://scenes/world/playable_block.tscn", "w": 224.0, "h": 72.0},
	{"id": "broken_highway_deck", "kind": "block", "style": "broken_highway_deck", "key": "DEV_BLK_HIGHWAY", "scene": "res://scenes/world/playable_block.tscn", "w": 320.0, "h": 56.0},
	{"id": "abandoned_car_platform", "kind": "block", "style": "abandoned_car_platform", "key": "DEV_BLK_CAR", "scene": "res://scenes/world/playable_block.tscn", "w": 208.0, "h": 56.0},
	{"id": "cracked_glass_bridge", "kind": "block", "style": "cracked_glass_bridge", "key": "DEV_BLK_GLASS_BRIDGE", "scene": "res://scenes/world/playable_block.tscn", "w": 240.0, "h": 36.0},
	{"id": "crumbling_ledge", "kind": "crumbling", "style": "crumbling_ledge", "key": "DEV_BLK_CRUMBLING", "scene": "res://scenes/world/crumbling_ledge.tscn", "w": 160.0, "h": 36.0},
	{"id": "wind_zone", "kind": "wind", "style": "wind_zone", "key": "DEV_BLK_WIND_ZONE", "scene": "res://scenes/world/wind_zone.tscn", "w": 360.0, "h": 220.0},
]

const ENEMY_PALETTE: Array = [
	{"id": "sand_stalker", "kind": "enemy", "style": "sand_stalker", "key": "DEV_ENEMY_STALKER", "scene": "res://scenes/enemies/sand_stalker.tscn", "w": 64.0, "h": 48.0},
	{"id": "shard_husk", "kind": "enemy", "style": "shard_husk", "key": "DEV_ENEMY_HUSK", "scene": "res://scenes/enemies/shard_husk.tscn", "w": 56.0, "h": 88.0},
	{"id": "relic_sentinel", "kind": "enemy", "style": "relic_sentinel", "key": "DEV_ENEMY_SENTINEL", "scene": "res://scenes/enemies/relic_sentinel.tscn", "w": 72.0, "h": 96.0},
	{"id": "boss_spire_warden", "kind": "boss", "style": "boss_spire_warden", "key": "DEV_ENEMY_BOSS", "scene": "res://scenes/boss/boss_spire_warden.tscn", "w": 110.0, "h": 170.0},
]

const PROP_PALETTE: Array = [
	{"id": "orb_shrine", "kind": "prop", "style": "orb_shrine", "key": "DEV_PROP_SHRINE", "scene": "res://scenes/interactables/orb_shrine.tscn", "w": 76.0, "h": 156.0},
	{"id": "memory_orb", "kind": "prop", "style": "memory_orb", "key": "DEV_PROP_ORB", "scene": "res://scenes/interactables/memory_orb.tscn", "w": 56.0, "h": 56.0},
	{"id": "notebook_page", "kind": "prop", "style": "notebook_page", "key": "DEV_PROP_PAGE", "scene": "res://scenes/interactables/notebook_page.tscn", "w": 44.0, "h": 44.0},
	{"id": "npc_boy", "kind": "prop", "style": "npc_boy", "key": "DEV_PROP_BOY", "scene": "res://scenes/interactables/npc_boy.tscn", "w": 48.0, "h": 72.0},
	{"id": "camel_amira", "kind": "prop", "style": "camel_amira", "key": "DEV_PROP_AMIRA", "scene": "res://scenes/interactables/camel_amira.tscn", "w": 120.0, "h": 72.0},
]

const ALL_UNLOCK_ABILITIES: Array = [
	"flame_spell", "dash", "wall_cling", "double_jump", "ground_pound", "glide"
]

@onready var _world_draw_canvas: Control = $WorldDrawCanvas
@onready var _root_control: Control = $RootControl
@onready var _top_bar_panel: PanelContainer = $RootControl/TopBarPanel
@onready var _title_label: Label = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/TitleLabel
@onready var _hint_label: Label = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/HintLabel
@onready var _tool_place_btn: Button = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/ToolPlaceBtn
@onready var _tool_move_btn: Button = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/ToolMoveBtn
@onready var _tool_erase_btn: Button = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/ToolEraseBtn
@onready var _play_pause_btn: Button = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/PlayPauseBtn
@onready var _grid_snap_btn: Button = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/GridSnapBtn
@onready var _save_room_btn: Button = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/SaveRoomBtn
@onready var _reset_room_btn: Button = $RootControl/TopBarPanel/TopBarMargin/TopBarHBox/ResetRoomBtn

@onready var _side_palette_panel: PanelContainer = $RootControl/SidePalettePanel
@onready var _tab_blocks_btn: Button = $RootControl/SidePalettePanel/SideMargin/SideVBox/TabsHBox/TabBlocksBtn
@onready var _tab_enemies_btn: Button = $RootControl/SidePalettePanel/SideMargin/SideVBox/TabsHBox/TabEnemiesBtn
@onready var _tab_props_btn: Button = $RootControl/SidePalettePanel/SideMargin/SideVBox/TabsHBox/TabPropsBtn
@onready var _tab_cheats_btn: Button = $RootControl/SidePalettePanel/SideMargin/SideVBox/TabsHBox/TabCheatsBtn
@onready var _palette_list: VBoxContainer = $RootControl/SidePalettePanel/SideMargin/SideVBox/PaletteScroll/PaletteList

@onready var _inspector_box: VBoxContainer = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox
@onready var _width_label: Label = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/WidthRow/WidthLabel
@onready var _width_spin: SpinBox = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/WidthRow/WidthSpin
@onready var _height_label: Label = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/HeightRow/HeightLabel
@onready var _height_spin: SpinBox = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/HeightRow/HeightSpin
@onready var _tilt_label: Label = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/TiltRow/TiltLabel
@onready var _tilt_spin: SpinBox = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/TiltRow/TiltSpin
@onready var _one_way_check: CheckButton = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/OneWayCheck
@onready var _wind_x_row: HBoxContainer = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/WindXRow
@onready var _wind_x_label: Label = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/WindXRow/WindXLabel
@onready var _wind_x_spin: SpinBox = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/WindXRow/WindXSpin
@onready var _wind_y_row: HBoxContainer = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/WindYRow
@onready var _wind_y_label: Label = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/WindYRow/WindYLabel
@onready var _wind_y_spin: SpinBox = $RootControl/SidePalettePanel/SideMargin/SideVBox/InspectorBox/WindYRow/WindYSpin

@onready var _bottom_bar_panel: PanelContainer = $RootControl/BottomBarPanel
@onready var _cam_hint_label: Label = $RootControl/BottomBarPanel/BottomMargin/CamHintLabel
@onready var _toast_panel: PanelContainer = $RootControl/ToastPanel
@onready var _toast_label: Label = $RootControl/ToastPanel/ToastMargin/ToastLabel

var _is_open: bool = false
var _world_paused: bool = false
var _active_tool: int = TOOL_PLACE
var _active_tab: int = TAB_BLOCKS
var _grid_snap_index: int = 2  # Default 32 px
var _selected_palette_id: String = "sand_dune_ground"

var _god_mode_enabled: bool = false
var _teleport_click_armed: bool = false

var _free_cam_active: bool = false
var _free_cam_pos: Vector2 = Vector2(960.0, 540.0)
var _free_cam_zoom: float = 1.0
var _is_panning_middle: bool = false
var _pan_last_screen: Vector2 = Vector2.ZERO

var _is_dragging_place: bool = false
var _drag_start_world: Vector2 = Vector2.ZERO
var _drag_current_world: Vector2 = Vector2.ZERO

var _selected_node: Node2D = null
var _is_dragging_move: bool = false
var _move_drag_offset: Vector2 = Vector2.ZERO

var _syncing_inspector: bool = false
var _toast_timer: float = 0.0
var _spawn_counter: int = 0
var _palette_buttons: Dictionary = {}
var _god_mode_button: CheckButton = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 85

	_style_panels()
	_connect_ui_signals()
	_world_draw_canvas.draw.connect(_on_world_canvas_draw)

	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.room_loaded.connect(_on_room_loaded)

	_root_control.visible = false
	_world_draw_canvas.visible = false
	_toast_panel.visible = false

	_rebuild_palette_list()
	_refresh_texts()
	_sync_tool_buttons()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer = maxf(_toast_timer - delta, 0.0)
		if _toast_timer <= 0.0:
			_toast_panel.visible = false

	if not _is_open:
		return

	if not GameState.is_gameplay_active:
		close_dev_mode()
		return

	# Clean up dangling selection reference if node was freed.
	if _selected_node != null and not is_instance_valid(_selected_node):
		_selected_node = null

	# WASD free-cam panning while world is paused and not typing into a SpinBox.
	if _world_paused and not _is_typing_in_ui():
		var pan_dir: Vector2 = Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			pan_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			pan_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			pan_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			pan_dir.y += 1.0
		if pan_dir != Vector2.ZERO:
			_ensure_free_cam()
			var pan_speed: float = 760.0 / maxf(_free_cam_zoom, 0.25)
			_free_cam_pos += pan_dir.normalized() * pan_speed * delta
			_push_free_cam()

	_world_draw_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_dev_mode"):
		if not GameState.is_gameplay_active:
			return
		get_viewport().set_input_as_handled()
		if _is_open:
			close_dev_mode()
		else:
			open_dev_mode()
		return

	if not _is_open:
		return

	if event is InputEventKey:
		var key_ev: InputEventKey = event as InputEventKey
		if key_ev.pressed and not key_ev.echo:
			if key_ev.keycode == KEY_F2:
				get_viewport().set_input_as_handled()
				_toggle_world_paused()
				return
			if key_ev.keycode == KEY_T and not _is_typing_in_ui():
				get_viewport().set_input_as_handled()
				_teleport_player_to_world(_screen_to_world(get_viewport().get_mouse_position()))
				return
			if key_ev.keycode == KEY_DELETE or key_ev.keycode == KEY_BACKSPACE:
				if _selected_node != null and is_instance_valid(_selected_node) and not _is_typing_in_ui():
					get_viewport().set_input_as_handled()
					_delete_custom_node(_selected_node)
					return


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open or not GameState.is_gameplay_active:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var screen_pos: Vector2 = mb.position
		if _is_point_over_ui(screen_pos):
			return

		# Mouse Wheel Zoom (0.5x..1.5x)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			_adjust_zoom(0.1)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			_adjust_zoom(-0.1)
			return

		# Middle-Mouse Free-Cam Pan
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			get_viewport().set_input_as_handled()
			if mb.pressed:
				_is_panning_middle = true
				_pan_last_screen = screen_pos
				_ensure_free_cam()
			else:
				_is_panning_middle = false
			return

		# Right-Click quick erase in any tool
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			_is_dragging_place = false
			_is_dragging_move = false
			_teleport_click_armed = false
			var hit_node: Node2D = _pick_custom_node_at(_screen_to_world(screen_pos))
			if hit_node != null:
				_delete_custom_node(hit_node)
			return

		# Left-Click actions
		if mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			var world_pos: Vector2 = _screen_to_world(screen_pos)
			if mb.pressed:
				if _teleport_click_armed:
					_teleport_click_armed = false
					_teleport_player_to_world(world_pos)
					return
				_handle_left_press(world_pos)
			else:
				_handle_left_release(world_pos)
			return

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_panning_middle:
			get_viewport().set_input_as_handled()
			var delta_screen: Vector2 = mm.position - _pan_last_screen
			_pan_last_screen = mm.position
			_free_cam_pos -= delta_screen / maxf(_free_cam_zoom, 0.25)
			_push_free_cam()
			return

		var world_pos: Vector2 = _screen_to_world(mm.position)
		if _is_dragging_place:
			_drag_current_world = _snap_point(world_pos)
		elif _is_dragging_move and _selected_node != null and is_instance_valid(_selected_node):
			var new_pos: Vector2 = _snap_point(world_pos - _move_drag_offset)
			_selected_node.global_position = new_pos
			var meta_dict: Dictionary = _get_node_item_dict(_selected_node)
			meta_dict["pos"] = [new_pos.x, new_pos.y]
			_selected_node.set_meta("dev_item", meta_dict)


func open_dev_mode() -> void:
	if _is_open or not GameState.is_gameplay_active:
		return
	_is_open = true
	_root_control.visible = true
	_world_draw_canvas.visible = true
	_teleport_click_armed = false

	var cam: RoomCamera = _get_camera()
	if cam != null:
		_free_cam_pos = cam.global_position
		_free_cam_zoom = 1.0

	_refresh_texts()
	_sync_tool_buttons()
	_sync_inspector_visibility()
	AudioManager.play_sfx("ui_click")


func close_dev_mode() -> void:
	if not _is_open:
		return
	_is_open = false
	_is_dragging_place = false
	_is_dragging_move = false
	_is_panning_middle = false
	_teleport_click_armed = false
	_selected_node = null

	if _world_paused:
		_world_paused = false
		get_tree().paused = false

	if _free_cam_active:
		_free_cam_active = false
		_free_cam_zoom = 1.0
		var cam: RoomCamera = _get_camera()
		if cam != null:
			cam.set_free_cam(false)

	_root_control.visible = false
	_world_draw_canvas.visible = false
	_toast_panel.visible = false
	AudioManager.play_sfx("ui_click")


func is_dev_mode_open() -> bool:
	return _is_open


func load_custom_room_items(room: RoomBase) -> void:
	if room == null or room.room_id.is_empty():
		return
	var save_path: String = _get_room_save_path(room.room_id)
	if not FileAccess.file_exists(save_path):
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var raw_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(raw_text) != OK or not (json.data is Dictionary):
		push_warning("DevModeController: invalid custom level JSON at %s" % save_path)
		return

	var root: Dictionary = json.data as Dictionary
	var items_raw: Variant = root.get("items", [])
	if not (items_raw is Array):
		return

	var custom_layer: Node2D = room.get_or_create_custom_layer()
	for child: Node in custom_layer.get_children():
		child.queue_free()

	for item_variant: Variant in items_raw as Array:
		if item_variant is Dictionary:
			_spawn_item_from_dict(room, item_variant as Dictionary)


func save_custom_room_items(room: RoomBase) -> bool:
	if room == null or room.room_id.is_empty():
		return false

	var user_dir: DirAccess = DirAccess.open("user://")
	if user_dir == null:
		return false
	if not user_dir.dir_exists(CUSTOM_LEVELS_DIR):
		if user_dir.make_dir_recursive(CUSTOM_LEVELS_DIR) != OK:
			return false

	var custom_layer: Node2D = room.get_or_create_custom_layer()
	var serialized_items: Array = []
	for child: Node in custom_layer.get_children():
		if child is Node2D and child.has_meta("dev_item"):
			var raw_meta: Variant = child.get_meta("dev_item")
			if raw_meta is Dictionary:
				var entry: Dictionary = (raw_meta as Dictionary).duplicate(true)
				var pos: Vector2 = (child as Node2D).global_position
				entry["pos"] = [pos.x, pos.y]
				serialized_items.append(entry)

	var payload: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"room_id": room.room_id,
		"items": serialized_items,
	}

	var save_path: String = _get_room_save_path(room.room_id)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	return true


func reset_custom_room_items(room: RoomBase) -> void:
	if room == null or room.room_id.is_empty():
		return
	var save_path: String = _get_room_save_path(room.room_id)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var custom_layer: Node2D = room.get_or_create_custom_layer()
	for child: Node in custom_layer.get_children():
		child.queue_free()
	_selected_node = null


func _handle_left_press(world_pos: Vector2) -> void:
	var room: RoomBase = _get_current_room()
	if room == null:
		return

	if _active_tool == TOOL_ERASE:
		var hit_erase: Node2D = _pick_custom_node_at(world_pos)
		if hit_erase != null:
			_delete_custom_node(hit_erase)
		return

	if _active_tool == TOOL_MOVE:
		var hit_move: Node2D = _pick_custom_node_at(world_pos)
		_selected_node = hit_move
		if _selected_node != null:
			_is_dragging_move = true
			_move_drag_offset = world_pos - _selected_node.global_position
			_load_inspector_from_node(_selected_node)
		_sync_inspector_visibility()
		return

	# TOOL_PLACE
	var entry: Dictionary = _get_selected_palette_entry()
	if entry.is_empty():
		return

	var kind: String = str(entry.get("kind", "block"))
	if _is_resizable_kind(kind):
		_is_dragging_place = true
		_drag_start_world = _snap_point(world_pos)
		_drag_current_world = _drag_start_world
	else:
		var snapped: Vector2 = _snap_point(world_pos)
		var item_dict: Dictionary = _build_item_dict_from_palette(entry, snapped, Vector2(float(entry.get("w", 64.0)), float(entry.get("h", 64.0))))
		var spawned: Node2D = _spawn_item_from_dict(room, item_dict)
		if spawned != null:
			_selected_node = spawned
			AudioManager.play_sfx("ui_click")


func _handle_left_release(world_pos: Vector2) -> void:
	if _is_dragging_move:
		_is_dragging_move = false
		return

	if not _is_dragging_place:
		return
	_is_dragging_place = false

	var room: RoomBase = _get_current_room()
	var entry: Dictionary = _get_selected_palette_entry()
	if room == null or entry.is_empty():
		return

	var end_world: Vector2 = _snap_point(world_pos)
	var drag_delta: Vector2 = end_world - _drag_start_world
	var place_pos: Vector2 = _drag_start_world
	var place_size: Vector2 = Vector2(_width_spin.value, _height_spin.value)

	if drag_delta.length() >= 16.0:
		place_pos = (_drag_start_world + end_world) * 0.5
		place_size = Vector2(
			maxf(32.0, absf(drag_delta.x)),
			maxf(24.0, absf(drag_delta.y))
		)
		_syncing_inspector = true
		_width_spin.value = place_size.x
		_height_spin.value = place_size.y
		_syncing_inspector = false

	var item_dict: Dictionary = _build_item_dict_from_palette(entry, place_pos, place_size)
	var spawned: Node2D = _spawn_item_from_dict(room, item_dict)
	if spawned != null:
		_selected_node = spawned
		AudioManager.play_sfx("ui_click")


func _build_item_dict_from_palette(entry: Dictionary, pos: Vector2, size: Vector2) -> Dictionary:
	return {
		"kind": str(entry.get("kind", "block")),
		"style": str(entry.get("style", "sand_dune_ground")),
		"pos": [pos.x, pos.y],
		"size": [size.x, size.y],
		"angle": _tilt_spin.value if str(entry.get("kind", "")) == "block" else 0.0,
		"one_way": _one_way_check.button_pressed if str(entry.get("kind", "")) == "block" else false,
		"wind_force": [_wind_x_spin.value, _wind_y_spin.value] if str(entry.get("kind", "")) == "wind" else [0.0, 0.0],
	}


func _spawn_item_from_dict(room: RoomBase, item: Dictionary) -> Node2D:
	var kind: String = str(item.get("kind", "block"))
	var style: String = str(item.get("style", "sand_dune_ground"))
	var scene_path: String = _resolve_scene_path(kind, style)
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("DevModeController: missing scene path '%s' for %s/%s" % [scene_path, kind, style])
		return null

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	if not (instance is Node2D):
		instance.queue_free()
		return null

	var node2d: Node2D = instance as Node2D
	_spawn_counter += 1

	# Prevent custom dev-placed unique bosses/orbs/pages from auto-despawning on GameState history.
	if kind == "boss" and "boss_id" in node2d:
		node2d.set("boss_id", "dev_boss_%d" % _spawn_counter)
	elif kind == "prop":
		if style == "memory_orb" and "orb_id" in node2d:
			node2d.set("orb_id", "dev_orb_%d" % _spawn_counter)
		elif style == "notebook_page" and "page_id" in node2d:
			node2d.set("page_id", "dev_page_%d" % _spawn_counter)
		elif style == "orb_shrine" and "room_id" in node2d:
			node2d.set("room_id", room.room_id)

	var pos_arr: Array = item.get("pos", [0.0, 0.0]) as Array if item.get("pos", []) is Array else [0.0, 0.0]
	var pos: Vector2 = Vector2(float(pos_arr[0]), float(pos_arr[1])) if pos_arr.size() >= 2 else Vector2.ZERO
	node2d.position = pos

	var layer_node: Node2D = room.get_or_create_custom_layer()
	layer_node.add_child(node2d)
	node2d.global_position = pos

	_apply_item_config_to_node(node2d, item)
	node2d.set_meta("dev_item", item.duplicate(true))

	if kind == "boss" and node2d.has_method("start_encounter"):
		node2d.call_deferred("start_encounter")

	return node2d


func _apply_item_config_to_node(node: Node2D, item: Dictionary) -> void:
	var kind: String = str(item.get("kind", "block"))
	var style: String = str(item.get("style", "sand_dune_ground"))
	var size_arr: Array = item.get("size", [256.0, 64.0]) as Array if item.get("size", []) is Array else [256.0, 64.0]
	var size: Vector2 = Vector2(float(size_arr[0]), float(size_arr[1])) if size_arr.size() >= 2 else Vector2(256.0, 64.0)
	var angle: float = float(item.get("angle", 0.0))
	var one_way: bool = bool(item.get("one_way", false))
	var wind_arr: Array = item.get("wind_force", [-240.0, 0.0]) as Array if item.get("wind_force", []) is Array else [-240.0, 0.0]
	var wind_force: Vector2 = Vector2(float(wind_arr[0]), float(wind_arr[1])) if wind_arr.size() >= 2 else Vector2(-240.0, 0.0)

	if kind == "block" and node.has_method("configure"):
		node.call("configure", style, size, one_way, angle)
	elif kind == "deep_sand" and node.has_method("configure"):
		node.call("configure", size, 0.60)
	elif kind == "wind" and node.has_method("configure"):
		node.call("configure", size, wind_force)
	elif kind == "crumbling" and node.has_method("configure"):
		node.call("configure", size)


func _delete_custom_node(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _selected_node == node:
		_selected_node = null
	node.queue_free()
	AudioManager.play_sfx("ui_click")


func _pick_custom_node_at(world_pos: Vector2) -> Node2D:
	var room: RoomBase = _get_current_room()
	if room == null:
		return null
	var custom_layer: Node2D = room.get_or_create_custom_layer()
	var children: Array[Node] = custom_layer.get_children()
	for i: int in range(children.size() - 1, -1, -1):
		var child: Node = children[i]
		if not (child is Node2D) or not child.has_meta("dev_item"):
			continue
		var node2d: Node2D = child as Node2D
		var meta: Dictionary = _get_node_item_dict(node2d)
		var size_arr: Array = meta.get("size", [64.0, 64.0]) as Array if meta.get("size", []) is Array else [64.0, 64.0]
		var size: Vector2 = Vector2(maxf(float(size_arr[0]), 48.0), maxf(float(size_arr[1]), 48.0)) if size_arr.size() >= 2 else Vector2(64.0, 64.0)
		var angle_rad: float = deg_to_rad(float(meta.get("angle", 0.0)))
		var local_p: Vector2 = (world_pos - node2d.global_position).rotated(-angle_rad)
		if absf(local_p.x) <= size.x * 0.5 and absf(local_p.y) <= size.y * 0.5:
			return node2d
	return null


func _on_world_canvas_draw() -> void:
	if not _is_open:
		return

	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	var inv_xform: Transform2D = canvas_xform.affine_inverse()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	# 1. Translucent snap grid in world coordinates.
	var snap: int = _get_grid_snap()
	if snap > 0:
		var top_left_w: Vector2 = inv_xform * Vector2.ZERO
		var bot_right_w: Vector2 = inv_xform * vp_size
		var start_x: float = floorf(top_left_w.x / float(snap)) * float(snap)
		var start_y: float = floorf(top_left_w.y / float(snap)) * float(snap)
		var grid_col: Color = Color(0.965, 0.886, 0.600, 0.10)
		var major_col: Color = Color(0.965, 0.886, 0.600, 0.22)
		var step: float = float(snap)
		var gx: float = start_x
		var guard_x: int = 0
		while gx <= bot_right_w.x and guard_x < 240:
			var p0: Vector2 = canvas_xform * Vector2(gx, top_left_w.y)
			var p1: Vector2 = canvas_xform * Vector2(gx, bot_right_w.y)
			var is_major: bool = (int(round(gx)) % (snap * 4)) == 0
			_world_draw_canvas.draw_line(p0, p1, major_col if is_major else grid_col, 1.0)
			gx += step
			guard_x += 1
		var gy: float = start_y
		var guard_y: int = 0
		while gy <= bot_right_w.y and guard_y < 160:
			var p0: Vector2 = canvas_xform * Vector2(top_left_w.x, gy)
			var p1: Vector2 = canvas_xform * Vector2(bot_right_w.x, gy)
			var is_major: bool = (int(round(gy)) % (snap * 4)) == 0
			_world_draw_canvas.draw_line(p0, p1, major_col if is_major else grid_col, 1.0)
			gy += step
			guard_y += 1

	# 2. Outlines for custom-placed items & active selection highlight.
	var room: RoomBase = _get_current_room()
	if room != null:
		var custom_layer: Node2D = room.get_node_or_null("DevCustomLayer") as Node2D
		if custom_layer != null:
			for child: Node in custom_layer.get_children():
				if child is Node2D and child.has_meta("dev_item"):
					var node2d: Node2D = child as Node2D
					var meta: Dictionary = _get_node_item_dict(node2d)
					var size_arr: Array = meta.get("size", [64.0, 64.0]) as Array if meta.get("size", []) is Array else [64.0, 64.0]
					var sz: Vector2 = Vector2(float(size_arr[0]), float(size_arr[1])) if size_arr.size() >= 2 else Vector2(64.0, 64.0)
					var ang: float = float(meta.get("angle", 0.0))
					var is_sel: bool = (node2d == _selected_node)
					var col: Color = Color(0.965, 0.886, 0.600, 0.92) if is_sel else Color(0.776, 0.545, 0.349, 0.38)
					_draw_world_box(canvas_xform, node2d.global_position, sz, ang, Color(col.r, col.g, col.b, 0.08 if is_sel else 0.0), col, 2.5 if is_sel else 1.2)

	# 3. Live ghost preview under mouse cursor (when not over UI panels).
	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	if not _is_point_over_ui(mouse_screen):
		var cursor_world: Vector2 = _snap_point(inv_xform * mouse_screen)
		if _teleport_click_armed:
			var sp: Vector2 = canvas_xform * cursor_world
			_world_draw_canvas.draw_arc(sp, 18.0, 0.0, TAU, 24, Color(0.290, 0.565, 0.851, 0.95), 2.5, true)
			_world_draw_canvas.draw_line(sp + Vector2(-24.0, 0.0), sp + Vector2(24.0, 0.0), Color(0.965, 0.886, 0.600, 0.9), 1.5)
			_world_draw_canvas.draw_line(sp + Vector2(0.0, -24.0), sp + Vector2(0.0, 24.0), Color(0.965, 0.886, 0.600, 0.9), 1.5)
		elif _active_tool == TOOL_PLACE:
			var entry: Dictionary = _get_selected_palette_entry()
			if not entry.is_empty():
				var kind: String = str(entry.get("kind", "block"))
				var preview_pos: Vector2 = cursor_world
				var preview_size: Vector2 = Vector2(_width_spin.value, _height_spin.value) if _is_resizable_kind(kind) else Vector2(float(entry.get("w", 64.0)), float(entry.get("h", 64.0)))
				if _is_dragging_place:
					var d: Vector2 = _drag_current_world - _drag_start_world
					if d.length() >= 16.0:
						preview_pos = (_drag_start_world + _drag_current_world) * 0.5
						preview_size = Vector2(maxf(32.0, absf(d.x)), maxf(24.0, absf(d.y)))
				var preview_angle: float = _tilt_spin.value if kind == "block" else 0.0
				var fill_col: Color = Color(0.965, 0.886, 0.600, 0.20)
				var stroke_col: Color = Color(0.965, 0.886, 0.600, 0.85)
				if kind == "wind":
					fill_col = Color(0.310, 0.427, 0.478, 0.22)
					stroke_col = Color(0.55, 0.85, 0.95, 0.90)
				elif kind == "deep_sand":
					fill_col = Color(0.878, 0.478, 0.235, 0.25)
					stroke_col = Color(0.965, 0.886, 0.600, 0.90)
				elif kind == "enemy" or kind == "boss":
					fill_col = Color(0.659, 0.267, 0.196, 0.24)
					stroke_col = Color(0.92, 0.45, 0.35, 0.90)

				_draw_world_box(canvas_xform, preview_pos, preview_size, preview_angle, fill_col, stroke_col, 2.0)

				if kind == "wind":
					var wf: Vector2 = Vector2(_wind_x_spin.value, _wind_y_spin.value)
					if wf.length() > 1.0:
						var dir: Vector2 = wf.normalized()
						var arrow_start: Vector2 = canvas_xform * (preview_pos - dir * 48.0)
						var arrow_end: Vector2 = canvas_xform * (preview_pos + dir * 48.0)
						_world_draw_canvas.draw_line(arrow_start, arrow_end, stroke_col, 3.0, true)
						var head_dir: Vector2 = (arrow_end - arrow_start).normalized()
						var perp: Vector2 = Vector2(-head_dir.y, head_dir.x)
						_world_draw_canvas.draw_line(arrow_end, arrow_end - head_dir * 12.0 + perp * 7.0, stroke_col, 2.5, true)
						_world_draw_canvas.draw_line(arrow_end, arrow_end - head_dir * 12.0 - perp * 7.0, stroke_col, 2.5, true)
		elif _active_tool == TOOL_ERASE:
			var hover_erase: Node2D = _pick_custom_node_at(inv_xform * mouse_screen)
			if hover_erase != null:
				var meta: Dictionary = _get_node_item_dict(hover_erase)
				var sz_arr: Array = meta.get("size", [64.0, 64.0]) as Array if meta.get("size", []) is Array else [64.0, 64.0]
				var sz: Vector2 = Vector2(float(sz_arr[0]), float(sz_arr[1])) if sz_arr.size() >= 2 else Vector2(64.0, 64.0)
				_draw_world_box(canvas_xform, hover_erase.global_position, sz, float(meta.get("angle", 0.0)), Color(0.85, 0.22, 0.18, 0.28), Color(1.0, 0.35, 0.30, 0.95), 2.5)


func _draw_world_box(canvas_xform: Transform2D, center: Vector2, size: Vector2, angle_deg: float, fill: Color, stroke: Color, width: float) -> void:
	var half: Vector2 = size * 0.5
	var rad: float = deg_to_rad(angle_deg)
	# Strictly clockwise convex quad (never self-intersecting).
	var pts: PackedVector2Array = PackedVector2Array([
		canvas_xform * (center + Vector2(-half.x, -half.y).rotated(rad)),
		canvas_xform * (center + Vector2(half.x, -half.y).rotated(rad)),
		canvas_xform * (center + Vector2(half.x, half.y).rotated(rad)),
		canvas_xform * (center + Vector2(-half.x, half.y).rotated(rad)),
	])
	if fill.a > 0.001:
		_world_draw_canvas.draw_colored_polygon(pts, fill)
	var closed: PackedVector2Array = PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	_world_draw_canvas.draw_polyline(closed, stroke, width, true)


func _connect_ui_signals() -> void:
	_tool_place_btn.pressed.connect(_on_tool_selected.bind(TOOL_PLACE))
	_tool_move_btn.pressed.connect(_on_tool_selected.bind(TOOL_MOVE))
	_tool_erase_btn.pressed.connect(_on_tool_selected.bind(TOOL_ERASE))
	_play_pause_btn.pressed.connect(_toggle_world_paused)
	_grid_snap_btn.pressed.connect(_cycle_grid_snap)
	_save_room_btn.pressed.connect(_on_save_room_pressed)
	_reset_room_btn.pressed.connect(_on_reset_room_pressed)

	_tab_blocks_btn.pressed.connect(_on_tab_selected.bind(TAB_BLOCKS))
	_tab_enemies_btn.pressed.connect(_on_tab_selected.bind(TAB_ENEMIES))
	_tab_props_btn.pressed.connect(_on_tab_selected.bind(TAB_PROPS))
	_tab_cheats_btn.pressed.connect(_on_tab_selected.bind(TAB_CHEATS))

	_width_spin.value_changed.connect(_on_inspector_changed)
	_height_spin.value_changed.connect(_on_inspector_changed)
	_tilt_spin.value_changed.connect(_on_inspector_changed)
	_one_way_check.toggled.connect(_on_inspector_toggled)
	_wind_x_spin.value_changed.connect(_on_inspector_changed)
	_wind_y_spin.value_changed.connect(_on_inspector_changed)


func _style_panels() -> void:
	var panel_bg: StyleBoxFlat = StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.086, 0.106, 0.200, 0.90)
	panel_bg.border_color = Color(0.965, 0.886, 0.600, 0.65)
	panel_bg.set_border_width_all(2)
	panel_bg.set_corner_radius_all(6)

	_top_bar_panel.add_theme_stylebox_override("panel", panel_bg)
	_side_palette_panel.add_theme_stylebox_override("panel", panel_bg)
	_bottom_bar_panel.add_theme_stylebox_override("panel", panel_bg)

	var toast_bg: StyleBoxFlat = StyleBoxFlat.new()
	toast_bg.bg_color = Color(0.11, 0.15, 0.26, 0.95)
	toast_bg.border_color = Color(0.965, 0.886, 0.600, 0.90)
	toast_bg.set_border_width_all(2)
	toast_bg.set_corner_radius_all(8)
	_toast_panel.add_theme_stylebox_override("panel", toast_bg)


func _refresh_texts() -> void:
	var active_locale: String = TranslationServer.get_locale()
	ArabicFontSetup.apply_to_control(_root_control, active_locale)

	_title_label.text = tr("DEV_TITLE")
	_hint_label.text = tr("DEV_HINT_TOGGLE")
	_tool_place_btn.text = tr("DEV_TOOL_PLACE")
	_tool_move_btn.text = tr("DEV_TOOL_MOVE")
	_tool_erase_btn.text = tr("DEV_TOOL_ERASE")
	_play_pause_btn.text = tr("DEV_PLAY_WORLD") if _world_paused else tr("DEV_PAUSE_WORLD")

	var snap_val: String = str(_get_grid_snap())
	_grid_snap_btn.text = ArabicFontSetup.format_bidi_pair(tr("DEV_GRID_SNAP"), snap_val)

	_save_room_btn.text = tr("DEV_SAVE_ROOM")
	_reset_room_btn.text = tr("DEV_RESET_ROOM")

	_tab_blocks_btn.text = tr("DEV_TAB_BLOCKS")
	_tab_enemies_btn.text = tr("DEV_TAB_ENEMIES")
	_tab_props_btn.text = tr("DEV_TAB_PROPS")
	_tab_cheats_btn.text = tr("DEV_TAB_CHEATS")

	_width_label.text = tr("DEV_PROP_WIDTH")
	_height_label.text = tr("DEV_PROP_HEIGHT")
	_tilt_label.text = tr("DEV_PROP_TILT")
	_one_way_check.text = tr("DEV_PROP_ONE_WAY")
	_wind_x_label.text = tr("DEV_PROP_WIND_X")
	_wind_y_label.text = tr("DEV_PROP_WIND_Y")
	_cam_hint_label.text = tr("DEV_CAM_HINT")

	_rebuild_palette_list()


func _rebuild_palette_list() -> void:
	for child: Node in _palette_list.get_children():
		child.queue_free()
	_palette_buttons.clear()
	_god_mode_button = null

	if _active_tab == TAB_CHEATS:
		var god_btn: CheckButton = CheckButton.new()
		god_btn.text = tr("DEV_CHEAT_GOD")
		god_btn.button_pressed = _god_mode_enabled
		god_btn.toggled.connect(_on_cheat_god_toggled)
		_palette_list.add_child(god_btn)
		_god_mode_button = god_btn

		var abil_btn: Button = Button.new()
		abil_btn.text = tr("DEV_CHEAT_ABILITIES")
		abil_btn.pressed.connect(_on_cheat_unlock_abilities)
		_palette_list.add_child(abil_btn)

		var refill_btn: Button = Button.new()
		refill_btn.text = tr("DEV_CHEAT_REFILL")
		refill_btn.pressed.connect(_on_cheat_refill)
		_palette_list.add_child(refill_btn)

		var tp_btn: Button = Button.new()
		tp_btn.text = tr("DEV_CHEAT_TELEPORT")
		tp_btn.pressed.connect(_on_cheat_arm_teleport)
		_palette_list.add_child(tp_btn)
	else:
		var entries: Array = _get_palette_for_tab(_active_tab)
		var found_selected: bool = false
		for entry_var: Variant in entries:
			var entry: Dictionary = entry_var as Dictionary
			var item_id: String = str(entry["id"])
			var btn: Button = Button.new()
			btn.toggle_mode = true
			btn.text = tr(str(entry["key"]))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if item_id == _selected_palette_id:
				btn.button_pressed = true
				found_selected = true
			btn.pressed.connect(_on_palette_item_selected.bind(item_id))
			_palette_list.add_child(btn)
			_palette_buttons[item_id] = btn

		if not found_selected and not entries.is_empty():
			var first_id: String = str((entries[0] as Dictionary)["id"])
			_selected_palette_id = first_id
			if _palette_buttons.has(first_id):
				(_palette_buttons[first_id] as Button).button_pressed = true
			_apply_palette_defaults_to_inspector(entries[0] as Dictionary)

	ArabicFontSetup.apply_to_control(_palette_list, TranslationServer.get_locale())
	_sync_inspector_visibility()


func _sync_tool_buttons() -> void:
	_tool_place_btn.button_pressed = (_active_tool == TOOL_PLACE)
	_tool_move_btn.button_pressed = (_active_tool == TOOL_MOVE)
	_tool_erase_btn.button_pressed = (_active_tool == TOOL_ERASE)
	_tab_blocks_btn.button_pressed = (_active_tab == TAB_BLOCKS)
	_tab_enemies_btn.button_pressed = (_active_tab == TAB_ENEMIES)
	_tab_props_btn.button_pressed = (_active_tab == TAB_PROPS)
	_tab_cheats_btn.button_pressed = (_active_tab == TAB_CHEATS)


func _sync_inspector_visibility() -> void:
	var active_kind: String = ""
	if _active_tool == TOOL_MOVE and _selected_node != null and is_instance_valid(_selected_node):
		active_kind = str(_get_node_item_dict(_selected_node).get("kind", ""))
	elif _active_tab == TAB_BLOCKS:
		active_kind = str(_get_selected_palette_entry().get("kind", "block"))

	var show_inspector: bool = _is_resizable_kind(active_kind)
	_inspector_box.visible = show_inspector
	if show_inspector:
		var is_block: bool = (active_kind == "block")
		var is_wind: bool = (active_kind == "wind")
		_tilt_spin.get_parent().visible = is_block
		_one_way_check.visible = is_block
		_wind_x_row.visible = is_wind
		_wind_y_row.visible = is_wind


func _on_tool_selected(tool_id: int) -> void:
	_active_tool = tool_id
	_teleport_click_armed = false
	_is_dragging_place = false
	_is_dragging_move = false
	_sync_tool_buttons()
	_sync_inspector_visibility()
	AudioManager.play_sfx("ui_click")


func _on_tab_selected(tab_id: int) -> void:
	_active_tab = tab_id
	if _active_tab != TAB_CHEATS:
		_active_tool = TOOL_PLACE
	_sync_tool_buttons()
	_rebuild_palette_list()
	AudioManager.play_sfx("ui_click")


func _on_palette_item_selected(item_id: String) -> void:
	_selected_palette_id = item_id
	_active_tool = TOOL_PLACE
	_teleport_click_armed = false
	for key: Variant in _palette_buttons.keys():
		var btn: Button = _palette_buttons[key] as Button
		btn.button_pressed = (str(key) == item_id)
	var entry: Dictionary = _get_selected_palette_entry()
	if not entry.is_empty():
		_apply_palette_defaults_to_inspector(entry)
	_sync_tool_buttons()
	_sync_inspector_visibility()
	AudioManager.play_sfx("ui_click")


func _apply_palette_defaults_to_inspector(entry: Dictionary) -> void:
	_syncing_inspector = true
	_width_spin.value = float(entry.get("w", 256.0))
	_height_spin.value = float(entry.get("h", 64.0))
	_tilt_spin.value = 0.0
	_one_way_check.button_pressed = (str(entry.get("style", "")) == "cracked_glass_bridge")
	_syncing_inspector = false


func _load_inspector_from_node(node: Node2D) -> void:
	var meta: Dictionary = _get_node_item_dict(node)
	var size_arr: Array = meta.get("size", [256.0, 64.0]) as Array if meta.get("size", []) is Array else [256.0, 64.0]
	var wind_arr: Array = meta.get("wind_force", [-240.0, 0.0]) as Array if meta.get("wind_force", []) is Array else [-240.0, 0.0]
	_syncing_inspector = true
	if size_arr.size() >= 2:
		_width_spin.value = float(size_arr[0])
		_height_spin.value = float(size_arr[1])
	_tilt_spin.value = float(meta.get("angle", 0.0))
	_one_way_check.button_pressed = bool(meta.get("one_way", false))
	if wind_arr.size() >= 2:
		_wind_x_spin.value = float(wind_arr[0])
		_wind_y_spin.value = float(wind_arr[1])
	_syncing_inspector = false


func _on_inspector_changed(_val: float) -> void:
	_apply_inspector_to_selected()


func _on_inspector_toggled(_pressed: bool) -> void:
	_apply_inspector_to_selected()


func _apply_inspector_to_selected() -> void:
	if _syncing_inspector or _selected_node == null or not is_instance_valid(_selected_node):
		return
	var meta: Dictionary = _get_node_item_dict(_selected_node)
	var kind: String = str(meta.get("kind", ""))
	if not _is_resizable_kind(kind):
		return
	meta["size"] = [_width_spin.value, _height_spin.value]
	meta["angle"] = _tilt_spin.value if kind == "block" else 0.0
	meta["one_way"] = _one_way_check.button_pressed if kind == "block" else false
	meta["wind_force"] = [_wind_x_spin.value, _wind_y_spin.value] if kind == "wind" else [0.0, 0.0]
	_selected_node.set_meta("dev_item", meta)
	_apply_item_config_to_node(_selected_node, meta)


func _toggle_world_paused() -> void:
	_world_paused = not _world_paused
	get_tree().paused = _world_paused
	if _world_paused:
		_ensure_free_cam()
	else:
		_free_cam_active = false
		_free_cam_zoom = 1.0
		var cam: RoomCamera = _get_camera()
		if cam != null:
			cam.set_free_cam(false)
	_play_pause_btn.text = tr("DEV_PLAY_WORLD") if _world_paused else tr("DEV_PAUSE_WORLD")
	AudioManager.play_sfx("ui_click")


func _cycle_grid_snap() -> void:
	_grid_snap_index = (_grid_snap_index + 1) % GRID_SNAP_STEPS.size()
	var snap_val: String = str(_get_grid_snap())
	_grid_snap_btn.text = ArabicFontSetup.format_bidi_pair(tr("DEV_GRID_SNAP"), snap_val)
	AudioManager.play_sfx("ui_click")


func _on_save_room_pressed() -> void:
	var room: RoomBase = _get_current_room()
	if room != null and save_custom_room_items(room):
		_show_toast("DEV_SAVED_OK")
		AudioManager.play_sfx("shrine_rest")


func _on_reset_room_pressed() -> void:
	var room: RoomBase = _get_current_room()
	if room != null:
		reset_custom_room_items(room)
		_show_toast("DEV_RESET_OK")
		AudioManager.play_sfx("ui_click")


func _on_cheat_god_toggled(toggled_on: bool) -> void:
	_god_mode_enabled = toggled_on
	var player: Node2D = _get_player()
	if player != null and player.has_method("set_god_mode"):
		player.call("set_god_mode", _god_mode_enabled)
	AudioManager.play_sfx("ui_click")


func _on_cheat_unlock_abilities() -> void:
	for abil: Variant in ALL_UNLOCK_ABILITIES:
		GameState.unlock_ability(str(abil))
	_show_toast("DEV_CHEAT_ABILITIES")
	AudioManager.play_sfx("orb_collect")


func _on_cheat_refill() -> void:
	GameState.heal_player(GameState.player_max_hp)
	GameState.add_resource(GameState.player_max_resource)
	_show_toast("DEV_CHEAT_REFILL")
	AudioManager.play_sfx("shrine_rest")


func _on_cheat_arm_teleport() -> void:
	_teleport_click_armed = true
	_show_toast("DEV_CHEAT_TELEPORT")
	AudioManager.play_sfx("ui_click")


func _teleport_player_to_world(world_pos: Vector2) -> void:
	var player: Node2D = _get_player()
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("teleport_to"):
		player.call("teleport_to", world_pos)
	else:
		player.global_position = world_pos
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
	AudioManager.play_sfx("dash")


func _show_toast(key: String) -> void:
	_toast_label.text = tr(key)
	_toast_panel.visible = true
	_toast_timer = 2.2


func _ensure_free_cam() -> void:
	var cam: RoomCamera = _get_camera()
	if cam == null:
		return
	if not _free_cam_active:
		_free_cam_active = true
		_free_cam_pos = cam.global_position
	_push_free_cam()


func _push_free_cam() -> void:
	var cam: RoomCamera = _get_camera()
	if cam != null:
		cam.set_free_cam(true, _free_cam_pos, _free_cam_zoom)


func _adjust_zoom(delta_zoom: float) -> void:
	_ensure_free_cam()
	_free_cam_zoom = clampf(_free_cam_zoom + delta_zoom, 0.5, 1.5)
	_push_free_cam()


func _get_grid_snap() -> int:
	return int(GRID_SNAP_STEPS[_grid_snap_index])


func _snap_point(world_pos: Vector2) -> Vector2:
	var snap: int = _get_grid_snap()
	if snap <= 0:
		return world_pos
	var s: float = float(snap)
	return Vector2(round(world_pos.x / s) * s, round(world_pos.y / s) * s)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _is_point_over_ui(screen_pos: Vector2) -> bool:
	if _top_bar_panel.visible and _top_bar_panel.get_global_rect().has_point(screen_pos):
		return true
	if _side_palette_panel.visible and _side_palette_panel.get_global_rect().has_point(screen_pos):
		return true
	if _bottom_bar_panel.visible and _bottom_bar_panel.get_global_rect().has_point(screen_pos):
		return true
	return false


func _is_typing_in_ui() -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


func _is_resizable_kind(kind: String) -> bool:
	return kind == "block" or kind == "deep_sand" or kind == "wind" or kind == "crumbling"


func _get_palette_for_tab(tab_id: int) -> Array:
	if tab_id == TAB_BLOCKS:
		return BLOCK_PALETTE
	if tab_id == TAB_ENEMIES:
		return ENEMY_PALETTE
	if tab_id == TAB_PROPS:
		return PROP_PALETTE
	return []


func _get_selected_palette_entry() -> Dictionary:
	for group: Array in [BLOCK_PALETTE, ENEMY_PALETTE, PROP_PALETTE]:
		for entry_var: Variant in group:
			var entry: Dictionary = entry_var as Dictionary
			if str(entry["id"]) == _selected_palette_id:
				return entry
	return {}


func _resolve_scene_path(kind: String, style: String) -> String:
	for group: Array in [BLOCK_PALETTE, ENEMY_PALETTE, PROP_PALETTE]:
		for entry_var: Variant in group:
			var entry: Dictionary = entry_var as Dictionary
			if str(entry["style"]) == style and str(entry["kind"]) == kind:
				return str(entry["scene"])
	if kind == "block":
		return "res://scenes/world/playable_block.tscn"
	if kind == "deep_sand":
		return "res://scenes/world/deep_sand_zone.tscn"
	if kind == "wind":
		return "res://scenes/world/wind_zone.tscn"
	if kind == "crumbling":
		return "res://scenes/world/crumbling_ledge.tscn"
	return ""


func _get_node_item_dict(node: Node2D) -> Dictionary:
	if node != null and node.has_meta("dev_item"):
		var raw: Variant = node.get_meta("dev_item")
		if raw is Dictionary:
			return raw as Dictionary
	return {}


func _get_room_save_path(room_id: String) -> String:
	return "%s/%s.json" % [CUSTOM_LEVELS_PREFIX, room_id]


func _get_room_manager() -> Node:
	return get_tree().get_first_node_in_group("room_manager")


func _get_current_room() -> RoomBase:
	var rm: Node = _get_room_manager()
	if rm != null and rm.has_method("get_current_room"):
		return rm.call("get_current_room") as RoomBase
	return null


func _get_player() -> Node2D:
	var rm: Node = _get_room_manager()
	if rm != null and rm.has_method("get_player"):
		return rm.call("get_player") as Node2D
	return null


func _get_camera() -> RoomCamera:
	var rm: Node = _get_room_manager()
	if rm != null and rm.has_method("get_camera"):
		return rm.call("get_camera") as RoomCamera
	return null


func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()


func _on_room_loaded(_room_id: String, _area_id: String, _title_key: String) -> void:
	_selected_node = null
	if _god_mode_enabled:
		var player: Node2D = _get_player()
		if player != null and player.has_method("set_god_mode"):
			player.call("set_god_mode", true)
	if _is_open and _free_cam_active:
		var cam: RoomCamera = _get_camera()
		if cam != null:
			_free_cam_pos = cam.global_position
			_push_free_cam()
