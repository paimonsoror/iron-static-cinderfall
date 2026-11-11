# IRON STATIC: CINDERFALL - Game Design (vertical slice)

Version 1.0, 2026-11-10. Scope: the five-wave offline vertical slice defined by the handoff package
(`docs/handoff/`). Anything tagged **[POST-SLICE]** is out of scope and must not be built.

Source precedence (highest first): `handoff/00_START_HERE/DECISION_LOG.md` > handoff v2 design, architecture
and `03_DATA` > this document > `handoff/07_SOURCE_CONTEXT/LEGACY_TECH_SPEC_v1.md` > concept-art text.
This document fills gaps and records every default it picks in section 14. Numbers live in `res://data/*.json`,
never in code; the values quoted here are the handoff baselines and are expected to be tuned (section 8.4).

Technical contracts are in `ARCHITECTURE.md`. Task breakdown is in `WORK_PLAN.md`.

---

## 1. Premise

One-line pitch: **"The perimeter fell. One Warden, one core, five waves. Hold the line."**

You are the combat-systems commander of a reprogrammed Warden bolted beside **RELAY CORE B-4**, a booster core
in a ruined freight yard. CHORUS machines pour in from the right and upper right. The Warden aims, fires and
reloads on its own. You never aim and never move. You spend Scrap on upgrades and turrets, and you trigger
three abilities (EMP, Shield, Overdrive). Survive five waves and kill the Siege Hulk to win.

It is a session game, not an idle game: one mission, about 4.5 to 6 minutes, win or lose, replay.

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

### 2.2 What Cinderfall adds (PROPOSED, pending canon-owner approval)

All of this is flavor text held in `data/strings/lore_en.json`. Changing it later is a text edit.

- **The event.** CHORUS breaches the outer perimeter that Cinder holds ("the Breach of Cinder", working name
  "Cinderfall"). Cinder still stands at Relay six; the yards around it do not.
- **Relay Core B-4.** A booster core in the Quiet Yards freight hub (the original game's sector 1 setting: rail
  yards of a dead freight hub). It feeds Relay six. If B-4 goes dark the hollow loses its water.
- **The defender.** Lantern Cell wakes a second recovered Warden and writes it one directive: "Hold B-4."
  Working designation: **serial ASH-12, callsign FLINT** (placeholder; see section 14, Q1). The HUD only ever
  says "WARDEN", so the name appears in the briefing and results text only.
- **Hollow Wardens.** Warden frames that were never recovered. CHORUS still drives them. They are what the
  player's Warden used to be.

### 2.3 Text samples (tone reference)

- Briefing (Accord radio, about 45 words): "B-4 is still warm. The perimeter is gone and Cinder cannot turn
  around. You hold the core or the yards go dark. They come from the east gate and the gantry line. Five
  pushes, then the big one. Count what you bring back. Accord out."
- Wave whisper lines (HUD, one per wave): `relay core b-4 online. hostile swarm detected.` /
  `armored frames on the gantry line.` / `fast movers. watch the core.`
- CHORUS boss banner (wave 5): `node 9 consolidating. 1 of 1 will pass.`
- Warden system lines: `ROUND CHAMBERED`, `RELOADING`, `CORE INTEGRITY 24%`.

### 2.4 IP guardrails (inherited from the original, hard rules)

- No Terminator-franchise names, lines or likenesses. In particular **no chrome skull face with two glowing
  red eyes** on any enemy. The concept image `enemy_roster.png` shows skull-like faces; do not reproduce them.
  Every CHORUS machine gets a **single red optic slit or sensor bar**, never a pair of eyes in a skull.
- No real-world weapon brands or calibres in UI text. Use "SERVICE PISTOL" and "SMG", not "9MM".
- Never write "Terminator-like" anywhere. Never use The Tower's terms (Cash, Coins, Workshop, Cards).
- Original text, original audio, original art. Concept PNGs are reference only and are never shipped in the APK.

## 3. Core loop

