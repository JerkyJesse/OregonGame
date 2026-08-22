extends Node

const SCRIPT := preload("res://tools/walkthrough/script.gd")

var active: bool = false
var start_from: String = ""
var sprint: bool = false
var arrive_dist: float = 1.7
var move_goal: Vector3 = Vector3.INF
var look_goal: Vector3 = Vector3.INF

var _held: String = ""
var _voice: AudioStreamPlayer
var _lines: Dictionary = {}
var _sfx_bus: int = -1


func _ready() -> void:
	_parse_args()
	if not active:
		return
	RunState.walkthrough = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lines = SCRIPT.lines()
	_ensure_buses()
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	_voice.volume_db = 0.0
	add_child(_voice)
	_prep_window()
	print("WALKTHROUGH active from=", start_from if start_from != "" else "title")
	call_deferred("_boot")


func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	for a in args:
		var s := str(a)
		if s == "--walkthrough":
			active = true
		if s.begins_with("--walkthrough-from="):
			active = true
			start_from = s.get_slice("=", 1).strip_edges()


func _prep_window() -> void:
	Settings.quality = "high"
	Settings.apply()
	var win := get_window()
	if win:
		win.mode = Window.MODE_WINDOWED
		win.size = Vector2i(1920, 1080)
		win.title = "GetTheMechOuttaDodge — walkthrough"


func _ensure_buses() -> void:
	if AudioServer.get_bus_index("Sfx") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Sfx")
		AudioServer.set_bus_send(i, "Master")
	if AudioServer.get_bus_index("Voice") == -1:
		AudioServer.add_bus()
		var j := AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, "Voice")
		AudioServer.set_bus_send(j, "Master")
	_sfx_bus = AudioServer.get_bus_index("Sfx")


func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if start_from == "pipe" or start_from == "hangar2":
		RunState.new_game()
		RunState.extracts_completed = 1
		RunState.credits = 220
		get_tree().change_scene_to_file("res://scenes/hangar.tscn")
		await wait_scene("hangar.tscn")
		await _seq_hangar2()
		await _seq_pipe()
		await _seq_hangar3()
	else:
		await _seq_title()
		await _seq_hangar1()
		await _seq_ash()
		await _seq_hangar2()
		await _seq_pipe()
		await _seq_hangar3()
	await _pause(1.2)
	print("WALKTHROUGH_DONE")
	get_tree().quit()


func move_axis(body: Node3D) -> Vector2:
	if not active or Hud.ui_busy:
		return Vector2.ZERO
	if not move_goal.is_finite():
		return Vector2.ZERO
	var to := move_goal - body.global_position
	to.y = 0.0
	if to.length() <= arrive_dist:
		return Vector2.ZERO
	var local := body.global_transform.basis.inverse() * to.normalized()
	return Vector2(local.x, -local.z).limit_length(1.0)


func apply_look(body: Node3D, delta: float) -> void:
	if not active or body == null:
		return
	var goal := look_goal
	if not goal.is_finite():
		if move_goal.is_finite():
			goal = move_goal + Vector3(0, 1.5, 0)
		else:
			return
	var origin := body.global_position + Vector3(0, 1.45, 0)
	if body is Scavenger:
		var cam: Camera3D = (body as Scavenger)._camera
		if cam:
			origin = cam.global_position
	elif body is MachineBase and (body as MachineBase)._camera:
		origin = (body as MachineBase)._camera.global_position
	var dir := goal - origin
	if dir.length() < 0.08:
		return
	if absf(dir.x) + absf(dir.z) < 0.04:
		dir.z = -0.05
	var b := Basis.looking_at(dir, Vector3.UP)
	var e := b.get_euler()
	body.rotation.y = lerp_angle(body.rotation.y, e.y, clampf(delta * 5.2, 0.0, 1.0))
	var pitch := clampf(e.x, deg_to_rad(-80.0), deg_to_rad(70.0))
	if body is Scavenger:
		var scav := body as Scavenger
		scav.look_pitch = lerp_angle(scav.look_pitch, pitch, clampf(delta * 5.2, 0.0, 1.0))
		if scav._camera:
			scav._camera.rotation.x = scav.look_pitch
	elif body is MachineBase:
		var mech := body as MachineBase
		mech._pitch = lerp_angle(mech._pitch, pitch, clampf(delta * 5.2, 0.0, 1.0))
		if mech._camera:
			mech._camera.rotation.x = mech._pitch


func actor() -> Node3D:
	if get_tree() == null:
		return null
	for n in get_tree().get_nodes_in_group("player"):
		if n is MachineBase and bool(n.get("boarded")):
			return n as Node3D
		if n is Scavenger and (n as Scavenger)._local() and not (n as Scavenger).boarded:
			return n as Node3D
	for n in get_tree().get_nodes_in_group("scavenger"):
		if n is Scavenger and (n as Scavenger)._local() and not (n as Scavenger).boarded:
			return n as Node3D
	return null


