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

@onready var _camera: Camera3D = $Camera3D
@onready var _ray: RayCast3D = $Camera3D/InteractRay
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	add_to_group("player")
	add_to_group("scavenger")
	if not Hud.ui_busy:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.current = true
	set_multiplayer_authority(peer_id)


func set_boarded(value: bool) -> void:
	boarded = value
	visible = not value
	_collision.disabled = value
	_camera.current = not value
	set_physics_process(not value)
	if value:
		remove_from_group("player")
	else:
		add_to_group("player")
		Hud.set_health(RunState.health)


func _unhandled_input(event: InputEvent) -> void:
	if boarded or Hud.ui_busy:
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
	if boarded:
		return
	_fire_cd = maxf(_fire_cd - delta, 0.0)
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

	if global_position.y < -20.0:
		take_damage(999.0)
		return

	if _local():
		_update_interact()
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


func _update_interact() -> void:
	if Hud.ui_busy:
		return
	if _in_extract():
		if Input.is_action_just_pressed("board"):
			_try_board_nearby()
		return
	var target := _interactable()
	if target:
		Hud.set_prompt(str(target.call("get_interact_label")))
		if Input.is_action_just_pressed("interact"):
			target.call("interact", self)
		if Input.is_action_just_pressed("hotwire") and target.has_method("begin_hotwire"):
			target.call("begin_hotwire", self)
	else:
		Hud.set_prompt("RMB/LMB scav gun   [E] interact   [F] board   [G] hotwire   CTRL crawl")
	if Input.is_action_just_pressed("board"):
		_try_board_nearby()
	if Input.is_action_just_pressed("deploy"):
		_try_deploy()


func _interactable() -> Node:
	if not _ray.is_colliding():
		return null
	var node := _climb(_ray.get_collider() as Node)
	if node == null:
		return null
	if not node.has_method("get_interact_label"):
		return null
	var label := str(node.call("get_interact_label"))
	if label.strip_edges() == "":
		return null
	return node


func _climb(node: Node) -> Node:
	var cur := node
	while cur:
		if cur.has_method("interact") and cur.has_method("get_interact_label"):
			return cur
		cur = cur.get_parent()
	return null


func _try_board_nearby() -> void:
	for mech in get_tree().get_nodes_in_group("machine"):
		if mech.is_in_group("machine") and global_position.distance_to(mech.global_position) < 9.0:
			if not bool(mech.get("hangar_preview")) and not bool(mech.get("disabled")):
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
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 5
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


func take_damage(amount: float) -> void:
	if boarded or not RunState.in_raid:
		return
	if not _local() and NetSession.is_online():
		return
	RunState.health -= amount
	Hud.set_health(RunState.health)
	if RunState.health <= 0.0:
		RunState.fail_raid("You died. Unsecured loot was lost.")
