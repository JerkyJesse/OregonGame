class_name WorldLore
extends RefCounted

## In-game copy for the post-Tarkovic occupation setting.
## Faction/map IDs stay stable so saves and spawns keep working.

const TITLE := "GET THE MECH OUTTA DODGE"
const TAGLINE := "After the Tarkovic Wars, Choir war-AIs and the Pale Host own the yards. Last humans raid the wrecks. Strip the giants. Bolt their guns. Get out."
const CRAWL_HINT := "Click, Enter, or Escape to continue."


static func crawl_text() -> String:
	return "\n\n".join([
		"AFTER THE TARKOVIC WARS",
		"The corridor burned until command handed kill-authority to the war AIs. The machines ended the war by ending human command.",
		"They still walk the yards in scavenged frames. We call them the Choir.",
		"The Pale Host came with the collapse. They seeded the air. Open exposure kills. Sealed steel does not.",
		"Occupation walkers and feral husks own the wreckage. The last human factions raid those yards for parts, cores, and enough steel to stay breathing.",
		"They still shoot each other. Trust is scarcer than plating.",
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
			return "Hoard the cores. Still think they can buy the occupation off."
		"remnant":
			return "Tarkovic military leftover. Doctrine, sealed bunkers, old actuators."
		"warlord":
			return "Independent khans who seized the machines and the extract routes."
		_:
			return "Live off wrecks. No flag worth dying for."


static func map_title(id: String) -> String:
	if id == "pipeline":
		return "Pipeline Cut"
	return "Ash Yard 7"


static func map_briefing(id: String) -> String:
	if id == "pipeline":
		return "Sealed atmosphere-and-fuel spine the occupation still uses. Catwalks above, Choir husks below."
	return "Former Tarkovic marshalling yard. Choir husks and Pale weather. Loot the wreck, strip the dead, bolt a gun, extract."


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
			return "Post-battle strip. Wrecks everywhere. Rival husks. Pale weather closing."
		"late_drop":
			return "You arrived after the giants already died. Grab and go."
		_:
			return "Live occupation fight. Walkers on patrol. Extract under fire."


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
	return "SEALED BAY TIER %d — last-human hole in the occupation. Bolt parts [E] on frames. Deploy at the console. Range door. Vendor." % tier


static func raid_objective(map_id: String, mode: String) -> String:
	if mode == "scav_wave":
		return "SCAV WAVE — wrecks everywhere. Choir husks. Pale weather closing."
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
	return "PALE WEATHER — get inside the green ring"


static func incoming_heavy_banner() -> String:
	return "Occupation walker inbound."


static func machine_down_banner() -> String:
	return "Occupation walker down — strip it."


static func peer_drop_banner(peer_id: int) -> String:
	return "Human dropped in (peer %d)." % peer_id


static func vendor_label() -> String:
	return "Yard stall  [E]  junk + paints for sealed-bay survivors (no combat gear P2W)"


static func vendor_blurb() -> String:
	return "Yard stall. Junk and paints for last-human bays. No occupation guns. No pay-to-win."


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
	return "A human extracted."


static func deploy_console_label() -> String:
	return "Deploy  [E] — choose scale, yard, faction"


static func bay_hack_label() -> String:
	return "Hold-hack Choir shard (exposed)"
