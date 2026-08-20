extends Area3D
class_name ClimbPoint

@export var target_path: NodePath
## 0 = calf (mount), 1 = thigh, 2 = pry plate
@export var stage: int = 0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("climb_point")


func get_interact_label() -> String:
	return WorldLore.climb_stage_label(stage)


func interact(actor: Node) -> void:
	hold_pry(actor, 0.0)


func hold_pry(actor: Node, delta: float) -> void:
	var t := get_node_or_null(target_path)
	if t == null or not (actor is Scavenger):
		return
	var scav := actor as Scavenger
	var lift := 1.15 + float(stage) * 1.55
	var dest := global_position + Vector3(0, lift, 0)
	scav.global_position = scav.global_position.lerp(dest, clampf(delta * 7.0, 0.0, 1.0))
	scav.velocity = Vector3.ZERO
	if stage >= 2:
		if t.has_method("hold_pry"):
			t.call("hold_pry", actor, delta)
		elif t.is_in_group("heavy_mech") and t.has_method("pry_plate") and delta > 0.0:
			t.call("pry_plate", actor)
	elif delta > 0.0 and stage == 1:
		Hud.set_prompt(WorldLore.climb_stage_label(1) + "  — look up for pry")
	if t.has_method("alert_to") and delta > 0.0 and stage >= 1:
		t.call("alert_to", global_position)
