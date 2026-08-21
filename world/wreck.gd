extends StaticBody3D

const LOOK := preload("res://world/WorldLook.gd")

@export var part_id: String = "vulcan_chest"
@export var extra_ids: PackedStringArray = PackedStringArray()

var looted: bool = false
var remaining: Array[String] = []
var _grant_peer: int = 0
var _grant_id: String = ""

@onready var _loot_mesh: MeshInstance3D = get_node_or_null("LootGlow")


func _ready() -> void:
	add_to_group("loot")
	collision_layer = 9
	collision_mask = 0
	remaining.append(part_id)
	for id in extra_ids:
		remaining.append(id)
	LOOK.smoke(self, Vector3(0.2, 2.1, 0.3), Color(0.16, 0.14, 0.12, 0.5))
	if _loot_mesh:
		_loot_mesh.material_override = LOOK.emit_surface(Color(0.95, 0.45, 0.1), 2.2)
	var ember := OmniLight3D.new()
	ember.light_color = Color(1.0, 0.4, 0.1)
	ember.light_energy = 2.4
	ember.omni_range = 7.0
	ember.position = Vector3(0.3, 2.2, 0.6)
	add_child(ember)


func get_interact_label() -> String:
	if remaining.is_empty() or looted:
		return "Wreck stripped clean"
	return "Loot %s  [E]  (%d left)" % [RunState.part_display_name(remaining[0]), remaining.size()]


func interact(_actor: Node) -> void:
	if remaining.is_empty():
		looted = true
		return
	if NetSession.is_online() and not NetSession.is_host():
		rpc_request_loot.rpc_id(1)
		return
	_host_give(NetSession.local_id())


func _host_give(peer_id: int) -> void:
	if remaining.is_empty():
		rpc_sync_wreck.rpc(_remaining_payload(), looted)
		return
	if _grant_peer != 0:
		return
	if peer_id <= 0:
		return
	var id := remaining[0]
	remaining.remove_at(0)
	var part := RunState.make_part(id, randf_range(0.45, 0.92))
	if part.is_empty():
		remaining.insert(0, id)
		return
	if peer_id == NetSession.local_id():
		if not RunState.add_carry(part):
			remaining.insert(0, id)
			Hud.show_banner("Carry full.")
			return
		Hud.refresh_carry()
		Hud.show_banner("Picked up %s" % part.get("display_name", "part"))
		Fx.play("ui")
		if remaining.is_empty():
			looted = true
			if _loot_mesh:
				_loot_mesh.visible = false
		rpc_sync_wreck.rpc(_remaining_payload(), looted)
		return
	_grant_peer = peer_id
	_grant_id = id
	rpc_grant_part.rpc_id(peer_id, part)


func _remaining_payload() -> Array:
	var out: Array = []
	for id in remaining:
		out.append(id)
	return out


@rpc("any_peer", "reliable")
func rpc_request_loot() -> void:
	if not NetSession.is_host():
		return
	_host_give(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable")
func rpc_grant_part(part: Dictionary) -> void:
	if not NetSession.sanity_loot(part):
		return
	if RunState.add_carry(part):
		Hud.refresh_carry()
		Hud.show_banner("Picked up %s" % part.get("display_name", "part"))
		Fx.play("ui")
		rpc_wreck_result.rpc_id(1, true, str(part.get("id", "")))
	else:
		Hud.show_banner("Carry full.")
		rpc_wreck_result.rpc_id(1, false, str(part.get("id", "")))


@rpc("any_peer", "reliable")
func rpc_wreck_result(ok: bool, id: String) -> void:
	if not NetSession.is_host():
		return
	if multiplayer.get_remote_sender_id() != _grant_peer:
		return
	var restored_id := _grant_id if id == "" else id
	_grant_peer = 0
	_grant_id = ""
	if ok:
		if remaining.is_empty():
			looted = true
			if _loot_mesh:
				_loot_mesh.visible = false
		rpc_sync_wreck.rpc(_remaining_payload(), looted)
		return
	if restored_id != "":
		remaining.insert(0, restored_id)
	looted = false
	if _loot_mesh:
		_loot_mesh.visible = true
	rpc_sync_wreck.rpc(_remaining_payload(), looted)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_wreck(left: Array, is_looted: bool) -> void:
	remaining.clear()
	for id in left:
		remaining.append(str(id))
	looted = is_looted
	if remaining.is_empty() and _loot_mesh:
		_loot_mesh.visible = false


func ai_steal() -> Dictionary:
	if remaining.is_empty() or _grant_peer != 0:
		return {}
	var id := remaining[0]
	remaining.remove_at(0)
	if remaining.is_empty() and _loot_mesh:
		_loot_mesh.visible = false
		looted = true
	return RunState.make_part(id, randf_range(0.35, 0.8))


func clear_pending_grant(peer_id: int) -> void:
	if _grant_peer != peer_id:
		return
	if _grant_id != "":
		remaining.insert(0, _grant_id)
		looted = false
		if _loot_mesh:
			_loot_mesh.visible = true
	_grant_peer = 0
	_grant_id = ""
	rpc_sync_wreck.rpc(_remaining_payload(), looted)
