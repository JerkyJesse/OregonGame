extends StaticBody3D
class_name LootDrop

const LOOK := preload("res://world/WorldLook.gd")

var part: Dictionary = {}
var extra: Array = []
var _spin: float = 0.0


func _ready() -> void:
	add_to_group("loot")
	collision_layer = 9
	collision_mask = 0
	if has_node("Glow") and part.has("albedo"):
		var c: Array = part.get("albedo", [1, 0.5, 0.1])
		($Glow as MeshInstance3D).material_override = LOOK.emit_surface(Color(float(c[0]), float(c[1]), float(c[2])), 2.4)
	var light := OmniLight3D.new()
	light.name = "LookLight"
	light.light_color = Color(1.0, 0.55, 0.15)
	light.light_energy = 2.2
	light.omni_range = 4.5
	add_child(light)
	LOOK.sparkle(self, Vector3.ZERO, Color(1.0, 0.6, 0.2, 0.7), 0.35)


func _process(delta: float) -> void:
	_spin += delta
	if has_node("Glow"):
		$Glow.position.y = sin(_spin * 2.6) * 0.12
		$Glow.rotate_y(delta * 1.7)


func get_interact_label() -> String:
	if part.is_empty():
		return ""
	if extra.size() > 0:
		return WorldLore.rival_bag_label(str(part.get("display_name", "part")), extra.size())
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
		_pop_next()
		if part.is_empty():
			rpc_taken.rpc()
			queue_free()
		return
	rpc_grant_part.rpc_id(peer_id, taken)


@rpc("any_peer", "reliable")
func rpc_loot_result(ok: bool) -> void:
	if not NetSession.is_host():
		return
	if ok:
		_pop_next()
		if part.is_empty():
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
		rpc_loot_result.rpc_id(1, true)
	else:
		Hud.show_banner("Carry full.")
		rpc_loot_result.rpc_id(1, false)


@rpc("authority", "call_remote", "reliable")
func rpc_taken() -> void:
	queue_free()


func ai_steal() -> Dictionary:
	if part.is_empty():
		return {}
	var taken: Dictionary = part
	_pop_next()
	if part.is_empty():
		queue_free()
	return taken


func _pop_next() -> void:
	if extra.is_empty():
		part = {}
		return
	var nxt: Variant = extra.pop_front()
	if nxt is Dictionary:
		part = nxt
	else:
		part = {}
		_pop_next()
