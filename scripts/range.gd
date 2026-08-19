extends Node3D

const LIGHT_SCENE := preload("res://actors/light_mech.tscn")


func _ready() -> void:
	RunState.in_raid = false
	Hud.reset_for_scene()
	Hud.set_objective("TEST RANGE — first-person cockpit live fire. [F] dismount. Walk into the orange door volume to return.")
	if has_node("WorldEnvironment"):
		($WorldEnvironment as WorldEnvironment).environment = Greybox.industrial_env(Color(0.2, 0.18, 0.16), 0.003)
	if has_node("Props"):
		Greybox.build_range($Props)
	if has_node("LightMech"):
		$LightMech.hangar_preview = false
		if has_node("Scavenger"):
			$LightMech.board_pilot($Scavenger)
	_dummy_targets()


func _dummy_targets() -> void:
	for i in 3:
		var b: Node3D = (load("res://world/breakable.gd") as GDScript).new()
		b.position = Vector3(-6 + i * 6, 1.4, -30)
		b.hp = 50
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


func spawn_loot(_part: Dictionary, _pos: Vector3) -> void:
	pass


func _process(_delta: float) -> void:
	if has_node("Scavenger") and $Scavenger.global_position.z > 10.0:
		get_tree().change_scene_to_file("res://scenes/hangar.tscn")
