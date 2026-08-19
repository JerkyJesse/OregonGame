extends MachineBase
class_name LightMech


func _ready() -> void:
	scale_id = "armor" if power_armor else "light"
	cockpit_height = 1.35 if power_armor else 6.4
	cockpit_forward = 0.28 if power_armor else 0.55
	move_speed = 11.0 if power_armor else 9.0
	hull_max = RunState.cap(scale_id, "hull")
	hull = hull_max
	super._ready()
