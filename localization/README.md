# SHAALA (شعلة) — Localization, Arabic Shaping & RTL Guide

## Overview

**SHAALA** is built **Arabic-first** (Modern Standard Arabic / الفصحى for all narrative, vignettes, dialogue, notebook pages, and UI) with full **English** parity. Zero user-facing strings are hardcoded in `.gd` or `.tscn` files — every label, button, prompt, boss title, area banner, vignette, and journal entry resolves through `tr("KEY")` backed by `localization/strings.csv`.

## File Layout

- `localization/strings.csv`: UTF-8 (no BOM) RFC 4180 CSV with header `keys,ar,en`.
  - All prose is stored on single lines so both Godot's native CSV importer and the runtime `Translation` loader in `SettingsManager` parse it identically even on cold headless launches before `.import` generation.
- `scripts/ui/arabic_font_setup.gd` (`ArabicFontSetup`):
  - Loads a bundled OFL Arabic `.ttf` / `.otf` font from `res://assets/final/fonts/` when present (e.g., `Cairo-Regular.ttf`, `Amiri-Regular.ttf`, `NotoSansArabic-Regular.ttf`, `Tajawal-Regular.ttf`).
  - Falls back cleanly to a `SystemFont` configured with `["Geeza Pro", "SF Arabic", "Damascus", "Noto Sans Arabic", "Cairo", "Amiri", "Arial"]` so connected Arabic glyphs shape correctly out-of-the-box on macOS, Windows, and Linux via Godot 4's Advanced Text Server (HarfBuzz + ICU BiDi).
- `assets/placeholder/theme/shaala_theme.tres`:
  - Shared painterly minimal theme (night indigo `#161B33CC` panels, pale gold `#F6E299` accents, mud-brick ochre `#C68B59` highlights, desert red `#A84432` embers).

## RTL & BiDi Architecture

1. **Dynamic Layout Direction**:
   - On startup and on every `EventBus.locale_changed(locale)` signal, `ArabicFontSetup.apply_to_tree(root, locale)` switches `Control.layout_direction` between `LAYOUT_DIRECTION_RTL` (for `ar*` locales) and `LAYOUT_DIRECTION_LTR` (for `en*` locales) across `ui_root` and all active overlays.
   - `Label` and `RichTextLabel` nodes receive explicit `text_direction` (`TEXT_DIRECTION_RTL` / `TEXT_DIRECTION_LTR` or `TEXT_DIRECTION_AUTO`) plus matching horizontal alignment so Arabic prose stays cleanly right-aligned and English stays left-aligned.
2. **Unicode BiDi Isolates for Mixed Strings**:
   - Whenever Arabic text is combined with LTR tokens such as keycaps (`[Space]`, `[E]`), HP fractions (`5/5`), percentages (`75%`), or room numbers, `ArabicFontSetup` wraps embedded LTR tokens with Unicode Left-to-Right Isolates (`\u2066` LRI ... `\u2069` PDI) and uses `Control.STRUCTURED_TEXT_BIDI_OVERRIDE` where needed so punctuation and numbers never scramble.
3. **Runtime Switching**:
   - Changing language from either the Title Screen quick-toggle or the Pause/Settings menu calls `SettingsManager.set_locale("ar" | "en")`, immediately updating every mounted UI screen without restarting the scene.

## Adding New Strings or Languages

1. Add a new key row to `localization/strings.csv` following the naming prefixes:
   - `UI_*`: menus, HUD, settings, map, notebook
   - `PROMPT_*` / `TUT_*`: world prompts and tutorial signs
   - `AREA_*`: area & room title banners
   - `ABILITY_*_NAME` / `ABILITY_*_DESC`: ability unlocks and descriptions
   - `SPEAKER_*` / `BOSS_*`: speaker headers and boss banners
   - `DLG_*`: dialogue lines
   - `VIG_*`: Memory Orb vignettes
   - `PAGE_*_TITLE` / `PAGE_*_BODY`: Torn Notebook pages
2. Never hardcode display text in scripts or `.tscn` files; set placeholder or empty text in `.tscn` and populate via `tr("KEY")` in `_refresh_texts()` connected to `EventBus.locale_changed`.
3. To swap in a final custom Arabic typeface, drop an OFL `.ttf` or `.otf` font into `res://assets/final/fonts/` — `ArabicFontSetup` detects and prioritizes it automatically.

## Narrative & Content Guidelines

- Use dignified, poetic Modern Standard Arabic (الفصحى) throughout story and UI.
- Preserve silence, memory, and grief with restraint — never graphic violence.
- Treat Saudi/Najdi culture, heritage, and spiritual elements with accuracy and respect.
- Leave the three intentional mysteries unresolved across M1–M4: the fate of the children and the uncle after the attack, who sits upon the throne, and the identity of the man with the coffee cup.
