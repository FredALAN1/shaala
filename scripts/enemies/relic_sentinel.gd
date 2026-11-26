class_name RelicSentinel
extends EnemyBase
## M1 Enemy — Relic Sentinel (حارس الأثر)
## Heavy Najdi-stone & dark-bronze ruined construct.
## Front tower shield blocks frontal low-tier melee strikes unless staggered by Parry,
## struck with Flame Spell, or flanked from behind!
## 0.60s overhead slam telegraph -> heavy parryable cleave.

const COL_DARK_BRONZE: Color = Color("#3D342E")
const COL_BRONZE_TRIM: Color = Color("#B5804A")

@export var advance_speed: float = 85.0
@export var turn_delay: float = 0.45

var _telegraph_progress: float = 0.0
var _attack_progress: float = 0.0
var _shield_block_flash: float = 0.0
var _turn_timer: float = 0.0


func _on_enemy_ready() -> void:
	enemy_id = "relic_sentinel"
	max_hp = 75
	current_hp = max_hp
	patrol_speed = 65.0
	detection_range = 440.0
	attack_range = 135.0
	telegraph_duration = 0.60
	attack_duration = 0.28
	recover_duration = 0.90
	stagger_duration = 1.2
	stagger_damage_multiplier = 1.35
	resource_drop = 30.0
	contact_damage = 1
	attack_damage = 2
	knockback_resistance = 0.72
	uses_gravity = true
	supports_dont_look_rule = false


func _physics_process(delta: float) -> void:
	if _shield_block_flash > 0.0:
		_shield_block_flash = maxf(0.0, _shield_block_flash - delta)
	if _turn_timer > 0.0:
		_turn_timer = maxf(0.0, _turn_timer - delta)
	super._physics_process(delta)


func _enter_state(new_state: State) -> void:
	super._enter_state(new_state)
	match new_state:
		State.TELEGRAPH:
			_telegraph_progress = 0.0
		State.ATTACK:
			_attack_progress = 0.0
			_position_attack_hitbox()
			_activate_attack_hitbox(attack_damage, Vector2(360.0, -200.0), true, "melee")
			AudioManager.play_sfx("dagger_swing")
			EventBus.camera_shake_requested.emit(4.5, 0.12)


func _state_patrol(delta: float) -> void:
	var player: Node2D = get_player()
	if player != null and can_see_player():
		var dy: float = absf(player.global_position.y - global_position.y)
		var dx: float = player.global_position.x - global_position.x
		if dy <= 170.0:
			var desired_dir: int = 1 if dx >= 0.0 else -1
			# Deliberate turn delay gives Farid a fair window to Dash behind and flank!
			if desired_dir != facing:
				if _turn_timer <= 0.0:
					facing = desired_dir
					_turn_timer = turn_delay
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
				return

			if absf(dx) <= attack_range:
				change_state(State.TELEGRAPH)
				return

			if not is_ledge_ahead(facing) and not is_wall_ahead(facing):
				velocity.x = move_toward(velocity.x, float(facing) * advance_speed, 620.0 * delta)
				return
			else:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
				return

	# Heavy measured patrol
	if is_on_floor() and (is_ledge_ahead(facing) or is_wall_ahead(facing)):
		facing = -facing
	velocity.x = move_toward(velocity.x, float(facing) * patrol_speed, 540.0 * delta)


func _state_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	_telegraph_progress = clampf(1.0 - (state_timer / maxf(0.01, telegraph_duration)), 0.0, 1.0)
	if state_timer <= 0.0:
		change_state(State.ATTACK)


func _state_attack(delta: float) -> void:
	_attack_progress = clampf(1.0 - (state_timer / maxf(0.01, attack_duration)), 0.0, 1.0)
	_position_attack_hitbox()
	# Slight forward weight lunge during initial cleave swing
	if _attack_progress < 0.45 and not is_ledge_ahead(facing) and not is_wall_ahead(facing):
		velocity.x = float(facing) * 145.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	if state_timer <= 0.0:
		change_state(State.RECOVER)


