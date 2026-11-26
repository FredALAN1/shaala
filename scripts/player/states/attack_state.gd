class_name AttackState
extends PlayerState
## Flame Dagger 3-hit directional combo state (left/right/up/down-pogo).

const ACTIVE_DURATION: float = 0.11
const TOTAL_DURATION: Array[float] = [0.26, 0.26, 0.38]
const CHAIN_OPEN_TIME: float = 0.10

var _timer: float = 0.0
var _total: float = 0.26
var _step: int = 0
var _buffered_attack: bool = false
var _was_airborne: bool = false


func enter(_prev_state: StringName, _data: Dictionary = {}) -> void:
	_step = player.advance_combo_step()
	_total = TOTAL_DURATION[_step]
	_timer = 0.0
	_buffered_attack = false
	_was_airborne = not player.is_on_floor()

	var dir: Vector2 = player.get_attack_direction()
	if absf(dir.x) > 0.5:
		player.set_facing(1 if dir.x > 0.0 else -1)

	# Small forward lunge on grounded horizontal slashes
	if not _was_airborne and absf(dir.x) > 0.5:
		var lunge: float = 120.0 if _step < 2 else 190.0
		player.velocity.x = float(player.facing_dir) * lunge
	player.squash_stretch(Vector2(1.10, 0.94))
	player.flame_dagger.start_slash(dir, _step, player, ACTIVE_DURATION)


func exit() -> void:
	player.flame_dagger.stop_slash()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_buffered_attack = true


func physics_update(delta: float) -> void:
	_timer += delta
	var input_x: float = player.get_move_input_x()
	var grounded: bool = player.is_on_floor()

	if player.controls_enabled:
		if Input.is_action_just_pressed("attack"):
			_buffered_attack = true
		if Input.is_action_just_pressed("parry") and player.can_parry():
			state_machine.transition_to(&"parry")
			return
		if Input.is_action_just_pressed("dash") and player.can_dash() and _timer >= 0.06:
			state_machine.transition_to(&"dash")
			return
		if Input.is_action_just_pressed("cast_spell") and player.can_cast_spell() and _timer >= 0.08:
			state_machine.transition_to(&"cast_spell")
			return
		if player.jump_buffer_timer > 0.0 and _timer >= 0.08:
			if grounded or player.can_coyote_jump():
				if player.consume_jump_buffer():
					state_machine.transition_to(&"jump")
					return
			elif player.can_double_jump():
				if player.consume_jump_buffer():
					state_machine.transition_to(&"jump", {"double_jump": true})
					return

	# Chain into next combo hit once the swing has had time to read
	if _buffered_attack and _timer >= CHAIN_OPEN_TIME and player.controls_enabled:
		state_machine.transition_to(&"attack")
		return

	# Movement during swing: heavily damped on ground, normal in air
	if grounded:
		player.apply_horizontal_movement(delta, input_x * 0.25, true, 1.0)
	else:
		player.apply_horizontal_movement(delta, input_x, false)
	player.apply_gravity(delta, 0.85 if not grounded else 1.0)

	if _timer >= _total:
		if grounded:
			state_machine.transition_to(&"run" if absf(input_x) > 0.05 else &"idle")
		else:
			state_machine.transition_to(&"fall")
