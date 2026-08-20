class_name RaidDirector
extends RefCounted

const LOOK := preload("res://world/WorldLook.gd")
const WRECK_SCENE := preload("res://world/wreck.tscn")
const LIGHT_SCENE := preload("res://actors/light_mech.tscn")
const MEDIUM_SCENE := preload("res://actors/medium_mech.tscn")
const HEAVY_SCENE := preload("res://actors/heavy_mech.tscn")
const HAULER_SCENE := preload("res://actors/hauler.tscn")
const SCAV_SCENE := preload("res://actors/scavenger.tscn")
const LOOT_SCENE := preload("res://actors/loot_drop.tscn")
const EXTRACT_SCENE := preload("res://world/extract_zone.tscn")
const AI_SCENE := preload("res://actors/ai_scavenger.tscn")
const PALE_SCENE := preload("res://actors/pale_host.tscn")
const HUSK_SCENE := preload("res://actors/choir_husk.tscn")


static func begin(world: Node3D, map_id: String) -> void:
	RunState.raid_map = map_id
	RunState.begin_raid()
	Hud.enter_gameplay()
	Hud.reset_for_scene()
	Hud.set_objective(WorldLore.raid_objective(map_id, RunState.raid_mode))
	Hud.set_health(RunState.health)
	Hud.refresh_carry()
	if world.has_node("Cover"):
		if map_id == "pipeline":
			Greybox.build_pipeline(world.get_node("Cover"))
		else:
			Greybox.build_raid_cover(world.get_node("Cover"))
	_setup_existing(world)
	if map_id == "pipeline":
		_setup_pipeline(world)
	else:
		_setup_ash_yard(world)
	_spawn_extracts(world, map_id)
	_spawn_events(world, map_id)
	_deploy_player(world, map_id)
	_net_spawns(world)
	_start_band(world)
	LOOK.apply(world, LOOK.KIND_PIPE if map_id == "pipeline" else LOOK.KIND_YARD)


static func spawn_loot(world: Node, part: Dictionary, pos: Vector3, drop_name: String = "", extra: Array = []) -> void:
	if part.is_empty() or world == null:
		return
	var drop: Node3D = LOOT_SCENE.instantiate()
	if drop_name != "":
		drop.name = drop_name
	drop.set("part", part)
	if not extra.is_empty():
		drop.set("extra", extra.duplicate())
	world.add_child(drop)
	drop.global_position = pos + Vector3(0, 0.6, 0)


static func spawn_bag(world: Node, parts: Array, pos: Vector3, drop_name: String = "") -> void:
	if world == null or parts.is_empty():
		return
	var first: Variant = parts[0]
	if not (first is Dictionary) or (first as Dictionary).is_empty():
		return
	var rest: Array = []
	for i in range(1, parts.size()):
		var item: Variant = parts[i]
		if item is Dictionary and not (item as Dictionary).is_empty():
			rest.append(item)
	spawn_loot(world, first, pos, drop_name, rest)


static func emit_loot(world: Node, part: Dictionary, pos: Vector3) -> void:
	if world != null and world.has_method("spawn_loot"):
		world.call("spawn_loot", part, pos)
	else:
		spawn_loot(world, part, pos)


static func update_raid_objective(world: Node3D) -> void:
	if RunState.raid_map == "pipeline":
		var open_dais := false
		for n in world.get_tree().get_nodes_in_group("shard_dais"):
			if not bool(n.get("core_taken")):
				open_dais = true
		if open_dais:
			Hud.set_objective(WorldLore.raid_objective("pipeline", RunState.raid_mode))
		elif RunState.carrying_payload():
			Hud.set_objective("SHARD IN BAG — green extract, blue stealth, or pay Brask on the west pad.")
		else:
			Hud.set_objective(WorldLore.raid_objective("pipeline", RunState.raid_mode))
		return
	update_ash_objective(world)


