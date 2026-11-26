class_name ShardHusk
extends EnemyBase
## M1 Enemy — Shard Husk (طيف الشظايا)
## Tall hovering fractured-glass & night-indigo echo of the Beam.
## Floats gently above the ruins, gathers pale-gold glass shards into a glowing
## telegraph ring for 0.65s, then fires a slow aimed parryable glass-shard projectile.

@export var hover_speed: float = 85.0
@export var preferred_distance: float = 280.0
@export var projectile_speed: float = 370.0
@export var hover_amplitude: float = 12.0

var _telegraph_progress: float = 0.0
var _aim_direction: Vector2 = Vector2.LEFT
var _fire_cooldown: float = 0.4


func _on_enemy_ready() -> void:
	collision_layer = 8
	collision_mask = 3
	enemy_id = "shard_husk"
	max_hp = 45
	current_hp = max_hp
	patrol_speed = 85.0
	detection_range = 560.0
	attack_range = 500.0
	telegraph_duration = 0.65
	attack_duration = 0.25
	recover_duration = 1.15
	stagger_duration = 1.2
	stagger_damage_multiplier = 1.35
	resource_drop = 20.0
	contact_damage = 1
	attack_damage = 1
	knockback_resistance = 0.20
	uses_gravity = false
	supports_dont_look_rule = false


func _enter_state(new_state: State) -> void:
	super._enter_state(new_state)
	match new_state:
		State.TELEGRAPH:
			_telegraph_progress = 0.0
			var player: Node2D = get_player()
			if player != null:
				face_toward(player.global_position.x)
				_aim_direction = (player.global_position + Vector2(0.0, -24.0) - _get_muzzle_world_position()).normalized()
		State.ATTACK:
			_fire_glass_shard()
		State.RECOVER:
			_fire_cooldown = recover_duration


func _state_patrol(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var bob_vel_y: float = cos(anim_time * 2.4) * hover_amplitude * 2.4
	var player: Node2D = get_player()

	if player != null and can_see_player():
		face_toward(player.global_position.x)
		var to_player: Vector2 = player.global_position - global_position
		var horiz_dist: float = absf(to_player.x)
		var desired_vx: float = 0.0
		if horiz_dist > preferred_distance + 70.0:
			desired_vx = signf(to_player.x) * hover_speed
		elif horiz_dist < preferred_distance - 105.0:
			desired_vx = -signf(to_player.x) * hover_speed * 0.85

		var desired_y: float = player.global_position.y - 75.0
		var dy: float = clampf(desired_y - global_position.y, -90.0, 90.0)
		velocity.x = move_toward(velocity.x, desired_vx, 340.0 * delta)
		velocity.y = move_toward(velocity.y, dy * 0.9 + bob_vel_y, 280.0 * delta)

		if _fire_cooldown <= 0.0 and to_player.length() <= attack_range:
			change_state(State.TELEGRAPH)
		return

	# Gentle drift around home anchor when idle/patrolling
	var home_offset: Vector2 = _spawn_position - global_position
	var patrol_target_x: float = sin(anim_time * 0.8) * 65.0
	velocity.x = move_toward(velocity.x, clampf(home_offset.x + patrol_target_x, -hover_speed, hover_speed), 260.0 * delta)
	velocity.y = move_toward(velocity.y, home_offset.y * 1.4 + bob_vel_y, 240.0 * delta)


func _state_telegraph(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 420.0 * delta)
	_telegraph_progress = clampf(1.0 - (state_timer / maxf(0.01, telegraph_duration)), 0.0, 1.0)
	if _telegraph_progress < 0.78:
		var player: Node2D = get_player()
		if player != null:
			face_toward(player.global_position.x)
			_aim_direction = (player.global_position + Vector2(0.0, -24.0) - _get_muzzle_world_position()).normalized()
	if state_timer <= 0.0:
		change_state(State.ATTACK)


func _state_attack(delta: float) -> void:
	velocity = velocity.move_toward(Vector2(-_aim_direction.x * 55.0, 0.0), 420.0 * delta)
	if state_timer <= 0.0:
		change_state(State.RECOVER)


func _state_recover(delta: float) -> void:
	var bob_vel_y: float = cos(anim_time * 2.4) * hover_amplitude * 1.8
	velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)
	velocity.y = move_toward(velocity.y, bob_vel_y, 260.0 * delta)
	if state_timer <= 0.0:
		change_state(State.PATROL)


