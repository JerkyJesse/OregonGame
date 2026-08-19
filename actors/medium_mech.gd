extends MachineBase
class_name MediumMech


func _ready() -> void:
	scale_id = "medium"
	cockpit_height = 10.45
	cockpit_forward = 2.05
	move_speed = 7.2
	hull_max = RunState.cap("medium", "hull")
	hull = hull_max
	super._ready()
