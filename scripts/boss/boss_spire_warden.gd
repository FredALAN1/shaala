class_name BossSpireWarden
extends BossBase
## M1 Boss — The Fractured Spire Warden (حارس البرج المتصدع)
## Towering shattered-glass & Najdi-arch guardian standing watch over the dead mall
## courtyard of Empty Riyadh. HP 280, 2 phases (Phase 2 at <= 50% HP).
##
## Phase 1 Attacks (0.55-0.75s telegraphs):
##   1) Sweeping Glass Halberd — parryable lunge cleave rewarding parry mastery.
##   2) Falling Spire Shards — 3 vertical gold telegraph beams -> plunging shards (Dash!).
##   3) Vaulting Slam — high leap toward player -> slam + low jumpable/dashable shockwaves.
##
## Phase 2 (<= 50% HP):
##   - Faster recovery cadence.
##   - Adds Twin Beam Sweep (two converging sweeping light beams).
##   - Summons 2 parryable orbiting shard projectiles before Vaulting Slam.

enum Action {
	DORMANT,
	REPOSITION,
	HALBERD_TELEGRAPH,
	HALBERD_SWEEP,
	SHARDS_TELEGRAPH,
	SHARDS_DROP,
	VAULT_TELEGRAPH,
	VAULT_ASCEND,
	VAULT_SLAM,
	TWIN_BEAM_TELEGRAPH,
	TWIN_BEAM_SWEEP,
	ORBIT_SUMMON,
	RECOVER,
}

const HALBERD_TELEGRAPH_TIME: float = 0.60
const HALBERD_SWEEP_TIME: float = 0.34
const HALBERD_LUNGE_SPEED: float = 640.0

const SHARDS_TELEGRAPH_TIME: float = 0.70
const SHARDS_DROP_TIME: float = 0.48

const VAULT_TELEGRAPH_TIME: float = 0.58
const VAULT_ASCEND_TIME: float = 0.42
const VAULT_SLAM_TIME: float = 0.36

const TWIN_BEAM_TELEGRAPH_TIME: float = 0.70
const TWIN_BEAM_SWEEP_TIME: float = 0.78

const ORBIT_SUMMON_TIME: float = 0.56

var action: Action = Action.DORMANT
var action_timer: float = 0.0
var action_duration: float = 0.5

var _last_attack_id: String = ""
var _attack_counter: int = 0
var _reposition_speed: float = 175.0

# Falling Spire Shards data
var _shard_beam_xs: Array[float] = []
var _shard_drop_progress: float = 0.0
var _shard_hitboxes: Array[Area2D] = []

# Vaulting Slam data
var _vault_start_pos: Vector2 = Vector2.ZERO
var _vault_apex_pos: Vector2 = Vector2.ZERO
var _vault_target_x: float = 1100.0
var _vault_slammed: bool = false
var _slam_hitbox: Area2D = null

# Twin Beam Sweep data
var _beam_origin: Vector2 = Vector2.ZERO
var _beam_angles: Array[float] = [0.45, 2.69]
var _beam_hitboxes: Array[Area2D] = []
var _beam_length: float = 760.0

# Tracked dynamic world nodes (shockwaves + orbiting shards) for clean teardown
var _active_world_hazards: Array[Node] = []


func _on_boss_ready() -> void:
	collision_layer = 8
	collision_mask = 3
	boss_id = "boss_spire_warden"
	boss_name_key = "BOSS_SPIRE_WARDEN_NAME"
	max_hp = 280
	current_hp = max_hp
	phase_thresholds = [0.5]
	stagger_duration = 1.4
	stagger_damage_multiplier = 1.35
	resource_drop = 100.0
	contact_damage = 1
	facing = -1
	action = Action.DORMANT


func _exit_tree() -> void:
	_cleanup_all_attacks()


func _on_encounter_started() -> void:
	face_player()
	_set_action(Action.REPOSITION, 0.55)


func _on_attack_interrupted() -> void:
	_clear_temporary_hitboxes()
	uses_gravity = true
	action = Action.RECOVER
	action_timer = 0.45
	action_duration = 0.45


func _on_stagger_finished() -> void:
	face_player()
	_set_action(Action.REPOSITION, 0.35 if phase >= 2 else 0.55)


func _on_phase_transition_started(_new_phase: int) -> void:
	_clear_temporary_hitboxes()
	_shard_beam_xs.clear()
	uses_gravity = true
	action = Action.RECOVER
	action_timer = 0.4


func _on_phase_transition_finished(_new_phase: int) -> void:
	face_player()
	# Open Phase 2 dramatically with Twin Beam Sweep!
	_start_twin_beam_sweep()


func _cleanup_all_attacks() -> void:
	_clear_temporary_hitboxes()
	_shard_beam_xs.clear()
	for node: Node in _active_world_hazards:
		if is_instance_valid(node):
			node.queue_free()
	_active_world_hazards.clear()


func _clear_temporary_hitboxes() -> void:
	_deactivate_attack_hitbox()
	for hb: Area2D in _shard_hitboxes:
		if is_instance_valid(hb):
			hb.queue_free()
	_shard_hitboxes.clear()

	for hb: Area2D in _beam_hitboxes:
		if is_instance_valid(hb):
			hb.queue_free()
	_beam_hitboxes.clear()

	if is_instance_valid(_slam_hitbox):
		_slam_hitbox.queue_free()
	_slam_hitbox = null


func _set_action(next_action: Action, duration: float) -> void:
	action = next_action
	action_timer = duration
	action_duration = maxf(0.01, duration)


func _get_action_progress() -> float:
	return clampf(1.0 - (action_timer / maxf(0.01, action_duration)), 0.0, 1.0)


