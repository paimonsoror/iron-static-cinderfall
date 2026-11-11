# IRON STATIC: CINDERFALL

A portrait, 3D top-down defense slice for Android, built in Godot 4.7.2 (statically typed GDScript, Mobile renderer
on Vulkan). The Warden holds Relay Core B-4 against five waves of CHORUS machines. Everything is generated in code:
meshes, materials, UI, audio. The only imported assets are two OFL fonts.

Status: Wave 0 scaffold. All contracts exist as compiling code; the sim systems, the real HUD and the screens are
stubs that the next waves fill in.

## Run the gate

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check.ps1        # import + compile + layer lint + tests -> "CHECK OK"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\test.ps1 -Path res://tests/unit/core
powershell -NoProfile -ExecutionPolicy Bypass -File tools\test.ps1 -Canary # proves the wrapper detects failures -> "CANARY OK"
powershell -NoProfile -ExecutionPolicy Bypass -File tools\capture.ps1 -Scene res://src/debug/view_sandbox.tscn -Out build\shots\view.png -Size 1080x2400
```

Requires Godot 4.7.2 at `C:\dev\tools\godot\4.7.2\` and Python 3.12 (`py -3.12`). The tools resolve the project from
their own location, so they work unchanged in a git worktree.

## Where to read

- `CLAUDE.md`: rules, commands, layering, gotchas.
- `docs/GAME_DESIGN.md`: rules and numbers. `docs/ARCHITECTURE.md`: contracts. `docs/WORK_PLAN.md`: tasks and acceptance.
- `docs/handoff/`: the original handoff package (data baselines, references, QA plan).
- `docs/reports/`: evidence and reports.

Third-party: GdUnit4 6.2.3 (MIT, `addons/gdUnit4/`), Oxanium and Share Tech Mono (SIL OFL 1.1, `assets/fonts/`).
