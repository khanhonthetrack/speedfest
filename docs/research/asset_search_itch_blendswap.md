# Asset search: itch.io and Blend Swap (session 19, 23 Oct 2026)

The owner asked whether we can browse for assets (after the itch.io MCP turned out to be read-only:
it lists your own games, download keys and purchases, nothing else). Looked for the open wishlist from
session 15 (TRANSCRIPT, 21 Oct): **neon/LED billboards, modern storefront/facade kits, street props,
better street trees**, CC0 or CC-BY. Nothing downloaded yet; the owner picks.

## How to browse from a cloud session
- **itch.io works without an account or MCP.** Every browse page has an RSS twin: append `.xml`,
  e.g. `https://itch.io/game-assets/free/tag-3d/tag-neon.xml` (tags chain: `/tag-3d/tag-pbr`).
  A page's "More information" table has an **Asset license** row when the author set one; otherwise
  the licence is only in the description (or missing: then don't use it).
- **Free / "name your own price" downloads work too**: POST `csrf_token` (from the purchase page's
  `<meta name="csrf_token">`, same cookie jar) to `<page>/download_url` → JSON `url` of the download
  page, which lists the files (`data-upload_id`, name, size). Checked on the Quaternius kit
  (one zip, 223 MB); nothing fetched.
- **Blend Swap**: the BlendSwap MCP (when connected) searches for free with a licence filter
  (`license: "cc0,cc_by"`); previews only come with a download, which costs the owner's daily free
  allowance (7/day). Files are `.blend`: convert with `stadium/tools/assets/blend_to_glb.py`.
- Free 3D on itch.io is mostly low-poly / PSX / voxel; filter with `tag-realistic`, `tag-pbr`.

## Licence rule for this repo
The repo is public, so assets are committed = redistributed. Use **CC0** (anywhere) or **CC BY**
(Stadium, credited in a `CREDITS.md`). Custom "free for commercial use, don't redistribute/resell
the raw files" licences don't fit a public repo: skip them unless the author agrees.

## Shortlist

| Asset | Source | Licence | Fits | Notes |
|---|---|---|---|---|
| **Downtown City MegaKit** (Quaternius): 300+ modular NYC/Boston city-block pieces, facades with storefronts, fire escapes, street pieces, 7 example buildings | https://quaternius.itch.io/downtown-city-megakit | **CC0** (Asset license row) | storefronts/facades, street level | Semi-realistic, best fit found; glTF/FBX/OBJ; one 223 MB zip |
| 3D Deciduous Trees Pack (Polyy.AI): 14 trees, GLB, PBR | https://polyyai.itch.io/3d-deciduous-trees-pack | **CC0** | street trees | AI-made; leaf clumps look decent on the cover, check up close |
| Free CC0 Industrial 3D Models (3dmodelscc0): 12 props | https://3dmodelscc0.itch.io/free-cc0-industrial-3d-models | **CC0** | dressing (work lights etc.) | Realistic, small set |
| Street Props Pack (CrazyDrPants / MadeByYeshe): bins, dumpster, hydrant, post box, bench, cones, lamp | https://crazydrpants.itch.io/street-props-pack | **CC BY 4.0** | street props | Stylised/low-poly look: may clash |
| Realistic Neon sign (kexsz) | https://blendswap.com/blend/22748 | CC0 | neon | `.blend` (2.8) |
| Neon Open Sign (mattsour) | https://blendswap.com/blend/19251 | CC BY | neon | wires + frame |
| Neon Dragon Sign (BartLors), Blade Runner style | https://blendswap.com/blend/28525 | CC BY | neon | |
| Apocalyptic Buildings, Ian Hubert style, with a billboard (rayanfernandes) | https://blendswap.com/blend/28489 | CC0 | billboard | 94 likes |
| Billboard / Chupete Publicitario (lucasromerodb); Scrolling advertising board (mik1190); Billboard, low poly (Jcubes) | https://blendswap.com/blend/6903, /11328, /4670 | CC0 | billboards | |
| Decorative Street Light (unyxium), 5.5k faces | https://blendswap.com/blend/23830 | CC0 | street props | we already have the owner's lamps |
| Street Props (RamonArango), Copenhagen signs | https://blendswap.com/blend/17709 | CC BY | street props | |
| Street Tree (jodesserres) | https://blendswap.com/blend/11346 | CC BY | street trees | |

Seen but **not usable as is** (custom licence that forbids redistributing the files, or no licence
stated): SKC Shop "Free Industrial Props Sampler" (realistic rooftop condenser + roof vent, AI-made,
custom licence), Cenji "Urban & Street Props Mega Pack" (120 low-poly props, custom licence),
AssetsFactory "Free Street Litter Sampler" (custom), EH98 "Low Poly Cyberpunk City" sample (custom),
ZFR "Realistic Street Lamp" (vague), VOiD1 "Free 3D Road Signs", LLGM "Traffic Signs - European / UK",
molodkrasiv "Neon Shop", screaminseagull "Neon Tech Modular Set" (no licence stated).