```
MENU -> BRIEFING -> DEPLOY (3 s) -> [ WAVE n: spawn -> clear -> INTERMISSION 8 s ] x4 -> WAVE 5 + boss
     -> VICTORY or DEFEAT -> RESULTS (award Recovered Data once) -> RETRY or MENU
```

- Core starts at 1,000 integrity. Core at 0 = defeat, at any moment.
- A wave ends only when every scheduled spawn has entered and every living enemy is dead.
- Victory = wave 5 fully cleared, including the Siege Hulk and all escorts.
- Scrap starts at 0, comes only from kills, exactly once per kill, and resets every run.
- Recovered Data is the only thing that persists (plus best result and settings). No mid-run resume.
- Fully offline. No accounts, ads, purchases or network.

Moment-to-moment: watch the swarm build, decide what to buy with the Scrap you have, and time three abilities.

## 4. Camera, arena and controls

### 4.1 Camera

- Fixed orthographic 3D camera, **60 degrees down from horizontal** (allowed band 55 to 65), portrait.
- No zoom, pan or rotation in the slice. **[POST-SLICE]** optional zoom-out.
- The camera is fitted in code so the whole playable arena sits between the top HUD (top 11%) and the bottom
  controls (bottom 23%) on every aspect from 9:16 to 9:20, and still fits on a near-square foldable screen.

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
  **no lanes**.
- Four props (two concrete barriers, a crate stack, a drum cluster) create soft funnels. They never seal a
  route; a data test proves every spawn point can reach the core.
- The play axes are screen-aligned, but all scenery (containers, floor seams, hazard stripes, the "B-4"
  stencil) is dressed at about 35 to 45 degrees so the picture reads as the isometric yard in
  `topdown_approved.png`.

### 4.3 Controls (touch only)

| Input | Effect |
|---|---|
| Tap an upgrade card | Buy one level if affordable |
| Tap EMP / SHIELD / OVERDRIVE | Activate if ready |
| Tap the UPGRADES tab | Open or close the upgrade drawer (combat keeps running; banner says so) |
| Tap pause, or Android back | Full pause (simulation and cooldowns freeze) |
| Tap CONTINUE in an intermission | Skip the rest of the preparation timer |

There is no joystick, no manual aim, no manual fire, no target tapping and no drag gesture.

## 5. The player kit

### 5.1 The Warden (stationary, automatic)

- Never moves. The upper body turns to face its target; legs stay planted.
- Hitscan. A shot resolves on the tick it fires; the tracer is only a picture. Props never block shots (the
  Warden fires over low cover). This is a fixed, tested rule.
- Range 25 m. Enemies outside range cannot be targeted.

**Targeting** (re-evaluated when the 0.4 s lock expires or the target dies or leaves range). Among living
enemies in range, pick the best by this order:

1. currently attacking the core,
2. lowest estimated time to reach the core, in 0.5 s buckets,
3. Rusher class,
4. shortest distance to the Warden,
5. lowest stable enemy id.

**Weapons**

| Weapon | Damage | Shots/s | Magazine | Reload | How you get it |
|---|---:|---:|---:|---:|---|
| Service Pistol | 30 | 2 | 12 | 1.25 s | Start |
| SMG | 15 | 6 | 30 | 1.6 s | One-time in-run purchase, 300 Scrap, from wave 2 |

The SMG replaces the pistol for the rest of the run and arrives with a full magazine. Reload is automatic at
an empty magazine. **[POST-SLICE]** rifle, LMG, Gauss, Arc and every other weapon in `armory_style.png`.

**Damage formula** (per hit):

```
effective_armor = max(0, enemy_armor * (1 - min(0.90, 0.15 * piercing_level)))
damage          = max(1, base_damage * (1 + 0.20 * damage_level) - effective_armor)
shots_per_sec   = base_sps * (1 + 0.15 * fire_rate_level) * (2.0 if overdrive else 1.0)
```

### 5.2 Upgrades (Scrap, in-run only)

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

### 5.3 Auto turrets

12 damage, 3 shots/s, 17 m range, no magazine. Each turret targets on its own with the same priority rule,
measured from its own position. Turrets do not get the damage or fire-rate upgrades and are not affected by
Overdrive. They do benefit from armor piercing. First purchase fills pad T0, second fills T1. No third.

