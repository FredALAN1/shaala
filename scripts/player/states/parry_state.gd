class_name ParryState
extends PlayerState
## Parry stance: 0.18s active window then 0.35s cooldown. A parryable hit during the
## window is negated by Player._on_hurtbox_damaged (+25 Resource, hitstop, shake, gold ring).

const RECOVERY_TIME: float = 0.10

var _timer: float = 0.0


func enter(_prev_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	player.parry_active = true
	player.parry_cooldown_timer = Player.PARRY_ACTIVE_WINDOW + RECOVERY_TIME + Player.PARRY_COOLDOWN
	player.trigger_parry_ring(false)
	player.squash_stretch(Vector2(0.94, 1.06))
	AudioManager.play_sfx("parry_whiff")


func exit() -> void:
	player.parry_active = false


func physics_update(delta: float) -> void:
	_timer += delta
	if _timer >= Player.PARRY_ACTIVE_WINDOW:
		player.parry_active = false

	var grounded: bool = player.is_on_floor()
	if grounded:
		player.apply_horizontal_movement(delta, 0.0, true)
	else:
		player.apply_horizontal_movement(delta, player.get_move_input_x() * 0.4, false)
	player.apply_gravity(delta)

	if _timer >= Player.PARRY_ACTIVE_WINDOW + RECOVERY_TIME:
		if grounded:
			state_machine.transition_to(&"idle")
		else:
			state_machine.transition_to(&"fall")
