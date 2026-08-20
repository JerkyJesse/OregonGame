extends Node

const LOOK := preload("res://world/WorldLook.gd")


var _players: Array[AudioStreamPlayer] = []
var _last_puff_ms: int = 0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func play(kind: String) -> void:
	var stream := _tone(kind)
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = -8.0
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()


func _tone(kind: String) -> AudioStreamWAV:
	var hz := 180.0
	var ms := 90
	var vol := 0.22
	match kind:
		"vulcan":
			hz = 90.0
			ms = 40
			vol = 0.28
		"energy":
			hz = 620.0
			ms = 70
			vol = 0.18
		"missile":
			hz = 140.0
			ms = 160
			vol = 0.24
		"melee":
			hz = 55.0
			ms = 120
			vol = 0.3
		"stomp":
			hz = 38.0
			ms = 220
			vol = 0.34
		"extract":
			hz = 440.0
			ms = 180
			vol = 0.16
		"alarm":
			hz = 880.0
			ms = 240
			vol = 0.2
		"ui":
			hz = 520.0
			ms = 50
			vol = 0.12
		"hack":
			hz = 310.0
			ms = 80
			vol = 0.14
		"radio":
			hz = 240.0
			ms = 55
			vol = 0.1
		_:
			hz = 200.0
	return _make_wav(hz, ms, vol)


func _make_wav(hz: float, ms: int, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * ms / 1000.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := 1.0 - float(i) / float(maxi(n, 1))
		var s := int(clamp(sin(t * hz * TAU) * vol * env * 32767.0, -32767.0, 32767.0))
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func spawn_tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.72, 0.18)) -> void:
	var dist := from.distance_to(to)
	if dist < 0.15 or get_tree() == null or get_tree().current_scene == null:
		return
	var scene := get_tree().current_scene
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.055
	cyl.height = dist
	cyl.material = LOOK.additive(color, 2.4)
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	if to.is_equal_approx(from):
		mi.queue_free()
		return
	mi.look_at_from_position(mi.global_position, to, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_flash(scene, from, color, 0.1, 0.05)
	get_tree().create_timer(0.11).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)


func spark(pos: Vector3, color: Color = Color(1.0, 0.7, 0.25)) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	_flash(get_tree().current_scene, pos, color, 0.16, 0.07)


func puff(pos: Vector3, color: Color = Color(0.45, 0.75, 1.0)) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_puff_ms < 70:
		return
	_last_puff_ms = now
	if get_tree() == null or get_tree().current_scene == null:
		return
	_flash(get_tree().current_scene, pos, color, 0.22, 0.1)


func burst(pos: Vector3, color: Color = Color(0.35, 1.0, 0.45)) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var scene := get_tree().current_scene
	_flash(scene, pos + Vector3(0, 1.2, 0), color, 0.55, 0.28)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 8.0
	light.omni_range = 12.0
	scene.add_child(light)
	light.global_position = pos + Vector3(0, 1.4, 0)
	get_tree().create_timer(0.28).timeout.connect(func() -> void:
		if is_instance_valid(light):
			light.queue_free()
	)


func falling_chunk(src: MeshInstance3D) -> void:
	if src == null or get_tree() == null or get_tree().current_scene == null:
		return
	var mi := src.duplicate() as MeshInstance3D
	if mi == null:
		return
	var scene := get_tree().current_scene
	var xform := src.global_transform
	scene.add_child(mi)
	mi.global_transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drift := Vector3(randf_range(-3.2, 3.2), randf_range(1.2, 3.6), randf_range(-3.2, 3.2))
	var end := xform.origin + drift + Vector3(0, -7.0, 0)
	var tw := scene.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "global_position", end, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "rotation", mi.rotation + Vector3(randf_range(-2.2, 2.2), randf_range(-1.8, 1.8), randf_range(-2.2, 2.2)), 0.9)
	tw.chain().tween_callback(mi.queue_free)


func float_text(pos: Vector3, text: String, color: Color = Color(1.0, 0.7, 0.25)) -> void:
	if get_tree() == null or get_tree().current_scene == null or text == "":
		return
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 40
	lab.modulate = color
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.outline_size = 8
	lab.outline_modulate = Color(0, 0, 0, 0.88)
	lab.no_depth_test = true
	var scene := get_tree().current_scene
	scene.add_child(lab)
	lab.global_position = pos + Vector3(0, 0.55, 0)
	var tw := scene.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lab, "global_position", lab.global_position + Vector3(0, 1.7, 0), 0.72)
	tw.tween_property(lab, "modulate:a", 0.0, 0.72)
	tw.chain().tween_callback(lab.queue_free)


func _flash(scene: Node, pos: Vector3, color: Color, radius: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = radius
	sp.height = radius * 2.0
	sp.radial_segments = 8
	sp.rings = 4
	sp.material = LOOK.additive(color, 3.2)
	mi.mesh = sp
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(mi)
	mi.global_position = pos
	get_tree().create_timer(life).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)
