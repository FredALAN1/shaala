# SHAALA (شعلة) — UI Design Plan: "Notebook & Ember" (دفتر وجمرة)

- **Status:** `PROPOSED`. P0 style frames delivered by Gemini (`docs/ui_style_frames/`); Gemini's adjustments 1–5 (DROP-002 §6.4) are folded in below. Awaiting Fred's sign-off on §10.
- **Date:** 2026-11-26
- **Owners:** Visual direction & ornaments: **Gemini** (Drop `DROP-002` in `docs/VISUAL_HANDOFF.md`). Scenes, scripts, shaders, theme, RTL wiring: **Claude Opus**.
- **Scope:** Every player-facing interface: title, HUD, prompts, dialogue, memory vignettes, pause, notebook, map, settings, confirm dialogs, save feedback, death/respawn, room transitions, and the M2 Time Shift / Grey Eye states.
- **Audit screenshots (current M1 UI, rendered in Godot 4.3 at 1920×1080):** `docs/ui_audit/*.png`

---

## 1. Audit — Why the Current UI Reads as Generic

The M1 UI works (RTL, localization, focus, rebinding all function), but visually every screen is built from the same template, and nothing in it could only belong to this game.

| # | Finding | Where (screenshot) |
| :-: | :--- | :--- |
| A1 | **One template for everything:** dark indigo rounded rectangle + thin gold border + soft shadow, used for the title card, HUD panel, era badge, pause, map, vignette and prompt pill. | all |
| A2 | **Centered stack of identical pill buttons.** Primary action (New Game), navigation tabs (Map / Notebook / Settings) and a destructive action (Save & Quit) look exactly the same. | `01`, `04` |
| A3 | **One typeface, one weight.** The system Noto Sans Arabic Bold is used for the logo, titles, buttons and body. There is no typographic hierarchy and no voice. | all |
| A4 | **The title card hides the world.** The painted skyline is covered by a box; the "orb" is 4 flat concentric circles; the sky is 6 hard bands. | `01` |
| A5 | **HUD reads like a debug panel:** `العافية: 5/5`, `طاقة الشعلة: 0/100`, `خنجر الجمر — طور ١` as text labels inside a box. Numbers dominate; the flame pips are generic leaf shapes. | `03` |
| A6 | **Mixed digit systems** in the same screen: `5/5`, `0/100`, `17% (1/6)` use Western digits while `٢٠٥٤` and `طور ١` use Arabic-Indic digits. | `03`, `05` |
| A7 | **Em-dash as the default separator** in copy (`٢٠٥٤ — الأطلال`, `Riyadh 2054 — Silence After the Beam`, tier names). Hierarchy is done with punctuation instead of type. | `01`, `03` |
| A8 | **The memory vignette — the emotional peak of the game — is a dialog box** at the bottom of the screen with `[E] اضغط للمتابعة` and `1 / 3`. | `06` |
| A9 | **Map is graph paper with rectangles**; legend is coloured squares; a link line runs to nowhere. Nothing says "Riyadh" or "memory". | `05` |
| A10 | **Bracket keycaps** (`[E]`) as text instead of input glyphs; prompt pill is another box. | `06` |
| A11 | **Disabled "Continue"** is shown greyed when there is no save, adding noise to a 4-item menu. | `01` |
| A12 | **Idle cost:** `title_screen.gd` and `vignette_player.gd` call `queue_redraw()` every frame to animate flat circles (CPU/GPU work while the player reads). | code |

---

## 2. Concept — "Notebook & Ember" (دفتر وجمرة)

Farid has lost his memory. What he has is **a torn notebook** and **an ember**. The interface is built from exactly those two things, plus the city he is walking through.

