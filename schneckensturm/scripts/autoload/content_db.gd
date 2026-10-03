# Autoload: loads every content resource from res://data/<folder>/ and indexes it by id.
# Content is authored as .tres (Inspector / editor plugin), never built in code.
extends Node

const DATA_ROOT := "res://data"

var heroes: Dictionary = {}      # id -> HeroData
var units: Dictionary = {}       # id -> UnitData
var towers: Dictionary = {}      # id -> TowerData
var barracks: Dictionary = {}    # id -> BarracksData
var abilities: Dictionary = {}   # id -> AbilityData
var layouts: Dictionary = {}     # id -> MapLayout
var wavesets: Dictionary = {}    # id -> WaveSet
var factions: Dictionary = {}    # id -> FactionData
var dialogs: Dictionary = {}     # id -> DialogData
var target_rules: TargetRuleSet
var balance: BalanceConfig


func _ready() -> void:
	reload()


func reload() -> void:
	heroes = _load_dir("heroes")
	units = _load_dir("units")
	towers = _load_dir("towers")
	barracks = _load_dir("barracks")
	abilities = _load_dir("abilities")
	layouts = _load_dir("maps")
	wavesets = _load_dir("waves")
	factions = _load_dir("factions")
	dialogs = _load_dir("dialogs")
	var rules_path := DATA_ROOT + "/rules/target_rules.tres"
	target_rules = load(rules_path) if ResourceLoader.exists(rules_path) else TargetRuleSet.make_default()
	var bal_path := DATA_ROOT + "/rules/balance.tres"
	balance = load(bal_path) if ResourceLoader.exists(bal_path) else BalanceConfig.new()
	if factions.is_empty() or wavesets.is_empty():
		push_error("ContentDB: no content found under %s (export filter / remap?)" % DATA_ROOT)
	elif OS.is_stdout_verbose() or OS.get_cmdline_user_args().has("--content-report"):
		print("ContentDB: %d heroes, %d units, %d maps, %d wavesets" % [heroes.size(), units.size(), layouts.size(), wavesets.size()])


# All resource file paths below `dir` (recursive). Exported builds list
# converted resources as "*.tres.remap"; the suffix is stripped so load() works.
static func list_resources(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var full := dir.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."):
				out.append_array(list_resources(full))
		else:
			if f.ends_with(".remap"):
				full = full.trim_suffix(".remap")
				f = f.trim_suffix(".remap")
			if (f.ends_with(".tres") or f.ends_with(".res")) and full not in out:
				out.append(full)
		f = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


func _load_dir(sub: String) -> Dictionary:
	var out := {}
	for path in list_resources(DATA_ROOT.path_join(sub)):
		var r = load(path)
		if r == null or not ("id" in r):
			push_warning("ContentDB: skipped %s" % path)
			continue
		var rid := str(r.id)
		if rid == "":
			push_warning("ContentDB: %s has no id" % path)
			continue
		if out.has(rid):
			push_error("ContentDB: duplicate id '%s' (%s)" % [rid, path])
		out[rid] = r
	return out


# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------
func get_hero(id: String) -> HeroData:
	return heroes.get(id, null)


func get_unit(id: String) -> UnitData:
	return units.get(id, null)


func get_waveset(id: String) -> WaveSet:
	return wavesets.get(id, null)


func get_faction(id: String) -> FactionData:
	return factions.get(id, null)


func playable_factions() -> Array[FactionData]:
	var out: Array[FactionData] = []
	for f in factions.values():
		if f.playable:
			out.append(f)
	return out


func heroes_of(faction_id: String) -> Array[HeroData]:
	var out: Array[HeroData] = []
	for h in heroes.values():
		if h.faction_id == faction_id:
			out.append(h)
	out.sort_custom(func(a, b): return a.tier < b.tier or (a.tier == b.tier and a.id < b.id))
	return out


# The building (tower or barracks) with this id, or null.
func get_building(id: String) -> Resource:
	if towers.has(id):
		return towers[id]
	return barracks.get(id, null)
