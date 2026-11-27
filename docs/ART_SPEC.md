# SHAALA (شعلة) — Art Specification & 1:1 Asset Replacement Manifest

**Version:** 0.1.0 (Milestone 1 Vertical Slice + Full 14-Area Production Roadmap)  
**Engine:** Godot 4.3 (2D Renderer, Typed GDScript)  
**Base Resolution:** `1920 × 1080` (`canvas_items`, aspect `expand`)  
**Target Frame Rate:** `60 FPS`  
**Pixel Snapping:** **OFF** (`snap_2d_transforms_to_pixel = false`, `snap_2d_vertices_to_pixel = false`)  

---

## 1. Visual Direction & Cultural Principles

### 1.1 Core Aesthetic Identity
SHAALA is an original hand-drawn 2D painterly metroidvania set across a silent, emptied Riyadh in 2054 (with temporal echoes of intact 2034). Every frame is composed like a melancholic gouache and ink illustration in motion:
- **Foreground & Playable Layer:** Crisp, high-contrast dark silhouettes (Night Indigo `#161B33` and Deep Shadow `#0D1021`) edged with warm Sunset Orange (`#E07A3C`) or Pale Gold (`#F6E299`) rim light so gameplay readability remains effortless at 60 FPS.
- **Midground & Background Layers:** Soft, hand-painted multi-layer parallax plates featuring atmospheric haze, canvas tooth texture, and sweeping desert horizon gradients.
- **Focal Luminance:** Memory Orbs, Orb Shrines, and Farid's Flame Dagger carry the warmest pale-gold luminescence in the frame, visually guiding exploration without intrusive UI clutter.

