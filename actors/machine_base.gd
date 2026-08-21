class_name MachineBase
extends CharacterBody3D

const LOOK := preload("res://world/WorldLook.gd")

signal died(world_pos: Vector3)
signal component_dropped(part: Dictionary, world_pos: Vector3)

const TURN_SENS := 0.0021
const HEAT_MAX := 100.0
const SELF_VISUAL_LAYER := 10

@export var scale_id: String = "light"
@export var hangar_preview: bool = false
@export var power_armor: bool = false
@export var ai_controlled: bool = false
@export var disabled: bool = false
@export var cockpit_height: float = 7.4
@export var cockpit_forward: float = 1.6
@export var move_speed: float = 9.0
@export var hull_max: float = 160.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var boarded: bool = false
var hull: float = 160.0
var heat: float = 0.0
var shield_hp: float = 0.0
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
var _alert_pos: Vector3 = Vector3.ZERO
var _alert_timer: float = 0.0
var _coat_radioed: bool = false
var core_taken: bool = false
var _base_hull: float = 160.0
var _section_max: Dictionary = {}
var _broken: Dictionary = {}
var _crit_fx: Dictionary = {}

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
	collision_mask = 7
	_base_hull = hull_max
	hull = hull_max
	_ensure_cockpit()
	_ensure_hardpoints()
	_init_sections()
	_copy_hangar_loadout()
	apply_loadout()
	if _camera:
		_camera.current = false
	set_notify_transform(true)


func _exit_tree() -> void:
	set_physics_process(false)
	set_process(false)


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
	_camera.near = 0.05
	_camera.current = false
	_camera.cull_mask = 1048575 & ~(1 << (SELF_VISUAL_LAYER - 1))
	LOOK.tune_camera(_camera)
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
		"chest": Vector3(0, cockpit_height * 0.75, 1.2),
		"arm_l": Vector3(-2.2, cockpit_height * 0.72, 0.2),
		"arm_r": Vector3(2.2, cockpit_height * 0.72, 0.2),
		"legs": Vector3(0, cockpit_height * 0.28, 0.7),
		"reactor": Vector3(0, cockpit_height * 0.72, -1.3),
		"sensors": Vector3(0, cockpit_height * 0.95, 0.6),
		"utility": Vector3(0, cockpit_height * 0.48, -0.8),
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
		_ensure_slot_hotspot(slot, offsets.get(slot, Vector3.ZERO))


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
	_section_max = section_hp.duplicate()
	_broken.clear()


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
		var current: Variant = equipped.get(slot, {})
		if current is Dictionary and not (current as Dictionary).is_empty():
			continue
		equipped[slot] = part
	disabled = true
	ai_controlled = false
	alive = false
	apply_loadout()


func _ensure_slot_hotspot(slot: String, pos: Vector3) -> void:
	for n in get_children():
		if n is SlotHotspot and str(n.get("slot")) == slot:
			return
	var spot := Area3D.new()
	spot.name = "Slot_%s" % slot
	spot.set_script(load("res://actors/slot_hotspot.gd"))
	spot.set("slot", slot)
	add_child(spot)
	spot.position = pos
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	var span := clampf(cockpit_height * 0.28, 1.3, 5.2)
	sh.size = Vector3(span, span * 0.7, span)
	col.shape = sh
	spot.add_child(col)


func apply_loadout() -> void:
	if equipped.is_empty():
		_copy_hangar_loadout()
	hull_max = _base_hull + _plating_bonus()
	if hangar_preview:
		hull = hull_max
	else:
		hull = minf(hull, hull_max)
	var sm := _shield_max()
	if shield_hp <= 0.0 or shield_hp > sm:
		shield_hp = sm
	var paint := RunState.paint_color()
	for slot in RunState.SLOTS:
		var part: Variant = equipped.get(slot, {})
		var broken := float(section_hp.get(slot, 100.0)) <= 0.0
		var filled := part is Dictionary and not (part as Dictionary).is_empty()
		_rebuild_kit(slot, part if filled else {}, broken)
	for child in get_children():
		if child is MeshInstance3D and str(child.name) in ["Torso", "Head", "ArmL", "ArmR", "LegL", "LegR", "Cab", "Bed"]:
			if hangar_preview or boarded or not disabled:
				_tint(child, paint.darkened(0.08), false)
		if child.name == "Visor":
			_tint(child, Color(1.0, 0.48, 0.12), false)
		if child.name == "Body":
			for sub in child.get_children():
				if sub is MeshInstance3D and str(sub.name) in ["Torso", "Head", "ArmL", "ArmR"]:
					_tint(sub, paint.darkened(0.08), false)
				if sub is MeshInstance3D and str(sub.name) == "Visor":
					_tint(sub, Color(0.85, 0.12, 0.06), false)
	_apply_limb_visuals()


