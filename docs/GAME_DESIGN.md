# IRON STATIC: CINDERFALL - Game Design (variety milestone)

Version 2.0, 2026-11-11. Scope: the offline game defined by the handoff package (`docs/handoff/`) as extended by the
owner-approved **variety milestone**: a generated 15-wave, three-act run with 1-of-3 directive drafts, ten weapons, new
enemies, bosses, chaos events, an Archive of unlocks and resume after the app is killed (`docs/design/VARIETY_PITCH.md`,
`VARIETY_SPEC.md`, `VARIETY_CONTENT.md`; decisions D1 to D8 approved 2026-11-11, section 14). Anything tagged
**[POST-SLICE]** is still out of scope and must not be built.

Status (2026-11-11): the five-wave slice plays end to end (merged through W3-A, W3-C and W3-D; the environment look W3-E is in progress). The
variety milestone is **specified, not yet built** (tasks V1 to V6 in `WORK_PLAN.md`): where this document describes it, it
describes the target. The five-wave rules that the milestone replaces are kept in Appendix A as the **legacy fixture**, which
the test suite still runs on.

Source precedence (highest first): owner decision of 2026-11-11 (the variety milestone) >
`handoff/00_START_HERE/DECISION_LOG.md` > handoff v2 design, architecture and `03_DATA` > this document >
`handoff/07_SOURCE_CONTEXT/LEGACY_TECH_SPEC_v1.md` > concept-art text. The handoff decision log is read-only history; where
the owner's 2026-11-11 decision supersedes a line of it (other weapons "future roadmap only", "No Shieldbearer/Reclaimer"),
this document says so. This document fills gaps and records every default it picks in section 14. Numbers live in
`res://data/*.json`, never in code; the values quoted here are the handoff baselines (Appendix A) and the first-pass values
of the milestone (`VARIETY_CONTENT.md`, cited as CONTENT n), all expected to be tuned (section 8.4).

Technical contracts are in `ARCHITECTURE.md`. Task breakdown is in `WORK_PLAN.md`.

---

## 1. Premise

One-line pitch: **"The perimeter fell. One Warden, one core, three pushes. Hold the line."**

You are the combat-systems commander of a reprogrammed Warden bolted beside **RELAY CORE B-4**, a booster core
in a ruined freight yard. CHORUS machines pour in from the right and upper right, and from act II some come up through the
yard floor. The Warden aims, fires and reloads on its own. You never aim and never move. During a wave you swap between two
carried weapons, trigger three abilities (EMP, Shield, Overdrive) and call a Deadfall Strike and a Core Vent. Between waves
Lantern Cell offers three directives and you keep one, you choose which threat comes next, and you take the salvage you
secured. Survive fifteen waves in three acts and kill Node 9, the Siege Hulk, to win.

It is a session game, not an idle game: one run, about 15 to 20 minutes (13 to 17 minutes of combat), win or lose,
resumable after the app is killed, replay. No two runs are the same: what attacks, what you are offered, what you find, what
happens to the yard and which bosses come are decided by the run seed (section 7), and every one of them can be replayed
exactly from that seed.

## 2. Setting and lore

### 2.1 What carries over from IRON STATIC (canon, do not change)

| Element | Canon (source: `C:\dev\tower\docs\design\01_setting_narrative.md`) |
|---|---|
| Year | 2091, "Cycle 61 of the Silence" |
| CHORUS | Hostile distributed machine intelligence. Order: "Preserve the Network". Logs are lowercase, no pronouns, never taunt, only count |
| Orrery Combine | Dead builder corporation. Source of all tech. Ringed-orbit logo on wreckage and service decals |
| Hollow Accord | Human holdouts in sealed vaults ("hollows"). Give briefings as short radio fragments. Never seen |
| Lantern Cell | Accord hacker team that captures and rewrites Wardens |
| Warden class | Orrery enforcement cyborgs. CHORUS turned them on the hollows. Serials use the `ASH-` prefix |
| Cinder (ASH-07) | The original game's protagonist, holding "Relay six". **Cinder is a character, not a place and not the core** |
| Relay network | Numbered relay stations, most of them dark |
| Currencies | `scrap` (in-run, resets) and `data` (permanent). Cinderfall uses exactly these two |
| Tone | Bleak, quiet, procedural. Terse machine-log language. No gore, no human enemies |
| Enemy naming | Lowercase mechanical nouns for what the machine does (`skitter`). Bosses are "nodes" |

### 2.2 What Cinderfall adds (PROPOSED, pending canon-owner approval; the variety additions are approved)

All of this is flavor text held in `data/strings/lore_en.json` and `data/strings/variety_en.json`. Changing it later is a
text edit. The entries marked **(approved)** are the story text of `VARIETY_SPEC.md` section 16, approved by the owner as
written on 2026-11-11, together with the five canon claims that sit inside it.

- **The event.** CHORUS breaches the outer perimeter that Cinder holds ("the Breach of Cinder", working name
  "Cinderfall"). Cinder still stands at Relay six; the yards around it do not.
- **Relay Core B-4.** A booster core in the Quiet Yards freight hub (the original game's sector 1 setting: rail
  yards of a dead freight hub). It feeds Relay six. If B-4 goes dark the hollow loses its water.
- **The defender.** Lantern Cell wakes a second recovered Warden and writes it one directive: "Hold B-4."
  Working designation: **serial ASH-12, callsign FLINT** (placeholder; see section 14, Q1). The HUD only ever
  says "WARDEN", so the name appears in the briefing and results text only.
- **Hollow Wardens.** Warden frames that were never recovered. CHORUS still drives them. They are what the
  player's Warden used to be.
- **Three pushes (approved).** CHORUS comes in three pushes: THE YARD, THE GANTRY LINE, then the node itself
  (CONSOLIDATION). Each act announces its CHORUS PLATING tier.
