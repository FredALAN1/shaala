class_name TitleScreen
extends Control
## Atmospheric Arabic-first title screen for SHAALA (شعلة).
## Notebook & Ember title (plan §6.1): hand-lettered logo, box-free text menu with an ember
## focus mark, and a small language toggle in the bottom end corner, over the dusk scene.

signal new_game_pressed
signal continue_pressed
signal settings_pressed
signal quit_pressed


@onready var title_label: Label = $Layout/Row/Column/TitleLabel
@onready var logo_rect: TextureRect = $Layout/Row/Column/Logo
@onready var subtitle_label: Label = $Layout/Row/Column/SubtitleLabel
@onready var tagline_label: Label = $Layout/Row/Column/TaglineLabel
@onready var new_game_button: Button = $Layout/Row/Column/ButtonsBox/NewGameButton
@onready var continue_button: Button = $Layout/Row/Column/ButtonsBox/ContinueButton
@onready var settings_button: Button = $Layout/Row/Column/ButtonsBox/SettingsButton
@onready var quit_button: Button = $Layout/Row/Column/ButtonsBox/QuitButton
@onready var language_label: Label = $Footer/LanguageRow/LanguageLabel
@onready var lang_ar_button: Button = $Footer/LanguageRow/LangArButton
@onready var lang_en_button: Button = $Footer/LanguageRow/LangEnButton

const FOCUS_EMBER_PATH: String = "res://assets/final/ui/focus_ember.png"
const FLICKER_HZ: float = 10.0

const AMBIENT_REDRAW_HZ: float = 20.0

var _elapsed: float = 0.0
var _redraw_accum: float = 0.0
var _flicker_accum: float = 0.0
var _menu_buttons: Array[Button] = []


