class_name Player
extends CharacterBody2D
## Farid — playable protagonist of SHAALA (شعلة).
## Tight metroidvania movement (coyote time, jump buffering, variable jump height,
## wall-cling, dash, double jump, ground-pound, glide), articulated Najdi desert-guardian
## visual rig with heterochromia eyes, 3-tier Flame Dagger combat, ranged Flame Spell,
## Parry with Resource generation, interactive surface/wind physics, and Dev-Mode hooks.
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

# --- Palette Colors (Desert Guardian Farid — Original Najdi Silhouette) ---
const COL_CLOAK: Color = Color(0.086, 0.106, 0.200, 1.0)       # Night indigo #161B33
const COL_DEEP_SHADOW: Color = Color(0.051, 0.063, 0.129, 1.0) # Deep shadow #0D1021
const COL_DESERT_RED: Color = Color(0.659, 0.267, 0.196, 1.0)  # Desert red #A84432
const COL_OCHRE: Color = Color(0.776, 0.545, 0.349, 1.0)       # Mud-brick ochre #C68B59
const COL_SAND_LIGHT: Color = Color(0.910, 0.769, 0.604, 1.0)  # Warm sand light #E8C49A
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
@onready var back_scarf_poly: Polygon2D = $VisualRoot/BackScarfTail
@onready var back_cloak_poly: Polygon2D = $VisualRoot/BackCloak
@onready var back_leg: Node2D = $VisualRoot/BackLeg
@onready var front_leg: Node2D = $VisualRoot/FrontLeg
@onready var torso_root: Node2D = $VisualRoot/TorsoRoot
@onready var front_cloak_poly: Polygon2D = $VisualRoot/TorsoRoot/FrontCloak
@onready var cloak_pleat_poly: Polygon2D = $VisualRoot/TorsoRoot/CloakPleat
@onready var sadu_trim_poly: Polygon2D = $VisualRoot/TorsoRoot/SaduTrimBand
@onready var off_arm: Node2D = $VisualRoot/TorsoRoot/OffArm
@onready var dagger_arm: Node2D = $VisualRoot/TorsoRoot/DaggerArm
@onready var head_root: Node2D = $VisualRoot/TorsoRoot/HeadRoot
@onready var front_scarf_poly: Polygon2D = $VisualRoot/TorsoRoot/HeadRoot/FrontScarfTail
@onready var spell_muzzle: Marker2D = $SpellMuzzle
@onready var wall_ray_left: RayCast2D = $WallRayLeft
@onready var wall_ray_right: RayCast2D = $WallRayRight

# --- Runtime Movement & Combat State ---
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
var god_mode: bool = false
var active_wall_normal: int = 0

# --- Environmental Surface & Wind State ---
var _active_surfaces: Dictionary = {} # surface_type -> {count, speed_mult, jump_mult}
var _surface_speed_mult: float = 1.0
var _surface_jump_mult: float = 1.0
var _in_deep_sand: bool = false
var _surface_sink_y: float = 0.0
var _wind_forces: Dictionary = {}     # source_id -> Vector2
var _smoothed_wind: Vector2 = Vector2.ZERO

# --- Articulated Visual Rig & Juice State ---
var visual_scale: Vector2 = Vector2.ONE
var visual_tilt: float = 0.0
var _anim_time: float = 0.0
var _stride_phase: float = 0.0
var _blink_timer: float = 3.2
var _blink_duration: float = 0.0
var _one_way_drop_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _parry_ring_timer: float = 0.0
var _parry_ring_duration: float = 0.24
var _parry_ring_success: bool = false
var _ground_pound_ring_timer: float = 0.0
var _dash_streak_timer: float = 0.0
var _dash_streak_dir: int = 1
var _attack_pose_timer: float = 0.0
var _attack_pose_dir: Vector2 = Vector2.RIGHT
var _attack_pose_step: int = 0
var _cast_pose_timer: float = 0.0
var _afterimages: Array[Dictionary] = []
var _dust_particles: Array[Dictionary] = []
var _spark_particles: Array[Dictionary] = []
var _silhouette_material: ShaderMaterial = null
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
	_tick_blink(delta)
	state_machine.update(delta)
	_update_visual_rig(delta)
	_update_fx_particles(delta)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_wind_smoothing(delta)

	if controls_enabled and not is_dead and Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	state_machine.physics_update(delta)
	_apply_environmental_wind(delta)
	move_and_slide()

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		reset_air_mobility()


# --- Environmental Surface, Wind & Dev-Mode API ---

func enter_surface(surface_type: String, speed_multiplier: float, jump_multiplier: float) -> void:
	var entry: Dictionary = _active_surfaces.get(surface_type, {
		"count": 0,
		"speed_mult": speed_multiplier,
		"jump_mult": jump_multiplier,
	})
	entry["count"] = int(entry["count"]) + 1
	entry["speed_mult"] = clampf(speed_multiplier, 0.25, 1.5)
	entry["jump_mult"] = clampf(jump_multiplier, 0.4, 1.5)
	_active_surfaces[surface_type] = entry
	_recompute_surface_modifiers()
	if surface_type == "deep_sand":
		spawn_dust(Vector2(0.0, 29.0), 6, 95.0)


