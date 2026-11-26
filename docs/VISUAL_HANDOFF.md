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
| **`DROP-001`** | M1 Baseline Painterly Visual Kit & 1:1 Sprite Replacement Queue | M1 | `NEEDS_VISUAL_FIX` *(spec fixes before Batches 1A–1E)* | Baseline still runs clean in Godot 4.3. Tech review `VR-01..VR-11` (2026-11-26) asks Gemini to correct `ART_SPEC.md` sizing, readability and performance rules **before** painting final PNGs. See section 6 below. |

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

---

## 6. Tech Review 2026-11-26 — Visual Performance & Readability Fix Requests (for Gemini)

- **Status:** `NEEDS_VISUAL_FIX` → **Next actor: Gemini**
- **Reviewer:** Claude Opus (Technical Engineer)
- **Method:** Read `docs/ART_SPEC.md` + this log against the real scenes; rendered every M1 room at `1920×1080` in Godot 4.3 and inspected screenshots; measured frame cost per room.
- **How to close:** For each item, update `docs/ART_SPEC.md` (and the Batch table above if sizes change), then tick the box and reply under it. Tech re-checks and moves DROP-001 back to `BASELINE_VERIFIED`.

### VR-01 — Parallax plate sizes must follow the scenes' real `motion_scale` (HIGH)
`ART_SPEC.md` §9.2 lists `motion_scale` values that do **not** match the scenes (e.g. L0 spec `(0,0)` vs scene `(0.05,0.05)`; L1 spec `(0.12,0.04)` vs scene `(0.18,0.10)`; L3 spec `(0.65,0.25)` vs scene `(0.75,0.50)`). The scene values are canonical (they are what the player sees). A plate must be at least:
`width ≥ 1920 + (room_width − 1920) × motion_x` and `height ≥ 1080 + (room_height − 1080) × motion_y`, plus **64 px bleed on every side**.

Minimum plate sizes from the current scenes (before bleed):

| Room (camera bounds) | L1 Far | L2 Mid | L3 Near | L5 Wind (tiled) |
| :--- | :---: | :---: | :---: | :---: |
| `desert_camp_01` (2600×1080) | 2043×1080 | 2206×1080 | 2430×1080 | tile 1920×1080 |
| `desert_camp_02` (2800×1080) | 2079×1080 | 2290×1080 | 2554×1080 | tile |
| `empty_highway_01` (3200×1080) | 2151×1080 | 2496×1080 | 2880×1080 | tile |
| `empty_highway_02` (2600×1400) | 2043×1119 | 2226×1170 | 2430×**1240** | tile |
| `empty_riyadh_01` (3400×1280) | 2157×1100 | 2542×1130 | 3030×1170 | tile |
| `empty_riyadh_boss` (2200×1080) | 1962×1080 | 2018×1080 | 2102×1080 | — |

- [ ] Update §9.2 `motion_scale` columns to the scene values above and size every plate from this table (round up to a multiple of 4, add bleed). Note: `empty_highway_02` plates are currently specced 1080 px tall but need ≥1240 px for L3 or the top/bottom edge shows during the wall-cling climb.

### VR-02 — Foreground veil (L5) must be edge strips, not full-screen transparent plates (HIGH, performance)
L5 is specced as a full `1920×1080` transparent plate on top of everything. Mostly-empty full-screen alpha layers cost fill-rate on every frame (laptop GPU heat) and the current scenes draw `WindLayer` **behind** gameplay, so a foreground frame needs its own layer anyway (tech will add a foreground `CanvasLayer` when the art lands).
- [ ] Deliver foreground framing as separate cropped strips (e.g. bottom `1920×320`, side `360×1080`) with the offset of each strip noted, not one full-screen PNG.
- [ ] Keep the drifting sand as the `sand_wind` shader (no painted sand veil PNG).

### VR-03 — Keep layers opaque where possible and crop empty alpha (MEDIUM, performance)
Six stacked full-screen layers = up to 6× overdraw per pixel.
- [ ] L0 Sky: fully opaque, no alpha channel needed.
- [ ] L1–L3: crop each plate to its painted content (record the y-offset) so transparent area stays under ~30% of the plate.

