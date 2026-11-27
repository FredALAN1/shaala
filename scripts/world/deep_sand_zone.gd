@tool
class_name DeepSandZone
extends Area2D
## Deep desert sand pit / drift that slows Farid's stride and kicks up soft ochre dust.
## Canonical physics contract:
##   collision_layer = 0
##   collision_mask  = 4 (Layer 3: player)

const PLAYER_MASK: int = 4
const DEEP_SAND_JUMP_FACTOR: float = 0.90

@export var zone_size: Vector2 = Vector2(280.0, 44.0):
	set(value):
		zone_size = Vector2(maxf(32.0, value.x), maxf(16.0, value.y))
		if is_node_ready():
			_apply_geometry()
			queue_redraw()

@export_range(0.25, 0.95, 0.05) var slow_factor: float = 0.60:
	set(value):
		slow_factor = clampf(value, 0.25, 0.95)

var _time: float = 0.0
var _active_bodies: Array[Node] = []

@onready var _collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_MASK
	monitoring = true
	monitorable = false
	if not is_in_group("deep_sand_zones"):
		add_to_group("deep_sand_zones")
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
	for body: Node in _active_bodies:
		if is_instance_valid(body) and body.has_method("exit_surface"):
			body.call("exit_surface", "deep_sand")
	_active_bodies.clear()


func configure(size: Vector2, slow: float = 0.60) -> void:
	zone_size = Vector2(maxf(32.0, size.x), maxf(16.0, size.y))
	slow_factor = clampf(slow, 0.25, 0.95)
	_apply_geometry()
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


func _on_body_entered(body: Node) -> void:
	if body == null or not body.has_method("enter_surface"):
		return
	if body in _active_bodies:
		return
	_active_bodies.append(body)
	body.call("enter_surface", "deep_sand", slow_factor, DEEP_SAND_JUMP_FACTOR)


func _on_body_exited(body: Node) -> void:
	if body == null:
		return
	if body in _active_bodies:
		_active_bodies.erase(body)
		if is_instance_valid(body) and body.has_method("exit_surface"):
			body.call("exit_surface", "deep_sand")


func _draw() -> void:
	var half: Vector2 = zone_size * 0.5
	var left: float = -half.x
	var right: float = half.x
	var top: float = -half.y
	var bottom: float = half.y
	var w: float = zone_size.x
	var h: float = zone_size.y

	# Soft translucent base ochre sand bed blending cleanly onto underlying ground.
	var base_bed: PackedVector2Array = PackedVector2Array([
		Vector2(left + 10.0, top + 6.0),
		Vector2(right - 10.0, top + 6.0),
		Vector2(right + 8.0, bottom),
		Vector2(left - 8.0, bottom),
	])
	draw_colored_polygon(base_bed, ShaalaPalette.with_alpha(ShaalaPalette.MUD_BRICK_OCHRE, 0.78))

	# Overlapping sculpted convex sand mounds so the drift looks plush and loose.
	var mound_count: int = clampi(int(w / 62.0), 3, 14)
	var step: float = w / float(mound_count)
	for i: int in range(mound_count):
		var mx0: float = left + float(i) * step - 6.0
		var mx1: float = mx0 + step + 12.0
		var mid_x: float = (mx0 + mx1) * 0.5
		var crest_y: float = top + 2.0 + sin(float(i) * 1.6 + 0.5) * 3.2
		var mound: PackedVector2Array = PackedVector2Array([
			Vector2(mx0, bottom),
			Vector2(lerpf(mx0, mid_x, 0.45), crest_y + 3.0),
			Vector2(mid_x, crest_y),
			Vector2(lerpf(mid_x, mx1, 0.55), crest_y + 3.0),
			Vector2(mx1, bottom),
		])
		var col: Color = ShaalaPalette.MUD_BRICK_OCHRE.lerp(ShaalaPalette.WARM_SAND_LIGHT, 0.25 if i % 2 == 0 else 0.08)
		draw_colored_polygon(mound, ShaalaPalette.with_alpha(col, 0.85))
		draw_line(
			Vector2(lerpf(mx0, mid_x, 0.35), crest_y + 3.5),
			Vector2(lerpf(mid_x, mx1, 0.65), crest_y + 3.5),
			ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, 0.80),
			2.0,
			true
		)

	# Wind-carved diagonal ripple ridges across the sand mass.
	var ripple_rows: int = clampi(int(h / 14.0), 2, 4)
	for r: int in range(ripple_rows):
		var ry: float = lerpf(top + 10.0, bottom - 6.0, float(r) / float(maxi(1, ripple_rows - 1)))
		var pts: PackedVector2Array = PackedVector2Array()
		var segs: int = clampi(int(w / 28.0), 4, 24)
		for s: int in range(segs + 1):
			var t: float = float(s) / float(segs)
			var rx: float = lerpf(left + 6.0, right - 6.0, t)
			var wave: float = sin(t * TAU * 2.5 + float(r) * 2.1 + _time * 0.9) * 2.0
			pts.append(Vector2(rx, clampf(ry + wave, top + 4.0, bottom - 2.0)))
		var ripple_col: Color = ShaalaPalette.with_alpha(ShaalaPalette.DESERT_RED, 0.38) if r % 2 == 1 else ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, 0.48)
		draw_polyline(pts, ripple_col, 1.8, true)

	# Animated drifting fine sand motes skimming across the top surface.
	var mote_count: int = clampi(int(w / 26.0), 6, 22)
	for m: int in range(mote_count):
		var fm: float = float(m)
		var cycle: float = fmod(fm / float(mote_count) + _time * (0.14 + fmod(fm * 0.037, 0.08)), 1.0)
		var mx: float = lerpf(left, right, cycle)
		var my: float = top + 4.0 - sin(cycle * PI) * (7.0 + fmod(fm * 3.1, 8.0)) + cos(_time * 2.6 + fm) * 2.0
		var alpha: float = sin(cycle * PI) * 0.65
		var rad: float = 1.4 + fmod(fm * 0.6, 1.5)
		draw_circle(Vector2(mx, my), rad, ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, alpha))

	# Extra warm dust kick-up swirls when Farid is wading inside.
	for body: Node in _active_bodies:
		if not is_instance_valid(body) or not (body is Node2D):
			continue
		var local_p: Vector2 = to_local((body as Node2D).global_position)
		for k: int in range(4):
			var fk: float = float(k)
			var phase: float = fmod(_time * 1.9 + fk * 0.25, 1.0)
			var dx: float = sin(_time * 5.0 + fk * 2.3) * 16.0
			var dy: float = lerpf(4.0, -24.0, phase)
			var ka: float = sin(phase * PI) * 0.6
			draw_circle(Vector2(clampf(local_p.x + dx, left, right), clampf(top + 10.0 + dy, top - 24.0, bottom)), 2.5 + phase * 2.5, ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, ka))
