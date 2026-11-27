class_name FlameDagger
extends Hitbox
## Farid's Flame Dagger melee weapon: 3-hit directional slash combo (left/right/up/down-pogo)
## scaling mechanically and visually across 3 Resource tiers via GameState.get_dagger_tier().
## Extends Hitbox directly: collision_layer = 16 (layer 5: player_hitbox), collision_mask = 8 (layer 4: enemy).

signal slash_hit(hurtbox: Hurtbox, info: DamageInfo, slash_dir: Vector2)

const RESOURCE_GAIN_PER_HIT: float = 12.0
const HITSTOP_DURATION: float = 0.035

const TIER_DAMAGE: Array = [10, 15, 22]
const TIER_REACH: Array = [72.0, 96.0, 124.0]
const TIER_THICKNESS: Array = [52.0, 64.0, 78.0]

const COLOR_TIER_0: Color = Color(0.878, 0.478, 0.235, 1.0) # Sunset orange #E07A3C
const COLOR_TIER_1: Color = Color(0.945, 0.655, 0.310, 1.0) # Bright orange-gold
const COLOR_TIER_2: Color = Color(0.965, 0.886, 0.600, 1.0) # Blazing pale gold #F6E299
const COLOR_CORE: Color = Color(1.0, 0.969, 0.855, 1.0)
const COLOR_DESERT_RED: Color = Color(0.659, 0.267, 0.196, 1.0)

@onready var hitbox_shape: CollisionShape2D = $CollisionShape2D

var _slash_active: bool = false
var _slash_timer: float = 0.0
var _slash_duration: float = 0.15
var _visual_timer: float = 0.0
var _visual_duration: float = 0.19
var _slash_direction: Vector2 = Vector2.RIGHT
var _combo_step: int = 0
var _current_tier: int = 0
var _impact_sparks: Array[Dictionary] = []


func _ready() -> void:
	collision_layer = 16 # Layer 5: player_hitbox
	collision_mask = 8   # Layer 4: enemy hurtbox
	damage_type = "melee"
	parryable = false
	active = false
	super._ready()
	deactivate()
	if not hit_landed.is_connected(_on_hitbox_hit_landed):
		hit_landed.connect(_on_hitbox_hit_landed)


func _process(delta: float) -> void:
	var needs_redraw: bool = false

	if _slash_active:
		_slash_timer -= delta
		if _slash_timer <= 0.0:
			stop_slash()

	if _visual_timer > 0.0:
		_visual_timer = maxf(0.0, _visual_timer - delta)
		needs_redraw = true

	if not _impact_sparks.is_empty():
		var remaining: Array[Dictionary] = []
		for spark: Dictionary in _impact_sparks:
			var life: float = float(spark["life"]) - delta
			if life > 0.0:
				spark["life"] = life
				spark["pos"] = (spark["pos"] as Vector2) + (spark["vel"] as Vector2) * delta
				spark["vel"] = (spark["vel"] as Vector2) * (1.0 - 4.0 * delta)
				remaining.append(spark)
		_impact_sparks = remaining
		needs_redraw = true

	if needs_redraw:
		queue_redraw()


func start_slash(
	direction: Vector2,
	combo_step: int,
	caster: Node,
	active_duration: float = 0.11
) -> void:
	_slash_direction = direction.normalized()
	if _slash_direction == Vector2.ZERO:
		_slash_direction = Vector2.RIGHT
	_combo_step = clampi(combo_step, 0, 2)
	_current_tier = clampi(GameState.get_dagger_tier(), 0, 2)
	_slash_duration = active_duration
	_slash_timer = active_duration
	_visual_duration = active_duration + 0.08
	_visual_timer = _visual_duration
	_slash_active = true

	var reach: float = float(TIER_REACH[_current_tier])
	var thickness: float = float(TIER_THICKNESS[_current_tier])
	var dmg: int = int(TIER_DAMAGE[_current_tier])
	if _combo_step == 2:
		reach += 10.0
		thickness += 8.0

	_configure_hitbox(reach, thickness, dmg, caster)
	AudioManager.play_sfx("dagger_swing")
	queue_redraw()


