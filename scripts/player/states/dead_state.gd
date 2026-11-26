class_name DeadState
extends PlayerState
## Death: Farid sinks to the sand in silence (no gore), then emits EventBus.player_died.

const DEATH_PAUSE: float = 1.1

var _timer: float = 0.0
var _announced: bool = false


func enter(_prev_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	_announced = false
	player.is_dead = true
	player.parry_active = false
	player.flame_dagger.stop_slash()
	if player.hurtbox != null:
		player.hurtbox.set_invulnerable(true)
	player.velocity.x *= 0.4
	player.squash_stretch(Vector2(1.1, 0.9))
	AudioManager.play_sfx("player_death")


func physics_update(delta: float) -> void:
	_timer += delta
	player.velocity.x = move_toward(player.velocity.x, 0.0, Player.GROUND_DECEL * 0.5 * delta)
	player.apply_gravity(delta)

	if player.visual_root != null and _timer > 0.5:
		player.visual_root.modulate.a = clampf(1.0 - (_timer - 0.5) / (DEATH_PAUSE - 0.5), 0.0, 1.0)

	if _timer >= DEATH_PAUSE and not _announced:
		_announced = true
		EventBus.player_died.emit()
