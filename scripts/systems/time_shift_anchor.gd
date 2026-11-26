class_name TimeShiftAnchor
extends Area2D
## Milestone 2-ready Time Shift anchor.
## Allows Farid to shift the active room between 2034 (intact) and 2054 (ruins)
## once the "time_shift" ability memory has been unlocked.

const INTERACT_COOLDOWN: float = 0.35

@export var anchor_id: String = ""
@export var prompt_key: String = "PROMPT_INTERACT"
@export var locked_prompt_key: String = "PROMPT_SEALED_M2"

var _player_inside: Node2D = null
var _pulse_time: float = 0.0
var _cooldown_timer: float = 0.0


func _ready() -> void:
	collision_layer = 64
	collision_mask = 4
	monitoring = true
	monitorable = true

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
	var unlocked: bool = GameState.has_ability("time_shift")
	var pulse: float = 0.75 + 0.25 * sin(_pulse_time * 2.6)
	var base_color: Color = Color(0.965, 0.886, 0.600, 0.85 * pulse) if unlocked else Color(0.545, 0.584, 0.647, 0.5 * pulse)
	var ring_color: Color = Color(0.290, 0.565, 0.851, 0.7 * pulse) if GameState.current_era == "2034" else base_color

	# Subtle painterly hourglass & concentric seal silhouette.
	draw_arc(Vector2(0.0, -34.0), 22.0, 0.0, TAU, 32, ring_color, 2.0, true)
	draw_arc(Vector2(0.0, -34.0), 13.0, 0.0, TAU, 24, base_color, 1.5, true)
	var diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -48.0),
		Vector2(8.0, -34.0),
		Vector2(0.0, -20.0),
		Vector2(-8.0, -34.0),
	])
	draw_colored_polygon(diamond, Color(ring_color.r, ring_color.g, ring_color.b, 0.35 * pulse))


func interact(_player: Node) -> void:
	_attempt_time_shift()


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside == null:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("time_shift"):
		get_viewport().set_input_as_handled()
		_attempt_time_shift()


func _attempt_time_shift() -> void:
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = INTERACT_COOLDOWN

	if GameState.has_ability("time_shift"):
		var next_era: String = "2034" if GameState.current_era == "2054" else "2054"
		GameState.set_era(next_era)
		AudioManager.play_sfx("time_shift")
		EventBus.camera_shake_requested.emit(4.0, 0.20)
	else:
		AudioManager.play_sfx("ui_click")


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = body
	var key: String = prompt_key if GameState.has_ability("time_shift") else locked_prompt_key
	EventBus.interaction_prompt_changed.emit(true, key)


func _on_body_exited(body: Node2D) -> void:
	if body != _player_inside:
		return
	_player_inside = null
	EventBus.interaction_prompt_changed.emit(false, "")
