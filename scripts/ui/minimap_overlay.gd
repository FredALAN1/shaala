class_name MinimapOverlay
extends Control
## Connected metroidvania minimap reading res://data/rooms.json and GameState.explored_rooms.
## Highlights Farid's current room in pale gold and marks Orb Shrines and Guardian Boss arenas.

signal closed

const ROOMS_JSON_PATH: String = "res://data/rooms.json"

const COLOR_PALE_GOLD: Color = Color("#F6E299")
const COLOR_DESERT_RED: Color = Color("#A84432")
const COLOR_MUD_BRICK: Color = Color("#C68B59")
const COLOR_GLASS_TEAL: Color = Color("#4F6D7A")
const COLOR_NIGHT_INDIGO: Color = Color("#161B33")
const COLOR_SUNSET_ORANGE: Color = Color("#E07A3C")
const COLOR_WARM_SAND: Color = Color("#E8C49A")

@onready var title_label: Label = $CenterContainer/MapPanel/VBox/HeaderRow/MapTitleLabel
@onready var explored_label: Label = $CenterContainer/MapPanel/VBox/HeaderRow/ExploredLabel
@onready var close_button: Button = $CenterContainer/MapPanel/VBox/HeaderRow/CloseButton
@onready var map_canvas: Control = $CenterContainer/MapPanel/VBox/MapCanvasFrame/MapCanvas
@onready var legend_current_label: Label = $CenterContainer/MapPanel/VBox/LegendRow/CurrentItem/Label
@onready var legend_shrine_label: Label = $CenterContainer/MapPanel/VBox/LegendRow/ShrineItem/Label
@onready var legend_boss_label: Label = $CenterContainer/MapPanel/VBox/LegendRow/BossItem/Label
@onready var legend_explored_label: Label = $CenterContainer/MapPanel/VBox/LegendRow/ExploredItem/Label

var _rooms_by_id: Dictionary = {}
var _elapsed: float = 0.0


func _ready() -> void:
	visible = false
	map_canvas.set_meta("keep_ltr", true)
	map_canvas.draw.connect(_on_map_canvas_draw)
	close_button.pressed.connect(close_map)
	_load_rooms_metadata()
	refresh_texts()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	map_canvas.queue_redraw()


func open_map() -> void:
	if _rooms_by_id.is_empty():
		_load_rooms_metadata()
	visible = true
	refresh_map()
	AudioManager.play_sfx("ui_click")
	close_button.grab_focus()


func close_map() -> void:
	visible = false
	AudioManager.play_sfx("ui_hover")
	closed.emit()


func refresh_map() -> void:
	refresh_texts()
	map_canvas.queue_redraw()


func refresh_texts() -> void:
	title_label.text = tr("UI_MAP_TITLE")
	close_button.text = tr("UI_CLOSE")
	legend_current_label.text = tr("UI_MAP_LEGEND_CURRENT")
	legend_shrine_label.text = tr("UI_MAP_LEGEND_SHRINE")
	legend_boss_label.text = tr("UI_MAP_LEGEND_BOSS")
	legend_explored_label.text = tr("UI_MAP_LEGEND_EXPLORED")

	var total_rooms: int = maxi(1, _rooms_by_id.size())
	var explored_count: int = 0
	for room_id: String in _rooms_by_id.keys():
		if room_id in GameState.explored_rooms:
			explored_count += 1
	var pct: int = int(round((float(explored_count) / float(total_rooms)) * 100.0))
	explored_label.text = ArabicFontSetup.format_bidi_pair(
		tr("UI_EXPLORED"),
		"%d%% (%d/%d)" % [pct, explored_count, total_rooms]
	)
	map_canvas.queue_redraw()


