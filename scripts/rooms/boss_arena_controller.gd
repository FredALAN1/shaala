class_name BossArenaController
extends "res://scripts/systems/room_base.gd"
## Controller for the Shattered Mall Courtyard boss arena (empty_riyadh_boss).
## Triggers The Fractured Spire Warden encounter, seals the west entrance during battle,
## and upon victory reopens west exit, reveals Torn Notebook Page #2, and opens the
## East alcove displaying the sealed Metro Tunnels Milestone 2 gate.

const PAINTERLY_CANVAS_SHADER_PATH: String = "res://assets/placeholder/shaders/painterly_canvas.gdshader"

@export var boss_id: String = "boss_spire_warden"
@export var boss_node_path: NodePath = NodePath("Enemies/BossSpireWarden")
@export var trigger_zone_path: NodePath = NodePath("BossTriggerZone")
@export var west_seal_door_path: NodePath = NodePath("Geometry/WestSealDoor")
@export var east_seal_door_path: NodePath = NodePath("Geometry/EastSealDoor")
@export var reward_page_path: NodePath = NodePath("Interactables/RewardNotebookPage")
@export var metro_gate_sign_path: NodePath = NodePath("Interactables/MetroSealedSign")
@export var music_mood_explore: String = "riyadh"
@export var music_mood_boss: String = "boss"
@export var atmosphere_tint: Color = Color("#4F6D7A")
@export var shadow_tint: Color = Color("#0D1021")

var _encounter_started: bool = false
var _boss_defeated_handled: bool = false
var _west_closed_y: float = 0.0
var _east_closed_y: float = 0.0

@onready var _boss_node: Node = get_node_or_null(boss_node_path)
@onready var _trigger_zone: Area2D = get_node_or_null(trigger_zone_path) as Area2D
@onready var _west_seal_door: StaticBody2D = get_node_or_null(west_seal_door_path) as StaticBody2D
@onready var _east_seal_door: StaticBody2D = get_node_or_null(east_seal_door_path) as StaticBody2D
@onready var _reward_page: Area2D = get_node_or_null(reward_page_path) as Area2D
@onready var _metro_sign: Area2D = get_node_or_null(metro_gate_sign_path) as Area2D


func _ready() -> void:
	super._ready()
	_apply_arena_shaders()
	apply_era(GameState.current_era)

	if _west_seal_door != null:
		_west_closed_y = _west_seal_door.position.y
	if _east_seal_door != null:
		_east_closed_y = _east_seal_door.position.y

	if not EventBus.era_changed.is_connected(_on_era_changed):
		EventBus.era_changed.connect(_on_era_changed)
	if not EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.connect(_on_boss_defeated)
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)

	if _boss_node != null and _boss_node.has_signal("defeated"):
		if not _boss_node.is_connected("defeated", _on_boss_node_defeated):
			_boss_node.connect("defeated", _on_boss_node_defeated)

	if GameState.is_boss_defeated(boss_id):
		_boss_defeated_handled = true
		_set_seal_door(_west_seal_door, _west_closed_y, true, true)
		_set_seal_door(_east_seal_door, _east_closed_y, true, true)
		_set_reward_page_visible(true, true)
		_set_metro_sign_active(true)
		if _trigger_zone != null:
			_trigger_zone.set_deferred("monitoring", false)
		AudioManager.set_music_mood(music_mood_explore)
	else:
		# West entry starts open so Farid enters freely; East Metro alcove stays sealed until victory.
		_set_seal_door(_west_seal_door, _west_closed_y, true, true)
		_set_seal_door(_east_seal_door, _east_closed_y, false, true)
		_set_reward_page_visible(false, true)
		_set_metro_sign_active(false)
		if _trigger_zone != null and not _trigger_zone.body_entered.is_connected(_on_trigger_entered):
			_trigger_zone.body_entered.connect(_on_trigger_entered)
		AudioManager.set_music_mood(music_mood_explore)


func _exit_tree() -> void:
	if EventBus.era_changed.is_connected(_on_era_changed):
		EventBus.era_changed.disconnect(_on_era_changed)
	if EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.disconnect(_on_boss_defeated)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)


