extends MachineBase
class_name Hauler


func _ready() -> void:
	scale_id = "vehicle"
	cockpit_height = 2.55
	cockpit_forward = 3.85
	move_speed = 12.5
	hull_max = RunState.cap("vehicle", "hull")
	hull = hull_max
	add_to_group("hauler")
	super._ready()


func get_interact_label() -> String:
	if hangar_preview:
		return "Hauler workshop  [E]"
	if boarded:
		return ""
	if disabled or not alive:
		return "Dead hauler  [E] strip  [G] hold hotwire"
	return "Board hauler cab  [E]/[F]   [G] tow wrecks while driving"