### 1.2 Authentic, Respectful Saudi & Najdi Architectural Motifs
All environmental art and prop silhouettes draw from genuine central Arabian (Najdi) and modern Riyadh visual heritage:
- **Mud-Brick Crenellations (*Shurfat* / شرفات):** Stepped triangular parapet battlements crowning Najdi walls, Diriyah fortresses, and Orb Shrine steles.
- **Triangular Ventilation Slits (*Furjat* / فرجات):** Clustered triangular apertures carved into thick mud-brick plaster (`#C68B59`) for cooling airflow and subtle shadow rhythm.
- **Bedouin Tent (*Bayt al-Sha'r* / بيت الشعر):** Low-slung dark woven hair-tent silhouette anchored by guy-ropes, warm lantern underglow, and crimson-gold *Sadu* geometric textiles.
- **Date Palms (*Nakheel*) & Acacia Silhouettes:** Wind-bent fronds framing oasis valleys (Wadi Hanifa) and desert camp outskirts.
- **Riyadh Ruined Skyline (2054) & Intact Skyline (2034) — Decision D6:** Original, respectful architectural silhouettes that evoke Riyadh's modern skyline rhythm (geometric glass spires, elevated ring-road viaducts, quiet limestone Tuwaiq cliffs) — **never** depicting real-world Riyadh landmarks (e.g., Kingdom Centre, Al Faisaliah) in a ruined or destroyed state. All world environment art follows the hand-painted gouache and ink-wash aesthetic of `docs/ui_style_frames/sf01_title_ar.png` and `sf03_pause_notebook_ar.png` (never comic-inked linework).

### 1.3 Content & Tone Guidelines
- **Grief in Silence, Not Gore:** Loss (Farid's family, the emptying of Riyadh) is conveyed through empty spaces, torn pages, fading embers, and quiet poses — never graphic injury, blood, or corpse imagery.
- **Respectful Cultural & Spiritual Framing:** Jinn folklore and religious heritage are depicted with dignity, awe, and mystery. The Beam Cult is a purely fictional esoteric sect with abstract light-prism motifs unrelated to any real-world faith.
- **Originality:** Every silhouette, gesture, and architectural contour is authored originally for SHAALA's Riyadh setting.

---

## 2. Technical Art & Export Specifications

| Parameter | Canonical Setting | Rationale |
| :--- | :--- | :--- |
| **Base Viewport** | `1920 × 1080 px` | Crisp HD framing for hand-painted brushstrokes |
| **Stretch Mode** | `canvas_items`, aspect `expand` | Supports 16:9 and ultrawide without cropping gameplay |
| **Pixel Snapping** | **OFF** (`false`) | Eliminates sub-pixel jitter on painted art & slow parallax |
| **Texture Filter** | `Linear with Mipmaps` | Smooth organic ink edges at all camera zoom levels |
| **File Format** | PNG-32 (8-bit/channel RGBA, straight alpha, sRGB) | Lossless alpha gradients for soft ink & glow edges |
| **Authoring Scale** | Paint at **2×** target size; export at **1×** manifest px | Preserves fine painterly tooth after downsampling |
| **Character Frame Rate** | `12 FPS` base (keyed `16–24 FPS` for attacks/dash) | Expressive hand-drawn cadence synced cleanly to 60 Hz |
| **Ambient / Prop Loops** | `8–12 FPS` | Gentle breathing, cloth sway, and fluttering parchment |
| **Pivot Standard (Grounded)** | Bottom-Center `(W / 2, H - ground_pad)` | Aligns feet directly to `y = 0` physics floor |
| **Pivot Standard (Floating/FX)** | Center `(W / 2, H / 2)` | Simplifies radial rotation, scaling, and bobbing |

---

## 3. Canonical Color Palette (`ShaalaPalette`)

Defined in code at [palettes.gd](file:///Users/alan/Desktop/نسخة من educational-review/shaala/assets/placeholder/palettes.gd) (`class_name ShaalaPalette`).

### 3.1 Core Swatches

| Constant Name | Hex | RGB (0–255) | Primary Usage |
| :--- | :--- | :--- | :--- |
| `MUD_BRICK_OCHRE` | `#C68B59` | `(198, 139, 89)` | Najdi walls, Diriyah plaster, Orb Shrine stele, midground architecture |
| `SUNSET_ORANGE` | `#E07A3C` | `(224, 122, 60)` | Desert Camp sky horizon, silhouette rim light, Tier 0–1 flame core |
| `DESERT_RED` | `#A84432` | `(168, 68, 50)` | Deep dusk sky, dune cliffs, Farid's cloak trim, Motaib's mantle, health embers |
| `NIGHT_INDIGO` | `#161B33` | `(22, 27, 51)` | Character/enemy silhouettes, ruined Riyadh twilight sky, translucent UI panels |
| `DEEP_SHADOW` | `#0D1021` | `(13, 16, 33)` | Foreground framing silhouettes, recessed arches, grounded contact shadows |
| `PALE_GOLD_ORB` | `#F6E299` | `(246, 226, 153)` | Memory Orbs, Shrine lantern, Tier 2 Shaala Blade, Parry seal ring, UI borders |
| `FARID_EYE_GREY` | `#8B95A5` | `(139, 149, 165)` | Farid's **left eye** (Citadel power), Grey Eye seal vision, Other Self accents |
| `FARID_EYE_BLUE` | `#4A90D9` | `(74, 144, 217)` | Farid's **right eye** (humanity/memory), True Ending final frame |
| `WARM_SAND_LIGHT` | `#E8C49A` | `(232, 196, 154)` | Wind-blown sand streaks, lit dune crests, parchment highlights |
| `GLASS_TEAL` | `#4F6D7A` | `(79, 109, 122)` | Shattered Riyadh tower facades, Mall skylights, Shard Husk, Motaib's blades |

### 3.2 Extended Atmospheric & Material Swatches

| Constant Name | Hex | Role |
| :--- | :--- | :--- |
| `SHADE_NAJDI_DARK` | `#6E4930` | Shaded mud-brick plinths, sandstone debris, wooden staff/stick |
| `NAJDI_PLASTER_HIGHLIGHT` | `#D9A87C` | Sunlit masonry bevels, torn paper fold |
| `PARCHMENT_CREAM` | `#EFE0BE` | Torn Notebook Pages base paper |
| `PARCHMENT_INK` | `#2A2233` | Arabic handwritten ink lines on Torn Notebook Pages |
| `SADDLE_CRIMSON` | `#8C2F2B` | Camel Amira's *Sadu* saddle blanket base |
| `SADDLE_TRIM_GOLD` | `#D9B66C` | *Sadu* woven border embroidery |
| `MOTAIB_BRONZE_TRIM` | `#B5804A` | Motaib's Najdi-engraved pauldrons and lantern chains |
| `ERA_2034_WARM_TINT` | `#F5D8A8` | Time Shift 2034 intact-city golden hour grade |
| `ERA_2054_COOL_TINT` | `#9BA7C4` | Time Shift 2054 silent-ruin cool twilight grade |

---

## 4. Shader Slots & Material Reference

All 4 production shaders live in `res://assets/placeholder/shaders/` and are shared seamlessly between placeholder polygons and final illustrated sprites.

| Shader File | Slot Target | Key Uniforms | Performance Note |
| :--- | :--- | :--- | :--- |
| `painterly_canvas.gdshader` | Parallax background & midground art layers | `atmosphere_tint`, `shadow_tint`, `tint_strength` (`0.15–0.30`), `grain_strength` (`0.04–0.08`), `warp_amount` (`0.002–0.006`), `brush_scale`, `time_speed` | Single value-noise pass; <0.15 ms @ 1080p |
| `painterly_silhouette.gdshader` | Farid, NPCs, Amira, Enemies, Bosses, Stele props | `rim_color` (`#E07A3C` or `#F6E299`), `rim_strength` (`0.40–0.65`), `rim_width` (`2.0`), `light_direction`, `ink_wobble_px` (`0.5–1.0`), `flash_amount` (`0.0–1.0`), `flash_color` | 1 neighbor alpha tap + stepped ink boil; supports combat hit-flash directly |
| `orb_glow.gdshader` | Memory Orbs, Orb Shrine lanterns, Citadel sky orbs | `core_color`, `halo_color` (`#F6E299`), `outer_tint` (`#E07A3C`), `pulse_speed`, `pulse_amount`, `core_radius`, `mote_intensity`, `burst_amount` (`0.0–1.0`) | Pure analytical radial field + 6 orbiting motes; zero texture samples |
| `sand_wind.gdshader` | Atmospheric foreground & midground wind overlays | `sand_color` (`#E8C49A`), `dusk_veil_color` (`#C68B59`), `wind_speed`, `wind_angle`, `density` (`0.18–0.35`), `streak_scale`, `grain_density`, `height_fade` | 2 noise octaves + hash flecks; toggleable intensity per room |

---

## 5. Character Manifest — Farid (Player)

- **Physics Hitbox Reference:** `CapsuleShape2D`, `28 × 62 px` (`radius = 14`, `height = 62`).
- **Silhouette Design:** Lean desert traveler in a weathered Night Indigo (`#161B33`) hooded cloak with Desert Red (`#A84432`) inner hem, wrapped desert scarf, and bare/wrapped forearms wielding the Flame Dagger.
- **Iconic Signature Detail:** Heterochromia visible on close-ups, idle facing turns, and ability flares — **Left Eye: Grey (`#8B95A5`)**, **Right Eye: Blue (`#4A90D9`)**.
- **Shader Slot:** `painterly_silhouette.gdshader` (`rim_color = #E07A3C`, `flash_amount` driven by `hurt_state.gd`).
- **Drop-In Directory:** `/assets/final/characters/farid/`

### 5.1 Core Traversal & Reactive States

| Animation State | Drop-In Filename Pattern | Canvas (px) | Frames | FPS | Loop | Pivot (x, y) | Visual Notes & Key Poses |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `idle` | `farid_idle_strip8.png` | `128 × 128` | 8 | 10 | Yes | `(64, 114)` | Calm stance, scarf and cloak hem drifting gently in desert breeze; subtle eye glint |
| `run` | `farid_run_strip10.png` | `128 × 128` | 10 | 16 | Yes | `(64, 114)` | Forward lean, streaming desert-red cloak lining, crisp foot contact dust cues |
| `jump_rise` | `farid_jump_strip4.png` | `128 × 128` | 4 | 14 | No | `(64, 114)` | 1 squash anticipation frame + 3 upward stretch frames; scarf trailing downward |
| `fall` | `farid_fall_strip4.png` | `128 × 128` | 4 | 12 | Yes | `(64, 114)` | Cloak billowing upward above shoulders; knees poised for landing |
| `land` | `farid_land_strip3.png` | `128 × 128` | 3 | 18 | No | `(64, 114)` | Brief crouch compression settling smoothly back into `idle` or `run` |
| `wall_cling` | `farid_wall_cling_strip4.png` | `128 × 128` | 4 | 10 | Yes | `(64, 114)` | One hand braced flat on wall, dagger hand tucked, scarf fluttering upward; dust trail |
| `dash` | `farid_dash_strip5.png` | `160 × 128` | 5 | 24 | No | `(80, 114)` | Horizontal ember-streak silhouette (`0.22s` duration); includes 1 clean afterimage mask (`farid_dash_ghost.png`, `160 × 128`) |
| `ground_pound_start` | `farid_gp_start_strip3.png` | `128 × 144` | 3 | 18 | No | `(64, 128)` | Brief airborne tuck flipping dagger point downward (M2/M3 ability) |
| `ground_pound_fall` | `farid_gp_fall_strip3.png` | `128 × 144` | 3 | 16 | Yes | `(64, 128)` | Vertical plunge wrapped in Sunset Orange / Pale Gold ember sheath |
| `ground_pound_land` | `farid_gp_land_strip5.png` | `192 × 144` | 5 | 20 | No | `(96, 128)` | Kneeling impact + radiating Najdi ember shockwave crack |
| `glide` | `farid_glide_strip6.png` | `160 × 128` | 6 | 12 | Yes | `(80, 112)` | Cloak spread wide catching updrafts with gentle pale-gold rim shimmer (M3 ability) |
| `spell_cast` | `farid_spell_cast_strip6.png` | `144 × 128` | 6 | 18 | No | `(64, 114)` | Forward palm thrust releasing Flame Spell; cloak snaps back on recoil |
| `parry` | `farid_parry_strip5.png` | `144 × 128` | 5 | 20 | No | `(72, 114)` | Cross-dagger guard + luminous pale-gold geometric seal ring on successful deflect |
| `hurt` | `farid_hurt_strip3.png` | `128 × 128` | 3 | 16 | No | `(64, 114)` | Recoil arch paired with `flash_amount = 0.85`; non-graphic |
| `death` | `farid_death_strip8.png` | `160 × 128` | 8 | 12 | No | `(80, 114)` | Drops to one knee as pale-gold memory embers drift upward from cloak (silent, dignified, zero gore) |

### 5.2 Flame Dagger 3-Hit Combo × 3 Flame Tiers & Combat FX

Farid's Flame Dagger scales dynamically with the Resource meter (`GameState.get_dagger_tier()`). Keep body frames reusable across tiers with additive tier-specific blade & arc overlay sheets so artists can swap either full combo sheets or separated blade FX cleanly.

| State / FX | Tier | Resource Range | Reach (px) | Drop-In Filename | Canvas (px) | Frames | FPS | Pivot (x, y) | Color Signature |
| :--- | :---: | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :--- |
| `attack_1` (horiz slash) | T0 | `0–34` | `72` | `farid_atk1_t0_strip5.png` | `192 × 128` | 5 | 24 | `(64, 114)` | `#E07A3C` + `#A84432` embers |
| `attack_2` (backhand) | T0 | `0–34` | `72` | `farid_atk2_t0_strip5.png` | `192 × 128` | 5 | 24 | `(64, 114)` | `#E07A3C` + warm sparks |
| `attack_3` (lunge finish) | T0 | `0–34` | `72` | `farid_atk3_t0_strip6.png` | `208 × 128` | 6 | 24 | `(64, 114)` | `#E07A3C` sweeping ember tail |
| `attack_1` (horiz slash) | T1 | `35–69` | `96` | `farid_atk1_t1_strip5.png` | `224 × 144` | 5 | 24 | `(72, 128)` | `#E07A3C` core -> `#F6E299` edge |
| `attack_2` (backhand) | T1 | `35–69` | `96` | `farid_atk2_t1_strip5.png` | `224 × 144` | 5 | 24 | `(72, 128)` | Bright orange-gold brushstroke arc |
| `attack_3` (lunge finish) | T1 | `35–69` | `96` | `farid_atk3_t1_strip6.png` | `240 × 144` | 6 | 24 | `(72, 128)` | Extended golden flame blade |
| `attack_1` (horiz slash) | T2 | `70–100` | `124` | `farid_atk1_t2_strip5.png` | `272 × 160` | 5 | 24 | `(80, 140)` | `#FFF8DC` core + `#F6E299` crescent wave |
| `attack_2` (backhand) | T2 | `70–100` | `124` | `farid_atk2_t2_strip5.png` | `272 × 160` | 5 | 24 | `(80, 140)` | Blazing pale-gold wide ribbon |
| `attack_3` (lunge finish) | T2 | `70–100` | `124` | `farid_atk3_t2_strip6.png` | `288 × 160` | 6 | 24 | `(80, 140)` | Radiant Shaala Blade surge |
| `attack_up` (all tiers) | T0–T2 | All | `72–124` | `farid_atk_up_t{0..2}_strip5.png` | `192 × 224` | 5 | 24 | `(96, 198)` | Overhead crescent slash |
| `attack_down` (pogo) | T0–T2 | All | `72–124` | `farid_atk_down_t{0..2}_strip5.png` | `192 × 224` | 5 | 24 | `(96, 112)` | Downward airborne plunge slash |
| `flame_projectile_loop` | Spell | Cost `25` | — | `/assets/final/fx/flame_projectile_strip6.png` | `96 × 64` | 6 | 18 | `(48, 32)` | Comet-like painted ember bolt (`#F6E299` / `#E07A3C`) |
| `flame_projectile_hit` | Spell | — | — | `/assets/final/fx/flame_impact_strip5.png` | `128 × 128` | 5 | 20 | `(64, 64)` | Gouache ember burst |
| `parry_seal_ring` | Parry | — | — | `/assets/final/fx/parry_seal_strip6.png` | `192 × 192` | 6 | 24 | `(96, 96)` | Expanding 8-point Najdi pale-gold star ring |

### 5.3 Narrative Portraits & Heterochromia Close-Ups

| Asset | Drop-In Filename | Canvas (px) | Frames | Notes |
| :--- | :--- | :---: | :---: | :--- |
| Farid Heterochromia Close-Up (Standard) | `/assets/final/characters/farid/farid_eyes_heterochromia.png` | `1920 × 1080` | 1 (layered PSD/PNG) | Extreme widescreen close-up: left eye `#8B95A5` (grey), right eye `#4A90D9` (blue), drifting golden embers |
| Ending 1 Close-Up (Revenge — Grey Eyes) | `/assets/final/characters/farid/farid_eyes_ending_grey.png` | `1920 × 1080` | 1 | Both eyes luminous Citadel grey `#8B95A5`; cool silver-indigo rim |
| Ending 2 Final Shot (True Ending — Blue Eyes) | `/assets/final/characters/farid/farid_eyes_ending_blue.png` | `1920 × 1080` | 1 | Both eyes warm human blue `#4A90D9`; soft 2034 stadium evening bokeh |

---

## 6. NPCs & Companions Manifest

**Shader Slot:** `painterly_silhouette.gdshader` (`rim_color = #E07A3C`).  
**Drop-In Directory:** `/assets/final/npcs/`

| Character | Animation State | Drop-In Filename | Canvas (px) | Frames | FPS | Pivot (x, y) | Design & Cultural Notes |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **The Boy** (`npc_boy`) | `idle` | `boy/boy_idle_strip6.png` | `96 × 96` | 6 | 8 | `(48, 88)` | Small silhouette (~58 px tall) in indigo thobe, ochre scarf, headcloth, holding thin wooden desert stick |
| **The Boy** | `talk_tap` | `boy/boy_talk_strip6.png` | `96 × 96` | 6 | 10 | `(48, 88)` | Gently taps stick forward toward Farid / gestures toward northern horizon |
| **Camel Amira** (`camel_amira`) | `rest_idle` | `amira/amira_idle_strip8.png` | `224 × 144` | 8 | 8 | `(112, 134)` | Kneeling Arabian dromedary in ochre-shadow `#593A28`, crimson-gold Najdi *Sadu* saddle blanket, slow breathing |
| **Camel Amira** | `ear_twitch_nod` | `amira/amira_nod_strip6.png` | `224 × 144` | 6 | 10 | `(112, 134)` | Gentle ear flick & calm nod toward the red desert horizon |
| **Motaib** (Cameo & Boss) | `cameo_idle` | `motaib/motaib_idle_strip8.png` | `192 × 192` | 8 | 10 | `(96, 178)` | Towering (~110 px) armored silhouette (`#1F2640`), bronze Najdi pauldrons (`#B5804A`), desert-red cloak, **two crossed greatswords** |
| **Motaib** (M2/M3) | `walk` | `motaib/motaib_walk_strip8.png` | `192 × 192` | 8 | 12 | `(96, 178)` | Heavy measured stride; twin blades slung or drawn low |
| **Motaib** (Mid-Game Boss) | `dual_cleave` | `motaib/motaib_cleave_strip10.png` | `288 × 224` | 10 | 18 | `(144, 206)` | 0.60s raised-cross telegraph -> sweeping dual greatsword arc (parryable) |
| **Motaib** (Mid-Game Boss) | `leap_slam` | `motaib/motaib_leap_strip10.png` | `288 × 256` | 10 | 18 | `(144, 236)` | High armored vault driving both blades into stone |
| **Motaib** (Mid-Game Boss) | `stagger_kneel` | `motaib/motaib_kneel_strip6.png` | `192 × 192` | 6 | 10 | `(96, 178)` | Post-parry stagger & somber recognition kneel |
| **Ithar** (M4 Memory & 2034) | `silhouette_idle` | `ithar/ithar_idle_strip6.png` | `128 × 144` | 6 | 8 | `(64, 132)` | Graceful backlit warm gold-indigo silhouette in flowing abaya/shawl; peaceful presence |
| **Ithar** (True Ending) | `stadium_seated` | `ithar/ithar_stadium_seated.png` | `256 × 192` | 4 | 6 | `(128, 178)` | Seated calmly in 2034 stadium bleachers, golden light across hair/scarf |

---

## 7. Enemies & Bosses Manifest

**Shader Slot:** `painterly_silhouette.gdshader` (`flash_amount` driven on hit & parry stagger; `rim_color` shifts to `#F6E299` during stagger).  
**Drop-In Directories:** `/assets/final/enemies/` and `/assets/final/bosses/`

### 7.1 Milestone 1 Enemies

| Enemy | State | Drop-In Filename | Canvas (px) | Frames | FPS | Pivot (x, y) | Visual & Telegraph Notes |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Sand Stalker** (`sand_stalker`, 35 HP) | `idle_patrol` | `sand_stalker/stalker_patrol_strip8.png` | `128 × 96` | 8 | 14 | `(64, 86)` | Low quadrupedal dune silhouette (`#A84432` / `#161B33`), sand-dusted spine ridges |
| Sand Stalker | `telegraph` | `sand_stalker/stalker_telegraph_strip5.png` | `128 × 96` | 5 | 12 | `(64, 86)` | `0.45s` low crouch; eyes & dorsal spines flare bright Sunset Orange (`#E07A3C`) |
| Sand Stalker | `lunge` | `sand_stalker/stalker_lunge_strip4.png` | `160 × 96` | 4 | 20 | `(80, 86)` | Stretched horizontal pounce (parryable) |
| Sand Stalker | `stagger_hurt` | `sand_stalker/stalker_stagger_strip4.png` | `128 × 96` | 4 | 10 | `(64, 86)` | Knocked back with pale-gold stun shimmer (`1.2s` stagger) |
| Sand Stalker | `death` | `sand_stalker/stalker_death_strip6.png` | `144 × 96` | 6 | 14 | `(72, 86)` | Collapses into wind-blown red sand and fading embers (non-graphic) |
| **Shard Husk** (`shard_husk`, 45 HP) | `hover_idle` | `shard_husk/husk_hover_strip8.png` | `128 × 160` | 8 | 10 | `(64, 80)` | Tall floating fractured-glass & night-indigo echo of the Beam (`#161B33` + `#4F6D7A` shards) |
| Shard Husk | `telegraph_cast` | `shard_husk/husk_cast_strip8.png` | `160 × 160` | 8 | 12 | `(80, 80)` | `0.65s` converging ring of pale-gold glass shards before releasing projectile |
| Shard Husk | `projectile` | `shard_husk/husk_shard_proj_strip4.png` | `64 × 48` | 4 | 16 | `(32, 24)` | Spinning teal-gold glass splinter (parryable) |
| Shard Husk | `stagger_death` | `shard_husk/husk_death_strip6.png` | `160 × 160` | 6 | 14 | `(80, 80)` | Glass plates scatter and evaporate into pale gold dust |
| **Relic Sentinel** (`relic_sentinel`, 75 HP) | `march_guard` | `relic_sentinel/sentinel_march_strip8.png` | `160 × 160` | 8 | 10 | `(80, 148)` | Heavy Najdi carved stone & dark bronze construct holding broad sandstone slab shield |
| Relic Sentinel | `shield_block` | `relic_sentinel/sentinel_block_strip3.png` | `160 × 160` | 3 | 16 | `(80, 148)` | Metallic spark flare when frontal low-tier melee is deflected |
| Relic Sentinel | `cleave_telegraph` | `relic_sentinel/sentinel_telegraph_strip6.png` | `192 × 176` | 6 | 10 | `(96, 164)` | `0.60s` heavy overhead raise glowing with ochre-gold fractures |
| Relic Sentinel | `cleave_strike` | `relic_sentinel/sentinel_cleave_strip5.png` | `224 × 176` | 5 | 20 | `(112, 164)` | Crushing forward arc (parryable!) |
| Relic Sentinel | `stagger_death` | `relic_sentinel/sentinel_death_strip7.png` | `192 × 160` | 7 | 12 | `(96, 148)` | Stone joints unbind and crumble into sand |

### 7.2 Milestone 1 Boss — The Fractured Spire Warden (`boss_spire_warden`, 280 HP)

Towering shattered-glass and Najdi-arch guardian of Empty Riyadh's dead mall courtyard (`#161B33` cloak, `#C68B59` architectural mantle, `#F6E299` luminous fracture lines, `#4F6D7A` glass halberd).

| Animation State | Drop-In Filename | Canvas (px) | Frames | FPS | Pivot (x, y) | Combat Telegraph & Readability |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| `idle` | `spire_warden/warden_idle_strip8.png` | `256 × 288` | 8 | 10 | `(128, 272)` | Tall poised silhouette (~220 px), floating cracked glass halo behind crown |
| `glide_move` | `spire_warden/warden_move_strip6.png` | `256 × 288` | 6 | 12 | `(128, 272)` | Regal drifting advance across cracked marble tiles |
| `halberd_telegraph` | `spire_warden/warden_halberd_tel_strip6.png` | `320 × 288` | 6 | 10 | `(160, 272)` | `0.60s` wide horizontal pull-back; blade edge flashes pale gold (clear parry cue) |
| `halberd_sweep` | `spire_warden/warden_halberd_atk_strip6.png` | `384 × 288` | 6 | 20 | `(192, 272)` | Long sweeping glass halberd lunge cleave (parryable) |
| `spire_shards_cast` | `spire_warden/warden_cast_strip8.png` | `288 × 320` | 8 | 14 | `(144, 304)` | Raises halberd skyward; triggers 3 vertical gold floor telegraph beams (`warden_beam_fx.png`, `96 × 640`) + falling shards (`warden_shard_drop.png`, `64 × 128`) |
| `vault_slam` | `spire_warden/warden_vault_strip10.png` | `320 × 320` | 10 | 18 | `(160, 304)` | High arcing leap -> downward impact -> low jumpable/dashable shockwave (`warden_shockwave_fx.png`, `256 × 96`) |
| `phase2_roar` | `spire_warden/warden_phase2_strip10.png` | `320 × 320` | 10 | 14 | `(160, 304)` | At ≤50% HP: armor cracks widen with blazing `#F6E299` Citadel light; summons twin orbiting parryable shards |
| `twin_beam_sweep` | `spire_warden/warden_twin_beam_strip8.png` | `352 × 288` | 8 | 16 | `(176, 272)` | Phase 2 sweeping dual light lances |
| `stagger` | `spire_warden/warden_stagger_strip4.png` | `256 × 288` | 4 | 10 | `(128, 272)` | `1.4s` vulnerable kneel after Farid's Parry (`1.35×` damage window) |
| `defeat` | `spire_warden/warden_defeat_strip12.png` | `320 × 320` | 12 | 12 | `(160, 304)` | Halberd plants upright into mall tiles as fractured cloak dissolves into rising pale-gold memory motes |

### 7.3 Milestone 2–4 Enemy & Boss Placeholder Manifest Slots

| Milestone | Entity | Drop-In Directory | Canvas (px) | Core States | Special Shader / Visual Hook |
| :---: | :--- | :--- | :---: | :--- | :--- |
| **M2/M3** | **Jinn — Mirage Wisp / Desert Sentinel** | `/assets/final/enemies/jinn/` | `160 × 192` | `veiled_idle`, `true_form_reveal`, `gaze_charge`, `smoke_vanish` | Invisible/shimmering until **Grey Eye** active; golden gaze telegraph supports **Don't-Look Rule** (respectful smokeless-flame folklore aesthetic) |
| **M2/M3** | **Beam Cultists (Acolyte / Prism Bearer)** | `/assets/final/enemies/beam_cult/` | `144 × 160` | `patrol`, `prism_channel`, `beam_sweep`, `stagger`, `defeat` | Fictional crystalline lantern robes in indigo & glass teal; geometric prism staves (zero real-faith emblems) |
| **M4** | **Grey-Eyed Other Self (Citadel Final Boss)** | `/assets/final/bosses/other_self/` | `224 × 192` | Mirrors Farid's full moveset + `citadel_orb_rain`, `mirror_parry`, `embrace_merge` | Same silhouette proportions as Farid in muted silver-grey `#8B95A5` cloak & glowing grey eyes; **defeat ends in a luminous two-silhouette Merge animation, never killing** |

---

## 8. Interactables & World FX Manifest

**Drop-In Directory:** `/assets/final/interactables/` and `/assets/final/fx/`

| Interactable / FX | Scene File | Drop-In Filename | Canvas (px) | Frames | FPS | Pivot (x, y) | Shader Slot | Visual Notes |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: | :--- | :--- |
| **Orb Shrine** | `orb_shrine.tscn` | `orb_shrine/shrine_stele.png` + `shrine_lantern_strip6.png` | `160 × 192` | 1 + 6 | 10 | `(80, 184)` | `painterly_silhouette` (stele) + `orb_glow` (lantern) | Najdi mud-brick stele with stepped *shurfat*, triangular *furjat* slits, arched niche, suspended gold orb, glowing ground ring |
| **Orb Shrine Pulse FX** | `orb_shrine.tscn` | `/assets/final/fx/shrine_pulse_strip8.png` | `384 × 384` | 8 | 18 | `(192, 192)` | Additive / `orb_glow` | Radiating pale-gold shockwave & rising motes on rest (capped when `reduce_flash = true`) |
| **Memory Orb** | `memory_orb.tscn` | `memory_orb/orb_loop_strip8.png` + `orb_absorb_strip6.png` | `128 × 128` | 8 + 6 | 12 | `(64, 64)` | `orb_glow.gdshader` | Pale-gold translucent sphere `#F6E299` with white-gold core & orbiting memory rings |
| **Torn Notebook Page** | `notebook_page.tscn` | `notebook_page/page_flutter_strip6.png` | `64 × 64` | 6 | 10 | `(32, 56)` | None / subtle gold glint | Cream parchment `#EFE0BE` caught on sand/debris with faint RTL Arabic ink lines `#2A2233` |
| **Time Shift Anchor** (M2) | `time_shift_anchor.gd` | `time_shift/anchor_idle_strip8.png` + `shift_ripple_strip10.png` | `144 × 208` | 8 + 10 | 12 | `(72, 196)` | `orb_glow` (warm/cool blend) | Suspended fractured glass hourglass prism refracting 2034 warm gold on one side and 2054 cool indigo on the other |
| **Grey Eye Seal** (M2) | M2 rooms | `grey_eye/seal_dormant.png` + `seal_revealed_strip8.png` | `160 × 224` | 1 + 8 | 12 | `(80, 212)` | `painterly_silhouette` | Subtle chalk-like invisible wall / locked arch that blossoms into luminous `#8B95A5` Citadel filigree under Grey Eye vision |
| **Shortcut Gate** | `shortcut_gate.gd` | `props/shortcut_gate_closed.png` + `shortcut_gate_open.png` | `128 × 224` | 1 + 4 | 12 | `(64, 216)` | `painterly_silhouette` | Weathered iron & Najdi timber service gate linking Empty Riyadh back to Desert Camp |
| **Tutorial Cairn / Sign** | `tutorial_sign.gd` | `props/tutorial_cairn.png` | `80 × 96` | 1 | — | `(40, 90)` | `painterly_silhouette` | Stacked desert sandstone cairn / tilted highway sign post with subtle amber marker |

---

## 9. Environments, Tilesets & Parallax Layers

### 9.1 Tileset & Modular Platform Specification
- **Tile Cell Size:** `64 × 64 px` modular painterly tiles (seamlessly painted with soft brush overlaps so tiles never feel grid-rigid).
- **Drop-In Path:** `/assets/final/environments/<area_id>/tiles_<area_id>.png` (`512 × 512 px` atlas: solid fill, top sand/asphalt/marble cap, left/right cliff edges, inner corners, cracked one-way ledges, Najdi *shurfat* trim).
- **Readability Rule:** Playable floor top edges ALWAYS carry a crisp `4–6 px` sunlit ochre (`#E8C49A` / `#C68B59`) or glass-teal (`#4F6D7A`) highlight lip separating walkable ground from deep background layers.

### 9.2 Milestone 1 Areas — Exact Multi-Layer Parallax Specs (1920×1080 Base)

#### Area 1: Desert Camp (`desert_camp_01`, `desert_camp_02`)
*Mood:* Melancholic late sunset — crimson-orange sky cooling toward dusk; quiet wind over soft dunes; distant ruined Riyadh towers barely visible on the eastern horizon.

| Layer | Parallax `motion_scale` | Plate Size (px) | Drop-In Path | Shader Slot | Palette & Motifs |
| :---: | :---: | :---: | :--- | :--- | :--- |
| **L0 Sky** | `(0.0, 0.0)` | `1920 × 1080` | `environments/desert_camp/l0_sky.png` | `painterly_canvas` | Vertical dusk wash `#A84432` -> `#E07A3C` -> `#E8C49A` low sun haze |
| **L1 Far Horizon** | `(0.12, 0.04)` | `2560 × 1080` | `environments/desert_camp/l1_far_skyline.png` | `painterly_canvas` | Distant Tuwaiq mesa ridge + faint ghostly silhouette of ruined Riyadh spires to the east |
| **L2 Mid Dunes** | `(0.35, 0.10)` | `2560 × 1080` | `environments/desert_camp/l2_mid_dunes.png` | `painterly_canvas` | Sweeping ochre & desert-red dunes, distant palm grove silhouettes |
| **L3 Camp Midground** | `(0.65, 0.25)` | `2800 × 1080` | `environments/desert_camp/l3_camp_props.png` | `painterly_canvas` | Bedouin tent (*bayt al-sha'r*) with lantern glow, wind-carved sandstone arches, woven poles |
| **L4 Gameplay Layer** | `(1.0, 1.0)` | Modular `64 px` + props | `environments/desert_camp/tiles_desert_camp.png` | `painterly_silhouette` (props) | Walkable dune ledges, ravine canyon floor, Orb Shrine, Boy, Amira, Memory Orb #1 |
| **L5 Foreground Veil** | `(1.22, 1.05)` | `1920 × 1080` tile | `environments/desert_camp/l5_fg_frame.png` + `sand_wind` | `sand_wind.gdshader` | Dark `#0D1021` silhouetted desert scrub framing bottom corners + drifting warm sand veil (`density = 0.28`) |

#### Area 2: Empty Highway (`empty_highway_01`, `empty_highway_02`)
*Mood:* Twilight transition — sunset fading into deep indigo; silent abandoned multi-lane approach road, tilted Arabic-script-style highway gantries, lone silhouette of Motaib overlooking the road.

| Layer | Parallax `motion_scale` | Plate Size (px) | Drop-In Path | Shader Slot | Palette & Motifs |
| :---: | :---: | :---: | :--- | :--- | :--- |
| **L0 Sky** | `(0.0, 0.0)` | `1920 × 1080` | `environments/empty_highway/l0_sky.png` | `painterly_canvas` | Twilight gradient `#161B33` top -> `#A84432` -> `#D66838` low western band |
| **L1 Far Riyadh** | `(0.15, 0.05)` | `2560 × 1080` | `environments/empty_highway/l1_riyadh_approach.png` | `painterly_canvas` | Looming broken glass towers growing closer on the east horizon |
| **L2 Overpass Piers** | `(0.40, 0.15)` | `2560 × 1080` | `environments/empty_highway/l2_piers.png` | `painterly_canvas` | Repeating concrete viaduct columns, half-buried streetlight poles |
| **L3 Abandoned Traffic** | `(0.72, 0.30)` | `3200 × 1080` | `environments/empty_highway/l3_vehicles.png` | `painterly_canvas` | Silent silhouettes of dust-covered sedans, coaches, tilted tollway canopies |
| **L4 Gameplay Layer** | `(1.0, 1.0)` | Modular `64 px` + props | `environments/empty_highway/tiles_highway.png` | `painterly_silhouette` (props) | Cracked asphalt, bus roofs, overpass deck (Motaib), vertical concrete wall-cling chimney (`220 px` wide) |
| **L5 Foreground Veil** | `(1.25, 1.08)` | `1920 × 1080` tile | `environments/empty_highway/l5_fg_gantry.png` + `sand_wind` | `sand_wind.gdshader` | Passing dark silhouette guardrail/sign trusses + heavier ochre crosswind (`density = 0.24`) |

#### Area 3: Empty Riyadh & Shattered Mall (`empty_riyadh_01`, `empty_riyadh_boss`)
*Mood:* Night indigo silence broken by pale-gold moonlight and shattered glass reflections; grand dead mall atrium combining modern glass architecture with Najdi geometric facade cutouts.

| Layer | Parallax `motion_scale` | Plate Size (px) | Drop-In Path | Shader Slot | Palette & Motifs |
| :---: | :---: | :---: | :--- | :--- | :--- |
| **L0 Sky** | `(0.0, 0.0)` | `1920 × 1080` | `environments/empty_riyadh/l0_sky.png` | `painterly_canvas` | Deep Night Indigo `#0D1021` -> `#161B33` with subtle cold teal haze |
| **L1 Broken Towers** | `(0.15, 0.05)` | `2560 × 1080` | `environments/empty_riyadh/l1_towers.png` | `painterly_canvas` | Original fractured Riyadh skyline spires catching faint pale-gold moonlight |
| **L2 Mall Atrium Vault** | `(0.42, 0.18)` | `2800 × 1280` | `environments/empty_riyadh/l2_atrium_vault.png` | `painterly_canvas` | Shattered arched glass roof trusses, silent upper shopfronts, Najdi star latticework |
| **L3 Interior Pillars** | `(0.70, 0.35)` | `3200 × 1280` | `environments/empty_riyadh/l3_pillars.png` | `painterly_canvas` | Fractured marble columns, stopped escalators, faint warm coffee-cup table alcove hint |
| **L4 Gameplay Layer** | `(1.0, 1.0)` | Modular `64 px` + props | `environments/empty_riyadh/tiles_riyadh.png` | `painterly_silhouette` (props) | Glass walkways, boss courtyard floor, elevated glass balconies, Shortcut Gate, sealed Metro Gate |
| **L5 Foreground Veil** | `(1.20, 1.05)` | `1920 × 1080` tile | `environments/empty_riyadh/l5_fg_shards.png` + `sand_wind` | `sand_wind.gdshader` | Framed dark atrium arches + slow teal-silver dust drift (`sand_color = #4F6D7A`, `density = 0.16`) |

### 9.3 Full 14-Area World Overview (M1–M4 Parallax & Palette Guide)

| # | Area | Milestone | Primary Palette | Signature Architectural / Natural Motifs | Time Shift (`2034` ↔ `2054`) |
| :-: | :--- | :---: | :--- | :--- | :---: |
| 1 | **Desert Camp** | M1 | `#E07A3C`, `#A84432`, `#C68B59` | *Bayt al-sha'r* tent, palms, soft dunes, Orb Shrine | No (2054) |
| 2 | **Empty Highway** | M1 | `#D66838`, `#161B33`, `#C68B59` | Viaduct piers, silent cars/buses, tilted gantries | No (2054) |
| 3 | **Empty Riyadh** | M1 | `#0D1021`, `#161B33`, `#4F6D7A` | Shattered glass towers, dead mall atrium, Najdi screens | Optional M2 anchor |
| 4 | **Metro Tunnels** | M2 | `#0D1021`, `#4F6D7A`, `#F6E299` | Deep subterranean station vaults, stopped futuristic trains, emergency amber | Yes |
| 5 | **Diriyah / At-Turaif** | M2 | `#C68B59`, `#E07A3C`, `#6E4930` | Iconic mud-brick citadel walls, *shurfat* battlements, *furjat* triangular slits | Yes |
| 6 | **Wadi Hanifa** | M3 | `#C68B59`, `#4F6D7A`, `#E8C49A` | Limestone canyon walls, dry/flowing oasis stream (2034), date palm silhouettes | Yes |
| 7 | **Old Market (Souq)** | M3 | `#A84432`, `#C68B59`, `#F6E299` | Covered wooden colonnades, woven awnings, brass lanterns, silent stalls | Yes |
| 8 | **The Hideout (Under the House)** | M3 | `#161B33`, `#6E4930`, `#E07A3C` | Subterranean family cellar, childhood chalk marks, forgotten notebook shelf | Yes |
| 9 | **The Library** | M3 | `#161B33`, `#C68B59`, `#F6E299` | Towering carved bookshelves, dust-mote shafts, suspended Citadel diagrams | Yes |
| 10 | **Edge of the World (Tuwaiq Cliffs)** | M3 | `#E07A3C`, `#A84432`, `#0D1021` | Dramatic sheer limestone precipice overlooking endless desert sea; high-wind Glide zone | No |
| 11 | **Jinn Kingdom** | M3 | `#0D1021`, `#8B95A5`, `#F6E299` | Impossible desert-mirage arches, smokeless-ember braziers, Don't-Look corridors | Grey Eye required |
| 12 | **2034 Stadium** | M4 | `#F5D8A8`, `#4A90D9`, `#E07A3C` | Intact opening-night arena glowing warmly under evening sky, distant cheerful hum | **2034 Time Shift Only** |
| 13 | **The Citadel (Al-Ma'qil)** | M4 | `#0D1021`, `#F6E299`, `#8B95A5` | Cosmic cracked glass floor stretching beneath an endless sky of hanging pale-gold Memory Orbs | Cosmic / Timeless |
| 14 | **Memory Garden** | M4 | `#F6E299`, `#4A90D9`, `#E8C49A` | Quiet luminous courtyard of light-blossoming palms and glass water pools; final choice | Ending Space |

---

## 10. UI & Typography Art Slots (`DROP-002` — "Notebook & Ember" / دفتر وجمرة)

Supersedes the M1 Batch 1E placeholder table. All UI plates pair with Godot's native RTL layout (`ArabicFontSetup`), use PNG-32 straight-alpha sRGB (`Lossless` import preset), and carry **zero baked lettering** (the sole approved exception per Decision **D2** is `logo_shaala.png` on the Title Screen, plus universal hardware key symbols in `input_glyphs_kbm.png`). Full colour tokens, 9-slice margins, and input glyph cell indices live in [`docs/VISUAL_HANDOFF.md`](VISUAL_HANDOFF.md) (`DROP-002` §6).

### 10.1 Production OFL Fonts (`/assets/final/fonts/`)
| File Name | Family | Role | Notes |
| :--- | :--- | :--- | :--- |
| `reem_kufi_variable.ttf` (+ `ofl_reem_kufi.txt`) | Reem Kufi (wght 400–700) | `display` (Arabic) | Area banners, boss names, headings, 2034 signage |
| `aref_ruqaa_regular.ttf`, `aref_ruqaa_bold.ttf` (+ `ofl_aref_ruqaa.txt`) | Aref Ruqaa | `hand` (Arabic) | Vignettes, journal scraps, notebook headings, map labels (`line-height 1.95–2.0`) |
| `readex_pro_variable.ttf` (+ `ofl_readex_pro.txt`) | Readex Pro (wght 160–700) | `body` (AR + EN) & `display` (EN SemiBold +4% tracking) | Menus, settings, dialogue, prompts, toasts, numerals |
| `eb_garamond_italic_variable.ttf` (+ `ofl_eb_garamond.txt`) | EB Garamond Italic | `hand` (English) | English journal scraps, vignettes, map labels |

### 10.2 Production UI Ornaments (`/assets/final/ui/`)
| UI Element | Drop-In Path (`assets/final/ui/...`) | Canvas (px) | 9-Slice / Layout Notes |
| :--- | :--- | :---: | :--- |
| Hand-Lettered Title Logotype (D2) | `logo_shaala.png` | `1400 × 600` | `شعلة` with rising ember flame from final `ة`; transparent bg |
| HP Ember (Lit / Cold Ash) | `hp_ember_full.png`, `hp_ember_ash.png` | `48 × 64` | Distinct teardrop vs. hollow cracked-ash silhouettes (colour-blind safe) |
| Flame Strip Frame (Sadu) | `flame_strip_frame.png` | `320 × 24` | 9-slice `(12, 4, 12, 4)`; hollow window `x=12..308, y=7..17`; *furjat* notches at 35% & 70% |
| Flame Strip Sadu Fills (T0–T2) | `flame_strip_fill_t0.png`, `_t1.png`, `_t2.png` | `296 × 12` | Horizontally tileable Sadu weave (mud-brick → ember → pale gold) |
| Focus Cursor Ember | `focus_ember.png` | `32 × 32` | Ink-rimmed ember mark readable on both dark scrims & `#E4D7C0` paper |
| Najdi *Furjat* Divider & Toggles | `furjat_divider.png`, `furjat_toggle_on.png`, `_off.png` | `160 × 16` / `28 × 28` | Carved 5-triangle divider; filled ▲ / hollow △ toggles |
| Settings Sadu Slider & Knob | `slider_sadu_track.png`, `slider_ember_knob.png` | `400 × 12` / `28 × 28` | Track 9-slice `(12, 2, 12, 2)`; ink-rimmed faceted ember knob |
| Najdi *Shurfat* End-Cap | `shurfat_cap.png` | `48 × 24` | Mirrorable stepped mud-brick crenellation cap |
| Boss Health Bar Frame & Fill | `boss_bar_frame.png`, `boss_bar_fill.png` | `1200 × 28` / `1152 × 16` | Frame 9-slice `(48, 6, 48, 6)` with *shurfat* caps & hollow window `x=24..1176, y=7..21`; desert-red tileable fill |
| Open Notebook Spread | `notebook_spread.png` | `1536 × 928` | Symmetric ash-ivory (`#E4D7C0`) spread, exact spine `x=768`, transparent outer alpha, content-free |
| Sadu Bookmark Ribbons | `notebook_ribbon.png`, `notebook_ribbon_active.png` | `128 × 116` / `128 × 168` | Content-free Sadu woven ribbons hanging from Content page top edge (zero lettering) |
| Pasted Torn Journal Scraps | `paper_scrap_a.png`, `_b.png`, `_c.png` | `560 × 640` | Three unique hand-torn silhouettes (`≥ 48 px` clean inner margin); variant C carries subtle coffee-ring kiss |
| Torn Spine Stub | `torn_stub.png` | `40 × 120` | Jagged spine stub (`x=40` spine edge), mirrorable for LTR |
| Confirm Dialog Paper Slip | `paper_slip.png` | `640 × 320` | 9-slice `(48, 48, 48, 48)` deckled ash-ivory confirm slip |
| Soft Bottom Scrim | `scrim_bottom.png` | `16 × 360` | Vertical gradient `rgba(13,16,33,0.0)` → `0.80`; stretch horizontally (no hard box) |
| Save Indicator Ember | `save_ember.png` | `48 × 48` | Breathing bottom-end save flame |
| Notebook Ink Map Icons (6) | `map_icon_{player,shrine,boss,gate_sealed,page,shortcut}.png` | `32 × 32` | Ink-on-paper silhouettes matching `#241914` / `#8C2D1E` / `#E07A3C` |
| Input Glyph Atlases (KBM & Pad) | `input_glyphs_kbm.png`, `input_glyphs_pad.png` | `512 × 512` (`64 × 64` cells) | Generic ink/ember glyphs; zero console brand logos; cell table in `VISUAL_HANDOFF.md` §6.6 |
