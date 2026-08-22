class_name Greybox
extends RefCounted

const LOOK := preload("res://world/WorldLook.gd")


static func mat(color: Color, emit: float = 0.0) -> Material:
	if emit > 0.0:
		return LOOK.emit_surface(color, emit)
	return LOOK.surface(color)


static func add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emit: float = 0.0, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot
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
	add_box(parent, Vector3(14, 1.1, -13.6), Vector3(3.4, 2.2, 0.35), Color(0.22, 0.28, 0.24), 0.15)
	sign_at(parent, Vector3(14, 2.8, -13.4), "NORTH WALL  ·  TAM'S STALL", Color(0.75, 0.95, 0.7))
	sign_at(parent, Vector3(0, 8.4, -13.2), "BAY TIER %d" % clampi(tier, 1, 3), Color(0.95, 0.62, 0.22))
	add_collider(parent, Vector3(0, 5, -17), Vector3(42, 10, 0.5))
	add_collider(parent, Vector3(0, 5, 17), Vector3(42, 10, 0.5))
	add_collider(parent, Vector3(-21, 5, 0), Vector3(0.5, 10, 34))
	add_collider(parent, Vector3(21, 5, 0), Vector3(0.5, 10, 34))
	add_collider(parent, Vector3(0, 10.2, 0), Vector3(42, 0.4, 34))
	# Tier 1: cramped scav bay
	add_box(parent, Vector3(-10, 0.35, -8), Vector3(3.2, 0.7, 2.4), Color(0.2, 0.18, 0.14))
	add_box(parent, Vector3(6, 0.9, 10), Vector3(2.0, 1.8, 1.4), steel)
	_barrel_stack(parent, Vector3(-12, 0, 6))
	if tier >= 2:
		add_box(parent, Vector3(16, 2.2, -6), Vector3(5, 4.4, 8), Color(0.16, 0.17, 0.19))
		add_box(parent, Vector3(-16, 0.2, -4), Vector3(8, 0.2, 8), Color(0.2, 0.18, 0.12), 0.2)
		add_box(parent, Vector3(-16, 2.4, 6), Vector3(4.5, 4.8, 5.5), Color(0.18, 0.19, 0.21))
		sign_at(parent, Vector3(-16, 5.2, 6), "MEDIUM PAD + HAULER LANE", Color(0.55, 0.85, 1.0))
		add_box(parent, Vector3(10, 0.08, -2), Vector3(10, 0.04, 0.35), Color(0.2, 0.7, 0.85), 0.9)
	if tier >= 3:
		add_box(parent, Vector3(0, 12.4, 0), Vector3(6, 4, 6), Color(0.2, 0.14, 0.1))
		add_box(parent, Vector3(8, 1.0, -12), Vector3(3, 2, 3), steel)
		add_box(parent, Vector3(0, 0.15, -8), Vector3(14, 0.12, 8), Color(0.14, 0.14, 0.15), 0.35)
		sign_at(parent, Vector3(0, 5.6, -10), "HEAVY CRANE BAY — LIVE", Color(0.95, 0.45, 0.2))
		add_crane(parent, Vector3(4, 0, -9), 0.0)


static func add_sealed_pocket(parent: Node3D, pos: Vector3, size: Vector3, label: String) -> void:
	var steel := Color(0.16, 0.17, 0.18)
	var rim := Color(0.35, 0.72, 0.85)
	# Shell walls — leave a doorway on +Z
	add_box(parent, pos + Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.15), Vector3(size.x, size.y, 0.35), steel)
	add_box(parent, pos + Vector3(-size.x * 0.5 + 0.15, size.y * 0.5, 0), Vector3(0.35, size.y, size.z), steel)
	add_box(parent, pos + Vector3(size.x * 0.5 - 0.15, size.y * 0.5, 0), Vector3(0.35, size.y, size.z), steel)
	add_box(parent, pos + Vector3(0, size.y + 0.1, 0), Vector3(size.x, 0.25, size.z), steel, 0.2)
	add_box(parent, pos + Vector3(0, 0.05, 0), Vector3(size.x - 0.4, 0.08, size.z - 0.4), Color(0.12, 0.14, 0.15), 0.15)
	sign_at(parent, pos + Vector3(0, size.y + 0.8, size.z * 0.55), label, rim)
	var pocket: Area3D = (load("res://world/sealed_pocket.gd") as GDScript).new()
	pocket.position = pos + Vector3(0, size.y * 0.45, 0)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(size.x - 0.6, size.y * 0.9, size.z - 0.6)
	col.shape = sh
	pocket.add_child(col)
	parent.add_child(pocket)