- **The notebook** = everything Farid *knows*: pause, journal, map, settings, saved progress. Ink on worn paper, Ruqʿah handwriting (the everyday hand a Saudi father would actually write in), torn edges, missing pages.
- **The ember** = everything Farid *is right now*: health, flame resource, focus/selection, interaction. Warm light on darkness, never a box.
- **The city** = the era. In **2054** the UI is ink, ash and paper. In **2034** (M2 Time Shift) the UI becomes the clean, lit wayfinding of a living city (original signage style: backlit glass, crisp Kufi, cool light). The interface itself remembers.

### 2.1 Five Rules (use these to judge every screen)
1. **Memory, not dashboard.** Show state as things (embers, ink, woven strips), not numbers in boxes. Numbers only on demand (accessibility toggle).
2. **No floating boxes.** Text sits on the world with a soft scrim, or on paper. A framed panel is only allowed when it *is* an object (a notebook page, a torn slip, a stele).
3. **Najd in the structure, not as stickers.** Each Najdi motif has one job (§5). No ornament that does not carry information or structure.
4. **The flame is the cursor.** Focus and selection are shown by an ember mark and warm text, not by a highlighted rectangle.
5. **Silence is a feature.** The HUD fades out when nothing is happening. Memory moments get the whole screen and slow time.

---

## 3. Typography

All fonts are **SIL OFL**, bundled under `assets/final/fonts/` (never system fonts in the shipped build). Three roles only.

| Role | Arabic (primary) | English pairing | Used for | Why |
| :--- | :--- | :--- | :--- | :--- |
| **Display** (عناوين) | **Reem Kufi** (variable, 400–700) | Reem Kufi Latin if coverage passes, else **Readex Pro** SemiBold, tracking +4% | Area titles, boss names, ability names, menu headings, 2034 signage | Geometric Kufi echoes mud-brick geometry and modern Riyadh signage; reads at large sizes. |
| **Hand** (خط اليد) | **Aref Ruqaa** (Regular / Bold) | **EB Garamond Italic** | Notebook pages, memory vignette lines, map labels, save-slot names | Ruqʿah is the real everyday handwriting of the region: it is Farid's voice. |
| **UI / Body** (النص) | **Readex Pro** (variable, 300–600) | Readex Pro (same family) | Menus, settings, dialogue, prompts, toasts, numbers | Clear at small sizes, one family for both scripts, harmonised Arabic + Latin metrics. |

**Logotype** `شعلة`: see decision D2 (§10). Recommended: a hand-lettered logotype by Gemini (brush/reed-pen, the ة/ـلة forming a flame), delivered as an image *only* for the title logo, with `GAME_TITLE` still used for accessibility/window title.

### 3.1 Type scale (1080p reference, Arabic sizes; English uses ~0.88× for matching optical size)
| Token | Size | Font | Use |
| :--- | :---: | :--- | :--- |
| `type_logo` | 180–220 | logotype | Title screen only |
| `type_display_xl` | 96 | Reem Kufi 600 | Area banner, ability name in vignette |
| `type_display_l` | 64 | Reem Kufi 500 | Boss name, screen headings |
| `type_hand_l` | 52 | Aref Ruqaa | Vignette lines |
| `type_hand_m` | 38 | Aref Ruqaa | Notebook page body, map labels |
| `type_body_l` | 36 | Readex Pro 500 | Menu items, dialogue |
| `type_body_m` | 30 | Readex Pro 400 | Settings rows, prompts, toasts |
| `type_caption` | 24 | Readex Pro 400 | Hints, legend (minimum size anywhere) |

Rules: Arabic line-height 1.6–1.75 (Aref Ruqaa 1.95–2.0, with ≥ 14 px clearance under Readex captions; at `text_scale ≥ 125%` Journal body falls back to Readex Pro); never apply letter-spacing to Arabic; no kashida stretching except in the logotype; never use all-caps English except the 2034 signage style.

### 3.2 Numerals (see decision D3)
One digit system per locale, everywhere. Recommended: **Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) in `ar`**, Western in `en`. Tech will add a single `ArabicFontSetup.localize_digits(text)` helper so code never formats numbers ad hoc.

---

## 4. Colour (built on the existing `ShaalaPalette`; one meaning per colour)

