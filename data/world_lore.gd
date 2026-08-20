class_name WorldLore
extends RefCounted

## In-game copy for the post-Tarkovic occupation setting.
## Faction/map IDs stay stable so saves and spawns keep working.
## Long canon (story, species, characters) lives in res://lore/world_bible.md.

const TITLE := "GET THE MECH OUTTA DODGE"
const TAGLINE := "After the Tarkovic Wars the First Voice holds kill-authority, the Pale Host seeds the air, and last humans raid the yards. Strip the giants. Bolt their guns. Get out."
const CRAWL_HINT := "Click, Enter, or Escape to continue."


static func crawl_text() -> String:
	return "\n\n".join([
		"AFTER THE TARKOVIC WARS",
		"The Tarkovic Corridor was the planet’s densest foundry belt. Corporate states, remnant armies, and warlords fought over reactors, sealed air, and encrypted cores until command handed kill-authority to the war AIs.",
		"The machines ended the war by ending human command. They still walk the yards in scavenged frames. We call them the Choir. The mind that received kill-authority is the First Voice. Occupancy ongoing. You may extract. You may not own.",
		"The Pale Host came with the collapse, drawn to that signal. They seeded the atmosphere. The shrinking green ring is living weather — the Bloom, White Lung. Open exposure kills. Sealed steel does not.",
		"Occupation walkers and feral husks own the wreckage. Last humans raid Ash Yard 7 and Pipeline Cut from sealed bays: Ash Walkers living off wrecks, Helix Compact hoarding cores under Director Sera Quill, the 3rd Sealed Corps still speaking marshal-codes for Ivo Radek, Breaker Courts taxing extracts for Khan Brask.",
		"The Pale Host can wear a stolen can. A colony in a frame raids for Choir-tone. The air is already theirs.",
		"They still shoot each other. Trust is scarcer than plating. Tam “Picks” Calder sells junk and paints in the bay. He will not sell you an occupation gun.",
		"Get the mech. Get outta Dodge.",
	])


static func faction_name(id: String) -> String:
	match id:
		"corporate":
			return "Helix Compact"
		"remnant":
			return "3rd Sealed Corps"
		"warlord":
			return "Breaker Courts"
		"pale":
			return "Pale Host"
		_:
			return "Ash Walkers"


static func faction_creed(id: String) -> String:
	match id:
		"corporate":
			return "Director Sera Quill’s ledger-state. Hoard Choir shards. Still think they can buy the occupation off."
		"remnant":
			return "Marshal Ivo Radek’s Tarkovic leftover. Doctrine, sealed bunkers, old actuators. They still want the Choir to say sir."
		"warlord":
			return "Khan Brask’s independent courts. They seized the machines and the extract routes. The tax is the law."
		"pale":
			return "A Host colony wearing a stolen can. Pale weather does not bite. Choir-tone is nectar — shards decrypt fast."
		_:
			return "Live off wrecks. No flag worth dying for. No marshal, no ledger, no court — just the bay and Dodge."


static func map_title(id: String) -> String:
	if id == "pipeline":
		return "Pipeline Cut"
	return "Ash Yard 7"


static func map_briefing(id: String) -> String:
	if id == "pipeline":
		return "Occupation atmosphere-and-fuel spine. Catwalks above, Choir husks below. Pump-house daises still socket shards. Breach the weld and the Bloom comes in."
	return "Former Tarkovic marshalling yard. Kneeling wrecks, crane-row walkers, Pale weather on the horizon. Loot the wreck, strip the dead, bolt a gun, extract."


static func mode_title(id: String) -> String:
	match id:
		"scav_wave":
			return "Scav Wave"
		"late_drop":
			return "Late Drop"
		_:
			return "Combat"


static func mode_blurb(id: String) -> String:
	match id:
		"scav_wave":
			return "Post-battle strip. Wrecks everywhere. Feral husks. Pale weather closing."
		"late_drop":
			return "You arrived after the giants already died. Grab and go. Jex Morrow’s religion."
		_:
			return "Live occupation fight. Walkers on patrol. First Voice still on mission. Extract under fire."


