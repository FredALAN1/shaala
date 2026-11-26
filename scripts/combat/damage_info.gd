class_name DamageInfo
extends RefCounted
## Data payload passed from a Hitbox to a Hurtbox on contact.
## Shared combat contract across player, enemies, and bosses.

var amount: int = 1
var source_position: Vector2 = Vector2.ZERO
var knockback: Vector2 = Vector2(220.0, -140.0)
var parryable: bool = true
var damage_type: String = "melee"
var source_node: Node = null


static func create(
	p_amount: int,
	p_source_position: Vector2 = Vector2.ZERO,
	p_knockback: Vector2 = Vector2(220.0, -140.0),
	p_parryable: bool = true,
	p_damage_type: String = "melee",
	p_source_node: Node = null
) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.source_position = p_source_position
	info.knockback = p_knockback
	info.parryable = p_parryable
	info.damage_type = p_damage_type
	info.source_node = p_source_node
	return info


func duplicate_info() -> DamageInfo:
	return DamageInfo.create(
		amount,
		source_position,
		knockback,
		parryable,
		damage_type,
		source_node
	)
