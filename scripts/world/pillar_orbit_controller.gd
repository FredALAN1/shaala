class_name PillarOrbitController
extends Node3D
## 360-degree 3D-in-2.5D Cylindrical Pillar Orbit experience for SHAALA (شعلة).
## Builds a 34m tall, 4.6m radius ruined Riyadh/Najdi cylindrical tower with 18 spiral ledges,
## Najdi furjat/shurfat motifs, fluttering Sadu banners, glowing summit Memory Orb,
## and a 360-degree orbiting original desert-and-ruined-skyline horizon (D6 compliant).

signal exit_requested(target_room_id: String, target_spawn_id: String)

const LEDGE_COUNT: int = 18
const SUMMIT_HEIGHT: float = 22.0
const SPIRAL_ANGULAR_STEP: float = 0.41
const HORIZON_RADIUS: float = 46.0

@export var blender_pillar_mesh: PackedScene = null
@export var pillar_radius: float = 4.6
@export var pillar_height: float = 34.0
@export var return_room_id: String = "empty_riyadh_01"
@export var return_spawn_id: String = "from_highway_02"

var _time: float = 0.0
var _exiting: bool = false
var _toon_shader: Shader = null
var _banners: Array[Node3D] = []
var _dust_motes: Array[Node3D] = []
var _summit_orb: Node3D = null
var _summit_base_y: float = 23.6
var _ledges: Array[Dictionary] = []

@onready var _player: PillarOrbitPlayer = get_node_or_null("PillarOrbitPlayer") as PillarOrbitPlayer


func _ready() -> void:
	_toon_shader = load("res://assets/placeholder/shaders/painterly_3d_toon.gdshader") as Shader
	_setup_dusk_environment_and_lights()
	_build_monumental_pillar()
	_build_spiral_ledges()
	_build_summit_memory_orb()
	_build_orbiting_horizon_d6()
	_build_ambient_dust_motes()

	if _player != null:
		_player.set_ledges(_ledges)
		if _summit_orb != null:
			_player.set_summit_position(_summit_orb.global_position)
		if not _player.summit_reached.is_connected(_on_summit_reached):
			_player.summit_reached.connect(_on_summit_reached)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("room_loaded", "pillar_orbit_spire", "empty_riyadh", "AREA_PILLAR_ORBIT")


func _process(delta: float) -> void:
	_time += delta

	# Gentle desert wind sway on crimson-ochre Sadu banners.
	for i: int in range(_banners.size()):
		var b: Node3D = _banners[i]
		b.rotation.x = sin(_time * 2.4 + float(i) * 1.4) * 0.10 + 0.05

	# Ethereal pale-gold summit Memory Orb bob & rotation.
	if _summit_orb != null:
		_summit_orb.position.y = _summit_base_y + sin(_time * 2.3) * 0.28
		_summit_orb.rotation.y = _time * 0.85

	# Rising golden desert dust motes around the spire.
	for i: int in range(_dust_motes.size()):
		var mote: Node3D = _dust_motes[i]
		var fi: float = float(i)
		var ang: float = fi * 0.47 + _time * (0.14 + fmod(fi * 0.03, 0.12))
		var r: float = 5.8 + fmod(fi * 1.37, 4.5)
		var y_pos: float = fmod(fi * 1.65 + _time * 0.65, 26.0)
		mote.position = Vector3(sin(ang) * r, y_pos, cos(ang) * r)


func _unhandled_input(event: InputEvent) -> void:
	if _exiting:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_request_exit()


func _on_summit_reached() -> void:
	_request_exit()


func _request_exit() -> void:
	if _exiting:
		return
	_exiting = true
	exit_requested.emit(return_room_id, return_spawn_id)


