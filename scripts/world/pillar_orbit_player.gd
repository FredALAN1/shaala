class_name PillarOrbitPlayer
extends Node3D
## Cylindrical-coordinate 2.5D controller for Farid orbiting a monumental 3D ruined pillar.
## Handles deterministic spiral ledge landings, coyote time, jump buffering, variable jump,
## angular flame dash with pale-gold trail, animated 3D-layered silhouette, and orbiting Camera3D.

signal summit_reached()

const MAX_ANGULAR_SPEED: float = 1.48
const GROUND_ACCEL: float = 11.5
const GROUND_DECEL: float = 13.5
const AIR_ACCEL: float = 8.2
const AIR_DECEL: float = 5.4
const GRAVITY: float = 28.0
const MAX_FALL_SPEED: float = 22.0
const JUMP_VELOCITY: float = 11.6
const VARIABLE_JUMP_CUT: float = 0.48
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.12
const DASH_ANGULAR_SPEED: float = 3.45
const DASH_DURATION: float = 0.20
const DASH_COOLDOWN: float = 0.42
const CAMERA_RADIUS: float = 15.5
const CAMERA_HEIGHT_OFFSET: float = 2.9
const CAMERA_ANGLE_LEAD: float = 0.15
const CAMERA_LERP_SPEED: float = 6.5

@export var orbit_radius: float = 5.45
@export var start_angle: float = 0.0
@export var start_height: float = 0.0

var orbit_angle: float = 0.0
var height_y: float = 0.0
var vel_angle: float = 0.0
var vel_y: float = 0.0

var _facing: float = 1.0
var _is_grounded: bool = true
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _air_dash_available: bool = true
var _dash_dir: float = 1.0
var _anim_time: float = 0.0
var _cam_angle: float = 0.0
var _cam_height: float = 3.0
var _summit_pos: Vector3 = Vector3(0.0, 23.6, 5.45)
var _summit_triggered: bool = false
var _ledges: Array[Dictionary] = []

var _visual_root: Node3D = null
var _scarf_node: Node3D = null
var _leg_left: MeshInstance3D = null
var _leg_right: MeshInstance3D = null
var _dagger_mesh: MeshInstance3D = null
var _dash_trail: MeshInstance3D = null
var _toon_shader: Shader = null

@onready var _camera: Camera3D = get_node_or_null("../OrbitCamera") as Camera3D


func _ready() -> void:
	orbit_angle = start_angle
	height_y = start_height
	_cam_angle = orbit_angle
	_cam_height = height_y + CAMERA_HEIGHT_OFFSET
	_toon_shader = load("res://assets/placeholder/shaders/painterly_3d_toon.gdshader") as Shader
	_build_farid_3d_silhouette()
	_sync_transform()
	if _camera != null:
		_camera.make_current()
		_update_camera(1.0)


func set_ledges(ledge_list: Array[Dictionary]) -> void:
	_ledges = ledge_list


func set_summit_position(world_pos: Vector3) -> void:
	_summit_pos = world_pos


func _physics_process(delta: float) -> void:
	_anim_time += delta
	_update_timers(delta)
	_handle_inputs(delta)
	_integrate_cylindrical_motion(delta)
	_sync_transform()
	_animate_silhouette(delta)
	_update_camera(delta)
	_check_summit_proximity()


func _update_timers(delta: float) -> void:
	if _coyote_timer > 0.0:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
	if _dash_timer > 0.0:
		_dash_timer = maxf(0.0, _dash_timer - delta)


func _handle_inputs(delta: float) -> void:
	var move_axis: float = Input.get_axis("move_left", "move_right")
	if absf(move_axis) > 0.05:
		_facing = 1.0 if move_axis > 0.0 else -1.0

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME

	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0 and (_is_grounded or _air_dash_available):
		_dash_dir = _facing
		_dash_timer = DASH_DURATION
		_dash_cooldown_timer = DASH_COOLDOWN
		if not _is_grounded:
			_air_dash_available = false
		vel_y = 0.0
		vel_angle = _dash_dir * DASH_ANGULAR_SPEED
		_play_sfx_safe("dash")

	if _dash_timer > 0.0:
		vel_angle = _dash_dir * DASH_ANGULAR_SPEED
		vel_y = 0.0
		return

	var target_ang_vel: float = move_axis * MAX_ANGULAR_SPEED
	var accel: float = GROUND_ACCEL if _is_grounded else AIR_ACCEL
	var decel: float = GROUND_DECEL if _is_grounded else AIR_DECEL
	var rate: float = accel if absf(move_axis) > 0.05 else decel
	vel_angle = move_toward(vel_angle, target_ang_vel, rate * delta)

	if _jump_buffer_timer > 0.0 and (_is_grounded or _coyote_timer > 0.0):
		vel_y = JUMP_VELOCITY
		_is_grounded = false
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		_play_sfx_safe("jump")

	if Input.is_action_just_released("jump") and vel_y > 0.0:
		vel_y *= VARIABLE_JUMP_CUT


