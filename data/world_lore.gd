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
	return "SEALED BAY TIER %d — last-human hole in the occupation. Bolt parts [E] on frames. Deploy at the console. Range door. Tam’s stall." % tier


static func raid_objective(map_id: String, mode: String) -> String:
	if mode == "scav_wave":
		return "SCAV WAVE — wrecks everywhere. Feral husks. Pale weather closing."
	if mode == "late_drop":
		return "LATE DROP — occupation fight already spent. Grab and go."
	if map_id == "pipeline":
		return "PIPELINE CUT — catwalks above, husks below. Strip, bolt, extract."
	return "ASH YARD 7 — loot the wreck, strip the dead medium, bolt a gun, extract."


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
	return "PALE WEATHER — the Bloom is closing. Get inside the green ring"


static func incoming_heavy_banner() -> String:
	return "Occupation walker inbound — First Voice coat."


static func machine_down_banner() -> String:
	return "Occupation walker down — strip the coat."


static func peer_drop_banner(peer_id: int) -> String:
	return "Human dropped in (peer %d). Trust is scarcer than plating." % peer_id


static func vendor_title() -> String:
	return "TAM “PICKS” CALDER"


static func vendor_label() -> String:
	return "Tam “Picks” Calder  [E]  junk + paints — no occupation guns"


static func vendor_blurb() -> String:
	return "Tam “Picks” Calder. Sealed-bay stall. Junk, myomer, coolers, sensors, paints. He will not sell occupation guns. Choir can smell a bought barrel. No pay-to-win."


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
	return "A human got outta Dodge."


static func deploy_console_label() -> String:
	return "Deploy  [E] — choose scale, yard, faction"


static func bay_hack_label() -> String:
	return "Hold-hack Choir shard (exposed)"
