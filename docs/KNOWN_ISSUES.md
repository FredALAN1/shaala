# SHAALA (شعلة) — Milestone 1 Known Issues & Scope Notes

**Milestone:** `0.1.0-M1`  
**Last Verified:** `tools/verify_m1.py --strict` + Godot `4.3.stable` headless import & `Geometry2D.triangulate_polygon()` -> **0 CRITICAL, 0 HIGH, 0 MEDIUM, 0 WARN (23/23 PASS)**

This document tracks verification notes, intentional Milestone 1 placeholder boundaries, and low-risk runtime items to inspect during ongoing interactive Godot 4.3+ playtests.

---

## 1. Engine Verification Status

### KI-01 — Godot 4.3.stable Headless & Live Playtest Verification (`RESOLVED`)
- **Status:** **Verified on Godot `4.3.stable`** (Apple Silicon macOS) via headless `--import --quit`, headless scene boot (`--quit-after 3`), `Geometry2D.triangulate_polygon()` across all 24 `.tscn` scenes (0 failures), and live interactive boot.
- **Re-run Commands (for contributors / CI):**
  ```bash
  godot --headless --path shaala --import --quit
  godot --headless --path shaala --quit-after 120
  python3 shaala/tools/verify_m1.py --strict
  ```

---

## 2. Low-Risk Runtime Watchlist (First Live Godot 4.3+ Playtest)

### KI-02 — Arabic SystemFont Fallback Consistency Across OSes
- **Detail:** `ArabicFontSetup` loads any OFL `.ttf` placed in `res://assets/final/fonts/` first, and otherwise falls back to `SystemFont` (`Geeza Pro`, `SF Arabic`, `Damascus`, `Noto Sans Arabic`, `Cairo`, `Amiri`, `Arial`) shaped by Godot 4's HarfBuzz Advanced Text Server.
- **Watch Item:** Minimal Linux containers without `fonts-noto-core` / `Noto Sans Arabic` installed may display tofu boxes until an OFL Arabic `.ttf` (e.g., Cairo or Noto Sans Arabic) is dropped into `res://assets/final/fonts/`. macOS and Windows ship with covered Arabic system fonts out of the box.

### KI-03 — `strings.csv` Dual Loading After Editor Import
- **Detail:** `SettingsManager.load_runtime_translations()` intentionally parses `res://localization/strings.csv` at startup and calls `TranslationServer.add_translation()` so translations work immediately on a cold clone with zero `.import` cache. When the project is opened in the Godot Editor, Godot will also auto-generate `.translation` import artifacts for `strings.csv`.
- **Watch Item:** Confirm no duplicate-translation warning appears after initial Godot import; `TranslationServer` resolves keys cleanly either way, and `project.godot` does not hardcode unimported `.translation` paths so cold-start logs stay clean.

### KI-04 — Boss Phase 2 & Enemy Combat Feel Tuning
- **Detail:** `BossSpireWarden` (280 HP, 2 phases) and the 3 M1 enemies (`SandStalker`, `ShardHusk`, `RelicSentinel`) were validated structurally, by layer contract, and by arena bounds (`arena_left_x=180`, `arena_right_x=1860`, `arena_floor_y=860`), but combat pacing (telegraph durations, knockback impulses, Phase 2 Twin Beam Sweep angular speed, and camera shake strength) should receive a live feel-tuning pass in Godot 4.3+.

### KI-05 — Gamepad Model Mapping Variance
- **Detail:** All 14 input actions include standard Godot `InputEventJoypadButton` / `InputEventJoypadMotion` bindings and configurable `SettingsManager.gamepad_deadzone` (`0.1..0.5`).
- **Watch Item:** Live-test face button ergonomics (Jump/Attack/Dash/Parry/Spell) and pause/map shoulder buttons on both Xbox and DualSense controllers; keyboard rebinding is live in M1, while gamepad button rebinding is planned for M5 polish.

### KI-06 — Procedural Audio & Dummy Driver Behavior
- **Detail:** `AudioManager` synthesizes ambient desert wind + Hijaz-scale oud plucks via `AudioStreamGenerator` and builds a procedural WAV SFX bank at startup, guarded against `headless` and `mix_rate <= 0.0`.
- **Watch Item:** Confirm CPU overhead of the per-frame `AudioStreamGenerator` fill loop stays negligible on target hardware and tune relative Music/SFX dB balance before replacing with authored oud/strings stems in M4/M5.

---

## 3. Intentional Milestone 1 Scope Boundaries (Scheduled for M2–M5)

The following items are **by design** not active gameplay features in M1 (architectural hooks are already in place):
- **Placeholder Painterly Silhouettes:** All characters, enemies, boss, interactables, and parallax backdrops use procedural polygons + Godot 4 `canvas_item` shaders (`assets/placeholder/`). Drop-in illustrator asset replacement paths and frame specs are documented 1:1 in `docs/ART_SPEC.md` and `assets/final/README.md`.
- **Time Shift (`2034` / `2054`) & Grey Eye:** `TimeShiftAnchor`, `RoomBase.apply_era()` (`Era2034`/`Era2054` containers in all 6 rooms), `GameState.set_era()`, `GameState.set_grey_eye_active()`, and `EnemyBase.supports_dont_look_rule` are wired and ready; player ability unlocks and full 2034/2054 puzzle rooms ship in **Milestone 2**.
- **Double Jump, Ground-Pound, Glide:** State scripts (`ground_pound_state.gd`, `glide_state.gd`, double jump in `jump_state.gd`) are implemented in Farid's FSM and gated cleanly by `GameState.has_ability(...)`; their Memory Orbs unlock in **Milestones 2–3**.
- **Metro Tunnels & Areas 4–14:** The East alcove of `empty_riyadh_boss` displays the sealed Metro Tunnels Milestone 2 teaser gate (`PROMPT_SEALED_M2` / `DLG_METRO_SEALED_01`); Areas 4–14 are mapped in `docs/WORLD_GRAPH.md` for **Milestones 2–4**.
- **Single Save Slot (`slot_0.json`):** M1 persists atomic JSON saves to `user://saves/slot_0.json` (`schema_version=1`); multi-slot save UI is scheduled for **Milestone 4–5**.
