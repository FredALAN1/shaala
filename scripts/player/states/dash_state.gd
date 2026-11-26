class_name DashState
extends PlayerState
## High-speed horizontal desert dash (860 px/s for 0.22s, 0.40s cooldown, 1 air dash).

var _dash_timer: float = 0.0
var _ghost_timer: float = 0.0
var _dash_dir: int = 1


func enter(_prev_state: StringName, data: Dictionary = {}) -> void:
	if not player.is_on_floor():
		player.air_dash_available = false

	var explicit_dir: int = int(data.get("direction", 0))
	if explicit_dir != 0:
		_dash_dir = 1 if explicit_dir > 0 else -1
	else:
		var input_x: float = player.get_move_input_x()
		if absf(input_x) > 0.1:
			_dash_dir = 1 if input_x > 0.0 else -1
		else:
			_dash_dir = player.facing_dir

	player.set_facing(_dash_dir)
	player.dash_cooldown_timer = Player.DASH_COOLDOWN
	_dash_timer = Player.DASH_DURATION
	_ghost_timer = 0.0
	player.velocity = Vector2(float(_dash_dir) * Player.DASH_SPEED, 0.0)
	player.squash_stretch(Vector2(1.28, 0.78))
	player.spawn_afterimage()
	player.spawn_dust(Vector2(float(-_dash_dir) * 12.0, 22.0), 5, 70.0)
	AudioManager.play_sfx("dash")


func physics_update(delta: float) -> void:
	_dash_timer -= delta
	_ghost_timer += delta
	if _ghost_timer >= 0.045:
		_ghost_timer = 0.0
		player.spawn_afterimage()

	player.velocity = Vector2(float(_dash_dir) * Player.DASH_SPEED, 0.0)

	# Allow crisp dash-jump when grounded
	if player.controls_enabled and player.is_on_floor() and player.consume_jump_buffer():
		player.velocity.x = float(_dash_dir) * Player.RUN_SPEED
		state_machine.transition_to(&"jump")
		return

	# Allow clinging immediately if dashing into a climbable wall mid-air
	if not player.is_on_floor():
		var wall_normal: int = player.can_wall_cling()
		if wall_normal != 0 and wall_normal == -_dash_dir:
			state_machine.transition_to(&"wall_cling", {"wall_normal": wall_normal})
			return

	if _dash_timer <= 0.0:
		player.velocity.x = float(_dash_dir) * Player.RUN_SPEED
		if player.is_on_floor():
			var input_x: float = player.get_move_input_x()
			state_machine.transition_to(&"run" if absf(input_x) > 0.05 else &"idle")
		else:
			state_machine.transition_to(&"fall")
