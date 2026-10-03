# The playable map: MatchSim (rules) + MatchWorld (visuals) + HUD. Input comes
# from InputRouter: tap = select/deploy, long-press = retreat hero.
extends Node2D

const STEP := 1.0 / 30.0
const QUICKTEST_CFG := "user://quicktest.cfg"

var ws: WaveSet
var sim: MatchSim
var world: MatchWorld
var speed := 1.0
var paused := false
var ended := false
var quicktest := false

## Card chosen in the deploy bar: { "kind": "hero"|"building", "id": String, "data": Resource }
var _card: Dictionary = {}
## Selected hero (SimUnit) or building (SimBuilding).
var _selected: Object = null

var _res_label: Label
var _lives_label: Label
var _wave_label: Label
var _next_btn: Button
var _speed_btn: Button
var _pause_btn: Button
var _toast: Label
var _toast_tween: Tween
var _cards: Dictionary = {}   # id -> { "button", "hp", "info" }
var _sel_panel: PanelContainer
var _sel_title: Label
var _sel_info: Label
var _sel_buttons: VBoxContainer
var _pause_menu: Control
var _end_overlay: Control
var _hud_blockers: Array[Control] = []
var _boss: SimUnit = null
var _boss_box: Control
var _boss_bar: ProgressBar
var _boss_name: Label


func _ready() -> void:
	ws = GameState.pending_waveset
	if ws == null:
		ws = _quicktest_waveset()
	if ws == null:
		SceneRouter.goto("main_menu")
		return
	sim = MatchSim.new()
	sim.setup(ws, _hero_entries(), ContentDB.target_rules, ContentDB.balance)
	sim.auto_tower_abilities = Settings.auto_tower_abilities
	world = MatchWorld.new()
	add_child(world)
	world.start(sim)
	sim.ended.connect(_on_ended)
	sim.wave_started.connect(_on_wave_started)
	sim.lives_changed.connect(func(_l): _flash_lives())
	sim.boss_spawned.connect(_on_boss_spawned)
	sim.hero_healed.connect(func(_id, _amount): AudioManager.play_sfx("heal"))
	_build_hud()
	InputRouter.tapped.connect(_on_tap)
	InputRouter.long_pressed.connect(_on_long_press)
	Settings.changed.connect(_on_settings_changed)
	AudioManager.play_music(ws.music_key)
	_toast_text(tr("UI_PREP_HINT"), 4.0)


func _exit_tree() -> void:
	if sim != null:
		sim.dispose()


# Every hero of the level's faction (Christina), always at full HP.
func _hero_entries() -> Array:
	var out := []
	for h in ContentDB.heroes_of(ws.faction_id):
		if out.size() < ws.hero_limit():
			out.append(h.match_entry())
	return out


# Editor "Schnelltest" / F6: no hand-over state -> play the chosen (or first) level without saving.
func _quicktest_waveset() -> WaveSet:
	var path := ""
	var cfg := ConfigFile.new()
	if cfg.load(QUICKTEST_CFG) == OK:
		path = str(cfg.get_value("quicktest", "waveset", ""))
	var qws: WaveSet = load(path) if path != "" and ResourceLoader.exists(path) else GameState.current_map()
	if qws == null:
		return null
	quicktest = true
	return qws


func _process(delta: float) -> void:
	if sim == null:
		return
	if not paused and not ended:
		var remaining := delta * speed
		while remaining > 0.0001:
			var dt := minf(STEP, remaining)
			sim.step(dt)
			remaining -= dt
	_update_hud()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _on_tap(p: Vector2) -> void:
	if ended or paused or _over_hud(p):
		return
	var cell := world.cell_at_screen(p)
	if not _card.is_empty():
		_try_place(cell)
		return
	var hero := sim.hero_at(cell)
	if hero != null:
		_select(hero)
		return
	var b := sim.building_at(cell)
	if b != null:
		_select(b)
		return
	_select(null)


func _on_long_press(p: Vector2) -> void:
	if ended or paused or _over_hud(p):
		return
	var hero := sim.hero_at(world.cell_at_screen(p))
	if hero != null:
		_retreat(hero)


