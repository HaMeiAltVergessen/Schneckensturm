# Talathon-Editor — Kurzanleitung

Das Plugin (`addons/talathon_editor/`, unter *Projekt → Projekteinstellungen → Plugins* aktiv) hängt
ein Panel **„Talathon"** unten in den Editor. Es öffnet sich, sobald im Dateisystem ein `MapLayout`
(`data/maps/*.tres`) oder ein `WaveSet` (`data/waves/*.tres`) ausgewählt wird.

Eine Karte besteht aus zwei Dateien:
- **MapLayout** — Geometrie, fraktionsneutral, wird von allen Feldzügen geteilt (Reskin über `tileset`).
- **WaveSet** — Wellen, Wirtschaft, Belohnungen, Akt und Fraktion; verweist auf ein MapLayout.

## Neue Karte anlegen
1. Dateisystem → Rechtsklick auf `data/maps/` → *Neu → Ressource…* → `MapLayout` → z. B. `layout_a1_04.tres`.
   Im Inspector `id` (= Dateiname) und `name_key` setzen.
2. Datei anklicken → Panel „Talathon" zeigt das Raster. Größe und Helden-Limit oben einstellen.
3. Malen (siehe unten), **Speichern**.
4. `data/waves/` → *Neu → Ressource…* → `WaveSet` (z. B. `zir_a1_04.tres`): `id`, `name_key`, `act`,
   `faction_id`, `layout` (das neue MapLayout hineinziehen) im Inspector setzen.
5. WaveSet anklicken → Wellen zusammenstellen → **Validieren** → **Schnelltest ▶**.
6. Damit die Karte im Feldzug erscheint: in `data/factions/garden.tres` beim Akt unter `maps` eintragen.
7. Neue Texte (`MAP_…_NAME`) in `localization/text.csv` ergänzen — `tests/content_loc_test` meldet fehlende Keys.

## Karte malen (MapLayout)
| Werkzeug | Wirkung |
|---|---|
| **Pfad** | Pfad mit der Nummer „Pfad #" verlängern: Nachbarfeld anklicken. Ein Feld in gerader Linie füllt die Lücke. Das letzte Feld erneut anklicken entfernt es. Erstes Feld = Spawn, letztes = Ausgang. |
| **Pfad-Feld** | Auf dem Pfad: hier dürfen Nahkampf-Helden stehen und blocken (gold). |
| **Rand-Feld** | Neben dem Pfad: Fernkampf/Support-Helden, blocken nie (blau). |
| **Bau-Slot** | Türme und Kasernen (weiß). Kasernen sammeln ihren Trupp auf dem nächsten Pfadfeld. |
| **Blockiert** | Deko/Hindernis. |
| **Radierer** / Rechtsklick | Markierung löschen; auf einem Pfad wird der Pfad ab diesem Feld abgeschnitten. |

Jeder Malstrich ist mit Strg+Z rückgängig zu machen.

**Map-Regel:** Pfade laufen nur zwischen Nachbarfeldern — auf dem Bildschirm also entlang der
Iso-Diagonalen. Sonst würden die Einheiten-Bilder sichtbar falsch laufen. Der Validator erzwingt das.

## Wellen (WaveSet)
Pro Welle beliebig viele Gruppen: Gegnertyp, Anzahl, Abstand (s), Start (s nach Wellenbeginn), Pfad.
„Pause danach" = Sekunden nach dem letzten Spawn, bis die nächste Welle automatisch startet (Spieler
können vorziehen). Die **Zeitleiste** rechts zeigt jede Gruppe als Balken, jeder Strich ist ein Spawn —
Vorschau ohne Spielstart. Wirtschaft (Startguthaben, Regeneration, Rückerstattung), Belohnungen,
Loot-Tabelle, Boss-Flag und Vordialog stehen im Inspector.

## Gebäude-Stufen
Türme und Kasernen werden im Inspektor gepflegt (`data/towers/`, `data/barracks/`). Die Grundwerte sind
Stufe 1; unter `upgrades` folgt je Eintrag eine weitere Stufe (`TowerLevel`: Kosten, Schaden,
Angriffsintervall; `BarracksLevel`: Kosten, Truppen-Faktor). Ein optionales `texture` je Stufe ersetzt den Skin.

## Validierung
Fehler (rot) verhindern sinnvolles Spielen: Pfad unterbrochen/diagonal, Pfad-Feld nicht auf Pfad,
Markierungen doppelt, Pfad-Index ungültig, keine Wellen …
Warnungen (gelb) sind Hinweise: Bau-Slot zu weit vom Pfad, Wellenzahl außerhalb des Richtwerts
(Akt 1: 5–7, Akt 2: 7–9, Akt 3: 9–12), knappes Startguthaben.

## Schnelltest
Speichert, schreibt die Karte nach `user://quicktest.cfg` und startet `scenes/match/match.tscn` mit einem
temporären Spielstand (alle Helden der Fraktion außer Mythen). Nichts davon landet im echten Spielstand.
Bei einem MapLayout wird das erste WaveSet benutzt, das dieses Layout verwendet.

## Automatischer Probelauf
`tests/content_sim_test` spielt jede Karte mit einem einfachen Bot (Heldenstufe wie an dieser Stelle der
Kampagne) und gibt Sieg/Niederlage, Leaks und durchgekommene Gegnertypen aus — ein schneller
Balance-Hinweis nach dem Bauen neuer Wellen.