func exit_surface(surface_type: String) -> void:
	if not _active_surfaces.has(surface_type):
		return
	var entry: Dictionary = _active_surfaces[surface_type] as Dictionary
	var next_count: int = int(entry["count"]) - 1
	if next_count <= 0:
		_active_surfaces.erase(surface_type)
	else:
		entry["count"] = next_count
		_active_surfaces[surface_type] = entry
	_recompute_surface_modifiers()


func get_surface_speed_multiplier() -> float:
	return _surface_speed_mult


func get_surface_jump_multiplier() -> float:
	return _surface_jump_mult


func is_in_deep_sand() -> bool:
	return _in_deep_sand


func add_wind_force(source_id: int, force: Vector2) -> void:
	_wind_forces[source_id] = force


func remove_wind_force(source_id: int) -> void:
	_wind_forces.erase(source_id)


func get_total_wind_force() -> Vector2:
	var total: Vector2 = Vector2.ZERO
	for force_val: Variant in _wind_forces.values():
		if force_val is Vector2:
			total += force_val as Vector2
	return total


func set_god_mode(enabled: bool) -> void:
	god_mode = enabled


func is_god_mode() -> bool:
	return god_mode


func teleport_to(world_pos: Vector2) -> void:
	global_position = world_pos
	velocity = Vector2.ZERO
	coyote_timer = 0.0
	wall_jump_lock_timer = 0.0
	jump_buffer_timer = 0.0
	if flame_dagger != null:
		flame_dagger.stop_slash()
	parry_active = false
	spawn_dust(Vector2(0.0, 12.0), 8, 120.0)
	if not is_dead and state_machine != null:
		state_machine.transition_to(&"idle" if is_on_floor() else &"fall")


func _recompute_surface_modifiers() -> void:
	var spd: float = 1.0
	var jmp: float = 1.0
	for entry_var: Variant in _active_surfaces.values():
		if entry_var is Dictionary:
			var entry: Dictionary = entry_var as Dictionary
			spd = minf(spd, float(entry.get("speed_mult", 1.0)))
			jmp = minf(jmp, float(entry.get("jump_mult", 1.0)))
	_surface_speed_mult = clampf(spd, 0.25, 1.5)
	_surface_jump_mult = clampf(jmp, 0.4, 1.5)
	_in_deep_sand = _active_surfaces.has("deep_sand")


func _update_wind_smoothing(delta: float) -> void:
	var target_wind: Vector2 = get_total_wind_force()
	_smoothed_wind = _smoothed_wind.lerp(target_wind, minf(1.0, delta * 6.5))


func _apply_environmental_wind(delta: float) -> void:
	if is_dead or _smoothed_wind.length_squared() < 1.0:
		return
	var cur_state: StringName = state_machine.current_state_name if state_machine != null else &""
	# Dash cuts straight through wind cleanly so Dash gaps remain reliable
	if cur_state == &"dash" or cur_state == &"ground_pound":
		return

	if absf(_smoothed_wind.x) > 1.0:
		var horiz_weight: float = 0.45 if is_on_floor() else 1.05
		if cur_state == &"glide":
			horiz_weight = 1.35
		velocity.x += _smoothed_wind.x * horiz_weight * delta
		var max_wind_x: float = RUN_SPEED * 1.45
		velocity.x = clampf(velocity.x, -max_wind_x, max_wind_x)

	if absf(_smoothed_wind.y) > 1.0:
		var vert_weight: float = 1.35 if cur_state == &"glide" else 1.15
		velocity.y += _smoothed_wind.y * vert_weight * delta
		velocity.y = clampf(velocity.y, -MAX_FALL_SPEED, MAX_FALL_SPEED)


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
	active_wall_normal = 0
	_active_surfaces.clear()
	_recompute_surface_modifiers()
	_wind_forces.clear()
	_smoothed_wind = Vector2.ZERO
	_surface_sink_y = 0.0
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
	var surface_mult: float = _surface_speed_mult if grounded else lerpf(1.0, _surface_speed_mult, 0.35)
	var target_speed: float = input_x * RUN_SPEED * speed_scale * surface_mult
	var accel: float = GROUND_ACCEL if grounded else AIR_ACCEL
	var decel: float = GROUND_DECEL if grounded else AIR_DECEL
	# Extra snappy turn acceleration when reversing direction on solid ground
	var is_reversing: bool = grounded and absf(input_x) > 0.05 and (input_x * velocity.x) < -20.0
	var rate: float = (accel + decel * 0.65) if is_reversing else (accel if absf(input_x) > 0.01 else decel)
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


func notify_attack_pose(dir: Vector2, step: int) -> void:
	_attack_pose_dir = dir
	_attack_pose_step = step
	_attack_pose_timer = 0.24 if step < 2 else 0.34


func notify_cast_pose() -> void:
	_cast_pose_timer = 0.26


func trigger_dash_streak(dir: int) -> void:
	_dash_streak_dir = 1 if dir >= 0 else -1
	_dash_streak_timer = DASH_DURATION + 0.06


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
	_parry_ring_duration = 0.30 if success else PARRY_ACTIVE_WINDOW
	_parry_ring_timer = _parry_ring_duration
	if success:
		_hit_flash_timer = 0.14 if SettingsManager.reduce_flash else 0.22
		squash_stretch(Vector2(1.18, 0.88))


