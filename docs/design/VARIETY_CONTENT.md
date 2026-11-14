# IRON STATIC: CINDERFALL - Variety milestone: first-pass content tables

Version 0.1 (proposal), 2026-11-11, task V0. Companion to `VARIETY_SPEC.md` (rules) and `VARIETY_PITCH.md` (owner summary).
This file is a **proposal that lives in `docs/design/`**. Nothing here is loaded by the game. Build agents transcribe these
tables into the data files named in VARIETY_SPEC section 13.1. Every number is a first-pass value to be tuned by the balance
task (V5-C) with deterministic runs; none of them has been simulated.

Conventions: seconds are converted with `ticks = roundi(seconds * 60)`; rates are shots per second; distances are meters;
"core dmg" is damage to Relay Core B-4; "Scrap" is the in-run currency; "Data" is Recovered Data. Ids are final unless the
owner renames them. Player-facing names are in VARIETY_SPEC section 16 (story text pending approval).

---

## 1. Run structure (`data/run.json`)

### 1.1 Acts and waves

15 waves in 3 acts of 5. Wave 5, 10 and 15 are boss waves. `budget` is threat points (section 4.1 gives the cost of each
enemy). `window_s` is the time over which the wave's groups are scheduled. `hp_mult` and `core_dmg_mult` are the act's
**visible** plating tier (shown on the act banner, never hidden).

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

Mission values: `core_max_hp` 1000; `enemy_cap` 50 (bodied, unchanged); `swarm_cap` 40 (minis, new); `max_elites_alive` 4;
`prepare_seconds` 3; `breather_seconds` 3 (countdown after the last choice); act-clear reward: core repair +15% of max, one
boss crate, the next draft has prototype weight x3.

### 1.2 Route rewards

Each route option carries one reward. "Hot" options (budget x1.25 and a modifier or an extra elite) draw from the hot column.

| id | Reward | Standard weight | Hot weight |
|---|---|---:|---:|
| `rw_scrap` | +120 / +200 / +280 Scrap (act I / II / III), paid at wave clear | 30 | 10 |
| `rw_patch` | Core repair +8% of max at wave clear | 20 | 10 |
| `rw_reroll` | +1 free reroll charge | 20 | 5 |
| `rw_crate` | A salvage crate drops during the wave (contested, section 7.2) | 20 | 25 |
| `rw_rare_draft` | Next draft: slot 1 is rare or better | 10 | 20 |
| `rw_charge` | +1 Deadfall Strike charge (cap 3) | 0 | 10 |
| `rw_double_pick` | Next draft: keep 2 of the offer | 0 | 12 |
| `rw_data` | +15 Recovered Data, banked only if the wave is cleared | 0 | 8 |

Option generation per normal wave: option A is "standard" (budget x1.0, 25% chance of a modifier from the mild list), option B
is "hot" (budget x1.25, always one modifier, +1 elite from act II). The two options never share a pack. From act II, 15% of
choices are "both hot" (the banner reads `NO QUIET ROUTE`). Elites appear from wave 3, also those of a pack or a modifier:
wave 2 never draws `mod_elite_pair` (the next modifier of its list is taken instead; V5-A, after a hot wave 2 of MARKED PAIR
killed the reference player of the scorecard before wave 3).

### 1.3 Threat packs (composition templates)

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
`clamp(window_s * (1 - start) * tempo / count, 0.08, 4.0)` seconds. A type that is not unlocked by act (`min_act` in section
4.1) is replaced by `skitter` at the same budget.

### 1.4 Wave modifiers

| id | Display | List | Effect (whole wave) |
|---|---|---|---|
| `mod_plated` | PLATED | mild | Every enemy +4 armor |
| `mod_rush` | RUSH ORDER | mild | Spawn intervals x0.6 (the wave arrives faster; same count) |
| `mod_twin_gate` | TWIN GATE | mild | Every R group is split half R, half U |
| `mod_bounty` | BOUNTY | mild | Scrap from kills x1.5, enemy HP x1.2 |
| `mod_volatile` | VOLATILE SWARM | hot | Skitters blast on death: 1.2 m, 20 dmg to enemies (chains with bursters and drums) |
| `mod_squall` | RAIN SQUALL | hot | Warden and turret range x0.7; cosmetic heavy rain on MID and HIGH |
| `mod_static_air` | STATIC AIR | hot | Ability cooldowns tick at 50% speed during the wave |
| `mod_low_power` | LOW POWER | hot | Turrets are offline for the first 12 s of the wave |
| `mod_elite_pair` | MARKED PAIR | hot | +2 elites |
| `mod_no_breather` | NO BREATHER | hot | The intermission after this wave has no core repair and its draft cannot be rerolled |

---

## 2. Weapons (`data/weapons.json`)

Stats at weapon level 1. `kind`: H hitscan, C cone, L line, S shell (delayed area hit), B beam, M missiles, A arc chain.
`feed`: magazine size, or `heat` for overheat weapons. All ranges are from the Warden.

| id | Tier | kind | damage | rate /s | feed | reload s | spread | range m | pierce | area m | Raw dps (single) |
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

Special fields (one row per weapon; a missing field is 0 or false):

