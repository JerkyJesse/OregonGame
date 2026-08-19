extends MachineBase
class_name LightMech


func _ready() -> void:
	apply_power_armor_frame()
	super._ready()


func apply_power_armor_frame() -> void:
	if power_armor:
		scale_id = "armor"
		scale = Vector3(0.24, 0.24, 0.24)
		move_speed = 8.8
	else:
		scale_id = "light"
		scale = Vector3.ONE
		move_speed = 9.0
	cockpit_height = 7.4
	cockpit_forward = 1.55
	hull_max = RunState.cap(scale_id, "hull")
	_base_hull = hull_max
	hull = hull_max
	if is_inside_tree() and _cockpit:
		_cockpit.position = Vector3(0.0, cockpit_height, cockpit_forward)
		if power_armor:
			add_to_group("power_armor")
