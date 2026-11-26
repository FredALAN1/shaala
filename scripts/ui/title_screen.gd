class_name TitleScreen
extends Control
## Atmospheric Arabic-first title screen for SHAALA (شعلة).
## Renders a painterly desert-and-ruined-Riyadh silhouette canvas behind translucent night-indigo controls.

signal new_game_pressed
signal continue_pressed
signal settings_pressed
signal quit_pressed


@onready var title_label: Label = $CenterContainer/MainCard/VBox/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/MainCard/VBox/SubtitleLabel
@onready var tagline_label: Label = $CenterContainer/MainCard/VBox/TaglineLabel
@onready var new_game_button: Button = $CenterContainer/MainCard/VBox/ButtonsBox/NewGameButton
@onready var continue_button: Button = $CenterContainer/MainCard/VBox/ButtonsBox/ContinueButton
@onready var settings_button: Button = $CenterContainer/MainCard/VBox/ButtonsBox/SettingsButton
@onready var language_label: Label = $CenterContainer/MainCard/VBox/LanguageRow/LanguageLabel
@onready var lang_ar_button: Button = $CenterContainer/MainCard/VBox/LanguageRow/LangArButton
@onready var lang_en_button: Button = $CenterContainer/MainCard/VBox/LanguageRow/LangEnButton
@onready var quit_button: Button = $CenterContainer/MainCard/VBox/ButtonsBox/QuitButton

const AMBIENT_REDRAW_HZ: float = 20.0

var _elapsed: float = 0.0
var _redraw_accum: float = 0.0


func _ready() -> void:
	title_label.set_meta("font_role", ArabicFontSetup.ROLE_DISPLAY)
	subtitle_label.set_meta("font_role", ArabicFontSetup.ROLE_HAND)
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
	var band_h: float = sz.y / float(sky_bands.size())
	for i: int in range(sky_bands.size()):
		draw_rect(Rect2(0.0, float(i) * band_h, sz.x, band_h + 2.0), sky_bands[i])

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
	var towers: Array[Rect2] = [
		Rect2(sz.x * 0.12, horizon_y - 190.0, 44.0, 210.0),
		Rect2(sz.x * 0.16, horizon_y - 260.0, 56.0, 280.0),
		Rect2(sz.x * 0.21, horizon_y - 150.0, 38.0, 170.0),
		Rect2(sz.x * 0.74, horizon_y - 210.0, 46.0, 230.0),
		Rect2(sz.x * 0.79, horizon_y - 310.0, 62.0, 330.0),
		Rect2(sz.x * 0.85, horizon_y - 175.0, 42.0, 195.0),
	]
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
	lang_ar_button.modulate = UITokens.PALE_GOLD if is_ar else UITokens.WARM_SAND
	lang_en_button.modulate = UITokens.PALE_GOLD if not is_ar else UITokens.WARM_SAND


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
