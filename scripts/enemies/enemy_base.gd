class_name EnemyBase
extends CharacterBody2D
## Base class for all SHAALA (شعلة) enemies.
## Provides a reusable AI state machine, ledge/wall detection, player sensing,
## parry-stagger vulnerability (1.2s, 1.35x damage), hit flash, knockback,
## painterly death burst + Resource reward, and M2/M3 Don't-Look hook.

enum State {
	IDLE,
	PATROL,
	TELEGRAPH,
	ATTACK,
	RECOVER,
	STAGGERED,
	HURT,
	DEAD,
}

signal died(enemy: EnemyBase)
signal state_changed(old_state: State, new_state: State)
signal parried_staggered(duration: float)

const SILHOUETTE_SHADER_PATH: String = "res://assets/placeholder/shaders/painterly_silhouette.gdshader"

const COL_MUD_BRICK_OCHRE: Color = Color("#C68B59")
const COL_SUNSET_ORANGE: Color = Color("#E07A3C")
const COL_DESERT_RED: Color = Color("#A84432")
const COL_NIGHT_INDIGO: Color = Color("#161B33")
const COL_DEEP_SHADOW: Color = Color("#0D1021")
const COL_PALE_GOLD: Color = Color("#F6E299")
const COL_WARM_SAND: Color = Color("#E8C49A")
const COL_GLASS_TEAL: Color = Color("#4F6D7A")

@export var enemy_id: String = "enemy_base"
@export var max_hp: int = 35
@export var patrol_speed: float = 110.0
@export var gravity: float = 1550.0
@export var max_fall_speed: float = 950.0
@export var uses_gravity: bool = true
@export var detection_range: float = 420.0
@export var attack_range: float = 220.0
@export var telegraph_duration: float = 0.50
@export var attack_duration: float = 0.30
@export var recover_duration: float = 0.70
@export var stagger_duration: float = 1.2
@export var stagger_damage_multiplier: float = 1.35
@export var resource_drop: float = 16.0
@export var contact_damage: int = 1
@export var attack_damage: int = 1
@export var knockback_resistance: float = 0.0
@export var initial_facing: int = -1
## Architectural hook for Milestone 2 / 3 Jinn zones ("Don't-Look" rule).
@export var supports_dont_look_rule: bool = false

var current_hp: int = 35
var state: State = State.PATROL
var state_timer: float = 0.0
var facing: int = -1
var hit_flash_timer: float = 0.0
var anim_time: float = 0.0
var is_dead: bool = false

var visual: Node2D = null
var hurtbox: Hurtbox = null
var attack_hitbox: Hitbox = null
var contact_hitbox: Hitbox = null
var ledge_ray_left: RayCast2D = null
var ledge_ray_right: RayCast2D = null
var wall_ray_left: RayCast2D = null
var wall_ray_right: RayCast2D = null

var _silhouette_material: ShaderMaterial = null
var _stagger_ring_timer: float = 0.0
var _death_timer: float = 0.0
var _death_particles: Array[Dictionary] = []
var _spawn_position: Vector2 = Vector2.ZERO
var _player_looking_duration: float = 0.0


func _ready() -> void:
	# Physics Layer Contract:
	# Enemy CharacterBody2D: layer 4 (bitmask 8), mask 1+2 (world + one_way = 3)
	collision_layer = 8
	collision_mask = 3
	add_to_group("enemies")

	_spawn_position = global_position
	current_hp = max_hp
	facing = -1 if initial_facing < 0 else 1

	_bind_nodes()
	_setup_visual_shader()
	_configure_combat_boxes()
	_on_enemy_ready()
	change_state(State.PATROL)


func _bind_nodes() -> void:
	visual = get_node_or_null("Visual") as Node2D
	if visual == null:
		visual = Node2D.new()
		visual.name = "Visual"
		add_child(visual)
	if not visual.draw.is_connected(_on_visual_draw):
		visual.draw.connect(_on_visual_draw)

	hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	attack_hitbox = get_node_or_null("AttackHitbox") as Hitbox
	contact_hitbox = get_node_or_null("ContactHitbox") as Hitbox

	ledge_ray_left = get_node_or_null("LedgeRayLeft") as RayCast2D
	ledge_ray_right = get_node_or_null("LedgeRayRight") as RayCast2D
	wall_ray_left = get_node_or_null("WallRayLeft") as RayCast2D
	wall_ray_right = get_node_or_null("WallRayRight") as RayCast2D

	for ray: RayCast2D in [ledge_ray_left, ledge_ray_right]:
		if ray != null:
			ray.collision_mask = 3
			ray.enabled = true

	for ray: RayCast2D in [wall_ray_left, wall_ray_right]:
		if ray != null:
			ray.collision_mask = 1
			ray.enabled = true


