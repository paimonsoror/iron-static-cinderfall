# W0-S contract changes

Every place where the Wave 0 scaffold departs from the letter of `docs/ARCHITECTURE.md`. The project copy and the
WSL copy of ARCHITECTURE.md were edited identically for section A (verified byte for byte with `cmp`).

## A. Changed in ARCHITECTURE.md (parameter names only; no type, return type, field, signal or path changed)

`project.godot` makes `shadowed_variable` an error (ARCH 1.1). A function parameter with the same name as a member
variable of its class therefore cannot compile. The smallest fix is to rename the parameter. GDScript has no named
arguments, so no caller can notice.

| Signature in ARCH | Was | Now | Clash |
|---|---|---|---|
| `ArenaDef.region` (5.3) | `region(id: StringName)` | `region(region_id: StringName)` | member `id` |
| `SimConfig.create` (6.3) | `create(content: ContentSet, run_seed: int)` | `create(content_set: ContentSet, seed_value: int)` | members `content`, `run_seed` |
| `SimCommand.purchase / ability / skip` (6.3) | `(command_id: int, ...)` | `(command_id_value: int, ...)` | member `command_id` |
| `PolicyBot._init` (6.7) | `_init(policy: int)` | `_init(policy_value: int)` | member `policy` (the bot keeps its policy in a var of that name) |
| `RunController.start` (7.3) | `start(config, run_id: String, view)` | `start(config, run_id_value: String, view)` | member `run_id` |

## B. Additive, ARCHITECTURE.md not changed (nothing removed, no existing signature touched)

| Addition | Why |
|---|---|
| `SimWorld.command_queue: Array[SimCommand]` | `submit()` needs somewhere to queue; `CommandSystem.apply_queued` consumes it (W1-C) |
| `SimEvents.current_tick: int` | `SimWorld.step()` sets it so pushed events carry their tick |
| `TurretStore._init(pad_count: int = 2)` | pad count from the arena data |
| `MeshBuilder.triangle_count()` | triangle budgets (WORK_PLAN section 6) and tests |
| `UiKit.stub_layout(root, title_key)` | shared by the Wave 0 stub screens |
| New helper classes: `JsonRead` and `ArenaBuilder` (`src/content/`), `ContentLoadResult` (named in ARCH 5.4), `ProfileDecodeResult` (named in ARCH 7.5 comments), `NavSystemHooks` (`src/sim/nav/nav_system_hooks.gd`), `RendererInfo` (`src/core/renderer_info.gd`) | keep files under 400 lines; ARCH named these classes but not their files |

## C. Interpretations of things ARCHITECTURE.md leaves open (decided once, here)

- `AbilityDef.duration_ticks` is 0 for EMP (instant; the stun lives in `stun_ticks` / `boss_stun_ticks`), 480 for shield, 360 for overdrive.
- `ContentLoader` does not depend on the sim layer (ARCH 2), so it keeps its own `TICK_RATE = 60` and rejects a
  mismatch with `sim_ticks_per_second`; a test pins it to `SimWorld.TICK_RATE`.
- The `content ok ... hash=` value is computed by `ContentDb` from the raw files (ARCH 5.4), not by the loader, so
  `ContentLoadResult` keeps exactly the two fields of ARCH.
- String keys: `mission.<id>.name`, `enemy.<id>.name`, `weapon.<id>.name`, `upgrade.<id>.name`, `ability.<id>.name`,
  `reason.<lowercase Reason name>` (= `Reason.string_key`).
- `ObstacleDef.contains` box rotation: `world = (lx*cos - lz*sin, lx*sin + lz*cos)`. `MeshBuilder.quad` lies in the XZ plane facing +Y.
- Boot line renderer name: `<RenderingServer method>/<driver>`, for example `mobile/vulkan`.
- `FakeRunApi` query state lives in `fake_*` variables (a var cannot share a name with its query method).
