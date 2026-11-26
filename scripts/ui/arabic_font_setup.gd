class_name ArabicFontSetup
extends RefCounted
## Configures Arabic-first typography, Godot 4 Advanced Text Server BiDi overrides,
## and dynamic RTL/LTR layout mirroring across the SHAALA UI tree.

const FINAL_FONTS_DIR: String = "res://assets/final/fonts"
const BASE_THEME_PATH: String = "res://assets/placeholder/theme/shaala_theme.tres"

const SYSTEM_ARABIC_FONTS: Array = [
	"Geeza Pro",
	"SF Arabic",
	"Damascus",
	"Noto Sans Arabic",
	"Cairo",
	"Amiri",
	"Arial",
]

## Unicode Bidirectional Isolate controls (UAX #9) so mixed Arabic + LTR tokens
## (HP ratios like 5/5, keycaps like [Space], percentages, coordinates) never garble.
const LRI: String = "\u2066"
const RLI: String = "\u2067"
const FSI: String = "\u2068"
const PDI: String = "\u2069"

static var _cached_font: Font = null
static var _cached_theme: Theme = null


static func is_rtl_locale(locale: String = "") -> bool:
	var active: String = locale if not locale.is_empty() else TranslationServer.get_locale()
	return active.to_lower().begins_with("ar")


static func get_arabic_font() -> Font:
	if _cached_font != null:
		return _cached_font

	var fallback_system_font := SystemFont.new()
	fallback_system_font.font_names = PackedStringArray(SYSTEM_ARABIC_FONTS)
	fallback_system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	fallback_system_font.multichannel_signed_distance_field = false

	var bundled_font: Font = _try_load_bundled_font()
	if bundled_font != null:
		if bundled_font is FontFile:
			var font_file := bundled_font as FontFile
			var fallbacks: Array[Font] = []
			fallbacks.append(fallback_system_font)
			font_file.fallbacks = fallbacks
		_cached_font = bundled_font
		return _cached_font

	_cached_font = fallback_system_font
	return _cached_font


static func _try_load_bundled_font() -> Font:
	if not DirAccess.dir_exists_absolute(FINAL_FONTS_DIR):
		return null
	var dir := DirAccess.open(FINAL_FONTS_DIR)
	if dir == null:
		return null

	var candidates: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var lower: String = file_name.to_lower()
			if lower.ends_with(".ttf") or lower.ends_with(".otf") or lower.ends_with(".woff2"):
				candidates.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	candidates.sort()
	for candidate: String in candidates:
		var path: String = FINAL_FONTS_DIR.path_join(candidate)
		if ResourceLoader.exists(path):
			var loaded: Resource = ResourceLoader.load(path)
			if loaded is Font:
				return loaded as Font
	return null


static func get_shaala_theme() -> Theme:
	if _cached_theme != null:
		return _cached_theme

	var theme_res: Theme = null
	if ResourceLoader.exists(BASE_THEME_PATH):
		var loaded: Resource = ResourceLoader.load(BASE_THEME_PATH)
		if loaded is Theme:
			theme_res = (loaded as Theme).duplicate(false) as Theme
	if theme_res == null:
		theme_res = Theme.new()

	theme_res.default_font = get_arabic_font()
	_cached_theme = theme_res
	return _cached_theme


static func apply_to_control(root: Control, locale: String = "") -> void:
	if root == null:
		return
	var rtl: bool = is_rtl_locale(locale)
	root.theme = get_shaala_theme()
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	_apply_recursive(root, rtl)


static func _apply_recursive(node: Node, rtl: bool) -> void:
	if node is Control:
		var ctrl := node as Control
		if ctrl.has_meta("keep_ltr") and bool(ctrl.get_meta("keep_ltr")):
			ctrl.layout_direction = Control.LAYOUT_DIRECTION_LTR
		elif ctrl.get_parent() is CanvasLayer or ctrl.get_parent() == null:
			ctrl.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR

		if ctrl is Label:
			var lbl := ctrl as Label
			lbl.text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
			lbl.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_DEFAULT
			if lbl.has_meta("align_reading_edge") and bool(lbl.get_meta("align_reading_edge")):
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
		elif ctrl is RichTextLabel:
			var rtl_label := ctrl as RichTextLabel
			rtl_label.text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
			rtl_label.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_DEFAULT
		elif ctrl is Button:
			var btn := ctrl as Button
			btn.text_direction = Control.TEXT_DIRECTION_AUTO
		elif ctrl is LineEdit:
			var edit := ctrl as LineEdit
			edit.text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
			edit.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_DEFAULT

	for child: Node in node.get_children():
		_apply_recursive(child, rtl)


static func isolate_ltr(value: String) -> String:
	return "%s%s%s" % [LRI, value, PDI]


static func isolate_rtl(value: String) -> String:
	return "%s%s%s" % [RLI, value, PDI]


static func isolate_auto(value: String) -> String:
	return "%s%s%s" % [FSI, value, PDI]


static func format_bidi_pair(label_text: String, ltr_value: String, separator: String = ": ") -> String:
	var isolated_val: String = isolate_ltr(ltr_value)
	if is_rtl_locale():
		return "%s%s%s" % [isolate_rtl(label_text), separator, isolated_val]
	return "%s%s%s" % [isolate_ltr(label_text), separator, isolated_val]


static func format_key_prompt(key_display: String, prompt_text: String) -> String:
	var key_token: String = isolate_ltr("[%s]" % key_display)
	if is_rtl_locale():
		return "%s  %s" % [key_token, isolate_rtl(prompt_text)]
	return "%s  %s" % [key_token, isolate_ltr(prompt_text)]


static func get_action_key_label(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "?"
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for ev: InputEvent in events:
		if ev is InputEventKey:
			var key_ev := ev as InputEventKey
			var code: Key = key_ev.physical_keycode if key_ev.physical_keycode != KEY_NONE else key_ev.keycode
			if code != KEY_NONE:
				return OS.get_keycode_string(code)
	return "?"
