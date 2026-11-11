# CLAUDE.md - IRON STATIC: CINDERFALL

Godot 4.7.2 (statically typed GDScript), portrait, Mobile renderer (Vulkan). A 3D top-down defense slice: the
Warden holds Relay Core B-4 against five waves. Project root `C:\dev\tower-two` (Git Bash `/c/dev/tower-two`). The
original game at `C:\dev\tower` is read-only reference; never read `secrets.local.json`, `C:\dev\keys` or any keystore.

## Doc map

| What | Where |
|---|---|
| Rules and numbers (source of truth for the game) | `docs/GAME_DESIGN.md` (GDD) |
| Contracts: classes, signatures, signals, paths, schemas (source of truth for technology) | `docs/ARCHITECTURE.md` (ARCH) |
| Tasks, ownership, acceptance | `docs/WORK_PLAN.md` |
| Handoff package (data baselines, references, QA plan) | `docs/handoff/` (Godot ignores it via `.gdignore`) |
| Wave 0 contract fixes | `docs/reports/W0_CONTRACT_CHANGES.md` |
| Reports of every task | `docs/reports/` |

If GDD and ARCH conflict, stop and report; do not guess.

## Rules for every task (WORK_PLAN section 1)

1. **Own only your paths.** Edit only the "Owned paths" of your task; everything else is read-only. Need a change
   elsewhere? Stop and report it ("needs owner").
2. **Contracts are frozen.** Signatures, signal names, field names, file paths and JSON schemas of ARCH do not change.
   `tests/unit/core/test_contracts.gd` enforces them; never edit it.
3. **Never edit** `project.godot`, `export_presets.cfg` (except its owner), `src/shared/**`, `src/content/defs/**`,
   `src/sim/sim_world.gd`, `src/sim/stores/**`, `src/core/event_bus.gd`, `src/core/main.gd`, `src/game/run_api.gd`,
   `src/view/battle_view.gd`, `tools/**` (except the owner), unless your task lists the file.
4. **Verify with the wrappers, never with raw Godot.** Headless Godot can exit 0 after an error. A check passes only
   when the command exits 0 **and** prints the stated last line.
5. **Unit tests use frozen data:** `TestContent.baseline()` (`tests/fixtures/test_content.gd`, reads
   `tests/fixtures/data_baseline/`). Never assert on values from `res://data/`; they get tuned in Wave 2.
6. Typed GDScript, warnings are errors. No `class_name` that clashes with an autoload (`Log`, `Events`, `Content`,
   `Save`, `Sfx`, `Game`). Do not name a variable `set`, `seed`, `name` or `position` where it would shadow a member
   or global.
7. Write files with the Write tool (UTF-8, no BOM, LF, tabs in `.gd`). A `.tscn` is a root node plus its script and
   nothing else unless the task says so; build children in code.
8. Do not pass `-d` to Godot. Do not run two Godot processes on the same checkout at once.
9. Only the task that says so may use the Android emulator (one shared device).
10. Report with `docs/handoff/05_AGENT_PROMPTS/REVIEW_TEMPLATE.md`: files changed, decisions, every command run with its
    exit code and last line, screenshots, known defects. Never report a check you did not run. Checks not run on a
    physical device are **NOT RUN**.

## Commands (PowerShell 5.1; call from Git Bash as shown; replace the root with your worktree root)

```
# Full gate: layer lint + import + compile (warnings as errors) + all tests. Pass = exit 0, last line "CHECK OK".
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\check.ps1

# Scoped tests. Pass = exit 0, last line "TEST SUMMARY: tests=N failures=0 errors=0 skipped=S exit=0", N > 0.
# Several paths: comma separated in ONE argument (works from Git Bash and from PowerShell).
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\test.ps1 -Path res://tests/unit/sim_nav
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\test.ps1 -Path res://tests/unit/content,res://tests/unit/save
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\test.ps1 -Suite test_formulas
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\test.ps1 -Canary      # prints CANARY OK

# Desktop screenshot through the real renderer (opens a window briefly). Pass = exit 0, "CAPTURE OK <path>".
# From Git Bash write -Out with FORWARD slashes (backslashes are eaten by bash).
powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two\tools\capture.ps1 -Scene res://src/debug/view_sandbox.tscn -Out C:/dev/tower-two/build/shots/view.png -Size 1080x2400
```