func _boss_physics_process(delta: float) -> void:
	action_timer = maxf(0.0, action_timer - delta)

	match action:
		Action.DORMANT:
			velocity.x = 0.0
		Action.REPOSITION:
			_process_reposition(delta)
		Action.HALBERD_TELEGRAPH:
			_process_halberd_telegraph(delta)
		Action.HALBERD_SWEEP:
			_process_halberd_sweep(delta)
		Action.SHARDS_TELEGRAPH:
			_process_shards_telegraph(delta)
		Action.SHARDS_DROP:
			_process_shards_drop(delta)
		Action.VAULT_TELEGRAPH:
			_process_vault_telegraph(delta)
		Action.VAULT_ASCEND:
			_process_vault_ascend(delta)
		Action.VAULT_SLAM:
			_process_vault_slam(delta)
		Action.TWIN_BEAM_TELEGRAPH:
			_process_twin_beam_telegraph(delta)
		Action.TWIN_BEAM_SWEEP:
			_process_twin_beam_sweep(delta)
		Action.ORBIT_SUMMON:
			_process_orbit_summon(delta)
		Action.RECOVER:
			_process_recover(delta)


func _process_reposition(delta: float) -> void:
	uses_gravity = true
	face_player()
	var player: Node2D = get_player()
	if player != null:
		var dx: float = player.global_position.x - global_position.x
		var desired_dist: float = 290.0
		if absf(dx) > desired_dist + 45.0:
			velocity.x = move_toward(velocity.x, signf(dx) * _reposition_speed * (1.25 if phase >= 2 else 1.0), 750.0 * delta)
		elif absf(dx) < 150.0:
			velocity.x = move_toward(velocity.x, -signf(dx) * _reposition_speed * 0.75, 750.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	if action_timer <= 0.0:
		_choose_next_attack()


func _choose_next_attack() -> void:
	face_player()
	_attack_counter += 1
	var player: Node2D = get_player()
	var dist_x: float = 340.0
	if player != null:
		dist_x = absf(player.global_position.x - global_position.x)

	var pool: Array[String] = []
	if phase == 1:
		pool = ["halberd", "shards", "vault"]
	else:
		pool = ["halberd", "shards", "twin_beam", "orbit_vault"]

	# Prevent repeating the same attack twice in a row
	if _last_attack_id in pool and pool.size() > 1:
		pool.erase(_last_attack_id)

	var chosen: String = pool[0]
	if dist_x <= 320.0 and "halberd" in pool and (_attack_counter % 2 == 1):
		chosen = "halberd"
	elif dist_x >= 560.0 and "shards" in pool and (_attack_counter % 2 == 0):
		chosen = "shards"
	else:
		chosen = pool[_attack_counter % pool.size()]

	_last_attack_id = chosen
	match chosen:
		"halberd":
			_start_halberd_sweep()
		"shards":
			_start_falling_shards()
		"vault":
			_start_vaulting_slam()
		"twin_beam":
			_start_twin_beam_sweep()
		"orbit_vault":
			_start_orbit_summon_then_vault()


# ==============================================================================
# ATTACK 1: SWEEPING GLASS HALBERD (Parryable Lunge Cleave)
# ==============================================================================

func _start_halberd_sweep() -> void:
	face_player()
	uses_gravity = true
	_set_action(Action.HALBERD_TELEGRAPH, HALBERD_TELEGRAPH_TIME)
	AudioManager.play_sfx("ui_hover")


func _process_halberd_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	if _get_action_progress() < 0.55:
		face_player()
	if action_timer <= 0.0:
		_set_action(Action.HALBERD_SWEEP, HALBERD_SWEEP_TIME)
		_set_contact_enabled(false)
		_position_halberd_hitbox()
		_activate_attack_hitbox(1, Vector2(360.0, -210.0), true, "melee")
		AudioManager.play_sfx("dagger_swing")
		EventBus.camera_shake_requested.emit(5.0, 0.14)


func _process_halberd_sweep(delta: float) -> void:
	var prog: float = _get_action_progress()
	_position_halberd_hitbox()
	if prog < 0.72:
		var spd: float = HALBERD_LUNGE_SPEED * (1.12 if phase >= 2 else 1.0)
		velocity.x = float(facing) * spd
	else:
		velocity.x = move_toward(velocity.x, 0.0, 2200.0 * delta)

	# Keep inside arena margins
	if (facing < 0 and global_position.x <= arena_left_x + 40.0) or (facing > 0 and global_position.x >= arena_right_x - 40.0):
		velocity.x = 0.0

	if action_timer <= 0.0:
		_deactivate_attack_hitbox()
		_set_contact_enabled(true)
		_enter_recover()


func _position_halberd_hitbox() -> void:
	if attack_hitbox != null:
		attack_hitbox.position = Vector2(float(facing) * 102.0, -64.0)


# ==============================================================================
# ATTACK 2: FALLING SPIRE SHARDS (Vertical Gold Beams -> Plunging Shards)
# ==============================================================================

func _start_falling_shards() -> void:
	face_player()
	uses_gravity = true
	_shard_beam_xs.clear()
	_shard_drop_progress = 0.0

	var player: Node2D = get_player()
	var center_x: float = player.global_position.x if player != null else clampf(global_position.x + float(facing) * 320.0, arena_left_x + 120.0, arena_right_x - 120.0)
	center_x = clampf(center_x, arena_left_x + 110.0, arena_right_x - 110.0)

	if phase == 1:
		# 3 crisp spaced beams (center on player + left/right flanks with clear dash gaps)
		var offsets: Array[float] = [-280.0, 0.0, 280.0]
		for off: float in offsets:
			_shard_beam_xs.append(clampf(center_x + off, arena_left_x + 80.0, arena_right_x - 80.0))
	else:
		# Phase 2: 4 beams spaced cleanly so Dash reliably slips into safe gaps
		var offsets_p2: Array[float] = [-370.0, -125.0, 125.0, 370.0]
		for off: float in offsets_p2:
			_shard_beam_xs.append(clampf(center_x + off, arena_left_x + 80.0, arena_right_x - 80.0))

	_set_action(Action.SHARDS_TELEGRAPH, SHARDS_TELEGRAPH_TIME)
	AudioManager.play_sfx("grey_eye")


func _process_shards_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	if action_timer <= 0.0:
		_set_action(Action.SHARDS_DROP, SHARDS_DROP_TIME)
		_shard_drop_progress = 0.0
		_spawn_falling_shard_hitboxes()
		AudioManager.play_sfx("spell_cast")
		EventBus.camera_shake_requested.emit(7.0, 0.20)


func _spawn_falling_shard_hitboxes() -> void:
	_clear_temporary_hitboxes()
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	for beam_x: float in _shard_beam_xs:
		var hb := Hitbox.new()
		hb.name = "FallingShardHitbox"
		hb.collision_layer = 32
		hb.collision_mask = 4
		hb.damage = 1
		hb.knockback = Vector2(210.0 * float(facing), -180.0)
		hb.parryable = false
		hb.damage_type = "shard"
		hb.one_shot_per_target = true
		hb.source_node = self
		hb.global_position = Vector2(beam_x, arena_floor_y - 240.0)

		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(56.0, 480.0)
		col.shape = rect
		hb.add_child(col)

		parent_node.add_child(hb)
		hb.set_deferred("active", true)
		_shard_hitboxes.append(hb)


func _process_shards_drop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	_shard_drop_progress = _get_action_progress()
	# Impact hazard window lasts the first 52% of the drop animation, then shards shatter cleanly
	if _shard_drop_progress > 0.52 and not _shard_hitboxes.is_empty():
		for hb: Area2D in _shard_hitboxes:
			if is_instance_valid(hb):
				hb.queue_free()
		_shard_hitboxes.clear()

	if action_timer <= 0.0:
		_shard_beam_xs.clear()
		_enter_recover()


# ==============================================================================
# ATTACK 3: VAULTING SLAM (Leap + Impact + Low Jumpable/Dashable Shockwaves)
# ==============================================================================

func _start_vaulting_slam() -> void:
	face_player()
	uses_gravity = true
	_vault_slammed = false
	_set_action(Action.VAULT_TELEGRAPH, VAULT_TELEGRAPH_TIME)
	AudioManager.play_sfx("ui_hover")


func _process_vault_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	face_player()
	if action_timer <= 0.0:
		var player: Node2D = get_player()
		_vault_start_pos = global_position
		var raw_target_x: float = player.global_position.x if player != null else global_position.x + float(facing) * 320.0
		_vault_target_x = clampf(raw_target_x, arena_left_x + 90.0, arena_right_x - 90.0)
		_vault_apex_pos = Vector2(lerpf(_vault_start_pos.x, _vault_target_x, 0.65), arena_floor_y - 380.0)
		uses_gravity = false
		_set_action(Action.VAULT_ASCEND, VAULT_ASCEND_TIME)
		AudioManager.play_sfx("jump")


func _process_vault_ascend(_delta: float) -> void:
	var t: float = _get_action_progress()
	# Smooth quadratic arc up to the skylight apex above the target zone
	var eased_x: float = lerpf(_vault_start_pos.x, _vault_target_x, t)
	var arc_y: float = lerpf(_vault_start_pos.y, _vault_apex_pos.y, sin(t * PI * 0.5))
	var next_pos := Vector2(eased_x, arc_y)
	velocity = (next_pos - global_position) * 60.0

	if action_timer <= 0.0:
		global_position = Vector2(_vault_target_x, _vault_apex_pos.y)
		velocity = Vector2(0.0, 1320.0)
		uses_gravity = true
		_vault_slammed = false
		_set_action(Action.VAULT_SLAM, VAULT_SLAM_TIME)


func _process_vault_slam(_delta: float) -> void:
	velocity.x = 0.0
	if not _vault_slammed:
		velocity.y = 1360.0
		if is_on_floor() or global_position.y >= arena_floor_y - 4.0:
			_vault_slammed = true
			velocity = Vector2.ZERO
			_trigger_slam_impact()
	else:
		velocity = Vector2.ZERO

	if action_timer <= 0.0:
		if not _vault_slammed:
			_vault_slammed = true
			_trigger_slam_impact()
		if is_instance_valid(_slam_hitbox):
			_slam_hitbox.queue_free()
			_slam_hitbox = null
		_enter_recover()


func _trigger_slam_impact() -> void:
	AudioManager.play_sfx("boss_roar")
	EventBus.camera_shake_requested.emit(10.0, 0.28)
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	# Direct slam impact burst hitbox (heavy damage = 2)
	var impact_hb := Hitbox.new()
	impact_hb.name = "VaultSlamImpactHitbox"
	impact_hb.collision_layer = 32
	impact_hb.collision_mask = 4
	impact_hb.damage = 2
	impact_hb.knockback = Vector2(320.0 * float(facing), -240.0)
	impact_hb.parryable = false
	impact_hb.damage_type = "slam"
	impact_hb.one_shot_per_target = true
	impact_hb.source_node = self
	impact_hb.global_position = Vector2(global_position.x, arena_floor_y - 36.0)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150.0, 72.0)
	col.shape = rect
	impact_hb.add_child(col)
	parent_node.add_child(impact_hb)
	impact_hb.set_deferred("active", true)
	_slam_hitbox = impact_hb

	# Two low ground shockwaves traveling left and right (cleanly jumpable or dashable!)
	var wave_speed: float = 610.0 if phase >= 2 else 540.0
	for dir: int in [-1, 1]:
		var wave := GroundShockwave.new()
		wave.setup(
			Vector2(global_position.x + float(dir) * 56.0, arena_floor_y),
			dir,
			wave_speed,
			arena_left_x - 30.0,
			arena_right_x + 30.0,
			self
		)
		parent_node.add_child(wave)
		_active_world_hazards.append(wave)