### 5.4 Abilities (all three available from the start)

| id | Effect | Duration | Cooldown | Cooldown starts |
|---|---|---|---|---|
| `emp` | Stuns every living enemy. Stunned enemies do not move or attack | 3 s (boss 1 s) | 35 s | on activation |
| `shield` | Absorbs the next 100 core damage. Does not heal | 8 s or until depleted | 50 s | when the shield ends |
| `overdrive` | Warden fire rate x2. Reloads still happen | 6 s | 60 s | when overdrive ends |

- EMP does not stack: a new stun replaces the old one only if longer. After the boss recovers from a stun it
  is immune to stuns for 5 s.
- An activation fails cleanly, with no cooldown started, when the ability is cooling down or active, when the
  game is paused, when no wave is running, or when the run is over.
- Cooldowns are simulation time. They freeze in a full pause and keep running in intermissions.

## 6. Enemies (four archetypes)

All are CHORUS machines: bone-ceramic plates over a dark gunmetal frame, one red optic. Stats from
`vertical_slice_balance.json`; radius and behavior flags from `content_ext.json`.

| id | Role | HP | Speed | Armor | Core hit | Period | Scrap | Radius |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `skitter` | Weak swarm | 45 | 2.3 m/s | 0 | 12 | 1.5 s | 20 | 0.35 m |
| `hollow_warden` | Armored line-breaker | 150 | 1.1 m/s | 8 | 30 | 2.0 s | 35 | 0.55 m |
| `rusher` | Fast breach threat | 65 | 3.6 m/s | 2 | 28 | 1.2 s | 25 | 0.40 m |
| `siege_hulk` | Wave-5 boss node | 2,800 | 0.65 m/s | 12 | 90 | 2.5 s | 400 | 1.60 m |

Shared rules: follow the flow field toward the core, keep apart with light separation, claim an **attack slot**
on a ring around the core, then stand there and hit the core once per period until killed. Arriving never
removes an enemy. Nothing despawns while alive. Each death pays Scrap once.

Distinct behavior (acceptance A08):

| id | Movement | Silhouette at phone scale |
|---|---|---|
| `skitter` | Low mass, strong separation, weaves sideways about 0.5 m as it runs. Easily pushed aside | Low four-legged crawler, long forelimbs, small head with a red slit |
| `hollow_warden` | Heavy. Others flow around it; it is barely pushed. Walks a straight, steady line | Upright broad-shouldered biped, slab chest plate, red visor bar. About 1.8x a Skitter's height |
| `rusher` | Sprints in a straight line at the core whenever the line is clear of props, almost ignores separation. Target-priority class | Forward-leaning lean biped, swept-back spines, red spine glow and spark trail |
| `siege_hulk` | Boss. Never pushed, shoves others aside, takes three adjacent attack slots. EMP stun 1 s then 5 s immune | Huge hunched quadruped-stance brute, armored shoulders, red chest core. 4x the footprint of a Hollow Warden |

Readability rules: every enemy has a dark blob shadow and an emissive red optic so 50 of them read on a phone.
Only the boss has a HUD health bar. Hollow Wardens show a small world-space bar once damaged. Skitters and
Rushers show no bar.

**[POST-SLICE]** Shieldbearer, Reclaimer and every other class in `enemy_roster.png`; boss phases.

## 7. Waves

Baseline schedules (`data/waves.json`). A group spawns `count` enemies at `start_s + i * interval_s`.

| Wave | Beat | Groups (count x type @ start / interval, region) | Total | Peak target | Scrap |
|---|---|---|---:|---:|---:|
| 1 | Tutorial, first purchase | 16 skitter @ 0 / 1.7 right | 16 | 10 | 320 |
| 2 | SMG becomes available | 30 skitter @ 0 / 1.1 right; 6 hollow_warden @ 8 / 4 upper_right | 36 | 18 | 810 |
| 3 | Armor pressure | 42 skitter @ 0 / 0.85 right; 12 hollow_warden @ 5 / 2.6 upper_right | 54 | 28 | 1,260 |
| 4 | Rusher swarm, turret and EMP pressure | 58 skitter @ 0 / 0.68 right; 18 rusher @ 7 / 1.8 upper_right | 76 | 40 | 1,610 |
| 5 | Siege Hulk and escorts | 72 skitter @ 0 / 0.55 right; 20 rusher @ 10 / 1.65 upper_right; 10 hollow_warden @ 14 / 3 right; 1 siege_hulk @ 18 upper_right | 103 | 50 | 2,690 |