func start_ground_pound_burst(caster: Node, active_duration: float = 0.14) -> void:
	_slash_direction = Vector2.DOWN
	_combo_step = 2
	_current_tier = clampi(GameState.get_dagger_tier(), 0, 2)
	_slash_duration = active_duration
	_slash_timer = active_duration
	_visual_duration = active_duration + 0.12
	_visual_timer = _visual_duration
	_slash_active = true

	if hitbox_shape != null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(150.0, 56.0)
		hitbox_shape.shape = rect
		hitbox_shape.position = Vector2(0.0, 22.0)
	source_node = caster
	damage = 26
	damage_type = "ground_pound"
	parryable = false
	knockback = Vector2(300.0, -240.0)
	activate(true)
	queue_redraw()


func stop_slash() -> void:
	_slash_active = false
	deactivate()


func get_tier_color(tier: int = -1) -> Color:
	var resolved: int = _current_tier if tier < 0 else clampi(tier, 0, 2)
	match resolved:
		0:
			return COLOR_TIER_0
		1:
			return COLOR_TIER_1
		_:
			return COLOR_TIER_2


func _configure_hitbox(reach: float, thickness: float, dmg: int, caster: Node) -> void:
	var rect := RectangleShape2D.new()
	var center_offset: Vector2 = Vector2.ZERO
	var kb: Vector2 = Vector2(220.0, -130.0)

	if absf(_slash_direction.x) >= absf(_slash_direction.y):
		var sign_x: float = 1.0 if _slash_direction.x >= 0.0 else -1.0
		rect.size = Vector2(reach, thickness)
		center_offset = Vector2(sign_x * (reach * 0.5 + 10.0), -2.0)
		var kb_x: float = 240.0 if _combo_step < 2 else 330.0
		kb = Vector2(sign_x * kb_x, -140.0)
	elif _slash_direction.y < 0.0:
		rect.size = Vector2(thickness + 14.0, reach)
		center_offset = Vector2(0.0, -(reach * 0.5 + 14.0))
		kb = Vector2(80.0, -280.0)
	else:
		rect.size = Vector2(thickness + 16.0, reach)
		center_offset = Vector2(0.0, reach * 0.5 + 12.0)
		kb = Vector2(90.0, 120.0)

	if hitbox_shape != null:
		hitbox_shape.shape = rect
		hitbox_shape.position = center_offset
	source_node = caster
	damage = dmg
	damage_type = "melee"
	parryable = false
	knockback = kb
	activate(true)


func _on_hitbox_hit_landed(hurtbox: Hurtbox, info: DamageInfo) -> void:
	GameState.add_resource(RESOURCE_GAIN_PER_HIT)
	EventBus.hitstop_requested.emit(HITSTOP_DURATION)
	EventBus.camera_shake_requested.emit(2.6 + float(_current_tier) * 1.1, 0.08)
	AudioManager.play_sfx("dagger_hit")
	_spawn_impact_sparks(to_local(hurtbox.global_position))
	slash_hit.emit(hurtbox, info, _slash_direction)


func _spawn_impact_sparks(local_hit_pos: Vector2) -> void:
	var spark_count: int = 6 + _current_tier * 3
	for i: int in range(spark_count):
		var angle: float = TAU * float(i) / float(spark_count) + randf_range(-0.25, 0.25)
		var spd: float = randf_range(120.0, 290.0)
		_impact_sparks.append({
			"pos": local_hit_pos,
			"vel": Vector2.from_angle(angle) * spd,
			"life": randf_range(0.12, 0.24),
			"max_life": 0.24,
			"radius": randf_range(2.2, 4.5 + float(_current_tier))
		})
	queue_redraw()


func _draw() -> void:
	if _visual_timer > 0.0:
		_draw_slash_arc()

	var tier_col: Color = get_tier_color()
	for spark: Dictionary in _impact_sparks:
		var alpha: float = clampf(float(spark["life"]) / float(spark["max_life"]), 0.0, 1.0)
		var col: Color = tier_col.lerp(COLOR_CORE, alpha * 0.6)
		col.a = alpha
		draw_circle(spark["pos"] as Vector2, float(spark["radius"]) * alpha, col)


