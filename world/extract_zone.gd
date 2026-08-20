extends Area3D

const LOOK := preload("res://world/WorldLook.gd")

@export var extract_type: String = "contested"
@export var channel_time: float = 3.0

var tax_gate: Node
var tax_paid: bool = false
var _inside: Array[Node] = []
var _progress: float = 0.0
var _waive_shown: bool = false
var _pulse: float = 0.0
var _alarmed: bool = false


func _ready() -> void:
	add_to_group("extract_zone")
	collision_layer = 8
	collision_mask = 6
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_paint()


func _paint() -> void:
	var col := Color(0.2, 0.75, 0.35)
	match extract_type:
		"stealth":
			col = Color(0.2, 0.45, 0.7)
			channel_time = 6.5
		"contested":
			col = Color(0.25, 0.8, 0.3)
			channel_time = 3.2
		"payload":
			col = Color(0.85, 0.75, 0.15)
			channel_time = 4.5
		"vehicle":
			col = Color(0.75, 0.45, 0.15)
			channel_time = 2.2
		"tax":
			col = Color(0.72, 0.22, 0.16)
			channel_time = 3.6
	if has_node("OmniLight3D"):
		($OmniLight3D as OmniLight3D).light_color = col
		($OmniLight3D as OmniLight3D).light_volumetric_fog_energy = 1.8
	LOOK.dress_extract(self, col)
	_ensure_title(col)


func _on_body_entered(body: Node) -> void:
	if _is_extractor(body) and not _inside.has(body):
		_inside.append(body)


func _on_body_exited(body: Node) -> void:
	_inside.erase(body)
	if _inside.is_empty():
		_progress = 0.0
		_alarmed = false
		Hud.set_extract(-1.0)


func _is_extractor(body: Node) -> bool:
	if body is Scavenger:
		return not (body as Scavenger).boarded
	if body.is_in_group("machine"):
		return bool(body.get("boarded"))
	return body.is_in_group("player")


func _process(delta: float) -> void:
	_pulse += delta
	if has_node("OmniLight3D"):
		($OmniLight3D as OmniLight3D).light_energy = 3.4 + sin(_pulse * 2.8) * 1.5
	if has_node("Beacon"):
		var s := 1.0 + sin(_pulse * 2.8) * 0.07
		$Beacon.scale = Vector3(s, 1.0, s)
	_purge_invalid()
	if _inside.is_empty() or Hud.ui_busy:
		return
	if extract_type == "tax" and not _tax_clear():
		_handle_tax()
		return
	if extract_type == "payload" and not _has_payload():
		Hud.set_prompt(WorldLore.payload_need_prompt())
		return
	if extract_type == "vehicle" and not _has_hauler():
		Hud.set_prompt("VEHICLE LZ — board the hauler")
		return
	var label := WorldLore.extract_title(extract_type)
	Hud.set_prompt("Hold [E]  %s extract" % label)
	if Input.is_action_pressed("interact"):
		if extract_type == "contested" and not _alarmed:
			_alarmed = true
			get_tree().call_group("heavy_mech", "alert_to", global_position)
			get_tree().call_group("ai_scavenger", "alert_to", global_position)
			Fx.play("alarm")
		var mul := 1.0
		if extract_type == "vehicle" and _has_hauler():
			mul = 1.35
		_progress += delta / channel_time * mul
		Hud.set_extract(_progress)
		Hud.set_prompt("Extracting %s…  %.0f%%" % [label, _progress * 100.0])
		if _progress >= 1.0:
			if extract_type == "contested":
				get_tree().call_group("heavy_mech", "alert_to", global_position)
				Fx.play("alarm")
			Fx.play("extract")
			Fx.burst(global_position, ($OmniLight3D as OmniLight3D).light_color if has_node("OmniLight3D") else Color(0.3, 1.0, 0.4))
			_progress = 0.0
			if NetSession.is_online() and not NetSession.is_host():
				_rpc_extract.rpc_id(1)
			RunState.extract_to_hangar()
	else:
		_progress = maxf(_progress - delta * 0.45, 0.0)
		if _progress > 0.0:
			Hud.set_extract(_progress)
		else:
			Hud.set_extract(-1.0)


@rpc("any_peer", "reliable")
func _rpc_extract() -> void:
	if NetSession.is_host():
		Hud.show_banner(WorldLore.extracted_banner())


func _has_payload() -> bool:
	for p in RunState.raid_carry:
		if bool(p.get("is_payload", false)):
			return true
	for p in RunState.secure_carry:
		if bool(p.get("is_payload", false)):
			return true
	for n in _inside:
		if n.is_in_group("machine") and bool(n.call("has_payload")):
			return true
	return false


func _has_hauler() -> bool:
	for n in _inside:
		if n.is_in_group("hauler") and bool(n.get("boarded")):
			return true
	return false


func _purge_invalid() -> void:
	var keep: Array[Node] = []
	for body in _inside:
		if is_instance_valid(body):
			keep.append(body)
	_inside = keep


func _tax_clear() -> bool:
	if RunState.faction == "warlord":
		if not _waive_shown:
			_waive_shown = true
			RunState.tax_cleared = true
			Hud.show_banner(WorldLore.tax_waived_banner())
		return true
	if tax_paid or RunState.tax_cleared:
		RunState.tax_cleared = true
		return true
	if not _gate_blocking():
		if not _waive_shown:
			_waive_shown = true
			RunState.tax_cleared = true
			Hud.show_banner(WorldLore.tax_gate_down_banner())
		return true
	return false


func _gate_blocking() -> bool:
	if tax_gate == null or not is_instance_valid(tax_gate):
		return false
	if not bool(tax_gate.get("alive")) or bool(tax_gate.get("disabled")):
		return false
	if bool(tax_gate.get("boarded")):
		return false
	return true


func _handle_tax() -> void:
	var cost := RunState.tax_cost()
	var can := RunState.credits >= cost
	Hud.set_prompt(WorldLore.tax_prompt(cost, can))
	if Input.is_action_just_pressed("interact"):
		if RunState.pay_tax():
			tax_paid = true
			Hud.show_banner(WorldLore.tax_paid_banner())
			Hud.refresh_carry()
			Fx.play("ui")
			if get_tree():
				get_tree().call_group("yard_band", "push", "BRASK — Tax paid. Pad's open. Don't sit on it.")
		else:
			Hud.show_banner("Not enough credits. Wreck the hauler.")


func _ensure_title(col: Color) -> void:
	var lab := get_node_or_null("Title") as Label3D
	if lab == null:
		lab = Label3D.new()
		lab.name = "Title"
		lab.position = Vector3(0, 3.2, 0)
		lab.font_size = 48
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lab)
	lab.text = WorldLore.extract_title(extract_type)
	lab.modulate = col
