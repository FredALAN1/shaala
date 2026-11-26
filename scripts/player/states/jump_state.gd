class_name JumpState
extends PlayerState
## Ascending jump state supporting normal jump, variable jump height, double jump, and wall jump.

var _can_cut_jump: bool = true
var _just_entered: bool = true


func enter(_prev_state: StringName, data: Dictionary = {}) -> void:
	_can_cut_jump = true
	_just_entered = true
	player.jump_buffer_timer = 0.0
	player.coyote_timer = 0.0

	var is_wall_jump: bool = bool(data.get("wall_jump", false))
	var is_double_jump: bool = bool(data.get("double_jump", false))

	if is_wall_jump:
		var wall_normal: float = float(data.get("wall_normal", -player.facing_dir))
		if wall_normal == 0.0:
			wall_normal = float(-player.facing_dir)
		player.velocity = Vector2(
			wall_normal * Player.WALL_JUMP_VELOCITY.x,
			Player.WALL_JUMP_VELOCITY.y
		)
		player.set_facing(1 if wall_normal > 0.0 else -1)
		player.wall_jump_lock_timer = Player.WALL_JUMP_LOCK
		AudioManager.play_sfx("jump")
	elif is_double_jump:
		player.double_jump_available = false
		player.velocity.y = Player.DOUBLE_JUMP_VELOCITY
		AudioManager.play_sfx("jump")
	else:
		player.velocity.y = Player.JUMP_VELOCITY
		AudioManager.play_sfx("jump")

	player.squash_stretch(Vector2(0.82, 1.22))
	player.spawn_dust(Vector2(0.0, 28.0), 5, 85.0)


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
		if not _just_entered and Input.is_action_just_pressed("jump") and player.can_double_jump():
			state_machine.transition_to(&"jump", {"double_jump": true})
			return

		# Variable jump height cut on early jump release
		if _can_cut_jump and not Input.is_action_pressed("jump") and player.velocity.y < 0.0 and player.wall_jump_lock_timer <= 0.0:
			player.velocity.y *= Player.VARIABLE_JUMP_CUT
			_can_cut_jump = false

	_just_entered = false
	player.apply_horizontal_movement(delta, input_x, false)
	player.apply_gravity(delta)

	if player.velocity.y >= 0.0:
		state_machine.transition_to(&"fall")
		return

	if player.is_on_floor():
		state_machine.transition_to(&"run" if absf(input_x) > 0.05 else &"idle")
