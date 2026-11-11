# Handoff review - IRON STATIC: CINDERFALL build package v2.0

Reviewed 2026-11-10. Package: `IRON_STATIC_CINDERFALL_BUILD_AGENT_PACKAGE_v2.zip`, extracted to
`tower-two/handoff/IRON_STATIC_CINDERFALL_AGENT_PACKAGE_v2/`. All 26 files were read; all five PNGs were viewed.
The original game was reviewed read-only at `C:\dev\tower` (commit `1dfe166`, version 0.5.2-beta.1).

## 1. What is in the zip

| Folder | Files | Content |
|---|---|---|
| root | `README.md`, `MANIFEST.json` | Start order, precedence rule, scope, SHA-256 list |
| `00_START_HERE` | `AGENT_MASTER_PROMPT.md`, `DECISION_LOG.md` | The brief and the binding decisions (camera, no lanes, density, lore, weapons, pause rules) |
| `01_PRODUCT_AND_LORE` | `GAME_DESIGN.md` | Pitch, loop, composition, agency, enemy behavior, wave arc, roadmap (about 2.7 KB) |
| `02_TECHNICAL` | `ARCHITECTURE.md`, `INTERFACES_AND_EVENTS.md`, `ANDROID_BUILD.md`, `ART_DIRECTION.md` | Proposed tree, determinism, movement, targeting, formulas, persistence, UI, performance; data contracts, signals, commands, states |
| `03_DATA` | `vertical_slice_balance.json`, `waves.json`, `visual_tokens.json`, `README.md` | Balance baseline (schema 2), five wave schedules, palette and UI fractions |
| `04_VISUAL_REFERENCES` | 5 PNGs + `REFERENCE_INDEX.md` | `topdown_approved` (primary), `environment_mood`, `enemy_roster`, `armory_style`, `user_camera_inspiration` |
| `05_AGENT_PROMPTS` | `PHASE_TASKS.md`, `REVIEW_TEMPLATE.md` | Phases P0 to P6 with gates; report template |
| `06_QA_AND_RELEASE` | `ACCEPTANCE_MATRIX.md`, `TEST_PLAN.md`, `KNOWN_RISKS.md`, `ASSET_MANIFEST.csv` | A01 to A20, test layers, seven risks, 13 assets all "missing" |
| `07_SOURCE_CONTEXT` | `LEGACY_TECH_SPEC_v1.md` | Superseded v1 spec (three lanes, smaller waves) with useful detail not repeated in v2 |

The package is a design contract, not a build. It states that no test, build or performance result is claimed.

## 2. Gaps and contradictions inside the handoff

