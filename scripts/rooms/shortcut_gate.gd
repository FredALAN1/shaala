class_name ShortcutGate
extends Area2D
## One-way unlockable metroidvania shortcut gate (e.g. Empty Riyadh -> Desert Camp).
## Blocks passage with a child StaticBody2D barrier until unlocked from the unlockable side;
## once opened, persists in GameState.opened_shortcuts and exposes the linked TransitionGate.

@export var shortcut_id: String = "shortcut_riyadh_to_camp"
@export var prompt_key: String = "PROMPT_OPEN_SHORTCUT"
@export var unlockable_from_this_side: bool = true
@export var linked_transition_gate: NodePath = NodePath("")
@export var lift_distance: float = 176.0

const COLOR_PALE_GOLD: Color = Color("#F6E299")
const COLOR_OCHRE: Color = Color("#C68B59")

var _is_open: bool = false
var _player_in_range: Node = null
var _closed_visual_y: float = 0.0
var _last_interact_frame: int = -1
var _time: float = 0.0

@onready var _barrier_collision: CollisionShape2D = get_node_or_null("BarrierBody/BarrierCollision") as CollisionShape2D
@onready var _gate_visual: Node2D = get_node_or_null("BarrierBody/GateVisual") as Node2D


func _ready() -> void:
	collision_layer = 64
	collision_mask = 4
	monitoring = true
	monitorable = true
	add_to_group("interactables")

	if _gate_visual != null:
		_closed_visual_y = _gate_visual.position.y

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	var already_open: bool = shortcut_id != "" and GameState.is_shortcut_opened(shortcut_id)
	_apply_gate_state(already_open, true)


func _process(delta: float) -> void:
	if _is_open:
		return
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _is_open or not unlockable_from_this_side or _player_in_range == null:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		interact(_player_in_range)
		get_viewport().set_input_as_handled()


func interact(_player: Node) -> void:
	if _is_open or not unlockable_from_this_side:
		return
	var current_frame: int = Engine.get_process_frames()
	if current_frame == _last_interact_frame:
		return
	_last_interact_frame = current_frame

	if shortcut_id != "":
		GameState.set_shortcut_opened(shortcut_id)
	SaveManager.save_game()
	AudioManager.play_sfx("shrine_rest")
	EventBus.camera_shake_requested.emit(5.0, 0.25)
	EventBus.interaction_prompt_changed.emit(false, "")
	_apply_gate_state(true, false)


func _apply_gate_state(opened: bool, instant: bool) -> void:
	_is_open = opened

	if _barrier_collision != null:
		_barrier_collision.set_deferred("disabled", opened)

	var transition_gate: Area2D = get_node_or_null(linked_transition_gate) as Area2D
	if transition_gate != null:
		transition_gate.set_deferred("monitoring", opened)
		transition_gate.set_deferred("monitorable", opened)
		transition_gate.visible = opened

	if opened:
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		_player_in_range = null

	if _gate_visual != null:
		var target_y: float = _closed_visual_y - lift_distance if opened else _closed_visual_y
		var target_alpha: float = 0.0 if opened else 1.0
		if instant:
			_gate_visual.position.y = target_y
			_gate_visual.modulate.a = target_alpha
		else:
			var tween: Tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(_gate_visual, "position:y", target_y, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(_gate_visual, "modulate:a", target_alpha, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _is_open or not unlockable_from_this_side:
		return
	if body == null or not body.is_in_group("player"):
		return
	_player_in_range = body
	EventBus.interaction_prompt_changed.emit(true, prompt_key)


func _on_body_exited(body: Node) -> void:
	if body != _player_in_range:
		return
	_player_in_range = null
	if not _is_open:
		EventBus.interaction_prompt_changed.emit(false, "")


func _draw() -> void:
	if _is_open:
		return
	# Subtle pale-gold Najdi lock emblem on the unlockable side of the gate.
	if unlockable_from_this_side:
		var pulse: float = 0.55 + 0.35 * sin(_time * 2.8)
		var ring_col: Color = Color(COLOR_PALE_GOLD.r, COLOR_PALE_GOLD.g, COLOR_PALE_GOLD.b, pulse)
		draw_arc(Vector2(28.0, 0.0), 14.0, 0.0, TAU, 24, ring_col, 2.2, true)
		draw_circle(Vector2(28.0, 0.0), 5.0, COLOR_OCHRE)
