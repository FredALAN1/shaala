class_name FlameProjectile
extends Hitbox
## Farid's ranged Flame Spell projectile.
## Travels at 760 px/s dealing 24 flame damage.
## Extends Hitbox directly: collision_layer = 16 (player_hitbox), collision_mask = 9 (world 1 + enemy 8).

const COLOR_CORE: Color = Color(1.0, 0.97, 0.86, 1.0)
const COLOR_GOLD: Color = Color(0.965, 0.886, 0.600, 1.0)
const COLOR_ORANGE: Color = Color(0.878, 0.478, 0.235, 1.0)
const COLOR_RED: Color = Color(0.659, 0.267, 0.196, 1.0)

@export var speed: float = 760.0
@export var max_lifetime: float = 1.6

var direction: Vector2 = Vector2.RIGHT
var caster: Node = null

var _elapsed: float = 0.0
var _impacted: bool = false
var _impact_timer: float = 0.0
var _trail_points: Array[Vector2] = []


func _ready() -> void:
	collision_layer = 16 # Layer 5: player_hitbox
	collision_mask = 9   # Layer 1 (world=1) + Layer 4 (enemy hurtbox=8)
	damage_type = "flame"
	parryable = false
	active = true
	if source_node == null and caster != null:
		source_node = caster
	super._ready()
	if not hit_landed.is_connected(_on_hit_landed):
		hit_landed.connect(_on_hit_landed)
	if not body_entered.is_connected(_on_wall_body_entered):
		body_entered.connect(_on_wall_body_entered)
	_trail_points.append(global_position)


func setup(p_direction: Vector2, p_caster: Node, p_damage: int = 24) -> void:
	direction = p_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	caster = p_caster
	source_node = p_caster
	damage = p_damage
	knockback = Vector2(direction.x * 260.0, -110.0)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if _impacted:
		_impact_timer -= delta
		queue_redraw()
		if _impact_timer <= 0.0:
			queue_free()
		return

	super._physics_process(delta)

	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return

	global_position += direction * speed * delta
	_trail_points.push_front(global_position)
	if _trail_points.size() > 10:
		_trail_points.pop_back()
	queue_redraw()


func _on_hit_landed(_hurtbox: Hurtbox, _info: DamageInfo) -> void:
	if _impacted:
		return
	AudioManager.play_sfx("dagger_hit")
	EventBus.hitstop_requested.emit(0.03)
	EventBus.camera_shake_requested.emit(3.5, 0.09)
	_trigger_impact()


func _on_wall_body_entered(_body: Node2D) -> void:
	if _impacted:
		return
	AudioManager.play_sfx("dagger_hit")
	_trigger_impact()


func _trigger_impact() -> void:
	_impacted = true
	_impact_timer = 0.14
	deactivate()
	queue_redraw()


func _draw() -> void:
	if _impacted:
		var t: float = 1.0 - clampf(_impact_timer / 0.14, 0.0, 1.0)
		var fade: float = 1.0 - t
		var outer_r: float = lerpf(16.0, 44.0, t)
		var ring_col: Color = COLOR_GOLD
		ring_col.a = fade * (0.55 if SettingsManager.reduce_flash else 0.85)
		var ember_col: Color = COLOR_ORANGE
		ember_col.a = fade * 0.65
		draw_circle(Vector2.ZERO, outer_r * 0.6, ember_col)
		draw_arc(Vector2.ZERO, outer_r, 0.0, TAU, 24, ring_col, 3.5, true)
		return

	var count: int = _trail_points.size()
	for i: int in range(1, count):
		var ratio: float = 1.0 - float(i) / float(count)
		var local_pt: Vector2 = to_local(_trail_points[i])
		var radius: float = lerpf(3.0, 13.0, ratio)
		var col: Color = COLOR_RED.lerp(COLOR_ORANGE, ratio)
		col.a = ratio * 0.65
		draw_circle(local_pt, radius, col)

	var pulse: float = 1.0 + sin(_elapsed * 34.0) * 0.08
	var outer_spear := PackedVector2Array([
		Vector2(22.0 * pulse, 0.0),
		Vector2(4.0, -13.0 * pulse),
		Vector2(-24.0, -7.0),
		Vector2(-34.0, 0.0),
		Vector2(-24.0, 7.0),
		Vector2(4.0, 13.0 * pulse)
	])
	var inner_spear := PackedVector2Array([
		Vector2(17.0 * pulse, 0.0),
		Vector2(2.0, -7.5 * pulse),
		Vector2(-15.0, 0.0),
		Vector2(2.0, 7.5 * pulse)
	])
	draw_colored_polygon(outer_spear, COLOR_ORANGE)
	draw_colored_polygon(inner_spear, COLOR_GOLD)
	draw_circle(Vector2(5.0, 0.0), 5.5 * pulse, COLOR_CORE)