static func update_ash_objective(world: Node3D) -> void:
	if RunState.raid_map == "pipeline":
		return
	var light: Node = world.get_node_or_null("LightMech")
	var bolted := false
	if light and light.has_method("best_weapon_name"):
		bolted = str(light.call("best_weapon_name")) != ""
	elif light:
		var pack: Variant = light.get("equipped")
		if pack is Dictionary:
			for slot in RunState.SLOTS:
				var part: Variant = (pack as Dictionary).get(slot, {})
				if part is Dictionary and bool(part.get("is_weapon", false)):
					bolted = true
	var carrying_gun := false
	for part in RunState.raid_carry:
		if bool(part.get("is_weapon", false)):
			carrying_gun = true
	if bolted:
		Hud.set_objective(WorldLore.ash_progress_objective("bolted"))
	elif carrying_gun:
		Hud.set_objective(WorldLore.ash_progress_objective("carrying_gun"))
	elif RunState.raid_carry.size() > 0:
		Hud.set_objective(WorldLore.ash_progress_objective("loot"))
	else:
		Hud.set_objective(WorldLore.raid_objective("ash_yard", RunState.raid_mode))


static func _setup_existing(world: Node3D) -> void:
	if world.has_node("LightMech"):
		var light: Node = world.get_node("LightMech")
		light.set("hangar_preview", false)
		light.set("disabled", false)
		light.set("alive", true)
		if light.has_method("apply_loadout"):
			light.call("apply_loadout")
		_nameplate(light, "PARKED LIGHT — bolt a gun", Vector3(0, 5.4, 0), Color(0.9, 0.55, 0.2))
	if world.has_node("HeavyMech"):
		var heavy: Node = world.get_node("HeavyMech")
		var points: Array[Vector3] = []
		if world.has_node("PatrolA") and world.has_node("PatrolB"):
			points = [world.get_node("PatrolA").global_position, world.get_node("PatrolB").global_position]
		if heavy.has_method("set_patrol"):
			heavy.call("set_patrol", points)
		heavy.set("ai_controlled", RunState.deploy_scale != "heavy")
		if heavy.has_signal("died"):
			heavy.connect("died", func(pos: Vector3) -> void:
				_on_machine_died(world, pos)
			)
		if heavy.has_signal("component_dropped"):
			heavy.connect("component_dropped", func(part: Dictionary, pos: Vector3) -> void:
				emit_loot(world, part, pos)
			)
		_attach_climb(heavy)
		_attach_core(heavy)
		_nameplate(heavy, "OCCUPANCY WALKER — First Voice coat", Vector3(0, 8.4, 0), Color(0.45, 1.0, 0.4))
	if world.has_node("Wreck"):
		world.get_node("Wreck").set("extra_ids", PackedStringArray(["cooler_pack", "sensor_suite", "filter_canister", "shield_emitter"]))


static func _setup_ash_yard(world: Node3D) -> void:
	var med: Node3D = MEDIUM_SCENE.instantiate()
	med.name = "DeadMedium"
	med.position = Vector3(-12, 0, -6)
	med.set("hangar_preview", false)
	world.add_child(med)
	if RunState.raid_mode == "late_drop":
		med.call("seed_wreck_parts", ["armor_plate", "reactor_core", "data_core"])
		spawn_loot(world, RunState.make_part("vulcan_chest", 0.52), Vector3(-20, 0, -5))
		spawn_loot(world, RunState.make_part("filter_canister", 0.7), Vector3(-18, 0, -3))
	else:
		med.call("seed_wreck_parts", ["vulcan_chest", "pulse_cannon", "armor_plate", "reactor_core", "data_core", "jump_jets"])
	med.set("disabled", true)
	med.set("alive", false)
	med.set("hull", 0.0)
	med.rotation_degrees = Vector3(8.0, 32.0, 18.0)
	med.position = Vector3(-12, 0.55, -6)
	_nameplate(med, "KNEELING HELIX — Jex already started" if RunState.raid_mode == "late_drop" else "KNEELING HELIX — strip the gun", Vector3(0, 6.2, 0), Color(0.85, 0.7, 0.35))
	if med.has_signal("component_dropped"):
		med.connect("component_dropped", func(part: Dictionary, pos: Vector3) -> void:
			emit_loot(world, part, pos)
		)
	_attach_core(med)
	if RunState.raid_mode == "scav_wave":
		var m2: Node3D = MEDIUM_SCENE.instantiate()
		m2.name = "ScavWaveHusk"
		m2.position = Vector3(12, 0, 16)
		world.add_child(m2)
		m2.call("seed_wreck_parts", ["missile_pod", "heavy_plating", "knee_vulcan", "filter_canister", "shield_emitter"])
		m2.set("disabled", true)
		m2.set("alive", false)
		m2.set("hull", 0.0)
		_nameplate(m2, "SECOND HUSK — strip it", Vector3(0, 6.2, 0), Color(0.85, 0.55, 0.3))
		if m2.has_signal("component_dropped"):
			m2.connect("component_dropped", func(part: Dictionary, pos: Vector3) -> void:
				emit_loot(world, part, pos)
			)
		_attach_core(m2)


