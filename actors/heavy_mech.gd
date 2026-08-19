extends MachineBase
class_name HeavyMech

@onready var _stomp: Area3D = get_node_or_null("Stomp")
@onready var _body: Node3D = get_node_or_null("Body")


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
	if not hangar_preview and not disabled and RunState.deploy_scale != "heavy":
		ai_controlled = true


func set_patrol(points: Array) -> void:
	patrol.clear()
	for p in points:
		if p is Vector3:
			patrol.append(p)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _body and alive:
		_body.position.y = 11.0 + sin(Time.get_ticks_msec() * 0.0035) * 0.35


func _on_stomp_body_entered(body: Node) -> void:
	if body is Scavenger:
		var scav := body as Scavenger
		if not scav.boarded:
			Hud.show_banner("Crushed.")
			Fx.play("stomp")
			scav.take_damage(999.0)


func pry_plate(scav: Node) -> void:
	hold_pry(scav, 0.28)
