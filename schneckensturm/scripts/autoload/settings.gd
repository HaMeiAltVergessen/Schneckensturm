# Autoload: user preferences (UI scale, audio, gameplay options), persisted to
# user://settings.cfg independently of the savegame.
extends Node

signal changed

const CONFIG_PATH := "user://settings.cfg"
const SCALE_PRESETS := [0.8, 1.0, 1.25, 1.5]   # UI/content zoom factors
const DEFAULT_SCALE := 1.0
const AUDIO_BUSES := ["Master", "Music", "SFX"]
const LOCALES := ["de"]

var window_scale: float = DEFAULT_SCALE
# Linear volumes 0..1, one per bus in AUDIO_BUSES.
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
## Tower abilities fire automatically when charged (default: manual).
var auto_tower_abilities: bool = false
## Initial match camera zoom (1 = native).
var camera_zoom: float = 1.0
var locale: String = "de"


func _ready() -> void:
	_load()
	_apply()
	_apply_audio()


func set_scale(s: float) -> void:
	window_scale = s
	_commit()
	_apply()


func set_auto_tower_abilities(v: bool) -> void:
	auto_tower_abilities = v
	_commit()


func set_camera_zoom(v: float) -> void:
	camera_zoom = clampf(v, 0.5, 2.0)
	_commit()


func set_locale(l: String) -> void:
	if l not in LOCALES:
		return
	locale = l
	TranslationServer.set_locale(l)
	_commit()


func get_volume(bus_name: String) -> float:
	match bus_name:
		"Master": return master_volume
		"Music": return music_volume
		"SFX": return sfx_volume
	return 1.0


func set_volume(bus_name: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus_name:
		"Master": master_volume = value
		"Music": music_volume = value
		"SFX": sfx_volume = value
	_commit()
	_apply_audio()


func _commit() -> void:
	_save()
	changed.emit()


func _apply_audio() -> void:
	for bus_name in AUDIO_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var value := get_volume(bus_name)
		var db := -80.0 if value <= 0.0 else linear_to_db(value)
		AudioServer.set_bus_volume_db(idx, db)


func _apply() -> void:
	# UI/content zoom without window ops (works on desktop, mobile and embedded).
	var win := get_window()
	if win != null:
		win.content_scale_factor = window_scale
	TranslationServer.set_locale(locale)


# Snaps an arbitrary (e.g. legacy-saved) value to the nearest valid preset.
func _nearest_preset(value: float) -> float:
	var best: float = DEFAULT_SCALE
	var best_dist := INF
	for preset in SCALE_PRESETS:
		var d: float = absf(preset - value)
		if d < best_dist:
			best_dist = d
			best = preset
	return best


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	window_scale = _nearest_preset(float(cfg.get_value("display", "window_scale", DEFAULT_SCALE)))
	camera_zoom = float(cfg.get_value("display", "camera_zoom", camera_zoom))
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	auto_tower_abilities = bool(cfg.get_value("gameplay", "auto_tower_abilities", auto_tower_abilities))
	var l := str(cfg.get_value("general", "locale", locale))
	locale = l if l in LOCALES else "de"


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window_scale", window_scale)
	cfg.set_value("display", "camera_zoom", camera_zoom)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("gameplay", "auto_tower_abilities", auto_tower_abilities)
	cfg.set_value("general", "locale", locale)
	cfg.save(CONFIG_PATH)
