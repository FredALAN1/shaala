class_name CastSpellState
extends PlayerState
## Ranged Flame Spell cast (costs 25 Resource, gated by GameState.has_ability("flame_spell")).

const CAST_DURATION: float = 0.24
const RELEASE_TIME: float = 0.07

var _timer: float = 0.0
var _released: bool = false
var _aborted: bool = false


func enter(_prev_state: StringName, _data: Dictionary = {}) -> void:
	_timer = 0.0
	_released = false
	_aborted = false

	if not player.can_cast_spell() or not GameState.spend_resource(Player.SPELL_COST):
		_aborted = true
		return

	player.spell_cooldown_timer = Player.SPELL_COOLDOWN
	player.squash_stretch(Vector2(1.14, 0.92))
	player.notify_cast_pose()
	AudioManager.play_sfx("spell_cast")


func physics_update(delta: float) -> void:
	var grounded: bool = player.is_on_floor()
	var input_x: float = player.get_move_input_x()

	if _aborted:
		_finish(grounded, input_x)
		return

	_timer += delta
	if not _released and _timer >= RELEASE_TIME:
		_released = true
		player.spawn_flame_projectile()
		EventBus.camera_shake_requested.emit(2.0, 0.07)
		player.velocity.x -= float(player.facing_dir) * 70.0

	if grounded:
		player.apply_horizontal_movement(delta, 0.0, true)
	else:
		player.apply_horizontal_movement(delta, input_x * 0.5, false)
	player.apply_gravity(delta, 0.7 if not grounded else 1.0)

	if _timer >= CAST_DURATION:
		_finish(grounded, input_x)


func _finish(grounded: bool, input_x: float) -> void:
	if grounded:
		state_machine.transition_to(&"run" if absf(input_x) > 0.05 else &"idle")
	else:
		state_machine.transition_to(&"fall")
