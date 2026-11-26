class_name MemoryOrb
extends InteractableBase
## Floating pale-gold Memory Orb — holds a returning fragment of Farid's memory
## and unlocks the linked traversal/combat ability with a poetic vignette.

@export var orb_id: String = ""
@export var ability_id: String = ""
@export var vignette_title_key: String = ""
@export var vignette_line_keys: Array[String] = []

var _time: float = 0.0
var _collected: bool = false
var _absorb_progress: float = 0.0
var _base_glow_pos: Vector2 = Vector2(-48.0, -48.0)

@onready var _orb_glow: ColorRect = get_node_or_null("OrbGlow") as ColorRect


func _init() -> void:
	prompt_key = "PROMPT_ABSORB_ORB"


func _ready() -> void:
	super._ready()
	if orb_id != "" and orb_id in GameState.collected_orbs:
		queue_free()
		return
	if _orb_glow != null:
		_base_glow_pos = _orb_glow.position


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta

	if not _collected and _orb_glow != null:
		var bob_y: float = sin(_time * 2.4) * 7.5
		var sway_x: float = cos(_time * 1.3) * 2.0
		_orb_glow.position = _base_glow_pos + Vector2(sway_x, bob_y)

	queue_redraw()


func _draw() -> void:
	var bob_offset: Vector2 = Vector2(cos(_time * 1.3) * 2.0, sin(_time * 2.4) * 7.5)
	if _collected:
		var ring_r: float = lerpf(16.0, 92.0, _absorb_progress)
		var ring_a: float = (1.0 - _absorb_progress) * (0.45 if SettingsManager.reduce_flash else 0.9)
		draw_arc(bob_offset, ring_r, 0.0, TAU, 36, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, ring_a), 3.0, true)
		return

	# Delicate concentric Citadel memory rings orbiting the core sphere.
	var outer_alpha: float = 0.28 + 0.14 * sin(_time * 2.8)
	draw_arc(bob_offset, 26.0, _time * 0.7, _time * 0.7 + PI * 1.35, 24, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, outer_alpha), 1.6, true)
	draw_arc(bob_offset, 20.0, -_time * 1.1, -_time * 1.1 + PI * 1.1, 20, ShaalaPalette.with_alpha(ShaalaPalette.SUNSET_ORANGE, outer_alpha * 0.85), 1.3, true)

	# Crisp luminous inner nucleus so orb reads clearly even before shaders load.
	draw_circle(bob_offset, 10.5, ShaalaPalette.with_alpha(ShaalaPalette.PALE_GOLD_ORB, 0.85))
	draw_circle(bob_offset, 6.0, ShaalaPalette.ORB_CORE_WHITE_GOLD)


func _on_interact(player: Node) -> void:
	if _collected:
		return
	_collected = true
	set_interaction_enabled(false)

	GameState.collect_orb(orb_id, ability_id, vignette_title_key)
	EventBus.vignette_requested.emit(vignette_title_key, vignette_line_keys, ability_id)
	SaveManager.save_game()
	AudioManager.play_sfx("orb_collect")
	EventBus.camera_shake_requested.emit(4.0, 0.25)

	_play_absorb_animation(player)


func _play_absorb_animation(player: Node) -> void:
	var target_global: Vector2 = global_position + Vector2(0.0, -28.0)
	if player is Node2D:
		target_global = (player as Node2D).global_position + Vector2(0.0, -24.0)

	var mat: ShaderMaterial = null
	if _orb_glow != null:
		mat = _orb_glow.material as ShaderMaterial
		if mat != null:
			var burst_cap: float = 0.45 if SettingsManager.reduce_flash else 1.0
			mat.set_shader_parameter("burst_amount", burst_cap)

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_global, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.15, 0.15), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_absorb_progress, 0.0, 1.0, 0.38)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _set_absorb_progress(value: float) -> void:
	_absorb_progress = value