func _draw_slash_arc() -> void:
	var progress: float = 1.0 - clampf(_visual_timer / maxf(_visual_duration, 0.001), 0.0, 1.0)
	var fade: float = clampf(1.0 - progress * progress, 0.0, 1.0)
	var reach: float = float(TIER_REACH[_current_tier]) + (10.0 if _combo_step == 2 else 0.0)
	var thickness: float = float(TIER_THICKNESS[_current_tier]) * 0.42
	var base_angle: float = _slash_direction.angle()

	var sweep_sign: float = -1.0 if _combo_step == 1 else 1.0
	var arc_span: float = lerpf(1.45, 1.95, float(_current_tier) * 0.5)
	if _combo_step == 2:
		arc_span += 0.35

	var start_angle: float = base_angle - sweep_sign * arc_span * 0.55
	var end_angle: float = base_angle + sweep_sign * arc_span * 0.45
	var segments: int = 14

	var halo_outer_pts := PackedVector2Array()
	var halo_inner_pts := PackedVector2Array()
	var outer_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	var core_outer := PackedVector2Array()
	var core_inner := PackedVector2Array()

	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		var ang: float = lerpf(start_angle, end_angle, t)
		var taper: float = sin(t * PI)
		var r_halo_out: float = reach * (0.94 + 0.14 * taper)
		var r_halo_in: float = clampf(r_halo_out - thickness * (0.55 + 0.85 * taper), 12.0, r_halo_out - 3.0)
		var r_outer: float = reach * (0.86 + 0.14 * taper)
		var r_inner: float = clampf(r_outer - thickness * (0.35 + 0.65 * taper), 14.0, r_outer - 2.5)
		var r_core_out: float = r_outer * 0.98
		var r_core_inner: float = clampf(r_core_out - thickness * (0.14 + 0.28 * taper), 16.0, r_core_out - 2.0)

		var unit: Vector2 = Vector2.from_angle(ang)
		halo_outer_pts.append(unit * r_halo_out)
		halo_inner_pts.append(unit * r_halo_in)
		outer_pts.append(unit * r_outer)
		inner_pts.append(unit * r_inner)
		core_outer.append(unit * r_core_out)
		core_inner.append(unit * r_core_inner)

	halo_inner_pts.reverse()
	var halo_poly := PackedVector2Array()
	halo_poly.append_array(halo_outer_pts)
	halo_poly.append_array(halo_inner_pts)

	inner_pts.reverse()
	var outer_poly := PackedVector2Array()
	outer_poly.append_array(outer_pts)
	outer_poly.append_array(inner_pts)

	core_inner.reverse()
	var core_poly := PackedVector2Array()
	core_poly.append_array(core_outer)
	core_poly.append_array(core_inner)

	var main_col: Color = get_tier_color()
	var rim_col: Color = COLOR_DESERT_RED if _current_tier == 0 else COLOR_TIER_0
	var halo_col: Color = COLOR_DESERT_RED.lerp(main_col, 0.45)
	halo_col.a = fade * 0.34
	rim_col.a = fade * 0.60
	main_col.a = fade * 0.88
	var core_col: Color = COLOR_CORE
	core_col.a = fade * (0.72 if SettingsManager.reduce_flash else 0.96)

	if halo_poly.size() >= 3:
		draw_colored_polygon(halo_poly, halo_col)
	if outer_poly.size() >= 3:
		draw_colored_polygon(outer_poly, main_col)
	if core_poly.size() >= 3:
		draw_colored_polygon(core_poly, core_col)

	# Trailing ember sparks along the crescent edge
	for j: int in range(4 + _current_tier * 2):
		var frac: float = (float(j) + 0.5) / float(4 + _current_tier * 2)
		var spark_ang: float = lerpf(start_angle, end_angle, frac)
		var spark_r: float = reach * (0.82 + 0.24 * progress + 0.08 * sin(frac * PI))
		var spark_col: Color = COLOR_CORE.lerp(main_col, 0.4)
		spark_col.a = fade * 0.85
		draw_circle(Vector2.from_angle(spark_ang) * spark_r, 2.2 + float(_current_tier) * 0.8, spark_col)

	if _current_tier >= 2:
		var wave_pts := PackedVector2Array()
		var wave_pts_2 := PackedVector2Array()
		for i: int in range(segments + 1):
			var t: float = float(i) / float(segments)
			var ang: float = lerpf(start_angle, end_angle, t)
			var wave_r: float = reach * (1.04 + 0.08 * progress)
			wave_pts.append(Vector2.from_angle(ang) * wave_r)
			wave_pts_2.append(Vector2.from_angle(ang) * (wave_r + 7.0))
		var wave_col: Color = COLOR_TIER_2
		wave_col.a = fade * 0.78
		draw_polyline(wave_pts, wave_col, 4.0, true)
		wave_col.a = fade * 0.42
		draw_polyline(wave_pts_2, wave_col, 2.2, true)

	if outer_pts.size() >= 2:
		draw_polyline(outer_pts, rim_col, 2.5, true)