func _try_place(cell: Vector2i) -> void:
	var err: int
	if _card["kind"] == "hero":
		err = sim.can_deploy_hero(_card["id"], cell)
		if err == MatchSim.DeployError.OK:
			_select(sim.deploy_hero(_card["id"], cell))
	else:
		err = sim.can_build(_card["data"], cell)
		if err == MatchSim.DeployError.OK:
			_select(sim.build(_card["data"], cell))
	if err == MatchSim.DeployError.OK:
		AudioManager.play_sfx("ui_confirm")
		_set_card({})
	elif err == MatchSim.DeployError.TILE_KIND:
		_set_card({})   # tapping elsewhere cancels placement
	else:
		_toast_text(tr(_error_key(err)))


func _error_key(err: int) -> String:
	match err:
		MatchSim.DeployError.COST: return "UI_ERR_COST"
		MatchSim.DeployError.OCCUPIED: return "UI_ERR_OCCUPIED"
		MatchSim.DeployError.LIMIT: return "UI_ERR_LIMIT"
		MatchSim.DeployError.COOLDOWN: return "UI_ERR_COOLDOWN"
		MatchSim.DeployError.FALLEN: return "UI_ERR_FALLEN"
		MatchSim.DeployError.ALREADY_DEPLOYED: return "UI_ERR_DEPLOYED"
		MatchSim.DeployError.NOT_ALLOWED: return "UI_ERR_NOT_ALLOWED"
		MatchSim.DeployError.MAX_LEVEL: return "UI_MAX_LEVEL"
		MatchSim.DeployError.FULL_HP: return "UI_HEAL_FULL"
	return "UI_ERR_TILE"


func _retreat(hero: SimUnit) -> void:
	var refund := sim.retreat(hero)
	_toast_text(tr("UI_RETREATED") % refund)
	if _selected == hero:
		_select(null)


func _heal(id: String) -> void:
	if not sim.heal_hero(id):
		_toast_text(tr(_error_key(sim.can_heal_hero(id))))
	_update_selection_panel()


func _upgrade(b: SimBuilding) -> void:
	if not sim.upgrade(b):
		_toast_text(tr(_error_key(sim.can_upgrade(b))))
	_update_selection_panel()


func _set_card(card: Dictionary) -> void:
	if not card.is_empty() and not _card.is_empty() and card["id"] == _card["id"]:
		card = {}   # tapping the same card again cancels
	_card = card
	if not card.is_empty():
		_select(null)
	for id in _cards:
		_cards[id]["button"].button_pressed = not card.is_empty() and id == card["id"]
	_refresh_highlight()


func _select(obj: Object) -> void:
	for o in [_selected, obj]:
		var v := world.visual_of(o) if o != null else null
		if v != null and is_instance_valid(v):
			v.set_selected(o == obj)
	_selected = obj
	_refresh_highlight()
	_rebuild_selection_panel()