Rules:

- At most **50** enemies alive. A spawn that would exceed the cap waits in a FIFO queue and enters as soon as
  there is room. Nothing is ever dropped.
- Same-tick spawn order: group order, then ordinal within the group, then id.
- Spawn points are spread along the region's edge by a seeded, stratified pick, so a group never stacks.
- Intermission: 8 s after waves 1 to 4. No hostiles exist during it. Upgrades are safe. CONTINUE skips it.
- A 3 s "DEPLOYING" countdown precedes wave 1.
- A wave banner and one CHORUS or Accord line mark each wave start. The boss gets a banner and a stinger.
- A stuck enemy (no progress for 4 s while moving) is logged, shown in debug, and deterministically freed. It
  is never deleted.

Peak targets (10 / 18 / 28 / 40 / 50 alive) are goals. The baseline schedule will not reach them untuned: the
pistol kills a Skitter about every 1.1 s while wave 1 spawns one every 1.7 s. Tuning is a planned task
(section 8.4).

## 8. Economy and progression

### 8.1 Scrap (in-run)

Earned on kill only (table in section 6). Starts at 0. Shown in the top HUD. A floating "+20" appears at the
kill. Scrap is discarded when the run ends.

### 8.2 Recovered Data (permanent)

- Victory: `100 + floor(core_hp / 20)` (100 to 150).
- Defeat: `10 * waves_completed` (0 to 40).
- Granted exactly once per run id, at the moment the run ends, and saved before the results screen shows.
  Reopening or re-rendering the results screen can never grant it again.
- In the slice Data has **no sink**. It is a score that accumulates on the menu. **[POST-SLICE]** permanent
  weapon unlock tree and armory.

### 8.3 Profile

Saved locally: total Recovered Data, missions completed (victories), best remaining core HP, settings, and the
list of rewarded run ids.

### 8.4 Balance targets and tuning rules

| Target | Value |
|---|---|
| First-win run length | 270 to 360 s |
| Peak alive per wave | 10 / 18 / 28 / 40 / 50, each within +/-20% |
| A bot that buys nothing | Loses (defeat by wave 3 or 4) |
| A greedy bot that buys the cheapest useful upgrade and uses abilities on simple triggers | Wins with 30% to 80% core HP |

Tuning levers, in order: spawn intervals and counts, then enemy HP and speed, then weapon numbers. Never
invulnerability or hidden scaling. Every change to `data/*.json` is justified by a deterministic balance run
and recorded in `docs/reports/BALANCE_REPORT.md`. The untouched baselines stay in `docs/handoff/03_DATA/`.

## 9. Armory and upgrades screen

- **In the slice** the "armory" is the in-run upgrade drawer only: five cards (Damage, Fire Rate, Armor
  Piercing, Turret, SMG). Each card shows icon, name, current level / max, the exact next effect ("+20% damage",
  "Deploy turret 1/2"), the exact cost, and a lock or reason line when it cannot be bought.
- No weapon carousel, no tier cards, no equip choices. The T1 to T5 weapon strip in `topdown_approved.png` is
  explicitly not built ("no fake weapon cards").
- `armory_style.png` is used for **styling only**: chamfered dark panels with a thin cyan rim, amber chevron
  rank marks, wide condensed capitals.
- **[POST-SLICE]** a between-run Armory screen with permanent weapon tiers bought with Data.

## 10. UX, HUD and screens

Design width 1080 px, height 1920 to 2400 px (the viewport expands vertically). 1 dp = 2.63 px. Touch targets
are at least 132 px (48 dp x 1.05 margin); primary buttons 148 px or more. Body text at least 38 px. All text
is live `Label` text from string tables through a theme, never baked into images. Everything respects the
display safe area.

