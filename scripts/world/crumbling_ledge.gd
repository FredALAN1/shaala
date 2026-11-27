@tool
class_name CrumblingLedge
extends StaticBody2D
## Fragile fractured sandstone/concrete ledge that shakes when Farid lands on it,
## breaks away with falling dust pebbles, and reforms gently in pale-gold shimmer.
## Canonical physics contract:
##   Root StaticBody2D: collision_layer = 1 (world), collision_mask = 0
##   TopSensor Area2D:  collision_layer = 0, collision_mask = 4 (player)

enum LedgeState {
	INTACT,
	SHAKING,
	BROKEN,
	REFORMING,
}

const WORLD_LAYER: int = 1
const PLAYER_MASK: int = 4
const REFORM_DURATION: float = 0.45

@export var block_size: Vector2 = Vector2(160.0, 36.0):
	set(value):
		block_size = Vector2(maxf(48.0, value.x), maxf(20.0, value.y))
		if is_node_ready():
			_apply_geometry()
			queue_redraw()

@export_range(0.2, 2.5, 0.05) var collapse_delay: float = 0.65
@export_range(1.0, 10.0, 0.25) var respawn_delay: float = 3.5

var _state: int = LedgeState.INTACT
var _state_timer: float = 0.0
var _time: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _debris: Array[Dictionary] = []

@onready var _collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var _top_sensor: Area2D = get_node_or_null("TopSensor") as Area2D
@onready var _sensor_shape: CollisionShape2D = get_node_or_null("TopSensor/SensorShape") as CollisionShape2D


func _ready() -> void:
	collision_layer = WORLD_LAYER
	collision_mask = 0
	if not is_in_group("crumbling_ledges"):
		add_to_group("crumbling_ledges")
	_apply_geometry()
	if not Engine.is_editor_hint() and _top_sensor != null:
		if not _top_sensor.body_entered.is_connected(_on_top_sensor_body_entered):
			_top_sensor.body_entered.connect(_on_top_sensor_body_entered)
	queue_redraw()


func configure(size: Vector2) -> void:
	block_size = Vector2(maxf(48.0, size.x), maxf(20.0, size.y))
	_apply_geometry()
	queue_redraw()


func get_world_rect() -> Rect2:
	return Rect2(global_position - block_size * 0.5, block_size)


func _apply_geometry() -> void:
	collision_layer = WORLD_LAYER
	collision_mask = 0
	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape != null:
		var body_rect: RectangleShape2D = RectangleShape2D.new()
		body_rect.size = block_size
		_collision_shape.shape = body_rect
		_collision_shape.position = Vector2.ZERO

	if _top_sensor == null:
		_top_sensor = get_node_or_null("TopSensor") as Area2D
	if _top_sensor != null:
		_top_sensor.collision_layer = 0
		_top_sensor.collision_mask = PLAYER_MASK
		_top_sensor.monitorable = false

	if _sensor_shape == null:
		_sensor_shape = get_node_or_null("TopSensor/SensorShape") as CollisionShape2D
	if _sensor_shape != null:
		var sensor_rect: RectangleShape2D = RectangleShape2D.new()
		sensor_rect.size = Vector2(maxf(20.0, block_size.x - 8.0), 14.0)
		_sensor_shape.shape = sensor_rect
		_sensor_shape.position = Vector2(0.0, -block_size.y * 0.5 - 5.0)


func _process(delta: float) -> void:
	_time += delta
	if Engine.is_editor_hint():
		return

	_update_debris(delta)

	match _state:
		LedgeState.INTACT:
			_shake_offset = Vector2.ZERO
		LedgeState.SHAKING:
			_state_timer -= delta
			var ratio: float = 1.0 - clampf(_state_timer / maxf(collapse_delay, 0.01), 0.0, 1.0)
			var amp: float = lerpf(1.6, 5.2, ratio)
			_shake_offset = Vector2(sin(_time * 58.0) * amp, cos(_time * 43.0) * amp * 0.45)
			if fmod(_time * 18.0, 1.0) < delta * 18.0:
				_spawn_pebble()
			if _state_timer <= 0.0:
				_break_apart()
		LedgeState.BROKEN:
			_shake_offset = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = LedgeState.REFORMING
				_state_timer = REFORM_DURATION
		LedgeState.REFORMING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_finish_reform()

	if _state != LedgeState.INTACT or not _debris.is_empty():
		queue_redraw()


