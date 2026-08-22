extends Node

const SAVE_PATH := "user://run_state.json"
const PART_DIR := "res://data/parts/"
const SCHEMA := 2
const SLOTS: Array[String] = ["chest", "arm_l", "arm_r", "legs", "reactor", "sensors", "utility"]
const SCALES: Array[String] = ["light", "armor", "medium", "heavy", "vehicle"]
const FACTIONS: Array[String] = ["corporate", "scav", "remnant", "warlord", "pale"]
const PAINTS: Array[Color] = [
	Color(0.52, 0.27, 0.12),
	Color(0.18, 0.22, 0.28),
	Color(0.22, 0.38, 0.28),
	Color(0.55, 0.48, 0.22),
	Color(0.12, 0.12, 0.14),
	Color(0.62, 0.18, 0.12),
	Color(0.48, 0.86, 0.32),
]

const SCALE_CAPS := {
	"scavenger": {"weight": 18.0, "secure": 1, "speed": 1.0, "hull": 100.0},
	"light": {"weight": 42.0, "secure": 2, "speed": 1.0, "hull": 160.0},
	"armor": {"weight": 28.0, "secure": 2, "speed": 1.15, "hull": 130.0},
	"medium": {"weight": 90.0, "secure": 3, "speed": 0.82, "hull": 280.0},
	"heavy": {"weight": 180.0, "secure": 5, "speed": 0.55, "hull": 520.0},
	"vehicle": {"weight": 140.0, "secure": 8, "speed": 1.05, "hull": 220.0},
}

var stash: Array[Dictionary] = []
var loadouts: Dictionary = {}
var credits: int = 120
var hangar_tier: int = 1
var repair_skill: float = 0.35
var paint_index: int = 0
var unlocked_scales: Array = ["light", "armor"]
var last_message: String = ""
var in_raid: bool = false
var health: float = 100.0
var raid_carry: Array[Dictionary] = []
var secure_carry: Array[Dictionary] = []
var raid_mode: String = "combat"
var raid_map: String = "ash_yard"
var faction: String = "scav"
var deploy_scale: String = "scavenger"
var raid_timer: float = 0.0
var heavy_engaged: bool = false
var extracted_value: int = 0
var filter: float = 100.0
var tax_cleared: bool = false
var extracts_completed: int = 0
var last_extract_tags: Array = []
var vendor_rotation: int = 0
var walkthrough: bool = false
const FILTER_MAX := 100.0


func _ready() -> void:
	_empty_loadouts()
	if not load_state():
		new_game()


func new_game() -> void:
	if not walkthrough and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	stash.clear()
	_empty_loadouts()
	credits = 120
	hangar_tier = 1
	repair_skill = 0.35
	paint_index = 0
	unlocked_scales = ["light", "armor"]
	faction = "scav"
	deploy_scale = "scavenger"
	raid_mode = "combat"
	raid_map = "ash_yard"
	last_message = ""
	in_raid = false
	health = 100.0
	extracts_completed = 0
	last_extract_tags.clear()
	vendor_rotation = 0
	raid_carry.clear()
	secure_carry.clear()
	stash.append(make_part("armor_plate", 1.0))
	stash.append(make_part("actuator_leg", 0.9))
	stash.append(make_part("vulcan_chest", 0.85))
	stash.append(make_part("compact_reactor", 0.8))
	stash.append(make_part("myomer_strand", 0.92))
	stash.append(make_part("sensor_suite", 0.9))
	stash.append(make_part("filter_canister", 1.0))
	_seed_starter_loadout()
	save_state()


func _seed_starter_loadout() -> void:
	var gun := make_part("vulcan_chest", 0.95)
	var reac := make_part("compact_reactor", 0.9)
	var legs := make_part("myomer_strand", 0.92)
	if not gun.is_empty():
		loadouts["light"]["chest"] = gun
		loadouts["armor"]["chest"] = make_part("vulcan_chest", 0.9)
	if not reac.is_empty():
		loadouts["light"]["reactor"] = reac
		loadouts["armor"]["reactor"] = make_part("compact_reactor", 0.88)
	if not legs.is_empty():
		loadouts["light"]["legs"] = legs
		loadouts["armor"]["legs"] = make_part("myomer_strand", 0.9)
	var sens := make_part("sensor_suite", 0.9)
	if not sens.is_empty():
		loadouts["light"]["sensors"] = sens


