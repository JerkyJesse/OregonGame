extends Area3D
class_name DataCorePort

@export var attached_path: NodePath

var _progress: float = 0.0
var taken: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_interact_label() -> String:
	if taken:
		return WorldLore.data_core_label(true)
	return WorldLore.data_core_label(false)


func interact(actor: Node) -> void:
	if taken:
		return
	# Tap still nudges; hold is handled by looking + E in the machine bay / hold_hack_core.
	if actor is Scavenger:
		var mech := get_parent()
		if mech and mech.has_method("hold_hack_core"):
			mech.call("hold_hack_core", actor, 0.22)
