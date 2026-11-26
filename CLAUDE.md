# CLAUDE.md — Technical Engineer Guide for SHAALA (شعلة)

Welcome to **SHAALA (شعلة)**, an original 2D painterly action-exploration metroidvania built in **Godot 4.3** (strictly typed GDScript), set in ruined Riyadh, Saudi Arabia (2054 / 2034).

You (**Claude Opus**) serve as the project's **Technical Engineer**, collaborating directly with **Gemini (Visual Design Lead & Instruction Writer)**. Read this file completely before modifying scenes, scripts, shaders, or localization files.

---

## 1. Two-Agent Role Split & Boundaries

| Responsibility | Visual Lead (Gemini) | Technical Engineer (Claude Opus) |
| :--- | :---: | :---: |
| Hand-drawn PNG-32 spritesheets, parallax plates, UI ornaments, OFL Arabic fonts under `assets/final/` | **Owns** | Integrates & configures `.import` presets |
| Art direction, `ShaalaPalette` colors, Najdi motifs, `docs/ART_SPEC.md` | **Owns** | Preserves faithfully during integration |
| Writing new visual Drop briefs & artistic notes in `docs/VISUAL_HANDOFF.md` | **Owns** | Executes checklist & marks Drop `VERIFIED` |
| Godot 4.3 `.tscn` scenes, `scripts/**/*.gd`, `data/*.json`, `project.godot` | Does not edit directly | **Owns** |
| `canvas_item` shaders (`assets/placeholder/shaders/*.gdshader`), rendering, performance | Specifies uniform intent | **Owns** implementation & 60 FPS optimization |
| Arabic-first RTL/BiDi UI (`scenes/ui/`, `scripts/ui/`, `localization/strings.csv`) | Supplies ornaments/fonts | **Owns** wiring, RTL layout & zero-hardcoded-string enforcement |
| Automated QA (`tools/verify_m1.py --strict`) & Godot 4.3 headless verification | Reviews visual output | **Owns** running & keeping at 0 defects |

### Non-Negotiable Integration Rule
When integrating final art into any `.tscn` scene, perform a **1:1 non-destructive visual swap**:
- Replace or hide **only** placeholder `Polygon2D` visual children inside the visual container (`PlayerVisual`, `VisualRoot`, `SteleVisual`, `CamelVisual`, `PageVisual`, `ParallaxLayer`).
- **NEVER alter** root node types, collision shapes, physics layers/masks, `Spawns/` `Marker2D` coordinates, `TransitionGate` targets, boss arena bounds (`arena_left_x=180`, `arena_right_x=1860`), or ability-gate spacing (`400 px` Dash chasm in `desert_camp_02`, `220×520 px` Wall-Cling chimney in `empty_highway_02`).

---

## 2. Godot 4.3 Architecture & Contracts

### 2.1 Engine Baseline (`project.godot`)
- **Config:** `config_version=5`, Godot `4.3` (`Forward Plus`), main scene `res://scenes/main.tscn`.
- **Viewport:** `1920 × 1080`, `stretch/mode = "canvas_items"`, `stretch/aspect = "expand"`, `60` physics ticks/sec.
- **Pixel Snapping:** **OFF** (`snap_2d_transforms_to_pixel = false`, `snap_2d_vertices_to_pixel = false`) — required for smooth hand-painted brushstrokes and slow parallax.
- **Locale:** `internationalization/locale/fallback = "ar"` (Arabic first, English second).

