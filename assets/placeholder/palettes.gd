class_name ShaalaPalette
extends RefCounted
## Canonical color palette and painterly tint utilities for SHAALA (شعلة).
## Original desert-ruin and Najdi architectural color language:
## high-contrast night-indigo silhouettes against warm dusk ochre, desert red,
## and pale-gold memory luminescence.

# Core Brand & Environment Swatches (canonical contract)
const MUD_BRICK_OCHRE: Color = Color("#C68B59")
const SUNSET_ORANGE: Color = Color("#E07A3C")
const DESERT_RED: Color = Color("#A84432")
const NIGHT_INDIGO: Color = Color("#161B33")
const DEEP_SHADOW: Color = Color("#0D1021")
const PALE_GOLD_ORB: Color = Color("#F6E299")
const FARID_EYE_GREY: Color = Color("#8B95A5")
const FARID_EYE_BLUE: Color = Color("#4A90D9")
const WARM_SAND_LIGHT: Color = Color("#E8C49A")
const GLASS_TEAL: Color = Color("#4F6D7A")

# Extended Painterly Tonal Accents (derived from canonical swatches)
const SHADE_NAJDI_DARK: Color = Color("#6E4930")
const NAJDI_PLASTER_HIGHLIGHT: Color = Color("#D9A87C")
const DUSK_HORIZON_AMBER: Color = Color("#D66838")
const TWILIGHT_INDIGO_MID: Color = Color("#242B4D")
const ORB_CORE_WHITE_GOLD: Color = Color("#FFF8DC")
const PARCHMENT_CREAM: Color = Color("#EFE0BE")
const PARCHMENT_INK: Color = Color("#2A2233")
const SADDLE_CRIMSON: Color = Color("#8C2F2B")
const SADDLE_TRIM_GOLD: Color = Color("#D9B66C")
const CAMEL_OCHRE_SHADOW: Color = Color("#593A28")
const MOTAIB_ARMOR_INDIGO: Color = Color("#1F2640")
const MOTAIB_BRONZE_TRIM: Color = Color("#B5804A")
const ERA_2034_WARM_TINT: Color = Color("#F5D8A8")
const ERA_2054_COOL_TINT: Color = Color("#9BA7C4")
const GREY_EYE_AURA: Color = Color("#7A8BA3")


static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


static func blend_dusk(progress: float) -> Color:
	var t: float = clampf(progress, 0.0, 1.0)
	if t < 0.5:
		return SUNSET_ORANGE.lerp(DESERT_RED, t * 2.0)
	return DESERT_RED.lerp(NIGHT_INDIGO, (t - 0.5) * 2.0)


static func get_era_tint(era: String) -> Color:
	if era == "2034":
		return ERA_2034_WARM_TINT
	return ERA_2054_COOL_TINT


static func get_area_palette(area_id: String) -> Dictionary:
	match area_id:
		"desert_camp":
			return {
				"sky_top": DESERT_RED,
				"sky_horizon": SUNSET_ORANGE,
				"midground": MUD_BRICK_OCHRE,
				"foreground": DEEP_SHADOW,
				"accent": PALE_GOLD_ORB,
				"sand_veil": WARM_SAND_LIGHT,
			}
		"empty_highway":
			return {
				"sky_top": TWILIGHT_INDIGO_MID,
				"sky_horizon": DUSK_HORIZON_AMBER,
				"midground": DESERT_RED,
				"foreground": NIGHT_INDIGO,
				"accent": PALE_GOLD_ORB,
				"sand_veil": MUD_BRICK_OCHRE,
			}
		"empty_riyadh":
			return {
				"sky_top": DEEP_SHADOW,
				"sky_horizon": NIGHT_INDIGO,
				"midground": GLASS_TEAL,
				"foreground": DEEP_SHADOW,
				"accent": PALE_GOLD_ORB,
				"sand_veil": GLASS_TEAL,
			}
		_:
			return {
				"sky_top": NIGHT_INDIGO,
				"sky_horizon": SUNSET_ORANGE,
				"midground": MUD_BRICK_OCHRE,
				"foreground": DEEP_SHADOW,
				"accent": PALE_GOLD_ORB,
				"sand_veil": WARM_SAND_LIGHT,
			}
