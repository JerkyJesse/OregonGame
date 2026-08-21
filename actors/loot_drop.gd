extends StaticBody3D
class_name LootDrop

const LOOK := preload("res://world/WorldLook.gd")

var part: Dictionary = {}
var extra: Array = []
var rival_bag: bool = false
var torn_off: bool = false
var _spin: float = 0.0


func _ready() -> void:
	add_to_group("loot")
	if rival_bag or name.begins_with("RivalBag"):
		rival_bag = true
		add_to_group("rival_bag")
	if torn_off or bool(part.get("torn_off", false)) or name.begins_with("Torn_"):
		torn_off = true
		add_to_group("torn_loot")
	collision_layer = 9
	collision_mask = 0
	_grow_pickup_shape()
	_dress_glow()


func _grow_pickup_shape() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
	var box := BoxShape3D.new()
	if torn_off or rival_bag:
		box.size = Vector3(1.9, 2.6, 1.9)
		col.position = Vector3(0, 1.0, 0)
	else:
		box.size = Vector3(1.2, 1.4, 1.2)
		col.position = Vector3(0, 0.35, 0)
	col.shape = box


func _dress_glow() -> void:
	var tint := Color(1.0, 0.55, 0.15)
	var energy := 2.2
	var light_range := 4.5
	if rival_bag:
		tint = Color(0.95, 0.35, 0.12)
		energy = 3.4
		light_range = 7.0
		if has_node("Glow"):
			($Glow as MeshInstance3D).scale = Vector3(1.45, 1.45, 1.45)
		var tag := Label3D.new()
		tag.name = "BagTag"
		tag.text = "RIVAL BAG"
		tag.position = Vector3(0, 1.15, 0)
		tag.font_size = 28
		tag.modulate = Color(1.0, 0.55, 0.25)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.outline_size = 6
		tag.outline_modulate = Color(0, 0, 0, 0.9)
		add_child(tag)
	elif torn_off:
		tint = Color(1.0, 0.72, 0.18)
		energy = 3.8
		light_range = 6.5
		if has_node("Glow"):
			($Glow as MeshInstance3D).scale = Vector3(1.35, 1.35, 1.35)
		var torn := Label3D.new()
		torn.name = "TornTag"
		torn.text = "TORN OFF\n%s" % str(part.get("display_name", "PART")).to_upper()
		torn.position = Vector3(0, 1.2, 0)
		torn.font_size = 26
		torn.modulate = Color(1.0, 0.78, 0.32)
		torn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		torn.outline_size = 6
		torn.outline_modulate = Color(0, 0, 0, 0.9)
		add_child(torn)
	if has_node("Glow"):
		var c: Array = part.get("albedo", [tint.r, tint.g, tint.b]) if part.has("albedo") else [tint.r, tint.g, tint.b]
		($Glow as MeshInstance3D).material_override = LOOK.emit_surface(Color(float(c[0]), float(c[1]), float(c[2])), 2.8 if rival_bag else 2.4)
	var light := OmniLight3D.new()
	light.name = "LookLight"
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = light_range
	add_child(light)
	LOOK.sparkle(self, Vector3.ZERO, Color(tint.r, tint.g, tint.b, 0.75), 0.45 if rival_bag else 0.35)


func _process(delta: float) -> void:
	_spin += delta
	if has_node("Glow"):
		$Glow.position.y = sin(_spin * 2.6) * 0.12
		$Glow.rotate_y(delta * 1.7)
	if rival_bag and has_node("BagTag"):
		$BagTag.position.y = 1.15 + sin(_spin * 2.0) * 0.08
	if torn_off and has_node("TornTag"):
		$TornTag.position.y = 1.2 + sin(_spin * 2.2) * 0.08


func get_interact_label() -> String:
	if part.is_empty():
		return ""
	if rival_bag or extra.size() > 0:
		return WorldLore.rival_bag_label(str(part.get("display_name", "part")), extra.size())
	if torn_off:
		return WorldLore.torn_drop_label(str(part.get("display_name", "part")))
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
		if rival_bag:
			Hud.show_banner("Stole rival bag — %s" % taken.get("display_name", "part"), Hud.BANNER_HIGH)
		elif torn_off:
			Hud.show_banner("Grabbed torn %s" % taken.get("display_name", "part"), Hud.BANNER_HIGH)
		else:
			Hud.show_banner("Picked up %s" % taken.get("display_name", "part"), Hud.BANNER_HIGH)
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
		Hud.show_banner("Picked up %s" % taken.get("display_name", "part"), Hud.BANNER_HIGH)
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
