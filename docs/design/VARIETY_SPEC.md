# IRON STATIC: CINDERFALL - Variety milestone: full design and technical specification

Version 0.1 (proposal), 2026-11-11, task V0, written against `main` at `74011e6`. Nothing in this document is built. Read order: `VARIETY_PITCH.md` (owner summary and the 8 decisions), this file (rules, contracts, plan), `VARIETY_CONTENT.md` (every id and first-pass number; cited as CONTENT n). GDD = `docs/GAME_DESIGN.md`, ARCH = `docs/ARCHITECTURE.md`, WP = `docs/WORK_PLAN.md`.

Split of duties: this file states **rules and contracts**; CONTENT holds the **tables a build agent transcribes**. When a number appears in both, CONTENT wins. Every number is a first-pass value that the balance task (V5-C) must confirm with deterministic runs; none has been simulated. The spec assumes the recommended option of each decision D1 to D8 (section 18.1); where another option would change the design, the section says so.

---

## 0. What the repository says today, and where it contradicts the request

Checked in the files, not assumed:

| # | Fact (source) | Consequence for this design |
|---|---|---|
| F1 | The only sim randomness is spawn jitter: `SimRng` has the streams `spawn` and `steer` (ARCH 6.1, `src/sim/sim_rng.gd`); BALANCE_REPORT section 2: "Seeds change only the spawn-position jitter" | The predictability is structural. New randomness must add streams, not reuse these two (their draw order is pinned by existing hashes) |
| F2 | `SimRng.stream(name)` creates a stream on first use from `hash("<seed>|<name>")` and hashes every stream state | Indexed streams such as `draft:7` need **no contract change** |
| F3 | `Replay.run(config, log, max_ticks)` re-simulates from tick 0 (`src/sim/replay.gd`). Sim tick cost: 0.09 to 0.53 ms on the desktop at 50 enemies (BALANCE_REPORT 8); phone budget 1.0 ms, limit 3.0 ms (ARCH 13) | A full replay of a 15-minute run (about 50,000 combat ticks) is 5 to 27 s on the desktop and could be 50 to 150 s on a phone. Resume cannot be "replay everything" (section 2.8) |
| F4 | GDD 2.4: "Never use The Tower's terms (Cash, Coins, Workshop, Cards)" | The owner's "upgrade cards" cannot be called cards in the game. This spec uses **DIRECTIVES** in player text and "directive" in ids (decision D4). The meta screen is the **ARCHIVE**, never a workshop |
| F5 | GDD 9 and 12.2: the T1 to T5 weapon strip of `topdown_approved.png` is "explicitly not built"; handoff `DECISION_LOG.md`: other weapons are "future roadmap only" and "No Shieldbearer/Reclaimer until future scope" | This milestone **is** that future scope. Section 17 lists the GDD lines to reverse. The handoff decision log is read-only history; the owner's 2026-11-11 request supersedes it and should be recorded as a new binding decision |
| F6 | GDD 4.3: "no target tapping and no drag gesture" | Crates, strikes and freight are designed with **no tap on the battlefield**: everything is a HUD button or an intermission choice |
| F7 | GDD 8.4: "Never invulnerability or hidden scaling" | Act scaling is a visible "plating tier" printed on the act banner and the route screen |
| F8 | GDD 3: "No mid-run resume"; ARCH 7.5: "There is no mid-run save" | Changed by section 2.8 (a 15-minute phone run must survive process death) |
| F9 | GDD 6: "Arriving never removes an enemy" | Kept for bodied enemies. Minis (`mote`, `shard`) and the `burster` are the stated exceptions: they are consumed by their one hit |
| F10 | `EnemyPool.SIZES = [50, 24, 32, 2]` (108 pooled nodes, one `MeshInstance3D` each); pool exhaustion recycles the oldest **visual** (`src/view/actors/enemy_pool.gd`) | A living enemy could lose its visual. New rule: a per-type alive cap equal to the pool size, enforced in the sim's spawn queue (section 5.5) |
| F11 | `ActorMeshes.TRI_BUDGET[&"warden"]` is 2,500 and the Warden already uses 2,448 (pistol) and 2,472 (SMG) triangles (lookdev README) | A long weapon does not fit. Proposed: body budget 2,300 plus a separate weapon budget of 350 (section 12.2) |
| F12 | `ContentLoader.STRING_FILES` is a fixed list of four files; `ContentLoader.build` takes six dictionaries (ARCH 5.4) | New data files need a loader contract change (section 13.1) |
| F13 | `CombatState.SOURCES = 3`, `DamageSource.Id` has WARDEN, TURRET_0, TURRET_1 only | Blasts, strikes and the core's own damage need new source ids (append only) |
| F14 | The attack slots are 64 and the validator requires `slots >= enemy_cap + 2` (ARCH 5.4) | The bodied cap stays 50, so slots stay 64. Minis and standoff types take no slot |
| F15 | The brief's phone numbers (Pixel, PowerVR: LOW 60 fps, MID and HIGH about 56 fps with p95 about 30 ms at 50 enemies, about 137 draw calls and 40k primitives on HIGH) are **not in `docs/reports/`**: TEST_REPORT says no physical device was used and there is no `PERFORMANCE_REPORT.md` | Section 10 uses the brief's numbers as given and makes "record the phone baseline in the repo" the first perf task |

---

## 1. Goals, in measurable form

