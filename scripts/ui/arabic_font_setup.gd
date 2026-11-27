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

## Font roles of the "Notebook & Ember" identity (docs/UI_DESIGN_PLAN.md §3).
## Bundled OFL files in FINAL_FONTS_DIR are matched by lowercase file-name prefix.
const ROLE_DISPLAY: String = "display"
const ROLE_HAND: String = "hand"
const ROLE_BODY: String = "body"
const ROLE_FILE_PREFIXES_AR: Dictionary = {
	"display": ["reem_kufi"],
	"hand": ["aref_ruqaa_regular", "aref_ruqaa"],
	"body": ["readex_pro"],
}
const ROLE_FILE_PREFIXES_EN: Dictionary = {
	"display": ["readex_pro"],
	"hand": ["eb_garamond_italic", "eb_garamond"],
	"body": ["readex_pro"],
}
const ROLE_WEIGHTS: Dictionary = {"display": 600, "hand": 400, "body": 400}
const ROLE_SYSTEM_FALLBACKS: Dictionary = {
	"display": ["Reem Kufi", "Noto Kufi Arabic", "Geeza Pro", "Noto Sans Arabic", "Arial"],
	"hand": ["Aref Ruqaa", "Noto Naskh Arabic", "Amiri", "Geeza Pro", "Noto Sans Arabic", "Arial"],
	"body": ["Readex Pro", "Geeza Pro", "SF Arabic", "Damascus", "Noto Sans Arabic", "Cairo", "Arial"],
}

## Western -> Arabic-Indic digits (decision D3: Arabic-Indic everywhere in `ar`).
const ARABIC_INDIC_DIGITS: String = "٠١٢٣٤٥٦٧٨٩"

static var _cached_font: Font = null
static var _cached_theme: Theme = null
static var _role_fonts: Dictionary = {}
static var _base_default_font_size: int = -1


static func is_rtl_locale(locale: String = "") -> bool:
	var active: String = locale if not locale.is_empty() else TranslationServer.get_locale()
	return active.to_lower().begins_with("ar")


static func get_arabic_font() -> Font:
	if _cached_font == null:
		_cached_font = get_role_font(ROLE_BODY, "ar")
	return _cached_font


## Returns the font for a UI role ("display", "hand", "body") in the given locale.
## Uses the bundled OFL file wrapped in a FontVariation (weight per ROLE_WEIGHTS), with the
## body font and a SystemFont chain as glyph fallbacks. Without bundled files it falls back
## to SystemFont so the game still renders.
static func get_role_font(role: String, locale: String = "") -> Font:
	var rtl: bool = is_rtl_locale(locale)
	var loc: String = "ar" if rtl else "en"
	var cache_key: String = "%s_%s" % [role, loc]
	if _role_fonts.has(cache_key):
		return _role_fonts[cache_key] as Font

	var prefixes_map: Dictionary = ROLE_FILE_PREFIXES_AR if rtl else ROLE_FILE_PREFIXES_EN
	var prefixes: Array = prefixes_map.get(role, []) as Array
	var base: Font = _find_bundled_font(prefixes)
	if base == null and role == ROLE_BODY:
		base = _try_load_bundled_font()

	var system_font := SystemFont.new()
	var fallback_names: Array = ROLE_SYSTEM_FALLBACKS.get(role, SYSTEM_ARABIC_FONTS) as Array
	system_font.font_names = PackedStringArray(fallback_names)
	system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	system_font.multichannel_signed_distance_field = false

	var chain: Array[Font] = []
	if role != ROLE_BODY:
		chain.append(get_role_font(ROLE_BODY, loc))
	if role == ROLE_BODY or base != null:
		var arabic_system := SystemFont.new()
		arabic_system.font_names = PackedStringArray(SYSTEM_ARABIC_FONTS)
		arabic_system.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		chain.append(arabic_system)

	var font: Font = null
	if base == null:
		system_font.fallbacks = chain
		font = system_font
	else:
		var variation := FontVariation.new()
		variation.base_font = base
		var weight: int = int(ROLE_WEIGHTS.get(role, 400))
		if base is FontFile and (base as FontFile).get_supported_variation_list().size() > 0:
			var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
			variation.variation_opentype = {tag: weight}
		chain.append(system_font)
		variation.fallbacks = chain
		font = variation

	_role_fonts[cache_key] = font
	return font


