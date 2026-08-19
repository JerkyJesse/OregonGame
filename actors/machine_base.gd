class_name MachineBase
extends CharacterBody3D

signal died(world_pos: Vector3)
signal component_dropped(part: Dictionary, world_pos: Vector3)

const TURN_SENS := 0.0021
const HEAT_MAX := 100.0

@export var scale_id: String = "light"
@export var hangar_preview: bool = false
@export var power_armor: bool = false
@export var ai_controlled: bool = false
@export var disabled: bool = false
@export var cockpit_height: float = 6.4
@export var cockpit_forward: float = 0.55
@export var move_speed: float = 9.0
@export var hull_max: float = 160.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var boarded: bool = false
var hull: float = 160.0
var heat: float = 0.0
var _pilot: Node
var _pitch: float = 0.0
var _fire_cd: float = 0.0
var _hotwire: float = 0.0
var _hack: float = 0.0
var _pry: float = 0.0
var patrol: Array[Vector3] = []
var _patrol_i: int = 0
var equipped: Dictionary = {}
var section_hp: Dictionary = {}
var alive: bool = true
var towing: Node3D
var _ai_fire: float = 0.0

var _camera: Camera3D
var _ray: RayCast3D
var _dismount: Marker3D
var _cockpit: Node3D


func _ready() -> void:
	add_to_group("machine")
	add_to_group("%s_mech" % scale_id)
	if power_armor:
		add_to_group("power_armor")
	collision_layer = 4
	collision_mask = 5
	hull = hull_max
	_ensure_cockpit()
	_ensure_hardpoints()
	_init_sections()
	_copy_hangar_loadout()
	apply_loadout()
	if _camera:
		_camera.current = false
	set_notify_transform(true)


func _ensure_cockpit() -> void:
	_cockpit = get_node_or_null("Cockpit")
	if _cockpit == null:
		_cockpit = Node3D.new()
		_cockpit.name = "Cockpit"
		add_child(_cockpit)
	_cockpit.position = Vector3(0.0, cockpit_height, cockpit_forward)
	_camera = get_node_or_null("Cockpit/CockpitCamera") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "CockpitCamera"
		_cockpit.add_child(_camera)
		_camera.fov = 72.0
		_camera.near = 0.08
	_camera.current = false
	_ray = get_node_or_null("Cockpit/CockpitCamera/InteractRay") as RayCast3D
	if _ray == null:
		_ray = RayCast3D.new()
		_ray.name = "InteractRay"
		_camera.add_child(_ray)
		_ray.target_position = Vector3(0, 0, -14.0)
		_ray.collision_mask = 13
		_ray.collide_with_areas = true
	_dismount = get_node_or_null("DismountPoint") as Marker3D
	if _dismount == null:
		_dismount = Marker3D.new()
		_dismount.name = "DismountPoint"
		add_child(_dismount)
		_dismount.position = Vector3(3.4, 0.1, 0.0)


func _ensure_hardpoints() -> void:
	var root := get_node_or_null("Hardpoints")
	if root == null:
		root = Node3D.new()
		root.name = "Hardpoints"
		add_child(root)
	var offsets := {
		"chest": Vector3(0, cockpit_height * 0.85, 1.2),
		"arm_l": Vector3(-2.2, cockpit_height * 0.82, 0.2),
		"arm_r": Vector3(2.2, cockpit_height * 0.82, 0.2),
		"legs": Vector3(0, cockpit_height * 0.32, 0.7),
		"reactor": Vector3(0, cockpit_height * 0.82, -1.3),
		"sensors": Vector3(0, cockpit_height * 1.08, 0.6),
		"utility": Vector3(0, cockpit_height * 0.55, -0.8),
	}
	for slot in RunState.SLOTS:
		if root.get_node_or_null(slot) == null:
			var mi := MeshInstance3D.new()
			mi.name = slot
			var box := BoxMesh.new()
			box.size = Vector3(0.7, 0.45, 0.45)
			mi.mesh = box
			mi.position = offsets.get(slot, Vector3.ZERO)
			root.add_child(mi)
		var spot_name := "Slot_%s" % slot
		if get_node_or_null(spot_name) == null:
			var spot: Area3D = load("res://actors/slot_hotspot.gd").new()
			spot.name = spot_name
			spot.set("slot", slot)
			var col := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(1.6, 1.1, 1.1)
			col.shape = sh
			spot.add_child(col)
			add_child(spot)
			spot.position = offsets.get(slot, Vector3.ZERO)