func _on_top_sensor_body_entered(body: Node) -> void:
	if _state != LedgeState.INTACT:
		return
	if body == null or not body.is_in_group("player"):
		return
	# Only trigger when player approaches from above/onto the ledge surface.
	if body is Node2D:
		var local_y: float = to_local((body as Node2D).global_position).y
		if local_y > 6.0:
			return
	_start_shaking()


func _start_shaking() -> void:
	_state = LedgeState.SHAKING
	_state_timer = collapse_delay
	for _i: int in range(4):
		_spawn_pebble()
	_play_sfx_safe("stone_crumble")
	queue_redraw()


func _break_apart() -> void:
	_state = LedgeState.BROKEN
	_state_timer = respawn_delay
	_shake_offset = Vector2.ZERO
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	if _top_sensor != null:
		_top_sensor.set_deferred("monitoring", false)
	_spawn_collapse_chunks()
	_play_sfx_safe("stone_break")
	queue_redraw()


func _play_sfx_safe(sfx_id: String) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", sfx_id)


func _is_reduce_flash_enabled() -> bool:
	if Engine.is_editor_hint() or not is_inside_tree():
		return false
	var settings: Node = get_node_or_null("/root/SettingsManager")
	if settings != null and "reduce_flash" in settings:
		return bool(settings.get("reduce_flash"))
	return false


func _finish_reform() -> void:
	_state = LedgeState.INTACT
	_state_timer = 0.0
	_shake_offset = Vector2.ZERO
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", false)
	if _top_sensor != null:
		_top_sensor.set_deferred("monitoring", true)
	queue_redraw()


func _spawn_pebble() -> void:
	var half: Vector2 = block_size * 0.5
	var rx: float = randf_range(-half.x + 8.0, half.x - 8.0)
	_debris.append({
		"pos": Vector2(rx, half.y - 2.0),
		"vel": Vector2(randf_range(-28.0, 28.0), randf_range(24.0, 65.0)),
		"size": Vector2(randf_range(4.0, 8.0), randf_range(3.0, 6.0)),
		"rot": randf_range(-0.4, 0.4),
		"vrot": randf_range(-4.0, 4.0),
		"life": 0.75,
		"max_life": 0.75,
	})


func _spawn_collapse_chunks() -> void:
	var half: Vector2 = block_size * 0.5
	var chunks: int = clampi(int(block_size.x / 34.0), 4, 8)
	var cw: float = block_size.x / float(chunks)
	for i: int in range(chunks):
		var cx: float = -half.x + (float(i) + 0.5) * cw
		_debris.append({
			"pos": Vector2(cx, randf_range(-4.0, 4.0)),
			"vel": Vector2(randf_range(-55.0, 55.0), randf_range(20.0, 110.0)),
			"size": Vector2(maxf(12.0, cw * 0.78), maxf(10.0, block_size.y * 0.65)),
			"rot": randf_range(-0.2, 0.2),
			"vrot": randf_range(-5.5, 5.5),
			"life": 1.05,
			"max_life": 1.05,
		})


func _update_debris(delta: float) -> void:
	var idx: int = _debris.size() - 1
	while idx >= 0:
		var d: Dictionary = _debris[idx]
		var life: float = float(d["life"]) - delta
		if life <= 0.0:
			_debris.remove_at(idx)
		else:
			var vel: Vector2 = d["vel"] as Vector2
			vel.y += 640.0 * delta
			d["vel"] = vel
			d["pos"] = (d["pos"] as Vector2) + vel * delta
			d["rot"] = float(d["rot"]) + float(d["vrot"]) * delta
			d["life"] = life
		idx -= 1


