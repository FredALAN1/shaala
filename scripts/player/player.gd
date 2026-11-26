class_name Player
extends CharacterBody2D
## Farid — playable protagonist of SHAALA (شعلة).
## Tight metroidvania movement (coyote time, jump buffering, variable jump height,
## wall-cling, dash, double jump, ground-pound, glide) + 3-tier Flame Dagger combat,
## ranged Flame Spell, and Parry with Resource generation.
##
## Physics Layer Contract:
##   - Player CharacterBody2D: collision_layer = 4 (layer 3: player), collision_mask = 3 (world + one_way)
##   - Player Hurtbox: collision_layer = 4 (layer 3: player), collision_mask = 0
##   - Player Hitbox (FlameDagger / FlameProjectile): collision_layer = 16 (layer 5), collision_mask = 8 (enemy)
##   - Player InteractSensor: collision_layer = 0, collision_mask = 64 (layer 7: interactable)
##   - Player HazardSensor: collision_layer = 0, collision_mask = 128 (layer 8: hazard)

# --- Canonical Movement & Physics Constants (60 FPS, 1920x1080) ---
const RUN_SPEED: float = 380.0
const GROUND_ACCEL: float = 2800.0
const GROUND_DECEL: float = 3200.0
const AIR_ACCEL: float = 2000.0
const AIR_DECEL: float = 1400.0

const GRAVITY: float = 1550.0
const MAX_FALL_SPEED: float = 980.0
const JUMP_VELOCITY: float = -640.0
const VARIABLE_JUMP_CUT: float = 0.45
const DOUBLE_JUMP_VELOCITY: float = -590.0

const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.12

const DASH_SPEED: float = 860.0
const DASH_DURATION: float = 0.22
const DASH_COOLDOWN: float = 0.40

const WALL_SLIDE_SPEED: float = 130.0
const WALL_JUMP_VELOCITY: Vector2 = Vector2(440.0, -610.0)
const WALL_JUMP_LOCK: float = 0.14

const GROUND_POUND_SPEED: float = 1050.0
const GLIDE_FALL_SPEED: float = 110.0

# --- Combat & Ability Constants ---
const POGO_BOUNCE_VELOCITY: float = -520.0
const SPELL_COST: float = 25.0
const SPELL_COOLDOWN: float = 0.28
const SPELL_DAMAGE: int = 24
const PARRY_ACTIVE_WINDOW: float = 0.18
const PARRY_COOLDOWN: float = 0.35
const PARRY_RESOURCE_GAIN: float = 25.0
const HURT_INVULN_DURATION: float = 0.85
const COMBO_RESET_TIME: float = 0.48
const ONE_WAY_DROP_TIME: float = 0.18

# --- Palette Colors (Desert Guardian Farid — Original Silhouette) ---
const COL_CLOAK: Color = Color(0.086, 0.106, 0.200, 1.0)      # Night indigo #161B33
const COL_DEEP_SHADOW: Color = Color(0.051, 0.063, 0.129, 1.0) # Deep shadow #0D1021
const COL_DESERT_RED: Color = Color(0.659, 0.267, 0.196, 1.0)  # Desert red #A84432
const COL_OCHRE: Color = Color(0.776, 0.545, 0.349, 1.0)       # Mud-brick ochre #C68B59
const COL_EYE_GREY: Color = Color(0.545, 0.584, 0.647, 1.0)    # Left eye grey #8B95A5
const COL_EYE_BLUE: Color = Color(0.290, 0.565, 0.851, 1.0)    # Right eye blue #4A90D9
const COL_PALE_GOLD: Color = Color(0.965, 0.886, 0.600, 1.0)   # Pale gold #F6E299
const COL_SUNSET_ORANGE: Color = Color(0.878, 0.478, 0.235, 1.0)

const SILHOUETTE_SHADER_PATH: String = "res://assets/placeholder/shaders/painterly_silhouette.gdshader"
const FLAME_PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/flame_projectile.tscn")