func trigger_ground_pound_shockwave() -> void:
	_ground_pound_ring_timer = 0.28
	squash_stretch(Vector2(1.34, 0.70))
	spawn_dust(Vector2(0.0, 30.0), 12, 195.0)


func spawn_afterimage() -> void:
	var f: float = float(facing_dir)
	# Strictly simple clockwise desert-guardian lunge silhouette
	var ghost_poly: PackedVector2Array = PackedVector2Array([
		Vector2(-8.0 * f, -27.0),
		Vector2(6.0 * f, -28.0),
		Vector2(13.0 * f, -14.0),
		Vector2(15.0 * f, 4.0),
		Vector2(11.0 * f, 26.0),
		Vector2(-10.0 * f, 28.0),
		Vector2(-21.0 * f, 18.0),
		Vector2(-14.0 * f, -9.0)
	])
	if facing_dir < 0:
		ghost_poly.reverse()
	_afterimages.append({
		"world_pos": global_position,
		"poly": ghost_poly,
		"life": 0.22,
		"max_life": 0.22,
		"tier": GameState.get_dagger_tier()
	})
	if _afterimages.size() > 6:
		_afterimages.pop_front()


func spawn_dust(origin_offset: Vector2, count: int = 5, spread_x: float = 90.0) -> void:
	var sand_mode: bool = _in_deep_sand
	var actual_count: int = count + (3 if sand_mode else 0)
	var base_col: Color = COL_SAND_LIGHT if sand_mode else COL_OCHRE
	for i: int in range(actual_count):
		_dust_particles.append({
			"world_pos": global_position + origin_offset + Vector2(randf_range(-9.0, 9.0), randf_range(-3.0, 3.0)),
			"vel": Vector2(randf_range(-spread_x, spread_x), randf_range(-105.0 if sand_mode else -85.0, -18.0)),
			"life": randf_range(0.20, 0.38 if sand_mode else 0.32),
			"max_life": 0.38 if sand_mode else 0.32,
			"radius": randf_range(3.0 if sand_mode else 2.4, 6.8 if sand_mode else 5.2),
			"color": base_col.lerp(COL_DESERT_RED, randf_range(0.0, 0.35))
		})


func spawn_wall_sparks(wall_normal: int, count: int = 3) -> void:
	var wall_x: float = float(-wall_normal) * 14.0
	for i: int in range(count):
		_spark_particles.append({
			"world_pos": global_position + Vector2(wall_x, randf_range(-10.0, 14.0)),
			"vel": Vector2(float(wall_normal) * randf_range(40.0, 120.0), randf_range(-110.0, -30.0)),
			"life": randf_range(0.14, 0.26),
			"max_life": 0.26,
			"color": COL_PALE_GOLD if randf() > 0.4 else COL_SUNSET_ORANGE
		})


# --- Internal Signal Handlers ---

func _on_hurtbox_damaged(info: DamageInfo) -> void:
	if is_dead or info == null:
		return

	# Parry window check works even in God Mode so players can test parrying!
	if is_parry_active() and info.parryable:
		_handle_successful_parry(info)
		return

	if god_mode or invuln_timer > 0.0:
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
	if is_dead or god_mode or invuln_timer > 0.0:
		return
	var info := DamageInfo.create(1, source_pos, Vector2(200.0, -340.0), false, "hazard", source)
	_on_hurtbox_damaged(info)


func _on_grey_eye_toggled(active: bool) -> void:
	grey_eye_active = active


# --- Timers & Articulated Silhouette Animation ---

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
	if _dash_streak_timer > 0.0:
		_dash_streak_timer = maxf(0.0, _dash_streak_timer - delta)
	if _attack_pose_timer > 0.0:
		_attack_pose_timer = maxf(0.0, _attack_pose_timer - delta)
	if _cast_pose_timer > 0.0:
		_cast_pose_timer = maxf(0.0, _cast_pose_timer - delta)


func _tick_blink(delta: float) -> void:
	if _blink_duration > 0.0:
		_blink_duration = maxf(0.0, _blink_duration - delta)
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_duration = 0.11
			_blink_timer = randf_range(3.2, 5.4)


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
		_silhouette_material.set_shader_parameter("ink_wobble_px", 0.35)
		_silhouette_material.set_shader_parameter("flash_amount", 0.0)
		_silhouette_material.set_shader_parameter("flash_color", COL_PALE_GOLD)
		_apply_shader_recursive(visual_root)


func _apply_shader_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Polygon2D:
			(child as Polygon2D).material = _silhouette_material
		_apply_shader_recursive(child)


