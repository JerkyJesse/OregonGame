extends Node3D
class_name ToxicStorm

var radius: float = 70.0
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group("storm")


func _process(delta: float) -> void:
	if not RunState.in_raid:
		return
	_pulse += delta
	radius = maxf(18.0, 70.0 - RunState.raid_timer * 0.35)
	if int(_pulse * 2.0) % 2 == 0:
		pass
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node3D:
			var p := n as Node3D
			var d := Vector2(p.global_position.x, p.global_position.z).length()
			if d > radius:
				if n is Scavenger:
					(n as Scavenger).take_damage(14.0 * delta)
				elif n.is_in_group("machine"):
					n.call("take_damage", 8.0 * delta)
				Hud.show_banner("TOXIC STORM — get inside the circle")


func current_radius() -> float:
	return radius