| id | Special fields |
|---|---|
| `pistol` | none. Never leaves the roster: if both slots would be empty the Warden holds the pistol |
| `smg` | none |
| `scattergun` | `pellets` 8; pellets go to enemies inside the cone nearest first, at most 3 per enemy while other targets remain; `knockback_m` 0.8 on enemies with mass below 3 |
| `assault_rifle` | `pierce_falloff` 0.6 (the second enemy on the line within 2 m behind the first takes 60%) |
| `hornet_rack` | `salvo` 6; each missile picks a different target (top 6 of the priority order, repeats when fewer); `flight_s` 0.5; `splash_damage` 10 |
| `lmg` | `spin_up_s` 1.5 (rate ramps 4.0 to 10.0 over continuous fire, resets after 1.0 s idle); `stray_chance` 0.25 (the shot hits a random enemy within 1.5 m of the target, `aim` stream); `armor_shred` 0.5 per hit, at most 6 per enemy |
| `slag_mortar` | `flight_s` 0.7; targets the densest cluster in range (most enemies within `area`); edge damage 50%; `pool_s` 4, `pool_dps` 15, `pool_slow` 0.25, `pool_radius_m` 2.2 |
| `cutting_torch` | `ramp_per_hit` 0.5 up to 16 on one target (resets on target change); `armor_ignore` 1.0; `heat_per_hit` 3, `cool_per_s` 25, `heat_cap` 100 |
| `arc_projector` | `chains` 4, `chain_falloff` 0.75, `armor_ignore` 1.0, `ward_mult` 3.0, `stunned_mult` 1.5; `heat_per_shot` 14, `cool_per_s` 20, `heat_cap` 100 |
| `rail_lance` | `charge_s` 1.0 before each shot (the line is drawn while charging); `armor_ignore` 0.5; hits every enemy within 0.25 m of the line |

Weapon levels (a duplicate found in a crate raises the level, cap 3):

| Level | Damage | Perk at level 3 |
|---:|---:|---|
| 1 | x1.00 | - |
| 2 | x1.25 | - |
| 3 | x1.55 | pistol: every 6th shot is a guaranteed x3 hit; smg: magazine 45; scattergun: 12 pellets; assault_rifle: pierce 2; hornet_rack: salvo 8; lmg: no spin-up; slag_mortar: pool 6 s; cutting_torch: ramp cap 22; arc_projector: chains 6; rail_lance: magazine 4 |

Crate contents: pool = unlocked weapons (section 12). Tier weights by act; boss crates use the next act's row (act III boss
crates do not exist: the run ends).

| Act | T2 | T3 | T4 | T5 |
|---|---:|---:|---:|---:|
| I | 70 | 30 | 0 | 0 |
| II | 20 | 45 | 30 | 5 |
| III | 0 | 25 | 45 | 30 |