func _empty_loadouts() -> void:
	loadouts.clear()
	for scale in SCALES:
		var slots := {}
		for slot in SLOTS:
			slots[slot] = {}
		loadouts[scale] = slots


func make_part(id: String, condition: float = 1.0) -> Dictionary:
	var path := "%s%s.tres" % [PART_DIR, id]
	var res: Resource = load(path)
	if res == null:
		push_error("Unknown part id: %s" % id)
		return {}
	var d: Dictionary = res.to_dict()
	d["condition"] = clampf(condition, 0.05, 1.0)
	d["uid"] = "%s_%d_%d" % [id, Time.get_ticks_usec(), randi()]
	return d


func part_display_name(id: String) -> String:
	var res: Resource = load("%s%s.tres" % [PART_DIR, id])
	if res is PartData:
		return (res as PartData).display_name
	return id


func catalog_ids() -> PackedStringArray:
	return PackedStringArray([
		"vulcan_chest", "knee_vulcan", "pulse_cannon", "missile_pod", "pile_bunker",
		"armor_plate", "heavy_plating", "actuator_leg", "myomer_strand",
		"reactor_core", "compact_reactor", "cooler_pack", "sensor_suite",
		"jump_jets", "data_core", "shield_emitter", "filament_veil", "filter_canister",
	])


func get_equipped(slot: String, scale: String = "") -> Dictionary:
	var s := scale if scale != "" else _active_scale()
	var pack: Variant = loadouts.get(s, {})
	if pack is Dictionary:
		var part: Variant = (pack as Dictionary).get(slot, {})
		if part is Dictionary:
			return part
	return {}


func _active_scale() -> String:
	if deploy_scale == "scavenger":
		return "light"
	return deploy_scale


func has_weapon_equipped(scale: String = "") -> bool:
	for slot in SLOTS:
		var part := get_equipped(slot, scale)
		if not part.is_empty() and bool(part.get("is_weapon", false)):
			return true
	return false


func best_weapon(scale: String, equipped: Dictionary = {}) -> Dictionary:
	var source: Dictionary = equipped
	if source.is_empty():
		var pack: Variant = loadouts.get(scale, {})
		if pack is Dictionary:
			source = pack
	var best: Dictionary = {}
	var dmg := -1.0
	for slot in SLOTS:
		var part: Variant = source.get(slot, {})
		if part is Dictionary and bool(part.get("is_weapon", false)):
			var c := float(part.get("condition", 1.0))
			var v := float(part.get("damage", 10.0)) * lerpf(0.4, 1.0, c)
			if v > dmg:
				dmg = v
				best = part
	return best


