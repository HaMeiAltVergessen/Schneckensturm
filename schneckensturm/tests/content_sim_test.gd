# Plays every real level headless with a simple scripted defence (Christina on an
# edge tile, rose bushes / rosehips on every slot as the resource allows, Leinen los
# whenever ready) using the live balance config. Every level must be winnable by
# this naive bot; the printout doubles as a rough balance probe.
extends TestSuite

const DT := 1.0 / 30.0
const MAX_TIME := 900.0


func _run() -> void:
	tag = "CONTENT_SIM"
	for ws in GameState.maps():
		expect(ws.layout != null, "%s has a layout" % ws.id)
		if ws.layout == null:
			continue
		var r := _play(ws)
		print("  %s: %s  petals %d/%d  kills %d  leaks %d  t=%ds%s%s" % [ws.id, "WIN" if r["victory"] else "LOSS",
			r["lives"], r["max_lives"], r["kills"], r["leaks"], int(r["time"]),
			"  reason: %s" % r["reason"] if r["reason"] != "" else "",
			"  leaked: %s" % str(r["leaked"]) if not r["leaked"].is_empty() else ""])
		expect(r["time"] < MAX_TIME, "%s finishes" % ws.id)
		expect(r["victory"], "%s must be winnable by the naive bot" % ws.id)


func _play(ws: WaveSet) -> Dictionary:
	var entries := []
	for h in ContentDB.heroes_of(ws.faction_id):
		entries.append(h.match_entry())
	var sim := MatchSim.new()
	sim.setup(ws, entries, ContentDB.target_rules, ContentDB.balance)
	sim.auto_tower_abilities = true
	var leaked := {}
	sim.unit_removed.connect(func(u, why):
		if why == "leaked":
			leaked[u.data.id] = int(leaked.get(u.data.id, 0)) + 1)
	var builds: Array = ContentDB.get_faction(ws.faction_id).buildings()
	var t := 0.0
	while sim.phase != MatchSim.Phase.ENDED and t < MAX_TIME:
		_bot(sim, ws, builds)
		sim.step(DT)
		t += DT
	var r := sim.result()
	r["lives"] = sim.lives
	r["max_lives"] = sim.max_lives
	r["time"] = t
	r["leaked"] = leaked
	sim.dispose()
	return r


func _bot(sim: MatchSim, ws: WaveSet, builds: Array) -> void:
	# Heroes first; buildings only once every hero stands.
	for id in sim.heroes:
		var h: HeroData = sim.heroes[id]["data"]
		var low: bool = sim.hero_hp(id) < sim.heroes[id]["max_hp"] * 0.4
		if sim.heroes[id]["unit"] != null:
			if sim.hero_ability_ready(id) and sim.alive_enemies().size() >= 4:
				sim.trigger_hero_ability(id)
			# like a player: heal when hurt, pull back when the heal is not affordable
			if low and not sim.heal_hero(id) and sim.hero_hp(id) < sim.heroes[id]["max_hp"] * 0.2:
				sim.retreat(sim.heroes[id]["unit"])
			continue
		if low and not sim.heal_hero(id):
			return   # saving up to heal before going back in
		var cells: Array[Vector2i] = ws.layout.deploy_path_cells if h.placement == Enums.Placement.PATH else ws.layout.deploy_edge_cells
		for c in cells:
			if sim.can_deploy_hero(id, c) == MatchSim.DeployError.OK:
				sim.deploy_hero(id, c)
				break
		if sim.heroes[id]["unit"] == null:
			return   # saving up for the hero
	var i := 0
	for c in ws.layout.build_slots:
		var data: Resource = builds[i % builds.size()]
		i += 1
		if sim.can_build(data, c) == MatchSim.DeployError.OK:
			sim.build(data, c)
	# spare resource goes into upgrades, towers first
	for b in sim.buildings:
		if b.is_tower and sim.can_upgrade(b) == MatchSim.DeployError.OK:
			sim.upgrade(b)
	for b in sim.buildings:
		if not b.is_tower and sim.can_upgrade(b) == MatchSim.DeployError.OK:
			sim.upgrade(b)
