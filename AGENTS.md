# AGENTS.md — Flap & Build (2D)

2D asymmetric co-op game inspired by Flappy Bird. The world scrolls automatically to the right.

> All code, comments, and docs in English, with good meaningful comments.

## Players
- **Player A (Builder):** places platforms, bridges, or temporary blocks. Has a **cooldown** between placements.
- **Player B (Flapper):** controls a character that flies with vertical impulses (tap = impulse, constant gravity).

## Modes
1. **Local (same device):** split touch controls on screen (one half for Builder, one half for Flapper).
2. **Offline LAN (no internet):** host + client over local IP (`ENetMultiplayerPeer`).
3. **Local Server:** host runs an authoritative internal server that validates:
   - collisions
   - world scroll
   - objects placed by the Builder

## Technical requirements
- Godot 4.x (GDScript)
- Web (HTML5) + Android + iOS export
- Flappy Bird-style physics (gravity + vertical impulse)
- Minimalist art
- Builder with cooldown
- Modular code (logic / networking / UI separated)
- Independent project: do NOT share anything with the other games in the monorepo

## Art style
Minimalist, flat, solid colors, no gradients. Original art or CC0.

---

## 🟩 FREE copyright-free assets (CC0)

### 🎨 2D Sprites / Tiles / UI
- Kenney.nl → https://kenney.nl/assets
- Itch.io CC0 Assets → https://itch.io/game-assets/free/tag-cc0
- OpenGameArt (filter CC0) → https://opengameart.org
- CraftPix Free → https://craftpix.net/freebies/
- GameDev Market Free → https://www.gamedevmarket.net/category/free/

### 🔊 Sound and music
- Kenney Audio
- Freesound.org (filter CC0)
- Mixkit
- OpenGameArt Audio

## 🟦 AI-generated assets
- Leonardo.ai, Flux/Midjourney, Stable Diffusion (local)

### Base prompt
> "2D game assets, flat style, clean shapes, no gradients, CC0 style, simple silhouettes, bright colors, for a mobile game"

---

## Wishlist (not implemented yet)

- **Online multiplayer:** current netcode is LAN-only (ENet over local IP, manual IP entry). Future: dedicated server reachable over the internet + matchmaking/relay. The authority model is already server-side (host validates everything in "Local Server" mode), so the migration path is extracting the host logic into a headless Godot server.
