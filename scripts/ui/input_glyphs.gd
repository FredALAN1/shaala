class_name InputGlyphs
extends RefCounted
## Input glyph icons from the DROP-002 atlases (docs/VISUAL_HANDOFF.md DROP-002 §6.6).
## 512×512 atlases, 8×8 grid of 64 px cells. Returns null when a key has no drawn glyph,
## so callers fall back to the text keycap from ArabicFontSetup.get_action_key_label().

const KBM_ATLAS_PATH: String = "res://assets/final/ui/input_glyphs_kbm.png"
const PAD_ATLAS_PATH: String = "res://assets/final/ui/input_glyphs_pad.png"
const CELL: int = 64

## OS.get_keycode_string() name -> Vector2i(col, row) in input_glyphs_kbm.png.
const KBM_CELLS: Dictionary = {
	"Up": Vector2i(2, 0), "Down": Vector2i(3, 0), "Left": Vector2i(4, 0), "Right": Vector2i(5, 0),
	"Space": Vector2i(6, 0), "Shift": Vector2i(7, 0),
	"Enter": Vector2i(0, 1), "Tab": Vector2i(1, 1), "Escape": Vector2i(2, 1), "Backspace": Vector2i(3, 1),
	"W": Vector2i(0, 2), "A": Vector2i(1, 2), "S": Vector2i(2, 2), "D": Vector2i(3, 2),
	"E": Vector2i(4, 2), "F": Vector2i(5, 2), "Q": Vector2i(6, 2), "R": Vector2i(7, 2),
	"J": Vector2i(0, 3), "K": Vector2i(1, 3), "L": Vector2i(2, 3), "I": Vector2i(3, 3),
	"Z": Vector2i(4, 3), "X": Vector2i(5, 3), "C": Vector2i(6, 3), "V": Vector2i(7, 3),
	"M": Vector2i(0, 4), "T": Vector2i(1, 4), "1": Vector2i(2, 4), "2": Vector2i(3, 4),
	"3": Vector2i(4, 4), "4": Vector2i(5, 4), "Plus": Vector2i(6, 4), "Minus": Vector2i(7, 4),
}

static var _cache: Dictionary = {}


## Glyph for the first keyboard binding of an action, or null when none is drawn.
static func get_action_glyph(action_name: String) -> Texture2D:
	var key_name: String = ArabicFontSetup.get_action_key_label(action_name)
	return get_key_glyph(key_name)


static func get_key_glyph(key_name: String) -> Texture2D:
	if not KBM_CELLS.has(key_name):
		return null
	if _cache.has(key_name):
		return _cache[key_name] as Texture2D
	if not ResourceLoader.exists(KBM_ATLAS_PATH):
		return null
	var atlas_tex: Texture2D = load(KBM_ATLAS_PATH) as Texture2D
	if atlas_tex == null:
		return null
	var cell: Vector2i = KBM_CELLS[key_name] as Vector2i
	var tex := AtlasTexture.new()
	tex.atlas = atlas_tex
	tex.region = Rect2(float(cell.x * CELL), float(cell.y * CELL), float(CELL), float(CELL))
	_cache[key_name] = tex
	return tex
