# W3-C Warden look-dev spike

Question from the owner: the Warden is "very block based" and "reminds me of very early video game graphics"; modernize it
and keep the design language. Decision (binding): characters get a stylised-but-detailed hard-surface treatment (bevelled
and rounded forms, baked ambient shadowing in the creases, rim light, glowing accents, a little surface detail, secondary
motion), not cel shaded, not outlined, not cartoon. Everything is procedural (code and one project shader), no third-party
asset, no concept PNG used as texture or sprite. The renderer stays Mobile (Vulkan). The shipped default is still `CURRENT`:
nothing in the game changes until the owner picks a look.

## The three looks

| Look | What it is |
|---|---|
| `CURRENT` | Today's boxes and prisms and flat palette materials. Byte-identical geometry (pinned by hash in `look_dev_meshes_test.gd`). |
| `STYLISED` | New hard-surface Warden (1,867 triangles with the pistol, 1,927 with the SMG; 9 parts, at most 3 surfaces per mesh): chamfered armour plates, tapered limbs, layered pauldrons, helmet with visor, backpack with exhausts and power bars, antenna, cable, detailed pistol and SMG. Baked ambient occlusion, tint and edge wear in the vertex colours. On MID and HIGH a custom shader adds a soft lighting ramp with a cool shadow side, a cyan fresnel rim, edge wear and brighter emissive accents. Springs, breathing and a reload pose. |
| `STYLISED_PLUS` | `STYLISED` plus the A-lite touches: a generated 128 px detail texture (panel seams, rivets, scratches, grime; read in mesh space, one fetch), stronger rim and specular, HDR accents with bloom on the `WorldEnvironment`, and a pooled muzzle light (HIGH only). |

Tier gates (`LookDevStyle`, asserted in `look_dev_style_test.gd` and `look_dev_view_test.gd`):

| Feature | CURRENT | STYLISED LOW | STYLISED MID/HIGH | PLUS LOW | PLUS MID | PLUS HIGH |
|---|---|---|---|---|---|---|
| New geometry, vertex colours (AO, tint) | no | yes | yes | yes | yes | yes |
| Custom shader: ramp, rim, edge wear | no | no (StandardMaterial3D with vertex colour) | yes | no | yes | yes |
| Detail texture | no | no | no | no | yes | yes |
| HDR accent energy | 1.0 | 1.0 | 1.5 | 1.0 | 2.2 | 2.2 |
| Bloom (WorldEnvironment glow) | no | no | no | no | yes | yes |
| Muzzle light | no | no | no | no | no | yes |
| Springs, breathing, reload pose | no | yes | yes | yes | yes | yes (CPU only, a few node transforms) |

## How to run it

```
# live (F8 cycles the look, F5 the tier, F9 the camera, F7 the perf overlay)
Godot --path <project> res://src/debug/look_dev_sandbox.tscn -- --look=stylised_plus --quality=2 --scenario=hold50
# captures with the wrapper (flags travel inside -Scene)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\capture.ps1 -Scene "res://src/debug/look_dev_sandbox.tscn --look=stylised --zoom=3" -Out C:/.../x.png -Size 1080x2400 -Frames 240
```

Flags of the sandbox: `--look=current|stylised|stylised_plus`, `--quality=0|1|2`, `--zoom=<f>` (top-down close-up at the game
camera's pitch), `--view=game|close|front|side|back|three` (the last four are low perspective cameras that follow the Warden's
facing), `--solo` (hides enemies, props and the reactor so a low camera has a clean background), `--reload-pose`,
`--scenario=hold10|hold28|hold50|boss`, `--debug-perf --measure=<s>`, `--render-size=1080x1920`, `--glow=0|1`,
`--tune=name:value,...` (shader parameter overrides used to tune the look). `view_sandbox.tscn` also honours `--look`. The shipped
game does not read it yet (see "needs owner"). `src/debug/look_dev_compare.gd` builds the comparison sheets (Image API, headless):
`Godot --headless --script res://src/debug/look_dev_compare.gd -- --out=x.png --crop=x,y,w,h --scale=3 --img=LABEL|a.png --img=LABEL|b.png`.

## Kit additions (additions only; no existing signature changed)