func _refresh_highlight() -> void:
	var cells := {}
	if not _card.is_empty():
		if _card["kind"] == "hero":
			var h: HeroData = _card["data"]
			var list: Array[Vector2i] = ws.layout.deploy_path_cells if h.placement == Enums.Placement.PATH else ws.layout.deploy_edge_cells
			for c in list:
				if sim.hero_at(c) == null:
					cells[c] = Color(1.0, 0.85, 0.3, 0.35)
		else:
			for c in ws.layout.build_slots:
				if sim.building_at(c) == null:
					cells[c] = Color(1.0, 1.0, 1.0, 0.3)
	elif _selected is SimUnit and _selected.alive:
		for off in _selected.range_pattern:
			cells[_selected.cell + off] = Color(0.9, 0.3, 0.3, 0.22) if not _selected.heals else Color(0.3, 0.9, 0.4, 0.22)
	world.map.highlight(cells)


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	UITheme.fill(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Top bar
	var top := UITheme.panel(Color(0.05, 0.05, 0.08, 0.82))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 60
	root.add_child(top)
	_hud_blockers.append(top)
	var row := UITheme.hbox(18)
	top.add_child(row)
	_pause_btn = _small_button("II", _toggle_pause)
	row.add_child(_pause_btn)
	_res_label = UITheme.label("", 26, Color(0.55, 0.85, 1.0))
	row.add_child(_res_label)
	_lives_label = UITheme.label("", 26, Color(1.0, 0.45, 0.45))
	row.add_child(_lives_label)
	_wave_label = UITheme.label("", 24)
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_wave_label)
	_next_btn = UITheme.button("", 20, "ui_confirm")
	_next_btn.custom_minimum_size = Vector2(230, 48)
	_next_btn.pressed.connect(func(): sim.call_next_wave())
	row.add_child(_next_btn)
	_speed_btn = _small_button("1×", _toggle_speed)
	row.add_child(_speed_btn)

	# Deploy bar
	var bottom := UITheme.panel(Color(0.05, 0.05, 0.08, 0.82))
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -132
	root.add_child(bottom)
	_hud_blockers.append(bottom)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(scroll)
	var cards := UITheme.hbox(10)
	scroll.add_child(cards)
	for id in sim.heroes:
		var h: HeroData = sim.heroes[id]["data"]
		cards.add_child(_make_card(id, tr(h.name_key), h.token, h.deploy_cost, { "kind": "hero", "id": id, "data": h }, true))
	cards.add_child(VSeparator.new())
	var f := ContentDB.get_faction(ws.faction_id)
	if f != null:
		var buildings: Array = []
		buildings.append_array(f.towers)
		buildings.append_array(f.barracks)
		for b in buildings:
			if not sim.allowed_buildings.is_empty() and b.id not in sim.allowed_buildings:
				continue
			var tex: Texture2D = b.texture if b.texture != null else (b.unit.token if b is BarracksData and b.unit != null else _swatch(b.color))
			cards.add_child(_make_card(b.id, tr(b.name_key), tex, b.cost, { "kind": "building", "id": b.id, "data": b }, false))

	# Selection panel (right)
	_sel_panel = UITheme.panel(Color(0.08, 0.07, 0.11, 0.9), UITheme.ACCENT, 2)
	_sel_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_sel_panel.offset_left = -280
	_sel_panel.offset_right = -12
	_sel_panel.offset_top = -170
	_sel_panel.offset_bottom = 170
	_sel_panel.visible = false
	root.add_child(_sel_panel)
	_hud_blockers.append(_sel_panel)
	var sv := UITheme.vbox(8)
	_sel_panel.add_child(sv)
	_sel_title = UITheme.label("", 22, UITheme.ACCENT)
	sv.add_child(_sel_title)
	_sel_info = UITheme.label("", 18)
	sv.add_child(_sel_info)
	_sel_buttons = UITheme.vbox(8)
	sv.add_child(_sel_buttons)

	# Boss HP bar (snail queen), hidden until a boss appears
	_boss_box = UITheme.vbox(2)
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_top = 66
	_boss_box.offset_left = -260
	_boss_box.offset_right = 260
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = UITheme.label("", 20, Color(0.95, 0.75, 1.0))
	_boss_name.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_boss_name.add_theme_constant_override("outline_size", 6)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(520, 18)
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 1.0
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_theme_stylebox_override("fill", UITheme.stylebox(Color(0.70, 0.25, 0.85)))
	_boss_bar.add_theme_stylebox_override("background", UITheme.stylebox(Color(0.1, 0.05, 0.12, 0.85), Color(0, 0, 0), 2))
	_boss_box.add_child(_boss_bar)

	# Toast
	_toast = UITheme.label("", 24, Color(1, 0.95, 0.8), true)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 70
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	_pause_menu = _build_pause_menu()
	root.add_child(_pause_menu)
	_end_overlay = Control.new()
	UITheme.fill(_end_overlay)
	_end_overlay.visible = false
	root.add_child(_end_overlay)


func _small_button(text: String, cb: Callable) -> Button:
	var b := UITheme.button(text, 22)
	b.custom_minimum_size = Vector2(64, 48)
	b.pressed.connect(cb)
	return b


