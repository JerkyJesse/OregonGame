extends Node
class_name YardBand

var _cd: float = 7.0


func _ready() -> void:
	add_to_group("yard_band")
	Hud.set_sensors(WorldLore.yard_open_band(RunState.raid_map, RunState.raid_mode))


func _process(delta: float) -> void:
	if not RunState.in_raid:
		return
	_cd -= delta
	if _cd > 0.0:
		return
	_cd = randf_range(16.0, 28.0)
	Hud.set_sensors(WorldLore.yard_band_line())
	Fx.play("radio")


func push(line: String) -> void:
	if line == "":
		return
	_cd = randf_range(18.0, 30.0)
	Hud.set_sensors(line)
	Fx.play("radio")