func _make_toon_mat(albedo: Color, shadow: Color, rim: Color, rim_str: float = 0.72, grain: float = 0.085, emit_str: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _toon_shader
	mat.set_shader_parameter("albedo_color", albedo)
	mat.set_shader_parameter("shadow_color", shadow)
	mat.set_shader_parameter("rim_color", rim)
	mat.set_shader_parameter("rim_strength", rim_str)
	mat.set_shader_parameter("grain_strength", grain)
	mat.set_shader_parameter("emission_strength", emit_str)
	return mat


func _setup_dusk_environment_and_lights() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	env_node.name = "DuskWorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = ShaalaPalette.DEEP_SHADOW
	sky_mat.sky_horizon_color = ShaalaPalette.DESERT_RED
	sky_mat.sky_curve = 0.24
	sky_mat.ground_bottom_color = ShaalaPalette.NIGHT_INDIGO
	sky_mat.ground_horizon_color = ShaalaPalette.SUNSET_ORANGE
	sky_mat.ground_curve = 0.16
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ShaalaPalette.NIGHT_INDIGO.lerp(ShaalaPalette.DESERT_RED, 0.35)
	env.ambient_light_energy = 0.55

	env.fog_enabled = true
	env.fog_light_color = ShaalaPalette.DESERT_RED.lerp(ShaalaPalette.SUNSET_ORANGE, 0.45)
	env.fog_light_energy = 0.85
	env.fog_density = 0.0085
	env_node.environment = env
	add_child(env_node)

	# Primary warm sunset key light casting dramatic warm-to-cool cel bands.
	var sun_light: DirectionalLight3D = DirectionalLight3D.new()
	sun_light.name = "SunsetKeyLight"
	sun_light.light_color = ShaalaPalette.SUNSET_ORANGE.lerp(ShaalaPalette.PALE_GOLD_ORB, 0.35)
	sun_light.light_energy = 1.65
	sun_light.rotation_degrees = Vector3(-24.0, 38.0, 0.0)
	add_child(sun_light)

	# Cool twilight indigo counter-fill light.
	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.name = "TwilightFillLight"
	fill_light.light_color = ShaalaPalette.NIGHT_INDIGO.lerp(ShaalaPalette.GLASS_TEAL, 0.45)
	fill_light.light_energy = 0.65
	fill_light.rotation_degrees = Vector3(-18.0, -142.0, 0.0)
	add_child(fill_light)


func _build_monumental_pillar() -> void:
	var pillar_root: Node3D = Node3D.new()
	pillar_root.name = "PillarRoot"
	add_child(pillar_root)

	if blender_pillar_mesh != null:
		var custom_inst: Node = blender_pillar_mesh.instantiate()
		pillar_root.add_child(custom_inst)
		return

	var ochre_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.MUD_BRICK_OCHRE, ShaalaPalette.NIGHT_INDIGO, ShaalaPalette.SUNSET_ORANGE, 0.80, 0.11)
	var concrete_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.NIGHT_INDIGO.lerp(ShaalaPalette.GLASS_TEAL, 0.35), ShaalaPalette.DEEP_SHADOW, ShaalaPalette.SUNSET_ORANGE, 0.72, 0.09)
	var dark_recess_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.DEEP_SHADOW, ShaalaPalette.DEEP_SHADOW, ShaalaPalette.NIGHT_INDIGO, 0.15, 0.04)
	var rebar_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.DESERT_RED.lerp(ShaalaPalette.SHADE_NAJDI_DARK, 0.5), ShaalaPalette.DEEP_SHADOW, ShaalaPalette.SUNSET_ORANGE, 0.6, 0.05)
	var crimson_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.SADDLE_CRIMSON, ShaalaPalette.DEEP_SHADOW, ShaalaPalette.PALE_GOLD_ORB, 0.85, 0.07)
	var trim_gold_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.SADDLE_TRIM_GOLD, ShaalaPalette.SHADE_NAJDI_DARK, ShaalaPalette.PALE_GOLD_ORB, 0.8, 0.06)

	# Main 34m tall, 4.6m radius cylindrical ruined viaduct / Najdi column core.
	var core_cyl: CylinderMesh = CylinderMesh.new()
	core_cyl.top_radius = pillar_radius
	core_cyl.bottom_radius = pillar_radius + 0.25
	core_cyl.height = pillar_height
	core_cyl.radial_segments = 32
	var core_mi: MeshInstance3D = MeshInstance3D.new()
	core_mi.name = "PillarCore"
	core_mi.mesh = core_cyl
	core_mi.material_override = ochre_mat
	core_mi.position = Vector3(0.0, pillar_height * 0.5 - 3.5, 0.0)
	pillar_root.add_child(core_mi)

	# Wide circular stone foundation plinth at y = 0.0 so player always has safe ground.
	var base_cyl: CylinderMesh = CylinderMesh.new()
	base_cyl.top_radius = 7.6
	base_cyl.bottom_radius = 8.4
	base_cyl.height = 3.2
	base_cyl.radial_segments = 32
	var base_mi: MeshInstance3D = MeshInstance3D.new()
	base_mi.name = "FoundationPlinth"
	base_mi.mesh = base_cyl
	base_mi.material_override = concrete_mat
	base_mi.position = Vector3(0.0, -1.6, 0.0)
	pillar_root.add_child(base_mi)

	# 12 monumental vertical concrete flutes ringing the cylinder.
	for i: int in range(12):
		var a: float = (float(i) / 12.0) * TAU
		var flute_box: BoxMesh = BoxMesh.new()
		flute_box.size = Vector3(0.55, pillar_height - 5.0, 0.42)
		var flute_mi: MeshInstance3D = MeshInstance3D.new()
		flute_mi.mesh = flute_box
		flute_mi.material_override = concrete_mat
		flute_mi.position = Vector3(sin(a) * (pillar_radius + 0.04), pillar_height * 0.5 - 3.0, cos(a) * (pillar_radius + 0.04))
		flute_mi.rotation.y = a
		pillar_root.add_child(flute_mi)

	# 4 carved Najdi cornice rings breaking up the vertical rhythm.
	for tier_y: float in [4.2, 10.6, 17.0, 23.8]:
		var ring_cyl: CylinderMesh = CylinderMesh.new()
		ring_cyl.top_radius = pillar_radius + 0.34
		ring_cyl.bottom_radius = pillar_radius + 0.24
		ring_cyl.height = 0.58
		ring_cyl.radial_segments = 32
		var ring_mi: MeshInstance3D = MeshInstance3D.new()
		ring_mi.mesh = ring_cyl
		ring_mi.material_override = concrete_mat
		ring_mi.position = Vector3(0.0, tier_y, 0.0)
		pillar_root.add_child(ring_mi)

	# Recessed triangular Najdi ventilation slits (furjat) in rhythmic trios.
	var furja_prism: PrismMesh = PrismMesh.new()
	furja_prism.size = Vector3(0.52, 0.58, 0.32)
	for tier_y: float in [2.6, 8.8, 15.2, 20.8]:
		for g: int in range(8):
			var base_a: float = (float(g) / 8.0) * TAU + tier_y * 0.1
			for offset_idx: int in range(-1, 2):
				var fa: float = base_a + float(offset_idx) * 0.13
				var fmi: MeshInstance3D = MeshInstance3D.new()
				fmi.mesh = furja_prism
				fmi.material_override = dark_recess_mat
				fmi.position = Vector3(sin(fa) * (pillar_radius + 0.06), tier_y, cos(fa) * (pillar_radius + 0.06))
				fmi.rotation.y = fa
				pillar_root.add_child(fmi)

	# Exposed rusted rebar ribs jutting from fractured upper masonry.
	var rebar_mesh: CylinderMesh = CylinderMesh.new()
	rebar_mesh.top_radius = 0.045
	rebar_mesh.bottom_radius = 0.045
	rebar_mesh.height = 1.65
	rebar_mesh.radial_segments = 6
	for r_idx: int in range(10):
		var ra: float = float(r_idx) * 0.68 + 0.25
		var ry: float = 5.5 + float(r_idx) * 1.9
		var rmi: MeshInstance3D = MeshInstance3D.new()
		rmi.mesh = rebar_mesh
		rmi.material_override = rebar_mat
		rmi.position = Vector3(sin(ra) * (pillar_radius + 0.45), ry, cos(ra) * (pillar_radius + 0.45))
		rmi.rotation = Vector3(deg_to_rad(68.0), ra, deg_to_rad(float((r_idx % 3) - 1) * 14.0))
		pillar_root.add_child(rmi)

	# Stepped Najdi shurfat (triangular crenellations) crowning the summit parapet.
	var shurfa_prism: PrismMesh = PrismMesh.new()
	shurfa_prism.size = Vector3(1.15, 1.35, 0.65)
	for s_idx: int in range(16):
		var sa: float = (float(s_idx) / 16.0) * TAU
		var smi: MeshInstance3D = MeshInstance3D.new()
		smi.mesh = shurfa_prism
		smi.material_override = ochre_mat
		smi.position = Vector3(sin(sa) * (pillar_radius - 0.15), 25.4, cos(sa) * (pillar_radius - 0.15))
		smi.rotation.y = sa
		pillar_root.add_child(smi)

	# 4 fluttering crimson-ochre Sadu woven banners hanging along the column.
	for b_idx: int in range(4):
		var ba: float = (float(b_idx) / 4.0) * TAU + 0.35
		var by: float = 7.5 + float(b_idx) * 4.4
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(sin(ba) * (pillar_radius + 0.36), by, cos(ba) * (pillar_radius + 0.36))
		pivot.rotation.y = ba
		pillar_root.add_child(pivot)

		var cloth_box: BoxMesh = BoxMesh.new()
		cloth_box.size = Vector3(0.85, 3.2, 0.06)
		var cloth_mi: MeshInstance3D = MeshInstance3D.new()
		cloth_mi.mesh = cloth_box
		cloth_mi.material_override = crimson_mat
		cloth_mi.position = Vector3(0.0, -1.6, 0.0)
		pivot.add_child(cloth_mi)

		var trim_box: BoxMesh = BoxMesh.new()
		trim_box.size = Vector3(0.88, 0.24, 0.08)
		var trim_mi: MeshInstance3D = MeshInstance3D.new()
		trim_mi.mesh = trim_box
		trim_mi.material_override = trim_gold_mat
		trim_mi.position = Vector3(0.0, -2.95, 0.0)
		pivot.add_child(trim_mi)
		_banners.append(pivot)