func _init_sections() -> void:
	section_hp = {
		"chest": 100.0,
		"arm_l": 70.0,
		"arm_r": 70.0,
		"legs": 90.0,
		"reactor": 80.0,
		"sensors": 50.0,
		"utility": 60.0,
	}


func _copy_hangar_loadout() -> void:
	equipped.clear()
	if hangar_preview or (not disabled and not ai_controlled):
		var pack: Variant = RunState.loadouts.get(scale_id, {})
		if pack is Dictionary:
			equipped = (pack as Dictionary).duplicate(true)
	for slot in RunState.SLOTS:
		if not equipped.has(slot):
			equipped[slot] = {}


func seed_wreck_parts(ids: Array) -> void:
	equipped.clear()
	for slot in RunState.SLOTS:
		equipped[slot] = {}
	for id in ids:
		var part: Dictionary = RunState.make_part(str(id), randf_range(0.4, 0.88))
		if part.is_empty():
			continue
		var slot := str(part.get("slot", "chest"))
		equipped[slot] = part
	disabled = true
	ai_controlled = false
	apply_loadout()


func apply_loadout() -> void:
	if equipped.is_empty():
		_copy_hangar_loadout()
	var paint := RunState.paint_color()
	for slot in RunState.SLOTS:
		var node := get_node_or_null("Hardpoints/" + slot)
		if node == null or not node is MeshInstance3D:
			continue
		var mesh := node as MeshInstance3D
		var part: Variant = equipped.get(slot, {})
		var broken := float(section_hp.get(slot, 100.0)) <= 0.0
		if broken:
			mesh.visible = false
			continue
		if part is Dictionary and not (part as Dictionary).is_empty():
			mesh.visible = true
			var c: Array = part.get("albedo", [0.8, 0.3, 0.1])
			_tint(mesh, Color(float(c[0]), float(c[1]), float(c[2])), false)
		else:
			mesh.visible = hangar_preview
			if hangar_preview:
				_tint(mesh, Color(0.25, 0.85, 1.0, 0.4), true)
	for child in get_children():
		if child is MeshInstance3D and str(child.name) in ["Torso", "Head", "ArmL", "ArmR", "LegL", "LegR", "Cab"]:
			if hangar_preview or boarded or not disabled:
				_tint(child, paint.darkened(0.08), false)
	_configure_hotspots()


func _tint(mesh: MeshInstance3D, color: Color, translucent: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if translucent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.4
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.45, 0.55)
		mat.emission_energy_multiplier = 0.8
	else:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.22
	mesh.material_override = mat


func _configure_hotspots() -> void:
	for child in get_children():
		if child.has_method("configure"):
			child.configure(hangar_preview, disabled or hangar_preview or boarded)


func get_interact_label() -> String:
	if hangar_preview:
		return "Workshop  %s  [E]" % scale_id.to_upper()
	if boarded:
		return ""
	if disabled:
		return "Disabled %s  [E] strip / field-bolt   [G] hotwire" % scale_id
	if not boarded:
		return "Board %s cockpit  [E] / [F]" % scale_id
	return ""


func interact(actor: Node) -> void:
	if hangar_preview:
		Hud.open_workshop(scale_id)
		return
	if actor is Scavenger:
		if disabled:
			Hud.show_banner("Look at a glowing hardpoint to strip or bolt.  [G] hotwire.")
			return
		board_pilot(actor)


func board_pilot(scav: Node) -> void:
	if hangar_preview or boarded or scav == null:
		return
	if scav is Scavenger and (scav as Scavenger).boarded:
		return
	if disabled:
		return
	boarded = true
	ai_controlled = false
	_pilot = scav
	if scav is Scavenger:
		(scav as Scavenger).set_boarded(true)
	add_to_group("player")
	if _camera:
		_camera.current = true
	Hud.set_prompt("COCKPIT  LMB fire   [F] dismount   WASD   mouse look")
	Fx.play("ui")


