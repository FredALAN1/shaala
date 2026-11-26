class_name Hitbox
extends Area2D
## Reusable damage dealer Area2D for melee swings, projectiles, and enemy attacks.
##
## Physics Layer Contract (1-indexed layers -> bitmask values):
##   1 = world (1), 2 = one_way (2), 3 = player (4), 4 = enemy (8),
##   5 = player_hitbox (16), 6 = enemy_hitbox (32), 7 = interactable (64), 8 = hazard (128)
##
## Hitbox configuration:
##   - monitoring = true when active, monitorable = false
##   - Player Hitbox (Flame Dagger / Flame Spell):
##       collision_layer = 16 (layer 5: player_hitbox)
##       collision_mask  = 8  (layer 4: enemy Hurtboxes)
##   - Enemy / Boss Hitbox:
##       collision_layer = 32 (layer 6: enemy_hitbox)
##       collision_mask  = 4  (layer 3: player Hurtbox)

signal hit_landed(hurtbox: Hurtbox, info: DamageInfo)

@export var damage: int = 10
@export var knockback: Vector2 = Vector2(220.0, -140.0)
@export var parryable: bool = true
@export var damage_type: String = "melee"
@export var active: bool = false:
	set(value):
		active = value
		if is_inside_tree():
			set_deferred("monitoring", active)
@export var one_shot_per_target: bool = true

var source_node: Node = null
var _already_hit: Array[Area2D] = []


func _ready() -> void:
	monitorable = false
	monitoring = active
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	if active and monitoring:
		_scan_overlapping_hurtboxes()


func set_active(value: bool) -> void:
	active = value


func activate(should_reset_hits: bool = true) -> void:
	if should_reset_hits:
		reset_hits()
	set_active(true)


func deactivate() -> void:
	set_active(false)


func reset_hits() -> void:
	_already_hit.clear()


func build_damage_info() -> DamageInfo:
	var resolved_source: Node = _resolve_source_node()
	var origin: Vector2 = global_position
	if resolved_source is Node2D:
		origin = (resolved_source as Node2D).global_position
	return DamageInfo.create(
		damage,
		origin,
		knockback,
		parryable,
		damage_type,
		resolved_source
	)


func _resolve_source_node() -> Node:
	if source_node != null:
		return source_node
	if owner != null:
		return owner
	return get_parent()


func _on_area_entered(area: Area2D) -> void:
	_try_hit_area(area)


func _scan_overlapping_hurtboxes() -> void:
	for area: Area2D in get_overlapping_areas():
		_try_hit_area(area)


func _try_hit_area(area: Area2D) -> void:
	if not active:
		return
	if not (area is Hurtbox):
		return
	if one_shot_per_target and area in _already_hit:
		return

	var resolved_source: Node = _resolve_source_node()
	if resolved_source != null and (area.owner == resolved_source or area.get_parent() == resolved_source):
		return

	var hurtbox: Hurtbox = area as Hurtbox
	var info: DamageInfo = build_damage_info()
	if hurtbox.receive_hit(info):
		if one_shot_per_target:
			_already_hit.append(area)
		hit_landed.emit(hurtbox, info)