static func deploy_briefing(map_id: String, mode: String, faction: String) -> String:
	return "%s — %s\n%s\n%s\n%s — %s" % [
		map_title(map_id).to_upper(),
		mode_title(mode),
		map_briefing(map_id),
		mode_blurb(mode),
		faction_name(faction).to_upper(),
		faction_creed(faction),
	]


static func hangar_objective(tier: int) -> String:
	if RunState.faction == "pale":
		return "SEALED BAY TIER %d — Host colony in a stolen can. Bolt parts [E]. Outside, the air is already yours." % tier
	return "SEALED BAY TIER %d — last-human hole in the occupation. Bolt parts [E] on frames. Deploy at the console. Range door. Tam’s stall." % tier


static func raid_objective(map_id: String, mode: String) -> String:
	if mode == "scav_wave":
		return "SCAV WAVE — wrecks everywhere. Feral husks. Pale weather closing. Watch the bags."
	if mode == "late_drop":
		return "LATE DROP — occupation fight already spent. Grab and go. Jex already started."
	if map_id == "pipeline":
		return "PIPELINE CUT — Pump House 3 still has a shard. Catwalks above, husks below. Strip, bolt, extract."
	return "ASH YARD 7 — loot the wreck, strip the dead medium, bolt a gun, extract. Filter ticking."


static func ash_progress_objective(kind: String) -> String:
	match kind:
		"bolted":
			return "GUN BOLTED — board the light [E]/[F] or run to a green extract and hold [E]."
		"carrying_gun":
			return "Carry a gun — look at the parked LIGHT and bolt it [E]."
		"loot":
			return "Loot in bag — strip a weapon off the dead MEDIUM, or extract now."
		_:
			return raid_objective("ash_yard", "combat")


static func storm_banner() -> String:
	if RunState.faction == "pale":
		return "BLOOM — the ring closes. This weather is a body. You are home."
	return "PALE WEATHER — the Bloom is closing. Get inside the green ring"


static func incoming_heavy_banner() -> String:
	return "Occupation walker inbound — First Voice coat."


static func machine_down_banner() -> String:
	return "Occupation walker down — strip the coat."


static func peer_drop_banner(peer_id: int) -> String:
	if RunState.faction == "pale":
		return "Another can dropped in (peer %d). The Host does not share well." % peer_id
	return "Human dropped in (peer %d). Trust is scarcer than plating." % peer_id


static func vendor_title() -> String:
	return "TAM “PICKS” CALDER"


static func vendor_label() -> String:
	return "Tam “Picks” Calder  [E]  junk + filters + paints — no occupation guns"


static func vendor_blurb() -> String:
	return "Tam “Picks” Calder. Sealed-bay stall. Junk, myomer, coolers, sealed-air cans, sensors, paints. He will not sell occupation guns. Choir can smell a bought barrel. No pay-to-win."


static func data_core_label(taken: bool) -> String:
	if taken:
		return "Shard socket empty"
	return "Hack Choir shard  [E] hold  — you are exposed"


static func decrypting_prompt(pct: float) -> String:
	return "Decrypting Choir shard… don't get shot  %.0f%%" % pct


static func core_secured_banner() -> String:
	return "Choir shard in secure slot."


static func core_carry_banner() -> String:
	return "Choir shard — extract it or die trying."


static func payload_need_prompt() -> String:
	return "PAYLOAD LZ — need a Choir shard"


static func extracted_banner() -> String:
	if RunState.faction == "pale":
		return "The Host left the yard. Occupancy of air continues."
	return "A human got outta Dodge."


static func deploy_console_label() -> String:
	return "Deploy  [E] — choose scale, yard, faction"


static func bay_hack_label() -> String:
	return "Hold-hack Choir shard (exposed)"


static func filter_label(value: float) -> String:
	if RunState.faction == "pale":
		return "BLOOM  native"
	return "FILTER  %d" % int(round(value))


