extends MachineBase
class_name HeavyMech

@onready var _stomp: Area3D = get_node_or_null("Stomp")
@onready var _body: Node3D = get_node_or_null("Body")
var _crush_cd: float = 0.0


func _ready() -> void:
	scale_id = "heavy"
	cockpit_height = 17.55
	cockpit_forward = 4.5
	move_speed = 4.4
	hull_max = RunState.cap("heavy", "hull")
	hull = hull_max
	add_to_group("heavy_mech")
	super._ready()
	if _stomp:
		_stomp.body_entered.connect(_on_stomp_body_entered)
		_stomp.monitoring = true
	if not hangar_preview and not disabled and RunState.deploy_scale != "heavy":
		ai_controlled = true


func set_patrol(points: Array) -> void:
	patrol.clear()
	for p in points:
		if p is Vector3:
			patrol.append(p)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_crush_cd = maxf(_crush_cd - delta, 0.0)
	if _body and alive:
		_body.position.y = 11.0 + sin(Time.get_ticks_msec() * 0.0035) * 0.35
	_crush_nearby(delta)


func _crush_nearby(delta: float) -> void:
	if hangar_preview or not alive or disabled or boarded:
		return
	if velocity.length() < 0.35 and not ai_controlled:
		return
	for n in get_tree().get_nodes_in_group("scavenger"):
		if not (n is Scavenger):
			continue
		var scav := n as Scavenger
		if scav.boarded:
			continue
		var flat := Vector3(scav.global_position.x - global_position.x, 0.0, scav.global_position.z - global_position.z)
		var d := flat.length()
		if d < 4.8 and scav.global_position.y < global_position.y + 3.5:
			if d < 2.4 and _crush_cd <= 0.0 and (velocity.length() > 0.8 or ai_controlled):
				_crush_cd = 0.55
				Fx.play("stomp")
				scav.take_damage(999.0, "crush")
			elif d < 5.5 and scav._local() and not Hud.ui_busy:
				Hud.set_sensors(WorldLore.crush_warning())


func _on_stomp_body_entered(body: Node) -> void:
	if body is Scavenger:
		var scav := body as Scavenger
		if not scav.boarded and alive and not disabled:
			Fx.play("stomp")
			scav.take_damage(999.0, "crush")


func pry_plate(scav: Node) -> void:
	hold_pry(scav, 0.28)
