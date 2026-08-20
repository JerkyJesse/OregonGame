extends StaticBody3D
class_name ShardDais

const LOOK := preload("res://world/WorldLook.gd")

var core_taken: bool = false
var taken: bool = false
var _hack: float = 0.0
var _spin: float = 0.0


func _ready() -> void:
	add_to_group("shard_dais")
	add_to_group("shard_socket")
	collision_layer = 9
	collision_mask = 0
	LOOK.dress_dais(self)


func _process(delta: float) -> void:
	_spin += delta
	var gone := core_taken or taken
	var crystal := get_node_or_null("LookDais/ShardCrystal") as MeshInstance3D
	if crystal:
		crystal.visible = not gone
		if not gone:
			crystal.rotate_y(delta * 1.15)
			crystal.position.y = 1.35 + sin(_spin * 2.4) * 0.1
	var glow := get_node_or_null("ShardGlow") as MeshInstance3D
	if glow:
		glow.visible = not gone
		if not gone:
			glow.rotate_y(delta * 0.8)
	var light := get_node_or_null("LookDais/ShardLight") as OmniLight3D
	if light:
		light.light_energy = 0.25 if gone else (3.8 + sin(_spin * 3.1) * 1.3)
		light.visible = not gone


func get_interact_label() -> String:
	return WorldLore.pump_house_label(core_taken or taken)


func interact(actor: Node) -> void:
	if core_taken or taken:
		return
	if actor is Scavenger:
		hold_hack(actor, 0.0)


func hold_hack(actor: Node, delta: float) -> bool:
	return hold_hack_core(actor, delta)


func hold_hack_core(scav: Node, delta: float) -> bool:
	if core_taken or taken:
		return false
	_hack += delta * RunState.hack_rate()
	Fx.play("hack")
	Hud.set_extract(_hack)
	Hud.set_prompt(WorldLore.pump_decrypting(_hack * 100.0))
	get_tree().call_group("heavy_mech", "alert_to", global_position)
	if _hack >= 1.0:
		_hack = 0.0
		core_taken = true
		taken = true
		Hud.set_extract(-1.0)
		var part := RunState.make_part("data_core", 0.92)
		if scav is Scavenger:
			if RunState.add_carry(part, true):
				Hud.refresh_carry()
				Hud.show_banner(WorldLore.pump_secured_banner())
			elif RunState.add_carry(part):
				Hud.refresh_carry()
				Hud.show_banner(WorldLore.core_carry_banner())
			else:
				core_taken = false
				taken = false
				Hud.show_banner("Carry full — shard snaps back into the dais.")
				return false
		Hud.set_sensors(WorldLore.first_voice_hack())
		Fx.play("alarm")
		Fx.burst(global_position + Vector3(0, 1.2, 0), LOOK.PALE)
		var scene := get_tree().current_scene if get_tree() else null
		if scene and scene.has_method("occupation_answer"):
			scene.call("occupation_answer", global_position)
		return true
	return false


func steal() -> Dictionary:
	if core_taken or taken:
		return {}
	core_taken = true
	taken = true
	_hack = 0.0
	Hud.set_sensors(WorldLore.first_voice_hack())
	Fx.play("alarm")
	var scene := get_tree().current_scene if get_tree() else null
	if scene and scene.has_method("occupation_answer"):
		scene.call("occupation_answer", global_position)
	return RunState.make_part("data_core", 0.8)


func reset_channels() -> void:
	if _hack > 0.0 and _hack < 1.0:
		_hack = maxf(_hack - 0.35, 0.0)
		if _hack <= 0.0:
			Hud.set_extract(-1.0)