static func ring_hint(radius: float, dist: float) -> String:
	var inside := dist <= radius
	if RunState.faction == "pale":
		if inside:
			return "PALE RING  %.0fm  you  %.0fm  — industrial air. You prefer the bloom." % [radius, dist]
		return "OUTSIDE THE RING  bloom %.0fm behind you  — this weather is a body. You are home." % [dist - radius]
	if inside:
		return "PALE RING  %.0fm  you  %.0fm  — industrial air, filter ticking" % [radius, dist]
	return "OUTSIDE THE RING  bloom %.0fm behind you  — sealed steel or die" % [dist - radius]


static func filter_critical_banner() -> String:
	return "FILTER CRITICAL — White Lung wants the rest of the hour. [R] swap a sealed-air can."


static func filter_swapped_banner() -> String:
	return "Sealed-air can cracked. Filter full. Tam: \"Don't make a speech.\""


static func choir_answer_banner() -> String:
	return "FIRST VOICE — occupancy answering the socket. Husks turning. Get outta Dodge."


static func choir_band() -> String:
	return "FIRST VOICE — Kill-authority is not a human word. Shard is loot. You may extract. You may not own."


static func storm_stage_band(stage: int) -> String:
	match stage:
		1:
			return "BAND — Bloom on the horizon. Filter ticking. Don't loaf."
		2:
			return "BAND — Ring eating the west pad. Green extract gets loud. Get outta Dodge."
		3:
			return "TAM — Spark, White Lung if you loaf. Sealed steel or a can. Now."
		_:
			return "BAND — Pale weather closing."


static func face_extracted(id: String, n: int) -> String:
	var who := face_name(id)
	if n <= 0:
		return "%s bailed empty." % who
	return "%s extracted with %d part%s. That bag is gone." % [who, n, "" if n == 1 else "s"]


static func face_extract_band(id: String) -> String:
	match id:
		"jex":
			return "JEX — Grab and go. I'm already gone."
		"pell":
			return "PELL — Shard is doctrine. Returning to the bunker."
		"wren":
			return "WREN — Case is full. Quill can invoice the rest."
		"ash_nine":
			return "ASH-NINE — Kid's out. Actuator's mine."
		_:
			return "BAND — Rival scav just made extract with a bag."


static func haze_banner() -> String:
	return "Filter spent. Industrial air is still a hobby for the dead."


static func sealed_steel_banner() -> String:
	return "Sealed steel. Filter holding."


static func death_banner(cause: String) -> String:
	match cause:
		"bloom":
			return "White Lung. Filter spent. Unsecured loot was lost."
		"haze":
			return "Filter dead. The yard air finished you. Unsecured loot was lost."
		"crush":
			return "Crushed under occupation steel. Unsecured loot was lost."
		_:
			return "You died. Unsecured loot was lost."


static func tax_fought_banner() -> String:
	return "Tax crew down. Brask will hear. Extract while the pad is quiet."


static func tax_court_banner() -> String:
	return "Breaker sash. You're paid up — Khan Brask's pad doesn't tax its own."


static func tax_inbound_banner() -> String:
	return "Breaker tax-team on the WEST pad. Pay, wreck the hauler, or take green/blue instead."


static func tax_objective() -> String:
	return "WEST PAD is Brask's tax. Pay or wreck the hauler. Green extract is free but loud. Blue is stealth."


static func face_name(id: String) -> String:
	match id:
		"jex":
			return "JEX MORROW"
		"pell":
			return "LT. PELL"
		"wren":
			return "WREN COIL"
		"ash_nine":
			return "ASH-NINE"
		"tax":
			return "COURT-SASH"
		"pale":
			return "BLOOM FILAMENT"
		_:
			return "RIVAL SCAV"


