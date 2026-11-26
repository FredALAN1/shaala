# SHAALA (شعلة) — Final Hand-Drawn Art Drop-In Guide

This directory (`/assets/final/`) is the production destination for final hand-painted 2D artwork, sprite sheets, parallax plates, UI ornaments, and OFL Arabic/Latin typography.

Every placeholder silhouette, shader material, collision shape, and animation anchor in the Godot 4.3 project is built for **1:1 non-destructive replacement** using the exact specifications in [ART_SPEC.md](file:///Users/alan/Desktop/نسخة من educational-review/shaala/docs/ART_SPEC.md).

---

## 1. Directory Layout Convention

Place final exported assets into the following sub-folders (create sub-folders as each asset pack is delivered):

```text
assets/final/
├── characters/
│   └── farid/                 # Farid spritesheets, 3-tier dagger combos, heterochromia close-ups
├── npcs/
│   ├── boy/                   # The Boy (with wooden stick)
│   ├── amira/                 # Camel Amira (resting + ear twitch + Sadu saddle)
│   ├── motaib/                # Motaib (highway cameo + mid-game dual-greatsword boss)
│   └── ithar/                 # Ithar (2034 memory silhouette + stadium seated)
├── enemies/
│   ├── sand_stalker/          # M1 dune beast
│   ├── shard_husk/            # M1 floating glass echo + projectile
│   ├── relic_sentinel/        # M1 shielded Najdi construct
│   ├── jinn/                  # M2/M3 veiled + Grey Eye reveal forms
│   └── beam_cult/             # M2/M3 fictional prism-lantern acolytes
├── bosses/
│   ├── spire_warden/          # M1 Boss: The Fractured Spire Warden + beams/shards/shockwave
│   └── other_self/            # M4 Citadel Final Boss + Merge sequence
├── interactables/
│   ├── orb_shrine/            # Najdi stele + suspended orb lantern
│   ├── memory_orb/            # Pale-gold orb loop + absorb burst
│   ├── notebook_page/         # Fluttering torn parchment
│   ├── time_shift/            # M2 Time Shift Anchor (2034 <-> 2054)
│   ├── grey_eye/              # M2 Grey Eye Seal door/wall states
│   └── props/                 # Shortcut gates, sandstone tutorial cairns, highway signs
├── fx/                        # Flame projectile, parry Najdi seal ring, shrine pulse, dust puffs
├── environments/
│   ├── desert_camp/           # l0_sky..l5_fg + tiles_desert_camp.png
│   ├── empty_highway/         # l0_sky..l5_fg + tiles_highway.png
│   ├── empty_riyadh/          # l0_sky..l5_fg + tiles_riyadh.png
│   └── <area_id>/             # Areas 4..14 (add `_2034.png` / `_2054.png` for Time Shift rooms)
├── ui/                        # Flame pips, bar frames, Najdi panel corners, minimap icons (NO baked text!)
└── fonts/                     # OFL Arabic+Latin .ttf/.otf fonts (e.g. Amiri, Cairo, Noto Sans Arabic)
```

---

## 2. File Naming & Export Checklist

Before exporting from Procreate, Photoshop, Clip Studio Paint, Krita, or Spine/After Effects:

1. **Format:** PNG-32 (8-bit/channel RGBA, straight alpha, sRGB). Never export indexed 8-bit PNGs or premultiplied black halos.
2. **Naming Pattern:**
   - Horizontal sprite strips: `<entity>_<state>_strip<frame_count>.png` (example: `farid_run_strip10.png`).
   - Individual frames (if preferred for `SpriteFrames`): `<entity>_<state>_01.png`, `_02.png`, ...
   - Time Shift era variants: `<plate_name>_2054.png` and `<plate_name>_2034.png`.
   - Zero spaces or uppercase letters in filenames.
3. **Exact Canvas & Pivot Alignment:** Match the exact pixel dimensions and pivot coordinates listed in `docs/ART_SPEC.md` so swapped sprites sit flush on floors (`y = 0`) without moving collision shapes.
4. **Zero Baked UI Text:** Keep all UI frames, banners, and signposts free of embedded Arabic/English lettering — all text renders live through Godot 4's Advanced Text Server and `localization/strings.csv`.

---

## 3. Godot 4.3 Import & 1:1 Swap Workflow

### 3.1 Texture Import Settings
In Godot 4.3, set the project-wide import preset for `/assets/final/**/*.png`:
- **Compress / Mode:** `VRAM Compressed` (or `Lossless` for crisp UI/vignettes)
- **Mipmaps / Generate:** `Enabled` (`true`)
- **Process / Fix Alpha Border:** `Enabled` (`true`) — prevents dark fringing on hand-painted soft edges
- **CanvasItem Default Texture Filter:** `Linear Mipmap` (matches `snap_2d_transforms_to_pixel = false`)

### 3.2 Swapping a Placeholder Entity Without Breaking Gameplay
1. Open the target `.tscn` scene (for example `scenes/interactables/orb_shrine.tscn` or `scenes/interactables/camel_amira.tscn`).
2. Add a `Sprite2D` or `AnimatedSprite2D` inside the visual container node (`SteleVisual`, `VisualRoot`, `CamelVisual`, `PageVisual`).
3. Assign the exported PNG or `SpriteFrames` resource and set `offset` so the bottom-center foot/base aligns with `(0, 0)` (or centered for `MemoryOrb`).
4. Keep the existing `ShaderMaterial` attached to the parent visual node (`painterly_silhouette.gdshader` for characters/stele, `orb_glow.gdshader` for orbs, `painterly_canvas.gdshader` for parallax plates) and set `use_parent_material = true` on the new `Sprite2D`/`AnimatedSprite2D` so rim-lighting, ink wobble, and `flash_amount` hit-flashes continue working automatically.
5. Hide or delete only the placeholder `Polygon2D` children — **never alter** the root `Area2D`/`CharacterBody2D`, physics layers/masks, `CollisionShape2D`, `Hurtbox`/`Hitbox`, or attached `.gd` script.

### 3.3 Dropping In Production Arabic Fonts
Place any OFL Arabic-capable `.ttf` or `.otf` font (such as `NotoSansArabic-Regular.ttf`, `Cairo-Regular.ttf`, or `Amiri-Regular.ttf`) directly inside `/assets/final/fonts/`. `scripts/ui/arabic_font_setup.gd` automatically detects fonts in this directory at startup and applies full HarfBuzz Arabic shaping and dynamic RTL/LTR layout across every screen.