### VR-04 — Farid's painted height must match his 62 px collision capsule (HIGH, gameplay readability)
Farid's collision is `CapsuleShape2D` radius 14, height 62 (≈62 px tall). The 128×128 canvas with pivot `(64,114)` is fine, but the **painted figure** must stand ~64–70 px tall (feet at y=114, head at ~y=48). A taller painted body makes enemy hits look unfair; a smaller one is hard to read at 1080p.
- [ ] Add the painted-height rule (and the same rule for each enemy vs. its collision shape) to §5 and §7.

### VR-05 — Shader uniforms for final painted art (MEDIUM, visual quality + performance)
- [ ] `painterly_silhouette`: set `ink_wobble_px = 0` for final `Sprite2D`/`AnimatedSprite2D`. On a 4-vertex sprite quad the vertex wobble moves the whole sprite by up to 1 px six times a second, which reads as jitter, not ink boil. If you want boil, paint it into the frames.
- [ ] `painterly_canvas` on painted plates: `warp_amount = 0` (warp blurs and shimmers painted detail) and `grain_strength ≤ 0.03` (the canvas tooth should be painted). State which layers should keep the shader at all; tech suggests L0–L1 only, L2–L3 plain.

### VR-06 — Empty Riyadh: walkable platforms blend into the background (HIGH, readability)
In `empty_riyadh_01` and `empty_riyadh_boss`, platforms use glass-teal `#4F6D7A` and the tower/pillar background layers use nearly the same teal value, so the player cannot tell walkable ledges from scenery.
- [ ] Specify a value rule: background layers in Empty Riyadh stay at least ~25% darker (or desaturated) than gameplay surfaces.
- [ ] Every walkable top edge carries the 4–6 px pale-gold/ochre lip (already in §9.1) — call this out explicitly for glass walkways and balconies.

### VR-07 — Desert Camp: floor colour equals the mid dunes (MEDIUM, readability)
In `desert_camp_01/02` the gameplay floor and the L2 dunes are the same desert red, so depth flattens.
- [ ] Push L2 dunes cooler/darker by ~15% value, or make the gameplay floor body darker with the sunlit lip on top.

### VR-08 — Sky gradients must not band (LOW, visual quality)
The placeholder sky is 3 flat bands. A smooth final L0 gradient on 8-bit PNG will show banding on a 1920-wide sky.
- [ ] Paint L0 with grain/dither in the gradient; avoid large perfectly smooth fills.

### VR-09 — Full-screen vignettes and close-ups (MEDIUM, memory)
Heterochromia close-ups and vignettes are `1920×1080` frames. With `Lossless` import each frame is ~8 MB of VRAM.
- [ ] Limit each vignette to ≤ 6 full-screen key frames (animate with camera pans/fades rather than extra frames).
- [ ] Mark them for `VRAM Compressed` import (Lossless stays for small UI only, ≤ 512 px).

### VR-10 — Texture budget rules for all batches (MEDIUM, memory and heat)
- [ ] Every PNG dimension is a multiple of 4 (required for VRAM block compression); no side above 4096 px.
- [ ] Character/enemy animation frames packed into sheets ≤ 2048×2048 per animation group.
- [ ] Per-room budget: all parallax plates of one room ≤ ~64 MB VRAM after compression (tech will measure and report).

### VR-11 — Spec ↔ scene name mismatches to settle before painting (LOW)
- [ ] `ART_SPEC.md` L4 lists "Modular 64 px tiles" but M1 rooms use hand-placed `Polygon2D` platforms, not a `TileMap`. Confirm whether final floors are tiles (tech converts) or painted platform sprites matched 1:1 to the existing collision rectangles. Tech recommends painted platform sprites for M1 to keep the 400 px chasm and 220×520 chimney geometry untouched.

### Tech notes (Claude Opus)
- No art files exist yet under `assets/final/` (only `README.md`), so this review covers the specs, the shaders and the placeholder visuals.
- Engine-side performance fixes in the same change: background room streaming (first-entry hitch 48–97 ms → 9–16 ms), unfocused/paused FPS caps, batched ambient audio. See `docs/QA_NOTES.md` §3.1.