| Role | Swatch | Meaning (only this) |
| :--- | :--- | :--- |
| Ink / Night | `#0D1021`, `#161B33` | Scrims and gradients behind text. Never a solid box fill. |
| Paper | **new** `paper_ash` ≈ `#E9D8B4` + `paper_shadow` ≈ `#C9B08A` (Gemini to finalise) | Notebook surfaces (pause, journal, map, settings, confirm slips). |
| Ink on paper | **new** `ink_brown` ≈ `#2B1D16` | Text and lines on paper (contrast ≥ 7:1 on `paper_ash`). |
| Warm sand | `#E8C49A` | Default text on dark. |
| Pale gold | `#F6E299` | **Memory and focus only:** focused item, memory orbs, vignette light. |
| Ember | `#E07A3C` | Life and flame: HP embers, flame meter, focus mark. |
| Desert red | `#A84432` | Danger only: damage flash, boss bar, destructive confirm. |
| Grey eye | `#8B95A5` | Grey Eye vision state (M2), disabled. |
| 2034 glass | `#4F6D7A`, `#4A90D9`, `#9BA7C4` + white | 2034 era UI skin only. |

**Two surfaces, two token sets** (accepted from Gemini, DROP-002 §6.2/§6.4): pale gold / ember / desert red are for dark surfaces only. On paper use `INK_FOCUS_PAPER` `#8C2D1E` (focus), `INK_EMBER_ACCENT` `#B84E24`, `INK_DESTRUCTIVE_PAPER` `#8F2E22`; paper is `PAPER_ASH` `#E4D7C0`, ink `INK_BROWN` `#241914`.

Text contrast: body ≥ 4.5:1 against its scrim/paper; captions ≥ 4.5:1; focus state must also change shape (ember mark), not colour alone.

---

## 5. Najdi Motif System (each motif has one job)

| Motif | Job in the UI | Notes |
| :--- | :--- | :--- |
| **Furjat** (فرجات — triangular wall vents) | **Dividers and bullets.** A row of 3–5 small triangles replaces horizontal rules and em-dashes. Filled ▲ / empty △ = toggle on/off. | Up-pointing triangles, carved look, not glossy. |
| **Shurfat** (شرفات — stepped crenellation) | **Top edge of major frames**: boss bar, notebook spine top, area banner underline end-caps. | Use sparingly: one per screen max. |
| **Sadu** (السدو — Bedouin weaving) | **Meters.** The flame resource bar and settings sliders are woven Sadu strips that fill. Pattern density rises with dagger tier. | Must read at 12–16 px tall; 9-slice/tiling-safe. |
| **Najdi door** (الباب النجدي) | **Save slots / chapter cards** (M3+): each save is a painted door panel. | Optional, later milestone. |
| **Mud-brick stele / shrine** | Map icon for shrines; save-confirmation mark. | Reuse shrine silhouette. |

**Forbidden motifs:** onion domes, Aladdin lamps, generic arabesque/mashrabiya stickers, Moroccan zellige, Persian/Ottoman tilework, crescent-moon decoration, gold filigree borders.

---

## 6. Screen-by-Screen Layout

RTL is the reference; LTR mirrors automatically. "Start edge" = right in Arabic, left in English.

### 6.1 Title Screen
- **No card.** Full painted scene (camp at dusk, Riyadh far on the horizon, Amira resting, tent lantern) fills the screen.
- **Logotype** large on the start-edge third, vertically ~35%. Subtitle in Aref Ruqaa below it, smaller, warm sand.
- **Menu** = plain text list under the logo, start-aligned, Readex Pro 36: `متابعة الرحلة` (only if a save exists), `بداية جديدة`, `الإعدادات`, `خروج`. Unfocused: warm sand 70%. Focused: pale gold + ember mark on the start side + gentle flicker. No boxes, no disabled items.
- **Language** = small `ع | EN` text toggle in the bottom end-corner.
- **Motion:** lantern flicker, sand drift (existing `sand_wind` shader), one slow orb mote. All shader/AnimationPlayer driven, no per-frame `_draw`.