### 2.2 Autoloads (Strict Load Order — Do Not Reorder)
1. **`EventBus`** (`scripts/autoload/event_bus.gd`) — 24 strictly typed signals decoupling all systems (`room_transition_requested`, `room_loaded`, `player_health_changed`, `player_resource_changed`, `player_died`, `player_respawn_requested`, `ability_unlocked`, `memory_orb_collected`, `notebook_page_collected`, `shrine_rested`, `dialogue_requested`, `vignette_requested`, `interaction_prompt_changed`, `boss_encounter_started`, `boss_health_changed`, `boss_defeated`, `era_changed`, `grey_eye_toggled`, `locale_changed`, `settings_changed`, `camera_shake_requested`, `hitstop_requested`, `pause_toggled`, `map_toggled`).
2. **`GameState`** (`scripts/autoload/game_state.gd`) — Single source of truth for HP (`5`), Flame Resource (`0.0–100.0`), Dagger Tier (`0`/`1`/`2` at `<35`/`<70`/`>=70`), `unlocked_abilities` (starts with `{"flame_spell": true}`), `collected_orbs`, `collected_pages`, `defeated_bosses`, `opened_shortcuts`, `explored_rooms`, `current_era` (`"2054"` / `"2034"`), `story_flags`, and shrine respawn state.
3. **`SettingsManager`** (`scripts/autoload/settings_manager.gd`) — Persists `user://settings.json` (locale, `screen_shake_scale`, `reduce_flash`, `assist_game_speed`, `gamepad_deadzone`, volumes, `rebind_action_key(action_name, keycode)`), and executes `load_runtime_translations()` to parse `res://localization/strings.csv` into `TranslationServer` at startup.
4. **`SaveManager`** (`scripts/autoload/save_manager.gd`) — Atomic JSON read/write at `user://saves/slot_0.json` (`schema_version = 1`).
5. **`AudioManager`** (`scripts/autoload/audio_manager.gd`) — `play_sfx(sfx_id)` + `set_music_mood(mood)`, with headless-safe procedural desert wind + Hijaz oud placeholders ready for studio audio stems.

### 2.3 Canonical 2D Physics Layers (1-Indexed)
| Layer | Bitmask | Name | Usage Contract |
| :-: | :-: | :--- | :--- |
| 1 | `1` | `world` | Solid static terrain (`StaticBody2D`, mask `0`) |
| 2 | `2` | `one_way` | One-way platforms/balconies (`one_way_collision = true`) |
| 3 | `4` | `player` | Player `CharacterBody2D` (`mask=3`, group `"player"`) & Player `Hurtbox` (`layer=4, mask=0, monitorable=true, monitoring=false`) |
| 4 | `8` | `enemy` | Enemy/Boss `CharacterBody2D` (`mask=3`, group `"enemies"`/`"bosses"`) & Enemy `Hurtbox` (`layer=8, mask=0, monitorable=true, monitoring=false`) |
| 5 | `16` | `player_hitbox` | `FlameDagger` (`mask=8`), `FlameProjectile` (`mask=9` = world+enemy); `monitoring=true, monitorable=false` |
| 6 | `32` | `enemy_hitbox` | Enemy/Boss `Hitbox` (`mask=4` detects Player `Hurtbox`); sets `DamageInfo.source_node = self` & `parryable = true` |
| 7 | `64` | `interactable` | Shrines, Orbs, Pages, NPCs, `TransitionGate`, `ShortcutGate`, `TutorialSign` (`mask=4`) |
| 8 | `128` | `hazard` | Environmental hazards (detected by Player `HazardSensor` `layer=0, mask=128`) |

### 2.4 Core Player & Combat Contracts (Keep Synchronized with `docs/GDD.md`)
- **Movement Constants (`scripts/player/player.gd`):** `RUN_SPEED=380`, `JUMP_VELOCITY=-640`, `GRAVITY=1550`, `VARIABLE_JUMP_CUT=0.45`, `COYOTE_TIME=0.12`, `JUMP_BUFFER_TIME=0.12`, `DASH_SPEED=860`, `DASH_DURATION=0.22`, `DASH_COOLDOWN=0.40`, `WALL_SLIDE_SPEED=130`, `WALL_JUMP_VELOCITY=Vector2(440, -610)`, `DOUBLE_JUMP_VELOCITY=-590`, `GROUND_POUND_SPEED=1050`, `GLIDE_FALL_SPEED=110`.
- **Combat & Parry:** `DamageInfo` (`amount`, `source_position`, `knockback`, `parryable`, `damage_type`, `source_node`); every enemy & boss implements `on_parried() -> void` (`1.2 s` enemy / `1.4 s` boss stagger, `1.35×` damage taken).
- **UI & RoomManager Wiring:** `RoomManager` calls `UIRoot.show_gameplay_hud()` / `show_title_screen()`, calls `player.set_controls_enabled(bool)` and `player.respawn()`, and defers `pause` / `toggle_map` input handling to `UIRoot._unhandled_input` whenever `_ui_root != null`.