### 10.1 Combat screen

```
+------------------------------------------------+  top HUD, 11% of height, inside safe area
| [||]   CORE 100% [==========]   WAVE 3/5  S 1240|
|        (boss bar appears here on wave 5)       |
+------------------------------------------------+
|                                                |
|                 3D battlefield                 |  about 66%; floating +Scrap; wave banner;
|                                                |  "COMBAT CONTINUES" strip when the drawer is open
|                                                |
+------------------------------------------------+
| [ UPGRADES (2) ^ ]   magazine 9/12  RELOADING  |  bottom controls, 23%
| [  EMP  ]      [ SHIELD ]      [ OVERDRIVE ]   |  three large ability buttons, radial cooldown + seconds
+------------------------------------------------+
```

- Top HUD: pause button; core bar with percent and number, amber, turns red and pulses below 25%, cyan overlay
  segment while the shield is up; "WAVE n/5"; Scrap with icon.
- Upgrade tab shows how many upgrades are affordable now. Opening it slides a drawer up over the lower
  battlefield with the five cards. During a wave a strip reads "COMBAT CONTINUES". In an intermission the
  drawer opens by itself and shows the countdown and a CONTINUE button.
- Ability buttons: icon plus label plus state. Ready = cyan rim; active = amber fill draining; cooling =
  dark with a radial sweep and seconds. State is never shown by color alone (icon and text change too).
- Boss: a wide red bar with the name "SIEGE HULK" under the top HUD, only while the boss lives.
- Feedback: purchase pulse and sound; denied tap = short shake and deny sound; kill = small burst and "+Scrap";
  core hit = amber edge flash (suppressed by Reduced Flash) and haptic tick; core below 25% = warning line and
  heartbeat sound.

### 10.2 Other screens

| Screen | Content |
|---|---|
| Boot | Obsidian background, title, version. At most 3 s |
| Main menu | Title; total Recovered Data; best core HP; START MISSION, SETTINGS, QUIT. A low hero-angle 3D backdrop is allowed here only |
| Briefing | Mission name "HOLD THE LINE", the Accord radio text, objective lines (5 waves, core 1,000, boss), threat icons for the four enemies, DEPLOY and BACK |
| Pause | RESUME, RESTART, SETTINGS, QUIT TO MENU. Simulation, cooldowns and audio are frozen. Entered by the pause button, the back gesture, or the app going to the background |
| Results | VICTORY or DEFEAT, waves cleared, kills by type, core remaining, run time, Recovered Data earned (count-up), new total, RETRY, MENU |
| Settings | Sound on/off, Music on/off, Haptics on/off, Reduced Flash, High Contrast, Quality (Low/Mid/High), FPS cap (30/60) |

Back gesture: closes the open drawer or overlay; else pauses during combat; else goes one screen back; on the
menu it asks to quit.

### 10.3 Accessibility

Contrast 4.5:1 for text. Color always paired with icon or shape (enemy = red plus angular silhouette, ally =
cyan plus hex pad, core = amber plus ring). Reduced Flash removes full-screen flashes and caps muzzle and EMP
brightness. High Contrast adds dark outlines to HUD text and brightens enemy optics and rims.

### 10.4 First-run guidance (light)

No scripted tutorial. Wave 1 shows three one-line hints tied to events: first 150 Scrap ("TAP UPGRADES"),
first core hit ("SHIELD ABSORBS CORE DAMAGE"), first intermission ("SAFE TO UPGRADE. CONTINUE WHEN READY").
Hints show once per profile. **[POST-SLICE]** a real FTUE.

## 11. Audio direction

Bleak industrial. Dry, metallic, close. Rain and distant machinery under everything. No melody that resembles
any film score. All audio is synthesized by project scripts (deterministic, no third-party samples).

