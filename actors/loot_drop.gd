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
	if NetSession.is_online() and not NetSession.is_host():
		rpc_request_loot.rpc_id(1)
		return
	_host_give(NetSession.local_id())


func _host_give(peer_id: int) -> void:
	if part.is_empty():
		return
	var taken: Dictionary = part
	if peer_id == NetSession.local_id():
		if not RunState.add_carry(taken):
			Hud.show_banner("Carry full.")
			return
		Hud.refresh_carry()
		Hud.show_banner("Picked up %s" % taken.get("display_name", "part"))
		part = {}
		rpc_taken.rpc()
		queue_free()
		return
	rpc_grant_part.rpc_id(peer_id, taken)
	part = {}
	rpc_taken.rpc()
	queue_free()


@rpc("any_peer", "reliable")
func rpc_request_loot() -> void:
	if not NetSession.is_host():
		return
	_host_give(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable")
func rpc_grant_part(taken: Dictionary) -> void:
	if not NetSession.sanity_loot(taken):
		return
	if RunState.add_carry(taken):
		Hud.refresh_carry()
		Hud.show_banner("Picked up %s" % taken.get("display_name", "part"))
	else:
		Hud.show_banner("Carry full.")


@rpc("authority", "call_remote", "reliable")
func rpc_taken() -> void:
	queue_free()


func ai_steal() -> void:
	queue_free()
