class_name BossBase
extends CharacterBody2D
## Reusable multi-phase boss framework for SHAALA (شعلة).
## Handles encounter activation, EventBus boss health/phase/defeat broadcasts,
## phase transitions with invulnerable telegraph roar, parry stagger (1.4s, 1.35x damage),
## persistence check via GameState.is_boss_defeated(), and defeat dissolve.

signal defeated
signal encounter_started
signal phase_changed(new_phase: int)
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

@export var boss_id: String = ""
@export var boss_name_key: String = ""
@export var max_hp: int = 280
@export var phase_thresholds: Array[float] = [0.5]
@export var stagger_duration: float = 1.4
@export var stagger_damage_multiplier: float = 1.35
@export var resource_drop: float = 100.0
@export var contact_damage: int = 1
@export var gravity: float = 1650.0
@export var max_fall_speed: float = 1150.0
@export var arena_left_x: float = 190.0
@export var arena_right_x: float = 2010.0
@export var arena_floor_y: float = 860.0

var current_hp: int = 280
var phase: int = 1
var is_active: bool = false
var is_defeated: bool = false
var is_staggered: bool = false
var is_phase_transitioning: bool = false
var stagger_timer: float = 0.0
var phase_transition_timer: float = 0.0
var facing: int = -1
var hit_flash_timer: float = 0.0
var anim_time: float = 0.0
var uses_gravity: bool = true

var visual: Node2D = null
var world_fx: Node2D = null
var hurtbox: Hurtbox = null
var attack_hitbox: Hitbox = null
var contact_hitbox: Hitbox = null

var _silhouette_material: ShaderMaterial = null
var _stagger_ring_timer: float = 0.0
var _roar_wave_timer: float = 0.0
var _death_timer: float = 0.0
var _death_motes: Array[Dictionary] = []
var _triggered_thresholds: int = 0


func _ready() -> void:
	# Cleanly remove already-defeated bosses on room load
	if not boss_id.is_empty() and GameState.is_boss_defeated(boss_id):
		queue_free()
		return

	# Physics Layer Contract:
	# Boss CharacterBody2D: layer 4 (bitmask 8), mask 1+2 (world + one_way = 3)
	collision_layer = 8
	collision_mask = 3
	add_to_group("enemies")
	add_to_group("bosses")

	current_hp = max_hp
	phase = 1
	_triggered_thresholds = 0

	_bind_nodes()
	_setup_visual_shader()
	_configure_combat_boxes()
	_on_boss_ready()


func _bind_nodes() -> void:
	visual = get_node_or_null("Visual") as Node2D
	if visual == null:
		visual = Node2D.new()
		visual.name = "Visual"
		add_child(visual)
	if not visual.draw.is_connected(_on_visual_draw):
		visual.draw.connect(_on_visual_draw)

	world_fx = get_node_or_null("WorldFX") as Node2D
	if world_fx == null:
		world_fx = Node2D.new()
		world_fx.name = "WorldFX"
		add_child(world_fx)
	world_fx.top_level = true
	world_fx.global_position = Vector2.ZERO
	world_fx.z_index = 2
	if not world_fx.draw.is_connected(_on_world_fx_draw):
		world_fx.draw.connect(_on_world_fx_draw)

	hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	attack_hitbox = get_node_or_null("AttackHitbox") as Hitbox
	contact_hitbox = get_node_or_null("ContactHitbox") as Hitbox


func _setup_visual_shader() -> void:
	if visual == null:
		return
	if ResourceLoader.exists(SILHOUETTE_SHADER_PATH):
		var shader_res: Shader = load(SILHOUETTE_SHADER_PATH) as Shader
		if shader_res != null:
			_silhouette_material = ShaderMaterial.new()
			_silhouette_material.shader = shader_res
			_silhouette_material.set_shader_parameter("rim_color", COL_PALE_GOLD)
			_silhouette_material.set_shader_parameter("rim_strength", 0.48)
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
		# Dormant until start_encounter() is triggered by the arena
		hurtbox.set_invulnerable(true)
		if not hurtbox.damaged.is_connected(_on_hurtbox_damaged):
			hurtbox.damaged.connect(_on_hurtbox_damaged)

	if attack_hitbox != null:
		attack_hitbox.collision_layer = 32
		attack_hitbox.collision_mask = 4
		attack_hitbox.damage = 1
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
		contact_hitbox.active = false


