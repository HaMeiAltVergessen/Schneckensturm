# Schneckensturm — Roadmap

Geburtstagsgeschenk für Christina, Deadline **< 2 Wochen** (Plan vom 2026-10-03). Spielbarkeit zuerst,
Politur zuletzt. **Owner:** 🤖 Claude (Code/Tests/Docs) · 🧑 Sebastian (Bilder, Texte, Playtest) · 🤝 gemeinsam.

## Entscheidungen
| Thema | Entscheidung |
|---|---|
| Umfang | 3 Level, linear: Menü → Intro → L1 → Dialog → L2 → Dialog → L3 → Finale → Abspann mit Gruß |
| Meta-Schicht | entfernt (Basis, Ausrüstung, Loot, Idle, Anwerben, Seitenwahl, Loadout) |
| Dahlie | am Pfadende, Leben = 10 Blüten, sichtbar angefressen |
| Rosen | Rosenbusch = Kaserne, 2 Rosenkriegerinnen, 3 Stufen |
| Hagebutte | 1 Turmtyp, 3 Stufen (weitere Pflanzen später möglich) |
| Christina | einzige Heldin, Fernkampf; „Leinen los“ trifft alle Schnecken; Fall = Niederlage; im Match heilbar |
| Schnecken | Nacktschnecke, Weinbergschnecke, Schleimspucker, Panzerschnecke + Königin (Boss-Leiste, Brut, Sofort-Niederlage) |
| Schauplätze | L1 Fensterbrett, L2 Teppich-Labyrinth (2 Pfade), L3 Nachttisch |
| Schwierigkeit | eher fordernd; zentraler Regler `data/rules/balance.tres` |
| Sprache | nur Deutsch |
| Plattform | Windows-.exe + Android-APK |

## Stand
- [x] 🤖 Phase 1 — Meta-Schicht entfernt, linearer Fluss (Levelauswahl, Story-Router), schlanker Save, Umbenennung
- [x] 🤖 Phase 2 — Content-Reskin per Generator (Garten/Schnecken, 3 Level, 5 Dialoge), Texte, Docs
- [x] 🤖 Phase 3 — Mechaniken: `STRIKE_ALL`, essentielle Heldin, Heilen im Match, Brut, Boss-Leiste, Dahlie
- [x] 🤖 Phase 4 — Post-Dialoge, Abspann-Szene
- [x] 🤖 Phase 5 — `BalanceConfig` + `docs/BALANCING.md`; Erstbalance per Bot (L1 10/10, L2 8/10, L3 7/10 Blüten)
- [x] 🤖 Bild-Pipeline: Prompts in `ASSETS.md`, Freistell-Plugin `addons/chroma_key`, `tools/art.sh` (Freistellen, Iso-Kacheln, App-Icon, Dialog-Hintergründe, HUD-Icons)
- [ ] 🧑 Bilder nach `ASSETS.md` generieren → `art_raw/` → `bash tools/art.sh`
- [ ] 🧑 Story-Entwurf in `STORY.md` prüfen, Geburtstagsgruß (`CREDITS_LINE_2..4`) schreiben
- [ ] 🧑 Playtest am PC und auf dem Handy → 🤝 Balancing nachziehen
- [ ] 🤖 Windows-.exe + Android-APK bauen, auf dem Handy testen
- [ ] 🤖 Politur nach Playtest (z. B. Tutorial-Hinweise in L1, Kamera-Startausschnitt auf die Dahlie)

## Ideen für später (nicht im Plan)
Weitere schneckenfeste Pflanzen (Lavendel, Kapuzinerkresse, Kupferband), echte Animationen (`SpriteFrames`),
eigene Musik.