static func _setup_pipeline(world: Node3D) -> void:
	if world.has_node("LightMech"):
		world.get_node("LightMech").position = Vector3(4, 0, 4)
	var med: Node3D = MEDIUM_SCENE.instantiate()
	med.name = "DeadMedium"
	med.position = Vector3(-8, 0, 6)
	world.add_child(med)
	med.call("seed_wreck_parts", ["pile_bunker", "pulse_cannon", "armor_plate", "data_core", "jump_jets"])
	med.set("disabled", true)
	med.set("alive", false)
	med.set("hull", 0.0)
	if med.has_signal("component_dropped"):
		med.connect("component_dropped", func(part: Dictionary, pos: Vector3) -> void:
			emit_loot(world, part, pos)
		)
	var hv: Node3D = HEAVY_SCENE.instantiate()
	hv.position = Vector3(18, 0, -10)
	world.add_child(hv)
	hv.set("ai_controlled", RunState.deploy_scale != "heavy")
	var pts: Array[Vector3] = [Vector3(18, 0, -10), Vector3(-16, 0, 12)]
	hv.call("set_patrol", pts)
	if hv.has_signal("died"):
		hv.connect("died", func(pos: Vector3) -> void:
			_on_machine_died(world, pos)
		)
	if hv.has_signal("component_dropped"):
		hv.connect("component_dropped", func(part: Dictionary, pos: Vector3) -> void:
			emit_loot(world, part, pos)
		)
	_attach_core(med)
	_attach_climb(hv)
	_attach_core(hv)
	_spawn_dais(world, Vector3(0, 0, 11.2))


static func _spawn_extracts(world: Node3D, map_id: String) -> void:
	if world.has_node("ExtractZone"):
		world.get_node("ExtractZone").set("extract_type", "contested")
	var stealth: Node3D = EXTRACT_SCENE.instantiate()
	stealth.position = Vector3(-40, 0, 18) if map_id != "pipeline" else Vector3(-26, 0, 18)
	world.add_child(stealth)
	stealth.set("extract_type", "stealth")
	stealth.call("_paint")
	var payload: Node3D = EXTRACT_SCENE.instantiate()
	payload.position = Vector3(0, 0, -36) if map_id != "pipeline" else Vector3(8, 0, -22)
	world.add_child(payload)
	payload.set("extract_type", "payload")
	payload.call("_paint")
	var veh: Node3D = EXTRACT_SCENE.instantiate()
	veh.position = Vector3(32, 0, -22) if map_id != "pipeline" else Vector3(24, 0, 16)
	world.add_child(veh)
	veh.set("extract_type", "vehicle")
	veh.call("_paint")
	_spawn_tax(world, map_id)


static func _spawn_events(world: Node3D, map_id: String) -> void:
	var storm: Node3D = (load("res://world/toxic_storm.gd") as GDScript).new()
	world.add_child(storm)
	_breakable(world, Vector3(-20, 1, 2), Vector3(3, 2, 1.2))
	_breakable(world, Vector3(4, 1, 10), Vector3(2.4, 2.2, 2.4))
	_breakable(world, Vector3(-6, 1, -10), Vector3(4, 1.6, 1))
	_spawn_rivals(world, map_id)
	var kit := RunState.make_part("filter_canister", 0.8)
	if not kit.is_empty():
		var kit_pos := Vector3(-26, 0, 6) if map_id != "pipeline" else Vector3(-18, 0, -4)
		spawn_loot(world, kit, kit_pos, "FilterDrop")
		var drop := world.get_node_or_null("FilterDrop")
		if drop:
			_nameplate(drop, "SEALED-AIR CAN  [E] then [R] swap", Vector3(0, 1.6, 0), Color(0.55, 0.95, 0.45))
	if map_id != "pipeline":
		world.get_tree().create_timer(90.0).timeout.connect(func() -> void:
			if not is_instance_valid(world) or not RunState.in_raid:
				return
			Hud.show_banner(WorldLore.incoming_heavy_banner())
			Fx.play("alarm")
			var extra: Node3D = HEAVY_SCENE.instantiate()
			extra.position = Vector3(-30, 0, -24)
			world.add_child(extra)
			extra.set("ai_controlled", true)
			if extra.has_method("set_patrol"):
				extra.call("set_patrol", [Vector3(-30, 0, -24), Vector3(-10, 0, 20)])
			_nameplate(extra, "INBOUND WALKER", Vector3(0, 8.4, 0), Color(0.95, 0.35, 0.2))
		)