# --- Node References ---
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var flame_dagger: FlameDagger = $FlameDagger
@onready var interact_sensor: Area2D = $InteractSensor
@onready var hazard_sensor: Area2D = $HazardSensor
@onready var visual_root: Node2D = $VisualRoot
@onready var cloak_poly: Polygon2D = $VisualRoot/CloakPolygon
@onready var trim_poly: Polygon2D = $VisualRoot/TrimPolygon
@onready var scarf_poly: Polygon2D = $VisualRoot/ScarfPolygon
@onready var body_poly: Polygon2D = $VisualRoot/BodyPolygon
@onready var head_poly: Polygon2D = $VisualRoot/HeadPolygon
@onready var spell_muzzle: Marker2D = $SpellMuzzle
@onready var wall_ray_left: RayCast2D = $WallRayLeft
@onready var wall_ray_right: RayCast2D = $WallRayRight

# --- Runtime State ---
var controls_enabled: bool = true
var facing_dir: int = 1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var spell_cooldown_timer: float = 0.0
var parry_cooldown_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0
var invuln_timer: float = 0.0
var combo_reset_timer: float = 0.0
var combo_step: int = 0
var air_dash_available: bool = true
var double_jump_available: bool = true
var parry_active: bool = false
var is_dead: bool = false
var grey_eye_active: bool = false

# --- Visual Rig & Juice State ---
var visual_scale: Vector2 = Vector2.ONE
var visual_tilt: float = 0.0
var _anim_time: float = 0.0
var _one_way_drop_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _parry_ring_timer: float = 0.0
var _parry_ring_duration: float = 0.24
var _parry_ring_success: bool = false
var _ground_pound_ring_timer: float = 0.0
var _afterimages: Array[Dictionary] = []
var _dust_particles: Array[Dictionary] = []
var _silhouette_material: ShaderMaterial = null
var _base_cloak_points: PackedVector2Array = PackedVector2Array()
var _base_scarf_points: PackedVector2Array = PackedVector2Array()
var _last_interact_frame: int = -1


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4 # Layer 3: player
	collision_mask = 3  # Layers 1+2: world + one_way

	if hurtbox != null:
		hurtbox.collision_layer = 4 # Layer 3: player
		hurtbox.collision_mask = 0
		if not hurtbox.damaged.is_connected(_on_hurtbox_damaged):
			hurtbox.damaged.connect(_on_hurtbox_damaged)

	if flame_dagger != null:
		if not flame_dagger.slash_hit.is_connected(_on_dagger_slash_hit):
			flame_dagger.slash_hit.connect(_on_dagger_slash_hit)

	if interact_sensor != null:
		interact_sensor.collision_layer = 0
		interact_sensor.collision_mask = 64 # Layer 7: interactable
		interact_sensor.monitoring = true
		interact_sensor.monitorable = false

	if hazard_sensor != null:
		hazard_sensor.collision_layer = 0
		hazard_sensor.collision_mask = 128 # Layer 8: hazard
		hazard_sensor.monitoring = true
		hazard_sensor.monitorable = false
		if not hazard_sensor.area_entered.is_connected(_on_hazard_entered):
			hazard_sensor.area_entered.connect(_on_hazard_entered)
		if not hazard_sensor.body_entered.is_connected(_on_hazard_body_entered):
			hazard_sensor.body_entered.connect(_on_hazard_body_entered)

	if EventBus.has_signal("grey_eye_toggled"):
		if not EventBus.grey_eye_toggled.is_connected(_on_grey_eye_toggled):
			EventBus.grey_eye_toggled.connect(_on_grey_eye_toggled)

	if cloak_poly != null:
		_base_cloak_points = cloak_poly.polygon.duplicate()
	if scarf_poly != null:
		_base_scarf_points = scarf_poly.polygon.duplicate()

	_setup_optional_silhouette_shader()
	state_machine.initialize(self)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or is_dead:
		return

	if event.is_action_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if event.is_action_pressed("interact"):
		if try_interact():
			get_viewport().set_input_as_handled()
			return

	state_machine.handle_input(event)


func _process(delta: float) -> void:
	_anim_time += delta
	state_machine.update(delta)
	_update_visual_rig(delta)
	_update_fx_particles(delta)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if controls_enabled and not is_dead and Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	state_machine.physics_update(delta)
	move_and_slide()

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		reset_air_mobility()


# --- Public Control & Respawn API ---

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		jump_buffer_timer = 0.0
		velocity.x = 0.0
		if not is_dead and state_machine != null:
			var cur: StringName = state_machine.current_state_name
			if cur != &"hurt" and cur != &"dead" and is_on_floor():
				state_machine.transition_to(&"idle")


func are_controls_enabled() -> bool:
	return controls_enabled


func respawn() -> void:
	revive_at_spawn()


