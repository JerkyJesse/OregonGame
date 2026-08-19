extends Node3D

const RAID := preload("res://scripts/raid.gd")


func _ready() -> void:
	RunState.begin_raid()
	Hud.reset_for_scene()
	Hud.set_objective("PIPELINE CUT — catwalks above, scavs below. First-person. Strip, bolt, extract.")
	if has_node("WorldEnvironment"):
		($WorldEnvironment as WorldEnvironment).environment = Greybox.industrial_env(Color(0.28, 0.22, 0.18), 0.01)
	if has_node("Cover"):
		Greybox.build_pipeline($Cover)
	if has_node("LightMech"):
		$LightMech.hangar_preview = false
	if has_node("Scavenger"):
		match RunState.faction:
			"corporate":
				$Scavenger.position = Vector3(22, 8.4, 0)
			_:
				$Scavenger.position = Vector3(-22, 0.2, -10)
		if RunState.deploy_scale in ["light", "armor"] and has_node("LightMech"):
			$LightMech.power_armor = RunState.deploy_scale == "armor"
			$LightMech.board_pilot($Scavenger)
	var storm: Node3D = (load("res://world/toxic_storm.gd") as GDScript).new()
	add_child(storm)
