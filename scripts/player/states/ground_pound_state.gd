class_name GroundPoundState
extends PlayerState
## Aerial ground-pound slam (gated by GameState.has_ability("ground_pound")).

const WINDUP_TIME: float = 0.07
const RECOVERY_TIME: float = 0.18

var _windup: float = 0.0
var _recovery: float = 0.0
var _landed: bool = false


func enter(_prev_state: StringName, _data: Dictionary = {}) -> void:
	_windup = WINDUP_TIME
	_recovery = 0.0
	_landed = false
	player.velocity = Vector2.ZERO
	player.squash_stretch(Vector2(0.80, 1.25))
	AudioManager.play_sfx("dash")


func exit() -> void:
	player.flame_dagger.stop_slash()


func physics_update(delta: float) -> void:
	if _landed:
		_recovery -= delta
		player.velocity.x = move_toward(player.velocity.x, 0.0, Player.GROUND_DECEL * delta)
		player.apply_gravity(delta)
		if _recovery <= 0.0:
			var input_x: float = player.get_move_input_x()
			state_machine.transition_to(&"run" if absf(input_x) > 0.05 else &"idle")
		return

	if _windup > 0.0:
		_windup -= delta
		player.velocity = Vector2.ZERO
		if _windup <= 0.0:
			player.velocity.y = Player.GROUND_POUND_SPEED
		return

	player.velocity.x = 0.0
	player.velocity.y = Player.GROUND_POUND_SPEED

	if player.is_on_floor():
		_landed = true
		_recovery = RECOVERY_TIME
		player.velocity = Vector2.ZERO
		player.trigger_ground_pound_shockwave()
		player.flame_dagger.start_ground_pound_burst(player, 0.14)
		EventBus.camera_shake_requested.emit(9.0, 0.2)
		EventBus.hitstop_requested.emit(0.05)
		AudioManager.play_sfx("land")