func _plating_bonus() -> float:
	var bonus := 0.0
	for slot in RunState.SLOTS:
		var part: Variant = equipped.get(slot, {})
		if part is Dictionary:
			var id := str(part.get("id", ""))
			if id == "armor_plate" or id == "heavy_plating":
				bonus += float(part.get("durability", 80.0)) * float(part.get("condition", 1.0)) * 0.45
	return bonus


func _shield_max() -> float:
	var util: Variant = equipped.get("utility", {})
	if util is Dictionary and str(util.get("id", "")) == "shield_emitter" and float(section_hp.get("utility", 1.0)) > 0.0:
		if _power_ok(util):
			return 90.0 * float(util.get("condition", 1.0))
	return 0.0


func has_sensors() -> bool:
	var s: Variant = equipped.get("sensors", {})
	if not (s is Dictionary):
		return false
	var id := str(s.get("id", ""))
	return (id == "sensor_suite" or id == "filament_veil") and float(section_hp.get("sensors", 1.0)) > 0.0


func best_weapon_name() -> String:
	var w := RunState.best_weapon(scale_id, equipped)
	if w.is_empty():
		return ""
	return str(w.get("display_name", ""))


func _tint(mesh: MeshInstance3D, color: Color, translucent: bool) -> void:
	if str(mesh.name) == "Visor":
		mesh.material_override = LOOK.visor_mat(color if translucent else Color(1.0, 0.5, 0.12))
		return
	mesh.material_override = LOOK.paint_mat(color, translucent)


func _rebuild_kit(slot: String, part: Dictionary, broken: bool) -> void:
	var root := get_node_or_null("Hardpoints")
	if root == null:
		return
	var old := root.get_node_or_null("Kit_%s" % slot)
	if old:
		old.queue_free()
	var marker := root.get_node_or_null(slot) as MeshInstance3D
	if marker:
		marker.visible = hangar_preview and part.is_empty() and not broken
		if marker.visible:
			_tint(marker, Color(0.25, 0.85, 1.0, 0.4), true)
	if broken or part.is_empty():
		return
	var kit := Node3D.new()
	kit.name = "Kit_%s" % slot
	if marker:
		kit.position = marker.position
	root.add_child(kit)
	_build_part_mesh(kit, part)


func _part_color(part: Dictionary) -> Color:
	var c: Variant = part.get("albedo", [0.8, 0.3, 0.1])
	if c is Array and (c as Array).size() >= 3:
		return Color(float(c[0]), float(c[1]), float(c[2]))
	if c is Color:
		return c
	return Color(0.8, 0.35, 0.12)


func _build_part_mesh(kit: Node3D, part: Dictionary) -> void:
	var col := _part_color(part)
	var id := str(part.get("id", ""))
	var kind := str(part.get("weapon_kind", ""))
	var mul := clampf(cockpit_height / 7.4, 0.65, 2.6)
	if bool(part.get("is_weapon", false)):
		match kind:
			"energy":
				_kit_cyl(kit, Vector3(0, 0, 0.85 * mul), 1.9 * mul, 0.13 * mul, col, Vector3(90, 0, 0), 1.8)
			"missile":
				_kit_box(kit, Vector3(0, 0, 0.45 * mul), Vector3(0.75 * mul, 0.42 * mul, 1.15 * mul), col, 0.25)
				_kit_cyl(kit, Vector3(-0.18 * mul, 0, 0.95 * mul), 0.7 * mul, 0.08 * mul, col.lightened(0.1), Vector3(90, 0, 0), 0.4)
				_kit_cyl(kit, Vector3(0.18 * mul, 0, 0.95 * mul), 0.7 * mul, 0.08 * mul, col.lightened(0.1), Vector3(90, 0, 0), 0.4)
			"melee":
				_kit_box(kit, Vector3(0, 0, 1.15 * mul), Vector3(0.16 * mul, 0.16 * mul, 2.5 * mul), col, 0.9)
			_:
				_kit_box(kit, Vector3(0, 0, 1.0 * mul), Vector3(0.28 * mul, 0.28 * mul, 2.3 * mul), col, 0.45)
				_kit_box(kit, Vector3(0, 0.18 * mul, 0.15 * mul), Vector3(0.5 * mul, 0.2 * mul, 0.7 * mul), col.darkened(0.25), 0.0)
		return
	if id == "armor_plate" or id == "heavy_plating":
		_kit_box(kit, Vector3.ZERO, Vector3(1.15 * mul, 0.14 * mul, 0.85 * mul), col, 0.0)
	elif id == "reactor_core" or id == "compact_reactor":
		_kit_cyl(kit, Vector3.ZERO, 0.7 * mul, 0.28 * mul, col, Vector3.ZERO, 1.4)
	elif id == "jump_jets":
		_kit_cyl(kit, Vector3(-0.28 * mul, 0, 0), 0.6 * mul, 0.11 * mul, col, Vector3(90, 0, 0), 1.5)
		_kit_cyl(kit, Vector3(0.28 * mul, 0, 0), 0.6 * mul, 0.11 * mul, col, Vector3(90, 0, 0), 1.5)
	elif id == "shield_emitter":
		_kit_box(kit, Vector3.ZERO, Vector3(0.7 * mul, 0.7 * mul, 0.18 * mul), col, 1.6)
	elif id == "cooler_pack":
		_kit_box(kit, Vector3.ZERO, Vector3(0.55 * mul, 0.4 * mul, 0.4 * mul), col, 0.3)
	elif id == "sensor_suite" or id == "filament_veil":
		_kit_cyl(kit, Vector3(0, 0.12 * mul, 0), 0.18 * mul, 0.28 * mul, col, Vector3.ZERO, 1.1)
	else:
		_kit_box(kit, Vector3.ZERO, Vector3(0.5 * mul, 0.35 * mul, 0.45 * mul), col, 0.15)


