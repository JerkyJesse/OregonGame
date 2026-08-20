class_name Greybox
extends RefCounted

const LOOK := preload("res://world/WorldLook.gd")


static func mat(color: Color, emit: float = 0.0) -> Material:
	if emit > 0.0:
		return LOOK.emit_surface(color, emit)
	return LOOK.surface(color)


static func add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emit: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat(color, emit)
	mesh.mesh = box
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(mesh)
	body.add_child(col)
	parent.add_child(body)
	return body


static func add_collider(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)


static func industrial_env(fog: Color, dens: float) -> Environment:
	return LOOK.make_env(LOOK.KIND_YARD, fog, dens)


static func build_hangar_props(parent: Node3D, tier: int = 1) -> void:
	var steel := Color(0.28, 0.3, 0.33)
	var rust := Color(0.45, 0.25, 0.12)
	var dark := Color(0.12, 0.13, 0.14)
	var hazard := Color(0.85, 0.45, 0.08)
	add_box(parent, Vector3(-14, 1.2, -10), Vector3(4, 2.4, 2.2), steel)
	add_box(parent, Vector3(-14, 0.6, 8), Vector3(3.2, 1.2, 3.2), rust)
	add_box(parent, Vector3(12, 0.4, 8), Vector3(6, 0.8, 2.4), dark)
	add_box(parent, Vector3(0, 7.6, -13.4), Vector3(18, 0.35, 0.35), rust, 0.6)
	add_box(parent, Vector3(-8, 0.08, 0), Vector3(12, 0.04, 0.4), hazard, 0.8)
	add_collider(parent, Vector3(0, 5, -17), Vector3(42, 10, 0.5))
	add_collider(parent, Vector3(0, 5, 17), Vector3(42, 10, 0.5))
	add_collider(parent, Vector3(-21, 5, 0), Vector3(0.5, 10, 34))
	add_collider(parent, Vector3(21, 5, 0), Vector3(0.5, 10, 34))
	add_collider(parent, Vector3(0, 10.2, 0), Vector3(42, 0.4, 34))
	if tier >= 2:
		add_box(parent, Vector3(16, 2.2, -6), Vector3(5, 4.4, 8), Color(0.16, 0.17, 0.19))
		add_box(parent, Vector3(-16, 0.2, -4), Vector3(8, 0.2, 8), Color(0.2, 0.18, 0.12), 0.2)
	if tier >= 3:
		add_box(parent, Vector3(0, 12.4, 0), Vector3(6, 4, 6), Color(0.2, 0.14, 0.1))
		add_box(parent, Vector3(8, 1.0, -12), Vector3(3, 2, 3), steel)


static func build_raid_cover(parent: Node3D) -> void:
	var crate := Color(0.36, 0.32, 0.24)
	var concrete := Color(0.34, 0.35, 0.36)
	var rust := Color(0.42, 0.22, 0.1)
	var dark := Color(0.14, 0.14, 0.15)
	add_box(parent, Vector3(-28, 1.1, 4), Vector3(4.5, 2.2, 1.4), crate)
	add_box(parent, Vector3(-24, 0.7, -6), Vector3(2.4, 1.4, 3.8), concrete)
	add_box(parent, Vector3(-16, 1.5, 8), Vector3(3.2, 3.0, 3.2), rust)
	add_box(parent, Vector3(-8, 0.9, -14), Vector3(6.0, 1.8, 2.0), crate)
	add_box(parent, Vector3(6, 1.2, -8), Vector3(2.2, 2.4, 5.5), concrete)
	add_box(parent, Vector3(10, 0.8, 12), Vector3(5.0, 1.6, 2.2), dark)
	add_box(parent, Vector3(-4, 2.4, 16), Vector3(8.0, 4.8, 1.6), concrete)
	add_box(parent, Vector3(28, 1.0, -6), Vector3(3.0, 2.0, 3.0), rust)
	add_box(parent, Vector3(18, 0.5, 8), Vector3(4.0, 1.0, 1.2), crate)
	add_box(parent, Vector3(30, 1.4, 8), Vector3(1.2, 2.8, 10.0), concrete)
	add_box(parent, Vector3(-10, 0.12, 0), Vector3(72, 0.1, 0.45), Color(0.2, 0.2, 0.22))
	add_box(parent, Vector3(-10, 0.12, 6.5), Vector3(72, 0.1, 0.45), Color(0.2, 0.2, 0.22))
	add_box(parent, Vector3(-32, 6.0, -20), Vector3(2.4, 12.0, 2.4), Color(0.22, 0.2, 0.18))
	add_box(parent, Vector3(8, 9.0, 22), Vector3(3.0, 18.0, 3.0), Color(0.2, 0.18, 0.16))
	add_collider(parent, Vector3(0, 8, -45), Vector3(110, 16, 1.2))
	add_collider(parent, Vector3(0, 8, 45), Vector3(110, 16, 1.2))
	add_collider(parent, Vector3(-55, 8, 0), Vector3(1.2, 16, 90))
	add_collider(parent, Vector3(55, 8, 0), Vector3(1.2, 16, 90))
	add_collider(parent, Vector3(-6, 3.5, -22), Vector3(14, 7, 2.4))


static func build_pipeline(parent: Node3D) -> void:
	var rust := Color(0.4, 0.22, 0.12)
	var steel := Color(0.3, 0.32, 0.34)
	add_box(parent, Vector3(0, 8, 0), Vector3(80, 0.4, 6), steel)
	add_box(parent, Vector3(-20, 4, 0), Vector3(4, 8, 4), rust)
	add_box(parent, Vector3(20, 4, 0), Vector3(4, 8, 4), rust)
	add_box(parent, Vector3(0, 4, 14), Vector3(12, 8, 2), Color(0.25, 0.25, 0.26))
	add_box(parent, Vector3(0, 0.55, 11.2), Vector3(3.2, 1.1, 3.2), Color(0.18, 0.2, 0.16), 0.5)
	add_box(parent, Vector3(-8, 1, -12), Vector3(6, 2, 3), rust)
	add_box(parent, Vector3(14, 1.2, -16), Vector3(3, 2.4, 8), steel)
	add_collider(parent, Vector3(0, 10, -32), Vector3(90, 20, 1))
	add_collider(parent, Vector3(0, 10, 32), Vector3(90, 20, 1))
	add_collider(parent, Vector3(-40, 10, 0), Vector3(1, 20, 64))
	add_collider(parent, Vector3(40, 10, 0), Vector3(1, 20, 64))


static func build_range(parent: Node3D) -> void:
	var dark := Color(0.16, 0.16, 0.17)
	add_box(parent, Vector3(0, 1.2, -18), Vector3(8, 2.4, 1.2), dark)
	add_box(parent, Vector3(-6, 1.6, -28), Vector3(2, 3.2, 1), Color(0.7, 0.2, 0.1), 0.5)
	add_box(parent, Vector3(6, 1.6, -28), Vector3(2, 3.2, 1), Color(0.7, 0.2, 0.1), 0.5)
	add_box(parent, Vector3(0, 2.4, -36), Vector3(3, 4.8, 1.4), Color(0.55, 0.18, 0.1), 0.7)
	add_collider(parent, Vector3(-14, 6, -8), Vector3(0.6, 12, 28))
	add_collider(parent, Vector3(14, 6, -8), Vector3(0.6, 12, 28))
