class_name IdleState
extends PlayerState
## Grounded idle state for Farid.


func enter(_prev_state: StringName, _data: Dictionary = {}) -> void:
	player.reset_air_mobility()


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		state_machine.transition_to(&"fall")
		return

	var input_x: float = player.get_move_input_x()

	if player.controls_enabled:
		if Input.is_action_just_pressed("parry") and player.can_parry():
			state_machine.transition_to(&"parry")
			return
		if Input.is_action_just_pressed("dash") and player.can_dash():
			state_machine.transition_to(&"dash")
			return
		if Input.is_action_just_pressed("cast_spell") and player.can_cast_spell():
			state_machine.transition_to(&"cast_spell")
			return
		if Input.is_action_just_pressed("attack"):
			state_machine.transition_to(&"attack")
			return
		if player.jump_buffer_timer > 0.0:
			if player.try_drop_through_one_way():
				state_machine.transition_to(&"fall")
				return
			if player.consume_jump_buffer():
				state_machine.transition_to(&"jump")
				return
		if absf(input_x) > 0.05:
			state_machine.transition_to(&"run")
			return

	player.apply_horizontal_movement(delta, 0.0, true)
	player.apply_gravity(delta)