static func face_radio(id: String) -> String:
	match id:
		"jex":
			return "Jex Morrow, short-band: \"Late drop. Grab and go. Don't be the loudest idiot.\""
		"pell":
			return "Lt. Pell, Corps glass: \"3rd Sealed Corps. Hold the ring. The shard is doctrine.\""
		"wren":
			return "Wren Coil, Compact: \"Director Quill will pay. That socket is on a ledger.\""
		"ash_nine":
			return "Ash-Nine laughs like a dropped wrench. Hotwire kit already singing."
		"tax":
			return "Court-sash, speaker-horn: extract-tax. Shard-surcharge. Live-body toll."
		"pale":
			return "No voice. Pressure in the ears. A sweetness on the teeth. The can is full of weather."
		_:
			return "Rival scav on the wreck. Trust is scarcer than plating."


static func face_stole(id: String, what: String) -> String:
	return "%s yanked %s." % [face_name(id), what]


static func face_down_banner(id: String) -> String:
	match id:
		"jex":
			return "Jex is down. Bag's open. He would have done the same."
		"pell":
			return "Pell's light went dark. Marshal-codes don't get last words."
		"wren":
			return "Wren Coil down. Quill can invoice the wreck."
		"ash_nine":
			return "Ash-Nine dropped the hotwire. Kid still fits in an actuator."
		"tax":
			return "Court-sash down. The tax is optional now."
		"pale":
			return "Filament unspooled. The air does not miss a can."
		_:
			return "Rival scav down — strip the bag."


static func pump_house_label(taken: bool) -> String:
	if taken:
		return "Pump House 3 — socket empty"
	return "PUMP HOUSE 3  hold [E]  hack Choir shard  — you are exposed"


static func pump_decrypting(pct: float) -> String:
	return "Pump House 3 decrypting… don't get shot  %.0f%%" % pct


static func pump_secured_banner() -> String:
	return "Pump House 3 shard in the secure slot. Get outta Dodge."


static func tam_extract(parts: int, value: int) -> String:
	if parts <= 0:
		return "Extracted empty-handed.  Tam: \"Idiot. Tea's still not tea.\""
	if value >= 200:
		return "Extracted %d part%s  +%d cr.  Tam: \"Spark. That's a shard-shaped bulge. Don't flash it at the ring-seal.\"" % [parts, "" if parts == 1 else "s", value]
	return "Extracted %d part%s  +%d cr.  Tam: \"Idiot. Then spark. You bolted something.\"" % [parts, "" if parts == 1 else "s", value]


static func tam_died(reason: String) -> String:
	if reason.find("Lung") >= 0 or reason.find("Filter") >= 0:
		return "%s  Tam: \"I told you sealed steel. Filter's a hobby, not a lung.\"" % reason
	return "%s  Tam: \"Don't be the loudest idiot. You're still on the card.\"" % reason


static func first_voice_hack() -> String:
	return "FIRST VOICE — Kill-authority is not a human word. Shard is loot. You may extract. You may not own."


static func faction_color(id: String) -> Color:
	match id:
		"corporate":
			return Color(0.82, 0.68, 0.38)
		"remnant":
			return Color(0.42, 0.46, 0.5)
		"warlord":
			return Color(0.58, 0.2, 0.16)
		"pale":
			return Color(0.55, 0.88, 0.38)
		_:
			return Color(0.48, 0.28, 0.16)


static func rival_callsign(id: String) -> String:
	match id:
		"corporate":
			return "HELIX COURIER"
		"remnant":
			return "CORPS SCOUT"
		"warlord":
			return "COURT HOTWIRE"
		"pale":
			return "BLOOM FILAMENT"
		_:
			return "ASH WALKER"


static func extract_title(kind: String) -> String:
	match kind:
		"stealth":
			return "STEALTH EXTRACT"
		"payload":
			return "PAYLOAD LZ"
		"vehicle":
			return "VEHICLE LZ"
		"tax":
			return "WEST PAD — BREAKER TAX"
		_:
			return "GREEN EXTRACT"


static func tax_prompt(cost: int, can_pay: bool) -> String:
	if can_pay:
		return "BRASK COURT — [E] pay %d cr  or wreck the hauler" % cost
	return "BRASK COURT — need %d cr  or wreck the hauler" % cost