# ==============================================================================
# PHASE 2 ATTACK 4: TWIN BEAM SWEEP
# ==============================================================================

func _start_twin_beam_sweep() -> void:
	face_player()
	uses_gravity = false
	velocity = Vector2.ZERO
	_beam_origin = Vector2(global_position.x, arena_floor_y - 115.0)
	# Two beams start aimed outward horizontally-down and sweep across the courtyard
	_beam_angles = [0.22, PI - 0.22]
	_set_action(Action.TWIN_BEAM_TELEGRAPH, TWIN_BEAM_TELEGRAPH_TIME)
	AudioManager.play_sfx("grey_eye")


func _process_twin_beam_telegraph(delta: float) -> void:
	# Levitate cleanly to casting height
	var target_y: float = arena_floor_y - 40.0
	global_position.y = move_toward(global_position.y, target_y, 240.0 * delta)
	_beam_origin = Vector2(global_position.x, global_position.y - 78.0)

	if action_timer <= 0.0:
		_set_action(Action.TWIN_BEAM_SWEEP, TWIN_BEAM_SWEEP_TIME)
		_spawn_twin_beam_hitboxes()
		AudioManager.play_sfx("spell_cast")
		EventBus.camera_shake_requested.emit(6.5, 0.30)


func _spawn_twin_beam_hitboxes() -> void:
	_clear_temporary_hitboxes()
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for i: int in range(2):
		var hb := Hitbox.new()
		hb.name = "TwinBeamHitbox_%d" % i
		hb.collision_layer = 32
		hb.collision_mask = 4
		hb.damage = 1
		hb.knockback = Vector2(240.0 * (-1.0 if i == 1 else 1.0), -170.0)
		hb.parryable = false
		hb.damage_type = "beam"
		hb.one_shot_per_target = false
		hb.source_node = self
		hb.global_position = _beam_origin
		hb.rotation = _beam_angles[i]

		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(_beam_length, 24.0)
		col.shape = rect
		col.position = Vector2(_beam_length * 0.5, 0.0)
		hb.add_child(col)

		parent_node.add_child(hb)
		hb.set_deferred("active", true)
		_beam_hitboxes.append(hb)