func _make_card(id: String, title: String, tex: Texture2D, cost: int, card: Dictionary, is_hero: bool) -> Control:
	var col := UITheme.vbox(2)
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(96, 92)
	b.icon = tex
	UITheme.style_toggle(b, 56)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = str(cost)
	b.add_theme_font_size_override("font_size", 20)
	b.tooltip_text = title
	b.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_set_card(card))
	col.add_child(b)
	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(96, 8)
	hp.show_percentage = false
	hp.max_value = 1.0
	hp.visible = is_hero
	col.add_child(hp)
	var info := UITheme.label("", 14, UITheme.MUTED)
	info.custom_minimum_size = Vector2(96, 0)
	info.clip_text = true
	col.add_child(info)
	_cards[id] = { "button": b, "hp": hp, "info": info, "card": card, "cost": cost }
	return col


func _update_hud() -> void:
	_res_label.text = "◆ %d" % sim.resource_int()
	_lives_label.text = tr("UI_PETALS") % [sim.lives, sim.max_lives]
	if _boss != null:
		_boss_bar.value = _boss.hp_ratio() if _boss.alive else 0.0
		_boss_box.visible = _boss.alive
	var total := sim.total_waves()
	if sim.phase == MatchSim.Phase.PREP:
		_wave_label.text = tr("UI_PREP") % int(ceil(sim.prep_left))
		_next_btn.text = tr("UI_START_WAVES")
		_next_btn.disabled = false
	else:
		_wave_label.text = tr("UI_WAVE") % [mini(sim.wave_index + 1, total), total]
		var more := sim.wave_index + 1 < total
		_next_btn.disabled = not more or ended
		_next_btn.text = (tr("UI_NEXT_WAVE") % int(ceil(maxf(0.0, sim.next_wave_timer)))) if more else tr("UI_LAST_WAVE")
	for id in _cards:
		var c: Dictionary = _cards[id]
		var b: Button = c["button"]
		if c["card"]["kind"] == "hero":
			var slot: Dictionary = sim.heroes[id]
			var hp_now: float = slot["unit"].hp if slot["unit"] != null else float(slot["hp"])
			c["hp"].value = hp_now / maxf(1.0, float(slot["max_hp"]))
			var status := ""
			if slot["hp"] <= 0 and slot["unit"] == null:
				status = tr("UI_FALLEN")
			elif slot["unit"] != null:
				status = tr("UI_DEPLOYED")
			elif slot["cooldown_left"] > 0.0:
				status = "%ds" % int(ceil(slot["cooldown_left"]))
			c["info"].text = status
			b.disabled = status != "" or ended
			b.modulate = Color(1, 1, 1) if sim.resource_int() >= c["cost"] else Color(0.6, 0.6, 0.6)
		else:
			b.disabled = ended
			b.modulate = Color(1, 1, 1) if sim.resource_int() >= c["cost"] else Color(0.6, 0.6, 0.6)
	if _selected != null:
		if (_selected is SimUnit or _selected is SimBuilding) and not _selected.alive:
			_select(null)
		else:
			_update_selection_panel()