func _ready() -> void:
	title_label.set_meta("font_role", ArabicFontSetup.ROLE_DISPLAY)
	subtitle_label.set_meta("font_role", ArabicFontSetup.ROLE_HAND)
	tagline_label.set_meta("font_role", ArabicFontSetup.ROLE_BODY)
	subtitle_label.set_meta("align_reading_edge", true)
	tagline_label.set_meta("align_reading_edge", true)
	# The hand-lettered logo (decision D2) replaces the text title when present.
	var has_logo: bool = logo_rect.texture != null
	logo_rect.visible = has_logo
	title_label.visible = not has_logo
	title_label.set_meta("align_reading_edge", true)
	_menu_buttons = [continue_button, new_game_button, settings_button, quit_button]
	for btn: Button in _menu_buttons:
		_style_menu_button(btn)
	for lang_btn: Button in [lang_ar_button, lang_en_button]:
		_style_language_button(lang_btn)
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	lang_ar_button.pressed.connect(_on_select_arabic)
	lang_en_button.pressed.connect(_on_select_english)

	refresh_texts()
	refresh_state()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	_flicker_accum += delta
	if _flicker_accum >= 1.0 / FLICKER_HZ:
		_flicker_accum = 0.0
		_update_focus_flicker()
	# Capped ambient redraw (was every frame); frozen under Reduce Motion.
	if SettingsManager.reduce_motion:
		return
	_redraw_accum += delta
	if _redraw_accum >= 1.0 / AMBIENT_REDRAW_HZ:
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		return

	# Painterly dusk sky gradient bands (night indigo -> desert red -> sunset ochre horizon)
	var sky_bands: Array[Color] = [
		UITokens.NIGHT_DEEP,
		UITokens.NIGHT_INDIGO,
		Color("#2A223D"),
		Color("#5C2D36"),
		UITokens.DESERT_RED,
		UITokens.EMBER.darkened(0.22),
	]
	# Smooth vertical gradient between the stops (no hard bands).
	var step_h: float = (sz.y * 0.8) / float(sky_bands.size() - 1)
	for i: int in range(sky_bands.size() - 1):
		var y0: float = float(i) * step_h
		var y1: float = y0 + step_h
		var quad := PackedVector2Array([Vector2(0.0, y0), Vector2(sz.x, y0), Vector2(sz.x, y1), Vector2(0.0, y1)])
		var cols := PackedColorArray([sky_bands[i], sky_bands[i], sky_bands[i + 1], sky_bands[i + 1]])
		draw_polygon(quad, cols)
	draw_rect(Rect2(0.0, sz.y * 0.8, sz.x, sz.y * 0.2), sky_bands[sky_bands.size() - 1])

	# Floating pale-gold Memory Orb halo in upper sky
	var orb_pulse: float = 1.0 + 0.06 * sin(_elapsed * 1.8)
	var orb_pos: Vector2 = Vector2(sz.x * 0.5, sz.y * 0.17)
	draw_circle(orb_pos, 150.0 * orb_pulse, Color(UITokens.PALE_GOLD, 0.05))
	draw_circle(orb_pos, 96.0 * orb_pulse, Color(UITokens.PALE_GOLD, 0.11))
	draw_circle(orb_pos, 52.0 * orb_pulse, Color(UITokens.PALE_GOLD, 0.22))
	draw_circle(orb_pos, 22.0, Color(UITokens.PALE_GOLD, 0.85))

	# Drifting desert memory motes
	for m: int in range(18):
		var phase: float = float(m) * 1.37
		var mx: float = fmod(float(m) * (sz.x / 18.0) + _elapsed * (12.0 + float(m % 4) * 5.0), sz.x)
		var my: float = sz.y * (0.25 + 0.55 * (0.5 + 0.5 * sin(phase + _elapsed * 0.45)))
		var alpha: float = 0.18 + 0.16 * sin(_elapsed * 1.4 + phase)
		draw_circle(Vector2(mx, my), 2.5 + float(m % 3), Color(UITokens.PALE_GOLD, alpha))

	# Distant ruined Riyadh glass towers silhouette (abstract respectful skyline on horizon)
	var horizon_y: float = sz.y * 0.72
	var tower_color: Color = Color(UITokens.NIGHT_INDIGO, 0.72)
	# Skyline sits on the end side so it never crosses the start-aligned menu.
	var tower_specs: Array[Vector3] = [
		Vector3(0.58, 190.0, 44.0),
		Vector3(0.62, 260.0, 56.0),
		Vector3(0.67, 150.0, 38.0),
		Vector3(0.80, 210.0, 46.0),
		Vector3(0.84, 310.0, 62.0),
		Vector3(0.90, 175.0, 42.0),
	]
	var mirror: bool = is_layout_rtl()
	var towers: Array[Rect2] = []
	for spec: Vector3 in tower_specs:
		var tx: float = sz.x * spec.x
		if mirror:
			tx = sz.x - tx - spec.z
		towers.append(Rect2(tx, horizon_y - spec.y, spec.z, spec.y + 20.0))
	for rect: Rect2 in towers:
		draw_rect(rect, tower_color)

	# Midground dune ridge in mud-brick ochre / desert shadow
	var mid_dune := PackedVector2Array([
		Vector2(0.0, sz.y),
		Vector2(0.0, sz.y * 0.78),
		Vector2(sz.x * 0.22, sz.y * 0.71),
		Vector2(sz.x * 0.48, sz.y * 0.76),
		Vector2(sz.x * 0.75, sz.y * 0.69),
		Vector2(sz.x, sz.y * 0.75),
		Vector2(sz.x, sz.y),
	])
	draw_colored_polygon(mid_dune, Color("#1D192F"))

	# Foreground desert ridge & Bedouin tent silhouette (left)
	var fore_dune := PackedVector2Array([
		Vector2(0.0, sz.y),
		Vector2(0.0, sz.y * 0.85),
		Vector2(sz.x * 0.30, sz.y * 0.82),
		Vector2(sz.x * 0.64, sz.y * 0.87),
		Vector2(sz.x, sz.y * 0.81),
		Vector2(sz.x, sz.y),
	])
	draw_colored_polygon(fore_dune, UITokens.NIGHT_DEEP)

	# Bedouin tent (bayt al-sha'r) silhouette on lower left
	var tent := PackedVector2Array([
		Vector2(sz.x * 0.08, sz.y * 0.86),
		Vector2(sz.x * 0.13, sz.y * 0.785),
		Vector2(sz.x * 0.22, sz.y * 0.79),
		Vector2(sz.x * 0.27, sz.y * 0.85),
	])
	draw_colored_polygon(tent, Color("#090B17"))
	draw_circle(Vector2(sz.x * 0.175, sz.y * 0.835), 9.0, Color(UITokens.EMBER, 0.55 + 0.2 * sin(_elapsed * 3.1)))