func _process_twin_beam_sweep(_delta: float) -> void:
	var t: float = _get_action_progress()
	_beam_origin = Vector2(global_position.x, global_position.y - 78.0)
	# Beams sweep symmetrically downward then cross cleanly above/across ground level
	_beam_angles[0] = lerpf(0.18, 1.32, t)
	_beam_angles[1] = lerpf(PI - 0.18, PI - 1.32, t)

	for i: int in range(mini(2, _beam_hitboxes.size())):
		var hb: Area2D = _beam_hitboxes[i]
		if is_instance_valid(hb):
			hb.global_position = _beam_origin
			hb.rotation = _beam_angles[i]

	if action_timer <= 0.0:
		_clear_temporary_hitboxes()
		uses_gravity = true
		_enter_recover()


# ==============================================================================
# PHASE 2 ATTACK 5: ORBITING PARRYABLE SHARDS -> VAULTING SLAM
# ==============================================================================

func _start_orbit_summon_then_vault() -> void:
	face_player()
	uses_gravity = true
	_set_action(Action.ORBIT_SUMMON, ORBIT_SUMMON_TIME)
	AudioManager.play_sfx("orb_collect")
	_spawn_orbiting_shards()


func _spawn_orbiting_shards() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	for i: int in range(2):
		var shard := WardenOrbitShard.new()
		var start_angle: float = float(i) * PI
		var launch_delay: float = 0.52 + float(i) * 0.30
		shard.setup(self, start_angle, launch_delay)
		parent_node.add_child(shard)
		_active_world_hazards.append(shard)


