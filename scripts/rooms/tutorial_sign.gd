class_name TutorialSign
extends Area2D
## Contextual Najdi stone tutorial marker and optional sealed-monument lore sign.
## Emits EventBus.interaction_prompt_changed with tutorial_key when Farid stands near.
## When dialogue_line_keys is non-empty, pressing interact displays localized dialogue.

@export var tutorial_key: String = "TUT_MOVE"
@export var speaker_key: String = ""
@export var dialogue_line_keys: Array[String] = []
@export_enum("stone", "metro_seal") var glyph_style: String = "stone"

const COLOR_OCHRE: Color = Color("#C68B59")
const COLOR_DESERT_RED: Color = Color("#A84432")
const COLOR_INDIGO: Color = Color("#161B33")
const COLOR_DEEP_SHADOW: Color = Color("#0D1021")
const COLOR_GLASS_TEAL: Color = Color("#4F6D7A")
const COLOR_PALE_GOLD: Color = Color("#F6E299")

var _player_in_range: Node = null
var _time: float = 0.0
var _glow_strength: float = 0.25
var _last_interact_frame: int = -1


func _ready() -> void:
	collision_layer = 64
	collision_mask = 4
	monitoring = true
	monitorable = true
	add_to_group("interactables")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_time += delta
	var target_glow: float = 0.95 if _player_in_range != null else 0.28
	_glow_strength = lerpf(_glow_strength, target_glow, minf(1.0, delta * 6.0))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null or dialogue_line_keys.is_empty():
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		interact(_player_in_range)
		get_viewport().set_input_as_handled()


func interact(_player: Node) -> void:
	if dialogue_line_keys.is_empty():
		return
	var current_frame: int = Engine.get_process_frames()
	if current_frame == _last_interact_frame:
		return
	_last_interact_frame = current_frame

	var lines: Array[Dictionary] = []
	for line_key: String in dialogue_line_keys:
		if line_key != "":
			lines.append({
				"speaker_key": speaker_key,
				"text_key": line_key,
			})
	if lines.is_empty():
		return
	AudioManager.play_sfx("ui_talk")
	EventBus.dialogue_requested.emit(lines)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	_player_in_range = body
	EventBus.interaction_prompt_changed.emit(true, tutorial_key)


func _on_body_exited(body: Node) -> void:
	if body != _player_in_range:
		return
	_player_in_range = null
	EventBus.interaction_prompt_changed.emit(false, "")


func _draw() -> void:
	var pulse: float = 0.8 + 0.2 * sin(_time * 2.4)
	var gold_alpha: float = clampf(_glow_strength * pulse, 0.18, 1.0)
	var gold_col: Color = Color(COLOR_PALE_GOLD.r, COLOR_PALE_GOLD.g, COLOR_PALE_GOLD.b, gold_alpha)

	if glyph_style == "metro_seal":
		# Sealed Milestone 2 Metro Tunnels monument arch.
		var frame_pts: PackedVector2Array = PackedVector2Array([
			Vector2(-46.0, 44.0),
			Vector2(-46.0, -76.0),
			Vector2(0.0, -104.0),
			Vector2(46.0, -76.0),
			Vector2(46.0, 44.0),
		])
		draw_colored_polygon(frame_pts, COLOR_INDIGO)
		var inner_pts: PackedVector2Array = PackedVector2Array([
			Vector2(-34.0, 44.0),
			Vector2(-34.0, -68.0),
			Vector2(0.0, -90.0),
			Vector2(34.0, -68.0),
			Vector2(34.0, 44.0),
		])
		draw_colored_polygon(inner_pts, COLOR_DEEP_SHADOW)
		# Cracked glass teal seal bars and humming pale-gold Citadel diamond.
		draw_line(Vector2(-32.0, -34.0), Vector2(32.0, -34.0), COLOR_GLASS_TEAL, 3.0, true)
		draw_line(Vector2(-32.0, 4.0), Vector2(32.0, 4.0), COLOR_GLASS_TEAL, 3.0, true)
		draw_arc(Vector2(0.0, -34.0), 18.0, 0.0, TAU, 28, gold_col, 2.2, true)
		var diamond: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, -48.0),
			Vector2(10.0, -34.0),
			Vector2(0.0, -20.0),
			Vector2(-10.0, -34.0),
		])
		draw_colored_polygon(diamond, gold_col)
	else:
		# Stepped Najdi mud-brick / desert sandstone waystone with etched flame diamond.
		var base_pts: PackedVector2Array = PackedVector2Array([
			Vector2(-24.0, 44.0),
			Vector2(-18.0, 32.0),
			Vector2(18.0, 32.0),
			Vector2(24.0, 44.0),
		])
		draw_colored_polygon(base_pts, COLOR_DEEP_SHADOW)
		var stele_pts: PackedVector2Array = PackedVector2Array([
			Vector2(-15.0, 34.0),
			Vector2(-13.0, -24.0),
			Vector2(0.0, -38.0),
			Vector2(13.0, -24.0),
			Vector2(15.0, 34.0),
		])
		draw_colored_polygon(stele_pts, COLOR_OCHRE)
		var trim_pts: PackedVector2Array = PackedVector2Array([
			Vector2(-11.0, 32.0),
			Vector2(-10.0, -20.0),
			Vector2(0.0, -31.0),
			Vector2(10.0, -20.0),
			Vector2(11.0, 32.0),
		])
		draw_colored_polygon(trim_pts, COLOR_DESERT_RED.darkened(0.32))
		# Etched Najdi triangular furjat slits + glowing ember diamond.
		var slit_top: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, -22.0),
			Vector2(6.0, -11.0),
			Vector2(-6.0, -11.0),
		])
		draw_colored_polygon(slit_top, gold_col)
		var slit_mid: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, -5.0),
			Vector2(7.0, 6.0),
			Vector2(0.0, 17.0),
			Vector2(-7.0, 6.0),
		])
		draw_colored_polygon(slit_mid, Color(gold_col.r, gold_col.g, gold_col.b, gold_alpha * 0.72))
