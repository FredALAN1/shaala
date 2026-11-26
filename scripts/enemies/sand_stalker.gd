class_name SandStalker
extends EnemyBase
## M1 Enemy — Sand Stalker (متربص الرمال)
## Low desert-red & ochre skittering dune beast.
## Patrols ledges safely, spots Farid, crouches with a crisp 0.45s bright-orange
## eye & dorsal-spine telegraph, then executes a fast parryable lunge dash.

@export var lunge_speed: float = 490.0
@export var stalk_speed: float = 165.0
@export var vertical_aggro_tolerance: float = 185.0

var _lunge_direction: int = -1
var _telegraph_progress: float = 0.0
var _lunge_trail: Array[Vector2] = []


func _on_enemy_ready() -> void:
	enemy_id = "sand_stalker"
	max_hp = 35
	current_hp = max_hp
	patrol_speed = 115.0
	detection_range = 420.0
	attack_range = 270.0
	telegraph_duration = 0.45
	attack_duration = 0.32
	recover_duration = 0.65
	stagger_duration = 1.2
	stagger_damage_multiplier = 1.35
	resource_drop = 16.0
	contact_damage = 1
	attack_damage = 1
	knockback_resistance = 0.15
	uses_gravity = true
	supports_dont_look_rule = false


func _enter_state(new_state: State) -> void:
	super._enter_state(new_state)
	match new_state:
		State.TELEGRAPH:
			_telegraph_progress = 0.0
			_lunge_direction = facing
			_lunge_trail.clear()
		State.ATTACK:
			_lunge_direction = facing
			_position_attack_hitbox()
			_activate_attack_hitbox(attack_damage, Vector2(280.0, -170.0), true, "melee")
			AudioManager.play_sfx("dash")
		State.RECOVER:
			_lunge_trail.clear()


func _state_patrol(delta: float) -> void:
	var player: Node2D = get_player()
	if player != null and can_see_player():
		var dy: float = absf(player.global_position.y - global_position.y)
		var dx: float = player.global_position.x - global_position.x
		if dy <= vertical_aggro_tolerance:
			var desired_dir: int = 1 if dx >= 0.0 else -1
			# Stalk cautiously toward player if safe ground ahead
			if absf(dx) <= attack_range and not is_ledge_ahead(desired_dir):
				facing = desired_dir
				change_state(State.TELEGRAPH)
				return
			elif not is_ledge_ahead(desired_dir) and not is_wall_ahead(desired_dir):
				facing = desired_dir
				velocity.x = move_toward(velocity.x, float(facing) * stalk_speed, 1100.0 * delta)
				return

	# Standard safe ledge patrol
	if is_on_floor() and (is_ledge_ahead(facing) or is_wall_ahead(facing)):
		facing = -facing
	velocity.x = move_toward(velocity.x, float(facing) * patrol_speed, 950.0 * delta)


func _state_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
	_telegraph_progress = clampf(1.0 - (state_timer / maxf(0.01, telegraph_duration)), 0.0, 1.0)
	# Track player during early crouch, then lock direction for fair reaction/parry
	if _telegraph_progress < 0.62:
		var player: Node2D = get_player()
		if player != null:
			face_toward(player.global_position.x)
			_lunge_direction = facing
	if state_timer <= 0.0:
		facing = _lunge_direction
		change_state(State.ATTACK)


func _state_attack(delta: float) -> void:
	_position_attack_hitbox()
	if is_ledge_ahead(_lunge_direction) or is_wall_ahead(_lunge_direction):
		velocity.x = 0.0
		change_state(State.RECOVER)
		return

	velocity.x = float(_lunge_direction) * lunge_speed
	_lunge_trail.append(Vector2(-float(_lunge_direction) * 18.0, -14.0))
	if _lunge_trail.size() > 5:
		_lunge_trail.pop_front()
	for i: int in range(_lunge_trail.size()):
		_lunge_trail[i] += Vector2(-float(_lunge_direction) * 260.0 * delta, 0.0)

	if state_timer <= 0.0:
		change_state(State.RECOVER)


func _state_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1250.0 * delta)
	if state_timer <= 0.0:
		change_state(State.PATROL)


func _position_attack_hitbox() -> void:
	if attack_hitbox != null:
		attack_hitbox.position = Vector2(float(facing) * 24.0, -14.0)


func _get_rim_color() -> Color:
	return COL_SUNSET_ORANGE


func _get_death_particle_color() -> Color:
	return COL_DESERT_RED


func _get_health_bar_offset_y() -> float:
	return -48.0


