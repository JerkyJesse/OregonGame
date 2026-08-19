extends Node3D

const LIGHT_SCENE := preload("res://actors/light_mech.tscn")
const MEDIUM_SCENE := preload("res://actors/medium_mech.tscn")
const HEAVY_SCENE := preload("res://actors/heavy_mech.tscn")
const HAULER_SCENE := preload("res://actors/hauler.tscn")


func _enter_tree() -> void:
	Hud.enter_gameplay()


func _ready() -> void:
	RunState.in_raid = false
	Hud.enter_gameplay()
	Hud.reset_for_scene()
	Hud.set_objective("HANGAR TIER %d  — bolt parts [E] on frames. Deploy at the console. Range door. Vendor." % RunState.hangar_tier)
	Hud.refresh_carry()
	_lights()
	if has_node("WorldEnvironment"):
		($WorldEnvironment as WorldEnvironment).environment = Greybox.industrial_env(Color(0.18, 0.16, 0.14), 0.004)
	if has_node("Props"):
		Greybox.build_hangar_props($Props, RunState.hangar_tier)
	_park_frames()
	_spawn_vendor()
	_spawn_range()
	if RunState.last_message != "":
		Hud.show_banner(RunState.last_message)
		RunState.last_message = ""


func _lights() -> void:
	if has_node("BayLight"):
		($BayLight as OmniLight3D).light_color = Color(1.0, 0.55, 0.22)
		($BayLight as OmniLight3D).light_energy = 7.5
	if has_node("Sun"):
		($Sun as DirectionalLight3D).light_color = Color(1.0, 0.78, 0.55)


func _park_frames() -> void:
	if has_node("LightMech"):
		$LightMech.hangar_preview = true
		$LightMech.power_armor = false
		$LightMech.scale_id = "light"
		$LightMech.apply_loadout()
	var armor: Node3D = LIGHT_SCENE.instantiate()
	armor.set("hangar_preview", true)
	armor.set("power_armor", true)
	armor.position = Vector3(-6, 0, 2)
	add_child(armor)
	if RunState.hangar_tier >= 2 or RunState.scale_unlocked("medium"):
		var med: Node3D = MEDIUM_SCENE.instantiate()
		med.set("hangar_preview", true)
		med.position = Vector3(8, 0, -4)
		add_child(med)
		var haul: Node3D = HAULER_SCENE.instantiate()
		haul.set("hangar_preview", true)
		haul.position = Vector3(-10, 0, -6)
		add_child(haul)
	if RunState.hangar_tier >= 3 or RunState.scale_unlocked("heavy"):
		var hv: Node3D = HEAVY_SCENE.instantiate()
		hv.set("hangar_preview", true)
		hv.set("ai_controlled", false)
		hv.position = Vector3(0, 0, -10)
		add_child(hv)


func _spawn_vendor() -> void:
	var v: Node3D = (load("res://world/vendor.gd") as GDScript).new()
	v.position = Vector3(12, 0, 12)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 1.8, 1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 0.28)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 0.3)
	mat.emission_energy_multiplier = 0.8
	box.material = mat
	mesh.mesh = box
	mesh.position.y = 0.9
	v.add_child(mesh)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.6, 1.8, 1.2)
	col.shape = sh
	col.position.y = 0.9
	v.add_child(col)
	add_child(v)


func _spawn_range() -> void:
	var d: Node3D = (load("res://world/range_door.gd") as GDScript).new()
	d.position = Vector3(-12, 0, 12)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 3.2, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.35, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.4, 0.1)
	mat.emission_energy_multiplier = 1.1
	box.material = mat
	mesh.mesh = box
	mesh.position.y = 1.6
	d.add_child(mesh)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.2, 3.2, 0.4)
	col.shape = sh
	col.position.y = 1.6
	d.add_child(col)
	add_child(d)
