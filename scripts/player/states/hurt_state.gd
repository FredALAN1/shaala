class_name HurtState
extends PlayerState
## Hit-stun with knockback; 0.85s invulnerability frames begin on entry.

const STUN_DURATION: float = 0.26

var _timer: float = 0.0


func enter(_prev_state: StringName, data: Dictionary = {}) -> void:
	_timer = 0.0
	player.parry_active = false
	player.flame_dagger.stop_slash()
	player.start_invulnerability(Player.HURT_INVULN_DURATION)

	var info: DamageInfo = data.get("damage_info") as DamageInfo
	var kb: Vector2 = Vector2(220.0, -140.0)
	var dir: float = float(-player.facing_dir)
	if info != null:
		kb = info.knockback
		var dx: float = player.global_position.x - info.source_position.x
		if absf(dx) > 1.0:
			dir = signf(dx)
		elif signf(kb.x) != 0.0:
			dir = signf(kb.x)
	player.velocity = Vector2(absf(kb.x) * dir, minf(kb.y, -140.0))
	player.squash_stretch(Vector2(0.86, 1.14))
	AudioManager.play_sfx("player_hurt")
	EventBus.camera_shake_requested.emit(6.0, 0.16)
	EventBus.hitstop_requested.emit(0.06)


func physics_update(delta: float) -> void:
	_timer += delta
	player.velocity.x = move_toward(player.velocity.x, 0.0, Player.AIR_DECEL * 0.6 * delta)
	player.apply_gravity(delta)

	if _timer >= STUN_DURATION:
		if player.is_on_floor():
			var input_x: float = player.get_move_input_x()
			state_machine.transition_to(&"run" if absf(input_x) > 0.05 else &"idle")
		else:
			state_machine.transition_to(&"fall")