static func _breakable(world: Node3D, pos: Vector3, size: Vector3) -> void:
	var b: Node3D = (load("res://world/breakable.gd") as GDScript).new()
	b.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = Greybox.mat(Color(0.4, 0.3, 0.2))
	mesh.mesh = box
	b.add_child(mesh)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	b.add_child(col)
	world.add_child(b)


static func player_node_name(id: int) -> String:
	return "Scavenger_%d" % id


static func spawn_proxy(world: Node3D, id: int) -> void:
	_spawn_proxy(world, id)


static func _spawn_pos(map_id: String, peer_id: int) -> Vector3:
	var slot := float((peer_id - 1) % 8)
	var base := Vector3(-32, 1.2, 10)
	match RunState.faction:
		"corporate":
			base = Vector3(22, 8.6, 0) if map_id == "pipeline" else Vector3(-38, 1.2, -22)
		"remnant":
			base = Vector3(-30, 1.2, -16) if map_id == "pipeline" else Vector3(-40, 1.2, -8)
		"warlord":
			base = Vector3(16, 1.2, 28) if map_id == "pipeline" else Vector3(-36, 1.2, 22)
		"pale":
			base = Vector3(20, 1.2, -18) if map_id == "pipeline" else Vector3(8, 1.2, 36)
		_:
			base = Vector3(-22, 1.2, -10) if map_id == "pipeline" else Vector3(-42, 1.2, 16)
	if RunState.raid_mode == "late_drop" and not NetSession.is_host():
		base = Vector3(-24, 1.2, 8) if map_id == "pipeline" else Vector3(-42, 1.2, 10)
	base.z += slot * 1.6
	return base


static func _deploy_player(world: Node3D, map_id: String) -> void:
	var scav: Scavenger = world.get_node_or_null("Scavenger") as Scavenger
	if scav == null:
		scav = SCAV_SCENE.instantiate()
		world.add_child(scav)
	var local := NetSession.local_id()
	scav.name = player_node_name(local)
	scav.peer_id = local
	scav.set_multiplayer_authority(local)
	var spawn := _spawn_pos(map_id, local)
	scav.position = spawn
	scav.set("spawn_point", spawn)
	scav.set("spawn_protect", 5.0)
	if RunState.deploy_scale == "light" or RunState.deploy_scale == "armor":
		if world.has_node("LightMech"):
			var light: Node = world.get_node("LightMech")
			light.set("power_armor", RunState.deploy_scale == "armor")
			if light.has_method("apply_power_armor_frame"):
				light.call("apply_power_armor_frame")
			light.call("board_pilot", scav)
	elif RunState.deploy_scale == "medium":
		var med: Node3D = MEDIUM_SCENE.instantiate()
		med.position = scav.position + Vector3(4, 0, 0)
		world.add_child(med)
		med.call("board_pilot", scav)
	elif RunState.deploy_scale == "heavy":
		var heavy: Node = world.get_node_or_null("HeavyMech")
		if heavy == null:
			heavy = HEAVY_SCENE.instantiate()
			heavy.position = scav.position + Vector3(6, 0, 0)
			world.add_child(heavy)
		heavy.set("ai_controlled", false)
		heavy.set("disabled", false)
		heavy.call("board_pilot", scav)
	elif RunState.deploy_scale == "vehicle":
		var h: Node3D = HAULER_SCENE.instantiate()
		h.position = scav.position + Vector3(5, 0, 0)
		world.add_child(h)
		h.call("board_pilot", scav)


static func _net_spawns(world: Node3D) -> void:
	if not NetSession.is_online():
		return
	for pid in world.multiplayer.get_peers():
		_spawn_proxy(world, pid)


