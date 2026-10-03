# Balancing — so drehst du an der Schwierigkeit

## 1. Grob: ein Regler für alles — `data/rules/balance.tres`
Im Godot-Editor die Datei im Dateisystem-Dock anklicken → Werte im Inspector ändern → speichern.

| Feld | Wirkung | Leichter | Schwerer |
|---|---|---|---|
| `enemy_hp_mult` | Lebenspunkte aller Schnecken | 0.8 | 1.2 |
| `enemy_speed_mult` | Tempo aller Schnecken | 0.85 | 1.15 |
| `start_resource_mult` | Startguthaben je Level | 1.5 | 0.8 |
| `regen_mult` | Ressourcen pro Sekunde | 1.3 | 0.8 |
| `petals` | Blüten (Leben) je Level, 0 = Levelwert (10) | 15 | 6 |
| `hero_attack_mult` | Christinas Angriff (auch „Leinen los“) | 1.3 | 0.9 |
| `hero_ability_cooldown_mult` | Abklingzeit „Leinen los“ (45 s) | 0.7 | 1.3 |
| `tower_attack_mult` | Schaden der Hagebutten | 1.3 | 0.9 |
| `troop_mult` | LP + Angriff der Rosenkriegerinnen | 1.3 | 0.9 |

## 2. Fein: einzelne Dateien
- Schnecken: `data/units/sna_*.tres` (LP, Angriff, Tempo, `bounty` = Kopfgeld, Königin: `brood_*`)
- Christina: `data/heroes/gar_christina.tres`, „Leinen los“: `data/abilities/leinen_los.tres` (`power` = Vielfaches des Angriffs)
- Gebäude: `data/towers/gar_rosehip.tres`, `data/barracks/gar_rose_bush.tres` (Kosten, Upgrades)
- Level: `data/waves/gar_l1..3.tres` — Startguthaben, Regeneration, Kopfgeld-Faktor, Vorbereitungszeit,
  Heilkosten (`heal_cost_per_hp`) und die Wellen (am bequemsten im Talathon-Editor-Dock, Wellen-Zeitleiste).

## 3. Prüfen
```
bash tests/run_tests.sh
```
`content_sim_test` spielt jedes Level mit einem einfachen Bot und druckt z. B.
`gar_l3: WIN  petals 7/10 …`. Der Test **schlägt fehl, wenn der Bot ein Level verliert** – dann
ist es vermutlich auch für Menschen zu schwer (oder der Bot zu dumm; dann sag Bescheid).

Stand bei Auslieferung (alle Regler 1.0): L1 10/10, L2 8/10, L3 7/10 Blüten für den Bot.
Der Bot baut sofort alles voll aus – Menschen verlieren eher mehr Blüten.