### 6.2 Gameplay HUD (fades after 4 s without combat/damage/resource change: to 0% only at full HP or in safe areas, otherwise holds a 30% ember-ghost floor; setting to keep it on)
- **Start-top corner, no panel:** 5 **ember teardrops** (HP). Lost HP = cold ash ember (shape changes too, not just colour).
- Under them: the **Sadu flame strip** (~320×16), filling from the start edge (right-to-left in `ar`, mirrored in `en`). Two small furjat notches mark 35 and 70 (dagger tiers). Pattern brightens per tier. When a tier changes, the tier name writes in once (Reem Kufi 30) next to the strip and fades after 1.5 s. No permanent tier label.
- **Numbers hidden by default** (setting "Show numbers" adds `٥/٥` beside HP).
- **Era mark (M2+ only, once Time Shift is unlocked):** small year in the end-top corner, `٢٠٥٤` in hand ink / `٢٠٣٤` in lit signage style. Hidden in M1.
- **Area banner:** centered upper third, Reem Kufi 96, writes on (ink reveal) with a furjat divider beneath; holds 2.5 s; fades. First visit only shows sub-area in Aref Ruqaa beneath.
- **Interaction prompt:** world-space, floating ~24 px above the object: input glyph icon + verb (`استرح`). No pill, soft scrim only.
- **Toasts** ("saved", "page found"): bottom start corner, one line, furjat bullet, fade. Max one at a time.
- **Boss bar:** bottom-centre, long thin desert-red bar with shurfat end-caps; boss name in Reem Kufi 64 above; phase marks as furjat notches. No numbers.

### 6.3 Dialogue (NPCs: boy, Motaib, etc.)
- **Cinematic letterbox:** two thin black bars slide in (top/bottom, 6% height), the world keeps running behind.
- Speaker name: Reem Kufi 30 in the speaker's colour, above the line. Line: Readex Pro 36 on a soft bottom gradient scrim, start-aligned, max 60% width.
- Advance indicator: a small pulsing ember at the end of the line (no `[E] اضغط للمتابعة`, no `1 / 3`).

### 6.4 Memory Vignette (ability unlock) — the emotional peak
- **Full screen, no panel.** World slows to a stop, desaturates and darkens; the orb light expands from the orb's world position to fill the screen in pale gold, then settles to near-black with warm grain.
- The three lines appear **one at a time, centered, in Aref Ruqaa 52**, written on with an ink-reveal (shaping-safe, see §8). Each line replaces the previous one; no counter.
- Final card: ability name in Reem Kufi 96 + the input glyph that uses it, then a quiet fade back to gameplay.
- Optional painted vignette frame (≤ 6 frames, VR-09) behind the text when Gemini provides it.

### 6.5 Pause = the Notebook
- World freezes and fades to a charcoal, blurred still (captured **once** on pause, not every frame).
- **A notebook spread** slides up into view (~1500×900): the start page holds the menu, the end page holds the content of the selected section.
- **Sections are bookmark ribbons** (woven Sadu ribbons, 128 px wide so labels stay horizontal, hanging from the top of the content page; navigation lives only on the ribbons): `الدفتر` (journal), `الخريطة`, `الإعدادات`, `التحكم`. Ribbons are navigation; actions are separate.
- Menu page (handwritten heading, then Readex Pro items): `استئناف`, then a furjat divider, then `حفظ والعودة` in desert red at the bottom (destructive actions are visually different and ask for confirmation).
- Default section on open: last used, otherwise Journal.

### 6.6 Journal (Torn Notebook Pages)
- Collected pages are **pasted-in paper scraps** in Aref Ruqaa; missing pages appear as **torn stubs** along the spine (stub count = missing pages, no `٠ / ٣` text).
- Empty state: one handwritten line on an otherwise blank page.