| Goal (owner's words) | What this design does | How we know (section 14) |
|---|---|---|
| "less predictable" | Five seeded sources of variance per run: the route (packs and modifiers), the drafts, the salvage, the events, the boss picks | Outcome spread across seeds, build diversity and "no dominant strategy" targets |
| "many more waves" | 15 waves in 3 acts, generated from packs and budgets, not scripted | Run length 13 to 17 minutes of combat for a win |
| "many more weapons" | 10 weapons with different firing kinds, 2 carried, found as salvage | No weapon is the primary of more than 30% of winning runs |
| "much more chaos on the screen" | Minis (up to 40 more bodies at about 4 draw calls), chain blasts, arcs, pools, strikes, freight, and tier-scaled cosmetic chaos | Phone frame budget held on LOW; effect pool caps |
| "suspense" | Every threat is telegraphed; route and boss previews; corrupted directives; contested crates | Loss is possible in every act; a competent bot wins 40 to 70% |
| "fair and readable on a phone" | Fairness rules (7.3), readability rules (5.6, 12.3), no battlefield taps, 2-tap choices | Legibility captures at 50 + 40 units; rule tests |

Non-goals of this milestone: new maps, a moving Warden, manual aim, online features, monetization, authored art or music.

---

## 2. Run structure

### 2.1 Shape

```
MENU -> (ARCHIVE | KIT select) -> BRIEFING -> DEPLOY 3 s
 ACT I   "THE YARD"         wave 1  2  3  4  [5 = boss, pool of 2]
 ACT II  "THE GANTRY LINE"  wave 6  7  8  9  [10 = boss, pool of 2]
 ACT III "CONSOLIDATION"    wave 11 12 13 14 [15 = NODE 9, 1 of 3 variants]
 -> VICTORY or DEFEAT -> RESULTS (Data once, build recap, seed) -> RETRY / SAME SEED / MENU

between waves:  WAVE CLEARED -> [SALVAGE, if a crate is banked] -> DRAFT (1 of 3) -> ROUTE (1 of 2) or BOSS BRIEFING
                -> BREATHER 3 s -> next wave
```

- 15 waves (decision D1). Budgets, windows, peak targets and act tiers: CONTENT 1.1.
- A wave ends as today: every scheduled spawn has entered and every living enemy is dead (minis included).
- Core at 0 = defeat at any moment (after `dead_mans_switch`, if held). Victory = wave 15 cleared.
- Wave 1 is fixed (`pack_tide`, no modifier, no event) so the first 30 seconds are always learnable. Everything after it comes from the run plan (section 9).

### 2.2 Timing and session length

| Item | Target |
|---|---|
| Normal wave, combat time | 35 to 55 s (the spawn window is 22 to 42 s; clearing the tail takes the rest) |
| Boss wave, combat time | 70 to 100 s |
| Whole run, combat time (a win) | 780 to 1,020 s (13 to 17 minutes) |
| Choice time between waves | Untimed. Expected 8 to 15 s per intermission, 14 intermissions: 2 to 3.5 minutes |
| Wall time of a win | 15 to 20 minutes |
| A loss | Possible from wave 3 on; the median loss of a new player should be in act I (4 to 6 minutes) |

The intermission is **untimed**: the phone can be put down. While a choice is pending the simulation does not advance (section 2.5), so thinking is never punished or rewarded.

### 2.3 Difficulty curve

Three levers, all visible to the player:

1. **Budget** per wave (CONTENT 1.1): 24 at wave 1 to 190 at wave 14. Today's tuned wave 5 is about 168 points in this scale, so the old final wave sits near the new wave 12 or 13 in body count.
2. **Act plating tier**: enemy HP x1.0 / x1.35 / x1.8 and core damage x1.0 / x1.15 / x1.3, announced on the act banner (`CHORUS PLATING: TIER II`). This replaces hidden scaling.
3. **Composition**: new types unlock by act (`min_act`), elites appear from wave 3, two affixes in act III.

Player power grows through 14 drafts, 2 to 5 crates, 2 boss crates and Scrap purchases. Expected (to be measured): a finished build deals 6 to 10 times the damage per second of the starting pistol, more against crowds.

### 2.4 The route choice

Before every normal wave except wave 1 the player picks one of two threats (11 choices per run). Each option shows: the pack (name, glyphs of the three main enemy types, total count), the modifier if any, the number of elites, the risk tag (STANDARD or HOT) and the reward. Rules and weights: CONTENT 1.2 to 1.4.

- Option A is normally standard, option B hot. A hot option is the same act budget x1.25 plus a modifier, and from act II one more elite. Its reward comes from the richer column.
- Both options of every wave are generated when the run starts (section 9), so what is shown is exactly what spawns, and a choice at wave 3 never changes what wave 7 offers.
- Boss waves have no route choice. They show a **boss briefing**: the boss picked for this run, its variant, one line on how it attacks and one on what stops it. With `u_f_boss_intel` the boss is already shown at the act start.

Why this creates suspense: the reward is known, the cost is partly known (the modifier and elites are shown; the event of the wave is not), and the core does not heal for free. A player at 45% core who takes `HOT: POWDER TRAIN + VOLATILE SWARM -> crate` is making a real bet.

### 2.5 Phase model (no new `GameState` value)

`GameState.Id` is frozen and stays as it is. The intermission gets sub-steps held in `PhaseState`:

```gdscript
# PhaseState additions (hashed)
enum Await { NONE, SALVAGE, DRAFT, ROUTE, BOSS_BRIEF }
var awaiting: int = Await.NONE
var act: int = 1                 # 1..3
var breather: bool = false       # true while INTERMISSION counts breather_ticks
```

| Step | Entered when | Left by | Timers |
|---|---|---|---|
| `SALVAGE` | Wave cleared and a crate is banked (repeats per crate) | `SALVAGE` command | frozen |
| `DRAFT` | After salvage (or directly at wave clear) | `PICK_DIRECTIVE` or `SKIP_DRAFT` (after any `REROLL`, `BUY_OUT`, `PATCH_CORE`) | frozen |
| `ROUTE` | After the draft, when the next wave is normal | `PICK_ROUTE` | frozen |
| `BOSS_BRIEF` | After the draft, when the next wave is a boss wave | `SKIP_INTERMISSION` (the CONTINUE button) | frozen |
| breather | After the last choice | `breather_ticks` (180) elapse, or `SKIP_INTERMISSION` | **running** (cooldowns recover as in today's intermission) |

Rules:

- While `awaiting != NONE` the sim treats a `step()` as "apply queued commands only": `tick` does **not** advance, no timer runs, no event is scheduled. (`SimWorld.step()` returns before `tick += 1` when awaiting and the queue is empty; when a command is queued it advances one tick, applies it, and stops again if still awaiting.) So the tick count of a run is a function of the seed and the decisions only, never of thinking time. Bots answer on the next tick.
- `RunController` keeps calling `TickDriver.advance`; it is the sim that refuses to move. The driver's accumulated time is consumed by steps that do nothing, so no burst of ticks follows a long choice.
- Wave-clear effects are applied before the first await: `rw_*` reward, `field_weld` repair, `compound_interest`, act-clear repair (+15%) after a boss.
- Abilities stay illegal outside SPAWNING and CLEARING (unchanged). `SWAP_WEAPON` is legal in the breather.

### 2.6 What a defeat and a victory give

Recovered Data: CONTENT 10. Summary: 6 per wave cleared, 30 and 45 for the act I and II bosses, 100 plus up to 50 for the victory, milestones once per profile. Granted exactly once per run id, saved before the results screen (unchanged rule). The results screen also gives, for free: the build recap, the seed, "what beat you" (the pack, modifier and top three damage sources against the core in the last wave) and a SAME SEED button.

### 2.7 Pause

Unchanged: the pause button, Android back and app backgrounding freeze the simulation, cooldowns and audio. The pause overlay gains a line with the run's seed and a BUILD button (the list of directives and weapons held).

### 2.8 Resume after the process is killed (evaluation and recommendation)

Options considered:

| Option | How | Cost | Verdict |
|---|---|---|---|
| A. No resume | Today's behaviour | A 15-minute run dies with a phone call | Rejected for this run length |
| B. Full replay | Save seed + command log; on launch call `Replay.run` from tick 0 | No new serialisation, but replay time grows with the run: up to 50 to 150 s on a phone at minute 14 (F3) | Rejected as the main path; kept as the test oracle and last-resort fallback |
| C. Serialise the whole world | Dump every store, nav state, hazards, RNG states mid-wave | Largest surface for bugs: about 20 state classes with live enemies, slots, queues | Rejected |
| **D. Boundary snapshot + command tail** | At each wave clear the world is almost empty (no enemies, no hazards, no pending spawns). Save that small state, then replay only the commands since | A `to_dict` / `from_dict` per state class, exercised only at a boundary; tail replay is at most one wave (about 2,400 to 6,000 ticks) | **Recommended** (decision D7) |

Design of D:

- File `user://run_v1.json` (+ `.tmp`, `.bak`; same atomic write as the profile). Schema: section 13.3.
- Written (1) at every wave clear: the boundary snapshot, its `state_hash`, an empty tail; (2) after every intermission command: the tail grows; (3) when the app is paused or backgrounded (`MobileShell` already calls `Save.flush()` there): the tail including this wave's commands and `resume_tick`.
- On launch, if the file exists and matches the build and the content hash, the menu shows **RESUME RUN (WAVE n)**. Resume = restore the snapshot, verify `state_hash`, re-submit the tail with `Replay`-style stepping up to `resume_tick`, show the pause overlay. If the process died without a pause notification (a crash) there is no `resume_tick`: the run resumes at the last recorded choice and the current wave starts again.
- If the hash check fails, fall back to option B with a progress bar; if that fails too, or the build or content changed, the run is closed and paid as a defeat at the last saved wave (CONTENT 10). The file is deleted when the run ends.
- Not an exploit: the tail replays the same commands on the same seed, so the player lands in the same state. Only the crash path gives a wave back, and it gives it back identical.

---

## 3. Weapons

Numbers: CONTENT 2. The Warden still never moves and never needs aiming; weapons change **what the automatic fire does**.

### 3.1 Carrying and swapping (decision D3)

- The Warden carries **2 weapons** (3 with `u_f_third_sling`). One is active; the other is holstered on its pack.
- The weapon bar (section 11.4) shows both. **Tap the holstered weapon to swap.** Swap takes 0.4 s with no fire.
- Each slot keeps its own magazine or heat. A holstered weapon reloads at half speed and cools at full speed, so swapping at an empty magazine is a real technique ("swap instead of reload").
- The pistol never leaves the game: a kit always starts with it, and if the player scraps down to one weapon the empty slot shows the pistol.
- There is no automatic swap in the shipped rules (the `balanced` bot shows a good manual policy). A "SWAP ASSIST" accessibility setting that swaps to the weapon with ammunition when the active one starts a reload is a small optional task (V4-U).

### 3.2 Roster

| id | Role | Handling feel | Feed | How it is found |
|---|---|---|---|---|
| `pistol` (T1) | Reliable sidearm | Slow, exact, never the wrong choice | 12, short reload | Start |
| `smg` (T2) | Swarm trimmer | Fast chatter, long reloads feel short | 30 | Crates, act I common |
| `scattergun` (T2) | Core defense | Only fires at 9 m: silent while they walk in, brutal at the cage; shoves light enemies back | 6 shells | Crates, act I common |
| `assault_rifle` (T3) | Generalist | Steady thump, each round passes into a second enemy | 30 | Crates from act I (30%) |
| `hornet_rack` (T3) | Six targets at once | A salvo fans out, six small blasts, long pause | 4 salvos | Unlock `u_w_hornet` |
| `lmg` (T4) | Sustained suppression | Spins up to a roar, strays hit neighbours (and fuel drums), strips armor; a 3.8 s reload is the price | 150 | Unlock `u_w_lmg` |
| `slag_mortar` (T4) | Area denial | Lobs at the densest clump, leaves a burning pool that slows | 4 | Unlock `u_w_mortar` |
| `cutting_torch` (T4) | Armor and boss melter | A beam that gets stronger the longer it stays on one target; overheats | Heat | Unlock `u_w_torch` |
| `arc_projector` (T5) | Chain lightning | One crack, five enemies light up; ignores armor, tears wards, loves an EMP | Heat | Unlock `u_w_arc` |
| `rail_lance` (T5) | Line execution | A one-second charge line, then everything on the line is hit | 3 | Unlock `u_w_rail` |

The five weapons of the concept bar keep its tiers (T1 Pistol, T2 SMG, T3 Assault Rifle, T4 LMG, T5 Arc Projector); the five original ones fill the gaps.

### 3.3 Firing kinds (new sim behaviours)

| Kind | Rule | New code |
|---|---|---|
| H hitscan | As today; optional `pierce` hits the next enemy within 2 m behind the target on the shooter-target line | small |
| C cone | Among enemies inside range and the cone around the aim line, pellets are dealt nearest first, at most 3 per enemy while other targets remain; knockback moves light enemies along the shot direction, never into an obstacle | medium |
| A arc | The target takes full damage; then up to `chains` jumps, each to the nearest not-yet-hit enemy within `chain range` of the last, lowest id on ties; each jump x`chain_falloff` | medium |
| L line | A `charge_s` wind-up during which the line is fixed on the target's position; then every enemy within 0.25 m of the segment is hit, sorted by distance | medium |
| S shell | The target point is the centre of the densest cluster in range; the hit lands `flight_s` later as a delayed area hit; leaves a pool | medium (uses the hazard queue) |
| M missiles | `salvo` delayed hits, one per chosen target, landing `flight_s` later at the target's position at launch; small splash | medium |
| B beam | A hit every 6 ticks on the locked target; damage ramps per consecutive hit; no magazine | small |

Heat weapons: each shot adds heat; at `heat_cap` the weapon vents for `vent` seconds (no fire) and restarts at 0; heat falls at `cool_per_s` whenever the weapon is not firing. The HUD shows a heat bar instead of a magazine count.

Targeting per kind: H, A, B, M and L use the existing priority order (ARCH 6.6) inside the weapon's range; C uses it inside 9 m; S uses "densest cluster, ties by the best-ranked enemy in it". The 0.4 s lock still applies.

Damage order (one place, `DamageResolver`): weapon damage x weapon level x `hot_loads` formula (unchanged `Formulas.hit_damage`) x conditional multipliers (full HP, low HP, stunned) - effective armor (unchanged formula; LMG shred and `armor_ignore` reduce the armor first) x ward and shieldbearer reductions x `debug_damage_mult`. The golden values of ARCH 6.5 stay true.

### 3.4 Salvage: how weapons are found

Sources, crate timing and tier odds: CONTENT 2 and 7. Flow:

1. A crate lands on a fixed drop point (cyan flare, 3 s warning). It shows a ring that fills while **no living bodied enemy is within 2 m**. 12 uncontested seconds secure it; after 40 s CHORUS takes it. Nearby skitters and rushers divert to stand on it, so the player's tools are the ones already on the HUD: swap to the right weapon, EMP, a Deadfall Strike.
2. A secured crate is banked and opened at the next intermission, before the draft (section 11.3): the weapon is shown with its stats next to the two carried weapons. Choices: **TAKE IN SLOT 1**, **TAKE IN SLOT 2** (the replaced weapon is scrapped for half the crate's Scrap value), **LEVEL UP** (when it is a weapon already carried) or **SCRAP IT**.
3. The wave 2 clear always grants a crate if none was secured, so no run is stuck on the pistol.

### 3.5 Sound, muzzle effect and model notes

Sound ids are listed in section 12.1. Models follow the hard-surface kit (`LookDevShapes`, vertex-colour AO), at most 350 triangles each, gunmetal with one cyan accent, readable from above by **length and one signature shape**.

| id | Shot sound | Muzzle and impact effect | Model note (procedural) |
|---|---|---|---|
| `pistol` | existing `shot_pistol` | existing amber star and tracer | existing |
| `smg` | existing `shot_smg` | existing, shorter tracers | existing |
| `scattergun` | Low double thud with a short pump click | Wide amber fan of 8 thin streaks, 9 m long; dust kick at the muzzle | Short, thick, twin stacked barrels, shell rack on the side |
| `assault_rifle` | Hard dry crack, medium pitch | Tracer continues through the first target as a thinner line | Long receiver, top rail box, angled magazine |
| `hornet_rack` | Six quick hisses, then six small pops | Six curved cyan-white streaks (SEGMENT pool with an offset midpoint), small ring blasts | A 2 x 3 tube block held at the hip, open ends glow cyan |
| `lmg` | A motor that spins up under a fast heavy rattle | Constant tracer stream, more sparks, brass debris cubes on MID and HIGH | Drum under a long barrel with a perforated shroud and a bipod stub |
| `slag_mortar` | Hollow "thoomp", whistle, wet blast | An amber-white ball on an arc (BILLBOARD), ring blast, then a dull red-amber ground pool with dark edge | Fat short tube angled up, base plate, three ribs |
| `cutting_torch` | Continuous rising hiss with a 60 Hz buzz, a "tsk" on vent | One bright cyan-white beam segment that thickens with the ramp; sparks at the contact point | Twin tanks on the pack side, a nozzle with a cowl |
| `arc_projector` | A sharp crack with a descending electric tail; a deeper thump on overheat | Jagged cyan-white bolt segments from muzzle to target to each chained enemy (3 jittered segments per jump), small blue-white ground rings like the EMP rings of the concept image | Three prongs around an emissive core, two coil rings |
| `rail_lance` | A one-second rising whine, then a slap and a long metallic ring | While charging: a thin cyan line. On fire: a thick white line for 0.12 s, sparks at every enemy on it | Very long twin rails with four brackets, capacitor box at the rear |

---

## 4. Directives (the upgrade cards)

Tables: CONTENT 3. This section is the rules and the reasoning.

### 4.1 What happens to today's upgrades

| Today (GDD 5.2) | In this design |
|---|---|
| `damage` (5 levels, bought with Scrap) | Directive `hot_loads`, 5 stacks, the same +20% per stack through the same formula and the same `upgrade_levels[UP_DAMAGE]` field |
| `fire_rate` | Directive `cyclic_tuning`, same formula and field |
| `armor_piercing` | Directive `penetrator_cores`, same formula, cap and field |
| `auto_turret` | Directive `turret_deploy`, 2 stacks, same turret |
| `smg_unlock` (300 Scrap, from wave 2) | Removed. The SMG is a salvage weapon |
| The upgrade drawer and the UPGRADES tab | Removed from the combat HUD. Its screen area becomes the weapon bar |
| Scrap prices and `Formulas.upgrade_cost` | The function and its golden tests stay (it is pure and is reused for the reroll, buy-out and patch prices as plain data). The five price rows stay only in the legacy fixture (section 13.9) |
| The `PURCHASE` command | Stays in the sim for the legacy fixture and its tests. The shipped mission sets `shop_enabled: false`, which makes `EconomySystem.purchase` answer `WRONG_STATE` |

Scrap keeps a job (decision D2): it pays for **rerolls, buy-outs and core patches** on the draft screen (CONTENT 3.7) and is what a scrapped crate turns into. It is no longer spent during combat, which removes the "open a drawer while they are hitting the core" moment and gives that attention to weapon swaps and calls.

### 4.2 Categories, rarities and build identity

60 directives: 14 weapon, 10 turret, 8 core, 11 ability, 8 economy, 9 corrupted. Rarities: common (stackable stats), rare (new behaviour), prototype (build-defining, one stack), corrupted (a strong gain with a permanent price, red frame, the price printed as large as the gain).

Each directive carries one or two **tags**. The draft leans toward tags the build already has (weight x2 when two or more held directives share a tag), which is what turns random offers into a build with an identity:

| Tag | Identity | Core pieces | Feels like |
|---|---|---|---|
| `bullet` | Rate of fire | `cyclic_tuning`, `kill_chain`, `shock_rounds`, `ricochet`, SMG or LMG, `twin_link` | A wall of tracers that speeds up as it kills |
| `blast` | Chain reactions | `overpressure`, `aftershock`, `incendiary_tips`, `unstable_munitions`, mortar or hornets, hot routes with bursters and `mod_volatile` | One kill sets off the yard |
| `arc` | Stun and lightning | `arc_projector`, `emp_tether`, `emp_overload`, `arc_pylons`, `shock_rounds` | EMP, then everything that is stunned dies in blue |
| `fortress` | Let them come | `reactive_plating`, `core_lash`, `ember_vent`, `shield_burst`, `ground_wire`, scattergun | The cage itself is the weapon |
| `gunline` | Turrets | `turret_deploy` x2, `sentry_link`, `flak_heads`, `mine_layer`, `overwatch`, `pad_capacitors` | Three guns and a minefield; the Warden is the smallest of them |
| `hoard` | Scrap as a stat | `scrap_rounds`, `compound_interest`, `scavenger_protocol`, `open_gate` | Never reroll, never patch, hit harder for every Scrap unspent |
| `tempo` | Abilities | `cascade`, `emp_capacitor`, `overdrive_coolant`, `bottomless`, `overclocked_core` | An ability every few seconds |
| `rail` | Big single hits | `heavy_barrel`, `first_strike`, `glass_cannon`, rail lance | Few shots, each one deletes a line |

Cross-tag combos that should surprise (to be confirmed in play): `aftershock` + `emp_overload` (the EMP itself starts a blast chain); `scattergun` + `reactive_plating` + `ground_wire` (a fortress that wants enemies at the cage); `kill_chain` + `twin_link` + LMG (the off-hand gun feeds the fire-rate stack); `scrap_rounds` + `open_gate` (more Scrap, faster waves, more damage); `static_pact` + arc projector (the event that hurts everyone else doubles this build).

### 4.3 How an offer is generated

Inputs: the `draft:<n>` stream (n = the offer's ordinal in the run), the unlocked pool (part of the run config), the held directives, the carried weapons, the act. Steps, in this order (the order is part of the contract because it fixes the draw sequence):

1. Build the candidate list: unlocked, not maxed, requirement met. Sort by id (stable input order).
2. For slot 1 to N (N = 3, or 4 with `quartermaster`): apply pity overrides (rare pity, turret pity, `rw_rare_draft`); else roll the rarity with the act weights; if that rarity has no candidate, fall to the next lower, then higher.
3. Inside the rarity, pick by weight (CONTENT 3.7) without replacement.
4. Roll the corrupted replacement for the last slot with the act's chance; if it hits and a corrupted candidate exists, replace the slot (one extra pick from the same stream).
5. Push `DRAFT_OFFERED`. A `REROLL` repeats steps 2 to 4 with the stream where it stands.

Every reroll and every offer is therefore a pure function of (seed, pool, earlier decisions), which is what replays, bug reports and the Daily Run need.

### 4.4 Commands on the draft screen

| Action | Command | Rule |
|---|---|---|
| Pick | `PICK_DIRECTIVE(slot)` | Applies the directive, closes the draft. With `rw_double_pick` the draft stays open for one more pick |
| Skip | `SKIP_DRAFT` | +60 Scrap |
| Reroll | `REROLL` | Free charge, else Scrap (CONTENT 3.7); not allowed after `mod_no_breather` |
| Buy-out | `BUY_OUT(slot)` | Before picking: also keep this slot for Scrap; once per draft |
| Patch | `PATCH_CORE` | +10% core for Scrap; price grows per use |

### 4.5 Growth with meta unlocks

The base pool has 31 directives; 7 packs add 29 more (CONTENT 12). A pack adds whole tags (blast, arc, fortress, gunline, hoard) so an unlock changes **which builds exist**, not how strong a build is. A larger pool dilutes each offer, so the tag lean (x2) is what keeps builds reachable; the scorecard checks that the win rate of the `balanced` bot does not fall by more than 5 points between the base pool and the full pool.

---

## 5. Enemies and elites

Tables: CONTENT 4. All are CHORUS machines: bone-ceramic plates over a dark gunmetal frame and **one red optic** (a slit, a bar or a single lens; never two eyes, never a skull).

### 5.1 The roster

| id | Silhouette at phone scale (and where its single optic is) | Behaviour | Counters |
|---|---|---|---|
| `skitter` | existing low crawler | existing | anything |
| `hollow_warden` | existing broad biped | existing | piercing, torch, rail |
| `rusher` | existing lean sprinter | existing | EMP, scattergun, pools |
| `mote` | A hand-sized hopping tripod, about a third of a skitter; the whole body is a small ceramic cap with a red slit. Reads as a moving grain | Runs the flow field in streams, burns out on the cage for 6 | Area, chain, turrets; a Shield turns a mote stream into nothing |
| `burster` | Hunched biped carrying a round hazard-striped tank on its back (the tank is wider than the body). Optic: a slit on the small head | Walks in; killed anywhere, it blasts the enemies around it 0.1 s later; reaching its slot it arms for 1.2 s (the tank swells) then detonates on the core | Kill it inside the crowd. Bursters next to bursters make a chain. Never let one arm |
| `spitter` | Tripod stance, a long tube on its back angled up at 45 degrees. Optic at the tube's base | Stops at 10.5 m and lobs slow slag bolts at the core (visible arc, 0.8 s) | Range, hornets, mortar, `overwatch` turrets; the Shield eats bolts |
| `splitter` | A three-lobed body with open seams, as wide as a Hollow Warden but lower. Optic on the centre lobe | Dies into 3 fast `shard` minis | Kill it far out, or with area damage so the shards die in the same blast |
| `shard` | One lobe of a splitter with two legs | As `mote`, 8 damage | as mote |
| `shieldbearer` | A tall biped behind a slab shield as wide as itself, held forward. Optic: a bar on the shield's upper edge. A thin red hex ring on the ground shows its ward radius | Everything within 2.4 m takes 40% damage while its ward pool lasts; the blocked damage drains the pool; the pool refills after 4 s of peace | EMP empties the pool. Arc and torch tear it. Focus the bearer (it is not protected by its own ward) |
| `reclaimer` | Low wide crawler with a tall mast and three cable arms. Optic on the mast head | Parks at 12.5 m and repairs up to 3 damaged machines (thin red tether lines) | Priority target by rule; strikes; rail |
| `jammer` | Biped with an upright ring antenna above its shoulders (a halo seen edge-on from above). Optic in the ring's hub | Turrets inside its 7 m aura fire at half rate; while any jammer lives, ability cooldowns run at 70%. Its death stuns its neighbours for 1 s | Kill it first; `overwatch` |
| `borer` | A drill-nosed wedge, low and long. Optic: a slit behind the drill | Comes out of the ground at a telegraphed breach point in mid-field and runs at the core | Watch the cracks; pools and mines on the breach; scattergun |

Six of the new types use existing movement (flow field, slots). New movement code: minis (a cheaper path), standoff points (spitter, reclaimer), breach spawns (borer), boss-specific motion.

### 5.2 Elites

An elite is a normal bodied enemy made dangerous by one or two **affixes** (CONTENT 4.3: PLATED, SWIFT, VOLATILE, REGENERATING, WARDED, MAGNETIC, OVERCLOCKER, ANCHORED, LEECHING, SHROUDED). Elites are rolled into the plan per wave.

Identity on screen: scale 1.25, a red chevron ring on the ground under it (one instanced mesh for all elites), a small health bar, and a ticker line when it enters (`ELITE: PLATED SWIFT RUSHER`). The affix is shown by **behaviour and one ground cue**, not by icons over heads: WARDED has a ring that shrinks as the ward drains, OVERCLOCKER a pulsing 4 m ring, MAGNETIC thin lines from shooters bending to it, SHROUDED a flicker, VOLATILE the burster's hazard stripes.

Combination rules and forbidden pairs: CONTENT 4.3. At most 4 elites alive (others wait in the queue).

### 5.3 Swarm composition rules

1. A wave is built from one pack: 2 to 4 groups (7 in `pack_everything`), each a count, a start, an interval and a region.
2. No more than 2 "specialist" types (spitter, reclaimer, jammer, shieldbearer) in one wave in act II, 3 in act III.
3. At least 40% of every wave's budget is basic fodder (skitter, mote, rusher): crowds are what make area weapons, chains and the phone-size picture work.
4. A reclaimer never spawns in the first 20% of the window (there is nothing to repair yet).
5. Bursters never spawn as the first 3 bodies of a wave (a blast needs neighbours to be interesting, and a lone burster reaching the core is a cheap hit).
6. Boss waves use the boss's escort pack (CONTENT 5) and schedule nothing in the first 4 s after the boss enters.

### 5.4 Minis

Minis are the cheap way to more bodies (section 10). In the sim they live in the same `EnemyStore` (capacity 98 = 50 + 40 + 8) and can be shot, stunned and blasted like anything else, but they skip separation, slots and stuck tracking (about a quarter of a bodied enemy's movement cost, to be measured). They can never be the Warden's target while a bodied enemy is in range and attacking or closer to the core by ETA bucket; otherwise the normal order applies (they are usually killed by area, chains and turrets).

### 5.5 Caps and the queue

| Cap | Value | Enforced by |
|---|---|---|
| Bodied enemies alive | 50 (`enemy_cap`, unchanged) | `SpawnSystem` queue, as today |
| Minis alive | 40 (`swarm_cap`, new) | same queue, second counter |
| Per type alive | CONTENT 4.1 last column = the view pool of that type | same queue (a spawn waits when its type is at its cap) |
| Elites alive | 4 | same queue |

Nothing is dropped: a spawn that cannot enter waits FIFO. Shards from a splitter that do not fit join the same queue at the splitter's death position.

### 5.6 Readability rules at 50 + 40 units

1. **One red optic per enemy and nothing else on an enemy glows.** Tanks, wards and auras are shape, stripe or ground ring.
2. Value ladder: ground darkest; bodies mid; optics and friendly lights brightest. Additive effects are capped so an optic is never washed out for more than 0.25 s (the blast flash lifetime).
3. Colour roles hold everywhere: cyan = ours (Warden, turrets, strikes, crate, beams, arcs), amber = the core and Scrap, red = CHORUS (optics, enemy projectiles, danger zones, elite rings). White is only for the first frames of a flash.
4. Every damage zone that can hurt the player's side is a **red hatched ground decal with a shrinking outline**; every zone that hurts enemies is cyan or amber and has no hatch. Shapes differ, so the rule survives colour blindness.
5. Size classes are far apart: mini 0.4 m tall, skitter 0.9, bipeds 1.4 to 1.8, specialists carry one tall or wide part (tube, mast, ring, slab, tank), bosses 3 m and more.
6. Only bosses, elites and damaged Hollow Wardens, shieldbearers and splitters show a health bar. Minis never do.
7. Floating text is only Scrap gains and crate or event words. No damage numbers (the concept image shows them; at 90 bodies they would hide the swarm. A setting can come later).
8. At most 3 ticker lines and 1 banner at a time; a boss banner pre-empts everything else.

---

## 6. Bosses

Tables: CONTENT 5. Bosses are "nodes" (canon naming). One boss per act; the act I and II bosses are each drawn from a pool of two; act III is always **Node 9, the Siege Hulk**, in one of three variants. So a run meets 1 of 2 x 1 of 2 x 1 of 3 = 12 boss sequences.

| Boss | The fight in one line | Why it is different |
|---|---|---|
| NODE 3 // BROOD CARRIER (act I) | A walking hive that pours motes; molts at half HP and doubles the flow while losing its armor | Tests area damage and teaches minis |
| NODE 5 // LANCE PLATFORM (act I) | Plants at 14 m and fires a 3-second telegraphed beam at the core every 9 s | Tests ability timing: EMP interrupts, Shield absorbs; it never touches the cage |
| NODE 6 // AEGIS ARRAY (act II) | Almost immune while its three orbiting pylons live; exposed for 10 s when they fall | Tests priority and burst windows |
| NODE 7 // TREMOR RIG (act II) | Stomps every 10 s (turrets offline, magazine emptied) and opens borer breaches at 66% and 33% | Tests the Shield as a brace and heat weapons |
| NODE 9 // SIEGE HULK (act III) | Canon final boss, three slots at the cage, 9,000 HP, enraged below 25% | Variants PLATED (sheds armor, gains speed), FED (reclaimers heal it), OVERCLOCKED (telegraphed charges) |

Shared rules: a boss is never an elite; the EMP stuns a boss for 1 s and it is then immune for 5 s (existing); a telegraphed boss attack can always be answered by at least two different tools the player always has (an ability, a Deadfall charge, raw damage in a window); no boss attack removes more than 20% of the core's maximum in one hit; events during a boss wave come from the boss-safe list; `static_front` never overlaps a Lance Platform charge.

---

## 7. Chaos events and hazards

Tables: CONTENT 6.

### 7.1 The set

Player-triggered (HUD buttons, section 11.4):

| Event | What the player does | Why it is a decision |
|---|---|---|
| DEADFALL STRIKE | Taps STRIKE. Two seconds later 450 damage lands on the densest cluster (it does not track) | 1 to 3 charges per run; the cluster may move in 2 s; it is the answer to a contested crate, an elite pair or an arming burster line |
| CORE VENT | Taps VENT. The core spends 8% of its maximum to throw everything within 6 m back and hit it for 220 | Paying HP to save HP; once per wave; blocked at 10% |
| FREIGHT (with `signal_hijack`) | Taps FREIGHT. Four seconds later a dead freight car crosses the rail line that has more enemies on it | One per act; huge on a column, useless on a scattered wave |

World-triggered (rolled into the plan): RELAY WINDOW (double Scrap for 10 s), ACCORD DROP (contested crate), CORE SURGE (turrets x2 then a brownout unless the Shield bleeds it off), RUNAWAY FREIGHT (700 damage along a rail line), STATIC FRONT (abilities offline 12 s for everyone, wards and auras down too), FLOOR BREACH (borers from the ground), RECOUNT (12 spawns at once from the other edge). Hazard: FUEL DRUMS (three per act; any blast sets them off).

### 7.2 Telegraphing (suspense needs a warning)

Every event has the same three-part grammar, so the player learns it once:

1. **Warning** (`warn_s`, CONTENT 6): a ticker line with an icon and a countdown bar, a sound sting unique to the event, and a ground decal where it will happen (lane, ring, cracks, edge arrows). Harmful events use the red hatch; helpful ones cyan.
2. **Effect**: the decal becomes the effect (the car, the column of light, the open breach).
3. **Aftermath**: a short state the player can read (brownout icon on turrets, slag pool, wreck sparks) and a ticker line.

Minimum warnings: 2.5 s for anything that spawns enemies, 4 s for anything that changes the player's tools, 6 s for the Static Front. The warning of a harmful event is never covered by a banner (the boss banner waits).

### 7.3 Fairness rules (each one becomes a test)

1. No event damages the core, the Warden or a turret directly. Events change the fight; enemies do the damage.
2. No harmful event in waves 1 and 2; wave 3's event is always helpful.
3. At most one harmful event per wave in acts I and II, two in act III; never two tool-denying events at once (`static_front`, the brownout of `power_surge`, `mod_low_power`, a Tremor Rig stomp).
4. Mercy: a harmful event whose warning would start while the core is below 15% is cancelled (and logged). This is a published rule (help text), not hidden scaling.
5. Abilities that are active when a Static Front starts keep running; cooldowns freeze, they do not reset.
6. Every event is in the plan from tick 0 (section 9); nothing is rolled in reaction to how well the player is doing.
7. The same world event never happens in two consecutive waves.
8. A run can always be lost and never be lost "from full": no single wave of act I can remove more than 60% of a full core from a player who takes any directive each draft and uses each ability once (checked with the `greedy` bot).

### 7.4 Interactions with abilities, the pad and turrets

| | EMP | Shield | Overdrive | Turrets | Warden pad |
|---|---|---|---|---|---|
| STATIC FRONT | locked | locked (an active shield continues) | locked (active continues) | unaffected | unaffected |
| CORE SURGE | - | activating it cancels the brownout | reload is instant during the surge, so Overdrive wastes nothing | x2 for 10 s, then offline 5 s | reload and vent instant |
| RUNAWAY FREIGHT | stunned enemies cannot leave the lane | - | - | lines never cross a pad | line B passes 3.5 m below the Warden; cosmetic wind only |
| ACCORD DROP | stuns the squatters but they still contest | - | kills them faster | pad T0 covers drop points 1 and 3 | - |
| FLOOR BREACH | borers emerge stunned if the EMP is active | - | - | mines and pools on a breach hit them as they emerge | - |
| Tremor Rig stomp | - | an active shield negates it | - | offline 4 s | magazine emptied |
| Jammer aura | kills the aura for the stun | - | - | 50% rate inside 7 m | - |
| Lance Platform beam | cancels the charge | absorbs its amount | boosts the damage window | - | - |

---

## 8. Meta: the Archive

Tables: CONTENT 10, 11, 12.

### 8.1 Sinks and philosophy (decision D5)

Recovered Data buys **variety, not power**: weapons that join the crate pool, directive packs that add build tags, kits that change how a run starts, and field options that add information (boss intel, route preview) or flexibility (one free reroll, a third sling). There is no permanent +damage and no permanent +core. A player with everything unlocked is not stronger than a new player on the same seed and kit; they have more ways to win. Threats (enemies, bosses, events) are never locked: variety on the CHORUS side is there from run 1.

### 8.2 The unlock tree

Four branches (ARMORY, DIRECTIVES, KITS, FIELD), three tiers; tier 2 opens after 3 unlocks, tier 3 after 8. 24 unlocks, 5,250 Data in total (4,650 without the stretch turret types).

### 8.3 Pacing and anti-grind

| Check | Target |
|---|---|
| First unlock | After run 1 or 2 (cheapest 80; a first run that reaches wave 4 or 5 pays 18 to 24, plus a first-boss milestone of 50) |
| Something new every | 1 to 2 runs for the first 10 runs |
| Everything | 20 to 30 runs (about 6 to 9 hours) |
| Losing is worth it | A defeat at wave 8 pays about a quarter of a victory |
| No farming loop | Data is per wave cleared and per boss; quitting pays 0; the hot route bonus `rw_data` needs the wave cleared; `data_siphon` costs a draft pick |
| Milestones | 13 one-time payouts (first kill per boss, first victory, first victory per kit, three builds): 1,050 Data, front-loading the first hours |

### 8.4 Reward-once rules

- Run reward: unchanged mechanism (`awarded_run_ids`, flush before the results screen).
- Milestones: `claimed` list of milestone ids; a milestone is granted in the same flush as the run that earned it.
- An unlock purchase is atomic: check tier gate, not owned, funds; debit; add the id; flush; emit `profile_changed`.
- A resumed run keeps its run id, so it can be rewarded only once however often it is resumed.

### 8.5 Daily Run (decision D8)

One seed per calendar day (`hash("daily|" + UTC date)`, computed in the game layer; the sim never reads the clock), a fixed kit (`k_standard`) and the **full** pool regardless of the profile's unlocks, so two players on the same day face the same plan and the same offers for the same decisions. Local only (offline game): the menu shows today's best wave and whether it was won. One rewarded attempt per day; further attempts are practice and pay half Data.

---

## 9. Randomness architecture

### 9.1 Principle

All gameplay randomness comes from `world.rng.stream(name)`. A stream is used for **one purpose and one index**, so the decisions of one part of the run cannot shift the dice of another. Everything that can be decided before the run starts is decided at tick 0 and stored in a `RunPlan`.

### 9.2 Streams

| Stream name | Drawn when | Decides |
|---|---|---|
| `spawn`, `steer` | as today | Spawn jitter, steering (unchanged; existing hashes of the legacy fixture stay valid) |
| `plan.boss` | tick 0 | Act I boss, act II boss, Node 9 variant |
| `plan.route:<w>` | tick 0, for w = 2..14 except boss waves | Both options of wave w: pack, modifier, reward, hot flags |
| `plan.wave:<w>:<o>` | tick 0 | Group counts and the group plan of option o of wave w |
| `plan.elite:<w>` | tick 0 | Which scheduled bodies are elites and their affixes |
| `plan.event:<w>` | tick 0 | The world events of wave w and their times |
| `plan.hazard:<act>` | tick 0 | Fuel drum points |
| `kit` | tick 0 | Random items of `k_gambler` |
| `draft:<n>` | when offer n is made, and on its rerolls | The directives offered |
| `crate:<n>` | when crate n is secured | Its contents |
| `aim` | per shot that needs it | LMG strays, pellet scatter ties |
| `proc` | per trigger | `unstable_munitions`, `mine_layer` placement, reload jams |

Bots never touch a sim stream: the `random` bot owns an RNG seeded from `hash(seed, "bot")` outside the world.

### 9.3 The run plan

```gdscript
class_name RunPlan extends RefCounted          # built by RunPlanSystem.build(world) inside SimWorld._init; hashed
var boss_ids: PackedInt32Array                 # enemy index per act
var boss_variant: int
var waves: Array[PlannedWave]                  # index 0 = wave 1
class_name PlannedWave extends RefCounted
var index: int; var act: int; var is_boss: bool
var options: Array[RouteOption]                # 1 (fixed or boss) or 2
var events: Array[PlannedEvent]                # event index, start tick offset
class_name RouteOption extends RefCounted
var pack_index: int; var modifier_index: int   # -1 = none
var reward_index: int; var hot: bool
var groups: Array[SpawnGroupDef]               # the existing def: SpawnSystem consumes it unchanged
var elites: Array[PlannedElite]                # group, ordinal, affix mask
```

Directives that change the future (`chorus_handshake`, `static_pact`, `open_gate`) patch the plan of the remaining waves with their own indexed streams (`plan.patch:<directive>:<w>`), so the patch is also reproducible.

### 9.4 Reproducing a run

A run is the tuple: build version, content hash (already logged by `Content`), `run_seed`, kit id, the sorted list of unlocked ids (or the flag `daily`), and the command log. `Replay.run` with a `SimConfig` built from the first five and the log gives the same `state_hash()` and `event_hash`. The results screen and the pause overlay show the seed; SAME SEED starts a new run from it. A bug report is the run file (section 13.3) with its tail.

### 9.5 Determinism rules for new code

1. Area queries go through `SpatialHash.query` (already sorted by enemy id). Any list of victims is processed in id order.
2. Delayed effects sit in one queue ordered by (due tick, sequence number); at most 8 blasts resolve per tick, the rest stay queued (a visible ripple, a bounded tick, and the same order on every device).
3. Every new state class implements `hash_into`; a test fails if a new field is not hashed (the "mutate one field, hash must change" pattern of `tests/unit/sim/test_stores.gd`).
4. No float accumulates across ticks where an integer can do it: heat, ward pools, fuses and timers are integers (milli-units or ticks).
5. The quality tier, the frame rate and the device never reach the sim (unchanged; `lint_layers.py` keeps enforcing it).

### 9.6 Golden tests that stay and that are added

Stay: every `Formulas` golden value of ARCH 6.5; "same seed and commands, same hash"; replay equality; kill-once and Scrap-once; reward-once; the legacy 5-wave fixture's behaviour suites (section 13.9). Added: the plan of seeds 1, 2 and 3 on the frozen variety fixture (boss ids, the pack and reward of every option); the first offer of seed 1 with the base pool; the first crate of seed 1; "a decision at wave 3 does not change the options of wave 7" (two runs, different picks, same `plan` and same `draft:5` candidates given equal held directives); snapshot-restore hash equality at every boundary for 3 seeds; "thinking time does not change the hash" (a bot that waits 0 or 600 calls before answering).

---

## 10. Chaos and performance budget

### 10.1 Where we are

From the task brief (to be recorded in the repo by task V2-P, see F15): a Pixel with a PowerVR GPU, 50 enemies: LOW 60 fps; MID and HIGH about 56 fps with hitches (p95 about 30 ms); about 137 draw calls and 40k primitives on HIGH; MSAA nearly free. ARCH 13 budgets: 150 draw calls target (220 limit), 120k triangles, 200 live VFX quads (400 limit), 48 tracers. The dev laptop's iGPU is slower than the phone and is not the reference.

Reading: draw calls are the cost that scales with enemies (one pooled `MeshInstance3D` per bodied enemy, up to 3 surfaces), and MID and HIGH are already at the edge. Raising `enemy_cap` would add a draw call per body. So this design does **not** raise the bodied cap.

### 10.2 The plan for "more on screen"

| Lever | What it adds | Sim cost | Render cost (guess, to be measured) |
|---|---|---|---|
| **Minis** (`mote`, `shard`): one transform-only `MultiMeshInstance3D` per mini type, 40 instances, a 40-triangle mesh with 2 surfaces | Up to 40 more moving bodies: 90 on screen instead of 50 | `swarm_cap` 40; about +25% movement time (minis skip separation, slots and stuck checks) | +4 draw calls, +1.6k triangles |
| **Chain reactions** (burster blasts, `mod_volatile`, drums, `aftershock`, arcs) | The loudest moments, made of things already on screen | A few `SpatialHash` queries per blast, at most 8 blasts per tick | Pooled rings and flashes: +3 draw calls |
| **Delayed hits** (mortar, missiles, spitter bolts, strikes) | Things in the air | One queue entry each, no physics | 1 instanced pool per projectile look: +3 draw calls |
| **Zones** (slag pools, ward rings, elite rings, telegraph decals) | The ground tells the story | Integer timers | 4 instanced pools: +4 draw calls |
| **Cosmetic chaos, tier-scaled** (section 10.4) | Rain bursts, embers, scorch marks, lingering debris, a ghost swarm massing outside the gates, screen shake | None (view only, driven by events and a non-sim RNG) | Per tier |
| **Sim cap change** | `enemy_cap` stays 50; new `swarm_cap` 40; store capacity 58 to 98 | Target at 50 + 40: 0.6 ms per tick on the desktop (limit 1.0), 2.0 ms on the phone (limit 3.0) | - |

Why the cap change is justified: a mini costs the phone almost nothing to draw (instanced) and about a quarter of a body to simulate, so 40 minis buy 80% more bodies for an estimated 3% more draw calls. Raising the bodied cap by 40 would add up to 120 draw calls on a GPU that already hitches.

Optional follow-up, not on the critical path (task V4-X2): draw **all** enemies of a type as one transform-only MultiMesh. It would cut about 50 to 100 draw calls and could remove the MID and HIGH hitches, but it replaces the material-swap hit flash (per-instance data is unreliable on PowerVR, ARCH 8) with a transform pop and needs the hard-surface look ported. Decide after the phone baseline is measured.

### 10.3 New pools and caps (allocated once at `setup`; exhaustion drops the oldest visual, never affects the sim)

| Pool | Cap LOW / MID / HIGH | Draw calls | Used by |
|---|---|---:|---|
| Mini bodies (2 types) | 40 / 40 / 40 each | 4 | mote, shard |
| Blast rings (FLAT) | 8 / 12 / 16 | 1 | every blast |
| Blast flashes (BILLBOARD) | 0 / 8 / 12 | 1 | every blast (not on LOW) |
| Arc segments (SEGMENT) | 18 / 30 / 45 | 1 | arc projector, shock rounds, pylons, core lash |
| Beam segments | 2 / 2 / 3 | 1 | torch, lance charge and shot, Lance Platform beam |
| Lobbed projectiles (BILLBOARD) | 12 / 18 / 24 | 1 | mortar shells, spitter bolts, hornets |
| Ground pools (FLAT) | 6 / 8 / 10 | 1 | slag, burn |
| Telegraph decals (FLAT, hatched) | 8 / 8 / 8 | 1 | lanes, rings, cracks |
| Ward and aura rings (FLAT) | 8 / 10 / 12 | 1 | shieldbearer, warded, overclocker, jammer |
| Elite rings | 4 / 4 / 4 | 1 | elites |
| Tether lines (SEGMENT) | 6 / 9 / 12 | 1 | reclaimer, magnetic |
| Scorch marks (FLAT, persistent ring) | 0 / 8 / 16 | 1 | after blasts |
| Ghost swarm (cosmetic) | 0 / 40 / 80 | 1 | outside the playable rectangle |
| Crate, strike column, freight car, drums | 1 + 1 + 1 + 3 nodes | 6 to 8 | events |
| Existing: tracers 48, sparks 64, bursts 24, texts 24, EMP rings 2 to 6 | unchanged except rings | - | - |

Worst-case addition: about 22 draw calls on LOW and 28 on HIGH. With the brief's 137 on HIGH that is about 165: over the 150 target, under the 220 limit. That is the number task V2-P must measure first; if it does not hold on the phone, the cut order is: ghost swarm, scorch marks, flashes, tether lines, then V4-X2 (instanced bodies).

Per-effect guesses to be measured on the phone (frame time added at the cap, HIGH): minis 0.3 ms; a 6-blast chain 0.4 ms for 0.3 s; 45 arc segments 0.2 ms; 10 pools 0.3 ms (alpha overdraw is the risk: pools are small and never stacked more than 2 deep by a view rule); ghost swarm 0.2 ms; bloom is unchanged.

### 10.4 What each tier shows (the simulation is identical on every tier)

| Feature | LOW | MID | HIGH |
|---|---|---|---|
| All sim-relevant visuals: bodies, minis, optics, telegraphs, pools, rings, projectiles, beams, arcs | yes | yes | yes |
| Blast | ring only | ring + flash | ring + flash + 4 debris streaks |
| Sparks per hit / debris per death | 2 / 2 | 3 / 3 | 4 / 4 (existing values) |
| Scorch marks, brass debris | no | 8 | 16 |
| Ghost swarm at the gates | no | 40 | 80 |
| Rain bursts on events, embers after blasts | no | light | full |
| Screen shake (blasts, stomps, freight; off with Reduced Flash) | no | small | full |
| Muzzle light, bloom | as today | as today | as today |

A telegraph, a danger zone or an enemy projectile is **never** tier-gated: what can hurt you is always drawn.

### 10.5 Audio budget

16 voices stay. New rule: 3 voices are reserved for the alert class (event warnings, boss telegraphs, core low); the weapon class may use at most 8; blasts at most 3 starts per frame (existing per-id cap) with a "big blast" sample replacing 4 or more simultaneous small ones. Without this, an LMG plus a chain blast would starve the warning that matters.

---

## 11. UX

Base 1080 px wide, 1920 to 2400 tall; touch targets at least 132 px, primary buttons 148 px or taller; body text 38 px, small text never under 30 px; everything inside the safe area (existing `SafeArea` and `HudLayout`). One-handed rule:
**every control of a choice screen is in the lower 60% of the screen**; the upper part is information only. Every choice is two taps (select, then CONFIRM) so a slip never commits; the selected item stays highlighted with its full text.

### 11.1 Draft screen (over the frozen battlefield, dimmed)

```
+------------------------------------------------+
| WAVE 6 CLEARED            CORE 64%   SCRAP 410 |  info band (top, not interactive)
| LANTERN CELL // PATCH WINDOW                   |
| build: [ARC x3] [TEMPO x2]   weapons: SMG  ARC |  build chips (tap = BUILD list)
+------------------------------------------------+
|                                                |
| +------------+ +------------+ +------------+   |
| | RARE       | | COMMON     | | CORRUPTED  |   |  3 cards, each 320 x 560 px
| | (icon)     | | (icon)     | | (icon)     |   |  frame: grey / cyan / amber-chevron / red
| | EMP TETHER | | HOT LOADS  | | GLASS      |   |
| |            | | 2 -> 3 / 5 | | CANNON     |   |
| | EMP stun   | | +20% Warden| | +80% Warden|   |
| | +1.5 s.    | | damage     | | damage     |   |
| | Stunned    | |            | | ---------- |   |
| | take +25%  | |            | | CORE MAX   |   |  the price is as large as the gain
| | [ARC][TEMPO]| | [BULLET]  | | -30%       |   |
| +------------+ +------------+ +------------+   |
|                                                |
| [ REROLL 60 ]  [ PATCH +10% 180 ]  [ SKIP +60 ]|  3 buttons, 320 x 132
| [            CONFIRM: EMP TETHER             ] |  1008 x 148; disabled until a card is selected
+------------------------------------------------+
```

- Tap a card: it lifts and CONFIRM names it. A long press shows the full rules text and what it combines with in the current build ("WORKS WITH: ARC PROJECTOR, EMP OVERLOAD").
- BUY-OUT appears on the unselected cards after a selection ("KEEP ALSO 250").
- With 4 offers (`quartermaster`) the cards are 250 px wide; text stays 30 px or more.

### 11.2 Route screen

```
+------------------------------------------------+
| ACT II  THE GANTRY LINE   WAVE 7 OF 15         |
| CHORUS PLATING: TIER II (HP +35%)   CORE 64%   |
| o-o-o-o-[B] o-(7)-o-o-[B] o-o-o-o-[9]          |  act strip: cleared, current, bosses
+------------------------------------------------+
|  CHOOSE THE NEXT PUSH                          |
| +--------------------+ +--------------------+  |
| | STANDARD           | | HOT                |  |  2 cards, 490 x 700 px
| | ARMORED COLUMN     | | POWDER TRAIN       |  |
| | (glyph)(glyph)     | | (glyph)(glyph)(gl) |  |  enemy glyphs (existing UiEnemyGlyph)
| | 31 hostiles        | | 52 hostiles        |  |
| | 1 elite            | | 2 elites           |  |
| | no modifier        | | VOLATILE SWARM:    |  |
| |                    | | skitters blast     |  |
| | REWARD             | | REWARD             |  |
| | +200 SCRAP         | | SALVAGE CRATE      |  |
| +--------------------+ +--------------------+  |
| [               CONFIRM: HOT                 ] |
+------------------------------------------------+
```

The boss briefing uses the same frame with one wide card: boss name, silhouette glyph, "ATTACK:" and "ANSWER:" lines, CONTINUE.

### 11.3 Crate pick-up and weapon choice (salvage step)

During combat the crate is a world object with a cyan ring that fills; the ticker shows `ACCORD DROP: 7 s` or `DROP CONTESTED`. No tap on the battlefield. At the next intermission:

```
+------------------------------------------------+
| SALVAGE RECOVERED                              |
| +--------------------------------------------+ |
| | T4  SLAG MORTAR                 NEW        | |
| | Lobs at the densest group. Leaves a pool.  | |
| | DMG 80  AREA 2.6 m  4 shells  RELOAD 2.4 s | |
| +--------------------------------------------+ |
| CARRIED                                        |
| +------------------+   +------------------+    |
| | 1  SMG  LV 2     |   | 2  PISTOL  LV 1  |    |
| | DMG 15  6.0/s    |   | DMG 30  2.0/s    |    |
| | [ REPLACE ]      |   | [ REPLACE ]      |    |  132 px high buttons
| +------------------+   +------------------+    |
| [ SCRAP IT +140 ]                              |
| [            CONFIRM: REPLACE PISTOL         ] |
+------------------------------------------------+
```

A duplicate shows `LEVEL UP: SMG LV 2 -> 3` as the highlighted default. A boss crate shows two weapon panels side by side first (tap one), then the same slot choice.

### 11.4 Combat HUD changes

```
+------------------------------------------------+  top HUD (11%)
| [||]  CORE 64% [=======   ]  ACT II  W7/15  S410|
| [ boss bar with phase pips, boss waves only  ] |
| ! STATIC FRONT IN 6 s [#####     ]             |  threat ticker: up to 3 lines, icon + text + bar
+------------------------------------------------+
|  >>                                            |  edge arrows when a RECOUNT or breach is coming
|                 3D battlefield                 |
|                                                |
+------------------------------------------------+  bottom controls (26%, was 23%)
| +-------------+ +----------+ +------+ +------+ |
| | 1 ARC PROJ. | | 2 SMG    | |STRIKE| | VENT | |  weapon bar: active 400 x 150, holstered 300 x 150,
| | LV2 [heat==]| | LV1 30/30| |  x2  | | -8%  | |  STRIKE and VENT 150 x 150
| +-------------+ +----------+ +------+ +------+ |
| [   EMP   ]    [  SHIELD  ]    [ OVERDRIVE ]   |  unchanged ability buttons
+------------------------------------------------+
```

- The UPGRADES tab and the drawer are gone. The magazine readout moves into the active weapon card (count or heat bar, RELOADING or VENTING text, level chevrons as in the concept bar).
- Tap the holstered card to swap. The active card pulses when a swap would help: the active weapon is reloading or venting and the other is ready (a hint, never an automatic action).
- STRIKE shows its charges; VENT shows its price and is dimmed when illegal (used this wave, core at 10% or less). FREIGHT replaces nothing: with `signal_hijack` it appears as a third small button and the active card narrows to 300.
- The threat ticker is new and sits under the top bar; it owns all event text. Banners are only for wave start, act start and bosses.
- The bottom band grows from 23% to 26% of the height (`visual_tokens.json` `bottom_controls_fraction`); `CameraFit` already takes the band heights as inputs, and the captures at 1080x1920 must show the whole arena still fits.
- Abilities locked by a Static Front show a static-pattern overlay and the text `OFFLINE` (state by icon and text, not only by colour).

### 11.5 Results screen additions

```
| DEFEAT   RELAY CORE B-4 LOST                   |
| ACT II  WAVE 8 OF 15      RUN TIME 9:42        |
| WHAT BROKE THE LINE: SLAG BATTERY + RAIN SQUALL|
|   spitter bolts 412   hollow wardens 260  ...  |
| YOUR BUILD: [ARC x4] [TEMPO x2]  ARC PROJ LV2, SMG LV1 |
|   directives: (12 icons, tap for the list)     |
| RECOVERED DATA +72   MILESTONE: NODE 5 FIRST KILL +50 |
| ARCHIVE: YOU CAN AFFORD  SLAG MORTAR (160)     |  the "one more run" hook
| SEED 48211 [ SAME SEED ]                       |
| [ RETRY ]   [ ARCHIVE ]   [ MENU ]             |
```

### 11.6 Archive (meta unlock) screen

```
+------------------------------------------------+
| ARCHIVE                  RECOVERED DATA  412   |
| [ARMORY] [DIRECTIVES] [KITS] [FIELD]           |  4 tabs, 250 x 132
+------------------------------------------------+
| TIER 1                                         |
| +----------------------+ +-------------------+ |
| | HORNET RACK   OWNED  | | LMG          120  | |  rows 500 x 200
| | Six targets at once  | | Sustained fire    | |
| +----------------------+ +-------------------+ |
| TIER 2  (3 unlocks needed: 2 / 3)              |
| | SLAG MORTAR   160 (locked) | ...             |
+------------------------------------------------+
| LMG  T4   DMG 20  4 to 10/s  150 rounds        |  detail panel of the selected row
| Spins up. Strays hit neighbours. Strips armor. |
| [            UNLOCK FOR 120 DATA             ] |  confirm; a second tap is not needed here because
+------------------------------------------------+   the button names the price and shows an UNDO for 5 s
```

The main menu gains: RESUME RUN (when a run file exists), ARCHIVE, DAILY RUN (after the first act I boss kill), and the kit selector on the briefing screen (a horizontal list of kit cards above DEPLOY).

### 11.7 First-run guidance

Hints stay one-line and event-tied, once per profile: first draft ("PICK ONE DIRECTIVE. THE REST ARE GONE"), first route ("HOT ROUTES PAY MORE AND HIT HARDER"), first crate ("HOLD THE AREA CLEAR TO SECURE THE DROP"), first second weapon ("TAP THE HOLSTERED WEAPON TO SWAP"), first event warning ("WATCH THE TICKER"), first corrupted offer ("RED DIRECTIVES COST SOMETHING FOR GOOD").

---

## 12. Audio and visual direction for the new content

### 12.1 Sounds to synthesise (`tools/audio_gen/voices.py` recipes; files `assets/audio/sfx/<id>.wav`)

| Group | New ids |
|---|---|
| Weapons | `shot_scattergun`, `shot_rifle`, `shot_hornet`, `hornet_pop`, `shot_lmg`, `lmg_spin` (loopable 1 s), `shot_mortar`, `mortar_blast`, `torch_loop` (loopable), `shot_arc`, `arc_chain`, `rail_charge`, `shot_rail`, `weapon_vent`, `weapon_swap` |
| Enemies | `burster_arm`, `blast_small`, `blast_big`, `spitter_shot`, `bolt_impact`, `splitter_split`, `ward_hum` (short), `ward_break`, `jammer_pop`, `borer_emerge`, `mote_burn`, `elite_spawn` |
| Bosses | `brood_hatch`, `lance_charge` (3 s rising, stinger class), `lance_fire`, `aegis_exposed`, `tremor_stomp`, `hulk_charge`, `boss_phase` |
| Events | `warn_harm` (two low pulses), `warn_help` (two rising pips), `strike_call`, `strike_impact`, `core_vent`, `freight_horn`, `freight_pass`, `static_front` (crackle bed, 2 s), `surge_up`, `brownout`, `breach_crack`, `recount_tick`, `relay_window`, `crate_land`, `crate_secured`, `crate_lost`, `drum_blast` |
| UI | `draft_open`, `draft_pick`, `draft_pick_corrupted`, `draft_reroll`, `route_pick`, `salvage_open`, `unlock_buy`, `act_start`, `resume_link` |

60 new ids (29 exist). Rules: all from the existing DSP kit (noise bursts, filtered sweeps, FM tones); deterministic (`gen.py --check` must stay byte-identical); each warning sting is distinct in rhythm, not only in pitch; nothing melodic. Two loop-capable weapon sounds (`lmg_spin`, `torch_loop`) need a small director feature: a held voice per weapon slot. `AudioCatalog` and the event router are extended by one owner (section 15.4).

### 12.2 Models (procedural, hard-surface kit, palette materials only)

| Asset | Triangle budget | Note |
|---|---:|---|
| 8 new weapons | 350 each | Section 3.5. The Warden budget becomes: body 2,300 + weapon in hand 350 (today 2,500 for both, 2,448 used with the pistol). The body must lose about 150 triangles or the budget rises to 2,650: owner of `ActorMeshes.TRI_BUDGET` decides after a look at the captures |
| Holstered weapon on the pack | reuses the weapon mesh | MID and HIGH only |
| `mote`, `shard` | 40 each | One mesh, 2 surfaces (ceramic, emit_red), instanced |
| `burster`, `spitter`, `borer`, `jammer` | 400 each | One mesh, 3 surfaces, pooled like today's enemies |
| `splitter`, `shieldbearer`, `reclaimer` | 500 each | Same |
| `ward_pylon` | 150 | |
| 4 new bosses | 900 each | Same budget as the Hulk; one pooled node each |
| Crate, freight car, fuel drum, strike beacon | 200, 600, 80, 100 | Arena props |

All new enemy materials are the existing `ceramic`, `dark_frame`, `gunmetal`, `hazard`, `emit_red`: no new material variant, so no new pipeline to warm. New effect materials reuse `add_cyan`, `add_amber`, `add_red`, `add_white`; the one new material is the red hatch for danger decals (unshaded, alpha), which must be added to `ShaderWarmup`.

### 12.3 Effect names and the readability rules they follow

Effects (ids used by the view): `fx_blast` (ring + flash), `fx_arc`, `fx_beam`, `fx_lob`, `fx_pool`, `fx_telegraph` (lane, ring, cracks, arrows), `fx_ward_ring`, `fx_elite_ring`, `fx_tether`, `fx_strike_column`, `fx_freight`, `fx_crate_ring`, `fx_scorch`, `fx_ghost_swarm`, `fx_static_overlay` (a HUD-space static pattern at the screen edges during a Static Front; never over the centre of the battlefield).

Rules: section 5.6, plus: (a) a flash that covers more than 5% of the screen lasts at most 0.25 s and is removed by Reduced Flash; (b) friendly beams and arcs are drawn thinner than the enemy's danger decals are wide, so a zone is never hidden by the player's own effects; (c) High Contrast thickens the hatch outline and the elite ring and brightens optics (existing switch); (d) during a 6-blast chain the optics of survivors must still be countable in a capture: this is a legibility test with a fixed seed (`look_dev_legibility.gd` pattern).

---

## 13. Technical impact

Legend: NEW = new file or class; EXT = existing contract extended (append only unless stated); FROZEN = unchanged.

### 13.1 Content (`data/`, `src/content/`)

New data files (all `schema_version: 1`, all listed in the export preset's `include_filter`, which already covers `data/*.json`):

| File | Top-level fields |
|---|---|
| `data/run.json` | `acts[] {id, name_key, hp_mult, core_dmg_mult, rarity_weights[3], corrupted_chance, elites_min, elites_max, affixes_min, affixes_max}`, `waves[] {index, act, kind, budget, window_s, peak_bodied, peak_minis, event_slots, fixed_pack?}`, `packs[] {id, name_key, min_act, budget_mult, extra_elites, groups[] {enemy, share, region, start, tempo}}`, `modifiers[] {id, name_key, list, ops[]}`, `route_rewards[] {id, name_key, weight_standard, weight_hot, ops[]}`, `draft {offer_size, skip_scrap, reroll_base, reroll_step, buyout_base, buyout_step, patch_frac, patch_base, patch_step, tag_lean, weapon_lean, repeat_penalty, rare_pity}`, `salvage {secure_s, contest_radius_m, lifetime_s, bank_max, scrap_by_act[3], tier_weights[3][4], dupe_bias}`, `caps {swarm_cap, max_elites_alive, max_blasts_per_tick}`, `reward {per_wave, boss_by_act[2], victory_base, victory_core_bonus}`, `mission {shop_enabled, breather_seconds}` |
| `data/weapons.json` | `weapons{} {tier, kind, damage, shots_per_second, magazine, reload_seconds, range_m, min_range_m, spread_deg, pierce, pierce_falloff, area_m, pellets, salvo, flight_s, chains, chain_range_m, chain_falloff, charge_s, heat_per_shot, cool_per_s, heat_cap, vent_s, armor_ignore, ward_mult, stunned_mult, spin_up_s, sps_min, stray_chance, armor_shred, pool{}, knockback_m, level_mult[3], level3{}}`, `turrets{}` (CONTENT 8), `swap_seconds`, `holster_reload_mult` |
| `data/enemies.json` | `enemies{}` = the balance fields plus the `content_ext` fields plus `class, cost, min_act, alive_cap, standoff_m, behaviour{}` for the 9 new types and the 4 new bosses; `overrides{}` (new Scrap values and `class`, `cost`, `alive_cap` for the 4 old types); `elite {hp_mult, scale, scrap_mult}`, `affixes[] {id, name_key, ops[]}`, `affix_rules {forbidden_pairs[], by_act[]}`, `bosses{} {pool_act, hp, behaviour{}, escorts[]}`, `hulk_variants[]` |
| `data/directives.json` | `directives[] {id, category, rarity, max, tags[], requires{}, ops[], hook?, pool}` in a fixed order (the index is the position) |
| `data/events.json` | `events[] {id, who, name_key, warn_s, duration_s, weights[3], boss_safe, harmful, params{}}`, `hazards{}`, `rules {window_min, window_max, mercy_core_frac}` |
| `data/unlocks.json` | `unlocks[] {id, branch, tier, cost, grants[]}`, `kits[] {id, name_key, cost, ops[]}`, `tier_gates[]`, `milestones[] {id, data}` |
| `data/strings/variety_en.json` | All new player text (keys `directive.*`, `weapon.*`, `enemy.*`, `event.*`, `route.*`, `archive.*`, `kit.*`, `hud.*` additions) |
| `data/arena.json` schema 1 to 2 | adds `standoff {radii[], counts[]}`, `breach_points[]`, `drop_points[]`, `drum_points[]`, `rail_lines[] {z, half_width}` |

`ops[]` is one small grammar shared by directives, modifiers, kits, affixes and rewards: `{ "stat": "<ModState field>", "add": n }`, `{ "stat": ..., "mul": n }`, `{ "flag": "<name>" }`, `{ "grant": "<kind>", "n": n }`. 34 of the 60 directives need nothing else.

Contract changes:

| Contract (ARCH) | Change | Why no alternative |
|---|---|---|
| 5.2 file list | +6 files, `arena.json` schema 2 | New content kinds; putting them in the handoff-schema balance file would break the frozen baseline fixture |
| 5.3 defs | EXT `EnemyDef` (+`enemy_class`, `cost`, `min_act`, `alive_cap`, `standoff_m`, behaviour fields), `WeaponDef` (+ the fields above), `MissionDef` (+`swarm_cap`, `breather_ticks`, `shop_enabled`), `ArenaDef` (+ the new point lists), `ContentSet` (+`run`, `directives`, `events`, `unlocks`, `affixes`, `bosses`). NEW `RunDef`, `ActDef`, `WaveSlotDef`, `PackDef`, `ModifierDef`, `RewardDef`, `DirectiveDef`, `OpDef`, `EventDef`, `AffixDef`, `BossDef`, `UnlockDef`, `KitDef` | Typed defs are the project convention |
| 5.4 loader | `ContentLoader.build` gains a 7th parameter `variety: Dictionary = {}` (file name to parsed JSON). Empty = today's content exactly (the legacy fixture). `STRING_FILES` gains `variety_en.json`, loaded only if present | The 6-dictionary signature is called by `TestContent.baseline()`; a default parameter keeps every existing call valid |
| 5.4 validator | New rules, each with a bad fixture: every id referenced exists; pack shares sum to 1; every wave has a pack available for its act; `alive_cap` >= 1; weights not all zero; ops name real stats; drop, drum and breach points are free cells that reach the core; rail lines cross no pad, no core, no Warden; standoff points are free; kits reference unlocked-or-base items; unlock grants are disjoint; boss pools have at least 1 entry per act | - |
| `Content` boot line | `content ok enemies=18 waves=15 directives=60 hash=...` | The smoke test greps `content ok` only, so it still passes |

### 13.2 Sim (`src/sim/`, `src/shared/`)

Shared (frozen files, changed once by the scaffold task V1-S, append only):

| File | Change |
|---|---|
| `ids.gd` | `ENEMIES` + `mote, shard, burster, spitter, splitter, shieldbearer, reclaimer, jammer, borer, ward_pylon, brood_carrier, lance_platform, aegis_array, tremor_rig` (index 4 to 17); `WEAPONS` + `scattergun, assault_rifle, hornet_rack, lmg, slag_mortar, cutting_torch, arc_projector, rail_lance` (index 2 to 9); `EN_*` and `WP_*` constants. Existing indices do not move ("fixed forever" is kept) |
| `damage_source.gd` | + `WARDEN_OFFHAND = 3`, `CORE = 4`, `STRIKE = 5`, `HAZARD = 6`; `CombatState.SOURCES` 3 to 7 |
| `reason.gd` | + `NOT_AWAITING`, `INVALID_CHOICE`, `NO_CHARGES`, `LOCKED_BY_EVENT`, `SHOP_CLOSED` |
| `game_state.gd`, `game_state_machine.gd`, `run_result.gd` | FROZEN |

`SimWorld` (frozen file, V1-S): new fields `plan: RunPlan`, `mods: ModState`, `arsenal: ArsenalState`, `draft: DraftState`, `salvage: SalvageState`, `ext: EnemyExtState`, `hazards: HazardState`, `events_state: EventState`, `boss: BossState`; `spawn_enemy` respects the class, type and elite caps; `kill_enemy` calls `DeathHooks.on_killed` (queues blasts, splits, crate credit; never recursion); `step()` returns early while awaiting (2.5); `state_hash` adds the new states in a fixed order after the existing ones; store capacity `enemy_cap + swarm_cap + 8`.

New tick order (EXT of ARCH 6.2; unchanged steps keep their relative order):

```
 1  (awaiting and no command queued: return)        tick += 1
 2  CommandSystem.apply_queued
 3  PhaseSystem.pre_step                            breather countdown; wave start reads the chosen RouteOption
 4  EventSystem.step                                warnings, starts, ends of planned and called events
 5  SpawnSystem.step                                + class, type and elite caps; breach spawns
 6  AbilitySystem.step                              + lock by static_front, cooldown rate from jammers / modifiers
 7  StatusSystem.step                               slow, burn, ward regeneration, auras, reclaimer tethers
 8  MovementSystem.step                             + mini path, standoff points, knockback, boss motion hooks
 9  WeaponSystem.step                               delegates to ArsenalSystem (active slot, off-hand, swap, heat)
10  TurretSystem.step                               + offline timers, rate multipliers, turret hooks
11  HazardSystem.step                               delayed hits, blasts (max 8 per tick), pools, mines, drums
12  CoreAttackSystem.step                           + burnout hits, fuses, spitter bolts landing, core hooks
13  BossSystem.step                                 the alive boss's script
14  SalvageSystem.step                              crate progress
15  PhaseSystem.post_step                           defeat (after dead_mans_switch), clear, awaits
16  stats.sample
```

New files (each a class of static functions or a state class with `hash_into`, `to_dict`, `from_dict`):

| File | Role |
|---|---|
| `sim/plan/run_plan.gd`, `planned_wave.gd`, `route_option.gd`, `planned_event.gd`, `planned_elite.gd` | Section 9.3 |
| `sim/systems/run_plan_system.gd`, `wave_builder.gd` | Build the plan at tick 0; pack to groups |
| `sim/systems/draft_system.gd`, `sim/stores/draft_state.gd` | Offers, pity counters, rerolls, buy-outs, skip |
| `sim/systems/mod_system.gd`, `sim/stores/mod_state.gd` | Applies `ops`; `ModState` is a flat set of typed fields recomputed when a directive, kit or modifier changes |
| `sim/systems/arsenal_system.gd`, `sim/stores/arsenal_state.gd` | Slots (weapon index, level, magazine, reload, heat, vent), active slot, swap timer, charge timer. `WardenState.weapon_index`, `magazine`, `reload_ticks_left` stay and mirror the active slot, so the HUD, the view and old tests keep reading them |
| `sim/systems/fire/fire_hitscan.gd`, `fire_cone.gd`, `fire_arc.gd`, `fire_line.gd`, `fire_shell.gd`, `fire_missiles.gd`, `fire_beam.gd` | One file per firing kind (parallel work without conflicts); `ArsenalSystem` dispatches on `WeaponDef.kind` |
| `sim/systems/area_damage.gd` | `blast(world, x, z, radius, damage, edge_frac, flags, source)` |
| `sim/systems/hazard_system.gd`, `sim/stores/hazard_state.gd` | The delayed-effect queue, pools, mines, drums |
| `sim/systems/status_system.gd`, `sim/stores/enemy_ext_state.gd` | Parallel arrays per store index: `flags`, `affix_mask`, `ward_milli`, `ward_regen_cd`, `slow_ticks`, `slow_milli`, `burn_ticks`, `burn_milli`, `shred_milli`, `fuse_ticks`, `aux_cd`, `anchor_point`, `hp_scale_milli`. (`EnemyStore` is frozen: ARCH 6.4 says extra state goes in its own class) |
| `sim/systems/death_hooks.gd`, `core_hooks.gd`, `shot_hooks.gd` | The HOOK directives of CONTENT 3, one function per hook point |
| `sim/systems/elite_system.gd` | Applies affixes at spawn; aura and leech rules |
| `sim/systems/event_system.gd`, `sim/stores/event_state.gd`, `sim/systems/events/event_<id>.gd` (10 files) | One file per event |
| `sim/systems/boss_system.gd`, `sim/stores/boss_state.gd`, `sim/systems/bosses/boss_<id>.gd` (5 files) | One file per boss |
| `sim/systems/salvage_system.gd`, `sim/stores/salvage_state.gd` | Crates on the field, the bank, crate contents |
| `sim/ai/policy_*.gd` (7 files), `sim/ai/scorecard.gd`, `build_signature.gd` | Section 14 |

Changed system contracts (ARCH 6.6):

| Contract | Change |
|---|---|
| `SimCommand.Kind` | + `PICK_DIRECTIVE, SKIP_DRAFT, REROLL, BUY_OUT, PATCH_CORE, PICK_ROUTE, SALVAGE, SWAP_WEAPON, CALL_EVENT` with static constructors. `arg` meanings: slot, -, -, slot, -, option, `choice * 16 + action` (action 0..2 slot, 8 level up, 9 scrap), slot, event index |
| `SimEventKind` | + `ACT_STARTED, DRAFT_OFFERED, DIRECTIVE_PICKED, DRAFT_REROLLED, ROUTE_OFFERED, ROUTE_PICKED, BOSS_BRIEFED, AWAIT_CHANGED, CRATE_DROPPED, CRATE_SECURED, CRATE_LOST, SALVAGE_RESOLVED, WEAPON_SWAPPED, WEAPON_VENTED, AREA_BLAST (a kind, b radius in cm, f x, g z), CHAIN_ARC (a from id, b to id), DELAYED_HIT_LAUNCHED (a kind, b ticks, f x, g z), POOL_STARTED, POOL_ENDED, ELITE_SPAWNED (a id, b affix mask), ENEMY_SPLIT, WARD_CHANGED, WARD_BROKEN, ENEMY_HEALED, EVENT_WARNED (a event, b ticks, f x, g z), EVENT_STARTED, EVENT_ENDED, EVENT_CANCELLED, BOSS_TELEGRAPH (a attack, b ticks), BOSS_PHASE, CORE_HEALED, CHARGES_CHANGED, COMMAND_REJECTED (a command id, b Reason)`. Existing kinds and payloads unchanged |
| `Targeting` | Signatures FROZEN. `is_valid` and `compare` read `world.ext` for MAGNETIC, SHROUDED and the mini rule. NEW `Targeting.pick_cluster(world, x, z, min_range, max_range, radius) -> Vector2` and `pick_many(world, x, z, range_m, n, out) -> int` |
| `DamageResolver` | `hit(...)` FROZEN (it calls the new path with no flags). NEW `hit_ex(world, enemy_index, amount, flags, source) -> float` with `F_IGNORE_ARMOR, F_HALF_ARMOR, F_AREA, F_NO_WARD, F_BURN`. Still the only writer of `enemies.hp` (heals included: `heal(world, enemy_index, amount)`) |
| `SpawnSystem.begin_wave` | Reads the groups of the chosen `RouteOption` instead of `content.waves[n - 1]` when `world.plan` exists; signature FROZEN |
| `PhaseSystem` | Awaits (2.5), acts, wave count from the plan (`content.waves.size()` in the legacy fixture) |
| `EconomySystem.purchase` | Answers `SHOP_CLOSED` when `mission.shop_enabled` is false; otherwise unchanged |
| `SimConfig` | + `kit_index: int`, `unlocked: PackedStringArray` (sorted), `daily: bool`. `create(content, seed)` keeps working (base pool, standard kit) |
| `RunStats`, `RunSummary` | + `act_reached`, `combat_ticks`, `directives: PackedInt32Array`, `weapons: PackedInt32Array`, `route_choices`, `core_damage_by_type`, `damage_by_source` (7), `events_seen`, `crates_secured`, `boss_ids`; `kills_by_type` and `peak_alive_by_wave` are sized from content |
| Field ownership table | New rows: one writer per new state class (the system of the same name); `enemies.hp` still only `DamageResolver`; `core_hp` gains `HazardSystem` (vent price) and `ModSystem` (max changes, repairs) through `set_core_hp` |

What stays frozen in the sim: `EnemyStore`, `TurretStore`, `AbilityState`, `WardenState` field lists; `Formulas` (all functions and golden values); `SimRng`, `StateHasher`, `SimEvents`, `CommandLog`; the signature of `Replay.run` (its loop gains one guard: it returns when the world is awaiting a choice and no logged command remains, otherwise a truncated log would spin forever because the tick does not advance; resume relies on the same stop); the fire cadence accumulator; the flow field, spatial hash and attack slots; the 60-tick rate.

### 13.3 Save (`src/save/`)

**Profile v2**, file `user://profile_v2.json` (+ `.tmp`, `.bak`):

```json
{ "schema_version": 2, "data": 0, "data_lifetime": 0, "missions_completed": 0, "best_core_hp": 0, "runs_played": 0,
  "awarded_run_ids": [], "hints_seen": [], "unlocks": [], "claimed": [], "kit": "k_standard",
  "codex_seen": [], "best_wave": 0, "boss_kills": {}, "victories_by_kit": {}, "victory_weapons": [],
  "daily": { "date": "", "best_wave": 0, "won": false, "rewarded": false },
  "settings": { "sound_on": true, "music_on": true, "haptics_on": true, "reduced_flash": false, "high_contrast": false,
                "quality": 2, "fps_cap": 60, "swap_assist": false } }
```

Migration from v1 (in `SaveManager.load_profile`, with tests on fixture files):

1. If `profile_v2.json` loads: use it.
2. Else if `profile_v1.json` loads (or its `.bak`): copy every v1 field as is; `data_lifetime = data`; the new lists are empty; `kit = "k_standard"`; `best_wave = 5` if `missions_completed > 0` else 0; write `profile_v2.json`; **leave the v1 files untouched** (a downgrade still finds them). Status `MIGRATED_FROM_V1` (new `LoadStatus` value).
3. Else: new profile. Corruption and newer-schema rules are the existing ones, applied to the v2 file names.

Testers keep their Data; nothing is unlocked for free. `Profile.SCHEMA_VERSION` becomes 2; `ProfileCodec` validates the new fields (unknown unlock ids are kept but ignored, so a newer build's file is not destroyed by an older one).

New `Save` methods: `purchase_unlock(id) -> int` (a `Reason.Id`), `has_unlock(id)`, `set_kit(id)`, `grant_run_reward(run_id, result, data_amount, core_hp, extras: Dictionary)` (the 5th parameter is new and optional: milestones, best wave, boss kills, daily flags), `save_run(doc: Dictionary) -> bool`, `load_run() -> Dictionary`, `clear_run()`.

**Run file** `user://run_v1.json`:

```json
{ "schema_version": 1, "build": "0.2.0", "content_hash": "<12 chars>", "run_id": "<unix>-<seed>", "seed": 48211,
  "kit": "k_standard", "unlocked": ["u_w_lmg"], "daily": false,
  "boundary": { "wave": 6, "tick": 21480, "state_hash": "<sha256>", "state": { "...": "to_dict of every state class" } },
  "log": [ { "tick": 12, "id": 3, "kind": 1, "arg": 0 } ],
  "tail": [ { "tick": 21481, "id": 311, "kind": 3, "arg": 1 } ], "resume_tick": 22950,
  "debug": { "invulnerable": false, "damage_mult": 1.0, "start_scrap": 0 } }
```

`log` is every command up to `boundary.tick`; `debug` is optional (debug runs only); `boundary.wave` is waves cleared; the snapshot
`VERSION` is 2; non-trivial floats travel as `~` plus 16 hex digits, 64-bit ints as decimal strings, packed arrays as `f:`, `i:`
or `b:` plus hex.

### 13.4 Game flow (`src/game/`, `src/core/`)

| Item | Change |
|---|---|
| `Events` (frozen file, V1-S, append only) | + `act_started(act)`, `await_changed(kind)`, `draft_offered(ids: Array[StringName])`, `directive_picked(id, stacks)`, `route_offered()`, `route_picked(option)`, `crate_dropped(x, z)`, `crate_secured()`, `crate_lost()`, `salvage_offered()`, `weapon_swapped(slot, id)`, `weapon_vented(slot)`, `area_blast(kind, x, z, radius)`, `chain_arc(from_id, to_id)`, `delayed_hit(kind, x, z, ticks)`, `pool_changed(id, x, z, radius, on)`, `elite_spawned(id, kind, affixes)`, `ward_changed(id, fraction)`, `event_warned(id, ticks, x, z)`, `event_started(id)`, `event_ended(id)`, `boss_telegraph(attack, ticks)`, `boss_phase(phase)`, `charges_changed(id, n)`, `command_rejected(command_id, reason)`, `unlock_purchased(id)` |
| `RunApi` (frozen file, V1-S, append only) | Commands: `pick_directive`, `skip_draft`, `reroll_draft`, `buy_out`, `patch_core`, `pick_route`, `resolve_salvage`, `swap_weapon`, `call_event`, `continue_run`. Queries: `awaiting()`, `act()`, `act_count()`, `draft_offer() -> PackedInt32Array`, `draft_reroll_cost()`, `draft_buyout_cost()`, `patch_cost()`, `free_rerolls()`, `route_option_count()`, `route_option(i) -> Dictionary` (pack, counts by type, modifier, elites, hot, reward), `boss_brief() -> Dictionary`, `salvage_offer() -> Dictionary`, `weapon_slot_count()`, `weapon_slot(i) -> Dictionary` (id, level, magazine, size, heat, state), `active_slot()`, `event_charges(id)`, `call_block_reason(id)`, `active_events() -> Array[Dictionary]`, `directive_stacks(id)`, `build_tags() -> Dictionary`, `boss_phase()`, `boss_phase_count()`, `run_seed()`. The old upgrade queries stay and return the legacy values |
| `FakeRunApi` | Mirrors every addition (the HUD sandbox must show draft, route, salvage and the weapon bar without a sim) |
| `GameEventRelay` | Maps the new sim events to the new signals |
| `RunController` | Run file writes (2.8), resume entry `start_resumed(doc, view)`, the reward extras, no stepping logic change (the sim holds itself) |
| `Game` | `start_run(run_seed, kit_id, daily)`, `resume_run_from_disk()`, `open_archive()`, the intermission screens' lifecycle (they are HUD overlays, not application states) |
| `GameStateMachine` | FROZEN. Draft, route and salvage are overlays inside INTERMISSION; the Archive is an overlay on MENU |
| `BackPolicy` | Back on a choice overlay = pause (a choice can never be dismissed); back on the Archive = close |
| `MobileShell` | Also writes the run file on app pause |

### 13.5 UI (`src/ui/`)

NEW `src/ui/run/`: `draft_overlay.*`, `directive_card.gd`, `route_overlay.*`, `route_card.gd`, `boss_brief_overlay.*`, `salvage_overlay.*`, `build_list.gd`. NEW `src/ui/screens/archive_screen.*`, `kit_selector.gd`. Changed in `src/ui/combat/`: `combat_hud.gd` (drawer removed, weapon bar, call buttons, ticker), NEW `hud_weapon_bar.gd`, `hud_weapon_card.gd`, `hud_call_button.gd`, `hud_threat_ticker.gd`, `hud_edge_arrows.gd`; `hud_boss_bar.gd` (phase pips); `hud_top_bar.gd` (act and wave of 15). `results_screen.gd`, `main_menu_screen.gd`, `briefing_screen.gd`, `pause_overlay.gd` extended. `hud_upgrade_drawer.gd` and `hud_upgrade_card.gd` are deleted in the cleanup task (V5-A), not before, so the legacy HUD tests can be migrated in one place. ARCH 9 table: +7 rows; `CombatHud.is_drawer_open` and `close_drawer` stay as no-ops returning false until V5-A removes them together with `BackPolicy`'s drawer branch. New icons in `assets/icons/`: 60 directive icons are too many to hand-author well; use 8 tag glyphs x 4 rarity frames plus a category corner mark (about 20 SVGs), and the weapon silhouettes (10).

### 13.6 View (`src/view/`)

`EnemyPool.SIZES` becomes data-driven from `EnemyDef.alive_cap` (bodied types only). NEW `actors/mini_swarm.gd` (the MultiMesh minis), `actors/enemy_meshes_2.gd` and `boss_meshes.gd`, `actors/weapon_meshes.gd` (the 8 weapons), `actors/crate_view.gd`, `arena/rail_lines.gd`, `arena/freight_view.gd`, `arena/drum_view.gd`; `vfx/fx_blasts.gd`, `fx_arcs.gd`, `fx_beams.gd`, `fx_lobs.gd`, `fx_zones.gd` (pools, wards, telegraphs, elite rings, tethers), `fx_strike.gd`, `fx_cosmetic.gd` (scorch, ghost swarm, embers). `VfxLayer` gets one `setup` call per new module and stays under 400 lines by delegating. `BattleView` signatures FROZEN. `ShaderWarmup` covers the one new material. `VisualQuality` gets the tier tables of 10.3 and 10.4. The ground material gains two faint rail lines (kept low-contrast, GDD 12.3).

### 13.7 Audio (`src/audio/`, `tools/audio_gen/`, `assets/audio/`)

`voices.py` + 60 recipes; `gen.py` count text; `AudioCatalog` + ids, classes (weapon, blast, alert, ui) and the per-class voice limits of 10.5; `AudioEventRouter` + the new signals; `AudioDirector` + two held weapon voices (`hold(id, slot)`, `release(slot)`); the combat drone's intensity follows `act` and wave budget instead of the wave number.

### 13.8 Debug and tools

| Item | Change |
|---|---|
| `DebugArgs` | + `--kit=<id>`, `--unlock=all|none|<ids>`, `--daily`, `--autoplay=<policy>` accepts the 8 policies, `--scenario=hold<N>+<M>` (N bodied + M minis), `--scenario=chain` (a burster line and a strike, for perf), `--scenario=event:<id>`, `--scenario=boss:<id>`, `--wave=<n>` (start at wave n with a scripted build) |
| `SimPuppet` | Drives minis, blasts, pools, telegraphs and a boss telegraph so the view tasks do not wait for the sim |
| `tools/sim_run.*` | `--policy` accepts every policy; prints the build signature and the death wave |
| `tools/balance_run.*` | Reads the redefined targets (section 14.3) |
| NEW `tools/scorecard_run.gd`, `scorecard_run.ps1 -Runs n [-Pool base\|full]` | The predictability scorecard; last line `SCORECARD: PASS\|WARN\|FAIL rows=.. pass=.. warn=.. fail=.. runs=..`; exit 1 on FAIL |
| NEW `tools/plan_dump.gd`, `plan_dump.ps1 -Seed n` | Prints a seed's whole plan (bosses, both options of every wave, events) for bug reports and design review |
| `tests/unit/core/test_contracts.gd` | Extended by V1-S only |

### 13.9 Tests and fixtures: migration

| Item | Decision |
|---|---|
| `tests/fixtures/data_baseline/` (the untouched 5-wave handoff data) | **Kept as it is.** With no `variety` files `ContentLoader.build` produces today's content: 4 enemies, 5 scripted waves, the shop enabled, no plan, no drafts. The 1,063 existing tests keep guarding the sim core (movement, targeting, cadence, slots, abilities, economy, replay) on it |
| NEW `tests/fixtures/data_variety/` | A frozen copy of the first complete variety data set, made in V3-I and refreshed only by an explicit task. `TestContent.variety()` loads it. All new unit tests use it (rule 5 of WP 1 stays: no unit test reads `res://data/`) |
| Tests that read `res://data/` on purpose (e2e suites, `test_e2e_main_scene`: greedy seed 1, VICTORY, five waves and the Hulk) | Rewritten in V3-I and V5-A for the 15-wave run: a scripted policy with a debug build (`--unlock=all`, `debug_damage_mult`) for a fast deterministic victory, and a `none` run for a defeat |
| HUD tests of the drawer and the upgrade cards | Stay green until V5-A deletes the drawer; then removed with it. New HUD tests come with V2-E and V4-U |
| `test_contracts.gd` | Append only |
| Save fixtures | + v1 files to migrate (plain, with `.bak` only, corrupt, newer schema), v2 files, run files (valid, hash mismatch, wrong build, truncated tail) |
| Stress | `test_stress_ten_minutes` gets a variant at 50 + 40 with blasts every second; limit 1.0 ms per tick on the desktop |
| Whether to delete the legacy path later | Open question Q7: keeping it costs one `if` in three systems and buys 1,000 regression tests |

---

## 14. Measurement and balance plan: how we know it is less predictable

### 14.1 Bots

`PolicyBot.Policy` grows from `{NONE, GREEDY}` to 8 policies (parameters in CONTENT 13): `none`, `greedy` (the old "cheapest first" habit: lowest rarity, leftmost, standard route), `random`, `hoarder` (weapons), `spammer` (abilities), `turret_rush`, `balanced` (the reference competent player), `risk` (hot routes and corrupted directives). Each is one file under `src/sim/ai/` implementing `act(world)`; all are deterministic; none reads a sim stream.

### 14.2 The predictability scorecard

Run by `tools/scorecard_run.ps1 -Runs 200` (200 seeds x 8 policies = 1,600 runs; at 60 to 180 times real time on the desktop this is roughly 2 to 6 hours of machine time for 15-minute runs, so the gate version is `-Runs 30` and the full card runs in the balance task). PASS, WARN and FAIL follow the `balance_run` convention: WARN prints the number, FAIL is a structural break.

| # | Question | Metric | Target |
|---|---|---|---|
| S1 | Do seeds matter? | `balanced`: standard deviation of the core HP fraction at the end of act I, over seeds | at least 0.12 (today: about 0.05) |
| S2 | | `balanced`: standard deviation of combat duration among wins | at least 45 s (today under 5 s) |
| S3 | | Median Jaccard similarity of the final directive sets of two `balanced` runs on different seeds | at most 0.35 |
| S4 | Is a competent player challenged? | `balanced` win rate | 40% to 70% |
| S5 | Does skill matter? | `random` win rate | at most 10% |
| S6 | | `none` | always defeated, in act I |
| S7 | | `greedy` (today it wins 100%) | 10% to 40% |
| S8 | Are early waves survivable? | Any policy except `none`: defeated before wave 3 | 0 runs; before wave 4: at most 2% |
| S9 | Is loss possible everywhere? | `balanced` losses by act | each act holds at least 15% of the losses; boss waves hold 25% to 50% of all losses |
| S10 | Is there a dominant strategy? | Win rate of each specialist (`hoarder`, `spammer`, `turret_rush`, `risk`) | each 15% to 65%, none more than 10 points above `balanced` |
| S11 | How many winning builds? | Build signature = primary weapon (most damage dealt) + the two tags with most stacks. Among all wins: | at least 8 signatures each with 4% or more of the wins; no signature above 25% |
| S12 | Is a weapon dominant? | Share of wins by primary weapon | none above 30%; every weapon at least 3% |
| S13 | Is a directive dominant? | Win rate when held minus win rate when offered and not picked (`random` and `balanced` pooled) | no directive above +15 points; none below -15 |
| S14 | Do routes matter? | `balanced` forced always-standard vs always-hot | both between 25% and 65%; hot gives more Data per run |
| S15 | Does the meta pool keep builds reachable? | `balanced` win rate, base pool vs full pool | difference at most 5 points |
| S16 | Is the run the right length? | Combat time of wins | 780 to 1,020 s |
| S17 | Is the chaos budget respected? | Peak bodied and minis per act; blasts per tick | within the caps; peaks within 20% of CONTENT 1.1 |
| S18 | Fairness rule 7.3.8 | `greedy`: largest core loss in one act I wave from full | at most 60% |

### 14.3 GDD 8.4 targets, redefined

| Old target | New target |
|---|---|
| First-win run length 270 to 360 s | S16: 780 to 1,020 s of combat for a win |
| Peak alive per wave 10 / 18 / 28 / 40 / 50 within 20% | S17 with the peak columns of CONTENT 1.1 (bodied and minis separately) |
| A bot that buys nothing loses by wave 3 or 4 | S6: `none` is defeated in act I (waves 3 to 5) |
| The greedy bot wins with 30% to 80% core | S4 and S7: `balanced` wins 40% to 70% of seeds; `greedy` wins 10% to 40%. Mean core at victory for `balanced`: 25% to 65% |

Tuning levers, in order: wave budgets and windows; pack shares; act tiers; enemy stats; weapon and directive numbers; draft weights. Never invulnerability or hidden scaling (unchanged rule). Every change to `data/*.json` is justified by a scorecard run and recorded in `docs/reports/BALANCE_REPORT.md` (a new part 2).

### 14.4 Human checks the bots cannot do

Bots measure spread and dominance; they do not measure suspense or readability. Three owner playtests are gates: after V3-I (the slice: "is the loop fun?"), after V4 (the full content: "can I read it?"), after V5-C (the tuned game: "one more run?"). Each has a short form: where did you die, what surprised you, what could you not read, which choice felt empty.

---

## 15. Implementation plan

Style and rules as in WP section 1 (own only your paths, contracts frozen after the scaffold, verify with the wrappers, one worktree per task at `C:\dev\tower-two-wt\<ID>\`, branch `task/<ID>`, merge then `check.ps1` on `main`). Effort is in agent-hours and is an estimate, not a measurement. Every task ends with `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two-wt\<ID>\tools\check.ps1` exiting 0 with last line `CHECK OK`; the commands below are the additional, task-specific checks (shown without the common prefix `powershell -NoProfile -ExecutionPolicy Bypass -File C:\dev\tower-two-wt\<ID>\`).

### 15.1 Wave overview

| ID | Title | Owned paths (summary) | Depends on | Hours |
|---|---|---|---|---:|
| **V1-S** | Contract scaffold | the shared and frozen files of 15.4, every new file as a compiling stub, the slice data, fixtures | - | 12 |
| V2-A | Sim: run plan, wave builder, phases and awaits | `src/sim/plan/`, `src/sim/systems/{run_plan_system,wave_builder,phase_system,phase_state,spawn_system}.gd`, `tests/unit/sim_plan/` | V1-S | 9 |
| V2-B | Sim: drafts, directives, modifiers | `src/sim/systems/{draft_system,mod_system,command_system,economy_system}.gd`, `src/sim/stores/{draft_state,mod_state}.gd`, `tests/unit/sim_draft/` | V1-S | 8 |
| V2-C | Sim: arsenal, arc projector, blasts, burster, salvage | `src/sim/systems/{arsenal_system,weapon_system,damage_resolver,area_damage,hazard_system,status_system,death_hooks,salvage_system,core_attack_system}.gd`, `src/sim/systems/fire/{fire_hitscan,fire_arc}.gd`, `src/sim/stores/{arsenal_state,hazard_state,enemy_ext_state,salvage_state}.gd`, `tests/unit/sim_arsenal/` | V1-S | 12 |
| V2-D | Game flow, run file, resume | `src/game/**`, `src/core/game.gd`, `src/save/**`, `tests/unit/{game,save}/`, `tests/integration/game/`, `tests/fixtures/saves/` | V1-S | 10 |
| V2-E | UI: draft, route, salvage overlays, weapon bar | `src/ui/run/**`, `src/ui/combat/**`, `assets/icons/`, `data/strings/variety_en.json`, `tests/unit/ui/` | V1-S | 12 |
| V2-F | View: arc projector, burster, minis, blast and arc effects | `src/view/**` except `battle_view.gd`, `tests/unit/view/` | V1-S | 10 |
| V2-G | Audio: slice sounds and voice classes | `src/audio/**`, `tools/audio_gen/**`, `assets/audio/**`, `tests/unit/audio/` | V1-S | 5 |
| V2-H | Bots and tools for drafts | `src/sim/ai/**`, `tools/{sim_run,balance_run,plan_dump}.*`, `tests/unit/sim_ai/` | V1-S | 6 |
| V2-P | Phone baseline and mini stress (uses the device) | `src/debug/**`, `docs/reports/PERFORMANCE_REPORT.md` | V1-S | 5 |
| **V3-I** | Slice integration and owner playtest build | `src/**`, `data/**`, `tests/**` (fixes only), `tests/fixtures/data_variety/` | Wave V2 | 10 |
| V4-W | Sim: the other 7 weapons and weapon levels | `src/sim/systems/fire/{fire_cone,fire_line,fire_shell,fire_missiles,fire_beam}.gd`, `src/sim/systems/{arsenal_system,shot_hooks}.gd`, `data/weapons.json`, `tests/unit/sim_arsenal/` | V3-I | 12 |
| V4-N | Sim: the other 8 enemy types, elites | `src/sim/systems/{status_system,elite_system,movement_system,core_attack_system,targeting}.gd`, `src/sim/nav/**`, `data/{enemies,arena}.json`, `tests/unit/sim_enemies/`, `tests/unit/sim_nav/` | V3-I | 14 |
| V4-L | Sim: bosses | `src/sim/systems/boss_system.gd`, `src/sim/systems/bosses/**`, `src/sim/stores/boss_state.gd`, `tests/unit/sim_boss/` | V3-I | 12 |
| V4-V | Sim: events and hazards | `src/sim/systems/{event_system,hazard_system,ability_system,turret_system}.gd`, `src/sim/systems/events/**`, `src/sim/stores/event_state.gd`, `data/events.json`, `tests/unit/sim_events/` | V3-I | 11 |
| V4-C | Sim: the other 52 directives, packs, modifiers, kits | `src/sim/systems/{mod_system,draft_system,death_hooks,core_hooks,wave_builder,run_plan_system}.gd`, `data/{directives,run}.json`, `tests/unit/sim_draft/`, `tests/unit/sim_plan/` | V3-I | 10 |
| V4-M | Save v2, unlocks, rewards, daily seed | `src/save/**`, `src/game/{game_rewards,game_launch}.gd`, `data/unlocks.json`, `tests/unit/save/`, `tests/fixtures/saves/` | V3-I | 8 |
| V4-U | UI: Archive, kits, results, ticker, boss bar, hints | `src/ui/**`, `assets/icons/`, `data/strings/{variety,screens,combat,lore}_en.json`, `tests/unit/ui/` | V3-I | 14 |
| V4-R | View: weapon, enemy and boss models | `src/view/actors/**`, `tests/unit/view/actors_*` | V3-I | 14 |
| V4-X | View: effects, zones, events, cosmetic chaos, tiers | `src/view/{vfx,arena,kit}/**`, `tests/unit/view/{vfx,arena,kit}_*` | V3-I | 12 |
| V4-A | Audio: the remaining sounds | as V2-G | V3-I | 6 |
| V4-T | Bots, scorecard tool | `src/sim/ai/**`, `tools/{scorecard_run,sim_run,balance_run}.*`, `tests/unit/sim_ai/` | V3-I | 8 |
| V5-A | Gameplay integration and cleanup | `src/{sim,game,core,content,save,shared}/**`, `data/*.json`, `tests/**` except view, ui, audio | Wave V4 | 10 |
| V5-B | Presentation integration, captures, accessibility | `src/{view,ui,audio,debug}/**`, `assets/**`, `data/strings/**`, `tests/unit/{view,ui,audio}/`, `docs/reports/screenshots/` | Wave V4 | 10 |
| V5-C | Balance with the scorecard | `data/*.json` (values only), `docs/reports/BALANCE_REPORT.md`, `tests/fixtures/data_variety/` (refresh) | V5-A | 14 |
| **V6-Q** | Release QA, device evidence | whole repo (fixes only); uses the device and the emulator | Wave V5 | 8 |

Totals: 26 tasks, about **262 agent-hours**. Seven waves: V1 (1 task), V2 (9 in parallel), V3 (1), V4 (11 in parallel), V5 (2 in parallel, then 1), V6 (1).

**Critical path** (longest chain of dependent work): V1-S 12 -> V2-C 12 -> V3-I 10 -> V4-N 14 -> V5-A 10 -> V5-C 14 -> V6-Q 8 = **80 hours** of sequential agent time, plus two owner playtests (after V3-I and after V4) and the merges.

### 15.2 The vertical slice comes first (waves V1 to V3)

The slice is the whole loop with one of each, playable on the phone:

| Pillar | In the slice |
|---|---|
| Run | Act I only: 4 generated waves and a boss wave (the existing Siege Hulk stands in as the act boss), untimed intermissions |
| Draft | The draft overlay with 8 directives: `hot_loads`, `cyclic_tuning`, `penetrator_cores`, `turret_deploy`, `reinforced_cage`, `emp_capacitor`, `incendiary_tips`, `glass_cannon` (one corrupted, to test the red frame) |
| Weapon | `arc_projector` (it proves chains, heat, a new effect and a new sound), found in the guaranteed crate after wave 2; 2 slots; the weapon bar and swapping |
| Enemy | `burster` (it proves death hooks and chain blasts) and `mote` (it proves minis and the instanced path) |
| Modifier | Route choice before waves 2 to 4 with 3 packs (`pack_tide`, `pack_powder`, `pack_column`) and one modifier (`mod_volatile`) |
| Event | Player-triggered `deadfall_strike` only (it proves delayed hits, telegraphs and the call button) |
| Resume | The run file and RESUME RUN |
| Meta | None yet (Data is still granted as today) |

Slice exit (V3-I acceptance): a `balanced` bot and a human finish a 5-wave run on the desktop and on the phone; two seeds give visibly different runs (different packs, offers and outcomes); kill the app mid-wave and resume; `sim_run` over 20 seeds shows wins and losses.

### 15.3 Task cards

Each card lists goal, owned paths (beyond the table), key deliverables, tests, acceptance and commands. "Read" is always: this spec, CONTENT, ARCH, GDD, plus the sections named.

#### V1-S Contract scaffold

**Goal.** Every contract of section 13 exists as compiling code and data, so nine tasks can start in parallel.
**Owned.** The whole repository, but functional changes only in the files of 15.4; everything else is new stubs.
**Deliverables.** (1) Shared and frozen files extended exactly as 13.1 to 13.4 (append only). (2) Every new def, state class, system, hook file, fire kind, event and boss file as a stub with the final signature, `hash_into`, `to_dict`, `from_dict`, marked `# TODO(<task id>)`. (3) `ContentLoader.build` with the 7th parameter; loaders for the six new files (straight mapping). (4) Slice data in `data/` (section 15.2) and the full schemas with at least one entry per list. (5) `TestContent.variety()` and `tests/fixtures/data_variety/` (slice data). (6) `FakeRunApi` and `SimPuppet` extended; `hud_sandbox.tscn` gains `--state=draft|route|salvage|combat2` and `view_sandbox.tscn` gains `--scenario=chain` and `hold<N>+<M>` (driven by the puppet), so V2-E and V2-F can capture without waiting for V2-P, which owns `src/debug/` afterwards. (7) `test_contracts.gd` extended. (8) `mission.shop_enabled` false in shipped data; the game still boots and a run still plays as 5 scripted waves until V2-A lands (the plan stub returns the legacy waves).
**Tests.** Loader tests for each new file; contract test; "legacy fixture content is byte-for-byte the same `ContentSet` as before" (compare a hash of the defs); every existing test still green.
**Acceptance.** `tools\check.ps1` -> `CHECK OK` with at least the current 1,063 tests plus 40 new; `tools\test.ps1 -Path res://tests/unit/core,res://tests/unit/content` passes; `tools\test.ps1 -Canary` -> `CANARY OK`; `tools\balance_run.ps1 -Runs 5 -Data res://tests/fixtures/data_baseline` still prints `BALANCE: PASS` (the legacy fixture is intact).

#### V2-A Sim: run plan, wave builder, phases and awaits

**Goal.** A run is a generated plan; intermissions wait for choices; the sim holds its tick while waiting.
**Deliverables.** `RunPlanSystem.build`, `WaveBuilder`, the `Await` flow of 2.5, `PICK_ROUTE`, acts, `ACT_STARTED`, `ROUTE_OFFERED`; `SpawnSystem` reads the chosen option and enforces the class and type caps.
**Tests (`tests/unit/sim_plan/`, at least 30).** The plan is identical for the same seed and differs for another; golden plan for seeds 1 to 3; both options of a wave never share a pack; budgets are met within 10%; composition rules 5.3; a pick at wave 3 does not change wave 7's options; awaiting freezes `tick` and every timer; a bot answering after 0 or 600 calls gives the same hash; caps and FIFO queue with minis; legacy fixture runs unchanged.
**Acceptance.** `tools\test.ps1 -Path res://tests/unit/sim_plan,res://tests/unit/sim_flow,res://tests/unit/sim_nav` passes.

#### V2-B Sim: drafts, directives, modifiers

**Goal.** 1-of-3 offers that are seeded, weighted, duplicate-free, with pity, reroll, skip, buy-out and patch.
**Deliverables.** `DraftSystem`, `DraftState`, `ModSystem`, `ModState`, the `ops` interpreter, the 5 draft commands, `SHOP_CLOSED`, the legacy level fields fed by the three stat directives.
**Tests (`tests/unit/sim_draft/`, at least 35).** No duplicates over 1,000 offers; rarity frequencies within 3 points of the weights over 5,000 offers; rare pity fires on the 4th offer; turret pity; requirement filtering; tag lean changes frequencies in the expected direction; reroll prices 60, 100, 140; buy-out once per draft; skip pays 60; maxed directives never appear; every op changes exactly its `ModState` field; `hot_loads` x3 gives the golden `hit_damage` values of ARCH 6.5; golden first offer of seed 1; replay equality with drafts.
**Acceptance.** `tools\test.ps1 -Path res://tests/unit/sim_draft,res://tests/unit/sim_flow` passes.

#### V2-C Sim: arsenal, arc projector, blasts, burster, salvage

**Goal.** Two weapon slots, swapping, heat, chain lightning, delayed and area damage, death blasts with a chain delay, crates.
**Deliverables.** As the owned files; `DamageResolver.hit_ex`; `DeathHooks.on_killed`; the 8-per-tick blast limit; `deadfall_strike` as the first user of delayed hits (the event file itself is V1-S's stub filled here).
**Tests (`tests/unit/sim_arsenal/`, at least 40).** Swap timing and per-slot magazines; holster reload at half speed; heat and vent exact tick counts; arc chain order (nearest, id ties), falloff values, armor ignored; a line of 6 bursters detonates in 6-tick steps and kills exactly the expected set; blasts never recurse; Scrap exactly once per kill by a blast; a burster at its slot arms and hits the core for 70 (shield first); minis burn out with no Scrap; crate progress, contest, loss, bank limit; `SALVAGE` actions; the legacy pistol and SMG cadence tests unchanged; determinism over 3,600 ticks with 50 + 40; micro-benchmark: the tick with 50 + 40 and a blast per second averages under 1.0 ms on the dev machine.
**Acceptance.** `tools\test.ps1 -Path res://tests/unit/sim_arsenal,res://tests/unit/sim_combat` passes.

#### V2-D Game flow, run file, resume

**Goal.** The app drives the new intermission, writes the run file, resumes after a kill.
**Deliverables.** `SimRunApi` additions, `GameEventRelay` additions, run file read and write, `start_resumed`, RESUME RUN wiring (the menu button itself is V2-E's stub signal), boundary snapshot calls, the fallback chain of 2.8.
**Tests.** Snapshot, restore, hash equal at each boundary (3 seeds); tail replay lands on the same hash; hash mismatch falls back to full replay; wrong build closes the run and pays once; reward-once across resumes; app-pause writes `resume_tick`; 100 kill-and-resume cycles in memory.
**Acceptance.** `tools\test.ps1 -Path res://tests/unit/game,res://tests/unit/save,res://tests/integration/game` passes.

#### V2-E UI: draft, route and salvage overlays, weapon bar

**Goal.** The three choice screens and the new bottom band, built against `FakeRunApi`.
**Deliverables.** Section 11.1 to 11.4 (ticker and call button in their first form), two-tap confirm, long-press detail, safe areas, the drawer hidden (not deleted).
**Tests.** Touch sizes at least 132 px for every control at 1080x1920, 1080x2400 and 1080x1120; text at least 30 px; a selection never commits without CONFIRM; the right command and argument reach the API for every button; corrupted cards show the price line; High Contrast variants.
**Acceptance.** `tools\test.ps1 -Path res://tests/unit/ui` passes; `tools\capture.ps1 -Scene "res://src/debug/hud_sandbox.tscn --state=draft" -Out C:/dev/tower-two-wt/V2-E/build/shots/draft.png -Size 1080x2400` prints `CAPTURE OK` (also `--state=route`, `--state=salvage`, `--state=combat2`); each PNG opened and listed in the report.

#### V2-F View: arc projector, burster, minis, blast and arc effects

**Deliverables.** The two models, `MiniSwarm`, `fx_blasts`, `fx_arcs`, the telegraph ring for the strike, the crate and its ring, pools sized by tier, data-driven `EnemyPool` sizes.
**Tests.** Triangle budgets; one optic material surface per enemy mesh; pool caps by tier; no allocation after `setup` (a counter test as in the existing vfx tests); a blast never draws on a recycled slot twice in a frame.
**Acceptance.** `tools\test.ps1 -Path res://tests/unit/view` passes; `tools\capture.ps1 -Scene "res://src/debug/view_sandbox.tscn --scenario=chain" -Out C:/dev/tower-two-wt/V2-F/build/shots/chain.png -Size 1080x2400` prints `CAPTURE OK`; the capture shows countable optics during the chain.

#### V2-G Audio, V2-H Bots and tools, V2-P Phone baseline

- **V2-G.** 14 slice sounds, the voice classes of 10.5, held voices. `py -3.12 -I tools/audio_gen/gen.py --check` exits 0; `tools\test.ps1 -Path res://tests/unit/audio` passes.
- **V2-H.** Policies `none`, `greedy`, `random`, `balanced` (slice scope), `plan_dump`. `tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20` prints `SIM SUMMARY:` with both victories and defeats possible; `tools\plan_dump.ps1 -Seed 1` prints the plan.
- **V2-P.** Record the phone baseline that the brief quotes (LOW, MID, HIGH at 50 enemies) in `docs/reports/PERFORMANCE_REPORT.md`; then `--scenario=hold50+40` and `--scenario=chain` on the phone with `--debug-perf`: six `[PERF]` lines per tier. Uses the physical device (the only task of the wave that may). Output: a go or no-go on the 10.3 budget and the cut list if no-go. Anything not run on the device is reported NOT RUN.

#### V3-I Slice integration

**Goal.** The slice of 15.2 plays end to end on desktop and phone. **Deliverables.** Fixes across layers, the e2e suite for the 5-wave generated run, the frozen `data_variety` fixture, a debug APK for the owner. **Acceptance.** `tools\check.ps1` -> `CHECK OK`; `tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20` shows at least 1 victory and 1 defeat; `tools\test.ps1 -Path res://tests/integration` passes; the real process `Godot --headless --fixed-fps 60 --path . -- --autoplay=balanced --seed=1 --mute --quit-after-run` ends with `[Game] quit after run`; `tools\deploy_android.ps1` and `tools\smoke_android.ps1 -SkipDeploy` -> `SMOKE OK`. **Gate: owner playtest.**

#### Wave V4 (eleven tasks in parallel; each ends with `check.ps1`)

| ID | Tests that must exist | Extra acceptance command |
|---|---|---|
| V4-W | Per firing kind: exact hit sets on hand-placed enemies; cadence, magazine, heat; level multipliers; level-3 perks; cluster targeting ties | `tools\test.ps1 -Path res://tests/unit/sim_arsenal` |
| V4-N | Per type: one behaviour test per row of 5.1; standoff points never overlap slots; ward maths with exact numbers; splitter with a full mini cap queues shards; affix tests one per affix and the forbidden pairs; mini movement cost benchmark | `tools\test.ps1 -Path res://tests/unit/sim_enemies,res://tests/unit/sim_nav` |
| V4-L | Per boss: timeline test over its first 60 s (telegraph ticks, attack ticks, phase thresholds); interrupt and brace rules; no attack above 20% of the core; boss pools and variants from the plan | `tools\test.ps1 -Path res://tests/unit/sim_boss` |
| V4-V | Per event: warn, start, end ticks; every fairness rule of 7.3 as a test; the interaction table 7.4 row by row; drums chain with bursters | `tools\test.ps1 -Path res://tests/unit/sim_events,res://tests/unit/sim_flow` |
| V4-C | Every directive: one test of its effect with numbers; every modifier and reward; kits; plan patches reproducible; the validator rejects each bad fixture | `tools\test.ps1 -Path res://tests/unit/sim_draft,res://tests/unit/sim_plan,res://tests/unit/content` |
| V4-M | v1 to v2 migration on 6 fixture files; purchase atomicity; tier gates; milestones once; daily seed same for a date, different across dates; reward extras | `tools\test.ps1 -Path res://tests/unit/save,res://tests/unit/game` |
| V4-U | Archive, kit selector, results additions, ticker (3 lines, priorities), boss pips, hints once per profile; sizes and safe areas on 3 aspects | `tools\test.ps1 -Path res://tests/unit/ui` and 8 captures |
| V4-R | Budgets, surfaces, one optic per mesh, silhouettes differ (the existing silhouette test pattern, pairwise) | `tools\test.ps1 -Path res://tests/unit/view` and a roster capture |
| V4-X | Pool caps by tier; a danger decal is drawn on every tier; Reduced Flash removes flashes and shake; legibility capture at 50 + 40 during a chain | `tools\test.ps1 -Path res://tests/unit/view` and 6 captures |
| V4-A | `gen.py --check`; every new id in the catalog has a file; alert voices are never starved (a test that floods weapon sounds) | `tools\test.ps1 -Path res://tests/unit/audio` |
| V4-T | Each policy is deterministic and never draws from a sim stream (a test compares `world.rng` hashes with and without the bot's idle decisions); the scorecard maths on synthetic results | `tools\scorecard_run.ps1 -Runs 5` prints `SCORECARD:` |

Optional, outside the path: **V4-X2** instanced bodies (10 hours), only if V2-P says the draw-call budget fails.
**Gate after V4: owner playtest (readability).**

#### V5-A, V5-B, V5-C, V6-Q

- **V5-A Gameplay integration and cleanup.** Full-run e2e tests for the 15-wave game; delete the drawer and its dead paths; fix cross-layer defects. `tools\check.ps1`; `tools\test.ps1 -Path res://tests/integration`; `tools\sim_run.ps1 -Seed 1 -Policy balanced -Runs 20`.
- **V5-B Presentation integration.** The screenshot set (at least 24 PNGs: every overlay, every boss, every event warning, a 50 + 40 chain on each tier, Reduced Flash, High Contrast, 3 aspects), the accessibility audit against 5.6 and 12.3, audio routing gaps. `tools\check.ps1`; captures listed with pass or issue notes.
- **V5-C Balance.** Tune `data/*.json` until `tools\scorecard_run.ps1 -Runs 200 -Pool base` and `-Pool full` print `SCORECARD: PASS` (or WARN rows each explained), `tools\balance_run.ps1 -Runs 20` prints `BALANCE: PASS`; write part 2 of BALANCE_REPORT.md with before and after for every changed value; refresh the frozen fixture. **Gate: owner playtest.**
- **V6-Q Release QA.** The WP W4-A step list, extended: resume after `am force-stop` mid-wave and mid-draft; a full run by input taps; a 15-minute soak with `--autoplay=balanced` on each tier with `[PERF]` lines; v1 profile migration on the device; reports and the APK hash.

### 15.4 Shared files that need a single owner

These files are touched by many features. They are extended **once, by V1-S**, as complete contracts; later tasks fill bodies in their own files and must not edit these (a needed change is reported as "needs owner" and done by the coordinator between waves).

| File | Why it is shared |
|---|---|
| `src/shared/{ids,reason,damage_source}.gd` | Ids and enums for every layer |
| `src/content/defs/**`, `src/content/content_loader.gd`, `content_validator.gd` | Every data file |
| `src/sim/sim_world.gd`, `sim_command.gd`, `sim_event_kind.gd`, `sim_config.gd`, `run_stats.gd`, `run_summary.gd` | Tick order, commands, events |
| `src/core/event_bus.gd`, `src/game/run_api.gd`, `src/game/game_event_relay.gd`, `src/debug/fake_run_api.gd` | The door between sim, UI, view and audio |
| `tests/unit/core/test_contracts.gd`, `tests/fixtures/test_content.gd` | Contract tests, fixtures |
| `data/strings/variety_en.json` | V2-E in wave V2, V4-U in wave V4 (one owner per wave; other tasks list the keys they need in their report) |
| `data/run.json`, `data/enemies.json`, `data/weapons.json`, `data/directives.json`, `data/events.json` | One owner per wave as in the table (V4-C owns `run.json` and `directives.json`, V4-N `enemies.json` and `arena.json`, V4-W `weapons.json`, V4-V `events.json`); V5-C owns all values afterwards |
| `src/audio/audio_catalog.gd`, `tools/audio_gen/voices.py` | The audio task of each wave |
| `src/view/vfx/vfx_layer.gd`, `src/view/actors/actor_layer.gd`, `enemy_pool.gd` | V2-F, then V4-X (vfx) and V4-R (actors) |
| `src/ui/combat/combat_hud.gd` | V2-E, then V4-U |
| `project.godot`, `export_presets.cfg` | Nobody (no change is needed: `data/*.json` is already included) |

Two same-wave tasks share a system file in wave V4 (`hazard_system.gd` is V4-V's, `status_system.gd` is V4-N's, `mod_system.gd` and the hook files are V4-C's, `arsenal_system.gd` and `shot_hooks.gd` are V4-W's): the scaffold's stubs define the call points, and a task that needs a new call point in another task's file reports it instead of editing. `class_name` uniqueness for test helpers stays a rule (the Wave 1 merge lesson in CLAUDE.md).

### 15.5 What to cut first if time is short

In this order, each cut independent: (1) the Daily Run; (2) turret types and the third sling; (3) cosmetic chaos beyond scorch marks; (4) `jammer` and `borer` (and `floor_breach`, and the Tremor Rig's breaches become a second stomp); (5) two weapons (`cutting_torch`, `hornet_rack`); (6) the second boss of each act pool (the "random pick" then comes only from Node 9's variants: a visible loss of variety, so this is late in the list); (7) the unlock packs `u_p_corrupted` and `u_p_proto`. Never cut: the run plan, drafts, two weapon slots, bursters and minis, resume, the scorecard.

---

## 16. Story text pending owner approval

Canon rules followed (GDD 2.1): CHORUS logs are lowercase, have no pronouns, never taunt, only count. The Hollow Accord speaks in short radio fragments and is never seen. Warden system lines are capitals. Bosses are nodes. Enemy names are lowercase mechanical nouns. **Every line below is new and is not final until the owner approves it.**

| Key (proposed) | Text | Voice |
|---|---|---|
| `lore.tagline` (change) | Hold the line at Relay Core B-4. Three pushes. One Warden. | title |
| `lore.briefing.text` (change: it says "Five pushes") | B-4 is still warm. The perimeter is gone and Cinder cannot turn around. They come in three pushes now: the yard, the gantry line, then the node itself. Lantern will patch you between pushes. Take what the yard gives you. Count what you bring back. Accord out. | Accord radio |
| `act.yard.name` / `act.gantry.name` / `act.node.name` | THE YARD / THE GANTRY LINE / CONSOLIDATION | banner |
| `act.tier` | CHORUS PLATING: TIER %d | system |
| `draft.header` | LANTERN CELL // PATCH WINDOW | system |
| `draft.sub` | Three directives. One fits in the window. | Accord radio |
| `draft.corrupted.tag` | CORRUPTED: CHORUS CODE IN THE PATCH | system |
| `route.header` | CHOOSE THE NEXT PUSH | system |
| `route.none_quiet` | NO QUIET ROUTE | system |
| `salvage.header` | SALVAGE RECOVERED | system |
| `archive.title` / `archive.sub` | ARCHIVE / Recovered Data opens what the Combine left behind. | menu |
| `lore.threat.mote` | Hand-sized. Burns out on the cage. Counted in hundreds. | briefing |
| `lore.threat.burster` | Carries a charge. Goes off where it dies, or where it arrives. | briefing |
| `lore.threat.spitter` | Stands off and lobs slag at the core. | briefing |
| `lore.threat.splitter` | One frame, three shards. Break it far from the cage. | briefing |
| `lore.threat.shieldbearer` | Its ward covers what walks beside it. A pulse drops the ward. | briefing |
| `lore.threat.reclaimer` | Repairs what you damage. Kill it first. | briefing |
| `lore.threat.jammer` | Slows your turrets and your triggers while it stands. | briefing |
| `lore.threat.borer` | Comes up through the yard floor. Watch for cracks. | briefing |
| `boss.brood_carrier.name` / `.banner` | NODE 3 // BROOD CARRIER / `node 3 dividing. 40 of 40 will pass.` | CHORUS log |
| `boss.lance_platform.name` / `.banner` | NODE 5 // LANCE PLATFORM / `node 5 ranging. 1 of 1 will pass.` | CHORUS log |
| `boss.aegis_array.name` / `.banner` | NODE 6 // AEGIS ARRAY / `node 6 shielding. 3 of 3 hold.` | CHORUS log |
| `boss.tremor_rig.name` / `.banner` | NODE 7 // TREMOR RIG / `node 7 below. 9 of 9 rising.` | CHORUS log |
| `boss.hulk_plated` / `hulk_fed` / `hulk_overclocked` | NODE 9 // PLATED / NODE 9 // FED / NODE 9 // OVERCLOCKED (the existing line `node 9 consolidating. 1 of 1 will pass.` stays) | CHORUS log |
| `boss.enrage` | `node 9 at 25 of 100. rate increased.` | CHORUS log |
| `event.deadfall.call` | DEADFALL UPLINK: ORRERY PLATFORM ANSWERING | Warden system |
| `event.deadfall.lore` | Lantern found a dead Combine platform that still listens. It has a few rounds left. | Accord radio (archive text) |
| `event.core_vent` | CORE VENT: INTEGRITY SPENT | Warden system |
| `event.freight.warn` | FREIGHT LINE %s LIVE. STAND CLEAR | Warden system |
| `event.static_front.warn` | Static front on the yards. Your triggers go dark in six. | Accord radio |
| `event.static_front.end` | STATIC CLEAR. TRIGGERS ONLINE | Warden system |
| `event.supply_drop.warn` | Accord drop on the yard. Hold it clear and it is yours. | Accord radio |
| `event.supply_drop.lost` | `drop recovered. 1 of 1 counted.` | CHORUS log |
| `event.power_surge.warn` | CORE SURGE. TURRETS OVERCHARGING | Warden system |
| `event.power_surge.brownout` | BROWNOUT. TURRETS OFFLINE | Warden system |
| `event.floor_breach.warn` | `subsurface route open. %d inbound.` | CHORUS log |
| `event.recount.warn` | `recount. 12 of 12 rerouted.` | CHORUS log |
| `event.relay_window` | Relay window. Everything you break counts double. | Accord radio |
| `elite.spawn` | `priority frame deployed: %s.` | CHORUS log |
| `lore.results.victory` (change) | B-4 is still warm. Node 9 is not. The yards hold. Flint is still standing. Accord out. | Accord radio |
| `lore.results.defeat` (keep) | `relay core b-4: offline. wardens active at b-4: 0. network preserved.` | CHORUS log |
| `resume.line` | LINK RESTORED. WAVE %d | Warden system |
| Kit names | STANDARD ISSUE, BREACHER, SIGNAL, GUNLINE, LEDGER, LONG ODDS | menu |
| Weapon names | SERVICE PISTOL, SMG, SCATTERGUN, ASSAULT RIFLE, HORNET RACK, LMG, SLAG MORTAR, CUTTING TORCH, ARC PROJECTOR, RAIL LANCE (no brands, no calibres) | UI |
| The 60 directive names | The ids of CONTENT 3 in capitals with spaces (HOT LOADS, GLASS CANNON, DEAD MAN'S SWITCH, ...) | UI |

New canon claims inside these lines that the owner should confirm explicitly: (a) boss node numbers 3, 5, 6 and 7 (Node 9 is the only canon number today); (b) a dead Orrery Combine orbital platform that Lantern Cell can call ("Deadfall"); (c) Lantern Cell patching the Warden between pushes, and CHORUS code arriving inside a patch ("corrupted directives"); (d) the Hollow Accord dropping supplies into the yard; (e) the names Shieldbearer and Reclaimer are taken from the handoff's future-scope list and `enemy_roster.png`.

---

## 17. Proposed edits to the existing documents (not applied by this task)

### 17.1 `docs/GAME_DESIGN.md`

| Section | Edit |
|---|---|
| Header, 1 | Scope line: "the 15-wave, three-act run"; pitch: "One Warden, one core, three pushes"; session "about 15 to 20 minutes, resumable" |
| 2.2, 2.3 | Add the approved lines of section 16 (after approval); the briefing text |
| 2.4 | Keep the ban on "Cards" and "Workshop"; add the approved words DIRECTIVE and ARCHIVE |
| 3 | Replace the loop diagram with section 2.1's; replace "No mid-run resume" with the rule of 2.8; Scrap rules: earned from kills and rewards, spent on rerolls, buy-outs and patches |
| 4.3 | Controls table: remove the upgrade rows; add weapon swap, STRIKE, VENT, FREIGHT, draft, route and salvage choices. Keep "no target tapping" |
| 5.1 | Weapons table replaced by section 3.2; two slots; damage order of 3.3 |
| 5.2 | Replaced by section 4 (directives); the old cost table moves to an appendix "legacy fixture" |
| 5.3 | Turret modifiers come from directives; turret types (stretch) |
| 5.4 | Abilities unchanged; add the player-triggered calls |
| 6 | Roster of section 5 and CONTENT 4; the exceptions to "arriving never removes an enemy"; elites; readability rules 5.6 |
| 7 | Replaced by section 2 (acts, budgets, packs, routes, caps incl. `swarm_cap`) |
| new 7a | Bosses (section 6); new 7b: events and hazards (section 7) |
| 8.1 to 8.3 | Scrap sinks; Data rewards of CONTENT 10; "Data has no sink" replaced by the Archive (section 8); profile fields |
| 8.4 | Replaced by section 14.3 and the scorecard |
| 9 | Replaced: the in-run weapon bar, the draft screen and the Archive; the "no fake weapon cards" sentence removed |
| 10 | Wireframes of section 11; bottom band 26%; the ticker; first-run hints of 11.7 |
| 11 | Sound table extended by 12.1; voice classes |
| 12 | 12.2: the weapon strip of `topdown_approved.png` moves from "ignore" to "use for the weapon bar"; damage numbers stay ignored. New VFX list and the rules of 12.3; the Warden triangle budget |
| 13 | Scope table: everything in this milestone moves to the left column; the right column keeps maps, authored art, music, online |
| 14 | Close A1, A2, A15 (SMG purchase, drawer); add the open questions of section 18.2 |

### 17.2 `docs/ARCHITECTURE.md`

| Section | Edit |
|---|---|
| 3 | Directory layout: the new folders `src/sim/plan/`, `src/sim/systems/{fire,events,bosses}/`, `src/ui/run/`, new data files, new tools |
| 4 | `Ids`, `DamageSource`, `Reason` appended as 13.2. Note: "append only; indices are fixed forever" |
| 4.1 | Add the paragraph on `PhaseState.Await` (intermission sub-steps are not application states) |
| 5.2, 5.3, 5.4 | The six new files and `arena.json` schema 2; the new and extended defs; `build` with the 7th parameter; `STRING_FILES` + `variety_en.json`; the new validation rules; the boot log line |
| 6.1 | The stream table of 9.2 and the rules of 9.5; "the tick does not advance while awaiting" |
| 6.2 | `SimWorld` new fields; the 16-step tick order; capacity `enemy_cap + swarm_cap + 8` |
| 6.3 | `SimConfig`, `SimCommand.Kind`, the new event kinds and payloads |
| 6.4 | The new state classes; `RunStats` and `RunSummary` additions; "stores frozen" stays |
| 6.5 | Unchanged formulas; add the damage order of 3.3 and the integer rules for heat and wards |
| 6.6 | Ownership rows for the new states; the new system contracts; `hit_ex`, `pick_cluster`, `pick_many` |
| 6.7 | `Replay.run` signature unchanged, plus the "awaiting and log exhausted" stop; the 8 policies; snapshot and tail resume |
| 7.1, 7.2 | The new signals and `RunApi` members |
| 7.3, 7.4 | `start_resumed`; `Game.start_run(run_seed, kit_id, daily)`, `resume_run_from_disk`, `open_archive`; `BackPolicy` on choice overlays |
| 7.5 | Profile v2, the migration, `run_v1.json`, the new `Save` methods; remove "There is no mid-run save" |
| 8 | Pool sizes from `alive_cap`; minis as MultiMesh; the new vfx modules; rules 5.6 and 12.3; the Warden budget split |
| 9 | The new scenes table rows; the weapon bar; removal of the drawer members (after V5-A) |
| 10 | The 60 new sound ids; voice classes; held voices |
| 11 | The new debug arguments |
| 12 | `scorecard_run.ps1`, `plan_dump.ps1`; `sim_run` and `balance_run` policy lists |
| 13 | Budgets: draw calls target stays 150, add the measured phone baseline; sim tick at 50 + 40; the pools of 10.3; "Quality tiers change the view only" stays |
| 14 | New deviation D11: generated waves and drafts replace the handoff's fixed five waves and upgrade tree (owner decision 2026-11-11) |

### 17.3 `docs/WORK_PLAN.md`

| Section | Edit |
|---|---|
| Header | Add "Milestone 2: Variety" with a pointer to this spec |
| 1 | Rule 3 "Never edit" list: add the shared files of 15.4. Rule 5: add `TestContent.variety()` and the second frozen fixture. Rule 9: V2-P and V6-Q may use the physical device |
| 1.1 | Add the `scorecard_run.ps1` and `plan_dump.ps1` commands |
| 2 | Append the wave overview table of 15.1 |
| new 8 | The task cards of 15.3 in full WP form (Goal, Owned, Read, Deliverables, Tests, Acceptance table) |
| 6 | Placeholder table: the new assets of 12.2 and their budgets |
| 7 | Acceptance matrix: new rows B01 to B12 (run plan determinism, drafts, two weapons and swap, each enemy type distinct, elites, bosses, events fairness, resume, profile migration, unlocks once, scorecard PASS, phone frame budget at 50 + 40) |

---

## 18. Open questions and risks

### 18.1 Decisions for the owner (detail in VARIETY_PITCH.md)

| # | Decision | This spec assumes |
|---|---|---|
| D1 | Run length | 15 waves, 3 acts of 5 |
| D2 | What Scrap is for | Rerolls, buy-outs, core patches; no combat shop |
| D3 | Weapons carried | 2, manual swap by tap |
| D4 | The word for cards | DIRECTIVES (and ARCHIVE for the meta screen) |
| D5 | Meta philosophy | Variety only, no permanent stat power |
| D6 | More bodies | Bodied cap stays 50; +40 instanced minis |
| D7 | Resume | Boundary snapshot + command tail |
| D8 | Daily Run | In the milestone, first thing cut |

### 18.2 Open questions

| # | Question | Default used |
|---|---|---|
| Q1 | The story text and the five canon claims of section 16 | Used as proposed, flagged pending |
| Q2 | Damage numbers over enemies (the concept image shows them) | Off; a setting later |
| Q3 | Should the wave-1 pack also vary? | No: a fixed, learnable opener |
| Q4 | Warden triangle budget with long weapons (F11) | Body 2,300 + weapon 350 |
| Q5 | Should hot routes be refusable when both options are hot? | No (15% of choices from act II); it is announced |
| Q6 | Is "restart the wave after a crash" acceptable as the crash-only path? | Yes |
| Q7 | Keep the legacy 5-wave path in the sim as a test fixture forever? | Yes for this milestone |
| Q8 | Should the Archive show locked content as silhouettes or hide it? | Show names and costs (it sells the next run) |
| Q9 | Android back on a choice screen | Pauses; never dismisses the choice |
| Q10 | One rewarded Daily attempt per day relies on the device clock (offline) | Accepted; practice runs pay half |

### 18.3 Risks

| Risk | Why it is real | Mitigation |
|---|---|---|
| The phone does not hold the effect budget | MID and HIGH already hitch at 50 enemies; the estimate is about +28 draw calls | V2-P measures in the first parallel wave, before content is built; a cut list exists; V4-X2 (instanced bodies) is the reserve |
| Sim tick at 50 + 40 with blasts exceeds the phone limit | The desktop tick already reaches 0.53 ms at 50 under load | Minis skip the expensive steps; 8 blasts per tick; a benchmark test in V2-C; `swarm_cap` is data and can drop to 24 |
| Randomness makes the game unfair instead of varied | Offers can miss what a build needs; a hot route plus a harmful event can stack | Pity rules, the tag lean, fairness rules 7.3 as tests, scorecard S8, S9, S13, S18 |
| Balance space explodes | 10 weapons x 60 directives x packs x modifiers x affixes | Bots and the scorecard are built in the slice wave, not at the end; 34 directives are pure data; V5-C has 14 hours and a frozen fixture |
| Readability collapses at 90 bodies with effects | The owner's metric image is loud; a phone is small | Rules 5.6 and 12.3 as tests and legibility captures; no damage numbers; the owner playtest after V4 is a gate |
| Choice fatigue: 14 drafts and 11 routes | Every intermission has 2 or 3 decisions | Two-tap choices, untimed, default highlights, the route is skipped before bosses; if the playtest says "too many", routes go to every second wave (a data change) |
| Resume bugs corrupt a run | A new serialisation surface | Boundary-only state, hash verification, full-replay fallback, 100-cycle test, the run is paid as a defeat if all fails |
| Contract churn breaks the 1,063 tests | Frozen files are extended | Append-only changes, default parameters, the legacy fixture kept byte-identical, one scaffold owner |
| Scope: about 262 agent-hours | Three times the content of the slice | The slice is playable after about 100 hours (V1 to V3); the cut order of 15.5 |
| Meta feels like a grind or like nothing | Variety-only unlocks are less of a "number go up" | Milestones front-load the first hours; the results screen names what the player can afford; revisit D5 after the third playtest |
| Unapproved lore ships | 40 new lines and five canon claims | Section 16 is the single list; strings live in one file; nothing is final until approved |
