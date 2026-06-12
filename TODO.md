# TODO — Flap & Build

Living checklist. Items are checked (`[x]`) when done — never deleted.

## Project setup

- [x] Godot 4.x project (`project.godot`, GL Compatibility renderer for Web + Android + iOS)
- [x] Entry scene `scenes/main.tscn` + code-built UI
- [x] `Net` autoload (`scripts/net.gd`) — LOCAL / HOST / CLIENT, port 7801
- [x] Repo files: README, LICENSE, EULA, PRIVACY_POLICY, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, AGENTS.md, TODO.md, .github templates, .gitignore

## Core gameplay

- [x] Flapper: gravity + vertical impulse physics (`scripts/flapper.gd`)
- [x] Auto-scrolling world (200 px/s)
- [x] Pipe pairs: random gap, spawn timer, score on pass, cleanup off-screen
- [x] Hazard collisions: pipes + ground kill; ceiling clamps
- [x] Builder: temporary platforms (3s cooldown, 5s lifetime with fade)
- [x] Score HUD + cooldown bar
- [x] Game over panel + restart + back to menu

## Modes

- [x] Local (same device): left half = Flapper tap, right half = Builder tap
- [x] Offline LAN: host + client by IP (`ENetMultiplayerPeer`)
- [x] Local Server: strict host-side validation (cooldown, bounds)
- [x] State sync: unreliable snapshot (flapper pos/rot, scroll, score) + reliable spawn/restart RPCs

## Polish / pending

- [ ] Manual playtest: balance pipe gap, scroll speed, cooldown values
- [ ] LAN playtest on two devices (phone + desktop)
- [ ] Smooth client sync (lerp instead of snap if jitter shows)
- [ ] Sound effects (flap, place, score, death) — CC0 or original
- [ ] Background music — CC0 or original
- [ ] Parallax background layers
- [ ] Pause menu
- [ ] High score persistence (local save)
- [ ] Web export preset + test in browser
- [ ] Android + iOS export presets + test on device (touch zones, performance)
- [ ] App icon final art + splash screen

## Wishlist

- [ ] Online multiplayer: dedicated headless server + matchmaking/relay
- [ ] Role swap option (host as Builder, client as Flapper)
- [ ] Spectator / replay mode