### 6.7 Map (inside the notebook)
- **Ink map drawn in the notebook**, not graph paper: explored rooms in ink outline with a light wash in the area colour; unexplored-but-known rooms as faint pencil; links as ink strokes.
- Icons (32×32, ink style): shrine stele, boss spire, sealed gate, notebook page, shortcut. Player = small ember that pulses.
- Area names hand-lettered in Aref Ruqaa *as text* (localised), placed by tech.
- Legend: one row of icon + word at the bottom of the page, furjat-separated. Exploration shown as the count of explored rooms in hand script.
- **2034 (M2):** the same map re-skins as a clean transit-style diagram (original design, not a copy of any real metro map).

### 6.8 Settings & Controls (inside the notebook; also reachable from title)
- Rows: label at start edge, control at end edge, 72 px row height, furjat dividers between groups (`اللغة والصوت`, `الشاشة`, `الوصول`).
- Sliders = Sadu strips with an ember knob; toggles = furjat ▲/△; language = `العربية | English` text pair.
- **Live preview:** changing screen shake shakes the notebook briefly; reduce-flash shows the parry ring at the chosen intensity.
- Key rebinding shows input glyphs, not key names in brackets.

### 6.9 Confirm Dialogs
A **torn paper slip** laid over the notebook (≈640×320), question in Readex Pro, two text choices; the safe choice is focused by default; destructive choice in desert red.

### 6.10 Saving, Shrine Rest, Death, Transitions
- **Saving indicator:** a small ember in the end-bottom corner that breathes while writing (never a floppy disk or spinner).
- **Shrine rest:** screen warms for 0.6 s, a pale-gold ring expands from the shrine, toast "استرحتَ عند المزار".
- **Death:** no "Game Over" text. Farid dissolves into embers, screen fades through sand colour, respawn at shrine. (Silent grief rule.)
- **Room transitions:** short sand wipe in the direction of travel (0.25 s) instead of a black fade.