func _update_visual_rig(delta: float) -> void:
	visual_scale = visual_scale.lerp(Vector2.ONE, minf(1.0, delta * 14.0))

	var target_sink: float = 4.5 if (_in_deep_sand and is_on_floor()) else 0.0
	_surface_sink_y = lerpf(_surface_sink_y, target_sink, minf(1.0, delta * 12.0))

	var cur_state: StringName = state_machine.current_state_name if state_machine != null else &"idle"
	var speed_ratio: float = clampf(absf(velocity.x) / RUN_SPEED, 0.0, 1.5)
	if cur_state == &"run" or (is_on_floor() and absf(velocity.x) > 30.0):
		_stride_phase += delta * (9.5 + speed_ratio * 4.5)
	else:
		_stride_phase = lerpf(_stride_phase, 0.0, minf(1.0, delta * 8.0))

	var target_tilt: float = clampf(velocity.x / RUN_SPEED * 0.10, -0.14, 0.14)
	if cur_state == &"dash":
		target_tilt = float(facing_dir) * 0.24
	elif cur_state == &"glide":
		target_tilt = clampf(velocity.x / RUN_SPEED * 0.18, -0.20, 0.20)
	elif cur_state == &"wall_cling":
		target_tilt = float(-active_wall_normal) * 0.08
	elif cur_state == &"hurt":
		target_tilt = float(-facing_dir) * 0.22
	elif is_dead:
		target_tilt = float(facing_dir) * 1.18
	visual_tilt = lerpf(visual_tilt, target_tilt, minf(1.0, delta * 14.0))

	if visual_root != null:
		# Anchor squash-and-stretch near feet (+31) plus subtle deep-sand sink
		visual_root.position = Vector2(0.0, (1.0 - visual_scale.y) * 30.0 + _surface_sink_y)
		visual_root.scale = Vector2(float(facing_dir) * visual_scale.x, visual_scale.y)
		visual_root.rotation = visual_tilt
		if invuln_timer > 0.0 and not is_dead:
			var blink_speed: float = 12.0 if SettingsManager.reduce_flash else 24.0
			visual_root.modulate.a = 0.55 if sin(_anim_time * blink_speed) > 0.0 else 1.0
		elif not is_dead:
			visual_root.modulate.a = 1.0

	if _silhouette_material != null:
		var flash_amt: float = clampf(_hit_flash_timer / 0.18, 0.0, 1.0)
		if SettingsManager.reduce_flash:
			flash_amt *= 0.45
		_silhouette_material.set_shader_parameter("flash_amount", flash_amt)
		var tier: int = GameState.get_dagger_tier()
		var rim: Color = COL_PALE_GOLD if tier >= 2 else COL_SUNSET_ORANGE
		_silhouette_material.set_shader_parameter("rim_color", rim)

	_animate_articulated_limbs(delta, cur_state, speed_ratio)
	_animate_cloth_and_scarves(cur_state, speed_ratio)