func begin_hotwire(scav: Node) -> void:
	if not disabled or boarded:
		return
	_hotwire += 0.34 + RunState.repair_skill * 0.2
	Fx.play("hack")
	Hud.set_extract(_hotwire)
	Hud.set_prompt("Hotwiring…  %.0f%%" % (_hotwire * 100.0))
	if _hotwire >= 1.0:
		_hotwire = 0.0
		Hud.set_extract(-1.0)
		if randf() <= RunState.hotwire_chance():
			disabled = false
			alive = true
			hull = maxf(hull, hull_max * 0.35)
			RunState.repair_skill = clampf(RunState.repair_skill + 0.02, 0.1, 0.95)
			Hud.show_banner("Hotwire good — cockpit yours.")
			board_pilot(scav)
		else:
			Hud.show_banner("Hotwire fail — systems scream.")
			Fx.play("alarm")
			heat = minf(heat + 40.0, HEAT_MAX)
			get_tree().call_group("heavy_mech", "alert_to", global_position)


func dismount() -> void:
	if not boarded:
		return
	boarded = false
	if _camera:
		_camera.current = false
	remove_from_group("player")
	if _pilot and _pilot is Scavenger:
		var scav := _pilot as Scavenger
		scav.global_transform = _dismount.global_transform
		scav.look_pitch = 0.0
		scav.set_boarded(false)
	_pilot = null
	Hud.set_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if not boarded or Hud.ui_busy:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * TURN_SENS * (0.55 if scale_id == "heavy" else 1.0))
		_pitch = clampf(_pitch - event.relative.y * TURN_SENS, deg_to_rad(-70.0), deg_to_rad(55.0))
		if _camera:
			_camera.rotation.x = _pitch
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	heat = maxf(heat - _cool_rate() * delta, 0.0)
	if hangar_preview:
		velocity = Vector3.ZERO
		return
	if boarded:
		_pilot_move(delta)
		return
	if ai_controlled:
		_ai_move(delta)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	velocity.z = move_toward(velocity.z, 0.0, move_speed)
	move_and_slide()


func _pilot_move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var jets := _has_jets() and Input.is_action_pressed("jump") and heat < 90.0
	if jets:
		velocity.y = 7.5 if scale_id != "heavy" else 4.2
		heat += 18.0 * delta
	var input_dir := Vector2.ZERO
	if not Hud.ui_busy:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := _current_speed()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	move_and_slide()
	if towing and is_instance_valid(towing):
		towing.global_position = global_position + -transform.basis.z * -8.0 + Vector3(0, 0.4, 0)
	var in_extract := _inside_extract()
	if Input.is_action_just_pressed("board") or (Input.is_action_just_pressed("interact") and not in_extract):
		dismount()
		return
	if Input.is_action_pressed("fire") and not Hud.ui_busy:
		_try_fire()
	if scale_id == "vehicle" and Input.is_action_just_pressed("hotwire"):
		_try_tow()
	_update_cockpit_hud()


func _current_speed() -> float:
	var w := RunState.loadout_weight(scale_id, equipped)
	var cap := RunState.cap(scale_id, "weight")
	var over := w > cap
	var legs_ok := float(section_hp.get("legs", 100.0)) > 0.0
	var mul := 0.55 if over else 1.0
	if not legs_ok:
		mul *= 0.45
	if power_armor:
		mul *= 1.12
	return move_speed * mul * RunState.cap(scale_id, "speed")


func _cool_rate() -> float:
	var rate := 18.0
	var util: Variant = equipped.get("utility", {})
	if util is Dictionary and str(util.get("id", "")) == "cooler_pack":
		rate += 22.0 * float(util.get("condition", 1.0))
	return rate


func _has_jets() -> bool:
	var util: Variant = equipped.get("utility", {})
	return util is Dictionary and str(util.get("id", "")) == "jump_jets" and float(section_hp.get("utility", 1.0)) > 0.0


func _power_ok(part: Dictionary) -> bool:
	var draw := float(part.get("power_draw", 0.0))
	var supply := 8.0
	var reac: Variant = equipped.get("reactor", {})
	if reac is Dictionary:
		supply += float(reac.get("power_output", 0.0)) * float(reac.get("condition", 1.0))
	if float(section_hp.get("reactor", 1.0)) <= 0.0:
		supply *= 0.2
	return supply + 0.01 >= draw


