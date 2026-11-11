# Game design document — vertical slice
## Pitch
After the breach of the Cinder perimeter, a separate Warden is the last operational defender of **Relay Core B-4**. CHORUS-controlled humanoid machines flood a ruined industrial yard. Player acts as a combat-systems commander while the Warden fights autonomously.

## Mission loop
Menu → briefing → deploy → 5 escalating waves with 8-second intermissions → victory/defeat → award Recovered Data → replay. No network. Core begins at 1,000 integrity. Core zero = defeat; all fifth-wave hostiles including boss eliminated = victory. Run duration target 4.5–6 min (validate).

## Spatial composition
Portrait game viewport. High orthographic/isometric camera angled 55–65° down from horizontal. World convention: X axis is attack direction (right +X to left -X); Y vertical; Z lateral depth. Relay/core left of Warden; Warden fixed near left edge, always visible. Spawns from broad right and upper-right edge arcs; enemies advance through a continuous 3D ground plane. Camera framing must preserve clear sight of full combat zone and UI safe areas on common Android aspect ratios. Optional user zoom-out is **post-slice**, not a blocking requirement.

## Player agency
No joystick, manual aim, manual shoot, or target tapping. Player spends Scrap on damage, fire rate, armor piercing, one-time SMG, and up to 2 turrets. EMP stuns, shield absorbs core damage, overdrive increases Warden fire rate. Strong audiovisual feedback for purchases, hits, kills and core danger. Upgrade overlay warns 'COMBAT CONTINUES' during active wave.

## Enemy behavior
Skitter = weak swarm, Hollow Warden = armored, Rusher = rapid breach threat, Siege Hulk = large wave-five boss. Enemy arrival does not delete it: attack core periodically until destroyed. Preserve enemy health/death exactly once. Avoid swarm blobs: seeded spawn spread, low-cost separation, minimal physics collisions, fixed update loops. 50 enemies should be individually legible at mobile scale through silhouette and red optics, not all require health bars.

## Wave arc
W1 tutorial and first purchase; W2 unlock SMG; W3 armored enemies; W4 Rusher swarm and turret/EMP pressure; W5 Siege Hulk + escorts with 50-entity peak. Spawns are data-driven and capped. During intermission player can upgrade safely and skip remaining preparation timer. If current DPS kills enemies faster than peak goals, tune group spawn interval and total counts, not arbitrary invulnerability.

## Future roadmap (explicitly out of slice)
Multiple maps, additional weapon tiers, permanent weapon unlock tree, more CHORUS classes, zoom control, story cinematics, boss phases, online features, monetization.
