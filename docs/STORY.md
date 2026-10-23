# PREVIOUS OWNER: SpeedFest Stadium's story mode

The story bible (PLAN M20-1). The owner picked premise A of `docs/STORY_PITCH.md` (session 21) and
asked for horror in how the cutscenes are delivered, a student at the auction, and night 1 first
as a playable slice. Everything here is new; nothing comes from the rejected "Rear View".

Status: **draft for the owner's review.** Night 1's full dialogue is in its scene files
(`stadium/story/scenes/`); the other nights are written to the beat here, and their dialogue
follows in batches once the slice has been played.

---

## 1. The story in one paragraph

Kit Arlen, 20, a second-year engineering student who delivers noodles at night, needs a car and
has 900 to spend. At the night auction on the docks, a black coupe goes for 900 because the top bid
is withdrawn at the last second. By the next night the whole city recognises it. It is **Vesper's
car**: the street legend's white coupe that went off the Halloran toll bridge eight years ago and
was pulled out of the river empty. It came with its old satnav still bolted in: nine unmarked
violet pins on the city map, no route between them, and the bridge greyed out, ROAD CLOSED. Each
night Kit drives to one pin and learns one hard fact about what happened on the bridge. And each
night, when Kit finally sleeps, there is someone in the back seat.

**The question all ten nights ask:** who was Vesper, and what happened on the Halloran Bridge?

---

## 2. How it plays (the rules)

- **Ten nights.** Night 1, THE YARD, is always first (the auction). The other eight come in
  whatever order the finishes send you; the tenth, THE BRIDGE, is the finale.
- **Three maps a night**, all on the City at night (`"scenery": "city"`, `"mood": "night"`,
  tracks H01-H30). Each map is a **7-minute time attack** (the owner's rule): restart as often as you
  like, and when the 7 minutes are up your best run counts. It must beat the time to beat to move
  on. The clock runs only while you are on the track; a run under way when time is up may finish.
- **The third map has four finishes** (three on a few nights). The finish of your best run is the
  night's **decision**, and it must beat that finish's own time to beat. The cruel choice is always
  the fastest, most dangerous line, so the stopwatch pulls you towards it: to choose otherwise you
  must keep your best run off it (or start the 7 minutes again).
- **Where the decision leads**: every finish line faces a different satnav pin, and the satnav
  recalculates as you cross it, so the decision also picks the next night. If you have already
  driven that pin, the satnav routes to the next unseen one in that direction; when every pin a map
  faces is driven, you pick from the satnav board.
- **The finale** (THE BRIDGE) lights up after **7** of the nine pins (ROAD CLOSED turns to ROUTE
  FOUND); it is offered beside the next night, so you may drive the last pins first.
- **Difficulty**, chosen with the save and changeable between nights: Cruise (bot's author time
  x1.30), Street (x1.18), Racer (x1.08), Author (x1.00).
- **The car**: Vesper's coupe, all story long (the Nemesis GT in Black Ops livery, violet
  underglow). It is the story's main character, and one car keeps the times fair. No car is won
  mid-story; the VESPER ending's car is an epilogue.
- **Endings**: three, plus a secret one (section 9). Your session-11 beats (beat the last rival,
  push them off, they crash, you walk up and take their car) are the VESPER ending.

---

## 3. The frame: Vesper's satnav

- **The satnav is the chapter board.** A violet pin turns red when its fact is learned; the lines
  you drove trace over the city in white; the bridge sits greyed out until ROUTE FOUND. The Story
  page shows it as a map (the board), and every night opens on it.
- **Arch 9** is Dee's workshop under the railway viaduct: one bare bulb, a pit, the trains every four
  minutes shaking dust off the roof. Every night opens here: Dee plugs the satnav into her laptop and
  reads back what Kit has found, in Kit's own order ("Four pins red. The yard, the roof, the lock,
  the market..."). That reading is how the game narrates the player's progress back.
- Dee's line for why the pins have no order: "Vesper never drove anywhere the same way twice."
- On every third map, each finish faces a pin: the satnav's voice says "Recalculating" as you
  cross a line, and the screen swings to the next pin.

---

## 4. The horror layer: THE PASSENGER

The owner's idea, at the centre of how the story is told: **nightmares in the car**, and small
uncanny things around it in the waking world. Two rules keep it fair:

