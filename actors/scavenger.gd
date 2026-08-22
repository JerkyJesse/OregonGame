extends CharacterBody3D
class_name Scavenger

const LOOK := preload("res://world/WorldLook.gd")
const SPEED := 6.4
const SPRINT := 8.8
const JUMP_VELOCITY := 6.4
const MOUSE_SENS := 0.0022
const CRAWL := 3.2

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var look_pitch: float = 0.0
var boarded: bool = false
var crawling: bool = false
var _fire_cd: float = 0.0
var peer_id: int = 1
var spawn_point: Vector3 = Vector3.ZERO
var spawn_protect: float = 0.0
var interact_focus: Node = null

@onready var _camera: Camera3D = $Camera3D
@onready var _ray: RayCast3D = $Camera3D/InteractRay
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	add_to_group("player")
	add_to_group("scavenger")
	floor_snap_length = 0.5
	set_multiplayer_authority(peer_id)
	if spawn_point == Vector3.ZERO:
		spawn_point = global_position
	if RunState.in_raid:
		spawn_protect = 5.0
	_paint_faction()
	call_deferred("_boot_camera")


func _paint_faction() -> void:
	if _mesh == null:
		return
	var col := WorldLore.faction_color(RunState.faction)
	if RunState.faction == "pale":
		_mesh.material_override = LOOK.emit_surface(Color(0.4, 0.85, 0.22), 0.45)
	else:
		_mesh.material_override = LOOK.paint_mat(col)
	LOOK.dress_human(self, col, true)


func _boot_camera() -> void:
	if not is_inside_tree():
		return
	if not Hud.gameplay_active:
		if _camera:
			_camera.current = false
		return
	if _local() and not Hud.ui_busy:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _camera:
		_camera.current = _local() and not boarded
		LOOK.tune_camera(_camera)


func set_boarded(value: bool) -> void:
	boarded = value
	visible = not value
	_collision.disabled = value
	if _camera:
		_camera.current = (not value) and _local()
	set_physics_process(not value)
	if value:
		remove_from_group("player")
	else:
		add_to_group("player")
		if _local():
			Hud.set_health(RunState.health)
			if not Hud.ui_busy:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if boarded or Hud.ui_busy or not Hud.gameplay_active:
		return
	if not _local():
		return
	if Walkthrough.active:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		look_pitch = clampf(look_pitch - event.relative.y * MOUSE_SENS, deg_to_rad(-89.0), deg_to_rad(89.0))
		_camera.rotation.x = look_pitch
	if event.is_action_pressed("ui_cancel") and not Hud.ui_busy:
		Hud.toggle_pause()
		get_viewport().set_input_as_handled()


func _local() -> bool:
	if not NetSession.is_online():
		return true
	return is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if boarded or not Hud.gameplay_active or not is_inside_tree() or get_world_3d() == null:
		return
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	spawn_protect = maxf(spawn_protect - delta, 0.0)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not Hud.ui_busy and _local():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	if not Hud.ui_busy and _local():
		if Walkthrough.active:
			input_dir = Walkthrough.move_axis(self)
			Walkthrough.apply_look(self, delta)
		else:
			input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	crawling = (not Walkthrough.active) and Input.is_key_pressed(KEY_CTRL) and _local()
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := SPEED
	if crawling:
		speed = CRAWL
	elif Walkthrough.active and Walkthrough.sprint:
		speed = SPRINT
	elif Input.is_key_pressed(KEY_SHIFT):
		speed = SPRINT
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	move_and_slide()

	if global_position.y < -8.0:
		if RunState.in_raid and RunState.raid_timer < 4.0:
			global_position = spawn_point
			velocity = Vector3.ZERO
			return
		take_damage(999.0)
		return

	if _local():
		_update_interact(delta)
		if Input.is_action_pressed("fire") and not Hud.ui_busy:
			_scav_fire()
		_sync_pose()


func _sync_pose() -> void:
	if NetSession.is_online() and _local():
		_rpc_pose.rpc(global_position, rotation.y, look_pitch)


@rpc("any_peer", "unreliable")
func _rpc_pose(pos: Vector3, yaw: float, pitch: float) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if _local():
		return
	if not pos.is_finite() or absf(pos.x) > 5000.0 or absf(pos.y) > 500.0 or absf(pos.z) > 5000.0:
		return
	global_position = pos
	rotation.y = yaw
	look_pitch = clampf(pitch, -1.4, 1.4)
	if _camera:
		_camera.rotation.x = look_pitch