func local_scav() -> Scavenger:
	if get_tree() == null:
		return null
	for n in get_tree().get_nodes_in_group("scavenger"):
		if n is Scavenger and (n as Scavenger)._local():
			return n as Scavenger
	return null


func _seq_title() -> void:
	print("WALKTHROUGH beat=title")
	await wait_scene("title.tscn")
	await _pause(1.0)
	await say("title_open")
	await say("title_menu")
	var title := get_tree().current_scene
	if title and title.has_method("_new_game"):
		title.call("_new_game")
	await _pause(0.7)
	await say("crawl_1")
	await say("crawl_2")
	await say("crawl_3")
	await say("crawl_4")
	await say("crawl_tam")
	title = get_tree().current_scene
	if title and title.has_method("_finish_crawl"):
		title.call("_finish_crawl")
	await wait_scene("hangar.tscn")


func _seq_hangar1() -> void:
	print("WALKTHROUGH beat=hangar1")
	await wait_actor()
	sprint = false
	await _look(Vector3(0, 7.6, -16.4), 0.7)
	await say("hangar_arrive")
	await say("hangar_sign")
	await walk_to(Vector3(-8.0, 1.1, 11.0))
	await _look(Vector3(-12.0, 1.6, 12.0), 0.45)
	await say("hangar_range")
	await say("hangar_tam_walk")
	await walk_to(Vector3(8.0, 1.1, 8.0))
	await walk_to(Vector3(14.0, 1.1, -6.0))
	await walk_to(Vector3(14.0, 1.1, -10.4))
	await _look(Vector3(14.0, 1.5, -13.0), 0.35)
	await tap_interact_or(func() -> void: Hud.open_vendor())
	await say("tam_stall_1")
	await say("tam_stall_2")
	Hud.close_all_ui()
	await _pause(0.35)
	await walk_to(Vector3(8.0, 1.1, -2.0))
	await walk_to(Vector3(3.0, 1.1, 2.5))
	await _look(Vector3(0.0, 2.4, -1.0), 0.45)
	await say("hangar_frames")
	var light := _named("LightMech")
	await tap_interact_or(func() -> void:
		if light:
			Hud.open_workshop("light")
	)
	await _pause(1.15)
	Hud.close_all_ui()
	await say("hangar_deploy")
	await walk_to(Vector3(10.0, 1.1, 10.4))
	await _look(Vector3(10.0, 1.3, 8.0), 0.3)
	await tap_interact_or(func() -> void: Hud.open_deploy())
	RunState.deploy_scale = "scavenger"
	RunState.raid_map = "ash_yard"
	RunState.raid_mode = "combat"
	RunState.apply_faction("scav")
	if Hud.has_method("_refresh_deploy_briefing"):
		Hud.call("_refresh_deploy_briefing")
	await say("hangar_brief")
	await say("tam_sendoff")
	Hud.call("_launch")
	await wait_scene("raid.tscn")


func _seq_ash() -> void:
	print("WALKTHROUGH beat=ash")
	await wait_actor()
	sprint = true
	await _look(Vector3(20.0, 8.0, 0.0), 0.8)
	await say("ash_drop")
	await say("ash_ring")
	await walk_to(Vector3(-36.0, 1.2, 12.0))
	await walk_to(Vector3(-28.0, 1.2, 8.0))
	await walk_to(Vector3(-26.0, 1.2, 7.4))
	await _look(Vector3(-26.0, 0.7, 6.0), 0.25)
	await say("ash_can")
	_use_named("FilterDrop")
	await tap("interact")
	await _pause(0.35)
	await walk_to(Vector3(-30.0, 1.2, -2.0))
	await walk_to(Vector3(-26.0, 1.2, -6.2))
	await _look(Vector3(-26.0, 1.6, -8.0), 0.25)
	await say("ash_wreck")
	_use_named("Wreck")
	await tap("interact")
	await _pause(0.4)
	await walk_to(Vector3(-18.0, 1.2, -3.0))
	await walk_to(Vector3(-12.0, 1.2, -3.4))
	await _look(Vector3(-12.0, 2.2, -6.0), 0.25)
	await say("ash_helix")
	var med := _named("DeadMedium")
	await tap_interact_or(func() -> void:
		if med:
			Hud.open_machine_bay(med)
	)
	await _pause(0.55)
	Hud.call("_bay_strip", "chest")
	await _pause(0.85)
	Hud.close_all_ui()
	await walk_to(Vector3(-4.0, 1.2, 2.0))
	await walk_to(Vector3(2.0, 1.2, 8.2))
	await _look(Vector3(2.0, 2.3, 6.0), 0.25)
	await say("ash_bolt")
	var light := _named("LightMech")
	await tap_interact_or(func() -> void:
		if light:
			Hud.open_machine_bay(light)
	)
	await _pause(0.45)
	Hud.call("_bay_bolt", "chest")
	await _pause(0.7)
	Hud.close_all_ui()
	await say("ash_board")
	await tap("board")
	if light and local_scav() and not bool(light.get("boarded")):
		light.call("board_pilot", local_scav())
	await _pause(0.55)
	await _look(Vector3(4.0, 1.4, 10.0), 0.3)
	await say("ash_guns")
	set_hold("fire")
	await _pause(1.7)
	clear_hold()
	await say("ash_dismount")
	await tap("board")
	if light and bool(light.get("boarded")) and light.has_method("dismount"):
		light.call("dismount")
	await _pause(0.4)
	if RunState.filter < 98.0 and RunState.has_filter_pack():
		await tap("use_item")
		await _pause(0.3)
	await walk_to(Vector3(14.0, 1.2, 4.0), 1.8, 16.0)
	await walk_to(Vector3(26.0, 1.2, 0.0), 1.8, 16.0)
	await walk_to(Vector3(36.0, 1.2, 2.0), 1.6, 16.0)
	if RunState.raid_timer >= 44.0:
		await say("ash_jex")
	await say("ash_extract")
	await _look(Vector3(38.0, 1.4, 2.0), 0.2)
	await channel_extract()