1. **Every scare has a waking-world explanation, revealed in the finale.** Nothing supernatural is
   true. A player who replays sees each scare differently (a decision never changes what you saw,
   only what it meant: the same goes for the scares).
2. **The nightmares are built from what Kit knows.** Their content is chosen by the knowledge flags,
   like the dialogue tiers, so they get closer to the truth as Kit does, in any order.

### The nightmare (THE MIRROR), the owner's scene

Kit drives the bridge in rain. In the dream the bridge is open, lit, and has no end. Kit looks at
the rear-view mirror: headlights, far back. Ahead: the wipers, the road. The mirror: closer. A white
coupe, violet light under it. Ahead. The mirror: closer still, the headlights filling it. Ahead:
nothing. Then the mirror once more, and **someone is sitting in the back seat**: a woman, soaked,
hair over her face, water running off her onto the seat. Hard cut to black. A breath. Kit wakes.

It plays as the closing scene of five nights (the Yard always, then four others), each time in a
different form, picked by what Kit knows (scene variants, `story/scenes/nightmare_*.json`):

| Kit knows | The passenger |
|---|---|
| nothing yet (cold) | a drowned shape, water to the ankles; she says nothing |
| Vesper raced someone every night (the Roof) | she whispers "faster" as the headlights close in |
| Vesper lived (the Lock) | **dry**: a mechanic's jacket, no water; she says "you're getting warmer" |
| Vesper was Ines (the Hill) | she hums a song (the one Dee hums at Arch 9, which is in Moth's oldest footage) |
| someone chose Kit (the Market) | she leans forward and taps a pin on the satnav: the bridge |

Kit wakes somewhere different each time (the car at Arch 9 with Dee knocking on the glass; a lecture
theatre at 9 a.m.; the night bus; the car outside Lucky Eight with the engine still running), so it
is a complete scene in any night.

### Uncanny things in the waking world, and what they really were

| What Kit sees | Innocent reading at the time | The truth (finale) |
|---|---|---|
| The driver's seat is two notches forward and the mirrors low after the car spends a night at Arch 9 | Dee rolls it round the arch to work on it | Dee drives her own car at night |
| The back seat is damp and there are handprints inside the rear window | rain through a bad seal | Dee sleeps in the back of her car some nights, as Ines did as a girl to get away from her family |
| The satnav wakes on its own at 03:12 and says "Recalculating" | a fault in an old unit | a timer Dee set: 03:12, the bridge |
| The radio tunes itself to an old song | a stuck preset | Dee's preset, Vesper's song |
| A white coupe in the mirror on empty roads, then gone | the ghost car Moth's channel talks about | Halloran security, who drive white coupes and tail the car every night |
| A call at 3 a.m.: only rain and breathing | a wrong number | Dee, checking Kit made it home |
| A figure at the far end of the arch, under the viaduct, at dawn | a rough sleeper | Dee, coming back from the car |

The finale pays it off on screen: when Kit arrives at the bridge, **someone is sitting in the back
seat for real**, and it is Dee.

---

## 5. Cast

People are staged in full body and in silhouette (no faces until the modelled cast; the owner wants
a modelled cast with the best graphics in the end). Each has a shape you can tell at a distance.

| Who | Role | Car | Silhouette | Wants |
|---|---|---|---|---|
| **Kit Arlen** | 20, engineering student, noodle-delivery driver, the player | Vesper's black coupe (Nemesis GT, Black Ops, violet underglow) | hooded jacket, backpack | a car; then the truth before someone takes the car back |
| **Dee Sandoval** | the night mechanic at Arch 9, Kit's friend; reads the satnav | none: never sits in a driver's seat ("lost my licence, long story") | short, hair in a bun, overalls, a welding mask pushed up | says: Kit wins and keeps the car. Really: her brother to see her car every night until he breaks |
| **Cass Halloran** | heir to Halloran Holdings, the toll-road family; king of the night runs | silver hypercar | tall, long coat, always lit from behind | the bridge demolished, the coupe off the streets, "Vesper" beaten in public |
| **Edgar Halloran** | Cass's father, who built the city's toll roads | long black V12 grand tourer with a driver, tinted glass | never seen outside his car | the family name intact, at any price |
| **Sgt. Lena Voss** | traffic sergeant, first at the bridge, taken off the case in 36 hours | unmarked white compact with grille strobes | uniform coat, torch | the file reopened and her career to survive it; the red herring (a woman who knows the bridge too well) |
| **Moth** | 19, runs the Friday roof meets and the channel WHERE IS VESPER | lime three-door hot hatch, mismatched panels | thin, phone always up, filming | to race Vesper's car and be somebody |
| **Gus Pell** | owns the salvage docks, runs the night auction; winched the white car out of the river | rust-brown rally saloon | big, hi-vis vest | to be paid twice for everything |
| **Pim** | owns Lucky Eight, a 24-hour noodle bar under the elevated railway; has held an envelope for eight years | none | old, small, behind the steamed glass | to hand the envelope over and stop being afraid |

Minor: Tibor (Gus's runner), Ambrose Kell (lock-keeper), the Ferro night foreman, Ozzie (satnav
cracker at the night market), Edgar's driver, Halloran security in white coupes.

---

## 6. The fact table

Every fact is a record or a witness of one night eight years ago, so any order adds up to the same
picture and nothing contradicts. Each night sets one `fact_*` flag; tiers count them (section 10).

| # | Night | Fact (flag) | Needs |
|---|---|---|---|
| 1 | THE YARD | the chassis stamp under the black paint is the white coupe from the river: this is Vesper's car (`fact_chassis`) | none |
| 2 | THE ROOF | Vesper raced one driver only, Cass Halloran: 31 times, on the bridge at 3 a.m., never for money, never a loss (`fact_rival`) | none |
| 3 | THE PLAZA | at 03:12 two cars went through Lane 3 nose to tail; the barrier was raised for the second from the Halloran control room; the second car was silver (`fact_barrier`) | none |
| 4 | THE BODY SHOP | next morning Cass's silver saloon came in crushed front-left with white paint in the dent; paid in cash, no record (`fact_dent`) | none |
| 5 | THE NOODLE STRIP | Vesper's last bet slip: "If I win, I take the keys of Halloran Holdings. If I lose, I leave the city. Witnessed, E.H." (`fact_bet`) | none |
| 6 | THE LOCK | at 03:40 a soaked woman climbed the lock ladder, used the keeper's phone and walked off up the towpath: Vesper lived (`fact_alive`) | none |
| 7 | THE HILL | Edgar's daughter Ines "died abroad" that week; her drawer is empty but for a photo: her back, a white coupe, violet underglow. Vesper was Ines Halloran (`fact_ines`) | none |
| 8 | THE PATROL | the bridge rail was hit from the left at about 190 km/h: a ram, not a crash; the case closed 36 hours after Edgar phoned the commissioner (`fact_ram`) | none |
| 9 | THE MARKET | the satnav was built two years after the bridge; its pins were loaded five weeks ago; the top bid at the auction was withdrawn so the car fell to Kit. Someone chose Kit (`fact_chosen`) | none |
| 10 | THE BRIDGE | Dee is Vesper (the finale) | 7 of the nine |

---

## 7. The nights

Each night: an **opening** at Arch 9 (or where the night starts), **map 1**, a scene, **map 2**, a
scene, **map 3** (the decision), the **decision's scene** (one variant per finish), and a **closing**
scene (the nightmare on five nights). Scenes run 20-40 lines; each has cold, warm and hot variants
where what Kit knows changes them. Every night has its own local goal, so it satisfies as a first
night after the Yard, and its one fact, so it is a step even as the eighth.

Gates are listed as finish lines on map 3; "cold" marks the fastest line. **To** is where the
satnav recalculates (the next night, or the next unseen pin in that direction).

### Night 1: THE YARD (always first) — the slice

*Gus Pell's salvage docks under the container cranes; wrecks stacked five high; the river black
beyond the fence.*

- **Local goal:** Gus calls the sale a mistake (a Halloran buyer offered triple) and sends his
  runner Tibor in the rust-brown rally saloon to take the coupe back. Beat Tibor out through the
  container canyons and come back for the car's recovery file in Gus's cabin.
- **Maps:** H01 *Lot 47* (out of the auction yard and round the quay; Kit's first drive in the car,
  ~25 s), H02 *Container Canyon* (between the stacks, Tibor's ghost to beat, ~30 s), H03 *Crane Hook*
  (back to the cabin and out; four finishes, ~35 s).
- **Scenes:**
  - `prologue` (before the auction, once per save): CCTV at the toll plaza, eight years ago, 03:12,
    rain: two pairs of headlights, one with violet under it, the barrier lifting, fog, static. A
    radio newsreader: the car pulled from the river, the driver not found. Title card.
  - `c01_open` *The Auction*: floodlights, rain, a crane lowering wrecks off a barge; Kit (hood,
    backpack) with 900 in an envelope; Gus selling by megaphone; Lot 47, a black coupe, a bid at 2,000
    from a man in a long coat... withdrawn as the hammer falls; Kit's 900 wins it. Dee on the phone
    ("Is it ugly? Ugly's cheap."). Kit turns the key and the satnav boots on its own: nine violet pins.
  - `c01_after1` *Triple*: Gus on the quay with a phone to his ear: a Halloran buyer offers triple;
    "Sale's off, kid." Kit refuses; Tibor's rally saloon rolls out between the stacks.
  - `c01_after2` *The File*: Kit has lost Tibor; Gus, grudging, tells Kit the coupe came out of the
    river eight years ago, white, and that the recovery file is in his cabin. "Everyone in this town
    knows that car. You just don't know it yet."
  - `c01_decision`: the gates' consequences (below).
  - `c01_close` *Nightmare: The Mirror* (cold): Kit drives home at dawn, falls asleep in the car at
    Arch 9; the owner's mirror sequence; Kit wakes to Dee knocking on the glass: "You slept in it."
    Dee looks at the satnav for a long moment: "Huh. Nine pins."
- **Fact:** the chassis stamp under the black paint matches the white coupe pulled out of the river
  eight years ago. You are driving Vesper's car.
- **Gates (H03):** (0) pay Gus the difference out of your savings (the wide, safe line) → THE ROOF;
  (1) get Gus to feed the Halloran buyer a false chassis number → THE BODY SHOP; (2) hand the recovery
  file to Sgt. Voss, who is waiting at the dock gate → THE PATROL; (3, cold) sell Gus the name of the
  arch that rebuilt the car, Dee's, so he can sell it on to the Hallorans (the fastest line, under the
  swinging crane hook) → THE LOCK.
- **Flags:** (0) `paid_gus`; (1) `lied_chassis`; (2) `voss_c01`; (3) `dark_c01`, `dee_minus_c01`.

### Night 2: THE ROOF

*The 14th-floor deck of the car park over the electronics night market, where Moth runs Friday meets
and films for his channel.*

- **Local goal:** nobody runs violet on Moth's roof. Beat Moth, then his best time, then the roof
  record, in front of his crowd.
- **Maps:** H04 *Fourteen Floors* (down the spiral ramps), H05 *Moth's Line* (against Moth's ghost),
  H06 *Roof Record* (four finishes).