## Plain text-list item (plan §6.1): no box; warm sand at 70%, pale gold + ember mark on focus.
func _style_menu_button(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for slot: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		btn.add_theme_stylebox_override(slot, empty)
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_constant_override("h_separation", 14)
	btn.add_theme_font_size_override("font_size", UITokens.SIZE_BODY_L)
	btn.set_meta("font_role", ArabicFontSetup.ROLE_BODY)
	btn.add_theme_color_override("font_color", Color(UITokens.WARM_SAND, 0.7))
	btn.add_theme_color_override("font_focus_color", UITokens.PALE_GOLD)
	btn.add_theme_color_override("font_hover_color", UITokens.PALE_GOLD)
	btn.add_theme_color_override("font_pressed_color", UITokens.PALE_GOLD)
	btn.add_theme_color_override("font_hover_pressed_color", UITokens.PALE_GOLD)
	if ResourceLoader.exists(FOCUS_EMBER_PATH):
		btn.icon = load(FOCUS_EMBER_PATH) as Texture2D
		btn.add_theme_color_override("icon_normal_color", Color(1.0, 1.0, 1.0, 0.0))
		btn.add_theme_color_override("icon_hover_color", Color(1.0, 1.0, 1.0, 0.0))
		btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
		btn.add_theme_color_override("icon_focus_color", Color.WHITE)
		btn.add_theme_color_override("icon_hover_pressed_color", Color.WHITE)
	btn.mouse_entered.connect(btn.grab_focus)


func _style_language_button(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for slot: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		btn.add_theme_stylebox_override(slot, empty)
	btn.flat = true
	btn.add_theme_font_size_override("font_size", UITokens.SIZE_CAPTION)
	btn.set_meta("font_role", ArabicFontSetup.ROLE_BODY)
	btn.add_theme_color_override("font_focus_color", UITokens.PALE_GOLD)
	btn.add_theme_color_override("font_hover_color", UITokens.PALE_GOLD)


## Gentle ember flicker on the focused item (2-4 Hz noise, about 8% brightness).
func _update_focus_flicker() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused == null or not (focused is Button) or not _menu_buttons.has(focused as Button):
		return
	var level: float = 1.0
	if not SettingsManager.reduce_motion:
		level = 0.92 + 0.08 * (0.5 + 0.5 * sin(_elapsed * 17.0) * sin(_elapsed * 5.3))
	(focused as Button).add_theme_color_override("icon_focus_color", Color(level, level, level, 1.0))


func refresh_state() -> void:
	var has_save_file: bool = SaveManager.has_save()
	continue_button.disabled = not has_save_file
	# No disabled items in the title list (plan §6.1): Continue exists only when a save exists.
	continue_button.visible = has_save_file
	_update_language_button_highlights()
	if visible:
		if has_save_file:
			continue_button.grab_focus()
		else:
			new_game_button.grab_focus()


func refresh_texts() -> void:
	title_label.text = tr("GAME_TITLE")
	subtitle_label.text = tr("GAME_SUBTITLE")
	tagline_label.text = tr("UI_TITLE_TAGLINE")
	new_game_button.text = tr("UI_NEW_GAME")
	continue_button.text = tr("UI_CONTINUE")
	settings_button.text = tr("UI_SETTINGS")
	language_label.text = tr("UI_LANGUAGE")
	lang_ar_button.text = tr("UI_LANG_AR")
	lang_en_button.text = tr("UI_LANG_EN")
	quit_button.text = tr("UI_QUIT")
	_update_language_button_highlights()


func _update_language_button_highlights() -> void:
	var is_ar: bool = ArabicFontSetup.is_rtl_locale()
	lang_ar_button.add_theme_color_override("font_color", UITokens.PALE_GOLD if is_ar else Color(UITokens.WARM_SAND, 0.55))
	lang_en_button.add_theme_color_override("font_color", UITokens.PALE_GOLD if not is_ar else Color(UITokens.WARM_SAND, 0.55))


func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	new_game_pressed.emit()


func _on_continue_pressed() -> void:
	if not SaveManager.has_save():
		return
	AudioManager.play_sfx("ui_click")
	continue_pressed.emit()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	settings_pressed.emit()


func _on_quit_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	quit_pressed.emit()


func _on_select_arabic() -> void:
	AudioManager.play_sfx("ui_hover")
	SettingsManager.set_locale("ar")


func _on_select_english() -> void:
	AudioManager.play_sfx("ui_hover")
	SettingsManager.set_locale("en")