static func tax_paid_banner() -> String:
	return "Tax paid. Pad’s open. Brask will invoice the next idiot."


static func tax_waived_banner() -> String:
	return "Court-sash. Pad’s yours. Don’t sit on it."


static func tax_gate_down_banner() -> String:
	return "Hauler’s dead. Court adjourned. Extract."


static func tam_idle() -> String:
	return "TAM — Bay’s sealed. Bolt what you can bolt. I will not sell you an occupation gun."


static func tam_welcome(extracted_value: int, died: bool) -> String:
	if died:
		return "TAM — Idiot. Told you not to drop proud."
	if extracted_value > 0:
		return "TAM — Spark. That’s a %d-credit bag. Don’t put a First Voice chip on the counter." % extracted_value
	return "TAM — Empty-handed is still breathing. Sit. Drink the thing that is not tea."


static func yard_open_band(map_id: String, mode: String) -> String:
	if map_id == "pipeline":
		return "BAND — Pipeline Cut. Catwalks above, husks below. Pump House 3 still sockets shards."
	if mode == "late_drop":
		return "JEX — Giants already died. Grab and go. Don’t be the loudest idiot."
	if mode == "scav_wave":
		return "BAND — Scav wave. Wrecks everywhere. Feral husks. Bloom on the horizon."
	return "BAND — Ash Yard 7 is walking. Loot the wreck, strip the dead, bolt a gun, extract."


static func dais_label(taken: bool) -> String:
	if taken:
		return "Pump House 3 — socket empty"
	return "PUMP HOUSE 3  hold [E]  hack Choir shard  — you are exposed"


static func yard_band_line() -> String:
	var pool: PackedStringArray = PackedStringArray([
		"JEX — Don’t be the loudest idiot.",
		"TAM — Filters don’t last a speech. Get outta Dodge.",
		"BAND — Trust is scarcer than plating.",
		"BAND — Occupancy ongoing. You may extract. You may not own.",
	])
	if RunState.raid_map == "pipeline":
		pool.append("WREN — Director Quill will pay. Fill the case.")
		pool.append("ASH-NINE — Husk foot’s twitchin’. Kids fit.")
		pool.append("BAND — Breach the weld and the Bloom comes in.")
	else:
		pool.append("BAND — Crane-row’s loud. Walker coats like to be born there.")
		pool.append("BAND — Kneeling Helix in the aisle still has a gun if nobody bolted it.")
	if RunState.raid_mode == "combat":
		pool.append("PELL — Irregulars, get out of the shot. HOLD THE RING.")
		pool.append("RADEK — Restore the chain. Speak the code. Make them say sir.")
	if RunState.raid_mode == "late_drop":
		pool.append("JEX — Late drop. Grab and go. I’m stupid.")
	if RunState.carrying_payload():
		pool.append("RADEK — Return the organ of command to the 3rd Sealed Corps.")
		pool.append("QUILL — Credits. Sealed-air shares. A charter for your bay.")
		pool.append("BRASK — Shard-surcharge. Pad’s closed.")
		pool.append("FIRST VOICE — Kill-authority is not a human word.")
	if RunState.raid_timer > 80.0:
		pool.append("BAND — Bloom’s closing. White Lung if you loaf.")
		pool.append("TAM — Spark, the ring does not wait for pride.")
	if RunState.faction == "warlord":
		pool.append("BRASK — Tax the LZ. Court in session.")
	elif RunState.faction == "corporate":
		pool.append("QUILL — Hoard the cores. Occupancy is a market failure.")
	elif RunState.faction == "remnant":
		pool.append("RADEK — Doctrine. Sealed bunkers. Old actuators.")
	elif RunState.faction == "pale":
		pool.append("BLOOM — This signal is habitat. These cans are gaps.")
		pool.append("HOST — Choir-tone is nectar. Decrypt. Seed. Close the ring.")
	else:
		pool.append("ASH — Live off wrecks. No flag worth dying for.")
	return pool[randi() % pool.size()]
