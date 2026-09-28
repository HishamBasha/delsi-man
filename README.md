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
| Change lane | A/D or arrows | D-pad | Left/right buttons |
| Jump | Space / W / Up | A | Jump |
| Slide | S / Down | B | Slide |
| Power | E / Shift | X | Power |
| Select flavor | 1–5 | UI focus navigation | Flavor buttons |
| Pause/resume | Esc / P | Start | Pause |
| Retry checkpoint | R | UI button | Checkpoint |

## Implemented

- One 1,800m course with six sections; approximately 2–3 minutes per clean run, longer with retries. **Not yet the proposed 10–12 minute authored level.**
- Three-lane automatic running, interpolated lateral movement, jumping, sliding, obstacle collisions, recovery, checkpoint retries.
- Cola speed/barrier power; Apple double/super jump; Orange float jump; Pomegranate magnet; Ginger temporary hazard immunity.
- 400 obstacle/collectible entities, deterministic course layout, five checkpoints plus start, score/combo/coldness, finish screen.
- Cosmetic delivery-cart riding segment and visible pursuing cart train. Vehicle physics and interactive chase pressure are not yet implemented.
- Keyboard, D-pad/controller buttons, onscreen touch controls.
- English interface with partial Arabic translation and RTL menu. Full localization/accessibility QA remains.
- Assist mode: reduced speed and collision protection.
- Generated sound cues with mute toggle.
- Persistent versioned best score/time, language and assist settings; atomic save-file replacement.
- Original procedural art, runner animation, lit streets, color-coded product stand-ins; distance culling.

## Brand/art status

The referenced user artwork was not available as an actual attachment. **All logos, packages, hero geometry and environments here are procedural stand-ins, not official Delsi artwork.** The display text is not a traced logo. Five flavor names are provisional, pending brand approval. Replace the `Art` factories or their products with approved scenes/materials. Do not publish as an authorized brand game before approvals.

## Project map

- `scripts/runner.gd`: movement and ability simulation; independent of course geometry.
- `scripts/course.gd`: deterministic course builder, entity registry, culling, checkpoint restoration.
- `scripts/art.gd`: replaceable original procedural art factories and materials.
- `scripts/profile.gd`: versioned progress and atomic persistence.
- `scripts/game.gd`: game state, UI, input setup, collision evaluation, audio, orchestration and smoke tests.
- `data/flavors.json`: stable flavor IDs, colors, copy and ability durations.
- `data/level_01.json`: stable level ID, length, speed and chapter boundaries.

The course factory still contains its 1,800m layout constants; changing JSON length alone does not author a new course. Ability implementations currently use five indexed behaviors. Next refactor: ability strategies keyed by stable flavor IDs, and authored section resources. Data-driven metadata is implemented; unlimited behavior extensibility is not claimed.

## Verification

Run: `godot --headless --path . -- --test`

Tests exercise movement, lane limits, jumps, cooldown, all five abilities, collision damage, checkpoint pickup deduplication, best-record comparisons, full-course completion and UI updates. They do not claim GPU performance, visual approval, device certification, or real-world controller/touch testing. Test mode does not write your profile.

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
2. Separate collision/scoring/UI into tested components; ability strategies; declarative section assets and authoring validation.
3. Author a 10–12 minute course with actual branches, elevated paths, contextual traversal, moving hazards and interactive chase/vehicle mechanics.
4. Finish localization, remappable inputs, controller focus flow, accessibility and scalable layouts.
5. Add authored cinematics, music, VFX, balancing, difficulty-specific records, time trials and photo mode.
6. Profile GPU/CPU/memory on named target hardware; ship signed platform builds after QA.

No analytics, external links, payment, tracking, online services or unimplemented menus are silently enabled.
