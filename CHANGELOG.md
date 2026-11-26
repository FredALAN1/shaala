# Changelog

All notable changes to **SHAALA (شعلة)** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with milestone tags (`-M1` through `-M5`).

---

## [Unreleased]

### Performance
- **Hitch-free room transitions:** `RoomManager` now streams the current room's neighbors in the background (`ResourceLoader.load_threaded_request`) and keeps only the current room + neighbors resident. Measured headless on Godot 4.3: worst frame on first entry into a room dropped from **48–97 ms** to **9–16 ms**.
- **Power saving:** frame rate is capped at `15 FPS` while the window is unfocused and `30 FPS` while the pause menu is open (physics stays at 60 Hz; vignettes are not capped).
- **Ambient audio:** procedural wind/oud generator fills one `PackedVector2Array` per frame and calls `push_buffer()` once, instead of ~22,050 `push_frame()` calls per second.

### Visual Review
- Added tech review `VR-01..VR-11` to `docs/VISUAL_HANDOFF.md` (DROP-001 → `NEEDS_VISUAL_FIX`): parallax plate sizing vs. real `motion_scale`, foreground-veil overdraw, Farid sprite scale vs. 62 px capsule, Empty Riyadh platform contrast, shader uniforms for final painted art, texture budgets.

### Planned for M2
- Active **Time Shift** (`2034` / `2054`) room-state puzzles across Diriyah / At-Turaif and Metro Tunnels.
- **Grey Eye** seal vision (hidden paths, false Najdi walls, invisible Jinn detection) and initial Don't-Look Jinn encounters.
- Expanded interactive world map and 2 additional bosses (Metro Conduit Warden, Diriyah Mirage Guardian).

---

## [0.1.0-M1] - 2026-11-26

### Added

#### Design & Documentation
- **Game Design Document** ([docs/GDD.md](docs/GDD.md)): Complete specification of narrative spine, themes, respectful Saudi/Najdi cultural & content rules, intentional unanswered mysteries, movement physics constants, 3-tier Flame Dagger combat, Memory Orbs & Orb Shrines, Time Shift (`2034`/`2054`), Grey Eye & Don't-Look rule, Torn Notebook Pages & dual endings, Motaib companion arc, M1 boss design, Arabic-first RTL localization, accessibility, and audio direction.
- **World Graph & Room Contracts** ([docs/WORLD_GRAPH.md](docs/WORLD_GRAPH.md)): Interconnected 14-area world graph with Mermaid diagram, adjacency & ability-gate table, formal zero-dead-end verification, critical path, all 12 Torn Notebook Page locations, and exact 6-room M1 vertical slice specifications.
- **M1 Task Breakdown** ([docs/M1_TASK_BREAKDOWN.md](docs/M1_TASK_BREAKDOWN.md)): Complete ownership matrix, task table (`M1-01`–`M1-23`), cross-worker technical contracts, and Definition of Done.
- **Illustrator Art Manifest** (`docs/ART_SPEC.md`, `assets/final/README.md`): Exhaustive 1:1 drop-in art specification for Farid, NPCs, enemies, bosses, interactables, and 14-area parallax layers.

#### Core Architecture & Persistence (Godot 4.3 Typed GDScript)
- Project configuration (`project.godot`) targeting `1920×1080` (`canvas_items`, `expand`), `60` physics ticks/sec, pixel-snapping OFF, default Arabic (`ar`) locale, 8 named 2D physics layers, and 14 keyboard + gamepad input actions.
- Five core autoloads (`EventBus`, `GameState`, `SettingsManager`, `SaveManager`, `AudioManager`) providing strictly typed signal routing, atomic JSON save/load (`user://saves/slot_0.json`, `schema_version = 1`), persistent settings (`user://settings.json`), runtime CSV-to-`TranslationServer` loading, and headless-safe procedural desert wind / oud audio placeholders.
- Modular room streaming (`RoomBase`, `RoomManager`, `RoomCamera`, `TransitionGate`, `TimeShiftAnchor`) with strict `camera_bounds` clamping, fade transitions, shrine respawn handling, hitstop support, and M2-ready `Era2054`/`Era2034` switching.
- Data registries (`data/abilities.json`, `data/rooms.json`, `data/enemies.json`).