func _update_interact(delta: float) -> void:
	if Hud.ui_busy:
		interact_focus = null
		return
	if Input.is_action_just_pressed("use_item") and not boarded:
		_try_filter()
	if Input.is_action_just_pressed("dump") and not boarded:
		_dump_part()
	var target := _interactable()
	interact_focus = target
	if target:
		Hud.set_prompt(str(target.call("get_interact_label")))
		_look_sections(target)
		if Input.is_action_pressed("hotwire") and target.has_method("hold_hotwire"):
			target.call("hold_hotwire", self, delta)
		elif Input.is_action_pressed("interact") and target is ClimbPoint:
			target.call("hold_pry", self, delta)
		elif Input.is_action_pressed("interact") and target.has_method("hold_hack"):
			target.call("hold_hack", self, delta)
		elif Input.is_action_pressed("interact") and target.has_method("hold_hack_core") and (Input.is_key_pressed(KEY_SHIFT) or target.is_in_group("shard_dais")):
			target.call("hold_hack_core", self, delta)
		elif Input.is_action_just_pressed("interact") and not Input.is_key_pressed(KEY_SHIFT):
			target.call("interact", self)
		elif target.has_method("reset_channels") and not Input.is_action_pressed("hotwire") and not Input.is_action_pressed("interact"):
			target.call("reset_channels")
	else:
		if not _in_extract():
			var hint := "LMB scav gun   [E] use   [F] board   [G] hotwire   [Q] dump   CTRL crawl"
			if RunState.has_filter_pack():
				hint += "   [R] swap filter"
			Hud.set_prompt(hint)
		Hud.set_sections("")
		_decay_nearby_channels()
	if Input.is_action_just_pressed("board"):
		_try_board_nearby()
	if Input.is_action_just_pressed("deploy"):
		_try_deploy()


func _dump_part() -> void:
	var part := RunState.dump_last_carry()
	if part.is_empty():
		Hud.show_banner(WorldLore.dump_empty())
		return
	Hud.refresh_carry()
	var drop_pos := global_position + Vector3(0, 0.4, 0) - transform.basis.z * 1.1
	if get_tree().current_scene and get_tree().current_scene.has_method("spawn_loot"):
		get_tree().current_scene.call("spawn_loot", part, drop_pos)
	Hud.show_banner(WorldLore.dump_banner(str(part.get("display_name", "part"))))
	Fx.play("ui")


func _try_filter() -> void:
	if RunState.use_filter_pack():
		Hud.refresh_carry()
		Hud.show_banner(WorldLore.filter_swapped_banner())
		Hud.set_lungs(RunState.filter)
		Fx.play("ui")
	elif RunState.last_message != "":
		Hud.show_banner(RunState.last_message)


func _decay_nearby_channels() -> void:
	for mech in get_tree().get_nodes_in_group("machine"):
		if mech.has_method("reset_channels") and global_position.distance_to(mech.global_position) < 12.0:
			mech.call("reset_channels")


func _look_sections(target: Node) -> void:
	var mech := _machine_from(target)
	if mech and mech.has_method("section_readout"):
		Hud.set_sections(str(mech.call("section_readout")))
	else:
		Hud.set_sections("")


func _machine_from(node: Node) -> Node:
	var cur := node
	while cur:
		if cur.is_in_group("machine"):
			return cur
		cur = cur.get_parent()
	return null


func _interactable() -> Node:
	var loot := _nearest_loot()
	if loot:
		return loot
	if _ray == null:
		return null
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.collision_mask = 8
	_ray.force_raycast_update()
	if _ray.is_colliding():
		var n := _climb(_ray.get_collider() as Node)
		if n:
			return n
	_ray.collision_mask = 13
	_ray.force_raycast_update()
	if _ray.is_colliding():
		var n := _climb(_ray.get_collider() as Node)
		if n:
			return n
	return _nearest_machine()


func _nearest_loot() -> Node:
	if _camera == null or not is_inside_tree():
		return null
	var best: Node = null
	var best_score := 999.0
	var facing := -_camera.global_transform.basis.z
	var origin := _camera.global_position
	for n in get_tree().get_nodes_in_group("loot"):
		if not (n is Node3D):
			continue
		if not n.has_method("interact") or not n.has_method("get_interact_label"):
			continue
		if str(n.call("get_interact_label")).strip_edges() == "":
			continue
		var pos: Vector3 = (n as Node3D).global_position + Vector3(0, 0.75, 0)
		var offset := pos - origin
		var d := offset.length()
		if d > 5.2:
			continue
		var dir := offset / maxf(d, 0.001)
		var face := facing.dot(dir)
		var tagged := n.is_in_group("torn_loot") or n.is_in_group("rival_bag")
		var reach := 3.4 if tagged else 2.2
		if d <= reach:
			if face < -0.2:
				continue
		elif face < 0.28:
			continue
		var score := d
		if tagged:
			score -= 0.9
		if face > 0.55:
			score -= 0.35
		if score < best_score:
			best_score = score
			best = n
	return best


