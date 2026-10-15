# SpeedFest

An arcade **time-attack stunt racer** in the spirit of Trackmania, styled after the street-tuner
night vibe of Need for Speed Underground 2. Built with **Godot 4.7**. Web first; the long-term
goal is Nintendo Switch / Switch 2.

- 3 original cars (JDM coupe, muscle, supercar) with performance tuning and NFSU2-style
  visual tuning (paint, hood, body kit, spoiler, rims, underglow, tint, plate)
- 3 tracks: Neon Downtown (night city), Pulse Arena (stunt stadium), Sunset Coast (cliff highway)
- Online Time Attack for 2–8 players with ghost cars, checkpoint splits and a live leaderboard

> Status: under construction. See [docs/PLAN.md](docs/PLAN.md) and [docs/PROGRESS.md](docs/PROGRESS.md).

## Play
One person hosts (full guide: [docs/HOSTING.md](docs/HOSTING.md)):
```bash
git clone https://github.com/khanhonthetrack/speedfest.git
cd speedfest/server && npm install && npm start          # http://localhost:8080
cloudflared tunnel --url http://localhost:8080          # optional: public https URL for friends
```
Everyone else opens the URL in desktop Chrome, Edge or Firefox. Pick **Online**, then join the
host's room. Keys: W/S drive and brake, A/D steer, Space handbrake, Shift nitro, R respawn,
Enter restart, C camera, Tab leaderboard, Esc pause.

## Develop
Open `game/project.godot` in Godot 4.7.2. Agents and contributors: read [CLAUDE.md](CLAUDE.md) first.
