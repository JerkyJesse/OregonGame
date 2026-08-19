extends Node3D

const WRECK_SCENE := preload("res://world/wreck.tscn")
const LIGHT_SCENE := preload("res://actors/light_mech.tscn")
const MEDIUM_SCENE := preload("res://actors/medium_mech.tscn")
const HEAVY_SCENE := preload("res://actors/heavy_mech.tscn")
const HAULER_SCENE := preload("res://actors/hauler.tscn")
const SCAV_SCENE := preload("res://actors/scavenger.tscn")
const LOOT_SCENE := preload("res://actors/loot_drop.tscn")
const EXTRACT_SCENE := preload("res://world/extract_zone.tscn")
const AI_SCENE := preload("res://actors/ai_scavenger.tscn")


func _ready() -> void:
	RunState.begin_raid()
	Hud.reset_for_scene()
	var obj := "ASH YARD 7  — strip the dead medium, bolt a gun onto a light, extract. Heavies crush scavs. First-person cockpits."
	if RunState.raid_mode == "scav_wave":
		obj = "SCAV WAVE — wrecks everywhere. Rival scavs. Storm closing."
	elif RunState.raid_mode == "late_drop":
		obj = "LATE DROP — battlefield already hot. Grab and go."
	Hud.set_objective(obj)
	Hud.set_health(RunState.health)
	Hud.refresh_carry()
	if has_node("WorldEnvironment"):
		($WorldEnvironment as WorldEnvironment).environment = Greybox.industrial_env(Color(0.42, 0.32, 0.2), 0.007)
	if has_node("Cover"):
		Greybox.build_raid_cover($Cover)
	_setup_existing()
	_spawn_medium_wreck()
	_spawn_extracts()
	_spawn_events()
	_deploy_player()
	_net_spawns()
	if NetSession.is_online() and NetSession.is_host():
		multiplayer.peer_connected.connect(_on_peer_in)


func _on_peer_in(id: int) -> void:
	var extra: Node3D = SCAV_SCENE.instantiate()
	extra.set("peer_id", id)
	extra.position = Vector3(-28, 0.2, 8 + float(id % 5))
	add_child(extra, true)
	Hud.show_banner("Scavenger dropped in (peer %d)." % id)


func _setup_existing() -> void:
	if has_node("LightMech"):
		$LightMech.hangar_preview = false
		$LightMech.disabled = false
	if has_node("HeavyMech"):
		var points: Array[Vector3] = [$PatrolA.global_position, $PatrolB.global_position]
		$HeavyMech.set_patrol(points)
		$HeavyMech.ai_controlled = RunState.deploy_scale != "heavy"
		$HeavyMech.died.connect(_on_machine_died)
		$HeavyMech.component_dropped.connect(spawn_loot)
		_attach_climb($HeavyMech)
		_attach_core($HeavyMech)
	if has_node("Wreck"):
		$Wreck.extra_ids = PackedStringArray(["cooler_pack", "sensor_suite"])


func _spawn_medium_wreck() -> void:
	var med: Node3D = MEDIUM_SCENE.instantiate()
	med.position = Vector3(-12, 0, -6)
	med.set("hangar_preview", false)
	add_child(med)
	med.call("seed_wreck_parts", ["vulcan_chest", "pulse_cannon", "armor_plate", "reactor_core", "data_core"])
	med.set("disabled", true)
	med.set("alive", false)
	med.set("hull", 0.0)
	if med.has_signal("component_dropped"):
		med.connect("component_dropped", spawn_loot)
	_attach_core(med)
	if RunState.raid_mode == "scav_wave":
		var m2: Node3D = MEDIUM_SCENE.instantiate()
		m2.position = Vector3(12, 0, 16)
		add_child(m2)
		m2.call("seed_wreck_parts", ["missile_pod", "heavy_plating", "knee_vulcan"])