func _kit_box(kit: Node3D, pos: Vector3, size: Vector3, color: Color, emit: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = LOOK.emit_surface(color, emit) if emit > 0.0 else LOOK.paint_mat(color)
	kit.add_child(mi)


func _kit_cyl(kit: Node3D, pos: Vector3, height: float, radius: float, color: Color, rot: Vector3, emit: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 10
	mi.mesh = cyl
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = LOOK.emit_surface(color, emit) if emit > 0.0 else LOOK.paint_mat(color)
	kit.add_child(mi)


func _apply_limb_visuals() -> void:
	var legs := float(section_hp.get("legs", 100.0)) > 0.0
	var al := float(section_hp.get("arm_l", 100.0)) > 0.0
	var ar := float(section_hp.get("arm_r", 100.0)) > 0.0
	_set_named_visible("ArmL", al)
	_set_named_visible("ArmR", ar)
	_set_named_visible("LegL", legs)
	_set_named_visible("LegR", legs)
	_scorch_named("ArmL", "arm_l")
	_scorch_named("ArmR", "arm_r")
	_scorch_named("LegL", "legs")
	_scorch_named("LegR", "legs")
	_scorch_named("Torso", "chest")
	_scorch_named("Head", "sensors")
	_scorch_named("Cab", "chest")
	_scorch_named("Bed", "utility")
	_tick_crit_fx("arm_l")
	_tick_crit_fx("arm_r")
	_tick_crit_fx("legs")
	_tick_crit_fx("chest")
	_tick_crit_fx("reactor")


func _mesh_by_name(n: String) -> MeshInstance3D:
	var node := get_node_or_null(n)
	if node is MeshInstance3D:
		return node as MeshInstance3D
	var body := get_node_or_null("Body")
	if body:
		var nested := body.get_node_or_null(n)
		if nested is MeshInstance3D:
			return nested as MeshInstance3D
	return null


func _set_named_visible(n: String, on: bool) -> void:
	var mesh := _mesh_by_name(n)
	if mesh:
		mesh.visible = on


func _scorch_named(n: String, slot: String) -> void:
	var mesh := _mesh_by_name(n)
	if mesh == null or not mesh.visible:
		return
	var hp := float(section_hp.get(slot, 100.0))
	var mx := float(_section_max.get(slot, 100.0))
	var ratio := hp / maxf(mx, 1.0)
	if ratio >= 0.55:
		return
	var paint := RunState.paint_color().darkened(0.08)
	if ratio < 0.25:
		_tint(mesh, Color(0.52, 0.1, 0.04), false)
	else:
		_tint(mesh, paint.darkened(0.28).lerp(Color(0.72, 0.22, 0.06), 0.45), false)


func _tick_crit_fx(slot: String) -> void:
	var hp := float(section_hp.get(slot, 100.0))
	var mx := float(_section_max.get(slot, 100.0))
	var ratio := hp / maxf(mx, 1.0)
	if ratio <= 0.0 or ratio > 0.28:
		if _crit_fx.has(slot) and is_instance_valid(_crit_fx[slot]):
			(_crit_fx[slot] as Node).queue_free()
		_crit_fx.erase(slot)
		return
	if _crit_fx.has(slot) and is_instance_valid(_crit_fx[slot]):
		return
	var local := to_local(slot_world_pos(slot))
	_crit_fx[slot] = LOOK.sparkle(self, local, Color(1.0, 0.32, 0.08), 0.28)


func get_interact_label() -> String:
	if hangar_preview:
		return "Workshop  %s  [E]" % scale_id.to_upper()
	if boarded:
		return ""
	if disabled or not alive:
		return "Wrecked %s  [E] strip/bolt/hack   [G] hold hotwire (hijack)" % scale_id
	return "%s  [E] workbench   [F] board cockpit" % scale_id


func interact(actor: Node) -> void:
	if hangar_preview:
		Hud.open_workshop(scale_id)
		return
	if actor is Scavenger:
		Hud.open_machine_bay(self)


func board_pilot(scav: Node) -> void:
	if hangar_preview or boarded or scav == null:
		return
	if scav is Scavenger and (scav as Scavenger).boarded:
		return
	if disabled or not alive:
		return
	boarded = true
	ai_controlled = false
	_pilot = scav
	if scav is Scavenger:
		(scav as Scavenger).set_boarded(true)
	add_to_group("player")
	_set_self_hidden(true)
	if _camera:
		_camera.current = true
	Hud.set_prompt("COCKPIT  LMB fire   [F] dismount   WASD   mouse look")
	Hud.set_health(hull)
	Hud.show_banner(WorldLore.sealed_steel_banner())
	Fx.play("ui")


func hold_hotwire(scav: Node, delta: float) -> void:
	if boarded or not (disabled or not alive):
		return
	_hotwire += delta * (0.22 + RunState.repair_skill * 0.18)
	Fx.play("hack")
	Hud.set_extract(_hotwire)
	Hud.set_prompt("Hotwiring %s…  %.0f%%  stay exposed — husks hear this" % [scale_id.to_upper(), _hotwire * 100.0])
	if get_tree():
		get_tree().call_group("heavy_mech", "alert_to", global_position)
		get_tree().call_group("choir_husk", "alert_to", global_position)
		get_tree().call_group("ai_scavenger", "alert_to", global_position)
	if _hotwire >= 1.0:
		_hotwire = 0.0
		Hud.set_extract(-1.0)
		if randf() <= RunState.hotwire_chance():
			disabled = false
			alive = true
			hull = maxf(hull, hull_max * 0.35)
			RunState.repair_skill = clampf(RunState.repair_skill + 0.02, 0.1, 0.95)
			Hud.show_banner("Hotwire good — cockpit yours. Hijack complete.")
			board_pilot(scav)
		else:
			Hud.show_banner("Hotwire fail — systems scream. Yard heard you.")
			Fx.play("alarm")
			heat = minf(heat + 40.0, HEAT_MAX)
			if get_tree():
				get_tree().call_group("heavy_mech", "alert_to", global_position)
				get_tree().call_group("choir_husk", "alert_to", global_position)
				get_tree().call_group("pale_host", "alert_to", global_position)


func reset_channels() -> void:
	if _hotwire > 0.0 and _hotwire < 1.0:
		_hotwire = maxf(_hotwire - 0.35, 0.0)
		if _hotwire <= 0.0:
			Hud.set_extract(-1.0)
	if _hack > 0.0 and _hack < 1.0:
		_hack = maxf(_hack - 0.35, 0.0)
	if _pry > 0.0 and _pry < 1.0:
		_pry = maxf(_pry - 0.35, 0.0)


func hold_hack_core(scav: Node, delta: float) -> bool:
	if core_taken:
		return false
	_hack += delta * RunState.hack_rate()
	Fx.play("hack")
	Hud.set_extract(_hack)
	Hud.set_prompt(WorldLore.decrypting_prompt(_hack * 100.0))
	get_tree().call_group("heavy_mech", "alert_to", global_position)
	if _hack >= 1.0:
		_hack = 0.0
		core_taken = true
		Hud.set_extract(-1.0)
		var part := RunState.make_part("data_core", 0.9)
		if scav is Scavenger:
			if RunState.add_carry(part, true):
				Hud.refresh_carry()
				Hud.show_banner(WorldLore.core_secured_banner())
			elif RunState.add_carry(part):
				Hud.refresh_carry()
				Hud.show_banner(WorldLore.core_carry_banner())
		Hud.show_banner(WorldLore.first_voice_hack())
		Hud.set_sensors(WorldLore.first_voice_hack())
		Fx.play("alarm")
		var scene := get_tree().current_scene if get_tree() else null
		if scene and scene.has_method("occupation_answer"):
			scene.call("occupation_answer", global_position)
		return true
	return false


func hold_pry(scav: Node, delta: float) -> void:
	if scale_id != "heavy":
		return
	_pry += delta * 0.32
	Hud.set_extract(_pry)
	Hud.set_prompt("Prying armor on the calf…  %.0f%%  — heavy will notice" % (_pry * 100.0))
	if get_tree() and delta > 0.0:
		get_tree().call_group("choir_husk", "alert_to", global_position)
	if _pry >= 1.0:
		_pry = 0.0
		Hud.set_extract(-1.0)
		var id := "heavy_plating"
		if randf() < 0.28:
			id = "knee_vulcan"
		elif randf() < 0.4:
			id = "armor_plate"
		var part := RunState.make_part(id, randf_range(0.3, 0.75))
		if scav is Scavenger and RunState.add_carry(part):
			Hud.refresh_carry()
			Hud.show_banner("Pried %s off the heavy." % part.get("display_name", id))
			take_section_damage(40.0, global_position + Vector3(0, 2, 0))
		alert_to(global_position)


func dismount() -> void:
	if not boarded:
		return
	boarded = false
	_set_self_hidden(false)
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
	Hud.set_heat(-1.0)
	Hud.set_sensors("")
	Hud.set_sections("")


func _set_self_hidden(hide: bool) -> void:
	var bit := 1 << (SELF_VISUAL_LAYER - 1)
	_hide_meshes(self, hide, bit)


func _hide_meshes(n: Node, hide: bool, bit: int) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).layers = bit if hide else 1
	for c in n.get_children():
		_hide_meshes(c, hide, bit)


func _unhandled_input(event: InputEvent) -> void:
	if not boarded or Hud.ui_busy:
		return
	if not _local_pilot():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * TURN_SENS * (0.55 if scale_id == "heavy" else 1.0))
		_pitch = clampf(_pitch - event.relative.y * TURN_SENS, deg_to_rad(-70.0), deg_to_rad(55.0))
		if _camera:
			_camera.rotation.x = _pitch
	if event.is_action_pressed("ui_cancel"):
		Hud.toggle_pause()
		get_viewport().set_input_as_handled()