func _process_orbit_summon(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	face_player()
	if action_timer <= 0.0:
		_start_vaulting_slam()


func _enter_recover() -> void:
	uses_gravity = true
	var recover_t: float = 0.55 if phase >= 2 else 0.92
	_set_action(Action.RECOVER, recover_t)


func _process_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	if action_timer <= 0.0:
		_set_action(Action.REPOSITION, 0.42 if phase >= 2 else 0.68)


# ==============================================================================
# PAINTERLY ARCHITECTURAL SILHOUETTE RENDERING
# ==============================================================================

func _draw_boss(canvas: Node2D) -> void:
	var f: float = float(facing)
	var breathe: float = sin(anim_time * 2.8) * 3.0
	var p2_glow: float = 1.0 if phase >= 2 else 0.45
	var stagger_lean: float = -12.0 * f if is_staggered else 0.0
	var crouch_y: float = 0.0
	if action == Action.VAULT_TELEGRAPH:
		crouch_y = 14.0 * _get_action_progress()
	elif action == Action.HALBERD_TELEGRAPH:
		crouch_y = 8.0 * _get_action_progress()

	var flash_mix: float = 0.65 if hit_flash_timer > 0.0 else 0.0
	if is_staggered:
		flash_mix = maxf(flash_mix, 0.45 + 0.25 * sin(anim_time * 16.0))
	if _is_reduce_flash_enabled():
		flash_mix *= 0.45

	var cloak_col: Color = COL_NIGHT_INDIGO.lerp(COL_PALE_GOLD, flash_mix)
	var shadow_col: Color = COL_DEEP_SHADOW.lerp(COL_PALE_GOLD, flash_mix * 0.5)
	var ochre_col: Color = COL_MUD_BRICK_OCHRE.lerp(COL_PALE_GOLD, flash_mix)
	var glass_col: Color = COL_GLASS_TEAL.lerp(COL_PALE_GOLD, flash_mix)
	var gold_col: Color = COL_PALE_GOLD

	# Courtyard shadow pool beneath the Warden
	if is_on_floor() or absf(global_position.y - arena_floor_y) < 30.0:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(-48.0, 0.0),
			Vector2(48.0, 0.0),
			Vector2(36.0, 7.0),
			Vector2(-36.0, 7.0),
		]), Color(COL_DEEP_SHADOW.r, COL_DEEP_SHADOW.g, COL_DEEP_SHADOW.b, 0.55))

	# Flowing tall architectural cloak (deep shadow inner + night indigo outer)
	var cloak_sway: float = sin(anim_time * 3.5) * 6.0 - clampf(velocity.x * 0.025, -18.0, 18.0)
	var outer_cloak := PackedVector2Array([
		Vector2(-38.0 + cloak_sway * 0.6, -4.0),
		Vector2(-34.0 + stagger_lean * 0.4, -76.0 + crouch_y),
		Vector2(-26.0 + stagger_lean * 0.8, -114.0 + crouch_y + breathe * 0.4),
		Vector2(26.0 + stagger_lean * 0.8, -114.0 + crouch_y + breathe * 0.4),
		Vector2(34.0 + stagger_lean * 0.4, -76.0 + crouch_y),
		Vector2(38.0 + cloak_sway * 0.6, -4.0),
		Vector2(14.0 + cloak_sway * 0.3, -12.0),
		Vector2(-14.0 + cloak_sway * 0.3, -12.0),
	])
	canvas.draw_colored_polygon(outer_cloak, cloak_col)

	# Inner vaulted Najdi archway panel in deep shadow
	var inner_arch := PackedVector2Array([
		Vector2(-18.0, -8.0),
		Vector2(-16.0 + stagger_lean * 0.5, -86.0 + crouch_y),
		Vector2(0.0 + stagger_lean * 0.7, -104.0 + crouch_y),
		Vector2(16.0 + stagger_lean * 0.5, -86.0 + crouch_y),
		Vector2(18.0, -8.0),
	])
	canvas.draw_colored_polygon(inner_arch, shadow_col)

	# Mud-brick ochre Najdi crenellated shoulder mantle (shurfat stepped battlements)
	var mantle_y: float = -108.0 + crouch_y + breathe * 0.5
	var mantle_pts := PackedVector2Array([
		Vector2(-44.0 + stagger_lean * 0.7, mantle_y + 18.0),
		Vector2(-40.0 + stagger_lean * 0.8, mantle_y),
		Vector2(-30.0 + stagger_lean * 0.8, mantle_y - 9.0),
		Vector2(-20.0 + stagger_lean * 0.8, mantle_y),
		Vector2(-12.0 + stagger_lean * 0.8, mantle_y - 6.0),
		Vector2(12.0 + stagger_lean * 0.8, mantle_y - 6.0),
		Vector2(20.0 + stagger_lean * 0.8, mantle_y),
		Vector2(30.0 + stagger_lean * 0.8, mantle_y - 9.0),
		Vector2(40.0 + stagger_lean * 0.8, mantle_y),
		Vector2(44.0 + stagger_lean * 0.7, mantle_y + 18.0),
		Vector2(22.0 + stagger_lean * 0.6, mantle_y + 10.0),
		Vector2(-22.0 + stagger_lean * 0.6, mantle_y + 10.0),
	])
	canvas.draw_colored_polygon(mantle_pts, ochre_col)

	# Glowing pale-gold fracture seams across chest & robe (intensify in Phase 2!)
	var seam_a: float = clampf(p2_glow + 0.25 * sin(anim_time * 6.0), 0.3, 1.0)
	var seam_col := Color(gold_col.r, gold_col.g, gold_col.b, seam_a)
	canvas.draw_polyline(PackedVector2Array([
		Vector2(0.0 + stagger_lean * 0.7, -102.0 + crouch_y),
		Vector2(5.0 * f + stagger_lean * 0.5, -76.0 + crouch_y),
		Vector2(-4.0 * f + stagger_lean * 0.4, -50.0 + crouch_y),
		Vector2(2.0 * f, -22.0),
	]), seam_col, 3.0 if phase >= 2 else 2.2, true)
	if phase >= 2:
		canvas.draw_line(
			Vector2(5.0 * f + stagger_lean * 0.5, -76.0 + crouch_y),
			Vector2(22.0 * f + stagger_lean * 0.5, -66.0 + crouch_y),
			seam_col,
			2.0,
			true
		)
		canvas.draw_line(
			Vector2(-4.0 * f + stagger_lean * 0.4, -50.0 + crouch_y),
			Vector2(-24.0 * f + stagger_lean * 0.4, -40.0 + crouch_y),
			seam_col,
			2.0,
			true
		)

	# Towering split fractured-glass Riyadh spire crown / helmet
	var head_base_y: float = -114.0 + crouch_y + breathe * 0.6
	var left_spire := PackedVector2Array([
		Vector2(-16.0 + stagger_lean, head_base_y),
		Vector2(-19.0 + stagger_lean, head_base_y - 36.0),
		Vector2(-5.0 + stagger_lean, head_base_y - 54.0),
		Vector2(-3.0 + stagger_lean, head_base_y - 16.0),
	])
	var right_spire := PackedVector2Array([
		Vector2(16.0 + stagger_lean, head_base_y),
		Vector2(19.0 + stagger_lean, head_base_y - 36.0),
		Vector2(5.0 + stagger_lean, head_base_y - 54.0),
		Vector2(3.0 + stagger_lean, head_base_y - 16.0),
	])
	canvas.draw_colored_polygon(left_spire, glass_col)
	canvas.draw_colored_polygon(right_spire, glass_col)
	# Luminous golden void inside the fractured spire arch
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0 + stagger_lean, head_base_y - 14.0),
		Vector2(0.0 + stagger_lean, head_base_y - 46.0),
		Vector2(4.0 + stagger_lean, head_base_y - 14.0),
		Vector2(0.0 + stagger_lean, head_base_y - 4.0),
	]), seam_col)
	canvas.draw_polyline(PackedVector2Array([
		left_spire[0], left_spire[1], left_spire[2], right_spire[2], right_spire[1], right_spire[0]
	]), ochre_col, 1.8, true)

	# Towering Fractured-Glass Halberd
	_draw_halberd(canvas, f, crouch_y, breathe, stagger_lean, ochre_col, glass_col, gold_col)