(Shipped as written since V5-A. The slice had the act I row at 0 / 0 / 0 / 100 so that its one crate held the arc projector;
with `u_w_arc` in the Archive a new profile's crates hold `smg`, `scattergun` and `assault_rifle`.)

Normal crate: 1 weapon. Boss crate: choose 1 of 2. 35% of a crate's rolls are forced to a weapon the Warden already carries
when that weapon is below level 3 (level-up chance). Scrapping a crate pays 80 / 140 / 200 Scrap by act.
Guaranteed crate: at the wave 2 clear if none was secured yet.

---

## 3. Directives (the upgrade cards; `data/directives.json`)

The player-facing word is **DIRECTIVE** (GDD 2.4 forbids "Cards"; decision D4). Columns: `cat` W weapon, T turret, C core,
A ability, E economy, X corrupted. `rar` C common, R rare, P prototype, X corrupted. `max` = stacks. `impl`: DATA = pure
stat operation on `ModState` (no new code per card), HOOK = needs the named sim hook. `pool`: base = available from the first
run, else the unlock pack that adds it (section 12).

### 3.1 Weapon directives

| id | rar | max | Effect per stack | Tags | Requires | impl | pool |
|---|---|---:|---|---|---|---|---|
| `hot_loads` | C | 5 | +20% Warden damage (the legacy `damage` level) | bullet | - | DATA `lvl_damage +1` | base |
| `cyclic_tuning` | C | 5 | +15% Warden fire rate (the legacy `fire_rate` level) | bullet | - | DATA `lvl_fire_rate +1` | base |
| `penetrator_cores` | C | 5 | Enemy armor -15% for all sources, cap 90% (the legacy `armor_piercing` level) | bullet, gunline | - | DATA `lvl_armor_piercing +1` | base |
| `extended_feed` | C | 3 | +30% magazine, +20% heat capacity | bullet | - | DATA `w_mag_mul +0.30`, `w_heat_cap_mul +0.20` | base |
| `fast_hands` | C | 3 | -20% reload and vent time; weapon swap time -0.15 s | tempo | - | DATA `w_reload_mul -0.20`, `swap_ticks -9` | base |
| `first_strike` | C | 3 | +50% damage to enemies at full HP | rail, blast | - | DATA `w_full_hp_mul +0.50` | base |
| `heavy_barrel` | C | 3 | +35% damage, -10% fire rate | rail | - | DATA `w_dmg_mul +0.35`, `w_rate_mul -0.10` | base |
| `executioner` | R | 2 | +60% damage to enemies below 30% HP (stack 2: below 40%) | bullet | - | DATA `w_low_hp_mul`, `w_low_hp_threshold` | base |
| `ricochet` | R | 2 | A Warden hitscan shot that kills continues to one more enemy within 3 m for 60% (stack 2: two more) | bullet | hitscan weapon carried | HOOK `on_warden_kill` | base |
| `incendiary_tips` | R | 3 | Warden hits ignite: 8 damage per second for 3 s (refreshes, does not stack per enemy) | blast, bullet | - | HOOK `on_warden_hit` (burn status) | base |
| `kill_chain` | R | 1 | Each Warden kill grants +4% fire rate for 2 s, up to +40% | bullet, tempo | - | HOOK `on_warden_kill` | base |
| `shock_rounds` | R | 3 | Every 6th Warden shot (5th, 4th) arcs to 2 enemies within 2.5 m for 50% | arc, bullet | - | HOOK `on_warden_shot` | `u_p_arc` |
| `overpressure` | P | 2 | Every blast, pool and arc chain caused by the player's side is 35% larger | blast, arc | - | DATA `area_mul +0.35` | `u_p_blast` |
| `twin_link` | P | 1 | The holstered weapon also fires, at 35% of its rate, with its own magazine | bullet, gunline | 2 weapons carried | HOOK off-hand fire | `u_p_proto` |

### 3.2 Turret directives

| id | rar | max | Effect per stack | Tags | Requires | impl | pool |
|---|---|---:|---|---|---|---|---|
| `turret_deploy` | C | 2 | Deploy a turret on the next free pad (the legacy `auto_turret`) | gunline | a free pad | DATA `turrets +1` | base |
| `turret_servos` | C | 4 | Turrets +25% fire rate | gunline | 1 turret | DATA `t_rate_mul +0.25` | base |
| `turret_heavy_slugs` | C | 4 | Turrets +30% damage | gunline | 1 turret | DATA `t_dmg_mul +0.30` | base |
| `overwatch` | R | 1 | Turrets target elites, spitters, reclaimers and jammers first and deal +40% to them | gunline | 1 turret | HOOK turret targeting class | `u_p_gunline` |
| `sentry_link` | R | 1 | Turrets gain half of the Warden's `hot_loads` and `cyclic_tuning` stacks (rounded down) | gunline, bullet | 1 turret | DATA `t_inherit 0.5` | `u_p_gunline` |
| `flak_heads` | R | 2 | Turret shots splash 1.2 m for 40% (stack 2: 60%) | gunline, blast | 1 turret | HOOK `on_turret_hit` | `u_p_gunline` |
| `arc_pylons` | R | 2 | Every 4th turret shot chains to 2 enemies within 2.5 m for 60% (stack 2: every 3rd) | gunline, arc | 1 turret | HOOK `on_turret_shot` | `u_p_arc` |
| `mine_layer` | R | 2 | Each turret drops a mine every 8 s (6 s) within 4 m toward the spawn edge, 3 per turret: 90 dmg, 2 m | gunline, blast | 1 turret | HOOK mines (`proc` stream) | `u_p_gunline` |
| `pad_capacitors` | P | 1 | Overdrive also doubles turret fire rate | gunline, tempo | 1 turret | DATA flag `od_turrets` | `u_p_gunline` |
| `last_stand_protocol` | P | 1 | While the core is below 35%, turrets +80% fire rate and the Warden reloads 50% faster | fortress, gunline | - | DATA conditional | `u_p_proto` |

### 3.3 Core directives

| id | rar | max | Effect per stack | Tags | Requires | impl | pool |
|---|---|---:|---|---|---|---|---|
| `reinforced_cage` | C | 3 | Core max +150 and repair 150 now | fortress | - | DATA `core_max_add +150` | base |
| `field_weld` | C | 3 | Repair 12% of core max now and 2% after every wave cleared | fortress | - | DATA `core_regen_wave +0.02` | base |
| `ground_wire` | R | 2 | Enemies attacking the core attack 25% slower | fortress | - | DATA `enemy_attack_period_mul +0.25` | base |
| `reactive_plating` | R | 3 | Every core hit deals 25 damage back to the attacker (armor ignored) | fortress | - | HOOK `on_core_hit` | `u_p_fortress` |
| `core_lash` | R | 3 | The core fires an amber bolt at the highest-priority attacker every 1.5 s (1.2, 0.9) for 40 | fortress | - | HOOK core weapon | `u_p_fortress` |
| `ember_vent` | R | 1 | Every 10th core hit taken triggers a free vent: 120 dmg, 5 m ring | fortress, blast | - | HOOK `on_core_hit` | `u_p_fortress` |
| `amber_surge` | P | 1 | The first time each wave the core drops below 50%, a free Shield starts (no cooldown change) | fortress, tempo | - | HOOK `on_core_changed` | base |
| `dead_mans_switch` | P | 1 | Once per run: a hit that would end the run leaves the core at 20% and deals 600 to every enemy within 8 m | fortress | - | HOOK defeat check | `u_p_fortress` |

### 3.4 Ability directives

| id | rar | max | Effect per stack | Tags | Requires | impl | pool |
|---|---|---:|---|---|---|---|---|
| `emp_capacitor` | C | 3 | EMP cooldown -15% | tempo, arc | - | DATA `emp_cd_mul -0.15` | base |
| `shield_lattice` | C | 3 | Shield absorbs +60 and lasts +2 s | fortress, tempo | - | DATA `shield_absorb_add`, `shield_dur_add` | base |
| `overdrive_coolant` | C | 3 | Overdrive lasts +2 s, cooldown -10% | tempo, bullet | - | DATA `od_dur_add`, `od_cd_mul` | base |
| `emp_tether` | R | 2 | EMP stun +1.5 s; stunned enemies take +25% damage | arc, tempo | - | DATA `emp_stun_add`, `stunned_dmg_mul` | `u_p_arc` |
| `emp_overload` | R | 2 | EMP deals 60 damage to every stunned enemy and breaks every ward | arc, blast | - | HOOK `on_emp` | `u_p_arc` |
| `aftershock` | R | 1 | Enemies killed while stunned blast: 1.5 m, 30 dmg | blast, arc | - | HOOK `on_enemy_killed` | `u_p_blast` |
| `shield_burst` | R | 1 | When the Shield ends or breaks: 150 dmg within 6 m of the core, knockback 1.5 m | fortress, blast | - | HOOK `on_shield_end` | `u_p_blast` |
| `deadfall_uplink` | R | 2 | +1 Deadfall Strike charge now and +1 more at each act start (cap 3 held) | blast | - | DATA `strike_per_act +1` | base |
| `signal_hijack` | R | 1 | Adds the FREIGHT call button: 1 charge per act (section 6) | blast | - | DATA `freight_per_act +1` | base |
| `bottomless` | P | 1 | During Overdrive the Warden uses no ammunition and builds no heat | tempo, bullet | - | DATA flag `od_free_ammo` | `u_p_proto` |
| `cascade` | P | 1 | Activating an ability takes 6 s off the other two cooldowns | tempo | - | HOOK `on_ability` | `u_p_proto` |

### 3.5 Economy directives

| id | rar | max | Effect per stack | Tags | Requires | impl | pool |
|---|---|---:|---|---|---|---|---|
| `scavenger_protocol` | C | 3 | +25% Scrap from kills | hoard | - | DATA `scrap_mul +0.25` | base |
| `requisition_line` | C | 2 | Rerolls cost 50% less; +1 free reroll now | hoard | - | DATA `reroll_cost_mul -0.5` | base |
| `black_box` | C | 2 | Crates offer +1 choice | - | - | DATA `crate_choices +1` | base |
| `salvage_drone` | R | 1 | Crates are secured 50% faster and are never lost | - | - | DATA `crate_time_mul`, flag | base |
| `compound_interest` | R | 1 | At each wave clear: +10% of banked Scrap, at most 150 | hoard | - | HOOK `on_wave_cleared` | `u_p_ledger` |
| `data_siphon` | R | 2 | +2 Recovered Data per wave cleared for the rest of the run | hoard | - | DATA `data_per_wave +2` | `u_p_ledger` |
| `quartermaster` | R | 1 | Drafts offer 4 directives instead of 3 | - | - | DATA `draft_slots +1` | `u_p_ledger` |
| `scrap_rounds` | P | 1 | Warden damage +1% per 40 banked Scrap, at most +60% | hoard, bullet | - | DATA dynamic | `u_p_ledger` |

### 3.6 Corrupted directives (risk with reward; red-framed, always clearly labelled)

| id | max | Gain | Price | Tags | impl | pool |
|---|---:|---|---|---|---|---|
| `glass_cannon` | 1 | Warden damage +80% | Core max -30% (current HP scaled) | bullet, rail | DATA | base |
| `open_gate` | 1 | Scrap from kills +60% | Spawn intervals x0.75 for the rest of the run | hoard | DATA | base |
| `overclocked_core` | 1 | All ability cooldowns -40% | Each activation costs 25 core HP (never the last 25) | tempo | HOOK `on_ability` | base |
| `chorus_handshake` | 1 | Every third elite killed drops a crate | +1 elite in every normal wave | - | HOOK plan patch | base |
| `unstable_munitions` | 1 | 20% of Warden kills blast: 2 m, 50 dmg | 5% of reloads jam: +1.5 s (`proc` stream) | blast | HOOK | `u_p_blast` |
| `borrowed_time` | 1 | 2 random prototype directives now | Core max -5% after every wave cleared | - | HOOK | `u_p_corrupted` |
| `static_pact` | 1 | During a Static Front the Warden fires at +100% rate | Static Fronts happen in every wave from now on | arc, tempo | HOOK plan patch | `u_p_corrupted` |
| `single_point` | 1 | Warden damage +60%, fire rate +30% | Turrets are removed and both pads are disabled for the run | bullet, rail | HOOK | `u_p_corrupted` |
| `the_tally` | 1 | +1% Warden damage per 10 kills this run, at most +100% | Half of the bonus is lost every time the core takes damage through an empty shield in a wave (at most once per 5 s) | bullet | HOOK | `u_p_corrupted` |

Totals: 14 weapon + 10 turret + 8 core + 11 ability + 8 economy + 9 corrupted = **60 directives**; 31 in the base pool, 29 in
unlock packs. 34 are DATA only (no new code per directive).

### 3.7 Draft rules (numbers)

| Rule | Value |
|---|---|
| Offer size | 3 (4 with `quartermaster`); no duplicate ids in one offer; maxed or requirement-failed directives have weight 0 |
| Rarity roll per slot | The act row of section 1.1 |
| Weight inside a rarity | 10 base; x2 when the build already holds 2 or more directives sharing a tag with it; x1.5 when it modifies a carried weapon kind; x0.5 when it was offered and not picked in the previous offer |
| Corrupted slot | With the act's chance, the last slot is replaced by one corrupted directive (at most one per offer) |
| Rare pity | After 3 consecutive offers with no rare or better, slot 1 of the next offer is rare or better |
| Turret pity | The draft after wave 2 always contains `turret_deploy` in slot 1 if no turret is deployed and none was offered |
| Skip | Take nothing: +60 Scrap |
| Reroll | Free charges first; else `60 + 40 * n` Scrap (n = paid rerolls so far this run). Redraws all slots |
| Buy-out | Keep a second directive from the same offer: `250 + 100 * n` Scrap (n = buy-outs so far this run) |
| Patch core | On the draft screen: repair 10% of core max for `180 + 90 * n` Scrap |

---

## 4. Enemies (`data/enemies.json` plus the four existing entries)

### 4.1 Stats

`class`: B bodied (pooled node, counts toward `enemy_cap` 50, takes an attack slot), M mini (instanced, counts toward
`swarm_cap` 40, no slot, burns out on the core), S standoff (bodied, holds a standoff point instead of a slot).
`cost` is the threat cost. HP and core damage are multiplied by the act tier of section 1.1. Scrap is per kill.

| id | class | HP | Speed m/s | Armor | Core dmg | Period s | Scrap | Radius m | cost | min act | type alive cap |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|
| `skitter` | B | 45 | 2.3 | 0 | 12 | 1.5 | 5 | 0.35 | 1.0 | I | 50 |
| `hollow_warden` | B | 150 | 1.1 | 8 | 30 | 2.0 | 15 | 0.55 | 3.0 | I | 24 |
| `rusher` | B | 65 | 3.6 | 2 | 28 | 1.2 | 8 | 0.40 | 1.5 | I | 32 |
| `mote` | M | 12 | 3.0 | 0 | 6 once (burnout) | - | 1 | 0.18 | 0.4 | I | 40 |
| `burster` | B | 70 | 1.9 | 0 | 70 once (detonates 1.2 s after reaching its slot) | - | 10 | 0.45 | 2.0 | I | 20 |
| `spitter` | S | 80 | 1.6 | 2 | 18 per bolt | 2.4 | 12 | 0.45 | 2.5 | I | 12 |
| `splitter` | B | 180 | 1.3 | 3 | 24 | 1.8 | 12 | 0.60 | 3.0 | II | 12 |
| `shard` | M | 22 | 3.2 | 0 | 8 once (burnout) | - | 2 | 0.22 | 0 (only from splitters) | II | shares the mini cap |
| `shieldbearer` | B | 220 | 1.0 | 6 | 26 | 2.0 | 25 | 0.60 | 5.0 | II | 6 |
| `reclaimer` | S | 160 | 1.2 | 4 | 0 | - | 30 | 0.55 | 5.0 | II | 4 |
| `jammer` | B | 140 | 1.5 | 2 | 20 | 2.0 | 22 | 0.50 | 4.0 | II | 6 |
| `borer` | B | 90 | 2.6 | 4 | 26 | 1.4 | 12 | 0.45 | 2.5 | II | 16 |
| `ward_pylon` | S | 300 | 0 (orbits its boss) | 0 | 0 | - | 0 | 0.40 | 0 (boss part) | II | 3 |

The Scrap values of the three old types drop (20 / 35 / 25 to 5 / 15 / 8; applied in the shipped `data/enemies.json` by V3-I) because a run now has about four times as many
kills. The legacy 5-wave fixture keeps the old values (VARIETY_SPEC 13.9).

### 4.2 Behaviour fields

| id | Behaviour fields |
|---|---|
| `mote` | `mini` true; flow field only (no separation, no slot, no stuck tracking); on reaching `core.radius + 0.6`: 6 core dmg (shield first) and dies with no Scrap |
| `shard` | as `mote`, 8 core dmg |
| `burster` | `death_blast_radius` 2.6, `death_blast_damage` 90 (enemies only), `death_blast_core` 35 if within 3 m of the core cage; `fuse_s` 1.2 at its slot then detonates for 70 core dmg and the same enemy blast; blasts resolve 6 ticks after the death (chain delay) |
| `spitter` | `standoff_m` 10.5 (24 standoff points on the slot arc); `bolt_flight_s` 0.8; counts as "attacking the core" for targeting once it has fired |
| `splitter` | `split_type` `shard`, `split_count` 3, spawned on a 0.6 m ring at its death position |
| `shieldbearer` | `ward_radius` 2.4; `ward_pool` 120, regenerates fully after 4 s without absorbing; every other enemy inside the radius takes x0.4 damage and the blocked damage drains the pool; pool at 0 = no protection until it regenerates. EMP empties the pool and blocks regeneration for the stun plus 4 s. `armor_ignore` weapons with `ward_mult` drain it x3 |
| `reclaimer` | `standoff_m` 12.5; tethers up to 3 damaged non-boss enemies within 6 m, 14 HP per second each (act tier applies); `priority_class` true |
| `jammer` | `aura_radius` 7.0: turrets whose pad is inside fire at 50% rate; while at least one jammer is alive ability cooldowns tick at 70%; on death, enemies within 3 m are stunned 1 s |
| `borer` | spawns at a breach point (region `breach`, section 6) 2.5 s after the breach telegraph; `direct_seek` true |
| `ward_pylon` | see `aegis_array` (section 5) |

### 4.3 Elite affixes (`elites` in `data/enemies.json`)

An elite is a bodied enemy with: HP x2.2, scale 1.25, Scrap x4, a red ground ring, a HUD ticker line on spawn. Never elite:
minis, bosses, `ward_pylon`, `burster` (its blast would be unfair), `reclaimer` before act III.

| id | Display | Effect | Counter |
|---|---|---|---|
| `aff_plated` | PLATED | +8 armor, HP x1.3 | piercing, torch, arc, rail |
| `aff_swift` | SWIFT | Speed +45% | slow pools, EMP, scattergun at the core |
| `aff_volatile` | VOLATILE | Death blast 3 m, 120 dmg to enemies; 50 core dmg if it dies within 3 m of the cage | kill it in the crowd, far from the core |
| `aff_regen` | REGENERATING | Heals 2% of max HP per second after 2 s without damage | sustained fire, burn |
| `aff_warded` | WARDED | A personal ward equal to 40% of max HP absorbs damage first; regenerates after 5 s | EMP strips it; arc x3 |
| `aff_magnetic` | MAGNETIC | Every shooter within 12 m must target it while it lives | burst it down; rail line through it |
| `aff_overclock` | OVERCLOCKER | Allies within 4 m: speed +30%, attack period -20% | priority kill; EMP |
| `aff_anchored` | ANCHORED | Immune to stun, slow and knockback | raw damage |
| `aff_leech` | LEECHING | Each of its core hits heals every enemy within 4 m by 30 | Shield (an absorbed hit heals nothing) |
| `aff_shroud` | SHROUDED | Cannot be targeted from more than 12 m; always visible, drawn flickering | turrets near it, area damage, strikes |

Combination rules: act I one affix; act II one, 40% two; act III two. Forbidden pairs: `aff_magnetic` + `aff_shroud`,
`aff_warded` + `aff_regen` (allowed only in act III), `aff_swift` + `aff_volatile` on a `rusher`. Affixes are rolled without
replacement from the `plan.elite:<wave>` stream. **`aff_shroud` is never rolled on a standoff enemy** (`spitter`, `reclaimer`;
V5-A, `PlanElites.SHROUD_AFFIX`): it parks about 14 m from the Warden, beyond the 12 m of the shroud, so a build with no
turret in reach, no area weapon and no strike could never kill it and its wave would never end.

---

## 5. Bosses (`bosses` in `data/enemies.json`)

All bosses: never pushed, EMP stun 1 s then 5 s immunity (existing rule), act tier does **not** multiply their HP (the HP
below is final), HUD bar with phase pips, a banner and a stinger. Escorts come from the boss wave budget of section 1.1.

| id | Act pool | Display | HP | Armor | Speed | Core attack | Slots |
|---|---|---|---:|---:|---:|---|---:|
| `brood_carrier` | I | NODE 3 // BROOD CARRIER | 2,400 | 6 | 0.70 | 60 per 2.5 s | 3 |
| `lance_platform` | I | NODE 5 // LANCE PLATFORM | 2,000 | 10 | 0.80 | beam only | 0 (plants at 14 m) |
| `aegis_array` | II | NODE 6 // AEGIS ARRAY | 4,200 | 8 | 0.60 | 75 per 2.5 s | 3 |
| `tremor_rig` | II | NODE 7 // TREMOR RIG | 5,000 | 10 | 0.55 | 80 per 2.5 s | 3 |
| `siege_hulk` | III (always) | NODE 9 // SIEGE HULK | 9,000 | 12 | 0.65 | 90 per 2.5 s | 3 |

| id | Behaviour (first pass) | Telegraph | Counterplay |
|---|---|---|---|
| `brood_carrier` | Every 6 s opens its hatches and releases 6 motes. At 50% HP it "molts": armor 0, release every 3 s | Hatches glow 1 s before each release | Area and chain weapons; a stun resets the hatch timer; the molt phase is a damage window |
| `lance_platform` | Walks to 14 m from the core and plants. Cycle 9 s: 3 s charge then a beam for 160 core dmg. Takes +50% damage while charging (vents open) | Red line from the boss to the core and a rising tone for the 3 s charge | EMP during the charge cancels the shot and stuns 2 s (then 5 s immune); Shield absorbs part; burst it during the charge |
| `aegis_array` | Deploys 3 `ward_pylon`s that orbit it at 2.2 m. While a pylon lives the boss takes x0.2 damage. When all are down it is exposed for 10 s, then redeploys 3, then 2, then 1 | Pylon ring is drawn; exposed state flashes the boss bar cyan | Pylons are priority targets; EMP drops all pylon protection for 3 s; rail and strikes hit pylons and boss together |
| `tremor_rig` | Every 10 s stomps: turrets offline 4 s and the Warden's magazine is emptied. At 66% and 33% HP opens 2 breach points with 3 borers each | Expanding red ring for 1.5 s before each stomp; breach cracks 2.5 s | An active Shield at the stomp negates it for turrets and Warden; heat weapons ignore the magazine dump |
| `siege_hulk` | Canon final boss. One of three variants per run (below). All variants: below 25% HP its attack period is -30% | Variant shown on the boss briefing | Variant-specific |

Node 9 variants (`plan.boss` stream, one per run):

| id | Display | Behaviour |
|---|---|---|
| `hulk_plated` | NODE 9 // PLATED | Armor 24. Sheds plating at 66% and 33% HP: armor 24 to 12 to 4, speed +25% each time |
| `hulk_fed` | NODE 9 // FED | Two reclaimers escort it and are re-sent every 20 s if dead; it heals 1% of max HP per second while a reclaimer lives |
| `hulk_overclocked` | NODE 9 // OVERCLOCKED | Every 12 s: 1.5 s wind-up, then a 3 s charge at 3x speed. EMP during the charge stops it and stuns 2 s |

Boss wave escorts: `brood_carrier` skitter 0.6 / mote 0.4; `lance_platform` hollow_warden 0.5 / rusher 0.5; `aegis_array`
shieldbearer 0.3 / skitter 0.7; `tremor_rig` rusher 0.5 / burster 0.5; `siege_hulk` `pack_everything`.

---

## 6. Chaos events and hazards (`data/events.json`)

`who`: P player-triggered (a HUD button), W world-triggered (rolled into the plan). `warn_s` is the telegraph before the
effect. Damage numbers ignore armor unless noted. No event damages the core, the Warden or a turret directly.

| id | who | Display | warn_s | Effect | Weight (act I / II / III) | Boss-safe |
|---|---|---|---:|---|---|---|
| `deadfall_strike` | P | DEADFALL STRIKE | 2.0 | 450 dmg within 4 m (50% at the edge; bosses take half) on the densest cluster at the moment of the call. Charges: 1 at run start, +1 at each act start, cap 3 | - | - |
| `core_vent` | P | CORE VENT | 0.5 | Costs 8% of core max (blocked at 10% or less). 220 dmg within 6 m of the core, knockback 2 m, attackers' attack timers reset. Once per wave | - | - |
| `freight_call` | P | FREIGHT | 4.0 | Calls `runaway_freight` on the rail line with more enemies. 1 charge per act, needs `signal_hijack` | - | - |
| `accord_window` | W | RELAY WINDOW | 0 | 10 s: Scrap from kills x2 | 30 / 15 / 10 | yes |
| `supply_drop` | W | ACCORD DROP | 3.0 | A crate lands on one of 4 drop points. Secure it: 12 s with no enemy within 2 m. Lost after 40 s. The 3 nearest skitters or rushers divert to stand on it | 30 / 20 / 15 | yes |
| `power_surge` | W | CORE SURGE | 4.0 | 10 s: turrets fire x2, Warden reload and vent are instant. Then a 5 s brownout: turrets offline. A Shield activated during the surge cancels the brownout | 20 / 15 / 15 | yes |
| `runaway_freight` | W | RUNAWAY FREIGHT | 4.0 | A freight car crosses the yard on rail line A (z = -7.0) or B (z = 10.5) in 1.2 s: 700 dmg to every enemy within 1.3 m of the line (bosses 350), knockback 1.5 m | 10 / 15 / 15 | yes |
| `static_front` | W | STATIC FRONT | 6.0 | 12 s: EMP, Shield and Overdrive cannot be activated (cooldowns frozen, active effects continue). Enemy wards, shieldbearer pools and jammer auras are also down; motes are stunned 2 s when it starts | 10 / 15 / 20 | no |
| `floor_breach` | W | FLOOR BREACH | 2.5 | 2 (act II) or 3 (act III) breach points open at x 2 to 8; each sends `1 + act` borers | 0 / 15 / 15 | no |
| `recount` | W | RECOUNT | 3.0 | The next 12 scheduled spawns enter together from the other edge | 0 / 5 / 10 | no |

Hazard (placed, not timed):

| id | Display | Rule |
|---|---|---|
| `fuel_drums` | FUEL DRUMS | At each act start 3 drums are placed on 3 of 6 fixed points (`plan.hazard:<act>` stream). A drum ignites when any blast, pool, strike or freight touches it, or after 80 stray LMG / pellet damage: 3 m blast, 150 dmg to enemies, then a 5 s slag pool. Drums do not block movement or shots |

Schedule rules: event times are drawn uniformly in 25% to 70% of `window_s`; the same world event never appears in two
consecutive waves; `static_front` and `power_surge` never overlap; at most one harmful event (`static_front`, `floor_breach`,
`recount`) per wave in acts I and II; wave 3's event is always helpful (`accord_window`, `supply_drop` or `power_surge`).
Mercy rule (published in the help text): a harmful event whose warning would start while the core is below 15% is cancelled.

---

## 7. Salvage

### 7.1 Sources of crates

| Source | When |
|---|---|
| Guaranteed | Wave 2 clear, if none secured yet (so every run has a second weapon by wave 3) |
| Route reward `rw_crate` | Drops at 40% of the wave's window |
| `supply_drop` event | See section 6 |
| Boss kill (acts I and II) | Boss crate: choose 1 of 2, tier row of the next act |
| `chorus_handshake` | Every third elite killed |

### 7.2 Crate on the field

| Field | Value |
|---|---|
| Drop points | 4 fixed points: (2.0, -3.0), (5.5, 3.5), (1.0, 4.5), (6.0, -8.0) |
| Secure time | 12 s of uncontested time (no living bodied enemy within 2.0 m); progress pauses while contested |
| Lifetime | 40 s after landing, then lost (`crate lost` ticker line); `salvage_drone` removes the lifetime |
| Banked crates | Opened at the next intermission, before the draft. At most 2 banked; a third is converted to Scrap |

---

## 8. Turret types (stretch; `turrets` in `data/weapons.json`)

| id | Unlock | damage | rate /s | range m | Special |
|---|---|---:|---:|---:|---|
| `turret_gun` | base | 12 | 3.0 | 17 | The existing turret |
| `turret_arc` | `u_f_turret_arc` | 16 | 1.2 | 12 | Chains to 2 enemies within 2.5 m at 70%; ignores armor |
| `turret_mortar` | `u_f_turret_mortar` | 45 | 0.4 | 8 to 22 | 2.0 m blast, 0.8 s flight, targets the densest cluster |

With a type unlocked, `turret_deploy` asks which type to place (one extra tap on the draft screen).

---

## 9. Abilities (unchanged numbers)

| id | Effect | Duration | Cooldown |
|---|---|---|---|
| `emp` | Stun all (3 s, boss 1 s) | - | 35 s |
| `shield` | Absorb 100 core damage | 8 s | 50 s |
| `overdrive` | Warden fire rate x2 | 6 s | 60 s |

---

## 10. Recovered Data rewards (`reward` in `data/run.json`)

| Source | Data |
|---|---:|
| Each wave cleared | 6 |
| Act I boss killed | 30 |
| Act II boss killed | 45 |
| Victory (Node 9 killed) | 100 + `floori(50 * core_hp / core_max_hp)` |
| Route reward `rw_data` (wave cleared) | 15 each |
| `data_siphon` | 2 per stack per wave cleared after it was taken |
| Abandoned run (quit to menu) | 0 |
| Run that cannot be resumed (version or content changed) | Paid as a defeat at the last saved wave |

Typical: defeat in wave 4: 18. Defeat in wave 8: 72. Victory at 60% core: 90 + 75 + 130 = 295.

Milestones (once per profile, `claimed` list):

| id | Condition | Data |
|---|---|---:|
| `ms_first_boss_<boss id>` (5) | First kill of that boss | 50 |
| `ms_first_victory` | First victory | 200 |
| `ms_victory_kit_<kit id>` (6) | First victory with that kit | 75 |
| `ms_three_builds` | Victories with 3 different primary weapons | 150 |

---

## 11. Kits (starting loadouts; `kits` in `data/unlocks.json`)

| id | Display | Cost | Start |
|---|---|---:|---|
| `k_standard` | STANDARD ISSUE | 0 | Pistol |
| `k_breacher` | BREACHER | 150 | Scattergun and pistol, 1 turret deployed, core max -15% |
| `k_signal` | SIGNAL | 150 | Pistol, +1 Deadfall charge, EMP cooldown -20%, no turret pity |
| `k_gunline` | GUNLINE | 250 | Pistol, 2 turrets deployed, Warden damage -25% |
| `k_ledger` | LEDGER | 250 | Pistol, 400 Scrap, 2 free rerolls, core max -10% |
| `k_gambler` | LONG ODDS | 350 | Pistol, 1 random corrupted and 1 random prototype directive (`kit` stream) |

---

## 12. Archive unlocks (`data/unlocks.json`)

Base content with no unlock: weapons `pistol`, `smg`, `scattergun`, `assault_rifle`; the 31 base directives; `k_standard`;
every enemy, boss, event and modifier (threats are never locked behind Data).

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
| `k_breacher`, `k_signal` | KITS | 1 | 150 each | See section 11 |
| `k_gunline`, `k_ledger` | KITS | 2 | 250 each | |
| `k_gambler` | KITS | 3 | 350 | |
| `u_f_reroll` | FIELD | 1 | 120 | Every run starts with 1 free reroll |
| `u_f_boss_intel` | FIELD | 1 | 150 | The act's boss is shown at the act start instead of at its briefing |
| `u_f_preview` | FIELD | 2 | 200 | The route screen also shows the packs of the wave after next |
| `u_f_turret_arc` | FIELD | 2 | 300 | Turret type `turret_arc` (stretch) |
| `u_f_turret_mortar` | FIELD | 3 | 300 | Turret type `turret_mortar` (stretch) |
| `u_f_third_sling` | FIELD | 3 | 500 | A third weapon slot |

Tier gates: tier 2 opens after 3 unlocks of any kind, tier 3 after 8. Total cost 5,250 Data (4,650 without the stretch
turret types). At about 150 to 250 Data per run this is 20 to 30 runs for everything, with the first unlock after run 1 or 2.
The Daily Run is not an unlock: it appears on the menu after the first act I boss kill.

---

## 13. Bot policies (parameters for `PolicyBot`)

| id | Draft | Route | Salvage and weapons | Abilities and calls |
|---|---|---|---|---|
| `none` | always SKIP | option A | scraps every crate | never |
| `greedy` | lowest rarity, ties leftmost (the old "cheapest first" habit); never rerolls | option A | takes every crate into the emptiest slot (a duplicate is levelled up; a duplicate at the top level passes to the next weapon of the crate, and a crate of nothing else is scrapped: V5-A); never swaps | EMP at 12 attackers, Shield when hit, Overdrive when a boss is in range (as today) |
| `random` | uniform slot from its own RNG (`hash(seed, "bot")`, never a sim stream) | uniform | uniform | each ready ability with 2% chance per second |
| `hoarder` | weapon directives first; rerolls when no weapon directive is offered and Scrap is 200 or more | the option with `rw_crate`, else hot | keeps the two highest tiers; swaps to the higher tier when its magazine is ready | as `greedy` |
| `spammer` | ability directives first | option A | as `greedy` | every ability the tick it is ready; Deadfall and Vent the tick they are legal |
| `turret_rush` | turret directives first, then core | standard option | as `greedy` | as `greedy` |
| `balanced` | scores each directive: +3 shares a tag with 2 or more held, +2 fills a gap (no area source by wave 4, no armor answer by wave 6, no turret by wave 3, core below 60% and a core directive offered), +1 per rarity step, -4 corrupted while core below 50%; rerolls below score 2 with 150 Scrap or more (at most 3 times a draft); patches the core once a draft below 60% when 150 Scrap stay after paying | hot when core is at or above 70% and the hot reward is crate, double pick or rare draft; else standard | best tier per role (one area or chain weapon, one single-target weapon), a duplicate levels up, else scrap; swaps to the area weapon at 12 or more enemies **within the reach of that weapon around the Warden (never less than 10 m)**, back at 5; bridges a reload or vent of 1 s or more with the other slot | EMP at 10 attackers or to interrupt a telegraphed boss attack; Shield on the hit that crosses 60% or before a lance beam, **and against a boss that stands at the cage while the core is below 95%**; Overdrive on a boss in range or 20 or more alive; Deadfall on a cluster of 10 or more within 4 m or on an elite pair; Vent at 12 attackers and core above 40% |
| `risk` | takes every corrupted directive offered, else as `balanced` | always hot | as `balanced` | as `balanced` |

As built (V4-T): the `balanced` row above is what `PolicyScoring`, `PolicyLoadout` and `PolicyAbilities` do. The two bold
clauses are the changes the first measurements forced: a bot that counted only the enemies within 10 m of the **core** met 12
of them in about 3% of the combat ticks, so its second weapon never left the holster; and a boss at the cage is answered with
EMP and Shield. On the 5-wave slice this bot won 19 of 20 seeds. On the 15-wave game with the first-pass numbers (V5-A) it
wins 11 of seeds 1 to 20 (`sim_run`) and 16 of 30 in the base scorecard (WARN, 6 pass, 13 warn, 0 fail); V5-C tunes the data,
not the bot, until the scorecard passes.
