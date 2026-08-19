extends StaticBody3D


func _ready() -> void:
	add_to_group("deploy_console")
	collision_layer = 9
	collision_mask = 0


func get_interact_label() -> String:
	return "Deploy  [E] — choose scale, map, raid mode"


func interact(_actor: Node) -> void:
	Hud.open_deploy()
