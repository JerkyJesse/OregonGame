extends StaticBody3D
class_name Breakable

@export var hp: float = 40.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		var n := get_parent()
		if n and n.has_method("spawn_loot"):
			n.call("spawn_loot", RunState.make_part("armor_plate", 0.3), global_position)
		queue_free()