func _setup_visual_shader() -> void:
	if visual == null:
		return
	if ResourceLoader.exists(SILHOUETTE_SHADER_PATH):
		var shader_res: Shader = load(SILHOUETTE_SHADER_PATH) as Shader
		if shader_res != null:
			_silhouette_material = ShaderMaterial.new()
			_silhouette_material.shader = shader_res
			_silhouette_material.set_shader_parameter("rim_color", _get_rim_color())
			_silhouette_material.set_shader_parameter("rim_strength", 0.42)
			_silhouette_material.set_shader_parameter("ink_wobble_px", 0.55)
			_silhouette_material.set_shader_parameter("flash_amount", 0.0)
			_silhouette_material.set_shader_parameter("flash_color", COL_PALE_GOLD)
			visual.material = _silhouette_material


func _configure_combat_boxes() -> void:
	if hurtbox != null:
		hurtbox.monitorable = true
		hurtbox.monitoring = false
		hurtbox.collision_layer = 8
		hurtbox.collision_mask = 0
		if not hurtbox.damaged.is_connected(_on_hurtbox_damaged):
			hurtbox.damaged.connect(_on_hurtbox_damaged)

	if attack_hitbox != null:
		attack_hitbox.collision_layer = 32
		attack_hitbox.collision_mask = 4
		attack_hitbox.damage = attack_damage
		attack_hitbox.parryable = true
		attack_hitbox.damage_type = "melee"
		attack_hitbox.one_shot_per_target = true
		attack_hitbox.source_node = self
		attack_hitbox.active = false

	if contact_hitbox != null:
		contact_hitbox.collision_layer = 32
		contact_hitbox.collision_mask = 4
		contact_hitbox.damage = contact_damage
		contact_hitbox.parryable = false
		contact_hitbox.damage_type = "contact"
		contact_hitbox.one_shot_per_target = false
		contact_hitbox.source_node = self
		contact_hitbox.active = true