#### Player Movement & Combat
- Modular 13-state `PlayerStateMachine` for Farid with tuned metroidvania constants (`RUN_SPEED=380`, `JUMP_VELOCITY=-640`, `0.12 s` coyote time & jump buffer, variable jump height, `860×0.22 s` Dash, `130` wall-slide & `440/-610` wall-jump, plus M2/M3 state hooks for Double Jump, Ground-Pound, and Glide).
- **Flame Dagger** 3-hit directional combo scaling dynamically across Tiers 0, 1, and 2 (`10`/`15`/`22` damage, `72`/`96`/`124 px` reach) with the Flame Resource Meter (`0–100`), plus **Ranged Flame Spell** (`25` Resource, `24` flame damage) and **Parry** (`0.18 s` window, `+25` Resource, hitstop, attacker stagger via `on_parried()`).
- Original painterly placeholder silhouette rig for Farid featuring desert cloak sway and signature heterochromia eyes (left grey `#8B95A5`, right blue `#4A90D9`).

#### Enemies & M1 Boss
- Reusable `EnemyBase` (with ledge detection, parry stagger, and M2/M3 `supports_dont_look_rule` hook) and multi-phase `BossBase`.
- Three M1 enemies with clear telegraphs and parryable attacks: **Sand Stalker** (`35 HP`), **Shard Husk** (`45 HP`), and **Relic Sentinel** (`75 HP`, frontal shield).
- M1 Boss: **The Fractured Spire Warden** (*حارس البرج المتصدع*, `280 HP`, 2 phases) featuring *Sweeping Glass Halberd*, *Falling Spire Shards*, *Vaulting Slam*, and Phase 2 *Twin Beam Sweep* + orbiting parryable shards.

#### Art Pipeline, Shaders & Interactables
- Canonical desert-and-ruin color palette (`ShaalaPalette`) and four lightweight 60 FPS Godot 4.3 `canvas_item` shaders (`painterly_canvas`, `painterly_silhouette`, `orb_glow`, `sand_wind`).
- Five interactive scene prefabs (`OrbShrine`, `MemoryOrb`, `NotebookPage`, `NpcInteractable` supporting The Boy and Motaib silhouettes, and `CamelAmira`).

#### M1 Vertical Slice World (6 Interconnected Rooms)
- **Desert Camp:** `desert_camp_01` (Bedouin tent, The Boy, Amira, `shrine_desert_camp`, `page_00_camp`, tutorials) and `desert_camp_02` (`orb_desert_dash`, 380 px Dash chasm with safe lower return ledges).
- **Empty Highway:** `empty_highway_01` (abandoned vehicles, Motaib cameo #1, Dash-reachable `page_01_highway`) and `empty_highway_02` (`orb_highway_wall_cling`, 220×480 px Wall-Cling pylon chimney).
- **Empty Riyadh:** `empty_riyadh_01` (shattered glass atrium, persistent `shortcut_riyadh_to_camp` loop back to `desert_camp_01`) and `empty_riyadh_boss` (Fractured Spire Warden courtyard arena, `page_02_mall`, and sealed M2 Metro Tunnels tease).

#### Arabic-First UI, RTL & Localization
- Full UTF-8 localization table (`localization/strings.csv`) in poetic Modern Standard Arabic (`ar`) and English (`en`) with zero hardcoded UI strings.
- `ArabicFontSetup` integrating Godot 4 Advanced Text Server HarfBuzz shaping, cross-platform Arabic font fallback + OFL `.ttf` override, live dynamic RTL/LTR layout flipping, and BiDi isolate protection for mixed numerals/keycaps.
- Complete UI suite: Title Screen (with live AR/EN toggle), HUD (HP embers, Flame Meter & Dagger Tier, Era badge, prompts, area banner, boss health bar, shrine toast), Memory Vignette & Dialogue Player, explored-room Minimap Overlay, and Pause/Settings Menu (Notebook viewer, live key rebinding, gamepad deadzone, screen shake, reduce flash, game speed assist, and audio sliders).

#### QA & Automated Verification
- Automated verification and playtest-simulation harness (`tools/verify_m1.py`) plus formal M1 QA documentation (`docs/QA_NOTES.md`, `docs/KNOWN_ISSUES.md`).
