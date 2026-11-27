class_name RunState
extends PlayerState
## Grounded running state for Farid.

var _step_dust_timer: float = 0.0


func enter(_prev_state: StringName, _data: Dictionary = {}) -> void:
	_step_dust_timer = 0.14
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

	player.apply_horizontal_movement(delta, input_x, true)
	player.apply_gravity(delta)

	_step_dust_timer -= delta
	if _step_dust_timer <= 0.0 and absf(player.velocity.x) > 95.0:
		var in_sand: bool = player.is_in_deep_sand()
		_step_dust_timer = 0.16 if in_sand else 0.22
		player.spawn_dust(Vector2(float(-player.facing_dir) * 8.0, 30.0), 4 if in_sand else 2, 55.0 if in_sand else 38.0)

	if absf(input_x) <= 0.05 and absf(player.velocity.x) < 12.0:
		state_machine.transition_to(&"idle")