func _load_rooms_metadata() -> void:
	_rooms_by_id.clear()
	if not FileAccess.file_exists(ROOMS_JSON_PATH):
		return
	var raw_text: String = FileAccess.get_file_as_string(ROOMS_JSON_PATH)
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		var root_dict := parsed as Dictionary
		if root_dict.has("rooms"):
			var rooms_val: Variant = root_dict["rooms"]
			if rooms_val is Array:
				for entry: Variant in rooms_val:
					if entry is Dictionary:
						var d := entry as Dictionary
						var rid: String = str(d.get("id", d.get("room_id", "")))
						if not rid.is_empty():
							_rooms_by_id[rid] = d
			elif rooms_val is Dictionary:
				for rid_key: Variant in (rooms_val as Dictionary).keys():
					var val: Variant = (rooms_val as Dictionary)[rid_key]
					if val is Dictionary:
						_rooms_by_id[str(rid_key)] = val
		else:
			for rid_key: Variant in root_dict.keys():
				var val: Variant = root_dict[rid_key]
				if val is Dictionary:
					_rooms_by_id[str(rid_key)] = val
	elif parsed is Array:
		for entry: Variant in (parsed as Array):
			if entry is Dictionary:
				var d := entry as Dictionary
				var rid: String = str(d.get("id", d.get("room_id", "")))
				if not rid.is_empty():
					_rooms_by_id[rid] = d


func _get_room_map_rect(room_data: Dictionary) -> Rect2:
	var pos_arr: Variant = room_data.get("map_pos", [0.0, 0.0])
	var size_arr: Variant = room_data.get("map_size", [1.0, 1.0])
	var px: float = 0.0
	var py: float = 0.0
	var sw: float = 1.0
	var sh: float = 1.0
	if pos_arr is Array and (pos_arr as Array).size() >= 2:
		px = float((pos_arr as Array)[0])
		py = float((pos_arr as Array)[1])
	if size_arr is Array and (size_arr as Array).size() >= 2:
		sw = maxf(0.5, float((size_arr as Array)[0]))
		sh = maxf(0.5, float((size_arr as Array)[1]))
	return Rect2(px, py, sw, sh)


