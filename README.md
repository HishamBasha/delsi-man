# Delsi Man — first playable development build

An original 3D branded runner, implemented in **Godot 4.5.1 / GDScript**. This repository is intended for continued development, not disposal. It is an early production foundation, **not a finished commercial release** or a Pepsiman remake.

## Run now

1. Install Godot 4.5.1 (standard edition; no .NET required) or a compatible Godot 4 version.
2. Extract this entire folder.
3. Import `project.godot` in Godot, then press **F6** with `scenes/main.tscn` open or **F5** from the project.
4. Select **START DELIVERY**.

Command line: `godot --path /path/to/delsi-man`

The archive also includes `DelsiMan.pck`, a compiled game-data pack. Run it with the Godot **4.5.1** executable: `godot --main-pack DelsiMan.pck`. It is not a standalone executable. Use the editable `delsi-man` folder for ongoing development.

No third-party addons, asset downloads, accounts, servers, or purchase is required to run the project. The only runtime prerequisite is Godot.

## Controls

| Action | Keyboard | Controller | Touch |
|---|---|---|---|
| Steer | A/D or arrows | D-pad | Left/right buttons |
| Jump | Space / W / Up | A | Jump |
| Slide | S / Down | B | Slide |
| Sprint | Hold E | Hold Y | — |
| Pause/resume | Esc / P | Start | Pause |
| Retry checkpoint | R | UI button | Checkpoint |

## Implemented

- One 1,800m course with six sections; approximately 2–3 minutes per clean run, longer with retries. **Not yet the proposed 10–12 minute authored level.**
- Free lateral steering across the road, jumping, sliding, holding **E to sprint** (faster run, higher animation cadence), obstacle collisions, recovery, checkpoint retries.
- Dense obstacle/collectible routes, deterministic course layout, five checkpoints plus start, score/combo/coldness, finish screen.
- Cosmetic delivery-cart riding segment and visible pursuing cart train. Vehicle physics and interactive chase pressure are not yet implemented.
- Keyboard, D-pad/controller buttons, onscreen touch controls.
- English interface with partial Arabic translation and RTL menu. Full localization/accessibility QA remains.
- Assist mode: reduced speed and collision protection.
- Generated sound cues with mute toggle.
- Persistent versioned best score/time, language and assist settings; atomic save-file replacement.
- Procedural art, lit streets, color-coded product stand-ins; a Mixamo FBX hero driven by baked `delsi/*` state clips; distance culling.
- Panorama sky from the supplied 4096x2048 skyboxes in `assets/Skyboxes/` — `game.gd::apply_sky` drops the equirectangular texture into a `PanoramaSkyMaterial`, keeps fog off most of the sky and falls back to the old flat colour if the file is missing. The level JSON can point at another panorama with `"sky"`.

## Brand/art status

The referenced user artwork was not available as an actual attachment. **All logos, packages and environments here are procedural stand-ins, and the hero is a Mixamo sample model rendered without its original texture; none of it is official Delsi artwork.** The display text is not a traced logo. Five flavor names are provisional, pending brand approval. Replace the `Art` factories or their products with approved scenes/materials, and replace the hero FBX and its clip set with the approved mascot rig. Do not publish as an authorized brand game before approvals.

## Project map

- `scripts/runner.gd`: movement simulation; independent of course geometry.
- `scripts/course.gd`: deterministic course builder, centerline bends (`center_at`), entity registry, six-stage choreography, culling, checkpoint restoration.
- `scripts/city.gd`: procedural Yemeni city kit (tower houses, qamariya windows, shopfronts, poles/cables, market stalls, vehicles, pedestrians, construction props, festival lights, building interiors).
- `scripts/art.gd`: replaceable original procedural art factories and materials.
- `scripts/hero.gd`: hero rig (Mixamo FBX skeleton, procedural fallback) — bakes the state clips into `delsi/*` and maps runner/game state onto them.
- `scripts/profile.gd`: versioned progress and atomic persistence.
- `scripts/game.gd`: game state, UI, input setup, collision evaluation, barrel obstruction event, audio, orchestration and headless tests.
- `scripts/entities/*.gd`: editor-placeable entities (`BottlePickup`, `RoadHazard`, `FinishMarker`); `scripts/hazards/*.gd`: `@tool` hazard nodes.
- `data/flavors.json`: stable flavor IDs, colors and copy.
- `data/level_01.json`: stable level ID, length, speed, chapter boundaries and optional `scene` field.
- `assets/Skyboxes/`: five 4096x2048 equirectangular panoramas (`skybox-space-day/galaxy/nebula/band/dark`); `day` is the default sky.

The generated course still owns its 1,800m layout constants; changing JSON length alone does not author a new course. Authored scenes are the intended path for new layouts (below). Data-driven metadata is implemented; unlimited behavior extensibility is not claimed.

## Authoring levels in the editor

A level can now be laid out visually in the editor and played instead of the generated course:

