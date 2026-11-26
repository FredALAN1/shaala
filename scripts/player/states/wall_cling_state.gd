class_name WallClingState
extends PlayerState
## Wall-cling & slow wall-slide state (gated by GameState.has_ability("wall_cling")).

var _wall_normal: int = 1
var _detach_timer: float = 0.0
var _slide_dust_timer: float = 0.0


func enter(_prev_state: StringName, data: Dictionary = {}) -> void:
	_wall_normal = int(data.get("wall_normal", 0))
	if _wall_normal == 0:
		_wall_normal = player.can_wall_cling()
	if _wall_normal == 0:
		_wall_normal = -player.facing_dir
	_detach_timer = 0.0
	_slide_dust_timer = 0.10
	player.active_wall_normal = _wall_normal
	player.reset_air_mobility()
	player.set_facing(_wall_normal)
	player.velocity.x = 0.0
	player.velocity.y = minf(player.velocity.y, Player.WALL_SLIDE_SPEED)
	player.spawn_wall_sparks(_wall_normal, 3)


func exit() -> void:
	player.active_wall_normal = 0


func physics_update(delta: float) -> void:
	if player.is_on_floor():
		state_machine.transition_to(&"idle")
		return

	if not GameState.has_ability("wall_cling"):
		state_machine.transition_to(&"fall")
		return

	var input_x: float = player.get_move_input_x()

	if player.controls_enabled:
		if player.consume_jump_buffer():
			state_machine.transition_to(&"jump", {
				"wall_jump": true,
				"wall_normal": _wall_normal
			})
			return
		if Input.is_action_just_pressed("dash") and player.can_dash():
			player.set_facing(_wall_normal)
			state_machine.transition_to(&"dash", {"direction": _wall_normal})
			return
		if Input.is_action_just_pressed("cast_spell") and player.can_cast_spell():
			player.set_facing(_wall_normal)
			state_machine.transition_to(&"cast_spell")
			return
		if Input.is_action_just_pressed("attack"):
			player.set_facing(_wall_normal)
			state_machine.transition_to(&"attack")
			return

	# Check whether the wall is still touching Farid on the cling side
	var still_touching_wall: bool = false
	if _wall_normal < 0 and player.wall_ray_right != null and player.wall_ray_right.is_colliding():
		still_touching_wall = true
	elif _wall_normal > 0 and player.wall_ray_left != null and player.wall_ray_left.is_colliding():
		still_touching_wall = true

	if not still_touching_wall:
		state_machine.transition_to(&"fall")
		return

	# Pulling away from the wall detaches after a brief sticky grace window
	if signf(input_x) == float(_wall_normal) and absf(input_x) > 0.3:
		_detach_timer += delta
		if _detach_timer >= 0.09:
			state_machine.transition_to(&"fall")
			return
	else:
		_detach_timer = 0.0

	# Push gently toward wall to keep crisp wall contact and clamp downward slide
	player.velocity.x = float(-_wall_normal) * 40.0
	player.velocity.y = minf(player.velocity.y + Player.GRAVITY * 0.45 * delta, Player.WALL_SLIDE_SPEED)

	_slide_dust_timer -= delta
	if _slide_dust_timer <= 0.0:
		_slide_dust_timer = 0.14
		player.spawn_dust(Vector2(float(-_wall_normal) * 14.0, -4.0), 2, 24.0)
		player.spawn_wall_sparks(_wall_normal, 2)
