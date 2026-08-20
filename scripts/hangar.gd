extends Node3D

const LOOK := preload("res://world/WorldLook.gd")
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
	Hud.set_objective(WorldLore.hangar_objective(RunState.hangar_tier))
	Hud.refresh_carry()
	if has_node("Props"):
		Greybox.build_hangar_props($Props, RunState.hangar_tier)
	LOOK.apply(self, LOOK.KIND_HANGAR)
	_lights()
	var dodge := Label3D.new()
	dodge.text = "NEW DODGE"
	dodge.position = Vector3(0, 7.6, -16.4)
	dodge.font_size = 96
	dodge.modulate = Color(0.95, 0.55, 0.18)
	dodge.outline_size = 10
	dodge.outline_modulate = Color(0, 0, 0, 0.8)
	add_child(dodge)
	_park_frames()
	_spawn_vendor()
	_spawn_range()
	if has_node("DeployConsole"):
		var lab := Label3D.new()
		lab.text = "DEPLOY"
		lab.position = Vector3(0, 2.4, 0)
		lab.font_size = 64
		lab.modulate = Color(0.3, 0.9, 1.0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		$DeployConsole.add_child(lab)
	if has_node("Scavenger"):
		$Scavenger.position.y = 1.1
		$Scavenger.set("spawn_point", $Scavenger.position)
	if RunState.last_message != "":
		Hud.show_banner(RunState.last_message)
		var died := "died" in RunState.last_message.to_lower()
		Hud.set_sensors(WorldLore.tam_welcome(RunState.extracted_value, died))
		RunState.last_message = ""
	else:
		Hud.set_sensors(WorldLore.tam_idle())


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
	v.position = Vector3(14, 0, -13)
	_stall_box(v, Vector3(0, 1.1, -0.7), Vector3(2.2, 2.2, 0.35), Color(0.22, 0.28, 0.24))
	_stall_box(v, Vector3(-1.0, 1.0, 0.1), Vector3(0.3, 2.0, 1.4), Color(0.18, 0.2, 0.19))
	_stall_box(v, Vector3(1.0, 1.0, 0.1), Vector3(0.3, 2.0, 1.4), Color(0.18, 0.2, 0.19))
	_stall_box(v, Vector3(0, 0.35, 0.2), Vector3(1.8, 0.12, 1.1), Color(0.3, 0.22, 0.14))
	_stall_box(v, Vector3(0, 1.05, 0.15), Vector3(1.7, 0.1, 1.0), Color(0.28, 0.2, 0.12))
	_stall_box(v, Vector3(0, 1.7, 0.1), Vector3(1.6, 0.1, 0.9), Color(0.26, 0.18, 0.12))
	var stool := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.32
	cyl.height = 0.7
	cyl.material = Greybox.mat(Color(0.35, 0.32, 0.22))
	stool.mesh = cyl
	stool.position = Vector3(0.9, 0.35, 0.85)
	v.add_child(stool)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.4, 2.2, 1.8)
	col.shape = sh
	col.position.y = 1.1
	v.add_child(col)
	var lab := Label3D.new()
	lab.text = "TAM PICKS  ·  JUNK + FILTERS + PAINTS"
	if RunState.extracts_completed > 0:
		lab.text = "TAM PICKS  ·  restock after %d extract%s" % [RunState.extracts_completed, "" if RunState.extracts_completed == 1 else "s"]
	lab.position = Vector3(0, 2.55, 0)
	lab.font_size = 52
	lab.modulate = Color(0.75, 0.95, 0.7)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	v.add_child(lab)
	add_child(v)


func _stall_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = Greybox.mat(color, 0.15)
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)


func _spawn_range() -> void:
	var d: Node3D = (load("res://world/range_door.gd") as GDScript).new()
	d.position = Vector3(-12, 0, 12)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 3.2, 0.4)
	box.material = LOOK.emit_surface(Color(0.95, 0.42, 0.08), 1.6)
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
