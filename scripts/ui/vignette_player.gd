class_name VignettePlayer
extends Control
## Plays both Memory Orb Vignettes (dimmed pale-gold orb canvas + poetic lines + Ability Unlocked banner)
## and NPC / Torn Notebook Dialogue boxes. Locks player controls cleanly while open.

signal finished

enum Mode {
	NONE,
	VIGNETTE,
	DIALOGUE,
}

const INPUT_DEBOUNCE_SEC: float = 0.24
## Ambient orb animation redraws at a capped rate instead of every frame (idle power, plan §9).
const AMBIENT_REDRAW_HZ: float = 20.0

@onready var backdrop: ColorRect = $Backdrop
@onready var vignette_container: CenterContainer = $VignetteContainer
@onready var vig_badge_label: Label = $VignetteContainer/VignetteCard/VBox/BadgeLabel
@onready var vig_title_label: Label = $VignetteContainer/VignetteCard/VBox/TitleLabel
@onready var vig_line_label: RichTextLabel = $VignetteContainer/VignetteCard/VBox/LineLabel
@onready var ability_banner: PanelContainer = $VignetteContainer/VignetteCard/VBox/AbilityBanner
@onready var ability_header_label: Label = $VignetteContainer/VignetteCard/VBox/AbilityBanner/VBox/AbilityHeaderLabel
@onready var ability_name_label: Label = $VignetteContainer/VignetteCard/VBox/AbilityBanner/VBox/AbilityNameLabel
@onready var ability_desc_label: Label = $VignetteContainer/VignetteCard/VBox/AbilityBanner/VBox/AbilityDescLabel
@onready var vig_continue_label: Label = $VignetteContainer/VignetteCard/VBox/FooterRow/ContinueHintLabel
@onready var vig_progress_label: Label = $VignetteContainer/VignetteCard/VBox/FooterRow/ProgressLabel

@onready var dialogue_panel: PanelContainer = $DialogueMargin/DialoguePanel
@onready var dlg_speaker_label: Label = $DialogueMargin/DialoguePanel/VBox/HeaderRow/SpeakerLabel
@onready var dlg_progress_label: Label = $DialogueMargin/DialoguePanel/VBox/HeaderRow/ProgressLabel
@onready var dlg_body_label: RichTextLabel = $DialogueMargin/DialoguePanel/VBox/BodyRow/BodyLabel
@onready var dlg_advance_ember: TextureRect = $DialogueMargin/DialoguePanel/VBox/BodyRow/AdvanceEmber
@onready var vig_advance_ember: TextureRect = $VignetteContainer/VignetteCard/VBox/FooterRow/AdvanceEmber
@onready var vig_card: PanelContainer = $VignetteContainer/VignetteCard
@onready var letterbox_top: ColorRect = $LetterboxTop
@onready var letterbox_bottom: ColorRect = $LetterboxBottom
@onready var dialogue_margin: MarginContainer = $DialogueMargin

const SCRIM_BOTTOM_PATH: String = "res://assets/final/ui/scrim_bottom.png"
## Dialogue text keeps to about 60% of the screen width, start-aligned (plan §6.3).
const DIALOGUE_SIDE_MARGIN: float = 220.0
@onready var dlg_continue_label: Label = $DialogueMargin/DialoguePanel/VBox/ContinueHintLabel