| # | Finding | Resolution used in our docs |
|---|---|---|
| 1 | v1 spec has three lanes, 12 to 25 enemies per wave; v2 has a continuous arena and 16 to 103 | v2 wins by the stated precedence |
| 2 | `INTERFACES_AND_EVENTS.md` says "typed `Resource` for authored data"; `03_DATA/README.md` says the JSON is not `.tres` and may be loaded through a strict adapter | JSON through a strict adapter (ARCH D4) |
| 3 | Contract fields with no data: `EnemyDef.collision_radius`, `visual_scene`; `WeaponDef.pierce`; `SpawnGroup.seed_offset`; `WaveDef.intermission_seconds`; `AbilityDef.effect` | `content_ext.json` supplies radius and behavior; the rest are dropped or derived (ARCH D5) |
| 4 | No arena data at all: bounds, core and Warden positions, turret pads, spawn polygons, obstacles, attack-slot layout | New `arena.json` (ARCH 5.2), all values are our assumptions |
| 5 | Ability rules exist only in the legacy spec: cooldown start, EMP non-stacking, 5 s boss immunity, "fails cleanly" | Adopted from the legacy spec (GDD A5, A6) |
| 6 | SMG timing: legacy "available after wave 1", v2 "W2 unlock SMG", JSON only `unlock_scrap: 300` | Purchasable from wave 2 (GDD A1) |
| 7 | Turrets: positions, whether upgrades or Overdrive affect them, lock time: not stated | Pads in `arena.json`; only armor piercing applies (GDD A3) |
| 8 | Targeting order puts "Rusher class" after "minimum ETA"; with exact ETA the Rusher rule almost never fires | ETA compared in 0.5 s buckets (GDD A8) |
| 9 | Cost formula `round(base * growth ** level)` hits a floating-point edge: 175 x 1.7 = 297.4999... which naive rounding turns into 297, not 298 | `floor(x + 0.5 + 1e-9)` with a golden table (ARCH 6.5) |
| 10 | 0.68 s spawn interval is not a whole number of 60 Hz ticks | Rounded to 41 ticks (GDD A12) |
| 11 | Peak-alive targets (10/18/28/40/50) do not follow from the schedules. Wave 1: one Skitter per 1.7 s against a kill about every 1.1 s gives about 2 or 3 alive, not 10 | Planned tuning task W2-D; the package itself flags this as the top risk |
| 12 | Balance oddities: SMG does 3 damage per shot to the Hulk (armor 12) against the pistol's 18, and the swap is irreversible; a shield of 100 is about one Hulk hit; 50 attackers would deal about 400 core damage per second | Left as data; W2-D reports and tunes |
| 13 | `topdown_approved.png` contradicts binding text: core labelled "ASH-07", a T1 to T5 weapon strip, a DATA counter in combat, prices that differ from the JSON | Image text is non-binding per `REFERENCE_INDEX.md`; GDD 12.2 lists what to ignore |
| 14 | `environment_mood.png` shows a cyan core; the palette says the core is amber | Amber |
| 15 | Architecture names `tools/*.sh`; the build host is Windows | PowerShell and Python wrappers (ARCH D10) |
| 16 | Master prompt says to inspect the GitHub repo and create a sibling repo `iron-static-cinderfall` | Local original at `C:\dev\tower` inspected; project at `C:\dev\tower-two` (coordinator decision); remote name is open |
| 17 | A02 and A18 require a physical device; only the `tower_phone` emulator is set up | Reported as emulator-only; physical NOT RUN unless a phone is attached |
| 18 | "Mobile renderer" is specified, but Vulkan is unproven on the only test target (the `tower_phone` emulator) | **Resolved 2026-11-11: owner chose Mobile (Vulkan).** W1-H must prove Vulkan on the emulator early (ARCH D1) |
| 19 | P5 asks for modelled, rigged characters and a cinematic art pass; the asset manifest lists every asset as missing with source "TBD" | Slice ships procedural placeholder-plus art; authored assets are post-slice (owner decision) |
| 20 | Defeat reward "10 x completed waves": "completed" is not defined | Waves fully cleared before the core fell |

## 3. Against the original IRON STATIC

**Carries over:** the world (2091, CHORUS, Orrery Combine, Hollow Accord, Lantern Cell, Warden class, `ASH-`
serials, the relay network), tone (terse machine logs, CHORUS lowercase counting lines, Accord radio
briefings), `scrap` and `data` as currency names, the `skitter` id and the hulk boss idea, the IP guardrails,
the fonts (Oxanium, Share Tech Mono, OFL), and engineering practice: Godot 4.7.2, pure deterministic sim
separated from the view, id tie-breaks, command log replay, GdUnit4 6.2.3 behind an output-parsing wrapper,
warnings as errors, the `tower_phone` emulator scripts, and a long list of Godot and Android gotchas.

**Intentionally different:** 3D orthographic yard instead of a 2D radial arena; enemies from two edges, not
all sides; a five-wave win/lose mission instead of an endless idle run; ballistic pistol and SMG instead of
a laser; 60 Hz instead of 30 Hz; no game-speed control; no meta progression, drafts, ads, billing or
backend; a second Warden defending a core, not Cinder on the Relay.

**Conflicts to resolve:**

| # | Conflict | Our handling |
|---|---|---|
| 1 | The original forbids "a chrome skull endoskeleton with glowing red eyes". `enemy_roster.png` and `environment_mood.png` show humanoid skull-faced machines with two red eyes | Enemies get one red optic slit or bar, no skull faces (GDD 2.4). Owner should confirm the look |
| 2 | The original's rating note says no real-world weapons or brands; `armory_style.png` says "9MM SERVICE PISTOL" | UI says "SERVICE PISTOL" and "SMG" |
| 3 | "Hollow" means the human vaults in canon; "Hollow Warden" is an enemy | Kept (binding decision); explained in the briefing; flagged |
| 4 | Canon has "Relay six"; the handoff introduces "Relay Core B-4" and a "Breach of Cinder" | Proposed tie-in: B-4 is a booster core in the Quiet Yards feeding Relay six. Marked as proposed canon |
| 5 | The original's HUD palette is amber primary, teal friendly, red hostile, magenta enemy fire; Cinderfall is cyan, amber, red with no magenta | Cinderfall tokens win for this game; roles are compatible |
| 6 | The original project has no license ("all rights reserved"); the handoff says to audit before reuse | We reuse only: GdUnit4 (MIT), the two OFL fonts, and the owner's own tool scripts as patterns. Needs the owner's nod since both projects are theirs |
| 7 | The original uses the Compatibility renderer and found per-instance MultiMesh data unreliable on a PowerVR phone | Cinderfall uses Mobile (Vulkan) but keeps the conservative pattern: transform-only MultiMeshes and a material-swap hit flash |