func _seq_hangar2() -> void:
	print("WALKTHROUGH beat=hangar2")
	await wait_scene("hangar.tscn")
	await wait_actor()
	sprint = false
	await _pause(0.6)
	await say("hangar2_tam")
	await say("hangar2_pipe")
	await walk_to(Vector3(10.0, 1.1, 10.4), 1.7, 18.0)
	await _look(Vector3(10.0, 1.3, 8.0), 0.25)
	await tap_interact_or(func() -> void: Hud.open_deploy())
	RunState.deploy_scale = "scavenger"
	RunState.raid_map = "pipeline"
	RunState.raid_mode = "combat"
	if Hud.has_method("_refresh_deploy_briefing"):
		Hud.call("_refresh_deploy_briefing")
	await _pause(1.4)
	Hud.call("_launch")
	await wait_scene("pipeline.tscn")


func _seq_pipe() -> void:
	print("WALKTHROUGH beat=pipe")
	await wait_actor()
	sprint = true
	await _look(Vector3(0.0, 6.0, 11.0), 0.6)
	await say("pipe_drop")
	await walk_to(Vector3(-16.0, 1.2, -6.0))
	await walk_to(Vector3(-8.0, 1.2, 2.0))
	await walk_to(Vector3(0.0, 1.2, 8.4))
	await _look(Vector3(0.0, 1.4, 11.2), 0.3)
	await say("pipe_pump")
	await say("pipe_decrypt")
	await hack_dais()
	await say("pipe_choir")
	await walk_to(Vector3(6.0, 1.2, 4.0))
	await walk_to(Vector3(8.0, 1.2, -10.0))
	await walk_to(Vector3(8.0, 1.2, -20.0), 1.7, 18.0)
	await say("pipe_lz")
	var pad := _extract("payload")
	if pad:
		await _look(pad.global_position + Vector3(0, 1.5, 0), 0.2)
	await channel_extract()


func _seq_hangar3() -> void:
	print("WALKTHROUGH beat=hangar3")
	await wait_scene("hangar.tscn")
	await wait_actor()
	sprint = false
	await _pause(0.5)
	await _look(Vector3(0.0, 7.6, -16.4), 0.6)
	await say("hangar3_tam")
	await say("hangar3_home")
	await _look(Vector3(0.0, 2.5, -1.0), 1.4)


func wait_scene(hint: String, timeout: float = 18.0) -> void:
	var t := 0.0
	while t < timeout:
		var sc := get_tree().current_scene
		if sc and sc.scene_file_path.ends_with(hint):
			await _pause(0.45)
			return
		await get_tree().process_frame
		t += get_process_delta_time()
	push_warning("WALKTHROUGH wait_scene timeout %s" % hint)


func wait_actor(timeout: float = 12.0) -> void:
	var t := 0.0
	while t < timeout:
		if actor() != null:
			await _pause(0.2)
			return
		await get_tree().process_frame
		t += get_process_delta_time()
	push_warning("WALKTHROUGH wait_actor timeout")


