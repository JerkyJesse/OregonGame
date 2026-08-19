extends CharacterBody3D
class_name AiScavenger

const SPEED := 5.2

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var hp: float = 40.0
var _loot_cd: float = 2.0


func _ready() -> void:
	add_to_group("ai_scavenger")
	collision_layer = 2
	collision_mask = 5


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	_loot_cd -= delta
	var dest := _goal()
	var offset := Vector3(dest.x - global_position.x, 0.0, dest.z - global_position.z)
	if offset.length() > 1.2:
		var dir := offset.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		look_at(global_position + dir, Vector3.UP)
		rotation.x = 0.0
		rotation.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _loot_cd <= 0.0:
			_try_loot()
	move_and_slide()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col is Scavenger:
			(col as Scavenger).take_damage(8.0 * delta)


func _goal() -> Vector3:
	for n in get_tree().get_nodes_in_group("loot"):
		if n is Node3D:
			return (n as Node3D).global_position
	for n in get_tree().get_nodes_in_group("machine"):
		if n.is_in_group("machine") and bool(n.get("disabled")):
			return (n as Node3D).global_position
	return global_position + Vector3(sin(Time.get_ticks_msec() * 0.001), 0, cos(Time.get_ticks_msec() * 0.001)) * 8.0


func _try_loot() -> void:
	_loot_cd = 4.0
	for n in get_tree().get_nodes_in_group("loot"):
		if n is Node3D and global_position.distance_to((n as Node3D).global_position) < 3.0 and n.has_method("ai_steal"):
			n.call("ai_steal")
			return


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		var wreck_part := RunState.make_part("armor_plate", 0.35)
		component_drop(wreck_part)
		queue_free()


func component_drop(part: Dictionary) -> void:
	if get_tree().current_scene and get_tree().current_scene.has_method("spawn_loot"):
		get_tree().current_scene.call("spawn_loot", part, global_position)
