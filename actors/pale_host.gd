extends CharacterBody3D
class_name PaleHost

const LOOK := preload("res://world/WorldLook.gd")
const SPEED := 4.6

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var hp: float = 78.0
var hostile: bool = true
var home: Vector3 = Vector3.ZERO
var _fire_cd: float = 1.1
var _bob: float = 0.0
var _alert_pos: Vector3 = Vector3.ZERO
var _radioed: bool = false


func _ready() -> void:
	add_to_group("pale_host")
	add_to_group("ai_scavenger")
	collision_layer = 2
	collision_mask = 5
	hostile = RunState.faction != "pale"
	if home == Vector3.ZERO:
		home = global_position
	LOOK.dress_pale_host(self)


func alert_to(pos: Vector3) -> void:
	_alert_pos = pos


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_bob += delta
	hostile = RunState.faction != "pale"
	if _alert_pos != Vector3.ZERO and global_position.distance_to(_alert_pos) < 2.4:
		_alert_pos = Vector3.ZERO
	var dest := _goal()
	var offset := Vector3(dest.x - global_position.x, 0.0, dest.z - global_position.z)
	if offset.length() > 1.4:
		var dir := offset.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		if dir.length() > 0.05:
			look_at(global_position + dir, Vector3.UP)
			rotation.x = 0.0
			rotation.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	var look := get_node_or_null("LookAlien") as Node3D
	if look:
		look.position.y = sin(_bob * 2.4) * 0.08
	if hostile:
		_try_spit()
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col is Scavenger:
				(col as Scavenger).take_damage(11.0 * delta, "bloom")
	_maybe_radio()


func _goal() -> Vector3:
	if _alert_pos != Vector3.ZERO:
		return _alert_pos
	if hostile:
		var p := _player_node()
		if p is Node3D:
			return (p as Node3D).global_position
	return home + Vector3(sin(Time.get_ticks_msec() * 0.0006), 0, cos(Time.get_ticks_msec() * 0.0006)) * 10.0


func _try_spit() -> void:
	if _fire_cd > 0.0:
		return
	var p := _player_node()
	if p == null or not (p is Node3D):
		return
	var target := p as Node3D
	var dist := global_position.distance_to(target.global_position)
	if dist > 18.0 or dist < 1.6:
		return
	if not _has_los(target):
		return
	_fire_cd = 1.15
	var from := global_position + Vector3(0, 1.7, 0)
	var to := target.global_position + Vector3(0, 1.1, 0)
	Fx.spawn_tracer(from, to, LOOK.PALE)
	Fx.play("energy")
	if target.has_method("take_damage"):
		if target is Scavenger:
			target.call("take_damage", 9.0, "bloom")
		else:
			target.call("take_damage", 6.0)


func _has_los(target: Node3D) -> bool:
	if get_world_3d() == null:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3(0, 1.6, 0)
	var to := target.global_position + Vector3(0, 1.1, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	if target is CollisionObject3D:
		query.exclude.append((target as CollisionObject3D).get_rid())
	query.collision_mask = 5
	return space.intersect_ray(query).is_empty()


func _player_node() -> Node:
	for n in get_tree().get_nodes_in_group("scavenger"):
		if n is Scavenger and not (n as Scavenger).boarded and (n as Scavenger)._local():
			return n
	for n in get_tree().get_nodes_in_group("player"):
		if n != self and n.is_in_group("machine") and bool(n.get("boarded")):
			return n
	return null


func _maybe_radio() -> void:
	if _radioed:
		return
	var p := _player_node()
	if p is Node3D and global_position.distance_to((p as Node3D).global_position) < 18.0:
		_radioed = true
		Hud.show_banner(WorldLore.pale_sighted_banner())
		Fx.play("radio")


func take_damage(amount: float) -> void:
	hp -= amount
	hostile = true
	if hp <= 0.0:
		_die()


func _die() -> void:
	Hud.show_banner(WorldLore.pale_down_banner())
	var drop := RunState.make_part("filament_veil", randf_range(0.45, 0.85))
	if get_tree().current_scene and get_tree().current_scene.has_method("spawn_loot"):
		get_tree().current_scene.call("spawn_loot", drop, global_position)
	Fx.burst(global_position + Vector3(0, 1.2, 0), LOOK.PALE)
	queue_free()
