# Quellen und Lizenzen

Fremdes Material im Repo: die Tondateien (`assets/audio/`) und die 3D-Modelle, aus denen die Sprites gerendert werden (`tools/render/models/`, siehe unten). Alles steht unter CC0.

## Tondateien

Alle Geräusche und die Musik unter `assets/audio/` stammen aus fremden Quellen und stehen unter **CC0 1.0** (Public Domain Dedication, <https://creativecommons.org/publicdomain/zero/1.0/>). Eine Namensnennung ist deshalb nicht vorgeschrieben, wir geben die Urheber trotzdem an. Material unter CC-BY ist nicht dabei; eine Ansicht „Mitwirkende“ ist darum nicht nötig.

Die Lizenz ist für jede Datei auf der Quellseite geprüft (Stand 2026-10-05). Bei Freesound dient die HQ-Vorschau (MP3) als Vorlage, denn das Original gibt es nur mit Anmeldung. Die Lizenz gilt für jede Fassung.

**Bearbeitung bei allen Dateien:** in Ogg Vorbis umgewandelt (Qualität 4). Bei Geräuschen ist außerdem die Stille am Anfang entfernt, der leise Nachlauf gekürzt und kurz ausgeblendet. Der Pegel ist auf eine einheitliche Lautheit normalisiert, die ortsabhängigen Kampfgeräusche sind mono. In der Tabelle steht nur, was darüber hinaus geändert wurde.

### Geräusche (`assets/audio/sounds/<anlass>/`)

| Datei | Quelle | Urheber | Lizenz | Bearbeitung |
|---|---|---|---|---|
| `button/button_1–3.ogg` | Kenney „RPG Audio“: `bookPlace1–3.ogg` – <https://kenney.nl/assets/rpg-audio> | Kenney (kenney.nl) | CC0 | – |
| `building_placed/building_placed_1–4.ogg` | Kenney „Impact Sounds“: `impactPlank_medium_000–003.ogg` – <https://kenney.nl/assets/impact-sounds> | Kenney (kenney.nl) | CC0 | – |
| `demolish/demolish_1–3.ogg` | Kenney „RPG Audio“: `creak1–3.ogg` – <https://kenney.nl/assets/rpg-audio>; rubberduck „80 CC0 RPG SFX“: `wood_03.ogg`, `wood_05.ogg`, `wood_02.ogg` – <https://opengameart.org/content/80-cc0-rpg-sfx> | Kenney (kenney.nl); rubberduck | CC0 | je ein Knarren und ein Holzgeräusch übereinandergelegt (creak1+wood_03, creak2+wood_05, creak3+wood_02) |
| `command_rejected/command_rejected_1–4.ogg` | Kenney „Impact Sounds“: `impactSoft_heavy_000–003.ogg` – <https://kenney.nl/assets/impact-sounds> | Kenney (kenney.nl) | CC0 | – |
| `recruit/recruit_1–4.ogg` | artisticdude „RPG Sound Pack“: `battle/sword-unsheathe.wav`, `sword-unsheathe2–4.wav` – <https://opengameart.org/content/rpg-sound-pack> | artisticdude | CC0 | – |
| `trade/trade_1–3.ogg` | rubberduck „80 CC0 RPG SFX“: `item_coins_01–03.ogg` – <https://opengameart.org/content/80-cc0-rpg-sfx> | rubberduck | CC0 | – |
| `wave_announced/wave_announced_1.ogg` | „Battle_horn_1.wav“ – <https://freesound.org/people/kirmm/sounds/392180/> | kirmm | CC0 | – |
| `wave_announced/wave_announced_2.ogg` | „war horn.wav“ – <https://freesound.org/people/adharca/sounds/539956/> | adharca | CC0 | – |
| `wave_spawned/wave_spawned_1–3.ogg` | „Horde War Drums loop“ – <https://opengameart.org/content/horde-war-drums-loop> | William Hector | CC0 | je zwei Takte ausgeschnitten (Takte 1–2, 3–4, 5–6), am Ende ausgeblendet |
| `wave_repelled/wave_repelled_1.ogg` | „Trumpet Fanfare“ – <https://freesound.org/people/bevibeldesign/sounds/350428/> | bevibeldesign | CC0 | – |
| `wave_repelled/wave_repelled_2.ogg` | „Medieval: Victory Theme“ – <https://opengameart.org/content/medieval-victory-theme> | RandomMind | CC0 | erste Phrase (0–6,5 s), ausgeblendet |
| `defeat/defeat_1.ogg` | „Medieval: Defeat Theme“ – <https://opengameart.org/content/medieval-defeat-theme> | RandomMind | CC0 | Nachlauf gekürzt, Pegel wie die Musik |
| `sword_hit/sword_hit_1–4.ogg` | Still North Media „Medieval sound effects – Weapon impacts“, Archiv 1: `Sabre Norse Sword Blade on Blade.wav` (Schläge bei 12,46 s und 17,67 s), `Norse Sword Katana Blade on Blade.wav` (13,86 s und 5,62 s) – <https://opengameart.org/content/medieval-sound-effects-weapon-impacts> | Ben Jaszczak & Brian Nelson (Still North Media) | CC0 | einzelne Schläge ausgeschnitten, von 192 auf 48 kHz umgerechnet |
| `arrow_shot/arrow_shot_1–3.ogg` | „Bow Release (Bow and Arrow) 2–4“ – <https://freesound.org/people/Ali_6868/sounds/384916/>, <https://freesound.org/people/Ali_6868/sounds/384918/>, <https://freesound.org/people/Ali_6868/sounds/384917/> | Ali_6868 | CC0 | – |
| `arrow_shot/arrow_shot_4.ogg` | „Arrow Flying 2“ – <https://freesound.org/people/Ali_6868/sounds/384910/> | Ali_6868 | CC0 | – |
| `building_hit/building_hit_1–4.ogg` | Kenney „Impact Sounds“: `impactWood_heavy_000–003.ogg` – <https://kenney.nl/assets/impact-sounds> | Kenney (kenney.nl) | CC0 | – |
| `fighter_died/fighter_died_1–4.ogg` | „Voice_AdultMale_PainGrunts_01/02/05/08.wav“ – <https://freesound.org/people/MrFossy/sounds/547203/>, <https://freesound.org/people/MrFossy/sounds/547202/>, <https://freesound.org/people/MrFossy/sounds/547207/>, <https://freesound.org/people/MrFossy/sounds/547204/> | MrFossy | CC0 | – |
| `building_destroyed/building_destroyed_1.ogg` | „R29-04-Crashing Collapse of Wood Building.wav“ – <https://freesound.org/people/craigsmith/sounds/487142/> | craigsmith | CC0 | – |
| `building_destroyed/building_destroyed_2.ogg` | „Fall debris (crash)“ – <https://freesound.org/people/xkeril/sounds/703248/> | xkeril | CC0 | – |
| `building_destroyed/building_destroyed_3.ogg` | „Big falling debris (crash)“ – <https://freesound.org/people/xkeril/sounds/703247/> | xkeril | CC0 | – |

### Musik (`assets/audio/music/<rolle>/`)

Alle Musikstücke sind von RandomMind (<https://opengameart.org/users/randommind>), Lizenz CC0. Jedes Stück lässt sich nahtlos in Schleife abspielen; bei geschnittenen Schleifen springt die Wiedergabe an den Einsprungpunkt `loop_offset` (in der `.import`-Datei), nicht an den Anfang. Der Pegel aller Stücke ist gleich normalisiert.

| Datei | Quelle | Bearbeitung |
|---|---|---|
| `menu/exploration.ogg` | „Medieval: Exploration“ (`Exploration.wav`) – <https://opengameart.org/content/medieval-exploration> | Stille am Anfang entfernt; Schleife selbst geschnitten: Ende nach der Wiederholung des Mittelteils, 2 s Überblendung zurück zum Einsprungpunkt, Schluss weggelassen |
| `peaceful/bards_tale.ogg` | „Medieval: The Bard's Tale“ (`Loop_The_Bards_Tale.wav`) – <https://opengameart.org/content/medieval-the-bards-tale> | Loop-Fassung des Urhebers |
| `peaceful/minstrel_dance.ogg` | „Medieval: Minstrel Dance“ (`Loop_Minstrel_Dance_0.wav`) – <https://opengameart.org/content/medieval-minstrel-dance> | Loop-Fassung des Urhebers |
| `peaceful/market_day.ogg` | „Medieval: Market Day“ (`Loop_Market_Day.wav`) – <https://opengameart.org/content/medieval-market-day> | Loop-Fassung des Urhebers; die Naht knackte und ist mit 10 ms überblendet |
| `peaceful/rejoicing.ogg` | „Medieval: Rejoicing“ (`Loop_Rejoicing.wav`) – <https://opengameart.org/content/medieval-rejoicing> | Loop-Fassung des Urhebers |
| `peaceful/harvest_season.ogg` | „Medieval: Harvest Season“ (`harvestseason.wav`) – <https://opengameart.org/content/medieval-harvest-season> | Stille am Anfang entfernt; Schleife selbst geschnitten (2 s Überblendung zum Einsprungpunkt), Schluss weggelassen |
| `battle/battle.ogg` | „Medieval: Battle“ (`battle_1.wav`) – <https://opengameart.org/content/medieval-battle> | Schleife selbst geschnitten (1,5 s Überblendung zum Einsprungpunkt), Ausklang weggelassen |

## 3D-Modelle (`tools/render/models/`)

Die Sprites unter `assets/sprites/` rendert `tools/render.sh` selbst aus diesen Modellen (ADR 0006); dabei werden sie auf die Palette `tools/render/palette.json` umgefärbt und nach den Rezepten in `tools/render/recipes/` zusammengesetzt, gedreht und gestreckt. Die gerenderten Bilder sind eigene Arbeit auf Grundlage dieser Modelle. Die Lizenz ist auf der Quellseite und in der Lizenzdatei des Pakets geprüft (Stand 2026-10-05); diese liegt jeweils mit im Ordner.

| Ordner | Quelle | Urheber | Lizenz | Dateien |
|---|---|---|---|---|
| `kenney-fantasy-town/` | Kenney „Fantasy Town Kit“ 2.0 (GLB-Fassung) – <https://kenney.nl/assets/fantasy-town-kit> | Kenney (kenney.nl) | CC0 | `wall.glb`, `wall-door.glb`, `wall-window-shutters.glb`, `roof-high-gable.glb`, `roof-high-gable-end.glb`, dazu die gemeinsame Farbtextur `Textures/colormap.png` und `License.txt`; unverändert |
| `kenney-nature/` | Kenney „Nature Kit“ 2.1 (GLB-Fassung) – <https://kenney.nl/assets/nature-kit> | Kenney (kenney.nl) | CC0 | `tree_default.glb`, `tree_detailed.glb`, `tree_pineRoundA.glb`, `tree_pineRoundB.glb`, `ground_grass.glb`, `stone_largeA.glb` bis `stone_largeD.glb` und `License.txt`; unverändert, die Bäume enthalten ihre Materialien ohne externe Texturen; das Geländemodell wird flach auf eine Kachel normiert; fünf Gelände mit je vier Varianten, transparenten Kanten-/Eckübergängen und statischem Wasser mit Ufersaum nutzen die gemeinsame Palette. Die Frontgrenzen werden zur Erdkante extrudiert; Rezepte und Materialtexturen: Burgwacht |


### Bewohner – KayKit Adventurers Character Pack 1.0

- Modell: `tools/render/models/kaykit-adventurers/Rogue.glb`, ohne Waffen und Umhang;
  die originalen Skelettanimationen `Idle` und `Walking_A` werden in acht Richtungen gerendert.
- Urheber: Kay Lousberg / KayKit
- Quelle: https://kaylousberg.itch.io/kaykit-adventurers
- Lizenz: CC0, beigefügt als `tools/render/models/kaykit-adventurers/LICENSE.txt`
- Umfärbung auf die gemeinsame Palette und Renderrezept: Burgwacht.

### Soldaten und Pfeile (#146)

- **KayKit Adventurers Character Pack 1.0** – Kay Lousberg, CC0,
  <https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0>.
  `Knight.glb` ist der unveränderte Schwertkämpfer mit Helm, Rundschild und Einhandschwert;
  der bereits verwendete `Rogue.glb` bildet den Bogenschützen mit den freigegebenen Proportionen.
  `quiver.glb`, `arrow_bundle.glb` und `arrow.glb` sind verlustfrei in binäres glTF
  exportierte Originalmodelle aus demselben Satz. Lizenz: `tools/render/models/kaykit-adventurers/LICENSE.txt`.
- **Langbogen** – eigene Low-Poly-Modellierung für Burgwacht; Quelle
  `tools/render/models/burgwacht/bow.blend`, reproduzierbar mit `tools/render/model_bow.py`.
  Die Bogenhaltung retargetet ausschließlich Armstellungen und verändert Kopf und Körper nicht.
  Holz, Griff und Sehne nutzen exportierbare Knotenmaterialien; die Farben bleiben beim
  erneuten Erzeugen des GLB erhalten.

### Burggebäude (#141)

- **Kenney – Fantasy Town Kit 2.0**, CC0: Holzfassaden, Schindeldach, Marktstände und Banner aus [kenney.nl/assets/fantasy-town-kit](https://kenney.nl/assets/fantasy-town-kit). Ausgewählte Modelle unter `tools/render/models/kenney-fantasy-town/`, Lizenz dort.
- **Kenney – Castle Kit 2.0**, CC0: Bergfried aus quadratischem Sockel, Fenstergeschoss und Zinnen, [kenney.nl/assets/castle-kit](https://kenney.nl/assets/castle-kit). Modelle und Lizenz unter `tools/render/models/kenney-castle/`.
- **Kenney – Survival Kit 2.0**, CC0: Kisten, Fässer, Holz-/Steinstapel, Arbeitstisch und Axt, [kenney.nl/assets/survival-kit](https://kenney.nl/assets/survival-kit). Modelle und Lizenz unter `tools/render/models/kenney-survival/`.
- **Kenney – Nature Kit 2.1**, CC0: Lagerfeuer-Steinkreis und Holzscheite, [kenney.nl/assets/nature-kit](https://kenney.nl/assets/nature-kit). Modelle und Lizenz unter `tools/render/models/kenney-nature/`.
- **Kay Lousberg – KayKit Medieval Hexagon Pack 1.0**, CC0: Waffengestell und Säcke, [Originalrepository](https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0). Modelle, Textur und Lizenz unter `tools/render/models/kaykit-medieval/`.
- **Burgwacht**: eigene Low-Poly-Flammen, modellierte Quelldatei `tools/render/models/burgwacht/campfire-flame.blend`, vier exportierte glTF-Posen. Keine fremden Modelle für die Flamme.


### Weitere Vorkommen

| Ordner | Quelle | Urheber | Lizenz | Dateien |
|---|---|---|---|---|
| `quaternius-animals/` | Quaternius „Ultimate Animated Animal Pack“ (Juli 2021) – <https://quaternius.com/packs/ultimateanimatedanimals.html> | Quaternius | CC0 | `Deer.glb`, `Stag.glb`, mit Blender 5.2 aus den glTF-Dateien des Originaldownloads exportiert; Herkunft und Lizenzangabe in `SOURCE.txt`. Vier feste Ausrichtungen als Wild-Vorkommen, ohne Bewegung in der Spielwelt |
| `burgwacht/iron.blend`, `burgwacht/iron.glb` | Eigenes Low-Poly-Modell | Burgwacht | Projektlizenz | Dunkles Gestein mit erhabenen rostfarbenen Eisenadern; Blender-Quelldatei und GLB-Export, vier Ausrichtungen |

### Arbeitsstätten (#142)

- **Kenney – Fantasy Town Kit 2.0**, CC0: Fassaden und Dächer wie beim freigegebenen Wohnhaus; zusätzlich Mühlenflügel (`windmill.glb`), Schornstein und Karren. Quelle und Lizenz: [kenney.nl/assets/fantasy-town-kit](https://kenney.nl/assets/fantasy-town-kit), `tools/render/models/kenney-fantasy-town/License.txt`.
- **Kenney – Nature Kit 2.1**, CC0: Holzstapel, Zelt, kleine Obstbäume, Weizenähren, Ackerreihen und Fels am Grubeneingang. Quelle und Lizenz: [kenney.nl/assets/nature-kit](https://kenney.nl/assets/nature-kit), `tools/render/models/kenney-nature/License.txt`.
- **Kenney – Survival Kit 2.0**, CC0: Arbeitstische, Amboss, Axt, Spitzhacke, Hammer, Holz, Stein und offene Kiste. Quelle und Lizenz: [kenney.nl/assets/survival-kit](https://kenney.nl/assets/survival-kit), `tools/render/models/kenney-survival/License.txt`.
- **Kenney – Food Kit 2.0**, CC0: Äpfel, Brot und Fleisch. Quelle und Lizenz: [kenney.nl/assets/food-kit](https://kenney.nl/assets/food-kit), `tools/render/models/kenney-food/License.txt`. Nur die drei verwendeten Modelle und ihre gemeinsame Textur `Textures/colormap.png` liegen im Repo.
- **Kay Lousberg – KayKit Medieval Hexagon Pack 1.0**, CC0: die bereits verwendeten Säcke für Mehl und Weizen. Quelle und Lizenz stehen oben bei den Burggebäuden.
- **Burgwacht**: Backofen, Esse, Holzrahmen des Grubeneingangs, Sägebock und Bogengestell sind eigene Low-Poly-Modelle. Die bearbeitbare Quelle `tools/render/models/burgwacht/trade-fixtures.blend` und das Erzeugungsskript `create_trade_fixtures.py` bleiben erhalten. Der Bogen im Bogengestell sowie bei Jäger und Bogner ist das oben dokumentierte eigene Modell `bow.blend`.
- **Kenney – Castle Kit 2.0**, CC0: Mittelpfeiler, modulare Mauerarme, Tor mit offenem Durchgang,
  Steintreppe und Turmsockel mit Ecktürmchen. [kenney.nl/assets/castle-kit](https://kenney.nl/assets/castle-kit).
  Ausgewählte Modelle und Lizenz unter `tools/render/models/kenney-castle/`; Richtungsrezepte unter
  `tools/render/recipes/buildings/`.

### Feinde (#147)

- **KayKit Adventurers Character Pack 1.0** – Kay Lousberg, CC0,
  <https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0>.
  `Rogue_Hooded.glb` ist das unveränderte Kapuzenmodell für Räuber und Wilderer;
  Lizenz unter `tools/render/models/kaykit-adventurers/LICENSE.txt`. Originale
  Steh-, Geh- und Nahkampfanimationen; Kleiderfarben unmittelbar aus `units.json`.
  Der Wilderer nutzt den eigenen Langbogen und den KayKit-Köcher samt Pfeilen aus #146.
- **Knüppel** – eigene Low-Poly-Modellierung für Burgwacht; Quelle
  `tools/render/models/burgwacht/club.blend`, reproduzierbar mit `tools/render/model_club.py`.




Arbeitswerkzeuge und Warenbündel: Kenney Survival Kit (`tool-axe`, `tool-pickaxe`, `resource-wood`, `resource-stone`), Nature Kit (`crops_wheatStageB`) und Food Kit (`apple`, `meat-raw`, `bread`), jeweils CC0; KayKit Medieval Hexagon Pack (`sack`) und Adventurers Character Pack 1.0 (`sword_1handed`), Kay Lousberg, CC0. Quellen und Lizenzen liegen bei den bereits verwendeten Modellen unter `tools/render/models/`. Das Bogenbündel verwendet den eigenen Bogen aus `burgwacht/bow.blend`. Werkzeuge folgen der unveränderten Rogue-Animation `1H_Melee_Attack_Chop`; die Warenrezepte liegen unter `tools/render/recipes/goods/`.