func _integrate_cylindrical_motion(delta: float) -> void:
	var prev_y: float = height_y
	orbit_angle = wrapf(orbit_angle + vel_angle * delta, -PI, PI)

	if _dash_timer <= 0.0:
		vel_y = maxf(-MAX_FALL_SPEED, vel_y - GRAVITY * delta)

	var next_y: float = height_y + vel_y * delta
	var landed: bool = false

	if vel_y <= 0.0:
		# Check all registered spiral ledges for crisp one-way top landings.
		for ledge: Dictionary in _ledges:
			var l_angle: float = float(ledge["angle"])
			var l_half: float = float(ledge["half_angle"])
			var l_top: float = float(ledge["top_y"])
			var ang_diff: float = absf(wrapf(orbit_angle - l_angle, -PI, PI))
			if ang_diff <= l_half + 0.06:
				if prev_y >= l_top - 0.18 and next_y <= l_top:
					next_y = l_top
					vel_y = 0.0
					landed = true
					break

	# Safe circular stone base floor at y = 0.0 prevents any bottomless fall.
	if next_y <= 0.0:
		next_y = 0.0
		vel_y = 0.0
		landed = true

	if landed:
		_is_grounded = true
		_coyote_timer = COYOTE_TIME
		_air_dash_available = true
	else:
		if _is_grounded:
			_coyote_timer = COYOTE_TIME
		_is_grounded = false

	height_y = next_y


func _sync_transform() -> void:
	var px: float = sin(orbit_angle) * orbit_radius
	var pz: float = cos(orbit_angle) * orbit_radius
	global_position = Vector3(px, height_y, pz)

	# Align character tangent to the pillar surface (radial normal points outward).
	rotation = Vector3(0.0, orbit_angle, 0.0)


func _animate_silhouette(delta: float) -> void:
	if _visual_root == null:
		return

	# Flip local X facing along cylinder tangent cleanly.
	var target_scale_x: float = _facing
	_visual_root.scale.x = move_toward(_visual_root.scale.x, target_scale_x, 16.0 * delta)

	# Squash & stretch on jump/fall and rhythmic stride on run.
	var speed_ratio: float = clampf(absf(vel_angle) / MAX_ANGULAR_SPEED, 0.0, 1.0)
	if not _is_grounded:
		var stretch: float = clampf(vel_y * 0.014, -0.10, 0.14)
		_visual_root.scale.y = 1.0 + stretch
	else:
		_visual_root.scale.y = lerpf(_visual_root.scale.y, 1.0 + sin(_anim_time * 3.0) * 0.018, 12.0 * delta)

	var stride: float = sin(_anim_time * 13.0) * 0.48 * speed_ratio if _is_grounded else 0.25
	if _leg_left != null:
		_leg_left.rotation.z = stride
	if _leg_right != null:
		_leg_right.rotation.z = -stride

	if _scarf_node != null:
		var whip: float = 0.25 + speed_ratio * 0.55 + (0.75 if _dash_timer > 0.0 else 0.0)
		_scarf_node.rotation.z = whip + sin(_anim_time * 9.0) * 0.12

	if _dagger_mesh != null:
		_dagger_mesh.position.y = 0.92 + sin(_anim_time * 4.5) * 0.04

	if _dash_trail != null:
		_dash_trail.visible = _dash_timer > 0.0


func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	var desired_angle: float = orbit_angle + _facing * CAMERA_ANGLE_LEAD
	var diff: float = wrapf(desired_angle - _cam_angle, -PI, PI)
	_cam_angle = wrapf(_cam_angle + diff * clampf(CAMERA_LERP_SPEED * delta, 0.0, 1.0), -PI, PI)
	var desired_h: float = height_y + CAMERA_HEIGHT_OFFSET
	_cam_height = lerpf(_cam_height, desired_h, clampf(5.2 * delta, 0.0, 1.0))

	var cam_pos: Vector3 = Vector3(sin(_cam_angle) * CAMERA_RADIUS, _cam_height, cos(_cam_angle) * CAMERA_RADIUS)
	var look_angle: float = wrapf(_cam_angle + _facing * 0.05, -PI, PI)
	var look_target: Vector3 = Vector3(sin(look_angle) * (orbit_radius * 0.45), height_y + 1.9, cos(look_angle) * (orbit_radius * 0.45))
	_camera.global_position = cam_pos
	_camera.look_at(look_target, Vector3.UP)


func _check_summit_proximity() -> void:
	if _summit_triggered:
		return
	var player_center: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
	if player_center.distance_to(_summit_pos) <= 1.65:
		_summit_triggered = true
		_play_sfx_safe("orb_collect")
		summit_reached.emit()


