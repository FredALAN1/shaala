class_name CamelAmira
extends InteractableBase
## Amira — Farid's resting Arabian camel in the Desert Camp.
## High-contrast ochre/indigo silhouette with traditional Najdi woven saddle blanket,
## calm breathing animation, and subtle periodic ear twitch.

@export var npc_id: String = "camel_amira"
@export var speaker_key: String = "SPEAKER_AMIRA"
@export var line_keys: Array[String] = ["DLG_AMIRA_01"]

var _time: float = 0.0
var _ear_twitch_timer: float = 2.8
var _ear_twitch_phase: float = 0.0
var _nod_phase: float = 0.0

@onready var _body_root: Node2D = get_node_or_null("CamelVisual/BodyGroup") as Node2D
@onready var _head_group: Node2D = get_node_or_null("CamelVisual/HeadGroup") as Node2D
@onready var _ear_poly: Polygon2D = get_node_or_null("CamelVisual/HeadGroup/Ear") as Polygon2D


func _init() -> void:
	prompt_key = "PROMPT_TALK"
	interaction_cooldown = 0.4


func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta

	# Calm resting chest/hump breathing cycle.
	if _body_root != null:
		var breath: float = sin(_time * 1.35) * 0.022
		_body_root.scale = Vector2(1.0 + breath * 0.5, 1.0 + breath)

	# Gentle ear twitch every few seconds.
	_ear_twitch_timer -= delta
	if _ear_twitch_timer <= 0.0:
		_ear_twitch_phase = 1.0
		_ear_twitch_timer = 3.4 + fmod(_time * 1.7, 2.4)

	if _ear_twitch_phase > 0.0:
		_ear_twitch_phase = maxf(0.0, _ear_twitch_phase - delta * 3.6)

	if _ear_poly != null:
		var twitch_angle: float = sin(_ear_twitch_phase * PI * 2.0) * 16.0 * _ear_twitch_phase
		_ear_poly.rotation = deg_to_rad(twitch_angle)

	# Subtle resting head sway + warm nod on interaction.
	if _nod_phase > 0.0:
		_nod_phase = maxf(0.0, _nod_phase - delta * 2.2)

	if _head_group != null:
		var idle_sway: float = sin(_time * 0.9) * 2.2
		var nod_angle: float = sin(_nod_phase * PI) * 8.5
		_head_group.rotation = deg_to_rad(idle_sway + nod_angle)


func _on_interact(_player: Node) -> void:
	_nod_phase = 1.0
	_ear_twitch_phase = 1.0

	var lines: Array[Dictionary] = []
	for line_key: String in line_keys:
		if line_key != "":
			lines.append({
				"speaker_key": speaker_key,
				"text_key": line_key,
			})
	if lines.is_empty():
		return
	AudioManager.play_sfx("camel_grunt")
	EventBus.dialogue_requested.emit(lines)