1. Create a scene whose root is a `Node3D` with `scripts/course.gd` attached (start from `scenes/levels/manual_sample_level.tscn`).
2. Place entities from the `scripts/entities/` and `scripts/hazards/` scripts. They are `@tool` scripts: each rebuilds its visuals and writes its collision metadata (`kind`, `radius`, drift/throw fields) automatically when you change exports.
3. Add a `FinishMarker` to set the finish distance (`finish_at` overrides the course length).
4. Register the scene in `data/level_01.json` with a `"scene"` field, and set the root's `use_in_game` export to **true**. The gate accepts the scene only when `use_in_game` is on and at least one entity was collected; otherwise the game falls back to the generated course and prints an INFO line. The bundled sample ships with `use_in_game = false` so it stays a template.

Entity kinds: `0` jump crate, `1` duck bar (looks: arcade bar, truck **slide-under** trailer), `2` dodge wall (looks: arcade/concrete/crates/container), `3` bottle, `4` hole, `5` thrown/moving object (styles: crate, pedestrian, handcart, motorbike, car, truck, barrel), `6` stairs (a three-jump set: rising flights, uneven gaps, each step clears higher), `7` building stair (a three-jump set: small → bigger → third porch block, equal gaps, same height), `10` checkpoint marker, `11` finish marker, `12` scripted trigger (barrel obstruction). Authored scenes are straight (no bends); the generated course uses the curved centerline.

## Level 1 — Yemeni city rework

The generated 1,800m course is now a six-stage choreography (300m per flavor section):

1. **0–300m old town** — stone tower houses with qamariya windows, gypsum bands, parapets; simple hazards and teaching holes.
2. **300–600m souq** — market stalls, pedestrians, handcart crossings, drifting hazards, festival light strings.
3. **600–900m alley run** — narrow building fronts and two building interiors: a simple corridor (640–720m) and a blocked passage (800–890m) preceded by the **barrel obstruction** trigger — a barrel sits on the runner's head for ~4.2s with **temporarily reversed steering** while he switches to the tipsy `unbalanced` walk take, then clears automatically.
4. **900–1200m construction** — warehouses, scaffolds, sand/bricks/pipes, holes, barrel tosses from reversed trucks.
5. **1200–1500m city rush** — billboards, wider vehicle traffic, triple lanes, car crossings.
6. **1500–1800m final chase** — dense gates and crossings, chase train, festival finish gate.

Street direction changes come from `course.center_at(at)`: a smooth bend table shifts the road center per stage. The runner's lateral clamp, obstacle positions, camera, chase train and checkpoints all follow the centerline; chunks are yawed onto the chord. Streets carry lane dashes, tire tracks, gutters, edge lines, painted curbs, sidewalk paving, manhole covers, asphalt patches, sand drift and zebra crosswalks at the stage boundaries.

Crossing hazards are either arcing tosses from roadside trucks or grounded crossings (pedestrians, carts, vehicles) that sweep the road during a window ending at their collision point; grounded barrels roll with spin. Later stages also place **cargo-trailer slide-under** hazards — a full truck trailer you must slide beneath. Collision rules: holes and crates are cleared by jumping, bars and trailers by sliding, walls only by lane position (or assist/invulnerability); the stair sets demand three separate timed jumps, each step with its own clearance height. Obstacles fade in/out by distance instead of popping, and every static obstacle stays completely still — no pulsing, breathing or idle drift — unless it is a hazard designed to move.

Passing each checkpoint makes its lollipop **rise while shrinking away** with a short ascending jingle.

## Verification

Run: `godot --headless --path . -- --test`

Tests exercise authored scene loading/gating, the curved centerline, the barrel obstruction trigger and control reversal, continuous steering bounds, jumps, sliding, collision damage, invulnerability, bottle pickup deduplication, best-record comparisons, sprint speed, the slide-under trailer hazard, the lollipop pickup animation state, the hero rig and its baked clip set (every state clip present, root motion pinned, heading on the road axis, hip bob and recovery takes intact), full-course completion and UI updates. They do not claim GPU performance, visual approval, device certification, or real-world controller/touch testing. Test mode does not write your profile.

## Cross-platform shipping

Godot supports Windows, macOS, Linux, Android, iOS and web. Install matching export templates via **Editor → Manage Export Templates**. Add/export each platform using **Project → Export**. This source project is not an installer or signed store package.

- Windows/Linux: install templates and build, then test actual devices.
- macOS: platform signing/notarization required for a normal public distribution.
- Android: configure Android SDK/JDK, package ID and signing key; validate touch, lifecycle and performance.
- iOS: export and build/sign with Xcode on macOS and the appropriate Apple account.
- Web: use Compatibility renderer (already selected), export and serve over HTTP(S); test target browsers. Offline/PWA installation is not implemented.
- Consoles: require platform approval and a supported porting arrangement; not a one-click promise.

Platform reference: https://docs.godotengine.org/en/4.5/tutorials/export/

## Next production milestones

1. Replace procedural art with the approved mascot, rig, bottle/label assets and Yemeni environment kit.
2. Separate collision/scoring/UI into tested components; declarative section assets and authoring validation.
3. Author a 10–12 minute course with actual branches, elevated paths, contextual traversal, moving hazards and interactive chase/vehicle mechanics.
4. Finish localization, remappable inputs, controller focus flow, accessibility and scalable layouts.
5. Add authored cinematics, music, VFX, balancing, difficulty-specific records, time trials and photo mode.
6. Profile GPU/CPU/memory on named target hardware; ship signed platform builds after QA.

No analytics, external links, payment, tracking, online services or unimplemented menus are silently enabled.
