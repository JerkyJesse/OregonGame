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


func _process(_delta: float) -> void:
	_sync_taken()


func get_interact_label() -> String:
	_sync_taken()
	if taken:
		return WorldLore.data_core_label(true)
	return WorldLore.data_core_label(false)


func interact(actor: Node) -> void:
	if taken:
		return
	if actor is Scavenger:
		hold_hack(actor, 0.0)


func hold_hack(actor: Node, delta: float) -> void:
	if taken:
		return
	var mech := get_parent()
	if mech and mech.has_method("hold_hack_core"):
		mech.call("hold_hack_core", actor, delta)
		_sync_taken()


func _sync_taken() -> void:
	var mech := get_parent()
	if mech != null and mech.get("core_taken") != null:
		taken = mech.get("core_taken") == true
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = not taken
