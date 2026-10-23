# Humanoid animation: sources and licences

The owner bought four humanoid animation packs and gave them to the project on 23 Oct 2026
(session 19). **Only the CC0 one is in the repo**; the other three may not be redistributed, and
this repo is public. `docs/ANIMATIONS.md` holds the study of all four -- every clip, its length,
its skeleton and what it is good for -- and `tools/anim/manifests/*.json` the machine-readable
inventories, so nothing about them is lost by leaving their files out.

## In the repo (`ual/`)

| Files | Pack | Author | Source | Licence |
|---|---|---|---|---|
| `ual_standard.glb`, `ual_standard_rm.glb` | Universal Animation Library [Standard] | **Quaternius** (patreon.com/quaternius) | quaternius.com, "Unreal-Godot" build of the pack | **CC0 1.0** (`LICENSE-CC0.txt`) |

43 clips on a 65-bone Unreal-style rig (`root`, `pelvis`, `spine_01..03`, `clavicle/upperarm/
lowerarm/hand` with all five fingers, `thigh/calf/foot/ball`), plus the pack's own 13,744-triangle
Mannequin, 1.83 m tall, which makes a stand-in character until we have our own. `_rm` is the same
43 clips with root motion baked into the `root` bone; the other has the character running on the
spot. Both load in Godot 4.7.2 as they are -- no retargeting, no Blender.

Godot's importer eats the `_Loop` name suffix and turns it into the clip's loop mode, so
`Walk_Loop` arrives as `Walk` set to loop and `Jump_Start` as `Jump_Start` set not to. Clip names
in `docs/ANIMATIONS.md` are the ones the file carries; the names in the game are those without
`_Loop`.

## Not in the repo

| Pack | Author | Licence | Why it is out |
|---|---|---|---|
| Human Basic Motions 2.4 FREE | Kevin Iglesias (keviniglesias.com) | Unity Asset Store Standard EULA: royalty-free in a project, **resale and redistribution not allowed** | the EULA covers the built game, not a public repository of the source clips |
| Motifect Emotes & Social v1.0 | Motifect AI (motifect.io) | free for personal and commercial use in a project, **"do not redistribute or resell these raw animation files"** | committing the raw `.fbx`/`.bvh` to a public repo is that redistribution |
| Motifect Daily Life v1.0 | Motifect AI (motifect.io) | the same | the same |

All three may be **used in the game**: what their licences forbid is handing the source clips on.
Baked into a build they are fine; sitting in a public GitHub repo they are not. The owner's copies
stage into the untracked `assets/anim/` at the repo root with
`tools/anim/stage_packs.sh <dir with the zips>`, which also rebuilds the manifests.