func _animate_articulated_limbs(delta: float, cur_state: StringName, speed_ratio: float) -> void:
	var blend: float = minf(1.0, delta * 16.0)
	var breathe: float = sin(_anim_time * 3.1) * 1.1

	var target_torso_y: float = 4.0 + breathe * 0.4
	var target_torso_rot: float = 0.0
	var target_head_rot: float = 0.0
	var target_front_leg_rot: float = 0.0
	var target_back_leg_rot: float = 0.0
	var target_front_leg_pos: Vector2 = Vector2(3.0, 7.0)
	var target_back_leg_pos: Vector2 = Vector2(-3.0, 7.0)
	var target_dagger_arm_rot: float = -0.32 + sin(_anim_time * 3.1) * 0.05
	var target_off_arm_rot: float = 0.18 - sin(_anim_time * 3.1) * 0.04

	match cur_state:
		&"run":
			var s: float = sin(_stride_phase)
			var c: float = cos(_stride_phase)
			target_torso_y = 4.0 + absf(s) * -2.2
			target_torso_rot = 0.11 * speed_ratio
			target_head_rot = -0.06 * speed_ratio
			target_front_leg_rot = s * 0.68
			target_back_leg_rot = -s * 0.68
			target_front_leg_pos = Vector2(3.0 + s * 2.5, 7.0 + maxf(0.0, -c) * -2.5)
			target_back_leg_pos = Vector2(-3.0 - s * 2.5, 7.0 + maxf(0.0, c) * -2.5)
			target_dagger_arm_rot = -0.45 - s * 0.35
			target_off_arm_rot = 0.28 + s * 0.45
		&"jump":
			target_torso_y = 2.0
			target_torso_rot = -0.06
			target_head_rot = -0.10
			target_front_leg_rot = -0.42
			target_back_leg_rot = 0.34
			target_front_leg_pos = Vector2(4.0, 4.0)
			target_back_leg_pos = Vector2(-4.0, 8.0)
			target_dagger_arm_rot = -0.62
			target_off_arm_rot = 0.55
		&"fall":
			target_torso_y = 3.0
			target_torso_rot = 0.05
			target_head_rot = 0.08
			target_front_leg_rot = 0.24
			target_back_leg_rot = -0.30
			target_front_leg_pos = Vector2(3.0, 6.0)
			target_back_leg_pos = Vector2(-4.0, 5.0)
			target_dagger_arm_rot = -0.82
			target_off_arm_rot = -0.45
		&"wall_cling":
			# Facing away from wall: rear arm & boots brace against wall behind Farid
			target_torso_y = 4.0
			target_torso_rot = -0.08
			target_front_leg_rot = -0.48
			target_back_leg_rot = 0.26
			target_front_leg_pos = Vector2(-5.0, 5.0)
			target_back_leg_pos = Vector2(-7.0, 9.0)
			target_off_arm_rot = 1.25
			target_dagger_arm_rot = -0.55
		&"dash":
			target_torso_y = 6.0
			target_torso_rot = 0.28
			target_head_rot = -0.18
			target_front_leg_rot = -0.55
			target_back_leg_rot = 0.72
			target_dagger_arm_rot = -1.45
			target_off_arm_rot = 0.95
		&"glide":
			target_torso_y = 2.0
			target_torso_rot = 0.08
			target_front_leg_rot = 0.22
			target_back_leg_rot = 0.38
			target_dagger_arm_rot = -1.15
			target_off_arm_rot = 0.95
		&"ground_pound":
			target_torso_y = 6.0
			target_torso_rot = 0.16
			target_front_leg_rot = -0.35
			target_back_leg_rot = -0.20
			target_dagger_arm_rot = 0.25
			target_off_arm_rot = -0.75
		&"parry":
			target_torso_y = 5.0
			target_torso_rot = -0.10
			target_front_leg_rot = -0.16
			target_back_leg_rot = 0.18
			target_dagger_arm_rot = -1.75
			target_off_arm_rot = -0.85
		&"hurt":
			target_torso_y = 5.0
			target_torso_rot = -0.24
			target_head_rot = -0.18
			target_front_leg_rot = -0.28
			target_back_leg_rot = 0.32
			target_dagger_arm_rot = 0.45
			target_off_arm_rot = -0.65
		&"dead":
			target_torso_y = 14.0
			target_torso_rot = 0.35
			target_head_rot = 0.25
			target_front_leg_rot = 0.65
			target_back_leg_rot = 0.85
			target_dagger_arm_rot = 0.70
			target_off_arm_rot = 0.60

	# Overlay crisp attack / spell-cast arm poses
	if _attack_pose_timer > 0.0:
		if _attack_pose_dir.y < -0.5:
			target_dagger_arm_rot = -2.45
			target_torso_rot -= 0.12
		elif _attack_pose_dir.y > 0.5:
			target_dagger_arm_rot = 0.42
			target_torso_rot += 0.14
		else:
			target_dagger_arm_rot = -1.65 if _attack_pose_step == 1 else -1.15
			target_torso_rot += 0.18 if _attack_pose_step == 2 else 0.12
		target_off_arm_rot = 0.68
	elif _cast_pose_timer > 0.0:
		target_dagger_arm_rot = -1.55
		target_off_arm_rot = -1.35
		target_torso_rot += 0.08

	if torso_root != null:
		torso_root.position.y = lerpf(torso_root.position.y, target_torso_y, blend)
		torso_root.rotation = lerpf(torso_root.rotation, target_torso_rot, blend)
	if head_root != null:
		head_root.rotation = lerpf(head_root.rotation, target_head_rot, blend)
	if front_leg != null:
		front_leg.rotation = lerpf(front_leg.rotation, target_front_leg_rot, blend)
		front_leg.position = front_leg.position.lerp(target_front_leg_pos, blend)
	if back_leg != null:
		back_leg.rotation = lerpf(back_leg.rotation, target_back_leg_rot, blend)
		back_leg.position = back_leg.position.lerp(target_back_leg_pos, blend)
	if dagger_arm != null:
		dagger_arm.rotation = lerpf(dagger_arm.rotation, target_dagger_arm_rot, minf(1.0, delta * 24.0))
	if off_arm != null:
		off_arm.rotation = lerpf(off_arm.rotation, target_off_arm_rot, blend)