func _try_fire() -> void:
	if _fire_cd > 0.0:
		return
	if heat >= 96.0:
		Hud.show_banner("Heat lock.")
		_fire_cd = 0.35
		return
	var weapon := RunState.best_weapon(scale_id, equipped)
	if weapon.is_empty() or float(section_hp.get(str(weapon.get("slot", "chest")), 1.0)) <= 0.0:
		Hud.show_banner("No weapon bolted on.")
		_fire_cd = 0.5
		return
	if not _power_ok(weapon):
		Hud.show_banner("Reactor starved.")
		_fire_cd = 0.5
		return
	var kind := str(weapon.get("weapon_kind", "ballistic"))
	_fire_cd = 0.09 if kind == "ballistic" else (0.55 if kind == "missile" else (0.22 if kind == "energy" else 0.4))
	heat += float(weapon.get("heat_gen", 8.0))
	var dmg := float(weapon.get("damage", 24.0)) * lerpf(0.4, 1.0, float(weapon.get("condition", 1.0)))
	if kind == "melee":
		dmg *= 1.6
	Fx.play(kind if kind != "ballistic" else "vulcan")
	var from := _camera.global_position
	var reach := 18.0 if kind == "melee" else 140.0
	var to := from + (-_camera.global_transform.basis.z) * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 7
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	if hit:
		end = hit.position
		var col: Object = hit.collider
		if col is Node:
			_apply_hit(col as Node, dmg, hit.position)
	Fx.spawn_tracer(from + (-_camera.global_transform.basis.z) * 1.4, end, _tracer_color(kind))
	if not NetSession.is_host():
		_rpc_shot.rpc_id(1, from, end, dmg, kind)


func _tracer_color(kind: String) -> Color:
	match kind:
		"energy":
			return Color(0.3, 0.85, 1.0)
		"missile":
			return Color(1.0, 0.35, 0.12)
		"melee":
			return Color(0.9, 0.9, 0.7)
		_:
			return Color(1.0, 0.72, 0.18)


func _apply_hit(node: Node, dmg: float, point: Vector3) -> void:
	var cur := node
	while cur:
		if cur.has_method("take_damage"):
			if cur.has_method("take_section_damage"):
				cur.call("take_section_damage", dmg, point)
			else:
				cur.call("take_damage", dmg)
			return
		cur = cur.get_parent()


@rpc("any_peer", "reliable")
func _rpc_shot(from: Vector3, to: Vector3, dmg: float, kind: String) -> void:
	if not NetSession.is_host():
		return
	if dmg < 0.0 or dmg > 400.0:
		return
	Fx.spawn_tracer(from, to, _tracer_color(kind))


func take_section_damage(amount: float, point: Vector3) -> void:
	if not alive:
		return
	var local := to_local(point)
	var slot := "chest"
	if local.y < cockpit_height * 0.45:
		slot = "legs"
	elif local.x < -0.9:
		slot = "arm_l"
	elif local.x > 0.9:
		slot = "arm_r"
	elif local.z < -0.6:
		slot = "reactor"
	elif local.y > cockpit_height * 0.92:
		slot = "sensors"
	section_hp[slot] = float(section_hp.get(slot, 100.0)) - amount * 0.65
	take_damage(amount * 0.55)
	if float(section_hp[slot]) <= 0.0:
		_break_section(slot)


func _break_section(slot: String) -> void:
	section_hp[slot] = 0.0
	var part: Variant = equipped.get(slot, {})
	if part is Dictionary and not (part as Dictionary).is_empty():
		var drop: Dictionary = (part as Dictionary).duplicate(true)
		drop["condition"] = clampf(float(drop.get("condition", 1.0)) * randf_range(0.35, 0.7), 0.08, 0.8)
		equipped[slot] = {}
		component_dropped.emit(drop, global_position + Vector3(randf_range(-2, 2), 1.2, randf_range(-2, 2)))
		Hud.show_banner("%s torn off." % drop.get("display_name", slot))
	apply_loadout()


func take_damage(amount: float) -> void:
	if not alive or hangar_preview:
		return
	hull -= amount
	if boarded:
		Hud.set_health(hull)
		Hud.show_banner("%s hull  %d" % [scale_id.to_upper(), maxi(int(hull), 0)])
	if hull <= 0.0:
		_die()


func _die() -> void:
	alive = false
	disabled = true
	ai_controlled = false
	var ours := boarded and RunState.deploy_scale == scale_id
	if boarded:
		dismount()
	var pos := global_position
	for slot in RunState.SLOTS:
		if float(section_hp.get(slot, 0.0)) > 0.0:
			_break_section(slot)
	died.emit(pos)
	if scale_id == "heavy" or scale_id == "medium":
		Fx.play("stomp")
	if ours:
		RunState.fail_raid("Your %s went down." % scale_id, scale_id == "heavy")
		return
	apply_loadout()


