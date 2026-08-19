extends MachineBase
class_name HeavyMech

@onready var _stomp: Area3D = get_node_or_null("Stomp")
@onready var _body: Node3D = get_node_or_null("Body")


func _ready() -> void:
	scale_id = "heavy"
	cockpit_height = 15.6
	cockpit_forward = 1.4
	move_speed = 4.4
	hull_max = RunState.cap("heavy", "hull")
	hull = hull_max
	add_to_group("heavy_mech")
	super._ready()
	if _stomp:
		_stomp.body_entered.connect(_on_stomp_body_entered)
	if not hangar_preview and not disabled and RunState.deploy_scale != "heavy":
		ai_controlled = true


func set_patrol(points: Array[Vector3]) -> void:
	patrol = points


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
	if not alive:
		return
	_pry += 0.28
	Hud.set_extract(_pry)
	Hud.set_prompt("Prying armor… stay on the calf")
	if _pry >= 1.0:
		_pry = 0.0
		Hud.set_extract(-1.0)
		var part := RunState.make_part("heavy_plating", randf_range(0.3, 0.7))
		if scav is Scavenger and RunState.add_carry(part):
			Hud.refresh_carry()
			Hud.show_banner("Plate ripped from the heavy.")
			take_section_damage(40.0, global_position + Vector3(0, 2, 0))
