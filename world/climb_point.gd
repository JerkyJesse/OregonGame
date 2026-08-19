extends Area3D
class_name ClimbPoint

@export var target_path: NodePath


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_interact_label() -> String:
	return "Climb calf  [E] pry plate  (heavy will notice)"


func interact(actor: Node) -> void:
	var t := get_node_or_null(target_path)
	if t and t.is_in_group("heavy_mech") and actor is Scavenger:
		t.call("pry_plate", actor)
		t.call("alert_to", global_position)