func _draw_halberd(
	canvas: Node2D,
	f: float,
	crouch_y: float,
	breathe: float,
	stagger_lean: float,
	ochre_col: Color,
	glass_col: Color,
	gold_col: Color
) -> void:
	var pivot := Vector2(12.0 * f + stagger_lean * 0.6, -74.0 + crouch_y + breathe * 0.5)
	var angle: float = 0.22 * f
	var prog: float = _get_action_progress()

	match action:
		Action.HALBERD_TELEGRAPH:
			angle = lerpf(0.22 * f, -1.95 * f, prog)
		Action.HALBERD_SWEEP:
			angle = lerpf(-1.95 * f, 1.55 * f, minf(1.0, prog * 1.45))
		Action.SHARDS_TELEGRAPH, Action.SHARDS_DROP:
			angle = 0.0
			pivot.y -= 28.0
		Action.VAULT_ASCEND, Action.VAULT_SLAM:
			angle = PI
		Action.TWIN_BEAM_TELEGRAPH, Action.TWIN_BEAM_SWEEP:
			angle = 0.55 * f
		_:
			if is_staggered:
				angle = -0.95 * f

	var shaft_butt: Vector2 = pivot + Vector2(0.0, 56.0).rotated(angle)
	var shaft_tip: Vector2 = pivot + Vector2(0.0, -108.0).rotated(angle)
	var perp: Vector2 = Vector2(f, 0.0).rotated(angle)

	# Bronze-ochre halberd shaft
	canvas.draw_line(shaft_butt, shaft_tip, ochre_col, 5.0, true)

	# Sweeping fractured-glass halberd crescent blade
	var blade_col: Color = glass_col
	if action == Action.HALBERD_TELEGRAPH:
		blade_col = glass_col.lerp(gold_col, prog * 0.85)
	elif action == Action.HALBERD_SWEEP:
		blade_col = gold_col

	var halberd_head := PackedVector2Array([
		pivot + Vector2(0.0, -72.0).rotated(angle),
		pivot + Vector2(0.0, -124.0).rotated(angle),
		pivot + Vector2(0.0, -104.0).rotated(angle) + perp * 28.0,
		pivot + Vector2(0.0, -76.0).rotated(angle) + perp * 22.0,
	])
	canvas.draw_colored_polygon(halberd_head, blade_col)
	canvas.draw_polyline(PackedVector2Array([
		halberd_head[0], halberd_head[1], halberd_head[2], halberd_head[3], halberd_head[0]
	]), gold_col, 2.0, true)

	# Crisp parry-readiness gold glint star during Sweeping Glass Halberd telegraph
	if action == Action.HALBERD_TELEGRAPH:
		var tip_pos: Vector2 = pivot + Vector2(0.0, -112.0).rotated(angle)
		var glint_a: float = 0.5 + 0.45 * prog
		if _is_reduce_flash_enabled():
			glint_a *= 0.5
		var glint_col := Color(gold_col.r, gold_col.g, gold_col.b, glint_a)
		var r: float = lerpf(10.0, 32.0, prog)
		canvas.draw_arc(tip_pos, r, 0.0, TAU, 24, glint_col, 2.8, true)
		if prog > 0.55:
			canvas.draw_line(tip_pos + Vector2(-r * 1.2, 0.0), tip_pos + Vector2(r * 1.2, 0.0), glint_col, 3.0, true)
			canvas.draw_line(tip_pos + Vector2(0.0, -r * 1.2), tip_pos + Vector2(0.0, r * 1.2), glint_col, 3.0, true)

	# Wide pale-gold sweep trail during active Halberd Sweep
	if action == Action.HALBERD_SWEEP:
		var arc_a: float = (1.0 - prog) * 0.85
		var arc_col := Color(gold_col.r, gold_col.g, gold_col.b, arc_a)
		var arc_center := Vector2(f * 52.0, -68.0)
		var a_start: float = -1.35 if f > 0.0 else PI + 0.15
		var a_end: float = 0.85 if f > 0.0 else PI + 2.35
		canvas.draw_arc(arc_center, 118.0, a_start, a_end, 26, arc_col, 9.0, true)