func _local_pilot() -> bool:
	if not NetSession.is_online():
		return true
	if _pilot is Scavenger:
		return (_pilot as Scavenger)._local()
	return NetSession.is_host()


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	if not alive and not boarded:
		if hangar_preview:
			velocity = Vector3.ZERO
		return
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	heat = maxf(heat - _cool_rate() * delta, 0.0)
	var sm := _shield_max()
	if sm > 0.0 and heat < 70.0:
		shield_hp = minf(shield_hp + 10.0 * delta, sm)
	if hangar_preview:
		velocity = Vector3.ZERO
		return
	if boarded:
		_pilot_move(delta)
		return
	if ai_controlled and alive:
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
		Fx.puff(global_position + Vector3(0, 0.35, 0), Color(0.45, 0.75, 1.0))
	var input_dir := Vector2.ZERO
	if not Hud.ui_busy and _local_pilot():
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
	if _local_pilot() and (Input.is_action_just_pressed("board") or (Input.is_action_just_pressed("interact") and not in_extract)):
		dismount()
		return
	if _local_pilot() and Input.is_action_pressed("fire") and not Hud.ui_busy:
		_try_fire()
	if scale_id == "vehicle" and _local_pilot() and Input.is_action_just_pressed("hotwire"):
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
	mul *= _leg_part_mul()
	return move_speed * mul * RunState.cap(scale_id, "speed")


