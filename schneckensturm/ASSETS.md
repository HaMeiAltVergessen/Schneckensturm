# Assets — Bildliste, Flux-Prompts und Pipeline

Alle Bilder entstehen mit **Flux (ComfyUI)**. Die Rohbilder kommen unverändert nach `art_raw/`.
Freistellen, Zuschneiden, Skalieren, Kacheln, Icons und das Verdrahten übernimmt `tools/art.sh`.
Fehlt ein Bild, bleibt im Spiel einfach der Platzhalter – du kannst also in beliebiger Reihenfolge liefern.

## Inhalt
1. [Workflow](#1-workflow) · 2. [ComfyUI-Einstellungen](#2-comfyui-einstellungen) · 3. [Stilregeln](#3-stilregeln)
4. Prompts: [Figuren](#41-figuren--art_rawfigures) · [Porträts](#42-porträts--art_rawportraits) ·
[Gebäude](#43-gebäude--art_rawbuildings) · [Dahlie](#44-dahlie--art_rawdahlia) · [Hintergründe](#45-hintergründe--art_rawbackgrounds) ·
[Icons](#46-icons--art_rawicons) · [App-Icon](#47-app-icon--art_rawapp) · [Boden-Kacheln](#48-boden-kacheln--art_rawtiles)
5. [Abhakliste](#5-abhakliste) · 6. [Probleme & Lösungen](#6-probleme--lösungen)

---

## 1. Workflow
1. Bild in ComfyUI erzeugen (Prompt unten kopieren, Auflösung aus der Karte nehmen).
2. Als PNG speichern unter **`art_raw/<ordner>/<dateiname>.png`**. Ordner und Name stehen in jeder Karte.
   Groß-/Kleinschreibung beachten, keine Leerzeichen.
3. Im Projektordner ausführen:
   ```
   bash tools/art.sh          # nur neue/geänderte Bilder
   bash tools/art.sh --all    # alles neu verarbeiten
   ```
   Das Skript erledigt nacheinander:
   - Hintergrund freistellen (Plugin `addons/chroma_key`)
   - zuschneiden und skalieren
   - Iso-Kacheln, App-Icons und JPG-Hintergründe bauen
   - importieren
   - in die `.tres` verdrahten (`tools/link_art.gd`)

   Balancing-Werte bleiben dabei unangetastet.
4. Spiel starten (F5) und anschauen. Gefällt ein Bild nicht: neu generieren, gleiche Datei überschreiben, Schritt 3 wiederholen.

| Ordner in `art_raw/` | wird zu | Größe im Projekt |
|---|---|---|
| `figures/` | `assets/garden/<name>.png` | 512 × 512, mittig |
| `portraits/` | `assets/garden/<name>.png` | 512 × 512, unten bündig |
| `buildings/` | `assets/garden/<name>.png` | 256 × 320, Fußpunkt unten |
| `dahlia/` | `assets/garden/<name>.png` | 256 × 384, Fußpunkt unten |
| `icons/` | `assets/ui/<name>.png` | 128 × 128 |
| `backgrounds/` | `assets/ui/<name>.jpg` | 1920 × 1080 (füllend zugeschnitten, **kein** Freistellen) |
| `app/` | `assets/app/icon*.png` + Projekt-/Android-Icon | 256 / 192 / 432 |
| `tiles/` | `assets/tiles/gar_l<n>_tiles.png` + Tileset je Level | 128 × 64 Iso-Rauten |

Stufenbilder werden **gemeinsam** zugeschnitten. Das betrifft `gar_rosehip`/`_2`/`_3` und `dahlia_0…3`. Größenunterschiede zwischen den Stufen bleiben so erhalten.
Bilder mit gleichem Namen ohne Endziffer gehören zusammen.

**Einzelbild von Hand freistellen:** In Godot über *Projekt → Werkzeuge → Chroma Key (Freistellen)…*.
Dort gibt es Live-Vorschau, Regler für Toleranz und weiche Kante und eine Zielgröße.
Das Ergebnis direkt nach `assets/garden/` speichern und danach `bash tools/art.sh` laufen lassen (verdrahtet es).

---

## 2. ComfyUI-Einstellungen
- **Modell:** Flux.1-dev (schnell und gut genug: Flux.1-schnell mit 4–8 Steps).
- **FluxGuidance** 3,5 · **Steps** 28 · **Sampler** `euler` · **Scheduler** `simple` oder `beta`.
- **Kein Negativ-Prompt** bei Flux. „no text, no watermark, no shadow“ steht deshalb im Prompt selbst.
- **Seed:** Pro Gruppe einen guten Seed merken und für die anderen Bilder der Gruppe wiederverwenden (Figuren, Pflanzen, Hintergründe). Das hält den Stil zusammen.
- **Stufenbilder per img2img:** Rosenbusch 2/3, Hagebutte 2/3 und Dahlie 1–3 entstehen aus Stufe 1 bzw. `dahlia_0`. Dafür das Basisbild laden, `VAE Encode` verwenden, **Denoise 0,45–0,6**, den Stufen-Prompt nehmen und den gleichen Seed.
  Alternativ Inpainting nur auf der Blüte bzw. den Blättern.
- **Auflösungen** (Flux mag ~1 Megapixel, Vielfache von 64):

| Art | Auflösung |
|---|---|
| Figuren, Porträts, Gebäude, Icons, App-Icon, Kacheln | 1024 × 1024 |
| Dahlie | 832 × 1216 (hochkant) |
| Hintergründe | 1344 × 768 (16:9) |

---

## 3. Stilregeln
Die Prompts unten sind **komplett ausformuliert** und können 1:1 kopiert werden. Wiederkehrende Bausteine:

- **Stil:** *cute cartoon storybook illustration, clean bold outlines, flat cel shading with soft highlights,
  vibrant saturated colors, slightly chibi proportions*
- **Freisteller-Hintergrund:** *plain flat solid magenta background (#FF00FF)*.
  - Gilt für Christina, Mama und alle Schnecken außer der Königin.
  - **Cyan (#00FFFF)** gilt für Rosen, Hagebutten, Dahlie, Königin (lila Umhang!) und rosa/rote Icons.
  - Regel: Die Keyfarbe darf im Motiv nicht vorkommen.
- **Blickrichtung:** Figuren schauen **nach rechts** (das Spiel spiegelt sie bei Bedarf).
  Ganzer Körper, mittig, etwas Luft drumherum. Im Spiel erscheinen sie als **runde Medaillons**,
  daher kompakte Posen ohne weit abstehende Waffen.
- **Pflanzen haben Augen** (niedlich, lebendig). **Schnecken sind „cartoony evil“**: frech, gierig, aber knuffig.

⚙ = darfst du frei anpassen. **Christinas Beschreibung** steht identisch in allen Prompts. Wenn du sie änderst, ändere sie überall:
> ⚙ *a cheerful young woman with long dark blond hair, wide hips and a curvy figure, wearing soft sage-green
> pajamas with a small coral dahlia print, barefoot, a wooden bow, a brown leather quiver full of arrows on her back*

---

## 4. Prompts

### 4.1 Figuren → `art_raw/figures/`
Spielfiguren (Token auf dem Spielfeld). 1024 × 1024, magenta bzw. cyan Hintergrund.

**`gar_christina.png`** — Heldin
```
Cute cartoon storybook illustration of a tiny toy-sized heroine: a cheerful young woman with long dark blond hair, wide hips and a curvy figure, wearing soft sage-green pajamas with a small coral dahlia print, barefoot, a brown leather quiver full of arrows on her back. She holds a wooden bow drawn with an arrow, aiming to the right, determined and cheerful expression, confident stance. Full body, three-quarter view facing right, centered, compact pose, some empty space around her. Clean bold outlines, flat cel shading with soft highlights, vibrant saturated colors, slightly chibi proportions, game character sprite. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no ground, no gradient, no text, no watermark.
```

**`gar_rose.png`** — Rosenkriegerin (Truppe aus dem Rosenbusch)
```
Cute cartoon storybook illustration of a small brave rose warrior: her head is a blooming red rose with big expressive cute eyes and a determined smile, her body is a green stem with leaf arms and little leaf feet, she holds a sharp thorn as a sword and a rose leaf as a shield. Full body, three-quarter view facing right, centered, compact fighting stance. Clean bold outlines, flat cel shading with soft highlights, vibrant saturated colors, chibi proportions, game character sprite. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no ground, no gradient, no text, no watermark.
```

**`sna_slug.png`** — Nacktschnecke (Tier 1: flink, schwach)
```
Cute but mischievous cartoon slug without a shell, small and fast, glossy orange-brown slimy body, big expressive eyes on long eyestalks, sneaky cheeky evil grin, leaning forward as if sprinting, a little drop of slime behind it. Full body, side three-quarter view facing right, centered. Cartoony evil villain minion, clean bold outlines, flat cel shading with glossy highlights, vibrant saturated colors, chibi proportions, game character sprite. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no ground, no gradient, no text, no watermark.
```

**`sna_garden_snail.png`** — Weinbergschnecke (Tier 2: gepanzert, langsam)
```
Cute but mischievous cartoon Roman snail, big and chunky, a thick heavy cream-and-brown spiral shell like a fortress, slow and smug, half-lidded eyes on eyestalks, arrogant evil smirk, glossy grey-beige slimy body. Full body, side three-quarter view facing right, centered. Cartoony evil villain, clean bold outlines, flat cel shading with glossy highlights, vibrant saturated colors, chibi proportions, game character sprite. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no ground, no gradient, no text, no watermark.
```

**`sna_spitter.png`** — Schleimspucker (Tier 3: Fernkampf, spuckt auf Christina)
```
Cute but mischievous cartoon snail with puffed-up cheeks, spitting a big glob of bright lime-green slime forward to the right, a small striped yellow-brown shell, glossy olive slimy body, big expressive eyes on eyestalks squinting while aiming, cartoony evil grin. Full body, side three-quarter view facing right, centered. Clean bold outlines, flat cel shading with glossy highlights, vibrant saturated colors, chibi proportions, game character sprite. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no ground, no gradient, no text, no watermark.
```

**`sna_armored.png`** — Panzerschnecke (Tier 4: greift Pflanzen an)
```
Cute but mischievous cartoon snail in armor, its shell is a dented riveted iron helmet shaped like a battering ram pointing forward, angry eyebrows, eyes on eyestalks with tiny helmets, gritted teeth, charging forward, glossy dark grey slimy body. Full body, side three-quarter view facing right, centered. Cartoony evil siege brute, clean bold outlines, flat cel shading with metallic and glossy highlights, vibrant colors, chibi proportions, game character sprite. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no ground, no gradient, no text, no watermark.
```

**`sna_queen.png`** — Die Schneckenkönigin (Boss)
```
Cute but dramatic cartoon snail queen, huge and plump, a jeweled golden crown balanced on her eyestalks, a royal purple velvet cape with white ermine trim, a shell decorated with gold and gems, greedy hungry grin, licking her lips, one eyestalk raised theatrically, glossy pale green slimy body. Full body, side three-quarter view facing right, centered, imposing pose. Cartoony evil villain boss, clean bold outlines, flat cel shading with glossy highlights, vibrant saturated colors, chibi proportions, game character sprite. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no ground, no gradient, no text, no watermark.
```

### 4.2 Porträts → `art_raw/portraits/`
Brustbilder für die Dialogbox. Optional: Fehlt ein Porträt, wird das Figurenbild genommen. 1024 × 1024.

**`gar_christina_portrait.png`**
```
Cute cartoon storybook character portrait, head and shoulders of a cheerful young woman with long dark blond hair, wearing soft sage-green pajamas with a small coral dahlia print, the wooden bow and the arrow feathers of her quiver visible over her shoulder, warm confident smile, looking slightly to the right, expressive big eyes. Centered bust, clean bold outlines, flat cel shading with soft highlights, vibrant saturated colors. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no gradient, no text, no watermark.
```

**`sna_queen_portrait.png`**
```
Cute but dramatic cartoon character portrait, head and upper body of a plump snail queen with a jeweled golden crown on her eyestalks and a royal purple velvet cape with white ermine trim, greedy scheming grin, one eyestalk raised, drooling slightly, looking slightly to the right. Centered bust, clean bold outlines, flat cel shading with glossy highlights, vibrant saturated colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no gradient, no text, no watermark.
```

**`mom.png`** — Mama, nur Silhouette
```
Dark shadow silhouette of an ordinary friendly woman, head and shoulders, shoulder-length hair, completely dark figure with no visible facial features, a soft warm golden rim light along her outline, gentle and kind posture, looking slightly to the right. Centered bust, simple clean shape, storybook style. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no gradient, no text, no watermark.
```

### 4.3 Gebäude → `art_raw/buildings/`
Stehen auf einer Iso-Kachel. Fußpunkt unten in der Mitte, leicht von oben gesehen. 1024 × 1024, cyan.
Stufe 1 normal generieren, Stufe 2 und 3 per **img2img aus Stufe 1** (Denoise ~0,55, gleicher Seed).

**`gar_rose_bush.png`** — Rosenbusch Stufe 1 (Kaserne, schickt Rosenkriegerinnen)
```
Cute cartoon storybook illustration of a small round rose bush as a living defender, a few red rose blossoms, glossy green leaves, two big cute eyes peeking out between the leaves with a brave look, growing from a small patch of dark soil. Isometric three-quarter top-down view, the bush stands on the ground with its base at the bottom center, centered, game building sprite. Clean bold outlines, flat cel shading with soft highlights, vibrant saturated colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no gradient, no text, no watermark.
```
**`gar_rose_bush_2.png`** — Stufe 2 (img2img)
```
The same cute rose bush defender, now bigger and fuller, many more red rose blossoms, thorny vines curling out, eyes more confident and determined, a small wooden garden trellis behind it. Isometric three-quarter top-down view, base at the bottom center, game building sprite. Clean bold outlines, flat cel shading, vibrant saturated colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no text, no watermark.
```
**`gar_rose_bush_3.png`** — Stufe 3 (img2img)
```
The same cute rose bush defender at its mightiest, lush and tall, covered in large glowing red roses, a crown of blossoms on top, strong thorny vines like a fortress wall, proud heroic eyes, tiny golden sparkles. Isometric three-quarter top-down view, base at the bottom center, game building sprite. Clean bold outlines, flat cel shading, vibrant saturated colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no text, no watermark.
```

**`gar_rosehip.png`** — Hagebuttenstrauch Stufe 1 (Turm, schießt Hagebutten)
```
Cute cartoon storybook illustration of a small wild rose shrub as a living turret, a few shiny glossy orange-red rosehips hanging from thorny branches, green leaves, two big cute eyes with a cheeky aiming look, one branch bent back like a slingshot holding a rosehip, growing from a small patch of dark soil. Isometric three-quarter top-down view, base at the bottom center, centered, game tower sprite. Clean bold outlines, flat cel shading with soft highlights, vibrant saturated colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no gradient, no text, no watermark.
```
**`gar_rosehip_2.png`** — Stufe 2 (img2img)
```
The same cute rosehip shrub turret, now bigger, many more large glossy orange-red rosehips, two branches bent back like catapults loaded with rosehips, focused eyes. Isometric three-quarter top-down view, base at the bottom center, game tower sprite. Clean bold outlines, flat cel shading, vibrant saturated colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no text, no watermark.
```
**`gar_rosehip_3.png`** — Stufe 3 (img2img)
```
The same cute rosehip shrub turret at full power, a big bush heavily laden with huge shiny orange-red rosehips, several rosehips glowing warmly as if ready to fire, strong thorny branches like a battery of catapults, fierce determined eyes. Isometric three-quarter top-down view, base at the bottom center, game tower sprite. Clean bold outlines, flat cel shading, vibrant saturated colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no text, no watermark.
```

### 4.4 Dahlie → `art_raw/dahlia/`
Das Ziel am Pfadende. Die Stufe wechselt mit den verlorenen Blüten (0 = alle da … 3 = fast keine).
832 × 1216, cyan. **Alle vier Bilder brauchen den gleichen Bildausschnitt.** Also `dahlia_0` normal generieren,
1–3 per img2img oder Inpainting daraus. ⚙ Farbe: korallrosa. ⚙ Augen: Wer die Dahlie ohne Gesicht will, streicht den Satz mit den Augen.

**`dahlia_0.png`** — unversehrt
```
Cute cartoon storybook illustration of a single gorgeous coral-pink dahlia flower in a small terracotta pot, one perfect full round bloom with many layered petals on a tall green stem with a few leaves, big cute eyes and a happy smile in the flower center. Front three-quarter view, the pot stands at the bottom center, whole plant visible, centered. Clean bold outlines, flat cel shading with soft highlights, vibrant saturated colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no gradient, no text, no watermark.
```
**`dahlia_1.png`** — angeknabbert (img2img, Denoise ~0,45)
```
The same coral-pink dahlia in the terracotta pot, a few petals bitten off with small round bite marks, one leaf nibbled, a thin shiny slime trail on the pot, the flower face looks worried. Same framing, front three-quarter view, pot at the bottom center. Clean bold outlines, flat cel shading, vibrant colors. Isolated on a plain flat solid cyan background (#00FFFF), no text, no watermark.
```
**`dahlia_2.png`** — stark angefressen (img2img, Denoise ~0,5)
```
The same coral-pink dahlia in the terracotta pot, heavily nibbled, about half of the petals missing, chewed ragged leaves, slime drips on the pot, the stem slightly bent, the flower face looks scared with a tear. Same framing, front three-quarter view, pot at the bottom center. Clean bold outlines, flat cel shading, vibrant colors. Isolated on a plain flat solid cyan background (#00FFFF), no text, no watermark.
```
**`dahlia_3.png`** — fast kahl (img2img, Denoise ~0,55)
```
The same dahlia in the terracotta pot, almost bald, only two or three coral-pink petals left, leaves chewed down to the veins, drooping stem, lots of glossy slime on the pot, the flower face crying dramatically. Same framing, front three-quarter view, pot at the bottom center. Clean bold outlines, flat cel shading, vibrant colors. Isolated on a plain flat solid cyan background (#00FFFF), no text, no watermark.
```

### 4.5 Hintergründe → `art_raw/backgrounds/`
1344 × 768, **kein** Freistellen. Die Dialogbox liegt im **unteren Drittel**, dieser Bereich bleibt ruhig und eher dunkel.
Szenen mit Christina in Normalgröße zeigen sie ohne Bogen. Ab dem Schrumpfen ist sie winzig, mit Bogen.

**`menu_bg.png`** — Hauptmenü, Levelauswahl, Einstellungen (wird abgedunkelt, Titel und Buttons liegen mittig)
```
Cozy cartoon storybook illustration, wide shot of a moonlit windowsill in a child's bedroom at night seen from toy-size perspective: on the left a big coral-pink dahlia in a terracotta pot with cute eyes, a tiny heroine with long dark blond hair in sage-green pajamas with a bow and quiver standing guard, a small rose bush and rosehip shrub with eyes beside her; on the right a cartoon army of mischievous snails led by a plump snail queen with a golden crown and purple cape creeping in through the open window. The center of the image is calm, darker and empty for a title. Clean bold outlines, soft cel shading, deep blue moonlight with warm accents, vibrant colors, no text, no watermark.
```

**`bg_gar_intro.png`** — Intro, Zeilen 1–2: Mama schenkt die Dahlie (Tag)
```
Cozy cartoon storybook illustration of a warm sunny birthday afternoon in a cozy bedroom: a cheerful young woman with long dark blond hair in a casual outfit happily receives a coral-pink dahlia in a terracotta pot with a big ribbon bow, held out by a woman who is shown only as a dark shadow silhouette without facial features; balloons and a small birthday cake on the table, a garden visible through the window. Calm, softer lower third. Clean bold outlines, soft cel shading, warm golden light, vibrant colors, no text, no watermark.
```

**`bg_gar_intro_3.png`** — Intro ab Zeile 3: nachts, auf Spielzeuggröße geschrumpft
```
Cozy cartoon storybook illustration, the same bedroom at night seen from the floor at toy-size perspective: the carpet is a vast landscape, the bed towers like a mountain, slippers as big as boats, moonlight streams through the window, on the windowsill high above glistening slime trails and many tiny glowing snail eyes in the dark, the coral dahlia silhouetted against the moon. Mysterious but cute mood, calm darker lower third. Clean bold outlines, soft cel shading, deep blue moonlight, no text, no watermark.
```

**`bg_gar_l1_post.png`** — nach Level 1
```
Cozy cartoon storybook illustration, a moonlit windowsill after a little battle seen from toy-size perspective: defeated cartoon snails retreating with dizzy eyes, puddles of slime, a cute rose bush and a rosehip shrub with eyes cheering, below on the vast carpet the plump snail queen with her golden crown and purple cape shaking an eyestalk angrily, her snail army gathering behind her. Funny triumphant mood, calm lower third. Clean bold outlines, soft cel shading, blue moonlight with warm accents, no text, no watermark.
```

**`bg_gar_l2_post.png`** — nach Level 2
```
Cozy cartoon storybook illustration, a huge carpet landscape at night from toy-size perspective: chair legs rise like giant tree trunks, mountains of crumpled socks, abandoned toys, a battered snail army regrouping between the sock mountains, the plump snail queen with golden crown and purple cape pointing dramatically up to a bedside table in the distance where a coral-pink dahlia glows in the moonlight. Adventurous mood, calm darker lower third. Clean bold outlines, soft cel shading, blue moonlight, no text, no watermark.
```

**`bg_gar_l3_pre.png`** — vor Level 3: Showdown auf dem Nachttisch
```
Cozy cartoon storybook illustration, dramatic showdown on top of a wooden bedside table in moonlight seen from toy-size perspective: the coral-pink dahlia in its terracotta pot glows in a moonbeam, a book stack and an alarm clock as giant landmarks, the huge plump snail queen with a golden crown and purple cape climbs over the table edge with a greedy grin, a swarm of baby slugs pours out behind her. Epic but cute boss mood, calm darker lower third. Clean bold outlines, soft cel shading, cold blue moonlight with a warm glow around the dahlia, no text, no watermark.
```

**`bg_gar_finale.png`** — Finale, Zeilen 1–2: die Königin ist besiegt
```
Cozy cartoon storybook illustration, the top of a bedside table at the very first light of dawn seen from toy-size perspective: the coral-pink dahlia in its terracotta pot towers triumphantly above the scene, standing tall and proud with a confident smile, lit by the first warm sunbeam; below her a beaten snail army retreats in a panic, the snails comically studded with many small arrows sticking out of their shells like pincushions, sweating and wide-eyed; together they strain to drag their defeated plump snail queen by her purple cape towards the open window, the queen lies dazed on her back with her golden crown askew and stars circling her eyestalks, one slug pushes from behind, another tugs at the window frame. Funny victorious mood, calm lower third. Clean bold outlines, soft cel shading, pink-orange dawn light mixing with fading moonlight, no text, no watermark.
```

**`bg_gar_finale_3.png`** — Finale ab Zeile 3: Morgen, wieder groß
```
Cozy cartoon storybook illustration of a bright sunny morning in a cozy bedroom: a cheerful young woman with long dark blond hair in sage-green pajamas with a small coral dahlia print sits up in bed at normal size, stretching happily, the healthy coral-pink dahlia in a terracotta pot glows in the sunlight on the bedside table, a dark shadow silhouette of a woman without facial features stands in the open doorway. Warm happy mood, calm lower third. Clean bold outlines, soft cel shading, warm golden sunlight, no text, no watermark.
```

**`credits_bg.png`** — Abspann (wird abgedunkelt, der Gruß liegt mittig darüber)
```
Cozy cartoon storybook illustration, warm morning sunlight on a bedside table: the coral-pink dahlia in full bloom in its terracotta pot with a happy face, a tiny wooden bow and quiver leaning against the pot, a small rose bush and rosehip shrub with cute eyes celebrating, colorful confetti and a small birthday candle, a slime trail leading out of the open window towards a vegetable garden. Calm composition with an open, softly lit center. Clean bold outlines, soft cel shading, warm golden light, vibrant colors, no text, no watermark.
```

#### Kampf-Hintergründe
Liegen im Kampf **bildschirmfest hinter der Karte** (leicht abgedunkelt). Die Iso-Karte bedeckt als Raute die
**Bildmitte** → Mitte ruhig, gleichmäßig und ohne Objekte; Deko nur an Rändern und in den Ecken.
Blick leicht von oben, passend zum Boden des Levels. 1344 × 768. Werden automatisch in `MapLayout.background` verdrahtet.

**`bg_battle_gar_l1.png`** — Level 1: Die Fensterbank
```
Cozy cartoon storybook illustration, high-angle view looking down onto a wide white painted wooden windowsill at night from toy-size perspective, the flat sill surface fills the whole frame with soft brush strokes and subtle wood grain. Only along the edges and in the corners: the bottom of a tall window frame with an open window at the top edge showing a starry night sky and a big moon, terracotta flower pots with rich soil and small green sprouts in the left and right corners, a few pebbles, glistening silvery snail slime trails creeping in from the top edge. The large center of the image is calm, even and completely empty. Clean bold outlines, soft cel shading, cool blue moonlight with warm accents, vibrant colors, no characters, no text, no watermark.
```

**`bg_battle_gar_l2.png`** — Level 2: Die Teppichlandschaft
```
Cozy cartoon storybook illustration, high-angle view looking down onto a vast soft wool rug at night from toy-size perspective, the rug with a cozy deep red and cream folk pattern and visible soft pile fills the whole frame. Only along the edges and in the corners: giant wooden chair legs rising like tree trunks, mountains of crumpled colorful knitted socks, a toppled toy wooden block, a marble and a crayon as huge landmarks, faint glossy slime trails crossing in from the edges. The large center of the image is calm, even and completely empty. Clean bold outlines, soft cel shading, cool blue moonlight with warm accents, vibrant colors, no characters, no text, no watermark.
```

**`bg_battle_gar_l3.png`** — Level 3: Showdown auf dem Nachttisch (Boss)
```
Cozy cartoon storybook illustration, high-angle view looking down onto the top of a dark polished walnut bedside table at night from toy-size perspective, the smooth wood with a white crocheted lace doily fills the whole frame. Only along the edges and in the corners: a towering stack of old books with gold embossed spines, a giant brass alarm clock, the base of a bedside lamp, the table edge dropping into a dark abyss at the bottom corners, a dramatic beam of cold moonlight falling across the scene, dark slime trails creeping over the table edge. The large center of the image is calm, even and completely empty. Epic but cute boss mood, clean bold outlines, soft cel shading, cold blue moonlight with a faint purple glow, no characters, no text, no watermark.
```

### 4.6 Icons → `art_raw/icons/`
Werden 128 px klein, deshalb **ein** klares Objekt mit dicken Umrissen und ohne Details. 1024 × 1024.

**`icon_leinen_los.png`** — Fähigkeit „Leinen los!“ (Pfeilhagel)
```
Game UI icon: three glowing golden arrows flying together in a steep arc with bright motion trails, bold and dynamic. Single object centered, filling most of the frame, thick clean outlines, simple shapes readable at very small size, cartoon style, vibrant colors. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no text, no watermark.
```
**`icon_rosehip_hail.png`** — Turmfähigkeit „Hagebuttenhagel“
```
Game UI icon: a burst of shiny glossy orange-red rosehips falling down like hail with small impact sparks. Single object group centered, filling most of the frame, thick clean outlines, simple shapes readable at very small size, cartoon style, vibrant colors. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no text, no watermark.
```
**`icon_heal.png`** — Christina heilen
```
Game UI icon: a fresh green leaf cradling a sparkling healing dew drop with a small white plus-shaped glint. Single object centered, filling most of the frame, thick clean outlines, simple shapes readable at very small size, cartoon style, vibrant colors. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no text, no watermark.
```
**`icon_petal.png`** — Blüten (Leben) in der oberen Leiste
```
Game UI icon: a single coral-pink dahlia petal, plump and glossy, slightly curved, with a tiny highlight. Single object centered, filling most of the frame, thick clean outlines, simple shape readable at very small size, cartoon style. Isolated on a plain flat solid cyan background (#00FFFF), no shadow on the background, no text, no watermark.
```
**`icon_resource.png`** — Ressource (⚙ Idee: Tautropfen, passt zur hellblauen Zahl)
```
Game UI icon: a single sparkling light-blue dew drop with a bright white highlight and a tiny star glint. Single object centered, filling most of the frame, thick clean outlines, simple shape readable at very small size, cartoon style. Isolated on a plain flat solid magenta background (#FF00FF), no shadow on the background, no text, no watermark.
```

### 4.7 App-Icon → `art_raw/app/`
**`app_icon.png`** — Icon für die .exe, das Fenster und den Android-Launcher. 1024 × 1024, **randlos mit Hintergrund**, kein Freistellen.
Android schneidet rund bzw. abgerundet zu, deshalb das Wichtige in die **mittleren 60 %**.
```
App icon, square, full-bleed: head and shoulders of a cheerful young woman with long dark blond hair in sage-green pajamas drawing a wooden bow, a big coral-pink dahlia blossom behind her, a cheeky cartoon snail with a tiny crown peeking in from the lower corner. All important content in the central area, bold simple shapes readable at small size, thick clean outlines, cartoon storybook style, vibrant colors on a deep night-blue background with a soft moon glow. No text, no letters, no border, no watermark.
```

### 4.8 Boden-Kacheln → `art_raw/tiles/` (optional, derzeit nicht genutzt)
Aus quadratischen, **nahtlosen Draufsicht-Texturen** baut `tools/art.sh` automatisch die Iso-Rauten
(128 × 64) samt blauen Christina-Feldern und weißen Bauplätzen. Pro Level gibt es drei Bilder:
`ground` (Fläche), `path` (Schneckenweg) und `blocked` (unbegehbar, optional, sonst abgedunkelter Boden).
1024 × 1024. **Nahtlos:** in ComfyUI einen Seamless-/Tiling-Node verwenden (z. B. „Seamless Tile“ bzw.
Circular-Padding am Modell). Ohne Node funktioniert es auch, die Kachelgrenzen sieht man dann etwas.
Die Texturen bleiben **ruhig und gleichmäßig**: keine Objekte, keine Schatten, keine Perspektive.

| Datei | Prompt |
|---|---|
| `tile_l1_ground.png` | `Seamless tileable texture, flat top-down view of a white painted wooden windowsill surface, soft brush strokes, subtle wood grain, slightly worn paint, cool blue moonlit tint, cartoon hand-painted game texture, even flat lighting, no objects, no shadows, no perspective, no text.` |
| `tile_l1_path.png` | `Seamless tileable texture, flat top-down view of light painted wood covered by a glistening silvery-green snail slime trail, glossy wet highlights, cartoon hand-painted game texture, even flat lighting, no objects, no perspective, no text.` |
| `tile_l1_blocked.png` | `Seamless tileable texture, flat top-down view of dark rich potting soil with small pebbles and tiny moss patches, cartoon hand-painted game texture, even flat lighting, no objects, no perspective, no text.` |
| `tile_l2_ground.png` | `Seamless tileable texture, flat top-down view of a soft fluffy wool rug with a cozy deep red and cream folk pattern, visible soft pile, cool moonlit tint, cartoon hand-painted game texture, even flat lighting, no objects, no perspective, no text.` |
| `tile_l2_path.png` | `Seamless tileable texture, flat top-down view of flattened worn beige carpet with a faint glossy snail slime trail, cartoon hand-painted game texture, even flat lighting, no objects, no perspective, no text.` |
| `tile_l2_blocked.png` | `Seamless tileable texture, flat top-down view of a pile of crumpled colorful knitted wool socks, cartoon hand-painted game texture, even flat lighting, no perspective, no text.` |
| `tile_l3_ground.png` | `Seamless tileable texture, flat top-down view of dark polished walnut wood with smooth grain, cool blue moonlit sheen, cartoon hand-painted game texture, even flat lighting, no objects, no perspective, no text.` |
| `tile_l3_path.png` | `Seamless tileable texture, flat top-down view of a white crocheted lace doily pattern, delicate cotton threads, cartoon hand-painted game texture, even flat lighting, no objects, no perspective, no text.` |
| `tile_l3_blocked.png` | `Seamless tileable texture, flat top-down view of a closed dark green leather book cover with gold embossed ornaments, cartoon hand-painted game texture, even flat lighting, no perspective, no text.` |

---

## 5. Abhakliste
Empfohlene Reihenfolge, jede Stufe macht das Spiel sichtbar schöner:

**A – Pflicht, Spielfeld (17)**
- [x] `gar_christina` · [x] `gar_rose`
- [x] `sna_slug` · [x] `sna_garden_snail` · [x] `sna_spitter` · [x] `sna_armored` · [x] `sna_queen`
- [x] `gar_rose_bush` · [x] `_2` · [x] `_3` — [x] `gar_rosehip` · [x] `_2` · [x] `_3`
- [x] `dahlia_0` · [x] `dahlia_1` · [x] `dahlia_2` · [x] `dahlia_3`

**B – Story (12)**
- [x] `gar_christina_portrait` · [x] `sna_queen_portrait` · [x] `mom`
- [x] `menu_bg` · [x] `bg_gar_intro` · [x] `bg_gar_intro_3` · [x] `bg_gar_l1_post` · [x] `bg_gar_l2_post`
- [x] `bg_gar_l3_pre` · [x] `bg_gar_finale` · [x] `bg_gar_finale_3` · [x] `credits_bg`

**C – Feinschliff (6)**
- [x] `icon_leinen_los` · [x] `icon_rosehip_hail` · [x] `icon_heal` · [x] `icon_petal` · [x] `icon_resource`
- [x] `app_icon`

**D – Boden (9, optional — verworfen, das Spiel nutzt das Platzhalter-Tileset)**
- [ ] `tile_l1_ground` · [ ] `tile_l1_path` · [ ] `tile_l1_blocked`
- [ ] `tile_l2_ground` · [ ] `tile_l2_path` · [ ] `tile_l2_blocked`
- [ ] `tile_l3_ground` · [ ] `tile_l3_path` · [ ] `tile_l3_blocked`

**E – Kampf-Hintergründe (3)**
- [x] `bg_battle_gar_l1` · [x] `bg_battle_gar_l2` · [x] `bg_battle_gar_l3`

Insgesamt 47 Bilder.

**Dialog-Hintergründe wechseln:** `bg_<dialog-id>` gilt ab Zeile 1, `bg_<dialog-id>_<n>` ab Zeile n.
Für weitere Wechsel einfach ein Bild mit Zeilennummer dazulegen, z. B. `bg_gar_l3_pre_3.png`.
Dialog-IDs: `gar_intro`, `gar_l1_post`, `gar_l2_post`, `gar_l3_pre`, `gar_finale`.

---

## 6. Probleme & Lösungen
| Problem | Lösung |
|---|---|
| Rosa/grüner **Saum** um die Figur | Flux hat den Hintergrund leicht verlaufen lassen. Neu generieren mit Betonung auf „plain flat solid … background“ oder im Editor-Dialog (Chroma Key) die Toleranz erhöhen. |
| **Löcher** in der Figur | Die Keyfarbe kommt im Motiv vor. Die andere Keyfarbe nehmen (Magenta ↔ Cyan). |
| Hintergrund **zwischen Bogen und Sehne / Ästen** bleibt stehen | Name (ohne Stufennummer) in `HOLES` in `tools/process_art.gd` eintragen – dann werden auch eingeschlossene Flächen freigestellt. Nicht global, sonst verschwinden rosa Lippen oder helle Augen. |
| **Bodenschatten** bleibt stehen | Flux malt gern einen Schatten unter die Figur. „no shadow, no ground“ steht schon drin; notfalls im Bildprogramm wegradieren. |
| Figur im Medaillon zu klein | Pose kompakter halten. Die Pipeline schneidet ohnehin auf den Inhalt zu. |
| Stufenbilder passen nicht zusammen | img2img mit niedrigerem Denoise (0,4) oder Inpainting nur auf den geänderten Bereich. |
| Kacheln mit sichtbaren Kanten | Seamless-Node verwenden. Oder `ground` ruhiger prompten („subtle, uniform“). |
| Bild ersetzt, aber Spiel zeigt das alte | `bash tools/art.sh --all` ausführen, danach im Editor einmal *Projekt → Neu laden*. |
