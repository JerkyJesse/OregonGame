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
		return "Core socket empty"
	return "Hack data core  [E] hold  — you are exposed"


func interact(actor: Node) -> void:
	if taken:
		return
	_progress += 0.22
	Fx.play("hack")
	Hud.set_extract(_progress)
	Hud.set_prompt("Decrypting core… don't get shot")
	get_tree().call_group("heavy_mech", "alert_to", global_position)
	if _progress >= 1.0:
		taken = true
		Hud.set_extract(-1.0)
		var part := RunState.make_part("data_core", 0.9)
		if actor is Scavenger:
			if RunState.add_carry(part, true):
				Hud.refresh_carry()
				Hud.show_banner("Data core in secure slot.")
			elif RunState.add_carry(part):
				Hud.refresh_carry()
				Hud.show_banner("Data core — extract it or die trying.")
		visible = false
