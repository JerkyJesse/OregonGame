extends Node3D

const LOOK := preload("res://world/WorldLook.gd")
const RD := preload("res://scripts/raid_director.gd")


func _enter_tree() -> void:
	Hud.enter_gameplay()


func _ready() -> void:
	RunState.in_raid = false
	Hud.enter_gameplay()
	Hud.reset_for_scene()
	Hud.set_objective(WorldLore.range_objective())
	if has_node("Props"):
		Greybox.build_range($Props)
	LOOK.apply(self, LOOK.KIND_RANGE)
	if has_node("LightMech"):
		$LightMech.hangar_preview = false
		$LightMech.disabled = false
		$LightMech.alive = true
		if has_node("Scavenger"):
			$LightMech.board_pilot($Scavenger)
	_dummy_targets()
	_spawn_exit()


func _dummy_targets() -> void:
	for i in 3:
		var b: Node3D = (load("res://world/breakable.gd") as GDScript).new()
		b.position = Vector3(-6 + i * 6, 1.4, -30)
		b.set("hp", 50)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 2.8, 0.6)
		box.material = Greybox.mat(Color(0.8, 0.2, 0.1), 0.6)
		mesh.mesh = box
		b.add_child(mesh)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.6, 2.8, 0.6)
		col.shape = sh
		b.add_child(col)
		add_child(b)


func spawn_loot(part: Dictionary, pos: Vector3) -> void:
	RD.spawn_loot(self, part, pos)


func _spawn_exit() -> void:
	var exit: Area3D = (load("res://world/range_exit.gd") as GDScript).new()
	exit.position = Vector3(0, 0, 12)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 3.2, 1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.45, 0.08, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 1.4
	box.material = mat
	mesh.mesh = box
	mesh.position.y = 1.6
	exit.add_child(mesh)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(6, 3.2, 1.6)
	col.shape = sh
	col.position.y = 1.6
	exit.add_child(col)
	var lab := Label3D.new()
	lab.text = "RETURN TO HANGAR"
	lab.position = Vector3(0, 3.4, 0)
	lab.font_size = 48
	lab.modulate = Color(1, 0.7, 0.2)
	exit.add_child(lab)
	add_child(exit)