func _leg_part_mul() -> float:
	var legs: Variant = equipped.get("legs", {})
	if not (legs is Dictionary) or (legs as Dictionary).is_empty():
		return 1.0
	if float(section_hp.get("legs", 1.0)) <= 0.0:
		return 1.0
	var id := str((legs as Dictionary).get("id", ""))
	var cond := float((legs as Dictionary).get("condition", 1.0))
	if id == "myomer_strand":
		return 1.0 + 0.16 * cond
	if id == "actuator_leg":
		return 1.0 + 0.08 * cond
	return 1.0


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
		_fire_cd = 0.28
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
	heat = minf(heat, HEAT_MAX)
	var dmg := float(weapon.get("damage", 24.0)) * lerpf(0.4, 1.0, float(weapon.get("condition", 1.0)))
	if kind == "melee":
		dmg *= 1.6
	Fx.play(kind if kind != "ballistic" else "vulcan")
	var from := _camera.global_position
	var reach := 18.0 if kind == "melee" else 140.0
	var to := from + (-_camera.global_transform.basis.z) * reach
	if NetSession.is_online() and not NetSession.is_host():
		Fx.spawn_tracer(from + (-_camera.global_transform.basis.z) * 1.4, to, _tracer_color(kind))
		_rpc_shot.rpc_id(1, from, to, dmg, kind)
		return
	_hitscan(from, to, dmg, kind)


func _hitscan(from: Vector3, to: Vector3, dmg: float, kind: String) -> void:
	if not is_inside_tree() or get_world_3d() == null or get_world_3d().direct_space_state == null:
		return
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 7
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	var slot_hint := _slot_hint_ray(from, to)
	if hit:
		end = hit.position
		var col: Object = hit.collider
		if col is Node:
			_apply_hit(col as Node, dmg, hit.position, slot_hint)
	var muzzle := from
	if _camera and _camera.is_inside_tree():
		muzzle = from + (-_camera.global_transform.basis.z) * 1.4
	Fx.spawn_tracer(muzzle, end, _tracer_color(kind))
	if hit:
		Fx.spark(end, _tracer_color(kind))


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


func _slot_hint_ray(from: Vector3, to: Vector3) -> String:
	if not is_inside_tree() or get_world_3d() == null or get_world_3d().direct_space_state == null:
		return ""
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is SlotHotspot:
		return str((hit.collider as SlotHotspot).slot)
	return ""


