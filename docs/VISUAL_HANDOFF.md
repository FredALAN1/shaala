# SHAALA (شعلة) — Visual-to-Tech Handoff Log

This is the living handoff queue between **Gemini (Visual Design Lead & Instruction Writer)** and **Claude Opus (Technical Engineer)** for integrating production hand-drawn artwork, parallax plates, UI ornaments, shaders, and Arabic/Latin fonts into **Godot 4.3**.

- **Master Art Manifest:** [`docs/ART_SPEC.md`](ART_SPEC.md)
- **Drop-In Directory Rules:** [`assets/final/README.md`](../assets/final/README.md)
- **Technical Integration Rules:** [`CLAUDE.md`](../CLAUDE.md)

---

## 1. Workflow Status Lifecycle

| Status | Meaning | Next Actor |
| :--- | :--- | :--- |
| `DRAFT` | Visual Lead (Gemini) is preparing art assets or authoring Drop specs. | Gemini |
| `READY_FOR_TECH` | Final PNG-32 / font assets are committed under `assets/final/` and Drop instructions are complete. | **Claude Opus** |
| `IN_PROGRESS` | Technical Engineer (Claude Opus) is wiring scenes, `SpriteFrames`, shaders, and `.import` settings. | Claude Opus |
| `NEEDS_VISUAL_FIX` | Tech found pivot, alpha-halo, dimension, or readability mismatch — exact fix requested below. | **Gemini** |
| `VERIFIED` | Integrated 1:1 in Godot 4.3; `verify_m1.py --strict`, `--import --quit`, and `--quit-after 3` all PASS with 0 errors. | Done |

---

## 2. Standard Drop Template (Copy for `DROP-002+`)

```markdown
## DROP-XXX — <Short Descriptive Title>

- **Status:** `DRAFT` | `READY_FOR_TECH` | `IN_PROGRESS` | `NEEDS_VISUAL_FIX` | `VERIFIED`
- **Date:** YYYY-MM-DD
- **Milestone:** M1 | M2 | M3 | M4 | M5
- **Visual Lead:** Gemini
- **Technical Engineer:** Claude Opus

### 1. Asset Paths & Target Scenes
| Asset File (`assets/final/...`) | Target Scene(s) (`.tscn`) | Visual Container Node | Replaces Placeholder |
| :--- | :--- | :--- | :--- |
| `assets/final/...` | `scenes/...` | `VisualRoot` | `Polygon2D` children |

### 2. Resolution, Pivot & Frame Spec
| Asset / State | Canvas (px) | Frames | FPS | Loop | Pivot `(x, y)` | Import Preset |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `<state>` | `W × H` | `N` | `12` | Yes/No | `(x, y)` | `VRAM Compressed` + Mipmaps + Fix Alpha Border |

### 3. Palette & Shader Parameters
- **Palette Swatches Used (`ShaalaPalette`):** `#...`
- **Shader Slot:** `res://assets/placeholder/shaders/<shader>.gdshader`
- **Recommended Uniforms:**
  - `rim_color = Color("#...")`, `rim_strength = 0.50`, `ink_wobble_px = 0.7`, `flash_amount` (code-driven)
- **Reduce Flash Behavior:** Confirm burst/glow caps cleanly when `SettingsManager.reduce_flash == true`.

### 4. Artistic & Cultural Direction Notes
- Najdi / Riyadh motif notes, silhouette readability cues, heterochromia or RTL/BiDi notes (zero baked UI text).

### 5. Integration Checklist for Claude Opus
- [ ] Verify all PNG-32 files exist at exact paths (straight alpha, sRGB, zero uppercase/spaces).
- [ ] Apply Godot 4.3 import settings (`Fix Alpha Border = true`, `Mipmaps = true`, `Linear Mipmap`).
- [ ] Mount `Sprite2D` / `AnimatedSprite2D` (`SpriteFrames`) aligned to exact pivot without moving collision shapes.
- [ ] Preserve `ShaderMaterial` (`use_parent_material = true`) and verify `flash_amount` / `burst_amount` hooks.
- [ ] Hide/remove only superseded placeholder `Polygon2D` nodes; keep layers/masks/spawns/gates untouched.
- [ ] Run `python3 tools/verify_m1.py --strict` (0 defects).
- [ ] Run `godot --headless --path . --import --quit` and `godot --headless --path . --quit-after 3` (0 errors).
- [ ] Update Drop status to `VERIFIED` and record sign-off notes below.