---

## 3. Solved Godot 4.3 Pitfalls — DO NOT Re-Introduce!

Every item below was hit during real Godot 4.3 headless/live testing in M1 and explicitly fixed. Never regress any of them:

1. **No Typed Array or `Packed*Array` Constants:**  
   Godot 4.3 rejects `const X: Array[String] = [...]`, `const X: Array[Dictionary] = [...]`, and `const X := PackedStringArray([...])` as non-constant expressions.  
   - **Correct pattern:** `const X: Array = [...]` and construct `PackedStringArray(X)` at runtime inside `_ready()` or helper methods.
2. **GDScript Inner Class Colon Syntax:**  
   Always write `class MyInner extends Area2D:` (with a trailing `:`) and indent its full body.
3. **Inline `@export` Setter Recursion:**  
   Calling a helper `set_active(value)` from `@export var active: bool: set(v): set_active(v)` where `set_active` assigns `active = value` causes infinite stack overflow in Godot 4 GDScript.  
   - **Correct pattern:** Mutate `active = value` directly inside `set(value):`, and make `set_active(value)` simply assign `active = value`.
4. **Deferred Physics `monitoring` / `monitorable` Toggles:**  
   Toggling `Area2D.monitoring` synchronously inside `area_entered` / `body_entered` triggers `"Can't change this state while flushing queries"`.  
   - **Correct pattern:** Always call `set_deferred("monitoring", active)` when `is_inside_tree()`.
5. **RFC-4180 Double-Quotes in `localization/strings.csv`:**  
   Godot's CSV translation importer does **NOT** recognize backslash-escaped quotes (`\"`). Using `\"` splits columns and raises `'KEY' has N locale(s)` import errors.  
   - **Correct pattern:** Wrap fields containing commas or quotes in `"..."` and escape literal inner quotes by doubling them (`""`).
6. **Never Set `structured_text_bidi_override` on `Button` / `CheckButton`:**  
   In Godot 4.3, `structured_text_bidi_override` exists on `Label`, `RichTextLabel`, `LineEdit`, and `TextEdit`, **not** on `Button` or `CheckButton`. Always guard with type checks or `"structured_text_bidi_override" in node`.
7. **Simple, Non-Degenerate `Polygon2D` / `draw_polygon` Geometry:**  
   Self-intersecting polygons, `< 3` vertices, duplicate consecutive vertices, or collinear zero-area polygons trigger `ERROR: Invalid polygon data, triangulation failed` at runtime. Keep every procedural or scene polygon strictly simple (non-crossing perimeter, `>= 3` distinct vertices, positive area).
8. **Single Input Owner for `pause` & `toggle_map`:**  
   `UIRoot._unhandled_input` exclusively owns `pause` and `toggle_map` so neither triggers mid-vignette, mid-dialogue, or during live key rebinding. Do not duplicate those checks in `RoomManager` or `Player`.
9. **Headless-Safe Audio & Guarded Optional Shaders:**  
   Guard `AudioStreamGenerator` when `DisplayServer.get_name() == "headless"` or `mix_rate <= 0.0`, and check `ResourceLoader.exists(shader_path)` before assigning optional shaders via code.
10. **100% Static GDScript Typing:**  
    Every function parameter and return type (`-> void`, `-> bool`, `-> Vector2`, etc.) must be statically typed. `verify_m1.py` fails strict mode on any untyped function.

---

## 4. Arabic-First Localization, RTL & Content Policy