func _apply_hit(node: Node, dmg: float, point: Vector3, slot_hint: String = "") -> void:
	var cur := node
	while cur:
		if cur is SlotHotspot and slot_hint == "":
			slot_hint = str((cur as SlotHotspot).slot)
		if cur.has_method("take_section_damage"):
			if slot_hint != "":
				cur.call("take_section_damage", dmg, point, slot_hint)
			else:
				cur.call("take_section_damage", dmg, point)
			return
		if cur.has_method("take_damage"):
			cur.call("take_damage", dmg)
			return
		cur = cur.get_parent()


@rpc("any_peer", "reliable")
func _rpc_shot(from: Vector3, to: Vector3, dmg: float, kind: String) -> void:
	if not NetSession.is_host():
		return
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if dmg < 0.0 or dmg > 400.0:
		return
	if not from.is_finite() or not to.is_finite():
		return
	if from.distance_to(to) > 200.0:
		return
	match kind:
		"melee", "ballistic", "energy", "missile":
			pass
		_:
			return
	_hitscan(from, to, dmg, kind)


func section_at_point(point: Vector3) -> String:
	var local := to_local(point)
	if local.y < cockpit_height * 0.45:
		return "legs"
	if local.x < -0.9:
		return "arm_l"
	if local.x > 0.9:
		return "arm_r"
	if local.z < -0.6:
		return "reactor"
	if local.y > cockpit_height * 0.92:
		return "sensors"
	if local.z > 0.85 and local.y < cockpit_height * 0.58:
		return "utility"
	return "chest"


func slot_world_pos(slot: String) -> Vector3:
	var root := get_node_or_null("Hardpoints")
	if root:
		var marker := root.get_node_or_null(slot)
		if marker is Node3D:
			return (marker as Node3D).global_position
	return global_position + Vector3(0, cockpit_height * 0.65, 0)


func section_readout() -> String:
	var bits: PackedStringArray = PackedStringArray()
	var names := {
		"chest": "C", "arm_l": "L", "arm_r": "R", "legs": "LEG",
		"reactor": "RCT", "sensors": "SNS", "utility": "UTL",
	}
	for slot in RunState.SLOTS:
		var hp := maxf(float(section_hp.get(slot, 0.0)), 0.0)
		var tag := str(names.get(slot, slot))
		if hp <= 0.0:
			bits.append("%s--" % tag)
		else:
			bits.append("%s%d" % [tag, int(round(hp))])
	return "SEC  " + " ".join(bits)


func take_section_damage(amount: float, point: Vector3, slot_hint: String = "") -> void:
	if hangar_preview or not alive:
		return
	var slot := slot_hint if slot_hint != "" and section_hp.has(slot_hint) else section_at_point(point)
	if not section_hp.has(slot):
		slot = "chest"
	var before := float(section_hp.get(slot, 100.0))
	if before <= 0.0:
		take_damage(amount * 0.35)
		if alive:
			_overflow_damage(slot, amount, point)
		return
	section_hp[slot] = before - amount * 0.65
	var hp_now := float(section_hp.get(slot, 0.0))
	_apply_limb_visuals()
	Fx.float_text(point, WorldLore.section_abbrev(slot), Color(1.0, 0.55, 0.18) if hp_now > 0.0 else Color(1.0, 0.28, 0.1))
	if boarded:
		Hud.set_sections(section_readout())
	else:
		Hud.set_sections(WorldLore.hit_section_line(scale_id, slot, hp_now))
	if hp_now <= 0.0:
		_break_section(slot)
		var spill := -hp_now
		take_damage(amount * 0.55)
		if alive and spill > 2.0:
			_overflow_damage(slot, spill / 0.65, point)
		return
	take_damage(amount * 0.55)


func _loot_drop_pos(slot: String) -> Vector3:
	var outward := Vector3.ZERO
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam:
		outward = cam.global_position - global_position
		outward.y = 0.0
	if outward.length() < 0.4:
		outward = slot_world_pos(slot) - global_position
		outward.y = 0.0
	if outward.length() < 0.4:
		outward = global_transform.basis.z
	var right := outward.cross(Vector3.UP)
	if right.length() < 0.2:
		right = global_transform.basis.x
	right = right.normalized()
	var side := 0.0
	match slot:
		"arm_l":
			side = -1.6
		"arm_r":
			side = 1.6
		"legs":
			side = -0.9
		"sensors":
			side = 0.7
		"chest":
			side = 0.0
		"reactor":
			side = -0.5
		_:
			side = 1.1
	var reach := 2.8
	return global_position + outward.normalized() * reach + right * side + Vector3(0, 1.15, 0)