func _draw() -> void:
	var half: Vector2 = block_size * 0.5
	var rect: Rect2 = Rect2(-half + _shake_offset, block_size)

	# Draw falling stone pebbles & collapse chunks behind/over the ledge.
	for d: Dictionary in _debris:
		var p: Vector2 = d["pos"] as Vector2
		var sz: Vector2 = d["size"] as Vector2
		var life_ratio: float = clampf(float(d["life"]) / maxf(float(d["max_life"]), 0.01), 0.0, 1.0)
		draw_set_transform(p, float(d["rot"]), Vector2.ONE)
		draw_rect(Rect2(-sz * 0.5, sz), ShaalaPalette.with_alpha(ShaalaPalette.SHADE_NAJDI_DARK, life_ratio * 0.9), true)
		draw_rect(Rect2(-sz * 0.5, Vector2(sz.x, 3.0)), ShaalaPalette.with_alpha(ShaalaPalette.WARM_SAND_LIGHT, life_ratio * 0.75), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _state == LedgeState.BROKEN:
		# Faint ghostly pale-gold outline marking where the ledge will reform.
		var pulse: float = 0.22 + 0.12 * sin(_time * 3.0)
		draw_rect(Rect2(-half, block_size), ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, pulse * 0.22), true)
		draw_rect(Rect2(-half, block_size), ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, pulse), false, 1.6)
		return

	var alpha: float = 1.0
	var shimmer: float = 0.0
	if _state == LedgeState.REFORMING:
		var t: float = 1.0 - clampf(_state_timer / REFORM_DURATION, 0.0, 1.0)
		alpha = t
		var reduce_flash: bool = _is_reduce_flash_enabled()
		shimmer = sin(t * PI) * (0.45 if reduce_flash else 0.9)

	# Fractured Najdi sandstone & weathered concrete body.
	var stone_base: Color = ShaalaPalette.SHADE_NAJDI_DARK.lerp(ShaalaPalette.MUD_BRICK_OCHRE, 0.45)
	var stone_shadow: Color = ShaalaPalette.DEEP_SHADOW.lerp(ShaalaPalette.SHADE_NAJDI_DARK, 0.5)
	draw_rect(rect, ShaalaPalette.with_alpha(stone_base, alpha), true)
	draw_rect(
		Rect2(rect.position.x, rect.end.y - rect.size.y * 0.36, rect.size.x, rect.size.y * 0.36),
		ShaalaPalette.with_alpha(stone_shadow, alpha * 0.72),
		true
	)

	# Visible jagged fault cracks across the ledge (glow amber when shaking).
	var crack_glow: float = 0.0
	if _state == LedgeState.SHAKING:
		crack_glow = 1.0 - clampf(_state_timer / maxf(collapse_delay, 0.01), 0.0, 1.0)
	var crack_col: Color = ShaalaPalette.DEEP_SHADOW.lerp(ShaalaPalette.PALE_GOLD_ORB, crack_glow * 0.85)
	var crack_w: float = lerpf(2.0, 3.2, crack_glow)
	var segs: int = clampi(int(block_size.x / 44.0), 2, 6)
	for i: int in range(1, segs):
		var fx: float = lerpf(rect.position.x + 12.0, rect.end.x - 12.0, float(i) / float(segs))
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(fx, rect.position.y + 3.0),
			Vector2(fx - 6.0 if i % 2 == 0 else fx + 6.0, rect.position.y + rect.size.y * 0.52),
			Vector2(fx + 3.0 if i % 2 == 0 else fx - 4.0, rect.end.y - 2.0),
		])
		draw_polyline(pts, ShaalaPalette.with_alpha(crack_col, alpha), crack_w, true)

	# Crisp sunlit sandstone walkable top lip.
	var lip_col: Color = ShaalaPalette.WARM_SAND_LIGHT.lerp(ShaalaPalette.PALE_GOLD_ORB, maxf(crack_glow, shimmer))
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 5.0), ShaalaPalette.with_alpha(lip_col, alpha), true)
	draw_rect(rect, ShaalaPalette.with_alpha(ShaalaPalette.DEEP_SHADOW, alpha * 0.8), false, 1.8)

	# Gentle pale-gold memory shimmer overlay while reforming.
	if shimmer > 0.01:
		draw_rect(rect, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, shimmer * 0.42), true)
		draw_rect(rect.grow(3.0 * shimmer), ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, shimmer * 0.7), false, 2.2)
