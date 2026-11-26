class_name OrbShrine
extends InteractableBase
## Najdi mud-brick Orb Shrine (مقام الشعلة) — checkpoint, full restore, and save point.
## Displays a stepped Najdi stele with triangular ventilation slits (furjat),
## suspended pale-gold memory orb lantern, glowing ground circle, and drifting dust motes.

@export var shrine_id: String = "shrine_desert_camp"
@export var room_id: String = "desert_camp_01"

const LANTERN_CENTER: Vector2 = Vector2(0.0, -78.0)
const MOTE_COUNT: int = 10

var _time: float = 0.0
var _pulse_progress: float = 1.0
var _pulse_active: bool = false
var _mote_phases: Array[float] = []
var _mote_radii: Array[float] = []

@onready var _orb_glow: ColorRect = get_node_or_null("OrbGlow") as ColorRect
@onready var _fx_overlay: Node2D = get_node_or_null("FxOverlay") as Node2D


func _init() -> void:
	prompt_key = "PROMPT_REST_SHRINE"
	interaction_cooldown = 0.6


func _ready() -> void:
	super._ready()
	_init_motes()
	if _fx_overlay != null and not _fx_overlay.draw.is_connected(_draw_overlay):
		_fx_overlay.draw.connect(_draw_overlay)


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta

	if _orb_glow != null:
		var bob: float = sin(_time * 2.1) * 3.5
		_orb_glow.position = LANTERN_CENTER + Vector2(-52.0, -52.0 + bob)

	if _pulse_active:
		_pulse_progress += delta * 1.45
		if _pulse_progress >= 1.0:
			_pulse_progress = 1.0
			_pulse_active = false
		_update_shader_burst(maxf(0.0, 1.0 - _pulse_progress))

	queue_redraw()
	if _fx_overlay != null:
		_fx_overlay.queue_redraw()


func _draw() -> void:
	var pulse_boost: float = 0.0
	if _pulse_active:
		pulse_boost = sin(_pulse_progress * PI)

	# Glowing Najdi ground circle beneath the stele.
	var ground_alpha: float = 0.24 + 0.08 * sin(_time * 1.8) + pulse_boost * 0.35
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 66.0 + pulse_boost * 14.0, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, ground_alpha * 0.45))
	draw_arc(Vector2.ZERO, 54.0, 0.0, TAU, 36, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, ground_alpha + 0.2), 2.5, true)
	draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 28, ShaalaPalette.with_alpha(ShaalaPalette.SUNSET_ORANGE, ground_alpha), 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_overlay() -> void:
	if _fx_overlay == null:
		return
	var pulse_boost: float = 0.0
	if _pulse_active:
		pulse_boost = sin(_pulse_progress * PI)
	# Expanding golden pulse shockwave on rest.
	if _pulse_active:
		var flash_cap: float = 0.45 if SettingsManager.reduce_flash else 0.9
		var wave_r: float = lerpf(24.0, 165.0, _pulse_progress)
		var wave_a: float = (1.0 - _pulse_progress) * flash_cap
		_fx_overlay.draw_arc(LANTERN_CENTER, wave_r, 0.0, TAU, 48, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, wave_a), 4.0 * (1.0 - _pulse_progress) + 1.0, true)
		_fx_overlay.draw_arc(LANTERN_CENTER, wave_r * 0.68, 0.0, TAU, 36, ShaalaPalette.with_alpha(ShaalaPalette.ORB_CORE_WHITE_GOLD, wave_a * 0.75), 2.0, true)

	# Suspended lantern chain and delicate brass ring.
	var bob_y: float = sin(_time * 2.1) * 3.5
	var orb_pos: Vector2 = LANTERN_CENTER + Vector2(0.0, bob_y)
	_fx_overlay.draw_line(Vector2(0.0, -124.0), orb_pos + Vector2(0.0, -14.0), ShaalaPalette.MOTAIB_BRONZE_TRIM, 2.0, true)
	_fx_overlay.draw_arc(orb_pos, 15.0, 0.0, TAU, 24, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, 0.65), 1.5, true)
	_fx_overlay.draw_circle(orb_pos, 8.5 + pulse_boost * 3.0, ShaalaPalette.ORB_CORE_WHITE_GOLD)

	# Floating golden dust motes rising gently from the shrine circle.
	for i: int in range(_mote_phases.size()):
		var cycle: float = fmod(_time * 0.24 + _mote_phases[i], 1.0)
		var drift_x: float = sin(_time * 1.1 + float(i) * 1.7) * _mote_radii[i]
		var pos_y: float = lerpf(-6.0, -148.0, cycle)
		var alpha: float = sin(cycle * PI) * (0.65 + pulse_boost * 0.35)
		var radius: float = 1.6 + 1.4 * sin(cycle * PI)
		_fx_overlay.draw_circle(Vector2(drift_x, pos_y), radius, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, alpha))


func _on_interact(_player: Node) -> void:
	GameState.rest_at_shrine(shrine_id, room_id)
	SaveManager.save_game()
	AudioManager.play_sfx("shrine_rest")
	_trigger_golden_pulse()


func _trigger_golden_pulse() -> void:
	_pulse_active = true
	_pulse_progress = 0.0
	var burst_level: float = 0.45 if SettingsManager.reduce_flash else 1.0
	_update_shader_burst(burst_level)
	EventBus.camera_shake_requested.emit(3.5, 0.22)


func _update_shader_burst(amount: float) -> void:
	if _orb_glow == null:
		return
	var mat: ShaderMaterial = _orb_glow.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("burst_amount", clampf(amount, 0.0, 1.0))


func _init_motes() -> void:
	_mote_phases.clear()
	_mote_radii.clear()
	for i: int in range(MOTE_COUNT):
		_mote_phases.append(float(i) / float(MOTE_COUNT))
		_mote_radii.append(16.0 + fmod(float(i) * 13.7, 36.0))
