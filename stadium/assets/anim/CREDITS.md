# Humanoid animation: sources and licences

The owner bought four humanoid animation packs and gave them to the project on 23 Oct 2026
(session 19: "learn and store these", then "Yes, commit all four packs"). All four are here as
they shipped, one folder each. `docs/ANIMATIONS.md` is the study of them -- every clip, its
length, its skeleton, what it is good for -- and `tools/anim/manifests/*.json` the
machine-readable inventories.

| Folder | Pack | Author | Clips | Licence |
|---|---|---|---:|---|
| `ual_standard/` | Universal Animation Library [Standard] | **Quaternius**, quaternius.com (patreon.com/quaternius) | 43 | **CC0 1.0**, public domain (`ual_standard/License.txt`) |
| `human_basic_motions/` | Human Basic Motions 2.4 FREE | **Kevin Iglesias**, keviniglesias.com | 118 | Unity Asset Store **Standard EULA**: royalty-free, commercial use allowed, **resale not allowed** (keviniglesias.com/#license, and the pack's own PDF) |
| `motifect_emotes_social/` | Motifect Emotes & Social v1.0 | **Motifect AI**, motifect.io | 30 | "Free for personal and commercial use in your projects. **Do not redistribute or resell these raw animation files as a standalone product.**" (`README.txt`) |
| `motifect_daily_life/` | Motifect Daily Life v1.0 | **Motifect AI**, motifect.io | 40 | the same (`README.txt`) |

## What the licences still require

Only the Quaternius pack is public domain. The other three are licensed to this project, not
released by it, and the owner's decision to keep them in the repository does not change their
terms. What that means for anyone working here:

- **Never sell or re-license them**, as files or as part of anything that is itself an animation
  product. Shipping them inside the game is what they are for; shipping them *as* a pack is not.
- **Never present them as a download in their own right** -- no "animation pack" release asset, no
  zip of `assets/anim/` on the Releases page, no linking a clip for someone to grab. The game's
  build zips are fine; a bundle whose point is the clips is not.
- **Keep this file accurate.** If a pack is replaced or upgraded, its row and its own README or
  PDF go with it.
- Anyone who wants these packs should get them from their authors. They are worth paying for.

The repository is public, so these files are readable by anyone who finds them. That was the
owner's call, made with the terms above in front of them (TRANSCRIPT, session 19).

## Shapes and sizes

- `ual_standard/` -- `Unreal-Godot/UAL1_Standard.glb` (and `_RM`) is the build to use: Godot
  imports it as it is, 43 clips on a 65-bone Unreal-style rig, with the pack's own 13,744-triangle
  Mannequin, 1.83 m tall, which serves as a stand-in character until we have our own. `Unity/`
  holds the same 43 clips as FBX for that engine; `*_Setup.png` are the author's import notes.
- `human_basic_motions/` -- 118 clips as single-take FBX under `Animations/` (female, male and two
  masked hand poses), `Models/` two body meshes, `Textures/` their colour palette, plus the pack's
  PDF and a zip of its Blender sources. The locomotion set: walk, run and sprint in eight
  directions, in-place and root-motion pairs.
- `motifect_emotes_social/`, `motifect_daily_life/` -- each clip twice, `Animations/*.fbx` and
  `BVH/*.bvh`, on one 77-bone rig. No mesh: motion only, to retarget onto a character.

Godot imports every `.fbx` here natively (no FBX2glTF, no Blender) and ignores the `.bvh`
entirely. `docs/ANIMATIONS.md` has the rig mapping, the import gotchas and the clips worth using.
