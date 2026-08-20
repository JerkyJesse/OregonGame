extends Node3D
class_name ToxicStorm

var radius: float = 70.0
var _pulse: float = 0.0
var _warn: float = 0.0
var _ring: MeshInstance3D


func _ready() -> void:
	add_to_group("storm")
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 69.4
	torus.outer_radius = 70.6
	torus.rings = 48
	torus.ring_segments = 12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.85, 0.2, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.9, 0.15)
	mat.emission_energy_multiplier = 1.8
	torus.material = mat
	_ring.mesh = torus
	_ring.rotation_degrees.x = 90.0
	_ring.position.y = 0.4
	add_child(_ring)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 1.0, 0.2)
	light.light_energy = 2.0
	light.omni_range = 12.0
	light.position = Vector3(0, 4, 0)
	add_child(light)


func _process(delta: float) -> void:
	if not RunState.in_raid:
		return
	_pulse += delta
	_warn = maxf(_warn - delta, 0.0)
	radius = maxf(18.0, 70.0 - RunState.raid_timer * 0.35)
	if _ring and _ring.mesh is TorusMesh:
		var t := _ring.mesh as TorusMesh
		t.inner_radius = maxf(radius - 0.7, 0.5)
		t.outer_radius = radius + 0.7
	for n in get_tree().get_nodes_in_group("player"):
		if n is Node3D:
			var p := n as Node3D
			var d := Vector2(p.global_position.x, p.global_position.z).length()
			if d > radius:
				if n is Scavenger:
					(n as Scavenger).take_damage(14.0 * delta)
				elif n.is_in_group("machine"):
					n.call("take_damage", 8.0 * delta)
				if _warn <= 0.0:
					Hud.show_banner(WorldLore.storm_banner())
					_warn = 2.4


func current_radius() -> float:
	return radius
