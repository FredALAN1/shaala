class_name NpcInteractable
extends InteractableBase
## Painterly silhouette NPC interactable supporting multiple character silhouettes:
## - "boy": The small desert boy with a wooden stick who wakes Farid ("أبي").
## - "motaib": Armored warrior with two greatswords (Empty Highway cameo).

@export var npc_id: String = "npc_boy"
@export var speaker_key: String = "SPEAKER_BOY"
@export var line_keys: Array[String] = ["DLG_BOY_01", "DLG_BOY_02", "DLG_BOY_03"]
@export_enum("boy", "motaib") var silhouette_style: String = "boy"
@export var face_player: bool = true

var _time: float = 0.0
var _facing: float = -1.0

@onready var _visual_root: Node2D = get_node_or_null("VisualRoot") as Node2D
@onready var _boy_visual: Node2D = get_node_or_null("VisualRoot/BoyVisual") as Node2D
@onready var _motaib_visual: Node2D = get_node_or_null("VisualRoot/MotaibVisual") as Node2D


func _init() -> void:
	prompt_key = "PROMPT_TALK"
	interaction_cooldown = 0.35


func _ready() -> void:
	super._ready()
	_apply_silhouette_style()


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta
	_update_facing()
	_animate_idle()


func _apply_silhouette_style() -> void:
	var is_motaib: bool = silhouette_style == "motaib"
	if _boy_visual != null:
		_boy_visual.visible = not is_motaib
	if _motaib_visual != null:
		_motaib_visual.visible = is_motaib


func _update_facing() -> void:
	if not face_player or _visual_root == null:
		return
	var player: Node = get_player_in_range()
	if player is Node2D:
		var dx: float = (player as Node2D).global_position.x - global_position.x
		if absf(dx) > 8.0:
			_facing = 1.0 if dx > 0.0 else -1.0
	_visual_root.scale.x = _facing


func _animate_idle() -> void:
	if _visual_root == null:
		return
	var breath_speed: float = 1.65 if silhouette_style == "motaib" else 2.25
	var breath_amp: float = 0.018 if silhouette_style == "motaib" else 0.024
	var breath: float = sin(_time * breath_speed) * breath_amp
	_visual_root.scale.y = 1.0 + breath

	if silhouette_style == "boy" and _boy_visual != null:
		var stick: Node2D = _boy_visual.get_node_or_null("WoodenStick") as Node2D
		if stick != null:
			stick.rotation = deg_to_rad(sin(_time * 1.45) * 3.2)
	elif silhouette_style == "motaib" and _motaib_visual != null:
		var cloak: Node2D = _motaib_visual.get_node_or_null("CloakHem") as Node2D
		if cloak != null:
			cloak.rotation = deg_to_rad(sin(_time * 2.1) * 2.4)


func _on_interact(_player: Node) -> void:
	var lines: Array[Dictionary] = []
	for line_key: String in line_keys:
		if line_key != "":
			lines.append({
				"speaker_key": speaker_key,
				"text_key": line_key,
			})
	if lines.is_empty():
		return
	AudioManager.play_sfx("ui_talk")
	EventBus.dialogue_requested.emit(lines)