func _overflow_damage(from_slot: String, amount: float, point: Vector3) -> void:
	var order := {
		"chest": ["arm_r", "arm_l", "sensors", "legs"],
		"arm_r": ["chest", "arm_l", "legs"],
		"arm_l": ["chest", "arm_r", "legs"],
		"legs": ["chest", "arm_r", "arm_l"],
		"sensors": ["arm_r", "arm_l", "chest"],
		"reactor": ["chest", "utility"],
		"utility": ["chest", "legs"],
	}
	var nexts: Variant = order.get(from_slot, ["chest", "arm_r", "arm_l"])
	if not (nexts is Array):
		return
	var armed: Array[String] = []
	var bare: Array[String] = []
	for n in nexts:
		var slot := str(n)
		if float(section_hp.get(slot, 0.0)) <= 0.0:
			continue
		var part: Variant = equipped.get(slot, {})
		if part is Dictionary and not (part as Dictionary).is_empty():
			armed.append(slot)
		else:
			bare.append(slot)
	for slot in armed:
		take_section_damage(amount * 0.9, point, slot)
		return
	for slot in bare:
		take_section_damage(amount * 0.9, point, slot)
		return


func _break_section(slot: String, announce: bool = true) -> void:
	if bool(_broken.get(slot, false)):
		return
	_broken[slot] = true
	section_hp[slot] = 0.0
	var pop_at := _loot_drop_pos(slot)
	_spawn_limb_debris(slot)
	if _crit_fx.has(slot) and is_instance_valid(_crit_fx[slot]):
		(_crit_fx[slot] as Node).queue_free()
	_crit_fx.erase(slot)
	var part: Variant = equipped.get(slot, {})
	if part is Dictionary and not (part as Dictionary).is_empty():
		var drop: Dictionary = (part as Dictionary).duplicate(true)
		drop["condition"] = clampf(float(drop.get("condition", 1.0)) * randf_range(0.35, 0.7), 0.08, 0.8)
		drop["torn_off"] = true
		drop["torn_slot"] = slot
		equipped[slot] = {}
		component_dropped.emit(drop, pop_at + Vector3(randf_range(-0.4, 0.4), 0.2, randf_range(-0.4, 0.4)))
		if announce:
			Hud.show_banner(WorldLore.torn_off_banner(str(drop.get("display_name", slot)), slot, bool(drop.get("is_weapon", false))), Hud.BANNER_HIGH)
			Fx.float_text(pop_at + Vector3(0, 1.1, 0), "%s TORN" % str(drop.get("display_name", slot)).to_upper(), Color(1.0, 0.62, 0.2))
	else:
		Fx.float_text(pop_at + Vector3(0, 0.8, 0), "%s GONE" % WorldLore.section_abbrev(slot), Color(0.95, 0.4, 0.15))
	Fx.burst(pop_at, Color(1.0, 0.45, 0.12))
	Fx.play("stomp" if scale_id == "heavy" else "melee")
	apply_loadout()


func _spawn_limb_debris(slot: String) -> void:
	var names: PackedStringArray = PackedStringArray()
	match slot:
		"arm_l":
			names = PackedStringArray(["ArmL"])
		"arm_r":
			names = PackedStringArray(["ArmR"])
		"legs":
			names = PackedStringArray(["LegL", "LegR"])
		_:
			return
	for n in names:
		var mesh := _mesh_by_name(n)
		if mesh and mesh.visible:
			Fx.falling_chunk(mesh)


func take_damage(amount: float) -> void:
	if hangar_preview:
		return
	if not alive and not boarded:
		return
	var sm := _shield_max()
	if sm > 0.0 and shield_hp > 0.0:
		var soak := minf(amount * 0.55, shield_hp)
		shield_hp -= soak
		amount -= soak
		heat = minf(heat + soak * 0.12, HEAT_MAX)
	hull -= amount
	if boarded:
		Hud.set_health(hull)
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
		_break_section(slot, false)
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
	_alert_timer = maxf(_alert_timer - delta, 0.0)
	if _alert_timer <= 0.0:
		_alert_pos = Vector3.ZERO
	var target := _ai_target()
	if target != Vector3.ZERO:
		_coat_notice(target)
		var offset := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		var hold := 8.0 if scale_id == "heavy" else 5.5
		if offset.length() > hold:
			_look_flat(offset)
			var spd := move_speed * (1.15 if _alert_timer > 0.0 else 0.85)
			velocity.x = offset.normalized().x * spd
			velocity.z = offset.normalized().z * spd
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_look_flat(offset)
		_ai_fire -= delta
		if _ai_fire <= 0.0 and offset.length() < 32.0 and _ai_has_los(target):
			_ai_fire = 0.55 if scale_id == "heavy" else 0.38
			_ai_shoot(target)
	elif _alert_pos != Vector3.ZERO:
		var offset := Vector3(_alert_pos.x - global_position.x, 0.0, _alert_pos.z - global_position.z)
		if offset.length() > 4.0:
			_look_flat(offset)
			velocity.x = offset.normalized().x * move_speed * 0.95
			velocity.z = offset.normalized().z * move_speed * 0.95
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_alert_pos = Vector3.ZERO
	elif patrol.size() >= 2:
		var p: Vector3 = patrol[_patrol_i]
		var offset := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
		if offset.length() < 3.5:
			_patrol_i = (_patrol_i + 1) % patrol.size()
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			_look_flat(offset)
			velocity.x = offset.normalized().x * move_speed * 0.72
			velocity.z = offset.normalized().z * move_speed * 0.72
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if is_inside_tree() and get_world_3d() != null:
		move_and_slide()


