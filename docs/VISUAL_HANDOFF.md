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
| **`DROP-002`** | UI Identity "Notebook & Ember": style frames, UI ornaments & OFL fonts | M1→M2 | `DRAFT` *(brief from tech, Gemini to produce)* | Full direction in [`docs/UI_DESIGN_PLAN.md`](UI_DESIGN_PLAN.md). Start with P0 style frames for Fred's approval. |
| **`DROP-001`** | M1 Baseline Painterly Visual Kit & 1:1 Sprite Replacement Queue | M1 | `BASELINE_VERIFIED` *(Queue Open for Final PNGs)* | Shaders, `ShaalaPalette`, and procedural silhouettes verified live in Godot 4.3; awaiting Batch 1A–1E final PNG & OFL font drops from Gemini. |

---

## DROP-002 — UI Identity "Notebook & Ember" (دفتر وجمرة)

- **Status:** `DRAFT` → **Next actor: Gemini**
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
| `notebook_ribbon.png` (+ `_active.png`) | `56×180` each | Sadu-woven bookmark ribbon hanging from top edge. |
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
- *(Pending: P0 style frames, swatch values, font coverage result, any disagreements with the plan.)*

### 7. Integration Checklist for Claude Opus
- [ ] P1 (no art needed): font role map in `ArabicFontSetup`; `UITokens`; `localize_digits()`; settings `reduce_motion` / `hud_always_visible` / `show_numbers` / `text_scale`; remove em-dash separators from UI copy; replace per-frame `_draw()` in title and vignette.
- [ ] P2: fonts discovered per role in `ar` (RTL) and `en` (LTR), zero tofu; title, HUD, prompts, dialogue, vignette rebuilt per plan §6.1–6.4.
- [ ] P3: notebook pause, journal, map, settings, confirm slip per plan §6.5–6.9.
- [ ] Import presets applied (`Lossless`, 9-slice margins), atlas packed, UI draw calls within budget (plan §9).
- [ ] `python3 tools/verify_m1.py --strict`, `godot --headless --path . --import --quit`, `godot --headless --path . --quit-after 3` all 0 errors.
- [ ] Before/after screenshots added next to `docs/ui_audit/`; status → `VERIFIED`.

### 8. Technical Sign-Off Notes (Claude Opus)
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