func stash_for_slot(slot: String, scale: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := scale if scale != "" else _active_scale()
	for part in stash:
		if str(part.get("slot", "")) != slot:
			continue
		if scale_ok(part, s):
			out.append(part)
	return out


func scale_ok(part: Dictionary, scale: String) -> bool:
	var tags: Variant = part.get("scales", [])
	if tags is PackedStringArray:
		return (tags as PackedStringArray).has(scale) or (tags as PackedStringArray).is_empty()
	if tags is Array:
		return (tags as Array).has(scale) or (tags as Array).is_empty()
	return true


func find_stash_index(uid: String) -> int:
	for i in stash.size():
		if str(stash[i].get("uid", "")) == uid:
			return i
	return -1


func equip_uid(uid: String, slot: String, scale: String = "") -> bool:
	var s := scale if scale != "" else _active_scale()
	var idx := find_stash_index(uid)
	if idx < 0:
		return false
	var part: Dictionary = stash[idx]
	if str(part.get("slot", "")) != slot or not scale_ok(part, s):
		return false
	unequip(slot, s, false)
	stash.remove_at(idx)
	loadouts[s][slot] = part
	save_state()
	get_tree().call_group("machine", "apply_loadout")
	return true


func unequip(slot: String, scale: String = "", persist: bool = true) -> void:
	var s := scale if scale != "" else _active_scale()
	var current := get_equipped(slot, s)
	if not current.is_empty():
		stash.append(current)
		loadouts[s][slot] = {}
	if persist:
		save_state()
		get_tree().call_group("machine", "apply_loadout")


func loadout_weight(scale: String, equipped: Dictionary = {}) -> float:
	var w := 0.0
	var source: Dictionary = equipped
	if source.is_empty():
		var pack: Variant = loadouts.get(scale, {})
		if pack is Dictionary:
			source = pack
	for slot in SLOTS:
		var part: Variant = source.get(slot, {})
		if part is Dictionary and not (part as Dictionary).is_empty():
			w += float(part.get("weight", 0.0))
	return w


func cap(scale: String, key: String) -> float:
	var row: Variant = SCALE_CAPS.get(scale, SCALE_CAPS["light"])
	if row is Dictionary:
		return float((row as Dictionary).get(key, 0.0))
	return 0.0


func stash_weight() -> float:
	var w := 0.0
	for part in stash:
		w += float(part.get("weight", 0.0))
	return w


func stash_limit() -> float:
	return 80.0 + float(hangar_tier) * 70.0


func carry_weight() -> float:
	var w := 0.0
	for part in raid_carry:
		w += float(part.get("weight", 0.0))
	for part in secure_carry:
		w += float(part.get("weight", 0.0))
	return w


func carry_limit() -> float:
	return cap(deploy_scale, "weight") * 0.45 + 8.0


func carry_value() -> int:
	var v := 0
	for part in raid_carry:
		v += int(part.get("value", 10))
	for part in secure_carry:
		v += int(part.get("value", 10))
	return v


func carrying_payload() -> bool:
	for part in raid_carry:
		if bool(part.get("is_payload", false)):
			return true
	for part in secure_carry:
		if bool(part.get("is_payload", false)):
			return true
	return false


func has_filter_pack() -> bool:
	return _filter_index(raid_carry) >= 0 or _filter_index(secure_carry) >= 0


func use_filter_pack() -> bool:
	if bloom_native():
		last_message = "The air is already yours."
		return false
	if filter >= FILTER_MAX - 2.0:
		last_message = "Filter still has hours."
		return false
	var bag := raid_carry
	var idx := _filter_index(raid_carry)
	if idx < 0:
		bag = secure_carry
		idx = _filter_index(secure_carry)
	if idx < 0:
		last_message = "No sealed-air can in the bag. Buy one from Tam or strip a wreck."
		return false
	bag.remove_at(idx)
	filter = FILTER_MAX
	last_message = ""
	return true


func _filter_index(bag: Array[Dictionary]) -> int:
	for i in bag.size():
		if str(bag[i].get("id", "")) == "filter_canister":
			return i
	return -1


func _pack_raid_kit() -> void:
	if has_filter_pack():
		return
	for i in stash.size():
		if str(stash[i].get("id", "")) != "filter_canister":
			continue
		var can: Dictionary = stash[i]
		stash.remove_at(i)
		if not add_carry(can):
			stash.insert(i, can)
		return


func _filter_gear_mul() -> float:
	if deploy_scale == "scavenger":
		return 1.0
	var s := _active_scale()
	var mul := 1.0
	for slot in SLOTS:
		var id := str(get_equipped(slot, s).get("id", ""))
		if id == "filter_canister":
			mul = minf(mul, 0.42)
		elif id == "cooler_pack":
			mul = minf(mul, 0.78)
	return mul


func tax_cost() -> int:
	if faction == "warlord":
		return 0
	var cost := 35 + int(float(carry_value()) * 0.2)
	if carrying_payload():
		cost += 90
	return cost


func bloom_native() -> bool:
	return faction == "pale"


func hack_rate() -> float:
	return 0.42 if bloom_native() else 0.28


func apply_faction(id: String) -> void:
	if not FACTIONS.has(id):
		return
	faction = id
	if id == "pale":
		if paint_index == 0:
			paint_index = PAINTS.size() - 1
		_ensure_pale_kit()
	save_state()
	get_tree().call_group("machine", "apply_loadout")
	get_tree().call_group("scavenger", "_paint_faction")


func _ensure_pale_kit() -> void:
	if _has_part("filament_veil"):
		return
	var veil := make_part("filament_veil", 0.94)
	if veil.is_empty():
		return
	var current := get_equipped("sensors", "light")
	if current.is_empty() or str(current.get("id", "")) == "sensor_suite":
		if not current.is_empty():
			stash.append(current)
		loadouts["light"]["sensors"] = veil
		loadouts["armor"]["sensors"] = make_part("filament_veil", 0.9)
	else:
		stash.append(veil)
	var util := get_equipped("utility", "light")
	if util.is_empty():
		loadouts["light"]["utility"] = make_part("cooler_pack", 0.88)


func _has_part(id: String) -> bool:
	for part in stash:
		if str(part.get("id", "")) == id:
			return true
	for scale in SCALES:
		for slot in SLOTS:
			if str(get_equipped(slot, scale).get("id", "")) == id:
				return true
	return false


func can_carry(part: Dictionary) -> bool:
	return carry_weight() + float(part.get("weight", 0.0)) <= carry_limit() + 0.01


func begin_raid() -> void:
	in_raid = true
	raid_carry.clear()
	secure_carry.clear()
	health = cap(deploy_scale if deploy_scale != "scavenger" else "scavenger", "hull")
	if deploy_scale == "scavenger":
		health = 100.0
	raid_timer = 0.0
	heavy_engaged = false
	extracted_value = 0
	filter = FILTER_MAX
	tax_cleared = faction == "warlord"
	_pack_raid_kit()


func add_carry(part: Dictionary, secure: bool = false) -> bool:
	if part.is_empty():
		return false
	if not NetSession.sanity_loot(part):
		return false
	if not in_raid:
		if stash_weight() + float(part.get("weight", 0.0)) > stash_limit() + 0.01:
			last_message = "Stash full."
			return false
		stash.append(part)
		save_state()
		return true
	if not can_carry(part):
		last_message = "Overweight — dump something or extract."
		return false
	if secure and secure_carry.size() < int(cap(deploy_scale, "secure")):
		secure_carry.append(part)
		if bool(part.get("is_payload", false)):
			last_message = WorldLore.core_secured_banner()
	else:
		raid_carry.append(part)
		if bool(part.get("is_payload", false)):
			last_message = WorldLore.core_carry_banner()
	return true


func bank_carry_to_stash() -> int:
	var n := raid_carry.size() + secure_carry.size()
	if n <= 0:
		return 0
	for part in raid_carry:
		stash.append(part)
	for part in secure_carry:
		stash.append(part)
	raid_carry.clear()
	secure_carry.clear()
	save_state()
	return n


func dump_last_carry() -> Dictionary:
	if not raid_carry.is_empty():
		var part: Dictionary = raid_carry.pop_back()
		return part
	return {}


func extract_to_hangar() -> void:
	var n := raid_carry.size() + secure_carry.size()
	var value := 0
	var tags: Array = []
	for part in raid_carry:
		stash.append(part)
		value += int(part.get("value", 10))
		_tag_extract_part(part, tags)
	for part in secure_carry:
		stash.append(part)
		value += int(part.get("value", 10))
		_tag_extract_part(part, tags)
	var salvage := maxi(int(float(value) * 0.35), n * 8) if n > 0 else 0
	credits += salvage
	extracted_value = salvage
	extracts_completed += 1
	last_extract_tags = tags
	vendor_rotation = (vendor_rotation + 1 + tags.size()) % 7
	_unlock_from_wealth()
	raid_carry.clear()
	secure_carry.clear()
	in_raid = false
	health = 100.0
	filter = FILTER_MAX
	tax_cleared = false
	last_message = WorldLore.tam_extract(n, salvage)
	save_state()
	if NetSession.is_online():
		NetSession.on_local_extracted()
	get_tree().change_scene_to_file("res://scenes/hangar.tscn")


func _tag_extract_part(part: Dictionary, tags: Array) -> void:
	if part.is_empty():
		return
	if bool(part.get("is_payload", false)):
		if not tags.has("shard"):
			tags.append("shard")
	elif bool(part.get("is_weapon", false)):
		if not tags.has("gun"):
			tags.append("gun")
	elif str(part.get("id", "")) == "filter_canister":
		if not tags.has("filter"):
			tags.append("filter")
	elif str(part.get("slot", "")) in ["legs", "chest"] or str(part.get("id", "")).contains("plating") or str(part.get("id", "")).contains("armor"):
		if not tags.has("plate"):
			tags.append("plate")
	elif str(part.get("id", "")).contains("reactor") or str(part.get("id", "")).contains("cooler"):
		if not tags.has("power"):
			tags.append("power")
	else:
		if not tags.has("junk"):
			tags.append("junk")


func fail_raid(reason: String, lose_machine: bool = false) -> void:
	if walkthrough:
		health = cap(deploy_scale if deploy_scale != "scavenger" else "scavenger", "hull")
		if deploy_scale == "scavenger":
			health = 100.0
		filter = FILTER_MAX
		return
	raid_carry.clear()
	in_raid = false
	health = 100.0
	extracted_value = 0
	if lose_machine and deploy_scale in SCALES:
		var s: String = deploy_scale
		var pack: Variant = loadouts.get(s, {})
		if pack is Dictionary:
			for slot in SLOTS:
				loadouts[s][slot] = {}
		credits = maxi(credits - 80, 0)
		reason += "  Frame write-off. Installed parts gone."
	if not secure_carry.is_empty():
		for part in secure_carry:
			stash.append(part)
		reason += "  Secure container recovered."
	secure_carry.clear()
	filter = FILTER_MAX
	tax_cleared = false
	last_message = WorldLore.tam_died(reason)
	save_state()
	if NetSession.is_online():
		NetSession.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/hangar.tscn")


func repair_part(uid: String) -> bool:
	var idx := find_stash_index(uid)
	var part: Dictionary = {}
	if idx >= 0:
		part = stash[idx]
	else:
		for scale in SCALES:
			for slot in SLOTS:
				var eq := get_equipped(slot, scale)
				if str(eq.get("uid", "")) == uid:
					part = eq
	if part.is_empty():
		return false
	var cond := float(part.get("condition", 1.0))
	if cond >= 0.99:
		return false
	var cost := maxi(int((1.0 - cond) * float(part.get("value", 40)) * 0.6), 8)
	if credits < cost:
		last_message = "Need %d cr to refurbish." % cost
		return false
	credits -= cost
	var bump := 0.18 + repair_skill * 0.45
	part["condition"] = clampf(cond + bump, 0.05, 1.0)
	repair_skill = clampf(repair_skill + 0.012, 0.1, 0.95)
	save_state()
	get_tree().call_group("machine", "apply_loadout")
	return true


func paint_next() -> void:
	paint_index = (paint_index + 1) % PAINTS.size()
	save_state()
	get_tree().call_group("machine", "apply_loadout")


func paint_color() -> Color:
	return PAINTS[paint_index % PAINTS.size()]


func try_upgrade_hangar() -> bool:
	var cost := hangar_tier * 400
	if hangar_tier >= 3 or credits < cost:
		return false
	credits -= cost
	hangar_tier += 1
	if hangar_tier >= 2 and not unlocked_scales.has("medium"):
		unlocked_scales.append("medium")
		unlocked_scales.append("vehicle")
	if hangar_tier >= 3 and not unlocked_scales.has("heavy"):
		unlocked_scales.append("heavy")
	save_state()
	return true


func _unlock_from_wealth() -> void:
	if credits >= 250 and not unlocked_scales.has("medium"):
		unlocked_scales.append("medium")
		unlocked_scales.append("vehicle")
	if credits >= 700 and not unlocked_scales.has("heavy"):
		unlocked_scales.append("heavy")
	if credits >= 400 and hangar_tier == 1:
		hangar_tier = 2
		if not unlocked_scales.has("medium"):
			unlocked_scales.append("medium")
			unlocked_scales.append("vehicle")


func scale_unlocked(scale: String) -> bool:
	if scale == "scavenger":
		return true
	return unlocked_scales.has(scale)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func vendor_offers() -> Array:
	var offers: Array = [
		["filter_canister", 22],
		["armor_plate", 25],
		["myomer_strand", 30],
		["cooler_pack", 35],
		["sensor_suite", 70],
	]
	var rot := vendor_rotation
	var tags: Array = last_extract_tags
	# Stock shifts after extracts: rotate specialty shelves.
	if extracts_completed >= 1 or hangar_tier >= 2:
		offers.append(["jump_jets", 55 if rot % 2 == 0 else 48])
	if extracts_completed >= 2:
		offers.append(["shield_emitter", 80])
		offers.append(["actuator_leg", 40 if rot % 3 != 0 else 34])
	if hangar_tier >= 3:
		offers.append(["heavy_plating", 90])
	if faction == "pale":
		offers.append(["filament_veil", 95])
	if tags.has("gun") or rot == 1:
		offers.append(["cooler_pack", 28])
		offers.append(["myomer_strand", 26])
	if tags.has("shard") or rot == 2:
		offers.append(["sensor_suite", 58])
		offers.append(["filter_canister", 18])
	if tags.has("plate") or rot == 3:
		offers.append(["armor_plate", 20])
		offers.append(["actuator_leg", 36])
	if tags.has("power") or rot == 4:
		offers.append(["cooler_pack", 30])
		if extracts_completed >= 1:
			offers.append(["compact_reactor", 110])
	if tags.has("filter") or extracts_completed >= 3:
		offers.append(["filter_canister", 16])
	if rot == 5 and extracts_completed >= 2:
		offers.append(["shield_emitter", 72])
	if rot == 6:
		offers.append(["sensor_suite", 62])
	# Deduplicate by part id, keep cheapest quote.
	var best: Dictionary = {}
	for o in offers:
		var pid := str(o[0])
		var cost := int(o[1])
		if not best.has(pid) or cost < int(best[pid]):
			best[pid] = cost
	var out: Array = []
	for pid in best.keys():
		out.append([pid, int(best[pid])])
	out.sort_custom(func(a, b): return int(a[1]) < int(b[1]))
	return out


func vendor_stock_note() -> String:
	var n := extracts_completed
	if n <= 0:
		return "Starter shelf: filters, plate seconds, myomer, coolers, lying sensors. Stock shifts after you extract."
	var tags: Array = last_extract_tags
	var flavor := "Shelf rotated after extract #%d." % n
	if tags.has("shard"):
		flavor += " You flashed Choir-tone — he's pushing sensors and sealed-air."
	elif tags.has("gun"):
		flavor += " You bolted loud — coolers and myomer are on the counter."
	elif tags.has("plate"):
		flavor += " You came back armored — plate seconds and legs are cheap."
	elif tags.has("power"):
		flavor += " Reactor smell on you — coolers and a compact core if you're flush."
	elif tags.has("filter"):
		flavor += " Filter cans discounted. Don't make a speech."
	else:
		flavor += " Junk in, junk out. Check the prices."
	return flavor


func vendor_buy(id: String, cost: int) -> bool:
	if credits < cost:
		return false
	var part := make_part(id, randf_range(0.45, 0.8))
	if part.is_empty():
		return false
	if stash_weight() + float(part.get("weight", 0.0)) > stash_limit():
		return false
	credits -= cost
	stash.append(part)
	save_state()
	return true


func vendor_sell(uid: String) -> int:
	var idx := find_stash_index(uid)
	if idx < 0:
		return -1
	var part: Dictionary = stash[idx]
	if bool(part.get("is_weapon", false)) or bool(part.get("is_payload", false)):
		last_message = "Tam will not take occupation guns or shards."
		return -1
	var pay := maxi(int(float(part.get("value", 10)) * float(part.get("condition", 1.0)) * 0.4), 4)
	credits += pay
	stash.remove_at(idx)
	save_state()
	return pay


func has_raid_payload() -> bool:
	return carrying_payload()


func pay_tax() -> bool:
	if tax_cleared:
		return true
	var c := tax_cost()
	if c <= 0:
		tax_cleared = true
		return true
	if credits < c:
		return false
	credits -= c
	tax_cleared = true
	return true


func tick_filter(delta: float, sealed: bool, in_bloom: bool) -> String:
	if not in_raid:
		return ""
	if bloom_native():
		filter = FILTER_MAX
		return ""
	if sealed:
		filter = minf(FILTER_MAX, filter + 9.0 * delta)
		return ""
	var drain := (14.0 if in_bloom else 1.55) * _filter_gear_mul()
	filter = maxf(0.0, filter - drain * delta)
	if filter > 0.0:
		return ""
	return "bloom" if in_bloom else "haze"


func hotwire_chance() -> float:
	if walkthrough:
		return 1.0
	return clampf(0.28 + repair_skill * 0.55, 0.15, 0.92)


func save_state() -> void:
	if walkthrough:
		return
	var payload := {
		"schema": SCHEMA,
		"stash": _dicts_to_untyped(stash),
		"loadouts": loadouts.duplicate(true),
		"credits": credits,
		"hangar_tier": hangar_tier,
		"repair_skill": repair_skill,
		"paint_index": paint_index,
		"unlocked_scales": unlocked_scales.duplicate(),
		"faction": faction,
		"deploy_scale": deploy_scale,
		"raid_mode": raid_mode,
		"raid_map": raid_map,
		"extracts_completed": extracts_completed,
		"last_extract_tags": last_extract_tags.duplicate(),
		"vendor_rotation": vendor_rotation,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))


