extends Area3D
class_name ClimbPoint

@export var target_path: NodePath


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_interact_label() -> String:
	return "Hold [E] climb calf — pry plate (heavy will notice)"


func interact(actor: Node) -> void:
	hold_pry(actor, 0.0)


func hold_pry(actor: Node, delta: float) -> void:
	var t := get_node_or_null(target_path)
	if t == null or not (actor is Scavenger):
		return
	var scav := actor as Scavenger
	var dest := global_position + Vector3(0, 1.35, 0)
	scav.global_position = scav.global_position.lerp(dest, clampf(delta * 6.0, 0.0, 1.0))
	scav.velocity = Vector3.ZERO
	if t.has_method("hold_pry"):
		t.call("hold_pry", actor, delta)
	elif t.is_in_group("heavy_mech") and t.has_method("pry_plate") and delta > 0.0:
		t.call("pry_plate", actor)
	if t.has_method("alert_to") and delta > 0.0:
		t.call("alert_to", global_position)
