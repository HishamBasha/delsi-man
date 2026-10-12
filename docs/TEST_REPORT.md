# Verification — 2026-09-28

Engine: Godot 4.5.1 stable, Linux x86_64, headless.

Passed:

- Editor project import/script compilation.
- Scene initialization and ordinary menu startup.
- Data loading: five flavors, six sections, 400 registered course objects.
- Continuous steering bounds, jump simulation, Apple double jump, cooldown rejection.
- Cola acceleration, Orange float jump, Ginger collision immunity, Pomegranate nearby-road collection.
- Ordinary collision damage; checkpoint restoration without awarding collected bottles twice.
- Best-score/time record comparisons.
- Complete accelerated simulation through every section, checkpoint and finish.
- UI state refresh after the simulated finish.
- Compiled PCK export and subsequent packed-game test (see delivery verification).

Not verified: GPU rendering/screenshot review, actual human playthrough, real controller/touch devices, audible mix, Arabic glyph/layout review, performance/frame rate, signed native exports, mobile/web exports, app-store compliance.

Environment warning: the sandbox does not expose `/proc/self/exe`; Godot falls back to argv[0]. No script errors were reported in the passing runs.

Visuals are procedural stand-ins, the vehicle segment is cosmetic, and the chase does not yet impose a pursuer-collision fail state. This report is deliberately narrower than the long-term production brief.
