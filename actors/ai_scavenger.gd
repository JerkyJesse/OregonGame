extends CharacterBody3D
class_name AiScavenger

const LOOK := preload("res://world/WorldLook.gd")
const SPEED := 5.2

@export var face_id: String = ""

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var hp: float = 40.0
var hostile: bool = true
var home: Vector3 = Vector3.ZERO
var _loot_cd: float = 2.0
var _fire_cd: float = 0.8
var _radioed: bool = false
var _hurt: bool = false
var _bag: Array[Dictionary] = []
var _job: String = "loot"
var _nametag: Label3D
var _alert_pos: Vector3 = Vector3.ZERO


func setup_faction(id: String) -> void:
	match str(id):
		"remnant":
			face_id = "pell"
		"corporate":
			face_id = "wren"
		"warlord":
			face_id = "ash_nine"
		"tax":
			face_id = "tax"
		"scav":
			face_id = "jex"
		"pale":
			face_id = "pale"
		_:
			face_id = str(id) if str(id) in ["jex", "pell", "wren", "ash_nine", "tax", "pale"] else ""
	_apply_face()
	_paint()


func _ready() -> void:
	add_to_group("ai_scavenger")
	collision_layer = 2
	collision_mask = 5
	if home == Vector3.ZERO:
		home = global_position
	_apply_face()
	_paint()


func _apply_face() -> void:
	match face_id:
		"jex":
			_job = "loot"
			hp = 55.0
			hostile = false
		"pell":
			_job = "hunt_core"
			hp = 70.0
			hostile = false
		"wren":
			_job = "catwalk"
			hp = 48.0
			hostile = false
		"ash_nine":
			_job = "hotwire"
			hp = 36.0
			hostile = false
		"tax":
			_job = "tax"
			hp = 50.0
			hostile = not RunState.tax_cleared
			add_to_group("tax_crew")
		"pale":
			_job = "hunt_core"
			hp = 58.0
			hostile = RunState.faction != "pale"
		_:
			_job = "loot"
			hostile = true


func _paint() -> void:
	var col := Color(0.45, 0.22, 0.18)
	match face_id:
		"jex":
			col = Color(0.38, 0.2, 0.14)
		"pell":
			col = Color(0.48, 0.5, 0.42)
		"wren":
			col = Color(0.82, 0.68, 0.42)
		"ash_nine":
			col = Color(0.62, 0.16, 0.12)
		"tax":
			col = Color(0.58, 0.38, 0.12)
		"pale":
			col = WorldLore.faction_color("pale")
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		if face_id == "pale":
			mesh.material_override = LOOK.emit_surface(col, 0.7)
		else:
			mesh.material_override = LOOK.paint_mat(col)
		LOOK.dress_human(self, col, false)
	if _nametag == null:
		_nametag = Label3D.new()
		_nametag.position = Vector3(0, 2.15, 0)
		_nametag.font_size = 36
		_nametag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_nametag.outline_size = 6
		_nametag.outline_modulate = Color(0, 0, 0, 0.85)
		add_child(_nametag)
	_nametag.visible = true
	if face_id == "":
		_nametag.text = WorldLore.rival_callsign("scav")
	else:
		_nametag.text = WorldLore.face_name(face_id)
	_nametag.modulate = col.lightened(0.25)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_loot_cd -= delta
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_refresh_hostility()
	_maybe_radio()
	var dest := _goal()
	var offset := Vector3(dest.x - global_position.x, 0.0, dest.z - global_position.z)
	if offset.length() > 1.2:
		var dir := offset.normalized()
		velocity.x = dir.x * _speed()
		velocity.z = dir.z * _speed()
		if dir.length() > 0.05:
			look_at(global_position + dir, Vector3.UP)
			rotation.x = 0.0
			rotation.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _job == "run_out":
			_escape()
			return
		if _loot_cd <= 0.0:
			_try_work()
	move_and_slide()
	if hostile:
		_try_shoot()
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col is Scavenger:
				(col as Scavenger).take_damage(8.0 * delta)


func _speed() -> float:
	match face_id:
		"jex":
			return SPEED + 0.8
		"ash_nine":
			return SPEED + 1.1
		"wren":
			return SPEED + 0.4
		"pale":
			return SPEED + 0.5
		_:
			return SPEED


func _refresh_hostility() -> void:
	if _hurt:
		hostile = true
		return
	match face_id:
		"tax":
			hostile = not RunState.tax_cleared
		"jex":
			hostile = RunState.has_raid_payload() or RunState.faction == "pale"
		"pell", "wren":
			hostile = RunState.has_raid_payload() or RunState.faction == "pale"
		"ash_nine":
			hostile = RunState.faction == "pale"
		"pale":
			hostile = RunState.faction != "pale"
		_:
			hostile = true