func _spawn_extracts() -> void:
	if has_node("ExtractZone"):
		$ExtractZone.extract_type = "contested"
		$ExtractZone.position = Vector3(38, 0, 2)
	var stealth: Node3D = EXTRACT_SCENE.instantiate()
	stealth.position = Vector3(-40, 0, 18)
	add_child(stealth)
	stealth.set("extract_type", "stealth")
	stealth.call("_paint")
	var payload: Node3D = EXTRACT_SCENE.instantiate()
	payload.position = Vector3(0, 0, -36)
	add_child(payload)
	payload.set("extract_type", "payload")
	payload.call("_paint")
	var veh: Node3D = EXTRACT_SCENE.instantiate()
	veh.position = Vector3(32, 0, -22)
	add_child(veh)
	veh.set("extract_type", "vehicle")
	veh.call("_paint")


func _spawn_events() -> void:
	var storm: Node3D = (load("res://world/toxic_storm.gd") as GDScript).new()
	add_child(storm)
	_breakable(Vector3(-20, 1, 2), Vector3(3, 2, 1.2))
	_breakable(Vector3(4, 1, 10), Vector3(2.4, 2.2, 2.4))
	_breakable(Vector3(-6, 1, -10), Vector3(4, 1.6, 1))
	if RunState.raid_mode != "combat" or RunState.faction == "scav":
		for i in 3:
			var ai := AI_SCENE.instantiate()
			ai.position = Vector3(-18 + i * 4, 0.2, 14)
			add_child(ai)
	if RunState.raid_mode == "combat":
		var extra: Node3D = HEAVY_SCENE.instantiate()
		extra.position = Vector3(-30, 0, -24)
		add_child(extra)
		extra.set("ai_controlled", true)
		extra.set("patrol", [Vector3(-30, 0, -24), Vector3(-10, 0, 20)])
		get_tree().create_timer(90.0).timeout.connect(func() -> void:
			Hud.show_banner("Incoming heavy reinforcement.")
			Fx.play("alarm")
		)


func _breakable(pos: Vector3, size: Vector3) -> void:
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
	add_child(b)


func _attach_climb(heavy: Node3D) -> void:
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


func _attach_core(machine: Node3D) -> void:
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
	p.position = Vector3(0, 2.2 if str(machine.name).begins_with("Medium") else 6.0, 1.6)


func _deploy_player() -> void:
	var scav: Scavenger = $Scavenger if has_node("Scavenger") else null
	if scav == null:
		return
	match RunState.faction:
		"corporate":
			scav.position = Vector3(30, 0.1, -8)
		"remnant":
			scav.position = Vector3(-30, 0.1, -16)
		"warlord":
			scav.position = Vector3(16, 0.1, 28)
		_:
			scav.position = Vector3(-32, 0.1, 10)
	if RunState.deploy_scale == "light" or RunState.deploy_scale == "armor":
		if has_node("LightMech"):
			$LightMech.power_armor = RunState.deploy_scale == "armor"
			$LightMech.board_pilot(scav)
	elif RunState.deploy_scale == "medium":
		var med: Node3D = MEDIUM_SCENE.instantiate()
		med.position = scav.position + Vector3(4, 0, 0)
		add_child(med)
		med.call("board_pilot", scav)
	elif RunState.deploy_scale == "heavy":
		if has_node("HeavyMech"):
			$HeavyMech.set("ai_controlled", false)
			$HeavyMech.set("disabled", false)
			$HeavyMech.call("board_pilot", scav)
	elif RunState.deploy_scale == "vehicle":
		var h: Node3D = HAULER_SCENE.instantiate()
		h.position = scav.position + Vector3(5, 0, 0)
		add_child(h)
		h.call("board_pilot", scav)


func _net_spawns() -> void:
	if not NetSession.is_online() or NetSession.is_host():
		return
	# Clients already load the raid; extra scavengers for peers are host-authored in a full lobby.
	pass


func _on_machine_died(pos: Vector3) -> void:
	var wreck := WRECK_SCENE.instantiate()
	wreck.part_id = "reactor_core"
	wreck.extra_ids = PackedStringArray(["heavy_plating", "missile_pod"])
	add_child(wreck)
	wreck.global_position = Vector3(pos.x, 0.0, pos.z)
	Hud.show_banner("Machine down — strip it.")
	RunState.heavy_engaged = true


func spawn_loot(part: Dictionary, pos: Vector3) -> void:
	if part.is_empty():
		return
	var drop: Node3D = LOOT_SCENE.instantiate()
	drop.set("part", part)
	add_child(drop)
	drop.global_position = pos + Vector3(0, 0.6, 0)