func _on_era_changed(era: String) -> void:
	apply_era(era)


func _on_trigger_entered(body: Node) -> void:
	if _encounter_started or _boss_defeated_handled:
		return
	if body == null or not body.is_in_group("player"):
		return
	if GameState.is_boss_defeated(boss_id):
		return

	_encounter_started = true
	if _trigger_zone != null:
		_trigger_zone.set_deferred("monitoring", false)

	_set_seal_door(_west_seal_door, _west_closed_y, false, false)
	EventBus.camera_shake_requested.emit(6.5, 0.28)
	AudioManager.set_music_mood(music_mood_boss)

	if is_instance_valid(_boss_node) and _boss_node.has_method("start_encounter"):
		_boss_node.call("start_encounter")


func _on_boss_node_defeated() -> void:
	_handle_victory()


func _on_boss_defeated(defeated_id: String) -> void:
	if defeated_id != boss_id:
		return
	_handle_victory()


func _handle_victory() -> void:
	if _boss_defeated_handled:
		return
	_boss_defeated_handled = true

	_set_seal_door(_west_seal_door, _west_closed_y, true, false)
	_set_seal_door(_east_seal_door, _east_closed_y, true, false)
	_set_reward_page_visible(true, false)
	_set_metro_sign_active(true)
	EventBus.camera_shake_requested.emit(4.5, 0.3)
	AudioManager.set_music_mood(music_mood_explore)
	SaveManager.save_game()


func _on_player_died() -> void:
	if not _boss_defeated_handled:
		AudioManager.set_music_mood(music_mood_explore)


func _set_seal_door(door: StaticBody2D, closed_y: float, opened: bool, instant: bool) -> void:
	if door == null:
		return
	var col: CollisionShape2D = door.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", opened)

	var target_y: float = closed_y - 210.0 if opened else closed_y
	var target_alpha: float = 0.0 if opened else 1.0
	if instant:
		door.position.y = target_y
		door.modulate.a = target_alpha
	else:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(door, "position:y", target_y, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(door, "modulate:a", target_alpha, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_reward_page_visible(shown: bool, instant: bool) -> void:
	if not is_instance_valid(_reward_page):
		return
	if shown:
		_reward_page.process_mode = Node.PROCESS_MODE_INHERIT
		_reward_page.visible = true
		_reward_page.set_deferred("monitoring", true)
		_reward_page.set_deferred("monitorable", true)
		if instant:
			_reward_page.modulate.a = 1.0
		else:
			_reward_page.modulate.a = 0.0
			var tween: Tween = create_tween()
			tween.tween_property(_reward_page, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_reward_page.visible = false
		_reward_page.set_deferred("monitoring", false)
		_reward_page.set_deferred("monitorable", false)
		_reward_page.process_mode = Node.PROCESS_MODE_DISABLED


func _set_metro_sign_active(active: bool) -> void:
	if not is_instance_valid(_metro_sign):
		return
	_metro_sign.set_deferred("monitoring", active)
	_metro_sign.set_deferred("monitorable", active)


func _apply_arena_shaders() -> void:
	if not ResourceLoader.exists(PAINTERLY_CANVAS_SHADER_PATH):
		return
	var parallax: ParallaxBackground = get_node_or_null("ParallaxBackground") as ParallaxBackground
	if parallax == null:
		return
	var canvas_shader: Shader = load(PAINTERLY_CANVAS_SHADER_PATH) as Shader
	if canvas_shader == null:
		return
	var canvas_mat: ShaderMaterial = ShaderMaterial.new()
	canvas_mat.shader = canvas_shader
	canvas_mat.set_shader_parameter("atmosphere_tint", atmosphere_tint)
	canvas_mat.set_shader_parameter("shadow_tint", shadow_tint)
	canvas_mat.set_shader_parameter("tint_strength", 0.22)
	for layer_child: Node in parallax.get_children():
		if layer_child is ParallaxLayer:
			for visual_child: Node in layer_child.get_children():
				if visual_child is CanvasItem and (visual_child as CanvasItem).material == null:
					(visual_child as CanvasItem).material = canvas_mat