func _look_flat(offset: Vector3) -> void:
	if not is_inside_tree() or offset.length() < 0.1:
		return
	look_at(global_position + offset.normalized(), Vector3.UP)
	rotation.x = 0.0
	rotation.z = 0.0


func _ai_detect_range() -> float:
	if _alert_timer > 0.0 or RunState.heavy_engaged:
		return 38.0 if scale_id == "heavy" else 30.0
	return 22.0 if scale_id == "heavy" else 18.0


func _ai_target() -> Vector3:
	var best := Vector3.ZERO
	var best_d := _ai_detect_range()
	for n in get_tree().get_nodes_in_group("scavenger"):
		if not (n is Scavenger):
			continue
		var scav := n as Scavenger
		if scav.boarded:
			continue
		var d := global_position.distance_to(scav.global_position)
		if d < best_d and _ai_has_los(scav.global_position):
			best_d = d
			best = scav.global_position
	if best != Vector3.ZERO:
		return best
	for n in get_tree().get_nodes_in_group("player"):
		if n == self or not (n is Node3D) or not n.is_in_group("machine"):
			continue
		if not bool(n.get("boarded")):
			continue
		var d := global_position.distance_to((n as Node3D).global_position)
		if d < best_d and _ai_has_los((n as Node3D).global_position):
			best_d = d
			best = (n as Node3D).global_position
	return best


func _ai_has_los(target: Vector3) -> bool:
	if get_world_3d() == null:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3(0, cockpit_height * 0.55, 0)
	var to := target + Vector3(0, 1.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	return space.intersect_ray(query).is_empty()


func _ai_shoot(target: Vector3) -> void:
	var from := global_position + Vector3(0, cockpit_height, 0)
	var to := target + Vector3(0, 1.2, 0)
	_hitscan(from, to, 18.0 if scale_id != "heavy" else 34.0, "ballistic")


func _coat_notice(target: Vector3) -> void:
	_alert_pos = target
	_alert_timer = maxf(_alert_timer, 10.0)
	RunState.heavy_engaged = true
	if _coat_radioed or scale_id != "heavy":
		return
	_coat_radioed = true
	Hud.show_banner(WorldLore.coat_notice_banner())
	if get_tree():
		get_tree().call_group("yard_band", "push", WorldLore.coat_band())


func alert_to(pos: Vector3) -> void:
	_alert_pos = pos
	_alert_timer = 16.0
	RunState.heavy_engaged = true
	if patrol.size() < 2:
		patrol = [pos, global_position] as Array[Vector3]
	if scale_id == "heavy" and not _coat_radioed:
		_coat_radioed = true
		Hud.show_banner(WorldLore.coat_alert_banner())
		if get_tree():
			get_tree().call_group("yard_band", "push", WorldLore.coat_band())


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
	var sh := ""
	if _shield_max() > 0.0:
		sh = "  SHD %d" % int(shield_hp)
	var lock := "  LOCK" if heat >= 96.0 else ""
	Hud.set_prompt("%s  %s   HEAT %.0f%s  WT %.0f%s   [F] dismount" % [scale_id.to_upper(), wname, heat, lock, w, sh])
	Hud.set_sections(section_readout())
	if has_sensors():
		Hud.set_sensors(_sensor_text())
	else:
		Hud.set_sensors("")


func _sensor_text() -> String:
	var bits: PackedStringArray = PackedStringArray()
	for zone in get_tree().get_nodes_in_group("extract_zone"):
		if zone is Node3D:
			var d := global_position.distance_to((zone as Node3D).global_position)
			bits.append("%s %.0fm" % [str(zone.get("extract_type")).to_upper(), d])
	for n in get_tree().get_nodes_in_group("heavy_mech"):
		if n is Node3D and n != self:
			bits.append("HEAVY %.0fm" % global_position.distance_to((n as Node3D).global_position))
	return "SENS  " + "  |  ".join(bits)


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
	if not core_taken:
		for slot in RunState.SLOTS:
			var part: Variant = equipped.get(slot, {})
			if part is Dictionary and bool(part.get("is_payload", false)):
				return true
	for p in RunState.raid_carry:
		if bool(p.get("is_payload", false)):
			return true
	for p in RunState.secure_carry:
		if bool(p.get("is_payload", false)):
			return true
	return false
