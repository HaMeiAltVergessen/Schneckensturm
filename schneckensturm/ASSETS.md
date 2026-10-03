# Assets — Bildliste und Pipeline

## So kommen deine Bilder ins Spiel
1. Bild als PNG mit **transparentem Hintergrund** unter `assets/garden/<dateiname>.png` ablegen
   (Dateinamen exakt wie in der Tabelle unten).
2. Einmal importieren und verdrahten:
   ```
   GODOT="E:/Godot/Godot_v4.4-stable_win64_console.exe"
   "$GODOT" --headless --path . --import
   "$GODOT" --headless --path . --script res://tools/link_art.gd
   ```
   `link_art.gd` setzt nur die Bildfelder in den `.tres` – Balancing-Werte bleiben unangetastet.
3. Spiel starten (F5). Fehlt ein Bild, bleibt der Platzhalter.

Die Dahlie und der Abspann-Hintergrund werden direkt über den Dateinamen gefunden (kein `link_art` nötig).

## Format
- Figuren (Christina, Rosen, Schnecken): quadratisch, **512 px** Quelle, Figur mittig, ganzer Körper,
  isometrische 3/4-Ansicht, Blick nach **rechts** (das Spiel spiegelt für die Gegenrichtung).
  Im Spiel als runder Medaillon-Token gezeigt → Figur soll den Kreis gut füllen.
- Gebäude (Rosenbusch, Hagebuttenstrauch): ca. **256 px breit**, Fußpunkt unten mittig, steht auf einer Iso-Kachel.
- Dahlie: ca. **256×384** (hochkant), Fußpunkt unten mittig, 4 Fraßstufen mit identischem Bildausschnitt.
- Kacheln (optional, zuletzt): 2:1-Iso **128×64** – die verdrahte ich (🤖), wenn du sie lieferst.

## Bildliste
| Datei (`assets/garden/…`) | Was | Wo im Spiel |
|---|---|---|
| `gar_christina.png` | Christina, Spielzeuggröße, Schlafanzug, Fernkampf-Waffe (deine Wahl) | Heldin, Dialog-Porträt |
| `mom.png` | Christinas Mama (freundlich, Porträt) – optional | Dialog-Porträt |
| `gar_rose.png` | Rosenkriegerin: kleine Kämpferin aus Rosenblüte/-stiel mit Dornen-Schwert | Nahkampf-Truppe |
| `gar_rose_bush.png`, `gar_rose_bush_2.png`, `gar_rose_bush_3.png` | Rosenbusch Stufe 1–3 (immer üppiger) | Kaserne |
| `gar_rosehip.png`, `gar_rosehip_2.png`, `gar_rosehip_3.png` | Hagebuttenstrauch Stufe 1–3 (mehr/größere Früchte) | Turm |
| `sna_slug.png` | Nacktschnecke – klein, flink, frech | Gegner Tier 1 |
| `sna_garden_snail.png` | Weinbergschnecke – dickes Haus, behäbig | Gegner Tier 2 (gepanzert) |
| `sna_spitter.png` | Schleimspucker – Schnecke mit grünem Schleim im Maul | Gegner Tier 3 (Fernkampf) |
| `sna_armored.png` | Panzerschnecke – Haus wie ein Rammbock/Helm | Gegner Tier 4 (greift Pflanzen an) |
| `sna_queen.png` | Schneckenkönigin – riesig, Krone, Umhang, gierig-dramatisch | Boss, Dialog-Porträt |
| `dahlia_0.png` … `dahlia_3.png` | Dahlie im Topf: 0 = unversehrt, 1 = angeknabbert, 2 = stark angefressen, 3 = fast kahl | Ziel am Pfadende |
| ⚠ `assets/ui/credits_bg.png` (anderer Ordner!) | Morgenlicht im Zimmer, Dahlie auf dem Nachttisch | Abspann-Hintergrund |

## Stilblock für Flux (Vorschlag — anpassen)
```
Allgemein: cozy storybook illustration, soft painterly shading, warm colors, moonlit child's
bedroom at night, toy-sized world, isometric 3/4 view, full body, centered, single character,
transparent background, no text
Christina: young woman in pajamas, determined and cheerful, tiny (toy-sized), ...
Schnecken: cute but mischievous snails, glossy slime, expressive eyes, ...
Pflanzen: lush garden plants as defenders, rose red / rosehip orange-red, glossy leaves, ...
```
Tipp: gleichen Seed und Stilblock für alle Figuren verwenden, damit sie zusammenpassen.