func _state_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 950.0 * delta)
	if state_timer <= 0.0:
		var player: Node2D = get_player()
		if player != null and can_see_player():
			_turn_timer = turn_delay * 0.65
		change_state(State.PATROL)


func is_shield_raised() -> bool:
	if is_dead:
		return false
	if state == State.STAGGERED or state == State.ATTACK or state == State.HURT:
		return false
	# Shield drops halfway through overhead cleave windup when raising weapon high
	if state == State.TELEGRAPH and _telegraph_progress > 0.50:
		return false
	return true


func _should_block_damage(info: DamageInfo) -> bool:
	if not is_shield_raised():
		return false
	# Flame Spell and reflected parry projectiles pierce the stone shield cleanly!
	if info.damage_type == "flame" or info.damage_type == "spell" or info.damage_type == "parry_reflect":
		return false
	# Flanking from behind bypasses the frontal shield!
	var hit_from_front: bool = (info.source_position.x - global_position.x) * float(facing) > -10.0
	if not hit_from_front:
		return false
	# Tier 2 blazing Flame Dagger breaks through frontal guard; Tier 0 & Tier 1 are blocked!
	if GameState.get_dagger_tier() >= 2:
		return false
	return true


func _on_damage_blocked(info: DamageInfo) -> void:
	_shield_block_flash = 0.24
	AudioManager.play_sfx("parry_whiff")
	EventBus.camera_shake_requested.emit(3.0, 0.08)
	var push_dir: float = signf(global_position.x - info.source_position.x)
	if is_zero_approx(push_dir):
		push_dir = -float(facing)
	velocity.x = push_dir * 65.0


func _can_enter_hurt_state(info: DamageInfo) -> bool:
	# Flame Spell briefly flinches the heavy sentinel even out of patrol
	if info.damage_type == "flame" or info.damage_type == "spell":
		return state != State.ATTACK
	return false


func _position_attack_hitbox() -> void:
	if attack_hitbox != null:
		attack_hitbox.position = Vector2(float(facing) * 66.0, -34.0)


func _get_rim_color() -> Color:
	return COL_PALE_GOLD


func _get_death_particle_color() -> Color:
	return COL_MUD_BRICK_OCHRE


func _get_health_bar_offset_y() -> float:
	return -98.0


