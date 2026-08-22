extends Node

const LOOK := preload("res://world/WorldLook.gd")
const OUT_DIR := "res://docs/readme/"


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600, 900)
	get_window().always_on_top = true
	AudioServer.set_bus_mute(0, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Hud.freeze_for_title()
	Settings.quality = "high"
	Settings.apply()
	RunState.hangar_tier = 3
	RunState.unlocked_scales = ["light", "armor", "medium", "heavy", "vehicle"]
	RunState.in_raid = false
	RunState.raid_mode = "combat"
	RunState.raid_map = "ash_yard"
	RunState.deploy_scale = "scavenger"
	RunState.faction = "scav"

	await _shot_title_logo()

	var raid := await _boot("res://scenes/raid.tscn", 8.0)
	# Occupation walkers (28,-38) / (-36,-34), kneeling frame (-8,-18), bloom wall.
	await _snap(raid, "banner.png", Vector3(-2.0, 6.8, 12.0), Vector3(10.0, 7.5, -30.0), 55.0)
	# Closer yard: wreck, parked light, bloom.
	await _snap(raid, "ash_yard.png", Vector3(-24.0, 2.4, 8.0), Vector3(-6.0, 3.5, -10.0), 62.0)
	await _kill(raid)

	var hang := await _boot("res://scenes/hangar.tscn", 4.0)
	# Scavenger spawn toward parked frames and Tam's stall.
	await _snap(hang, "hangar.png", Vector3(0.5, 2.8, 14.2), Vector3(5.5, 3.2, -7.0), 58.0)
	# Size lineup: scavenger, light, armor, medium, heavy, hauler.
	await _snap(hang, "scales.png", Vector3(0.0, 5.4, 16.6), Vector3(0.0, 3.2, -5.0), 55.0)
	await _kill(hang)

	var pipe := await _boot("res://scenes/pipeline.tscn", 4.0)
	# Fuel spine / Pale leak at (0, 6, 14).
	await _snap(pipe, "pipeline.png", Vector3(-16.0, 3.8, 14.0), Vector3(2.0, 3.5, 2.0), 58.0)
	await _kill(pipe)

	print("README_SHOTS_DONE")
	get_tree().quit()


func _shot_title_logo() -> void:
	print("README_SHOT logo.png")
	var packed := load("res://scenes/title.tscn") as PackedScene
	var inst: Node = packed.instantiate()
	add_child(inst)
	if inst is Control:
		(inst as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inst.set_process(false)
	Hud.freeze_for_title()
	_hide_title_ui(inst)
	var stage := _title_stage(inst)
	var vp := _title_viewport(inst)
	await get_tree().create_timer(8.0).timeout
	_hide_title_ui(inst)
	if stage:
		var showcase := stage.get_node_or_null("ShowcaseMech")
		if showcase is Node3D:
			(showcase as Node3D).rotation = Vector3.ZERO
		# Title-stage camera already frames the showcase mech. Pull in slightly for a visor-forward mark.
		for cam in _find_cams(stage):
			cam.current = false
		_place_cam(stage, Vector3(5.4, 6.6, 8.2), Vector3(0.2, 5.9, 0.3), 36.0)
	for _i in 24:
		_hide_title_ui(inst)
		Hud.freeze_for_title()
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = null
	if vp:
		img = vp.get_texture().get_image()
	if img == null:
		img = get_viewport().get_texture().get_image()
	if img:
		img = _square(img)
		await _save(img, "logo.png")
	else:
		push_error("No viewport image for logo.png")
	await _kill(inst)


func _boot(path: String, settle: float) -> Node:
	print("README_BOOT ", path)
	var packed := load(path) as PackedScene
	var inst: Node = packed.instantiate()
	add_child(inst)
	_silence(inst)
	Settings.apply()
	await get_tree().create_timer(settle).timeout
	_silence(inst)
	return inst


func _snap(inst: Node, filename: String, pos: Vector3, look: Vector3, fov: float) -> void:
	print("README_SHOT ", filename)
	var host: Node = inst if inst is Node3D else self
	var old := host.get_node_or_null("ReadmeCam")
	if old:
		old.queue_free()
		await get_tree().process_frame
	_place_cam(host, pos, look, fov)
	_silence(inst)
	for _i in 24:
		_silence(inst)
		await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("No viewport image for %s" % filename)
		return
	img.resize(1600, 900, Image.INTERPOLATE_LANCZOS)
	await _save(img, filename)


func _place_cam(host: Node, pos: Vector3, look: Vector3, fov: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "ReadmeCam"
	host.add_child(cam)
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = fov
	cam.near = 0.08
	cam.far = 520.0
	cam.current = true
	LOOK.tune_camera(cam)
	return cam


func _save(img: Image, filename: String) -> void:
	var out := ProjectSettings.globalize_path(OUT_DIR + filename)
	var err := img.save_png(out)
	if err != OK:
		await get_tree().create_timer(0.4).timeout
		err = img.save_png(out)
	print("README_SHOT_SAVE ", out, " err=", err, " ", img.get_width(), "x", img.get_height())


func _kill(inst: Node) -> void:
	inst.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _silence(root: Node) -> void:
	Hud.freeze_for_title()
	Hud.visible = false
	Hud.layer = -20
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_labels(root)
	_freeze_bodies(root)
	for cam in _find_cams(root):
		if cam.name != "ReadmeCam":
			cam.current = false
			var spot := cam.get_node_or_null("SpotLight3D")
			if spot is Light3D:
				(spot as Light3D).visible = false


func _hide_title_ui(inst: Node) -> void:
	for c in inst.get_children():
		if c.name == "TitleWorld":
			continue
		if c is CanvasItem:
			(c as CanvasItem).visible = false


func _title_viewport(inst: Node) -> SubViewport:
	var tw := inst.get_node_or_null("TitleWorld")
	if tw == null:
		return null
	for c in tw.get_children():
		if c is SubViewport:
			return c as SubViewport
	return null


func _title_stage(inst: Node) -> Node3D:
	var vp := _title_viewport(inst)
	if vp == null:
		return null
	var stage := vp.get_node_or_null("Stage")
	return stage as Node3D


func _freeze_bodies(n: Node) -> void:
	if n is CharacterBody3D or n is RigidBody3D:
		n.set_process(false)
		n.set_physics_process(false)
		n.set_process_unhandled_input(false)
		n.set_process_input(false)
	for c in n.get_children():
		_freeze_bodies(c)


func _hide_labels(n: Node) -> void:
	if n is Label3D:
		(n as Label3D).visible = false
	for c in n.get_children():
		_hide_labels(c)


func _find_cams(n: Node) -> Array[Camera3D]:
	var out: Array[Camera3D] = []
	if n is Camera3D:
		out.append(n as Camera3D)
	for c in n.get_children():
		out.append_array(_find_cams(c))
	return out


func _square(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var s := mini(w, h)
	var x := int((w - s) * 0.5)
	var y := int((h - s) * 0.5)
	var cut := Image.create(s, s, false, img.get_format())
	cut.blit_rect(img, Rect2i(x, y, s, s), Vector2i.ZERO)
	cut.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	return cut
