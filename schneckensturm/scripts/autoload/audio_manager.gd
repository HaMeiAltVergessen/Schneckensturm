# Autoload: zentrale SFX-Wiedergabe über einen Pool von AudioStreamPlayern plus
# ein Musik-Player. Sounds werden per Kurzname angesprochen; fehlende Dateien
# werden still ignoriert, damit Platzhalter jederzeit austauschbar sind (MUSIC.md).
extends Node

const _POOL_SIZE := 8
const _SFX_DIR := "res://audio/sfx/%s.ogg"

# Logische Musik-Keys -> Pfad. Mehrere Keys dürfen auf denselben Track zeigen.
const MUSIC := {
	"main_theme": "res://audio/music/music_maintheme.mp3",
	"battle": "res://audio/music/music_battle01.mp3",
	"boss": "res://audio/music/music_boss01.mp3",
}

const _MUSIC_FADE := 0.5

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _sfx_cache := {}

var _music: AudioStreamPlayer
var _current_music := ""
var _music_tween: Tween


func _ready() -> void:
	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)


func _sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	var path := _SFX_DIR % sfx_name
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_sfx_cache[sfx_name] = stream
	return stream


# Spielt einen Sound per Kurzname. Unbekannte Namen werden ignoriert (kein Crash).
# pitch_var > 0 variiert die Tonhöhe zufällig (±pitch_var).
func play_sfx(sfx_name: String, pitch_var := 0.0) -> void:
	var stream := _sfx(sfx_name)
	if stream == null or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var) if pitch_var > 0.0 else 1.0
	p.play()


# Startet den Loop-Track für einen logischen Key. "" oder bereits laufender Key
# sind ein No-Op; unbekannte Keys werden ignoriert.
func play_music(key: String) -> void:
	if key == "" or key == _current_music or not MUSIC.has(key):
		return
	var path: String = MUSIC[key]
	if not ResourceLoader.exists(path) or _music == null:
		return
	var stream: AudioStream = load(path)
	if "loop" in stream:
		stream.loop = true
	_current_music = key
	if _music_tween != null:
		_music_tween.kill()
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", 0.0, _MUSIC_FADE)


func stop_music(fade := true) -> void:
	_current_music = ""
	if _music == null or not _music.playing:
		return
	if _music_tween != null:
		_music_tween.kill()
	if not fade:
		_music.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -40.0, _MUSIC_FADE)
	_music_tween.tween_callback(_music.stop)
