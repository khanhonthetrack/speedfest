# BlendSwap for the Stadium remake and the "mix" (investigation, 18 Oct 2026)

Owner's question (TRANSCRIPT, 18 Oct): could BlendSwap be useful, for the `stadium` branch and for
the planned **mix** (Stadium + NFS Underground 2 vibe: buildings, neon lights, some nature, city)?
The owner has a BlendSwap API key.

## Short answer

- **`stadium`: no.** Its rule is "recreate only": every model is our own, built in TMNF's style
  from measured shapes and generated in code (`blocks/shapes/`, `race/tm_track_decor.gd`,
  `tools/texgen/`). BlendSwap has nothing in TMNF's look that we could use without breaking that
  rule. The upload licences aren't checked, so a TMNF-looking upload is exactly the kind of file
  that might be a rip.
- **The mix: a little, as a source of a few CC0 props, not as the base.** BlendSwap has
  CC0 neon signs, street lamps and some buildings and rooftops. It also has many CC-BY, CC-BY-SA,
  older NC and "GAL" files we shouldn't ship. The files are `.blend` scenes by thousands of
  uploaders, in mixed scales and styles, and often use Cycles node materials. Each one needs
  cleanup, decimation and baking before it works in Godot on the web (Compatibility) or the Switch.
  The look we already get from procedural buildings, interior-mapped facades and emissive neon is
  more consistent and cheaper to run. **Poly Haven** (CC0, photoreal, glTF, an API we already use)
  is the better first source for nature and street props. **Kenney / Quaternius** (CC0, game
  ready) are better if we want a stylised look.
- **The API key is useful only if we run a trial** (below). Don't paste it into chat. Store it as
  an environment secret. `blendswap.com` is also blocked by this cloud environment's network
  policy today, so it has to be allowed first.

## 1. What BlendSwap is now