func revive_at_spawn(spawn_pos: Vector2 = Vector2.ZERO, use_position: bool = false) -> void:
	if use_position:
		global_position = spawn_pos
	is_dead = false
	controls_enabled = true
	parry_active = false
	velocity = Vector2.ZERO
	invuln_timer = 0.0
	dash_cooldown_timer = 0.0
	spell_cooldown_timer = 0.0
	parry_cooldown_timer = 0.0
	wall_jump_lock_timer = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = COYOTE_TIME
	reset_air_mobility()
	if hurtbox != null:
		hurtbox.set_invulnerable(false)
	if flame_dagger != null:
		flame_dagger.stop_slash()
	if visual_root != null:
		visual_root.visible = true
		visual_root.modulate.a = 1.0
	state_machine.transition_to(&"idle")


# --- Input & Movement Helpers ---

func get_move_input_x() -> float:
	if not controls_enabled or is_dead:
		return 0.0
	var raw: float = Input.get_axis("move_left", "move_right")
	var dz: float = clampf(SettingsManager.gamepad_deadzone, 0.05, 0.5)
	if absf(raw) < dz:
		return 0.0
	return signf(raw) if absf(raw) > 0.85 else raw


func get_move_input_y() -> float:
	if not controls_enabled or is_dead:
		return 0.0
	var raw: float = Input.get_axis("move_up", "move_down")
	var dz: float = clampf(SettingsManager.gamepad_deadzone, 0.05, 0.5)
	if absf(raw) < dz:
		return 0.0
	return raw


func set_facing(dir: int) -> void:
	if dir == 0:
		return
	facing_dir = 1 if dir > 0 else -1
	if spell_muzzle != null:
		spell_muzzle.position.x = absf(spell_muzzle.position.x) * float(facing_dir)


func apply_horizontal_movement(
	delta: float,
	input_x: float,
	grounded: bool,
	speed_scale: float = 1.0
) -> void:
	if wall_jump_lock_timer > 0.0:
		return
	var target_speed: float = input_x * RUN_SPEED * speed_scale
	var accel: float = GROUND_ACCEL if grounded else AIR_ACCEL
	var decel: float = GROUND_DECEL if grounded else AIR_DECEL
	var rate: float = accel if absf(input_x) > 0.01 else decel
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if absf(input_x) > 0.05:
		set_facing(1 if input_x > 0.0 else -1)


func apply_gravity(
	delta: float,
	gravity_scale: float = 1.0,
	max_fall: float = MAX_FALL_SPEED
) -> void:
	velocity.y = minf(velocity.y + GRAVITY * gravity_scale * delta, max_fall)


func reset_air_mobility() -> void:
	air_dash_available = true
	double_jump_available = true


func consume_jump_buffer() -> bool:
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		return true
	return false


func can_coyote_jump() -> bool:
	return coyote_timer > 0.0


func can_double_jump() -> bool:
	return controls_enabled and GameState.has_ability("double_jump") and double_jump_available


func can_dash() -> bool:
	if not controls_enabled or is_dead:
		return false
	if not GameState.has_ability("dash"):
		return false
	if dash_cooldown_timer > 0.0:
		return false
	return is_on_floor() or air_dash_available


func can_wall_cling() -> int:
	if not controls_enabled or is_dead or is_on_floor():
		return 0
	if not GameState.has_ability("wall_cling"):
		return 0
	if wall_jump_lock_timer > 0.0:
		return 0

	var input_x: float = get_move_input_x()
	if wall_ray_right != null and wall_ray_right.is_colliding():
		if input_x >= 0.0 or is_on_wall():
			return -1 # Wall is on right, wall normal points left (-1)
	if wall_ray_left != null and wall_ray_left.is_colliding():
		if input_x <= 0.0 or is_on_wall():
			return 1  # Wall is on left, wall normal points right (+1)
	return 0


func can_cast_spell() -> bool:
	if not controls_enabled or is_dead:
		return false
	if not GameState.has_ability("flame_spell"):
		return false
	if spell_cooldown_timer > 0.0:
		return false
	return GameState.player_resource >= SPELL_COST


func can_parry() -> bool:
	return controls_enabled and not is_dead and parry_cooldown_timer <= 0.0


func can_ground_pound() -> bool:
	if not controls_enabled or is_dead or is_on_floor():
		return false
	if not GameState.has_ability("ground_pound"):
		return false
	return get_move_input_y() > 0.5


