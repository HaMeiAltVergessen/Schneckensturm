# Story — Dialog-Ledger

Die Texte stehen in `localization/text.csv` (Spalte `de`; `en` ist nur eine Kopie). Zum Ändern:
Zeile im CSV anpassen, Projekt einmal importieren (`--headless --import` oder Editor öffnen) – fertig.
Platzhalter beginnen mit `[PH]`. Dialoge selbst (`data/dialogs/*.tres`) legen nur Sprecher und
Reihenfolge fest.

## Rahmen
Christina bekommt zum Geburtstag von ihrer Mama eine Dahlie – „schütz sie vor den Schnecken!“.
Nachts wacht sie auf Spielzeuggröße geschrumpft auf; die Schneckenkönigin führt ihre Armee ins
Zimmer, um die Dahlie zu fressen. Ton: humorvoll-liebevoll. Mama nur am Anfang und Ende.

## Ablauf
| Wann | Dialog | Keys | Inhalt |
|---|---|---|---|
| vor Level 1 „Das Fensterbrett“ | `gar_intro` | `DIALOG_GAR_INTRO_1..6` | Geschenk, Schrumpfen, Königin kündigt den Mitternachtssnack an |
| nach Level 1 | `gar_l1_post` | `DIALOG_GAR_L1_POST_1..3` | Erster Sieg, Königin droht mit der Armee auf dem Teppich |
| nach Level 2 „Das Teppich-Labyrinth“ | `gar_l2_post` | `DIALOG_GAR_L2_POST_1..3` | Königin will die Dahlie selbst holen – auf zum Nachttisch |
| vor Level 3 „Der Nachttisch“ | `gar_l3_pre` | `DIALOG_GAR_L3_PRE_1..3` | Showdown im Mondlicht, Ankündigung „Leinen los“ |
| nach Level 3 | `gar_finale` | `DIALOG_GAR_FINALE_1..5` | Königin besiegt, Morgen, Mama fragt nach der Dahlie |
| danach | Abspann | `CREDITS_TITLE`, `CREDITS_LINE_1..4` | Geburtstagsgruß |

Sprecher-Keys: `DIALOG_SPEAKER_NARRATOR` (Erzähler), `DIALOG_SPEAKER_MOM` (Mama),
`HERO_GAR_CHRISTINA_NAME`, `UNIT_SNA_QUEEN_NAME`.

## 🧑 Offen
- **Geburtstagsgruß** für `CREDITS_LINE_2..4` (aktuell `[PH]`).
- Insider/Anspielungen nach Wunsch in die Dialogzeilen einbauen.
- ~~Womit schießt Christina?~~ Entschieden: Pfeil und Bogen, unendlich viele Pfeile.
