extends StaticBody3D

@export var part_id: String = "vulcan_chest"
@export var extra_ids: PackedStringArray = PackedStringArray()

var looted: bool = false
var remaining: Array[String] = []

@onready var _loot_mesh: MeshInstance3D = get_node_or_null("LootGlow")


func _ready() -> void:
	add_to_group("loot")
	collision_layer = 9
	collision_mask = 0
	remaining.append(part_id)
	for id in extra_ids:
		remaining.append(id)


func get_interact_label() -> String:
	if remaining.is_empty() or looted:
		return "Wreck stripped clean"
	return "Loot %s  [E]  (%d left)" % [RunState.part_display_name(remaining[0]), remaining.size()]


func interact(_actor: Node) -> void:
	if remaining.is_empty():
		looted = true
		return
	var id := remaining[0]
	remaining.remove_at(0)
	var part := RunState.make_part(id, randf_range(0.45, 0.92))
	if part.is_empty():
		return
	if not RunState.add_carry(part):
		remaining.insert(0, id)
		Hud.show_banner("Carry full.")
		return
	Hud.refresh_carry()
	Hud.show_banner("Picked up %s" % part.get("display_name", "part"))
	Fx.play("ui")
	if remaining.is_empty():
		looted = true
		if _loot_mesh:
			_loot_mesh.visible = false


func ai_steal() -> void:
	if remaining.is_empty():
		return
	remaining.remove_at(0)
	if remaining.is_empty() and _loot_mesh:
		_loot_mesh.visible = false
		looted = true