func _draw_world_fx(canvas: Node2D) -> void:
	if is_defeated:
		return

	var reduce_flash: bool = _is_reduce_flash_enabled()

	# 1. Falling Spire Shards vertical telegraph beams & plunging glass spears
	if action == Action.SHARDS_TELEGRAPH and not _shard_beam_xs.is_empty():
		var prog: float = _get_action_progress()
		var alpha: float = (0.25 + 0.55 * prog) * (0.55 if reduce_flash else 1.0)
		var half_w: float = lerpf(32.0, 22.0, prog)
		for bx: float in _shard_beam_xs:
			# Vertical pale-gold warning beam
			canvas.draw_rect(
				Rect2(bx - half_w, arena_floor_y - 560.0, half_w * 2.0, 560.0),
				Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, alpha * 0.28),
				true
			)
			# Crisp central warning line
			canvas.draw_line(
				Vector2(bx, arena_floor_y - 560.0),
				Vector2(bx, arena_floor_y),
				Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, alpha),
				2.5 + prog * 2.0,
				true
			)
			# Floor target diamond rune
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(bx, arena_floor_y - 12.0),
				Vector2(bx + 26.0, arena_floor_y),
				Vector2(bx, arena_floor_y + 6.0),
				Vector2(bx - 26.0, arena_floor_y),
			]), Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, alpha))

	elif action == Action.SHARDS_DROP and not _shard_beam_xs.is_empty():
		var prog: float = _shard_drop_progress
		var fade: float = clampf(1.0 - maxf(0.0, (prog - 0.45) / 0.55), 0.0, 1.0)
		var drop_y: float = lerpf(arena_floor_y - 540.0, arena_floor_y, minf(1.0, prog * 3.2))
		for bx: float in _shard_beam_xs:
			# Giant plunging fractured glass spire spear
			var spear := PackedVector2Array([
				Vector2(bx, drop_y),
				Vector2(bx - 24.0, drop_y - 120.0),
				Vector2(bx, drop_y - 260.0),
				Vector2(bx + 24.0, drop_y - 120.0),
			])
			canvas.draw_colored_polygon(spear, Color(COL_GLASS_TEAL.r, COL_GLASS_TEAL.g, COL_GLASS_TEAL.b, fade * 0.92))
			canvas.draw_polyline(PackedVector2Array([
				spear[0], spear[1], spear[2], spear[3], spear[0]
			]), Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, fade), 3.0, true)
			# Ground impact burst ring
			if prog >= 0.25:
				var ring_r: float = lerpf(16.0, 68.0, (prog - 0.25) / 0.75)
				canvas.draw_arc(
					Vector2(bx, arena_floor_y - 4.0),
					ring_r,
					PI,
					TAU,
					20,
					Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, fade * 0.8),
					3.0,
					true
				)

	# 2. Vaulting Slam floor target marker while airborne
	if action == Action.VAULT_ASCEND or (action == Action.VAULT_SLAM and not _vault_slammed):
		var pulse: float = 0.55 + 0.35 * sin(anim_time * 18.0)
		var col := Color(COL_SUNSET_ORANGE.r, COL_SUNSET_ORANGE.g, COL_SUNSET_ORANGE.b, pulse * (0.55 if reduce_flash else 0.9))
		canvas.draw_line(Vector2(_vault_target_x - 68.0, arena_floor_y - 2.0), Vector2(_vault_target_x + 68.0, arena_floor_y - 2.0), col, 4.0, true)
		canvas.draw_line(Vector2(_vault_target_x, global_position.y), Vector2(_vault_target_x, arena_floor_y), Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, 0.28), 2.0, true)

	# 3. Phase 2 Twin Beam Sweep telegraph & active luminous beams
	if action == Action.TWIN_BEAM_TELEGRAPH:
		var prog: float = _get_action_progress()
		var a: float = (0.35 + 0.55 * prog) * (0.55 if reduce_flash else 1.0)
		for ang: float in _beam_angles:
			var end_pt: Vector2 = _beam_origin + Vector2.RIGHT.rotated(ang) * _beam_length
			canvas.draw_line(_beam_origin, end_pt, Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, a), 2.5 + prog * 2.0, true)
		canvas.draw_circle(_beam_origin, lerpf(10.0, 26.0, prog), Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, a * 0.7))

	elif action == Action.TWIN_BEAM_SWEEP:
		var outer_a: float = 0.45 if reduce_flash else 0.72
		for ang: float in _beam_angles:
			var end_pt: Vector2 = _beam_origin + Vector2.RIGHT.rotated(ang) * _beam_length
			canvas.draw_line(_beam_origin, end_pt, Color(COL_GLASS_TEAL.r, COL_GLASS_TEAL.g, COL_GLASS_TEAL.b, outer_a), 28.0, true)
			canvas.draw_line(_beam_origin, end_pt, Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, 0.92), 12.0, true)
		canvas.draw_circle(_beam_origin, 22.0, COL_PALE_GOLD)


# ==============================================================================
# INNER HAZARD: LOW GROUND SHOCKWAVE (Jumpable / Dashable)
# ==============================================================================

class GroundShockwave extends Area2D:
	const COL_GOLD_W: Color = Color("#F6E299")
	const COL_TEAL_W: Color = Color("#4F6D7A")

	var dir: int = 1
	var speed: float = 540.0
	var min_x: float = 140.0
	var max_x: float = 2060.0
	var caster: Node = null
	var _life: float = 2.4
	var _hit_player: bool = false
	var _anim: float = 0.0

	func setup(
		start_pos: Vector2,
		p_dir: int,
		p_speed: float,
		p_min_x: float,
		p_max_x: float,
		p_caster: Node
	) -> void:
		global_position = start_pos
		dir = 1 if p_dir >= 0 else -1
		speed = p_speed
		min_x = p_min_x
		max_x = p_max_x
		caster = p_caster

	func _ready() -> void:
		collision_layer = 32
		collision_mask = 4
		monitoring = true
		monitorable = false

		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		# Low height (42 px) so Farid can cleanly jump over or Dash through
		rect.size = Vector2(64.0, 42.0)
		col.shape = rect
		col.position = Vector2(0.0, -21.0)
		add_child(col)

		area_entered.connect(_on_area_entered)

	func _physics_process(delta: float) -> void:
		_anim += delta
		_life -= delta
		global_position.x += float(dir) * speed * delta
		queue_redraw()
		if _life <= 0.0 or global_position.x < min_x or global_position.x > max_x:
			queue_free()

	func _on_area_entered(area: Area2D) -> void:
		if _hit_player or not (area is Hurtbox):
			return
		var hb: Hurtbox = area as Hurtbox
		var info: DamageInfo = DamageInfo.create(
			1,
			global_position,
			Vector2(float(dir) * 260.0, -200.0),
			false,
			"shockwave",
			caster
		)
		if hb.receive_hit(info):
			_hit_player = true

	func _draw() -> void:
		var f: float = float(dir)
		var crest_h: float = 42.0 + sin(_anim * 22.0) * 4.0
		var pts := PackedVector2Array([
			Vector2(-34.0 * f, 0.0),
			Vector2(-12.0 * f, -crest_h * 0.65),
			Vector2(18.0 * f, -crest_h),
			Vector2(34.0 * f, 0.0),
		])
		draw_colored_polygon(pts, Color(COL_TEAL_W.r, COL_TEAL_W.g, COL_TEAL_W.b, 0.85))
		draw_polyline(PackedVector2Array([
			pts[0], pts[1], pts[2], pts[3]
		]), COL_GOLD_W, 3.0, true)