func can_glide() -> bool:
	if not controls_enabled or is_dead or is_on_floor():
		return false
	if not GameState.has_ability("glide"):
		return false
	return Input.is_action_pressed("jump") and velocity.y > 40.0


func try_drop_through_one_way() -> bool:
	if not is_on_floor() or get_move_input_y() <= 0.5:
		return false
	for i: int in range(get_slide_collision_count()):
		var col: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider is CollisionObject2D:
			var obj: CollisionObject2D = collider as CollisionObject2D
			if (obj.collision_layer & 2) != 0 and (obj.collision_layer & 1) == 0:
				_one_way_drop_timer = ONE_WAY_DROP_TIME
				collision_mask = 1 # Temporarily ignore layer 2 (one_way)
				position.y += 2.0
				jump_buffer_timer = 0.0
				coyote_timer = 0.0
				return true
	return false


# --- Combat Helpers ---

func get_attack_direction() -> Vector2:
	var input_y: float = get_move_input_y()
	if input_y < -0.5:
		return Vector2.UP
	if input_y > 0.5 and not is_on_floor():
		return Vector2.DOWN
	return Vector2(float(facing_dir), 0.0)


func advance_combo_step() -> int:
	if combo_reset_timer > 0.0:
		combo_step = (combo_step + 1) % 3
	else:
		combo_step = 0
	combo_reset_timer = COMBO_RESET_TIME
	return combo_step


func spawn_flame_projectile() -> FlameProjectile:
	if FLAME_PROJECTILE_SCENE == null:
		return null
	var instance: Node = FLAME_PROJECTILE_SCENE.instantiate()
	var projectile: FlameProjectile = instance as FlameProjectile
	if projectile == null:
		instance.queue_free()
		return null

	var spawn_parent: Node = get_parent() if get_parent() != null else get_tree().current_scene
	spawn_parent.add_child(projectile)
	var origin: Vector2 = spell_muzzle.global_position if spell_muzzle != null else global_position + Vector2(float(facing_dir) * 28.0, -4.0)
	projectile.global_position = origin
	projectile.setup(Vector2(float(facing_dir), 0.0), self, SPELL_DAMAGE)
	return projectile


func apply_pogo_bounce() -> void:
	velocity.y = POGO_BOUNCE_VELOCITY
	air_dash_available = true
	squash_stretch(Vector2(0.84, 1.18))
	spawn_dust(Vector2(0.0, 26.0), 5, 70.0)


func is_parry_active() -> bool:
	return parry_active and not is_dead


func start_invulnerability(duration: float = HURT_INVULN_DURATION) -> void:
	invuln_timer = maxf(invuln_timer, duration)
	if hurtbox != null:
		hurtbox.set_invulnerable(true)


# --- Interaction ---

func try_interact() -> bool:
	var frame: int = Engine.get_process_frames()
	if frame == _last_interact_frame:
		return false
	if interact_sensor == null:
		return false

	var best_area: Area2D = null
	var best_dist: float = INF
	for area: Area2D in interact_sensor.get_overlapping_areas():
		if area != null and area.has_method("interact"):
			var dist: float = global_position.distance_squared_to(area.global_position)
			if dist < best_dist:
				best_dist = dist
				best_area = area

	if best_area != null:
		_last_interact_frame = frame
		best_area.call("interact", self)
		return true
	return false


# --- Visual & Juice FX Helpers ---

func squash_stretch(target_scale: Vector2) -> void:
	visual_scale = target_scale


func trigger_parry_ring(success: bool) -> void:
	_parry_ring_success = success
	_parry_ring_duration = 0.28 if success else PARRY_ACTIVE_WINDOW
	_parry_ring_timer = _parry_ring_duration
	if success:
		_hit_flash_timer = 0.14 if SettingsManager.reduce_flash else 0.20
		squash_stretch(Vector2(1.18, 0.88))


func trigger_ground_pound_shockwave() -> void:
	_ground_pound_ring_timer = 0.26
	squash_stretch(Vector2(1.32, 0.72))
	spawn_dust(Vector2(0.0, 30.0), 10, 180.0)


