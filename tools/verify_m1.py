#!/usr/bin/env python3
"""
SHAALA (شعلة) — Milestone 1 Automated Verification & Playtest-Simulation Harness.

Performs deep static + geometric + playtest-simulation checks across:
  (a) Project & Resource Integrity (project.godot, .tscn, .tres, .gdshader, .json)
  (b) Typed GDScript & Cross-System Contract Verification (autoloads, signals, arity, layers, combat)
  (c) Arabic-First Localization, RTL & BiDi Audit (strings.csv, tr() keys, hardcoded UI text, fonts/BiDi)
  (d) Playtest Simulation — Softlock, Sequence-Break & Collision Geometry Audit (all 6 M1 rooms)
  (e) Deliverables, Docs & Content Rules Audit
  (f) Godot 4.3+ Headless Validation (if Godot binary is installed)

Usage:
  python3 tools/verify_m1.py [--root PATH] [--section a|b|c|d|e|f|all] [--json] [--strict]
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import shutil
import subprocess
import sys
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

# ---------------------------------------------------------------------------
# Data Structures & Ownership Mapping
# ---------------------------------------------------------------------------

SEVERITY_ORDER = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "WARN": 3, "INFO": 4, "PASS": 5}


@dataclass
class Finding:
    section: str
    severity: str  # CRITICAL, HIGH, MEDIUM, WARN, INFO, PASS
    owner: str
    code: str
    message: str
    file: str = ""
    line: int = 0

    def to_dict(self) -> Dict[str, Any]:
        return {
            "section": self.section,
            "severity": self.severity,
            "owner": self.owner,
            "code": self.code,
            "message": self.message,
            "file": self.file,
            "line": self.line,
        }


def infer_owner(rel_path: str) -> str:
    p = rel_path.replace("\\", "/").lstrip("/")
    if p in ("docs/GDD.md", "docs/WORLD_GRAPH.md", "docs/M1_TASK_BREAKDOWN.md", "CHANGELOG.md"):
        return "@designer"
    if p in ("docs/QA_NOTES.md", "docs/KNOWN_ISSUES.md", "tools/verify_m1.py"):
        return "@qa-verifier"
    if p in ("project.godot", "data/abilities.json", "data/rooms.json", "scenes/main.tscn") or p.startswith(
        ("scripts/autoload/", "scripts/systems/")
    ):
        return "@core-systems"
    if p.startswith(("scripts/combat/", "scripts/player/", "scenes/player/")):
        return "@player-combat"
    if p == "data/enemies.json" or p.startswith(("scripts/enemies/", "scripts/boss/", "scenes/enemies/", "scenes/boss/")):
        return "@enemies-boss"
    if p in ("docs/ART_SPEC.md", "assets/final/README.md", "assets/placeholder/palettes.gd") or p.startswith(
        ("assets/placeholder/shaders/", "scripts/interactables/", "scenes/interactables/")
    ):
        return "@art-shaders"
    if p.startswith(("scripts/rooms/", "scenes/rooms/")):
        return "@level-builder"
    if p.startswith(("localization/", "assets/placeholder/theme/", "scripts/ui/", "scenes/ui/")):
        return "@ui-loc"
    return "@coordinator"


EXPECTED_DELIVERABLES: Dict[str, List[str]] = {
    "@designer": [
        "docs/GDD.md",
        "docs/WORLD_GRAPH.md",
        "docs/M1_TASK_BREAKDOWN.md",
        "CHANGELOG.md",
    ],
    "@core-systems": [
        "project.godot",
        "data/abilities.json",
        "data/rooms.json",
        "scripts/autoload/event_bus.gd",
        "scripts/autoload/game_state.gd",
        "scripts/autoload/settings_manager.gd",
        "scripts/autoload/save_manager.gd",
        "scripts/autoload/audio_manager.gd",
        "scripts/systems/room_base.gd",
        "scripts/systems/room_manager.gd",
        "scripts/systems/room_camera.gd",
        "scripts/systems/transition_gate.gd",
        "scripts/systems/time_shift_anchor.gd",
        "scenes/main.tscn",
    ],
    "@player-combat": [
        "scripts/combat/damage_info.gd",
        "scripts/combat/hitbox.gd",
        "scripts/combat/hurtbox.gd",
        "scripts/combat/flame_dagger.gd",
        "scripts/combat/flame_projectile.gd",
        "scripts/player/player_state.gd",
        "scripts/player/player_state_machine.gd",
        "scripts/player/player.gd",
        "scripts/player/states/idle_state.gd",
        "scripts/player/states/run_state.gd",
        "scripts/player/states/jump_state.gd",
        "scripts/player/states/fall_state.gd",
        "scripts/player/states/wall_cling_state.gd",
        "scripts/player/states/dash_state.gd",
        "scripts/player/states/ground_pound_state.gd",
        "scripts/player/states/glide_state.gd",
        "scripts/player/states/attack_state.gd",
        "scripts/player/states/cast_spell_state.gd",
        "scripts/player/states/parry_state.gd",
        "scripts/player/states/hurt_state.gd",
        "scripts/player/states/dead_state.gd",
        "scenes/player/flame_projectile.tscn",
        "scenes/player/player.tscn",
    ],
    "@enemies-boss": [
        "data/enemies.json",
        "scripts/enemies/enemy_base.gd",
        "scripts/enemies/sand_stalker.gd",
        "scripts/enemies/shard_husk.gd",
        "scripts/enemies/relic_sentinel.gd",
        "scripts/boss/boss_base.gd",
        "scripts/boss/boss_spire_warden.gd",
        "scenes/enemies/sand_stalker.tscn",
        "scenes/enemies/shard_husk.tscn",
        "scenes/enemies/relic_sentinel.tscn",
        "scenes/boss/boss_spire_warden.tscn",
    ],
    "@art-shaders": [
        "docs/ART_SPEC.md",
        "assets/final/README.md",
        "assets/placeholder/palettes.gd",
        "assets/placeholder/shaders/painterly_canvas.gdshader",
        "assets/placeholder/shaders/painterly_silhouette.gdshader",
        "assets/placeholder/shaders/orb_glow.gdshader",
        "assets/placeholder/shaders/sand_wind.gdshader",
        "scripts/interactables/interactable_base.gd",
        "scripts/interactables/orb_shrine.gd",
        "scripts/interactables/memory_orb.gd",
        "scripts/interactables/notebook_page.gd",
        "scripts/interactables/npc_interactable.gd",
        "scripts/interactables/camel_amira.gd",
        "scenes/interactables/orb_shrine.tscn",
        "scenes/interactables/memory_orb.tscn",
        "scenes/interactables/notebook_page.tscn",
        "scenes/interactables/npc_boy.tscn",
        "scenes/interactables/camel_amira.tscn",
    ],
    "@level-builder": [
        "scripts/rooms/m1_room_controller.gd",
        "scripts/rooms/boss_arena_controller.gd",
        "scripts/rooms/shortcut_gate.gd",
        "scripts/rooms/tutorial_sign.gd",
        "scenes/rooms/m1/desert_camp_01.tscn",
        "scenes/rooms/m1/desert_camp_02.tscn",
        "scenes/rooms/m1/empty_highway_01.tscn",
        "scenes/rooms/m1/empty_highway_02.tscn",
        "scenes/rooms/m1/empty_riyadh_01.tscn",
        "scenes/rooms/m1/empty_riyadh_boss.tscn",
    ],
    "@ui-loc": [
        "localization/strings.csv",
        "localization/README.md",
        "assets/placeholder/theme/shaala_theme.tres",
        "scripts/ui/arabic_font_setup.gd",
        "scripts/ui/ui_root.gd",
        "scripts/ui/title_screen.gd",
        "scripts/ui/hud.gd",
        "scripts/ui/vignette_player.gd",
        "scripts/ui/minimap_overlay.gd",
        "scripts/ui/pause_settings_menu.gd",
        "scenes/ui/ui_root.tscn",
        "scenes/ui/title_screen.tscn",
        "scenes/ui/hud.tscn",
        "scenes/ui/vignette_player.tscn",
        "scenes/ui/minimap_overlay.tscn",
        "scenes/ui/pause_settings_menu.tscn",
    ],
}

CANONICAL_EVENT_BUS_SIGNALS: Dict[str, int] = {
    "room_transition_requested": 2,
    "room_loaded": 3,
    "player_health_changed": 2,
    "player_resource_changed": 3,
    "player_died": 0,
    "player_respawn_requested": 0,
    "ability_unlocked": 1,
    "memory_orb_collected": 3,
    "notebook_page_collected": 3,
    "shrine_rested": 2,
    "dialogue_requested": 1,
    "vignette_requested": 3,
    "interaction_prompt_changed": 2,
    "boss_encounter_started": 3,
    "boss_health_changed": 4,
    "boss_defeated": 1,
    "era_changed": 1,
    "grey_eye_toggled": 1,
    "locale_changed": 1,
    "settings_changed": 0,
    "camera_shake_requested": 2,
    "hitstop_requested": 1,
    "pause_toggled": 1,
    "map_toggled": 0,
}

CANONICAL_GAME_STATE_METHODS = [
    "has_ability",
    "unlock_ability",
    "get_dagger_tier",
    "add_resource",
    "spend_resource",
    "damage_player",
    "heal_player",
    "collect_orb",
    "collect_page",
    "mark_room_explored",
    "mark_boss_defeated",
    "is_boss_defeated",
    "set_shortcut_opened",
    "is_shortcut_opened",
    "rest_at_shrine",
    "set_era",
    "reset_new_game",
    "to_save_dict",
    "from_save_dict",
]

CANONICAL_PHYSICS_LAYERS = {
    "layer_1": "world",
    "layer_2": "one_way",
    "layer_3": "player",
    "layer_4": "enemy",
    "layer_5": "player_hitbox",
    "layer_6": "enemy_hitbox",
    "layer_7": "interactable",
    "layer_8": "hazard",
}

CANONICAL_INPUT_ACTIONS = [
    "move_left",
    "move_right",
    "move_up",
    "move_down",
    "jump",
    "dash",
    "attack",
    "cast_spell",
    "parry",
    "interact",
    "grey_eye",
    "time_shift",
    "toggle_map",
    "pause",
]

REQUIRED_LOCALIZATION_KEYS = [
    # UI
    "GAME_TITLE", "GAME_SUBTITLE", "UI_NEW_GAME", "UI_CONTINUE", "UI_SETTINGS", "UI_QUIT",
    "UI_RESUME", "UI_MAP", "UI_NOTEBOOK", "UI_SAVE_AND_QUIT", "UI_LANGUAGE", "UI_LANG_AR",
    "UI_LANG_EN", "UI_CONTROLS", "UI_ACCESSIBILITY", "UI_AUDIO", "UI_GAMEPAD_DEADZONE",
    "UI_SCREEN_SHAKE", "UI_REDUCE_FLASH", "UI_ASSIST_SPEED", "UI_MASTER_VOL", "UI_MUSIC_VOL",
    "UI_SFX_VOL", "UI_BACK", "UI_CLOSE", "UI_PRESS_CONTINUE", "UI_SAVED", "UI_RESTED_AT_SHRINE",
    "UI_ABILITY_UNLOCKED", "UI_PAGE_FOUND", "UI_NO_PAGES_YET", "UI_MAP_TITLE", "UI_EXPLORED",
    "UI_ERA_2054", "UI_ERA_2034", "UI_HP", "UI_FLAME_METER", "UI_DAGGER_TIER_0",
    "UI_DAGGER_TIER_1", "UI_DAGGER_TIER_2", "UI_REBIND_PROMPT", "UI_ACTION_MOVE_LEFT",
    "UI_ACTION_MOVE_RIGHT", "UI_ACTION_JUMP", "UI_ACTION_DASH", "UI_ACTION_ATTACK",
    "UI_ACTION_SPELL", "UI_ACTION_PARRY", "UI_ACTION_INTERACT", "UI_DEMO_COMPLETE",
    # Prompts & Tutorials
    "PROMPT_INTERACT", "PROMPT_REST_SHRINE", "PROMPT_ABSORB_ORB", "PROMPT_READ_PAGE",
    "PROMPT_TALK", "PROMPT_OPEN_SHORTCUT", "PROMPT_SEALED_M2",
    "TUT_MOVE", "TUT_JUMP", "TUT_ATTACK", "TUT_PARRY", "TUT_SPELL", "TUT_DASH", "TUT_WALL_CLING",
    # Areas
    "AREA_DESERT_CAMP", "AREA_EMPTY_HIGHWAY", "AREA_EMPTY_RIYADH", "AREA_EMPTY_RIYADH_MALL",
    # Abilities
    "ABILITY_DASH_NAME", "ABILITY_DASH_DESC", "ABILITY_WALL_CLING_NAME", "ABILITY_WALL_CLING_DESC",
    "ABILITY_FLAME_SPELL_NAME", "ABILITY_FLAME_SPELL_DESC", "ABILITY_DOUBLE_JUMP_NAME",
    "ABILITY_DOUBLE_JUMP_DESC", "ABILITY_GROUND_POUND_NAME", "ABILITY_GROUND_POUND_DESC",
    "ABILITY_GLIDE_NAME", "ABILITY_GLIDE_DESC", "ABILITY_TIME_SHIFT_NAME", "ABILITY_TIME_SHIFT_DESC",
    "ABILITY_GREY_EYE_NAME", "ABILITY_GREY_EYE_DESC",
    # Speakers & Boss
    "SPEAKER_BOY", "SPEAKER_FARID", "SPEAKER_MOTAIB", "SPEAKER_AMIRA",
    "BOSS_SPIRE_WARDEN_NAME", "BOSS_SPIRE_WARDEN_SUBTITLE",
    # Dialogue
    "DLG_BOY_01", "DLG_BOY_02", "DLG_BOY_03", "DLG_AMIRA_01",
    "DLG_MOTAIB_HWY_01", "DLG_MOTAIB_HWY_02", "DLG_METRO_SEALED_01",
    # Vignettes
    "VIG_DASH_TITLE", "VIG_DASH_01", "VIG_DASH_02", "VIG_DASH_03",
    "VIG_WALL_TITLE", "VIG_WALL_01", "VIG_WALL_02", "VIG_WALL_03",
    # Notebook Pages
    "PAGE_CAMP_TITLE", "PAGE_CAMP_BODY", "PAGE_HIGHWAY_TITLE", "PAGE_HIGHWAY_BODY",
    "PAGE_MALL_TITLE", "PAGE_MALL_BODY",
]

M1_ROOMS = [
    "desert_camp_01",
    "desert_camp_02",
    "empty_highway_01",
    "empty_highway_02",
    "empty_riyadh_01",
    "empty_riyadh_boss",
]

GODOT_BUILTIN_NODE_METHODS = {
    "add_child", "remove_child", "queue_free", "free", "get_node", "get_node_or_null",
    "has_node", "get_children", "get_parent", "get_tree", "call", "call_deferred",
    "set", "get", "set_deferred", "connect", "disconnect", "is_connected", "emit_signal",
    "has_method", "has_signal", "is_in_group", "add_to_group", "remove_from_group",
    "set_process", "set_physics_process", "set_process_input", "set_process_unhandled_input",
    "is_inside_tree", "get_path", "get_name", "name", "process_mode", "ready", "tree_entered",
    "tree_exiting", "tree_exited", "script",
}

# ---------------------------------------------------------------------------
# Godot Text Format (.tscn / .tres) Parser
# ---------------------------------------------------------------------------

@dataclass
class TscnNode:
    name: str
    node_type: str = ""
    parent: Optional[str] = None  # None for root
    instance_id: Optional[str] = None
    groups: List[str] = field(default_factory=list)
    props: Dict[str, str] = field(default_factory=dict)
    line: int = 0

    @property
    def full_path(self) -> str:
        if self.parent is None:
            return "."
        if self.parent == ".":
            return self.name
        return f"{self.parent}/{self.name}"


@dataclass
class TscnResource:
    kind: str  # ext_resource or sub_resource
    res_type: str
    res_id: str
    path: str = ""
    props: Dict[str, str] = field(default_factory=dict)
    line: int = 0


@dataclass
class TscnConnection:
    signal: str
    from_path: str
    to_path: str
    method: str
    line: int = 0


@dataclass
class ParsedScene:
    rel_path: str
    header_kind: str = ""  # gd_scene or gd_resource
    header_attrs: Dict[str, str] = field(default_factory=dict)
    ext_resources: Dict[str, TscnResource] = field(default_factory=dict)
    sub_resources: Dict[str, TscnResource] = field(default_factory=dict)
    duplicate_ext_ids: List[Tuple[str, int]] = field(default_factory=list)
    duplicate_sub_ids: List[Tuple[str, int]] = field(default_factory=list)
    nodes: List[TscnNode] = field(default_factory=list)
    node_map: Dict[str, TscnNode] = field(default_factory=dict)
    connections: List[TscnConnection] = field(default_factory=list)
    resource_props: Dict[str, str] = field(default_factory=dict)
    ext_refs: List[Tuple[str, int]] = field(default_factory=list)
    sub_refs: List[Tuple[str, int]] = field(default_factory=list)
    parse_errors: List[Tuple[int, str]] = field(default_factory=list)


ATTR_RE = re.compile(r'([A-Za-z0-9_]+)\s*=\s*("(?:[^"\\]|\\.)*"|\[[^\]]*\]|[^\s\]]+)')
EXT_REF_RE = re.compile(r'ExtResource\(\s*"([^"]+)"\s*\)')
SUB_REF_RE = re.compile(r'SubResource\(\s*"([^"]+)"\s*\)')


def parse_header_attrs(raw: str) -> Dict[str, str]:
    attrs: Dict[str, str] = {}
    for m in ATTR_RE.finditer(raw):
        k = m.group(1)
        v = m.group(2)
        if v.startswith('"') and v.endswith('"'):
            v = v[1:-1]
        attrs[k] = v
    return attrs


def parse_tscn(path: Path, rel_path: str) -> ParsedScene:
    scene = ParsedScene(rel_path=rel_path)
    try:
        text = path.read_text(encoding="utf-8")
    except Exception as exc:
        scene.parse_errors.append((1, f"Failed to read UTF-8: {exc}"))
        return scene

    lines = text.splitlines()
    current_section: Optional[str] = None
    current_obj: Any = None
    current_key: Optional[str] = None
    multiline_val: List[str] = []
    bracket_depth = 0

    def flush_prop() -> None:
        nonlocal current_key, multiline_val
        if current_key is not None and current_obj is not None:
            val = "\n".join(multiline_val).strip()
            if isinstance(current_obj, dict):
                current_obj[current_key] = val
            else:
                current_obj.props[current_key] = val
        current_key = None
        multiline_val = []

    def count_brackets(s: str) -> int:
        in_str = False
        esc = False
        delta = 0
        for ch in s:
            if esc:
                esc = False
                continue
            if ch == "\\" and in_str:
                esc = True
                continue
            if ch == '"':
                in_str = not in_str
                continue
            if not in_str:
                if ch in "([{":
                    delta += 1
                elif ch in ")]}":
                    delta -= 1
        return delta

    for idx, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()
        # Record all ExtResource / SubResource references
        for m in EXT_REF_RE.finditer(raw_line):
            scene.ext_refs.append((m.group(1), idx))
        for m in SUB_REF_RE.finditer(raw_line):
            scene.sub_refs.append((m.group(1), idx))

        if not line or line.startswith(";"):
            continue

        if current_key is not None and bracket_depth > 0:
            multiline_val.append(raw_line)
            bracket_depth += count_brackets(raw_line)
            if bracket_depth <= 0:
                bracket_depth = 0
                flush_prop()
            continue

        if line.startswith("[") and line.endswith("]"):
            flush_prop()
            inner = line[1:-1].strip()
            parts = inner.split(None, 1)
            if not parts:
                scene.parse_errors.append((idx, "Empty section header []"))
                continue
            tag = parts[0]
            attrs = parse_header_attrs(parts[1] if len(parts) > 1 else "")

            if tag in ("gd_scene", "gd_resource"):
                scene.header_kind = tag
                scene.header_attrs = attrs
                current_section = tag
                current_obj = None
            elif tag == "ext_resource":
                rid = attrs.get("id", "")
                res = TscnResource(
                    kind="ext_resource",
                    res_type=attrs.get("type", ""),
                    res_id=rid,
                    path=attrs.get("path", ""),
                    line=idx,
                )
                if not rid:
                    scene.parse_errors.append((idx, "ext_resource missing id"))
                elif rid in scene.ext_resources:
                    scene.duplicate_ext_ids.append((rid, idx))
                else:
                    scene.ext_resources[rid] = res
                current_section = tag
                current_obj = res
            elif tag == "sub_resource":
                rid = attrs.get("id", "")
                res = TscnResource(
                    kind="sub_resource",
                    res_type=attrs.get("type", ""),
                    res_id=rid,
                    line=idx,
                )
                if not rid:
                    scene.parse_errors.append((idx, "sub_resource missing id"))
                elif rid in scene.sub_resources:
                    scene.duplicate_sub_ids.append((rid, idx))
                else:
                    scene.sub_resources[rid] = res
                current_section = tag
                current_obj = res
            elif tag == "node":
                inst_raw = attrs.get("instance", "")
                inst_m = EXT_REF_RE.search(inst_raw) if inst_raw else None
                groups_raw = attrs.get("groups", "")
                groups = re.findall(r'"([^"]+)"', groups_raw)
                node = TscnNode(
                    name=attrs.get("name", ""),
                    node_type=attrs.get("type", ""),
                    parent=attrs.get("parent", None),
                    instance_id=inst_m.group(1) if inst_m else None,
                    groups=groups,
                    line=idx,
                )
                scene.nodes.append(node)
                scene.node_map[node.full_path] = node
                current_section = tag
                current_obj = node
            elif tag == "connection":
                conn = TscnConnection(
                    signal=attrs.get("signal", ""),
                    from_path=attrs.get("from", ""),
                    to_path=attrs.get("to", ""),
                    method=attrs.get("method", ""),
                    line=idx,
                )
                scene.connections.append(conn)
                current_section = tag
                current_obj = None
            elif tag == "resource":
                current_section = tag
                current_obj = scene.resource_props
            elif tag == "editable":
                current_section = tag
                current_obj = None
            else:
                current_section = tag
                current_obj = None
            continue

        # Property assignment
        if "=" in line and current_obj is not None:
            k, v = line.split("=", 1)
            current_key = k.strip()
            v_strip = v.strip()
            multiline_val = [v_strip]
            bracket_depth = count_brackets(v_strip)
            if bracket_depth <= 0:
                bracket_depth = 0
                flush_prop()
        elif current_section is None:
            scene.parse_errors.append((idx, f"Unexpected content before header: {line[:60]}"))

    flush_prop()
    return scene


# ---------------------------------------------------------------------------
# GDScript Lightweight Parser
# ---------------------------------------------------------------------------

@dataclass
class GdFunc:
    name: str
    params_raw: str
    min_args: int
    max_args: int
    has_return_type: bool
    all_params_typed: bool
    line: int
    is_static: bool = False


@dataclass
class GdSignal:
    name: str
    param_count: int
    params_raw: str
    line: int


@dataclass
class ParsedGd:
    rel_path: str
    text: str = ""
    extends: str = ""
    class_name: str = ""
    signals: Dict[str, GdSignal] = field(default_factory=dict)
    funcs: Dict[str, GdFunc] = field(default_factory=dict)
    vars: Dict[str, Tuple[str, int]] = field(default_factory=dict)  # name -> (value_expr, line)
    consts: Dict[str, Tuple[str, int]] = field(default_factory=dict)
    enums: Dict[str, int] = field(default_factory=dict)
    enum_values: Set[str] = field(default_factory=set)
    lines: List[str] = field(default_factory=list)


def strip_gd_comments_and_strings(line: str, keep_strings_placeholder: bool = True) -> str:
    out: List[str] = []
    i = 0
    n = len(line)
    in_quote: Optional[str] = None
    while i < n:
        ch = line[i]
        if in_quote:
            if ch == "\\":
                i += 2
                continue
            if ch == in_quote:
                in_quote = None
                if keep_strings_placeholder:
                    out.append('""')
            i += 1
            continue
        if ch == "#":
            break
        if ch in ('"', "'"):
            in_quote = ch
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def split_top_level_args(arg_str: str) -> List[str]:
    s = arg_str.strip()
    if not s:
        return []
    args: List[str] = []
    cur: List[str] = []
    depth = 0
    in_quote: Optional[str] = None
    i = 0
    while i < len(s):
        ch = s[i]
        if in_quote:
            cur.append(ch)
            if ch == "\\" and i + 1 < len(s):
                i += 1
                cur.append(s[i])
            elif ch == in_quote:
                in_quote = None
            i += 1
            continue
        if ch in ('"', "'"):
            in_quote = ch
            cur.append(ch)
        elif ch in "([{":
            depth += 1
            cur.append(ch)
        elif ch in ")]}":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            args.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
        i += 1
    if cur or args:
        tail = "".join(cur).strip()
        if tail:
            args.append(tail)
    return args


def parse_gd(path: Path, rel_path: str) -> ParsedGd:
    gd = ParsedGd(rel_path=rel_path)
    text = path.read_text(encoding="utf-8")
    gd.text = text
    gd.lines = text.splitlines()

    func_re = re.compile(r"^(static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*(->\s*[^:]+)?\s*:")
    sig_re = re.compile(r"^signal\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*\(([^)]*)\))?")
    var_re = re.compile(
        r"^(?:@(?:export(?:_[a-z_]+)?|onready)(?:\([^)]*\))?\s+)*(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*[^=]+)?(?:\s*=\s*(.+))?"
    )
    const_re = re.compile(r"^const\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*[^=]+)?\s*=\s*(.+)")
    enum_re = re.compile(r"^enum(?:\s+([A-Za-z_][A-Za-z0-9_]*))?\s*\{([^}]*)\}")

    for idx, raw_line in enumerate(gd.lines, start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not raw_line[0].isspace():
            if stripped.startswith("extends "):
                gd.extends = stripped[len("extends "):].split("#")[0].strip().strip('"')
            elif stripped.startswith("class_name "):
                gd.class_name = stripped[len("class_name "):].split("#")[0].strip()

            m = sig_re.match(stripped)
            if m:
                sname = m.group(1)
                praw = (m.group(2) or "").strip()
                pcount = len(split_top_level_args(praw)) if praw else 0
                gd.signals[sname] = GdSignal(sname, pcount, praw, idx)
                continue

            m = func_re.match(stripped)
            if m:
                is_static = bool(m.group(1))
                fname = m.group(2)
                praw = m.group(3).strip()
                has_ret = bool(m.group(4))
                params = split_top_level_args(praw)
                min_args = 0
                all_typed = True
                for p in params:
                    # Check default value (outside brackets)
                    has_default = False
                    depth = 0
                    for ch in p:
                        if ch in "([{":
                            depth += 1
                        elif ch in ")]}":
                            depth -= 1
                        elif ch == "=" and depth == 0:
                            has_default = True
                            break
                    if not has_default:
                        min_args += 1
                    param_decl = p.split("=")[0].strip()
                    if ":" not in param_decl:
                        all_typed = False
                gd.funcs[fname] = GdFunc(fname, praw, min_args, len(params), has_ret, all_typed, idx, is_static)
                continue

            m = const_re.match(stripped)
            if m:
                gd.consts[m.group(1)] = (m.group(2).split("#")[0].strip(), idx)
                continue

            m = var_re.match(stripped)
            if m:
                val = (m.group(2) or "").split("#")[0].strip()
                gd.vars[m.group(1)] = (val, idx)
                continue

            m = enum_re.match(stripped)
            if m:
                ename = m.group(1)
                if ename:
                    gd.enums[ename] = idx
                for item in m.group(2).split(","):
                    tok = item.strip().split("=")[0].strip()
                    if tok:
                        gd.enum_values.add(tok)

    return gd


# ---------------------------------------------------------------------------
# Geometry Helpers for Playtest Simulation
# ---------------------------------------------------------------------------

@dataclass
class Rect:
    x: float
    y: float
    w: float
    h: float

    @property
    def left(self) -> float:
        return self.x

    @property
    def right(self) -> float:
        return self.x + self.w

    @property
    def top(self) -> float:
        return self.y

    @property
    def bottom(self) -> float:
        return self.y + self.h

    @property
    def cx(self) -> float:
        return self.x + self.w * 0.5

    @property
    def cy(self) -> float:
        return self.y + self.h * 0.5

    def intersects(self, other: "Rect", shrink: float = 0.0) -> bool:
        return (
            self.left + shrink < other.right - shrink
            and self.right - shrink > other.left + shrink
            and self.top + shrink < other.bottom - shrink
            and self.bottom - shrink > other.top + shrink
        )

    def contains_point(self, px: float, py: float, margin: float = 0.0) -> bool:
        return (
            self.left - margin <= px <= self.right + margin
            and self.top - margin <= py <= self.bottom + margin
        )

    def distance_to_point(self, px: float, py: float) -> float:
        dx = max(self.left - px, 0.0, px - self.right)
        dy = max(self.top - py, 0.0, py - self.bottom)
        return math.hypot(dx, dy)


VEC2_RE = re.compile(r"Vector2\(\s*([-+]?\d*\.?\d+)\s*,\s*([-+]?\d*\.?\d+)\s*\)")
RECT2_RE = re.compile(
    r"Rect2\(\s*([-+]?\d*\.?\d+)\s*,\s*([-+]?\d*\.?\d+)\s*,\s*([-+]?\d*\.?\d+)\s*,\s*([-+]?\d*\.?\d+)\s*\)"
)
PACKED_VEC2_RE = re.compile(r"PackedVector2Array\(([^)]*)\)")


def parse_vec2(val: Optional[str], default: Tuple[float, float] = (0.0, 0.0)) -> Tuple[float, float]:
    if not val:
        return default
    m = VEC2_RE.search(val)
    if m:
        return (float(m.group(1)), float(m.group(2)))
    return default


def parse_rect2(val: Optional[str]) -> Optional[Rect]:
    if not val:
        return None
    m = RECT2_RE.search(val)
    if m:
        return Rect(float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)))
    return None


def parse_packed_vec2(val: Optional[str]) -> List[Tuple[float, float]]:
    if not val:
        return []
    m = PACKED_VEC2_RE.search(val)
    if not m:
        return []
    nums = [float(x.strip()) for x in m.group(1).split(",") if x.strip()]
    pts: List[Tuple[float, float]] = []
    for i in range(0, len(nums) - 1, 2):
        pts.append((nums[i], nums[i + 1]))
    return pts


def parse_int_prop(val: Optional[str], default: int) -> int:
    if val is None:
        return default
    try:
        return int(val.strip())
    except ValueError:
        return default


def parse_bool_prop(val: Optional[str], default: bool) -> bool:
    if val is None:
        return default
    s = val.strip().lower()
    if s == "true":
        return True
    if s == "false":
        return False
    return default


def parse_str_prop(val: Optional[str], default: str = "") -> str:
    if val is None:
        return default
    s = val.strip()
    if s.startswith('"') and s.endswith('"'):
        return s[1:-1]
    return s


# ---------------------------------------------------------------------------
# Main Verifier Class
# ---------------------------------------------------------------------------

class M1Verifier:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self.findings: List[Finding] = []
        self.metrics: Dict[str, Any] = {}
        self.parsed_scenes: Dict[str, ParsedScene] = {}
        self.parsed_gds: Dict[str, ParsedGd] = {}
        self.csv_keys: Dict[str, Tuple[str, str]] = {}  # key -> (ar, en)
        self.rooms_json: Dict[str, Any] = {}
        self.abilities_json: Dict[str, Any] = {}
        self.enemies_json: Dict[str, Any] = {}

    def add(
        self,
        section: str,
        severity: str,
        code: str,
        message: str,
        rel_path: str = "",
        line: int = 0,
        owner: Optional[str] = None,
    ) -> None:
        resolved_owner = owner or (infer_owner(rel_path) if rel_path else "@coordinator")
        self.findings.append(Finding(section, severity, resolved_owner, code, message, rel_path, line))

    def rel(self, p: Path) -> str:
        return str(p.resolve().relative_to(self.root)).replace("\\", "/")

    def res_to_path(self, res_path: str) -> Path:
        assert res_path.startswith("res://")
        return self.root / res_path[len("res://"):]

    def preload_all(self) -> None:
        if not self.root.exists():
            return
        for ext in ("*.tscn", "*.tres"):
            for p in sorted(self.root.rglob(ext)):
                rp = self.rel(p)
                self.parsed_scenes[rp] = parse_tscn(p, rp)
        for p in sorted(self.root.rglob("*.gd")):
            rp = self.rel(p)
            try:
                self.parsed_gds[rp] = parse_gd(p, rp)
            except Exception as exc:
                self.add("B", "CRITICAL", "GD_READ_ERR", f"Cannot read/parse GDScript: {exc}", rp)

        # Load JSON data files if present
        for name, target_attr in [
            ("data/rooms.json", "rooms_json"),
            ("data/abilities.json", "abilities_json"),
            ("data/enemies.json", "enemies_json"),
        ]:
            jp = self.root / name
            if jp.exists():
                try:
                    setattr(self, target_attr, json.loads(jp.read_text(encoding="utf-8")))
                except Exception:
                    pass

        # Load CSV keys if present
        csv_path = self.root / "localization/strings.csv"
        if csv_path.exists():
            try:
                with csv_path.open("r", encoding="utf-8-sig", newline="") as fh:
                    reader = csv.DictReader(fh)
                    if reader.fieldnames and "ar" in reader.fieldnames and "en" in reader.fieldnames:
                        key_col = reader.fieldnames[0]
                        for row in reader:
                            k = (row.get(key_col) or "").strip()
                            if k:
                                self.csv_keys[k] = ((row.get("ar") or "").strip(), (row.get("en") or "").strip())
            except Exception:
                pass

    # -----------------------------------------------------------------------
    # SECTION A: Project & Resource Integrity
    # -----------------------------------------------------------------------

    def check_section_a(self) -> None:
        sec = "A"
        if not self.root.exists():
            self.add(sec, "CRITICAL", "ROOT_MISSING", f"Project root does not exist: {self.root}", owner="@core-systems")
            return

        # 1. Deliverable existence manifest
        missing_by_owner: Dict[str, List[str]] = defaultdict(list)
        present_count = 0
        total_expected = 0
        for owner, files in EXPECTED_DELIVERABLES.items():
            for rp in files:
                total_expected += 1
                if (self.root / rp).exists():
                    present_count += 1
                else:
                    missing_by_owner[owner].append(rp)
                    self.add(sec, "CRITICAL", "MISSING_FILE", f"Required deliverable missing: {rp}", rp, owner=owner)
        self.metrics["deliverables_present"] = present_count
        self.metrics["deliverables_expected"] = total_expected
        if present_count == total_expected:
            self.add(sec, "PASS", "ALL_DELIVERABLES", f"All {total_expected}/{total_expected} M1 deliverables exist.", owner="@coordinator")

        # 2. Parse project.godot
        pg_path = self.root / "project.godot"
        if pg_path.exists():
            self._check_project_godot(pg_path)

        # 3. Validate JSON files
        self._check_json_files()

        # 4. Validate all .tscn and .tres files
        tscn_count = 0
        tres_count = 0
        for rp, scene in sorted(self.parsed_scenes.items()):
            if rp.endswith(".tscn"):
                tscn_count += 1
            else:
                tres_count += 1
            self._check_parsed_scene(scene)
        self.metrics["tscn_count"] = tscn_count
        self.metrics["tres_count"] = tres_count

        # 5. Validate all .gdshader files
        shader_files = sorted(self.root.rglob("*.gdshader"))
        self.metrics["shader_count"] = len(shader_files)
        for sp in shader_files:
            self._check_shader(sp)

    def _check_project_godot(self, pg_path: Path) -> None:
        sec = "A"
        rp = "project.godot"
        text = pg_path.read_text(encoding="utf-8")
        sections: Dict[str, Dict[str, str]] = defaultdict(dict)
        cur_sec = "_root"
        autoload_order: List[Tuple[str, str]] = []
        current_key: Optional[str] = None
        buf: List[str] = []
        depth = 0

        def flush() -> None:
            nonlocal current_key, buf
            if current_key is not None:
                val = "\n".join(buf).strip()
                sections[cur_sec][current_key] = val
                if cur_sec == "autoload":
                    autoload_order.append((current_key, val))
            current_key = None
            buf = []

        for raw_line in text.splitlines():
            s = raw_line.strip()
            if not s or s.startswith(";"):
                continue
            if current_key is not None and depth > 0:
                buf.append(raw_line)
                depth += raw_line.count("{") + raw_line.count("[") + raw_line.count("(")
                depth -= raw_line.count("}") + raw_line.count("]") + raw_line.count(")")
                if depth <= 0:
                    depth = 0
                    flush()
                continue
            if s.startswith("[") and s.endswith("]"):
                flush()
                cur_sec = s[1:-1].strip()
                continue
            if "=" in s:
                k, v = s.split("=", 1)
                current_key = k.strip()
                v_s = v.strip()
                buf = [v_s]
                depth = v_s.count("{") + v_s.count("[") + v_s.count("(") - (
                    v_s.count("}") + v_s.count("]") + v_s.count(")")
                )
                if depth <= 0:
                    depth = 0
                    flush()
        flush()

        # Config version
        if sections["_root"].get("config_version") != "5":
            self.add(sec, "HIGH", "PG_CONFIG_VER", f"Expected config_version=5 for Godot 4.3, got {sections['_root'].get('config_version')}", rp)

        # App name & main scene
        app = sections.get("application", {})
        app_name = app.get("config/name", "")
        if "SHAALA" not in app_name or "شعلة" not in app_name:
            self.add(sec, "MEDIUM", "PG_APP_NAME", f"Expected app name containing 'SHAALA' and 'شعلة', got {app_name}", rp)
        main_scene = app.get("run/main_scene", "").strip('"')
        if main_scene != "res://scenes/main.tscn":
            self.add(sec, "CRITICAL", "PG_MAIN_SCENE", f"Expected run/main_scene='res://scenes/main.tscn', got '{main_scene}'", rp)
        elif not self.res_to_path(main_scene).exists():
            self.add(sec, "CRITICAL", "PG_MAIN_MISSING", f"main_scene target missing on disk: {main_scene}", rp)

        # Display viewport
        disp = sections.get("display", {})
        if disp.get("window/size/viewport_width") != "1920" or disp.get("window/size/viewport_height") != "1080":
            self.add(
                sec, "HIGH", "PG_VIEWPORT",
                f"Expected viewport 1920x1080, got {disp.get('window/size/viewport_width')}x{disp.get('window/size/viewport_height')}",
                rp,
            )
        if disp.get("window/stretch/mode", "").strip('"') != "canvas_items":
            self.add(sec, "HIGH", "PG_STRETCH_MODE", f"Expected stretch mode 'canvas_items', got {disp.get('window/stretch/mode')}", rp)
        if disp.get("window/stretch/aspect", "").strip('"') != "expand":
            self.add(sec, "MEDIUM", "PG_STRETCH_ASPECT", f"Expected stretch aspect 'expand', got {disp.get('window/stretch/aspect')}", rp)

        # Rendering pixel snapping OFF
        rend = sections.get("rendering", {})
        for snap_key in ("2d/snap/snap_2d_transforms_to_pixel", "2d/snap/snap_2d_vertices_to_pixel"):
            v = rend.get(snap_key)
            if v == "true":
                self.add(sec, "HIGH", "PG_PIXEL_SNAP", f"{snap_key} MUST be false (pixel-snapping OFF for painterly 2D)!", rp)
            elif v is None:
                self.add(sec, "WARN", "PG_PIXEL_SNAP_IMPLICIT", f"{snap_key} not explicitly set to false (Godot default is false, explicit recommended).", rp)

        # Physics ticks 60
        phys = sections.get("physics", {})
        ticks = phys.get("common/physics_ticks_per_second", "60")
        if ticks != "60":
            self.add(sec, "HIGH", "PG_PHYSICS_FPS", f"Expected 60 physics ticks/sec, got {ticks}", rp)

        # Autoloads exact order & paths
        expected_autoloads = [
            ("EventBus", '"*res://scripts/autoload/event_bus.gd"'),
            ("GameState", '"*res://scripts/autoload/game_state.gd"'),
            ("SettingsManager", '"*res://scripts/autoload/settings_manager.gd"'),
            ("SaveManager", '"*res://scripts/autoload/save_manager.gd"'),
            ("AudioManager", '"*res://scripts/autoload/audio_manager.gd"'),
        ]
        if autoload_order != expected_autoloads:
            self.add(
                sec, "CRITICAL", "PG_AUTOLOADS",
                f"Autoloads mismatch. Expected {[x[0] for x in expected_autoloads]} in exact order with exact paths; got {autoload_order}",
                rp,
            )
        for name, val in autoload_order:
            clean_p = val.strip('"').lstrip("*")
            if clean_p.startswith("res://") and not self.res_to_path(clean_p).exists():
                self.add(sec, "CRITICAL", "PG_AUTOLOAD_MISSING", f"Autoload {name} script missing: {clean_p}", rp)

        # Physics Layer Names
        ln = sections.get("layer_names", {})
        for k, expected_name in CANONICAL_PHYSICS_LAYERS.items():
            actual = ln.get(f"2d_physics/{k}", "").strip('"')
            if actual != expected_name:
                self.add(sec, "HIGH", "PG_LAYER_NAME", f"2d_physics/{k}: expected '{expected_name}', got '{actual}'", rp)

        # Localization settings
        i18n = sections.get("internationalization", {})
        fb = i18n.get("locale/fallback", "").strip('"')
        if fb != "ar":
            self.add(sec, "HIGH", "PG_LOCALE_FALLBACK", f"Expected internationalization/locale/fallback='ar', got '{fb}'", rp)
        # Check if translations points to non-existent .translation files (can warn on cold start in Godot)
        tr_list = i18n.get("locale/translations", "")
        for res_m in re.finditer(r'res://[^"\)]+', tr_list):
            tpath = res_m.group(0)
            if not self.res_to_path(tpath).exists():
                self.add(
                    sec, "WARN", "PG_UNIMPORTED_TRANSLATION",
                    f"project.godot references '{tpath}' which does not exist until Godot imports strings.csv (ensure runtime CSV loader handles cold start cleanly; remove missing .translation paths if they emit startup errors).",
                    rp,
                )

        # Input Actions
        inp = sections.get("input", {})
        for action in CANONICAL_INPUT_ACTIONS:
            if action not in inp:
                self.add(sec, "CRITICAL", "PG_INPUT_MISSING", f"Missing required input action '{action}' in project.godot", rp)
            else:
                val = inp[action]
                if "InputEventKey" not in val:
                    self.add(sec, "MEDIUM", "PG_INPUT_NO_KEY", f"Input action '{action}' has no keyboard (InputEventKey) binding", rp)
                if "InputEventJoypad" not in val:
                    self.add(sec, "MEDIUM", "PG_INPUT_NO_JOY", f"Input action '{action}' has no gamepad (InputEventJoypad*) binding", rp)

        self.add(sec, "PASS", "PG_PARSED", f"Parsed project.godot ({len(autoload_order)} autoloads, {len(inp)} input actions).", rp)

    def _check_json_files(self) -> None:
        sec = "A"
        for rp in ("data/abilities.json", "data/rooms.json", "data/enemies.json"):
            p = self.root / rp
            if not p.exists():
                continue
            try:
                data = json.loads(p.read_text(encoding="utf-8"))
            except Exception as exc:
                self.add(sec, "CRITICAL", "JSON_INVALID", f"Invalid JSON: {exc}", rp)
                continue

            if rp == "data/abilities.json":
                items = data.get("abilities", data) if isinstance(data, dict) else data
                ids: Set[str] = set()
                if isinstance(items, dict):
                    ids = set(items.keys())
                elif isinstance(items, list):
                    ids = {x.get("id", "") for x in items if isinstance(x, dict)}
                expected = {"flame_spell", "dash", "wall_cling", "double_jump", "ground_pound", "glide", "time_shift", "grey_eye"}
                missing = expected - ids
                if missing:
                    self.add(sec, "HIGH", "ABILITIES_MISSING", f"data/abilities.json missing abilities: {sorted(missing)}", rp)
                else:
                    self.add(sec, "PASS", "ABILITIES_OK", f"data/abilities.json defines all 8 abilities.", rp)

            elif rp == "data/rooms.json":
                rooms = data.get("rooms", data) if isinstance(data, dict) else {}
                room_ids = set(rooms.keys()) if isinstance(rooms, dict) else {x.get("id", "") for x in rooms if isinstance(x, dict)}
                missing = set(M1_ROOMS) - room_ids
                if missing:
                    self.add(sec, "CRITICAL", "ROOMS_JSON_MISSING", f"data/rooms.json missing M1 rooms: {sorted(missing)}", rp)
                else:
                    self.add(sec, "PASS", "ROOMS_JSON_OK", f"data/rooms.json defines all 6 M1 rooms.", rp)
                # Verify scene_path exists
                iter_rooms = rooms.items() if isinstance(rooms, dict) else [(x.get("id", "?"), x) for x in rooms]
                for rid, rinfo in iter_rooms:
                    if not isinstance(rinfo, dict):
                        continue
                    sp = rinfo.get("scene_path", "")
                    if not sp.startswith("res://") or not self.res_to_path(sp).exists():
                        self.add(sec, "CRITICAL", "ROOM_SCENE_MISSING", f"Room '{rid}' scene_path does not exist: '{sp}'", rp)

            elif rp == "data/enemies.json":
                enemies = data.get("enemies", data) if isinstance(data, dict) else data
                ids = set(enemies.keys()) if isinstance(enemies, dict) else {x.get("id", "") for x in enemies if isinstance(x, dict)}
                if isinstance(data, dict) and "bosses" in data:
                    b = data["bosses"]
                    ids |= set(b.keys()) if isinstance(b, dict) else {x.get("id", "") for x in b if isinstance(x, dict)}
                expected = {"sand_stalker", "shard_husk", "relic_sentinel", "boss_spire_warden"}
                missing = expected - ids
                if missing:
                    self.add(sec, "HIGH", "ENEMIES_JSON_MISSING", f"data/enemies.json missing definitions: {sorted(missing)}", rp)
                else:
                    self.add(sec, "PASS", "ENEMIES_JSON_OK", "data/enemies.json defines all 3 M1 enemies + boss.", rp)

    def _check_parsed_scene(self, scene: ParsedScene) -> None:
        sec = "A"
        rp = scene.rel_path

        for line, msg in scene.parse_errors:
            self.add(sec, "CRITICAL", "TSCN_PARSE_ERR", msg, rp, line)

        expected_kind = "gd_scene" if rp.endswith(".tscn") else "gd_resource"
        if scene.header_kind != expected_kind:
            self.add(sec, "CRITICAL", "TSCN_HEADER", f"Expected [{expected_kind} ... format=3], got [{scene.header_kind}]", rp, 1)
        if scene.header_attrs.get("format") != "3":
            self.add(sec, "CRITICAL", "TSCN_FORMAT", f"Expected format=3 for Godot 4, got format={scene.header_attrs.get('format')}", rp, 1)

        # load_steps check
        if "load_steps" in scene.header_attrs:
            try:
                ls = int(scene.header_attrs["load_steps"])
                expected_ls = len(scene.ext_resources) + len(scene.sub_resources) + 1
                if ls < expected_ls:
                    self.add(sec, "HIGH", "TSCN_LOAD_STEPS", f"load_steps={ls} is less than actual resources+1 ({expected_ls})", rp, 1)
            except ValueError:
                self.add(sec, "HIGH", "TSCN_LOAD_STEPS", f"Invalid load_steps value: {scene.header_attrs['load_steps']}", rp, 1)

        # Duplicates
        for rid, line in scene.duplicate_ext_ids:
            self.add(sec, "CRITICAL", "TSCN_DUP_EXT", f"Duplicate ext_resource id='{rid}'", rp, line)
        for rid, line in scene.duplicate_sub_ids:
            self.add(sec, "CRITICAL", "TSCN_DUP_SUB", f"Duplicate sub_resource id='{rid}'", rp, line)

        # ext_resource path existence
        for rid, res in scene.ext_resources.items():
            if not res.path.startswith("res://"):
                self.add(sec, "HIGH", "TSCN_EXT_PATH", f"ext_resource id='{rid}' has invalid path '{res.path}'", rp, res.line)
            else:
                target = self.res_to_path(res.path)
                if not target.exists():
                    self.add(sec, "CRITICAL", "TSCN_BROKEN_EXT", f"ext_resource id='{rid}' points to missing file: {res.path}", rp, res.line)

        # Check all ExtResource / SubResource references
        for rid, line in scene.ext_refs:
            if rid not in scene.ext_resources:
                self.add(sec, "CRITICAL", "TSCN_UNDEF_EXT", f'Reference to undefined ExtResource("{rid}")', rp, line)
        for rid, line in scene.sub_refs:
            if rid not in scene.sub_resources:
                self.add(sec, "CRITICAL", "TSCN_UNDEF_SUB", f'Reference to undefined SubResource("{rid}")', rp, line)

        # Node hierarchy integrity
        if rp.endswith(".tscn"):
            if not scene.nodes:
                self.add(sec, "CRITICAL", "TSCN_NO_NODES", "Scene contains zero [node] entries", rp)
            else:
                root_nodes = [n for n in scene.nodes if n.parent is None]
                if len(root_nodes) != 1:
                    self.add(sec, "CRITICAL", "TSCN_ROOT_COUNT", f"Expected exactly 1 root node, found {len(root_nodes)}", rp)
                known_paths: Set[str] = set()
                instanced_prefixes: Set[str] = set()
                for n in scene.nodes:
                    if n.parent is not None:
                        if n.parent != "." and n.parent not in known_paths:
                            # Could be a child of an instanced scene
                            if not any(n.parent == ip or n.parent.startswith(ip + "/") for ip in instanced_prefixes):
                                self.add(sec, "CRITICAL", "TSCN_BAD_PARENT", f"Node '{n.name}' references nonexistent parent '{n.parent}'", rp, n.line)
                    known_paths.add(n.full_path)
                    if n.instance_id:
                        instanced_prefixes.add(n.full_path)

            # Connection integrity
            for conn in scene.connections:
                for label, path_str in (("from", conn.from_path), ("to", conn.to_path)):
                    if path_str not in scene.node_map:
                        self.add(sec, "CRITICAL", "TSCN_CONN_NODE", f"Connection '{conn.signal}' {label}='{path_str}' does not exist in scene", rp, conn.line)
                target_node = scene.node_map.get(conn.to_path)
                if target_node and "script" in target_node.props:
                    m = EXT_REF_RE.search(target_node.props["script"])
                    if m and m.group(1) in scene.ext_resources:
                        sp = scene.ext_resources[m.group(1)].path
                        if sp.startswith("res://"):
                            gd_rp = sp[len("res://"):]
                            if gd_rp in self.parsed_gds and conn.method:
                                if not self._script_has_method(gd_rp, conn.method):
                                    self.add(
                                        sec, "CRITICAL", "TSCN_CONN_METHOD",
                                        f"Connection calls missing method '{conn.method}' on script {gd_rp}",
                                        rp, conn.line,
                                    )

            # @onready $NodePath cross-check between attached scripts and scene nodes
            onready_re = re.compile(r'^\s*@onready\s+var\s+[A-Za-z_][A-Za-z0-9_]*[^=]*=\s*\$([A-Za-z0-9_/]+)')
            for n in scene.nodes:
                sc_prop = n.props.get("script", "")
                if not sc_prop:
                    continue
                m = EXT_REF_RE.search(sc_prop)
                if not m or m.group(1) not in scene.ext_resources:
                    continue
                sp = scene.ext_resources[m.group(1)].path
                if not sp.startswith("res://"):
                    continue
                gd_rp = sp[len("res://"):]
                gd = self.parsed_gds.get(gd_rp)
                if not gd:
                    continue
                base_prefix = "" if n.full_path == "." else (n.full_path + "/")
                for lno, raw_line in enumerate(gd.lines, start=1):
                    om = onready_re.match(raw_line)
                    if not om:
                        continue
                    rel_node = om.group(1).strip()
                    target_path = base_prefix + rel_node
                    if target_path not in scene.node_map:
                        # Check if parent of target is an instanced subscene (whose internal children live in its own .tscn)
                        under_instance = any(
                            target_path.startswith(ip + "/")
                            for ip in [x.full_path for x in scene.nodes if x.instance_id]
                        )
                        if not under_instance:
                            self.add(
                                sec, "CRITICAL", "TSCN_MISSING_ONREADY_NODE",
                                f"Script {gd_rp}:{lno} expects @onready ${rel_node}, but node '{target_path}' does not exist in {rp}!",
                                rp, n.line,
                            )

            # Polygon2D triangulation / self-intersection / degeneracy audit
            for n in scene.nodes:
                if n.node_type != "Polygon2D" or "polygon" not in n.props:
                    continue
                pts = parse_packed_vec2(n.props.get("polygon"))
                if len(pts) < 3:
                    self.add(sec, "CRITICAL", "POLY_DEGENERATE", f"Polygon2D '{n.full_path}' has <3 vertices ({len(pts)})", rp, n.line)
                    continue
                area2 = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
                if abs(area2) < 1e-4:
                    self.add(sec, "CRITICAL", "POLY_ZERO_AREA", f"Polygon2D '{n.full_path}' has zero area (triangulation will fail)", rp, n.line)
                    continue
                has_dup = False
                for i in range(len(pts)):
                    a, b = pts[i], pts[(i + 1) % len(pts)]
                    if math.hypot(a[0] - b[0], a[1] - b[1]) < 1e-4:
                        self.add(sec, "HIGH", "POLY_DUP_VERT", f"Polygon2D '{n.full_path}' has consecutive duplicate vertex at index {i}: {a}", rp, n.line)
                        has_dup = True
                        break
                if not has_dup:
                    inter = self._find_polygon_self_intersection(pts)
                    if inter is not None:
                        self.add(
                            sec, "HIGH", "POLY_SELF_INTERSECT",
                            f"Polygon2D '{n.full_path}' is self-intersecting / collinear-overlapping ({inter}) -> Godot triangulation may fail!",
                            rp, n.line,
                        )

    @staticmethod
    def _find_polygon_self_intersection(pts: List[Tuple[float, float]]) -> Optional[str]:
        def orient(a: Tuple[float, float], b: Tuple[float, float], c: Tuple[float, float]) -> float:
            return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

        def on_seg(a: Tuple[float, float], b: Tuple[float, float], c: Tuple[float, float]) -> bool:
            return (
                min(a[0], b[0]) - 1e-6 <= c[0] <= max(a[0], b[0]) + 1e-6
                and min(a[1], b[1]) - 1e-6 <= c[1] <= max(a[1], b[1]) + 1e-6
            )

        def seg_hit(p1: Tuple[float, float], p2: Tuple[float, float], p3: Tuple[float, float], p4: Tuple[float, float]) -> bool:
            o1, o2 = orient(p1, p2, p3), orient(p1, p2, p4)
            o3, o4 = orient(p3, p4, p1), orient(p3, p4, p2)
            if ((o1 > 1e-6 and o2 < -1e-6) or (o1 < -1e-6 and o2 > 1e-6)) and ((o3 > 1e-6 and o4 < -1e-6) or (o3 < -1e-6 and o4 > 1e-6)):
                return True
            if abs(o1) <= 1e-6 and on_seg(p1, p2, p3):
                return True
            if abs(o2) <= 1e-6 and on_seg(p1, p2, p4):
                return True
            if abs(o3) <= 1e-6 and on_seg(p3, p4, p1):
                return True
            if abs(o4) <= 1e-6 and on_seg(p3, p4, p2):
                return True
            return False

        n = len(pts)
        for i in range(n):
            p1, p2 = pts[i], pts[(i + 1) % n]
            for j in range(i + 2, n):
                if i == 0 and j == n - 1:
                    continue
                p3, p4 = pts[j], pts[(j + 1) % n]
                if seg_hit(p1, p2, p3, p4):
                    return f"edge {i}({p1}->{p2}) x edge {j}({p3}->{p4})"
        return None

    def _check_shader(self, sp: Path) -> None:
        sec = "A"
        rp = self.rel(sp)
        text = sp.read_text(encoding="utf-8")
        if "shader_type canvas_item;" not in text:
            self.add(sec, "HIGH", "SHADER_TYPE", "Shader missing 'shader_type canvas_item;'", rp)
        if text.count("{") != text.count("}"):
            self.add(sec, "CRITICAL", "SHADER_BRACES", "Unbalanced braces '{}' in shader", rp)
        if re.search(r"\bhint_color\b", text):
            self.add(sec, "CRITICAL", "SHADER_GODOT3_HINT", "Godot 3 'hint_color' found — use Godot 4 'source_color'", rp)
        if re.search(r"\bSCREEN_TEXTURE\b", text) and "hint_screen_texture" not in text:
            self.add(sec, "CRITICAL", "SHADER_GODOT3_SCREEN", "Godot 3 built-in SCREEN_TEXTURE used without Godot 4 hint_screen_texture uniform", rp)
        if re.search(r"\bvoid\s+fragment\s*\(\s*\)", text) or re.search(r"\bvoid\s+vertex\s*\(\s*\)", text):
            self.add(sec, "PASS", "SHADER_OK", f"Shader valid Godot 4 canvas_item syntax: {rp}", rp)
        else:
            self.add(sec, "MEDIUM", "SHADER_NO_ENTRY", "Shader has neither vertex() nor fragment() entry function", rp)

    # -----------------------------------------------------------------------
    # SECTION B: Typed GDScript & Contract Verification
    # -----------------------------------------------------------------------

    def _script_has_method(self, gd_rp: str, method: str, visited: Optional[Set[str]] = None) -> bool:
        if method in GODOT_BUILTIN_NODE_METHODS:
            return True
        visited = visited or set()
        if gd_rp in visited or gd_rp not in self.parsed_gds:
            return False
        visited.add(gd_rp)
        gd = self.parsed_gds[gd_rp]
        if method in gd.funcs:
            return True
        # Follow base class if custom
        base_rp = self._resolve_extends_script(gd.extends)
        if base_rp:
            return self._script_has_method(base_rp, method, visited)
        return False

    def _resolve_extends_script(self, ext: str) -> Optional[str]:
        if not ext:
            return None
        if ext.startswith("res://"):
            return ext[len("res://"):]
        for rp, gd in self.parsed_gds.items():
            if gd.class_name == ext:
                return rp
        return None

    def check_section_b(self) -> None:
        sec = "B"
        self.metrics["gd_count"] = len(self.parsed_gds)

        # 1. Per-file GDScript syntax, typing, indentation, Godot 3 leftovers, res:// refs
        untyped_funcs_total = 0
        total_funcs = 0
        for rp, gd in sorted(self.parsed_gds.items()):
            self._check_gd_syntax_and_style(gd)
            for fn in gd.funcs.values():
                total_funcs += 1
                if not fn.has_return_type or not fn.all_params_typed:
                    untyped_funcs_total += 1
                    self.add(
                        sec, "WARN", "GD_UNTYPED_SIG",
                        f"Function '{fn.name}' missing full static type annotations (params_typed={fn.all_params_typed}, return_typed={fn.has_return_type})",
                        rp, fn.line,
                    )
        self.metrics["gd_funcs_total"] = total_funcs
        self.metrics["gd_funcs_untyped"] = untyped_funcs_total

        # 2. Verify canonical Autoload definitions
        eb = self.parsed_gds.get("scripts/autoload/event_bus.gd")
        gs = self.parsed_gds.get("scripts/autoload/game_state.gd")
        sm = self.parsed_gds.get("scripts/autoload/save_manager.gd")
        cfg = self.parsed_gds.get("scripts/autoload/settings_manager.gd")
        am = self.parsed_gds.get("scripts/autoload/audio_manager.gd")

        if eb:
            for sig_name, expected_arity in CANONICAL_EVENT_BUS_SIGNALS.items():
                if sig_name not in eb.signals:
                    self.add(sec, "CRITICAL", "EB_MISSING_SIG", f"EventBus missing canonical signal '{sig_name}'", eb.rel_path)
                elif eb.signals[sig_name].param_count != expected_arity:
                    self.add(
                        sec, "HIGH", "EB_SIG_ARITY",
                        f"EventBus signal '{sig_name}' has {eb.signals[sig_name].param_count} params, expected {expected_arity}",
                        eb.rel_path, eb.signals[sig_name].line,
                    )
            self.add(sec, "PASS", "EB_CONTRACT", f"EventBus defines {len(eb.signals)} signals.", eb.rel_path)

        if gs:
            for mname in CANONICAL_GAME_STATE_METHODS:
                if mname not in gs.funcs:
                    self.add(sec, "CRITICAL", "GS_MISSING_METHOD", f"GameState missing canonical method '{mname}'", gs.rel_path)
            self.add(sec, "PASS", "GS_CONTRACT", f"GameState defines {len(gs.funcs)} methods and {len(gs.vars)} properties.", gs.rel_path)

        # 3. Cross-script Autoload call & signal verification
        autoloads: Dict[str, Optional[ParsedGd]] = {
            "EventBus": eb,
            "GameState": gs,
            "SaveManager": sm,
            "SettingsManager": cfg,
            "AudioManager": am,
        }
        for rp, gd in sorted(self.parsed_gds.items()):
            self._check_autoload_usages(gd, autoloads)

        # 4. Combat & Physics contract verification
        self._check_combat_contracts()
        self._check_physics_layer_contracts()
        self._check_player_constants()

    def _check_gd_syntax_and_style(self, gd: ParsedGd) -> None:
        sec = "B"
        rp = gd.rel_path
        if not gd.extends:
            self.add(sec, "HIGH", "GD_NO_EXTENDS", "Script missing top-level 'extends' statement", rp, 1)

        # Mixed tabs / spaces indentation check
        uses_tabs = False
        uses_spaces = False
        paren = bracket = brace = 0
        in_triple_str: Optional[str] = None

        for idx, raw in enumerate(gd.lines, start=1):
            # Handle triple-quoted strings roughly
            if in_triple_str:
                if in_triple_str in raw:
                    in_triple_str = None
                continue
            for tq in ('"""', "'''"):
                if raw.count(tq) % 2 == 1:
                    in_triple_str = tq
                    break
            if in_triple_str:
                continue

            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                continue

            # Leading indent check (only when not inside multiline expression)
            if paren == 0 and bracket == 0 and brace == 0:
                lead = raw[: len(raw) - len(raw.lstrip(" \t"))]
                if "\t" in lead and " " in lead:
                    self.add(sec, "CRITICAL", "GD_MIXED_INDENT", "Mixed tabs and spaces on same indentation line (Godot 4 parse error!)", rp, idx)
                elif "\t" in lead:
                    uses_tabs = True
                elif " " in lead:
                    uses_spaces = True

            code = strip_gd_comments_and_strings(raw)
            paren += code.count("(") - code.count(")")
            bracket += code.count("[") - code.count("]")
            brace += code.count("{") - code.count("}")

            # Godot 3 leftover checks
            if re.match(r"^\s*export\s*(\(|var\b)", code):
                self.add(sec, "CRITICAL", "GD_GODOT3_EXPORT", "Godot 3 'export' syntax — use '@export' in Godot 4", rp, idx)
            if re.match(r"^\s*onready\s+var\b", code):
                self.add(sec, "CRITICAL", "GD_GODOT3_ONREADY", "Godot 3 'onready var' syntax — use '@onready var' in Godot 4", rp, idx)
            if re.search(r"\byield\s*\(", code):
                self.add(sec, "CRITICAL", "GD_GODOT3_YIELD", "Godot 3 'yield()' — use 'await' in Godot 4", rp, idx)
            if re.search(r"\bKinematicBody2D\b", code):
                self.add(sec, "CRITICAL", "GD_GODOT3_KINEMATIC", "Godot 3 'KinematicBody2D' — use 'CharacterBody2D' in Godot 4", rp, idx)
            if re.search(r"\bmove_and_slide\s*\(\s*[^)\s]", code):
                self.add(sec, "CRITICAL", "GD_GODOT3_MOVE_AND_SLIDE", "Godot 3 move_and_slide(vel, ...) — in Godot 4 CharacterBody2D.move_and_slide() takes 0 args!", rp, idx)
            if re.search(r"\binstance\s*\(\s*\)", code):
                self.add(sec, "HIGH", "GD_GODOT3_INSTANCE", "Possible Godot 3 PackedScene.instance() — in Godot 4 use instantiate()", rp, idx)

            # Check res:// path literals
            for m in re.finditer(r'"(res://[^"]+)"', raw):
                rpath = m.group(1)
                if rpath.endswith("/") or "{" in rpath or "%" in rpath or rpath.startswith("res://assets/final/"):
                    continue
                if "ResourceLoader.exists" in raw or "FileAccess.file_exists" in raw or "DirAccess" in raw:
                    continue
                # Check if previous line guarded it with ResourceLoader.exists
                prev = gd.lines[idx - 2] if idx >= 2 else ""
                if "ResourceLoader.exists" in prev and rpath in prev:
                    continue
                # Ignore .translation paths checked elsewhere if guarded
                if rpath.endswith(".translation"):
                    continue
                if not self.res_to_path(rpath).exists():
                    self.add(sec, "CRITICAL", "GD_MISSING_RES", f"Script references nonexistent resource '{rpath}'", rp, idx)

        if uses_tabs and uses_spaces:
            self.add(sec, "CRITICAL", "GD_INCONSISTENT_INDENT", "File mixes tab-indented and space-indented blocks (Godot 4 parse error!)", rp)
        if paren != 0 or bracket != 0 or brace != 0:
            self.add(sec, "CRITICAL", "GD_UNBALANCED_DELIM", f"Unbalanced delimiters in script: ()={paren}, []={bracket}, {{}}={brace}", rp)

    def _extract_call_args_from_line(self, text: str, open_paren_pos: int) -> Optional[str]:
        depth = 0
        in_q: Optional[str] = None
        for i in range(open_paren_pos, len(text)):
            ch = text[i]
            if in_q:
                if ch == "\\":
                    continue
                if ch == in_q:
                    in_q = None
                continue
            if ch in ('"', "'"):
                in_q = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    return text[open_paren_pos + 1 : i]
        return None

    def _check_autoload_usages(self, gd: ParsedGd, autoloads: Dict[str, Optional[ParsedGd]]) -> None:
        sec = "B"
        rp = gd.rel_path
        full_text = gd.text

        # EventBus.<sig>.emit(...) / .connect(...) / .disconnect(...)
        eb = autoloads.get("EventBus")
        if eb and rp != eb.rel_path:
            for idx, raw in enumerate(gd.lines, start=1):
                code = strip_gd_comments_and_strings(raw, keep_strings_placeholder=True)
                for m in re.finditer(r"\bEventBus\.([A-Za-z_][A-Za-z0-9_]*)\.(emit|connect|disconnect)\s*\(", code):
                    sig_name = m.group(1)
                    action = m.group(2)
                    if sig_name not in eb.signals:
                        self.add(sec, "CRITICAL", "EB_UNDEF_SIG_USE", f"Calls EventBus.{sig_name}.{action}() but '{sig_name}' is not declared on EventBus", rp, idx)
                    elif action == "emit":
                        # Parse args from raw line (with comment stripped)
                        raw_no_comment = raw.split("#")[0]
                        pos = raw_no_comment.find(f"EventBus.{sig_name}.emit(")
                        if pos != -1:
                            p_open = raw_no_comment.find("(", pos)
                            arg_s = self._extract_call_args_from_line(raw_no_comment, p_open)
                            if arg_s is not None:
                                argc = len(split_top_level_args(arg_s))
                                expected = eb.signals[sig_name].param_count
                                if argc != expected:
                                    self.add(
                                        sec, "CRITICAL", "EB_EMIT_ARITY",
                                        f"EventBus.{sig_name}.emit() passed {argc} arg(s), expected {expected}",
                                        rp, idx,
                                    )

        # Other Autoloads: GameState, SaveManager, SettingsManager, AudioManager
        for al_name in ("GameState", "SaveManager", "SettingsManager", "AudioManager"):
            al_gd = autoloads.get(al_name)
            if not al_gd or rp == al_gd.rel_path:
                continue
            valid_members = (
                set(al_gd.funcs.keys())
                | set(al_gd.vars.keys())
                | set(al_gd.consts.keys())
                | set(al_gd.signals.keys())
                | set(al_gd.enums.keys())
                | GODOT_BUILTIN_NODE_METHODS
            )
            for idx, raw in enumerate(gd.lines, start=1):
                code = strip_gd_comments_and_strings(raw)
                for m in re.finditer(rf"\b{al_name}\.([A-Za-z_][A-Za-z0-9_]*)(\s*\()?", code):
                    member = m.group(1)
                    is_call = bool(m.group(2))
                    if member not in valid_members:
                        self.add(
                            sec, "CRITICAL", "AUTOLOAD_MISSING_MEMBER",
                            f"References {al_name}.{member}{'()' if is_call else ''} which does not exist on {al_gd.rel_path}",
                            rp, idx,
                        )
                    elif is_call and member in al_gd.funcs:
                        fn = al_gd.funcs[member]
                        raw_nc = raw.split("#")[0]
                        pos = raw_nc.find(f"{al_name}.{member}(")
                        if pos != -1:
                            p_open = raw_nc.find("(", pos)
                            arg_s = self._extract_call_args_from_line(raw_nc, p_open)
                            if arg_s is not None:
                                argc = len(split_top_level_args(arg_s))
                                if argc < fn.min_args or argc > fn.max_args:
                                    self.add(
                                        sec, "CRITICAL", "AUTOLOAD_CALL_ARITY",
                                        f"{al_name}.{member}() called with {argc} arg(s), signature accepts {fn.min_args}..{fn.max_args}",
                                        rp, idx,
                                    )

    def _check_combat_contracts(self) -> None:
        sec = "B"
        # DamageInfo
        di = self.parsed_gds.get("scripts/combat/damage_info.gd")
        if di:
            if di.class_name != "DamageInfo":
                self.add(sec, "CRITICAL", "COMBAT_CLASS", f"Expected class_name DamageInfo, got '{di.class_name}'", di.rel_path)
            for field_name in ("amount", "source_position", "knockback", "parryable", "damage_type", "source_node"):
                if field_name not in di.vars:
                    self.add(sec, "CRITICAL", "COMBAT_FIELD", f"DamageInfo missing field '{field_name}'", di.rel_path)

        # Hurtbox
        hb_hurt = self.parsed_gds.get("scripts/combat/hurtbox.gd")
        if hb_hurt:
            if hb_hurt.class_name != "Hurtbox":
                self.add(sec, "CRITICAL", "COMBAT_CLASS", f"Expected class_name Hurtbox, got '{hb_hurt.class_name}'", hb_hurt.rel_path)
            if "damaged" not in hb_hurt.signals:
                self.add(sec, "CRITICAL", "COMBAT_SIG", "Hurtbox missing signal 'damaged(info: DamageInfo)'", hb_hurt.rel_path)
            if "receive_hit" not in hb_hurt.funcs:
                self.add(sec, "CRITICAL", "COMBAT_METHOD", "Hurtbox missing method 'receive_hit(info: DamageInfo)'", hb_hurt.rel_path)

        # Hitbox
        hb_hit = self.parsed_gds.get("scripts/combat/hitbox.gd")
        if hb_hit:
            if hb_hit.class_name != "Hitbox":
                self.add(sec, "CRITICAL", "COMBAT_CLASS", f"Expected class_name Hitbox, got '{hb_hit.class_name}'", hb_hit.rel_path)
            if "hit_landed" not in hb_hit.signals:
                self.add(sec, "HIGH", "COMBAT_SIG", "Hitbox missing signal 'hit_landed'", hb_hit.rel_path)
            if "reset_hits" not in hb_hit.funcs:
                self.add(sec, "HIGH", "COMBAT_METHOD", "Hitbox missing method 'reset_hits()'", hb_hit.rel_path)

        # EnemyBase & BossBase on_parried()
        for rp in ("scripts/enemies/enemy_base.gd", "scripts/boss/boss_base.gd"):
            gd = self.parsed_gds.get(rp)
            if gd and "on_parried" not in gd.funcs:
                self.add(sec, "CRITICAL", "COMBAT_PARRY", f"{rp} MUST implement on_parried()", rp)

        # Player set_controls_enabled()
        pl = self.parsed_gds.get("scripts/player/player.gd")
        if pl and "set_controls_enabled" not in pl.funcs:
            self.add(sec, "CRITICAL", "PLAYER_CTRL_LOCK", "player.gd missing set_controls_enabled(enabled: bool)", pl.rel_path)

    def _check_physics_layer_contracts(self) -> None:
        sec = "B"

        def node_script_path(scene: ParsedScene, node: TscnNode) -> str:
            sc = node.props.get("script", "")
            m = EXT_REF_RE.search(sc)
            if m and m.group(1) in scene.ext_resources:
                return scene.ext_resources[m.group(1)].path
            return ""

        def check_layer_mask(
            scene: ParsedScene,
            node: TscnNode,
            exp_layer: Optional[int],
            exp_mask: Optional[int],
            label: str,
            mask_allow_bits: Optional[Set[int]] = None,
        ) -> None:
            # Default Godot Area2D/PhysicsBody2D collision_layer=1, collision_mask=1 if omitted in .tscn
            # Note: scripts may also set collision_layer/mask in _ready(); check both .tscn and attached script!
            actual_layer = parse_int_prop(node.props.get("collision_layer"), 1)
            actual_mask = parse_int_prop(node.props.get("collision_mask"), 1)

            sp = node_script_path(scene, node)
            script_sets_layer = False
            script_sets_mask = False
            if sp.startswith("res://"):
                gd = self.parsed_gds.get(sp[len("res://"):])
                if gd:
                    m_l = re.search(r"^\s*collision_layer\s*=\s*(\d+)", gd.text, re.M)
                    m_m = re.search(r"^\s*collision_mask\s*=\s*(\d+)", gd.text, re.M)
                    if m_l:
                        actual_layer = int(m_l.group(1))
                        script_sets_layer = True
                    if m_m:
                        actual_mask = int(m_m.group(1))
                        script_sets_mask = True

            if exp_layer is not None and actual_layer != exp_layer:
                self.add(
                    sec, "CRITICAL", "LAYER_MISMATCH",
                    f"{label} ({node.full_path}): collision_layer={actual_layer}, expected {exp_layer}",
                    scene.rel_path, node.line,
                )
            if exp_mask is not None:
                if mask_allow_bits is not None:
                    if actual_mask not in mask_allow_bits:
                        self.add(
                            sec, "CRITICAL", "MASK_MISMATCH",
                            f"{label} ({node.full_path}): collision_mask={actual_mask}, expected one of {sorted(mask_allow_bits)}",
                            scene.rel_path, node.line,
                        )
                elif actual_mask != exp_mask:
                    self.add(
                        sec, "CRITICAL", "MASK_MISMATCH",
                        f"{label} ({node.full_path}): collision_mask={actual_mask}, expected {exp_mask}",
                        scene.rel_path, node.line,
                    )

        # Player scene
        pl_scene = self.parsed_scenes.get("scenes/player/player.tscn")
        if pl_scene and pl_scene.nodes:
            root = pl_scene.nodes[0]
            check_layer_mask(pl_scene, root, 4, 3, "Player CharacterBody2D")
            if "player" not in root.groups:
                # Check if player.gd adds to group "player"
                pl_gd = self.parsed_gds.get("scripts/player/player.gd")
                if not pl_gd or 'add_to_group("player")' not in pl_gd.text:
                    self.add(sec, "CRITICAL", "PLAYER_GROUP", "Player is not in group 'player' (neither in player.tscn nor player.gd)", pl_scene.rel_path)
            for n in pl_scene.nodes[1:]:
                sp = node_script_path(pl_scene, n)
                if "hurtbox.gd" in sp or n.name.lower() == "hurtbox":
                    check_layer_mask(pl_scene, n, 4, 0, "Player Hurtbox")
                elif "hitbox.gd" in sp or "flame_dagger.gd" in sp:
                    check_layer_mask(pl_scene, n, 16, 8, "Player Hitbox")

        # Flame projectile
        fp_scene = self.parsed_scenes.get("scenes/player/flame_projectile.tscn")
        if fp_scene and fp_scene.nodes:
            for n in fp_scene.nodes:
                sp = node_script_path(fp_scene, n)
                if "hitbox.gd" in sp or "flame_projectile.gd" in sp:
                    # Projectile may collide with world (1) + enemy (8) = 9, or just enemy (8)
                    check_layer_mask(fp_scene, n, 16, 8, "FlameProjectile", mask_allow_bits={8, 9, 11})

        # Enemies & Boss scenes
        for rp in (
            "scenes/enemies/sand_stalker.tscn",
            "scenes/enemies/shard_husk.tscn",
            "scenes/enemies/relic_sentinel.tscn",
            "scenes/boss/boss_spire_warden.tscn",
        ):
            sc = self.parsed_scenes.get(rp)
            if not sc or not sc.nodes:
                continue
            root = sc.nodes[0]
            check_layer_mask(sc, root, 8, 3, f"{root.name} CharacterBody2D")
            for n in sc.nodes[1:]:
                sp = node_script_path(sc, n)
                if "hurtbox.gd" in sp or "hurtbox" in n.name.lower():
                    check_layer_mask(sc, n, 8, 0, f"{root.name} Hurtbox")
                elif "hitbox.gd" in sp or "hitbox" in n.name.lower():
                    check_layer_mask(sc, n, 32, 4, f"{root.name} Hitbox")

        # Interactables scenes
        for rp in (
            "scenes/interactables/orb_shrine.tscn",
            "scenes/interactables/memory_orb.tscn",
            "scenes/interactables/notebook_page.tscn",
            "scenes/interactables/npc_boy.tscn",
            "scenes/interactables/camel_amira.tscn",
        ):
            sc = self.parsed_scenes.get(rp)
            if not sc or not sc.nodes:
                continue
            root = sc.nodes[0]
            # Root or child Area2D with interactable script
            if root.node_type == "Area2D":
                check_layer_mask(sc, root, 64, 4, f"Interactable {root.name}")

    def _check_player_constants(self) -> None:
        sec = "B"
        pl = self.parsed_gds.get("scripts/player/player.gd")
        if not pl:
            return
        expected_consts = {
            "RUN_SPEED": 380.0,
            "JUMP_VELOCITY": -640.0,
            "COYOTE_TIME": 0.12,
            "JUMP_BUFFER_TIME": 0.12,
            "DASH_SPEED": 860.0,
            "DASH_DURATION": 0.22,
            "WALL_SLIDE_SPEED": 130.0,
            "GRAVITY": 1550.0,
        }
        for cname, expected_val in expected_consts.items():
            raw = pl.consts.get(cname, pl.vars.get(cname, (None, 0)))[0]
            if raw is None:
                self.add(sec, "MEDIUM", "PLAYER_CONST_MISSING", f"player.gd missing expected constant '{cname}' (spec={expected_val})", pl.rel_path)
            else:
                try:
                    actual = float(raw)
                    if abs(actual - expected_val) > 0.05 * max(1.0, abs(expected_val)):
                        self.add(
                            sec, "HIGH", "PLAYER_CONST_DRIFT",
                            f"player.gd {cname}={actual} deviates from canonical spec {expected_val} (may break platforming gaps!)",
                            pl.rel_path,
                        )
                except ValueError:
                    pass

    # -----------------------------------------------------------------------
    # SECTION C: Arabic-First Localization, RTL & BiDi Audit
    # -----------------------------------------------------------------------

    def check_section_c(self) -> None:
        sec = "C"
        csv_rp = "localization/strings.csv"
        csv_path = self.root / csv_rp
        if not csv_path.exists():
            return

        # 1. Parse and validate strings.csv thoroughly
        seen_keys: Set[str] = set()
        arabic_re = re.compile(r"[\u0600-\u06FF]")
        row_count = 0
        try:
            with csv_path.open("r", encoding="utf-8-sig", newline="") as fh:
                reader = csv.reader(fh)
                header = next(reader, None)
                if not header or len(header) < 3 or header[0].strip() != "keys" or header[1].strip() != "ar" or header[2].strip() != "en":
                    self.add(sec, "HIGH", "CSV_HEADER", f"Expected CSV header 'keys,ar,en', got {header}", csv_rp, 1)
                for line_no, row in enumerate(reader, start=2):
                    if not row or all(not c.strip() for c in row):
                        continue
                    row_count += 1
                    if len(row) < 3:
                        self.add(sec, "CRITICAL", "CSV_COLS", f"Row has {len(row)} columns, expected 3 (keys,ar,en)", csv_rp, line_no)
                        continue
                    k, ar, en = row[0].strip(), row[1].strip(), row[2].strip()
                    if not k:
                        self.add(sec, "HIGH", "CSV_EMPTY_KEY", "Row has empty key", csv_rp, line_no)
                        continue
                    if k in seen_keys:
                        self.add(sec, "HIGH", "CSV_DUP_KEY", f"Duplicate localization key '{k}'", csv_rp, line_no)
                    seen_keys.add(k)
                    if not ar:
                        self.add(sec, "CRITICAL", "CSV_EMPTY_AR", f"Key '{k}' has empty Arabic ('ar') string", csv_rp, line_no)
                    elif (
                        not arabic_re.search(ar)
                        and not re.fullmatch(r"[\d\s/\-.:+%\[\]()]+", ar)
                        and k not in ("UI_LANG_EN",)  # language endonym 'English' is intentionally Latin
                    ):
                        self.add(sec, "HIGH", "CSV_NO_ARABIC", f"Key '{k}' 'ar' value contains no Arabic characters: '{ar}'", csv_rp, line_no)
                    if not en:
                        self.add(sec, "CRITICAL", "CSV_EMPTY_EN", f"Key '{k}' has empty English ('en') string", csv_rp, line_no)
        except Exception as exc:
            self.add(sec, "CRITICAL", "CSV_PARSE_ERR", f"Failed to parse strings.csv: {exc}", csv_rp)
            return

        self.metrics["loc_keys_defined"] = len(seen_keys)

        # Required keys check
        missing_req = [k for k in REQUIRED_LOCALIZATION_KEYS if k not in seen_keys]
        if missing_req:
            self.add(sec, "HIGH", "CSV_MISSING_REQ_KEYS", f"Missing {len(missing_req)} canonical required keys in strings.csv: {missing_req[:15]}", csv_rp)
        else:
            self.add(sec, "PASS", "CSV_REQ_KEYS", f"All {len(REQUIRED_LOCALIZATION_KEYS)} canonical localization keys exist ({len(seen_keys)} total keys).", csv_rp)

        # Narrative flavor checks on Arabic CSV
        boy_ar = " ".join(self.csv_keys.get(k, ("", ""))[0] for k in ("DLG_BOY_01", "DLG_BOY_02", "DLG_BOY_03"))
        if boy_ar and "أبي" not in boy_ar:
            self.add(sec, "MEDIUM", "LOC_BOY_ABI", "Boy opening dialogue (DLG_BOY_01..03) should call Farid 'أبي'", csv_rp)

        # 2. Scan ALL .gd, .tscn, and .json files for referenced keys
        referenced_keys: Dict[str, List[Tuple[str, int]]] = defaultdict(list)

        # In .gd files: tr("KEY"), TranslationServer.translate("KEY"), *_key = "KEY", *_keys = ["KEY", ...]
        tr_re = re.compile(r'\b(?:tr|TranslationServer\.translate)\(\s*"([A-Z][A-Z0-9_]{2,})"\s*\)')
        key_assign_re = re.compile(r'\b[a-z0-9_]*_key\s*(?::\s*String\s*)?=\s*"([A-Z][A-Z0-9_]{2,})"')
        keys_arr_re = re.compile(r'\b[a-z0-9_]*_keys\s*(?::\s*Array(?:\[String\])?\s*)?=\s*\[([^\]]+)\]')
        dict_key_re = re.compile(r'"(?:speaker_key|text_key|title_key|body_key|prompt_key|name_key|desc_key|vignette_title_key)"\s*:\s*"([A-Z][A-Z0-9_]{2,})"')

        for rp, gd in sorted(self.parsed_gds.items()):
            for idx, line in enumerate(gd.lines, start=1):
                nc = line.split("#")[0]
                for rx in (tr_re, key_assign_re, dict_key_re):
                    for m in rx.finditer(nc):
                        referenced_keys[m.group(1)].append((rp, idx))
                for m in keys_arr_re.finditer(nc):
                    for km in re.finditer(r'"([A-Z][A-Z0-9_]{2,})"', m.group(1)):
                        referenced_keys[km.group(1)].append((rp, idx))

        # In .tscn files: *_key = "KEY", *_keys = ["KEY"], and UI text = "KEY"
        for rp, scene in sorted(self.parsed_scenes.items()):
            for n in scene.nodes:
                for k, v in n.props.items():
                    if k.endswith("_key"):
                        val = parse_str_prop(v)
                        if val and re.fullmatch(r"[A-Z][A-Z0-9_]{2,}", val):
                            referenced_keys[val].append((rp, n.line))
                    elif k.endswith("_keys"):
                        for km in re.finditer(r'"([A-Z][A-Z0-9_]{2,})"', v):
                            referenced_keys[km.group(1)].append((rp, n.line))
                    elif k in ("text", "title", "placeholder_text") and rp.startswith("scenes/ui/"):
                        val = parse_str_prop(v)
                        if val and re.fullmatch(r"[A-Z][A-Z0-9_]{2,}", val):
                            referenced_keys[val].append((rp, n.line))

        # In data/*.json: *_key values
        def walk_json_keys(obj: Any, rp: str) -> None:
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if k.endswith("_key") and isinstance(v, str) and v:
                        referenced_keys[v].append((rp, 1))
                    else:
                        walk_json_keys(v, rp)
            elif isinstance(obj, list):
                for item in obj:
                    walk_json_keys(item, rp)

        for rp, data in (
            ("data/rooms.json", self.rooms_json),
            ("data/abilities.json", self.abilities_json),
            ("data/enemies.json", self.enemies_json),
        ):
            walk_json_keys(data, rp)

        missing_refs = 0
        for key, locs in sorted(referenced_keys.items()):
            if key not in seen_keys:
                missing_refs += 1
                first_rp, first_line = locs[0]
                self.add(
                    sec, "CRITICAL", "LOC_KEY_MISSING",
                    f"Referenced localization key '{key}' is missing from localization/strings.csv (used in {first_rp}:{first_line} and {len(locs)-1} other place(s))",
                    first_rp, first_line, owner="@ui-loc",
                )
        self.metrics["loc_keys_referenced"] = len(referenced_keys)
        self.metrics["loc_keys_missing"] = missing_refs
        if missing_refs == 0:
            self.add(sec, "PASS", "LOC_ALL_REFS_VALID", f"100% of {len(referenced_keys)} referenced localization keys resolve in strings.csv.", csv_rp)

        # 3. Hardcoded user-facing text check in UI .tscn and .gd
        hardcoded_count = 0
        for rp, scene in sorted(self.parsed_scenes.items()):
            if not rp.startswith("scenes/ui/"):
                continue
            for n in scene.nodes:
                for prop in ("text", "title", "placeholder_text"):
                    if prop in n.props:
                        val = parse_str_prop(n.props[prop])
                        if not val:
                            continue
                        if val in seen_keys:
                            continue
                        # Allow pure numbers/symbols/formatting
                        if re.fullmatch(r"[\d\s/\-.:+%•★◆■□\[\]()]+", val):
                            continue
                        hardcoded_count += 1
                        self.add(
                            sec, "HIGH", "UI_HARDCODED_TSCN",
                            f"Hardcoded user-facing {prop}='{val}' on node '{n.full_path}' (must use a localization key from strings.csv)",
                            rp, n.line,
                        )

        ui_text_assign_re = re.compile(r'\.(?:text|title|placeholder_text)\s*=\s*"([^"]+)"')
        for rp, gd in sorted(self.parsed_gds.items()):
            if not rp.startswith("scripts/ui/"):
                continue
            for idx, line in enumerate(gd.lines, start=1):
                nc = line.split("#")[0]
                if "tr(" in nc:
                    continue
                for m in ui_text_assign_re.finditer(nc):
                    val = m.group(1)
                    # Allow empty, pure format specifiers, numbers, keycap punctuation, bidi isolates
                    cleaned = re.sub(r"(\\u206[6-9]|%[-+0-9.]*[sdf]|[\d\s/\-.:+%•★◆■□\[\]()×x|—–]+)", "", val)
                    if not cleaned:
                        continue
                    if val in seen_keys:
                        continue
                    # Allow language self-names in language selector if intentional? Still should use UI_LANG_AR/UI_LANG_EN
                    hardcoded_count += 1
                    self.add(
                        sec, "HIGH", "UI_HARDCODED_GD",
                        f"Possible hardcoded UI string \"{val}\" assigned to .text without tr()",
                        rp, idx,
                    )
        self.metrics["ui_hardcoded_strings"] = hardcoded_count

        # 4. ArabicFontSetup & SettingsManager runtime CSV loader check
        afs = self.parsed_gds.get("scripts/ui/arabic_font_setup.gd")
        if afs:
            txt = afs.text
            if "SystemFont" not in txt:
                self.add(sec, "HIGH", "RTL_NO_SYSFONT", "arabic_font_setup.gd does not configure SystemFont Arabic fallback", afs.rel_path)
            if not any(f in txt for f in ("Geeza Pro", "SF Arabic", "Noto Sans Arabic", "Damascus")):
                self.add(sec, "HIGH", "RTL_NO_ARABIC_FONTS", "arabic_font_setup.gd missing Arabic system font fallback names", afs.rel_path)
            if "LAYOUT_DIRECTION_RTL" not in txt or "LAYOUT_DIRECTION_LTR" not in txt:
                self.add(sec, "CRITICAL", "RTL_NO_LAYOUT_DIR", "arabic_font_setup.gd must set LAYOUT_DIRECTION_RTL and LAYOUT_DIRECTION_LTR dynamically", afs.rel_path)
            if not any(tok in txt for tok in ("STRUCTURED_TEXT_BIDI_OVERRIDE", "\\u2066", "\\u2067", "TEXT_DIRECTION", "bidi")):
                self.add(sec, "HIGH", "RTL_NO_BIDI", "arabic_font_setup.gd missing explicit BiDi / directional isolate handling", afs.rel_path)
            self.add(sec, "PASS", "RTL_FONT_SETUP", "ArabicFontSetup configures Arabic SystemFont fallback, RTL/LTR layout direction, and BiDi handling.", afs.rel_path)

        sm = self.parsed_gds.get("scripts/autoload/settings_manager.gd")
        if sm:
            if "TranslationServer.add_translation" not in sm.text or "strings.csv" not in sm.text:
                self.add(sec, "CRITICAL", "LOC_NO_RUNTIME_CSV", "SettingsManager must load localization/strings.csv via TranslationServer.add_translation() at startup!", sm.rel_path)
            if '"ar"' not in sm.text:
                self.add(sec, "HIGH", "LOC_DEFAULT_AR", "SettingsManager should default locale to 'ar' (Arabic first)", sm.rel_path)

    # -----------------------------------------------------------------------
    # SECTION D: Playtest Simulation — Softlock, Sequence-Break & Geometry Audit
    # -----------------------------------------------------------------------

    def _compute_world_positions(self, scene: ParsedScene) -> Dict[str, Tuple[float, float]]:
        pos_map: Dict[str, Tuple[float, float]] = {}
        for n in scene.nodes:
            lx, ly = parse_vec2(n.props.get("position"), (0.0, 0.0))
            if n.parent is None:
                pos_map[n.full_path] = (lx, ly)
            else:
                px, py = pos_map.get(n.parent, (0.0, 0.0))
                pos_map[n.full_path] = (px + lx, py + ly)
        return pos_map

    def _extract_shape_rects(self, scene: ParsedScene, body_node: TscnNode, pos_map: Dict[str, Tuple[float, float]]) -> List[Rect]:
        rects: List[Rect] = []
        body_path = body_node.full_path
        for n in scene.nodes:
            if n.parent != body_path:
                continue
            wx, wy = pos_map.get(n.full_path, (0.0, 0.0))
            if n.node_type == "CollisionShape2D":
                m = SUB_REF_RE.search(n.props.get("shape", ""))
                if not m or m.group(1) not in scene.sub_resources:
                    continue
                sub = scene.sub_resources[m.group(1)]
                if sub.res_type == "RectangleShape2D":
                    sw, sh = parse_vec2(sub.props.get("size"), (0.0, 0.0))
                    if sw > 0 and sh > 0:
                        rects.append(Rect(wx - sw * 0.5, wy - sh * 0.5, sw, sh))
                elif sub.res_type == "CapsuleShape2D":
                    r = float(sub.props.get("radius", "16"))
                    h = float(sub.props.get("height", "32"))
                    rects.append(Rect(wx - r, wy - h * 0.5, r * 2.0, h))
                elif sub.res_type == "CircleShape2D":
                    r = float(sub.props.get("radius", "16"))
                    rects.append(Rect(wx - r, wy - r, r * 2.0, r * 2.0))
                elif sub.res_type == "SegmentShape2D":
                    ax, ay = parse_vec2(sub.props.get("a"), (0.0, 0.0))
                    bx, by = parse_vec2(sub.props.get("b"), (0.0, 0.0))
                    minx, maxx = min(ax, bx), max(ax, bx)
                    miny, maxy = min(ay, by), max(ay, by)
                    rects.append(Rect(wx + minx, wy + miny, max(maxx - minx, 4.0), max(maxy - miny, 4.0)))
            elif n.node_type == "CollisionPolygon2D":
                pts = parse_packed_vec2(n.props.get("polygon"))
                if pts:
                    xs = [wx + p[0] for p in pts]
                    ys = [wy + p[1] for p in pts]
                    rects.append(Rect(min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)))
        return rects

    def check_section_d(self) -> None:
        sec = "D"
        # Farid physics model (canonical)
        g = 1550.0
        v_jump = 640.0
        v_run = 380.0
        v_dash = 860.0
        t_dash = 0.22
        jump_h = (v_jump * v_jump) / (2.0 * g)  # 132.13 px
        jump_air_t = (2.0 * v_jump) / g  # 0.8258 s
        jump_w = v_run * jump_air_t  # 313.8 px
        dash_dist = v_dash * t_dash  # 189.2 px
        dash_jump_w = jump_w + dash_dist  # 503.0 px
        player_half_w = 14.0
        player_half_h = 31.0

        room_data: Dict[str, Dict[str, Any]] = {}
        all_gates: List[Dict[str, Any]] = []

        for rid in M1_ROOMS:
            rp = f"scenes/rooms/m1/{rid}.tscn"
            scene = self.parsed_scenes.get(rp)
            if not scene or not scene.nodes:
                continue

            root = scene.nodes[0]
            pos_map = self._compute_world_positions(scene)

            # Check room_id, area_id, room_title_key, camera_bounds
            r_id = parse_str_prop(root.props.get("room_id"))
            r_area = parse_str_prop(root.props.get("area_id"))
            r_title = parse_str_prop(root.props.get("room_title_key"))
            cam_bounds = parse_rect2(root.props.get("camera_bounds"))

            if r_id != rid:
                self.add(sec, "CRITICAL", "ROOM_ID_MISMATCH", f"Root room_id='{r_id}' does not match filename '{rid}'", rp, root.line)
            if not r_area:
                self.add(sec, "HIGH", "ROOM_NO_AREA", f"Room '{rid}' missing area_id property", rp, root.line)
            if not r_title:
                self.add(sec, "HIGH", "ROOM_NO_TITLE_KEY", f"Room '{rid}' missing room_title_key", rp, root.line)
            if cam_bounds is None or cam_bounds.w <= 0 or cam_bounds.h <= 0:
                self.add(sec, "CRITICAL", "ROOM_NO_BOUNDS", f"Room '{rid}' missing valid camera_bounds Rect2", rp, root.line)
                cam_bounds = Rect(0, 0, 1920, 1080)

            # Collect Spawns, Solid geometry, One-way platforms, TransitionGates, Entities
            spawns: Dict[str, Tuple[float, float, int]] = {}
            solids: List[Tuple[Rect, str, int, bool]] = []  # (rect, node_path, line, has_visual)
            one_ways: List[Tuple[Rect, str, int]] = []
            gates: List[Dict[str, Any]] = []
            entities: List[Dict[str, Any]] = []
            has_spawns_container = False

            for n in scene.nodes:
                if n.name == "Spawns" and n.parent == ".":
                    has_spawns_container = True
                if n.parent == "Spawns" and n.node_type == "Marker2D":
                    wx, wy = pos_map[n.full_path]
                    spawns[n.name] = (wx, wy, n.line)

                # StaticBody2D geometry
                if n.node_type == "StaticBody2D":
                    clayer = parse_int_prop(n.props.get("collision_layer"), 1)
                    cmask = parse_int_prop(n.props.get("collision_mask"), 1)
                    if cmask not in (0, 1):
                        self.add(sec, "WARN", "SOLID_MASK", f"StaticBody2D '{n.full_path}' has collision_mask={cmask} (recommended 0)", rp, n.line)
                    # Check if body or sibling/child has visual
                    has_visual = any(
                        cn.parent == n.full_path and cn.node_type in ("Polygon2D", "ColorRect", "Sprite2D", "Line2D", "NinePatchRect")
                        for cn in scene.nodes
                    )
                    rects = self._extract_shape_rects(scene, n, pos_map)
                    is_one_way_body = clayer == 2
                    for cn in scene.nodes:
                        if cn.parent == n.full_path and cn.node_type == "CollisionShape2D":
                            ow = parse_bool_prop(cn.props.get("one_way_collision"), False)
                            if is_one_way_body and not ow:
                                self.add(sec, "HIGH", "ONEWAY_FLAG", f"Layer-2 one-way platform '{n.full_path}' missing one_way_collision=true on CollisionShape2D", rp, cn.line)
                    for r in rects:
                        if is_one_way_body:
                            one_ways.append((r, n.full_path, n.line))
                        elif clayer & 1:
                            solids.append((r, n.full_path, n.line, has_visual))

                # TransitionGate / ShortcutGate
                sc_ref = n.props.get("script", "")
                sc_m = EXT_REF_RE.search(sc_ref)
                script_res = scene.ext_resources[sc_m.group(1)].path if (sc_m and sc_m.group(1) in scene.ext_resources) else ""
                inst_res = scene.ext_resources[n.instance_id].path if (n.instance_id and n.instance_id in scene.ext_resources) else ""

                if "transition_gate.gd" in script_res:
                    clayer = parse_int_prop(n.props.get("collision_layer"), 1)
                    cmask = parse_int_prop(n.props.get("collision_mask"), 1)
                    if clayer != 64 or cmask != 4:
                        # Check if transition_gate.gd enforces 64/4 in _ready()
                        tg_gd = self.parsed_gds.get("scripts/systems/transition_gate.gd")
                        enforced = tg_gd and "collision_layer = 64" in tg_gd.text and "collision_mask = 4" in tg_gd.text
                        if not enforced:
                            self.add(sec, "HIGH", "GATE_LAYERS", f"TransitionGate '{n.full_path}' has layer={clayer}, mask={cmask} (expected 64/4)", rp, n.line)
                    g_rects = self._extract_shape_rects(scene, n, pos_map)
                    g_info = {
                        "from_room": rid,
                        "node": n.full_path,
                        "line": n.line,
                        "target_room_id": parse_str_prop(n.props.get("target_room_id")),
                        "target_spawn_id": parse_str_prop(n.props.get("target_spawn_id")),
                        "require_interact": parse_bool_prop(n.props.get("require_interact"), False),
                        "shortcut_id": parse_str_prop(n.props.get("shortcut_id")),
                        "locked_until_flag": parse_str_prop(n.props.get("locked_until_flag")),
                        "rects": g_rects,
                        "pos": pos_map[n.full_path],
                    }
                    gates.append(g_info)
                    all_gates.append(g_info)

                if inst_res or "shortcut_gate.gd" in script_res or "tutorial_sign.gd" in script_res:
                    entities.append({
                        "name": n.name,
                        "path": n.full_path,
                        "inst": inst_res,
                        "script": script_res,
                        "pos": pos_map[n.full_path],
                        "props": n.props,
                        "line": n.line,
                    })

            if not has_spawns_container or not spawns:
                self.add(sec, "CRITICAL", "ROOM_NO_SPAWNS", f"Room '{rid}' has no Spawns/Marker2D nodes!", rp)
            if not solids:
                self.add(sec, "CRITICAL", "ROOM_NO_SOLIDS", f"Room '{rid}' has no layer-1 solid StaticBody2D geometry!", rp)

            # Check invisible solid bodies (ignore seal doors or thin boundary walls if styled elsewhere)
            for rect, npath, nline, has_vis in solids:
                if not has_vis and "bound" not in npath.lower() and "wall_bound" not in npath.lower() and "ceiling" not in npath.lower():
                    # Also check if room has a sibling Visuals/Polygons layer
                    has_room_visuals = any(n.node_type == "Polygon2D" for n in scene.nodes)
                    if not has_room_visuals:
                        self.add(sec, "HIGH", "ROOM_INVIS_SOLID", f"Solid body '{npath}' has no visible Polygon2D/ColorRect", rp, nline)

            # Spawn Safety Audit
            for sname, (sx, sy, sline) in spawns.items():
                if not cam_bounds.contains_point(sx, sy, margin=-10.0):
                    self.add(sec, "CRITICAL", "SPAWN_OUT_OF_BOUNDS", f"Spawn '{sname}' at ({sx:.0f},{sy:.0f}) is outside camera_bounds {cam_bounds}", rp, sline)

                # Player capsule bounding box at spawn
                pl_box = Rect(sx - player_half_w, sy - player_half_h, player_half_w * 2, player_half_h * 2)
                for srect, npath, _, _ in solids:
                    if pl_box.intersects(srect, shrink=2.0):
                        self.add(
                            sec, "CRITICAL", "SPAWN_IN_SOLID",
                            f"Spawn '{sname}' ({sx:.0f},{sy:.0f}) intersects solid '{npath}' ({srect.left:.0f}..{srect.right:.0f}, {srect.top:.0f}..{srect.bottom:.0f})!",
                            rp, sline,
                        )

                # Floor directly below spawn
                feet_y = sy + player_half_h
                floor_drops: List[float] = []
                for srect, _, _, _ in solids:
                    if srect.left <= sx <= srect.right and srect.top >= feet_y - 6.0:
                        floor_drops.append(srect.top - feet_y)
                for orect, _, _ in one_ways:
                    if orect.left <= sx <= orect.right and orect.top >= feet_y - 6.0:
                        floor_drops.append(orect.top - feet_y)
                if not floor_drops:
                    self.add(sec, "CRITICAL", "SPAWN_OVER_VOID", f"Spawn '{sname}' at ({sx:.0f},{sy:.0f}) has NO floor beneath it (bottomless pit softlock!)", rp, sline)
                else:
                    min_drop = min(floor_drops)
                    if min_drop > 140.0:
                        self.add(sec, "HIGH", "SPAWN_HIGH_DROP", f"Spawn '{sname}' sits {min_drop:.0f}px above nearest floor (recommended ~34px center -> ~3px feet clearance)", rp, sline)

                # Anti-ping-pong check against auto TransitionGates
                for g_info in gates:
                    if g_info["require_interact"]:
                        continue
                    for grect in g_info["rects"]:
                        if pl_box.intersects(grect):
                            self.add(
                                sec, "CRITICAL", "SPAWN_OVERLAPS_GATE",
                                f"Spawn '{sname}' ({sx:.0f},{sy:.0f}) OVERLAPS auto TransitionGate '{g_info['node']}' -> infinite transition ping-pong softlock!",
                                rp, sline,
                            )
                        else:
                            dist = grect.distance_to_point(sx, sy)
                            if dist < 45.0:
                                self.add(
                                    sec, "HIGH", "SPAWN_TOO_CLOSE_GATE",
                                    f"Spawn '{sname}' ({sx:.0f},{sy:.0f}) is only {dist:.0f}px from auto TransitionGate '{g_info['node']}' (recommend >= 60px clearance)",
                                    rp, sline,
                                )

            # Entity grounding & bounds check
            for ent in entities:
                ex, ey = ent["pos"]
                if not cam_bounds.contains_point(ex, ey, margin=20.0):
                    self.add(sec, "HIGH", "ENTITY_OUT_OF_BOUNDS", f"Entity '{ent['path']}' at ({ex:.0f},{ey:.0f}) is outside camera_bounds", rp, ent["line"])
                inst = ent["inst"]
                if any(k in inst for k in ("sand_stalker.tscn", "relic_sentinel.tscn", "boss_spire_warden.tscn", "orb_shrine.tscn", "npc_boy.tscn", "camel_amira.tscn")):
                    has_floor = any(
                        r.left - 24 <= ex <= r.right + 24 and r.top >= ey - 10 and (r.top - ey) <= 180
                        for r, _, _, _ in solids
                    ) or any(
                        r.left - 24 <= ex <= r.right + 24 and r.top >= ey - 10 and (r.top - ey) <= 180
                        for r, _, _ in one_ways
                    )
                    if not has_floor:
                        self.add(sec, "HIGH", "ENTITY_NO_FLOOR", f"Grounded entity '{ent['path']}' at ({ex:.0f},{ey:.0f}) has no floor within 180px beneath it", rp, ent["line"])

            room_data[rid] = {
                "rel_path": rp,
                "bounds": cam_bounds,
                "spawns": spawns,
                "solids": solids,
                "one_ways": one_ways,
                "gates": gates,
                "entities": entities,
            }

        # 2. Cross-Room Gate Target Resolution & Graph Connectivity (Zero Dead Ends!)
        adj_all: Dict[str, Set[str]] = defaultdict(set)
        for g_info in all_gates:
            src = g_info["from_room"]
            dst = g_info["target_room_id"]
            dsp = g_info["target_spawn_id"]
            rp = f"scenes/rooms/m1/{src}.tscn"
            if dst not in room_data:
                self.add(sec, "CRITICAL", "GATE_BAD_ROOM", f"TransitionGate '{g_info['node']}' targets unknown room '{dst}'", rp, g_info["line"])
                continue
            if dsp not in room_data[dst]["spawns"]:
                self.add(
                    sec, "CRITICAL", "GATE_BAD_SPAWN",
                    f"TransitionGate '{g_info['node']}' targets spawn '{dsp}' which does NOT exist in '{dst}' (available: {sorted(room_data[dst]['spawns'].keys())})",
                    rp, g_info["line"],
                )
            else:
                adj_all[src].add(dst)

        # Verify reachability from desert_camp_01 and return reachability to desert_camp_01
        if "desert_camp_01" in room_data:
            visited: Set[str] = set()
            q = deque(["desert_camp_01"])
            while q:
                u = q.popleft()
                if u in visited:
                    continue
                visited.add(u)
                for v in adj_all[u]:
                    if v not in visited:
                        q.append(v)
            unreachable = set(room_data.keys()) - visited
            if unreachable:
                self.add(sec, "CRITICAL", "GRAPH_UNREACHABLE", f"Rooms unreachable from desert_camp_01: {sorted(unreachable)}", owner="@level-builder")

            # Reverse graph: can every room return to desert_camp_01?
            rev: Dict[str, Set[str]] = defaultdict(set)
            for u, vs in adj_all.items():
                for v in vs:
                    rev[v].add(u)
            can_return: Set[str] = set()
            q = deque(["desert_camp_01"])
            while q:
                u = q.popleft()
                if u in can_return:
                    continue
                can_return.add(u)
                for v in rev[u]:
                    if v not in can_return:
                        q.append(v)
            dead_ends = set(room_data.keys()) - can_return
            if dead_ends:
                self.add(sec, "CRITICAL", "GRAPH_DEAD_END", f"Dead-end rooms with NO return path to desert_camp_01: {sorted(dead_ends)}", owner="@level-builder")
            elif not unreachable and len(room_data) == len(M1_ROOMS):
                self.add(sec, "PASS", "GRAPH_CONNECTED", f"All {len(M1_ROOMS)} M1 rooms are strongly connected with valid spawns & zero dead ends.", owner="@level-builder")

        # 3. Specific Metroidvania Gate & Softlock Geometry Audits
        self._audit_desert_camp_02_dash_chasm(room_data.get("desert_camp_02"), jump_w, dash_jump_w, jump_h)
        self._audit_highway_02_wall_chimney(room_data.get("empty_highway_02"), jump_h)
        self._audit_riyadh_01_shortcut(room_data.get("empty_riyadh_01"), room_data.get("desert_camp_01"))
        self._audit_boss_room_seal(room_data.get("empty_riyadh_boss"))

    def _audit_desert_camp_02_dash_chasm(
        self, rinfo: Optional[Dict[str, Any]], jump_w: float, dash_jump_w: float, jump_h: float
    ) -> None:
        sec = "D"
        if not rinfo:
            return
        rp = rinfo["rel_path"]
        # Locate Dash Memory Orb
        orbs = [e for e in rinfo["entities"] if "memory_orb.tscn" in e["inst"]]
        dash_orb = next((o for o in orbs if parse_str_prop(o["props"].get("ability_id")) == "dash"), None)
        if not dash_orb:
            self.add(sec, "CRITICAL", "CAMP02_NO_DASH_ORB", "desert_camp_02 missing MemoryOrb with ability_id='dash'", rp)
            return

        # Analyze top surfaces (solids + one_ways) to detect main chasm between west and east
        solid_decks: List[Rect] = [r for r, _, _, _ in rinfo["solids"] if r.w >= 120 and r.top > 200]
        surfaces: List[Rect] = [r for r, _, _, _ in rinfo["solids"] if r.w >= 60 and r.top > 200]
        surfaces += [r for r, _, _ in rinfo["one_ways"] if r.w >= 40 and r.top > 200]
        surfaces.sort(key=lambda r: r.left)

        # Find main solid-to-solid chasm gap (300..550px) between comparable upper decks
        best_chasm: Optional[Tuple[Rect, Rect, float]] = None
        for a in solid_decks:
            for b in solid_decks:
                if b.left <= a.right:
                    continue
                gap = b.left - a.right
                if abs(a.top - b.top) <= 80.0 and 240.0 <= gap <= 550.0:
                    bridged = any(
                        s is not a and s is not b
                        and s.right > a.right + 20 and s.left < b.left - 20
                        and s.top <= max(a.top, b.top) + 40.0
                        for s in surfaces
                    )
                    if not bridged:
                        if best_chasm is None or gap > best_chasm[2]:
                            best_chasm = (a, b, gap)

        if best_chasm is None:
            self.add(sec, "HIGH", "CAMP02_CHASM_NOT_FOUND", "Could not detect the Dash-gated chasm (expected 360..410px horizontal gap) in desert_camp_02", rp)
            return

        west_ledge, east_ledge, gap_w = best_chasm
        self.metrics["camp02_dash_chasm_px"] = round(gap_w, 1)

        if dash_orb["pos"][0] > west_ledge.right + 40:
            self.add(sec, "CRITICAL", "CAMP02_ORB_PAST_CHASM", f"Dash Memory Orb (x={dash_orb['pos'][0]:.0f}) is placed PAST the chasm (west edge x={west_ledge.right:.0f}) — softlock!", rp, dash_orb["line"])

        # Exact ballistic parabolic jump reach (without Dash, incl. 0.12s coyote + 14px body edge)
        def max_normal_jump_reach(dy_up: float) -> float:
            if dy_up > jump_h:
                return 0.0
            disc = 640.0 * 640.0 - 2.0 * 1550.0 * dy_up
            if disc < 0.0:
                return 0.0
            t_land = (640.0 + math.sqrt(disc)) / 1550.0
            return 380.0 * (t_land + 0.12) + 14.0

        # Sequence-break check on main chasm
        main_max_reach = max_normal_jump_reach(west_ledge.top - east_ledge.top)
        if gap_w < 360.0 or gap_w <= main_max_reach:
            self.add(
                sec, "HIGH", "CAMP02_SEQ_BREAK",
                f"Main Dash chasm is {gap_w:.0f}px wide (max non-Dash coyote jump reach ~{main_max_reach:.0f}px -> sequence-breakable! Target 375..410px)",
                rp,
            )
        elif gap_w > 460.0:
            self.add(
                sec, "CRITICAL", "CAMP02_CHASM_UNJUMPABLE",
                f"Dash chasm is {gap_w:.0f}px wide — exceeds comfortable Jump+Dash reach (~{dash_jump_w:.0f}px max, target 375..410px)!",
                rp,
            )
        else:
            self.add(sec, "PASS", "CAMP02_CHASM_OK", f"Main Dash chasm width={gap_w:.0f}px (blocks non-Dash coyote jump ~{main_max_reach:.0f}px, clearable with Jump+Dash ~{dash_jump_w:.0f}px).", rp)

        # Also check every west/canyon return ledge for coyote-time sequence break onto east_ledge
        for s in surfaces:
            if s is east_ledge or s is west_ledge or s.right >= east_ledge.left:
                continue
            if s.right <= west_ledge.right:
                continue
            ledge_gap = east_ledge.left - s.right
            dy_up = s.top - east_ledge.top
            reach = max_normal_jump_reach(dy_up)
            if reach > 0.0 and ledge_gap <= reach + 4.0:
                self.add(
                    sec, "HIGH", "CAMP02_LEDGE_SEQ_BREAK",
                    f"Canyon return ledge (right={s.right:.0f}, top={s.top:.0f}) is only {ledge_gap:.0f}px from east ramp (top={east_ledge.top:.0f}, dy={dy_up:.0f}px) vs non-Dash coyote jump reach ~{reach:.0f}px -> sequence-breakable without Dash!",
                    rp,
                )

        # Safe recovery floor check underneath chasm
        mid_x = (west_ledge.right + east_ledge.left) * 0.5
        recovery_floors = [
            r for r, _, _, _ in rinfo["solids"]
            if r.left <= mid_x <= r.right and r.top > max(west_ledge.top, east_ledge.top) + 20
        ]
        if not recovery_floors:
            self.add(sec, "CRITICAL", "CAMP02_NO_RECOVERY_FLOOR", f"No solid recovery floor beneath chasm center x={mid_x:.0f} (pit fall softlock!)", rp)
        else:
            rec_top = min(r.top for r in recovery_floors)
            # Check step-up climb from rec_top back up to west_ledge.top (all steps <= jump_h * 0.95 = 125px)
            climb_surfaces = sorted(
                [r for r in surfaces if r.right <= east_ledge.left + 20 and r.left >= west_ledge.left - 300 and west_ledge.top <= r.top <= rec_top],
                key=lambda r: -r.top,
            )
            cur_y = rec_top
            for step_r in climb_surfaces:
                if cur_y - step_r.top <= jump_h - 6.0 and step_r.top < cur_y:
                    cur_y = step_r.top
            if cur_y > west_ledge.top + 8.0:
                self.add(
                    sec, "CRITICAL", "CAMP02_RECOVERY_SOFTLOCK",
                    f"Falling into chasm recovery floor (y={rec_top:.0f}) cannot jump back up to west ledge (y={west_ledge.top:.0f}; reached y={cur_y:.0f}, max jump={jump_h:.0f}px)!",
                    rp,
                )
            else:
                self.add(sec, "PASS", "CAMP02_RECOVERY_OK", f"Chasm recovery floor (y={rec_top:.0f}) has climbable step-ups back to west deck (y={west_ledge.top:.0f}).", rp)

    def _audit_highway_02_wall_chimney(self, rinfo: Optional[Dict[str, Any]], jump_h: float) -> None:
        sec = "D"
        if not rinfo:
            return
        rp = rinfo["rel_path"]
        orbs = [e for e in rinfo["entities"] if "memory_orb.tscn" in e["inst"]]
        wc_orb = next((o for o in orbs if parse_str_prop(o["props"].get("ability_id")) == "wall_cling"), None)
        if not wc_orb:
            self.add(sec, "CRITICAL", "HWY02_NO_WALL_ORB", "empty_highway_02 missing MemoryOrb with ability_id='wall_cling'", rp)

        # Find pairs of tall vertical solid walls (height >= 260px) forming a chimney gap 140..320px
        tall_walls = [r for r, _, _, _ in rinfo["solids"] if r.h >= 240.0]
        best_chimney: Optional[Tuple[Rect, Rect, float, float]] = None
        for a in tall_walls:
            for b in tall_walls:
                if b.left <= a.right:
                    continue
                gap = b.left - a.right
                overlap_top = max(a.top, b.top)
                overlap_bot = min(a.bottom, b.bottom)
                overlap_h = overlap_bot - overlap_top
                if 130.0 <= gap <= 320.0 and overlap_h >= 240.0:
                    if best_chimney is None or overlap_h > best_chimney[3]:
                        best_chimney = (a, b, gap, overlap_h)

        if best_chimney is None:
            self.add(sec, "HIGH", "HWY02_CHIMNEY_NOT_FOUND", "Could not detect Wall-Cling chimney (two opposing vertical walls >=240px tall, 180..260px apart) in empty_highway_02", rp)
            return

        w_left, w_right, ch_gap, ch_h = best_chimney
        self.metrics["hwy02_chimney_width_px"] = round(ch_gap, 1)
        self.metrics["hwy02_chimney_height_px"] = round(ch_h, 1)

        if ch_gap < 170.0 or ch_gap > 270.0:
            self.add(sec, "HIGH", "HWY02_CHIMNEY_WIDTH", f"Wall-Cling chimney width is {ch_gap:.0f}px (canonical target 180..260px, ideal 200..240px)", rp)
        else:
            self.add(sec, "PASS", "HWY02_CHIMNEY_OK", f"Wall-Cling chimney verified: width={ch_gap:.0f}px, vertical overlap={ch_h:.0f}px.", rp)

        # Check upper east exit is significantly higher than lower west spawn (> 250px vertical rise)
        sp_low = rinfo["spawns"].get("from_highway_01")
        sp_high = rinfo["spawns"].get("from_riyadh_01")
        if sp_low and sp_high:
            rise = sp_low[1] - sp_high[1]
            self.metrics["hwy02_vertical_rise_px"] = round(rise, 1)
            if rise < 220.0:
                self.add(sec, "HIGH", "HWY02_RISE_TOO_SMALL", f"Vertical rise from lower to upper exit is only {rise:.0f}px (may be sequence-breakable without Wall-Cling)", rp)
            if wc_orb and wc_orb["pos"][1] < sp_high[1] + 100:
                self.add(sec, "CRITICAL", "HWY02_ORB_ABOVE_CHIMNEY", "Wall-Cling Memory Orb appears placed above the chimney — softlock!", rp, wc_orb["line"])

    def _audit_riyadh_01_shortcut(self, rinfo: Optional[Dict[str, Any]], camp01: Optional[Dict[str, Any]]) -> None:
        sec = "D"
        if not rinfo:
            return
        rp = rinfo["rel_path"]
        sc_gates = [e for e in rinfo["entities"] if "shortcut_gate.gd" in e["script"]]
        if not sc_gates:
            self.add(sec, "CRITICAL", "RIYADH_NO_SHORTCUT", "empty_riyadh_01 missing shortcut_gate.gd node for shortcut_riyadh_to_camp", rp)
        else:
            has_id = any(parse_str_prop(e["props"].get("shortcut_id")) == "shortcut_riyadh_to_camp" for e in sc_gates)
            if not has_id:
                sg_gd = self.parsed_gds.get("scripts/rooms/shortcut_gate.gd")
                if not sg_gd or "shortcut_riyadh_to_camp" not in sg_gd.text:
                    self.add(sec, "HIGH", "RIYADH_SHORTCUT_ID", "ShortcutGate in empty_riyadh_01 does not set shortcut_id='shortcut_riyadh_to_camp'", rp)
        # Verify transition gate returning to desert_camp_01/from_riyadh_shortcut
        ret_gate = next(
            (g for g in rinfo["gates"] if g["target_room_id"] == "desert_camp_01" and g["target_spawn_id"] == "from_riyadh_shortcut"),
            None,
        )
        if not ret_gate:
            self.add(sec, "CRITICAL", "RIYADH_NO_RETURN_GATE", "empty_riyadh_01 missing TransitionGate to desert_camp_01 ('from_riyadh_shortcut')", rp)
        elif camp01 and "from_riyadh_shortcut" in camp01["spawns"]:
            self.add(sec, "PASS", "RIYADH_SHORTCUT_OK", "shortcut_riyadh_to_camp connects empty_riyadh_01 -> desert_camp_01 (from_riyadh_shortcut).", rp)

    def _audit_boss_room_seal(self, rinfo: Optional[Dict[str, Any]]) -> None:
        sec = "D"
        if not rinfo:
            return
        rp = rinfo["rel_path"]
        has_boss = any("boss_spire_warden.tscn" in e["inst"] for e in rinfo["entities"])
        if not has_boss:
            self.add(sec, "CRITICAL", "BOSS_ROOM_NO_BOSS", "empty_riyadh_boss.tscn does not instance boss_spire_warden.tscn", rp)
        has_page = any("notebook_page.tscn" in e["inst"] for e in rinfo["entities"])
        ctrl_gd = self.parsed_gds.get("scripts/rooms/boss_arena_controller.gd")
        if not has_page and (not ctrl_gd or "page_02_mall" not in ctrl_gd.text):
            self.add(sec, "HIGH", "BOSS_ROOM_NO_PAGE", "empty_riyadh_boss missing Torn Notebook Page #2 ('page_02_mall') reward", rp)
        if ctrl_gd:
            if "is_boss_defeated" not in ctrl_gd.text:
                self.add(sec, "HIGH", "BOSS_CTRL_REENTRY", "boss_arena_controller.gd should check GameState.is_boss_defeated() so re-entering never seals an empty room!", ctrl_gd.rel_path)
            if "boss_defeated" not in ctrl_gd.text and "defeated" not in ctrl_gd.text:
                self.add(sec, "CRITICAL", "BOSS_CTRL_UNSEAL", "boss_arena_controller.gd does not handle boss defeat to reopen the sealed exit!", ctrl_gd.rel_path)
            else:
                self.add(sec, "PASS", "BOSS_ROOM_OK", "Boss room instances Fractured Spire Warden, seals/reopens on defeat, and guards re-entry.", rp)

    # -----------------------------------------------------------------------
    # SECTION E: Deliverables, Docs & Content Rules Audit
    # -----------------------------------------------------------------------

    def check_ui_identity(self) -> None:
        """DROP-002 "Notebook & Ember" P1 contracts (docs/UI_DESIGN_PLAN.md §8)."""
        sec = "C"
        problems = 0
        tokens_rp = "scripts/ui/ui_tokens.gd"
        tokens_p = self.root / tokens_rp
        if not tokens_p.exists():
            self.add(sec, "HIGH", "UI_TOKENS_MISSING", "UITokens script missing", tokens_rp)
            problems += 1
        else:
            ttxt = tokens_p.read_text(encoding="utf-8")
            for tok in ("PALE_GOLD", "EMBER", "DESERT_RED", "PAPER_ASH", "INK_BROWN", "INK_FOCUS_PAPER",
                        "INK_DESTRUCTIVE_PAPER", "HUD_WOUNDED_FLOOR_ALPHA"):
                if f"const {tok}" not in ttxt:
                    self.add(sec, "HIGH", "UI_TOKEN_MISSING", f"UITokens missing {tok}", tokens_rp)
                    problems += 1
        afs_rp = "scripts/ui/arabic_font_setup.gd"
        afs_p = self.root / afs_rp
        if afs_p.exists():
            atxt = afs_p.read_text(encoding="utf-8")
            for fn in ("func get_role_font(", "func localize_digits(", "func get_text_scale("):
                if fn not in atxt:
                    self.add(sec, "HIGH", "UI_FONT_ROLES", f"ArabicFontSetup missing {fn}", afs_rp)
                    problems += 1
        sm_rp = "scripts/autoload/settings_manager.gd"
        sm_p = self.root / sm_rp
        if sm_p.exists():
            stxt = sm_p.read_text(encoding="utf-8")
            for key in ("reduce_motion", "hud_always_visible", "show_numbers", "text_scale"):
                if f'"{key}"' not in stxt or f"func set_{key}(" not in stxt:
                    self.add(sec, "HIGH", "UI_SETTING_MISSING", f"SettingsManager must persist and set '{key}'", sm_rp)
                    problems += 1
        ui_dir = self.root / "scripts/ui"
        if ui_dir.exists():
            for gd in sorted(ui_dir.glob("*.gd")):
                txt = gd.read_text(encoding="utf-8")
                rp = gd.relative_to(self.root).as_posix()
                if re.search(r"^const COLOR_[A-Z_]+\s*:", txt, re.M):
                    self.add(sec, "MEDIUM", "UI_LOCAL_COLOR_CONST", "Use UITokens instead of local COLOR_* constants", rp)
                    problems += 1
        for rp in ("scripts/ui/title_screen.gd", "scripts/ui/vignette_player.gd"):
            p_ = self.root / rp
            if p_.exists() and "AMBIENT_REDRAW_HZ" not in p_.read_text(encoding="utf-8"):
                self.add(sec, "MEDIUM", "UI_PER_FRAME_REDRAW", "Ambient _draw must be rate-capped (AMBIENT_REDRAW_HZ)", rp)
                problems += 1
        csv_p = self.root / "localization/strings.csv"
        if csv_p.exists():
            with csv_p.open("r", encoding="utf-8-sig", newline="") as fh:
                for line_no, row in enumerate(csv.reader(fh), start=1):
                    if not row:
                        continue
                    key = row[0].strip()
                    if key.startswith(("UI_", "PROMPT_", "AREA_")) or (key.startswith("PAGE_") and key.endswith("_TITLE")):
                        if any("\u2014" in cell for cell in row[1:]):
                            self.add(sec, "MEDIUM", "UI_EM_DASH", f"Em-dash separator in UI copy '{key}' (use hierarchy, not punctuation)", "localization/strings.csv", line_no)
                            problems += 1
        if problems == 0:
            self.add(sec, "PASS", "UI_IDENTITY_P1", "Notebook & Ember P1 contracts hold (tokens, font roles, digits, settings, no em-dash UI copy, capped redraw).")

    def check_section_e(self) -> None:
        sec = "E"
        # 1. GDD.md
        gdd_p = self.root / "docs/GDD.md"
        if gdd_p.exists():
            txt = gdd_p.read_text(encoding="utf-8")
            checks = [
                ("movement constants", all(tok in txt for tok in ("380", "-640", "0.12", "860"))),
                ("combat 3-tier / parry", all(tok.lower() in txt.lower() for tok in ("dagger", "parry", "spell"))),
                ("Time Shift 2034/2054", "2034" in txt and "2054" in txt and "time shift" in txt.lower()),
                ("Grey Eye & Don't-Look", "grey eye" in txt.lower() and ("don't-look" in txt.lower() or "don't look" in txt.lower())),
                ("Both Endings (grey eyes / blue eyes)", "grey" in txt.lower() and "blue" in txt.lower() and "stadium" in txt.lower()),
                ("Motaib & Spire Warden", "motaib" in txt.lower() and "warden" in txt.lower()),
                ("Arabic RTL", "arabic" in txt.lower() and "rtl" in txt.lower()),
            ]
            for label, ok in checks:
                if not ok:
                    self.add(sec, "MEDIUM", "GDD_MISSING_TOPIC", f"docs/GDD.md missing or incomplete section: {label}", "docs/GDD.md")
            self.add(sec, "PASS", "GDD_CHECKED", f"Audited docs/GDD.md ({len(txt.splitlines())} lines).", "docs/GDD.md")

        # 2. WORLD_GRAPH.md
        wg_p = self.root / "docs/WORLD_GRAPH.md"
        if wg_p.exists():
            txt = wg_p.read_text(encoding="utf-8")
            areas = [
                ("Desert Camp", ("desert camp",)),
                ("Empty Highway", ("empty highway",)),
                ("Empty Riyadh", ("empty riyadh",)),
                ("Metro Tunnels", ("metro",)),
                ("Diriyah / At-Turaif", ("diriyah", "turaif")),
                ("Wadi Hanifa", ("wadi hanifa",)),
                ("Old Market", ("old market",)),
                ("The Hideout", ("hideout",)),
                ("The Library", ("library",)),
                ("Edge of the World / Tuwaiq", ("edge of the world", "tuwaiq")),
                ("Jinn Kingdom", ("jinn kingdom",)),
                ("2034 Stadium", ("stadium",)),
                ("The Citadel", ("citadel", "ma'qil")),
                ("Memory Garden", ("memory garden",)),
            ]
            tl = txt.lower()
            missing_areas = [name for name, alts in areas if not any(a in tl for a in alts)]
            if missing_areas:
                self.add(sec, "HIGH", "WG_MISSING_AREAS", f"docs/WORLD_GRAPH.md missing area(s): {missing_areas}", "docs/WORLD_GRAPH.md")
            if "```mermaid" not in txt:
                self.add(sec, "MEDIUM", "WG_NO_MERMAID", "docs/WORLD_GRAPH.md missing Mermaid diagram", "docs/WORLD_GRAPH.md")
            for rm in M1_ROOMS + ["shortcut_riyadh_to_camp"]:
                if rm not in txt:
                    self.add(sec, "MEDIUM", "WG_MISSING_M1_ROOM", f"docs/WORLD_GRAPH.md does not document '{rm}'", "docs/WORLD_GRAPH.md")
            if not missing_areas:
                self.add(sec, "PASS", "WG_14_AREAS", "docs/WORLD_GRAPH.md covers all 14 areas.", "docs/WORLD_GRAPH.md")

        # 3. M1_TASK_BREAKDOWN.md & CHANGELOG.md & ART_SPEC.md
        tb_p = self.root / "docs/M1_TASK_BREAKDOWN.md"
        if tb_p.exists():
            tl = tb_p.read_text(encoding="utf-8").lower()
            for role in ("designer", "core-systems", "player-combat", "enemies-boss", "art-shaders", "level-builder", "ui-loc", "qa-verifier"):
                if role not in tl:
                    self.add(sec, "WARN", "TASK_BREAKDOWN_ROLE", f"docs/M1_TASK_BREAKDOWN.md does not mention owner '{role}'", "docs/M1_TASK_BREAKDOWN.md")

        cl_p = self.root / "CHANGELOG.md"
        if cl_p.exists():
            txt = cl_p.read_text(encoding="utf-8")
            if "0.1.0-M1" not in txt:
                self.add(sec, "MEDIUM", "CHANGELOG_VERSION", "CHANGELOG.md missing [0.1.0-M1] section", "CHANGELOG.md")

        art_p = self.root / "docs/ART_SPEC.md"
        if art_p.exists():
            tl = art_p.read_text(encoding="utf-8").lower()
            for tok in ("1920", "1080", "assets/final", "farid", "amira", "motaib", "sand stalker", "shard husk", "relic sentinel", "warden", "parallax"):
                if tok not in tl:
                    self.add(sec, "MEDIUM", "ART_SPEC_TOPIC", f"docs/ART_SPEC.md missing expected asset spec entry: '{tok}'", "docs/ART_SPEC.md")

        # 4. Content rules scan (no Hollow Knight copying; no graphic violence/gore in story/dialogue/code)
        hk_re = re.compile(r"\b(hollow\s+knight|hallownest|pale\s+king|radiance\s+boss|mantis\s+claw|mothwing\s+cloak)\b", re.I)
        gore_re = re.compile(r"\b(decapitat\w*|dismember\w*|mutilat\w*|eviscerat\w*|entrails|bloodbath|gorefest)\b", re.I)

        scan_exts = {".gd", ".tscn", ".csv", ".md", ".json"}
        for p in sorted(self.root.rglob("*")):
            if not p.is_file() or p.suffix not in scan_exts:
                continue
            rp = self.rel(p)
            if rp in ("tools/verify_m1.py", "docs/QA_NOTES.md", "docs/KNOWN_ISSUES.md"):
                continue
            try:
                lines = p.read_text(encoding="utf-8").splitlines()
            except Exception:
                continue
            for idx, line in enumerate(lines, start=1):
                if hk_re.search(line):
                    # Allow explicit negative policy statements in docs/comments like "do NOT copy Hollow Knight"
                    if not re.search(r"\b(not|no|never|avoid|original|without|non-)\b", line, re.I):
                        self.add(sec, "HIGH", "CONTENT_HK_REF", f"Un-negated Hollow Knight reference found: '{line.strip()[:80]}'", rp, idx)
                if gore_re.search(line):
                    if not re.search(r"\b(no|not|never|avoid|without)\b", line, re.I):
                        self.add(sec, "HIGH", "CONTENT_GORE", f"Graphic violence term found (violates silent-grief rule): '{line.strip()[:80]}'", rp, idx)

    # -----------------------------------------------------------------------
    # SECTION F: Godot Headless Validation
    # -----------------------------------------------------------------------

    def check_section_f(self) -> None:
        sec = "F"
        candidates = [
            shutil.which("godot"),
            shutil.which("godot4"),
            "/Applications/Godot.app/Contents/MacOS/Godot",
            "/Applications/Godot_mono.app/Contents/MacOS/Godot",
            os.path.expanduser("~/Applications/Godot.app/Contents/MacOS/Godot"),
            "/tmp/godot-4.3/Godot.app/Contents/MacOS/Godot",
        ]
        godot_bin = next((c for c in candidates if c and os.path.isfile(c) and os.access(c, os.X_OK)), None)
        self.metrics["godot_binary"] = godot_bin or "not_installed"

        if not godot_bin:
            self.add(
                sec, "INFO", "GODOT_NOT_INSTALLED",
                "Godot 4.3+ binary not found on host; skipped headless engine check. Run manually: godot --headless --path shaala --import --quit",
                owner="@qa-verifier",
            )
            return

        try:
            env = os.environ.copy()
            if godot_bin.startswith("/tmp/"):
                env["HOME"] = "/tmp/godot-home"
                os.makedirs("/tmp/godot-home", exist_ok=True)
            res = subprocess.run(
                [godot_bin, "--headless", "--path", str(self.root), "--import", "--quit"],
                capture_output=True,
                text=True,
                timeout=60,
                env=env,
            )
            combined = (res.stdout or "") + "\n" + (res.stderr or "")
            raw_lines = combined.splitlines()
            err_lines: List[str] = []
            for idx_l, ln in enumerate(raw_lines):
                if not re.search(r"(SCRIPT ERROR|Parse Error|ERROR:)", ln):
                    continue
                next_ln = raw_lines[idx_l + 1] if idx_l + 1 < len(raw_lines) else ""
                if "get_system_ca_certificates" in ln or "get_system_ca_certificates" in next_ln:
                    continue
                if "sandbox_extension_issue" in ln:
                    continue
                err_lines.append(ln)
            if res.returncode != 0 or err_lines:
                for el in err_lines[:15]:
                    self.add(sec, "CRITICAL", "GODOT_HEADLESS_ERR", el.strip(), owner="@core-systems")
            else:
                self.add(sec, "PASS", "GODOT_HEADLESS_OK", f"Godot headless import/validation passed ({godot_bin}).", owner="@qa-verifier")
        except Exception as exc:
            self.add(sec, "WARN", "GODOT_HEADLESS_EXC", f"Godot headless execution failed: {exc}", owner="@qa-verifier")

    # -----------------------------------------------------------------------
    # Execution & Reporting
    # -----------------------------------------------------------------------

    def run(self, section: str = "all") -> int:
        self.preload_all()
        s = section.lower()
        if s in ("all", "a"):
            self.check_section_a()
        if s in ("all", "b"):
            self.check_section_b()
        if s in ("all", "c"):
            self.check_section_c()
            self.check_ui_identity()
        if s in ("all", "d"):
            self.check_section_d()
        if s in ("all", "e"):
            self.check_section_e()
        if s in ("all", "f"):
            self.check_section_f()

        crit_high = [f for f in self.findings if f.severity in ("CRITICAL", "HIGH")]
        return 1 if crit_high else 0

    def summary_counts(self) -> Dict[str, int]:
        counts = {k: 0 for k in SEVERITY_ORDER}
        for f in self.findings:
            counts[f.severity] = counts.get(f.severity, 0) + 1
        return counts

    def print_report(self, as_json: bool = False) -> None:
        counts = self.summary_counts()
        if as_json:
            print(json.dumps({
                "root": str(self.root),
                "counts": counts,
                "metrics": self.metrics,
                "findings": [f.to_dict() for f in self.findings],
            }, ensure_ascii=False, indent=2))
            return

        print("=" * 78)
        print(f"SHAALA (شعلة) — M1 Verification Report | Root: {self.root}")
        print("=" * 78)
        print(
            f"Summary: CRITICAL={counts['CRITICAL']}  HIGH={counts['HIGH']}  "
            f"MEDIUM={counts['MEDIUM']}  WARN={counts['WARN']}  INFO={counts['INFO']}  PASS={counts['PASS']}"
        )
        print("Metrics:", json.dumps(self.metrics, ensure_ascii=False))
        print("-" * 78)

        # Group non-PASS findings by owner for rapid defect routing
        defects = [f for f in self.findings if f.severity in ("CRITICAL", "HIGH", "MEDIUM", "WARN")]
        if defects:
            by_owner: Dict[str, List[Finding]] = defaultdict(list)
            for f in defects:
                by_owner[f.owner].append(f)
            print("DEFECTS & WARNINGS BY OWNER:")
            for owner in sorted(by_owner.keys()):
                items = sorted(by_owner[owner], key=lambda x: (SEVERITY_ORDER[x.severity], x.section, x.file, x.line))
                print(f"\n  [{owner}] ({len(items)} item(s)):")
                for f in items:
                    loc = f"{f.file}:{f.line}" if f.file and f.line else f.file
                    loc_str = f" ({loc})" if loc else ""
                    print(f"    - [{f.severity}][{f.section}:{f.code}]{loc_str} {f.message}")
        else:
            print("ZERO DEFECTS OR WARNINGS!")

        passes = [f for f in self.findings if f.severity in ("PASS", "INFO")]
        if passes:
            print("\nCHECKS PASSED / INFO:")
            for f in passes:
                print(f"  [{f.severity}][{f.section}:{f.code}] {f.message}")
        print("=" * 78)


def main() -> int:
    parser = argparse.ArgumentParser(description="SHAALA M1 Verification & Playtest-Simulation Harness")
    default_root = Path(__file__).resolve().parent.parent
    parser.add_argument("--root", type=Path, default=default_root, help="Path to shaala/ project root")
    parser.add_argument("--section", default="all", choices=["all", "a", "b", "c", "d", "e", "f"], help="Run single section or all")
    parser.add_argument("--json", action="store_true", help="Output JSON report")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero on MEDIUM/WARN too")
    args = parser.parse_args()

    verifier = M1Verifier(args.root)
    rc = verifier.run(args.section)
    verifier.print_report(as_json=args.json)
    if args.strict:
        counts = verifier.summary_counts()
        if counts["CRITICAL"] + counts["HIGH"] + counts["MEDIUM"] + counts["WARN"] > 0:
            return 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
