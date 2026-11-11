# Agent work orders and gates
## P0 Audit + foundation
Inspect upstream repository, licenses, lore, engine/toolchain; create isolated project, document findings, setup CI/test harness, Android portrait export. **Gate:** project imports headlessly, blank APK builds if Android toolchain available; report blockers instead of inventing success.

## P1 Deterministic combat kernel
Implement state machine, 60Hz clock, seeded RNG, stable enemy IDs, core HP, targeting, pistol/SMG firing and reload, damage/death/rewards. **Gate:** reproducible headless seeded replay and unit tests.

## P2 Continuous swarm arena
Implement high camera, fixed Warden, right/upper-right spawn regions, pathing/steering and local separation, spatial indexing, 50 active cap and pending spawn queue, stuck diagnostics. **Gate:** 50 enemy simulation stress test; visible debug paths; no deadlocks or silent despawns.

## P3 Economy and wave content
Import five-wave schedules, 4 archetypes, upgrade transactions, two turrets, EMP/shield/overdrive. Tune with deterministic balance simulator. **Gate:** five waves completable, win/loss reproducible, target peaks measured, no duplicate rewards.

## P4 UI, persistence and flow
Menus, briefing, combat HUD, upgrade drawer, intermissions, pause, results, profile save and backup. **Gate:** complete offline end-to-end run and save/relaunch on desktop and Android emulator/device if available.

## P5 Art pass
Model/rig Warden, enemies, boss, turrets, relay, industrial environment; lighting, particles, UI theme, SFX. **Gate:** screenshot review matches approved top-down reference and palette; silhouettes readable with 50 enemies; no baked-in HUD.

## P6 Android optimization + release
LOD, pools, render scale, safe areas, thermal/long-run profiling, reproducible APK, release documentation. **Gate:** actual Android test report, 50 enemy benchmark, no critical functional regressions.

At each phase: commit/PR, files changed, commands and raw logs, screenshots, decisions, issues, rollback. Do not proceed to next phase without reporting gate status.