func spawn_afterimage() -> void:
	var ghost_poly: PackedVector2Array = PackedVector2Array([
		Vector2(-15.0 * float(facing_dir), 30.0),
		Vector2(-11.0 * float(facing_dir), -10.0),
		Vector2(-6.0 * float(facing_dir), -29.0),
		Vector2(8.0 * float(facing_dir), -28.0),
		Vector2(13.0 * float(facing_dir), -8.0),
		Vector2(14.0 * float(facing_dir), 30.0)
	])
	_afterimages.append({
		"world_pos": global_position,
		"poly": ghost_poly,
		"life": 0.22,
		"max_life": 0.22,
		"tier": GameState.get_dagger_tier()
	})


func spawn_dust(origin_offset: Vector2, count: int = 5, spread_x: float = 90.0) -> void:
	for i: int in range(count):
		_dust_particles.append({
			"world_pos": global_position + origin_offset + Vector2(randf_range(-8.0, 8.0), randf_range(-3.0, 3.0)),
			"vel": Vector2(randf_range(-spread_x, spread_x), randf_range(-85.0, -18.0)),
			"life": randf_range(0.18, 0.34),
			"max_life": 0.34,
			"radius": randf_range(2.5, 5.5)
		})


# --- Internal Signal Handlers ---

func _on_hurtbox_damaged(info: DamageInfo) -> void:
	if is_dead or info == null:
		return

	# Parry window check!
	if is_parry_active() and info.parryable:
		_handle_successful_parry(info)
		return

	if invuln_timer > 0.0:
		return

	GameState.damage_player(info.amount)
	_hit_flash_timer = 0.12 if SettingsManager.reduce_flash else 0.18

	if GameState.player_hp <= 0:
		is_dead = true
		state_machine.transition_to(&"dead", {"damage_info": info})
	else:
		state_machine.transition_to(&"hurt", {"damage_info": info})


func _handle_successful_parry(info: DamageInfo) -> void:
	parry_active = false
	parry_cooldown_timer = 0.0
	GameState.add_resource(PARRY_RESOURCE_GAIN)
	EventBus.hitstop_requested.emit(0.08)
	EventBus.camera_shake_requested.emit(7.0, 0.14)
	AudioManager.play_sfx("parry_success")
	trigger_parry_ring(true)
	start_invulnerability(0.25)

	if info.source_node != null and info.source_node.has_method("on_parried"):
		info.source_node.call("on_parried")

	# Slight authoritative recoil away from parried strike
	var push_dir: float = signf(global_position.x - info.source_position.x)
	if push_dir == 0.0:
		push_dir = float(-facing_dir)
	velocity.x = push_dir * 160.0

	if state_machine.current_state_name == &"parry":
		state_machine.transition_to(&"idle" if is_on_floor() else &"fall")


func _on_dagger_slash_hit(_hurtbox: Hurtbox, _info: DamageInfo, slash_dir: Vector2) -> void:
	if slash_dir.y > 0.5 and not is_on_floor():
		apply_pogo_bounce()


func _on_hazard_entered(area: Area2D) -> void:
	_apply_hazard_damage(area.global_position, area)


func _on_hazard_body_entered(body: Node2D) -> void:
	_apply_hazard_damage(body.global_position, body)


func _apply_hazard_damage(source_pos: Vector2, source: Node) -> void:
	if is_dead or invuln_timer > 0.0:
		return
	var info := DamageInfo.create(1, source_pos, Vector2(200.0, -340.0), false, "hazard", source)
	_on_hurtbox_damaged(info)


func _on_grey_eye_toggled(active: bool) -> void:
	grey_eye_active = active


# --- Timers & Procedural Silhouette Animation ---

func _tick_timers(delta: float) -> void:
	if coyote_timer > 0.0:
		coyote_timer = maxf(0.0, coyote_timer - delta)
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	if spell_cooldown_timer > 0.0:
		spell_cooldown_timer = maxf(0.0, spell_cooldown_timer - delta)
	if parry_cooldown_timer > 0.0:
		parry_cooldown_timer = maxf(0.0, parry_cooldown_timer - delta)
	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer = maxf(0.0, wall_jump_lock_timer - delta)
	if combo_reset_timer > 0.0:
		combo_reset_timer = maxf(0.0, combo_reset_timer - delta)

	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)
		if invuln_timer <= 0.0 and not is_dead and hurtbox != null:
			hurtbox.set_invulnerable(false)

	if _one_way_drop_timer > 0.0:
		_one_way_drop_timer = maxf(0.0, _one_way_drop_timer - delta)
		if _one_way_drop_timer <= 0.0:
			collision_mask = 3 # Restore world + one_way

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	if _parry_ring_timer > 0.0:
		_parry_ring_timer = maxf(0.0, _parry_ring_timer - delta)
	if _ground_pound_ring_timer > 0.0:
		_ground_pound_ring_timer = maxf(0.0, _ground_pound_ring_timer - delta)