var _mode: Mode = Mode.NONE
var _vignette_title_key: String = ""
var _vignette_lines: Array[String] = []
var _vignette_ability_id: String = ""
var _dialogue_entries: Array[Dictionary] = []
var _current_index: int = 0
var _debounce_timer: float = 0.0
var _elapsed: float = 0.0
var _line_tween: Tween = null
var _redraw_accum: float = 0.0
var _revealing_label: RichTextLabel = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	dlg_speaker_label.set_meta("align_reading_edge", true)
	dlg_continue_label.set_meta("align_reading_edge", true)
	ability_desc_label.set_meta("align_reading_edge", true)
	vig_title_label.set_meta("font_role", ArabicFontSetup.ROLE_DISPLAY)
	ability_name_label.set_meta("font_role", ArabicFontSetup.ROLE_DISPLAY)
	vig_line_label.set_meta("font_role", ArabicFontSetup.ROLE_HAND)
	dlg_speaker_label.set_meta("font_role", ArabicFontSetup.ROLE_DISPLAY)
	ability_header_label.set_meta("font_role", ArabicFontSetup.ROLE_BODY)
	dlg_body_label.set_meta("font_role", ArabicFontSetup.ROLE_BODY)
	# No counters and no "press to continue" text on memories or dialogue (plan §6.3–§6.4);
	# a small pulsing ember marks that the line can be advanced.
	vig_progress_label.visible = false
	dlg_progress_label.visible = false
	vig_continue_label.visible = false
	dlg_continue_label.visible = false
	_style_surfaces()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _debounce_timer > 0.0:
		_debounce_timer = maxf(0.0, _debounce_timer - delta)
	_update_advance_embers()
	if _mode == Mode.VIGNETTE and not SettingsManager.reduce_motion:
		_redraw_accum += delta
		if _redraw_accum >= 1.0 / AMBIENT_REDRAW_HZ:
			_redraw_accum = 0.0
			queue_redraw()


func _draw() -> void:
	if _mode != Mode.VIGNETTE:
		return
	# Near-black memory field drawn here (not by Backdrop) so the orb light sits on top of it.
	draw_rect(Rect2(Vector2.ZERO, size), Color(UITokens.NIGHT_DEEP, 0.95))
	var orb_center: Vector2 = Vector2(size.x * 0.5, size.y * 0.16)
	var pulse: float = 1.0 + 0.07 * sin(_elapsed * 2.1)
	draw_circle(orb_center, 155.0 * pulse, Color(UITokens.PALE_GOLD, 0.05))
	draw_circle(orb_center, 102.0 * pulse, Color(UITokens.PALE_GOLD, 0.11))
	draw_circle(orb_center, 58.0 * pulse, Color(UITokens.PALE_GOLD, 0.24))
	draw_circle(orb_center, 24.0, Color(UITokens.PALE_GOLD, 0.9))

	for i: int in range(12):
		var angle: float = _elapsed * 0.55 + float(i) * (TAU / 12.0)
		var radius: float = 72.0 + 26.0 * sin(_elapsed * 1.1 + float(i))
		var pos: Vector2 = orb_center + Vector2(cos(angle), sin(angle) * 0.65) * radius
		draw_circle(pos, 2.5, Color(UITokens.PALE_GOLD, 0.42))


func _input(event: InputEvent) -> void:
	if not visible or _mode == Mode.NONE:
		return
	if _debounce_timer > 0.0:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
		return

	var should_advance: bool = (
		event.is_action_pressed("interact")
		or event.is_action_pressed("jump")
		or event.is_action_pressed("ui_accept")
	)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			should_advance = true

	if should_advance:
		get_viewport().set_input_as_handled()
		_advance()


func is_playing() -> bool:
	return _mode != Mode.NONE and visible


func play_vignette(title_key: String, lines: Array, ability_id: String = "") -> void:
	_mode = Mode.VIGNETTE
	_vignette_title_key = title_key
	_vignette_lines.clear()
	for item: Variant in lines:
		_vignette_lines.append(str(item))
	_vignette_ability_id = ability_id
	_current_index = 0
	_debounce_timer = INPUT_DEBOUNCE_SEC

	backdrop.color = Color(UITokens.NIGHT_DEEP, 0.0)
	vignette_container.visible = true
	dialogue_panel.get_parent().visible = false
	_show_letterbox(false)
	queue_redraw()
	visible = true
	_set_player_controls(false)
	AudioManager.play_sfx("orb_collect")
	refresh_texts()
	_animate_current_line(vig_line_label)


