@tool
class_name WindZone
extends Area2D
## Directional desert gust / updraft zone with flowing painterly sand-wind ribbons.
## Canonical physics contract:
##   collision_layer = 0
##   collision_mask  = 4 (Layer 3: player)

const PLAYER_MASK: int = 4

@export var zone_size: Vector2 = Vector2(360.0, 220.0):
	set(value):
		zone_size = Vector2(maxf(48.0, value.x), maxf(48.0, value.y))
		if is_node_ready():
			_apply_geometry()
			queue_redraw()

@export var wind_force: Vector2 = Vector2(-240.0, 0.0):
	set(value):
		wind_force = value
		if is_node_ready():
			_sync_active_bodies_force()
			queue_redraw()

var _time: float = 0.0
var _active_bodies: Array[Node] = []

@onready var _collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_MASK
	monitoring = true
	monitorable = false
	if not is_in_group("wind_zones"):
		add_to_group("wind_zones")
	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
	_apply_geometry()
	queue_redraw()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var wid: int = get_instance_id()
	for body: Node in _active_bodies:
		if is_instance_valid(body) and body.has_method("remove_wind_force"):
			body.call("remove_wind_force", wid)
	_active_bodies.clear()


func configure(size: Vector2, force: Vector2) -> void:
	zone_size = Vector2(maxf(48.0, size.x), maxf(48.0, size.y))
	wind_force = force
	_apply_geometry()
	_sync_active_bodies_force()
	queue_redraw()


func get_world_rect() -> Rect2:
	return Rect2(global_position - zone_size * 0.5, zone_size)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _apply_geometry() -> void:
	collision_layer = 0
	collision_mask = PLAYER_MASK
	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		return
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = zone_size
	_collision_shape.shape = rect_shape
	_collision_shape.position = Vector2.ZERO


func _sync_active_bodies_force() -> void:
	if Engine.is_editor_hint():
		return
	var wid: int = get_instance_id()
	for body: Node in _active_bodies:
		if is_instance_valid(body) and body.has_method("add_wind_force"):
			body.call("add_wind_force", wid, wind_force)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.has_method("add_wind_force"):
		return
	if body in _active_bodies:
		return
	_active_bodies.append(body)
	body.call("add_wind_force", get_instance_id(), wind_force)


func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	if body in _active_bodies:
		_active_bodies.erase(body)
		if is_instance_valid(body) and body.has_method("remove_wind_force"):
			body.call("remove_wind_force", get_instance_id())


func _draw() -> void:
	var half: Vector2 = zone_size * 0.5
	var rect: Rect2 = Rect2(-half, zone_size)

	# Very soft atmospheric sand-haze tint defining the gust corridor without harsh box borders.
	var is_updraft: bool = absf(wind_force.y) > absf(wind_force.x)
	var veil_tint: Color = ShaalaPalette.PALE_GOLD_ORB if is_updraft else ShaalaPalette.WARM_SAND_LIGHT
	draw_rect(rect, ShaalaPalette.with_alpha(veil_tint, 0.045), true)

	var force_len: float = wind_force.length()
	var dir: Vector2 = wind_force.normalized() if force_len > 1.0 else Vector2(-1.0, 0.0)
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	# Project zone extents onto flow direction & perpendicular lane axis.
	var span_along: float = absf(dir.x) * zone_size.x + absf(dir.y) * zone_size.y
	var span_across: float = absf(perp.x) * zone_size.x + absf(perp.y) * zone_size.y
	var speed_px: float = clampf(force_len * 0.95, 95.0, 420.0)

	# Flowing painterly sand-wind ribbons streaming along dir.
	var ribbon_count: int = clampi(int(span_across / 32.0), 4, 14)
	var ribbon_len: float = clampf(span_along * 0.34, 48.0, 145.0)
	for i: int in range(ribbon_count):
		var fi: float = float(i)
		var lane_t: float = (fi + 0.5) / float(ribbon_count) - 0.5
		var lane_offset: float = lane_t * (span_across * 0.86)
		var travel_span: float = span_along + ribbon_len
		var phase: float = fmod((_time * speed_px + fi * 97.3) / maxf(travel_span, 1.0), 1.0)
		var head_along: float = -span_along * 0.5 - ribbon_len * 0.25 + phase * travel_span

		var pts: PackedVector2Array = PackedVector2Array()
		var segs: int = 8
		for s: int in range(segs + 1):
			var st: float = float(s) / float(segs)
			var along_pos: float = head_along - st * ribbon_len
			var wave: float = sin(st * PI * 2.0 + _time * 4.2 + fi * 1.7) * 6.5
			var pt: Vector2 = dir * along_pos + perp * (lane_offset + wave)
			pt.x = clampf(pt.x, -half.x + 2.0, half.x - 2.0)
			pt.y = clampf(pt.y, -half.y + 2.0, half.y - 2.0)
			pts.append(pt)

		var fade: float = sin(phase * PI)
		var rib_col: Color = ShaalaPalette.PALE_GOLD_ORB if (i % 3 == 0) else ShaalaPalette.WARM_SAND_LIGHT
		var width: float = 2.4 if (i % 3 == 0) else 1.6
		draw_polyline(pts, ShaalaPalette.with_alpha(rib_col, fade * 0.48), width, true)

	# Fast glowing sand-dust streaks & directional specks.
	var speck_count: int = clampi(int((zone_size.x * zone_size.y) / 4800.0), 8, 28)
	for k: int in range(speck_count):
		var fk: float = float(k)
		var lane_r: float = fmod(fk * 0.3719, 1.0) - 0.5
		var p: float = fmod((_time * speed_px * 1.25 + fk * 53.7) / maxf(span_along, 1.0), 1.0)
		var along_p: float = (p - 0.5) * span_along
		var across_p: float = lane_r * span_across * 0.88 + sin(_time * 3.5 + fk) * 4.0
		var pos: Vector2 = dir * along_p + perp * across_p
		if not rect.has_point(pos):
			continue
		var alpha: float = sin(p * PI) * 0.72
		var tail: Vector2 = pos - dir * clampf(force_len * 0.06, 8.0, 22.0)
		tail.x = clampf(tail.x, -half.x, half.x)
		tail.y = clampf(tail.y, -half.y, half.y)
		var scol: Color = ShaalaPalette.PALE_GOLD_ORB if k % 2 == 0 else ShaalaPalette.SUNSET_ORANGE
		draw_line(tail, pos, ShaalaPalette.with_alpha(scol, alpha), 1.5, true)
		draw_circle(pos, 1.8, ShaalaPalette.with_alpha(ShaalaPalette.ORB_CORE_WHITE_GOLD, alpha * 0.9))
