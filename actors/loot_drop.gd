extends StaticBody3D
class_name LootDrop

var part: Dictionary = {}


func _ready() -> void:
	add_to_group("loot")
	collision_layer = 9
	collision_mask = 0
	if has_node("Glow") and part.has("albedo"):
		var c: Array = part.get("albedo", [1, 0.5, 0.1])
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(float(c[0]), float(c[1]), float(c[2]))
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.8
		($Glow as MeshInstance3D).material_override = mat


func get_interact_label() -> String:
	if part.is_empty():
		return ""
	return "Pick up %s  [E]" % part.get("display_name", "part")


func interact(_actor: Node) -> void:
	if part.is_empty():
		return
	if not NetSession.sanity_loot(part):
		return
	if RunState.add_carry(part):
		Hud.refresh_carry()
		Hud.show_banner("Picked up %s" % part.get("display_name", "part"))
		queue_free()
	else:
		Hud.show_banner("Carry full.")


func ai_steal() -> void:
	queue_free()
