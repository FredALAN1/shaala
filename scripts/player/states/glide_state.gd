class_name GlideState
extends PlayerState
## Late-game cloaked desert glide state (gated by GameState.has_ability("glide")).


func enter(_prev_state: StringName, _data: Dictionary = {}) -> void:
	player.velocity.y = minf(player.velocity.y, Player.GLIDE_FALL_SPEED)
	player.squash_stretch(Vector2(1.12, 0.92))


func physics_update(delta: float) -> void:
	var input_x: float = player.get_move_input_x()

	if player.is_on_floor():
		player.squash_stretch(Vector2(1.16, 0.86))
		AudioManager.play_sfx("land")
		state_machine.transition_to(&"run" if absf(input_x) > 0.05 else &"idle")
		return

	if not GameState.has_ability("glide") or not player.controls_enabled or not Input.is_action_pressed("jump"):
		state_machine.transition_to(&"fall")
		return

	if Input.is_action_just_pressed("parry") and player.can_parry():
		state_machine.transition_to(&"parry")
		return
	if Input.is_action_just_pressed("dash") and player.can_dash():
		state_machine.transition_to(&"dash")
		return
	if Input.is_action_just_pressed("cast_spell") and player.can_cast_spell():
		state_machine.transition_to(&"cast_spell")
		return
	if player.can_ground_pound() and Input.is_action_just_pressed("attack"):
		state_machine.transition_to(&"ground_pound")
		return
	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to(&"attack")
		return

	var wall_normal: int = player.can_wall_cling()
	if wall_normal != 0:
		state_machine.transition_to(&"wall_cling", {"wall_normal": wall_normal})
		return

	player.apply_horizontal_movement(delta, input_x, false, 0.92)
	player.velocity.y = move_toward(player.velocity.y, Player.GLIDE_FALL_SPEED, Player.GRAVITY * 1.4 * delta)