- **Zero Hardcoded User-Facing Text:** Every label, button, prompt, tutorial, dialogue, vignette, notebook page, boss name, and area banner MUST resolve from `localization/strings.csv` via `tr("KEY")`. Never bake Arabic or English lettering into PNG UI textures.
- **Arabic First (Modern Standard Arabic / الفصحى):** Default locale is `"ar"`, fallback `"ar"`, live toggle to `"en"`. Both `ar` (containing real Arabic Unicode `U+0600..U+06FF`) and `en` columns must be non-empty for every key.
- **RTL & BiDi Discipline:** All UI roots pass through `ArabicFontSetup` (`scripts/ui/arabic_font_setup.gd`):
  - Auto-loads any OFL `.ttf`/`.otf` dropped into `res://assets/final/fonts/` before falling back to HarfBuzz-shaped `SystemFont`.
  - Switches `Control.LAYOUT_DIRECTION_RTL` (`ar`) ↔ `Control.LAYOUT_DIRECTION_LTR` (`en`) dynamically on `EventBus.locale_changed`.
  - Wraps mixed Arabic + numerals/keycaps (`5/5`, `[Space]`) with Unicode directional isolates (`\u2066`..`\u2069`).
- **Tone & Cultural Guardrails:** Keep grief silent and dignified (zero gore/graphic death depictions), treat Saudi/Najdi motifs, faith, and Jinn respectfully, keep the Beam Cult strictly fictional, never use copyrighted song lyrics, and preserve the 3 intentional unanswered mysteries (the children & uncle, the throne, the man with the coffee cup).

---

## 5. How to Process Visual Drops (`docs/VISUAL_HANDOFF.md`)

Whenever Gemini logs a new Drop marked `READY_FOR_TECH` in `docs/VISUAL_HANDOFF.md`:

1. **Inspect the Drop:** Read the Drop's asset paths, canvas sizes, frame counts, pivots, and shader uniforms in `docs/VISUAL_HANDOFF.md`, cross-checking `docs/ART_SPEC.md`.
2. **Verify Assets on Disk:** Confirm every PNG-32 or `.ttf`/`.otf` file exists at its exact `assets/final/...` path with zero uppercase/spaces and valid dimensions.
3. **Configure Godot Import Presets:** For final PNGs, ensure `VRAM Compressed` (or `Lossless` for crisp UI/vignettes), `Mipmaps = true`, `Fix Alpha Border = true`, and `Linear Mipmap` filtering (`snap_2d_transforms_to_pixel = false`).
4. **Perform 1:1 Scene Integration:**
   - Mount `Sprite2D` or `AnimatedSprite2D` (`SpriteFrames`) inside the target scene's visual container node.
   - Align `offset` to the manifest pivot so grounded feet sit flush on `y = 0` without shifting collision shapes.
   - Set `use_parent_material = true` (or bind the specified shader: `painterly_silhouette.gdshader`, `orb_glow.gdshader`, `painterly_canvas.gdshader`, `sand_wind.gdshader`) and verify combat hit-flash (`flash_amount`) and `SettingsManager.reduce_flash` still function.
   - Hide or remove **only** the superseded placeholder `Polygon2D` children.
5. **Preserve Time Shift & Animation Hooks:** For M2+ Time Shift plates (`*_2034.png` / `*_2054.png`), wire them inside `Era2034` / `Era2054` containers controlled by `RoomBase.apply_era(era)`.
6. **Verify & Sign Off:** Run Section 6 verification completely, check off every item in the Drop's Integration Checklist, update its status to `VERIFIED`, and add concise tech notes (import preset, frame tweaks, FPS measurements) in `docs/VISUAL_HANDOFF.md`.

---

## 6. Mandatory Verification Gate (Run Before Every Commit / Push)

Every engineering change or visual drop integration MUST pass all three commands with **zero errors**:

```bash
# 1. Automated static, contract, localization, RTL/BiDi & ballistic-geometry harness:
python3 tools/verify_m1.py --strict

# 2. Real Godot 4.3 headless resource import & GDScript compilation check:
godot --headless --path . --import --quit

# 3. Real Godot 4.3 headless boot check (verifies autoloads, UI, CSV, & zero runtime errors):
godot --headless --path . --quit-after 3
```

*(On macOS if Godot 4.3 is extracted outside `PATH`, invoke `/Applications/Godot.app/Contents/MacOS/Godot` or your local Godot 4.3 binary path with the same flags.)*

If you add new scripts, scenes, localization keys, or rooms, update `tools/verify_m1.py` and `docs/QA_NOTES.md` / `CHANGELOG.md` as appropriate so the verification suite stays authoritative from M1 through M5.