func _maybe_radio() -> void:
	if _radioed or face_id == "":
		return
	var p := _player_node()
	if p is Node3D and global_position.distance_to((p as Node3D).global_position) < 16.0:
		_radioed = true
		Hud.show_banner(WorldLore.face_radio(face_id))
		Fx.play("ui")


func _goal() -> Vector3:
	if _job == "run_out":
		return _extract_goal()
	if _alert_pos != Vector3.ZERO:
		return _alert_pos
	match _job:
		"tax":
			if RunState.tax_cleared:
				return home + Vector3(sin(Time.get_ticks_msec() * 0.0007), 0, cos(Time.get_ticks_msec() * 0.0007)) * 10.0
			return home
		"catwalk":
			return _wren_goal()
		"hunt_core":
			var prey := _core_target()
			if prey != Vector3.ZERO:
				return prey
		"hotwire":
			for n in get_tree().get_nodes_in_group("machine"):
				if n is Node3D and bool(n.get("disabled")):
					return (n as Node3D).global_position
	for n in get_tree().get_nodes_in_group("loot"):
		if n is Node3D:
			return (n as Node3D).global_position
	for n in get_tree().get_nodes_in_group("machine"):
		if n is Node3D and bool(n.get("disabled")):
			return (n as Node3D).global_position
	return home + Vector3(sin(Time.get_ticks_msec() * 0.001), 0, cos(Time.get_ticks_msec() * 0.001)) * 8.0


func _wren_goal() -> Vector3:
	var sock := _nearest_socket()
	var want_ground := sock != null and (RunState.has_raid_payload() or _alert_pos != Vector3.ZERO)
	if sock and not bool(sock.get("taken")) and _job == "catwalk" and _bag.is_empty():
		want_ground = global_position.distance_to(sock.global_position) < 22.0 and RunState.raid_timer > 20.0
	if want_ground and sock and global_position.y < 4.0:
		return sock.global_position
	if want_ground and sock and global_position.y >= 4.0:
		if global_position.z > 4.0:
			return Vector3(10.0, 0.3, 8.0)
		return Vector3(10.0, 8.45, 6.0)
	return Vector3(sin(Time.get_ticks_msec() * 0.00045) * 16.0, 8.45, 0.0)


func _core_target() -> Vector3:
	var p := _player_node()
	if RunState.has_raid_payload() and p is Node3D:
		return (p as Node3D).global_position
	var sock := _nearest_socket()
	if sock:
		return sock.global_position
	for n in get_tree().get_nodes_in_group("machine"):
		if n is Node3D and not bool(n.get("core_taken")) and (bool(n.get("disabled")) or not bool(n.get("alive"))):
			return (n as Node3D).global_position
	return Vector3.ZERO


func _nearest_socket() -> Node3D:
	for n in get_tree().get_nodes_in_group("shard_socket"):
		if n is Node3D and not bool(n.get("taken")):
			return n as Node3D
	return null


func alert_to(pos: Vector3) -> void:
	if _job == "run_out" or _job == "tax":
		return
	_alert_pos = pos


func _extract_goal() -> Vector3:
	var best := home + Vector3(-36.0, 0.0, 12.0)
	var best_d := 9999.0
	if get_tree() == null:
		return best
	for n in get_tree().get_nodes_in_group("extract_zone"):
		if not (n is Node3D):
			continue
		if str(n.get("extract_type")) != "stealth":
			continue
		var d := global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = (n as Node3D).global_position
	return best


func _maybe_run_out() -> void:
	if face_id == "" or face_id == "tax" or face_id == "pale":
		return
	if _bag.is_empty():
		return
	_job = "run_out"
	_alert_pos = Vector3.ZERO


func _escape() -> void:
	var n := _bag.size()
	Hud.show_banner(WorldLore.face_extracted(face_id, n))
	if get_tree():
		get_tree().call_group("yard_band", "push", WorldLore.face_extract_band(face_id))
	var scene := get_tree().current_scene if get_tree() else null
	if scene and scene.has_method("spawn_bag") and not _bag.is_empty():
		scene.call("spawn_bag", _bag.duplicate(), global_position + Vector3(0, 0.2, 0))
	else:
		for part in _bag:
			component_drop(part)
	_bag.clear()
	queue_free()


func _try_work() -> void:
	_loot_cd = 3.6
	if _job == "hunt_core" or _job == "catwalk":
		if _steal_core():
			return
	if _job == "hotwire":
		if _yank_part():
			return
	for n in get_tree().get_nodes_in_group("loot"):
		if n is Node3D and global_position.distance_to((n as Node3D).global_position) < 3.0 and n.has_method("ai_steal"):
			var taken: Variant = n.call("ai_steal")
			if taken is Dictionary and not (taken as Dictionary).is_empty():
				_bag.append(taken)
				if face_id != "":
					Hud.show_banner(WorldLore.face_stole(face_id, str(taken.get("display_name", "part"))))
				_maybe_run_out()
			return