- **The patch window (approved).** Lantern Cell patches the Warden between pushes (LANTERN CELL // PATCH WINDOW). A patch is
  a directive. Sometimes CHORUS code arrives inside the patch: that is a corrupted directive.
- **Salvage (approved).** The Hollow Accord drops supply crates into the yard. Hold the area clear and they are yours; weapons
  are found, not issued.
- **Deadfall (approved).** A dead Orrery Combine orbital platform that Lantern Cell found still listens and has a few rounds
  left. It is the Deadfall Strike.
- **The nodes (approved).** Bosses are numbered nodes: 3 (Brood Carrier), 5 (Lance Platform), 6 (Aegis Array), 7 (Tremor
  Rig) and the canon Node 9 (Siege Hulk). Node 9 is the only number from the original canon; 3, 5, 6 and 7 are new.
- **New machines (approved).** The names Shieldbearer and Reclaimer come from the handoff's future-scope list and
  `enemy_roster.png`; this milestone builds them (the decision log's "No Shieldbearer/Reclaimer until future scope" ends).

### 2.3 Text samples (tone reference) and approved story lines

- Briefing (Accord radio, about 50 words): "B-4 is still warm. The perimeter is gone and Cinder cannot turn
  around. They come in three pushes now: the yard, the gantry line, then the node itself. Lantern will patch you between
  pushes. Take what the yard gives you. Count what you bring back. Accord out."
- Wave whisper lines (HUD, at a wave start): `relay core b-4 online. hostile swarm detected.` /
  `armored frames on the gantry line.` / `fast movers. watch the core.`
- CHORUS boss banner (wave 15): `node 9 consolidating. 1 of 1 will pass.`
- Warden system lines: `ROUND CHAMBERED`, `RELOADING`, `CORE INTEGRITY 24%`.

Approved story lines (owner, 2026-11-11, as written in `VARIETY_SPEC.md` section 16; keys live in `data/strings/`). Voices
follow the canon rules of 2.1: CHORUS logs lowercase, no pronouns, never taunt, only count; the Accord speaks in short radio
fragments; Warden system lines are capitals; bosses are nodes; enemy names are lowercase mechanical nouns.

| Key | Text | Voice |
|---|---|---|
| `lore.tagline` | Hold the line at Relay Core B-4. Three pushes. One Warden. | title |
| `lore.briefing.text` | B-4 is still warm. The perimeter is gone and Cinder cannot turn around. They come in three pushes now: the yard, the gantry line, then the node itself. Lantern will patch you between pushes. Take what the yard gives you. Count what you bring back. Accord out. | Accord radio |
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
| `lore.results.victory` | B-4 is still warm. Node 9 is not. The yards hold. Flint is still standing. Accord out. | Accord radio |
| `lore.results.defeat` (unchanged) | `relay core b-4: offline. wardens active at b-4: 0. network preserved.` | CHORUS log |
| `resume.line` | LINK RESTORED. WAVE %d | Warden system |
| Kit names | STANDARD ISSUE, BREACHER, SIGNAL, GUNLINE, LEDGER, LONG ODDS | menu |
| Weapon names | SERVICE PISTOL, SMG, SCATTERGUN, ASSAULT RIFLE, HORNET RACK, LMG, SLAG MORTAR, CUTTING TORCH, ARC PROJECTOR, RAIL LANCE (no brands, no calibres) | UI |
| The 60 directive names | The ids of section 5.2 in capitals with spaces (HOT LOADS, GLASS CANNON, DEAD MAN'S SWITCH, ...) | UI |

### 2.4 IP guardrails (inherited from the original, hard rules)

- No Terminator-franchise names, lines or likenesses. In particular **no chrome skull face with two glowing
  red eyes** on any enemy. The concept image `enemy_roster.png` shows skull-like faces; do not reproduce them.
  Every CHORUS machine gets a **single red optic slit or sensor bar**, never a pair of eyes in a skull.
- No real-world weapon brands or calibres in UI text. Use "SERVICE PISTOL" and "SMG", not "9MM".
- Never write "Terminator-like" anywhere. Never use The Tower's terms (Cash, Coins, Workshop, Cards): no player-visible text calls the
  upgrade choice a "card" (this document and the code say "card" for a layout piece, as in "weapon card"), and the meta
  screen is never a "workshop".
- The approved words are **DIRECTIVE** (an upgrade choice; Lantern Cell already writes the Warden a directive: "Hold B-4")
  and **ARCHIVE** (the meta unlock screen). Ids and code say "directive" and "archive" as well (decision D4).
- Original text, original audio, original art. Concept PNGs are reference only and are never shipped in the APK.

## 3. Core loop

```
MENU -> (ARCHIVE | KIT select) -> BRIEFING -> DEPLOY 3 s
 ACT I   "THE YARD"         wave 1  2  3  4  [5 = boss, pool of 2]
 ACT II  "THE GANTRY LINE"  wave 6  7  8  9  [10 = boss, pool of 2]
 ACT III "CONSOLIDATION"    wave 11 12 13 14 [15 = NODE 9, 1 of 3 variants]
 -> VICTORY or DEFEAT -> RESULTS (Data once, build recap, seed) -> RETRY / SAME SEED / MENU

between waves:  WAVE CLEARED -> [SALVAGE, if a crate is banked] -> DRAFT (1 of 3) -> ROUTE (1 of 2) or BOSS BRIEFING
                -> BREATHER 3 s -> next wave
```

- Core starts at 1,000 integrity (a kit may change it). Core at 0 = defeat, at any moment (after `dead_mans_switch`, if held).
- A wave ends only when every scheduled spawn has entered and every living enemy is dead, minis included.
- Victory = wave 15 fully cleared, including Node 9 and all escorts.
- Wave 1 is fixed (`pack_tide`, no modifier, no event) so the first 30 seconds are always learnable. Everything after it
  comes from the run plan, which is decided from the seed at the start of the run (section 7.1).
- The intermission is **untimed**: the phone can be put down. While a choice is pending the simulation does not advance, so
  thinking is never punished or rewarded. Only the 3 s breather after the last choice is timed (section 7.4).
- Scrap starts at 0 (a kit may change it), is earned from kills (exactly once per kill) and from route rewards and scrapped
  crates, is spent on rerolls, second picks (buy-outs) and core patches on the draft screen, and resets every run. It is no
  longer spent during combat.
- Recovered Data is the only thing that persists, together with the unlocks bought with it, the chosen kit, best results and
  settings (section 8).
- **Resume after the app is killed.** A 15-minute run must survive a phone call. At every wave clear the world is almost
  empty (no enemies, no hazards, no pending spawns), so the run is saved there as a small snapshot; every choice and then
  the commands of the running wave are appended. On launch the menu shows **RESUME RUN (WAVE n)**. Resume restores the
  snapshot, checks it, re-applies the saved commands and shows the pause overlay: the player lands in exactly the state they
  left (the tail is at most one wave). If the process died without a pause notification (a crash), the run resumes at the
  last recorded choice and the current wave starts again. If the saved state cannot be verified it is rebuilt by replaying the
  whole run from its seed and commands; if that fails too, or the build or the content changed, the run is closed and paid as
  a defeat at the last saved wave (section 8.2). A resumed run keeps its run id, so it can be rewarded only once however often
  it is resumed. Resume is not an exploit: it replays the same commands on the same seed. Only the crash path gives a wave
  back, and it gives it back identical.
- Fully offline. No accounts, ads, purchases or network.

Moment-to-moment: watch the swarm build, swap weapons at the right moment, time three abilities and the calls, and between
waves decide what to take and what to face next.

## 4. Camera, arena and controls

### 4.1 Camera

- Fixed perspective 3D camera (30 degrees vertical field of view), **50 degrees down from horizontal** (allowed band 40 to 65),
  portrait. The owner chose this three-quarter view (2026-11-12) for the balance between battlefield detail and a view into the
  swarm, as in the concept image. The pitch is data (`arena.json` `camera.pitch_down_deg`); the field of view is the constant
  `CameraFit.FOV_DEG`.
- No zoom, pan or rotation in the slice. **[POST-SLICE]** optional zoom-out.
- The camera is fitted in code so the whole playable arena sits between the top HUD (top 11%) and the bottom
  controls (bottom 26%, up from 23% before the weapon bar; `visual_tokens.json` `bottom_controls_fraction`) on every aspect
  from 9:16 to 9:20, and still fits on a near-square foldable screen. The captures at 1080x1920 must show the whole arena
  still fits with the taller band.

### 4.2 Arena (one map: "Quiet Yards, Core B-4")

World axes: X = screen right, Y = up, Z = toward the viewer (screen down). Units are meters. The playable
ground is a 20 m by 28 m rectangle (`data/arena.json`).

```
            upper_right spawn edge (top, x -1..10)
      +----------------------------------------------+
      |                    v  v  v  v                |
      |   drums o                                    |
      |                 /barrier A/                  | <
      |        T0                                    | <  right spawn edge
      |  ((CORE))                  [crates]          | <  (z -8..9)
      |     B-4                                      | <
      |        W (Warden)     \barrier B\            |
      |               T1                             |
      +----------------------------------------------+
```

- Relay Core B-4 sits at the left. The Warden stands just right of and below it. Two turret pads (T0, T1) sit
  forward of the Warden.
- Hostiles enter from the **right edge** and the **top edge (upper right)** and cross open ground. There are
  **no lanes**. From act II, borers also come out of the ground at telegraphed **breach points** in mid-field.
- Four props (two concrete barriers, a crate stack, a drum cluster) create soft funnels. They never seal a
  route; a data test proves every spawn point can reach the core.
- The play axes are screen-aligned, but all scenery (containers, floor seams, hazard stripes, the "B-4"
  stencil) is dressed at about 35 to 45 degrees so the picture reads as the isometric yard in
  `topdown_approved.png`.
- The milestone adds no map, only points on this yard (`arena.json` schema 2): four **drop points** for crates, six fixed
  **fuel drum points** (three are used per act), mid-field **breach points**, **standoff points** on the slot arc for spitters
  and reclaimers, and two **rail lines** (z = -7.0 and z = 10.5) that Runaway Freight uses. Drop, drum and breach points are
  free cells that reach the core; rail lines cross no pad, no core and no Warden; the ground gains two faint rail marks that
  stay low-contrast (12.3). Coordinates: CONTENT 6 and 7.2.

### 4.3 Controls (touch only)

| Input | Effect |
|---|---|
| Tap the holstered weapon card | Swap weapons (0.4 s with no fire; also legal in the breather) |
| Tap EMP / SHIELD / OVERDRIVE | Activate if ready |
| Tap STRIKE | Call a Deadfall Strike on the densest cluster (needs a charge) |
| Tap VENT | Core Vent: spend 8% of the core to throw the attackers off the cage |
| Tap FREIGHT (only with `signal_hijack`) | Call Runaway Freight on the rail line with more enemies |
| Tap a directive, route or salvage option, then CONFIRM | Two-tap choices in the intermission; a slip never commits |
| Tap REROLL / PATCH / SKIP, or KEEP ALSO on an unselected card | Spend Scrap on a new offer, a core repair or a second pick; SKIP takes +60 Scrap |
| Long-press a directive card | Full rules text and what it combines with in the current build |
| Tap the build chips | Open the BUILD list (the directives and weapons held) |
| Tap pause, or Android back | Full pause (simulation and cooldowns freeze). On a choice screen back also pauses; a choice is never dismissed |
| Tap CONTINUE (boss briefing) | Leave the briefing; the 3 s breather then starts (it can be skipped too) |

There is no joystick, no manual aim, no manual fire, no target tapping and no drag gesture. Crates, strikes and freight need
no tap on the battlefield: every one is a HUD button or an intermission choice.

## 5. The player kit

### 5.1 The Warden (stationary, automatic) and the arsenal

- Never moves. The upper body turns to face its target; legs stay planted. Weapons change **what the automatic fire does**,
  never the fact that it needs no aiming.
- Most weapons are hitscan: a shot resolves on the tick it fires and the tracer is only a picture. The delayed kinds (mortar
  shells, hornet missiles, the rail lance's charge, the Deadfall Strike) land at a fixed later tick that is known when they
  are launched. Props never block shots or blasts (the Warden fires over low cover). This is a fixed, tested rule.
- Range belongs to the weapon (table below): 25 m for the pistol, SMG, assault rifle and LMG, 9 m for the scattergun.
  Enemies outside range cannot be targeted.

**Targeting** (re-evaluated when the 0.4 s lock expires or the target dies or leaves range). Among living
enemies in range, pick the best by this order:

1. currently attacking the core,
2. lowest estimated time to reach the core, in 0.5 s buckets,
3. Rusher class,
4. shortest distance to the Warden,
5. lowest stable enemy id.

Per firing kind (3.3 below): H, A, B, M and L use this order inside the weapon's range; C uses it inside 9 m; S aims at the
centre of the densest cluster in range, ties broken by the best-ranked enemy in it. Minis can never be the Warden's target
while a bodied enemy is in range and attacking, or closer to the core by ETA bucket; otherwise the normal order applies
(minis are mostly killed by area damage, chains and turrets). The elite affixes MAGNETIC and SHROUDED bend this order (6.4).

**Carrying and swapping** (decision D3)

- The Warden carries **2 weapons** (3 with `u_f_third_sling`). One is active; the other is holstered on its pack.
- The weapon bar (section 10.1) shows both. **Tap the holstered weapon to swap.** A swap takes 0.4 s with no fire.
- Each slot keeps its own magazine or heat. A holstered weapon reloads at half speed and cools at full speed, so swapping
  at an empty magazine is a real technique ("swap instead of reload"). The active card pulses when a swap would help (the
  active weapon is reloading or venting and the other is ready): a hint, never an automatic action.
- The pistol never leaves the game: a kit always starts with it, and if the player scraps down to one weapon the empty slot
  shows the pistol.
- There is no automatic swap in the shipped rules. A "SWAP ASSIST" accessibility setting that swaps to the weapon with
  ammunition when the active one starts a reload is a small optional task (V4-U).

**Roster** (numbers: the stat tables below)

| id | Tier | Role | Handling feel | Feed | How it is found |
|---|---|---|---|---|---|
| `pistol` | T1 | Reliable sidearm | Slow, exact, never the wrong choice | 12, short reload | Start |
| `smg` | T2 | Swarm trimmer | Fast chatter, long reloads feel short | 30 | Crates, act I common |
| `scattergun` | T2 | Core defense | Only fires at 9 m: silent while they walk in, brutal at the cage; shoves light enemies back | 6 shells | Crates, act I common |
| `assault_rifle` | T3 | Generalist | Steady thump, each round passes into a second enemy | 30 | Crates from act I (30%) |
| `hornet_rack` | T3 | Six targets at once | A salvo fans out, six small blasts, long pause | 4 salvos | Archive unlock `u_w_hornet` |
| `lmg` | T4 | Sustained suppression | Spins up to a roar, strays hit neighbours (and fuel drums), strips armor; a 3.8 s reload is the price | 150 | Unlock `u_w_lmg` |
| `slag_mortar` | T4 | Area denial | Lobs at the densest clump, leaves a burning pool that slows | 4 | Unlock `u_w_mortar` |
| `cutting_torch` | T4 | Armor and boss melter | A beam that gets stronger the longer it stays on one target; overheats | Heat | Unlock `u_w_torch` |
| `arc_projector` | T5 | Chain lightning | One crack, five enemies light up; ignores armor, tears wards, loves an EMP | Heat | Unlock `u_w_arc` |
| `rail_lance` | T5 | Line execution | A one-second charge line, then everything on the line is hit | 3 | Unlock `u_w_rail` |

The five weapons of the concept bar keep its tiers (T1 Pistol, T2 SMG, T3 Assault Rifle, T4 LMG, T5 Arc Projector); the five
original ones fill the gaps. This replaces the handoff's "other weapons are future roadmap only".

**Stats at weapon level 1** (CONTENT 2). `kind`: H hitscan, C cone, L line, S shell (delayed area hit), B beam, M missiles,
A arc chain. In the damage column `n x d` means n pellets or missiles of d damage. All ranges are from the Warden.

| id | Tier | Kind | Damage | Rate /s | Feed | Reload s | Spread | Range m | Pierce | Area m | Raw dps (single) |
|---|---|---|---:|---:|---|---:|---:|---:|---:|---:|---:|
| `pistol` | T1 | H | 30 | 2.0 | 12 | 1.25 | 0 | 25 | 0 | 0 | 60 |
| `smg` | T2 | H | 15 | 6.0 | 30 | 1.6 | 0 | 25 | 0 | 0 | 90 |
| `scattergun` | T2 | C | 8 x 10 | 1.2 | 6 | 2.4 | 30 deg cone | 9 | 0 | 0 | 96 |
| `assault_rifle` | T3 | H | 28 | 4.5 | 30 | 1.8 | 0 | 25 | 1 | 0 | 126 |
| `hornet_rack` | T3 | M | 6 x 24 | 0.45 | 4 salvos | 3.2 | 0 | 22 | 0 | 1.2 | 65 |
| `lmg` | T4 | H | 20 | 4.0 to 10.0 | 150 | 3.8 | 5 deg | 25 | 0 | 0 | 200 |
| `slag_mortar` | T4 | S | 80 | 0.8 | 4 | 2.4 | 0 | 6 to 24 | 0 | 2.6 | 64 |
| `cutting_torch` | T4 | B | 4 to 16 per hit | 10 hits/s | heat | vent 2.0 | 0 | 13 | 0 | 0 | 40 to 160 |
| `arc_projector` | T5 | A | 40 | 1.6 | heat | vent 2.5 | 0 | 18 | 0 | chain 3.0 | 64 |
| `rail_lance` | T5 | L | 320 | 0.45 | 3 | 2.6 | 0 | 30 | all | line 0.5 | 144 |

Special fields (a missing field is 0 or false):

| id | Special fields |
|---|---|
| `pistol` | None. If both slots would be empty the Warden holds the pistol |
| `smg` | None |
| `scattergun` | 8 pellets go to enemies inside the cone, nearest first, at most 3 per enemy while other targets remain; knockback 0.8 m on enemies with mass below 3 |
| `assault_rifle` | The second enemy on the line within 2 m behind the first takes 60% (`pierce_falloff` 0.6) |
| `hornet_rack` | 6 missiles, each to a different target (top 6 of the priority order, repeats when fewer); flight 0.5 s; splash damage 10 |
| `lmg` | Rate ramps 4.0 to 10.0 over 1.5 s of continuous fire and resets after 1.0 s idle; 25% of shots stray to a random enemy within 1.5 m of the target; strips 0.5 armor per hit, at most 6 per enemy |
| `slag_mortar` | Flight 0.7 s; targets the densest cluster in range; edge damage 50%; leaves a pool for 4 s: 15 dps, 25% slow, radius 2.2 m |
| `cutting_torch` | Damage ramps +0.5 per consecutive hit up to 16 on one target (resets on target change); ignores armor; heat 3 per hit, cools 25 per s, cap 100 |
| `arc_projector` | 4 chains, each x0.75; ignores armor; x3 against wards, x1.5 against stunned enemies; heat 14 per shot, cools 20 per s, cap 100 |
| `rail_lance` | 1.0 s charge before each shot (the line is drawn while charging); ignores half the armor; hits every enemy within 0.25 m of the line |

**Weapon levels** (a duplicate found in a crate raises the level, cap 3): level 1 x1.00 damage, level 2 x1.25, level 3 x1.55
plus a perk: pistol every 6th shot is a guaranteed x3 hit; smg magazine 45; scattergun 12 pellets; assault_rifle pierce 2;
hornet_rack salvo 8; lmg no spin-up; slag_mortar pool 6 s; cutting_torch ramp cap 22; arc_projector 6 chains; rail_lance
magazine 4.

**Firing kinds** (rules; the code is in `ARCHITECTURE.md` 6.6)

| Kind | Rule |
|---|---|
| H hitscan | As before; optional pierce hits the next enemy within 2 m behind the target on the shooter-target line |
| C cone | Among enemies inside range and the cone around the aim line, pellets are dealt nearest first, at most 3 per enemy while other targets remain; knockback moves light enemies along the shot direction, never into an obstacle |
| A arc | The target takes full damage; then up to `chains` jumps, each to the nearest not-yet-hit enemy within chain range of the last, lowest id on ties; each jump x the falloff |
| L line | A charge wind-up during which the line is fixed on the target's position; then every enemy within 0.25 m of the segment is hit, sorted by distance |
| S shell | The target point is the centre of the densest cluster in range; the hit lands after the flight time as a delayed area hit; leaves a pool |
| M missiles | One delayed hit per chosen target, landing after the flight time at the target's position at launch; small splash |
| B beam | A hit every 6 ticks on the locked target; damage ramps per consecutive hit; no magazine |

Heat weapons: each shot adds heat; at the heat cap the weapon vents for its vent time (no fire) and restarts at 0; heat
falls at the cool rate whenever the weapon is not firing. The HUD shows a heat bar instead of a magazine count. Reload is
automatic at an empty magazine (a new weapon arrives with a full one).

**Damage** (per hit; the formulas of the handoff are unchanged and `damage_level`, `fire_rate_level` and `piercing_level` are
now the stacks of the directives `hot_loads`, `cyclic_tuning` and `penetrator_cores`):

```
effective_armor = max(0, enemy_armor * (1 - min(0.90, 0.15 * piercing_level)))
damage          = max(1, base_damage * (1 + 0.20 * damage_level) - effective_armor)
shots_per_sec   = base_sps * (1 + 0.15 * fire_rate_level) * (2.0 if overdrive else 1.0)
```

Order of the whole calculation (one place in the code, `DamageResolver`): weapon damage x weapon level x the `hot_loads`
formula above x conditional multipliers (full HP, low HP, stunned) - effective armor (the LMG's shred and `armor_ignore`
reduce the armor first) x ward and shieldbearer reductions x the debug multiplier. The golden values of `ARCHITECTURE.md`
6.5 stay true.

### 5.2 Directives (the upgrade choice)

The player-facing word is **DIRECTIVE** (2.4). Lantern Cell offers three after every wave and the player keeps one.

**What happens to the old upgrades** (decision D2)

| Before (Appendix A) | Now |
|---|---|
| `damage` (5 levels, bought with Scrap) | Directive `hot_loads`, 5 stacks, the same +20% per stack through the same formula |
| `fire_rate` | Directive `cyclic_tuning`, same formula |
| `armor_piercing` | Directive `penetrator_cores`, same formula and cap |
| `auto_turret` | Directive `turret_deploy`, 2 stacks, same turret |
| `smg_unlock` (300 Scrap, from wave 2) | Removed. The SMG is a salvage weapon |
| The upgrade drawer and the UPGRADES tab | Removed from the combat HUD. Its screen area becomes the weapon bar |
| Scrap prices | The five price rows stay only in the legacy fixture (Appendix A) |

Scrap keeps a job: it pays for **rerolls, second picks (buy-outs) and core patches** on the draft screen, and it is what a
scrapped crate turns into. It is no longer spent during combat, which removes the "open a drawer while they are hitting the
core" moment and gives that attention to weapon swaps and calls.

**Categories, rarities and tags.** 60 directives: 14 weapon, 10 turret, 8 core, 11 ability, 8 economy, 9 corrupted.
Rarities: common (stackable stats), rare (new behaviour), prototype (build-defining, one stack), corrupted (a strong gain
with a permanent price, red frame, the price printed as large as the gain). Each directive carries one or two **tags**. The
draft leans toward tags the build already has (weight x2 when two or more held directives share a tag), which is what turns
random offers into a build with an identity:

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

Cross-tag combos that should surprise (to be confirmed in play): `aftershock` + `emp_overload` (the EMP itself starts a blast
chain); `scattergun` + `reactive_plating` + `ground_wire` (a fortress that wants enemies at the cage); `kill_chain` +
`twin_link` + LMG (the off-hand gun feeds the fire-rate stack); `scrap_rounds` + `open_gate` (more Scrap, faster waves, more
damage); `static_pact` + arc projector (the event that hurts everyone else doubles this build).

**How an offer is generated.** Inputs: the offer's ordinal in the run, the unlocked pool, the held directives, the carried
weapons, the act. Steps, in this order (the order is part of the contract because it fixes the dice):

1. Build the candidate list: unlocked, not maxed, requirement met. Sort by id.
2. For slot 1 to N (N = 3, or 4 with `quartermaster`): apply pity overrides (rare pity, turret pity, `rw_rare_draft`); else
   roll the rarity with the act weights (7.1); if that rarity has no candidate, fall to the next lower, then higher.
3. Inside the rarity, pick by weight without replacement.
4. Roll the corrupted replacement for the last slot with the act's chance; if it hits and a corrupted candidate exists,
   replace the slot (one extra pick).
5. Show the offer. A reroll repeats steps 2 to 4.

Every reroll and every offer is therefore a pure function of (seed, pool, earlier decisions), which is what replays, bug
reports and the Daily Run need.

**Draft rules (numbers, CONTENT 3.7)**

| Rule | Value |
|---|---|
| Offer size | 3 (4 with `quartermaster`); no duplicate ids in one offer; maxed or requirement-failed directives have weight 0 |
| Rarity roll per slot | The act row of 7.1 |
| Weight inside a rarity | 10 base; x2 when the build already holds 2 or more directives sharing a tag with it; x1.5 when it modifies a carried weapon kind; x0.5 when it was offered and not picked in the previous offer |
| Corrupted slot | With the act's chance, the last slot is replaced by one corrupted directive (at most one per offer) |
| Rare pity | After 3 consecutive offers with no rare or better, slot 1 of the next offer is rare or better |
| Turret pity | The draft after wave 2 always contains `turret_deploy` in slot 1 if no turret is deployed and none was offered |
| Skip | Take nothing: +60 Scrap |
| Reroll | Free charges first; else `60 + 40 * n` Scrap (n = paid rerolls so far this run). Redraws all slots. Not allowed after `mod_no_breather` |
| Buy-out | Keep a second directive from the same offer: `250 + 100 * n` Scrap (n = buy-outs so far this run); once per draft |
| Patch core | On the draft screen: repair 10% of core max for `180 + 90 * n` Scrap (n = patches so far) |
| Pick | The chosen directive applies and the draft closes. With `rw_double_pick` the draft stays open for one more pick |

**Growth with meta unlocks.** The base pool has 31 directives; 7 Archive packs add 29 more (8.5). A pack adds whole tags
(blast, arc, fortress, gunline, hoard) so an unlock changes **which builds exist**, not how strong a build is. A larger pool
dilutes each offer, so the tag lean (x2) is what keeps builds reachable; the scorecard checks that the win rate of the
`balanced` bot does not fall by more than 5 points between the base pool and the full pool.

#### Directive lists (CONTENT 3)

Columns: `rar` C common, R rare, P prototype; `max` = stacks; `pool` = `base` (from the first run) or the Archive pack that
adds it. "Needs" is a requirement that must be met for the directive to be offered.

*Weapon directives (14)*

| id | rar | max | Effect per stack | Tags | Needs | pool |
|---|---|---:|---|---|---|---|
| `hot_loads` | C | 5 | +20% Warden damage | bullet | - | base |
| `cyclic_tuning` | C | 5 | +15% Warden fire rate | bullet | - | base |
| `penetrator_cores` | C | 5 | Enemy armor -15% for all sources, cap 90% | bullet, gunline | - | base |
| `extended_feed` | C | 3 | +30% magazine, +20% heat capacity | bullet | - | base |
| `fast_hands` | C | 3 | -20% reload and vent time; weapon swap time -0.15 s | tempo | - | base |
| `first_strike` | C | 3 | +50% damage to enemies at full HP | rail, blast | - | base |
| `heavy_barrel` | C | 3 | +35% damage, -10% fire rate | rail | - | base |
| `executioner` | R | 2 | +60% damage to enemies below 30% HP (stack 2: below 40%) | bullet | - | base |
| `ricochet` | R | 2 | A Warden hitscan shot that kills continues to one more enemy within 3 m for 60% (stack 2: two more) | bullet | a hitscan weapon carried | base |
| `incendiary_tips` | R | 3 | Warden hits ignite: 8 damage per second for 3 s (refreshes, does not stack per enemy) | blast, bullet | - | base |
| `kill_chain` | R | 1 | Each Warden kill grants +4% fire rate for 2 s, up to +40% | bullet, tempo | - | base |
| `shock_rounds` | R | 3 | Every 6th Warden shot (5th, 4th) arcs to 2 enemies within 2.5 m for 50% | arc, bullet | - | `u_p_arc` |
| `overpressure` | P | 2 | Every blast, pool and arc chain caused by the player's side is 35% larger | blast, arc | - | `u_p_blast` |
| `twin_link` | P | 1 | The holstered weapon also fires, at 35% of its rate, with its own magazine | bullet, gunline | 2 weapons carried | `u_p_proto` |

*Turret directives (10)*

| id | rar | max | Effect per stack | Tags | Needs | pool |
|---|---|---:|---|---|---|---|
| `turret_deploy` | C | 2 | Deploy a turret on the next free pad | gunline | a free pad | base |
| `turret_servos` | C | 4 | Turrets +25% fire rate | gunline | 1 turret | base |
| `turret_heavy_slugs` | C | 4 | Turrets +30% damage | gunline | 1 turret | base |
| `overwatch` | R | 1 | Turrets target elites, spitters, reclaimers and jammers first and deal +40% to them | gunline | 1 turret | `u_p_gunline` |
| `sentry_link` | R | 1 | Turrets gain half of the Warden's `hot_loads` and `cyclic_tuning` stacks (rounded down) | gunline, bullet | 1 turret | `u_p_gunline` |
| `flak_heads` | R | 2 | Turret shots splash 1.2 m for 40% (stack 2: 60%) | gunline, blast | 1 turret | `u_p_gunline` |
| `arc_pylons` | R | 2 | Every 4th turret shot chains to 2 enemies within 2.5 m for 60% (stack 2: every 3rd) | gunline, arc | 1 turret | `u_p_arc` |
| `mine_layer` | R | 2 | Each turret drops a mine every 8 s (6 s) within 4 m toward the spawn edge, 3 per turret: 90 damage, 2 m | gunline, blast | 1 turret | `u_p_gunline` |
| `pad_capacitors` | P | 1 | Overdrive also doubles turret fire rate | gunline, tempo | 1 turret | `u_p_gunline` |
| `last_stand_protocol` | P | 1 | While the core is below 35%, turrets +80% fire rate and the Warden reloads 50% faster | fortress, gunline | - | `u_p_proto` |

*Core directives (8)*

| id | rar | max | Effect per stack | Tags | pool |
|---|---|---:|---|---|---|
| `reinforced_cage` | C | 3 | Core max +150 and repair 150 now | fortress | base |
| `field_weld` | C | 3 | Repair 12% of core max now and 2% after every wave cleared | fortress | base |
| `ground_wire` | R | 2 | Enemies attacking the core attack 25% slower | fortress | base |
| `reactive_plating` | R | 3 | Every core hit deals 25 damage back to the attacker (armor ignored) | fortress | `u_p_fortress` |
| `core_lash` | R | 3 | The core fires an amber bolt at the highest-priority attacker every 1.5 s (1.2, 0.9) for 40 | fortress | `u_p_fortress` |
| `ember_vent` | R | 1 | Every 10th core hit taken triggers a free vent: 120 damage, 5 m ring | fortress, blast | `u_p_fortress` |
| `amber_surge` | P | 1 | The first time each wave the core drops below 50%, a free Shield starts (no cooldown change) | fortress, tempo | base |
| `dead_mans_switch` | P | 1 | Once per run: a hit that would end the run leaves the core at 20% and deals 600 to every enemy within 8 m | fortress | `u_p_fortress` |

*Ability directives (11)*

| id | rar | max | Effect per stack | Tags | pool |
|---|---|---:|---|---|---|
| `emp_capacitor` | C | 3 | EMP cooldown -15% | tempo, arc | base |
| `shield_lattice` | C | 3 | Shield absorbs +60 and lasts +2 s | fortress, tempo | base |
| `overdrive_coolant` | C | 3 | Overdrive lasts +2 s, cooldown -10% | tempo, bullet | base |
| `emp_tether` | R | 2 | EMP stun +1.5 s; stunned enemies take +25% damage | arc, tempo | `u_p_arc` |
| `emp_overload` | R | 2 | EMP deals 60 damage to every stunned enemy and breaks every ward | arc, blast | `u_p_arc` |
| `aftershock` | R | 1 | Enemies killed while stunned blast: 1.5 m, 30 damage | blast, arc | `u_p_blast` |
| `shield_burst` | R | 1 | When the Shield ends or breaks: 150 damage within 6 m of the core, knockback 1.5 m | fortress, blast | `u_p_blast` |
| `deadfall_uplink` | R | 2 | +1 Deadfall Strike charge now and +1 more at each act start (cap 3 held) | blast | base |
| `signal_hijack` | R | 1 | Adds the FREIGHT call button: 1 charge per act (7b) | blast | base |
| `bottomless` | P | 1 | During Overdrive the Warden uses no ammunition and builds no heat | tempo, bullet | `u_p_proto` |
| `cascade` | P | 1 | Activating an ability takes 6 s off the other two cooldowns | tempo | `u_p_proto` |

*Economy directives (8)*

| id | rar | max | Effect per stack | Tags | pool |
|---|---|---:|---|---|---|
| `scavenger_protocol` | C | 3 | +25% Scrap from kills | hoard | base |
| `requisition_line` | C | 2 | Rerolls cost 50% less; +1 free reroll now | hoard | base |
| `black_box` | C | 2 | Crates offer +1 choice | - | base |
| `salvage_drone` | R | 1 | Crates are secured 50% faster and are never lost | - | base |
| `compound_interest` | R | 1 | At each wave clear: +10% of banked Scrap, at most 150 | hoard | `u_p_ledger` |
| `data_siphon` | R | 2 | +2 Recovered Data per wave cleared for the rest of the run | hoard | `u_p_ledger` |
| `quartermaster` | R | 1 | Drafts offer 4 directives instead of 3 | - | `u_p_ledger` |
| `scrap_rounds` | P | 1 | Warden damage +1% per 40 banked Scrap, at most +60% | hoard, bullet | `u_p_ledger` |

*Corrupted directives (9; risk with reward, red-framed, always clearly labelled with the price as large as the gain)*

| id | max | Gain | Price | Tags | pool |
|---|---:|---|---|---|---|
| `glass_cannon` | 1 | Warden damage +80% | Core max -30% (current HP scaled) | bullet, rail | base |
| `open_gate` | 1 | Scrap from kills +60% | Spawn intervals x0.75 for the rest of the run | hoard | base |
| `overclocked_core` | 1 | All ability cooldowns -40% | Each activation costs 25 core HP (never the last 25) | tempo | base |
| `chorus_handshake` | 1 | Every third elite killed drops a crate | +1 elite in every normal wave | - | base |
| `unstable_munitions` | 1 | 20% of Warden kills blast: 2 m, 50 damage | 5% of reloads jam: +1.5 s | blast | `u_p_blast` |
| `borrowed_time` | 1 | 2 random prototype directives now | Core max -5% after every wave cleared | - | `u_p_corrupted` |
| `static_pact` | 1 | During a Static Front the Warden fires at +100% rate | Static Fronts happen in every wave from now on | arc, tempo | `u_p_corrupted` |
| `single_point` | 1 | Warden damage +60%, fire rate +30% | Turrets are removed and both pads are disabled for the run | bullet, rail | `u_p_corrupted` |
| `the_tally` | 1 | +1% Warden damage per 10 kills this run, at most +100% | Half of the bonus is lost every time the core takes damage through an empty shield in a wave (at most once per 5 s) | bullet | `u_p_corrupted` |

Totals: 14 + 10 + 8 + 11 + 8 + 9 = **60 directives**; 31 in the base pool, 29 in the Archive packs.

### 5.3 Auto turrets

12 damage, 3 shots/s, 17 m range, no magazine. Each turret targets on its own with the same priority rule,
measured from its own position. Turrets do not get the Warden's damage or fire-rate stacks and are not affected by
Overdrive unless a directive says so (`sentry_link` gives them half of the Warden's stacks, `pad_capacitors` lets Overdrive
double their rate). They benefit from armor piercing. The first `turret_deploy` fills pad T0, the second fills T1. No third.

Turret modifiers come from directives (5.2): `turret_servos`, `turret_heavy_slugs`, `overwatch`, `flak_heads`, `arc_pylons`,
`mine_layer`, `last_stand_protocol`. Events and enemies touch turrets in fixed ways: a jammer's aura halves the fire rate of
turrets on pads inside 7 m, a Core Surge doubles turret rate for 10 s and then takes them offline for 5 s, `mod_low_power`
keeps them offline for the first 12 s of a wave, and a Tremor Rig stomp takes them offline for 4 s.

**Turret types (stretch; CONTENT 8).** With a type unlocked, `turret_deploy` asks which type to place (one extra tap on the
draft screen). **[Stretch: first thing cut after the Daily Run, section 14.]**

| id | Unlock | Damage | Rate /s | Range m | Special |
|---|---|---:|---:|---:|---|
| `turret_gun` | base | 12 | 3.0 | 17 | The existing turret |
| `turret_arc` | `u_f_turret_arc` | 16 | 1.2 | 12 | Chains to 2 enemies within 2.5 m at 70%; ignores armor |
| `turret_mortar` | `u_f_turret_mortar` | 45 | 0.4 | 8 to 22 | 2.0 m blast, 0.8 s flight, targets the densest cluster |

### 5.4 Abilities (all three available from the start) and calls

| id | Effect | Duration | Cooldown | Cooldown starts |
|---|---|---|---|---|
| `emp` | Stuns every living enemy. Stunned enemies do not move or attack | 3 s (boss 1 s) | 35 s | on activation |
| `shield` | Absorbs the next 100 core damage. Does not heal | 8 s or until depleted | 50 s | when the shield ends |
| `overdrive` | Warden fire rate x2. Reloads still happen | 6 s | 60 s | when overdrive ends |

- EMP does not stack: a new stun replaces the old one only if longer. After the boss recovers from a stun it
  is immune to stuns for 5 s.
- An activation fails cleanly, with no cooldown started, when the ability is cooling down or active, when the
  game is paused, when no wave is running, or when the run is over.
- Cooldowns are simulation time. They freeze in a full pause and keep running in intermissions. (While a choice is pending
  the simulation does not advance at all, so they hold; they run again during the 3 s breather.)
- Ability directives (5.2) change durations, cooldowns and what an ability does. A jammer alive slows every ability
  cooldown to 70%; a Static Front locks EMP, Shield and Overdrive for 12 s (7b).

**Calls (player-triggered events, HUD buttons).** Deadfall Strike (STRIKE), Core Vent (VENT) and, with `signal_hijack`,
Freight (FREIGHT). They are not abilities: they have charges or a per-wave limit instead of a cooldown, and they are
used during a wave. Rules and numbers: section 7b.

### 5.5 Salvage and crates

Weapons are found in crates (sources and odds: CONTENT 2 and 7). Flow:

1. A crate lands on a fixed drop point (cyan flare, 3 s warning). It shows a ring that fills while **no living bodied enemy is
   within 2 m**. 12 uncontested seconds secure it; after 40 s CHORUS takes it. Nearby skitters and rushers divert to stand on
   it, so the player's tools are the ones already on the HUD: swap to the right weapon, EMP, a Deadfall Strike.
2. A secured crate is banked and opened at the next intermission, before the draft (section 10.5): the weapon is shown with its
   stats next to the two carried weapons. Choices: **TAKE IN SLOT 1**, **TAKE IN SLOT 2** (the replaced weapon is scrapped for
   half the crate's Scrap value), **LEVEL UP** (when it is a weapon already carried) or **SCRAP IT**.
3. The wave 2 clear always grants a crate if none was secured, so no run is stuck on the pistol.

| Rule | Value |
|---|---|
| Sources | Guaranteed at the wave 2 clear; route reward `rw_crate` (drops at 40% of the wave's window); the `supply_drop` event; boss kill in acts I and II (a boss crate: choose 1 of 2, using the next act's tier row); `chorus_handshake` (every third elite) |
| Drop points | 4 fixed points: (2.0, -3.0), (5.5, 3.5), (1.0, 4.5), (6.0, -8.0) |
| Secure time | 12 s of uncontested time; progress pauses while contested |
| Lifetime | 40 s after landing, then lost (a `crate lost` ticker line); `salvage_drone` removes the lifetime |
| Banked crates | Opened at the next intermission, before the draft. At most 2 banked; a third is converted to Scrap |
| Contents | 1 weapon from the unlocked pool by the tier row below; 35% of rolls are forced to a carried weapon below level 3 (level-up chance); `black_box` adds a choice |
| Scrapping | A scrapped crate pays 80 / 140 / 200 Scrap by act (act III has no boss crate: the run ends) |

| Act | T2 | T3 | T4 | T5 |
|---|---:|---:|---:|---:|
| I | 70 | 30 | 0 | 0 |
| II | 20 | 45 | 30 | 5 |
| III | 0 | 25 | 45 | 30 |

## 6. Enemies (twelve types, elites, and the bosses of 7a)

All are CHORUS machines: bone-ceramic plates over a dark gunmetal frame and **one red optic** (a slit, a bar or a single lens;
never two eyes, never a skull). Stats of the three original types come from `vertical_slice_balance.json` with the new Scrap
values of `data/enemies.json`; the other types are in `data/enemies.json` (CONTENT 4); radius and behavior flags come from
`content_ext.json` and the same file.

### 6.1 Stats

`class`: **B** bodied (pooled node, counts toward `enemy_cap` 50, takes an attack slot), **M** mini (instanced, counts toward
`swarm_cap` 40, no slot, burns out on the core), **S** standoff (bodied, holds a standoff point instead of a slot). `cost` is
the threat cost the wave budget is spent in. HP and core damage are multiplied by the act tier (7.1). Scrap is per kill.

| id | Role | class | HP | Speed m/s | Armor | Core dmg | Period s | Scrap | Radius m | cost | min act | type alive cap |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|
| `skitter` | Weak swarm | B | 45 | 2.3 | 0 | 12 | 1.5 | 5 | 0.35 | 1.0 | I | 50 |
| `hollow_warden` | Armored line-breaker | B | 150 | 1.1 | 8 | 30 | 2.0 | 15 | 0.55 | 3.0 | I | 24 |
| `rusher` | Fast breach threat | B | 65 | 3.6 | 2 | 28 | 1.2 | 8 | 0.40 | 1.5 | I | 32 |
| `mote` | Stream of tiny bodies | M | 12 | 3.0 | 0 | 6 once (burnout) | - | 1 | 0.18 | 0.4 | I | 40 |
| `burster` | Chain blaster | B | 70 | 1.9 | 0 | 70 once (detonates 1.2 s after reaching its slot) | - | 10 | 0.45 | 2.0 | I | 20 |
| `spitter` | Standoff artillery | S | 80 | 1.6 | 2 | 18 per bolt | 2.4 | 12 | 0.45 | 2.5 | I | 12 |
| `splitter` | Breaks into shards | B | 180 | 1.3 | 3 | 24 | 1.8 | 12 | 0.60 | 3.0 | II | 12 |
| `shard` | Fast mini from a splitter | M | 22 | 3.2 | 0 | 8 once (burnout) | - | 2 | 0.22 | 0 (only from splitters) | II | shares the mini cap |
| `shieldbearer` | Ward carrier | B | 220 | 1.0 | 6 | 26 | 2.0 | 25 | 0.60 | 5.0 | II | 6 |
| `reclaimer` | Repairs machines | S | 160 | 1.2 | 4 | 0 | - | 30 | 0.55 | 5.0 | II | 4 |
| `jammer` | Jams turrets and abilities | B | 140 | 1.5 | 2 | 20 | 2.0 | 22 | 0.50 | 4.0 | II | 6 |
| `borer` | Comes out of the ground | B | 90 | 2.6 | 4 | 26 | 1.4 | 12 | 0.45 | 2.5 | II | 16 |
| `ward_pylon` | Boss part (orbits the Aegis Array, 7a) | S | 300 | 0 (orbits its boss) | 0 | 0 | - | 0 | 0.40 | 0 (boss part) | II | 3 |

The Scrap values of the three original types drop (20 / 35 / 25 to 5 / 15 / 8) because a run now has about four times as
many kills; the legacy fixture keeps the old values (Appendix A). The Siege Hulk and the three other bosses are in 7a.

### 6.2 Shared rules

Shared rules: follow the flow field toward the core, keep apart with light separation, claim an **attack slot** on a ring
around the core, then stand there and hit the core once per period until killed. Arriving never removes a bodied enemy.
Nothing despawns while alive. Each death pays Scrap once. The stated exceptions:

- **Minis** (`mote`, `shard`) follow the flow field only (no separation, no slot, no stuck tracking). On reaching the cage they
  hit it once for their burnout damage (shield first) and are consumed, paying no Scrap. In the sim they are ordinary enemies:
  they can be shot, stunned and blasted (6.6).
- The **burster** is consumed by its own detonation on the core (it arms for 1.2 s at its slot).
- **Standoff** types (`spitter`, `reclaimer`) walk to a standoff point instead of an attack slot and act from there. A spitter
  counts as "attacking the core" for targeting once it has fired.

### 6.3 Silhouettes, behaviour and counters (acceptance A08, B04)

Size classes are far apart: mini 0.4 m tall, skitter 0.9, bipeds 1.4 to 1.8, specialists carry one tall or wide part (tube,
mast, ring, slab, tank), bosses 3 m and more. "Optic" is the single red light.

| id | Silhouette at phone scale (and where its single optic is) | Behaviour | Counters |
|---|---|---|---|
| `skitter` | Low four-legged crawler, long forelimbs, small head with a red slit | Low mass, strong separation, weaves sideways about 0.5 m as it runs. Easily pushed aside | Anything |
| `hollow_warden` | Upright broad-shouldered biped, slab chest plate, red visor bar. About 1.8x a Skitter's height | Heavy. Others flow around it; it is barely pushed. Walks a straight, steady line | Piercing, torch, rail |
| `rusher` | Forward-leaning lean biped, swept-back spines, red spine glow and spark trail | Sprints in a straight line at the core whenever the line is clear of props, almost ignores separation. Target-priority class | EMP, scattergun, pools |
| `mote` | A hand-sized hopping tripod, about a third of a skitter; the whole body is a small ceramic cap with a red slit. Reads as a moving grain | Runs the flow field in streams, burns out on the cage for 6 | Area, chain, turrets; a Shield turns a mote stream into nothing |
| `burster` | Hunched biped carrying a round hazard-striped tank on its back (the tank is wider than the body). Optic: a slit on the small head | Walks in; killed anywhere, it blasts the enemies around it 0.1 s later; reaching its slot it arms for 1.2 s (the tank swells) then detonates on the core | Kill it inside the crowd. Bursters next to bursters make a chain. Never let one arm |
| `spitter` | Tripod stance, a long tube on its back angled up at 45 degrees. Optic at the tube's base | Stops at 10.5 m and lobs slow slag bolts at the core (visible arc, 0.8 s) | Range, hornets, mortar, `overwatch` turrets; the Shield eats bolts |
| `splitter` | A three-lobed body with open seams, as wide as a Hollow Warden but lower. Optic on the centre lobe | Dies into 3 fast `shard` minis | Kill it far out, or with area damage so the shards die in the same blast |
| `shard` | One lobe of a splitter with two legs | As `mote`, 8 damage | As mote |
| `shieldbearer` | A tall biped behind a slab shield as wide as itself, held forward. Optic: a bar on the shield's upper edge. A thin red hex ring on the ground shows its ward radius | Everything within 2.4 m takes 40% damage while its ward pool lasts; the blocked damage drains the pool; the pool refills after 4 s of peace | EMP empties the pool. Arc and torch tear it. Focus the bearer (it is not protected by its own ward) |
| `reclaimer` | Low wide crawler with a tall mast and three cable arms. Optic on the mast head | Parks at 12.5 m and repairs up to 3 damaged machines (thin red tether lines) | Priority target by rule; strikes; rail |
| `jammer` | Biped with an upright ring antenna above its shoulders (a halo seen edge-on from above). Optic in the ring's hub | Turrets inside its 7 m aura fire at half rate; while any jammer lives, ability cooldowns run at 70%. Its death stuns its neighbours for 1 s | Kill it first; `overwatch` |
| `borer` | A drill-nosed wedge, low and long. Optic: a slit behind the drill | Comes out of the ground at a telegraphed breach point in mid-field and runs at the core | Watch the cracks; pools and mines on the breach; scattergun |
| `siege_hulk` | See 7a | See 7a | See 7a |

**Behaviour numbers** (CONTENT 4.2)

| id | Fields |
|---|---|
| `mote` | Flow field only; on reaching `core radius + 0.6` m: 6 core damage (shield first) and dies with no Scrap |
| `shard` | As `mote`, 8 core damage |
| `burster` | Death blast radius 2.6 m, 90 damage (enemies only), plus 35 core damage if it dies within 3 m of the core cage; 1.2 s fuse at its slot, then the blast and 70 core damage; blasts resolve 6 ticks after the death (the chain delay) |
| `spitter` | Standoff 10.5 m (24 standoff points on the slot arc); bolt flight 0.8 s |
| `splitter` | Splits into 3 `shard` on a 0.6 m ring at its death position |
| `shieldbearer` | Ward radius 2.4 m, ward pool 120, regenerates fully after 4 s without absorbing; every other enemy inside the radius takes x0.4 damage and the blocked damage drains the pool; pool at 0 = no protection until it regenerates. EMP empties the pool and blocks regeneration for the stun plus 4 s. Weapons that ignore armor drain it x3 (`ward_mult`) |
| `reclaimer` | Standoff 12.5 m; tethers up to 3 damaged non-boss enemies within 6 m, 14 HP per second each (the act tier applies); priority target |
| `jammer` | Aura radius 7.0 m: turrets whose pad is inside fire at 50% rate; while at least one jammer is alive ability cooldowns tick at 70%; on death, enemies within 3 m are stunned 1 s |
| `borer` | Spawns at a breach point 2.5 s after the breach telegraph; seeks the core directly |

### 6.4 Elites

An elite is a normal bodied enemy made dangerous by one or two **affixes**. Elites are rolled into the plan per wave: HP x2.2,
scale 1.25, Scrap x4, a red chevron ring on the ground under it (one instanced mesh for all elites), a small health bar, and a
ticker line when it enters (`ELITE: PLATED SWIFT RUSHER`). The affix is shown by **behaviour and one ground cue**, not by icons
over heads. Never elite: minis, bosses, `ward_pylon`, `burster` (its blast would be unfair), `reclaimer` before act III. At
most 4 elites are alive at once (others wait in the queue).

| id | Display | Effect | Counter |
|---|---|---|---|
| `aff_plated` | PLATED | +8 armor, HP x1.3 | Piercing, torch, arc, rail |
| `aff_swift` | SWIFT | Speed +45% | Slow pools, EMP, scattergun at the core |
| `aff_volatile` | VOLATILE | Death blast 3 m, 120 damage to enemies; 50 core damage if it dies within 3 m of the cage (burster's hazard stripes) | Kill it in the crowd, far from the core |
| `aff_regen` | REGENERATING | Heals 2% of max HP per second after 2 s without damage | Sustained fire, burn |
| `aff_warded` | WARDED | A personal ward equal to 40% of max HP absorbs damage first; regenerates after 5 s (a ring that shrinks as the ward drains) | EMP strips it; arc x3 |
| `aff_magnetic` | MAGNETIC | Every shooter within 12 m must target it while it lives (thin lines from shooters bend to it) | Burst it down; rail line through it |
| `aff_overclock` | OVERCLOCKER | Allies within 4 m: speed +30%, attack period -20% (a pulsing 4 m ring) | Priority kill; EMP |
| `aff_anchored` | ANCHORED | Immune to stun, slow and knockback | Raw damage |
| `aff_leech` | LEECHING | Each of its core hits heals every enemy within 4 m by 30 | Shield (an absorbed hit heals nothing) |
| `aff_shroud` | SHROUDED | Cannot be targeted from more than 12 m; always visible, drawn flickering | Turrets near it, area damage, strikes |

Combination rules: act I one affix; act II one, 40% two; act III two. Forbidden pairs: `aff_magnetic` + `aff_shroud`,
`aff_warded` + `aff_regen` (allowed only in act III), `aff_swift` + `aff_volatile` on a `rusher`. Affixes are rolled without
replacement, per wave, when the run plan is made.

### 6.5 Swarm composition rules

1. A wave is built from one pack: 2 to 4 groups (7 in `pack_everything`), each a count, a start, an interval and a region.
2. No more than 2 "specialist" types (spitter, reclaimer, jammer, shieldbearer) in one wave in act II, 3 in act III.
3. At least 40% of every wave's budget is basic fodder (skitter, mote, rusher): crowds are what make area weapons, chains and
   the phone-size picture work.
4. A reclaimer never spawns in the first 20% of the window (there is nothing to repair yet).
5. Bursters never spawn as the first 3 bodies of a wave (a blast needs neighbours to be interesting, and a lone burster
   reaching the core is a cheap hit).
6. Boss waves use the boss's escort pack (7a) and schedule nothing in the first 4 s after the boss enters.

### 6.6 Minis

Minis are the cheap way to more bodies. In the sim they live in the same enemy store (capacity 98 = 50 + 40 + 8) and can be
shot, stunned and blasted like anything else, but they skip separation, slots and stuck tracking (about a quarter of a bodied
enemy's movement cost, to be measured). They never show a health bar.

### 6.7 Readability rules at 50 + 40 units

Every enemy has a dark blob shadow and an emissive red optic so 50 of them read on a phone, and:

1. **One red optic per enemy and nothing else on an enemy glows.** Tanks, wards and auras are shape, stripe or ground ring.
2. Value ladder: ground darkest; bodies mid; optics and friendly lights brightest. Additive effects are capped so an optic is
   never washed out for more than 0.25 s (the blast flash lifetime).
3. Colour roles hold everywhere: cyan = ours (Warden, turrets, strikes, crate, beams, arcs), amber = the core and Scrap, red =
   CHORUS (optics, enemy projectiles, danger zones, elite rings). White is only for the first frames of a flash.
4. Every damage zone that can hurt the player's side is a **red hatched ground decal with a shrinking outline**; every zone that
   hurts enemies is cyan or amber and has no hatch. Shapes differ, so the rule survives colour blindness.
5. Size classes are far apart (see 6.3).
6. Only bosses, elites and damaged Hollow Wardens, shieldbearers and splitters show a health bar. Skitters, Rushers and minis
   show no bar.
7. Floating text is only Scrap gains and crate or event words. No damage numbers (the concept image shows them; at 90 bodies
   they would hide the swarm. A setting can come later, VQ2).
8. At most 3 ticker lines and 1 banner at a time; a boss banner pre-empts everything else.

## 7. Waves and the run

### 7.1 Acts, waves and the visible difficulty

15 waves in 3 acts of 5. Waves 5, 10 and 15 are boss waves. `budget` is threat points (each enemy has a `cost`, 6.1).
`window_s` is the time over which the wave's groups are scheduled. The plating tier of an act is **visible** (printed on the
act banner and the route screen, `CHORUS PLATING: TIER II`); it replaces any hidden scaling.

| Wave | Act | Kind | budget | window_s | Peak target (bodied / minis) | Route choice before it | Event slots |
|---:|---|---|---:|---:|---|---|---:|
| 1 | I | opener (fixed pack `pack_tide`, no modifier) | 24 | 22 | 10 / 0 | no | 0 |
| 2 | I | normal | 34 | 26 | 16 / 8 | yes | 0 |
| 3 | I | normal | 46 | 28 | 24 / 12 | yes | 1 (helpful only) |
| 4 | I | normal | 60 | 30 | 30 / 16 | yes | 1 |
| 5 | I | boss (act I pool) + escorts | 36 | 40 | 26 / 16 | no (boss briefing) | 1 (boss-safe) |
| 6 | II | normal | 78 | 30 | 34 / 16 | yes | 1 |
| 7 | II | normal | 92 | 32 | 38 / 20 | yes | 1 |
| 8 | II | normal | 108 | 34 | 42 / 24 | yes | 1 |
| 9 | II | normal | 124 | 36 | 46 / 28 | yes | 1 |
| 10 | II | boss (act II pool) + escorts | 70 | 50 | 36 / 24 | no (boss briefing) | 1 (boss-safe) |
| 11 | III | normal | 140 | 36 | 46 / 30 | yes | 1 |
| 12 | III | normal | 156 | 38 | 48 / 34 | yes | 2 |
| 13 | III | normal | 172 | 40 | 50 / 36 | yes | 2 |
| 14 | III | normal | 190 | 42 | 50 / 40 | yes | 2 |
| 15 | III | boss: Node 9 (variant) + escorts | 120 | 60 | 44 / 30 | no (boss briefing) | 1 (boss-safe) |

| Act | id | hp_mult | core_dmg_mult | Elites per normal wave | Affixes per elite | Draft rarity weights (common / rare / prototype) | Corrupted slot chance |
|---|---|---:|---:|---|---:|---|---:|
| I | `act_yard` | 1.00 | 1.00 | 0 (waves 1-2), 0-1 (waves 3-4) | 1 | 70 / 26 / 4 | 0% (waves 1-2), 12% |
| II | `act_gantry` | 1.35 | 1.15 | 1-2 | 1-2 | 55 / 35 / 10 | 18% |
| III | `act_node` | 1.80 | 1.30 | 2-3 | 2 | 40 / 42 / 18 | 25% |

Mission values: core 1,000 integrity; `enemy_cap` 50 bodied enemies (unchanged); `swarm_cap` 40 minis (new);
at most 4 elites alive; 3 s deploy countdown; 3 s breather after the last choice; the act-clear reward is a core repair of
+15% of max, one boss crate, and the next draft has prototype weight x3. Bosses do not get the act's HP multiplier.

**Timing and session length**

| Item | Target |
|---|---|
| Normal wave, combat time | 35 to 55 s (the spawn window is 22 to 42 s; clearing the tail takes the rest) |
| Boss wave, combat time | 70 to 100 s |
| Whole run, combat time (a win) | 780 to 1,020 s (13 to 17 minutes) |
| Choice time between waves | Untimed. Expected 8 to 15 s per intermission, 14 intermissions: 2 to 3.5 minutes |
| Wall time of a win | 15 to 20 minutes |
| A loss | Possible from wave 3 on; the median loss of a new player should be in act I (4 to 6 minutes) |

**Difficulty curve.** Three levers, all visible to the player: (1) the **budget** per wave, 24 at wave 1 to 190 at wave 14
(the old wave 5 is about 168 points in this scale, so the old final wave sits near the new wave 12 or 13 in body count); (2) the
**act plating tier**, enemy HP x1.0 / x1.35 / x1.8 and core damage x1.0 / x1.15 / x1.3, announced on the act banner; (3)
**composition**: new types unlock by act (`min act` in 6.1), elites appear from wave 3, two affixes in act III. Player power
grows through 14 drafts, 2 to 5 crates, 2 boss crates and Scrap purchases; a finished build is expected to deal 6 to 10 times
the damage per second of the starting pistol, more against crowds (to be measured).

**The run seed.** Five seeded sources of variance make a run: the route (packs and modifiers), the drafts, the salvage, the
events and the boss picks. Everything that can be decided before the run starts is decided at the start and stored in the run
plan, so what the route screen shows is exactly what spawns, and a choice at wave 3 never changes what wave 7 offers. Nothing
is rolled in reaction to how well the player is doing. A run is reproduced from its build, content, seed, kit, unlocked ids
and command log; the results screen and the pause overlay show the seed and SAME SEED starts a new run from it.

### 7.2 Threat packs

`share` is the fraction of the budget spent on that enemy. `region`: R = right edge, U = upper right, B = breach points
(mid-field). `start` is a fraction of `window_s`. `tempo` multiplies the even spacing (below 1 = bunched early).

| id | Display | min act | Groups (enemy share region start tempo) |
|---|---|---:|---|
| `pack_tide` | SWARM TIDE | I | skitter 0.70 R 0.0 1.0; mote 0.30 U 0.2 0.5 |
| `pack_column` | ARMORED COLUMN | I | hollow_warden 0.55 U 0.1 1.0; skitter 0.45 R 0.0 1.0 |
| `pack_breach` | FAST BREACH | I | rusher 0.50 U 0.25 0.8; skitter 0.50 R 0.0 1.0 |
| `pack_powder` | POWDER TRAIN | I | burster 0.35 R 0.15 1.0; skitter 0.45 R 0.0 0.8; mote 0.20 U 0.3 0.5 |
| `pack_battery` | SLAG BATTERY | I | spitter 0.35 U 0.2 1.0; hollow_warden 0.25 R 0.1 1.0; skitter 0.40 R 0.0 1.0 |
| `pack_brood` | SPLIT BROOD | II | splitter 0.45 R 0.1 1.0; mote 0.25 U 0.0 0.5; skitter 0.30 R 0.3 1.0 |
| `pack_bulwark` | SHIELD WALL | II | shieldbearer 0.30 R 0.1 1.0; hollow_warden 0.30 R 0.15 1.0; rusher 0.40 U 0.4 0.8 |
| `pack_repair` | RECLAIM LINE | II | reclaimer 0.15 U 0.0 1.0; hollow_warden 0.45 R 0.1 1.0; rusher 0.40 U 0.3 0.8 |
| `pack_static` | JAMMER SCREEN | II | jammer 0.20 U 0.1 1.0; rusher 0.35 R 0.3 0.8; skitter 0.45 R 0.0 1.0 |
| `pack_undermine` | UNDERMINE | II | borer 0.40 B 0.3 0.6; skitter 0.40 R 0.0 1.0; burster 0.20 U 0.2 1.0 |
| `pack_everything` | CONVERGENCE | III | skitter 0.25 R; rusher 0.15 U; hollow_warden 0.15 R; burster 0.15 R; spitter 0.10 U; splitter 0.10 R; mote 0.10 U (starts 0.0 to 0.4, tempo 1.0) |
| `pack_hunt` | ELITE HUNT | II | hollow_warden 0.50 R 0.0 1.0; rusher 0.50 U 0.2 1.0; budget x0.7 and +2 elites |

Group count = `max(1, roundi(budget * share / cost * (0.9 + 0.2 * u)))` with `u` from the wave's plan stream. Interval =
`clamp(window_s * (1 - start) * tempo / count, 0.08, 4.0)` seconds. A type that is not unlocked by act (`min act`, 6.1) is
replaced by `skitter` at the same budget. Boss waves use the boss's escort pack (7a).

### 7.3 The route choice

Before every normal wave except wave 1 the player picks one of two threats (11 choices per run). Each option shows: the pack
(name, glyphs of the three main enemy types, total count), the modifier if any, the number of elites, the risk tag (STANDARD or
HOT) and the reward.

- Option A is normally standard, option B hot. A standard option has budget x1.0 and a 25% chance of a modifier from the mild
  list. A hot option has budget x1.25, always one modifier, and from act II one more elite; its reward comes from the richer
  (hot) column. The two options never share a pack. From act II, 15% of choices are "both hot" (the banner reads `NO QUIET
  ROUTE`); it is announced and cannot be refused (VQ5).
- Both options of every wave are generated when the run starts, so what is shown is exactly what spawns, and a choice at wave 3
  never changes what wave 7 offers.
- Boss waves have no route choice. They show a **boss briefing**: the boss picked for this run, its variant, one line on how it
  attacks and one on what stops it. With `u_f_boss_intel` the boss is already shown at the act start.

Why this creates suspense: the reward is known, the cost is partly known (the modifier and elites are shown; the event of the
wave is not), and the core does not heal for free. A player at 45% core who takes `HOT: POWDER TRAIN + VOLATILE SWARM -> crate`
is making a real bet.

**Route rewards** (hot options draw from the hot column):

| id | Reward | Standard weight | Hot weight |
|---|---|---:|---:|
| `rw_scrap` | +120 / +200 / +280 Scrap (act I / II / III), paid at wave clear | 30 | 10 |
| `rw_patch` | Core repair +8% of max at wave clear | 20 | 10 |
| `rw_reroll` | +1 free reroll charge | 20 | 5 |
| `rw_crate` | A salvage crate drops during the wave (contested, 5.5) | 20 | 25 |
| `rw_rare_draft` | Next draft: slot 1 is rare or better | 10 | 20 |
| `rw_charge` | +1 Deadfall Strike charge (cap 3) | 0 | 10 |
| `rw_double_pick` | Next draft: keep 2 of the offer | 0 | 12 |
| `rw_data` | +15 Recovered Data, banked only if the wave is cleared | 0 | 8 |

**Wave modifiers**

| id | Display | List | Effect (whole wave) |
|---|---|---|---|
| `mod_plated` | PLATED | mild | Every enemy +4 armor |
| `mod_rush` | RUSH ORDER | mild | Spawn intervals x0.6 (the wave arrives faster; same count) |
| `mod_twin_gate` | TWIN GATE | mild | Every R group is split half R, half U |
| `mod_bounty` | BOUNTY | mild | Scrap from kills x1.5, enemy HP x1.2 |
| `mod_volatile` | VOLATILE SWARM | hot | Skitters blast on death: 1.2 m, 20 damage to enemies (chains with bursters and drums) |
| `mod_squall` | RAIN SQUALL | hot | Warden and turret range x0.7; cosmetic heavy rain on MID and HIGH |
| `mod_static_air` | STATIC AIR | hot | Ability cooldowns tick at 50% speed during the wave |
| `mod_low_power` | LOW POWER | hot | Turrets are offline for the first 12 s of the wave |
| `mod_elite_pair` | MARKED PAIR | hot | +2 elites |
| `mod_no_breather` | NO BREATHER | hot | The intermission after this wave has no core repair and its draft cannot be rerolled |

### 7.4 Intermission steps (no new application state)

The intermission has sub-steps; the application state machine is unchanged (they are overlays inside INTERMISSION).

| Step | Entered when | Left by | Timers |
|---|---|---|---|
| Salvage | Wave cleared and a crate is banked (repeats per crate) | The salvage choice | frozen |
| Draft | After salvage (or directly at wave clear) | Pick or skip (after any reroll, buy-out, patch) | frozen |
| Route | After the draft, when the next wave is normal | Picking an option | frozen |
| Boss briefing | After the draft, when the next wave is a boss wave | CONTINUE | frozen |
| Breather | After the last choice | 3 s elapse, or CONTINUE | **running** (cooldowns recover) |

Rules:

- While a choice is pending the simulation does not advance: no timer runs, no event is scheduled. The tick count of a run is
  therefore a function of the seed and the decisions only, never of thinking time. Bots answer on the next tick.
- Wave-clear effects are applied before the first choice: the route reward, `field_weld` repair, `compound_interest`, the
  act-clear repair (+15%) after a boss.
- Abilities stay illegal outside a running wave (SPAWNING and CLEARING). A weapon swap is legal in the breather.

### 7.5 Caps, the queue and the spawn rules

| Cap | Value | Enforced by |
|---|---|---|
| Bodied enemies alive | 50 (`enemy_cap`, unchanged) | The spawn queue, as before |
| Minis alive | 40 (`swarm_cap`, new) | Same queue, second counter |
| Per type alive | The "type alive cap" column of 6.1 (the number of pooled visuals of that type) | Same queue (a spawn waits when its type is at its cap) |
| Elites alive | 4 | Same queue |

Nothing is dropped: a spawn that cannot enter waits FIFO. Shards from a splitter that do not fit join the same queue at the
splitter's death position. Attack slots stay 64: minis and standoff types take none.

Other rules:

- Same-tick spawn order: group order, then ordinal within the group, then id.
- Spawn points are spread along the region's edge by a seeded, stratified pick, so a group never stacks.
- A 3 s "DEPLOYING" countdown precedes wave 1.
- A wave banner and one CHORUS or Accord line mark each wave start; an act banner marks each act (with its plating tier). The
  boss gets a banner and a stinger. Banners are only for wave start, act start and bosses; event text lives in the threat
  ticker (10.1).
- A stuck enemy (no progress for 4 s while moving) is logged, shown in debug, and deterministically freed. It
  is never deleted.

Peak targets (the table of 7.1) are goals. The generated plan will not reach them untuned; tuning is a planned task (section
8.4).

## 7a. Bosses

Bosses are "nodes" (canon naming). One boss per act; the act I and II bosses are each drawn from a pool of two; act III is
always **Node 9, the Siege Hulk**, in one of three variants. So a run meets 1 of 2 x 1 of 2 x 1 of 3 = 12 boss sequences. All
bosses: never pushed, EMP stun 1 s then 5 s immunity, the act tier does **not** multiply their HP (the HP below is final), a
HUD bar with phase pips, a banner and a stinger. Escorts come from the boss wave's budget (7.1).

| id | Act pool | Display | HP | Armor | Speed m/s | Core attack | Slots |
|---|---|---|---:|---:|---:|---|---:|
| `brood_carrier` | I | NODE 3 // BROOD CARRIER | 2,400 | 6 | 0.70 | 60 per 2.5 s | 3 |
| `lance_platform` | I | NODE 5 // LANCE PLATFORM | 2,000 | 10 | 0.80 | beam only | 0 (plants at 14 m) |
| `aegis_array` | II | NODE 6 // AEGIS ARRAY | 4,200 | 8 | 0.60 | 75 per 2.5 s | 3 |
| `tremor_rig` | II | NODE 7 // TREMOR RIG | 5,000 | 10 | 0.55 | 80 per 2.5 s | 3 |
| `siege_hulk` | III (always) | NODE 9 // SIEGE HULK | 9,000 | 12 | 0.65 | 90 per 2.5 s | 3 |

| id | The fight (first pass) | Telegraph | Counterplay |
|---|---|---|---|
| `brood_carrier` | A walking hive. Every 6 s opens its hatches and releases 6 motes. At 50% HP it "molts": armor 0, release every 3 s | Hatches glow 1 s before each release | Area and chain weapons; a stun resets the hatch timer; the molt phase is a damage window. Tests area damage and teaches minis |
| `lance_platform` | Walks to 14 m from the core and plants. Cycle 9 s: 3 s charge then a beam for 160 core damage. Takes +50% damage while charging (vents open). It never touches the cage | Red line from the boss to the core and a rising tone for the 3 s charge | EMP during the charge cancels the shot and stuns 2 s (then 5 s immune); Shield absorbs part; burst it during the charge. Tests ability timing |
| `aegis_array` | Deploys 3 `ward_pylon`s (300 HP each) that orbit it at 2.2 m. While a pylon lives the boss takes x0.2 damage. When all are down it is exposed for 10 s, then redeploys 3, then 2, then 1 | Pylon ring is drawn; exposed state flashes the boss bar cyan | Pylons are priority targets; EMP drops all pylon protection for 3 s; rail and strikes hit pylons and boss together. Tests priority and burst windows |
| `tremor_rig` | Every 10 s stomps: turrets offline 4 s and the Warden's magazine is emptied. At 66% and 33% HP opens 2 breach points with 3 borers each | Expanding red ring for 1.5 s before each stomp; breach cracks 2.5 s | An active Shield at the stomp negates it for turrets and Warden; heat weapons ignore the magazine dump. Tests the Shield as a brace |
| `siege_hulk` | Canon final boss. Huge hunched quadruped-stance brute, armored shoulders, red chest core, 4x the footprint of a Hollow Warden; shoves others aside. One of three variants per run (below). All variants: below 25% HP its attack period is -30% (banner `node 9 at 25 of 100. rate increased.`) | Variant shown on the boss briefing | Variant-specific |

Node 9 variants (chosen at the start of the run):

| id | Display | Behaviour |
|---|---|---|
| `hulk_plated` | NODE 9 // PLATED | Armor 24. Sheds plating at 66% and 33% HP: armor 24 to 12 to 4, speed +25% each time |
| `hulk_fed` | NODE 9 // FED | Two reclaimers escort it and are re-sent every 20 s if dead; it heals 1% of max HP per second while a reclaimer lives |
| `hulk_overclocked` | NODE 9 // OVERCLOCKED | Every 12 s: 1.5 s wind-up, then a 3 s charge at 3x speed. EMP during the charge stops it and stuns 2 s |

Boss wave escorts: `brood_carrier` skitter 0.6 / mote 0.4; `lance_platform` hollow_warden 0.5 / rusher 0.5; `aegis_array`
shieldbearer 0.3 / skitter 0.7; `tremor_rig` rusher 0.5 / burster 0.5; `siege_hulk` `pack_everything`.

Shared rules: a boss is never an elite; the EMP stuns a boss for 1 s and it is then immune for 5 s (unchanged); a telegraphed
boss attack can always be answered by at least two different tools the player always has (an ability, a Deadfall charge, raw
damage in a window); no boss attack removes more than 20% of the core's maximum in one hit; events during a boss wave come
from the boss-safe list; `static_front` never overlaps a Lance Platform charge.

## 7b. Chaos events and hazards

No event damages the core, the Warden or a turret directly: events change the fight; enemies do the damage. `who`: P
player-triggered (a HUD button), W world-triggered (rolled into the plan). `warn_s` is the telegraph before the effect. Damage
numbers ignore armor unless noted.

| id | who | Display | warn_s | Effect | Weight (act I / II / III) | Boss-safe |
|---|---|---|---:|---|---|---|
| `deadfall_strike` | P | DEADFALL STRIKE | 2.0 | 450 damage within 4 m (50% at the edge; bosses take half) on the densest cluster at the moment of the call; it does not track, so the cluster may move. Charges: 1 at run start, +1 at each act start, cap 3 | - | - |
| `core_vent` | P | CORE VENT | 0.5 | Costs 8% of core max (blocked at 10% or less). 220 damage within 6 m of the core, knockback 2 m, attackers' attack timers reset. Once per wave | - | - |
| `freight_call` | P | FREIGHT | 4.0 | Calls `runaway_freight` on the rail line with more enemies. 1 charge per act, needs `signal_hijack`. Huge on a column, useless on a scattered wave | - | - |
| `accord_window` | W | RELAY WINDOW | 0 | 10 s: Scrap from kills x2 | 30 / 15 / 10 | yes |
| `supply_drop` | W | ACCORD DROP | 3.0 | A crate lands on one of 4 drop points (5.5). The 3 nearest skitters or rushers divert to stand on it | 30 / 20 / 15 | yes |
| `power_surge` | W | CORE SURGE | 4.0 | 10 s: turrets fire x2, Warden reload and vent are instant. Then a 5 s brownout: turrets offline. A Shield activated during the surge cancels the brownout | 20 / 15 / 15 | yes |
| `runaway_freight` | W | RUNAWAY FREIGHT | 4.0 | A freight car crosses the yard on rail line A (z = -7.0) or B (z = 10.5) in 1.2 s: 700 damage to every enemy within 1.3 m of the line (bosses 350), knockback 1.5 m | 10 / 15 / 15 | yes |
| `static_front` | W | STATIC FRONT | 6.0 | 12 s: EMP, Shield and Overdrive cannot be activated (cooldowns frozen, active effects continue). Enemy wards, shieldbearer pools and jammer auras are also down; motes are stunned 2 s when it starts | 10 / 15 / 20 | no |
| `floor_breach` | W | FLOOR BREACH | 2.5 | 2 (act II) or 3 (act III) breach points open at x 2 to 8; each sends `1 + act` borers | 0 / 15 / 15 | no |
| `recount` | W | RECOUNT | 3.0 | The next 12 scheduled spawns enter together from the other edge | 0 / 5 / 10 | no |

**Hazard (placed, not timed).** `fuel_drums` FUEL DRUMS: at each act start 3 drums are placed on 3 of 6 fixed points. A drum
ignites when any blast, pool, strike or freight touches it, or after 80 stray LMG or pellet damage: 3 m blast, 150 damage to
enemies, then a 5 s slag pool. Drums do not block movement or shots.

**Schedule rules.** Event times are drawn uniformly in 25% to 70% of the wave's window; the same world event never appears in
two consecutive waves; `static_front` and `power_surge` never overlap; at most one harmful event (`static_front`,
`floor_breach`, `recount`) per wave in acts I and II; wave 3's event is always helpful (`accord_window`, `supply_drop` or
`power_surge`).

**Telegraphing.** Every event has the same three-part grammar, so the player learns it once: (1) **Warning**: a ticker line with
an icon and a countdown bar, a sound sting unique to the event, and a ground decal where it will happen (lane, ring, cracks, edge
arrows); harmful events use the red hatch, helpful ones cyan. (2) **Effect**: the decal becomes the effect (the car, the column of
light, the open breach). (3) **Aftermath**: a short state the player can read (brownout icon on turrets, slag pool, wreck sparks)
and a ticker line. Minimum warnings: 2.5 s for anything that spawns enemies, 4 s for anything that changes the player's tools, 6 s
for the Static Front. The warning of a harmful event is never covered by a banner (the boss banner waits).

**Fairness rules** (each one becomes a test):

1. No event damages the core, the Warden or a turret directly.
2. No harmful event in waves 1 and 2; wave 3's event is always helpful.
3. At most one harmful event per wave in acts I and II, two in act III; never two tool-denying events at once (`static_front`,
   the brownout of `power_surge`, `mod_low_power`, a Tremor Rig stomp).
4. Mercy: a harmful event whose warning would start while the core is below 15% is cancelled (and logged). This is a published
   rule (help text), not hidden scaling.
5. Abilities that are active when a Static Front starts keep running; cooldowns freeze, they do not reset.
6. Every event is in the plan from the start of the run; nothing is rolled in reaction to how well the player is doing.
7. The same world event never happens in two consecutive waves.
8. A run can always be lost and never be lost "from full": no single wave of act I can remove more than 60% of a full core from
   a player who takes any directive each draft and uses each ability once (checked with the `greedy` bot).

**Interactions with abilities, the pad and turrets**

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

## 8. Economy and progression

### 8.1 Scrap (in-run)

Earned on kill (amounts in 6.1, x1.5 under `mod_bounty`, x2 in a RELAY WINDOW), from route rewards (`rw_scrap`), from scrapped
crates and from SKIP on the draft screen. Starts at 0 (the kit `k_ledger` starts with 400). Shown in the top HUD. A floating
"+5" appears at the kill. Scrap is spent only on the draft screen: **rerolls, second picks (buy-outs) and core patches**
(prices in 5.2), and it is discarded when the run ends. Several directives make unspent Scrap a stat (`scrap_rounds`,
`compound_interest`), so spending it is a decision.

### 8.2 Recovered Data (permanent)

Granted exactly once per run id, at the moment the run ends, and saved before the results screen shows. Reopening or
re-rendering the results screen, or resuming the run any number of times, can never grant it again.

| Source | Data |
|---|---:|
| Each wave cleared | 6 |
| Act I boss killed | 30 |
| Act II boss killed | 45 |
| Victory (Node 9 killed) | 100 + `floor(50 * core_hp / core_max_hp)` |
| Route reward `rw_data` (only if the wave is cleared) | 15 each |
| `data_siphon` | 2 per stack per wave cleared after it was taken |
| Abandoned run (quit to menu) | 0 |
| Run that cannot be resumed (version or content changed) | Paid as a defeat at the last saved wave |
| Daily Run practice attempt (8.5) | Half of the above |

Typical: defeat in wave 4: 18. Defeat in wave 8: 72. Victory at 60% core: 90 + 75 + 130 = 295. A defeat at wave 8 pays about a
quarter of a victory. The results screen also gives, for free, the build recap, the seed, "what beat you" (the pack, modifier
and top three damage sources against the core in the last wave) and a SAME SEED button.

**Milestones** (one-time payouts, once per profile, granted in the same save as the run that earned them): 13 in all,
1,050 Data, front-loading the first hours.

| id | Condition | Data |
|---|---|---:|
| `ms_first_boss_<boss id>` (5) | First kill of that boss | 50 |
| `ms_first_victory` | First victory | 200 |
| `ms_victory_kit_<kit id>` (6) | First victory with that kit | 75 |
| `ms_three_builds` | Victories with 3 different primary weapons | 150 |

Data now has a sink: the Archive (8.5). It is still never shown in the combat HUD (it is not earned until the run ends).

### 8.3 Profile

Saved locally: total Recovered Data and lifetime Data, victories, best remaining core HP, best wave, boss kills, victories per
kit and per primary weapon (for the milestones), the bought unlocks, the chosen kit, the claimed milestones, today's Daily Run
result, settings, the hints seen and the list of rewarded run ids. The exact fields, the migration of a v1 profile (testers
keep their Data; nothing is unlocked for free) and the run file used for resume are in `ARCHITECTURE.md` 7.5.

### 8.4 Balance targets and tuning rules

Every number in this document is a first-pass value that the balance task confirms with deterministic runs. A scorecard run
of eight bot policies replaces the handoff's three targets.

The handoff targets, redefined:

| Old target (Appendix A) | New target |
|---|---|
| First-win run length 270 to 360 s | S16: 780 to 1,020 s of combat for a win |
| Peak alive per wave 10 / 18 / 28 / 40 / 50 within +/-20% | S17 with the peak columns of 7.1 (bodied and minis separately) |
| A bot that buys nothing loses by wave 3 or 4 | S6: `none` is defeated in act I (waves 3 to 5) |
| The greedy bot wins with 30% to 80% core | S4 and S7: `balanced` wins 40% to 70% of seeds; `greedy` wins 10% to 40%. Mean core at victory for `balanced`: 25% to 65% |

The bots (parameters in CONTENT 13): `none` (always skips, never uses abilities), `greedy` (the old "cheapest first" habit:
lowest rarity, leftmost, standard route), `random`, `hoarder` (weapons), `spammer` (abilities), `turret_rush`, `balanced` (the
reference competent player) and `risk` (hot routes and corrupted directives). All are deterministic and none reads a sim
stream.

The predictability scorecard (200 seeds x 8 policies; the gate version is 30 runs). PASS, WARN and FAIL follow the balance
tool's convention: WARN prints the number, FAIL is a structural break.

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
| S17 | Is the chaos budget respected? | Peak bodied and minis per act; blasts per tick | within the caps; peaks within 20% of the 7.1 table |
| S18 | Fairness rule 7b.8 | `greedy`: largest core loss in one act I wave from full | at most 60% |

Bots measure spread and dominance; they do not measure suspense or readability. Three owner playtests are gates: after the
vertical slice ("is the loop fun?"), after the full content ("can I read it?"), after balance ("one more run?"). Each has a short
form: where did you die, what surprised you, what could you not read, which choice felt empty.

Tuning levers, in order: wave budgets and windows, then pack shares, then act tiers, then enemy stats, then weapon and
directive numbers, then draft weights. Never invulnerability or hidden scaling. Every change to `data/*.json` is justified by a
scorecard run and recorded in `docs/reports/BALANCE_REPORT.md` (part 2 for the milestone). The untouched five-wave baselines
stay in `docs/handoff/03_DATA/` and in the legacy fixture (Appendix A).

### 8.5 The Archive (meta unlocks)

**Philosophy (decision D5).** Recovered Data buys **variety, not power**: weapons that join the crate pool, directive packs
that add build tags, kits that change how a run starts, and field options that add information (boss intel, route preview) or
flexibility (one free reroll, a third sling). There is no permanent +damage and no permanent +core. A player with everything
unlocked is not stronger than a new player on the same seed and kit; they have more ways to win. Threats (enemies, bosses,
events, modifiers) are never locked: variety on the CHORUS side is there from run 1.

**The tree.** Four branches (ARMORY, DIRECTIVES, KITS, FIELD), three tiers; tier 2 opens after 3 unlocks of any kind, tier 3
after 8. 24 unlocks, 5,250 Data in total (4,650 without the stretch turret types). Base content with no unlock: weapons
`pistol`, `smg`, `scattergun`, `assault_rifle`; the 31 base directives; `k_standard`; every enemy, boss, event and modifier.

| id | Branch | Tier | Cost | Unlocks |
|---|---|---:|---:|---|
| `u_w_hornet` | ARMORY | 1 | 80 | `hornet_rack` joins the crate pool |
| `u_w_lmg` | ARMORY | 1 | 120 | `lmg` |
| `u_w_mortar` | ARMORY | 2 | 160 | `slag_mortar` |
| `u_w_torch` | ARMORY | 2 | 220 | `cutting_torch` |
| `u_w_rail` | ARMORY | 3 | 300 | `rail_lance` |
| `u_w_arc` | ARMORY | 3 | 400 | `arc_projector` |
| `u_p_blast` | DIRECTIVES | 1 | 100 | `overpressure`, `aftershock`, `shield_burst`, `unstable_munitions` |
| `u_p_arc` | DIRECTIVES | 1 | 100 | `shock_rounds`, `arc_pylons`, `emp_tether`, `emp_overload` |
| `u_p_fortress` | DIRECTIVES | 2 | 150 | `reactive_plating`, `core_lash`, `ember_vent`, `dead_mans_switch` |
| `u_p_gunline` | DIRECTIVES | 2 | 150 | `overwatch`, `sentry_link`, `flak_heads`, `mine_layer`, `pad_capacitors` |
| `u_p_ledger` | DIRECTIVES | 2 | 200 | `compound_interest`, `data_siphon`, `quartermaster`, `scrap_rounds` |
| `u_p_corrupted` | DIRECTIVES | 3 | 250 | `borrowed_time`, `static_pact`, `single_point`, `the_tally` |
| `u_p_proto` | DIRECTIVES | 3 | 300 | `twin_link`, `last_stand_protocol`, `bottomless`, `cascade` |
| `k_breacher`, `k_signal` | KITS | 1 | 150 each | See the kit table |
| `k_gunline`, `k_ledger` | KITS | 2 | 250 each | |
| `k_gambler` | KITS | 3 | 350 | |
| `u_f_reroll` | FIELD | 1 | 120 | Every run starts with 1 free reroll |
| `u_f_boss_intel` | FIELD | 1 | 150 | The act's boss is shown at the act start instead of at its briefing |
| `u_f_preview` | FIELD | 2 | 200 | The route screen also shows the packs of the wave after next |
| `u_f_turret_arc` | FIELD | 2 | 300 | Turret type `turret_arc` (stretch) |
| `u_f_turret_mortar` | FIELD | 3 | 300 | Turret type `turret_mortar` (stretch) |
| `u_f_third_sling` | FIELD | 3 | 500 | A third weapon slot |

**Kits (starting loadouts).** Chosen on the briefing screen, a horizontal list of kit cards above DEPLOY.

| id | Display | Cost | Start |
|---|---|---:|---|
| `k_standard` | STANDARD ISSUE | 0 | Pistol |
| `k_breacher` | BREACHER | 150 | Scattergun and pistol, 1 turret deployed, core max -15% |
| `k_signal` | SIGNAL | 150 | Pistol, +1 Deadfall charge, EMP cooldown -20%, no turret pity |
| `k_gunline` | GUNLINE | 250 | Pistol, 2 turrets deployed, Warden damage -25% |
| `k_ledger` | LEDGER | 250 | Pistol, 400 Scrap, 2 free rerolls, core max -10% |
| `k_gambler` | LONG ODDS | 350 | Pistol, 1 random corrupted and 1 random prototype directive |

**Pacing and anti-grind**

| Check | Target |
|---|---|
| First unlock | After run 1 or 2 (cheapest 80; a first run that reaches wave 4 or 5 pays 18 to 24, plus a first-boss milestone of 50) |
| Something new every | 1 to 2 runs for the first 10 runs |
| Everything | 20 to 30 runs (about 6 to 9 hours), at about 150 to 250 Data per run |
| Losing is worth it | A defeat at wave 8 pays about a quarter of a victory |
| No farming loop | Data is per wave cleared and per boss; quitting pays 0; the hot route bonus `rw_data` needs the wave cleared; `data_siphon` costs a draft pick |

**Unlock rules.** An unlock purchase is atomic: check the tier gate, not owned, funds; debit; add the id; save. The Archive
shows locked content with names and costs (it sells the next run, VQ8).

**Daily Run (decision D8).** One seed per calendar day, the same for everyone: a fixed kit (`k_standard`) and the **full** pool
regardless of the profile's unlocks, so two players on the same day face the same plan and the same offers for the same
decisions. The seed comes from the UTC date, computed in the game layer (the simulation never reads the clock). Local only (the
game is offline): the menu shows today's best wave and whether it was won. One rewarded attempt per day; further attempts are
practice and pay half Data. The menu offers it after the first act I boss kill. It is not an unlock, and it is the first
thing cut if time is short (section 14).

## 9. Weapon bar, draft screen and Archive

The in-run screens replace the handoff's upgrade drawer. Wireframes are in section 10; this section says what each one is
for.

- **Weapon bar (in combat).** Two weapon cards (the active one 400 x 150, the holstered one 300 x 150, tap to swap) plus STRIKE
  and VENT (150 x 150 each), and a small FREIGHT button with `signal_hijack`. Each card shows the weapon, its level chevrons,
  and a magazine count or a heat bar with RELOADING or VENTING text. It takes the screen area of the old drawer tab.
- **Draft screen.** The info band (wave cleared, core, Scrap, the pack just beaten), the build chips (the tags held; tap for
  the BUILD list), three cards (four with `quartermaster`) with a frame by rarity (grey common, cyan rare, amber chevron
  prototype, red corrupted), the icon, name, stack counter ("2 -> 3 / 5"), the effect and its tags. A corrupted card prints its
  price as large as its gain. REROLL, PATCH and SKIP show their Scrap price; CONFIRM names the selected card and is disabled
  until a card is selected. After a selection BUY-OUT appears on the unselected cards ("KEEP ALSO 250").
- **Route screen.** Two cards, STANDARD and HOT, each with the pack name, the glyphs of its three main enemy types, the count,
  the elites, the modifier and the reward. The act strip above shows cleared waves, the current wave and the bosses; the act
  banner repeats the plating tier. The boss briefing uses the same frame with one wide card: boss name, silhouette glyph,
  "ATTACK:" and "ANSWER:" lines, CONTINUE.
- **Salvage screen.** The recovered weapon with its stats next to the two carried weapons; REPLACE on each slot, LEVEL UP for a
  duplicate (the highlighted default), SCRAP IT with its Scrap value, CONFIRM. A boss crate shows two weapons first (tap one).
- **Archive.** The meta screen of 8.5: four tabs, rows per tier with owned, affordable or locked state, a detail panel for the
  selected row and an UNLOCK button that names the price and offers an UNDO for 5 s.
- **Style.** `armory_style.png` is used for **styling only**: chamfered dark panels with a thin cyan rim, amber chevron rank
  marks, wide condensed capitals. The T1 to T5 weapon strip of `topdown_approved.png` is used for the weapon bar (12.2).
  There are no hand-authored icons per directive (60 are too many to author well): 8 tag glyphs x 4 rarity frames plus a
  category corner mark (about 20 SVGs), and 10 weapon silhouettes.

## 10. UX, HUD and screens

Design width 1080 px, height 1920 to 2400 px (the viewport expands vertically). 1 dp = 2.63 px. Touch targets
are at least 132 px (48 dp x 1.05 margin); primary buttons 148 px or more. Body text at least 38 px, small text never under
30 px. All text is live `Label` text from string tables through a theme, never baked into images. Everything respects the
display safe area.

One-handed rule: **every control of a choice screen is in the lower 60% of the screen**; the upper part is information only.
Every choice is two taps (select, then CONFIRM) so a slip never commits; the selected item stays highlighted with its full text.

### 10.1 Combat screen

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

- Top HUD: pause button; core bar with percent and number, amber, turns red and pulses below 25%, cyan overlay
  segment while the shield is up; "ACT II  W7/15" (act and wave of 15); Scrap with icon. Under the bar, the boss bar and the
  threat ticker (below).
- **The UPGRADES tab and the drawer are gone.** The magazine readout moves into the active weapon card (count or heat bar,
  RELOADING or VENTING text, level chevrons as in the concept bar).
- Tap the holstered card to swap. The active card pulses when a swap would help: the active weapon is reloading or venting
  and the other is ready (a hint, never an automatic action).
- STRIKE shows its charges; VENT shows its price and is dimmed when illegal (used this wave, core at 10% or less). FREIGHT
  replaces nothing: with `signal_hijack` it appears as a third small button and the active card narrows to 300.
- The **threat ticker** is new and sits under the top bar: up to 3 lines of icon + text + countdown bar. It owns all event
  text, including enemy-entry lines such as `ELITE: PLATED SWIFT RUSHER`. Banners are only for wave start, act start and bosses.
- Ability buttons: icon plus label plus state. Ready = cyan rim; active = amber fill draining; cooling =
  dark with a radial sweep and seconds. State is never shown by color alone (icon and text change too). Abilities locked by
  a Static Front show a static-pattern overlay and the text `OFFLINE`.
- Boss: a wide red bar with the boss name (for example "NODE 9 // SIEGE HULK") under the top HUD, with phase pips, only
  while the boss lives.
- Edge arrows show where a RECOUNT or a floor breach is coming from.
- Feedback: confirm pulse and sound when a choice is made; denied tap = short shake and deny sound; kill = small burst and
  "+Scrap"; core hit = amber edge flash (suppressed by Reduced Flash) and haptic tick; core below 25% = warning line and
  heartbeat sound.
- The bottom band grows from 23% to 26% of the height; the camera fit takes the band heights as inputs.

### 10.2 Other screens

| Screen | Content |
|---|---|
| Boot | Obsidian background, title, version. At most 3 s |
| Main menu | Title; total Recovered Data; best core HP and best wave; **RESUME RUN (WAVE n)** when a saved run exists; START MISSION, ARCHIVE, DAILY RUN (after the first act I boss kill), SETTINGS, QUIT. A low hero-angle 3D backdrop is allowed here only |
| Briefing | Mission name "HOLD THE LINE", the Accord radio text, objective lines (15 waves in three acts, core 1,000, three bosses), threat icons with their one-line briefings, the **kit selector** (a horizontal list of kit cards above DEPLOY), DEPLOY and BACK |
| Pause | RESUME, RESTART, SETTINGS, QUIT TO MENU, a line with the run's seed and a BUILD button (the directives and weapons held). Simulation, cooldowns and audio are frozen. Entered by the pause button, the back gesture, or the app going to the background |
| Results | VICTORY or DEFEAT, act and wave reached, run time, "what broke the line", the build recap, kills by type, core remaining, Recovered Data earned (count-up) with any milestone, new total, what the player can now afford in the Archive, the seed with SAME SEED, RETRY, ARCHIVE, MENU |
| Archive | See 10.7 |
| Settings | Sound on/off, Music on/off, Haptics on/off, Reduced Flash, High Contrast, Quality (Low/Mid/High), FPS cap (30/60), and optionally Swap assist (5.1, task V4-U) |

Back gesture: closes the open overlay (the Archive, settings); on a choice screen (salvage, draft, route, boss briefing) it
pauses and never dismisses the choice; in combat it pauses; else goes one screen back; on the menu it asks to quit.

### 10.3 Accessibility

Contrast 4.5:1 for text. Color always paired with icon or shape (enemy = red plus angular silhouette, ally =
cyan plus hex pad, core = amber plus ring; a danger zone is a red hatched decal, a friendly one has no hatch; an offline ability
shows the text OFFLINE). Reduced Flash removes full-screen flashes and screen shake and caps muzzle and EMP brightness; a
flash that covers more than 5% of the screen lasts at most 0.25 s. High Contrast adds dark outlines to HUD text, thickens
the hatch outline and the elite ring, and brightens enemy optics and rims.

### 10.4 First-run guidance (light)

No scripted tutorial. Hints stay one-line and event-tied, once per profile: first draft ("PICK ONE DIRECTIVE. THE REST ARE
GONE"), first route ("HOT ROUTES PAY MORE AND HIT HARDER"), first crate ("HOLD THE AREA CLEAR TO SECURE THE DROP"), first
second weapon ("TAP THE HOLSTERED WEAPON TO SWAP"), first event warning ("WATCH THE TICKER"), first corrupted offer ("RED
DIRECTIVES COST SOMETHING FOR GOOD"), and the handoff's first core hit ("SHIELD ABSORBS CORE DAMAGE"). The two hints tied to
the old drawer ("TAP UPGRADES", "SAFE TO UPGRADE. CONTINUE WHEN READY") go with it. **[POST-SLICE]** a real FTUE.

### 10.5 Choice screens (over the frozen battlefield, dimmed)

Draft screen:

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

- Tap a card: it lifts and CONFIRM names it. A long press shows the full rules text and what it combines with in the current
  build ("WORKS WITH: ARC PROJECTOR, EMP OVERLOAD").
- BUY-OUT appears on the unselected cards after a selection ("KEEP ALSO 250").
- With 4 offers (`quartermaster`) the cards are 250 px wide; text stays 30 px or more.

Route screen:

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

Salvage screen (a crate banked at the wave clear; a duplicate shows `LEVEL UP: SMG LV 2 -> 3` as the highlighted default; a
boss crate shows two weapon panels side by side first, tap one, then the same slot choice):

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

During combat the crate is a world object with a cyan ring that fills; the ticker shows `ACCORD DROP: 7 s` or `DROP
CONTESTED`. No tap on the battlefield.

### 10.6 Results additions

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

### 10.7 Archive screen

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

## 11. Audio direction

Bleak industrial. Dry, metallic, close. Rain and distant machinery under everything. No melody that resembles
any film score. All audio is synthesized by project scripts (deterministic, no third-party samples). Nothing is melodic. Each
warning sting is distinct in rhythm, not only in pitch.

| Group | Sounds |
|---|---|
| Weapons | pistol shot, SMG shot (shorter, brighter), reload start, reload done, turret shot; new: `shot_scattergun`, `shot_rifle`, `shot_hornet`, `hornet_pop`, `shot_lmg`, `lmg_spin` (loopable, 1 s), `shot_mortar`, `mortar_blast`, `torch_loop` (loopable), `shot_arc`, `arc_chain`, `rail_charge`, `shot_rail`, `weapon_vent`, `weapon_swap` |
| Impacts | hit on ceramic, hit on armor (duller, for armor > 0), small death burst, heavy death, boss death |
| Enemies | core strike light, core strike heavy, boss stomp; new: `burster_arm`, `blast_small`, `blast_big`, `spitter_shot`, `bolt_impact`, `splitter_split`, `ward_hum` (short), `ward_break`, `jammer_pop`, `borer_emerge`, `mote_burn`, `elite_spawn` |
| Bosses | `brood_hatch`, `lance_charge` (3 s rising, stinger class), `lance_fire`, `aegis_exposed`, `tremor_stomp`, `hulk_charge`, `boss_phase` |
| Events | `warn_harm` (two low pulses), `warn_help` (two rising pips), `strike_call`, `strike_impact`, `core_vent`, `freight_horn`, `freight_pass`, `static_front` (crackle bed, 2 s), `surge_up`, `brownout`, `breach_crack`, `recount_tick`, `relay_window`, `crate_land`, `crate_secured`, `crate_lost`, `drum_blast` |
| Abilities | EMP pulse, shield up, shield break, overdrive on, overdrive off, ability denied |
| UI | tap, purchase, deny, drawer open/close (legacy HUD), wave start, wave clear, intermission tick (last 3 s); new: `draft_open`, `draft_pick`, `draft_pick_corrupted`, `draft_reroll`, `route_pick`, `salvage_open`, `unlock_buy`, `act_start`, `resume_link` |
| Alerts | core low heartbeat, boss stinger, victory, defeat |
| Beds | one ambient loop (rain, hum, far metal), one low combat drone layer whose intensity follows the act and the wave budget (it used to follow the wave number) |

60 new ids (29 exist). Rules: per-sound voice caps (at most 3 starts of one id per frame, 16 voices total); **new:** 3 voices
are reserved for the alert class (event warnings, boss telegraphs, core low), the weapon class may use at most 8, and a "big
blast" sample replaces 4 or more simultaneous small blasts, so an LMG plus a chain blast never starves the warning that
matters. Two loop-capable weapon sounds (`lmg_spin`, `torch_loop`) are played as a held voice per weapon slot. Small random
pitch variation comes from a non-simulation RNG, audio pauses with the simulation, the Sound and Music toggles work at once.
**[POST-SLICE]** composed music and voice.

## 12. Art direction

Target: **cinematic industrial sci-fi seen from high above**, realistic-leaning, never cartoon. The game ships with procedural
"placeholder-plus" art (section 12.4) that follows the same rules so final models can replace it one asset at a time. The
shipped character look is **STYLISED** (the hard-surface look chosen by the owner after the Warden look-dev, v4, and rolled
out to the turret, the enemies and the Hulk in W3-D); the old blocky look stays available as `--look=current` for comparison.

### 12.1 Palette (`data/visual_tokens.json`; meanings never change)

| Token | Hex | Meaning |
|---|---|---|
| `obsidian` | `#101820` | Backgrounds, panels, deep shadow |
| `gunmetal` | `#6C7882` | Steel, frames, neutral UI lines |
| `bone_ceramic` | `#D8D3C5` | Armor plates (Warden and CHORUS), primary text |
| `warden_cyan` | `#39C9DB` | Friendly: Warden lights, turrets, pads, shield, ready states, strikes, crates, beams, arcs |
| `core_amber` | `#F1A34A` | Core, Scrap, Data, warm practical lights, prices |
| `chorus_red` | `#D94D4D` | CHORUS optics, enemy bars, enemy projectiles, danger zones, elite rings |

### 12.2 What each reference image decides

| Image | Use it for | Ignore |
|---|---|---|
| `topdown_approved.png` (primary) | Camera height and angle, Warden-left and swarm-right layout, swarm density, hex turret pads, cyan ring under the Warden, amber core glow, red containers and jersey barriers as dressing, HUD zones, **the T1 to T5 weapon strip (for the weapon bar)** | The "ASH-07" core label (must read **RELAY CORE B-4**), the DATA counter in combat, the prices, damage numbers |
| `environment_mood.png` | Wet reflective concrete, rain haze, teal/amber/red light pools, hazard stripes, cable runs, gantries | The low camera, the cyan core (the core is amber), the banner logo |
| `enemy_roster.png` | Plate-over-frame construction, weathered bone ceramic, red emissive seams, mass differences between classes, **the Shieldbearer and Reclaimer silhouettes (with one optic each)** | Skull faces and paired eyes |
| `armory_style.png` | Panel chamfers, cyan rim lines, amber chevrons, type hierarchy | The weapon list (the roster is 5.1) |
| `user_camera_inspiration.png` | How readable a few props and one character are from this height; container and barrier scale | Everything else (cartoon style, third-party UI and characters) |

### 12.3 Scene rules

- Ground: wet charcoal concrete with seams, puddle gloss, hazard stripes and a large "B-4" stencil. It must
  stay calm enough to track 50 silhouettes plus 40 minis: no high-contrast clutter inside the playable rectangle. The two rail
  marks of Runaway Freight stay low-contrast.
- Dressing lives outside the playable rectangle: stacked containers (dull red, grey), gantry legs, pipes,
  lamp posts with amber heads, cable bundles. Four props inside it (section 4.2).
- Lighting: one cool directional key light, low cool ambient, and faked light pools (additive ground quads):
  amber around the core, cyan around the Warden and turrets, faint red along the spawn edges. No real-time GI,
  no depth of field, no screen-space effects during combat.
- Relay Core B-4: a caged cylindrical reactor with an amber glowing column, cable roots, the label
  "RELAY CORE B-4" on its base. It dims and flickers as integrity falls and goes dark with sparks on defeat.
- Warden: bone-ceramic plates over gunmetal, cyan slit visor and shoulder light, planted wide stance, upper
  body yaws to the target. A cyan ring is painted under it. The carried weapon is in its hands and the holstered one sits on
  its pack (MID and HIGH).
- Turrets: squat tripod, twin barrels, cyan status light, on a hexagonal cyan-rimmed pad. An empty pad shows a
  dim outline so the player can see where a turret will go.
- VFX (all pooled and capped): amber tracer lines and muzzle flashes, spark impacts, small debris bursts on
  death, floating Scrap text, EMP = expanding cyan-white ground ring, shield = cyan dome shimmer over the core,
  overdrive = amber heat glow on the Warden and faster tracers, boss footfall dust. **New effects:** `fx_blast` (ring + flash),
  `fx_arc`, `fx_beam`, `fx_lob` (lobbed projectiles), `fx_pool` (slag and burn pools), `fx_telegraph` (lane, ring, cracks,
  arrows), `fx_ward_ring`, `fx_elite_ring`, `fx_tether`, `fx_strike_column`, `fx_freight`, `fx_crate_ring`, `fx_scorch`,
  `fx_ghost_swarm` (a cosmetic crowd massing outside the gates), `fx_static_overlay` (a HUD-space static pattern at the screen
  edges during a Static Front; never over the centre of the battlefield).
- Legibility rules of the new effects, on top of 6.7: (a) a flash that covers more than 5% of the screen lasts at most 0.25 s
  and is removed by Reduced Flash; (b) friendly beams and arcs are drawn thinner than the enemy's danger decals are wide, so a
  zone is never hidden by the player's own effects; (c) High Contrast thickens the hatch outline and the elite ring and
  brightens optics; (d) during a 6-blast chain the optics of survivors must still be countable in a capture (a legibility test
  with a fixed seed).
- What each quality tier shows (the simulation is identical on every tier): all sim-relevant visuals (bodies, minis, optics,
  telegraphs, pools, rings, projectiles, beams, arcs) on every tier; LOW shows a blast as a ring only, MID adds a flash, HIGH
  adds 4 debris streaks; scorch marks, brass debris, the ghost swarm, rain bursts and embers and screen shake grow from none
  on LOW to full on HIGH. **A telegraph, a danger zone or an enemy projectile is never tier-gated: what can hurt you is always
  drawn.** The pool sizes are in `ARCHITECTURE.md` 13.

### 12.4 Placeholder-plus strategy

Every model is built in code from primitives (boxes, cylinders, prisms, capsules) merged into one mesh per
actor, colored only with the palette materials, with emissive strips for optics and lights. Motion is
procedural (bob, lean, stomp, recoil, yaw). Details and the per-asset table are in `WORK_PLAN.md` section 6.
The new content follows the same rules, with these triangle budgets (all in the existing material set: `ceramic`,
`dark_frame`, `gunmetal`, `hazard`, `emit_red`; the one new material is the red hatch for danger decals):

| Asset | Triangle budget | Note |
|---|---:|---|
| 8 new weapons | 350 each | 12.5. See the Warden budget below |
| Holstered weapon on the pack | reuses the weapon mesh | MID and HIGH only |
| `mote`, `shard` | 40 each | One mesh, 2 surfaces (ceramic, emit_red), instanced |
| `burster`, `spitter`, `borer`, `jammer` | 400 each | One mesh, 3 surfaces, pooled like today's enemies |
| `splitter`, `shieldbearer`, `reclaimer` | 500 each | Same |
| `ward_pylon` | 150 | |
| 4 new bosses | 900 each | The Hulk's budget when the milestone was specified (it is 1,500 since the W3-D look rollout, so the bosses' final budget is fixed by the owner of `ActorMeshes.TRI_BUDGET`); one pooled node each |
| Crate, freight car, fuel drum, strike beacon | 200, 600, 80, 100 | Arena props |

**The Warden's triangle budget** is 2,500 for every body part plus the weapon in hand (it went 700, 2,000, 2,500 during the
W3-C look-dev; the Warden uses 2,448 triangles with the pistol and 2,472 with the SMG). A long weapon does not fit, so the
proposal is: body 2,300 plus a separate weapon budget of 350 (VQ4). The body must lose about 150 triangles or the budget
rises to 2,650; the owner of `ActorMeshes.TRI_BUDGET` decides after a look at the captures.

**[POST-SLICE]** authored, rigged, textured models and a full art pass (handoff phase P5).

### 12.5 Weapon looks and sounds

Models follow the hard-surface kit (vertex-colour AO), at most 350 triangles each, gunmetal with one cyan accent, readable
from above by **length and one signature shape**.

| id | Shot sound | Muzzle and impact effect | Model note (procedural) |
|---|---|---|---|
| `pistol` | existing `shot_pistol` | existing amber star and tracer | existing |
| `smg` | existing `shot_smg` | existing, shorter tracers | existing |
| `scattergun` | Low double thud with a short pump click | Wide amber fan of 8 thin streaks, 9 m long; dust kick at the muzzle | Short, thick, twin stacked barrels, shell rack on the side |
| `assault_rifle` | Hard dry crack, medium pitch | Tracer continues through the first target as a thinner line | Long receiver, top rail box, angled magazine |
| `hornet_rack` | Six quick hisses, then six small pops | Six curved cyan-white streaks, small ring blasts | A 2 x 3 tube block held at the hip, open ends glow cyan |
| `lmg` | A motor that spins up under a fast heavy rattle | Constant tracer stream, more sparks, brass debris cubes on MID and HIGH | Drum under a long barrel with a perforated shroud and a bipod stub |
| `slag_mortar` | Hollow "thoomp", whistle, wet blast | An amber-white ball on an arc, ring blast, then a dull red-amber ground pool with dark edge | Fat short tube angled up, base plate, three ribs |
| `cutting_torch` | Continuous rising hiss with a 60 Hz buzz, a "tsk" on vent | One bright cyan-white beam segment that thickens with the ramp; sparks at the contact point | Twin tanks on the pack side, a nozzle with a cowl |
| `arc_projector` | A sharp crack with a descending electric tail; a deeper thump on overheat | Jagged cyan-white bolt segments from muzzle to target to each chained enemy (3 jittered segments per jump), small blue-white ground rings like the EMP rings of the concept image | Three prongs around an emissive core, two coil rings |
| `rail_lance` | A one-second rising whine, then a slap and a long metallic ring | While charging: a thin cyan line. On fire: a thick white line for 0.12 s, sparks at every enemy on it | Very long twin rails with four brackets, capacitor box at the rear |

## 13. Scope summary

| In the game (the slice and the variety milestone) | Post-slice |
|---|---|
| One map; a generated 15-wave run in three acts with three bosses; untimed intermissions; resume after the app is killed | More maps and missions |
| 10 weapons, two carried, found as salvage and levelled by duplicates | |
| 12 enemy types, elites with 10 affixes, 5 bosses (3 per run) | |
| 3 abilities, Deadfall Strike, Core Vent, Freight; 60 directives; 2 turrets (turret types are stretch) | |
| 10 chaos events and fuel drums, every one telegraphed | |
| Recovered Data buys the Archive (24 unlocks of variety), kits and the Daily Run | |
| Procedural placeholder-plus art, synthesized audio | Authored models, rigs, music, cinematics |
| Offline, debug APK | Online features, monetization, store release |
| Fixed camera | Zoom control |

## 14. Open questions, decisions and assumptions

Each item states the default this design uses. "Q" items need the owner; "A" items are assumptions that tests
will lock in unless someone objects; "D" items are the owner's decisions of the variety milestone; "VQ" items are the open
questions of the variety milestone (`VARIETY_SPEC.md` 18.2, numbered Q1 to Q10 there; renamed here so they do not collide
with the Q items below).

**Binding decision record (owner, 2026-11-11).** The owner approved the variety milestone (`docs/design/VARIETY_PITCH.md`),
all eight decisions D1 to D8 as recommended, and the story text of `VARIETY_SPEC.md` section 16 as written. This supersedes
the handoff decision log's "other weapons: future roadmap only" and "No Shieldbearer/Reclaimer until future scope", and the
[POST-SLICE] tags that went with them.

| # | Topic | Default used |
|---|---|---|
| Q1 | New Warden designation | Serial **ASH-12**, callsign **FLINT**, text only, in `lore_en.json` (the approved victory line names Flint) |
| Q2 | Event name "Breach of Cinder" / title "Cinderfall" | Used as written, flagged as proposed canon |
| Q3 | "Hollow Warden" may be confused with the Hollow Accord (humans) | Keep the id and name (binding decision); the briefing explains they are CHORUS-driven frames |
| Q4 | How realistic the slice art must be | Procedural placeholder-plus now; authored models are post-slice |
| Q5 | Android package id | `com.normalexception.games.cinderfall.dev` (debug only) |

Decisions of the variety milestone (approved 2026-11-11; not the deviations D1 to D10 of `ARCHITECTURE.md` 14):

| # | Decision | Chosen |
|---|---|---|
| D1 | Run length | 15 waves, 3 acts of 5 |
| D2 | What Scrap is for | Rerolls, second picks (buy-outs), core patches; no combat shop |
| D3 | Weapons carried | 2, manual swap by tap |
| D4 | The word for cards | DIRECTIVES (and ARCHIVE for the meta screen) |
| D5 | Meta philosophy | Variety only, no permanent stat power |
| D6 | More bodies | Bodied cap stays 50; +40 instanced minis |
| D7 | Resume | Boundary snapshot + command tail |
| D8 | Daily Run | In the milestone, first thing cut |

Open questions of the variety milestone:

| # | Question | Default used |
|---|---|---|
| VQ1 | The story text and the five canon claims of 2.3 | Approved by the owner as written (2026-11-11) |
| VQ2 | Damage numbers over enemies (the concept image shows them) | Off; a setting later |
| VQ3 | Should the wave-1 pack also vary? | No: a fixed, learnable opener |
| VQ4 | Warden triangle budget with long weapons | Body 2,300 + weapon 350 (the budget is 2,500 in total today; the owner of `ActorMeshes.TRI_BUDGET` decides after the captures) |
| VQ5 | Should hot routes be refusable when both options are hot? | No (15% of choices from act II); it is announced |
| VQ6 | Is "restart the wave after a crash" acceptable as the crash-only path? | Yes |
| VQ7 | Keep the legacy 5-wave path in the sim as a test fixture forever? | Yes for this milestone (Appendix A) |
| VQ8 | Should the Archive show locked content as silhouettes or hide it? | Show names and costs (it sells the next run) |
| VQ9 | Android back on a choice screen | Pauses; never dismisses the choice |
| VQ10 | One rewarded Daily attempt per day relies on the device clock (offline) | Accepted; practice runs pay half |

Assumptions:

| # | Topic | Default used |
|---|---|---|
| A1 | SMG availability | **Closed.** The SMG is a salvage weapon (5.1). The handoff default (purchasable from wave 2 for 300 Scrap) lives in Appendix A |
| A2 | SMG swap | **Closed.** Weapons swap by tap in 0.4 s with no fire, each slot keeps its own magazine (5.1). The handoff default (immediate, full magazine, cancels a reload) lives in Appendix A |
| A3 | Upgrades and turrets | `hot_loads` and `cyclic_tuning` affect the Warden only; `penetrator_cores` affects all sources; Overdrive affects the Warden only. Exceptions are directives that say so (`sentry_link`, `pad_capacitors`) |
| A4 | EMP area | Every living enemy on the field |
| A5 | Cooldown start | EMP on activation; Shield and Overdrive when the effect ends (from the legacy spec, not contradicted by v2) |
| A6 | Boss stun immunity | 5 s after a stun ends |
| A7 | Abilities outside a wave | Rejected in the deploy countdown, in intermissions (every choice step and the breather) |
| A8 | Rusher priority vs "shortest ETA" | ETA is compared in 0.5 s buckets so the Rusher rule can matter |
| A9 | Hitscan and props | Props never block shots or blasts |
| A10 | Who attacks the core | Every bodied enemy that reaches an attack slot (64 slots on four rings), including outer rings. Minis hit once on arrival and standoff types fire from their points (6.2) |
| A11 | First core hit | One full attack period after the enemy reaches its slot |
| A12 | Time conversion | `ticks = round(seconds * 60)`; 0.68 s becomes 41 ticks (0.683 s) |
| A13 | Cost rounding | `floor(x + 0.5 + 1e-9)`, golden table in Appendix A.1 (175 x 1.7 is 297.4999... in floating point and must give 298); the function stays for the legacy fixture |
| A14 | Deploy countdown | 3 s before wave 1 |
| A15 | Purchases while paused | **Closed.** There is no combat shop and no drawer; a choice screen holds the simulation anyway (3, 7.4) |
| A16 | Defeat reward "completed waves" | Waves fully cleared before the core fell, paid at 6 Data each (8.2) |
| A17 | Enemy collision radii, turret pad positions, arena size | As in `arena.json` and `content_ext.json` (the handoff gives none) |
| A18 | Data in the combat HUD | Not shown (it is not earned until the run ends) |
| A19 | Hints | One-line contextual hints, once per profile (10.4) |
| A20 | Haptics | Short ticks on core hit and boss spawn; needs only the VIBRATE permission (the purchase tick belongs to the legacy drawer) |

**What to cut first if time is short** (in this order, each cut independent): (1) the Daily Run; (2) turret types and the third
sling; (3) cosmetic chaos beyond scorch marks; (4) `jammer` and `borer` (and `floor_breach`; the Tremor Rig's breaches become
a second stomp); (5) two weapons (`cutting_torch`, `hornet_rack`); (6) the second boss of each act pool (a visible loss of
variety, so late in the list); (7) the unlock packs `u_p_corrupted` and `u_p_proto`. **Never cut:** the run plan, drafts, two
weapon slots, bursters and minis, resume, the scorecard.

---

## Appendix A. Legacy 5-wave fixture

The five-wave game as the handoff defined it. It no longer ships, but it stays in the simulation as a **test fixture**
(`tests/fixtures/data_baseline/`, the untouched handoff data; VQ7): with no variety data files the content loader produces
exactly this content (4 enemies, 5 scripted waves, the shop enabled, no run plan, no drafts), and the existing 1,063 tests keep
guarding the simulation core on it (movement, targeting, cadence, slots, abilities, economy, replay). The shipped mission
sets `shop_enabled: false`. Nothing in this appendix is a rule of the shipped game.

### A.1 Upgrades (Scrap, in-run only)

Cost of the next level = `floor(base_cost * growth^level + 0.5)` where `level` is the number already bought.

| id | Effect per level | Max | Costs (level 1, 2, 3, 4, 5) |
|---|---|---:|---|
| `damage` | +20% Warden base damage | 5 | 175, 298, 506, 860, 1462 |
| `fire_rate` | +15% Warden shots per second | 5 | 150, 240, 384, 614, 983 |
| `armor_piercing` | Enemy armor -15% (cap 90%), for Warden and turrets | 5 | 200, 360, 648, 1166, 2100 |
| `auto_turret` | Deploys one turret on the next free pad | 2 | 350, 700 |
| `smg_unlock` | Replaces the pistol with the SMG | 1 | 300 (needs wave 2 or later) |

- Buying everything costs 11,496 Scrap. A full clear pays 6,690. The player must choose.
- A purchase is atomic: check state, prerequisite, max level and funds; debit once; apply at once. A failed
  purchase changes nothing and tells the player why (not enough Scrap, max level, locked until wave 2).
- A double tap cannot buy twice by accident: one purchase per upgrade per simulation tick.
- The SMG replaces the pistol for the rest of the run and arrives with a full magazine (swap is immediate and cancels a reload
  in progress). The first turret purchase fills pad T0, the second fills T1. No third. Purchases are impossible while paused
  (the drawer is behind the pause overlay).
- Weapons: Service Pistol (30 damage, 2 shots/s, magazine 12, reload 1.25 s, start) and SMG (15, 6, 30, 1.6 s).

### A.2 Enemies (four archetypes)

| id | Role | HP | Speed | Armor | Core hit | Period | Scrap | Radius |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `skitter` | Weak swarm | 45 | 2.3 m/s | 0 | 12 | 1.5 s | 20 | 0.35 m |
| `hollow_warden` | Armored line-breaker | 150 | 1.1 m/s | 8 | 30 | 2.0 s | 35 | 0.55 m |
| `rusher` | Fast breach threat | 65 | 3.6 m/s | 2 | 28 | 1.2 s | 25 | 0.40 m |
| `siege_hulk` | Wave-5 boss node | 2,800 | 0.65 m/s | 12 | 90 | 2.5 s | 400 | 1.60 m |

Only the boss had a HUD health bar; Hollow Wardens showed a small world-space bar once damaged; Skitters and Rushers showed
none. Shieldbearer, Reclaimer and boss phases were **[POST-SLICE]** (now built: 6 and 7a).

### A.3 Waves (`data/waves.json`)

A group spawns `count` enemies at `start_s + i * interval_s`.

| Wave | Beat | Groups (count x type @ start / interval, region) | Total | Peak target | Scrap |
|---|---|---|---:|---:|---:|
| 1 | Tutorial, first purchase | 16 skitter @ 0 / 1.7 right | 16 | 10 | 320 |
| 2 | SMG becomes available | 30 skitter @ 0 / 1.1 right; 6 hollow_warden @ 8 / 4 upper_right | 36 | 18 | 810 |
| 3 | Armor pressure | 42 skitter @ 0 / 0.85 right; 12 hollow_warden @ 5 / 2.6 upper_right | 54 | 28 | 1,260 |
| 4 | Rusher swarm, turret and EMP pressure | 58 skitter @ 0 / 0.68 right; 18 rusher @ 7 / 1.8 upper_right | 76 | 40 | 1,610 |
| 5 | Siege Hulk and escorts | 72 skitter @ 0 / 0.55 right; 20 rusher @ 10 / 1.65 upper_right; 10 hollow_warden @ 14 / 3 right; 1 siege_hulk @ 18 upper_right | 103 | 50 | 2,690 |

- Intermission: 8 s after waves 1 to 4. No hostiles exist during it. Upgrades are safe. CONTINUE skips it.
- Victory = wave 5 fully cleared, including the Siege Hulk and all escorts. The loop was
  `MENU -> BRIEFING -> DEPLOY (3 s) -> [ WAVE n: spawn -> clear -> INTERMISSION 8 s ] x4 -> WAVE 5 + boss -> VICTORY or DEFEAT -> RESULTS`.
- Peak targets (10 / 18 / 28 / 40 / 50 alive) are goals. The baseline schedule will not reach them untuned: the pistol kills a
  Skitter about every 1.1 s while wave 1 spawns one every 1.7 s.
- The cap of 50 alive, the FIFO queue, the same-tick spawn order and the stuck-enemy rule are unchanged (7.5).

### A.4 Economy and balance targets

- Recovered Data: victory `100 + floor(core_hp / 20)` (100 to 150); defeat `10 * waves_completed` (0 to 40). In the slice Data
  had **no sink**; it was a score on the menu.
- Balance targets: first-win run length 270 to 360 s; peak alive per wave 10 / 18 / 28 / 40 / 50 within +/-20%; a bot that buys
  nothing loses (defeat by wave 3 or 4); a greedy bot that buys the cheapest useful upgrade and uses abilities on simple
  triggers wins with 30% to 80% core HP. Lever order: spawn intervals and counts, then enemy HP and speed, then weapon numbers.

### A.5 Legacy combat HUD and armory

- The combat bottom band was 23% of the height: an `UPGRADES (n) ^` tab with the affordable count, the magazine readout, and
  the three ability buttons. The tab opened a drawer over the lower battlefield with five cards (Damage, Fire Rate, Armor
  Piercing, Turret, SMG), each with icon, name, level / max, the exact next effect, the exact cost and a lock or reason line;
  during a wave a "COMBAT CONTINUES" strip showed; in an intermission the drawer opened by itself with the countdown and a
  CONTINUE button. The top HUD read `WAVE n/5`.
- The armory was the drawer only: no weapon carousel, no tier cards, no equip choices ("no fake weapon cards"), and
  `armory_style.png` for styling only. **[POST-SLICE]** was a between-run Armory with permanent weapon tiers bought with Data
  (now the Archive, 8.5).
- Hints: first 150 Scrap ("TAP UPGRADES"), first core hit ("SHIELD ABSORBS CORE DAMAGE"), first intermission ("SAFE TO
  UPGRADE. CONTINUE WHEN READY"). The drawer code and its tests stay until task V5-A deletes them.
