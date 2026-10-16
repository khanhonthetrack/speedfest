SpeedFest RTX build (Windows)
=============================

An arcade stunt time-attack racer, in a build made with NVIDIA's RTX branch of the Godot engine:
NVIDIA DLSS upscaling and experimental path tracing.

What you need
- Windows 10 (20H1 or newer) or Windows 11, 64-bit.
- An NVIDIA GeForce RTX card (RTX 20-series or newer) with a current Game Ready driver.
  Other graphics cards: use the normal SpeedFest PC build instead.

Start
1. Unzip the whole folder somewhere (not inside the zip), keep all files together.
2. NVIDIA DLSS files: if the folder has no sl.interposer.dll / nvngx_dlss.dll, run
   add_nvidia_dlss.bat once. It downloads NVIDIA's official Streamline SDK v2.10.0 (213 MB, from
   github.com/NVIDIA-RTX/Streamline) and copies only the runtime files next to the game.
3. Run SpeedFest.exe. Windows may say "Windows protected your PC" because the game isn't signed:
   click "More info" -> "Run anyway".
4. If nothing happens, run SpeedFest.console.exe: it shows a console window with any errors.

Recommended settings (Settings -> Graphics -> NVIDIA RTX)
- The status line should say "RTX ready."
- DLSS: Quality (Performance at 1440p and above). DLSS model: Auto.
  On an RTX 2060 at 1440p that's ~110 fps instead of ~65 without DLSS.
- Path tracing (experimental): very heavy. Fine for screenshots on RTX 20/30 cards (8-25 fps on
  an RTX 2060); try it for driving on RTX 40/50 cards. Frame Generation needs an RTX 40 or newer.
- "DLSS unavailable": the NVIDIA DLL files are missing from the folder, or the card isn't RTX.

Controls: arrow keys / WASD to drive, Space handbrake/drift, Shift nitro, Backspace or R back to
the last checkpoint, Enter restart, Esc pause. Gamepads work too.

Credits and licences
This build contains NVIDIA DLSS and NVIDIA Streamline (sl.*.dll, nvngx_*.dll), used under
NVIDIA's licence terms; the licence files are in this folder. NVIDIA, GeForce RTX and DLSS are
trademarks of NVIDIA Corporation. Engine: Godot Engine (godotengine.org, MIT) with NVIDIA's RTX
path tracing branch (github.com/NVIDIA-RTX/godot).
