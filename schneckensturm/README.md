# Schneckensturm

Ein kleines isometrisches Tower-Defense als Geburtstagsgeschenk: Christina, auf Spielzeuggröße
geschrumpft, verteidigt ihre Dahlie gegen die Schneckenarmee der Schneckenkönigin – drei Level,
eine Mini-Geschichte, ein Abspann mit Gruß. Godot **4.4**, GL Compatibility, Landscape, PC + Android.
Klon von „Talathons Fall“, auf das Wesentliche reduziert.

Konventionen: [`CLAUDE.md`](CLAUDE.md) · Plan: [`ROADMAP.md`](ROADMAP.md) · Story: [`STORY.md`](STORY.md) ·
Bilder: [`ASSETS.md`](ASSETS.md) · Balancing: [`docs/BALANCING.md`](docs/BALANCING.md) · Editor: [`docs/EDITOR.md`](docs/EDITOR.md)

## Starten
Projekt in Godot 4.4 öffnen (`project.godot`) und F5 drücken. Einzelnes Level direkt testen:
`scenes/match/match.tscn` mit F6 (spielt das erste offene Level, speichert nichts) oder im
Talathon-Editor „Schnelltest ▶".

**Steuerung:** Tippen/Linksklick = auswählen und setzen · lange drücken/Rechtsklick = Christina zurückziehen ·
Ziehen = Kamera bewegen · Pinch/Mausrad = Zoom. Christina antippen → „Leinen los!“, Heilen, Rückzug.

## Bilder
Flux-Rohbilder nach `art_raw/<kategorie>/` legen (Liste + Prompts: [`ASSETS.md`](ASSETS.md)), dann
`bash tools/art.sh` – stellt frei, skaliert, baut Kacheln/Icons und verdrahtet alles.
Das Freistell-Plugin `addons/chroma_key/` ist projektunabhängig (eigene `README.md`).

## Builds
Voraussetzung: Export-Templates 4.4 (Editor → *Export-Vorlagen verwalten*), für Android zusätzlich
Android-SDK + JDK 17 in den Editor-Einstellungen (*Export → Android*).

```
GODOT="E:/Godot/Godot_v4.4-stable_win64_console.exe"

# Windows (eine .exe, PCK eingebettet)
"$GODOT" --headless --path . --export-release "Windows Desktop" builds/windows/Schneckensturm.exe

# Android (Debug-signiert – reicht zum Installieren auf dem eigenen Handy)
"$GODOT" --headless --path . --export-debug "Android" builds/android/Schneckensturm.apk
adb install -r builds/android/Schneckensturm.apk
```
Paketname: `com.schneckensturm.game`. Selbsttest eines Builds:
`Schneckensturm.exe --headless --quit-after 120 -- --content-report` gibt die Anzahl geladener Inhalte aus.

## Tests
```
bash tests/run_tests.sh
```
Alle Suiten laufen headless (Kampfregeln, Save/Fortschritt, Lokalisierung, Editor, jede Szene,
Bot-Probelauf jedes Levels). Details in `CLAUDE.md`.

## Ordner
`scripts/` Code · `scenes/` Szenen · `data/` Content als `.tres` · `assets/` Grafik · `audio/` Musik/SFX ·
`localization/` Texte · `addons/talathon_editor/` Karten-/Wellen-Editor · `tests/` · `tools/`.
