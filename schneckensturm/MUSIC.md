# Musik & SFX

Aktuell Platzhalter aus Eldmyrdur (`audio/music/`, `audio/sfx/`). Zuordnung in
`scripts/autoload/audio_manager.gd` (`MUSIC`); SFX werden per Kurzname aus `audio/sfx/<name>.ogg` geladen,
fehlende Dateien werden still ignoriert.

| Key | Verwendung | Datei (Platzhalter) |
|---|---|---|
| `main_theme` | Menü, Levelauswahl, Abspann | `music_maintheme.mp3` |
| `battle` | Level 1 und 2 (`WaveSet.music_key`) | `music_battle01.mp3` |
| `boss` | Level 3 (Schneckenkönigin) | `music_boss01.mp3` |

Optional (🧑, Lizenz beachten): verspieltes Menü-/Abspann-Thema, nächtlich-spannender Kampftrack,
dramatischer Boss-Track. SFX-Namen im Code: `ui_click`, `ui_confirm`, `scene_transition`, `attack`,
`hit`, `heal`, `summon`, `enemy_death`, `victory`, `defeat`, `level_up`, `dialog_advance`.
