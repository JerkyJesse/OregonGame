extends StaticBody3D
class_name RangeDoor


func _ready() -> void:
	collision_layer = 9
	collision_mask = 0
	add_to_group("range_door")


func get_interact_label() -> String:
	return "Test range  [E]  — first-person live fire"


func interact(_actor: Node) -> void:
	RunState.save_state()
	get_tree().change_scene_to_file("res://scenes/range.tscn")
