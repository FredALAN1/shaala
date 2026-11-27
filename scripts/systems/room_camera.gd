class_name RoomCamera
extends Camera2D
## Smooth metroidvania room camera with horizontal lookahead, strict bounds clamping,
## and accessibility-scaled screen shake.

@export var follow_smoothing: float = 8.5
@export var lookahead_distance: float = 110.0
@export var lookahead_smoothing: float = 4.5
@export var vertical_offset: float = -45.0

var _target: Node2D = null
var _bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
var _facing_sign: float = 1.0
var _current_lookahead: float = 0.0

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _free_cam_enabled: bool = false
var _free_cam_pos: Vector2 = Vector2.ZERO
var _free_cam_zoom: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	enabled = true
	make_current()
	position_smoothing_enabled = false
	if not EventBus.camera_shake_requested.is_connected(_on_camera_shake_requested):
		EventBus.camera_shake_requested.connect(_on_camera_shake_requested)


func set_target(target: Node2D, snap: bool = false) -> void:
	_target = target
	if snap and _target != null and not _free_cam_enabled:
		snap_to_target()


func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds
	if not _free_cam_enabled:
		_apply_bounds_limits()
		if _target != null:
			global_position = _clamp_to_bounds(global_position)


func set_free_cam(enabled_state: bool, pos: Vector2 = Vector2.ZERO, zoom_val: float = 1.0) -> void:
	if enabled_state:
		if not _free_cam_enabled:
			_free_cam_enabled = true
			_free_cam_pos = pos if pos != Vector2.ZERO else global_position
			limit_left = -10000000
			limit_top = -10000000
			limit_right = 10000000
			limit_bottom = 10000000
		else:
			_free_cam_pos = pos
		_free_cam_zoom = clampf(zoom_val, 0.5, 1.5)
	else:
		if _free_cam_enabled:
			_free_cam_enabled = false
			_free_cam_zoom = 1.0
			zoom = Vector2.ONE
			_apply_bounds_limits()
			if _target != null and is_instance_valid(_target):
				global_position = _clamp_to_bounds(global_position)


func is_free_cam_enabled() -> bool:
	return _free_cam_enabled


func snap_to_target() -> void:
	if _target == null or not is_instance_valid(_target) or _free_cam_enabled:
		return
	_update_facing_sign()
	_current_lookahead = _facing_sign * lookahead_distance * 0.5
	var desired: Vector2 = _target.global_position + Vector2(_current_lookahead, vertical_offset)
	global_position = _clamp_to_bounds(desired)
	reset_smoothing()


func _physics_process(delta: float) -> void:
	if _free_cam_enabled:
		var smooth: float = clampf(18.0 * delta, 0.0, 1.0)
		global_position = global_position.lerp(_free_cam_pos, smooth)
		var target_zoom: Vector2 = Vector2(_free_cam_zoom, _free_cam_zoom)
		zoom = zoom.lerp(target_zoom, smooth)
		offset = Vector2.ZERO
		return

	if get_tree().paused:
		return

	if _target != null and is_instance_valid(_target):
		_update_facing_sign()
		var target_lookahead: float = _facing_sign * lookahead_distance
		_current_lookahead = lerpf(_current_lookahead, target_lookahead, clampf(lookahead_smoothing * delta, 0.0, 1.0))

		var desired: Vector2 = _target.global_position + Vector2(_current_lookahead, vertical_offset)
		var clamped_desired: Vector2 = _clamp_to_bounds(desired)
		global_position = global_position.lerp(clamped_desired, clampf(follow_smoothing * delta, 0.0, 1.0))
		global_position = _clamp_to_bounds(global_position)

	_update_shake(delta)


func _apply_bounds_limits() -> void:
	limit_left = int(floorf(_bounds.position.x))
	limit_top = int(floorf(_bounds.position.y))
	limit_right = int(ceilf(_bounds.position.x + _bounds.size.x))
	limit_bottom = int(ceilf(_bounds.position.y + _bounds.size.y))


func _update_facing_sign() -> void:
	if _target == null:
		return
	var facing_prop: Variant = _target.get("facing_direction")
	if facing_prop is int or facing_prop is float:
		var f: float = float(facing_prop)
		if absf(f) > 0.1:
			_facing_sign = signf(f)
			return
	if _target is CharacterBody2D:
		var vel_x: float = (_target as CharacterBody2D).velocity.x
		if absf(vel_x) > 25.0:
			_facing_sign = signf(vel_x)


func _clamp_to_bounds(pos: Vector2) -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1920.0, 1080.0)
	var half_view: Vector2 = (vp_size * 0.5) / Vector2(maxf(zoom.x, 0.01), maxf(zoom.y, 0.01))

	var min_x: float = _bounds.position.x + half_view.x
	var max_x: float = _bounds.position.x + _bounds.size.x - half_view.x
	var min_y: float = _bounds.position.y + half_view.y
	var max_y: float = _bounds.position.y + _bounds.size.y - half_view.y

	var clamped_x: float = _bounds.position.x + _bounds.size.x * 0.5 if min_x > max_x else clampf(pos.x, min_x, max_x)
	var clamped_y: float = _bounds.position.y + _bounds.size.y * 0.5 if min_y > max_y else clampf(pos.y, min_y, max_y)
	return Vector2(clamped_x, clamped_y)


func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	var scaled: float = intensity * SettingsManager.screen_shake_scale
	if scaled <= 0.05 or duration <= 0.0:
		return
	if scaled >= _shake_intensity or _shake_timer <= 0.0:
		_shake_intensity = scaled
		_shake_duration = duration
		_shake_timer = duration


func _update_shake(delta: float) -> void:
	if _shake_timer > 0.0 and _shake_duration > 0.0:
		_shake_timer = maxf(_shake_timer - delta, 0.0)
		var decay: float = _shake_timer / _shake_duration
		var amp: float = _shake_intensity * decay
		offset = Vector2(
			_rng.randf_range(-amp, amp),
			_rng.randf_range(-amp, amp)
		)
	else:
		_shake_intensity = 0.0
		offset = Vector2.ZERO