func start_encounter() -> void:
	if is_active or is_defeated:
		return
	is_active = true
	if hurtbox != null:
		hurtbox.set_invulnerable(false)
	_set_contact_enabled(true)

	# Align arena floor Y with standing surface if resting on floor
	if is_on_floor():
		arena_floor_y = global_position.y

	EventBus.boss_encounter_started.emit(boss_id, boss_name_key, max_hp)
	EventBus.boss_health_changed.emit(boss_id, current_hp, max_hp, phase)
	encounter_started.emit()
	_on_encounter_started()


func _physics_process(delta: float) -> void:
	anim_time += delta

	if is_defeated:
		_process_defeat_dissolve(delta)
		_redraw_all()
		return

	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	if _stagger_ring_timer > 0.0:
		_stagger_ring_timer = maxf(0.0, _stagger_ring_timer - delta)
	if _roar_wave_timer > 0.0:
		_roar_wave_timer = maxf(0.0, _roar_wave_timer - delta)

	if is_active:
		if is_phase_transitioning:
			phase_transition_timer = maxf(0.0, phase_transition_timer - delta)
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if phase_transition_timer <= 0.0:
				is_phase_transitioning = false
				if hurtbox != null:
					hurtbox.set_invulnerable(false)
				_set_contact_enabled(true)
				_on_phase_transition_finished(phase)
		elif is_staggered:
			stagger_timer = maxf(0.0, stagger_timer - delta)
			velocity.x = move_toward(velocity.x, 0.0, 950.0 * delta)
			if stagger_timer <= 0.0:
				is_staggered = false
				_set_contact_enabled(true)
				_on_stagger_finished()
		else:
			_boss_physics_process(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	if uses_gravity and not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	move_and_slide()
	_update_shader_feedback()
	_redraw_all()


func on_parried() -> void:
	if is_defeated or not is_active or is_phase_transitioning:
		return
	_deactivate_attack_hitbox()
	_on_attack_interrupted()

	is_staggered = true
	stagger_timer = stagger_duration
	_stagger_ring_timer = 0.55
	hit_flash_timer = 0.28
	_set_contact_enabled(false)

	var player: Node2D = get_player()
	var push_dir: float = -float(facing)
	if player != null:
		push_dir = signf(global_position.x - player.global_position.x)
		if is_zero_approx(push_dir):
			push_dir = -float(facing)
	velocity.x = push_dir * 165.0
	velocity.y = 0.0
	uses_gravity = true

	EventBus.camera_shake_requested.emit(8.0, 0.16)
	parried_staggered.emit(stagger_duration)


func _on_hurtbox_damaged(info: DamageInfo) -> void:
	if not is_active or is_defeated or is_phase_transitioning or info == null:
		return

	var raw_damage: float = float(info.amount)
	if is_staggered:
		raw_damage *= stagger_damage_multiplier
	var final_damage: int = maxi(1, int(ceil(raw_damage)))

	current_hp = maxi(0, current_hp - final_damage)
	hit_flash_timer = 0.12
	AudioManager.play_sfx("enemy_hurt")
	EventBus.boss_health_changed.emit(boss_id, current_hp, max_hp, phase)

	if current_hp <= 0:
		_handle_defeat()
	else:
		_check_phase_transition()


func _check_phase_transition() -> void:
	if _triggered_thresholds >= phase_thresholds.size():
		return
	var hp_ratio: float = float(current_hp) / float(maxi(1, max_hp))
	var next_threshold: float = phase_thresholds[_triggered_thresholds]
	if hp_ratio <= next_threshold:
		_triggered_thresholds += 1
		phase += 1
		is_staggered = false
		stagger_timer = 0.0
		_deactivate_attack_hitbox()
		_on_attack_interrupted()
		_set_contact_enabled(false)

		is_phase_transitioning = true
		phase_transition_timer = 1.35
		_roar_wave_timer = 1.10
		uses_gravity = true
		velocity.x = 0.0
		if hurtbox != null:
			hurtbox.set_invulnerable(true)

		EventBus.boss_health_changed.emit(boss_id, current_hp, max_hp, phase)
		EventBus.camera_shake_requested.emit(11.0, 0.45)
		AudioManager.play_sfx("boss_roar")
		phase_changed.emit(phase)
		_on_phase_transition_started(phase)


func _handle_defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	is_active = false
	is_staggered = false
	is_phase_transitioning = false

	_deactivate_attack_hitbox()
	_set_contact_enabled(false)
	_cleanup_all_attacks()

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if hurtbox != null:
		hurtbox.set_invulnerable(true)
		hurtbox.set_deferred("monitorable", false)

	GameState.add_resource(resource_drop)
	GameState.mark_boss_defeated(boss_id)
	EventBus.boss_defeated.emit(boss_id)
	EventBus.hitstop_requested.emit(0.12)
	EventBus.camera_shake_requested.emit(12.0, 0.50)
	AudioManager.play_sfx("enemy_death")
	defeated.emit()

	_death_timer = 1.50
	_spawn_defeat_motes()


func _spawn_defeat_motes() -> void:
	_death_motes.clear()
	for i: int in range(32):
		var angle: float = (TAU / 32.0) * float(i) + randf_range(-0.18, 0.18)
		var spd: float = randf_range(55.0, 210.0)
		var is_gold: bool = (i % 2 == 0)
		_death_motes.append({
			"pos": Vector2(randf_range(-34.0, 34.0), randf_range(-140.0, -8.0)),
			"vel": Vector2(cos(angle) * spd * 0.7, sin(angle) * spd * 0.45 - randf_range(75.0, 150.0)),
			"size": randf_range(4.0, 10.0),
			"color": COL_PALE_GOLD if is_gold else COL_GLASS_TEAL,
			"rot": randf_range(0.0, TAU),
		})


func _process_defeat_dissolve(delta: float) -> void:
	_death_timer -= delta
	for m: Dictionary in _death_motes:
		var pos: Vector2 = m["pos"] as Vector2
		var vel: Vector2 = m["vel"] as Vector2
		vel.y -= 35.0 * delta
		pos += vel * delta
		m["pos"] = pos
		m["vel"] = vel
		m["rot"] = float(m["rot"]) + 3.2 * delta
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
	attack_hitbox.set_deferred("active", true)


func _deactivate_attack_hitbox() -> void:
	if attack_hitbox != null:
		attack_hitbox.set_deferred("active", false)


func _set_contact_enabled(enabled: bool) -> void:
	if contact_hitbox == null:
		return
	if enabled and is_active and not is_defeated:
		contact_hitbox.knockback = Vector2(230.0 * float(facing), -160.0)
		contact_hitbox.source_node = self
		contact_hitbox.set_deferred("active", true)
	else:
		contact_hitbox.set_deferred("active", false)


func get_player() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node2D


func face_player() -> void:
	var player: Node2D = get_player()
	if player == null:
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 10.0:
		facing = 1 if dx > 0.0 else -1


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
		flash_col = COL_PALE_GOLD if is_staggered else COL_WARM_SAND
	elif is_staggered:
		var pulse: float = 0.45 + 0.35 * sin(anim_time * 16.0)
		flash_val = pulse * (0.45 if reduce_flash else 0.72)
		flash_col = COL_PALE_GOLD
	elif is_phase_transitioning:
		var roar_pulse: float = 0.35 + 0.35 * sin(anim_time * 22.0)
		flash_val = roar_pulse * (0.35 if reduce_flash else 0.65)
		flash_col = COL_PALE_GOLD

	_silhouette_material.set_shader_parameter("flash_amount", flash_val)
	_silhouette_material.set_shader_parameter("flash_color", flash_col)
	_silhouette_material.set_shader_parameter("rim_strength", 0.70 if phase >= 2 else 0.48)


func _redraw_all() -> void:
	if visual != null:
		visual.queue_redraw()
	if world_fx != null:
		world_fx.queue_redraw()


func _on_visual_draw() -> void:
	if visual == null:
		return
	if is_defeated:
		_draw_defeat_dissolve(visual)
		return
	_draw_boss(visual)
	_draw_boss_status_overlays(visual)


func _on_world_fx_draw() -> void:
	if world_fx == null:
		return
	_draw_world_fx(world_fx)


func _draw_boss_status_overlays(canvas: Node2D) -> void:
	if _stagger_ring_timer > 0.0:
		var t: float = 1.0 - (_stagger_ring_timer / 0.55)
		var r: float = lerpf(28.0, 128.0, t)
		var col := Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, (1.0 - t) * 0.9)
		canvas.draw_arc(Vector2(0.0, -72.0), r, 0.0, TAU, 36, col, 4.0, true)

	if _roar_wave_timer > 0.0:
		var t: float = 1.0 - (_roar_wave_timer / 1.10)
		var r1: float = lerpf(34.0, 260.0, t)
		var r2: float = lerpf(16.0, 185.0, t)
		var alpha: float = (1.0 - t) * (0.45 if _is_reduce_flash_enabled() else 0.85)
		var col1 := Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, alpha)
		var col2 := Color(COL_GLASS_TEAL.r, COL_GLASS_TEAL.g, COL_GLASS_TEAL.b, alpha * 0.8)
		canvas.draw_arc(Vector2(0.0, -76.0), r1, 0.0, TAU, 44, col1, 5.0, true)
		canvas.draw_arc(Vector2(0.0, -76.0), r2, 0.0, TAU, 36, col2, 3.0, true)

	if is_staggered:
		var alpha: float = 0.55 + 0.30 * sin(anim_time * 14.0)
		if _is_reduce_flash_enabled():
			alpha = 0.5
		var gold := Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, alpha)
		for i: int in range(4):
			var a: float = anim_time * 4.2 + float(i) * (TAU / 4.0)
			var p := Vector2(cos(a) * 38.0, -162.0 + sin(a) * 8.0)
			canvas.draw_colored_polygon(PackedVector2Array([
				p + Vector2(0.0, -8.0),
				p + Vector2(5.0, 0.0),
				p + Vector2(0.0, 8.0),
				p + Vector2(-5.0, 0.0),
			]), gold)