# ==============================================================================
# INNER HAZARD: PHASE 2 ORBITING PARRYABLE SHARD PROJECTILE
# ==============================================================================

class WardenOrbitShard extends Area2D:
	const COL_GOLD_S: Color = Color("#F6E299")
	const COL_TEAL_S: Color = Color("#4F6D7A")

	var warden: BossBase = null
	var orbit_angle: float = 0.0
	var launch_delay: float = 0.55
	var launched: bool = false
	var reflected: bool = false
	var direction: Vector2 = Vector2.LEFT
	var speed: float = 395.0
	var lifetime: float = 4.6
	var _alive: bool = true
	var _anim: float = 0.0

	func setup(p_warden: BossBase, p_start_angle: float, p_launch_delay: float) -> void:
		warden = p_warden
		orbit_angle = p_start_angle
		launch_delay = p_launch_delay
		if is_instance_valid(warden):
			global_position = warden.global_position + Vector2(cos(orbit_angle) * 78.0, -92.0 + sin(orbit_angle) * 42.0)

	func _ready() -> void:
		collision_layer = 32
		collision_mask = 5
		monitoring = true
		monitorable = false

		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		col.shape = circle
		add_child(col)

		area_entered.connect(_on_area_entered)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		if not _alive:
			return
		_anim += delta

		if not launched:
			launch_delay -= delta
			orbit_angle += 4.6 * delta
			if is_instance_valid(warden) and not warden.is_defeated:
				global_position = warden.global_position + Vector2(cos(orbit_angle) * 78.0, -92.0 + sin(orbit_angle) * 42.0)
			else:
				queue_free()
				return

			if launch_delay <= 0.0:
				launched = true
				var player: Node2D = warden.get_player() if is_instance_valid(warden) else null
				if player != null:
					direction = (player.global_position + Vector2(0.0, -24.0) - global_position).normalized()
				else:
					direction = Vector2(float(warden.facing), 0.0)
				rotation = direction.angle()
				AudioManager.play_sfx("spell_cast")
		else:
			lifetime -= delta
			if lifetime <= 0.0:
				queue_free()
				return
			global_position += direction * speed * delta
			rotation = direction.angle()

		queue_redraw()

	func on_parried() -> void:
		if reflected or not _alive:
			return
		reflected = true
		launched = true
		lifetime = 3.0
		speed = 640.0

		if is_instance_valid(warden) and warden.is_inside_tree() and not warden.is_defeated:
			var target_pos: Vector2 = warden.global_position + Vector2(0.0, -76.0)
			var back: Vector2 = target_pos - global_position
			direction = back.normalized() if back.length_squared() > 4.0 else -direction
		else:
			direction = -direction

		rotation = direction.angle()
		set_deferred("collision_layer", 16)
		set_deferred("collision_mask", 9)
		AudioManager.play_sfx("parry_success")
		queue_redraw()

	func _on_area_entered(area: Area2D) -> void:
		if not _alive or not (area is Hurtbox):
			return
		var hb: Hurtbox = area as Hurtbox

		if reflected:
			var target_owner: Node = hb.get_parent()
			if target_owner != null and target_owner.is_in_group("player"):
				return
			var info: DamageInfo = DamageInfo.create(
				24,
				global_position,
				Vector2(direction.x * 240.0, -140.0),
				false,
				"parry_reflect",
				self
			)
			if hb.receive_hit(info):
				if target_owner != null and target_owner.has_method("on_parried"):
					target_owner.call("on_parried")
				_alive = false
				queue_free()
		else:
			var info: DamageInfo = DamageInfo.create(
				1,
				global_position,
				Vector2(direction.x * 220.0, -150.0),
				true,
				"projectile",
				self
			)
			var accepted: bool = hb.receive_hit(info)
			if accepted and not reflected:
				_alive = false
				queue_free()

	func _on_body_entered(_body: Node2D) -> void:
		if launched and _alive:
			_alive = false
			queue_free()

	func _draw() -> void:
		var core: Color = COL_GOLD_S if reflected else COL_TEAL_S
		var pulse: float = 1.0 + 0.16 * sin(_anim * 16.0)
		draw_circle(Vector2.ZERO, 15.0 * pulse, Color(COL_GOLD_S.r, COL_GOLD_S.g, COL_GOLD_S.b, 0.30))
		draw_colored_polygon(PackedVector2Array([
			Vector2(18.0, 0.0),
			Vector2(2.0, -8.5),
			Vector2(-12.0, 0.0),
			Vector2(2.0, 8.5),
		]), core)
		draw_polyline(PackedVector2Array([
			Vector2(18.0, 0.0),
			Vector2(2.0, -8.5),
			Vector2(-12.0, 0.0),
			Vector2(2.0, 8.5),
			Vector2(18.0, 0.0),
		]), COL_GOLD_S, 2.0, true)
