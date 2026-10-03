# One-shot generator for the Schneckensturm content (.tres under res://data) and the
# procedural iso tileset. Existing files are NEVER overwritten, so balance edits in the
# Inspector are safe; delete a file (or pass --force) to regenerate it.
#   godot --headless --path . --script res://tools/gen_schneckensturm_content.gd [-- --force]
# Art: if assets/garden/<id>.png exists it is used, otherwise a placeholder token.
extends SceneTree

const TILE := Vector2i(128, 64)
const TILE_COLORS := [
	[Color(0.23, 0.30, 0.22), Color(0.18, 0.24, 0.17)],   # 0 ground
	[Color(0.62, 0.52, 0.36), Color(0.50, 0.42, 0.29)],   # 1 path
	[Color(0.66, 0.55, 0.37), Color(0.95, 0.78, 0.30)],   # 2 deploy path (gold rim)
	[Color(0.27, 0.36, 0.26), Color(0.40, 0.65, 0.95)],   # 3 deploy edge (blue rim)
	[Color(0.40, 0.40, 0.44), Color(0.92, 0.92, 0.95)],   # 4 build slot (white rim)
	[Color(0.14, 0.13, 0.15), Color(0.09, 0.08, 0.10)],   # 5 blocked
]
const ART := "res://assets/garden/%s.png"
## Placeholder tokens until the real art exists (assets/units/<group>/<name>_face.png).
const PLACEHOLDER := {
	"gar_christina": "heroes/mira", "gar_rose": "troops/the_seraph",
	"sna_slug": "enemies/imp", "sna_garden_snail": "enemies/gargoyle", "sna_spitter": "enemies/hex_priest",
	"sna_armored": "enemies/bone_colossus", "sna_queen": "enemies/demon_lord",
}

var force := false
var created := 0
var kept := 0
## Wave density of the level being generated: counts x count_mult, intervals x interval_mult.
var count_mult := 1.0
var interval_mult := 1.0


func _initialize() -> void:
	force = "--force" in OS.get_cmdline_user_args()
	_gen_tileset()
	_save(TargetRuleSet.make_default(), "res://data/rules/target_rules.tres")
	_save(BalanceConfig.new(), "res://data/rules/balance.tres")
	var un := _gen_units()
	var ab := _gen_abilities()
	_gen_heroes(ab)
	var bu := _gen_buildings(ab, un)
	var ly := _gen_layouts()
	var dl := _gen_dialogs()
	var ws := _gen_wavesets(un, ly, dl)
	_gen_factions(ws, bu)
	print("GEN_DONE created=%d kept=%d" % [created, kept])
	quit(0)