func _animate_cloth_and_scarves(cur_state: StringName, speed_ratio: float) -> void:
	# Convert world wind into Farid's local facing space (+X = forward, -X = behind)
	var local_wind_x: float = _smoothed_wind.x * float(facing_dir)
	var wind_pull_x: float = clampf(local_wind_x * 0.055, -18.0, 14.0)
	var wind_lift_y: float = clampf(_smoothed_wind.y * 0.025, -10.0, 6.0)
	var vel_pull_x: float = -speed_ratio * 10.5
	var total_pull_x: float = clampf(vel_pull_x + wind_pull_x, -26.0, 8.0)
	var lift_y: float = clampf(-velocity.y * 0.015 + wind_lift_y, -9.0, 9.0)
	var is_gliding: bool = cur_state == &"glide"
	var is_dashing: bool = cur_state == &"dash"

	var flutter: float = sin(_anim_time * (5.2 + speed_ratio * 5.0 + absf(local_wind_x) * 0.02)) * (2.2 + speed_ratio * 3.2 + absf(local_wind_x) * 0.012)
	var flutter2: float = cos(_anim_time * (6.4 + speed_ratio * 5.5)) * (1.8 + speed_ratio * 2.8)

	# 1. Front traveler cloak + Sadu trim hem (strictly ordered clockwise, guaranteed non-crossing)
	var glide_back: float = -15.0 if is_gliding else (-10.0 if is_dashing else 0.0)
	var glide_front: float = 9.0 if is_gliding else 0.0
	var hem_front_x: float = maxf(6.0, 12.0 + total_pull_x * 0.25 + flutter * 0.3 + glide_front)
	var hem_mid_x: float = clampf(-4.0 + total_pull_x * 0.65 - flutter * 0.45, -24.0, hem_front_x - 6.0)
	var hem_back_x: float = minf(hem_mid_x - 6.0, -16.0 + total_pull_x + flutter + glide_back)

	var hem_front_y: float = 17.0 + lift_y * 0.35
	var hem_mid_y: float = 21.0 + lift_y * 0.65
	var hem_back_y: float = 19.0 + lift_y * 0.90

	if front_cloak_poly != null:
		front_cloak_poly.polygon = PackedVector2Array([
			Vector2(-10.0, -18.0),
			Vector2(10.0, -17.0),
			Vector2(13.0, -3.0),
			Vector2(hem_front_x, hem_front_y),
			Vector2(hem_mid_x, hem_mid_y),
			Vector2(hem_back_x, hem_back_y),
			Vector2(-13.0, -2.0)
		])

	if sadu_trim_poly != null:
		sadu_trim_poly.polygon = PackedVector2Array([
			Vector2(hem_back_x + 1.0, hem_back_y - 4.5),
			Vector2(hem_mid_x, hem_mid_y - 4.5),
			Vector2(hem_front_x - 0.5, hem_front_y - 4.5),
			Vector2(hem_front_x, hem_front_y),
			Vector2(hem_mid_x, hem_mid_y),
			Vector2(hem_back_x, hem_back_y)
		])

	if cloak_pleat_poly != null:
		var pleat_mid_x: float = lerpf(hem_mid_x, hem_front_x, 0.35)
		cloak_pleat_poly.polygon = PackedVector2Array([
			Vector2(-4.0, -15.0),
			Vector2(2.0, -15.0),
			Vector2(pleat_mid_x + 2.0, hem_mid_y - 2.0),
			Vector2(pleat_mid_x - 5.0, hem_mid_y - 1.5)
		])

	# 2. Back shadow cloak layer
	if back_cloak_poly != null:
		var b_front_x: float = maxf(4.0, 8.0 + total_pull_x * 0.2 + glide_front * 0.5)
		var b_mid_x: float = minf(b_front_x - 5.0, -7.0 + total_pull_x * 0.7)
		var b_back_x: float = minf(b_mid_x - 6.0, -19.0 + total_pull_x * 1.1 + flutter2 + glide_back)
		back_cloak_poly.polygon = PackedVector2Array([
			Vector2(-9.0, -14.0),
			Vector2(7.0, -14.0),
			Vector2(10.0, 4.0),
			Vector2(b_front_x, 25.0 + lift_y * 0.4),
			Vector2(b_mid_x, 28.0 + lift_y * 0.7),
			Vector2(b_back_x, 25.0 + lift_y * 0.95),
			Vector2(-13.0, 3.0)
		])

	# 3. Dual layered flowing desert headscarf tails (built as guaranteed-simple non-crossing ribbons)
	var scarf_reach: float = clampf(total_pull_x * 1.15 - (8.0 if is_dashing else 0.0), -34.0, 6.0)
	if front_scarf_poly != null:
		front_scarf_poly.polygon = _build_scarf_ribbon(
			Vector2(-3.0, 0.0),
			Vector2(-13.0 + scarf_reach * 0.45, 5.0 + flutter * 0.45 + lift_y * 0.4),
			Vector2(-24.0 + scarf_reach, 8.0 + flutter * 0.9 + lift_y * 0.7),
			3.2,
			2.6,
			1.6
		)

	if back_scarf_poly != null:
		back_scarf_poly.polygon = _build_scarf_ribbon(
			Vector2(-2.0, -16.0),
			Vector2(-14.0 + scarf_reach * 0.5, -10.0 + flutter2 * 0.5 + lift_y * 0.45),
			Vector2(-28.0 + scarf_reach * 1.15, -6.0 + flutter2 * 1.05 + lift_y * 0.8),
			3.4,
			2.8,
			1.7
		)


func _build_scarf_ribbon(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	w0: float,
	w1: float,
	w2: float
) -> PackedVector2Array:
	# Enforce strictly monotonic X leftward so consecutive ribbon quads can never fold or self-intersect
	var m1: Vector2 = Vector2(minf(p1.x, p0.x - 5.0), p1.y)
	var m2: Vector2 = Vector2(minf(p2.x, m1.x - 5.0), p2.y)
	return PackedVector2Array([
		Vector2(p0.x, p0.y - w0),
		Vector2(p0.x + 2.0, p0.y + w0),
		Vector2(m1.x, m1.y + w1),
		Vector2(m2.x, m2.y + w2),
		Vector2(m2.x - 2.0, m2.y - w2),
		Vector2(m1.x, m1.y - w1)
	])


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
				p["world_pos"] = (p["world_pos"] as Vector2) + ((p["vel"] as Vector2) + _smoothed_wind * 0.35) * delta
				p["vel"] = (p["vel"] as Vector2) * (1.0 - 4.0 * delta)
				next_dust.append(p)
		_dust_particles = next_dust

	if not _spark_particles.is_empty():
		var next_sparks: Array[Dictionary] = []
		for sp: Dictionary in _spark_particles:
			var life: float = float(sp["life"]) - delta
			if life > 0.0:
				sp["life"] = life
				sp["world_pos"] = (sp["world_pos"] as Vector2) + (sp["vel"] as Vector2) * delta
				sp["vel"] = (sp["vel"] as Vector2) + Vector2(0.0, 260.0) * delta
				next_sparks.append(sp)
		_spark_particles = next_sparks