func _make_toon_mat(albedo: Color, shadow: Color, rim: Color, rim_str: float = 0.85, emit_str: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _toon_shader
	mat.set_shader_parameter("albedo_color", albedo)
	mat.set_shader_parameter("shadow_color", shadow)
	mat.set_shader_parameter("rim_color", rim)
	mat.set_shader_parameter("rim_strength", rim_str)
	mat.set_shader_parameter("grain_strength", 0.06)
	mat.set_shader_parameter("emission_strength", emit_str)
	return mat


func _build_farid_3d_silhouette() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "FaridVisual"
	add_child(_visual_root)

	var indigo_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.NIGHT_INDIGO, ShaalaPalette.DEEP_SHADOW, ShaalaPalette.SUNSET_ORANGE, 1.0)
	var crimson_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.DESERT_RED, ShaalaPalette.DEEP_SHADOW, ShaalaPalette.PALE_GOLD_ORB, 0.85)
	var ochre_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.MUD_BRICK_OCHRE, ShaalaPalette.SHADE_NAJDI_DARK, ShaalaPalette.WARM_SAND_LIGHT, 0.7)
	var gold_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.PALE_GOLD_ORB, ShaalaPalette.SUNSET_ORANGE, ShaalaPalette.ORB_CORE_WHITE_GOLD, 1.2, 1.1)
	var eye_grey_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.FARID_EYE_GREY, ShaalaPalette.FARID_EYE_GREY, ShaalaPalette.ORB_CORE_WHITE_GOLD, 0.4, 1.4)
	var eye_blue_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.FARID_EYE_BLUE, ShaalaPalette.FARID_EYE_BLUE, ShaalaPalette.ORB_CORE_WHITE_GOLD, 0.4, 1.4)

	# Articulated dark boots / legs.
	_leg_left = _add_box(_visual_root, Vector3(0.22, 0.62, 0.22), Vector3(-0.14, 0.31, 0.0), indigo_mat)
	_leg_right = _add_box(_visual_root, Vector3(0.22, 0.62, 0.22), Vector3(0.14, 0.31, 0.0), indigo_mat)

	# Layered traveler cloak torso + crimson-ochre Sadu hem trim.
	var cloak_mesh: CylinderMesh = CylinderMesh.new()
	cloak_mesh.top_radius = 0.28
	cloak_mesh.bottom_radius = 0.50
	cloak_mesh.height = 1.05
	cloak_mesh.radial_segments = 10
	var cloak_inst: MeshInstance3D = MeshInstance3D.new()
	cloak_inst.mesh = cloak_mesh
	cloak_inst.material_override = indigo_mat
	cloak_inst.position = Vector3(0.0, 0.96, 0.0)
	_visual_root.add_child(cloak_inst)

	var hem_mesh: CylinderMesh = CylinderMesh.new()
	hem_mesh.top_radius = 0.47
	hem_mesh.bottom_radius = 0.52
	hem_mesh.height = 0.16
	hem_mesh.radial_segments = 10
	var hem_inst: MeshInstance3D = MeshInstance3D.new()
	hem_inst.mesh = hem_mesh
	hem_inst.material_override = crimson_mat
	hem_inst.position = Vector3(0.0, 0.48, 0.0)
	_visual_root.add_child(hem_inst)

	# Draped Najdi hood & head silhouette.
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.54
	head_mesh.radial_segments = 12
	head_mesh.rings = 8
	var head_inst: MeshInstance3D = MeshInstance3D.new()
	head_inst.mesh = head_mesh
	head_inst.material_override = indigo_mat
	head_inst.position = Vector3(0.02, 1.66, 0.0)
	_visual_root.add_child(head_inst)

	# Agal / ochre headband.
	_add_box(_visual_root, Vector3(0.46, 0.07, 0.46), Vector3(0.02, 1.80, 0.0), ochre_mat)

	# Distinctive heterochromia eyes (Left Grey #8B95A5, Right Blue #4A90D9).
	_add_box(_visual_root, Vector3(0.07, 0.06, 0.06), Vector3(0.24, 1.67, -0.07), eye_grey_mat)
	_add_box(_visual_root, Vector3(0.07, 0.06, 0.06), Vector3(0.24, 1.67, 0.07), eye_blue_mat)

	# Flowing desert-red scarf tail whipping opposite to angular velocity.
	_scarf_node = Node3D.new()
	_scarf_node.position = Vector3(-0.14, 1.44, 0.0)
	_visual_root.add_child(_scarf_node)
	_add_box(_scarf_node, Vector3(0.85, 0.16, 0.12), Vector3(-0.42, -0.04, 0.0), crimson_mat)
	_add_box(_scarf_node, Vector3(0.48, 0.12, 0.08), Vector3(-0.92, -0.10, 0.0), ochre_mat)

	# Glowing pale-gold Flame Dagger held at Farid's side.
	_dagger_mesh = _add_box(_visual_root, Vector3(0.62, 0.09, 0.06), Vector3(0.46, 0.92, 0.16), gold_mat)
	_dagger_mesh.rotation.z = deg_to_rad(-18.0)

	# Pale-gold angular dash flame streak.
	_dash_trail = _add_box(_visual_root, Vector3(1.9, 0.34, 0.16), Vector3(-1.05, 1.0, 0.0), gold_mat)
	_dash_trail.visible = false


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _play_sfx_safe(sfx_id: String) -> void:
	if not is_inside_tree():
		return
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", sfx_id)