func _draw_entity(canvas: Node2D) -> void:
	var f: float = float(facing)
	var crouch_offset: float = 0.0
	var stretch_x: float = 1.0
	var gait_speed: float = absf(velocity.x) * 0.045
	var bob: float = sin(anim_time * (8.0 + gait_speed)) * (2.2 if absf(velocity.x) > 15.0 else 0.8)

	if state == State.TELEGRAPH:
		crouch_offset = lerpf(0.0, 7.0, _telegraph_progress)
		stretch_x = lerpf(1.0, 0.86, _telegraph_progress)
	elif state == State.ATTACK:
		crouch_offset = 4.0
		stretch_x = 1.24
	elif state == State.STAGGERED:
		crouch_offset = -3.0
		stretch_x = 0.90

	var flash_mix: float = 0.65 if hit_flash_timer > 0.0 else 0.0
	if state == State.STAGGERED:
		flash_mix = maxf(flash_mix, 0.42 + 0.25 * sin(anim_time * 16.0))
	if _is_reduce_flash_enabled():
		flash_mix *= 0.45

	var body_col: Color = COL_DESERT_RED.lerp(COL_PALE_GOLD, flash_mix)
	var ochre_col: Color = COL_MUD_BRICK_OCHRE.lerp(COL_PALE_GOLD, flash_mix)
	var shadow_col: Color = COL_NIGHT_INDIGO.lerp(COL_PALE_GOLD, flash_mix * 0.6)
	var eye_col: Color = COL_SUNSET_ORANGE
	if state == State.TELEGRAPH or state == State.ATTACK:
		eye_col = COL_SUNSET_ORANGE.lerp(COL_PALE_GOLD, 0.65)
	elif state == State.STAGGERED:
		eye_col = COL_PALE_GOLD

	# Motion streaks during lunge dash
	if state == State.ATTACK:
		for i: int in range(_lunge_trail.size()):
			var a: float = (float(i + 1) / float(_lunge_trail.size() + 1)) * 0.45
			var tp: Vector2 = _lunge_trail[i]
			canvas.draw_line(
				tp + Vector2(0.0, -6.0),
				tp + Vector2(-f * 32.0, -2.0),
				Color(COL_SUNSET_ORANGE.r, COL_SUNSET_ORANGE.g, COL_SUNSET_ORANGE.b, a),
				3.0,
				true
			)

	# Ground shadow
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-24.0 * stretch_x, 0.0),
		Vector2(24.0 * stretch_x, 0.0),
		Vector2(18.0 * stretch_x, 4.0),
		Vector2(-18.0 * stretch_x, 4.0),
	]), Color(COL_DEEP_SHADOW.r, COL_DEEP_SHADOW.g, COL_DEEP_SHADOW.b, 0.45))

	# Sweeping desert-beast tail (behind)
	var tail_wag: float = sin(anim_time * 9.0) * 5.0
	var tail_pts := PackedVector2Array([
		Vector2(-16.0 * f * stretch_x, -12.0 + crouch_offset),
		Vector2(-32.0 * f * stretch_x, -18.0 + crouch_offset + tail_wag * 0.5),
		Vector2(-40.0 * f * stretch_x, -10.0 + crouch_offset + tail_wag),
		Vector2(-26.0 * f * stretch_x, -6.0 + crouch_offset + tail_wag * 0.3),
	])
	canvas.draw_colored_polygon(tail_pts, shadow_col)

	# Four scuttling jointed legs
	for leg_idx: int in range(4):
		var phase: float = anim_time * (13.0 if absf(velocity.x) > 20.0 else 3.0) + float(leg_idx) * 1.55
		var foot_x: float = (-15.0 + float(leg_idx) * 10.5) * f * stretch_x + sin(phase) * (5.5 if absf(velocity.x) > 20.0 else 1.0)
		var knee_y: float = -11.0 + crouch_offset * 0.6
		var hip_x: float = (-13.0 + float(leg_idx) * 9.5) * f * stretch_x
		canvas.draw_line(
			Vector2(hip_x, -14.0 + crouch_offset + bob * 0.4),
			Vector2(foot_x, knee_y),
			shadow_col,
			3.0,
			true
		)
		canvas.draw_line(
			Vector2(foot_x, knee_y),
			Vector2(foot_x + f * 2.5, 0.0),
			shadow_col,
			2.6,
			true
		)

	# Low hunched dune-beast torso (deep indigo shadow underside + desert-red back)
	var torso_pts := PackedVector2Array([
		Vector2(-22.0 * f * stretch_x, -10.0 + crouch_offset + bob),
		Vector2(-16.0 * f * stretch_x, -26.0 + crouch_offset + bob),
		Vector2(4.0 * f * stretch_x, -28.0 + crouch_offset + bob),
		Vector2(20.0 * f * stretch_x, -19.0 + crouch_offset + bob),
		Vector2(16.0 * f * stretch_x, -8.0 + crouch_offset + bob),
		Vector2(-12.0 * f * stretch_x, -7.0 + crouch_offset + bob),
	])
	canvas.draw_colored_polygon(torso_pts, body_col)

	# Layered ochre dune-carapace plates
	var carapace_pts := PackedVector2Array([
		Vector2(-15.0 * f * stretch_x, -24.0 + crouch_offset + bob),
		Vector2(-4.0 * f * stretch_x, -29.0 + crouch_offset + bob),
		Vector2(10.0 * f * stretch_x, -25.0 + crouch_offset + bob),
		Vector2(2.0 * f * stretch_x, -17.0 + crouch_offset + bob),
		Vector2(-12.0 * f * stretch_x, -17.0 + crouch_offset + bob),
	])
	canvas.draw_colored_polygon(carapace_pts, ochre_col)

	# Bristling dorsal spines — flare bright sunset-orange during telegraph!
	var spine_flare: float = _telegraph_progress if state == State.TELEGRAPH else (1.0 if state == State.ATTACK else 0.0)
	var spine_col: Color = ochre_col.lerp(COL_SUNSET_ORANGE, spine_flare)
	if spine_flare > 0.65:
		spine_col = spine_col.lerp(COL_PALE_GOLD, (spine_flare - 0.65) * 2.0)
	for s: int in range(3):
		var sx: float = (-12.0 + float(s) * 8.5) * f * stretch_x
		var sy: float = (-25.0 - float(s % 2) * 2.0) + crouch_offset + bob
		var extra_len: float = spine_flare * 9.0
		var spine_pts := PackedVector2Array([
			Vector2(sx - 3.5 * f, sy + 2.0),
			Vector2(sx - (6.0 + extra_len * 0.5) * f, sy - (8.0 + extra_len)),
			Vector2(sx + 3.5 * f, sy + 2.0),
		])
		canvas.draw_colored_polygon(spine_pts, spine_col)

	# Angular desert-skull head & snout
	var head_pts := PackedVector2Array([
		Vector2(12.0 * f * stretch_x, -24.0 + crouch_offset + bob),
		Vector2(24.0 * f * stretch_x, -22.0 + crouch_offset + bob),
		Vector2(31.0 * f * stretch_x, -14.0 + crouch_offset + bob),
		Vector2(22.0 * f * stretch_x, -10.0 + crouch_offset + bob),
		Vector2(12.0 * f * stretch_x, -13.0 + crouch_offset + bob),
	])
	canvas.draw_colored_polygon(head_pts, shadow_col)

	# Swept-back desert horn crest
	var horn_pts := PackedVector2Array([
		Vector2(15.0 * f * stretch_x, -23.0 + crouch_offset + bob),
		Vector2(6.0 * f * stretch_x, -34.0 + crouch_offset + bob - spine_flare * 4.0),
		Vector2(19.0 * f * stretch_x, -21.0 + crouch_offset + bob),
	])
	canvas.draw_colored_polygon(horn_pts, ochre_col)

	# Glowing predator eye + unmistakable telegraph flare glint
	var eye_pos := Vector2(22.5 * f * stretch_x, -17.5 + crouch_offset + bob)
	canvas.draw_circle(eye_pos, 3.2 + spine_flare * 1.8, eye_col)

	if state == State.TELEGRAPH:
		var pulse_r: float = lerpf(8.0, 26.0, _telegraph_progress)
		var glint_a: float = 0.85 * (1.0 - _telegraph_progress * 0.35)
		if _is_reduce_flash_enabled():
			glint_a *= 0.5
		var glint_col := Color(COL_SUNSET_ORANGE.r, COL_SUNSET_ORANGE.g, COL_SUNSET_ORANGE.b, glint_a)
		canvas.draw_arc(eye_pos, pulse_r, 0.0, TAU, 20, glint_col, 2.2, true)
		# Crisp 4-point parry-readiness glint star right before lunge
		if _telegraph_progress >= 0.55:
			var star_len: float = lerpf(6.0, 18.0, (_telegraph_progress - 0.55) / 0.45)
			var star_col := Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, glint_a)
			canvas.draw_line(eye_pos + Vector2(-star_len, 0.0), eye_pos + Vector2(star_len, 0.0), star_col, 2.4, true)
			canvas.draw_line(eye_pos + Vector2(0.0, -star_len), eye_pos + Vector2(0.0, star_len), star_col, 2.4, true)