func _draw() -> void:
	# 1. Dash afterimage silhouettes
	for ghost: Dictionary in _afterimages:
		var alpha: float = clampf(float(ghost["life"]) / float(ghost["max_life"]), 0.0, 1.0)
		var local_offset: Vector2 = to_local(ghost["world_pos"] as Vector2)
		var poly: PackedVector2Array = ghost["poly"] as PackedVector2Array
		var shifted := PackedVector2Array()
		for pt: Vector2 in poly:
			shifted.append(pt + local_offset)
		var ghost_col: Color = COL_CLOAK.lerp(COL_PALE_GOLD, 0.28 if int(ghost["tier"]) >= 1 else 0.14)
		ghost_col.a = alpha * 0.42
		if shifted.size() >= 3:
			draw_colored_polygon(shifted, ghost_col)

	# 2. Horizontal Dash blade-streak
	if _dash_streak_timer > 0.0:
		var ds_t: float = clampf(_dash_streak_timer / (DASH_DURATION + 0.06), 0.0, 1.0)
		var f: float = float(_dash_streak_dir)
		var streak_col: Color = COL_PALE_GOLD if GameState.get_dagger_tier() >= 1 else COL_SUNSET_ORANGE
		streak_col.a = ds_t * (0.55 if SettingsManager.reduce_flash else 0.82)
		var streak_poly := PackedVector2Array([
			Vector2(f * 32.0, -4.0),
			Vector2(f * -64.0, -10.0),
			Vector2(f * -86.0, -2.0),
			Vector2(f * -64.0, 6.0)
		])
		if _dash_streak_dir < 0:
			streak_poly.reverse()
		draw_colored_polygon(streak_poly, streak_col)
		draw_line(Vector2(f * 30.0, -3.0), Vector2(f * -72.0, -3.0), Color(1.0, 0.97, 0.86, ds_t * 0.85), 2.2, true)

	# 3. Surface-colored dust puffs & wall-slide friction sparks
	for p: Dictionary in _dust_particles:
		var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var col: Color = p.get("color", COL_OCHRE) as Color
		col.a = alpha * 0.65
		draw_circle(to_local(p["world_pos"] as Vector2), float(p["radius"]) * (0.4 + 0.6 * alpha), col)

	for sp: Dictionary in _spark_particles:
		var alpha: float = clampf(float(sp["life"]) / float(sp["max_life"]), 0.0, 1.0)
		var col: Color = sp.get("color", COL_PALE_GOLD) as Color
		col.a = alpha
		var pos: Vector2 = to_local(sp["world_pos"] as Vector2)
		var vel: Vector2 = sp["vel"] as Vector2
		draw_line(pos, pos - vel.normalized() * 6.0, col, 2.0, true)

	# 4. Sadu geometric embroidery accents, Heterochromia Eyes & Held Flame Dagger
	if not is_dead:
		_draw_sadu_embroidery()
		_draw_heterochromia_eyes()
		_draw_held_flame_dagger()

	# 5. Parry concentric pale-gold Najdi seal rings
	if _parry_ring_timer > 0.0:
		_draw_parry_seal_ring()

	# 6. Ground Pound shockwave ring
	if _ground_pound_ring_timer > 0.0:
		var gp_t: float = 1.0 - clampf(_ground_pound_ring_timer / 0.28, 0.0, 1.0)
		var gp_alpha: float = (1.0 - gp_t) * (0.55 if SettingsManager.reduce_flash else 0.88)
		var gp_col: Color = COL_PALE_GOLD
		gp_col.a = gp_alpha
		var rx: float = lerpf(24.0, 128.0, gp_t)
		draw_line(Vector2(-rx, 30.0), Vector2(rx, 30.0), gp_col, 4.5 * (1.0 - gp_t) + 1.2, true)
		var orange_col: Color = COL_SUNSET_ORANGE
		orange_col.a = gp_alpha * 0.7
		draw_line(Vector2(-rx * 0.75, 27.0), Vector2(rx * 0.75, 27.0), orange_col, 2.2, true)


func _draw_sadu_embroidery() -> void:
	if torso_root == null:
		return
	# Crisp ochre geometric Najdi Sadu diamond stitches across waist sash
	var sash_center: Vector2 = to_local(torso_root.to_global(Vector2(0.0, -1.0)))
	var gold_col: Color = COL_PALE_GOLD
	gold_col.a = 0.75
	for i: int in range(-1, 2):
		var c: Vector2 = sash_center + Vector2(float(i) * 5.5, 0.0)
		var diamond := PackedVector2Array([
			c + Vector2(0.0, -2.0),
			c + Vector2(2.0, 0.0),
			c + Vector2(0.0, 2.0),
			c + Vector2(-2.0, 0.0)
		])
		draw_colored_polygon(diamond, gold_col)