func _setup_optional_silhouette_shader() -> void:
	if visual_root == null:
		return
	if not ResourceLoader.exists(SILHOUETTE_SHADER_PATH):
		return
	var shader_res: Resource = load(SILHOUETTE_SHADER_PATH)
	if shader_res is Shader:
		_silhouette_material = ShaderMaterial.new()
		_silhouette_material.shader = shader_res as Shader
		_silhouette_material.set_shader_parameter("rim_color", COL_SUNSET_ORANGE)
		_silhouette_material.set_shader_parameter("rim_strength", 0.42)
		_silhouette_material.set_shader_parameter("ink_wobble_px", 0.45)
		_silhouette_material.set_shader_parameter("flash_amount", 0.0)
		_silhouette_material.set_shader_parameter("flash_color", COL_PALE_GOLD)
		for child: Node in visual_root.get_children():
			if child is Polygon2D:
				(child as Polygon2D).material = _silhouette_material


func _update_visual_rig(delta: float) -> void:
	visual_scale = visual_scale.lerp(Vector2.ONE, minf(1.0, delta * 14.0))

	var target_tilt: float = clampf(velocity.x / RUN_SPEED * 0.11, -0.14, 0.14)
	if state_machine != null and state_machine.current_state_name == &"glide":
		target_tilt = clampf(velocity.x / RUN_SPEED * 0.18, -0.20, 0.20)
	elif is_dead:
		target_tilt = float(facing_dir) * 1.15
	visual_tilt = lerpf(visual_tilt, target_tilt, minf(1.0, delta * 12.0))

	if visual_root != null:
		visual_root.scale = Vector2(float(facing_dir) * visual_scale.x, visual_scale.y)
		visual_root.rotation = visual_tilt
		if invuln_timer > 0.0 and not is_dead:
			var blink_speed: float = 12.0 if SettingsManager.reduce_flash else 24.0
			visual_root.modulate.a = 0.55 if sin(_anim_time * blink_speed) > 0.0 else 1.0
		else:
			visual_root.modulate.a = 1.0

	if _silhouette_material != null:
		var flash_amt: float = clampf(_hit_flash_timer / 0.18, 0.0, 1.0)
		if SettingsManager.reduce_flash:
			flash_amt *= 0.45
		_silhouette_material.set_shader_parameter("flash_amount", flash_amt)
		var tier: int = GameState.get_dagger_tier()
		var rim: Color = COL_PALE_GOLD if tier >= 2 else COL_SUNSET_ORANGE
		_silhouette_material.set_shader_parameter("rim_color", rim)

	_animate_cloth_polygons()


func _animate_cloth_polygons() -> void:
	var speed_ratio: float = clampf(absf(velocity.x) / RUN_SPEED, 0.0, 1.5)
	var is_gliding: bool = state_machine != null and state_machine.current_state_name == &"glide"
	var wind_sway: float = sin(_anim_time * (4.2 + speed_ratio * 5.0)) * (2.5 + speed_ratio * 4.5)
	var trail_pull: float = -speed_ratio * 11.0
	var lift_y: float = clampf(-velocity.y * 0.014, -7.0, 8.0)

	if cloak_poly != null and _base_cloak_points.size() >= 6:
		var pts := _base_cloak_points.duplicate()
		# Clockwise hem order in local facing space: pts[3]=front-right, pts[4]=center, pts[5]=back-left.
		var glide_spread: float = -14.0 if is_gliding else 0.0
		var front_pt: Vector2 = _base_cloak_points[3] + Vector2(trail_pull * 0.35 + wind_sway * 0.4 + (10.0 if is_gliding else 0.0), lift_y * 0.4)
		var mid_pt: Vector2 = _base_cloak_points[4] + Vector2(trail_pull * 0.7 - wind_sway * 0.6, lift_y * 0.7)
		var back_pt: Vector2 = _base_cloak_points[5] + Vector2(trail_pull + wind_sway + glide_spread, lift_y)
		# Keep hem strictly ordered (back_pt.x < mid_pt.x < front_pt.x) so the polygon never self-intersects.
		front_pt.x = maxf(front_pt.x, mid_pt.x + 4.0)
		back_pt.x = minf(back_pt.x, mid_pt.x - 4.0)
		pts[3] = front_pt
		pts[4] = mid_pt
		pts[5] = back_pt
		cloak_poly.polygon = pts

	if scarf_poly != null and _base_scarf_points.size() >= 4:
		var spts := _base_scarf_points.duplicate()
		# Clockwise scarf order: spts[2]=lower-inner tail, spts[3]=upper-outer tail.
		var tail_wave: float = sin(_anim_time * (6.5 + speed_ratio * 6.0)) * (3.0 + speed_ratio * 4.0)
		var lower_tail: Vector2 = _base_scarf_points[2] + Vector2(trail_pull * 0.85, tail_wave * 0.6 + lift_y * 0.4)
		var upper_tail: Vector2 = _base_scarf_points[3] + Vector2(trail_pull * 1.15, tail_wave + lift_y * 0.6)
		upper_tail.x = minf(upper_tail.x, lower_tail.x - 3.0)
		upper_tail.y = minf(upper_tail.y, lower_tail.y - 3.0)
		spts[2] = lower_tail
		spts[3] = upper_tail
		scarf_poly.polygon = spts