func _physics_process(delta: float) -> void:
	anim_time += delta

	if is_dead:
		_process_death(delta)
		if visual != null:
			visual.queue_redraw()
		return

	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	if _stagger_ring_timer > 0.0:
		_stagger_ring_timer = maxf(0.0, _stagger_ring_timer - delta)

	if supports_dont_look_rule:
		_process_dont_look_hook(delta)

	state_timer = maxf(0.0, state_timer - delta)

	match state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.TELEGRAPH:
			_state_telegraph(delta)
		State.ATTACK:
			_state_attack(delta)
		State.RECOVER:
			_state_recover(delta)
		State.STAGGERED:
			_state_staggered(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			pass

	if uses_gravity and not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	move_and_slide()
	_update_shader_feedback()
	if visual != null:
		visual.queue_redraw()


func change_state(new_state: State) -> void:
	if state == new_state and state != State.IDLE:
		return
	var old_state: State = state
	_exit_state(old_state)
	state = new_state
	_enter_state(new_state)
	state_changed.emit(old_state, new_state)


func _enter_state(new_state: State) -> void:
	match new_state:
		State.IDLE:
			state_timer = 0.6
			velocity.x = move_toward(velocity.x, 0.0, 600.0)
			_set_contact_enabled(true)
		State.PATROL:
			state_timer = 0.0
			_set_contact_enabled(true)
		State.TELEGRAPH:
			state_timer = telegraph_duration
			_deactivate_attack_hitbox()
			_set_contact_enabled(true)
			AudioManager.play_sfx("ui_hover")
		State.ATTACK:
			state_timer = attack_duration
			# The (parryable) attack hitbox deals the damage; contact damage is
			# suspended so a successful parry is never undercut by a contact hit.
			_set_contact_enabled(false)
		State.RECOVER:
			state_timer = recover_duration
			_deactivate_attack_hitbox()
			_set_contact_enabled(true)
		State.STAGGERED:
			state_timer = stagger_duration
			_deactivate_attack_hitbox()
			_set_contact_enabled(false)
		State.HURT:
			state_timer = 0.16
			_deactivate_attack_hitbox()
			_set_contact_enabled(true)
		State.DEAD:
			state_timer = 0.45
			_deactivate_attack_hitbox()
			_set_contact_enabled(false)


func _exit_state(old_state: State) -> void:
	if old_state == State.ATTACK:
		_deactivate_attack_hitbox()
	elif old_state == State.STAGGERED:
		_set_contact_enabled(not is_dead)


func _state_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if state_timer <= 0.0:
		change_state(State.PATROL)


func _state_patrol(delta: float) -> void:
	if uses_gravity and is_on_floor():
		if is_ledge_ahead(facing) or is_wall_ahead(facing):
			facing = -facing
	velocity.x = move_toward(velocity.x, float(facing) * patrol_speed, 900.0 * delta)

	var player: Node2D = get_player()
	if player != null and can_see_player():
		var dist: float = global_position.distance_to(player.global_position)
		if dist <= attack_range:
			face_toward(player.global_position.x)
			change_state(State.TELEGRAPH)


func _state_telegraph(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	if state_timer <= 0.0:
		change_state(State.ATTACK)


func _state_attack(_delta: float) -> void:
	if state_timer <= 0.0:
		change_state(State.RECOVER)


func _state_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
	if state_timer <= 0.0:
		change_state(State.PATROL)


func _state_staggered(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 820.0 * delta)
	if not uses_gravity:
		velocity.y = move_toward(velocity.y, 0.0, 600.0 * delta)
	if state_timer <= 0.0:
		change_state(State.PATROL)


func _state_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 950.0 * delta)
	if not uses_gravity:
		velocity.y = move_toward(velocity.y, 0.0, 750.0 * delta)
	if state_timer <= 0.0:
		change_state(State.PATROL)


func on_parried() -> void:
	if is_dead:
		return
	_deactivate_attack_hitbox()
	_on_attack_interrupted()
	_stagger_ring_timer = 0.50
	hit_flash_timer = 0.25

	var player: Node2D = get_player()
	var push_dir: float = -float(facing)
	if player != null:
		push_dir = signf(global_position.x - player.global_position.x)
		if is_zero_approx(push_dir):
			push_dir = -float(facing)
	velocity.x = push_dir * (210.0 * (1.0 - knockback_resistance * 0.5))
	if uses_gravity and is_on_floor():
		velocity.y = -110.0

	change_state(State.STAGGERED)
	parried_staggered.emit(stagger_duration)


func _on_hurtbox_damaged(info: DamageInfo) -> void:
	if is_dead or info == null:
		return

	if _should_block_damage(info):
		_on_damage_blocked(info)
		return

	var base_damage: float = float(info.amount)
	if state == State.STAGGERED:
		base_damage *= stagger_damage_multiplier
	var final_damage: int = maxi(1, int(ceil(base_damage)))

	current_hp = maxi(0, current_hp - final_damage)
	hit_flash_timer = 0.14
	AudioManager.play_sfx("enemy_hurt")

	var kb_scale: float = clampf(1.0 - knockback_resistance, 0.15, 1.0)
	var kb_dir: float = signf(global_position.x - info.source_position.x)
	if is_zero_approx(kb_dir):
		kb_dir = -float(facing)
	var kb_x: float = absf(info.knockback.x) * kb_dir * kb_scale
	var kb_y: float = info.knockback.y * kb_scale
	velocity.x = kb_x
	if uses_gravity:
		velocity.y = minf(velocity.y, kb_y)
	else:
		velocity.y = kb_y * 0.5

	_on_damaged(info, final_damage)

	if current_hp <= 0:
		_die(info)
	elif state != State.STAGGERED and _can_enter_hurt_state(info):
		change_state(State.HURT)


func _die(info: DamageInfo) -> void:
	if is_dead:
		return
	is_dead = true
	change_state(State.DEAD)
	_on_attack_interrupted()

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if hurtbox != null:
		hurtbox.set_invulnerable(true)
		hurtbox.set_deferred("monitorable", false)

	GameState.add_resource(resource_drop)
	AudioManager.play_sfx("enemy_death")
	EventBus.camera_shake_requested.emit(4.0, 0.10)

	_death_timer = 0.45
	_spawn_death_particles(info)
	died.emit(self)


func _spawn_death_particles(info: DamageInfo) -> void:
	_death_particles.clear()
	var dir_bias: float = 0.0
	if info != null:
		dir_bias = signf(global_position.x - info.source_position.x) * 90.0
	for i: int in range(14):
		var angle: float = (TAU / 14.0) * float(i) + randf_range(-0.22, 0.22)
		var spd: float = randf_range(80.0, 240.0)
		var col: Color = COL_PALE_GOLD if i % 3 == 0 else _get_death_particle_color()
		_death_particles.append({
			"pos": Vector2(randf_range(-16.0, 16.0), randf_range(-28.0, 8.0)),
			"vel": Vector2(cos(angle) * spd + dir_bias, sin(angle) * spd - 65.0),
			"size": randf_range(3.5, 8.5),
			"color": col,
			"rot": randf_range(0.0, TAU),
		})


func _process_death(delta: float) -> void:
	_death_timer -= delta
	for p: Dictionary in _death_particles:
		var pos: Vector2 = p["pos"] as Vector2
		var vel: Vector2 = p["vel"] as Vector2
		vel.y += 320.0 * delta
		pos += vel * delta
		p["pos"] = pos
		p["vel"] = vel
		p["rot"] = float(p["rot"]) + 5.0 * delta
	if _death_timer <= 0.0:
		queue_free()


func _activate_attack_hitbox(dmg: int, kb: Vector2, is_parryable: bool = true, dmg_type: String = "melee") -> void:
	if attack_hitbox == null:
		return
	attack_hitbox.damage = dmg
	attack_hitbox.knockback = Vector2(absf(kb.x) * float(facing), kb.y)
	attack_hitbox.parryable = is_parryable
	attack_hitbox.damage_type = dmg_type
	attack_hitbox.source_node = self
	attack_hitbox.reset_hits()
	# Deferred: Hitbox.monitoring must never change while physics queries flush
	# (e.g. when a parry / hit callback re-enters this enemy).
	attack_hitbox.set_deferred("active", true)


func _deactivate_attack_hitbox() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_deferred("active", false)


func _set_contact_enabled(enabled: bool) -> void:
	if contact_hitbox == null:
		return
	if enabled and not is_dead:
		contact_hitbox.knockback = Vector2(210.0 * float(facing), -150.0)
		contact_hitbox.source_node = self
		contact_hitbox.set_deferred("active", true)
	else:
		contact_hitbox.set_deferred("active", false)


func get_player() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node2D


func get_distance_to_player() -> float:
	var player: Node2D = get_player()
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)


