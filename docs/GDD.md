# SHAALA (شعلة) — Game Design Document

**Title:** SHAALA | شعلة (*"Flame"*)  
**Genre:** Original 2D Painterly Action-Exploration Metroidvania  
**Engine & Language:** Godot 4.3 (Strictly Typed GDScript)  
**Primary Language:** Arabic (Modern Standard Arabic / الفصحى) with full English (`en`) support & live RTL/LTR switching  
**Target Resolution & Frame Rate:** `1920×1080` (`canvas_items`, `expand`), `60` physics ticks/sec, pixel-snapping disabled  
**Document Version:** `0.1.0-M1` (Vertical Slice Baseline)

---

## 1. Premise, Narrative Spine, Themes & Content Rules

### 1.1 Premise
Loosely inspired by the emotional spine, themes, and Riyadh landmarks of the novel *Shaala* (reimagined for interactive exploration rather than a literal retelling), **Farid (فريد)** wakes inside a woven desert tent (*bayt al-sha'r*) south of Riyadh with no memory of who he is. A small boy gently nudges him awake with a wooden stick, calling him **"أبي"** (*Abi* — Father). Beside the tent rests the Arabian camel **Amira (أميرة)** and a tattered notebook with missing pages. To the north rises the broken silhouette of a city emptied twenty years earlier: in **2034**, a blinding beam of light swept across Riyadh, vanishing its people and freezing its glass towers in dust. It is now **2054**.

Farid was once the guardian of **the Citadel (*Al-Ma'qil* / المعقل)** — a cosmic sanctuary beyond Earth where every human memory hangs like a pale-gold glowing orb. Long ago, he broke the gate linking the Citadel to Earth so he could walk away from eternity and live an ordinary life beside his wife **Ithar (إيثار)** and his child. The price of breaking that gate was his memory. Across ruined Riyadh, **every ability Farid regains is a memory returning**.

### 1.2 Core Themes
- **Memory and Identity:** Who remains when remembrance is stripped away — the guardian of cosmic order, or the father who gave it up?
- **The Price of Choosing Family Over the World:** Farid's love for Ithar and his son was real and defiant, yet breaking the gate left the world vulnerable to the Beam.
- **Grief Shown in Silence, Not Gore:** Loss is conveyed through empty streets, untouched dinner tables, wind through fractured glass, and quiet pauses — never shock violence.

### 1.3 Content & Cultural Respect Rules
1. **Implied Loss Only:** The deaths of Farid's son and Ithar are strictly implied through memory vignettes, stillness, and empty spaces — **never shown graphically** and never accompanied by gore.
2. **Respectful Treatment of Heritage & Faith:** Saudi and Najdi architecture, customs, language, religion, and Jinn folklore are portrayed with accuracy, dignity, and reverence.
3. **Fictional Antagonist Sect:** **The Beam Cult** (*Seekers of the Beam* / أتباع الشعاع) is an entirely fictional esoteric sect driven by obsession with the 2034 event and the Citadel; it does not depict, parody, or allude to any real-world faith or group.
4. **Original Expression:** Zero real-world copyrighted song lyrics, zero licensed recordings, and strictly original visual and gameplay identity.

### 1.4 Intentional Unanswered Mysteries
Three narrative threads are purposefully seeded through environmental clues and Torn Notebook Pages and **must remain unresolved** across the entire game:
1. **The Children and the Uncle:** What happened to the children and the uncle after the attack on the neighborhood.
2. **The Throne:** Who sits upon the distant throne glimpsed through fractures of the Citadel.
3. **The Man with the Coffee Cup:** The quiet recurring figure holding an Arabic coffee cup (*finjan* / فنجان القهوة) at the edges of memory — subtly referenced in Notebook Page #2 (`PAGE_MALL_BODY`) and later visions, never explained.

### 1.5 Milestone Roadmap
| Milestone | Scope |
| :--- | :--- |
| **M1 (Current)** | Vertical Slice: Desert Camp (`01–02`), Empty Highway (`01–02`), Empty Riyadh (`01`, `boss`); core movement + Dash + Wall-Cling; 3-tier Flame Dagger + Flame Spell + Parry; 3 enemies + 1 boss; 2 Memory Orbs + 1 Orb Shrine + 3 Notebook Pages; atomic save/load; Arabic-first RTL UI & EN toggle. |
| **M2** | Time Shift (`2034`/`2054`) + Grey Eye vision; Diriyah/At-Turaif + Metro Tunnels; expanded world map; 2 bosses. |
| **M3** | All 14 areas greyboxed with complete ability gating, Don't-Look Jinn zones, Motaib boss duel, and remaining boss prototypes. |
| **M4** | Full narrative pass, all 12 Torn Notebook Pages, Citadel merge climax, Revenge & True Endings (2034 Stadium), full MSA/EN localization pass. |
| **M5** | Final hand-drawn art drop-in (`/assets/final/`), audio mastering, combat juice, accessibility audit, 60 FPS optimization, and polish. |

---

## 2. Movement & Physics System

Farid's traversal is built for crisp, responsive 2D platforming at `60` physics ticks per second on a `1920×1080` canvas. Farid's collision hull is a `CapsuleShape2D` (`radius = 14 px`, `height = 62 px`, approx. `28×62 px`), using a finite state machine (`PlayerStateMachine`) cleanly separating Idle, Run, Jump, Fall, Wall-Cling, Dash, Ground-Pound, Glide, Attack, Cast Spell, Parry, Hurt, and Dead states.

### 2.1 Canonical Physics Constants
| Parameter | Constant Name | Value | Design Intent |
| :--- | :--- | :--- | :--- |
| Horizontal Run Speed | `RUN_SPEED` | `380.0 px/s` | Snappy pace suited to broad desert vistas and ruined boulevards. |
| Ground Accel / Decel | `GROUND_ACCEL` / `GROUND_DECEL` | `2800.0` / `3200.0 px/s²` | Near-instant start and crisp stopping with zero icy drift. |
| Air Accel / Decel | `AIR_ACCEL` / `AIR_DECEL` | `2000.0` / `1400.0 px/s²` | Strong mid-air spacing control without feeling weightless. |
| Gravity / Terminal Fall | `GRAVITY` / `MAX_FALL_SPEED` | `1550.0 px/s²` / `980.0 px/s` | Grounded arc that makes landing readable in combat. |
| Jump Velocity | `JUMP_VELOCITY` | `-640.0 px/s` | Max vertical apex ≈ `132 px`; safe level ledge step `<= 105 px`. |
| Variable Jump Height | `VARIABLE_JUMP_CUT` | `0.45` | Releasing `jump` early scales upward velocity to 45% for short hops. |
| Coyote Time | `COYOTE_TIME` | `0.12 s` | Allows jumping briefly after stepping off a ledge edge. |
| Jump Buffering | `JUMP_BUFFER_TIME` | `0.12 s` | Queues jump input pressed just before touchdown. |
| Dash Speed / Duration | `DASH_SPEED` / `DASH_DURATION` | `860.0 px/s` × `0.22 s` | `~189 px` flat burst; Jump + Dash horizontal reach ≈ `480 px`. |
| Dash Cooldown | `DASH_COOLDOWN` | `0.40 s` | 1 air dash per airborne phase; resets on floor or wall contact. |
| Wall-Slide Speed | `WALL_SLIDE_SPEED` | `130.0 px/s` | Controlled descent along Najdi mud-brick walls and highway pylons. |
| Wall-Jump Velocity | `WALL_JUMP_VELOCITY` | `Vector2(440.0, -610.0)` | Crisp outward kick with `WALL_JUMP_LOCK = 0.14 s` to prevent immediate wall re-sticking. |
| Double Jump Velocity | `DOUBLE_JUMP_VELOCITY` | `-590.0 px/s` | M2/M3 mid-air vertical boost; resets on ground or wall contact. |
| Ground-Pound Speed | `GROUND_POUND_SPEED` | `1050.0 px/s` | M3 downward slam (`move_down` + `jump`/`attack` mid-air); shatters cracked floor slabs. |
| Glide Fall Speed | `GLIDE_FALL_SPEED` | `110.0 px/s` | M3/M4 cloak-assisted slow descent (`hold jump` while falling); catches Tuwaiq updrafts. |

### 2.2 Level Geometry Metrics (Softlock Prevention Contract)
- **Normal Jump Reach:** Max height `~132 px` (design safe ledges `<= 105 px`), max horizontal gap `~310 px` (design normal gaps `<= 220 px`).
- **Dash Gate Standard:** Chasms gated by `dash` span **`360–410 px`** (uncrossable with normal jump, comfortably cleared with Jump + Dash, always backed by a safe return floor).
- **Wall-Cling Gate Standard:** Vertical chimneys gated by `wall_cling` span **`200–240 px`** wide and **`420–520 px`** tall.

### 2.3 Abilities as Returning Memories
| Ability ID | Name (AR / EN) | Milestone | Memory Orb ID | Returning Memory Theme |
| :--- | :--- | :--- | :--- | :--- |
| `flame_spell` | تعويذة الشعلة / Flame Spell | M1 (Start) | Innate ember | Faint muscle memory of the Citadel's warm hearth. |
| `dash` | الاندفاع / Desert Dash | M1 | `orb_desert_dash` | Running through windstorms to reach his child before dusk. |
| `wall_cling` | التعلّق بالجدار / Wall-Cling | M1 | `orb_highway_wall_cling` | Scaling old mud-brick walls above the silent highway. |
| `time_shift` | تحوّل الزمن / Time Shift | M2 | `orb_diriyah_time_shift` | Remembering 2034 before the sky fractured. |
| `grey_eye` | العين الرمادية / Grey Eye | M2 | `orb_wadi_grey_eye` | The guardian's sight piercing illusion and Jinn veils. |
| `double_jump` | القفزة المزدوجة / Double Jump | M2/M3 | `orb_metro_double_jump` | Stepping off light itself inside the Citadel's halls. |
| `ground_pound` | الضربة الأرضية / Ground-Pound | M3 | `orb_library_ground_pound` | The weight of breaking the gate to stay on Earth. |
| `glide` | الانزلاق الهوائي / Desert Glide | M3 | `orb_tuwaiq_glide` | Riding the Tuwaiq cliff winds toward the horizon. |

---

## 3. Combat System

Combat balances deliberate spacing, defensive poise (Parry), and momentum-rewarding aggression via the **Flame Resource Meter (`0.0–100.0`)**. Rather than treating energy solely as a spendable mana bar, holding Resource actively empowers Farid's blade — creating a constant tactical tension between keeping a blazing Tier-2 dagger or spending Resource to cast a piercing Flame Spell.

### 3.1 Flame Dagger (خنجر الشعلة) — 3-Tier Resource Scaling
Farid performs a responsive **3-hit directional slash combo** (left, right, upward, and aerial downward pogo strike). Every landed strike awards **`+12.0` Resource**, `0.035 s` hitstop (`EventBus.hitstop_requested`), and `dagger_hit` SFX.

| Tier | Resource Range | Damage | Reach | Visual Silhouette & Glow |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 0** (`UI_DAGGER_TIER_0`) | `0.0 – 34.9` | `10` | `72 px` | Short warm orange ember arc (`#E07A3C`). |
| **Tier 1** (`UI_DAGGER_TIER_1`) | `35.0 – 69.9` | `15` | `96 px` | Extended bright orange-gold flame blade (`#E07A3C` → `#F6E299`). |
| **Tier 2** (`UI_DAGGER_TIER_2`) | `70.0 – 100.0` | `22` | `124 px` | Blazing pale-gold crescent wave (`#F6E299`) with trailing ash motes. |

### 3.2 Ranged Flame Spell (`flame_spell`)
- **Cost:** `25.0` Resource (`GameState.spend_resource(25.0)`).
- **Projectile (`FlameProjectile`):** Travels horizontally at `760 px/s`, deals **`24` damage** (`damage_type = "flame"`).
- **Tactical Role:** Punishes airborne enemies (`Shard Husk`), breaks frontal guards (`Relic Sentinel`), and triggers distant braziers without committing to melee range.

### 3.3 Parry & Stagger System (`parry_state.gd`)
- **Timing:** **`0.18 s`** active parry window, **`0.35 s`** cooldown.
- **Reward on Success:** Negates 100% of incoming damage from any attack flagged `parryable == true`, grants **`+25.0` Resource**, emits `0.08 s` hitstop + camera shake (`intensity = 7.0`, `duration = 0.14 s`) + pale-gold seal ring flash, and invokes `on_parried()` on the attacker.
- **Enemy/Boss Stagger:** Parried enemies enter `STAGGERED` for **`1.2 s`** (bosses **`1.4 s`**), glowing pale gold and receiving **`1.35×` damage** from follow-up strikes.

### 3.4 Health, Invulnerability & Physics Layer Contract
- Farid starts with **`5` Max HP** (displayed as desert-red flame pips). Taking damage applies knockback and **`0.85 s`** invulnerability frames. Reaching `0` HP enters `DeadState` and respawns Farid at the last rested Orb Shrine.
- **Canonical 2D Physics Layers (1-indexed):**
  - Layer 1 (`1`): `world` — solid static terrain.
  - Layer 2 (`2`): `one_way` — drop-through/jump-through balconies & beams.
  - Layer 3 (`4`): `player` — Player body & Player `Hurtbox` (`monitorable=true, monitoring=false`).
  - Layer 4 (`8`): `enemy` — Enemy/Boss body & Enemy `Hurtbox` (`monitorable=true, monitoring=false`).
  - Layer 5 (`16`): `player_hitbox` — Player `Hitbox` (`monitoring=true, mask=8` detects layer 4).
  - Layer 6 (`32`): `enemy_hitbox` — Enemy/Boss `Hitbox` (`monitoring=true, mask=4` detects layer 3).
  - Layer 7 (`64`): `interactable` — Shrines, Orbs, Pages, NPCs, Transition Gates (`mask=4`).
  - Layer 8 (`128`): `hazard` — Environmental hazards & spikes.

---

## 4. Memory Orbs & Orb Shrines

### 4.1 Memory Orbs (كرات الذكرى)
- **Presentation:** Suspended pale-gold (`#F6E299`) spheres rendered with `orb_glow.gdshader`, drifting silently in quiet alcoves or after overcoming a trial.
- **Interaction Flow:** Pressing `interact` freezes player controls (`player.set_controls_enabled(false)`), records the orb in `GameState.collected_orbs`, unlocks its paired ability (`GameState.unlock_ability(ability_id)`), auto-saves (`SaveManager.save_game()`), and launches `VignettePlayer` to present a short 3-line poetic Modern Standard Arabic / English memory vignette before awarding the Ability Unlocked banner.
- **Persistence:** Collected orbs free themselves automatically on room reload (`if orb_id in GameState.collected_orbs: queue_free()`).

### 4.2 Orb Shrines (مزارات الكرات)
- **Presentation:** Weathered Najdi mud-brick steles with triangular *furjat* carvings holding a warm hanging pale-gold orb lantern above an inscribed ground seal.
- **Mechanics:** Interacting triggers `GameState.rest_at_shrine(shrine_id, room_id)`:
  1. Restores Farid's HP to `player_max_hp`.
  2. Sets `last_shrine_id` and `last_shrine_room_id` as the active respawn anchor.
  3. Writes an atomic JSON save file to `user://saves/slot_0.json` (`schema_version = 1`).
  4. Triggers a golden ring burst, `shrine_rest` oud chord, and localized saved toast (`UI_RESTED_AT_SHRINE`).
- **M1 Placement:** `shrine_desert_camp` in `desert_camp_01`, looped back via `shortcut_riyadh_to_camp` from `empty_riyadh_01` so players can quickly rest before challenging the M1 boss.

---

## 5. Time Shift System (2034 / 2054 Room State)

Unlocked in Milestone 2 (`time_shift`) inside Diriyah / At-Turaif, **Time Shift** lets Farid fold a room between two moments separated by twenty years without changing spatial coordinates:

| Era State | Visual Palette & Atmosphere | Architectural & Gameplay State |
| :--- | :--- | :--- |
| **`"2054"` (Default — Ruins)** | Deep sunset red, cold glass teal, night indigo shadows, windborne dust. | Collapsed highway overpasses, breached security doors, broken mall escalators, silent emptiness. |
| **`"2034"` (Pre-Beam — Intact)** | Warm dusk ochre, golden streetlights, soft silhouetted crowds frozen at the moment before the Beam. | Intact bridges and walkways, locked gates still sealed, powered metro rails, and the **2034 Stadium** (Area 12, accessible exclusively via Time Shift). |

### Technical Implementation (M1 Scaffolded, M2 Active)
- Every room inheriting `RoomBase` exposes `supports_time_shift: bool` and `apply_era(era: String)`, toggling sibling `Era2054` and `Era2034` `Node2D` geometry/lighting containers while preserving Farid's exact position (with a safe-eject check to prevent clipping into solid 2034 masonry).
- **Time Shift Anchors** (`TimeShiftAnchor`) are crystalline fractures placed in supported rooms; interacting toggles `GameState.set_era(...)` and emits `EventBus.era_changed(era)`, updating the HUD Era badge (`UI_ERA_2054` / `UI_ERA_2034`) and ambient soundscape.

---

## 6. Grey Eye Seal Vision & The Don't-Look Rule

### 6.1 Grey Eye Seal Vision (`grey_eye`, M2)
Farid's heterochromia — **left eye grey (`#8B95A5`), right eye blue (`#4A90D9`)** — is both narrative emblem and gameplay tool. Toggling `grey_eye` awakens his dormant Citadel sight:
- **Cost:** Steadily drains the Flame Resource meter (`~8.0 / s`) while active; automatically deactivates at `0` Resource or when toggled off.
- **Reveals:** Hidden pale-gold Citadel seal-paths, illusory mud-brick walls concealing Torn Notebook Pages, spectral footprints from 2034, and invisible Jinn presences.
- **Readability:** Applies a subtle indigo-silver rim vignette (`EventBus.grey_eye_toggled`) that respects `SettingsManager.reduce_flash`.

### 6.2 The Don't-Look Rule (قاعدة عدم النظر — Jinn Zones, M2–M3)
In liminal Jinn territories (deep Wadi Hanifa and the Jinn Kingdom), ancient etiquette dictates that mortals must not stare directly at an unveiled Jinn.
- **Fair Telegraphing:** Before a Jinn initiates a Gaze Phase, a clear `0.85 s` golden-indigo halo blooms around its silhouette accompanied by a resonant low oud/bell harmonic and directional screen-edge chime — giving ample reaction time even in hectic fights.
- **Facing Penalty:** Looking directly at an active Gaze Jinn drains Farid's **Clarity/Sanity** gauge (visualized through darkening indigo vignette edges and muffled wind), culminating in a staggered mental shock if ignored.
- **Turning Away Counterplay:** Turning Farid's facing direction **away** from the Jinn completely halts Clarity drain and **blocks gaze-based attacks**. Players fight and navigate using back-steps, wall-clings facing outward, Parry cues, and brief glances between Gaze Phases.
- **M1 Architectural Hook:** `EnemyBase` exposes `supports_dont_look_rule: bool = false` so M2/M3 Jinn subclasses plug directly into the existing combat framework.

---

## 7. Torn Notebook Pages & Ending Structure

### 7.1 Torn Notebook Pages (صفحات الدفتر الممزق)
- **Count:** **12 pages** total across all 14 areas (**3 pages** playable in M1: `page_00_camp`, `page_01_highway`, `page_02_mall`).
- **Dual Function:**
  1. **Journal Entries:** Hand-penned fragments of Farid's lost days with Ithar, the Beam, and unanswered mysteries — readable in full RTL Modern Standard Arabic or English inside the Pause Menu's Notebook tab.
  2. **Map Fragments:** Each page illuminates hidden landmarks and secret room silhouettes on the world map.
- **Ending Requirement:** Collecting all 12 Torn Notebook Pages unlocks the choice for the **True Ending** in Area 14.

### 7.2 Climax & Dual Endings (M4)
1. **The Citadel (*Al-Ma'qil*, Area 13):** Farid crosses a vast cracked glass floor reflecting an infinite sky of pale-gold memory orbs.
2. **Final Duel — The Grey-Eyed Other Self:** Farid faces the sovereign guardian version of himself who never broke the gate. The duel mirrors Farid's full movement and dagger kit, culminating **not in a killing blow, but in a quiet embrace and merging** as both silhouettes become one.
3. **The Memory Garden (Area 14) — Final Choice:**
   - **Ending 1 — Revenge / Dominion (نهاية الانتقام):** Farid reclaims all cosmic Citadel authority to pursue the architects of the Beam. The power floods back; both of Farid's eyes turn cold **grey (`#8B95A5`)**.
   - **Ending 2 — True Ending (النهاية الحقيقية — requires 12/12 Torn Notebook Pages):** Farid relinquishes the Citadel's power altogether. The memory dissolves into warm stadium floodlights on **2034 opening night** (Area 12). Farid sits silently beside **Ithar** for one full, unhurried minute as distant crowd hum softens into desert wind. Final shot: both of Farid's eyes are clear **blue (`#4A90D9`)**.

---

## 8. Companion (Motaib), NPCs & Boss Design

### 8.1 Companion & Mid-Game Boss: Motaib (متعب)
- **Silhouette & Motif:** Broad-shouldered warrior clad in weathered desert-steel armor carrying **two great swords** strapped across his back.
- **Narrative Arc:**
  1. **Appearance 1 (M1 — `empty_highway_01`):** Stands watch upon a broken highway overpass (`DLG_MOTAIB_HWY_01..02`). Speaks sparsely, staring at Farid's mismatched eyes with troubled half-recognition.
  2. **Appearance 2 (M2 — Diriyah / Wadi Hanifa):** Briefly fights alongside Farid to hold back a Beam-shard ambush before parting toward the Old Market.
  3. **Mid-Game Boss Duel (M3 — Edge of the World / Old Market threshold):** The Beam's lingering fracture strips Motaib's memory of Farid. Convinced Farid is an intruder from the Citadel, Motaib confronts him with disciplined twin-greatsword combos. Winning through Parry breaks the haze without killing him, restoring their quiet bond.

### 8.2 Desert Camp NPCs (M1)
- **The Boy (`npc_boy`, `SPEAKER_BOY`):** Wakes Farid gently with a wooden stick, calls him **"أبي"** (`DLG_BOY_01..03`), and gestures toward the torn notebook and the silent skyline.
- **Amira (`camel_amira`, `SPEAKER_AMIRA`):** Farid's resting Arabian camel wrapped in a Najdi woven saddle cloth; offers quiet grounding (`DLG_AMIRA_01`).

### 8.3 M1 Enemies & Boss Roster
| Entity ID | Name (AR / EN) | HP | Behavior, Telegraph & Counterplay |
| :--- | :--- | :--- | :--- |
| `sand_stalker` | متعقّب الرمال / Sand Stalker | `35` | Dune-red quadruped; patrols with ledge-detection raycasts; `0.45 s` glowing crouch telegraph -> fast **parryable** lunge dash. |
| `shard_husk` | قشرة الشظايا / Shard Husk | `45` | Hovering fractured-glass indigo echo; `0.65 s` rotating gold shard ring telegraph -> aimed **parryable** glass-shard projectile. |
| `relic_sentinel` | حارس الأطلال / Relic Sentinel | `75` | Heavy Najdi-stone construct; front shield blocks low-tier melee (counter via **Parry**, **Flame Spell**, or flanking behind); `0.60 s` overhead windup -> heavy **parryable** cleave. |
| `boss_spire_warden` | **حارس البرج المتصدع / The Fractured Spire Warden** | `280` | **M1 Boss** in `empty_riyadh_boss`. Towering shattered-glass & Najdi-arch guardian (`2 phases`, Phase 2 at `<= 50%` HP). **Phase 1:** *Sweeping Glass Halberd* (parryable lunge cleave), *Falling Spire Shards* (3 vertical `0.70 s` gold telegraph beams requiring Dash), *Vaulting Slam* (high arc + jumpable/dashable shockwave). **Phase 2:** Faster recovery, *Twin Beam Sweep*, and 2 parryable orbiting shard projectiles before Vaulting Slam. Defeat opens exit, drops `page_02_mall`, and reveals the sealed M2 Metro gate. |

---

## 9. UI, Arabic-First RTL Localization & Accessibility

### 9.1 Arabic-First Localization Architecture
- **Default Locale:** `"ar"` (Modern Standard Arabic / الفصحى), fallback `"ar"`, live toggle to `"en"` on Title Screen and Pause/Settings Menu.
- **Zero Hardcoded Text:** 100% of user-facing strings (titles, HUD badges, interaction prompts, tutorials, area banners, dialogue, memory vignettes, notebook pages, boss names, settings) reside in `localization/strings.csv` (`keys,ar,en`) and are queried via `tr("KEY")`.
- **Runtime CSV Loader:** `SettingsManager._ready()` parses `res://localization/strings.csv` directly into Godot `Translation` resources registered with `TranslationServer`, ensuring full Arabic/English text works immediately even on cold launch or headless runs without requiring prior `.import` generation.

### 9.2 Godot 4 Advanced Text Server, RTL & BiDi Rules
- `ArabicFontSetup` configures a cross-platform `SystemFont` chain (`Geeza Pro`, `SF Arabic`, `Damascus`, `Noto Sans Arabic`, `Cairo`, `Amiri`, `Arial`) with full HarfBuzz Arabic shaping and automatically upgrades to bundled OFL `.ttf` fonts if present in `res://assets/final/fonts/`.
- On `EventBus.locale_changed(locale)`, `ui_root` dynamically switches `layout_direction` between `Control.LAYOUT_DIRECTION_RTL` (`ar`) and `Control.LAYOUT_DIRECTION_LTR` (`en`), mirroring HUD alignment, dialogue portraits, and menu rows seamlessly.
- All mixed strings containing numerals, slashes, or Latin keycaps (e.g., HP `5/5`, `[Space]`) wrap embedded LTR tokens in Unicode directional isolates (`\u2066`..`\u2069`) or apply `Control.STRUCTURED_TEXT_BIDI_OVERRIDE` so BiDi rendering never garbles.

### 9.3 Accessibility & Controls
- **Inputs:** Full simultaneous Keyboard + Gamepad support across all 14 actions (`move_left`, `move_right`, `move_up`, `move_down`, `jump`, `dash`, `attack`, `cast_spell`, `parry`, `interact`, `grey_eye`, `time_shift`, `toggle_map`, `pause`), with live key rebinding saved in `user://settings.json`.
- **Comfort Options:**
  - `screen_shake_scale` (`0.0`–`1.0`)
  - `reduce_flash` (`bool` — softens hit-flashes, parry bursts, and Grey Eye transitions)
  - `assist_game_speed` (`0.7`–`1.0` — lowers simulation speed for players wanting wider parry/platforming windows)
  - `gamepad_deadzone` (`0.1`–`0.5`)
  - Independent `master_volume`, `music_volume`, and `sfx_volume` sliders.

---

## 10. Technical Architecture, Art & Audio Direction

### 10.1 Core Godot 4.3 Architecture
- **Autoloads (Strict Load Order):**
  1. `EventBus` — Strictly typed signal hub decoupling player, enemies, interactables, rooms, camera, and UI.
  2. `GameState` — Authoritative runtime state (HP, Resource, dagger tier, unlocked abilities, collected orbs/pages, defeated bosses, opened shortcuts, explored rooms, era `"2054"`/`"2034"`, story flags).
  3. `SettingsManager` — User settings (`user://settings.json`), runtime CSV translation loader, locale switching, keybinding persistence, accessibility scales.
  4. `SaveManager` — Atomic JSON save/load at `user://saves/slot_0.json` (`schema_version = 1`).
  5. `AudioManager` — Mood-driven music controller + SFX dispatcher with headless-safe procedural `AudioStreamGenerator` placeholders.
- **Scene Streaming (`RoomManager` in `scenes/main.tscn`):** Loads rooms listed in `data/rooms.json` with fade transitions, positions Farid at the exact `Spawns/<spawn_id>` `Marker2D`, clamps `RoomCamera` to `room.camera_bounds`, and handles hitstop & shrine respawn cleanly.

### 10.2 Visual Direction & Palette (`ShaalaPalette`)
Hand-drawn 2D painterly silhouettes layered over soft, multi-plane parallax backdrops with authentic Saudi/Najdi geometry (*shurfat* mud-brick crenellations, *furjat* triangular vents, woven *bayt al-sha'r* tents, palm silhouettes, and abstract shattered Riyadh towers).

| Swatch Name | Hex | Role |
| :--- | :--- | :--- |
| `MUD_BRICK_OCHRE` | `#C68B59` | Najdi mud-brick ruins, Diriyah arches, warm stone ledges |
| `SUNSET_ORANGE` | `#E07A3C` | Desert dusk skies, rim lighting, Tier 0–1 dagger flames |
| `DESERT_RED` | `#A84432` | Red Nafud dunes, Farid's cloak trim, health ember pips |
| `NIGHT_INDIGO` | `#161B33` | Ruined Riyadh skyline, UI translucent panels, Farid's cloak |
| `DEEP_SHADOW` | `#0D1021` | High-contrast foreground silhouettes and boss framing |
| `PALE_GOLD_ORB` | `#F6E299` | Memory Orbs, Orb Shrines, Tier-2 dagger wave, UI borders |
| `FARID_EYE_GREY` | `#8B95A5` | Farid's **left eye** (Citadel guardian mark / Revenge ending) |
| `FARID_EYE_BLUE` | `#4A90D9` | Farid's **right eye** (Humanity & family / True ending) |
| `WARM_SAND_LIGHT` | `#E8C49A` | Highlight rims, parchment notebook pages, desert horizon glow |
| `GLASS_TEAL` | `#4F6D7A` | Broken skyscrapers, mall skylight shards, Shard Husks |

Four lightweight canvas shaders power the painterly look at 60 FPS: `painterly_canvas.gdshader`, `painterly_silhouette.gdshader`, `orb_glow.gdshader`, and `sand_wind.gdshader`. All M1 procedural visuals follow a 1:1 drop-in replacement manifest in `docs/ART_SPEC.md` targeting `/assets/final/`.

### 10.3 Audio Direction
- **Instrumentation:** Sparse solo **oud** phrases, warm **low strings**, subtle Najdi frame-drum heartbeat during boss transitions, and continuous multi-layered **ambient desert wind**.
- **Design Principle:** Restraint and negative space. Exploring ruined streets often drops the melody entirely, letting dry wind and footsteps carry the weight of twenty silent years.
- **M1 Implementation:** `AudioManager` synthesizes subtle desert wind and soft oud/chime feedback via `AudioStreamGenerator` (cleanly bypassed in headless mode), mapped by semantic SFX IDs (`dagger_hit`, `parry_clang`, `flame_cast`, `shrine_rest`, `orb_absorb`, `boss_roar`) ready for final studio stems in M5.