static func _spawn_proxy(world: Node3D, id: int) -> void:
	if not is_instance_valid(world):
		return
	if id == NetSession.local_id():
		return
	var n := player_node_name(id)
	if world.has_node(n):
		return
	var extra: Node3D = SCAV_SCENE.instantiate()
	extra.name = n
	extra.set("peer_id", id)
	extra.position = _spawn_pos(RunState.raid_map, id)
	world.add_child(extra)
	extra.set_multiplayer_authority(id)
	Hud.show_banner(WorldLore.peer_drop_banner(id))


static func _on_machine_died(world: Node3D, pos: Vector3) -> void:
	var wreck := WRECK_SCENE.instantiate()
	wreck.set("part_id", "reactor_core")
	wreck.set("extra_ids", PackedStringArray(["heavy_plating", "missile_pod"]))
	world.add_child(wreck)
	wreck.global_position = Vector3(pos.x, 0.0, pos.z)
	Hud.show_banner(WorldLore.machine_down_banner())
	RunState.heavy_engaged = true


static func _attach_climb(heavy: Node) -> void:
	var c: Node3D = (load("res://world/climb_point.gd") as GDScript).new()
	var sh := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 3.0
	cyl.radius = 2.2
	sh.shape = cyl
	c.add_child(sh)
	heavy.add_child(c)
	c.position = Vector3(2.4, 1.2, 0)
	c.set("target_path", heavy.get_path())


static func _attach_core(machine: Node) -> void:
	var p: Node3D = (load("res://world/data_core_port.gd") as GDScript).new()
	var sh := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.4, 1.4)
	sh.shape = box
	p.add_child(sh)
	var glow := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.5, 0.5, 0.5)
	m.material = Greybox.mat(Color(0.4, 1.0, 0.4), 2.0)
	glow.mesh = m
	p.add_child(glow)
	machine.add_child(p)
	var y := 6.0 if str(machine.get("scale_id")) == "heavy" else 2.2
	p.position = Vector3(0, y, 1.6)


static func _start_band(world: Node3D) -> void:
	var band: Node = (load("res://world/yard_band.gd") as GDScript).new()
	world.add_child(band)


static func _spawn_tax(world: Node3D, map_id: String) -> void:
	var pad: Node3D = EXTRACT_SCENE.instantiate()
	pad.position = Vector3(-38, 0, -18) if map_id != "pipeline" else Vector3(-22, 0, 20)
	world.add_child(pad)
	pad.set("extract_type", "tax")
	pad.call("_paint")
	var gate: Node3D = HAULER_SCENE.instantiate()
	gate.position = pad.position + Vector3(8, 0, 0)
	gate.set("hangar_preview", false)
	gate.set("ai_controlled", false)
	world.add_child(gate)
	gate.set("hull_max", 90.0)
	gate.set("hull", 90.0)
	pad.set("tax_gate", gate)
	_nameplate(gate, "BRASK COURT — extract-tax", Vector3(0, 4.2, 0), Color(0.85, 0.28, 0.18))
	if RunState.faction == "warlord":
		world.get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_instance_valid(world):
				Hud.show_banner(WorldLore.tax_court_banner())
		)
		return
	_spawn_face(world, "tax", gate.position + Vector3(-2.4, 0.2, 2.2))
	_spawn_face(world, "tax", gate.position + Vector3(2.2, 0.2, -2.0))
	world.get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(world):
			Hud.show_banner(WorldLore.tax_inbound_banner())
	)


static func _spawn_rivals(world: Node3D, map_id: String) -> void:
	if RunState.faction != "pale":
		var bloom_pos := Vector3(18, 0.2, -12) if map_id == "pipeline" else Vector3(22, 0.2, -8)
		_spawn_face(world, "pale", bloom_pos)
	_spawn_occupants(world, map_id)
	if map_id == "pipeline":
		_spawn_face(world, "wren", Vector3(10, 8.45, 0))
		var nine := _spawn_face(world, "ash_nine", Vector3(-8, 0.2, 7.4))
		_nameplate(nine, "ASH-NINE — husk ankle", Vector3(0, 2.4, 0), Color(0.9, 0.3, 0.2))
		return
	if RunState.raid_mode == "late_drop":
		_spawn_face(world, "jex", Vector3(-22, 0.2, -6))
		return
	if RunState.raid_mode == "scav_wave":
		_spawn_face(world, "jex", Vector3(-20, 0.2, -4))
		_spawn_face(world, "ash_nine", Vector3(10, 0.2, 14))
		return
	_spawn_face(world, "pell", Vector3(-8, 0.2, -18))
	_spawn_face(world, "", Vector3(14, 0.2, 8))
	world.get_tree().create_timer(48.0).timeout.connect(func() -> void:
		if not is_instance_valid(world) or not RunState.in_raid:
			return
		_spawn_face(world, "jex", Vector3(-24, 0.2, 8))
		Hud.show_banner(WorldLore.face_radio("jex"))
	)


