extends Node

var _players: Array[AudioStreamPlayer] = []


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
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = dist
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.6
	cyl.material = mat
	mi.mesh = cyl
	get_tree().current_scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	if to.is_equal_approx(from):
		mi.queue_free()
		return
	mi.look_at(to, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)
