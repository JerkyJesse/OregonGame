extends Area3D
class_name RangeExit


func _ready() -> void:
	add_to_group("range_exit")
	collision_layer = 8
	collision_mask = 6
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Scavenger and not (body as Scavenger).boarded:
		_go_hangar()
		return
	if body.is_in_group("machine") and bool(body.get("boarded")):
		_go_hangar()


func _go_hangar() -> void:
	RunState.save_state()
	get_tree().change_scene_to_file("res://scenes/hangar.tscn")