func _draw_defeat_dissolve(canvas: Node2D) -> void:
	var alpha: float = clampf(_death_timer / 1.50, 0.0, 1.0)
	# Fading luminous fracture silhouette core
	if alpha > 0.35:
		var core_a: float = (alpha - 0.35) / 0.65
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(-24.0, -8.0),
			Vector2(-18.0, -130.0),
			Vector2(0.0, -152.0),
			Vector2(18.0, -130.0),
			Vector2(24.0, -8.0),
		]), Color(COL_PALE_GOLD.r, COL_PALE_GOLD.g, COL_PALE_GOLD.b, core_a * 0.45))

	for m: Dictionary in _death_motes:
		var pos: Vector2 = m["pos"] as Vector2
		var sz: float = float(m["size"]) * (0.35 + 0.65 * alpha)
		var col: Color = m["color"] as Color
		col.a = alpha
		var rot: float = float(m["rot"])
		canvas.draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0.0, -sz).rotated(rot),
			pos + Vector2(sz * 0.65, 0.0).rotated(rot),
			pos + Vector2(0.0, sz).rotated(rot),
			pos + Vector2(-sz * 0.65, 0.0).rotated(rot),
		]), col)


# --- Virtual hooks for concrete bosses ---

func _on_boss_ready() -> void:
	pass


func _on_encounter_started() -> void:
	pass


func _boss_physics_process(_delta: float) -> void:
	pass


func _on_attack_interrupted() -> void:
	pass


func _on_stagger_finished() -> void:
	pass


func _on_phase_transition_started(_new_phase: int) -> void:
	pass


func _on_phase_transition_finished(_new_phase: int) -> void:
	pass


func _cleanup_all_attacks() -> void:
	pass


func _draw_boss(_canvas: Node2D) -> void:
	pass


func _draw_world_fx(_canvas: Node2D) -> void:
	pass