func _draw_entity(canvas: Node2D) -> void:
	var f: float = float(facing)
	var stride: float = sin(anim_time * 5.2) * (3.5 if absf(velocity.x) > 10.0 else 0.0)
	var stomp_bob: float = absf(stride) * 0.45
	var stagger_lean: float = -8.0 * f if state == State.STAGGERED else 0.0

	var flash_mix: float = 0.65 if hit_flash_timer > 0.0 else 0.0
	if state == State.STAGGERED:
		flash_mix = maxf(flash_mix, 0.45 + 0.25 * sin(anim_time * 16.0))
	if _is_reduce_flash_enabled():
		flash_mix *= 0.45

	var stone_col: Color = COL_MUD_BRICK_OCHRE.lerp(COL_PALE_GOLD, flash_mix)
	var bronze_col: Color = COL_DARK_BRONZE.lerp(COL_PALE_GOLD, flash_mix)
	var trim_col: Color = COL_BRONZE_TRIM.lerp(COL_PALE_GOLD, flash_mix)
	var shadow_col: Color = COL_NIGHT_INDIGO.lerp(COL_PALE_GOLD, flash_mix * 0.5)

	# Ground weight shadow
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-32.0, 0.0),
		Vector2(32.0, 0.0),
		Vector2(26.0, 5.0),
		Vector2(-26.0, 5.0),
	]), Color(COL_DEEP_SHADOW.r, COL_DEEP_SHADOW.g, COL_DEEP_SHADOW.b, 0.5))

	# Heavy dark-bronze pillar legs
	canvas.draw_rect(Rect2(-18.0 + stride * 0.6, -24.0, 12.0, 24.0), bronze_col, true)
	canvas.draw_rect(Rect2(6.0 - stride * 0.6, -24.0, 12.0, 24.0), bronze_col, true)

	# Monolithic Najdi-stone torso with stepped shurfat battlements on shoulders
	var body_pts := PackedVector2Array([
		Vector2(-24.0 + stagger_lean * 0.4, -22.0 - stomp_bob),
		Vector2(-27.0 + stagger_lean * 0.8, -68.0 - stomp_bob),
		Vector2(-20.0 + stagger_lean, -76.0 - stomp_bob),
		Vector2(-12.0 + stagger_lean, -70.0 - stomp_bob),
		Vector2(12.0 + stagger_lean, -70.0 - stomp_bob),
		Vector2(20.0 + stagger_lean, -76.0 - stomp_bob),
		Vector2(27.0 + stagger_lean * 0.8, -68.0 - stomp_bob),
		Vector2(24.0 + stagger_lean * 0.4, -22.0 - stomp_bob),
	])
	canvas.draw_colored_polygon(body_pts, stone_col)

	# Dark-bronze architectural breastplate frame
	var armor_pts := PackedVector2Array([
		Vector2(-20.0 + stagger_lean * 0.6, -30.0 - stomp_bob),
		Vector2(-22.0 + stagger_lean * 0.8, -62.0 - stomp_bob),
		Vector2(22.0 + stagger_lean * 0.8, -62.0 - stomp_bob),
		Vector2(20.0 + stagger_lean * 0.6, -30.0 - stomp_bob),
	])
	canvas.draw_colored_polygon(armor_pts, shadow_col)

	# Iconic Najdi triangular ventilation slits (furjat) glowing warm amber/gold
	var slit_col: Color = COL_PALE_GOLD if state == State.TELEGRAPH or state == State.STAGGERED else COL_SUNSET_ORANGE
	for idx: int in range(3):
		var sx: float = (-10.0 + float(idx) * 10.0) + stagger_lean * 0.7
		var sy: float = -47.0 - stomp_bob
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(sx, sy - 6.0),
			Vector2(sx + 4.0, sy + 2.0),
			Vector2(sx - 4.0, sy + 2.0),
		]), slit_col)

	# Recessed bronze helmet crest
	var head_pts := PackedVector2Array([
		Vector2(-11.0 + stagger_lean, -70.0 - stomp_bob),
		Vector2(-9.0 + stagger_lean, -86.0 - stomp_bob),
		Vector2(0.0 + stagger_lean, -91.0 - stomp_bob),
		Vector2(9.0 + stagger_lean, -86.0 - stomp_bob),
		Vector2(11.0 + stagger_lean, -70.0 - stomp_bob),
	])
	canvas.draw_colored_polygon(head_pts, bronze_col)
	# Glowing visor slit
	canvas.draw_line(
		Vector2((2.0 if f > 0.0 else -8.0) + stagger_lean, -79.0 - stomp_bob),
		Vector2((8.0 if f > 0.0 else -2.0) + stagger_lean, -79.0 - stomp_bob),
		slit_col,
		2.6,
		true
	)

	# Heavy stone-bronze overhead cleaver blade
	var blade_pivot := Vector2(-8.0 * f + stagger_lean * 0.7, -56.0 - stomp_bob)
	var blade_angle: float = -0.35 * f
	if state == State.TELEGRAPH:
		blade_angle = lerpf(-0.35 * f, -2.35 * f, _telegraph_progress)
	elif state == State.ATTACK:
		blade_angle = lerpf(-2.35 * f, 0.85 * f, minf(1.0, _attack_progress * 1.8))
	elif state == State.RECOVER:
		blade_angle = lerpf(0.85 * f, -0.35 * f, 1.0 - (state_timer / maxf(0.01, recover_duration)))
	elif state == State.STAGGERED:
		blade_angle = -1.15 * f

	var handle_tip: Vector2 = blade_pivot + Vector2(0.0, -56.0).rotated(blade_angle)
	var perp: Vector2 = Vector2(f, 0.0).rotated(blade_angle)
	canvas.draw_line(blade_pivot, handle_tip, bronze_col, 4.5, true)
	var cleaver_pts := PackedVector2Array([
		blade_pivot + Vector2(0.0, -24.0).rotated(blade_angle),
		handle_tip + Vector2(0.0, -14.0).rotated(blade_angle),
		handle_tip + Vector2(0.0, -8.0).rotated(blade_angle) + perp * 16.0,
		blade_pivot + Vector2(0.0, -26.0).rotated(blade_angle) + perp * 13.0,
	])
	var blade_col: Color = trim_col
	if state == State.TELEGRAPH:
		blade_col = trim_col.lerp(COL_PALE_GOLD, _telegraph_progress * 0.85)
	elif state == State.ATTACK:
		blade_col = COL_PALE_GOLD
	canvas.draw_colored_polygon(cleaver_pts, blade_col)

	# Telegraph overhead parry glint & cleave arc preview
	if state == State.TELEGRAPH:
		var glint_a: float = 0.5 + 0.45 * _telegraph_progress
		if _is_reduce_flash_enabled():
			glint_a *= 0.5
		var glint_col := Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, glint_a)
		var star_pos: Vector2 = handle_tip + Vector2(0.0, -10.0).rotated(blade_angle)
		var star_r: float = lerpf(6.0, 22.0, _telegraph_progress)
		canvas.draw_arc(star_pos, star_r, 0.0, TAU, 20, glint_col, 2.2, true)
		if _telegraph_progress > 0.55:
			canvas.draw_line(star_pos + Vector2(-star_r, 0.0), star_pos + Vector2(star_r, 0.0), glint_col, 2.5, true)
			canvas.draw_line(star_pos + Vector2(0.0, -star_r), star_pos + Vector2(0.0, star_r), glint_col, 2.5, true)
	elif state == State.ATTACK:
		# Dramatic cleave slash arc
		var arc_center := Vector2(f * 34.0, -44.0)
		var arc_col := Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, (1.0 - _attack_progress) * 0.85)
		var start_a: float = -1.6 if f > 0.0 else PI + 0.3
		var end_a: float = 0.65 if f > 0.0 else PI + 1.9
		canvas.draw_arc(arc_center, 62.0, start_a, end_a, 18, arc_col, 6.0, true)

	# Heavy Najdi tower shield (held forward when guarding; swung aside when staggered/cleaving)
	var shield_raised: bool = is_shield_raised()
	var shield_x: float = (28.0 * f) if shield_raised else (14.0 * f + stagger_lean)
	var shield_y: float = (-42.0 - stomp_bob) if shield_raised else (-34.0 - stomp_bob)
	var shield_w: float = 12.0
	var shield_h: float = 52.0 if shield_raised else 40.0
	var shield_col: Color = bronze_col
	if _shield_block_flash > 0.0:
		shield_col = COL_PALE_GOLD
	var shield_rect := Rect2(shield_x - shield_w * 0.5, shield_y - shield_h * 0.5, shield_w, shield_h)
	canvas.draw_rect(shield_rect, shield_col, true)
	canvas.draw_rect(shield_rect, trim_col, false, 2.0)

	# Carved Najdi diamond emblem on front face of shield
	var emblem_c := Vector2(shield_x + f * 2.0, shield_y)
	canvas.draw_colored_polygon(PackedVector2Array([
		emblem_c + Vector2(0.0, -9.0),
		emblem_c + Vector2(4.0, 0.0),
		emblem_c + Vector2(0.0, 9.0),
		emblem_c + Vector2(-4.0, 0.0),
	]), COL_PALE_GOLD if _shield_block_flash > 0.0 else stone_col)

	# Bronze block clang spark ring when blocking low-tier frontal melee
	if _shield_block_flash > 0.0:
		var t: float = 1.0 - (_shield_block_flash / 0.24)
		var spark_c := Vector2(shield_x + f * 8.0, shield_y - 4.0)
		var spark_col := Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, 1.0 - t)
		canvas.draw_arc(spark_c, lerpf(8.0, 34.0, t), 0.0, TAU, 18, spark_col, 2.8, true)