func play_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return
	_mode = Mode.DIALOGUE
	_dialogue_entries.clear()
	for item: Variant in lines:
		if item is Dictionary:
			var d := item as Dictionary
			_dialogue_entries.append({
				"speaker_key": str(d.get("speaker_key", "")),
				"text_key": str(d.get("text_key", d.get("line_key", ""))),
			})
		else:
			_dialogue_entries.append({
				"speaker_key": "",
				"text_key": str(item),
			})
	_current_index = 0
	_debounce_timer = INPUT_DEBOUNCE_SEC

	# The world keeps running behind a cinematic letterbox; no dimmer (plan §6.3).
	backdrop.color = Color(UITokens.NIGHT_DEEP, 0.0)
	vignette_container.visible = false
	dialogue_panel.get_parent().visible = true
	_show_letterbox(true)
	queue_redraw()
	visible = true
	_set_player_controls(false)
	AudioManager.play_sfx("ui_talk")
	refresh_texts()
	_animate_current_line(dlg_body_label)


func force_close() -> void:
	if _mode != Mode.NONE:
		_set_player_controls(true)
	_mode = Mode.NONE
	visible = false
	_show_letterbox(false)


func refresh_texts() -> void:
	if _mode == Mode.VIGNETTE:
		_render_vignette()
	elif _mode == Mode.DIALOGUE:
		_render_dialogue()


func _render_vignette() -> void:
	vig_badge_label.text = tr("UI_MEMORY_ECHO")
	vig_title_label.text = tr(_vignette_title_key)

	var total: int = maxi(1, _vignette_lines.size())
	var line_key: String = _vignette_lines[_current_index] if _current_index < _vignette_lines.size() else ""
	vig_line_label.text = "[center]%s[/center]" % tr(line_key).replace("[", "[lb]") if not line_key.is_empty() else ""
	vig_progress_label.text = ArabicFontSetup.isolate_ltr(ArabicFontSetup.localize_digits("%d / %d" % [_current_index + 1, total]))

	# The ability card is its own final beat after the last line (plan §6.4).
	var show_ability: bool = _is_ability_card()
	ability_banner.visible = show_ability
	vig_line_label.visible = not show_ability
	if show_ability:
		var upper_id: String = _vignette_ability_id.to_upper()
		ability_header_label.text = tr("UI_ABILITY_UNLOCKED")
		ability_name_label.text = tr("ABILITY_%s_NAME" % upper_id)
		ability_desc_label.text = tr("ABILITY_%s_DESC" % upper_id)

	var key_str: String = ArabicFontSetup.get_action_key_label("interact")
	vig_continue_label.text = ArabicFontSetup.format_key_prompt(key_str, tr("UI_PRESS_CONTINUE"))


func _render_dialogue() -> void:
	if _current_index >= _dialogue_entries.size():
		return
	var entry: Dictionary = _dialogue_entries[_current_index]
	var speaker_key: String = str(entry.get("speaker_key", ""))
	var text_key: String = str(entry.get("text_key", ""))

	dlg_speaker_label.text = tr(speaker_key) if not speaker_key.is_empty() else ""
	dlg_speaker_label.visible = not speaker_key.is_empty()
	dlg_body_label.text = tr(text_key) if not text_key.is_empty() else ""
	dlg_progress_label.text = ArabicFontSetup.isolate_ltr(
		ArabicFontSetup.localize_digits("%d / %d" % [_current_index + 1, _dialogue_entries.size()])
	)

	var key_str: String = ArabicFontSetup.get_action_key_label("interact")
	dlg_continue_label.text = ArabicFontSetup.format_key_prompt(key_str, tr("UI_PRESS_CONTINUE"))


func _is_ability_card() -> bool:
	return not _vignette_ability_id.is_empty() and _current_index >= _vignette_lines.size()


func _style_surfaces() -> void:
	var empty := StyleBoxEmpty.new()
	vig_card.add_theme_stylebox_override("panel", empty)
	ability_banner.add_theme_stylebox_override("panel", empty)
	var scrim: StyleBox = empty
	if ResourceLoader.exists(SCRIM_BOTTOM_PATH):
		var tex_box := StyleBoxTexture.new()
		tex_box.texture = load(SCRIM_BOTTOM_PATH) as Texture2D
		scrim = tex_box
	scrim.content_margin_left = DIALOGUE_SIDE_MARGIN
	scrim.content_margin_right = DIALOGUE_SIDE_MARGIN
	scrim.content_margin_top = 120.0
	scrim.content_margin_bottom = 110.0
	dialogue_panel.add_theme_stylebox_override("panel", scrim)


