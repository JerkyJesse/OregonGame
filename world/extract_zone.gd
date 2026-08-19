extends Area3D

@export var extract_type: String = "contested"
@export var channel_time: float = 3.0

var _inside: Array[Node] = []
var _progress: float = 0.0


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
	if has_node("OmniLight3D"):
		($OmniLight3D as OmniLight3D).light_color = col


func _on_body_entered(body: Node) -> void:
	if _is_extractor(body) and not _inside.has(body):
		_inside.append(body)


func _on_body_exited(body: Node) -> void:
	_inside.erase(body)
	if _inside.is_empty():
		_progress = 0.0
		Hud.set_extract(-1.0)


func _is_extractor(body: Node) -> bool:
	if body is Scavenger:
		return not (body as Scavenger).boarded
	if body.is_in_group("machine"):
		return bool(body.get("boarded"))
	return body.is_in_group("player")


func _process(delta: float) -> void:
	_purge_invalid()
	if _inside.is_empty() or Hud.ui_busy:
		return
	if extract_type == "payload" and not _has_payload():
		Hud.set_prompt("PAYLOAD LZ — need a data core")
		return
	if extract_type == "vehicle" and not _has_hauler():
		Hud.set_prompt("VEHICLE LZ — board the hauler")
		return
	var label := extract_type.to_upper()
	Hud.set_prompt("Hold [E]  %s extract" % label)
	if Input.is_action_pressed("interact"):
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
			_progress = 0.0
			if NetSession.is_host():
				RunState.extract_to_hangar()
			else:
				_rpc_extract.rpc_id(1)
	else:
		_progress = maxf(_progress - delta * 0.45, 0.0)
		if _progress > 0.0:
			Hud.set_extract(_progress)
		else:
			Hud.set_extract(-1.0)


@rpc("any_peer", "reliable")
func _rpc_extract() -> void:
	if NetSession.is_host():
		RunState.extract_to_hangar()


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