func _rebuild_selection_panel() -> void:
	for ch in _sel_buttons.get_children():
		ch.queue_free()
	_sel_panel.visible = _selected != null
	if _selected == null:
		return
	if _selected is SimUnit:
		var u: SimUnit = _selected
		_sel_title.text = tr(u.data.name_key)
		var abilities: Array = sim.heroes[u.hero_id]["abilities"]
		for i in abilities.size():
			var ab: AbilityData = abilities[i]
			var b := UITheme.button(tr(ab.name_key), 20)
			b.tooltip_text = tr(ab.desc_key)
			var idx := i
			b.pressed.connect(func(): sim.trigger_hero_ability(u.hero_id, idx))
			b.set_meta("ability", idx)
			_sel_buttons.add_child(b)
		var heal := UITheme.button("", 20)
		heal.pressed.connect(func(): _heal(u.hero_id))
		heal.set_meta("heal", true)
		_sel_buttons.add_child(heal)
		var r := UITheme.button(tr("UI_RETREAT") % int(floor(sim.hero_cost(u.hero_id) * ws.retreat_refund_ratio)), 20)
		r.pressed.connect(func(): _retreat(u))
		_sel_buttons.add_child(r)
	else:
		var bl: SimBuilding = _selected
		_sel_title.text = tr(bl.data.name_key)
		if bl.is_tower and bl.data.ability != null:
			var b := UITheme.button(tr(bl.data.ability.name_key), 20)
			b.tooltip_text = tr(bl.data.ability.desc_key)
			b.pressed.connect(func(): sim.trigger_tower_ability(bl))
			b.set_meta("tower", true)
			_sel_buttons.add_child(b)
		var up := UITheme.button("", 20)
		up.pressed.connect(func(): _upgrade(bl))
		up.set_meta("upgrade", true)
		_sel_buttons.add_child(up)
	_update_selection_panel()


func _update_selection_panel() -> void:
	if _selected is SimUnit:
		var u: SimUnit = _selected
		_sel_info.text = "%s %d / %d\n%s %d   %s %d" % [tr("UI_STAT_HP"), int(ceil(u.hp)), int(u.max_hp),
			tr("UI_STAT_ATK"), int(u.effective_attack()), tr("UI_STAT_BLOCK"), u.block_capacity]
		var slot: Dictionary = sim.heroes[u.hero_id]
		for b in _sel_buttons.get_children():
			if b.has_meta("ability"):
				var cd: float = slot["ability_cd"][b.get_meta("ability")]
				b.disabled = cd > 0.0
				b.text = tr(slot["abilities"][b.get_meta("ability")].name_key) + ("" if cd <= 0.0 else "  (%ds)" % int(ceil(cd)))
			elif b.has_meta("heal"):
				var err := sim.can_heal_hero(u.hero_id)
				b.disabled = err != MatchSim.DeployError.OK
				b.text = tr("UI_HEAL_FULL") if err == MatchSim.DeployError.FULL_HP else tr("UI_HEAL") % sim.heal_cost(u.hero_id)
	elif _selected is SimBuilding:
		var bl: SimBuilding = _selected
		var extra := ""
		if not bl.is_tower:
			extra = "   %s %d / %d" % [tr("UI_SQUAD"), bl.squad.size(), (bl.data as BarracksData).squad_size]
		else:
			extra = "   %s %d" % [tr("UI_STAT_ATK"), int(bl.attack())]
		_sel_info.text = "%s %d / %d\n%s %d / %d%s" % [tr("UI_STAT_HP"), int(ceil(bl.hp)), int(bl.max_hp),
			tr("UI_LEVEL"), bl.level, bl.max_level(), extra]
		for b in _sel_buttons.get_children():
			if b.has_meta("tower"):
				b.disabled = not bl.ability_ready()
			elif b.has_meta("upgrade"):
				var err := sim.can_upgrade(bl)
				b.disabled = err != MatchSim.DeployError.OK
				b.text = tr("UI_MAX_LEVEL") if err == MatchSim.DeployError.MAX_LEVEL else tr("UI_UPGRADE") % sim.upgrade_cost(bl)


func _toast_text(text: String, secs := 1.8) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(secs)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _flash_lives() -> void:
	AudioManager.play_sfx("hit")
	FX.punch(_lives_label, 1.35)


func _on_wave_started(i: int) -> void:
	var wave: WaveData = ws.waves[i]
	var text := tr("UI_WAVE_INCOMING") % (i + 1)
	if wave.announce_key != "":
		text += "\n" + tr(wave.announce_key)
	_toast_text(text, 2.5)


func _on_boss_spawned(u: SimUnit) -> void:
	_boss = u
	_boss_name.text = tr(u.data.name_key)
	_boss_box.visible = true
	FX.punch(_boss_name, 1.3)


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	_speed_btn.text = "%d×" % int(speed)


func _toggle_pause() -> void:
	if ended:
		return
	paused = not paused
	_pause_menu.visible = paused


