extends StaticBody3D


func _ready() -> void:
	add_to_group("deploy_console")
	collision_layer = 9
	collision_mask = 0


func get_interact_label() -> String:
	return WorldLore.deploy_console_label()


func interact(_actor: Node) -> void:
	Hud.open_deploy()
