# FPS: Weapon Selection Screen

A Roblox first-person shooter, starting with the loadout / weapon selection screen.

When a player joins (and again each time they die), they land in a private **armory**. It's a dark
showroom with a glowing turntable, spotlights and a holographic wall. The selected gun floats and
spins on the pedestal while a tactical UI shows its stats. Pressing **DEPLOY** spawns the player in
first person with that weapon recorded on them.

Weapons: **M1 Garand**, **M16A1**, **M4 Carbine**.

## Features

- Live 3D preview of the selected gun. Drag to rotate it (with inertia); it auto-spins when idle. Scroll or pinch to zoom.
- Swap animation: the old gun sinks into the pedestal, the new one rises and pops in, and a hologram scan ring sweeps up through it.
- Each gun has its own accent colour, and the whole room and UI re-tint to match (neon strips, rim light, stat bars, deploy button).
- Weapon cards with hover and selection states, stat bars that count up with staggered animation, a text "decrypt" effect on the gun name, and MAG / RPM / ACTION tiles.
- Cinematic touches: letterbox bars, vignette, HUD corner brackets, bloom, depth of field, floating dust and mouse parallax.
- Controls: mouse, keyboard (`1-3`, `Q/E`, arrow keys, `Enter`), gamepad (D-pad / bumpers, `A`) and touch.
- The guns are built entirely from Parts in code, so there are no meshes to upload.

## Project layout

```
src/
  shared/                      -> ReplicatedStorage.Shared
    GunConfig.luau             weapon stats and descriptions (single source of truth)
    GunModels.luau             procedural gun models built from Parts
  server/                      -> ServerScriptService.Server
    Loadout.server.luau        holds players in the armory, validates DEPLOY, respawns into the armory on death
  client/                      -> StarterPlayer.StarterPlayerScripts.Client
    SelectionScreen.client.luau  controller: opens/closes the armory, input shortcuts, talks to the server
    Showroom.luau              3D room, turntable, lighting, post effects, camera
    SelectionUI.luau           2D overlay: cards, stats, deploy button, transitions
```

## Getting it into Roblox Studio

### Option A: Rojo (recommended)

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/) and the Rojo Studio plugin.
2. In Studio, create a new place from the **Baseplate** template.
3. In this folder run `rojo serve`, then click **Connect** in the Rojo plugin.
4. Press **Play**.

Or build a ready-to-play place file (scripts plus a baseplate, spawn point and Future lighting) with
`rojo build place.project.json -o FPS.rbxlx`, then open `FPS.rbxlx` in Studio.

### Option B: copy the scripts by hand

1. In **ReplicatedStorage**, create a Folder named `Shared` and add two **ModuleScripts**, `GunConfig` and `GunModels`.
2. In **ServerScriptService**, add a **Script** named `Loadout`.
3. In **StarterPlayer > StarterPlayerScripts**, create a Folder named `Client` and add:
   a **LocalScript** named `SelectionScreen`, and **ModuleScripts** named `Showroom` and `SelectionUI`.
4. Paste in the contents of the matching `.luau` file for each one.

## Tweaking

- **Stats, names, colours:** edit `src/shared/GunConfig.luau`. The UI bars read the 0-100 `stats` values.
- **Add a gun:** add an entry to `GunConfig.Guns`, add its id to `GunConfig.Order`, and add a builder in `GunModels.luau`
  (or have the builder return a clone of a real mesh model).
- **Sounds:** the UI uses a built-in Roblox ping sound. Swap the ids in `SOUNDS` at the top of `SelectionUI.luau` for your own.

## Next steps

The chosen weapon is stored on the player as the attribute `PrimaryWeapon`. The combat system
(viewmodel, shooting, recoil, reloading) will read that attribute and `GunConfig`.