| Group | Sounds |
|---|---|
| Weapons | pistol shot, SMG shot (shorter, brighter), reload start, reload done, turret shot |
| Impacts | hit on ceramic, hit on armor (duller, for armor > 0), small death burst, heavy death, boss death |
| Enemies | core strike light, core strike heavy, boss stomp |
| Abilities | EMP pulse, shield up, shield break, overdrive on, overdrive off, ability denied |
| UI | tap, purchase, deny, drawer open/close, wave start, wave clear, intermission tick (last 3 s) |
| Alerts | core low heartbeat, boss stinger, victory, defeat |
| Beds | one ambient loop (rain, hum, far metal), one low combat drone layer that rises with wave number |

Rules: per-sound voice caps (at most 3 starts of one id per frame, 16 voices total), small random pitch
variation from a non-simulation RNG, audio pauses with the simulation, the Sound and Music toggles work at
once. **[POST-SLICE]** composed music and voice.

## 12. Art direction

Target: **cinematic industrial sci-fi seen from high above**, realistic-leaning, never cartoon. The slice
ships with procedural "placeholder-plus" art (section 12.4) that follows the same rules so final models can
replace it one asset at a time.

### 12.1 Palette (`data/visual_tokens.json`; meanings never change)

| Token | Hex | Meaning |
|---|---|---|
| `obsidian` | `#101820` | Backgrounds, panels, deep shadow |
| `gunmetal` | `#6C7882` | Steel, frames, neutral UI lines |
| `bone_ceramic` | `#D8D3C5` | Armor plates (Warden and CHORUS), primary text |
| `warden_cyan` | `#39C9DB` | Friendly: Warden lights, turrets, pads, shield, ready states |
| `core_amber` | `#F1A34A` | Core, Scrap, Data, warm practical lights, purchase prices |
| `chorus_red` | `#D94D4D` | CHORUS optics, enemy bars, danger |

### 12.2 What each reference image decides

| Image | Use it for | Ignore |
|---|---|---|
| `topdown_approved.png` (primary) | Camera height and angle, Warden-left and swarm-right layout, swarm density, hex turret pads, cyan ring under the Warden, amber core glow, red containers and jersey barriers as dressing, HUD zones | The "ASH-07" core label (must read **RELAY CORE B-4**), the weapon-card strip, the DATA counter in combat, the prices, damage numbers |
| `environment_mood.png` | Wet reflective concrete, rain haze, teal/amber/red light pools, hazard stripes, cable runs, gantries | The low camera, the cyan core (the core is amber), the banner logo |
| `enemy_roster.png` | Plate-over-frame construction, weathered bone ceramic, red emissive seams, mass differences between classes | Skull faces and paired eyes, the Shieldbearer and Reclaimer |
| `armory_style.png` | Panel chamfers, cyan rim lines, amber chevrons, type hierarchy | The weapon list |
| `user_camera_inspiration.png` | How readable a few props and one character are from this height; container and barrier scale | Everything else (cartoon style, third-party UI and characters) |

### 12.3 Scene rules

- Ground: wet charcoal concrete with seams, puddle gloss, hazard stripes and a large "B-4" stencil. It must
  stay calm enough to track 50 silhouettes: no high-contrast clutter inside the playable rectangle.
- Dressing lives outside the playable rectangle: stacked containers (dull red, grey), gantry legs, pipes,
  lamp posts with amber heads, cable bundles. Four props inside it (section 4.2).
- Lighting: one cool directional key light, low cool ambient, and faked light pools (additive ground quads):
  amber around the core, cyan around the Warden and turrets, faint red along the spawn edges. No real-time GI,
  no depth of field, no screen-space effects during combat.
- Relay Core B-4: a caged cylindrical reactor with an amber glowing column, cable roots, the label
  "RELAY CORE B-4" on its base. It dims and flickers as integrity falls and goes dark with sparks on defeat.
- Warden: bone-ceramic plates over gunmetal, cyan slit visor and shoulder light, planted wide stance, upper
  body yaws to the target. A cyan ring is painted under it.
- Turrets: squat tripod, twin barrels, cyan status light, on a hexagonal cyan-rimmed pad. An empty pad shows a
  dim outline so the player can see where a turret will go.