Godot CLI: `C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe` (pin: `tools/GODOT_VERSION`). Python: `py -3.12`.
`py -3.12 tools/lint_layers.py` runs only the layer lint (also part of `check.ps1`).

### Parallel worktrees

Wave tasks run in separate git worktrees (`C:\dev\tower-two-wt\<ID>\`, branch `task/<ID>`). The tools resolve the
project root from their own location and write only under that checkout's `build/` (gitignored). `APPDATA` is
redirected to `build\test_appdata` / `build\capture_appdata`, so editor settings, caches and `user://` are never
shared. A timeout kills only the process tree the tool started, never Godot by name. Keep that if you add tooling.
Each checkout needs its own first import (the wrappers do it): `.godot/` is not shared.

## Layering (ARCH 2, enforced by `tools/lint_layers.py`)

| Layer | Path | May depend on | Must not contain |
|---|---|---|---|
| shared | `src/shared/` | nothing | `extends Node`, autoload names, `randf`, `randi`, `Time.`, `OS.` |
| content defs | `src/content/defs/` | shared | same as shared |
| **sim** | `src/sim/` | shared, content defs | `extends Node`, `Engine.`, `OS.`, `Time.`, `Input`, `get_tree`, `randf(`, `randi(`, `randomize(`, the words `Events.` `Log.` `Content.` `Save.` `Game.` `Sfx.` |
| content, save | `src/content/`, `src/save/` | shared, defs | UI or view classes |
| game | `src/game/`, `src/core/` | everything below | - |
| view | `src/view/` | shared, defs, sim (**read only**), `Events` | any write to sim state |
| ui | `src/ui/` | shared, defs, `RunApi`, `Events`, `Save`, `Content` | `SimWorld` (the UI never touches the sim) |
| audio | `src/audio/` | shared, `Events`, `Save` | sim access |
| debug | `src/debug/` | anything | - |

Also: the sim is pure `RefCounted`; one writer per sim field (ARCH 6.6); numbers come from `data/*.json` through
`ContentSet`; player text comes from `Strings.t(key)`; files stay under 400 lines; one class per file.

## What Wave 0 left for you (stubs and conventions)

- Every system (`SpawnSystem`, `MovementSystem`, `Targeting`, `DamageResolver`, `WeaponSystem`, `TurretSystem`,
  `CoreAttackSystem`, `CommandSystem`, `EconomySystem`, `AbilitySystem`, `PhaseSystem`), `NavState`, `CombatState`,
  `PhaseState`, `FlowField`/`ArenaGrid`/`SpatialHash`/`AttackSlots`, `Replay`, `PolicyBot` is a stub marked
  `# TODO(<task id>)` that does nothing and returns neutral values (`Reason.Id.WRONG_STATE`, `0`, `false`, `-1`).
  `SimWorld.step()` is complete, so a world with stubs only advances `tick`; `phase` stays PREPARING until
  `PhaseSystem` is real. `PhaseSystem.init_world` is where PREPARING gets `prepare_ticks`.
- `SimWorld.command_queue: Array[SimCommand]` holds submitted commands; `CommandSystem.apply_queued` must consume it,
  set `cmd.tick`, and append to `command_log.entries`. `SimEvents.current_tick` is set by `step()`.
- `SimWorld.upgrade_cost` is implemented (and `EconomySystem.cost` delegates to it); purchases and the rest of the
  economy are W1-C. `add_scrap` handles debits too (`add_scrap(-cost)`).
- `FakeRunApi` (src/debug) keeps query state in `fake_*` vars (see its header comment), records commands in
  `calls`, and emits the matching `Events` signals. Use `set_scrap`, `set_core`, `clear_calls`.
- `SimPuppet` + `view_sandbox.tscn` give the view a live, fake battle: `--scenario=hold<N>` or `boss` (user args
  after `--`). Capture runs read the same flags.
- `MatLib`, `MeshBuilder`, `MeshKit`, `VisualQuality`, `CameraFit`, `CameraRig`, `UiTheme`, `UiKit`, `SafeArea`,
  `HudLayout` work (basic versions). `ArenaView`, `ActorLayer`, `VfxLayer` are minimal stubs for W1-E/W1-F.
- `ObstacleDef.contains` rotates a box by `rot_deg` as `world = (lx*cos - lz*sin, lx*sin + lz*cos)`; attack-slot angle 0
  points along +X and positive angles turn toward -Z. `MeshBuilder.quad` lies in the XZ plane facing +Y.
- `Game.boot` logs `game boot version=<v> renderer=<method>/<driver>` (e.g. `mobile/vulkan`) and `boot ok`.
  `RendererInfo.current()` gives the same string; `mobile/vulkan` is the expected value on desktop and Android.
- Each `.gd` has a committed `.gd.uid`, each imported asset a `.import`: commit them with your files (Godot makes them).
- Parameter names differ from ARCH in a few places only where `shadowed_variable` (an error) forbids the ARCH name;
  see `docs/reports/W0_CONTRACT_CHANGES.md`.

## Gotchas (inherited from the original project; one line each)

- Headless Godot can exit 0 after an error: never judge by exit code; the wrappers parse output (ANSI stripped) and
  the JUnit XML. Never pass `-d`: on a script error the debugger waits on stdin and the run hangs.
- Warnings-as-errors print as `Parse Error: <description> (Warning treated as error.)`. Typed everything:
  `untyped_declaration`, `unsafe_*`, `integer_division`, `narrowing_conversion`, `shadowed_variable` are errors;
  `return_value_discarded` and `inferred_declaration` only warn.
- Variant-to-typed: passing `dict[k]` or `arr[i]` straight to `int()`/`float()` or a typed parameter fails
  `unsafe_call_argument`; assign to a typed local first (`var x: float = d["k"]`). `x.call(...) as T` trips
  `unsafe_cast`: assign to a `Variant` first.
- `int / int` is an error (`integer_division`): use `floori(float(a) / float(b))`. Hex literals above
  `0x7FFFFFFFFFFFFFFF` overflow. `>>` is arithmetic on a signed 64-bit int: mask after shifts in hashes.
- A parameter named like a member or method (`id`, `capacity`, `name`) shadows it (error): rename the parameter.
- `const X: PackedStringArray = PackedStringArray([...])` is not a constant expression; write
  `const X: PackedStringArray = ["a", "b"]`.
- A Control already in the tree needs `set_anchors_and_offsets_preset`, not `set_anchors_preset` (the latter keeps the
  current 0x0 rect and a full-rect overlay collapses to the top-left corner).
- `build/` and `docs/handoff/` keep a `.gdignore` (nested `project.godot` copies and PNGs would otherwise be scanned).
  `data/` must NOT have one (runtime JSON). Every checkout's `build/` is gitignored.
- The console exe can hang after exit when its output is piped; the PowerShell tools start the plain
  `Godot_v4.7.2-stable_win64.exe` and the Python tools pipe the console exe with a timeout and tree kill.
- Run the PS tools from a normal drive path, not a `\\wsl$` UNC path. From Git Bash pass paths to `-Out` with forward
  slashes. `adb exec-out screencap` also fails from a UNC working directory (use `C:\`).
- PowerShell 5.1 `Set-Content -Encoding utf8` writes a BOM: use the Write tool or `Write-Utf8NoBom`.
- Export converts text resources and drops non-`@export` script vars of `Resource` scripts; this project reads JSON into
  `RefCounted` defs instead (ARCH D4), and `export_presets.cfg` includes `data/*.json, data/strings/*.json`.
- Per-instance MultiMesh data is unreliable on some PowerVR phone GPUs: keep MultiMeshes transform-only (ARCH 8).
- GdUnit4 6.2.3 needs `--ignoreHeadlessMode`; its test classes should stay under 20 public test methods.
- Never write secrets, keystores or real ad ids into tracked files; `.gitignore` excludes `secrets*.json`, keystores,
  `*.apk`, `*.aab`.
- Every task's `class_name`s land in ONE project when the worktrees merge. Test helper classes (kits, fixtures, fakes)
  must carry a name unique to your task or suite (`CombatHudTestKit`, not `CombatTestKit`): two branches that were each
  green alone broke the compile gate at the Wave 1 merge over a duplicate `class_name`. Check with
  `git grep -n "^class_name <Name>"` on `main` before you choose a name.
- Mobile (Vulkan) renderer: `GeometryInstance3D.transparency` has no effect on `MeshInstance3D` or
  `MultiMeshInstance3D`. Fade or dim with material alpha instead (shared, pre-dimmed materials for pooled effects).
- `SpawnSystem.begin_wave(world, n)` takes the 1-based wave number (the same value as `world.wave` and
  `WAVE_STARTED.a`); content wave `n` is `content.waves[n - 1]`.