func get_direction_to_player() -> Vector2:
	var player: Node2D = get_player()
	if player == null:
		return Vector2(float(facing), 0.0)
	return (player.global_position - global_position).normalized()


func can_see_player() -> bool:
	var player: Node2D = get_player()
	if player == null:
		return false
	if GameState.player_hp <= 0:
		return false
	return global_position.distance_to(player.global_position) <= detection_range


func face_toward(target_x: float) -> void:
	var dx: float = target_x - global_position.x
	if absf(dx) > 6.0:
		facing = 1 if dx > 0.0 else -1


func is_ledge_ahead(dir: int) -> bool:
	if not is_on_floor():
		return false
	var ray: RayCast2D = ledge_ray_right if dir > 0 else ledge_ray_left
	if ray == null:
		return false
	ray.force_raycast_update()
	return not ray.is_colliding()


func is_wall_ahead(dir: int) -> bool:
	var ray: RayCast2D = wall_ray_right if dir > 0 else wall_ray_left
	if ray != null:
		ray.force_raycast_update()
		if ray.is_colliding():
			return true
	if is_on_wall():
		var normal: Vector2 = get_wall_normal()
		if normal.x * float(dir) < -0.5:
			return true
	return false


## Architectural helper for M2/M3 Jinn zones ("Don't-Look" rule):
## Returns true when the player is facing toward this enemy within detection_range.
func is_player_looking_at_me(player: Node2D) -> bool:
	if player == null:
		return false
	if global_position.distance_to(player.global_position) > detection_range:
		return false
	var player_facing: float = 1.0
	if "facing_dir" in player:
		player_facing = float(player.get("facing_dir"))
	elif "facing" in player:
		player_facing = float(player.get("facing"))
	elif "facing_direction" in player:
		player_facing = float(player.get("facing_direction"))
	var to_enemy_x: float = global_position.x - player.global_position.x
	return to_enemy_x * player_facing > 0.0


func _process_dont_look_hook(delta: float) -> void:
	var player: Node2D = get_player()
	if is_player_looking_at_me(player):
		_player_looking_duration += delta
	else:
		_player_looking_duration = maxf(0.0, _player_looking_duration - delta * 2.0)


func _is_reduce_flash_enabled() -> bool:
	return SettingsManager.reduce_flash


func _update_shader_feedback() -> void:
	if _silhouette_material == null:
		return
	var reduce_flash: bool = _is_reduce_flash_enabled()
	var flash_cap: float = 0.35 if reduce_flash else 0.85
	var flash_val: float = 0.0
	var flash_col: Color = COL_PALE_GOLD

	if hit_flash_timer > 0.0:
		flash_val = flash_cap
		flash_col = COL_PALE_GOLD if state == State.STAGGERED else COL_WARM_SAND
	elif state == State.STAGGERED:
		var pulse: float = 0.45 + 0.35 * sin(anim_time * 16.0)
		flash_val = pulse * (0.45 if reduce_flash else 0.72)
		flash_col = COL_PALE_GOLD

	_silhouette_material.set_shader_parameter("flash_amount", flash_val)
	_silhouette_material.set_shader_parameter("flash_color", flash_col)