func walk_to(pos: Vector3, dist: float = 1.7, timeout: float = 20.0) -> void:
	arrive_dist = dist
	move_goal = pos
	look_goal = pos + Vector3(0, 1.45, 0)
	var t := 0.0
	var stall := 0.0
	var last := Vector3.ZERO
	while t < timeout:
		var body := actor()
		if body == null:
			await get_tree().process_frame
			t += get_process_delta_time()
			continue
		var d := Vector2(body.global_position.x - pos.x, body.global_position.z - pos.z).length()
		if d <= dist:
			break
		if last != Vector3.ZERO and last.distance_to(body.global_position) < 0.04:
			stall += get_process_delta_time()
		else:
			stall = 0.0
		last = body.global_position
		if stall > 2.4:
			body.global_position = Vector3(pos.x, maxf(body.global_position.y, 1.05), pos.z)
			body.velocity = Vector3.ZERO
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	move_goal = Vector3.INF
	var done := actor()
	if done and Vector2(done.global_position.x - pos.x, done.global_position.z - pos.z).length() > dist + 0.8:
		done.global_position = Vector3(pos.x, maxf(done.global_position.y, 1.05), pos.z)


func _look(pos: Vector3, dwell: float) -> void:
	look_goal = pos
	move_goal = Vector3.INF
	await _pause(dwell)


func say(id: String) -> void:
	print("WALKTHROUGH vo=", id)
	var spec: Variant = _lines.get(id, {})
	var text := ""
	if spec is Dictionary:
		text = str((spec as Dictionary).get("text", ""))
	var stream := _load_mp3(id)
	if stream:
		_duck(true)
		_voice.stream = stream
		_voice.play()
		await _voice.finished
		_duck(false)
		await _pause(0.18)
		return
	var words := maxi(text.split(" ", false).size(), 8)
	await _pause(float(words) / 2.35)


func tap(action: String) -> void:
	clear_hold()
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)


func tap_interact_or(fallback: Callable) -> void:
	await tap("interact")
	await _pause(0.32)
	if not Hud.ui_busy and fallback.is_valid():
		fallback.call()
		await _pause(0.18)


func set_hold(action: String) -> void:
	clear_hold()
	Input.action_press(action)
	_held = action


func clear_hold() -> void:
	if _held != "":
		Input.action_release(_held)
		_held = ""


func channel_extract(timeout: float = 9.0) -> void:
	set_hold("interact")
	var t := 0.0
	while t < timeout:
		if not RunState.in_raid:
			break
		var sc := get_tree().current_scene
		if sc and sc.scene_file_path.ends_with("hangar.tscn"):
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	clear_hold()
	if RunState.in_raid:
		print("WALKTHROUGH extract fallback")
		RunState.extract_to_hangar()
	await wait_scene("hangar.tscn")


func hack_dais(timeout: float = 7.0) -> void:
	var dais: Node = null
	if get_tree():
		var nodes := get_tree().get_nodes_in_group("shard_dais")
		if not nodes.is_empty():
			dais = nodes[0]
	var scav := local_scav()
	if dais is Node3D:
		await walk_to((dais as Node3D).global_position + Vector3(0, 0, -2.1), 1.4, 10.0)
		await _look((dais as Node3D).global_position + Vector3(0, 1.3, 0), 0.2)
	set_hold("interact")
	var t := 0.0
	while t < timeout:
		if RunState.carrying_payload():
			break
		if dais and scav and dais.has_method("hold_hack_core"):
			dais.call("hold_hack_core", scav, get_process_delta_time())
		await get_tree().process_frame
		t += get_process_delta_time()
	clear_hold()
	await _pause(0.35)


func _use_named(node_name: String) -> void:
	var n := _named(node_name)
	var scav := local_scav()
	if n and scav and n.has_method("interact"):
		n.call("interact", scav)


func _named(node_name: String) -> Node:
	var sc := get_tree().current_scene
	if sc == null:
		return null
	if sc.has_node(node_name):
		return sc.get_node(node_name)
	return sc.find_child(node_name, true, false)


func _extract(kind: String) -> Node3D:
	if get_tree() == null:
		return null
	for z in get_tree().get_nodes_in_group("extract_zone"):
		if str(z.get("extract_type")) == kind and z is Node3D:
			return z as Node3D
	return null


func _load_mp3(id: String) -> AudioStream:
	var res_path := SCRIPT.vo_path(id)
	var abs_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path) and not FileAccess.file_exists(res_path):
		return null
	var use := abs_path if FileAccess.file_exists(abs_path) else res_path
	var bytes := FileAccess.get_file_as_bytes(use)
	if bytes.is_empty():
		return null
	var stream := AudioStreamMP3.new()
	stream.data = bytes
	return stream


func _duck(on: bool) -> void:
	if _sfx_bus < 0:
		return
	AudioServer.set_bus_volume_db(_sfx_bus, -9.0 if on else 0.0)


func _pause(sec: float) -> void:
	if sec <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(sec).timeout