func _get_muzzle_world_position() -> Vector2:
	return global_position + Vector2(float(facing) * 20.0, -40.0)


func _fire_glass_shard() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var dir: Vector2 = _aim_direction
	if dir.length_squared() < 0.01:
		dir = Vector2(float(facing), 0.0)
	var proj := GlassShardProjectile.new()
	proj.setup(
		_get_muzzle_world_position(),
		dir.normalized(),
		projectile_speed,
		attack_damage,
		self
	)
	parent_node.add_child(proj)
	AudioManager.play_sfx("spell_cast")


func _get_rim_color() -> Color:
	return COL_PALE_GOLD


func _get_death_particle_color() -> Color:
	return COL_GLASS_TEAL


func _get_health_bar_offset_y() -> float:
	return -86.0


func _draw_entity(canvas: Node2D) -> void:
	var f: float = float(facing)
	var float_y: float = sin(anim_time * 3.1) * 4.5
	var sway_x: float = sin(anim_time * 2.0) * 3.0

	var flash_mix: float = 0.65 if hit_flash_timer > 0.0 else 0.0
	if state == State.STAGGERED:
		flash_mix = maxf(flash_mix, 0.45 + 0.25 * sin(anim_time * 16.0))
	if _is_reduce_flash_enabled():
		flash_mix *= 0.45

	var robe_col: Color = COL_NIGHT_INDIGO.lerp(COL_PALE_GOLD, flash_mix)
	var shadow_col: Color = COL_DEEP_SHADOW.lerp(COL_PALE_GOLD, flash_mix * 0.5)
	var glass_col: Color = COL_GLASS_TEAL.lerp(COL_PALE_GOLD, flash_mix)
	var seam_col: Color = COL_PALE_GOLD

	# Faint ethereal ground reflection beneath floating husk
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-16.0, 12.0),
		Vector2(16.0, 12.0),
		Vector2(11.0, 16.0),
		Vector2(-11.0, 16.0),
	]), Color(COL_NIGHT_INDIGO.r, COL_NIGHT_INDIGO.g, COL_NIGHT_INDIGO.b, 0.35))

	# Trailing tattered night-indigo cloak shreds
	for shred: int in range(3):
		var sx: float = (-10.0 + float(shred) * 10.0) + sway_x * 0.4
		var tip_sway: float = sin(anim_time * 4.2 + float(shred) * 1.3) * 6.0
		var shred_pts := PackedVector2Array([
			Vector2(sx - 5.0, -16.0 + float_y),
			Vector2(sx + 5.0, -16.0 + float_y),
			Vector2(sx + tip_sway, 8.0 + float(shred % 2) * 5.0 + float_y),
		])
		canvas.draw_colored_polygon(shred_pts, shadow_col)

	# Tall slender cloaked echo torso
	var robe_pts := PackedVector2Array([
		Vector2(-18.0, -14.0 + float_y),
		Vector2(-15.0, -48.0 + float_y),
		Vector2(-7.0, -64.0 + float_y),
		Vector2(7.0, -64.0 + float_y),
		Vector2(16.0, -48.0 + float_y),
		Vector2(17.0, -14.0 + float_y),
		Vector2(6.0, -18.0 + float_y),
		Vector2(-6.0, -18.0 + float_y),
	])
	canvas.draw_colored_polygon(robe_pts, robe_col)

	# Fractured glass mantle shoulders
	var left_glass := PackedVector2Array([
		Vector2(-22.0, -40.0 + float_y),
		Vector2(-14.0, -58.0 + float_y),
		Vector2(-6.0, -46.0 + float_y),
	])
	var right_glass := PackedVector2Array([
		Vector2(22.0, -40.0 + float_y),
		Vector2(14.0, -58.0 + float_y),
		Vector2(6.0, -46.0 + float_y),
	])
	canvas.draw_colored_polygon(left_glass, glass_col)
	canvas.draw_colored_polygon(right_glass, glass_col)

	# Hollow vertical pale-gold Beam fracture seam down torso
	var seam_w: float = 2.4 + (2.0 * _telegraph_progress if state == State.TELEGRAPH else 0.0)
	canvas.draw_line(
		Vector2(f * 3.0, -56.0 + float_y),
		Vector2(f * 3.0, -24.0 + float_y),
		seam_col,
		seam_w,
		true
	)

	# Floating fractured-glass Najdi diamond crown / mask
	var crown_y: float = -70.0 + float_y + sin(anim_time * 4.5) * 2.0
	var crown_pts := PackedVector2Array([
		Vector2(0.0, crown_y - 13.0),
		Vector2(11.0, crown_y),
		Vector2(0.0, crown_y + 11.0),
		Vector2(-11.0, crown_y),
	])
	canvas.draw_colored_polygon(crown_pts, glass_col)
	canvas.draw_polyline(PackedVector2Array([
		crown_pts[0], crown_pts[1], crown_pts[2], crown_pts[3], crown_pts[0]
	]), seam_col, 1.5, true)
	# Inner hollow fracture eye slit
	canvas.draw_line(
		Vector2(f * 3.0, crown_y - 5.0),
		Vector2(f * 3.0, crown_y + 4.0),
		seam_col,
		2.2,
		true
	)

	# Orbiting glass shards — gather into a glowing pale-gold ring during 0.65s telegraph!
	var muzzle_local := Vector2(f * 20.0, -40.0 + float_y)
	var shard_count: int = 5
	for i: int in range(shard_count):
		var orbit_r: float = 34.0
		var orbit_speed: float = 2.2
		var center: Vector2 = Vector2(0.0, -42.0 + float_y)
		if state == State.TELEGRAPH:
			center = center.lerp(muzzle_local, _telegraph_progress)
			orbit_r = lerpf(36.0, 9.0, _telegraph_progress)
			orbit_speed = 7.5
		elif state == State.STAGGERED:
			orbit_r = 46.0
			orbit_speed = 0.8

		var angle: float = anim_time * orbit_speed + float(i) * (TAU / float(shard_count))
		var pos: Vector2 = center + Vector2(cos(angle) * orbit_r, sin(angle) * orbit_r * 0.72)
		var shard_col: Color = glass_col.lerp(COL_PALE_GOLD, 0.35 + (0.65 * _telegraph_progress if state == State.TELEGRAPH else 0.0))
		var shard_pts := PackedVector2Array([
			pos + Vector2(0.0, -7.0).rotated(angle),
			pos + Vector2(3.5, 0.0).rotated(angle),
			pos + Vector2(0.0, 7.0).rotated(angle),
			pos + Vector2(-3.5, 0.0).rotated(angle),
		])
		canvas.draw_colored_polygon(shard_pts, shard_col)

	# Crisp telegraph ring + aimed sightline glint
	if state == State.TELEGRAPH:
		var ring_r: float = lerpf(32.0, 11.0, _telegraph_progress)
		var ring_a: float = 0.45 + 0.50 * _telegraph_progress
		if _is_reduce_flash_enabled():
			ring_a *= 0.5
		var ring_col := Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, ring_a)
		canvas.draw_arc(muzzle_local, ring_r, 0.0, TAU, 24, ring_col, 2.2, true)
		# Aimed sightline hint
		var sight_end: Vector2 = muzzle_local + _aim_direction * (45.0 + 75.0 * _telegraph_progress)
		canvas.draw_line(
			muzzle_local,
			sight_end,
			Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, ring_a * 0.45),
			1.5,
			true
		)


