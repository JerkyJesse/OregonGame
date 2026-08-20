extends Node3D
class_name ToxicStorm

const LOOK := preload("res://world/WorldLook.gd")

var radius: float = 70.0
var shrink_rate: float = 0.35
var _pulse: float = 0.0
var _warn: float = 0.0
var _filter_warn: float = 0.0
var _stage: int = 0
var _ring: MeshInstance3D


func _ready() -> void:
	add_to_group("storm")
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 69.4
	torus.outer_radius = 70.6
	torus.rings = 48
	torus.ring_segments = 12
	torus.material = LOOK.emit_surface(Color(0.62, 0.95, 0.28, 0.55), 2.4, 0.5)
	_ring.mesh = torus
	_ring.rotation_degrees.x = 90.0
	_ring.position.y = 0.4
	add_child(_ring)
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 1.0, 0.28)
	light.light_energy = 3.2
	light.omni_range = 18.0
	light.position = Vector3(0, 5, 0)
	light.light_volumetric_fog_energy = 1.6
	add_child(light)
	LOOK.dust(self, Vector3(42, 12, 42), Color(0.5, 0.85, 0.28, 0.14), 48)
	var tend := Node3D.new()
	tend.name = "Tendrils"
	add_child(tend)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var stalk := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.04
		mesh.bottom_radius = 0.16
		mesh.height = 2.4
		mesh.material = LOOK.flesh_mat(LOOK.PALE, 1.6)
		stalk.mesh = mesh
		stalk.position = Vector3(cos(ang) * 69.0, 1.2, sin(ang) * 69.0)
		tend.add_child(stalk)


func _process(delta: float) -> void:
	if not RunState.in_raid:
		Hud.set_lungs(-1.0)
		return
	_pulse += delta
	_warn = maxf(_warn - delta, 0.0)
	_filter_warn = maxf(_filter_warn - delta, 0.0)
	radius = maxf(18.0, 70.0 - RunState.raid_timer * shrink_rate)
	if _ring and _ring.mesh is TorusMesh:
		var t := _ring.mesh as TorusMesh
		t.inner_radius = maxf(radius - 0.7, 0.5)
		t.outer_radius = radius + 0.7
		_ring.rotate_y(delta * 0.12)
	var tend := get_node_or_null("Tendrils") as Node3D
	if tend:
		tend.rotate_y(delta * 0.08)
		var idx := 0
		for child in tend.get_children():
			if child is Node3D:
				var ang := TAU * float(idx) / 8.0 + _pulse * 0.15
				(child as Node3D).position = Vector3(cos(ang) * radius, 1.1 + sin(_pulse * 2.0 + float(idx)) * 0.2, sin(ang) * radius)
				idx += 1
	LOOK.set_pale(get_parent(), clampf(1.0 - radius / 70.0, 0.0, 0.95))
	_tick_stage()
	var local_foot := false
	var foot_dist := 0.0
	for n in get_tree().get_nodes_in_group("scavenger"):
		if not (n is Scavenger):
			continue
		var scav := n as Scavenger
		if not scav._local():
			continue
		if scav.boarded:
			RunState.tick_filter(delta, true, false)
			Hud.set_lungs(RunState.filter)
			continue
		local_foot = true
		foot_dist = Vector2(scav.global_position.x, scav.global_position.z).length()
		var sealed := _in_sealed(scav)
		var in_bloom := foot_dist > radius and not sealed
		var cause := RunState.tick_filter(delta, sealed, in_bloom)
		Hud.set_lungs(RunState.filter, radius, foot_dist)
		if sealed and _warn <= 0.0 and RunState.raid_timer > 2.0:
			Hud.set_sensors(WorldLore.sealed_pocket_hint())
		if cause != "":
			var dps := 16.0 if cause == "bloom" else 4.0
			scav.take_damage(dps * delta, cause)
			if _warn <= 0.0:
				Hud.show_banner(WorldLore.storm_banner() if cause == "bloom" else WorldLore.haze_banner())
				_warn = 2.4
		elif in_bloom and _warn <= 0.0:
			Hud.show_banner(WorldLore.storm_banner())
			_warn = 2.8
		if RunState.filter < 18.0 and _filter_warn <= 0.0 and not RunState.bloom_native() and not sealed:
			Hud.show_banner(WorldLore.filter_critical_banner())
			_filter_warn = 8.0
	if local_foot:
		Hud.set_lungs(RunState.filter, radius, foot_dist)
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node3D and n.is_in_group("machine"):
			var p := n as Node3D
			var d := Vector2(p.global_position.x, p.global_position.z).length()
			if d > radius and not RunState.bloom_native():
				n.call("take_damage", 6.0 * delta)


func _in_sealed(body: Node3D) -> bool:
	for n in get_tree().get_nodes_in_group("sealed_steel"):
		if n is Area3D and n.has_method("covers") and bool(n.call("covers", body)):
			return true
		if n is Area3D and (n as Area3D).overlaps_body(body):
			return true
	return false


func current_radius() -> float:
	return radius


func _tick_stage() -> void:
	var next := 0
	if radius <= 55.0:
		next = 1
	if radius <= 40.0:
		next = 2
	if radius <= 28.0:
		next = 3
	if next <= _stage:
		return
	_stage = next
	if get_tree():
		get_tree().call_group("yard_band", "push", WorldLore.storm_stage_band(_stage))
	if _stage >= 2:
		Hud.show_banner(WorldLore.storm_stage_band(_stage))
		Fx.play("alarm")
		var world := get_parent() as Node3D
		if world:
			RaidDirector.spawn_pale(world, Vector3(radius * 0.82, 0.2, 4.0))
			RaidDirector.spawn_pale(world, Vector3(-radius * 0.55, 0.2, radius * 0.4))