- `MeshBuilder`: per-vertex colours (`tint`, `use_colors`; rgb = tint x baked AO, alpha = edge wear), `add_tri`, `begin_part` and
  `add_occluder`, `recentre`, `surface_of`. Meshes that never ask for colours are unchanged.
- `LookDevShapes`: `bevel_box` (44 or 36 triangles, taper, normals rolled across the chamfer), `limb` (smooth tapered tube, flat or
  rounded ends), `ellipsoid` (full or upper half: pauldron, helmet), `curved_plate` (visor, chest plate), `frame_along`, `facing`.
- `LookDevBake`: `ao` (analytic ambient occlusion from occluder spheres of the other shapes, plus a sky term and a ground contact term;
  deterministic) and `gradient_y`. No extra draw call, no per-frame cost.
- `LookDevMat` and `look_dev_actor.gdshader`: shared materials per role, look and tier class; Mobile-safe (opaque, no screen or depth
  texture, no discard). `LookDevTex`: the deterministic detail texture. `LookDevStyle`: the look switch and every gate.
- `ArenaView.set_look` (bloom only), `ActorLayer.set_look` and `set_quality` forwarding, `WardenView`, `WardenParts` (one MeshInstance3D
  per part, look swap on the same nodes), `WardenMotion` (springs, no per-frame allocation).

Budget: `ActorMeshes.TRI_BUDGET[&"warden"]` is 2000 (was 700) and counts every body part plus the weapon in hand. All other budgets are unchanged.

## Measurements (desktop integrated GPU, NOT phone numbers)

Machine: Intel Iris Plus Graphics (Vulkan 1.3, Forward Mobile renderer), Windows 11, 1920x1080 display. Scene: `look_dev_sandbox`,
puppet `hold50` (50 enemies alive, the real arena, the real game camera, no HUD), rendered in a 1080x1920 SubViewport (a desktop window
cannot be taller than the screen, so the sandbox renders into a SubViewport of the phone size inside a 540x960 window),
`--disable-vsync`, `Engine.max_fps = 0`. Each run is the average `frame_ms` of four 5-second `[PERF]` windows (about 20 s) after a
discarded warm-up window; `measure.ps1` runs them one Godot process at a time on an otherwise idle machine. Every cell is the mean of
the runs made (the runs are in brackets; all in `measurements.csv`). Run-to-run noise: the same configuration varied by up to 0.2 ms
between runs (CURRENT on HIGH: 12.35, 12.38, 12.55), so a delta below about 0.2 ms is not a difference. Absolute times are lower than the
real game's because this scene has no canvas HUD; read the deltas.

| Tier | CURRENT | STYLISED | delta | STYLISED_PLUS | delta | PLUS with bloom forced off | delta |
|---|---|---|---|---|---|---|---|
| LOW (0.75 render scale) | 4.90 (4.87, 4.93) | 4.93 (4.88, 4.97) | +0.03 | 4.84 (4.89, 4.79) | -0.06 (noise) | same as PLUS (bloom is gated off) | |
| MID | 9.69 (9.57, 9.69, 9.82) | 9.79 (9.87, 9.79, 9.72) | +0.10 | 10.31 (10.29, 10.28, 10.36) | +0.62 | 9.83 (one run) | +0.14 |
| HIGH | 12.43 (12.35, 12.38, 12.55) | 12.35 (12.32, 12.24, 12.49) | -0.08 (noise) | 13.00 (13.07, 13.07, 12.84) | +0.57 | 12.62 (one run) | +0.19 |

Draw calls and primitives per frame (3D only here): LOW and MID 92 draws and 26.6k primitives with CURRENT, 97 draws and 28.2k with the
new looks; HIGH 98 draws and 38.6k with CURRENT, 103 draws and 40.1k with the new looks. The Warden goes from 4 to 9 mesh instances
(+5 draws, all tiers, both new looks) and from 312 to about 1,900 triangles (+1.5k primitives). The detail texture is 128 x 128 RGBA8 with
mipmaps (about 85 KB).

Cost of glow/bloom, measured separately (three mip levels, additive, HDR threshold 1.0; these isolation runs were made one revision of the
colour tuning earlier, which changed ALU only):