func _on_settings_changed() -> void:
	sim.auto_tower_abilities = Settings.auto_tower_abilities


func _build_pause_menu() -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	UITheme.fill(shade)
	shade.visible = false
	var box := UITheme.vbox(14)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(380, 0)
	box.offset_left = -190
	box.offset_right = 190
	box.offset_top = -150
	shade.add_child(box)
	box.add_child(UITheme.title(tr("UI_PAUSED")))
	var resume := UITheme.button(tr("UI_RESUME"))
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var auto := CheckButton.new()
	auto.text = tr("UI_AUTO_TOWER_ABILITIES")
	auto.button_pressed = Settings.auto_tower_abilities
	auto.toggled.connect(func(v): Settings.set_auto_tower_abilities(v))
	box.add_child(auto)
	var give_up := UITheme.button(tr("UI_GIVE_UP"))
	give_up.pressed.connect(func():
		paused = false
		shade.visible = false
		sim._end(false))
	box.add_child(give_up)
	return shade


# ---------------------------------------------------------------------------
# End of match
# ---------------------------------------------------------------------------
func _on_ended(victory: bool) -> void:
	ended = true
	_set_card({})
	_select(null)
	AudioManager.play_sfx("victory" if victory else "defeat")
	var first_clear := false
	if victory and not quicktest:
		first_clear = GameState.mark_cleared(ws)
		SaveManager.save_game()
	_show_end(victory, first_clear)


func _show_end(victory: bool, first_clear: bool) -> void:
	for ch in _end_overlay.get_children():
		ch.queue_free()
	var shade := UITheme.background(Color(0, 0, 0, 0.6))
	_end_overlay.add_child(shade)
	var panel := UITheme.panel(UITheme.PANEL, UITheme.ACCENT, 2)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -170
	_end_overlay.add_child(panel)
	var vb := UITheme.vbox(12)
	var m := UITheme.margin(20)
	m.add_child(vb)
	panel.add_child(m)
	vb.add_child(UITheme.title(tr("UI_VICTORY") if victory else tr("UI_DEFEAT")))
	if quicktest:
		vb.add_child(UITheme.label(tr("UI_QUICKTEST_DONE"), 20, UITheme.MUTED))
	elif victory:
		vb.add_child(UITheme.label(tr("UI_PETALS_LEFT") % [sim.lives, sim.max_lives], 22, UITheme.GOOD))
		if first_clear:
			vb.add_child(UITheme.label(tr("UI_FIRST_CLEAR"), 20, UITheme.MUTED))
	else:
		var hint := "UI_DEFEAT_HERO" if sim.defeat_reason == "hero_fell" else "UI_DEFEAT_HINT"
		vb.add_child(UITheme.label(tr(hint), 20, UITheme.MUTED, true))
	var row := UITheme.hbox(12)
	vb.add_child(row)
	if victory and not quicktest:
		row.add_child(_end_button(tr("UI_CONTINUE_STORY"), "ui_confirm", func(): SceneRouter.continue_story(ws)))
		row.add_child(_end_button(tr("UI_RETRY"), "ui_click", _retry))
	else:
		row.add_child(_end_button(tr("UI_RETRY"), "ui_confirm", _retry))
		row.add_child(_end_button(tr("UI_TO_MENU") if quicktest else tr("UI_LEVEL_SELECT"), "ui_click",
			func(): SceneRouter.goto("main_menu" if quicktest else "level_select")))
	_end_overlay.visible = true
	_end_overlay.modulate.a = 0.0
	_end_overlay.create_tween().tween_property(_end_overlay, "modulate:a", 1.0, 0.3)


func _end_button(text: String, sound: String, cb: Callable) -> Button:
	var b := UITheme.button(text, 22, sound)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _retry() -> void:
	GameState.pending_waveset = null if quicktest else ws
	SceneRouter.goto("match")


# Touch events that land on HUD panels must not also act on the map below.
func _over_hud(p: Vector2) -> bool:
	for c in _hud_blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


# Plain colour icon for buildings without art yet.
func _swatch(c: Color) -> Texture2D:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)
