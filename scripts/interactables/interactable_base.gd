class_name InteractableBase
extends Area2D
## Base class for all world interactables in SHAALA (شعلة).
## Canonical physics contract:
##   collision_layer = 64 (Layer 7: interactable)
##   collision_mask  = 4  (Layer 3: player)
## Emits EventBus.interaction_prompt_changed when the player enters/exits range,
## and supports both direct `interact(player)` calls and `"interact"` input presses.

signal interacted(player: Node)

const INTERACTABLE_LAYER: int = 64
const PLAYER_MASK: int = 4

@export var prompt_key: String = "PROMPT_INTERACT"
@export var interaction_enabled: bool = true
@export var interaction_cooldown: float = 0.25

var _player_in_range: Node = null
var _cooldown_remaining: float = 0.0
var _last_interact_frame: int = -1
var _prompt_visible: bool = false


func _ready() -> void:
	collision_layer = INTERACTABLE_LAYER
	collision_mask = PLAYER_MASK
	monitoring = true
	monitorable = true
	if not is_in_group("interactables"):
		add_to_group("interactables")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	if _prompt_visible:
		_set_prompt_visible(false)
	_player_in_range = null


func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	if _player_in_range == null:
		return

	if not is_instance_valid(_player_in_range):
		_player_in_range = null
		_set_prompt_visible(false)
		return

	var can_interact: bool = interaction_enabled and _can_player_interact(_player_in_range)
	_set_prompt_visible(can_interact)

	if can_interact and Input.is_action_just_pressed("interact"):
		interact(_player_in_range)


func interact(player: Node) -> void:
	if not interaction_enabled:
		return
	if not _can_player_interact(player):
		return
	var current_frame: int = Engine.get_process_frames()
	if current_frame == _last_interact_frame:
		return
	if _cooldown_remaining > 0.0:
		return
	_last_interact_frame = current_frame
	_cooldown_remaining = interaction_cooldown
	interacted.emit(player)
	_on_interact(player)


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not enabled and _prompt_visible:
		_set_prompt_visible(false)


func is_player_in_range() -> bool:
	return _player_in_range != null and is_instance_valid(_player_in_range)


func get_player_in_range() -> Node:
	if is_player_in_range():
		return _player_in_range
	return null


func _on_interact(_player: Node) -> void:
	pass


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = body
	if interaction_enabled and _can_player_interact(body):
		_set_prompt_visible(true)


func _on_body_exited(body: Node) -> void:
	if body != _player_in_range:
		return
	_player_in_range = null
	_set_prompt_visible(false)


func _set_prompt_visible(visible_state: bool) -> void:
	if _prompt_visible == visible_state:
		return
	_prompt_visible = visible_state
	if visible_state:
		EventBus.interaction_prompt_changed.emit(true, prompt_key)
	else:
		EventBus.interaction_prompt_changed.emit(false, "")


func _can_player_interact(player: Node) -> bool:
	var tree: SceneTree = get_tree()
	if tree == null or tree.paused:
		return false
	if player == null or not is_instance_valid(player):
		return false
	if player.has_method("are_controls_enabled"):
		return bool(player.call("are_controls_enabled"))
	if "controls_enabled" in player:
		return bool(player.get("controls_enabled"))
	if "_controls_enabled" in player:
		return bool(player.get("_controls_enabled"))
	return true