## Self-contained parryable glass-shard projectile spawned by ShardHusk.
## When parried by Farid, on_parried() reflects the shard back at enemies!
class GlassShardProjectile extends Area2D:
	const COL_GLASS_TEAL_P: Color = Color("#4F6D7A")
	const COL_PALE_GOLD_P: Color = Color("#F6E299")
	const COL_NIGHT_INDIGO_P: Color = Color("#161B33")

	var direction: Vector2 = Vector2.RIGHT
	var speed: float = 370.0
	var damage: int = 1
	var source_enemy: Node2D = null
	var reflected: bool = false
	var lifetime: float = 4.2
	var _alive: bool = true
	var _anim: float = 0.0

	func setup(
		spawn_pos: Vector2,
		dir: Vector2,
		proj_speed: float,
		proj_damage: int,
		caster: Node2D
	) -> void:
		global_position = spawn_pos
		direction = dir.normalized()
		speed = proj_speed
		damage = proj_damage
		source_enemy = caster
		rotation = direction.angle()

	func _ready() -> void:
		# Layer 6 (enemy_hitbox = 32); detects layer 3 (player = 4) + layer 1 (world = 1)
		collision_layer = 32
		collision_mask = 5
		monitoring = true
		monitorable = false

		var shape_node := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 11.0
		shape_node.shape = circle
		add_child(shape_node)

		area_entered.connect(_on_area_entered)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		if not _alive:
			return
		_anim += delta
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
		lifetime = 3.0
		speed *= 1.55
		damage = 22

		# Aim reflected shard right back at the Shard Husk (or straight reverse if gone)
		if is_instance_valid(source_enemy) and source_enemy.is_inside_tree():
			var target_pos: Vector2 = source_enemy.global_position + Vector2(0.0, -38.0)
			var back_vec: Vector2 = target_pos - global_position
			if back_vec.length_squared() > 4.0:
				direction = back_vec.normalized()
			else:
				direction = -direction
		else:
			direction = -direction

		rotation = direction.angle()
		# Switch to layer 5 (player_hitbox = 16); detects layer 4 (enemy = 8) + layer 1 (world = 1)
		set_deferred("collision_layer", 16)
		set_deferred("collision_mask", 9)
		AudioManager.play_sfx("parry_success")
		queue_redraw()

	func _on_area_entered(area: Area2D) -> void:
		if not _alive:
			return
		if not (area is Hurtbox):
			return
		var target_hurtbox: Hurtbox = area as Hurtbox

		if reflected:
			var target_owner: Node = target_hurtbox.get_parent()
			if target_owner != null and target_owner.is_in_group("player"):
				return
			var info: DamageInfo = DamageInfo.create(
				damage,
				global_position,
				Vector2(direction.x * 260.0, -130.0),
				false,
				"parry_reflect",
				self
			)
			if target_hurtbox.receive_hit(info):
				if target_owner != null and target_owner.has_method("on_parried"):
					target_owner.call("on_parried")
				_shatter()
		else:
			var info: DamageInfo = DamageInfo.create(
				damage,
				global_position,
				Vector2(direction.x * 220.0, -140.0),
				true,
				"projectile",
				self
			)
			# Note: if Farid parries this projectile, his Hurtbox calls on_parried()
			# inside receive_hit() and sets reflected = true — so do NOT shatter!
			var accepted: bool = target_hurtbox.receive_hit(info)
			if accepted and not reflected:
				_shatter()

	func _on_body_entered(_body: Node2D) -> void:
		if not _alive:
			return
		_shatter()

	func _shatter() -> void:
		_alive = false
		queue_free()

	func _draw() -> void:
		var core_col: Color = COL_PALE_GOLD_P if reflected else COL_GLASS_TEAL_P
		var glow_col: Color = Color(COL_PALE_GOLD_P.r, COL_PALE_GOLD_P.g, COL_PALE_GOLD_P.b, 0.55)
		var pulse: float = 1.0 + 0.14 * sin(_anim * 18.0)

		# Outer luminous aura
		draw_circle(Vector2.ZERO, 14.0 * pulse, Color(glow_col.r, glow_col.g, glow_col.b, 0.28))

		# Trailing shard tail
		draw_colored_polygon(PackedVector2Array([
			Vector2(-24.0, 0.0),
			Vector2(-6.0, -5.0),
			Vector2(-6.0, 5.0),
		]), glow_col)

		# Main fractured spearhead crystal
		draw_colored_polygon(PackedVector2Array([
			Vector2(17.0, 0.0),
			Vector2(2.0, -7.5),
			Vector2(-10.0, 0.0),
			Vector2(2.0, 7.5),
		]), core_col)

		# Bright inner pale-gold edge highlight
		draw_polyline(PackedVector2Array([
			Vector2(17.0, 0.0),
			Vector2(2.0, -7.5),
			Vector2(-10.0, 0.0),
			Vector2(2.0, 7.5),
			Vector2(17.0, 0.0),
		]), COL_PALE_GOLD_P, 1.8, true)
