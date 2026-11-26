class_name TransitionGate
extends Area2D
## Room exit / doorway trigger supporting walk-through gates, interactable doors,
## persisted shortcuts, and story-flag locks.
## Canonical layers: layer 7 (64 = interactable), mask 3 (4 = player).

const ENTRY_ARM_DELAY: float = 0.25

@export var target_room_id: String = ""
@export var target_spawn_id: String = ""
@export var require_interact: bool = false
@export var shortcut_id: String = ""
@export var locked_until_flag: String = ""
@export var prompt_key: String = "PROMPT_INTERACT"

var _player_inside: Node2D = null
var _triggered: bool = false
var _arm_timer: float = ENTRY_ARM_DELAY


func _ready() -> void:
	collision_layer = 64
	collision_mask = 4
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _arm_timer > 0.0:
		_arm_timer = maxf(_arm_timer - delta, 0.0)
		if _arm_timer <= 0.0 and _player_inside != null and not require_interact and is_unlocked():
			_trigger_transition()


func is_unlocked() -> bool:
	if not shortcut_id.is_empty() and not GameState.is_shortcut_opened(shortcut_id):
		return false
	if not locked_until_flag.is_empty() and not GameState.has_story_flag(locked_until_flag):
		return false
	return true


func refresh_state() -> void:
	if _player_inside != null and is_unlocked():
		if require_interact:
			EventBus.interaction_prompt_changed.emit(true, prompt_key)
		elif _arm_timer <= 0.0:
			_trigger_transition()


func interact(_player: Node) -> void:
	if _triggered or not is_unlocked():
		return
	_trigger_transition()


func _unhandled_input(event: InputEvent) -> void:
	if not require_interact or _player_inside == null or _triggered:
		return
	if not is_unlocked():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_trigger_transition()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = body
	if not is_unlocked():
		return
	if require_interact:
		EventBus.interaction_prompt_changed.emit(true, prompt_key)
	elif _arm_timer <= 0.0:
		_trigger_transition()


func _on_body_exited(body: Node2D) -> void:
	if body != _player_inside:
		return
	_player_inside = null
	if require_interact:
		EventBus.interaction_prompt_changed.emit(false, "")


func _trigger_transition() -> void:
	if _triggered or target_room_id.is_empty():
		return
	_triggered = true
	if require_interact and _player_inside != null:
		EventBus.interaction_prompt_changed.emit(false, "")
	EventBus.room_transition_requested.emit(target_room_id, target_spawn_id)
	# Re-arm after a delay in case the transition was rejected (e.g. already transitioning).
	get_tree().create_timer(1.0).timeout.connect(_rearm)


func _rearm() -> void:
	_triggered = false