func _update_fx_particles(delta: float) -> void:
	if not _afterimages.is_empty():
		var next_ghosts: Array[Dictionary] = []
		for ghost: Dictionary in _afterimages:
			var life: float = float(ghost["life"]) - delta
			if life > 0.0:
				ghost["life"] = life
				next_ghosts.append(ghost)
		_afterimages = next_ghosts

	if not _dust_particles.is_empty():
		var next_dust: Array[Dictionary] = []
		for p: Dictionary in _dust_particles:
			var life: float = float(p["life"]) - delta
			if life > 0.0:
				p["life"] = life
				p["world_pos"] = (p["world_pos"] as Vector2) + (p["vel"] as Vector2) * delta
				p["vel"] = (p["vel"] as Vector2) * (1.0 - 4.0 * delta)
				next_dust.append(p)
		_dust_particles = next_dust


func _draw() -> void:
	# 1. Dash afterimage silhouettes
	for ghost: Dictionary in _afterimages:
		var alpha: float = clampf(float(ghost["life"]) / float(ghost["max_life"]), 0.0, 1.0)
		var local_offset: Vector2 = to_local(ghost["world_pos"] as Vector2)
		var poly: PackedVector2Array = ghost["poly"] as PackedVector2Array
		var shifted := PackedVector2Array()
		for pt: Vector2 in poly:
			shifted.append(pt + local_offset)
		var ghost_col: Color = COL_CLOAK.lerp(COL_PALE_GOLD, 0.25 if int(ghost["tier"]) >= 1 else 0.1)
		ghost_col.a = alpha * 0.45
		if shifted.size() >= 3:
			draw_colored_polygon(shifted, ghost_col)

	# 2. Dust motes (jump / landing / ground pound)
	for p: Dictionary in _dust_particles:
		var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var col: Color = COL_OCHRE
		col.a = alpha * 0.6
		draw_circle(to_local(p["world_pos"] as Vector2), float(p["radius"]) * alpha, col)

	# 3. Distinctive Heterochromia Eyes on Farid's wrapped desert headscarf:
	#    LEFT eye = Grey (#8B95A5), RIGHT eye = Blue (#4A90D9).
	if not is_dead:
		_draw_heterochromia_eyes()
		_draw_held_flame_dagger()

	# 4. Parry Najdi geometric pale-gold seal ring
	if _parry_ring_timer > 0.0:
		_draw_parry_seal_ring()

	# 5. Ground Pound shockwave ring
	if _ground_pound_ring_timer > 0.0:
		var gp_t: float = 1.0 - clampf(_ground_pound_ring_timer / 0.26, 0.0, 1.0)
		var gp_alpha: float = (1.0 - gp_t) * (0.55 if SettingsManager.reduce_flash else 0.85)
		var gp_col: Color = COL_PALE_GOLD
		gp_col.a = gp_alpha
		var rx: float = lerpf(24.0, 118.0, gp_t)
		draw_line(Vector2(-rx, 30.0), Vector2(rx, 30.0), gp_col, 4.0 * (1.0 - gp_t) + 1.0, true)