## 4. Risks

From `KNOWN_RISKS.md`, with our mitigation:

| Risk | Mitigation in the plan |
|---|---|
| 50-enemy density vs five-minute duration | W2-D balance runner and tuning before any visual tuning; targets in GDD 8.4 |
| 50 agents on mobile | Pure sim with flow field, spatial hash, capped separation; pooled views; budgets in ARCH 13; `[PERF]` soak in W4-A |
| Camera angle from a non-orthographic concept | `CameraFit` computed and unit-tested for four aspect ratios; captures reviewed in W1-E and W3-B |
| Canon ambiguity | All lore text in one strings file; label fixed as RELAY CORE B-4; open questions Q1 to Q3 |
| Engine compatibility | Verified locally: Godot 4.7.2 and GdUnit4 6.2.3 already work together in the original; no plugins used here |
| Concept art is not deployable | Procedural art only; a grep check that no reference PNG is used; `docs/handoff/.gdignore` |
| Accessibility of tiny enemies | Blob shadows, emissive optics, silhouette ratios tested, high-contrast and reduced-flash modes |

New risks we see:

| # | Risk | Mitigation |
|---|---|---|
| N1 | **Expectation gap on visuals.** The brief says "cinematic realistic"; code-built primitives will look like a clean prototype, not the concept art | State it up front (decision 2 below); A17 remains an owner review |
| N2 | **3D on the emulator.** The original only proved 2D on the Intel-iGPU emulator; a 3D scene may be slow or misrender there | W1-H deploys a 3D scene in Wave 1, before any art exists; fallback `-gpu swangle_indirect`; a real phone via `-Serial` if available |
| N3 | **Parallel agents in one working tree** break each other's compile gate and fight over `.godot/` and `user://` | One git worktree per task; `test.ps1` redirects `APPDATA`; one emulator user per wave |
| N4 | **Headless Godot exits 0 on errors**, and the console exe can hang when piped | All verification goes through wrappers that parse output; non-console exe for imports; timeouts with process-tree kill |
| N5 | **Vulkan on the emulator and low-end phones.** The owner chose Mobile (Vulkan); it is unproven on `tower_phone` and can bring shader-compile hitches and driver bugs | W1-H validates it in Wave 1, before any art exists. `fallback_to_opengl3` is a crash safety net only. The look sticks to features both renderers share (emissives, additive quads, material swaps) |
| N6 | **Android 16+ ignores the portrait lock on large screens** (foldables), seen in the original | HUD and camera fit are tested at 1080x1120 as well |
| N7 | **Data files not packed into the APK** (the original lost a day to this with `.gdignore`d CSVs) | `include_filter` for `data/*.json`, an APK content check and a `content ok` log check in the smoke test |
| N8 | **Tuning changes break unit tests** | Unit tests read a frozen baseline copy in `tests/fixtures/data_baseline/` |
| N9 | **Swarm reaching the core is instantly lethal** (hundreds of damage per second), which may make abilities feel irrelevant | W2-D measures; levers are core damage, attack periods and slot count |
| N10 | **Scope of Wave 0.** Everything depends on one large scaffold task | Its acceptance includes a contract test that later tasks cannot weaken |

## 5. Decisions that need the owner

1. Renderer: **decided 2026-11-11, Mobile (Vulkan)**.
2. Art bar for the slice: procedural placeholder-plus (recommended) or authored models before calling it done.
3. Lore: defender designation (default ASH-12 "Flint"), the event name, the Hollow Warden name, the B-4 tie-in.
4. Enemy faces: single red optic instead of the skull-and-eyes look in the concept art (recommended).
5. Reuse of the original's tool scripts, fonts and vendored GdUnit4: **decided 2026-11-11, yes as planned** (gameplay code written fresh).
6. Package id `com.normalexception.games.cinderfall.dev`. Git: **decided 2026-11-11, a local repo with a worktree per task and local commits at wave merges; no remote, never push**.
7. Whether a physical phone will be available for A02 and A18.