func _save(res: Resource, path: String) -> Resource:
	if FileAccess.file_exists(path) and not force:
		kept += 1
		return load(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed %s: %d" % [path, err])
	created += 1
	return res


func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


# Real art (assets/garden/<id>.png) or the placeholder token.
func _art(id: String) -> Texture2D:
	var t := _tex(ART % id)
	if t == null and PLACEHOLDER.has(id):
		t = _tex("res://assets/units/%s_face.png" % PLACEHOLDER[id])
	return t


# ---------------------------------------------------------------------------
func _gen_tileset() -> void:
	var png := "res://assets/tiles/placeholder_iso.png"
	if not FileAccess.file_exists(png) or force:
		var img := Image.create(TILE.x * TILE_COLORS.size(), TILE.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for i in TILE_COLORS.size():
			_draw_diamond(img, i * TILE.x, TILE_COLORS[i][0], TILE_COLORS[i][1], i >= 2)
		DirAccess.make_dir_recursive_absolute("res://assets/tiles")
		img.save_png(ProjectSettings.globalize_path(png))
		print("wrote ", png, " (re-run the import, then this generator again for the TileSet)")
	var ts_path := "res://assets/tiles/placeholder_iso_tileset.tres"
	if not ResourceLoader.exists(png):
		return   # texture not imported yet
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = TILE
	var src := TileSetAtlasSource.new()
	src.texture = load(png)
	src.texture_region_size = TILE
	for i in TILE_COLORS.size():
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	_save(ts, ts_path)


# Filled 2:1 diamond; `rim` draws a 3 px border in the second colour.
func _draw_diamond(img: Image, ox: int, fill: Color, edge: Color, rim: bool) -> void:
	var hw := TILE.x / 2.0
	var hh := TILE.y / 2.0
	for y in TILE.y:
		for x in TILE.x:
			var d := absf(x + 0.5 - hw) / hw + absf(y + 0.5 - hh) / hh
			if d > 1.0:
				continue
			var c: Color = fill
			if rim and d > 0.90:
				c = edge
			elif not rim and d > 0.96:
				c = edge
			else:
				# subtle noise so large areas do not look flat
				var n := (sin(x * 12.9898 + y * 78.233) * 43758.5453)
				n = n - floor(n)
				c = c.lightened((n - 0.5) * 0.06)
			img.set_pixel(ox + x, y, c)


# ---------------------------------------------------------------------------
func _ability(id: String, kind: int, power: float, radius: float, duration: float, cooldown: float) -> AbilityData:
	var a := AbilityData.new()
	a.id = id
	a.name_key = "ABILITY_%s_NAME" % id.to_upper()
	a.desc_key = "ABILITY_%s_DESC" % id.to_upper()
	a.kind = kind
	a.power = power
	a.radius = radius
	a.duration = duration
	a.cooldown = cooldown
	return a


func _gen_abilities() -> Dictionary:
	var K := Enums.AbilityKind
	var out := {}
	for a in [
		_ability("leinen_los", K.STRIKE_ALL, 3.0, 0.0, 0.0, 45.0),
		_ability("rosehip_hail", K.STRIKE, 2.5, 1.5, 0.0, 18.0),
	]:
		out[a.id] = _save(a, "res://data/abilities/%s.tres" % a.id)
	return out


func _unit(id: String, faction: String, tc: int, hp: int, atk: int, def: int, interval: float,
		speed: float, reach: float, ranged: bool) -> UnitData:
	var u := UnitData.new()
	u.id = id
	u.name_key = "UNIT_%s_NAME" % id.to_upper()
	u.faction_id = faction
	u.target_class = tc
	u.max_hp = hp
	u.attack = atk
	u.defense = def
	u.attack_interval = interval
	u.move_speed = speed
	u.attack_range = reach
	u.is_ranged = ranged
	u.token = _art(id)
	return u


func _gen_units() -> Dictionary:
	var T := Enums.TargetClass
	# Snails: tier 1 slug (fast, weak) … tier 4 armored (siege), plus the queen.
	var slug := _unit("sna_slug", "snails", T.MELEE, 260, 35, 0, 1.1, 1.15, 0.8, false)
	slug.visual_scale = 0.85
	var snail := _unit("sna_garden_snail", "snails", T.MELEE, 700, 50, 45, 1.4, 0.6, 0.8, false)
	snail.bounty = 2
	var spitter := _unit("sna_spitter", "snails", T.RANGED, 300, 35, 0, 2.0, 0.8, 2.2, true)
	spitter.bounty = 2
	var armored := _unit("sna_armored", "snails", T.SIEGE, 1300, 140, 30, 2.5, 0.5, 1.6, false)
	armored.leak_damage = 2
	armored.block_weight = 2
	armored.bounty = 4
	armored.visual_scale = 1.3
	var queen := _unit("sna_queen", "snails", T.MELEE, 3000, 180, 40, 2.0, 0.4, 0.9, false)
	queen.leak_damage = 99   # reaching the dahlia ends the game at once
	queen.block_weight = 3
	queen.bounty = 10
	queen.is_boss = true
	queen.visual_scale = 1.7
	queen.brood_unit = slug
	queen.brood_interval = 6.0
	queen.brood_count = 2
	# Own troop: the rose warrior from the rose bush.
	var rose := _unit("gar_rose", "garden", T.MELEE, 450, 40, 25, 1.2, 0.0, 0.8, false)
	var out := {}
	for u in [slug, snail, spitter, armored, queen, rose]:
		out[u.id] = _save(u, "res://data/units/%s.tres" % u.id)
	return out


func _pattern(max_manhattan: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-max_manhattan, max_manhattan + 1):
		for dy in range(-max_manhattan, max_manhattan + 1):
			if absi(dx) + absi(dy) <= max_manhattan:
				out.append(Vector2i(dx, dy))
	return out


func _gen_heroes(ab: Dictionary) -> void:
	var h := HeroData.new()
	h.id = "gar_christina"
	h.name_key = "HERO_GAR_CHRISTINA_NAME"
	h.faction_id = "garden"
	h.tier = Enums.HeroTier.LEGEND
	h.hero_class = Enums.HeroClass.RANGED
	h.placement = Enums.Placement.EDGE
	h.max_hp = 1200
	h.attack = 95
	h.defense = 20
	h.attack_interval = 1.0
	h.block = 0
	h.holds_line = false
	h.deploy_cost = 8
	h.redeploy_cooldown = 15.0
	h.range_pattern = _pattern(3)
	h.ability = ab["leinen_los"]
	h.essential = true
	h.token = _art(h.id)
	h.portrait = h.token
	_save(h, "res://data/heroes/%s.tres" % h.id)


func _gen_buildings(ab: Dictionary, un: Dictionary) -> Dictionary:
	var out := {}
	var hip := TowerData.new()
	hip.id = "gar_rosehip"
	hip.name_key = "TOWER_GAR_ROSEHIP_NAME"
	hip.faction_id = "garden"
	hip.cost = 12
	hip.max_hp = 700
	hip.attack = 80
	hip.attack_interval = 1.4
	hip.attack_range = 3.5
	hip.ability = ab["rosehip_hail"]
	hip.color = Color(0.85, 0.30, 0.20)
	hip.texture = _tex(ART % hip.id)
	add_tower_levels(hip)
	out[hip.id] = _save(hip, "res://data/towers/%s.tres" % hip.id)
	var bush := BarracksData.new()
	bush.id = "gar_rose_bush"
	bush.name_key = "BARRACKS_GAR_ROSE_BUSH_NAME"
	bush.faction_id = "garden"
	bush.unit = un["gar_rose"]
	bush.cost = 10
	bush.max_hp = 900
	bush.respawn_time = 12.0
	bush.squad_size = 2
	bush.color = Color(0.85, 0.35, 0.50)
	bush.texture = _tex(ART % bush.id)
	add_barracks_levels(bush)
	out[bush.id] = _save(bush, "res://data/barracks/%s.tres" % bush.id)
	return out


# Upgrade curve: level 2 and 3, each ~+35 % damage and -15 % interval; skin per level if present.
func add_tower_levels(t: TowerData) -> void:
	t.upgrades.clear()
	for i in [1, 2]:
		var lv := TowerLevel.new()
		lv.cost = roundi(t.cost * (0.4 + 0.4 * i))
		lv.attack = roundi(t.attack * pow(1.35, i))
		lv.attack_interval = snappedf(t.attack_interval * pow(0.85, i), 0.01)
		lv.texture = _tex(ART % ("%s_%d" % [t.id, i + 1]))
		t.upgrades.append(lv)


# Upgrade curve for barracks: troops x1.325 and x1.65.
func add_barracks_levels(b: BarracksData) -> void:
	b.upgrades.clear()
	for i in [1, 2]:
		var lv := BarracksLevel.new()
		lv.cost = roundi(b.cost * (0.4 + 0.4 * i))
		lv.troop_mult = 1.0 + 0.325 * i
		lv.texture = _tex(ART % ("%s_%d" % [b.id, i + 1]))
		b.upgrades.append(lv)


# ---------------------------------------------------------------------------
func _path(points: Array) -> MapPath:
	# points: corner cells; straight orthogonal runs are filled in between.
	var p := MapPath.new()
	for i in points.size():
		var c: Vector2i = points[i]
		if i == 0:
			p.cells.append(c)
			continue
		var prev: Vector2i = p.cells[p.cells.size() - 1]
		var step := Vector2i(signi(c.x - prev.x), signi(c.y - prev.y))
		while prev != c:
			prev += step
			p.cells.append(prev)
	return p


func _cells(arr: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in arr:
		out.append(c)
	return out


# No path deploy cells: Christina is the only hero and stands on edge tiles.
func _layout(id: String, size: Vector2i, paths: Array, dedge: Array, builds: Array) -> MapLayout:
	var l := MapLayout.new()
	l.id = id
	l.name_key = "MAP_%s_NAME" % id.to_upper()
	l.size = size
	for p in paths:
		l.paths.append(p)
	l.deploy_edge_cells = _cells(dedge)
	l.build_slots = _cells(builds)
	l.hero_limit = 1
	return l


func _gen_layouts() -> Dictionary:
	var out := {}
	# L1 windowsill: one winding path.
	var l1 := _layout("layout_gar_l1", _v(14, 9),
		[_path([_v(0, 2), _v(6, 2), _v(6, 6), _v(13, 6)])],
		[_v(3, 1), _v(5, 1), _v(7, 5), _v(8, 7), _v(10, 7), _v(12, 5)],
		[_v(2, 3), _v(4, 1), _v(5, 4), _v(7, 3), _v(9, 5), _v(11, 7)])
	# L2 carpet maze: two paths meeting in the middle.
	var l2 := _layout("layout_gar_l2", _v(14, 11),
		[_path([_v(0, 1), _v(5, 1), _v(5, 5), _v(13, 5)]), _path([_v(0, 9), _v(5, 9), _v(5, 5), _v(13, 5)])],
		[_v(4, 2), _v(4, 8), _v(7, 4), _v(7, 6), _v(10, 4), _v(11, 6)],
		[_v(3, 3), _v(3, 7), _v(6, 3), _v(6, 7), _v(9, 4), _v(9, 6), _v(12, 4)])
	# L3 bedside table: long serpentine to the dahlia.
	var l3 := _layout("layout_gar_l3", _v(16, 10),
		[_path([_v(0, 1), _v(4, 1), _v(4, 7), _v(10, 7), _v(10, 2), _v(15, 2)])],
		[_v(5, 3), _v(5, 8), _v(9, 5), _v(9, 8), _v(11, 1), _v(14, 1)],
		[_v(2, 2), _v(3, 5), _v(6, 6), _v(8, 6), _v(7, 4), _v(11, 4), _v(13, 3)])
	for l in [l1, l2, l3]:
		out[l.id] = _save(l, "res://data/maps/%s.tres" % l.id)
	return out


# lines: [[speaker_key, portrait_id or ""], ...] -> keys DIALOG_<ID>_<n>
func _dialog(id: String, lines: Array) -> DialogData:
	var d := DialogData.new()
	d.id = id
	for i in lines.size():
		var line := DialogLine.new()
		line.speaker_name_key = lines[i][0]
		line.text_key = "DIALOG_%s_%d" % [id.to_upper(), i + 1]
		line.portrait = _art(lines[i][1]) if lines[i][1] != "" else null
		d.lines.append(line)
	return d


func _gen_dialogs() -> Dictionary:
	var NAR := ["DIALOG_SPEAKER_NARRATOR", ""]
	var MOM := ["DIALOG_SPEAKER_MOM", ""]
	var CHR := ["HERO_GAR_CHRISTINA_NAME", "gar_christina"]
	var QUE := ["UNIT_SNA_QUEEN_NAME", "sna_queen"]
	var out := {}
	for d in [
		_dialog("gar_intro", [NAR, MOM, NAR, CHR, QUE, CHR]),
		_dialog("gar_l1_post", [CHR, QUE, CHR]),
		_dialog("gar_l2_post", [NAR, QUE, CHR]),
		_dialog("gar_l3_pre", [NAR, QUE, CHR]),
		_dialog("gar_finale", [QUE, CHR, NAR, MOM, CHR]),
	]:
		out[d.id] = _save(d, "res://data/dialogs/%s.tres" % d.id)
	return out


# groups: [[unit, count, interval, delay, path], ...]
func _wave(groups: Array, next_delay := 18.0, announce := "") -> WaveData:
	var w := WaveData.new()
	for g in groups:
		var s := SpawnGroup.new()
		s.unit = g[0]
		s.count = maxi(1, roundi(g[1] * count_mult))
		s.interval = snappedf(g[2] * interval_mult, 0.05)
		s.delay = g[3] if g.size() > 3 else 0.0
		s.path_index = g[4] if g.size() > 4 else 0
		w.groups.append(s)
	w.next_delay = next_delay
	w.announce_key = announce
	return w


func _gen_wavesets(un: Dictionary, ly: Dictionary, dl: Dictionary) -> Dictionary:
	var slug: UnitData = un["sna_slug"]
	var snail: UnitData = un["sna_garden_snail"]
	var spit: UnitData = un["sna_spitter"]
	var arm: UnitData = un["sna_armored"]
	var queen: UnitData = un["sna_queen"]
	var out := {}

	var w1 := WaveSet.new()
	w1.id = "gar_l1"
	w1.layout = ly["layout_gar_l1"]
	w1.pre_dialog = dl["gar_intro"]
	w1.post_dialog = dl["gar_l1_post"]
	w1.start_resource = 20
	_density(2.6, 0.55)
	w1.waves = [
		_wave([[slug, 4, 2.0]]),
		_wave([[slug, 6, 1.6]]),
		_wave([[slug, 4, 1.8], [snail, 2, 3.0, 4.0]]),
		_wave([[slug, 6, 1.4], [spit, 2, 2.5, 3.0]], 18.0, "WAVE_SPITTERS"),
		_wave([[slug, 8, 1.2], [snail, 2, 3.0, 2.0], [spit, 2, 2.5, 4.0]], 0.0, "WAVE_FINAL"),
	] as Array[WaveData]

	var w2 := WaveSet.new()
	w2.id = "gar_l2"
	w2.layout = ly["layout_gar_l2"]
	w2.post_dialog = dl["gar_l2_post"]
	w2.start_resource = 24
	_density(2.6, 0.55)
	w2.waves = [
		_wave([[slug, 4, 2.0, 0.0, 0], [slug, 4, 2.0, 1.0, 1]]),
		_wave([[slug, 5, 1.6, 0.0, 0], [spit, 2, 3.0, 2.0, 1]]),
		_wave([[snail, 3, 2.5, 0.0, 1], [slug, 5, 1.5, 0.0, 0]]),
		_wave([[spit, 3, 2.0, 0.0, 0], [slug, 5, 1.5, 0.0, 1]], 18.0, "WAVE_SPITTERS"),
		_wave([[arm, 1, 1.0, 0.0, 0], [slug, 4, 1.5, 2.0, 1]], 20.0, "WAVE_SIEGE"),
		_wave([[slug, 5, 1.4, 0.0, 0], [snail, 2, 2.5, 3.0, 1], [spit, 2, 2.5, 1.0, 0]], 0.0, "WAVE_FINAL"),
	] as Array[WaveData]

	var w3 := WaveSet.new()
	w3.id = "gar_l3"
	w3.layout = ly["layout_gar_l3"]
	w3.pre_dialog = dl["gar_l3_pre"]
	w3.post_dialog = dl["gar_finale"]
	w3.is_boss = true
	w3.music_key = "boss"
	w3.start_resource = 28
	_density(1.6, 0.75)
	w3.waves = [
		_wave([[slug, 6, 1.5]]),
		_wave([[slug, 5, 1.4], [spit, 3, 2.5, 2.0]]),
		_wave([[snail, 3, 2.2], [slug, 4, 1.5, 3.0]]),
		_wave([[arm, 2, 6.0], [slug, 6, 1.3, 1.0]], 20.0, "WAVE_SIEGE"),
		_wave([[snail, 4, 2.0], [spit, 3, 2.2, 2.0]]),
		_wave([[slug, 10, 0.8], [snail, 2, 2.5, 4.0]], 18.0, "WAVE_BROOD"),
		_wave([[queen, 1, 1.0, 2.0], [slug, 5, 1.8], [spit, 2, 3.0, 3.0]], 0.0, "WAVE_BOSS"),
	] as Array[WaveData]

	for w in [w1, w2, w3]:
		w.name_key = "MAP_%s_NAME" % w.id.to_upper()
		w.faction_id = "garden"
		w.enemy_faction_id = "snails"
		w.lives = 10
		w.prep_time = 25.0
		w.resource_regen = 0.6
		w.kill_bonus_mult = 0.5
		out[w.id] = _save(w, "res://data/waves/%s.tres" % w.id)
	return out


func _gen_factions(ws: Dictionary, bu: Dictionary) -> void:
	var g := FactionData.new()
	g.id = "garden"
	g.name_key = "FACTION_GARDEN_NAME"
	g.color = Color(0.85, 0.35, 0.50)
	var act := ActData.new()
	act.id = "gar_act1"
	act.name_key = "ACT_GAR_ACT1_NAME"
	act.act_number = 1
	for id in ["gar_l1", "gar_l2", "gar_l3"]:
		act.maps.append(ws[id])
	g.acts.append(act)
	g.towers.append(bu["gar_rosehip"])
	g.barracks.append(bu["gar_rose_bush"])
	_save(g, "res://data/factions/garden.tres")

	var s := FactionData.new()
	s.id = "snails"
	s.name_key = "FACTION_SNAILS_NAME"
	s.playable = false
	s.color = Color(0.55, 0.65, 0.30)
	_save(s, "res://data/factions/snails.tres")


func _v(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)


func _density(counts: float, intervals: float) -> void:
	count_mult = counts
	interval_mult = intervals