func _draw_heterochromia_eyes() -> void:
	if head_root == null:
		return
	var f: float = float(facing_dir)
	var far_local: Vector2 = Vector2(2.0, -5.8)
	var near_local: Vector2 = Vector2(7.0, -5.4)
	var far_eye: Vector2 = to_local(head_root.to_global(far_local))
	var near_eye: Vector2 = to_local(head_root.to_global(near_local))

	# Anatomically: Farid's LEFT eye is Grey (#8B95A5), RIGHT eye is Blue (#4A90D9).
	var left_eye_pos: Vector2 = far_eye if facing_dir > 0 else near_eye
	var right_eye_pos: Vector2 = near_eye if facing_dir > 0 else far_eye

	if _blink_duration > 0.0:
		# Soft closed-eyelid blink stroke
		draw_line(left_eye_pos + Vector2(-2.0, 0.0), left_eye_pos + Vector2(2.0, 0.0), COL_EYE_GREY, 1.4, true)
		draw_line(right_eye_pos + Vector2(-2.0, 0.0), right_eye_pos + Vector2(2.0, 0.0), COL_EYE_BLUE, 1.4, true)
		return

	# Subtle warm/cool atmospheric glow around each eye so heterochromia pops in shadow
	var left_halo: Color = COL_EYE_GREY
	left_halo.a = (0.48 + 0.16 * sin(_anim_time * 8.0)) if grey_eye_active else 0.28
	var right_halo: Color = COL_EYE_BLUE
	right_halo.a = 0.30
	draw_circle(left_eye_pos, 5.8 if grey_eye_active else 3.8, left_halo)
	draw_circle(right_eye_pos, 3.8, right_halo)

	draw_circle(left_eye_pos, 2.3, COL_EYE_GREY)
	draw_circle(right_eye_pos, 2.3, COL_EYE_BLUE)
	draw_circle(left_eye_pos + Vector2(0.55 * f, -0.55), 0.8, Color(0.96, 0.98, 1.0, 0.92))
	draw_circle(right_eye_pos + Vector2(0.55 * f, -0.55), 0.8, Color(0.92, 0.97, 1.0, 0.95))


func _draw_held_flame_dagger() -> void:
	if dagger_arm == null:
		return
	var tier: int = clampi(GameState.get_dagger_tier(), 0, 2)
	var hand_pos: Vector2 = to_local(dagger_arm.to_global(Vector2(2.0, 14.0)))
	var tip_dir: Vector2 = (to_local(dagger_arm.to_global(Vector2(14.0, 16.0))) - hand_pos).normalized()
	if tip_dir == Vector2.ZERO:
		tip_dir = Vector2(float(facing_dir), 0.0)
	var perp: Vector2 = Vector2(-tip_dir.y, tip_dir.x)

	var blade_len: float = 15.0 + float(tier) * 7.5
	var glow_col: Color = flame_dagger.get_tier_color(tier) if flame_dagger != null else COL_PALE_GOLD
	var aura_col: Color = glow_col
	aura_col.a = (0.26 + float(tier) * 0.14) * (0.62 if SettingsManager.reduce_flash else 1.0)

	# Ember halo around blade
	draw_circle(hand_pos + tip_dir * (blade_len * 0.55), 6.0 + float(tier) * 3.8, aura_col)

	# Curved Arabian jambiya-inspired Flame Dagger silhouette (strictly simple pentagon)
	var up_sign: float = -1.0 if facing_dir > 0 else 1.0
	var p0: Vector2 = hand_pos + perp * (2.3 * up_sign)
	var p1: Vector2 = hand_pos + tip_dir * (blade_len * 0.62) + perp * ((3.5 + float(tier)) * up_sign)
	var p2: Vector2 = hand_pos + tip_dir * blade_len + perp * ((6.0 + float(tier) * 1.4) * up_sign)
	var p3: Vector2 = hand_pos + tip_dir * (blade_len * 0.58) - perp * (2.4 * up_sign)
	var p4: Vector2 = hand_pos - perp * (2.3 * up_sign)
	var blade_poly := PackedVector2Array([p0, p1, p2, p3, p4])
	if facing_dir < 0:
		blade_poly.reverse()
	draw_colored_polygon(blade_poly, glow_col)

	# Incandescent inner core line
	draw_line(hand_pos + tip_dir * 2.0, p2, Color(1.0, 0.97, 0.88, 0.9), 1.4, true)


func _draw_parry_seal_ring() -> void:
	var progress: float = 1.0 - clampf(_parry_ring_timer / maxf(_parry_ring_duration, 0.001), 0.0, 1.0)
	var alpha: float = (1.0 - progress) * (0.6 if SettingsManager.reduce_flash else 0.95)
	var center: Vector2 = Vector2(0.0, -4.0)
	var radius: float = lerpf(22.0, 78.0 if _parry_ring_success else 44.0, progress)
	var ring_col: Color = COL_PALE_GOLD
	ring_col.a = alpha

	# Concentric Najdi pale-gold seal rings + counter-rotating 8-point geometric star
	draw_arc(center, radius, 0.0, TAU, 36, ring_col, 3.6 if _parry_ring_success else 2.2, true)
	var inner_ring_col: Color = COL_SUNSET_ORANGE.lerp(COL_PALE_GOLD, 0.72)
	inner_ring_col.a = alpha * 0.82
	draw_arc(center, radius * 0.72, 0.0, TAU, 28, inner_ring_col, 1.8, true)

	var rot_a: float = _anim_time * 3.5
	var rot_b: float = rot_a + PI * 0.25
	var r_sq: float = radius * 0.88
	for rot: float in [rot_a, rot_b]:
		var sq := PackedVector2Array()
		for i: int in range(5):
			var ang: float = rot + float(i) * PI * 0.5
			sq.append(center + Vector2.from_angle(ang) * r_sq)
		draw_polyline(sq, inner_ring_col, 1.8, true)