static func add_filter_landmark(parent: Node3D, pos: Vector3, label: String = "SEALED-AIR CACHE") -> void:
	var can := Color(0.35, 0.75, 0.4)
	add_box(parent, pos + Vector3(0, 0.7, 0), Vector3(1.1, 1.4, 1.1), Color(0.22, 0.28, 0.22), 0.35)
	LOOK.add_cyl(parent, pos + Vector3(0, 1.55, 0), 0.55, 0.28, can, Vector3.ZERO, 1.2)
	sign_at(parent, pos + Vector3(0, 2.4, 0), label, Color(0.55, 0.95, 0.45))


static func sign_at(parent: Node3D, pos: Vector3, text: String, color: Color) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.position = pos
	lab.font_size = 52
	lab.modulate = color
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.outline_size = 8
	lab.outline_modulate = Color(0, 0, 0, 0.85)
	parent.add_child(lab)


static func add_crane(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var rust := Color(0.4, 0.22, 0.1)
	var steel := Color(0.26, 0.28, 0.3)
	add_box(parent, pos + Vector3(0, 7.2, 0), Vector3(1.6, 14.4, 1.6), rust)
	add_box(parent, pos + Vector3(0, 14.4, 0), Vector3(2.4, 0.7, 2.4), steel)
	add_box(parent, pos + Vector3(0, 13.2, 0), Vector3(3.2, 0.35, 3.2), Color(0.18, 0.18, 0.2))
	add_box(parent, pos + Vector3(0.9, 11.2, 0), Vector3(1.4, 1.8, 1.6), Color(0.22, 0.2, 0.16), 0.15)
	var rad := deg_to_rad(yaw)
	var boom := Vector3(cos(rad) * 7.0, 14.2, sin(rad) * 7.0)
	add_box(parent, pos + boom, Vector3(14.0, 0.55, 0.7), steel, 0.0, Vector3(0, yaw, 8))
	add_box(parent, pos + boom * 0.45 + Vector3(0, 0.4, 0), Vector3(0.35, 0.35, 0.35), Color(0.12, 0.12, 0.12))
	add_box(parent, pos + boom + Vector3(0, -3.5, 0), Vector3(0.2, 7.0, 0.2), Color(0.12, 0.12, 0.12))
	add_box(parent, pos + boom + Vector3(0, -7.1, 0), Vector3(1.6, 0.35, 1.1), rust)


static func add_stairs(parent: Node3D, origin: Vector3, along: Vector3, steps: int, step_h: float, step_d: float, width: float, color: Color) -> void:
	var n := along.normalized()
	var side := Vector3(-n.z, 0, n.x)
	for i in steps:
		var t := float(i) + 0.5
		var p := origin + n * (step_d * t) + Vector3(0, step_h * t, 0)
		var size := Vector3(abs(n.x) * step_d + abs(side.x) * width, step_h, abs(n.z) * step_d + abs(side.z) * width)
		if size.x < 0.4:
			size.x = width
		if size.z < 0.4:
			size.z = width
		add_box(parent, p, size, color)


static func build_raid_cover(parent: Node3D) -> void:
	var crate := Color(0.36, 0.32, 0.24)
	var concrete := Color(0.34, 0.35, 0.36)
	var rust := Color(0.42, 0.22, 0.1)
	var dark := Color(0.14, 0.14, 0.15)
	var rail := Color(0.18, 0.18, 0.2)
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
	for z in [0.0, 3.2, 6.5]:
		add_box(parent, Vector3(0, 0.1, z), Vector3(96, 0.12, 0.55), rail)
	for i in 7:
		add_box(parent, Vector3(-42.0 + float(i) * 14.0, 0.22, 3.2), Vector3(1.1, 0.35, 8.2), Color(0.22, 0.2, 0.18))
	for i in 4:
		add_crane(parent, Vector3(-30.0 + float(i) * 16.0, 0, -26), 90.0 if i % 2 == 0 else 75.0)
	add_box(parent, Vector3(38, 0.08, 0), Vector3(8, 0.06, 8), Color(0.18, 0.55, 0.22), 0.8)
	add_box(parent, Vector3(-38, 0.08, -18), Vector3(8, 0.06, 8), Color(0.7, 0.22, 0.14), 0.6)
	add_box(parent, Vector3(-32, 6.0, -20), Vector3(2.4, 12.0, 2.4), Color(0.22, 0.2, 0.18))
	add_box(parent, Vector3(8, 9.0, 22), Vector3(3.0, 18.0, 3.0), Color(0.2, 0.18, 0.16))
	_barrel_stack(parent, Vector3(14, 0, 6))
	_barrel_stack(parent, Vector3(-12, 0, -10))
	_barrel_stack(parent, Vector3(24, 0, -16))
	sign_at(parent, Vector3(-6, 9.5, -26), "CRANE-ROW", Color(0.9, 0.55, 0.2))
	sign_at(parent, Vector3(38, 3.4, 0), "EAST GREEN EXTRACT", Color(0.35, 0.95, 0.4))
	sign_at(parent, Vector3(-38, 3.4, -18), "WEST PAD — BRASK TAX", Color(0.95, 0.35, 0.18))
	sign_at(parent, Vector3(0, 4.2, 3.2), "ASH YARD 7  ·  RAIL SPINE", Color(0.85, 0.72, 0.4))
	sign_at(parent, Vector3(-22, 5.2, 14), "KNEELING MEDIUM — STRIP ZONE", Color(0.85, 0.5, 0.25))
	sign_at(parent, Vector3(18, 3.8, -14), "PARKED LIGHT — BOLT GUN", Color(0.95, 0.65, 0.3))
	sign_at(parent, Vector3(-40, 2.6, 16), "BLUE STEALTH EXTRACT", Color(0.35, 0.7, 1.0))
	# Kneeling wreck silhouette prop for yard identity
	add_box(parent, Vector3(-18, 2.2, 12), Vector3(3.2, 4.4, 5.5), Color(0.22, 0.2, 0.18))
	add_box(parent, Vector3(-18, 0.9, 15.5), Vector3(1.4, 1.8, 2.2), rust)
	add_box(parent, Vector3(-18, 4.8, 10.2), Vector3(1.2, 1.2, 4.0), Color(0.28, 0.26, 0.24), 0.0, Vector3(0, 0, 35))
	# Sealed-steel pockets + filter landmarks
	add_sealed_pocket(parent, Vector3(-22, 0, 22), Vector3(6.5, 3.2, 5.5), "SEALED STEEL — filter holds")
	add_filter_landmark(parent, Vector3(-18.5, 0, 24.2), "FILTER CACHE")
	add_sealed_pocket(parent, Vector3(22, 0, -20), Vector3(5.5, 3.0, 5.0), "SEALED BUNKER — White Lung blind")
	add_filter_landmark(parent, Vector3(24.5, 0, -17.5), "SEALED-AIR CAN")
	add_collider(parent, Vector3(0, 8, -45), Vector3(110, 16, 1.2))
	add_collider(parent, Vector3(0, 8, 45), Vector3(110, 16, 1.2))
	add_collider(parent, Vector3(-55, 8, 0), Vector3(1.2, 16, 90))
	add_collider(parent, Vector3(55, 8, 0), Vector3(1.2, 16, 90))
	add_collider(parent, Vector3(-6, 3.5, -22), Vector3(14, 7, 2.4))


static func build_pipeline(parent: Node3D) -> void:
	var rust := Color(0.4, 0.22, 0.12)
	var steel := Color(0.3, 0.32, 0.34)
	var dark := Color(0.16, 0.16, 0.17)
	add_box(parent, Vector3(0, 8, 0), Vector3(80, 0.45, 6.2), steel)
	add_box(parent, Vector3(0, 8.95, 2.9), Vector3(80, 0.9, 0.12), dark)
	add_box(parent, Vector3(0, 8.95, -2.9), Vector3(80, 0.9, 0.12), dark)
	add_box(parent, Vector3(-20, 4, 0), Vector3(4, 8, 4), rust)
	add_box(parent, Vector3(20, 4, 0), Vector3(4, 8, 4), rust)
	add_box(parent, Vector3(0, 4, 14), Vector3(12, 8, 2.4), Color(0.25, 0.25, 0.26))
	add_box(parent, Vector3(0, 0.55, 11.2), Vector3(3.2, 1.1, 3.2), Color(0.18, 0.2, 0.16), 0.5)
	add_box(parent, Vector3(-8, 1, -12), Vector3(6, 2, 3), rust)
	add_box(parent, Vector3(14, 1.2, -16), Vector3(3, 2.4, 8), steel)
	add_stairs(parent, Vector3(10, 0, 8), Vector3(0, 0, -1), 10, 0.82, 1.05, 2.2, steel)
	add_stairs(parent, Vector3(-10, 0, -8), Vector3(0, 0, 1), 10, 0.82, 1.05, 2.2, steel)
	LOOK.add_cyl(parent, Vector3(0, 5.5, -24), 88.0, 3.4, rust, Vector3(0, 0, 90))
	LOOK.add_cyl(parent, Vector3(0, 7.2, -24), 88.0, 1.1, steel, Vector3(0, 0, 90), 0.12)
	sign_at(parent, Vector3(0, 10.6, 14), "PUMP HOUSE 3", Color(0.5, 1.0, 0.42))
	sign_at(parent, Vector3(0, 10.2, 0), "CATWALKS  ·  HUSKS BELOW", Color(0.9, 0.7, 0.35))
	sign_at(parent, Vector3(0, 9.5, -24), "ATMOSPHERE SPINE", Color(0.75, 0.45, 0.2))
	sign_at(parent, Vector3(-20, 9.2, 0), "BREACH RISK — FILTER ON", Color(0.95, 0.4, 0.25))
	sign_at(parent, Vector3(20, 9.2, 0), "FUEL RISER — STRIP / EXTRACT", Color(0.45, 0.85, 0.95))
	add_box(parent, Vector3(-6, 1.2, 18), Vector3(2.4, 2.4, 2.4), Color(0.2, 0.28, 0.18), 0.4)
	add_sealed_pocket(parent, Vector3(-24, 0, -18), Vector3(5.5, 3.0, 4.8), "SEALED STEEL — under the pipe")
	add_filter_landmark(parent, Vector3(-21, 0, -15.5), "FILTER CACHE")
	add_sealed_pocket(parent, Vector3(22, 0, 18), Vector3(5.0, 3.0, 4.5), "PUMP HOUSE ANNEX — sealed")
	add_filter_landmark(parent, Vector3(19.5, 0, 20.5))
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


static func _barrel_stack(parent: Node3D, pos: Vector3) -> void:
	var rust := Color(0.42, 0.22, 0.1)
	LOOK.add_cyl(parent, pos + Vector3(0, 0.7, 0), 1.4, 0.42, rust)
	LOOK.add_cyl(parent, pos + Vector3(0.7, 0.55, 0.15), 1.1, 0.36, Color(0.28, 0.18, 0.1))
	LOOK.add_cyl(parent, pos + Vector3(-0.55, 0.45, 0.4), 0.9, 0.32, Color(0.2, 0.2, 0.18), Vector3.ZERO, 0.2)
	add_collider(parent, pos + Vector3(0.1, 0.7, 0.15), Vector3(1.8, 1.4, 1.4))