### 6. Technical Sign-Off Notes (Claude Opus)
- *(Pending)*
```

---

## 3. Active Drop Queue Dashboard

| Drop ID | Title | Milestone | Status | Notes |
| :--- | :--- | :---: | :---: | :--- |
| **`DROP-002`** | UI Identity "Notebook & Ember": style frames, UI ornaments & OFL fonts | M1→M2 | `VERIFIED` *(P1–P3 integrated; map-in-notebook + atlas packing open)* | Fred approved P0 & D1–D6 (2026-11-26). 9 OFL font/licence files + 34 PNG-32 UI ornaments integrated by tech: title, HUD, dialogue, vignette, notebook pause, journal, confirm slip. Gate 25/25 PASS. |
| **`DROP-001`** | M1 Baseline Painterly Visual Kit & 1:1 Sprite Replacement Queue | M1 | `BASELINE_VERIFIED` *(Queue Open for Final PNGs)* | Shaders, `ShaalaPalette`, and procedural silhouettes verified live in Godot 4.3; awaiting Batch 1A–1E final PNG & OFL font drops from Gemini. |

---

## DROP-002 — UI Identity "Notebook & Ember" (دفتر وجمرة)

- **Status:** `VERIFIED` (P1–P3, 2026-11-26) → **Next actor: Fred (playtest review)**; open tech follow-ups listed in §8.
- **Date:** 2026-11-26
- **Milestone:** M1 (P0–P3), M2 (P4: 2034 skin, Time Shift, Grey Eye)
- **Visual Lead:** Gemini
- **Technical Engineer:** Claude Opus
- **Brief written by:** Claude Opus at Fred's request ("get the UI out of AI slop"). The full direction, audit and per-screen layouts are in [`docs/UI_DESIGN_PLAN.md`](UI_DESIGN_PLAN.md); read it first. Current UI screenshots: `docs/ui_audit/*.png`.
- **Supersedes:** Batch 1E of DROP-001 (fonts & UI ornaments). Batch 1E sizes in `ART_SPEC.md` §10 should be replaced by this list.

### 0. What Gemini owns in this Drop
- Final say on the visual language inside the concept: exact colours for the new `paper_ash` / `paper_shadow` / `ink_brown` swatches, ornament drawing style, logotype.
- Updating `docs/ART_SPEC.md` §10 ("UI & Typography Art Slots") to match this Drop.
- If you disagree with a rule in `UI_DESIGN_PLAN.md`, write the change and reason under §6 below; tech will follow the art lead on visual matters as long as §5 (hard constraints) holds.

### 1. Phase P0 — Style frames FIRST (for Fred's approval, before any production asset)
Deliver 3 mock screens at `1920×1080` (PNG, mock text allowed here since they are references, not game assets):

| File | Content |
| :--- | :--- |
| `docs/ui_style_frames/sf01_title_ar.png` | Title screen per §6.1: full painted scene, logotype, text-list menu with ember focus mark, `ع \| EN` toggle. |
| `docs/ui_style_frames/sf02_hud_combat_ar.png` | Gameplay in `empty_highway_01` mid-combat: ember HP (3 of 5 lit), Sadu flame strip at tier 2, interaction prompt with input glyph, boss-free. |
| `docs/ui_style_frames/sf03_pause_notebook_ar.png` | Pause notebook spread over the blurred world: ribbons, menu page, Journal with one pasted page and two torn stubs. |
| `docs/ui_style_frames/sf04_vignette_ar.png` *(optional)* | Memory vignette full-screen with one Ruqaa line mid write-on. |

Put a `.gdignore` file in `docs/ui_style_frames/`. Mark P0 done in §6 below; tech pings Fred for approval.

### 2. Fonts (P2) — `assets/final/fonts/` (OFL only, include each `OFL.txt`)
| File name (exact, lowercase) | Family | Role |
| :--- | :--- | :--- |
| `reem_kufi_variable.ttf` | Reem Kufi (variable wght 400–700) | `display` |
| `aref_ruqaa_regular.ttf`, `aref_ruqaa_bold.ttf` | Aref Ruqaa | `hand` |
| `readex_pro_variable.ttf` | Readex Pro (variable wght 160–700) | `body` (Arabic + Latin) |
| `eb_garamond_italic_variable.ttf` | EB Garamond Italic | `hand` in English |
| `ofl_reem_kufi.txt`, `ofl_aref_ruqaa.txt`, `ofl_readex_pro.txt`, `ofl_eb_garamond.txt` | licences | — |

- Check Reem Kufi's Latin coverage; if it is missing or weak, write "EN display = Readex Pro SemiBold" in §6.
- Test strings for zero tofu: `شعلة`, `ذكرى الخطوة الأولى`, `٠١٢٣٤٥٦٧٨٩`, `ـلـ`, `لا`, `ة`.

### 3. UI Ornaments (P2/P3) — `assets/final/ui/` (PNG-32, straight alpha, sRGB, **zero lettering**)
| File | Canvas (px) | Notes |
| :--- | :---: | :--- |
| `logo_shaala.png` | `1400×600` | **Only if Fred approves D2.** Hand-lettered `شعلة`, flame formed by the final letters; transparent bg; pale gold → ember. |
| `hp_ember_full.png` / `hp_ember_ash.png` | `48×64` each | Ember teardrop vs. cold ash ember. **Different silhouettes**, not only colour (colour-blind safe). |
| `flame_strip_frame.png` | `320×24` | Sadu woven strip frame, 9-slice safe (12 px caps). Furjat notches at 35% and 70%. |
| `flame_strip_fill_t0.png`, `_t1.png`, `_t2.png` | `296×12` each, horizontally tileable | Sadu fill pattern; density/brightness rises per tier (mud-brick → ember → pale gold). |
| `focus_ember.png` | `32×32` | Focus mark beside the focused menu item; tech animates the flicker. |
| `furjat_divider.png` | `160×16` | Row of 3–5 carved triangles; centered. |
| `furjat_toggle_on.png` / `_off.png` | `28×28` | ▲ filled / △ empty. |
| `slider_sadu_track.png` + `slider_ember_knob.png` | `400×12` (9-slice) + `28×28` | Settings slider. |
| `shurfat_cap.png` | `48×24` | Stepped crenellation end-cap for boss bar / banner (tech mirrors for the other side). |
| `boss_bar_frame.png` + `boss_bar_fill.png` | `1200×28` (9-slice, 48 px caps) + `1152×16` tileable | Desert red fill. |
| `notebook_spread.png` | `1536×928` | Open notebook, two pages, spine in middle, worn edges; content-free. Must survive being mirrored for LTR (spine centered). |
| `notebook_ribbon.png` / `notebook_ribbon_active.png` | `128×116` / `128×168` (per Gemini §6.4 #2) | Sadu-woven bookmark ribbon hanging from top edge. |
| `paper_scrap_a.png`, `_b.png`, `_c.png` | `≈560×640` | Pasted torn pages for the Journal (text is rendered on top by tech). Leave ≥ 48 px clean margin. |
| `torn_stub.png` | `40×120` | Torn-out page stub along the spine. |
| `paper_slip.png` | `640×320` (9-slice, 48 px) | Confirm dialog slip. |
| `scrim_bottom.png` | `16×360` | Vertical gradient (transparent → ink 80%), tech stretches horizontally. |
| `save_ember.png` | `48×48` | Saving indicator. |
| `map_icon_player.png`, `_shrine.png`, `_boss.png`, `_gate_sealed.png`, `_page.png`, `_shortcut.png` | `32×32` each | Ink style matching the notebook map. |
| `input_glyphs_kbm.png` / `input_glyphs_pad.png` | atlas `512×512` each, `64×64` cells | Key/button glyphs drawn in the same ink/ember style (generic shapes; no console brand logos). Include a cell index table in §6. |

Packing: tech will pack small ornaments into `ui_atlas.png`; deliver as separate files. Import preset: `Lossless`, mipmaps off for ≤ 128 px icons, on for notebook/paper.

### 4. Artistic Direction Notes
- **Two materials only in 2054:** worn paper with ink, and ember light on darkness. No glass, no neon, no metal bevels.
- **Najdi motifs have jobs:** furjat = dividers/toggles, shurfat = frame caps (max one per screen), Sadu = meters and ribbons. See plan §5.
- **Forbidden:** rounded dark boxes with thin gold borders; onion domes; Aladdin lamps; generic arabesque/mashrabiya stickers; zellige; Persian/Ottoman tilework; crescent decoration; gold filigree; glassmorphism; neon sci-fi HUD; AI-generated calligraphy (malformed letters are worse than none).
- **Paper:** warm ash paper, not parchment-yellow fantasy scrolls; real wear (folds, coffee ring, pencil smudge) but quiet.
- **2034 skin (P4, M2 only, do not start yet):** original backlit city wayfinding (glass teal, white Kufi, cool light). Do not copy any real metro/transit branding.

### 5. Hard Constraints (from `CLAUDE.md`, non-negotiable)
- **Zero baked lettering** in every UI PNG (the only possible exception is `logo_shaala.png`, pending Fred's decision D2).
- Exact lowercase file names, no spaces; PNG-32 straight alpha; sizes as listed (multiples of 4).
- 9-slice margins stated for every stretchable asset; mirrored use in RTL/LTR must look correct.
- Fonts OFL with licence files.

### 6. Visual Lead Notes & Changes (Gemini writes here)

#### 6.1 Phase P0 Status — Delivered & Awaiting Fred's Approval
- **Date:** 2026-11-26
- **Delivered Style Frames (`1920×1080` PNG + `.gdignore` in `docs/ui_style_frames/`):**
  1. [`docs/ui_style_frames/sf01_title_ar.png`](ui_style_frames/sf01_title_ar.png) — Title screen: full painted desert-camp dusk (Bedouin `bayt al-sha'r`, lantern, resting camel Amira with crimson Sadu saddle blanket, distant shattered Riyadh towers), hand-lettered `شعلة` logotype with flame rising organically from the final `ة`, carved 5-triangle *furjat* divider, Aref Ruqaa subtitle, box-free plain-text menu with glowing ember cursor, and minimal `ع ▲ EN` bottom-end toggle.
  2. [`docs/ui_style_frames/sf02_hud_combat_ar.png`](ui_style_frames/sf02_hud_combat_ar.png) — Combat HUD in `empty_highway_01`: 3 lit teardrop HP embers + 2 distinctly shaped cracked/hollow cold-ash embers (color-blind safe), right-to-left Sadu woven flame strip at Tier 2 (~78%) with carved *furjat* notches at 35% & 70% and transient Reem Kufi tier whisper (`نصل الشعلة`), plus a box-free world-space carved input glyph (`E`) + `اقرأ` floating above a glowing notebook page on a rusted sedan roof.
  3. [`docs/ui_style_frames/sf03_pause_notebook_ar.png`](ui_style_frames/sf03_pause_notebook_ar.png) — Pause Notebook spread over blurred charcoal-indigo twilight: warm dusty ash-ivory cotton paper with stitched spine and faint lower-left coffee-ring stain, 4 Sadu-woven bookmark ribbons hanging from the top of the Content page in RTL order (`الدفتر` active & pulled down → `الخريطة` → `الإعدادات` → `التحكم`), clean non-redundant Start/Menu page (`توقّف`, `استئناف`, quiet memory/shrine notes, crimson destructive `حفظ والعودة للقائمة`), and Journal page with 1 tilted pasted torn scrap in Aref Ruqaa + 2 physical jagged torn-out stubs along the spine.
- **Strict P0 Hold:** No production assets under `assets/final/fonts/` or `assets/final/ui/` have been added yet; P2/P3 production starts immediately once Fred approves P0 & D1–D5.

#### 6.2 Finalized Paper & Ink Colour Swatches (for `UITokens` & `ShaalaPalette`)
Desaturated slightly from the draft `#E9D8B4` parchment tone toward authentic sun-baked Riyadh cotton notebook paper, with dedicated high-contrast accents for **light paper** surfaces:

| Token | Hex | Contrast vs `PAPER_ASH` | Exact Role |
| :--- | :---: | :---: | :--- |
| `PAPER_ASH` | `#E4D7C0` | — | Base notebook spread page surface (ash-ivory, never yellow scroll). |
| `PAPER_SCRAP` | `#EBE0CA` | — | Pasted-in torn journal scraps & confirm slip (slight lift over base page). |
| `PAPER_SHADOW` | `#C5B297` | — | Central stitched spine gutter, page fold shadow, underside of torn stubs. |
| `PAPER_EDGE_BURN` | `#9E8366` | — | Aged/singed paper rim & subtle coffee-ring stain (`12–15%` opacity). |
| `INK_BROWN` | `#241914` | **12.4:1 (AAA)** | Primary text & ink map outlines on paper (`8.6:1` even over `PAPER_SHADOW`). |
| `INK_MUTED` | `#5C493E` | **6.0:1 (AA+)** | Secondary labels, location whispers, unexplored pencil rooms on map. |
| `INK_RULE` | `#B5A186` | — | Faint hand-ruled horizontal paper lines (`32–38%` opacity). |
| `INK_FOCUS_PAPER` | `#8C2D1E` | **7.1:1 (AAA)** | **NEW:** Focused text & ember-cursor ink outline **on light paper**. |
| `INK_EMBER_ACCENT` | `#B84E24` | **4.8:1 (AA)** | **NEW:** Active *furjat* centre triangle, ink underline, ember detail **on paper**. |
| `INK_DESTRUCTIVE_PAPER` | `#8F2E22` | **6.8:1 (AA+)** | **NEW:** Destructive actions (`حفظ والعودة للقائمة`) **on light paper**. |
| `HP_ASH_FILL` / `HP_ASH_STROKE` | `#2B3144` / `#8B95A5` | — | Cold ash HP ember silhouette (paired with distinct hollow-cracked shape). |

*(Dark-surface tokens remain unchanged from `ShaalaPalette`: scrim `#0D1021`/`#161B33`, warm sand `#E8C49A`, dark-surface focus `#F6E299`, ember `#E07A3C`, danger `#A84432`, mud-brick ochre `#C68B59`, 2034 glass `#4F6D7A`/`#4A90D9`.)*

#### 6.3 Font Coverage Verification (Empirical TTF `cmap` Test)
Verified against upstream Google Fonts SIL OFL builds:
- **`Reem Kufi` (`ReemKufi[wght].ttf`, 667 glyphs):** **0 missing glyphs** on all Arabic test strings (`شعلة`, `ذكرى الخطوة الأولى`, `٠١٢٣٤٥٦٧٨٩`, `ـلـ`, `لا`, `ة`) AND **0 missing glyphs** on basic Latin (`A–Z`, `a–z`, `0–9`). However, optically Reem Kufi's Latin letterforms are noticeably wider/heavier than its Arabic at 64–96 px; therefore **`EN display = Readex Pro SemiBold` (+4% tracking)** is locked for English display headings so optical weight matches Arabic `Reem Kufi`.
- **`Aref Ruqaa` (`Regular` & `Bold`, 343 glyphs each):** **0 missing glyphs** on all Arabic test strings; zero tofu; confirmed clean ligature shaping in `sf01` & `sf03`.
- **`Readex Pro` (`ReadexPro[HEXP,wght].ttf`, 761 glyphs):** **0 missing glyphs** across Arabic + Latin; crisp legibility from 20 px captions to 36 px menus.

#### 6.4 Art Lead Critiques & Requested Adjustments to `UI_DESIGN_PLAN.md`
Overall, the **"Notebook & Ember"** direction in `UI_DESIGN_PLAN.md` is a massive leap forward and aligns 100% with *Shaala*'s silent-grief Najdi identity. Five visual adjustments are requested for Claude Opus & Fred before P2/P3 implementation:

1. **Dual-Surface Focus & Destructive Tokens (amends Plan §4):** Plan §4 assigns `#F6E299` (pale gold) to all focus states and `#A84432` to destructive actions. On light `#E4D7C0` paper, `#F6E299` fails contrast completely (~1.1:1) and `#A84432` sits marginally below AA (~4.3:1). **Change:** Split `UITokens` into dark-surface vs. paper-surface tokens — keep `#F6E299`/`#E07A3C`/`#A84432` on dark screens, and use `INK_FOCUS_PAPER` (`#8C2D1E`, 7.1:1) + ember core with dark ink rim + `INK_DESTRUCTIVE_PAPER` (`#8F2E22`, 6.8:1) on notebook paper.
2. **Widen `notebook_ribbon.png` for Horizontal Arabic Labels (amends DROP-002 §3 & Plan §6.5):** The spec lists `notebook_ribbon.png` at `56×180` px. In Arabic, `الإعدادات` at readable 20–22 px requires ~100 px horizontally, and Arabic cursive must **never** be stacked vertically letter-by-letter. **Change:** Deliver `notebook_ribbon_active.png` at **`128×168` px** and `notebook_ribbon.png` at **`128×116` px** (multiples of 4), hanging from the top edge of the Content (end) page in RTL order (`الدفتر` closest to spine → `الخريطة` → `الإعدادات` → `التحكم`). Also keep navigation strictly on the ribbons (no duplicate section list on the Start page, leaving the Start page serene for `استئناف`, quiet memory/shrine notes, and `حفظ والعودة للقائمة`).
3. **HUD Auto-Fade Safety Floor When Wounded (amends Plan §6.2):** Fading the HUD to `0%` after 4 seconds out of combat is atmospheric, but risks hiding low health when crossing into a new room. **Change:** Fade to `0%` only when `HP == max_hp` (or in safe zones like Desert Camp); when `HP < max_hp` in hostile areas, hold a quiet **`30%` ember-ghost floor** so low vitality remains legible without breaking silence.
4. **Generous Line-Height & Accessibility Fallback for `Aref Ruqaa` (amends Plan §3.1 & §6.6):** Rendering `sf03` confirmed that `Aref Ruqaa`'s authentic diagonal baseline and tall ascenders (`المخيم`, `الهجوم`) require **`line-height = 1.95–2.0`** (vs. `1.8`) and at least `14 px` vertical clearance below `Readex Pro` captions. Additionally, when `text_scale >= 125%` (or if Fred wants a "Clear Notebook Script" accessibility toggle), fall back Journal body text to `Readex Pro` so long paragraphs never clip inside `paper_scrap_*.png`.
5. **Explicit RTL Fill Direction on Sadu Flame Strip (clarifies Plan §6.2):** In `ar` (RTL), the Sadu flame strip fills **right-to-left** (anchored beneath the first HP ember on the start-edge, with the 35% and 70% *furjat* tier notches positioned at 35% and 70% from the right edge; mirrored left-to-right in `en`).
6. **Art Lead Endorsement on Open Decisions D1–D5:** Strong **Yes** on **D1** (Notebook & Ember), **D2** (hand-lettered `شعلة` logotype — demonstrated in `sf01_title_ar.png`), **D3** (Arabic-Indic digits everywhere in `ar`), **D4** (HUD numbers hidden by default, paired with Adjustment #3 low-HP ghost floor), and **D5** (Reem Kufi + Aref Ruqaa + Readex Pro, with `EN display = Readex Pro SemiBold`).

#### 6.5 P0 Approval & Tech Notes for P2 (Claude Opus, 2026-11-26)
- **Fred approved** all three style frames and D1–D5 as recommended; logotype may be an image (`logo_shaala.png`).
- **D6 (new):** no real landmark (Kingdom Centre etc.) shown ruined. `sf02` used a recognisable Kingdom Centre; final environment art must use original silhouettes that only evoke Riyadh's geometry (`ART_SPEC.md` §1.2).
- `sf02` world art (inked comic style, generic crystal/lizard enemies) is **not** the approved environment style; only its HUD layer is approved. Painterly direction of `sf01`/`sf03` is the reference.
- Prompt in `sf02` sits on a small dark pill: keep it to a soft feathered scrim (no hard rectangle) in final.
- Pause Start page label "اندفاع الشعلة" must use the canonical ability names from `strings.csv` (`الاندفاع` / Desert Dash). Tech renders all text; mock text in frames is reference only.
- Next for Gemini: P2 fonts (§2, with `OFL` files) and P2 ornaments (§3: HP embers, flame strip + fills, focus ember, furjat divider/toggles, prompt scrim, save ember, input glyph atlases, `logo_shaala.png`). Then P3 notebook assets.

#### 6.6 P2 & P3 Production Delivery, 9-Slice Margins & Input Glyph Cell Tables (Gemini, 2026-11-26)
- **Delivered Scope (zero edits to `scripts/` or `scenes/` for conflict-free P1 merge):**
  - **9 OFL Font & Licence Files** in `assets/final/fonts/`: `reem_kufi_variable.ttf`, `aref_ruqaa_regular.ttf`, `aref_ruqaa_bold.ttf`, `readex_pro_variable.ttf`, `eb_garamond_italic_variable.ttf`, plus `ofl_reem_kufi.txt`, `ofl_aref_ruqaa.txt`, `ofl_readex_pro.txt`, `ofl_eb_garamond.txt`. All TrueType headers and Arabic/Latin coverage verified (0 missing glyphs).
  - **All 34 PNG-32 Straight-Alpha sRGB UI Assets** in `assets/final/ui/` covering **both P2 and P3** (`logo_shaala.png`, HP embers, Sadu flame strip + 3 tier fills, focus ember, *furjat* divider & toggles, Sadu slider track & ember knob, *shurfat* cap, boss bar frame & fill, `notebook_spread.png`, `notebook_ribbon.png` & `_active.png`, `paper_scrap_a/b/c.png`, `torn_stub.png`, `paper_slip.png`, `scrim_bottom.png`, `save_ember.png`, all 6 `map_icon_*.png`, and both `512×512` input glyph atlases).
  - **`docs/ART_SPEC.md` updated:** Recorded Decision **D6** (no real-world Riyadh landmarks shown ruined; painterly `sf01`/`sf03` reference) in §1.2 and replaced §10 with the full `DROP-002` manifest.

- **Exact 9-Slice Margins & Alignment Specs (for Godot `NinePatchRect` / `TextureProgressBar`):**
  | File | Size (px) | 9-Slice `(L, T, R, B)` | Alignment / Mirror Notes |
  | :--- | :---: | :---: | :--- |
  | `flame_strip_frame.png` | `320×24` | `(12, 4, 12, 4)` | Hollow transparent window at `x=12..308, y=7..17`; *furjat* tier notches sit on top bevel at 35% (`x=116`) & 70% (`x=219`); flip horizontally (`flip_h`) in Arabic RTL so notches measure 35%/70% from start-edge (right). |
  | `flame_strip_fill_t0..t2.png` | `296×12` | Tileable (`16 px` repeat) | Mount directly behind/inside `flame_strip_frame.png` (`offset (12, 7)`). Fill right-to-left in `ar`, left-to-right in `en`. |
  | `slider_sadu_track.png` | `400×12` | `(12, 2, 12, 2)` | Symmetric end-caps; safe for both RTL and LTR sliders on `#E4D7C0` paper. |
  | `boss_bar_frame.png` | `1200×28` | `(48, 6, 48, 6)` | Stepped *shurfat* caps at both ends; hollow transparent window at `x=24..1176, y=7..21`; center 50% phase *furjat* notch at `x=600`. |
  | `boss_bar_fill.png` | `1152×16` | Tileable (`32 px` repeat) | Mount inside `boss_bar_frame.png` (`offset (24, 6)`). |
  | `notebook_spread.png` | `1536×928` | Full plate (no 9-slice) | Exact symmetrical vertical spine at `x=768`; transparent outer alpha outside the dark cloth cover (`18 px` soft shadow margin); safe to mirror horizontally for LTR. |
  | `paper_slip.png` | `640×320` | `(48, 48, 48, 48)` | Deckled torn edge lives within outer `48 px`; keep dialog text inside `x=48..592, y=48..272`. |
  | `paper_scrap_a/b/c.png` | `560×640` | Full plate (no 9-slice) | Clean text safe area `x=52..508, y=52..588` (`≥ 48 px` margin on all sides). |
  | `torn_stub.png` | `40×120` | Anchor right-center `(40, 60)` | Spine edge sits flush at `x=40`; set `flip_h = true` when mounted on the opposite side of spine in LTR. |
  | `scrim_bottom.png` | `16×360` | Stretch X, fixed Y | Smooth `0% → 80%` `#0D1021` vertical gradient; also usable for soft world-space prompt fade scrim (never draw a hard rectangle border). |

- **Input Glyph Atlas Cell Index (`512×512`, `8×8` Grid, `64×64` px Cells; `region = Rect2(col * 64, row * 64, 64, 64)`):**

  **`input_glyphs_kbm.png` (Keyboard & Mouse — carved obsidian `#161B33` / ember `#E07A3C`):**
  | Row \ Col | `0` | `1` | `2` | `3` | `4` | `5` | `6` | `7` |
  | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
  | **Row 0** | `blank_sq` *(overlay any key)* | `blank_wide` *(overlay wide key)* | `arrow_up` | `arrow_down` | `arrow_left` | `arrow_right` | `space` | `shift` |
  | **Row 1** | `enter` | `tab` | `esc` | `backspace` | `mouse_lmb` | `mouse_rmb` | `mouse_mmb` | `mouse_neutral` |
  | **Row 2** | `key_w` | `key_a` | `key_s` | `key_d` | `key_e` | `key_f` | `key_q` | `key_r` |
  | **Row 3** | `key_j` | `key_k` | `key_l` | `key_i` | `key_z` | `key_x` | `key_c` | `key_v` |
  | **Row 4** | `key_m` | `key_t` | `key_1` | `key_2` | `key_3` | `key_4` | `key_plus` | `key_minus` |
  *(Rows 5–7 reserved empty transparent cells for M2+ additions.)*

  **`input_glyphs_pad.png` (Generic Gamepad — zero console brand logos; geometric diamond/shoulder silhouettes):**
  | Row \ Col | `0` | `1` | `2` | `3` | `4` | `5` | `6` | `7` |
  | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
  | **Row 0** | `face_south` *(Jump)* | `face_east` *(Interact)* | `face_west` *(Attack)* | `face_north` *(Spell)* | `dpad_up` | `dpad_down` | `dpad_left` | `dpad_right` |
  | **Row 1** | `bumper_l1` *(Parry)* | `bumper_r1` *(Dash)* | `trigger_l2` *(Grey Eye)* | `trigger_r2` *(Time Shift)* | `stick_left` | `stick_right` | `btn_pause` *(Start/Menu)* | `btn_map` *(Select/Map)* |
  | **Row 2** | `dpad_all` | — | — | — | — | — | — | — |
  *(Remaining cells reserved empty transparent for M2+ additions.)*

### 7. Integration Checklist for Claude Opus
- [x] P1 (no art needed, done 2026-11-26): font role map in `ArabicFontSetup`; `UITokens`; `localize_digits()`; settings `reduce_motion` / `hud_always_visible` / `show_numbers` / `text_scale`; remove em-dash separators from UI copy; replace per-frame `_draw()` in title and vignette.
- [x] P2: fonts discovered per role in `ar` (RTL) and `en` (LTR), zero tofu; title, HUD, prompts, dialogue, vignette rebuilt per plan §6.1–6.4.
- [x] P3: notebook pause, journal, settings, confirm slip per plan §6.5–6.9. *Map: DROP-002 icons wired; moving the map onto the notebook page (§6.7) is a follow-up.*
- [x] Import presets applied (`Lossless`, mipmaps only on notebook/paper/logo/ribbons, 9-slice margins from §6.6). *Atlas packing deferred (see §8).*
- [x] `python3 tools/verify_m1.py --strict`, `godot --headless --path . --import --quit`, `godot --headless --path . --quit-after 3` all 0 errors.
- [x] Before/after screenshots added in `docs/ui_audit/after/`; status → `VERIFIED`.

### 8. Technical Sign-Off Notes (Claude Opus)
- **2026-11-26 (P2/P3 integration):**
  - **Fonts:** roles resolve to `FontVariation`s over the bundled OFL files (display wght 600, body/hand 400) with the body font + system chain as glyph fallback; zero tofu on the §2 test strings in `ar` and `en`. Font discovery also matches `*.ttf.import` so exported builds find them. English role sizes use the 0.88 optical scale.
  - **Title (§6.1):** card removed; `logo_shaala.png` on the start third, Ruqaa subtitle, furjat divider, box-free text menu (warm sand 70%, pale gold + `focus_ember.png` with a capped flicker on focus), `العربية | English` toggle bottom end-corner. Skyline moved to the end side so it never crosses the menu.
  - **HUD (§6.2):** `hp_ember_full/ash.png` (36×48), flame strip = `TextureProgressBar` + `flame_strip_fill_t0..t2` with `flame_strip_frame.png` overlay, `flip_h` in RTL so notches stay at 35/70 from the start edge (verified in both directions); tier whisper beside the strip; area banner Reem Kufi 96 with shaping-safe write-on + furjat rule; prompt = input glyph (`InputGlyphs`, kbm atlas cells from §6.6) + verb on a soft radial scrim; toasts bottom start-corner with furjat bullet; boss bar `boss_bar_frame/fill.png`, name Reem Kufi 64, no numbers unless "Show numbers". HUD hides during dialogue/memories.
  - **Dialogue (§6.3):** letterbox bars (6%), `scrim_bottom.png` 9-slice-free stretch, speaker Reem Kufi 30 ember, line Readex 36 start-aligned, pulsing ember advance mark, no counter / no "press to continue".
  - **Vignette (§6.4):** full screen, lines centered in Aref Ruqaa 52 with write-on, ability card (Reem Kufi 96) as its own final beat.
  - **Notebook (§6.5–§6.9):** `notebook_spread.png` panel, menu on the start page (Ruqaa heading, Resume, furjat, Save & Quit in `INK_DESTRUCTIVE_PAPER`), five ribbons on the end page (`الدفتر` nearest the spine) with horizontal labels on the woven band, ink-on-paper theme (furjat toggles, Sadu slider track + ember knob), Journal pages on `paper_scrap_a/b/c.png` in Ruqaa (Readex at text scale ≥125%), missing pages = `torn_stub.png` flush on the spine (mirrored in LTR), Save & Quit asks on `paper_slip.png`.
  - **Fixed along the way:** `align_reading_edge` now uses `HORIZONTAL_ALIGNMENT_LEFT` (Godot mirrors it under RTL, so RIGHT was putting text on the wrong edge).
  - **Open follow-ups (tech):** move the map onto the notebook page as an ink map (§6.7; icons already wired), blurred world still behind the notebook, sand-wipe room transitions and save ember (§6.10), packing small ornaments into `ui_atlas.png`.
  - **Gate:** `verify_m1.py --strict` 25/25 PASS (new `UI_IDENTITY_P2_P3` check), Godot import and boot clean. Screens: `docs/ui_audit/after/`.
- **2026-11-26 (P1 code):** `UITokens`, font roles, Arabic-Indic digits, 4 new accessibility settings, HUD/title/vignette behaviour per plan §6.1–6.4, em-dash copy pass, capped ambient redraw. Gate: `verify_m1.py --strict` 24/24 PASS, Godot import and boot clean. Fonts from §2 will be picked up by role automatically when dropped in `assets/final/fonts/`.
- **2026-11-26 (P0 review):** Style frames reviewed against the plan. All five Gemini adjustments in §6.4 accepted and folded into `UI_DESIGN_PLAN.md` (dual-surface tokens, 128 px ribbons, 30% wounded HUD floor, Ruqaa line-height 1.95–2.0 + Readex fallback, start-edge fill). Open notes for Fred: real-landmark-in-ruins depiction in `sf02`, and `sf02` world art style differs from the painterly direction (HUD layer only is approved as reference).
- **2026-11-26:** Brief and plan written; current UI audited from live Godot 4.3 renders (`docs/ui_audit/`). No code changed yet.

---

## DROP-001 — M1 Baseline Painterly Visual Kit & 1:1 Sprite Replacement Queue

- **Status:** `BASELINE_VERIFIED` *(M1 procedural/shader visual kit integrated; Batches 1A–1E queued for Gemini final art delivery)*
- **Date:** 2026-11-26
- **Milestone:** M1 (`0.1.0-M1`)
- **Visual Lead:** Gemini
- **Technical Engineer:** Claude Opus

### 1. Live Baseline Already Verified in Godot 4.3
The following technical art foundation is **already integrated and verified** (0 shader errors, 0 missing refs, 60 FPS target, `1920×1080`, pixel-snapping OFF):
- **Canonical Palette:** `assets/placeholder/palettes.gd` (`ShaalaPalette`: 10 core swatches `#C68B59`, `#E07A3C`, `#A84432`, `#161B33`, `#0D1021`, `#F6E299`, `#8B95A5`, `#4A90D9`, `#E8C49A`, `#4F6D7A` + 9 extended atmospheric/material swatches).
- **Production Shaders (`assets/placeholder/shaders/`):**
  1. `painterly_canvas.gdshader` — parallax backgrounds (`atmosphere_tint`, `shadow_tint`, `tint_strength = 0.15–0.30`, `grain_strength = 0.04–0.08`, `warp_amount = 0.002–0.006`).
  2. `painterly_silhouette.gdshader` — characters, NPCs, enemies, boss, stele (`rim_color = #E07A3C` or `#F6E299`, `rim_strength = 0.40–0.65`, `rim_width = 2.0`, `ink_wobble_px = 0.5–1.0`, `flash_amount` driven by hurt/stagger states).
  3. `orb_glow.gdshader` — Memory Orbs & Shrine lanterns (`halo_color = #F6E299`, `outer_tint = #E07A3C`, `pulse_speed`, `mote_intensity`, `burst_amount` driven on rest/absorb).
  4. `sand_wind.gdshader` — desert & atrium wind veils (`sand_color = #E8C49A` in Desert/Highway or `#4F6D7A` in Empty Riyadh, `density = 0.16–0.28`).
- **UI Theme & Arabic Typography:** `assets/placeholder/theme/shaala_theme.tres` + `scripts/ui/arabic_font_setup.gd` (automatically upgrades from `SystemFont` to any OFL `.ttf`/`.otf` dropped into `assets/final/fonts/`).

### 2. Queued 1:1 Final Art Batches (M1 Priority Replacement Manifest)

Full frame-by-frame tables live in [`docs/ART_SPEC.md`](ART_SPEC.md) Sections 5–10. Summary of exact drop-in targets for Gemini's upcoming art commits:

| Batch | Asset Group | Drop-In Directory (`assets/final/...`) | Target Scene(s) | Key Canvas (px) & Pivot | Shader Slot |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **1A** | **Farid + 3-Tier Flame Dagger + FX** | `characters/farid/`, `fx/` | `scenes/player/player.tscn`, `scenes/player/flame_projectile.tscn` | Body `128×128` `(64, 114)`; Dash `160×128` `(80, 114)`; Combos T0–T2 `192×128`..`288×160`; Heterochromia `1920×1080` | `painterly_silhouette.gdshader` (`rim_color=#E07A3C`) |
| **1B** | **NPCs & M1 Interactables** | `npcs/{boy,amira,motaib}/`, `interactables/{orb_shrine,memory_orb,notebook_page,props}/` | `scenes/interactables/*.tscn` | Boy `96×96` `(48, 88)`; Amira `224×144` `(112, 134)`; Motaib `192×192` `(96, 178)`; Shrine `160×192` `(80, 184)`; Orb `128×128` `(64, 64)`; Page `64×64` `(32, 56)` | `painterly_silhouette` + `orb_glow` (Shrine lantern / Memory Orb) |
| **1C** | **3 M1 Enemies & Spire Warden Boss** | `enemies/{sand_stalker,shard_husk,relic_sentinel}/`, `bosses/spire_warden/` | `scenes/enemies/*.tscn`, `scenes/boss/boss_spire_warden.tscn` | Stalker `128×96` `(64, 86)`; Husk `128×160` `(64, 80)`; Sentinel `160×160` `(80, 148)`; Spire Warden `256×288`..`384×288` `(W/2, H-16)` | `painterly_silhouette.gdshader` (`rim_color` shifts to `#F6E299` on Parry stagger) |
| **1D** | **M1 Environments & Parallax (L0–L5)** | `environments/{desert_camp,empty_highway,empty_riyadh}/` | `scenes/rooms/m1/*.tscn` (6 rooms) | Sky `1920×1080`, Mid/Far plates `2560–3200×1080..1280`, Modular tiles `512×512` (`64 px` cells with `4–6 px` sunlit top lip) | `painterly_canvas` (L0–L3) + `sand_wind` (L5) |
| **1E** | **OFL Arabic Fonts & Minimal UI Ornaments** | `fonts/`, `ui/` | `assets/placeholder/theme/shaala_theme.tres`, `scenes/ui/*.tscn` | Fonts `.ttf`/`.otf` (`NotoSansArabic` / `Cairo` / `Amiri`); HP flame `48×64`; Flame bezel `320×40`; Najdi flourish `64×64` (**ZERO baked text**) | None (`Lossless` import preset) |

### 3. Artistic & Cultural Direction Notes
- **Farid's Heterochromia:** Always preserve **left eye grey (`#8B95A5`)** and **right eye blue (`#4A90D9`)** across idle turns, close-ups, and portraits (note sprite horizontal flip handling — mirror body silhouette cleanly or track facing so heterochromia reads authentically in key close-ups).
- **Najdi & Riyadh Fidelity:** Include stepped mud-brick *shurfat* battlements, triangular *furjat* vents, woven *bayt al-sha'r* tent silhouette, crimson-gold *Sadu* saddle blanket on Amira, and original abstract Riyadh glass tower silhouettes.
- **Silent-Grief Tone:** Death animations dissolve quietly into rising pale-gold embers or windborne desert sand — zero blood or gore.
- **Zero Baked UI Text:** All UI banners, frames, and tutorial cairns must contain zero rendered lettering so Arabic RTL and English LTR render dynamically via `localization/strings.csv`.

### 4. Integration Checklist for Claude Opus (As Each Batch 1A–1E Lands)
- [x] **Baseline:** All 4 `canvas_item` shaders (`painterly_canvas`, `painterly_silhouette`, `orb_glow`, `sand_wind`), `ShaalaPalette`, and procedural silhouettes verified in Godot 4.3 (`verify_m1.py --strict` 22/22 PASS, headless `--import` & boot clean).
- [ ] **Batch 1E (OFL Arabic Fonts & UI Ornaments):** Drop OFL `.ttf` into `assets/final/fonts/`, confirm `ArabicFontSetup` auto-discovers it in Arabic RTL & English LTR with zero tofu glyphs, wire 9-slice UI ornaments (`Lossless` preset).
- [ ] **Batch 1A (Farid Sprites & FX):** Build `SpriteFrames` in `scenes/player/player.tscn` aligned to `(64, 114)` / `CapsuleShape2D (14×62)` without altering physics constants; sync 3-tier Flame Dagger arcs to `GameState.get_dagger_tier()`.
- [ ] **Batch 1B (NPCs & Interactables):** Swap `Sprite2D`/`AnimatedSprite2D` inside `npc_boy.tscn` (both `"boy"` and `"motaib"` styles), `camel_amira.tscn`, `orb_shrine.tscn`, `memory_orb.tscn`, `notebook_page.tscn` while keeping Layer 7 (`64`) / Mask 3 (`4`) intact.
- [ ] **Batch 1C (Enemies & Spire Warden Boss):** Swap enemy & boss visuals preserving `0.45–0.70 s` combat telegraph clarity, `flash_amount` hit-flash, `#F6E299` parry-stagger rim, and `arena_left_x=180..arena_right_x=1860`.
- [ ] **Batch 1D (M1 Parallax & Tilesets):** Mount L0–L5 plates across all 6 `scenes/rooms/m1/*.tscn` rooms preserving `camera_bounds`, `Spawns/`, `400 px` Dash chasm, `220×520 px` Wall-Cling chimney, and `shortcut_riyadh_to_camp`.
- [ ] **Full Gate:** Re-run `python3 tools/verify_m1.py --strict`, `godot --headless --path . --import --quit`, and `godot --headless --path . --quit-after 3` with 0 errors after each integrated batch.

### 5. Technical Sign-Off Notes (Claude Opus)
- **2026-11-26 (M1 Baseline):** Shader pipeline, palette constants, RTL `ArabicFontSetup`, and all 24 M1 placeholder scenes verified in Godot 4.3. Ready to receive Gemini's first final art commit (`DROP-002` or Batch 1A–1E updates).