- **Scenes:** `c02_open` (Arch 9: Dee reads the board; a white coupe in Kit's mirror on the way, then
  gone); `c02_after1` *Phones Up* (the crowd in silhouette, phones up, Moth recognises the car and
  goes pale); `c02_after2` *The Archive* (Moth's laptop on a car bonnet: eight years of footage);
  `c02_decision`; `c02_close` (Moth's channel goes live in the rain, or doesn't).
- **Fact:** Moth's archive shows Vesper raced one driver only, Cass Halloran: 31 times, on the bridge
  at 3 a.m., never for money, never a loss.
- **Gates (H06):** (0) let Moth post "Vesper is back" (the whole city, and Cass, will see the car) →
  THE PLAZA; (1) make him delete it and tell him you're nobody (it kills the legend and breaks the
  kid) → THE NOODLE STRIP; (2) bring Moth in as your eyes on the street → THE LOCK; (3, cold) take his
  archive drive and leave him nothing (the stairwell-spiral jump, fastest) → THE MARKET.
- **Flags:** (0) `moth_posted`; (1) `moth_broken`; (2) `moth_ally`; (3) `dark_c02`.

### Night 3: THE PLAZA

*The closed Halloran toll plaza: boarded booths, floodlights, the fenced bridge rising into fog,
Halloran security patrolling in white coupes.*