func _draw_heterochromia_eyes() -> void:
	var f: float = float(facing_dir)
	var bob_y: float = sin(_anim_time * 3.4) * 0.6
	# Slightly 3/4 head orientation so BOTH eyes remain clearly readable in silhouette:
	# Anatomically: Farid's LEFT eye is Grey (#8B95A5), RIGHT eye is Blue (#4A90D9).
	var far_eye_pos: Vector2 = Vector2(f * 2.2, -20.5 + bob_y)
	var near_eye_pos: Vector2 = Vector2(f * 7.2, -20.0 + bob_y)
	var left_eye_pos: Vector2 = far_eye_pos if facing_dir > 0 else near_eye_pos
	var right_eye_pos: Vector2 = near_eye_pos if facing_dir > 0 else far_eye_pos

	# Subtle grey-eye aura when Grey Eye seal vision is active
	if grey_eye_active:
		var aura_col: Color = COL_EYE_GREY
		aura_col.a = 0.45 + 0.15 * sin(_anim_time * 8.0)
		draw_circle(left_eye_pos, 5.5, aura_col)

	var left_col: Color = COL_EYE_GREY
	var right_col: Color = COL_EYE_BLUE
	draw_circle(left_eye_pos, 2.2, left_col)
	draw_circle(right_eye_pos, 2.2, right_col)
	# Crisp specular glint
	draw_circle(left_eye_pos + Vector2(0.5 * f, -0.5), 0.75, Color(0.95, 0.97, 1.0, 0.9))
	draw_circle(right_eye_pos + Vector2(0.5 * f, -0.5), 0.75, Color(0.92, 0.97, 1.0, 0.95))


func _draw_held_flame_dagger() -> void:
	var tier: int = clampi(GameState.get_dagger_tier(), 0, 2)
	var f: float = float(facing_dir)
	var hand_pos: Vector2 = Vector2(f * 13.0, 2.0 + sin(_anim_time * 5.0) * 1.1)
	var blade_len: float = 14.0 + float(tier) * 7.0
	var glow_col: Color = flame_dagger.get_tier_color(tier) if flame_dagger != null else COL_PALE_GOLD
	var aura_col: Color = glow_col
	aura_col.a = (0.28 + float(tier) * 0.14) * (0.65 if SettingsManager.reduce_flash else 1.0)

	# Ember halo around held flame dagger
	draw_circle(hand_pos + Vector2(f * blade_len * 0.5, -2.0), 6.0 + float(tier) * 3.5, aura_col)

	# Stylized curved Arabian jambiya-inspired flame dagger silhouette
	var blade_poly := PackedVector2Array([
		hand_pos + Vector2(0.0, -2.5),
		hand_pos + Vector2(f * (blade_len * 0.65), -3.5 - float(tier)),
		hand_pos + Vector2(f * blade_len, -6.0 - float(tier) * 1.5),
		hand_pos + Vector2(f * (blade_len * 0.6), 2.5),
		hand_pos + Vector2(0.0, 2.5)
	])
	draw_colored_polygon(blade_poly, glow_col)


func _draw_parry_seal_ring() -> void:
	var progress: float = 1.0 - clampf(_parry_ring_timer / maxf(_parry_ring_duration, 0.001), 0.0, 1.0)
	var alpha: float = (1.0 - progress) * (0.6 if SettingsManager.reduce_flash else 0.95)
	var radius: float = lerpf(24.0, 74.0 if _parry_ring_success else 42.0, progress)
	var ring_col: Color = COL_PALE_GOLD
	ring_col.a = alpha

	# Outer Najdi octagonal star seal + luminous ring
	draw_arc(Vector2(0.0, -4.0), radius, 0.0, TAU, 32, ring_col, 3.5 if _parry_ring_success else 2.2, true)
	var diamond := PackedVector2Array([
		Vector2(0.0, -4.0 - radius * 0.92),
		Vector2(radius * 0.92, -4.0),
		Vector2(0.0, -4.0 + radius * 0.92),
		Vector2(-radius * 0.92, -4.0),
		Vector2(0.0, -4.0 - radius * 0.92)
	])
	var inner_col: Color = COL_SUNSET_ORANGE.lerp(COL_PALE_GOLD, 0.65)
	inner_col.a = alpha * 0.8
	draw_polyline(diamond, inner_col, 2.0, true)
