# Schneckensturm — Projektkonventionen

Isometrisches Tower-Defense (Arknights-Blocking) in **Godot 4.4**, GL Compatibility, 1280×720 Landscape,
PC + Android. Geburtstagsgeschenk: 3 Level, lineare Mini-Story, nur Deutsch. Planung: `ROADMAP.md`.
Klon von „Talathons Fall“ (Meta-Schicht – Basis, Ausrüstung, Loot, Idle, Anwerben – wurde entfernt).

## Ordner
| Pfad | Inhalt |
|---|---|
| `scripts/autoload/` | `ContentDB`, `GameState` (Story-Fortschritt), `SaveManager`, `SceneRouter` (Story-Fluss), `Settings`, `AudioManager` |
| `scripts/input/` | `InputRouter` (Autoload): Tap / Long-Press / Pan / Pinch aus Touch **und** Maus |
| `scripts/resources/` | Resource-Klassen (`HeroData`, `UnitData`, `TowerData`, `BarracksData`, `MapLayout`, `WaveSet`, `BalanceConfig`, …) |
| `scripts/match/` | `MatchSim` (headless Kampfregeln), `Targeting`, `SimUnit`, `SimBuilding`, `IsoGrid`, Darstellung (`MatchWorld`, `UnitVisual`, `DahliaVisual`, …) |
| `scripts/ui/` | `UITheme`, `FX`, `DialogBox` |
| `scenes/<name>/` | je Szene `<name>.tscn` + `<name>.gd`; UI wird im Code gebaut (`UITheme`) |
| `data/<typ>/` | **Content als `.tres`** — wird von `ContentDB` per Ordner-Scan geladen, nie im Code gebaut |
| `data/rules/` | `target_rules.tres` (Zielregel-Matrix), `balance.tres` (globale Balancing-Regler) |
| `assets/` | Grafik (`garden/` Figuren/Gebäude/Dahlie, `ui/` Hintergründe + Icons, `tiles/`, `app/` App-Icons, `units/` Platzhalter, `shaders/`) |
| `art_raw/` | Flux-Rohbilder nach Kategorie (`.gdignore`, nicht importiert) → `tools/art.sh` |
| `addons/talathon_editor/` | Map- und Wellen-Editor |
| `addons/chroma_key/` | Projektunabhängiges Freistell-Plugin (`ChromaKey`, Editor-Dialog, Headless-CLI) |
| `tools/` | `gen_schneckensturm_content.gd` (Content-Generator), `art.sh` → `process_art.gd` (Rohbilder freistellen/skalieren, `IsoTiles`) + `link_art.gd` (verdrahten) |
| `tests/` | Headless-Test-Szenen (`*_test.tscn`) + `run_tests.sh`; `tests/tmp/` = Screenshot-Helfer, kein Test |

## Namen
- Dateien/Ordner `snake_case`, Klassen `PascalCase` (`class_name`), Konstanten `UPPER_CASE`.
- Content-IDs: `<fraktion>_<name>` mit `gar_` (Garten/Spieler) und `sna_` (Schnecken); Level `gar_l<n>`; Layouts `layout_gar_l<n>`.
- Loc-Keys: `HERO_<ID>_NAME`, `UNIT_<ID>_NAME`, `ABILITY_<ID>_NAME/_DESC`, `MAP_<ID>_NAME`, `DIALOG_<ID>_<n>`, `UI_*`.
  Platzhaltertexte beginnen mit `[PH]`. Neue Texte in `localization/text.csv` (Spalten `keys,de,en`; `en` = Kopie von `de`).

## Architekturregeln
- **Kampfregeln nur in `MatchSim`/`Targeting`** (RefCounted, ohne Szene). Die Match-Szene beobachtet Signale und liest den Zustand — dadurch ist jede Regel headless testbar.
- Sonderfälle gehören in Daten, nicht in Code: Zielregeln (`TargetRuleSet`), Platzierung (`HeroData.placement`), Niederlage beim Fall (`HeroData.essential`), Boss-Brut (`UnitData.brood_*`), Ökonomie (`WaveSet`-Felder, `BalanceConfig`).
- Ein Level = `MapLayout` (Geometrie) + `WaveSet` (Wellen, Ökonomie, `pre_dialog`/`post_dialog`). Reihenfolge = `data/factions/garden.tres`.
- Story-Fluss nur über `SceneRouter.goto_match` / `continue_story` / `play_dialog`.
- Einheiten-Darstellung über `UnitVisual`: Standbild + Tweens, automatisch `SpriteFrames`, sobald hinterlegt.
- Eingaben nur über `InputRouter`-Signale, keine verstreuten `Input.*`-Abfragen.
- Save ist versioniertes JSON (`SaveManager.VERSION`); jede Formatänderung bekommt einen Schritt in `_migrate()`.
- `MatchSim.dispose()` beim Verlassen des Matches aufrufen (bricht Referenzzyklen).

## Tests
```
bash tests/run_tests.sh              # alle Suiten, Godot-Pfad per GODOT=... überschreibbar
"E:/Godot/Godot_v4.4-stable_win64_console.exe" --headless --path . res://tests/match_test.tscn
```
Suiten: `match_test` (Kampfregeln inkl. Leinen los, Heilen, Brut, Balance), `save_test` (Fortschritt), `chroma_key_test` (Freistellen, Iso-Kacheln),
`content_loc_test`, `content_sim_test` (Bot muss **jedes** Level gewinnen), `validator_test`, `editor_test`,
`scene_harness` (jede Szene instanziiert), `loc_test.gd` (Script-Modus).
Jede neue Mechanik bekommt einen Headless-Test. Tests schreiben nie in den echten Spielstand.

Bilder: Rohbild nach `art_raw/<kategorie>/` (Namen und Prompts in `ASSETS.md`), dann `bash tools/art.sh`
(freistellen → importieren → verdrahten; Bild-Felder: `token`, `portrait`, `texture`, `AbilityData.icon`,
`DialogLine.background`, `MapLayout.tileset`). Fehlende Bilder = Platzhalter, nie ein Fehler. Content neu erzeugen:
`--headless --script res://tools/gen_schneckensturm_content.gd` (überschreibt nichts Bestehendes; `-- --force` erzwingt).

## Performance-Budget
Noch nicht gemessen (`scenes/perf_test`, im Router registriert, nicht im Menü). Zielwert ≤ 120 gleichzeitige
Einheiten bei 60 FPS auf PC; das Handy-Ergebnis hier eintragen.