func _build_spiral_ledges() -> void:
	var ledges_root: Node3D = Node3D.new()
	ledges_root.name = "SpiralLedges"
	add_child(ledges_root)
	_ledges.clear()

	var ledge_stone_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.MUD_BRICK_OCHRE.lerp(ShaalaPalette.WARM_SAND_LIGHT, 0.22), ShaalaPalette.NIGHT_INDIGO, ShaalaPalette.PALE_GOLD_ORB, 0.90, 0.09)
	var ledge_glass_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.GLASS_TEAL, ShaalaPalette.NIGHT_INDIGO, ShaalaPalette.PALE_GOLD_ORB, 1.05, 0.06)
	var lip_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.WARM_SAND_LIGHT, ShaalaPalette.MUD_BRICK_OCHRE, ShaalaPalette.PALE_GOLD_ORB, 0.95, 0.04)

	var orbit_r: float = _player.orbit_radius if _player != null else 5.45

	for i: int in range(LEDGE_COUNT):
		var t: float = float(i) / float(LEDGE_COUNT - 1)
		var angle: float = wrapf(float(i) * SPIRAL_ANGULAR_STEP, -PI, PI)
		var top_y: float = lerpf(0.95, SUMMIT_HEIGHT, t)
		var is_summit: bool = i == LEDGE_COUNT - 1
		var width_x: float = 3.8 if is_summit else (2.75 if i % 4 == 0 else 2.25)
		var depth_z: float = 2.15 if is_summit else 1.75
		var thick_y: float = 0.56 if is_summit else 0.42

		var body: StaticBody3D = StaticBody3D.new()
		body.name = "SpiralLedge_%02d" % i
		body.position = Vector3(sin(angle) * (orbit_r - 0.12), top_y - thick_y * 0.5, cos(angle) * (orbit_r - 0.12))
		body.rotation.y = angle
		ledges_root.add_child(body)

		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = Vector3(width_x, thick_y, depth_z)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = box_mesh
		mi.material_override = ledge_glass_mat if (i % 3 == 2 and not is_summit) else ledge_stone_mat
		body.add_child(mi)

		# Crisp sunlit walkable top lip so every spiral step reads clearly against the dusk sky.
		var lip_mesh: BoxMesh = BoxMesh.new()
		lip_mesh.size = Vector3(width_x + 0.04, 0.08, depth_z + 0.04)
		var lip_mi: MeshInstance3D = MeshInstance3D.new()
		lip_mi.mesh = lip_mesh
		lip_mi.material_override = lip_mat
		lip_mi.position = Vector3(0.0, thick_y * 0.5 - 0.02, 0.0)
		body.add_child(lip_mi)

		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(width_x, thick_y, depth_z)
		col.shape = shape
		body.add_child(col)

		var half_angle: float = (width_x * 0.5) / maxf(orbit_r, 1.0)
		_ledges.append({
			"angle": angle,
			"half_angle": half_angle,
			"top_y": top_y,
			"thickness": thick_y,
		})


