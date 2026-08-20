extends CharacterBody3D
class_name Scavenger

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
	call_deferred("_boot_camera")


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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		look_pitch = clampf(look_pitch - event.relative.y * MOUSE_SENS, deg_to_rad(-89.0), deg_to_rad(89.0))
		_camera.rotation.x = look_pitch
	if event.is_action_pressed("ui_cancel") and not Hud.ui_busy:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	crawling = Input.is_key_pressed(KEY_CTRL) and _local()
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := SPEED
	if crawling:
		speed = CRAWL
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
	if _local():
		return
	global_position = pos
	rotation.y = yaw
	look_pitch = pitch
	if _camera:
		_camera.rotation.x = pitch


func _update_interact(delta: float) -> void:
	if Hud.ui_busy:
		return
	if _in_extract():
		if Input.is_action_just_pressed("board"):
			_try_board_nearby()
		return
	var target := _interactable()
	if target:
		Hud.set_prompt(str(target.call("get_interact_label")))
		if Input.is_action_just_pressed("interact") and not Input.is_key_pressed(KEY_SHIFT):
			target.call("interact", self)
		if Input.is_action_pressed("hotwire") and target.has_method("hold_hotwire"):
			target.call("hold_hotwire", self, delta)
		elif target.has_method("reset_channels") and not Input.is_action_pressed("hotwire"):
			target.call("reset_channels")
		if Input.is_action_pressed("interact") and target.has_method("hold_hack_core") and Input.is_key_pressed(KEY_SHIFT):
			target.call("hold_hack_core", self, delta)
	else:
		Hud.set_prompt("LMB scav gun   [E] use   [F] board   [G] hold hotwire   CTRL crawl")
		_decay_nearby_channels()
	if Input.is_action_just_pressed("board"):
		_try_board_nearby()
	if Input.is_action_just_pressed("deploy"):
		_try_deploy()


func _decay_nearby_channels() -> void:
	for mech in get_tree().get_nodes_in_group("machine"):
		if mech.has_method("reset_channels") and global_position.distance_to(mech.global_position) < 12.0:
			mech.call("reset_channels")


func _interactable() -> Node:
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
	if hit:
		end = hit.position
		var col: Object = hit.collider
		if col is Node:
			var n := col as Node
			if n.has_method("take_section_damage"):
				n.call("take_section_damage", 8.0, hit.position)
			elif n.has_method("take_damage"):
				n.call("take_damage", 8.0)
	Fx.spawn_tracer(from + (-_camera.global_transform.basis.z) * 0.8, end, Color(0.9, 0.85, 0.5))


@rpc("any_peer", "reliable")
func _rpc_scav_shot(from: Vector3, to: Vector3) -> void:
	if not NetSession.is_host():
		return
	_scav_hitscan(from, to)


func take_damage(amount: float) -> void:
	if boarded or not RunState.in_raid or spawn_protect > 0.0:
		return
	if not _local() and NetSession.is_online():
		return
	RunState.health -= amount
	Hud.set_health(RunState.health)
	if RunState.health <= 0.0:
		RunState.fail_raid("You died. Unsecured loot was lost.")