- **Local goal:** Booth 3's last ticket roll is still in its drum. Get in, get it, get out past the
  patrol.
- **Maps:** H07 *Lane 3* (through the booths), H08 *Patrol* (the security coupes' loop), H09 *The
  Barrier* (four finishes).
- **Scenes:** `c03_open` (Arch 9; the satnav wakes on its own at 03:12 and says "Recalculating");
  `c03_after1` *Booth 3* (Kit on foot in the dark booth, a torch, the drum); `c03_after2` *The Strip*
  (the ticket roll unrolled across the coupe's bonnet under the floodlights); `c03_decision`;
  `c03_close`.
- **Fact:** at 03:12 on the bridge's last night two cars went through Lane 3 nose to tail; the
  barrier was raised for the second from the Halloran control room; the camera strip shows it was
  silver.
- **Gates (H09):** (0) leave the roll and tip off Voss so it is found legally → THE BODY SHOP;
  (1) take it to Dee → THE HILL; (2) burn the booth so nobody has it → THE MARKET; (3, cold) sell it
  back to Halloran security for cash (straight through the barrier arm, fastest) → THE ROOF.
- **Flags:** (0) `voss_c03`; (1) `dee_plus_c03`; (2) `burned_booth`; (3) `dark_c03`, `paid_c03`.

### Night 4: THE BODY SHOP

*Ferro Coachworks, a 24-hour body shop of chrome and blue strip light in the industrial estate, which
has fixed Halloran cars for thirty years.*

- **Local goal:** a Halloran lawyer is having the old job cards shredded tonight. The night foreman
  races you for the card from the morning after the bridge; win it before the shredder does.
- **Maps:** H10 *Paint Booth*, H11 *Industrial Estate*, H12 *Shredder Run* (four finishes).
- **Scenes:** `c04_open` (Arch 9: the driver's seat two notches forward; Dee: "I rolled it round the
  pit"); `c04_after1` *Blue Light* (the foreman in silhouette against the paint booth's glow);
  `c04_after2` *Job Card 1187*; `c04_decision`; `c04_close` (nightmare, if four nights' facts are
  known or more: the passenger whispers "faster").
- **Fact:** the morning after the bridge, Cass Halloran's silver saloon came in crushed front-left
  with white paint in the dent; Halloran Holdings paid cash and asked for no record.
- **Gates (H12):** (0) give the card to Voss → THE PATROL; (1) give it to Moth to post → THE ROOF;
  (2) give it back to the foreman, whose job depends on it → THE NOODLE STRIP; (3, cold) use it to
  squeeze Cass for money (through the paint booth, fastest) → THE HILL.
- **Flags:** (0) `voss_c04`; (1) `moth_card`; (2) `kind_c04`; (3) `dark_c04`, `paid_c04`.

### Night 5: THE NOODLE STRIP

*Lucky Eight, a 24-hour noodle bar under the elevated railway; steam on the glass and the strip's
neon in every puddle.*

- **Local goal:** Pim has held an envelope for eight years "for whoever brings Vesper's car back".
  Edgar Halloran's driver, in the long black V12, wants it too. Keep it, across the viaducts and the
  market crossings.
- **Maps:** H13 *Under the Rails*, H14 *Market Crossing*, H15 *Viaduct* (four finishes).
- **Scenes:** `c05_open` (Kit's delivery run ends at Lucky Eight; Pim behind the steamed glass sees
  the car and drops a bowl); `c05_after1` *The Envelope*; `c05_after2` *Black Car* (Edgar's grand
  tourer idling at the far end of the street, tinted glass, wipers going); `c05_decision`;
  `c05_close`.
- **Fact:** inside is Vesper's last bet slip: "If I win, I take the keys of Halloran Holdings. If I
  lose, I leave the city. Witnessed, E.H." The bridge race was for the family company, and Edgar
  signed the bet.
- **Gates (H15):** (0) give it to Dee → THE LOCK; (1) give it to Voss → THE MARKET; (2) burn it in
  Pim's stove so nobody comes for Pim again → THE PLAZA; (3, cold) sell it to Edgar's driver for the
  cash in his glovebox (through the market crossing against the lights, fastest) → THE BODY SHOP.
- **Flags:** (0) `dee_plus_c05`; (1) `voss_c05`; (2) `kind_c05`; (3) `dark_c05`, `paid_c05`.

### Night 6: THE LOCK

*The old river lock under the bridge's south pier; the lock-keeper's cottage lit at 3 a.m.; barges
waiting in the fog.*

- **Local goal:** a chop crew has stolen the lock-keeper Ambrose Kell's granddaughter's car and uses
  the towpath as its getaway. Bring the car back before they cut it up.
- **Maps:** H16 *Towpath*, H17 *Barge Lane*, H18 *Lock Wall* (four finishes).
- **Scenes:** `c06_open` (Arch 9: the back seat is damp, handprints inside the rear window; Dee: "Bad
  seal. I'll fix it."); `c06_after1` *The Old Man's Cottage*; `c06_after2` *03:40* (Ambrose at the lock
  ladder, telling it); `c06_decision`; `c06_close` (nightmare: water rising in the cabin; or, if Kit now
  knows she lived, she is dry).
- **Fact:** at 03:40 on the bridge night a soaked woman climbed Ambrose's lock ladder, used his
  phone, asked him to tell no one and walked off up the towpath. Vesper came out of the river alive.
- **Gates (H18):** (0) keep his secret as he has kept it → THE HILL; (1) bring him to Voss as a witness
  → THE PATROL; (2) pay him to forget it → THE NOODLE STRIP; (3, cold) tell Cass Halloran there is a
  witness (along the edge of the lock wall above the water, fastest) → THE MARKET.
- **Flags:** (0) `kind_c06`; (1) `voss_c06`; (2) `paid_off_c06`; (3) `dark_c06`, `told_cass`.

### Night 7: THE HILL

*The hillside cemetery above the city: a switchback road with the whole neon grid below it, and the
Halloran mausoleum at the top.*

- **Local goal:** Edgar's black grand tourer climbs to the tomb at 2 a.m. Tail it up unseen, then get
  back down past his driver.
- **Maps:** H19 *Switchbacks*, H20 *Mausoleum*, H21 *Cemetery Wall* (four finishes).
- **Scenes:** `c07_open` (on the way: the radio tunes itself to an old song); `c07_after1` *The Tomb
  Door* (Edgar's car at the mausoleum, the driver holding an umbrella over an empty seat); `c07_after2`
  *The Drawer* (the photo: a young woman's back, a white coupe, violet underglow); `c07_decision`;
  `c07_close` (nightmare: she hums).
- **Fact:** Ines Halloran, Edgar's daughter, "died abroad" the week of the bridge. Her drawer is empty
  but for one photograph: a young woman, back to the camera, leaning on a white coupe with violet
  underglow. Vesper was Ines Halloran, Cass's sister.
- **Gates (H21):** (0) leave the photograph where it is → THE MARKET; (1) give it to Dee to keep safe →
  THE PLAZA; (2) confront Edgar at the tomb door (he offers a deal) → THE PATROL; (3, cold) take it to
  Cass and watch him break (down the switchbacks and through the gap in the cemetery wall, fastest) →
  THE ROOF.
- **Flags:** (0) `kind_c07`; (1) `dee_plus_c07`; (2) `deal_edgar`; (3) `dark_c07`.

### Night 8: THE PATROL

*The ring road and its all-night services. Sgt. Voss pulls Kit over, and gets in.*

- **Local goal:** Voss's own colleagues, on Halloran money, are coming for the file she keeps in her
  spare-wheel well. Outrun them to the evidence store with her in the passenger seat.
- **Maps:** H22 *Ring Road*, H23 *Services*, H24 *Contraflow* (four finishes).
- **Scenes:** `c08_open` (a 3 a.m. call: only rain and breathing; then blue lights in the mirror);
  `c08_after1` *Passenger* (Voss in the passenger seat, her torch on the file); `c08_after2` *190*;
  `c08_decision`; `c08_close` (nightmare, if not already seen four times).
- **Fact:** the bridge rail was hit from the left at about 190 km/h: a ram, not a crash. The case was
  closed 36 hours after Edgar Halloran phoned the commissioner, who sits on his board.
- **Gates (H24):** (0) give Voss everything you have → THE BODY SHOP; (1) make her promise to keep
  Dee's name out of it → THE NOODLE STRIP; (2) give her nothing and drop her at the services → THE
  PLAZA; (3, cold) sell her to her colleagues for a clean record (the contraflow
  line, fastest) → THE LOCK.
- **Flags:** (0) `voss_c08`; (1) `dee_plus_c08`; (2) `alone_c08`; (3) `dark_c08`.

### Night 9: THE MARKET

*The electronics night market under the flyover: stalls of phones and pulled satnavs, cables strung
overhead like vines.*

- **Local goal:** Ozzie, a satnav cracker, will open the unit if Kit outruns the Halloran men who
  followed the car in, through the market lanes and out.
- **Maps:** H25 *Cable Lanes*, H26 *Flyover*, H27 *Stall Run* (four finishes).
- **Scenes:** `c09_open` (Arch 9: a figure at the far end of the arch at dawn, gone when Kit looks
  again); `c09_after1` *Ozzie*; `c09_after2` *Five Weeks*; `c09_decision`; `c09_close` (nightmare: she
  taps the bridge pin).
- **Fact:** the satnav was built two years after the bridge; its nine pins were loaded five weeks
  ago, the week before the auction; at the auction the top bid was withdrawn at the last second so
  the car fell to the next bidder: Kit. Someone chose Kit.
- **Gates (H27):** (0) take it to Dee and ask her who would do this → THE HILL; (1) keep following the
  pins → THE PLAZA; (2) wipe the pins and stop following them → THE BODY SHOP; (3, cold) sell the unit
  to the Halloran men (through the stalls, fastest) → THE NOODLE STRIP.
- **Flags:** (0) `dee_plus_c09`; (1) `kept_pins`; (2) `wiped_pins`; (3) `dark_c09`, `paid_c09`,
  `dee_minus_c09` (the unit leads to Dee).

---

## 8. THE BRIDGE (the finale)

*The closed Halloran Bridge in heavy rain, the fence cut, Cass's silver hypercar waiting at the far
end where Vesper went over.* Opens after 7 of the nine pins; reached from the satnav board.

- **Local goal:** race Cass for the same bet, the keys of Halloran Holdings, over three maps: H28
  *The Plaza End*, H29 *The Span*, H30 *The Rail* (four finishes).
- **Scenes:**
  - `c10_open` *The Passenger*: Kit walks to the coupe at Arch 9 in the rain; someone is sitting in the
    back seat, for real. It is Dee, wet, the satnav in her lap. "You've been driving me around for
    weeks, Kit." The reveal plays at every knowledge level, in its cold, warm or hot form: cold, Kit
    learns it all here, from Dee; hot, Kit has guessed and says so first.
  - `c10_after1` *Hello, Cassie*: at the plaza end, Dee walks out into the hypercar's headlights.
  - `c10_after2` *Thirty-one*: Cass, at the rail where she went over, in silhouette: the 32nd race.
  - `c10_decision`, then the ending's scene.
- **The answer:** Dee is Ines Halloran, Vesper. Her father knew she had lived and had her declared dead
  abroad rather than let his daughter put his son in prison and take his company. She was away two
  years, came back changed, and has lived under the arches since, where Hallorans never go. She rebuilt
  her own car, painted it black, loaded nine pins and rigged the auction so it would fall to a courier
  whose run passes Halloran Tower at 3 a.m. every night: Cass would see his sister's car every night
  until he broke. The scares were hers: the seat, the damp back seat, the 03:12 timer, the song, the
  calls.
- **Gates (H30):** (0, cold) the inside rail, putting Cass into the toll barrier (fastest); (1) the
  clean line, beating him and letting the truth stand; (2) stopping at the rail where she went in and
  giving Dee the race; (3) the exit ramp off the bridge, leaving them both to it.

## 9. Endings

The finish of the best run on H30 picks the ending, with the flags (first that holds):

- **VESPER** (gate 0, always): Kit runs Cass into the toll barrier at Booth 3, walks up through the
  rain to the wreck (hazards blinking on a still silhouette) and takes the hypercar, the company keys
  on its ring. Dee stands alone at the rail, her revenge done by someone else's hand and her name never
  returned. The city starts calling Kit Vesper. (The owner's session-11 beats.)
- **WHITE** (secret; gate 2, all nine pins driven, and Kit stood by Dee three times or more): Kit hands
  Dee the keys. Vesper drives her own car against her brother for the 32nd time, and wins; Cass hands
  over the keys of Halloran Holdings at the rail.
- **INES** (gate 1 or 2, unless SALVAGE's money or betrayal applies): Cass stops where his sister
  went over and sits down in the rain. Voss's strobes light the plaza and Edgar's car turns and
  leaves. If Kit stood by Dee twice or more, Dee says her own name into Voss's radio, and the last
  scene is under the arches before dawn: the coupe painted white again, Dee in a driver's seat for the
  first time in eight years, Kit beside her. If not, Dee walks off into the rain and Voss says the name
  for her; Kit keeps the car and an empty arch.
- **SALVAGE** (gate 3; or, on gates 1 and 2, Kit took Halloran money twice or more, or sold Dee out): Cass takes the
  bridge, Halloran security takes the coupe. At the yard, Gus crushes it while Kit watches through the
  fence. Arch 9 is shuttered and empty, and Kit walks home under the railway with an envelope of
  Halloran money. Lost everything.

---

## 10. Flags and tiers

- **Facts:** `fact_chassis`, `fact_rival`, `fact_barrier`, `fact_dent`, `fact_bet`, `fact_alive`,
  `fact_ines`, `fact_ram`, `fact_chosen` (one per night).
- **Tiers** (how much Kit knows, for every line with variants): **cold** 0-2 facts, **warm** 3-6,
  **hot** 7 or more (`story.json` `"tiers": {"warm": 3, "hot": 7}`).
- **Counters** (conditions `count:<prefix>>=n`): `dee_plus_*` (Kit stood by Dee), `dee_minus_*` (sold
  her out), `voss_*` (evidence to Voss), `paid_*` (Halloran money), `dark_*` (the cold line), `kind_*`.
- **Nightmares:** `nightmare_*` (seen), so five nightmares never repeat a form.

## 11. The decision graph

| Night | gate 0 | gate 1 | gate 2 | gate 3 (cold) |
|---|---|---|---|---|
| c01 THE YARD | c02 Roof | c04 Body Shop | c08 Patrol | c06 Lock |
| c02 THE ROOF | c03 Plaza | c05 Noodle | c06 Lock | c09 Market |
| c03 THE PLAZA | c04 Body Shop | c07 Hill | c09 Market | c02 Roof |
| c04 THE BODY SHOP | c08 Patrol | c02 Roof | c05 Noodle | c07 Hill |
| c05 THE NOODLE STRIP | c06 Lock | c09 Market | c03 Plaza | c04 Body Shop |
| c06 THE LOCK | c07 Hill | c08 Patrol | c05 Noodle | c09 Market |
| c07 THE HILL | c09 Market | c03 Plaza | c08 Patrol | c02 Roof |
| c08 THE PATROL | c04 Body Shop | c05 Noodle | c03 Plaza | c06 Lock |
| c09 THE MARKET | c07 Hill | c03 Plaza | c04 Body Shop | c05 Noodle |

Every night 2-9 is the target of four or five gates; when a target is already driven, the satnav
takes the gate's other pins in turn, then the board. `tests/test_story_graph` proves it over every
reachable state (every night reachable, no dead ends, the finale only after 7, never a night twice).

---

## 12. Production notes

- **Sets, as corners of the same City:** docks and cranes (the Yard), a car-park roof (the Roof), a toll
  plaza and a bridge (the Plaza, the Bridge), an industrial estate (the Body Shop), an elevated railway
  and a noodle bar (the Noodle Strip, Arch 9), a river lock (the Lock), a cemetery hill (the Hill), a
  ring road and services (the Patrol), a night market under a flyover (the Market). Built with what the
  City has, plus props found or made (licences in `CREDITS.md`).
- **People:** in silhouette with the animation library (UAL clips on the Mannequin; Quaternius' CC0 base
  bodies and hairstyles give each character a shape: Dee's bun, Moth's hood, Cass's long coat). The
  owner wants a **modelled cast with the best graphics** in the end (a later milestone).
- **The car interior** is needed for the mirror shots (the back seat seen in the rear-view mirror).
- **Horror tools** in the cutscene player: mirror shots (the picture flipped and framed by the mirror),
  hard cuts to black, a white flash, an audio sting, flickering lights, the rain on the glass, the
  satnav's voice.
