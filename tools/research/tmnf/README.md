# TMNF reverse-engineering toolkit (research only)

Scripts used in session 9 to study TrackMania Nations Forever 2.11.26 (freeware, official installer
`tmnationsforever_setup.exe`, SHA-256 `2f659138…6355`). Findings: `docs/research/tmnf_physics.md`.
**Nothing from the game is committed**: no binaries, no pack data, no decompiled code. These scripts
work on a local install only.

Pipeline (Linux, all in a scratch directory outside the repo):
1. Unpack: the installer is a 7-Zip SFX around an Inno Setup 5.2.3 installer:
   `7z x tmnationsforever_setup.exe` then `innoextract -s TmNationsForever_Setup_Tmp.exe`.
   You get `app/TmForever.exe`, `app/TmForever.map` (linker map with every function name) and
   `app/Packs/*.pak`.
2. Symbols: `python3 -I map2seeds.py TmForever.map seeds.tsv` (63k functions, 43k data labels).
3. Decompiler: REA (`npm i -g rea-agents`, https://github.com/morluto/rea) with Ghidra 12.1.4 and JDK 21.
   `GHIDRA_INSTALL_DIR=… REA_GHIDRA_SEED_FILE=seeds.tsv REA_GHIDRA_STARTUP_TIMEOUT_MS=10800000
   python3 -I rea_bridge.py rea.sock bridge.log &` keeps one `rea --mcp` session (and one Ghidra
   analysis, ~8 min) alive. Then `reacall.py rea.sock open_binary '{"path":"/abs/TmForever.exe","provider_id":"ghidra"}'`,
   `dc.py rea.sock 0x7c3e80 out.c` (pseudocode), `asm.py rea.sock 0x7f3c70` (assembly).
4. Packs: `nadeopak.py list Packs Stadium FileHashes.txt` lists a pack (keys come from
   `packlist.dat`; name hashes from GBX.NET's `Resources/FileHashes.txt`).
   `pak_emulate.py Packs Stadium C2A255EF80618DC714C2B1F7CA68608C60 tunings.gbx` decrypts
   `Vehicles\VehicleTunings\StadiumCar.VehicleTunings.Gbx`. The pack cipher re-keys its IV on every
   node read (the node's parent class id) and after each tuning name (its first 4 bytes); this
   script emulates TmForever's reader buffering (256-byte zlib input blocks, 1024-byte output
   blocks), and zlib's Adler-32 checks the result.
5. `tuning_parse.py tunings.gbx tunings.json` parses all 30 `CSceneVehicleCarTuning` nodes with the
   chunk layout taken from `CSceneVehicleCarTuning::Chunk`. `annotate.py tunings.json in.c out.c`
   rewrites tuning reads in pseudocode as `T[offset]{value}`.

Lighter path (session 11): for **reading one function** you do not need Ghidra or REA at all.
`TmForever.map` gives every function's exact start, and the next symbol bounds it, so
`objdump -d -b pei-i386 -m i386 --start-address=.. --stop-address=..` disassembles it directly.
`fnmap.py TmForever.map <name-substring>` prints matching functions with their start, end and size;
`dis.py TmForever.exe TmForever.map 0xSTART 0xEND` disassembles that range and annotates call targets
and float constants from the map. Ghidra setup is ~8 min of analysis and ~1 GB; this is instant and
objdump is already installed. Pseudocode still needs REA/Ghidra.

The pack scripts need `pycryptodome` (`pip install pycryptodome`) and import each other, so run them
from `tools/research/tmnf/` with absolute paths to the data rather than with `python3 -I`
(isolated mode drops the script's own directory from `sys.path`).

Format knowledge for the packs (salts, Blowfish variant, header layout) comes from GBX.NET
(https://github.com/BigBang1112/gbx-net, `Src/GBX.NET.PAK`); the scripts are a Python reimplementation.