func _on_map_canvas_draw() -> void:
	var canvas_size: Vector2 = map_canvas.size
	if canvas_size.x <= 4.0 or canvas_size.y <= 4.0:
		return

	# Subtle parchment-indigo architectural grid
	map_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.0509804, 0.0627451, 0.129412, 0.85))
	var grid_step: float = 48.0
	var grid_col: Color = Color(COLOR_MUD_BRICK, 0.08)
	var gx: float = grid_step
	while gx < canvas_size.x:
		map_canvas.draw_line(Vector2(gx, 0.0), Vector2(gx, canvas_size.y), grid_col, 1.0)
		gx += grid_step
	var gy: float = grid_step
	while gy < canvas_size.y:
		map_canvas.draw_line(Vector2(0.0, gy), Vector2(canvas_size.x, gy), grid_col, 1.0)
		gy += grid_step

	if _rooms_by_id.is_empty():
		return

	# Compute logical bounding box of all defined rooms
	var min_pt: Vector2 = Vector2(INF, INF)
	var max_pt: Vector2 = Vector2(-INF, -INF)
	var raw_rects: Dictionary = {}
	for rid: String in _rooms_by_id.keys():
		var r: Rect2 = _get_room_map_rect(_rooms_by_id[rid] as Dictionary)
		raw_rects[rid] = r
		min_pt.x = minf(min_pt.x, r.position.x)
		min_pt.y = minf(min_pt.y, r.position.y)
		max_pt.x = maxf(max_pt.x, r.end.x)
		max_pt.y = maxf(max_pt.y, r.end.y)

	var span: Vector2 = (max_pt - min_pt).max(Vector2(1.0, 1.0))
	var margin: Vector2 = Vector2(90.0, 80.0)
	var usable: Vector2 = (canvas_size - margin * 2.0).max(Vector2(100.0, 100.0))
	var scale_factor: float = minf(usable.x / span.x, usable.y / span.y)
	scale_factor = clampf(scale_factor, 1.0, 220.0)

	var content_size: Vector2 = span * scale_factor
	var origin: Vector2 = (canvas_size - content_size) * 0.5 - min_pt * scale_factor

	var screen_rects: Dictionary = {}
	for rid: String in raw_rects.keys():
		var r: Rect2 = raw_rects[rid] as Rect2
		var sr := Rect2(origin + r.position * scale_factor, r.size * scale_factor)
		# Keep clean visual padding between connected rooms
		sr = sr.grow(-minf(8.0, minf(sr.size.x, sr.size.y) * 0.1))
		screen_rects[rid] = sr

	# Pass 1: Draw corridors between explored neighboring rooms
	var drawn_pairs: Dictionary = {}
	for rid: String in _rooms_by_id.keys():
		if not (rid in GameState.explored_rooms):
			continue
		var rdata: Dictionary = _rooms_by_id[rid] as Dictionary
		var neighbors: Variant = rdata.get("neighbors", [])
		if not (neighbors is Array):
			continue
		var center_a: Vector2 = (screen_rects[rid] as Rect2).get_center()
		for n_var: Variant in (neighbors as Array):
			var nid: String = str(n_var)
			if not screen_rects.has(nid):
				continue
			var pair_key: String = "%s|%s" % [rid, nid] if rid < nid else "%s|%s" % [nid, rid]
			if drawn_pairs.has(pair_key):
				continue
			drawn_pairs[pair_key] = true
			var center_b: Vector2 = (screen_rects[nid] as Rect2).get_center()
			var both_explored: bool = nid in GameState.explored_rooms
			var line_col: Color = Color(COLOR_PALE_GOLD, 0.72) if both_explored else Color(COLOR_MUD_BRICK, 0.25)
			map_canvas.draw_line(center_a, center_b, line_col, 4.0 if both_explored else 2.0, true)

	# Pass 2: Draw room rectangles and icons
	var font: Font = ArabicFontSetup.get_arabic_font()
	for rid: String in _rooms_by_id.keys():
		var explored: bool = rid in GameState.explored_rooms or rid == GameState.current_room_id
		if not explored:
			continue
		var rdata: Dictionary = _rooms_by_id[rid] as Dictionary
		var sr: Rect2 = screen_rects[rid] as Rect2
		var is_current: bool = rid == GameState.current_room_id
		var area_id: String = str(rdata.get("area_id", ""))
		var fill_col: Color = _color_for_area(area_id)

		map_canvas.draw_rect(sr, fill_col, true)
		var border_col: Color = COLOR_PALE_GOLD if is_current else Color(COLOR_WARM_SAND, 0.75)
		map_canvas.draw_rect(sr, border_col, false, 4.0 if is_current else 2.0)

		# Shrine marker (pale gold diamond)
		if bool(rdata.get("has_shrine", false)):
			var sp: Vector2 = Vector2(sr.position.x + 20.0, sr.position.y + 20.0)
			var diamond := PackedVector2Array([
				sp + Vector2(0.0, -9.0),
				sp + Vector2(9.0, 0.0),
				sp + Vector2(0.0, 9.0),
				sp + Vector2(-9.0, 0.0),
			])
			map_canvas.draw_colored_polygon(diamond, COLOR_PALE_GOLD)

		# Boss marker (desert red / gold crown diamond)
		if bool(rdata.get("has_boss", false)):
			var bp: Vector2 = Vector2(sr.end.x - 20.0, sr.position.y + 20.0)
			var boss_col: Color = COLOR_SUNSET_ORANGE if not GameState.is_boss_defeated("boss_spire_warden") else Color(COLOR_MUD_BRICK, 0.65)
			map_canvas.draw_circle(bp, 9.0, boss_col)
			map_canvas.draw_arc(bp, 11.0, 0.0, TAU, 16, COLOR_PALE_GOLD, 2.0, true)

		# Current player pulse dot
		if is_current:
			var pulse_r: float = 8.0 + 3.0 * sin(_elapsed * 4.0)
			map_canvas.draw_circle(sr.get_center(), pulse_r + 4.0, Color(COLOR_PALE_GOLD, 0.25))
			map_canvas.draw_circle(sr.get_center(), 6.5, COLOR_PALE_GOLD)

		# Room area title caption inside wide enough cells
		var title_key: String = str(rdata.get("title_key", ""))
		if not title_key.is_empty() and sr.size.x >= 96.0:
			var caption: String = tr(title_key)
			var text_pos: Vector2 = Vector2(sr.position.x + 8.0, sr.end.y - 10.0)
			map_canvas.draw_string(
				font,
				text_pos,
				caption,
				HORIZONTAL_ALIGNMENT_CENTER,
				sr.size.x - 16.0,
				15,
				COLOR_WARM_SAND
			)


func _color_for_area(area_id: String) -> Color:
	match area_id:
		"desert_camp":
			return Color(COLOR_DESERT_RED, 0.55)
		"empty_highway":
			return Color(COLOR_MUD_BRICK, 0.48)
		"empty_riyadh":
			return Color(COLOR_GLASS_TEAL, 0.55)
		_:
			return Color(COLOR_NIGHT_INDIGO, 0.75)
