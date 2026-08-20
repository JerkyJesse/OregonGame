extends Area3D
class_name SealedPocket

## Greybox sealed-steel pocket — on foot inside, filter does not drain.


func _ready() -> void:
	add_to_group("sealed_steel")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false


func covers(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	return overlaps_body(body)