- VFX (all pooled and capped): amber tracer lines and muzzle flashes, spark impacts, small debris bursts on
  death, floating Scrap text, EMP = expanding cyan-white ground ring, shield = cyan dome shimmer over the core,
  overdrive = amber heat glow on the Warden and faster tracers, boss footfall dust.

### 12.4 Placeholder-plus strategy

Every model is built in code from primitives (boxes, cylinders, prisms, capsules) merged into one mesh per
actor, colored only with the palette materials, with emissive strips for optics and lights. Motion is
procedural (bob, lean, stomp, recoil, yaw). Details and the per-asset table are in `WORK_PLAN.md` section 6.
**[POST-SLICE]** authored, rigged, textured models and a full art pass (handoff phase P5).

## 13. Scope summary

| In the slice | Post-slice |
|---|---|
| One map, one mission, five waves, boss | More maps and missions |
| Pistol, SMG | Rifle, LMG, Gauss, Arc and the armory |
| Skitter, Hollow Warden, Rusher, Siege Hulk | Shieldbearer, Reclaimer, others, boss phases |
| 3 abilities, 3 stat upgrades, 2 turrets | More abilities, turret types |
| Recovered Data as a saved score | Data sinks, permanent unlock tree |
| Procedural placeholder-plus art, synthesized audio | Authored models, rigs, music, cinematics |
| Offline, debug APK | Online features, monetization, store release |
| Fixed camera | Zoom control |

## 14. Open questions and assumptions

Each item states the default this design uses. "Q" items need the owner; "A" items are assumptions that tests
will lock in unless someone objects.

| # | Topic | Default used |
|---|---|---|
| Q1 | New Warden designation | Serial **ASH-12**, callsign **FLINT**, text only, in `lore_en.json` |
| Q2 | Event name "Breach of Cinder" / title "Cinderfall" | Used as written, flagged as proposed canon |
| Q3 | "Hollow Warden" may be confused with the Hollow Accord (humans) | Keep the id and name (binding decision); the briefing explains they are CHORUS-driven frames |
| Q4 | How realistic the slice art must be | Procedural placeholder-plus now; authored models are post-slice |
| Q5 | Android package id | `com.normalexception.games.cinderfall.dev` (debug only) |
| A1 | SMG availability | Purchasable from wave 2 (first intermission onward), 300 Scrap |
| A2 | SMG swap | Immediate, full magazine, cancels a reload in progress |
| A3 | Upgrades and turrets | Damage and fire rate affect the Warden only; armor piercing affects all sources; Overdrive affects the Warden only |
| A4 | EMP area | Every living enemy on the field |
| A5 | Cooldown start | EMP on activation; Shield and Overdrive when the effect ends (from the legacy spec, not contradicted by v2) |
| A6 | Boss stun immunity | 5 s after a stun ends |
| A7 | Abilities outside a wave | Rejected in the deploy countdown and in intermissions |
| A8 | Rusher priority vs "shortest ETA" | ETA is compared in 0.5 s buckets so the Rusher rule can matter |
| A9 | Hitscan and props | Props never block shots |
| A10 | Who attacks the core | Every enemy that reaches an attack slot (64 slots on four rings), including outer rings |
| A11 | First core hit | One full attack period after the enemy reaches its slot |
| A12 | Time conversion | `ticks = round(seconds * 60)`; 0.68 s becomes 41 ticks (0.683 s) |
| A13 | Cost rounding | `floor(x + 0.5 + 1e-9)`, golden table in section 5.2 (175 x 1.7 is 297.4999... in floating point and must give 298) |
| A14 | Deploy countdown | 3 s before wave 1 |
| A15 | Purchases while paused | Not possible (the drawer is behind the pause overlay) |
| A16 | Defeat reward "completed waves" | Waves fully cleared before the core fell |
| A17 | Enemy collision radii, turret pad positions, arena size | As in `arena.json` and `content_ext.json` (the handoff gives none) |
| A18 | Data in the combat HUD | Not shown (it is not earned until the run ends) |
| A19 | Hints | Three one-line contextual hints, once per profile |
| A20 | Haptics | Short ticks on purchase, core hit and boss spawn; needs only the VIBRATE permission |