| Tier | bloom forced on in the CURRENT scene | PLUS with bloom minus PLUS without |
|---|---|---|
| LOW | +0.30 ms (5.20 vs 4.90) | +0.46 ms (5.30 vs 4.84), which is why it is gated off on LOW |
| MID | +0.44 ms (10.13 vs 9.69) | +0.48 ms (10.31 vs 9.83) |
| HIGH | +0.15 ms (12.58 vs 12.43) | +0.38 ms (13.00 vs 12.62) |

Reading: on this iGPU STYLISED costs nothing measurable on any tier (the extra draws and triangles are below the noise); the A-lite touches
other than bloom (detail texture, stronger spec and rim, HDR accents, muzzle light) cost 0.1 to 0.2 ms; bloom costs about 0.4 to 0.5 ms
(under 5 percent of a 60 fps frame). That is acceptable here, so `LookDevStyle.GLOW_MIN_TIER` is MID, but bloom is the one effect whose
cost on a tile-based phone GPU can be far larger than on an iGPU (the scene must be resolved to a texture and filtered in several
passes), so it has to be re-measured on a phone before it ships. Making it HIGH-only is a one-line change of that constant.
One-time build cost (not per frame): the first switch to a hard-surface look builds the meshes, bakes the ambient occlusion and builds the
materials in about 75 ms; STYLISED_PLUS adds about 170 ms for the generated texture (GDScript). Both belong in the boot warm-up if a
hard-surface look ships.

## Images

All captures went through `tools/capture.ps1` (`CAPTURE OK`, `renderer=mobile/vulkan`, Intel Iris Plus), scenario `hold28` (28 enemies),
HIGH tier unless stated, the same simulation frame (240 frames = 4 s) for every look, so the three looks differ only in the Warden and
the bloom. The individual captures are JPEG (quality 0.88) to keep this folder small; every capture was opened and looked at.

| File | What it shows |
|---|---|
| `compare_1_game_camera_1x.png` | The real game camera, 1080x2400, a 700x900 crop at 1x pixels, three looks. The Warden is about 55 px wide. |
| `compare_1b_game_camera_warden_x3.png` | The same frames, the Warden region (260x200) enlarged 3x with nearest neighbour, to see what the 1x pixels contain. |
| `compare_2_closeup_3x.png` | The game camera zoomed 3x on the Warden while it fires (`--zoom=3`, 1080x2400, cropped). |
| `compare_3a_front.png`, `compare_3b_side.png`, `compare_3c_three_quarter.png` | The Warden alone (`--solo`, low perspective camera at 0, 90 and 38 degrees from its facing). |
| `compare_4_reload_pose.png` | The held reload pose from the side (`--reload-pose`): CURRENT only dips the weapon. |
| `compare_5_tiers_stylised_plus.png` | STYLISED_PLUS at LOW, MID and HIGH at 3x. |
| `game_*.jpg`, `close3x_*.jpg` (1080x2400), `front_*.jpg`, `side_*.jpg` (900x1000) | The individual captures behind the sheets, one per look. |

What the images show:

- **Real game camera (compare_1, 1b).** At 1x the Warden is a figure of about 55 x 55 pixels and the three frames look almost the same at a
  glance, because the arena and the swarm dominate. Looking at the figure: CURRENT is an "H" of cyan-white blocks; STYLISED reads as an armoured
  trooper (round helmet with a dark crest, two layered pauldrons with cyan light bars, dark suit between warm bone plates, a pack with two cyan bars
  seen from behind, boots); STYLISED_PLUS has the same figure plus bloom: the muzzle flash and the cyan lights glow, and the whole frame is
  slightly brighter because bloom also touches the core, the tracers and the enemy plates. The improvement at 1x is real but modest.
- **3x close-up (compare_2).** CURRENT: a stack of boxes with a flat cyan roof. STYLISED: helmet, shoulders, pack and boots are clearly separate
  shapes with light and dark values. PLUS: the same with a glowing muzzle flash and warmer highlights.
- **Front, side and three-quarter (compare_3).** This is where the gain is large. CURRENT is brown and black cubes with a flat cyan belt.
  STYLISED is a bone-armoured soldier with a cyan visor slit, layered pauldrons, a power pack with exhausts and an antenna, knee and shin
  guards, a detailed SMG, and soft baked darkening in the creases. PLUS adds visible panel seams and rivets (detail texture), a warm
  muzzle light on the chest and arm, and a bloom halo on the helmet highlight and the muzzle.