func _ai_move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var target := _ai_target()
	if patrol.size() >= 2 and (target == Vector3.ZERO or global_position.distance_to(target) > 48.0):
		var p: Vector3 = patrol[_patrol_i]
		var offset := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
		if offset.length() < 3.0:
			_patrol_i = (_patrol_i + 1) % patrol.size()
		else:
			_look_flat(offset)
			velocity.x = offset.normalized().x * move_speed
			velocity.z = offset.normalized().z * move_speed
	elif target != Vector3.ZERO:
		var offset := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		if offset.length() > 6.0:
			_look_flat(offset)
			velocity.x = offset.normalized().x * move_speed
			velocity.z = offset.normalized().z * move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		_ai_fire -= delta
		if _ai_fire <= 0.0 and offset.length() < 55.0:
			_ai_fire = 0.35
			_ai_shoot(target)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _look_flat(offset: Vector3) -> void:
	if offset.length() < 0.1:
		return
	look_at(global_position + offset.normalized(), Vector3.UP)
	rotation.x = 0.0
	rotation.z = 0.0


func _ai_target() -> Vector3:
	var best := Vector3.ZERO
	var best_d := 9999.0
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node3D and n != self:
			var d := global_position.distance_to((n as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = (n as Node3D).global_position
	return best


func _ai_shoot(target: Vector3) -> void:
	var from := global_position + Vector3(0, cockpit_height, 0)
	var to := target + Vector3(0, 1.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 7
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	Fx.play("vulcan")
	var end := to
	if hit:
		end = hit.position
		var col: Object = hit.collider
		if col is Node:
			_apply_hit(col as Node, 18.0 if scale_id != "heavy" else 34.0, hit.position)
	Fx.spawn_tracer(from, end, Color(1.0, 0.45, 0.12))


func alert_to(pos: Vector3) -> void:
	if patrol.size() < 2:
		patrol = [pos, global_position] as Array[Vector3]
	else:
		patrol[_patrol_i] = pos
	RunState.heavy_engaged = true


func _try_tow() -> void:
	if towing:
		towing = null
		Hud.show_banner("Tow released.")
		return
	for n in get_tree().get_nodes_in_group("machine"):
		if n == self or not n.is_in_group("machine"):
			continue
		var m := n as Node3D
		if m.get("disabled") and global_position.distance_to(m.global_position) < 12.0:
			towing = m
			Hud.show_banner("Towing wreck.")
			return


func _inside_extract() -> bool:
	for zone in get_tree().get_nodes_in_group("extract_zone"):
		if zone is Area3D and (zone as Area3D).overlaps_body(self):
			return true
	return false


func _update_cockpit_hud() -> void:
	var w := RunState.loadout_weight(scale_id, equipped)
	Hud.set_heat(heat / HEAT_MAX)
	Hud.set_health(hull)
	var weapon := RunState.best_weapon(scale_id, equipped)
	var wname := "NO GUN" if weapon.is_empty() else str(weapon.get("display_name", "GUN"))
	Hud.set_prompt("%s  %s   HEAT %.0f  WT %.0f   [F] dismount" % [scale_id.to_upper(), wname, heat, w])


func field_install(part: Dictionary) -> bool:
	if part.is_empty():
		return false
	var slot := str(part.get("slot", ""))
	if slot == "" or not RunState.scale_ok(part, scale_id):
		return false
	if float(section_hp.get(slot, 0.0)) <= 0.0:
		return false
	var current: Variant = equipped.get(slot, {})
	if current is Dictionary and not (current as Dictionary).is_empty():
		if not RunState.add_carry(current):
			return false
	equipped[slot] = part
	apply_loadout()
	Fx.play("ui")
	return true


func field_strip(slot: String) -> Dictionary:
	var part: Variant = equipped.get(slot, {})
	if part is Dictionary and not (part as Dictionary).is_empty():
		var taken: Dictionary = part
		equipped[slot] = {}
		apply_loadout()
		return taken
	return {}


func has_payload() -> bool:
	for slot in RunState.SLOTS:
		var part: Variant = equipped.get(slot, {})
		if part is Dictionary and bool(part.get("is_payload", false)):
			return true
	for p in RunState.raid_carry:
		if bool(p.get("is_payload", false)):
			return true
	return false