func _show_letterbox(enabled: bool) -> void:
	letterbox_top.visible = enabled
	letterbox_bottom.visible = enabled
	if not enabled:
		return
	if SettingsManager.reduce_motion:
		letterbox_top.scale.y = 1.0
		letterbox_bottom.scale.y = 1.0
		return
	letterbox_top.scale.y = 0.0
	letterbox_bottom.pivot_offset = Vector2(0.0, letterbox_bottom.size.y)
	letterbox_bottom.scale.y = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(letterbox_top, "scale:y", 1.0, UITokens.SLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(letterbox_bottom, "scale:y", 1.0, UITokens.SLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The advance ember appears once the line has fully written on, and breathes gently.
func _update_advance_embers() -> void:
	var ready_to_advance: bool = _revealing_label == null or _revealing_label.visible_ratio >= 1.0
	var pulse: float = 1.0 if SettingsManager.reduce_motion else 0.55 + 0.45 * (0.5 + 0.5 * sin(_elapsed * 4.0))
	var alpha: float = pulse if ready_to_advance else 0.0
	vig_advance_ember.modulate.a = alpha
	dlg_advance_ember.modulate.a = alpha


func _advance() -> void:
	_debounce_timer = INPUT_DEBOUNCE_SEC
	# First press while a line is still writing on completes it instead of skipping it.
	if _revealing_label != null and _revealing_label.visible_ratio < 1.0:
		if _line_tween != null and _line_tween.is_valid():
			_line_tween.kill()
		_revealing_label.visible_ratio = 1.0
		_revealing_label.modulate.a = 1.0
		return
	AudioManager.play_sfx("ui_talk")
	if _mode == Mode.VIGNETTE:
		if _current_index + 1 < _vignette_lines.size():
			_current_index += 1
			_render_vignette()
			_animate_current_line(vig_line_label)
		elif not _vignette_ability_id.is_empty() and not _is_ability_card():
			_current_index = _vignette_lines.size()
			_render_vignette()
			_animate_current_line(ability_banner)
		else:
			_close()
	elif _mode == Mode.DIALOGUE:
		if _current_index + 1 < _dialogue_entries.size():
			_current_index += 1
			_render_dialogue()
			_animate_current_line(dlg_body_label)
		else:
			_close()


func _animate_current_line(target: Control) -> void:
	if _line_tween != null and _line_tween.is_valid():
		_line_tween.kill()
	# Write-on reveal that keeps Arabic letters joined (shaping first, then reveal);
	# Reduce Motion falls back to a plain fade.
	target.modulate.a = 0.0
	_revealing_label = target as RichTextLabel if target is RichTextLabel else null
	_line_tween = create_tween()
	_line_tween.set_parallel(true)
	_line_tween.tween_property(target, "modulate:a", 1.0, UITokens.FADE_IN)
	if target is RichTextLabel and not SettingsManager.reduce_motion:
		var rich := target as RichTextLabel
		rich.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		rich.visible_ratio = 0.0
		var reveal_time: float = UITokens.WRITE_ON_LONG if _mode == Mode.VIGNETTE else UITokens.WRITE_ON_SHORT
		_line_tween.tween_property(rich, "visible_ratio", 1.0, reveal_time)
	elif target is RichTextLabel:
		(target as RichTextLabel).visible_ratio = 1.0


func _close() -> void:
	_mode = Mode.NONE
	visible = false
	_show_letterbox(false)
	_set_player_controls(true)
	finished.emit()


func _set_player_controls(enabled: bool) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for node: Node in players:
		if node.has_method("set_controls_enabled"):
			node.call("set_controls_enabled", enabled)