func _steal_core() -> bool:
	var sock := _nearest_socket()
	if sock and global_position.distance_to(sock.global_position) < 2.6 and sock.has_method("steal"):
		var part: Dictionary = sock.call("steal")
		if not part.is_empty():
			_bag.append(part)
			Hud.show_banner(WorldLore.face_stole(face_id, "Choir shard"))
			Fx.play("hack")
			_choir_answer()
			_maybe_run_out()
			return true
	for n in get_tree().get_nodes_in_group("machine"):
		if n is Node3D and global_position.distance_to((n as Node3D).global_position) < 4.0:
			if not bool(n.get("core_taken")) and n.has_method("field_strip"):
				n.set("core_taken", true)
				var shard := RunState.make_part("data_core", 0.75)
				_bag.append(shard)
				Hud.show_banner(WorldLore.face_stole(face_id, "Choir shard"))
				Fx.play("hack")
				_choir_answer()
				_maybe_run_out()
				return true
	return false


func _choir_answer() -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if scene and scene.has_method("occupation_answer"):
		scene.call("occupation_answer", global_position)


func _yank_part() -> bool:
	for n in get_tree().get_nodes_in_group("machine"):
		if n is Node3D and bool(n.get("disabled")) and global_position.distance_to((n as Node3D).global_position) < 4.0:
			for slot in RunState.SLOTS:
				if not n.has_method("field_strip"):
					break
				var taken: Dictionary = n.call("field_strip", slot)
				if not taken.is_empty():
					_bag.append(taken)
					Hud.show_banner(WorldLore.face_stole(face_id, str(taken.get("display_name", "part"))))
					Fx.play("ui")
					_maybe_run_out()
					return true
	return false


func _try_shoot() -> void:
	if _fire_cd > 0.0:
		return
	var p := _player_node()
	if p == null or not (p is Node3D):
		return
	var target := p as Node3D
	var dist := global_position.distance_to(target.global_position)
	if dist > 16.0 or dist < 1.4:
		return
	if not _has_los(target):
		return
	_fire_cd = 0.82
	var from := global_position + Vector3(0, 1.3, 0)
	var to := target.global_position + Vector3(0, 1.1, 0)
	Fx.spawn_tracer(from, to, Color(0.95, 0.55, 0.2))
	Fx.play("vulcan")
	if target.has_method("take_damage"):
		target.call("take_damage", 7.0)


func _has_los(target: Node3D) -> bool:
	if get_world_3d() == null:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3(0, 1.3, 0)
	var to := target.global_position + Vector3(0, 1.1, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	if target is CollisionObject3D:
		query.exclude.append((target as CollisionObject3D).get_rid())
	query.collision_mask = 5
	return space.intersect_ray(query).is_empty()


func _player_node() -> Node:
	var fallback: Node = null
	for n in get_tree().get_nodes_in_group("scavenger"):
		if n == self or not (n is Scavenger):
			continue
		var scav := n as Scavenger
		if scav.boarded:
			continue
		if scav._local():
			return scav
		if fallback == null:
			fallback = scav
	if fallback:
		return fallback
	for n in get_tree().get_nodes_in_group("player"):
		if n != self and n.is_in_group("machine") and bool(n.get("boarded")):
			return n
	return null


func take_damage(amount: float) -> void:
	hp -= amount
	_hurt = true
	hostile = true
	if hp <= 0.0:
		_die()


func _die() -> void:
	if face_id == "tax":
		call_deferred("_check_tax_wipe")
	var drop := RunState.make_part(_drop_id(), randf_range(0.3, 0.7))
	component_drop(drop)
	for part in _bag:
		component_drop(part)
	if face_id != "":
		Hud.show_banner(WorldLore.face_down_banner(face_id))
	queue_free()


func _check_tax_wipe() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("tax_crew"):
		if is_instance_valid(n) and n != self:
			return
	if not RunState.tax_cleared:
		RunState.tax_cleared = true
		Hud.show_banner(WorldLore.tax_fought_banner())
		Fx.play("extract")


func _drop_id() -> String:
	match face_id:
		"jex":
			return "armor_plate"
		"pell":
			return "sensor_suite"
		"wren":
			return "cooler_pack"
		"ash_nine":
			return "myomer_strand"
		"tax":
			return "armor_plate"
		"pale":
			return "filament_veil"
		_:
			return "armor_plate"


func component_drop(part: Dictionary) -> void:
	if part.is_empty():
		return
	if get_tree().current_scene and get_tree().current_scene.has_method("spawn_loot"):
		get_tree().current_scene.call("spawn_loot", part, global_position + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)))