func _on_visual_draw() -> void:
	if visual == null:
		return
	if is_dead:
		_draw_death_burst(visual)
		return
	_draw_entity(visual)
	_draw_stagger_overlay(visual)
	_draw_health_pips(visual)


func _draw_stagger_overlay(canvas: Node2D) -> void:
	if _stagger_ring_timer > 0.0:
		var t: float = 1.0 - (_stagger_ring_timer / 0.50)
		var ring_r: float = lerpf(16.0, 68.0, t)
		var ring_col: Color = Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, (1.0 - t) * 0.9)
		canvas.draw_arc(Vector2(0.0, -24.0), ring_r, 0.0, TAU, 28, ring_col, 3.0, true)

	if state == State.STAGGERED:
		var alpha: float = 0.55 + 0.30 * sin(anim_time * 14.0)
		if _is_reduce_flash_enabled():
			alpha = 0.5
		var gold: Color = Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, alpha)
		# Floating pale-gold stagger shards overhead signaling 1.35x vulnerability
		for i: int in range(3):
			var a: float = anim_time * 4.5 + float(i) * (TAU / 3.0)
			var p: Vector2 = Vector2(cos(a) * 24.0, -64.0 + sin(a) * 6.0)
			var diamond := PackedVector2Array([
				p + Vector2(0.0, -6.0),
				p + Vector2(4.0, 0.0),
				p + Vector2(0.0, 6.0),
				p + Vector2(-4.0, 0.0),
			])
			canvas.draw_colored_polygon(diamond, gold)


func _draw_health_pips(canvas: Node2D) -> void:
	if current_hp >= max_hp or max_hp <= 0:
		return
	var ratio: float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var bar_w: float = 44.0
	var bar_h: float = 5.0
	var top_y: float = _get_health_bar_offset_y()
	var bg_rect := Rect2(-bar_w * 0.5, top_y, bar_w, bar_h)
	var fill_rect := Rect2(-bar_w * 0.5, top_y, bar_w * ratio, bar_h)
	var fill_col: Color = COL_PALE_GOLD if state == State.STAGGERED else COL_DESERT_RED
	canvas.draw_rect(bg_rect, Color(COL_DEEP_SHADOW.r, COL_DEEP_SHADOW.g, COL_DEEP_SHADOW.b, 0.8), true)
	canvas.draw_rect(fill_rect, fill_col, true)
	canvas.draw_rect(bg_rect, Color(COL_MUD_BRICK_OCHRE.r, COL_MUD_BRICK_OCHRE.g, COL_MUD_BRICK_OCHRE.b, 0.7), false, 1.0)


func _draw_death_burst(canvas: Node2D) -> void:
	var alpha: float = clampf(_death_timer / 0.45, 0.0, 1.0)
	for p: Dictionary in _death_particles:
		var pos: Vector2 = p["pos"] as Vector2
		var sz: float = float(p["size"]) * (0.4 + 0.6 * alpha)
		var col: Color = p["color"] as Color
		col.a = alpha
		var rot: float = float(p["rot"])
		var pts := PackedVector2Array([
			pos + Vector2(0.0, -sz).rotated(rot),
			pos + Vector2(sz * 0.7, 0.0).rotated(rot),
			pos + Vector2(0.0, sz).rotated(rot),
			pos + Vector2(-sz * 0.7, 0.0).rotated(rot),
		])
		canvas.draw_colored_polygon(pts, col)


# --- Virtual hooks for subclasses ---

func _on_enemy_ready() -> void:
	pass


func _on_attack_interrupted() -> void:
	pass


func _should_block_damage(_info: DamageInfo) -> bool:
	return false


func _on_damage_blocked(_info: DamageInfo) -> void:
	pass


func _on_damaged(_info: DamageInfo, _final_damage: int) -> void:
	pass


func _can_enter_hurt_state(_info: DamageInfo) -> bool:
	return state != State.ATTACK and state != State.TELEGRAPH


func _get_rim_color() -> Color:
	return COL_SUNSET_ORANGE


func _get_death_particle_color() -> Color:
	return COL_DESERT_RED


func _get_health_bar_offset_y() -> float:
	return -58.0


func _draw_entity(_canvas: Node2D) -> void:
	pass