static func _find_bundled_font(prefixes: Array) -> Font:
	if prefixes.is_empty() or not DirAccess.dir_exists_absolute(FINAL_FONTS_DIR):
		return null
	var dir := DirAccess.open(FINAL_FONTS_DIR)
	if dir == null:
		return null
	var names: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			# Exported builds list "x.ttf.import" instead of the source file.
			var source_name: String = file_name.trim_suffix(".import").trim_suffix(".remap")
			var lower: String = source_name.to_lower()
			var is_font: bool = lower.ends_with(".ttf") or lower.ends_with(".otf") or lower.ends_with(".woff2")
			if is_font and not names.has(source_name):
				names.append(source_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for prefix: Variant in prefixes:
		var pre: String = str(prefix)
		for candidate: String in names:
			if candidate.to_lower().begins_with(pre):
				var path: String = FINAL_FONTS_DIR.path_join(candidate)
				if ResourceLoader.exists(path):
					var loaded: Resource = ResourceLoader.load(path)
					if loaded is Font:
						return loaded as Font
	return null


## Converts Western digits (and %) to Arabic-Indic forms in Arabic locales (decision D3).
## Use only on numeric/formatted values, never on key names like "F1".
static func localize_digits(text: String, locale: String = "") -> String:
	if not is_rtl_locale(locale):
		return text
	var out: String = ""
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if code >= 48 and code <= 57:
			out += ARABIC_INDIC_DIGITS[code - 48]
		elif code == 37:
			out += "٪"
		else:
			out += text[i]
	return out


static func format_number(value: int, locale: String = "") -> String:
	return localize_digits(str(value), locale)


static func format_percent(ratio: float, locale: String = "") -> String:
	var pct: String = localize_digits(str(int(round(ratio * 100.0))), locale)
	if is_rtl_locale(locale):
		return "%s٪" % pct
	return "%s%%" % pct


static func get_text_scale() -> float:
	var settings: Node = null
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		settings = (loop as SceneTree).root.get_node_or_null("SettingsManager")
	if settings != null and "text_scale" in settings:
		return clampf(float(settings.get("text_scale")), 1.0, 1.5)
	return 1.0


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
			var source_name: String = file_name.trim_suffix(".import").trim_suffix(".remap")
			var lower: String = source_name.to_lower()
			var is_font: bool = lower.ends_with(".ttf") or lower.ends_with(".otf") or lower.ends_with(".woff2")
			if is_font and not candidates.has(source_name):
				candidates.append(source_name)
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
	_base_default_font_size = theme_res.default_font_size if theme_res.default_font_size > 0 else 28
	_cached_theme = theme_res
	return _cached_theme


static func apply_to_control(root: Control, locale: String = "") -> void:
	if root == null:
		return
	var rtl: bool = is_rtl_locale(locale)
	var scale: float = get_text_scale()
	var theme_res: Theme = get_shaala_theme()
	theme_res.default_font_size = int(round(float(_base_default_font_size) * scale))
	root.theme = theme_res
	root.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	_apply_recursive(root, rtl, scale)


## Re-applies direction, role fonts and text scale to a subtree without replacing its theme
## (for content built at runtime inside a surface that has its own theme, e.g. the notebook paper).
static func apply_typography_tree(root: Control, locale: String = "") -> void:
	if root == null:
		return
	_apply_recursive(root, is_rtl_locale(locale), get_text_scale())


## Applies role font and text scale to one control. Controls opt into a role with
## set_meta("font_role", "display" | "hand" | "body"); explicit font sizes are scaled
## from the size first seen (stored in meta "base_font_size").
static func _apply_typography(ctrl: Control, rtl: bool, scale: float) -> void:
	var font_slot: String = "normal_font" if ctrl is RichTextLabel else "font"
	var size_slot: String = "normal_font_size" if ctrl is RichTextLabel else "font_size"
	var size_scale: float = scale
	if ctrl.has_meta("font_role"):
		var role: String = str(ctrl.get_meta("font_role"))
		ctrl.add_theme_font_override(font_slot, get_role_font(role, "ar" if rtl else "en"))
		# Role sizes are Arabic sizes; Latin glyphs read larger at the same px (plan §3.1).
		if not rtl:
			size_scale *= UITokens.EN_OPTICAL_SCALE
	if ctrl.has_theme_font_size_override(size_slot) or ctrl.has_meta("base_font_size"):
		if not ctrl.has_meta("base_font_size"):
			ctrl.set_meta("base_font_size", ctrl.get_theme_font_size(size_slot))
		var base: int = int(ctrl.get_meta("base_font_size"))
		ctrl.add_theme_font_size_override(size_slot, int(round(float(base) * size_scale)))


static func _apply_recursive(node: Node, rtl: bool, scale: float = 1.0) -> void:
	if node is Control:
		var ctrl := node as Control
		if ctrl is Label or ctrl is RichTextLabel or ctrl is Button:
			_apply_typography(ctrl, rtl, scale)
		if ctrl.has_meta("keep_ltr") and bool(ctrl.get_meta("keep_ltr")):
			ctrl.layout_direction = Control.LAYOUT_DIRECTION_LTR
		elif ctrl.get_parent() is CanvasLayer or ctrl.get_parent() == null:
			ctrl.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR

		if ctrl is Label:
			var lbl := ctrl as Label
			lbl.text_direction = Control.TEXT_DIRECTION_RTL if rtl else Control.TEXT_DIRECTION_LTR
			lbl.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_DEFAULT
			if lbl.has_meta("align_reading_edge") and bool(lbl.get_meta("align_reading_edge")):
				# Godot mirrors LEFT/RIGHT under an RTL layout, so LEFT is always the reading start.
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		_apply_recursive(child, rtl, scale)


static func isolate_ltr(value: String) -> String:
	return "%s%s%s" % [LRI, value, PDI]


static func isolate_rtl(value: String) -> String:
	return "%s%s%s" % [RLI, value, PDI]


static func isolate_auto(value: String) -> String:
	return "%s%s%s" % [FSI, value, PDI]


static func format_bidi_pair(label_text: String, ltr_value: String, separator: String = ": ") -> String:
	var isolated_val: String = isolate_ltr(localize_digits(ltr_value))
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