func _build_summit_memory_orb() -> void:
	var summit_ledge: Dictionary = _ledges[_ledges.size() - 1]
	var s_angle: float = float(summit_ledge["angle"])
	var orbit_r: float = _player.orbit_radius if _player != null else 5.45
	_summit_base_y = float(summit_ledge["top_y"]) + 1.55

	_summit_orb = Node3D.new()
	_summit_orb.name = "SummitMemoryOrb"
	_summit_orb.position = Vector3(sin(s_angle) * orbit_r, _summit_base_y, cos(s_angle) * orbit_r)
	add_child(_summit_orb)

	var orb_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.PALE_GOLD_ORB, ShaalaPalette.SUNSET_ORANGE, ShaalaPalette.ORB_CORE_WHITE_GOLD, 1.4, 0.03, 1.6)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.52
	sphere.height = 1.04
	var sphere_mi: MeshInstance3D = MeshInstance3D.new()
	sphere_mi.mesh = sphere
	sphere_mi.material_override = orb_mat
	_summit_orb.add_child(sphere_mi)

	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.72
	ring_mesh.outer_radius = 0.80
	var ring_mi: MeshInstance3D = MeshInstance3D.new()
	ring_mi.mesh = ring_mesh
	ring_mi.material_override = orb_mat
	ring_mi.rotation_degrees = Vector3(62.0, 0.0, 24.0)
	_summit_orb.add_child(ring_mi)

	var glow_light: OmniLight3D = OmniLight3D.new()
	glow_light.light_color = ShaalaPalette.PALE_GOLD_ORB
	glow_light.light_energy = 2.4
	glow_light.omni_range = 10.5
	_summit_orb.add_child(glow_light)


