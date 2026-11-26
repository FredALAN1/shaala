class_name RoomBase
extends Node2D
## Base class for all rooms in SHAALA (شعلة).
## Provides spawn lookup, camera bounds, and 2034/2054 Time Shift era toggling.

const FALLBACK_SPAWN_POSITION: Vector2 = Vector2(200.0, 700.0)

@export var room_id: String = ""
@export var area_id: String = ""
@export var room_title_key: String = ""
@export var camera_bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
@export var supports_time_shift: bool = false


func _ready() -> void:
	if not EventBus.era_changed.is_connected(apply_era):
		EventBus.era_changed.connect(apply_era)
	apply_era(GameState.current_era)


func get_spawn_position(spawn_id: String) -> Vector2:
	var spawns_container: Node = get_node_or_null("Spawns")
	if spawns_container != null:
		if not spawn_id.is_empty():
			var named_marker: Node = spawns_container.get_node_or_null(spawn_id)
			if named_marker is Node2D:
				return (named_marker as Node2D).global_position
		for child: Node in spawns_container.get_children():
			if child is Marker2D:
				return (child as Marker2D).global_position
		for child: Node in spawns_container.get_children():
			if child is Node2D:
				return (child as Node2D).global_position
	return FALLBACK_SPAWN_POSITION


func get_camera_bounds() -> Rect2:
	return camera_bounds


func apply_era(era: String) -> void:
	var era_2034: Node = get_node_or_null("Era2034")
	var era_2054: Node = get_node_or_null("Era2054")
	if era_2034 == null and era_2054 == null:
		return

	# Only switch away from 2054 if an alternate 2034 layer actually exists.
	var show_2034: bool = (era == "2034") and (era_2034 != null)
	if era_2034 != null:
		_set_era_branch_active(era_2034, show_2034)
	if era_2054 != null:
		_set_era_branch_active(era_2054, not show_2034)


func _set_era_branch_active(root: Node, active: bool) -> void:
	if root is CanvasItem:
		(root as CanvasItem).visible = active
	root.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_collisions_enabled_recursive(root, active)


func _set_collisions_enabled_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D:
		(node as CollisionShape2D).set_deferred("disabled", not enabled)
	elif node is CollisionPolygon2D:
		(node as CollisionPolygon2D).set_deferred("disabled", not enabled)
	for child: Node in node.get_children():
		_set_collisions_enabled_recursive(child, enabled)
