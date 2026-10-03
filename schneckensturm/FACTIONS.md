# Fraktionen — Christinas Garten vs. die Schneckenarmee

Werte stehen in den `.tres` unter `data/` (Balancing: `docs/BALANCING.md`), Namen in
`localization/text.csv`. Bilder: `ASSETS.md`.

## Christinas Garten (`garden`, Spieler)
| ID | Was | Rolle |
|---|---|---|
| `gar_christina` | Christina – einzige Heldin | Fernkampf auf blauen Randfeldern, Reichweite 3. **Fällt sie, ist das Level verloren**; im Auswahlpanel für Ressourcen heilbar |
| `leinen_los` | Fähigkeit „Leinen los!“ | trifft **alle** Schnecken auf der Karte (3× Angriff), Abklingzeit 45 s |
| `gar_rose_bush` → `gar_rose` | Rosenbusch (Kaserne) → Rosenkriegerinnen | 2 Nahkämpferinnen blockieren den Pfad, wachsen nach 12 s nach; 3 Stufen |
| `gar_rosehip` | Hagebuttenstrauch (Turm) | Einzelziel, Reichweite 3,5; Fähigkeit *Hagebuttenhagel* (Flächenschaden); 3 Stufen |
| Dahlie | Ziel | 10 Blüten (= Leben) je Level |

Weitere schneckenfeste Pflanzen sind jederzeit möglich (neues `TowerData`/`BarracksData` in
`data/` + Eintrag in `data/factions/garden.tres`). Ideen: Lavendel (verlangsamt), Kapuzinerkresse
(Köder), Eierschalen-Barriere, Kupferband.

## Die Schneckenarmee (`snails`, nur Gegner)
| ID | Name | Klasse (Zielregel) | Besonderheit |
|---|---|---|---|
| `sna_slug` | Nacktschnecke | Nahkampf | schnell, schwach (Tier 1) |
| `sna_garden_snail` | Weinbergschnecke | Nahkampf | gepanzert, langsam (Tier 2) |
| `sna_spitter` | Schleimspucker | Fernkampf | schießt auf Christina (Tier 3) |
| `sna_armored` | Panzerschnecke | Belagerer | greift Rosenbüsche/Hagebutten an, kostet 2 Blüten (Tier 4) |
| `sna_queen` | Die Schneckenkönigin | Nahkampf, Boss | Boss-Leiste, legt alle 6 s zwei Nacktschnecken, erreicht sie die Dahlie: sofort verloren |