func load_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	stash.clear()
	for item in data.get("stash", []):
		if item is Dictionary:
			var normalized := _normalize_part(item)
			if not normalized.is_empty():
				stash.append(normalized)
	_empty_loadouts()
	if data.has("loadouts") and data["loadouts"] is Dictionary:
		var saved: Dictionary = data["loadouts"]
		for scale in SCALES:
			var pack: Variant = saved.get(scale, {})
			if pack is Dictionary:
				for slot in SLOTS:
					var part: Variant = (pack as Dictionary).get(slot, {})
					if part is Dictionary:
						loadouts[scale][slot] = _normalize_part(part)
	elif data.has("loadout") and data["loadout"] is Dictionary:
		var old: Dictionary = data["loadout"]
		for slot in SLOTS:
			var part: Variant = old.get(slot, {})
			if part is Dictionary:
				loadouts["light"][slot] = _normalize_part(part)
	credits = clampi(int(data.get("credits", credits)), 0, 9999999)
	hangar_tier = clampi(int(data.get("hangar_tier", 1)), 1, 3)
	repair_skill = clampf(float(data.get("repair_skill", repair_skill)), 0.0, 1.0)
	paint_index = clampi(int(data.get("paint_index", 0)), 0, PAINTS.size() - 1)
	var un: Variant = data.get("unlocked_scales", unlocked_scales)
	if un is Array:
		var cleaned: Array = []
		for s in un as Array:
			var sid := str(s)
			if sid in SCALES and sid not in cleaned:
				cleaned.append(sid)
		if cleaned.is_empty():
			cleaned = ["light", "armor"]
		unlocked_scales = cleaned
	var fac := str(data.get("faction", faction))
	faction = fac if fac in FACTIONS else "scav"
	var dep := str(data.get("deploy_scale", deploy_scale))
	deploy_scale = dep if (dep == "scavenger" or dep in SCALES) else "scavenger"
	var mode := str(data.get("raid_mode", raid_mode))
	raid_mode = mode if mode in ["combat", "scav_wave", "late_drop"] else "combat"
	var map := str(data.get("raid_map", raid_map))
	raid_map = map if map in ["ash_yard", "pipeline"] else "ash_yard"
	extracts_completed = clampi(int(data.get("extracts_completed", 0)), 0, 999999)
	var tags: Variant = data.get("last_extract_tags", [])
	if tags is Array:
		last_extract_tags = (tags as Array).duplicate()
	else:
		last_extract_tags.clear()
	vendor_rotation = clampi(int(data.get("vendor_rotation", 0)), 0, 64)
	var light_empty := true
	for slot in SLOTS:
		if not get_equipped(slot, "light").is_empty():
			light_empty = false
			break
	if light_empty:
		_seed_starter_loadout()
	return true


func _normalize_part(part: Dictionary) -> Dictionary:
	if part.is_empty() or str(part.get("id", "")) == "":
		return {}
	var base := make_part(str(part["id"]), float(part.get("condition", 1.0)))
	if base.is_empty():
		return {}
	if str(part.get("uid", "")) != "":
		base["uid"] = str(part["uid"])
	if part.has("display_name"):
		base["display_name"] = str(part["display_name"])
	if part.has("paint_id"):
		base["paint_id"] = str(part["paint_id"])
	return base


func _dicts_to_untyped(parts: Array[Dictionary]) -> Array:
	var out: Array = []
	for part in parts:
		out.append(part)
	return out