- **Reload pose (compare_4).** The weapon drops to the hip, pitches down and rolls, the support arm reaches for the magazine; CURRENT only
  tilts the same boxes.
- **Tiers (compare_5).** LOW keeps the new geometry and the baked vertex colours only: a warm bone and dark figure with cyan accents, no
  rim, no bloom. MID and HIGH add the ramp, rim, brighter accents and bloom; HIGH adds the muzzle light (not visible in this frame).

## Assessment (honest)

- **Is it clearly more modern than CURRENT?** Zoomed in or seen alone: yes, clearly. At the real game camera: only modestly, because the Warden
  is about 55 px wide and about 1,900 triangles of detail mostly fall below pixel size. What carries at 1x is the silhouette (helmet, layered
  shoulders, pack, antenna), the value structure (dark suit, light plates) and the cyan accents; in PLUS the bloom is the one thing that changes
  the feel of the whole frame. If the owner wants a clear change at the real camera, the levers are outside this task: a larger on-screen
  Warden (camera or scale), a stronger accent glow, and a modernised environment around it.
- **It is stylised, not photoreal.** The armour is bevelled boxes and ellipsoids; it reads as a good low-poly hard-surface soldier, not as
  the concept art's weathered, heavily detailed trooper. Fully authored models remain the route to that.
- **Recommendation.** Adopt `STYLISED` as the baseline for the Warden: it costs nothing measurable on this GPU (+0.03 ms LOW, +0.1 MID,
  within noise on HIGH), needs no change to the ARCH 8 lighting rules, degrades gracefully (LOW keeps geometry and baked shading), and is the
  look that fixes "blocky". Take the A-lite touches from `STYLISED_PLUS` as separate switches: the detail texture, the muzzle light and the
  stronger rim are cheap and look good up close; bloom is the expensive and global one (it also brightens the core, the tracers and the enemy
  plates, and ARCH 8 currently says "no glow"), so decide it only after a phone measurement. If bloom is wanted, ship it HIGH-only first.

## Known defects

- Not photoreal: flat-shaded bevel boxes, a 60-triangle ellipsoid helmet that reads as a faceted ball, thin rigid arms (the support arm
  rotates rigidly toward the weapon, so its forearm does not bend and the hand can miss the magazine by a few centimeters in the reload pose).
- The visor and chest face away from the game camera (the Warden faces the swarm), so the strongest-looking parts are seen only in the solo views.
- Bloom is global: in STYLISED_PLUS the core, tracers, enemy plates and VFX bloom as well. That is a change of the whole scene look, not of
  the Warden only.
- The first use of a hard-surface look builds meshes and textures in 75 to 250 ms and compiles new shader pipelines on the first draw;
  `ShaderWarmup` does not cover the new materials yet.
- `STYLISED_PLUS` on HIGH has a fifth omni light while the muzzle flashes (the arena has four) (the Mobile renderer allows 8 per object); it is hidden otherwise.
- Physical-device and Android-emulator checks: NOT RUN (the emulator cannot present Vulkan frames; the owner resolves that before Wave 4).

## Needs owner

- Pick a look. Until then `LookDevStyle.current()` is `CURRENT`.
- `src/core/main.gd` / `Game` (frozen): to ship a hard-surface look the boot must call `LookDevStyle.set_current(...)` before
  `BattleView.setup`, or the settings system must offer it; the `--look` flag is read only by the two sandboxes.
- ARCH 8 and WORK_PLAN 6 (docs, not mine): the Warden budget is now 2000 triangles for all parts plus the weapon in hand, and "WorldEnvironment:
  no glow" conflicts with STYLISED_PLUS (default CURRENT is unaffected).
- Warm-up: extend `ShaderWarmup`/Game boot so the hard-surface materials and meshes are built and drawn once before the first battle.
- Rollout, if STYLISED is chosen: the turret (300 triangle budget), the four enemy archetypes (108 pooled MeshInstance3D: the custom shader's
  fill cost and the per-actor AO bake must be measured at 50 enemies before it goes beyond the single Warden), the Hulk (900), `ActorContrast`
  (high contrast needs variants of the new materials), and the environment later (the same kit bakes vertex AO into props). Hit flash
  (`material_override`) already works over the shader materials.
- Phone measurement of bloom and of the custom shader (Adreno, Mali, PowerVR), thermals, and a 50-enemy run with the Warden in the new look.