- A library of free `.blend` files. It relaunched in May 2026 under new owners (rebuilt site,
  in-browser `.blend` to OBJ/STL/**GLB** conversion, mesh cleanup and retopology tools), then added
  Contributor Levels (Jul), a paid marketplace (Aug) and MCP/API access for AI agents (Sep).
  About **25,800 free assets from ~8,000 creators**.
- **Licences are chosen by the uploader, per asset:** CC0, CC-BY, CC-BY-SA, BlendSwap's own
  **General Asset License (GAL)** (we couldn't read its text), and on older uploads NC variants
  (example: a CC-BY-NC street-lamp scan). The MCP page says BlendSwap **does not verify** licence
  claims and API access "does not add rights".
- **API:** REST with a bearer key (`GET /api/v1/assets?q=…&license=cc0&format=…`,
  `POST /api/v1/downloads`). There is also an MCP server at `https://blendswap.com/api/mcp`
  (Streamable HTTP, `Authorization: Bearer bsk_live_…`) with tools `search_assets`,
  `get_asset`, `download_asset` and `get_balance`. Search and metadata are free. Downloads are
  metered: a free account gets 5-7 a day (BlendSwap's pages disagree), paid plans 50-100 a day,
  then 10 credits each. The search filters cover keyword, type, licence, file format, category,
  tag, Blender version and render engine.
- What turned up for our themes: tag pages "neon" (45 models) and "street lamp" (24). Examples:
  *Neon Sign* (KBeres, CC0), *Realistic Neon sign* (kexsz, CC0, beveled curves), *Neon Open
  Sign* (CC-BY), *Low Poly Street Lamps Pack* (matthewinglis, CC0), CC0 building and rooftop
  packs written up by blender3darchitect. Nothing turned up for "stadium".

## 2. The rules it would have to fit

| Rule (where) | What it means for BlendSwap |
|---|---|
| SpeedFest: **CC0 only**, plus OFL fonts (`docs/ASSETS.md`, `docs/M5_SPECS.md` §5) | Filter to `license=cc0`. CC-BY, BY-SA, NC and GAL are out unless the owner changes the rule. |
| Build geometry **in code**; generator scripts in the repo (root `CLAUDE.md`) | An imported mesh is an exception. M5 already allows Blender-script outputs (`.glb`) with their `.py`. A downloaded `.blend` needs a fetch + convert script, like `tools/textures/fetch_cc0.py`. |
| Stadium: **recreate only, our own models in TMNF's style** (`stadium/README.md`, `stadium/CLAUDE.md`) | BlendSwap models aren't ours and aren't TMNF's style. Out. (Stadium's recorded sounds and music are open-licensed downloads, with credits in `stadium/audio/*/CREDITS.md`; models were never treated that way.) |
| No real brands; parody names only (M5 spec, session 14 adverts) | Skip neon signs, cars and billboards that carry real logos, **even under CC0**: the licence covers copyright, not trademarks. |
| Both renderers; web `.pck` ~8.4 MB; Switch later | High-poly showcase scenes and Cycles-only materials need decimation, LODs and baked PBR textures. Neon made from curves needs converting to meshes with emissive materials. |

## 3. Licences: why CC0 is the only easy one

- **CC0:** nothing to do. Still list each file in `docs/ASSETS.md`.
- **CC-BY / CC-BY-SA:** need credits in the game. Every CC version also forbids applying
  "effective technological measures" that stop recipients exercising the licence. Whether a
  console's encrypted packages count is **not settled** (the CC wiki says encryption isn't
  necessarily a prohibited measure). For a Switch target it's simplest to avoid the question,
  which is one reason the project picked CC0. **BY-SA** adds share-alike on the changed model.
  `stadium` already ships CC-BY 3.0/4.0 and one CC-BY-SA 3.0 music track: fine for the PC zips,
  but worth flagging before any console build.
- **NC:** not compatible with any paid release. Out.
- **GAL:** we couldn't find its text, so treat it as out until someone reads it.
- **Provenance:** BlendSwap doesn't check the claims. So keep only CC0 uploads that look original
  (WIP shots, the author's other work, no logos or game-ripped look), and keep the asset page URL
  and its licence in `docs/ASSETS.md` the day we download it.

## 4. The mix, item by item

| Need | Ours today | BlendSwap's value | Better source |
|---|---|---|---|
| City buildings | `city_kit.gd`, interior-mapped facades (look plan step 3), batching | Low: mixed styles and scales; CC0 sets exist but would need consistent materials | Keep procedural; ambientCG facade textures if needed |
| Neon signs | emissive neon in `env_neon` and track shaders, bloom | **Medium**: a few CC0 hand-made signs would add variety (signs only, no logos) | Or our own: text to curve to mesh in a Blender script with our parody brands |
| Street props (lamps, bollards, barriers) | procedural props | **Medium**: CC0 lamp packs | Poly Haven models (CC0, glTF, consistent PBR); Kenney City Kits (stylised) |
| Nature (trees, bushes, rocks, grass) | coast kit, terrain, ambientCG rock | Low to medium: quality varies, foliage is often high-poly or alpha-heavy | **Poly Haven** (trees, plants, rocks; CC0); Quaternius nature packs (stylised) |
| Stadium structures (stands, floodlights, gates) | `arena_kit.gd`, the stadium's TMNF-style generators | Low: "stadium" found nothing usable | Keep procedural |
| Cars | procedural / Blender-scripted, original designs | None: real-brand cars are a trademark risk; mixed quality | Keep our own |

## 5. If we try it: a one-hour trial

1. The owner allows `blendswap.com` in the environment's network settings, adds the key as an
   environment secret named `BLENDSWAP_KEY`, and installs Blender (`bpy`) in the container
   (M5 used `/opt/bpyenv`).
2. `tools/assets/fetch_blendswap.py` (new): search with `license=cc0` for about 5 candidates
   (a neon sign, the low-poly street-lamp pack, a rooftop pack, a building, a tree). Save the
   asset page, author, licence and date. Download into a fresh untrusted folder, opened only by
   our `bpy` script, which never runs scripts embedded in the `.blend`.
3. `tools/blender/convert_asset.py`: apply transforms, scale to metres, decimate to a triangle
   budget, bake materials to albedo/normal/ORM, export `.glb` into `game/assets/props/` (desktop
   HD under `assets/hd/`).
4. Render next to our procedural versions on Forward+ and Compatibility (`tools/run_scene.sh`),
   and record triangle and texture costs. Keep an asset only if it clearly beats what we have.
   Each kept asset gets a row in `docs/ASSETS.md`.

Decisions for the owner before that: (a) does CC0-only stay? (recommended: yes, given Switch);
(b) may the mix use imported props next to procedural geometry?; (c) is the mix a new branch off
`stadium`, off `main`, or a third project?

## 6. Limits of this investigation

The cloud environment's network policy blocks `blendswap.com` (and polyhaven.com, kenney.nl and
the others), and the page fetcher couldn't resolve them either. Everything above comes from web
search results that quote BlendSwap's own pages (FAQ, About, MCP & API, news posts, asset pages).
The free download quota, the GAL text and the exact API parameters weren't checked first-hand.
Check them on the site before building the fetch script.

## Sources

- BlendSwap, A New Chapter for BlendSwap in 2026: https://blendswap.com/news/98
- BlendSwap, Blender MCP launch post: https://blendswap.com/news/105
- BlendSwap, MCP & API page: https://blendswap.com/3d-mcp-api
- BlendSwap, Plans & Credits: https://blendswap.com/plans; FAQ: https://blendswap.com/faq;
  About: https://blendswap.com/about; old Terms: https://www.blendswap.com/terms
- BlendSwap, paid marketplace post: https://blendswap.com/news/104
- BlendSwap tag pages: https://blendswap.com/3d/neon, https://blendswap.com/3d/street-lamp;
  assets https://blendswap.com/blend/11833, /22748, /19251, /15415, /23678
- blender3darchitect, free BlendSwap architecture assets:
  https://www.blender3darchitect.com/furniture-models/best-free-assets-for-architecture-in-blendswap-april-2018
- Creative Commons wiki, 4.0 technical protection measures:
  https://wiki.creativecommons.org/4.0/Technical_protection_measures
- Kenney Racing Kit (CC0): https://opengameart.org/content/racing-kit; City Kit Roads:
  https://gamedev.net/news/5156-city-kit-roads/
