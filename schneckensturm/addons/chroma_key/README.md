# Chroma Key — Godot-4-Plugin zum Freistellen

Entfernt einen **einfarbigen Hintergrund** (Magenta, Cyan, Greenscreen …) aus Bildern – gedacht für
KI-generierte Sprites (Flux, SDXL …), die keine echte Transparenz können. Projektunabhängig, Godot 4.3+.

- **Flood-Fill vom Rand:** nur Hintergrund, der mit dem Bildrand verbunden ist, wird entfernt –
  keyfarbene Details *in* der Figur bleiben. Optional `holes`: auch eingeschlossene Flächen
  (zwischen Bogen und Sehne, Ästen) freistellen – nur Pixel sehr nah an der Keyfarbe.
- **Keyfarbe automatisch** aus dem Rand-Median (oder fest vorgeben).
- **Weiche Kante** (Toleranz + Feather) und **Despill** (Farbsaum wird herausgerechnet).
- `trim` (auf Inhalt zuschneiden), `union_rect` (gleicher Ausschnitt für Stufen/Frames),
  `fit` (Einpassen, mittig oder Fußpunkt unten), `cover` (Hintergründe füllend skalieren).

## Installation in einem anderen Projekt
Ordner `addons/chroma_key/` kopieren → *Projekt → Projekteinstellungen → Plugins* → „Chroma Key“ aktivieren.
(Für CLI und Skripte ist das Aktivieren nicht nötig – `ChromaKey` ist eine globale Klasse.)

## Nutzung
**Editor:** *Projekt → Werkzeuge → Chroma Key (Freistellen)…* → Bilder wählen, Regler einstellen
(Live-Vorschau vorher/nachher auf Grau), „Freistellen & speichern“.

**Headless/Batch:**
```
godot --headless --path . --script res://addons/chroma_key/cli.gd -- \
    --in art_raw/figures --out res://assets/sprites --size 512 --anchor bottom
```
Optionen: `--size N|WxH`, `--anchor center|bottom`, `--key #ff00ff`, `--tolerance 0.22`,
`--feather 0.14`, `--margin 8`, `--holes`, `--no-trim`, `--shared-trim`, `--cover WxH` (ohne Keying, füllend).

**Im Code:**
```gdscript
var img := ChromaKey.key(Image.load_from_file("raw.png"))          # Keyfarbe automatisch
img = ChromaKey.fit(ChromaKey.trim(img), Vector2i(512, 512), ChromaKey.Anchor.BOTTOM)
img.save_png("res://assets/hero.png")
```

## Tipps für den Prompt
- „plain flat solid magenta (#FF00FF) background, no shadow on the background, no gradient“.
- Keyfarbe wählen, die im Motiv **nicht** vorkommt: Magenta für grüne/braune Motive, Cyan für
  rosa/rote Motive, Grün für alles ohne Grün.
- Bleibt ein Saum: Toleranz leicht erhöhen; frisst es in die Figur: Toleranz senken.

Lizenz: MIT (`LICENSE`).
