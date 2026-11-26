class_name PlayerStateMachine
extends Node
## Finite state machine driving Farid's movement and combat states.

signal state_changed(from_state: StringName, to_state: StringName)

@export var initial_state: NodePath

var current_state: PlayerState = null
var current_state_name: StringName = &""
var _states: Dictionary = {}


func initialize(p_player: Player) -> void:
	_states.clear()
	for child: Node in get_children():
		if child is PlayerState:
			var state: PlayerState = child as PlayerState
			state.player = p_player
			state.state_machine = self
			var key: StringName = _normalize_state_name(child.name)
			_states[key] = state

	var start_state: PlayerState = null
	if not initial_state.is_empty():
		var node: Node = get_node_or_null(initial_state)
		if node is PlayerState:
			start_state = node as PlayerState

	if start_state == null and _states.has(&"idle"):
		start_state = _states[&"idle"] as PlayerState

	if start_state != null:
		current_state = start_state
		current_state_name = _normalize_state_name(start_state.name)
		current_state.enter(&"", {})


func handle_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


func update(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func transition_to(target_state_name: StringName, data: Dictionary = {}) -> void:
	var key: StringName = _normalize_state_name(String(target_state_name))
	if not _states.has(key):
		push_warning("PlayerStateMachine: Unknown state '%s'" % String(target_state_name))
		return

	var next_state: PlayerState = _states[key] as PlayerState
	if next_state == null:
		return

	var prev_name: StringName = current_state_name
	if current_state != null:
		current_state.exit()

	current_state = next_state
	current_state_name = key
	current_state.enter(prev_name, data)
	state_changed.emit(prev_name, key)


func has_state(state_name: StringName) -> bool:
	return _states.has(_normalize_state_name(String(state_name)))


func _normalize_state_name(raw_name: String) -> StringName:
	var snake: String = raw_name.to_snake_case()
	if snake.ends_with("_state"):
		snake = snake.substr(0, snake.length() - 6)
	return StringName(snake)
