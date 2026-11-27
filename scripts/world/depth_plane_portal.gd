class_name DepthPlanePortal
extends Area2D
## Z-Depth Walk-Through Archway Portal (Dimension 2) & 3D Orbit Spire Entrance.
## Allows Farid to step smoothly INTO a recessed interior plane behind dark foreground
## framing pillars (z_index = 15) and return to the foreground plane, or enter the
## 360-degree cylindrical Pillar Orbit Spire when target_plane == "orbit_spire".

const TRANSITION_DURATION: float = 0.38
const INTERIOR_SCALE: Vector2 = Vector2(0.76, 0.76)
const INTERIOR_MODULATE: Color = Color(0.78, 0.78, 0.88, 1.0)
const INTERIOR_Z_INDEX: int = -5
const INTERACT_COOLDOWN: float = 0.45

@export var target_plane: String = "interior"
@export var destination_position: Vector2 = Vector2.ZERO
@export var prompt_key: String = "PROMPT_ENTER_DEPTH"
@export var arch_width: float = 96.0
@export var arch_height: float = 150.0

var _player_inside: Node2D = null
var _cooldown_timer: float = 0.0
var _is_transitioning: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	collision_layer = 64
	collision_mask = 4
	monitoring = true
	monitorable = true

	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(arch_width, arch_height)
		shape_node.shape = rect
		shape_node.position = Vector2(0.0, -arch_height * 0.5)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_pulse_time += delta
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var half_w: float = arch_width * 0.5
	var h: float = arch_height
	var pulse: float = 0.75 + 0.25 * sin(_pulse_time * 2.4)

	var frame_col: Color = Color(0.776, 0.545, 0.349, 0.92)
	var shadow_col: Color = Color(0.051, 0.063, 0.129, 0.95)
	var recess_col: Color = Color(0.118, 0.149, 0.263, 0.88)
	var glow_col: Color = Color(0.965, 0.886, 0.600, 0.26 * pulse)

	if target_plane == "orbit_spire":
		frame_col = Color(0.310, 0.427, 0.478, 0.94)
		recess_col = Color(0.086, 0.106, 0.200, 0.94)
		glow_col = Color(0.965, 0.886, 0.600, 0.36 * pulse)
	elif target_plane == "foreground":
		recess_col = Color(0.220, 0.285, 0.360, 0.84)
		glow_col = Color(0.910, 0.769, 0.604, 0.30 * pulse)

	# Outer Najdi stepped lintel & jambs (strictly convex quads).
	var pillar_w: float = maxf(14.0, arch_width * 0.16)
	_draw_rect_poly(Rect2(-half_w - pillar_w, -h, pillar_w, h), frame_col)
	_draw_rect_poly(Rect2(half_w, -h, pillar_w, h), frame_col)
	_draw_rect_poly(Rect2(-half_w - pillar_w - 6.0, -h - 16.0, arch_width + pillar_w * 2.0 + 12.0, 18.0), frame_col)

	# Deep archway shadow recess.
	_draw_rect_poly(Rect2(-half_w, -h, arch_width, h), shadow_col)

	# Layered recessed inner depth frames (perspective illusion).
	var inset_1: float = arch_width * 0.14
	var top_1: float = h * 0.10
	_draw_rect_poly(Rect2(-half_w + inset_1, -h + top_1, arch_width - inset_1 * 2.0, h - top_1), recess_col)

	var inset_2: float = arch_width * 0.28
	var top_2: float = h * 0.22
	_draw_rect_poly(Rect2(-half_w + inset_2, -h + top_2, arch_width - inset_2 * 2.0, h - top_2), glow_col)

	# Subtle threshold glow bar on the floor.
	_draw_rect_poly(Rect2(-half_w, -4.0, arch_width, 4.0), Color(0.965, 0.886, 0.600, 0.55 * pulse))

	# Spire entrance gets a pale-gold orbital ring emblem.
	if target_plane == "orbit_spire":
		var center: Vector2 = Vector2(0.0, -h * 0.55)
		draw_arc(center, 22.0, 0.0, TAU, 28, Color(0.965, 0.886, 0.600, 0.82 * pulse), 2.2, true)
		draw_arc(center, 11.0, 0.0, TAU, 20, Color(0.878, 0.478, 0.235, 0.78 * pulse), 1.8, true)


func _draw_rect_poly(rect: Rect2, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		rect.position + rect.size,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
	])
	draw_colored_polygon(pts, col)


func interact(player: Node) -> void:
	if player is Node2D:
		_trigger_portal(player as Node2D)


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside == null or _is_transitioning:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_trigger_portal(_player_inside)


func _trigger_portal(player: Node2D) -> void:
	if _is_transitioning or _cooldown_timer > 0.0 or player == null or not is_instance_valid(player):
		return
	_cooldown_timer = INTERACT_COOLDOWN

	if target_plane == "orbit_spire":
		EventBus.interaction_prompt_changed.emit(false, "")
		var rm: Node = get_tree().get_first_node_in_group("room_manager")
		if rm != null and rm.has_method("enter_3d_orbit_spire"):
			rm.call("enter_3d_orbit_spire")
		return

	_is_transitioning = true
	EventBus.interaction_prompt_changed.emit(false, "")

	# Allow stepping in or out seamlessly from either end of the gallery.
	var currently_interior: bool = player.z_index < 0
	var going_interior: bool = (target_plane == "interior") if not currently_interior else false
	if target_plane == "foreground" and not currently_interior:
		going_interior = true

	var target_scale: Vector2 = INTERIOR_SCALE if going_interior else Vector2.ONE
	var target_mod: Color = INTERIOR_MODULATE if going_interior else Color.WHITE
	var target_z: int = INTERIOR_Z_INDEX if going_interior else 0
	var dest: Vector2 = destination_position if destination_position != Vector2.ZERO else player.global_position

	if player.has_method("set_controls_enabled"):
		player.call("set_controls_enabled", false)
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO

	AudioManager.play_sfx("time_shift")
	if going_interior:
		player.z_index = target_z

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "scale", target_scale, TRANSITION_DURATION)
	tween.tween_property(player, "modulate", target_mod, TRANSITION_DURATION)
	tween.tween_property(player, "global_position", dest, TRANSITION_DURATION)
	await tween.finished

	if is_instance_valid(player):
		player.z_index = target_z
		if player.has_method("set_controls_enabled"):
			player.call("set_controls_enabled", true)

	_is_transitioning = false


func _resolve_active_prompt(player: Node2D) -> String:
	if target_plane == "orbit_spire":
		return prompt_key if not prompt_key.is_empty() else "PROMPT_ORBIT_PILLAR"
	if player != null and player.z_index < 0:
		return "PROMPT_EXIT_DEPTH"
	return prompt_key if not prompt_key.is_empty() else "PROMPT_ENTER_DEPTH"


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = body
	if not _is_transitioning:
		EventBus.interaction_prompt_changed.emit(true, _resolve_active_prompt(body))


func _on_body_exited(body: Node2D) -> void:
	if body != _player_inside:
		return
	_player_inside = null
	EventBus.interaction_prompt_changed.emit(false, "")