func _build_orbiting_horizon_d6() -> void:
	# Strictly original D6 silhouette ring of distant desert mesas & abstract ruined towers
	# encircling the 360-degree horizon so the skyline sweeps as Farid orbits.
	var horizon_root: Node3D = Node3D.new()
	horizon_root.name = "OrbitingHorizonD6"
	add_child(horizon_root)

	var dune_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.DESERT_RED.lerp(ShaalaPalette.MUD_BRICK_OCHRE, 0.4), ShaalaPalette.NIGHT_INDIGO, ShaalaPalette.SUNSET_ORANGE, 0.55, 0.10)
	var tower_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.NIGHT_INDIGO.lerp(ShaalaPalette.GLASS_TEAL, 0.25), ShaalaPalette.DEEP_SHADOW, ShaalaPalette.SUNSET_ORANGE, 0.50, 0.08)

	# 18 sweeping desert dunes & Tuwaiq-inspired mesa plateaus around perimeter.
	for d: int in range(18):
		var a: float = (float(d) / 18.0) * TAU
		var dist: float = HORIZON_RADIUS + (4.0 if d % 2 == 0 else -3.0)
		var dune_w: float = 16.0 + float(d % 3) * 4.0
		var dune_h: float = 6.5 + float(d % 4) * 2.4
		var dune_prism: PrismMesh = PrismMesh.new()
		dune_prism.size = Vector3(dune_w, dune_h, 9.0)
		var dmi: MeshInstance3D = MeshInstance3D.new()
		dmi.mesh = dune_prism
		dmi.material_override = dune_mat
		dmi.position = Vector3(sin(a) * dist, dune_h * 0.4 - 4.0, cos(a) * dist)
		dmi.rotation.y = a
		horizon_root.add_child(dmi)

	# 14 distant abstract broken architectural monoliths (original D6 geometry only).
	for t_idx: int in range(14):
		var a: float = (float(t_idx) / 14.0) * TAU + 0.18
		var dist: float = HORIZON_RADIUS + 8.0 + float(t_idx % 3) * 5.0
		var th: float = 18.0 + float((t_idx * 7) % 19)
		var tw: float = 4.2 + float(t_idx % 3) * 1.4
		var t_box: BoxMesh = BoxMesh.new()
		t_box.size = Vector3(tw, th, tw * 0.85)
		var tmi: MeshInstance3D = MeshInstance3D.new()
		tmi.mesh = t_box
		tmi.material_override = tower_mat
		tmi.position = Vector3(sin(a) * dist, th * 0.5 - 5.0, cos(a) * dist)
		tmi.rotation = Vector3(deg_to_rad(float((t_idx % 3) - 1) * 3.5), a, deg_to_rad(float((t_idx % 5) - 2) * 2.0))
		horizon_root.add_child(tmi)


func _build_ambient_dust_motes() -> void:
	var motes_root: Node3D = Node3D.new()
	motes_root.name = "AmbientDustMotes"
	add_child(motes_root)
	_dust_motes.clear()

	var mote_mat: ShaderMaterial = _make_toon_mat(ShaalaPalette.PALE_GOLD_ORB, ShaalaPalette.PALE_GOLD_ORB, ShaalaPalette.ORB_CORE_WHITE_GOLD, 0.6, 0.0, 1.5)
	var mote_mesh: SphereMesh = SphereMesh.new()
	mote_mesh.radius = 0.075
	mote_mesh.height = 0.15
	mote_mesh.radial_segments = 6
	mote_mesh.rings = 4

	for i: int in range(28):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mote_mesh
		mi.material_override = mote_mat
		motes_root.add_child(mi)
		_dust_motes.append(mi)
