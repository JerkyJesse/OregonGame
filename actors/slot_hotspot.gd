extends Area3D
class_name SlotHotspot

@export var slot: String = "chest"


func _ready() -> void:
	add_to_group("slot_hotspot")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func configure(hangar: bool, raid_usable: bool) -> void:
	monitorable = hangar or raid_usable
	collision_layer = 8 if (hangar or raid_usable) else 0


func configure_for_hangar(enabled: bool) -> void:
	configure(enabled, enabled)


func get_interact_label() -> String:
	var mech: Node = _mech()
	if mech == null:
		return ""
	var pretty := slot.to_upper().replace("_", " ")
	var pack: Variant = mech.get("equipped")
	var equipped: Variant = {}
	if pack is Dictionary:
		equipped = (pack as Dictionary).get(slot, {})
	if bool(mech.get("hangar_preview")):
		if equipped is Dictionary and not (equipped as Dictionary).is_empty():
			return "%s: %s  [E] change" % [pretty, equipped.get("display_name", "?")]
		return "Empty %s  [E] install" % pretty
	var hp_pack: Variant = mech.get("section_hp")
	var hp := 1.0
	if hp_pack is Dictionary:
		hp = float((hp_pack as Dictionary).get(slot, 1.0))
	if hp <= 0.0:
		return "%s wrecked" % pretty
	if equipped is Dictionary and not (equipped as Dictionary).is_empty():
		var crack := "  CRACKING" if hp < 28.0 else ""
		return "Strip %s (%s %.0f%s, %.0f%%)  [E]" % [equipped.get("display_name", "?"), pretty, hp, crack, float(equipped.get("condition", 1.0)) * 100.0]
	var carry := _matching_carry()
	if not carry.is_empty():
		return "Bolt %s onto %s  [E]" % [carry.get("display_name", "?"), pretty]
	return "Empty %s hardpoint" % pretty


func interact(actor: Node) -> void:
	var mech: Node = _mech()
	if mech == null:
		return
	if bool(mech.get("hangar_preview")):
		Hud.open_slot_picker(slot, str(mech.get("scale_id")))
		return
	if not actor is Scavenger:
		return
	var pack: Variant = mech.get("equipped")
	var equipped: Variant = {}
	if pack is Dictionary:
		equipped = (pack as Dictionary).get(slot, {})
	if equipped is Dictionary and not (equipped as Dictionary).is_empty():
		var taken: Dictionary = mech.call("field_strip", slot)
		if taken.is_empty():
			return
		if RunState.add_carry(taken):
			Hud.refresh_carry()
			Hud.show_banner("Stripped %s — now it's yours." % taken.get("display_name", "part"))
			Fx.play("ui")
		else:
			mech.call("field_install", taken)
			Hud.show_banner("Carry full.")
		return
	var carry := _matching_carry()
	if carry.is_empty():
		Hud.show_banner("No compatible part in carry for %s." % slot)
		return
	if not RunState.scale_ok(carry, str(mech.get("scale_id"))):
		Hud.show_banner("Incompatible with this chassis.")
		return
	_remove_carry(str(carry.get("uid", "")))
	if bool(mech.call("field_install", carry)):
		Hud.refresh_carry()
		Hud.show_banner("Bolted %s onto the %s." % [carry.get("display_name", "part"), str(mech.get("scale_id"))])


func _matching_carry() -> Dictionary:
	var mech: Node = _mech()
	if mech == null:
		return {}
	var bags: Array[Dictionary] = []
	bags.append_array(RunState.raid_carry)
	bags.append_array(RunState.secure_carry)
	for part in bags:
		if str(part.get("slot", "")) == slot and RunState.scale_ok(part, str(mech.get("scale_id"))):
			return part
	return {}


func _remove_carry(uid: String) -> void:
	for i in RunState.raid_carry.size():
		if str(RunState.raid_carry[i].get("uid", "")) == uid:
			RunState.raid_carry.remove_at(i)
			return
	for i in RunState.secure_carry.size():
		if str(RunState.secure_carry[i].get("uid", "")) == uid:
			RunState.secure_carry.remove_at(i)
			return


func _mech() -> Node:
	var n := get_parent()
	while n:
		if n.is_in_group("machine"):
			return n
		n = n.get_parent()
	return null