static func _spawn_occupants(world: Node3D, map_id: String) -> void:
	if map_id == "pipeline":
		spawn_pale(world, Vector3(16, 0.2, -14))
		spawn_pale(world, Vector3(-18, 0.2, 16))
		spawn_husk(world, Vector3(8, 0.2, -12))
	else:
		spawn_pale(world, Vector3(28, 0.2, -16))
		spawn_pale(world, Vector3(-30, 0.2, -20))
		spawn_pale(world, Vector3(12, 0.2, 30))
		spawn_husk(world, Vector3(-16, 0.2, 18))
	if RunState.raid_mode == "scav_wave":
		spawn_pale(world, Vector3(-8, 0.2, 24))
		spawn_husk(world, Vector3(18, 0.2, -6))
		spawn_husk(world, Vector3(-26, 0.2, 6))


static func spawn_pale(world: Node3D, pos: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	var alien: Node3D = PALE_SCENE.instantiate()
	alien.position = pos
	alien.set("home", pos)
	world.add_child(alien)


static func spawn_husk(world: Node3D, pos: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	var husk: Node3D = HUSK_SCENE.instantiate()
	husk.position = pos
	husk.set("home", pos)
	world.add_child(husk)


static func _spawn_face(world: Node3D, id: String, pos: Vector3) -> Node3D:
	var ai: Node3D = AI_SCENE.instantiate()
	ai.position = pos
	ai.set("face_id", id)
	ai.set("home", pos)
	world.add_child(ai)
	return ai


static func _spawn_dais(world: Node3D, pos: Vector3) -> void:
	var dais: Node3D = (load("res://world/shard_dais.gd") as GDScript).new()
	dais.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 1.1, 2.2)
	box.material = Greybox.mat(Color(0.22, 0.24, 0.2), 0.4)
	mesh.mesh = box
	mesh.position.y = 0.55
	dais.add_child(mesh)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.2, 1.1, 2.2)
	col.shape = sh
	col.position.y = 0.55
	dais.add_child(col)
	var glow := MeshInstance3D.new()
	var core := BoxMesh.new()
	core.size = Vector3(0.45, 0.45, 0.45)
	core.material = Greybox.mat(Color(0.4, 1.0, 0.4), 2.2)
	glow.mesh = core
	glow.name = "ShardGlow"
	glow.position = Vector3(0, 1.25, 0)
	dais.add_child(glow)
	world.add_child(dais)
	_nameplate(dais, "PUMP HOUSE 3 — shard socket", Vector3(0, 2.4, 0), Color(0.45, 1.0, 0.4))


static func occupation_answer(world: Node3D, pos: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	Hud.set_sensors(WorldLore.first_voice_hack())
	var tree := world.get_tree()
	if tree:
		tree.call_group("yard_band", "push", WorldLore.choir_band())
		tree.call_group("heavy_mech", "alert_to", pos)
		tree.call_group("ai_scavenger", "alert_to", pos)
	if world.has_meta("choir_answered"):
		return
	world.set_meta("choir_answered", true)
	Hud.show_banner(WorldLore.choir_answer_banner())
	Fx.play("alarm")
	spawn_husk(world, pos + Vector3(7.2, 0.2, -3.4))
	spawn_pale(world, pos + Vector3(-6.4, 0.2, 5.0))
	if tree:
		tree.call_group("pale_host", "alert_to", pos)


static func _nameplate(host: Node, text: String, offset: Vector3, color: Color) -> void:
	if host == null:
		return
	var lab := Label3D.new()
	lab.text = text
	lab.position = offset
	lab.font_size = 48
	lab.modulate = color
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	host.add_child(lab)
