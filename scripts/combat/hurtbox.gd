class_name Hurtbox
extends Area2D
## Reusable damage receiver Area2D for Player, Enemies, and Bosses.
##
## Physics Layer Contract (1-indexed layers -> bitmask values):
##   1 = world (1)
##   2 = one_way (2)
##   3 = player (4)
##   4 = enemy (8)
##   5 = player_hitbox (16)
##   6 = enemy_hitbox (32)
##   7 = interactable (64)
##   8 = hazard (128)
##
## Hurtbox configuration:
##   - monitorable = true, monitoring = false
##   - Player Hurtbox: collision_layer = 4 (layer 3: player), collision_mask = 0
##   - Enemy / Boss Hurtbox: collision_layer = 8 (layer 4: enemy), collision_mask = 0
##
## Hitboxes detect Hurtboxes and invoke receive_hit(info: DamageInfo).

signal damaged(info: DamageInfo)

@export var invulnerable: bool = false


func _ready() -> void:
	monitorable = true
	monitoring = false


func set_invulnerable(value: bool) -> void:
	invulnerable = value


func receive_hit(info: DamageInfo) -> bool:
	if invulnerable or info == null:
		return false
	damaged.emit(info)
	return true
