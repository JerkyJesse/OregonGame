extends StaticBody3D
class_name VendorStall


func _ready() -> void:
	add_to_group("vendor")
	collision_layer = 9
	collision_mask = 0


func get_interact_label() -> String:
	return WorldLore.vendor_label()


func interact(_actor: Node) -> void:
	Hud.open_vendor()