### 6.11 M2 States
- **Time Shift:** a 0.6 s UI cross-fade between skins (ink ↔ lit signage) synchronised with the world shift; era mark flips.
- **Grey Eye:** the HUD desaturates to `#8B95A5` and dims to 40%; hidden things get a thin grey outline; a grey vignette from the left edge of the screen (Farid's grey eye is his left eye).

---

## 7. Motion Language

| Pattern | Use | Timing / easing |
| :--- | :--- | :--- |
| Ink write-on | Area titles, vignette lines, notebook headings | 0.5–1.2 s, ease-out sine |
| Ember flicker | Focus mark, HP embers, save ember | 2–4 Hz noise, ±8% brightness |
| Fade | Everything else | 0.2–0.3 s ease-out in, 0.4–0.6 s ease-in out |
| Slide | Notebook in/out, letterbox bars | 0.3 s ease-out cubic, ≤ 40 px travel |
| Sand wipe | Room transitions, death | 0.25–0.6 s |

**Never:** bouncy/elastic/back easing, scale-pop toasts, confetti/particle bursts on menus, spinning icons, typewriter "click" reveals for Arabic, screen-wide glow pulses.

**Reduce Motion** (new setting, with existing Reduce Flash): replaces write-on and wipes with plain fades, freezes ember flicker, disables letterbox slide.

---

## 8. Technical Plan (Claude Opus)

1. **Font roles:** extend `ArabicFontSetup` from "first font in folder" to a role map (`display`, `hand`, `body`) read from file names (`reem_kufi*`, `aref_ruqaa*`, `readex_pro*`), with SystemFont fallback per role. Expose as Theme type variations (`DisplayXL`, `HandL`, `BodyM` …) in `shaala_theme.tres`.
2. **Tokens:** a single `UITokens` script (colours, sizes, timings) replacing the per-script `COLOR_*` constants in `hud.gd`, `title_screen.gd`, `pause_settings_menu.gd`, `minimap_overlay.gd`, `vignette_player.gd`.
3. **Digits:** `ArabicFontSetup.localize_digits()` used by every formatted number.
4. **Write-on reveal:** `Label.visible_ratio` with `visible_characters_behavior = VC_CHARS_AFTER_SHAPING` (keeps Arabic letters joined while revealing), plus an optional ink-edge shader mask.
5. **Pause blur:** capture the viewport once on pause, blur once into a texture (no per-frame `BackBufferCopy`).
6. **Replace per-frame `_draw()`** in title and vignette with shader/`AnimationPlayer` driven nodes (fixes A12, matches PR #1's power-saving goal).
7. **Input glyphs:** `InputGlyphs` helper mapping actions → keyboard/gamepad icon textures, refreshed when the last-used device changes.
8. **New settings:** `reduce_motion`, `hud_always_visible`, `show_numbers`, `text_scale` (100/125/150%) in `SettingsManager` + `strings.csv` keys.
9. **Copy pass:** remove em-dash separators from `strings.csv` UI keys (split into separate keys where hierarchy is needed), keep both `ar`/`en` non-empty.
10. **Verification:** extend `tools/verify_m1.py` with checks for font roles, no em-dash in `UI_*` keys, no hard-coded colours in `scripts/ui/*.gd`, and digit consistency.

---

## 9. Accessibility & Performance Budget

**Accessibility**
- Text scale 100/125/150%; minimum rendered size 24 px at 100%. Arabic body never below 28 px.
- Contrast ≥ 4.5:1 for all text; focus visible by shape + colour; HP readable without colour (ember vs. ash shape).
- Full keyboard and gamepad navigation; focus never lost when a panel opens/closes; mouse optional.
- No timed text: vignettes and dialogue advance on input (optional auto-advance setting).
- Reduce Motion, Reduce Flash, HUD always visible, Show numbers, subtitle scrim opacity.

**Performance (60 FPS, laptop-friendly)**
- All UI ornaments in **one atlas** (`ui_atlas.png`, ≤ 2048×2048, Lossless) + paper 9-slice textures ≤ 1024 px.
- Max **3 font files** (variable fonts). MSDF only for `display` role at ≥ 64 px.
- No full-screen transparent UI layers left visible when hidden (`visible = false`, not alpha 0).
- No per-frame `queue_redraw()` in idle UI; animated bits via shaders.
- UI draw calls in gameplay ≤ 20; pause ≤ 40.

---

## 10. Decisions Needed From Fred

| ID | Question | Recommendation |
| :-: | :--- | :--- |
| **D1** | Approve the "Notebook & Ember" concept (pause/map/settings as Farid's notebook; HUD as embers; UI changes with the era)? | Yes |
| **D2** | Logotype `شعلة`: hand-lettered image (an exception to the "no baked text" rule, title logo only) or font-rendered? | Hand-lettered image |
| **D3** | Digits in Arabic mode: Arabic-Indic (٥/٥، ٢٠٥٤) or Western (5/5، 2054)? | Arabic-Indic everywhere in `ar` |
| **D4** | HUD numbers (HP 5/5, flame 0/100): hidden by default with a setting to show? | Hidden by default |
| **D5** | Fonts: Reem Kufi + Aref Ruqaa + Readex Pro? | Yes |

Until answered, work proceeds on the recommendations.

---

## 11. Phasing

| Phase | Who | What |
| :-: | :--- | :--- |
| **P0** | Gemini | Style frames (3 mock screens: Title, HUD in combat, Pause/Notebook) at 1920×1080 + ornament sheet. Fred approves. |
| **P1** | Claude | Font roles, tokens, digits helper, settings, copy pass, per-frame `_draw` removal (works with placeholder art). |
| **P2** | Gemini → Claude | `DROP-002` ornaments/fonts → title, HUD, prompts, dialogue, vignette. |
| **P3** | Gemini → Claude | Notebook (pause, journal, map, settings, confirm). |
| **P4 (M2)** | both | 2034 skin, Time Shift UI transition, Grey Eye. |
