# City buildings: sources and licences

Buildings the owner chose from Blend Swap (session 15, 20 Oct 2026), split into one glTF per
building by `stadium/tools/assets/blend_to_glb.py` (cameras, lights, ground, trees left out; each
building joined into one mesh, moved to its foot, decimated to 60,000 triangles at most; no images:
the game dresses them in its own materials, `env/tm_city_assets.gd`). Each set's manifest
(`<set>.json`) lists its buildings, sizes and licence.

| Set | Files | Source | Author | Licence |
|-----|-------|--------|--------|---------|
| sky | `sky_01..11.glb` | "Skyscraper", Blend Swap #81908 (blendswap.com/blends/view/81908) | Blend Swap user (2015) | CC0 1.0 |
| sky2 | `sky2_01..05.glb` | "Skyscraper 2", Blend Swap #82048 (blendswap.com/blends/view/82048) | Blend Swap user (2015) | CC0 1.0 |
| hotel | `hotel_01.glb` | "Hotel", Blend Swap #82480 (blendswap.com/blends/view/82480) | Blend Swap user (2015) | CC0 1.0 |
| rt | `rt_01..21.glb` | "12 Buildings", Blend Swap #69593 (blendswap.com/blends/view/69593) | **raytrace** (soundcloud.com/raytrace) | **CC BY 3.0** (credit required) |

"12 Buildings" by raytrace is licensed under Creative Commons Attribution 3.0
(creativecommons.org/licenses/by/3.0/); scaled to metres (x 100), one of each design kept.
