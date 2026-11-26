class_name FallState
extends PlayerState
## Airborne falling state supporting coyote jump, jump buffering, double jump, wall cling, glide, and ground pound.


func physics_update(delta: float) -> void:
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
		if player.can_ground_pound() and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack")):
			state_machine.transition_to(&"ground_pound")
			return
		if Input.is_action_just_pressed("attack"):
			state_machine.transition_to(&"attack")
			return

		# Coyote time ground jump
		if player.jump_buffer_timer > 0.0 and player.can_coyote_jump():
			if player.consume_jump_buffer():
				state_machine.transition_to(&"jump")
				return

		# Mid-air double jump
		if Input.is_action_just_pressed("jump") and player.can_double_jump():
			state_machine.transition_to(&"jump", {"double_jump": true})
			return

		# Wall cling transition
		var wall_normal: int = player.can_wall_cling()
		if wall_normal != 0 and player.velocity.y >= 0.0:
			state_machine.transition_to(&"wall_cling", {"wall_normal": wall_normal})
			return

		# Late-game glide
		if player.can_glide():
			state_machine.transition_to(&"glide")
			return

	player.apply_horizontal_movement(delta, input_x, false)
	player.apply_gravity(delta)

	if player.is_on_floor():
		player.squash_stretch(Vector2(1.22, 0.80))
		player.spawn_dust(Vector2(0.0, 30.0), 6, 110.0)
		AudioManager.play_sfx("land")
		if player.consume_jump_buffer():
			state_machine.transition_to(&"jump")
		elif absf(input_x) > 0.05:
			state_machine.transition_to(&"run")
		else:
			state_machine.transition_to(&"idle")