func _nearest_machine() -> Node:
	var best: Node = null
	var best_d := 4.5
	var facing := -_camera.global_transform.basis.z
	for mech in get_tree().get_nodes_in_group("machine"):
		if mech is Node3D:
			var offset: Vector3 = (mech as Node3D).global_position + Vector3(0, 2, 0) - _camera.global_position
			var d := offset.length()
			if d < best_d and facing.dot(offset.normalized()) > 0.35:
				best_d = d
				best = mech
	if best and best.has_method("get_interact_label") and str(best.call("get_interact_label")) != "":
		return best
	return null


func _climb(node: Node) -> Node:
	var cur := node
	while cur:
		if cur.has_method("interact") and cur.has_method("get_interact_label"):
			var label := str(cur.call("get_interact_label"))
			if label.strip_edges() != "":
				return cur
		cur = cur.get_parent()
	return null


func _try_board_nearby() -> void:
	for mech in get_tree().get_nodes_in_group("machine"):
		if mech.is_in_group("machine") and global_position.distance_to(mech.global_position) < 9.0:
			if not bool(mech.get("hangar_preview")) and not bool(mech.get("disabled")) and bool(mech.get("alive")):
				mech.call("board_pilot", self)
				return


func _try_deploy() -> void:
	for console in get_tree().get_nodes_in_group("deploy_console"):
		if global_position.distance_to(console.global_position) < 5.0 and console.has_method("interact"):
			console.interact(self)
			return


func _in_extract() -> bool:
	for zone in get_tree().get_nodes_in_group("extract_zone"):
		if zone is Area3D and (zone as Area3D).overlaps_body(self):
			return true
	return false


func _scav_fire() -> void:
	if _fire_cd > 0.0 or not RunState.in_raid:
		return
	_fire_cd = 0.28
	Fx.play("vulcan")
	var from := _camera.global_position
	var to := from + (-_camera.global_transform.basis.z) * 40.0
	if NetSession.is_online() and not NetSession.is_host():
		Fx.spawn_tracer(from + (-_camera.global_transform.basis.z) * 0.8, to, Color(0.9, 0.85, 0.5))
		_rpc_scav_shot.rpc_id(1, from, to)
		return
	_scav_hitscan(from, to)


func _scav_hitscan(from: Vector3, to: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 7
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	var slot_hint := ""
	var hint_q := PhysicsRayQueryParameters3D.create(from, to)
	hint_q.exclude = [get_rid()]
	hint_q.collision_mask = 8
	hint_q.collide_with_areas = true
	hint_q.collide_with_bodies = false
	var hint_hit := get_world_3d().direct_space_state.intersect_ray(hint_q)
	if hint_hit and hint_hit.collider is SlotHotspot:
		slot_hint = str((hint_hit.collider as SlotHotspot).slot)
	if hit:
		end = hit.position
		var col: Object = hit.collider
		if col is Node:
			var n := col as Node
			if n is SlotHotspot and slot_hint == "":
				slot_hint = str((n as SlotHotspot).slot)
			if n.has_method("take_section_damage"):
				if slot_hint != "":
					n.call("take_section_damage", 8.0, hit.position, slot_hint)
				else:
					n.call("take_section_damage", 8.0, hit.position)
			elif n.has_method("take_damage"):
				n.call("take_damage", 8.0)
			else:
				var parent := n.get_parent()
				while parent:
					if parent.has_method("take_section_damage"):
						if slot_hint != "":
							parent.call("take_section_damage", 8.0, hit.position, slot_hint)
						else:
							parent.call("take_section_damage", 8.0, hit.position)
						break
					if parent.has_method("take_damage"):
						parent.call("take_damage", 8.0)
						break
					parent = parent.get_parent()
	Fx.spawn_tracer(from + (-_camera.global_transform.basis.z) * 0.8, end, Color(0.9, 0.85, 0.5))
	if hit:
		Fx.spark(end, Color(1.0, 0.75, 0.35))


@rpc("any_peer", "reliable")
func _rpc_scav_shot(from: Vector3, to: Vector3) -> void:
	if not NetSession.is_host():
		return
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if not from.is_finite() or not to.is_finite():
		return
	if from.distance_to(to) > 80.0:
		return
	_scav_hitscan(from, to)


func take_damage(amount: float, cause: String = "") -> void:
	if Walkthrough.active or boarded or not RunState.in_raid or spawn_protect > 0.0:
		return
	if not _local() and NetSession.is_online():
		return
	RunState.health -= amount
	Hud.set_health(RunState.health)
	if RunState.health <= 0.0:
		RunState.fail_raid(WorldLore.death_banner(cause))
