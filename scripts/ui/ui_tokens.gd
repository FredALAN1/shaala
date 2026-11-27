class_name UITokens
extends RefCounted
## Single source of UI design tokens for the "Notebook & Ember" identity
## (docs/UI_DESIGN_PLAN.md §3–§7, DROP-002 §6.2).
## Two surfaces, two token sets: DARK_* for text on night scrims, PAPER_* / INK_* for notebook paper.
## Gold / ember / desert red are dark-surface colours only; on paper use the INK_* accents.

# --- Dark surface (world, scrims, HUD) ---
const NIGHT_DEEP: Color = Color("#0D1021")
const NIGHT_INDIGO: Color = Color("#161B33")
const WARM_SAND: Color = Color("#E8C49A")          # default text on dark
const PALE_GOLD: Color = Color("#F6E299")          # memory & focus only
const EMBER: Color = Color("#E07A3C")              # life, flame, focus mark
const DESERT_RED: Color = Color("#A84432")         # danger / destructive only
const MUD_BRICK: Color = Color("#C68B59")
const GREY_EYE: Color = Color("#8B95A5")           # Grey Eye state, disabled
const GLASS_TEAL: Color = Color("#4F6D7A")         # 2034 skin only
const SKY_BLUE: Color = Color("#4A90D9")           # 2034 skin only
const HP_ASH_FILL: Color = Color("#2B3144")
const HP_ASH_STROKE: Color = Color("#8B95A5")
const SCRIM: Color = Color(0.0509804, 0.0627451, 0.129412, 0.78)

# --- Paper surface (pause notebook, journal, map, settings, confirm slip) ---
const PAPER_ASH: Color = Color("#E4D7C0")
const PAPER_SCRAP: Color = Color("#EBE0CA")
const PAPER_SHADOW: Color = Color("#C5B297")
const PAPER_EDGE_BURN: Color = Color("#9E8366")
const INK_BROWN: Color = Color("#241914")
const INK_MUTED: Color = Color("#5C493E")
const INK_RULE: Color = Color("#B5A186")
const INK_FOCUS_PAPER: Color = Color("#8C2D1E")
const INK_EMBER_ACCENT: Color = Color("#B84E24")
const INK_DESTRUCTIVE_PAPER: Color = Color("#8F2E22")

# --- Type scale at 1080p, Arabic sizes (plan §3.1). English uses ~0.88x. ---
const SIZE_DISPLAY_XL: int = 96
const SIZE_DISPLAY_L: int = 64
const SIZE_HAND_L: int = 52
const SIZE_HAND_M: int = 38
const SIZE_BODY_L: int = 36
const SIZE_BODY_M: int = 30
const SIZE_CAPTION: int = 24
const EN_OPTICAL_SCALE: float = 0.88

# --- Motion (plan §7), seconds ---
const FADE_IN: float = 0.25
const FADE_OUT: float = 0.5
const SLIDE: float = 0.3
const WRITE_ON_SHORT: float = 0.5
const WRITE_ON_LONG: float = 1.2
const TIER_WHISPER_HOLD: float = 1.5
const AREA_BANNER_HOLD: float = 2.5

# --- HUD behaviour (plan §6.2 + Gemini adjustment #3) ---
const HUD_IDLE_FADE_DELAY: float = 4.0
const HUD_WOUNDED_FLOOR_ALPHA: float = 0.30


## Optical size for the active locale: Latin glyphs read larger than Arabic at the same px size.
static func optical_size(arabic_px: int, locale: String = "") -> int:
	if ArabicFontSetup.is_rtl_locale(locale):
		return arabic_px
	return int(round(float(arabic_px) * EN_OPTICAL_SCALE))
