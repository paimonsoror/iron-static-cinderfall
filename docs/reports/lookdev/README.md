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
  muzzle light on the chest and arm, and a bloom glow on the helmet highlight and the muzzle.
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

## Round 2: the v2 Warden (the STYLISED and STYLISED_PLUS geometry is replaced)

The owner chose "iterate on the Warden first" and "keep current scale". Camera, sim and scale are untouched; `CURRENT` is still
byte-identical (hash test green). The v1 files above are kept for comparison; the v2 images were pruned from the repository to keep it small (the v3 sheets carry a v2 column).

What changed against the coordinator's critique:

1. **Toy robot read.** The base is a dark charcoal suit (vertex value 0.46) with mid steel plates, and bone on only a few plates: the
   chest plate, the two pauldron lames (the right one brighter), the shin guards, the helmet crest and the pack top plate. The plates and
   the suit are tinted a little warm so the arena's cyan light lands on neutral grey, the shader desaturates the incoming light
   (`light_sat` 0.15), the shaded side is deep blue-black (`shade_floor` 0.12, cool `shade_tint`) with a warm bounce from the amber pad on
   the lower and sideways faces (`bounce_*`), and specular and rim on the bone are toned down. Nothing is near white any more.
2. **Faceting.** Round parts (helmet, shoulder caps, cheek pods, knee caps, limbs, elbow caps) have smooth normals; only plates are
   chamfered. The helmet shell is 12 sides x 6 bands. The notches and spikes of v1 were the open corners of `closed=false` bevel boxes;
   plates now use a new 30 triangle `plate` shell (no bottom face, side faces run to the bottom edge) and every box has closed corners.
3. **Helmet.** Shell, curved cyan visor under a brow plate, smooth cheek pods, a bone dorsal crest, a comm unit and the antenna.
4. **Proportions.** Chest with a V taper (top 1.5 x the bottom width), pauldron caps out to about 0.62 m, thighs 0.15 m radius, shins
   0.113 to 0.082 m and shorter, chunky 0.21 x 0.4 m boots, a belt with a pouch.
5. **Arms.** Two parts each (upper arm with an elbow cap, forearm with a glove; the weapon arm wears a gauntlet). `LookDevIk` solves both
   arms analytically (shoulder, wrist target, pole) every frame; the targets are points of the weapon node, so the grips follow every
   recoil kick, and in the reload pose the support wrist reaches the magazine. `look_dev_arms_test.gd` asserts that the wrists sit within
   5 mm of their targets while firing (both weapons, with recoil kicks) and within 3 cm of the magazine in the reload pose (v1 missed by
   several cm). The styled weapon hand mount moved closer to the chest (`LookDevWarden.HAND_R`) so the support arm can reach.
6. **Top-down read.** The budget went to the helmet top (crest, comm unit, antenna), the pauldrons with long cyan bars, and the pack with
   two stacks, glowing rings, a glowing vent strip and two wide cyan back bars.
7. **Shading** as in point 1; baked AO and edge wear kept.
8. **STYLISED_PLUS** still works (gates and tests green); no PLUS-only work. Accent energy of STYLISED is now 1.8, its rim 0.55, and the
   LOW-tier vertex-colour material no longer has a metallic term (it only darkened the baked colours).

Part count: the Warden is now 11 mesh instances (legs, torso, four arm segments, pack, antenna, cable, pistol, SMG); the part-count test in
`look_dev_view_test.gd` was updated deliberately (`ArmR`/`ArmL` became `ArmRU`, `ArmRF`, `ArmLU`, `ArmLF`). Triangles: 1,835 with the pistol
and 1,889 with the SMG (v1: 1,867 and 1,927; budget 2,000). New tests: `look_dev_arms_test.gd` (8 tests: solver lengths, clamping, pole, node
posing, firing and reload reach, elbow bend, gauntlet) and plate, smooth-normal and colour-plan tests in `look_dev_meshes_test.gd` (bone at
most 15 percent of the triangles; the metal averages below 0.8).

### v2 measurements

Same setup as above: 50 enemies, 1080x1920 SubViewport, vsync off, `Engine.max_fps = 0`; desktop Intel Iris Plus iGPU, not a phone.

| Tier | CURRENT frame_ms | v2 STYLISED frame_ms | delta | draws | primitives |
|---|---|---|---|---|---|
| LOW (one run) | 4.81 | 4.80 | -0.01 | 92 -> 99 | 26.6k -> 28.1k |
| MID (3 runs) | 9.69 (9.69, 9.67, 9.72) | 9.64 (9.57, 9.68, 9.68) | -0.05 | 92 -> 99 | 26.7k -> 28.2k |
| HIGH (3 runs) | 12.38 (12.84, 12.09, 12.21) | 12.29 (12.51, 12.18, 12.17) | -0.09 | 98 -> 105 | 38.6k -> 40.1k |

All rows are within noise (the three HIGH runs of the same configuration spread by 0.75 ms on this machine today): the cost of v2 is not
measurable on this GPU. It adds 7 draw calls (4 -> 11 mesh instances) and 1.5k primitives on every tier. Rows are in `measurements.csv`
(run `v2`). These runs were taken before the last colour-only tuning (the bone lames, crest and pack plate, steel value 1.15 -> 1.3, warm
bone); geometry, draws and triangles did not change.

### v2 images

The round-2 images were pruned from the repository; every one was opened and looked at when it was made; the captures went through `tools/capture.ps1` (`CAPTURE OK`, `renderer=mobile/vulkan`).
`v2_1_game_camera_1x.jpg` (real camera, 700x900 crop), `v2_2_warden_x3.jpg` (the Warden region enlarged 3x), `v2_3_closeup_3x.jpg` (3x zoom,
firing), `v2_4_three_quarter.jpg`, `v2_5_front.jpg`, `v2_6_side.jpg`, `v2_7_back.jpg` (solo views), `v2_8_reload.jpg`, `v2_9_four_angles.jpg`
(v2 alone), `game_v2.jpg` and `close3x_v2.jpg` (full 1080x2400 captures).

### v2 vs v1 vs CURRENT (honest)

- **Improved.** v2 reads as a person in a suit, not a toy: a dark suit with armour plates over it, a rounded helmet with a visor, brow,
  cheek pods and crest, broad V-shaped shoulders with pauldron lames, a real elbow, a belt with a pouch, chunky boots and a power pack
  with glowing bars. Round things are round (no spikes, no notches). The arms hold the weapon with both hands and follow it. Nothing
  clips to white. In the solo views (v2_4 to v2_9) it is clearly the best of the three.
- **Did not improve, or got worse.** At the real camera (v2_1, v2_2) the Warden is a dark grey-blue figure about 55 px wide. It reads as an
  armoured figure with cyan lights, more soldier than v1, but it is less bright and less legible than v1 and it is no longer the brightest
  thing on the field: the bone plates are small and read cream, and the pad glow, the cyan ring and the enemies' pale plates outshine it.
  At 3x (v2_3) the helmet crest, the two pauldrons with cyan bars and the pack are readable. Honest verdict: it reads as a soldier at 3x
  and only just at 1x; it does not yet stand out at 1x the way the owner asked.
- **Still weak.** The legs are still straight columns (no calf or thigh shaping; the stilt look is reduced, not gone); the knee caps are
  blobby; the helmet front reads like a round mask with a visor band (an astronaut more than a combat helmet); the shin plates read copper
  next to the pad (bone plus warm bounce); the chest plate looks grey from the front; the arms are tubes with caps; the reload pose reads as
  "weapon tilted, hand underneath" more than as a reload (no magazine moves).
- **Best ideas, cheapest first.** (1) At 1x only silhouette, value and the few bright accents survive; the figure has about 1,850 triangles,
  most of them below pixel size, so an 800 triangle version would look the same at the real camera. Spend the effort on value: raise the
  steel and the chest and back plates until the Warden is the brightest mass, and give the pack a large cyan back panel (the biggest lit
  shape the camera sees). (2) A thin always-on cyan fresnel seen from above (a rim that survives the pad glow), or a small warm key light on
  the Warden only, is cheaper than geometry. (3) Reshape the legs (calf bulge, tapered ankle, a visible knee hinge) and the helmet (a jaw
  guard and a flatter front). (4) A larger on-screen Warden (camera or scale) is the one lever that would make the triangles matter; the
  owner said no to that for now. (5) Authored models remain the way to concept-art detail.

## Round 3: Warden v3 (a heavy-armour trooper archetype; legibility at the real camera first)

The owner reviewed v2 and wanted two things: legibility at the real camera as the acceptance criterion, and a heavier "heavy-armour
trooper" read with softer edges. v3 replaces the STYLISED and STYLISED_PLUS geometry again (CURRENT is untouched and still byte-identical:
the hash test is green). Scale, camera and sim are unchanged. The design is original and procedural: no reference images, nothing from any
franchise. Images are in `v3/` (sheets are CURRENT | v2 | v3).

### 1. Legibility at the real camera (measured)

`--hide-warden` (sandbox flag) draws the same deterministic frame without the Warden. `src/debug/look_dev_legibility.gd` (headless, Image
API) takes the capture with and without it: the Warden pixels are the pixels that differ (biggest blob after a 1 px opening, which drops the
rain, the muzzle-flash spikes and the tracer); the ring is the background 3 to 9 px outside the silhouette, taken from the capture without the
Warden. Luma is Rec. 709 on the sRGB values. `contrast` = |mean luma of the Warden - mean luma of the ring|; `pixel contrast` = the mean over
the Warden pixels of |luma - ring luma| (robust when a figure is half dark and half bright); `clipped` = share of Warden pixels with any
channel at 250/255 or more (this includes saturated cyan); `white` = share with all channels at 240/255 or more. 1080x2400, scenario hold28,
frame 240, `--msaa=0` on both halves of every pair (anti-aliasing would put edge pixels on the pad rings into the mask). Command:
`Godot --headless --script res://src/debug/look_dev_legibility.gd -- --without=<png> --with=LABEL|<png> ...`.

| Tier | Look | Warden px | mean luma | ring luma | contrast | pixel contrast | p10 / p90 | clipped | white |
|---|---|---|---|---|---|---|---|---|---|
| HIGH | CURRENT | 2816 | 0.594 | 0.519 | 0.075 | 0.203 | 0.32 / 0.92 | 8.9% | 0.0% |
| HIGH | v1 | 2236 | 0.688 | 0.507 | 0.180 | 0.275 | 0.30 / 0.95 | 10.0% | 2.0% |
| HIGH | v2 | 2084 | 0.552 | 0.514 | 0.038 | 0.158 | 0.30 / 0.79 | 1.4% | 0.5% |
| HIGH | **v3** | 2317 | 0.628 | 0.514 | **0.114** | **0.205** | 0.30 / 0.84 | **3.3%** | 1.1% |
| MID | CURRENT | 2681 | 0.600 | 0.514 | 0.085 | 0.202 | 0.32 / 0.92 | 9.4% | 0.0% |
| MID | **v3** | 2317 | 0.627 | 0.496 | **0.131** | **0.213** | 0.30 / 0.84 | **3.3%** | 1.1% |
| LOW | CURRENT | 2926 | 0.543 | 0.516 | 0.027 | 0.156 | 0.33 / 0.74 | 0.0% | 0.0% |
| LOW | **v3** | 2483 | 0.562 | 0.512 | **0.049** | **0.184** | 0.28 / 0.81 | **1.6%** | 0.0% |

(v1 and v2 are the round 1 and 2 captures re-scored against the new background: the pair differs by 0.5 percent of the pixels outside the
box, which is rain. The v1 and v2 rows are HIGH only. The CURRENT and v3 rows are re-captured with the final code.)

**Target: v3 contrast at least CURRENT, at most 5 percent clipped Warden pixels. Met on all three tiers** (mean-luma contrast 0.114 vs 0.075,
0.131 vs 0.085 and 0.049 vs 0.027; clipped 3.3, 3.3 and 1.6 percent against CURRENT's 8.9, 9.4 and 0.0). Honest reading: the pixel contrast,
the measure that does not cancel when a figure is half dark and half bright, is **at parity with CURRENT on HIGH (0.205 vs 0.203) and
slightly above on MID and LOW**. v2 was far worse (0.158) and v1, the whitest, was better than everything (0.275, at 2 percent blown
white). So v3 is no longer a dim figure sinking into the floor, and it is not clipped like CURRENT's cyan blocks, but at 1x it is **not
clearly more legible than CURRENT and not the brightest mass on the field**: the enemies' pale plates and the pad's cyan ring are as bright.
How v3 got here, in order of effect: the plate material gain 2.4 (vertex colours cannot exceed 1), a camera-side fill in the shader, the dark
lower body (thighs, boots, suit) against the light upper body (helmet, pauldrons, pack top) so the figure is bimodal instead of mid grey (mid
grey was v2's problem: its mean luma 0.55 equals the pad's 0.51), the large cyan back panel and top strip, cyan shoulder inlays and a cyan helmet
fin, the desaturated specular, and cyan at 0.97 energy so no channel reaches 250. The dump `--dump=<dir>` of the scorer writes the mask and the
clipped pixels (the helmet top was the first clipping source; it was darkened).



### 2. The v3 design

A heavy-armour trooper archetype drawn from scratch, procedurally (no reference images, nothing from any franchise): charcoal and
gunmetal armour, a few bone plates, cyan lights. Scale, camera and sim are unchanged; the figure is the same 1.93 m tall and its footprint
is inside the old one (torso mesh 1.24 m wide, legs 0.92 m wide, boots at the same depth); the mass went into the helmet, the shoulders
and the chest.

- **Helmet** (about a fifth of the height: 0.36 of 1.93 m): a big rounded block with a flat front and a top that leans back (no
  forehead dome), a horizontal visor slot with angled corners (a flat hexagon in cyan over a dark bezel), a vent jaw guard with two
  slots, cheek plates, a sensor pod on the right side only, a dorsal fin with a cyan stripe that the top-down camera sees, and the
  antenna on the rear right.
- **Shoulders**: two stacked smooth domes per side, the right one bigger than the left (0.20 vs 0.18 m radius), bone on the right
  upper layer, steel on the left, a cyan inlay on each top layer. The torso mesh is 1.24 m wide against a 0.53 m belt.
- **Chest**: a rounded V block (top 1.6 x the bottom width) with a rounded bone plate and a cyan hexagon power core, a steel yoke.
- **Pack**: a big rounded body, two stacks with cyan caps, a cyan strip across the top and the large back panel (two tall cyan cells, a
  spine and two dark slats): 0.14 m2 of lit surface facing the camera.
- **Legs**: a wide planted stance, thighs as steel cylinders with rounded ends over the suit, small bevelled knee guards with a visible
  hinge cap on the outer side (no balls), a calf that bulges and tapers to a narrow ankle, neutral steel greaves with a cyan trim, chunky
  rounded boots.
- **Arms**: cylindrical steel vambraces with rounded ends over the suit, chunky gloves, the weapon arm with a cyan stripe. Same solver.
- **Colours**: dark suit (vertex value 0.12), steel (0.2 to 1.0, lifted by a material gain of 2.4 because vertex colours are 8 bit and
  clamp at 1), bone (gain 1.0), cyan lifted 30 percent toward white at energy 0.97 so that no channel reaches 250. The steel is neutral
  (no warm cast); the specular uses the same desaturated light as the diffuse, which removed the copper highlights of v2; the warm
  bounce is 0.12 instead of 0.3.
- **Legibility levers** in the shader (MID and HIGH): `value_gain`, a camera-side fill (`fill_strength` 0.6: a headlight toward the
  game camera, proportional to the albedo, so what the camera sees is lifted and the dark parts stay dark), a thin cyan rim (strength
  0.95, power 3). LOW has the gain on the material albedo and the cyan lights in the mesh (unshaded surface), but no fill and no rim.

### 3. Edges: geometry and aliasing

The owner still saw hard edges. There were two causes.

**Geometry.** v2 used one 45 degree chamfer strip per edge with normals leaned toward the neighbour face (a visible shading crease at the
strip border) and flat corners. v3: a new kit shape `LookDevRound.rounded_box` (`src/view/kit/look_dev_round.gd`: every edge a quarter
cylinder in two 45 degree facets, every corner an eighth of a sphere, analytic normals, so light rolls over the edge; 108 triangles; used
for the chest, the pack, the helmet block, the chest plate and the boots), `bevel_box` now defaults to `soft` 0 (the strip carries the
normals of the two faces at its borders: zero crease), plates are wider-bevelled, limbs have 10 sides and rounded ends where they end in
the open (thighs, vambraces), pauldrons are smooth domes. Numeric bounds are in `look_dev_edges_test.gd` (edge statistics by welding
vertices: facet angle between neighbouring triangles and shading crease at the shared vertices): a rounded box has no vertex on a bare
corner, shading crease below 1 degree and facet angles below 56 degrees untapered (the corner triangles; a taper adds its slope); the
whole figure has facet angles below 65 degrees on smooth-shaded edges and 10 percent hard edges (the flat caps of tubes, the thin glowing
panels and the weapon edges), bound 14 percent. The measured values are printed by the test (`EDGES` lines).

**Aliasing.** `project.godot` has `anti_aliasing/quality/msaa_3d=0` and the captures forced `MSAA_DISABLED`, so every silhouette in every
screenshot was jagged. New: `--msaa=0|2|4` and `--fxaa=0|1` sandbox flags (investigation) and a per-tier switch behind the look:
`LookDevStyle.msaa_samples(look, tier)` / `apply_aa(viewport, look, tier)`, called by `ArenaView.set_quality` and `set_look` (two lines each).
CURRENT always gets 0 (the project default); `project.godot` is untouched. Frame cost, vsync off, 50 enemies, 1080x1920 SubViewport, same
setup as the other measurements (desktop Intel Iris Plus iGPU, 2 runs per cell; rows `aa_*` in `measurements.csv`):

| Tier | off | MSAA 2x | MSAA 4x | FXAA |
|---|---|---|---|---|
| LOW (1 run) | 5.32 ms | 6.11 (+0.8) | not measured | not measured |
| MID | 10.60 (10.53, 10.66) | 12.73 (+2.1) | 13.99 (+3.4) | 11.65 (+1.05) |
| HIGH | 12.77 (12.22, 13.32) | 15.66 (+2.9) | 17.01 (+4.2) | 14.51 (+1.7) |

What the images show (`v3/v3_11_msaa_high_1x.jpg`, `v3_12_msaa_high_3x.jpg`, `v3_13_msaa_mid_1x.jpg`): off is stair-stepped on every
dome and on the ring decals; 2x removes most of it and leaves a little crawl on near-horizontal edges; 4x is clean; FXAA smooths the large
silhouettes about like 2x but blurs slightly more than MSAA (it also softens the world text a little) and does nothing for
sub-pixel features. **Recommendation** (implemented as constants `LookDevStyle.MSAA_LOW/MID/HIGH` = 0 / 2 / 4): LOW off, MID 2x, HIGH 4x.
Caveat: on this desktop iGPU HIGH with 4x is 17.0 ms, over the 16.7 ms budget, and even 2x costs 2.9 ms; the iGPU resolves MSAA through
shared memory. Tile-based phone GPUs (Adreno, Mali) resolve on-tile and are much cheaper, but that is a guess until it is measured on a
phone: **this needs a phone check before it ships**. If a phone shows more than about 1 ms for 4x, change `MSAA_HIGH` to 2 (and `MSAA_MID` to
0 or use FXAA there, +1.05 ms here). No `project.godot` change is needed or recommended (the setting is per look and per tier, so CURRENT
cannot be affected).


### 4. Cost

Same setup as the other measurements (50 enemies, 1080x1920 SubViewport, vsync off, `Engine.max_fps = 0`, desktop Intel Iris Plus iGPU, not a
phone), both looks with `--msaa=0`, two interleaved runs per cell (rows `v3_cur_*` and `v3_sty_*` in `measurements.csv`). The shader gained
a gain, a fill (one dot product) and a cheaper specular; there is no new draw, light or pass beyond v2.

| Tier | CURRENT frame_ms | v3 STYLISED frame_ms | delta | draws | primitives |
|---|---|---|---|---|---|
| LOW | 5.46 (5.43, 5.49) | 5.60 (5.41, 5.79) | +0.14 | 92 -> 99 | 26.6k -> 28.7k |
| MID | 10.26 (10.41, 10.11) | 10.39 (10.47, 10.31) | +0.13 | 92 -> 99 | 26.7k -> 28.7k |
| HIGH | 13.12 (13.37, 12.86) | 13.40 (13.57, 13.23) | +0.28 | 98 -> 105 | 38.6k -> 40.7k |

All inside the run-to-run spread of this machine (the two runs of one cell differ by 0.2 to 0.5 ms). Triangles: 2,448 with the pistol and
2,472 with the SMG (v2: 1,835 and 1,889; budget 2,500 now, `ActorMeshes.TRI_BUDGET`: **the "2,000" in ARCH 8 and WORK_PLAN 6 is stale, docs are
not mine**), 11 mesh instances as in v2, at most 3 surfaces per mesh. The anti-aliasing costs above are on top of this.

### 5. Images

All in `v3/` (CURRENT | v2 | v3 unless noted), all captures through `tools/capture.ps1` (`CAPTURE OK`, `renderer=mobile/vulkan`), every one opened
and looked at. The v3 images use the shipped per-tier anti-aliasing (HIGH: MSAA 4x); CURRENT and v2 have none, which is part of the difference you see.
`v3_1_game_camera_1x.jpg` (the real camera, 700x900 crop), `v3_2_warden_x3.jpg` (the figure enlarged 3x), `v3_3_closeup_3x.jpg` (3x zoom, firing),
`v3_4_three_quarter.jpg`, `v3_5_front.jpg`, `v3_6_side.jpg`, `v3_7_back.jpg` (solo views), `v3_8_reload.jpg`, `v3_9_four_angles.jpg` (v3 alone),
`v3_10_legibility_1x.jpg` (CURRENT | v1 | v2 | v3, the figure at 5x, no anti-aliasing: what the score measures; v3 is a 4x-MSAA capture there),
`v3_11_msaa_high_1x.jpg`, `v3_12_msaa_high_3x.jpg`, `v3_13_msaa_mid_1x.jpg` (off, 2x, 4x, FXAA), `v3_14_vs_turret.jpg` and `v3_15_vs_hulk.jpg` (CURRENT | v3
next to the turret and the Hulk), `v3_16_plus_bloom.jpg` (STYLISED | STYLISED_PLUS at 3x), (the full-frame captures `game_v3.jpg` and `close3x_v3.jpg` were pruned from the repository; regenerate them with `tools/capture.ps1`). Total under 4 MB.

What I saw: **v3_1 / v3_2 (1x)**: a silver-blue figure with two round pauldrons, a boxy helmet top with a cyan fin, a lit cyan pack panel and dark legs on
the amber pad: clearly a heavy figure, clearly a different silhouette from CURRENT's cyan blocks, similar overall brightness to CURRENT, clearly brighter than
v2, and the lit panel is the first thing the eye lands on. **v3_4 to v3_9**: a big squared helmet with a flat front and a hexagonal cyan visor slot, a vent jaw guard,
side plates and a sensor pod on the right, wide stacked pauldrons (the right one bigger, bone-topped), a thick chest with a bone plate, a big rounded pack with the lit
panel, thick black thighs, small knee guards with a hinge cap, neutral steel greaves with a cyan trim, chunky rounded boots. Silhouettes are smooth (rounded, MSAA 4x)
where v2's were faceted and jagged. **v3_14 / v3_15**: next to the turret (a hexagon base with one barrel, dark) and the Hulk (three times the size, red markings) the
Warden is clearly its own thing (round shoulders, a pack panel, the pad rings), but all three are pale silver-cyan; the Warden is distinguished by shape and the pad, not by
colour.

### 6. v3 vs v2 vs CURRENT (honest)

- **Better.** Legibility is back to CURRENT's level and the clipping is gone (above); the figure reads as a heavy armoured soldier in every solo view, with
  the helmet a fifth of the height, shoulders twice the waist, a wide stance, cylindrical thighs, a real knee guard with a visible hinge instead of a ball, a tapered calf
  and ankle, neutral steel greaves (no copper), a flat-fronted helmet with a jaw guard, cheek plates and a dorsal fin instead of a bowl-hat crest. Round things are smooth
  and the silhouette is anti-aliased on HIGH and MID.
- **Not better, or worse.** At 1x the pixel contrast is only at parity with CURRENT, so the owner's acceptance point ("the Warden should stand out at the real camera") is
  met in the numbers but not in the eye: it is as readable as CURRENT, not more. The lower body is black, so at 1x the legs are two dark posts and the figure reads
  as head, shoulders and pack. LOW (no shader) reads a little darker and flatter than MID and HIGH.
- **STYLISED_PLUS** works again and now really blooms: the cyan accents were never HDR before, because an unshaded material ignores its emission (v2 and v1 set
  an emission energy that did nothing); the accent brightness is now the albedo, 1.5 times the cyan in PLUS (2.2 white-outs the pack panel), and the pack, shoulders and
  visor glow with a soft bloom (`v3_16`). PLUS got no other work.
- **Known defects.** (1) The thighs are black inflated capsules: heavy, but they read as padded trousers more than as armour; the owner may want steel with panel lines.
  (2) The helmet is a rounded box with ear plates and a pod: it reads "trooper helmet" in profile and "robot head" from the front; a sloped brow and a narrower jaw would
  help, at the price of a few hundred triangles of shaping. (3) The bone chest plate is a flat slab from the front. (4) The steel has white specular blobs on the pauldrons at 3x
  (the specular strength is 0.26; a rougher metal would calm it). (5) The cyan back panel is flat unshaded colour, a lit billboard; the dark slats help only at 3x. (6) The right
  pauldron's bone top reads tan next to the cool steel. (7) The reload pose is "weapon tilted, support hand on it", no magazine moves. (8) The muzzle flash overlaps the helmet in
  the capture frame, so the mask includes a few flash pixels (the same for every look). (9) The turret and Hulk are still the old look: the Warden is smooth and the enemies are
  boxy and unaliased (CURRENT never gets MSAA), which the owner will see as a style mismatch until the rollout.
- **If the Warden still must stand out at 1x, the next lever and its cost.** (a) Make the steel brighter (value gain 3 and a whiter bone): the first sweep (gain 3.0 with fill 1.0)
  reached pixel contrast 0.24 at no cost in draws, but 13 to 19 percent of the pixels clipped and the plates went white, which is v1's toy look. (b) A thin screen-space
  outline or an inverted-hull outline (one extra draw per part, about 11 draws, or one post pass) separates the figure from any floor; this is the strongest legibility lever
  that does not touch the palette, and it costs 11 draws on the Warden only. (c) A larger on-screen Warden (the owner said no). (d) A small additive cyan floor light under the
  Warden (one draw) to lift the legs against the pad.

### 7. Tests, commands

`tools/test.ps1 -Path res://tests/unit/view`: 208 tests, 0 failures (new: `look_dev_edges_test.gd` with the numeric edge bounds, `look_dev_v3_test.gd` with the
cyan panel and lights, the gains, the clip bound, the proportions, the footprint, the flags and the per-tier anti-aliasing; updated: budget 2,500, accent materials,
style gates, and the emission tests, because an unshaded material ignores its emission: the v2 "emission energy" of the accents never did anything, the accent
brightness is now the albedo). `CURRENT` meshes remain byte-identical (hash test). The legibility scorer is a tool (`src/debug/look_dev_legibility.gd`), not
unit-tested; its pairs and the table above are reproducible with the commands in section 1.

## Round 4: Warden v4 (the freeze)

The owner saw v3 and chose one last polish round, then freeze. Sheets only, in `v4/` (CURRENT | v3 | v4, or v3 | v4; JPG quality 0.85, 1.4 MB; the full-frame
captures and the round 2 images were pruned from the public repo, so the v3 sheets are in `v3/` and the v3 captures used here were taken from my build directory).
Same constraints: scale, camera and sim unchanged, CURRENT hash-pinned, budget 2,500 triangles, tier gating, LOW parity, nothing from any franchise.

### Legibility (measured; same scorer and setup as round 3: 1080x2400, hold28, frame 240, `--msaa=0` on both halves)

| Tier | Look | px | mean luma | ring | contrast | pixel contrast | p10 / p90 | clipped | white |
|---|---|---|---|---|---|---|---|---|---|
| HIGH | CURRENT | 2816 | 0.594 | 0.519 | 0.075 | 0.203 | 0.32 / 0.92 | 8.9% | 0.0% |
| HIGH | v3 | 2317 | 0.628 | 0.514 | 0.114 | 0.205 | 0.30 / 0.84 | 3.3% | 1.1% |
| HIGH | **v4** | 2318 | 0.691 | 0.518 | **0.173** | **0.208** | 0.44 / 0.88 | **2.9%** | 0.4% |
| MID | CURRENT | 2681 | 0.600 | 0.514 | 0.085 | 0.202 | 0.32 / 0.92 | 9.4% | 0.0% |
| MID | v3 | 2317 | 0.627 | 0.496 | 0.131 | 0.213 | 0.30 / 0.84 | 3.3% | 1.1% |
| MID | **v4** | 2318 | 0.690 | 0.500 | **0.190** | **0.219** | 0.44 / 0.88 | **2.8%** | 0.4% |
| LOW | CURRENT | 2926 | 0.543 | 0.516 | 0.027 | 0.156 | 0.33 / 0.74 | 0.0% | 0.0% |
| LOW | v3 | 2483 | 0.562 | 0.512 | 0.049 | 0.184 | 0.28 / 0.81 | 1.6% | 0.0% |
| LOW | **v4** | 2473 | 0.621 | 0.516 | **0.105** | **0.184** | 0.37 / 0.86 | **3.5%** | 0.0% |

**The gate (HIGH pixel contrast at least 0.205, clipped at most 5 percent) is met: 0.208 and 2.9 percent.** The mean-luma contrast rose a lot (0.114 to 0.173 on HIGH) because
the lower body is no longer black; the pixel contrast, which is what a half-dark figure scores honestly, is flat: the figure is brighter overall and sits further above the
pad's luma (0.52) but has lost its very dark mass, so it is exactly as readable as v3 and CURRENT in that measure, not more. It was reached by value structure alone, no
outline and no light: the plate gain 2.4 to 3.1 (the shader tolerates it, MID and HIGH have the ramp), the LOW material takes 0.8 of it (`LOW_GAIN_SCALE`; at the full gain LOW clipped
29.5 percent of its pixels), a deeper shade floor (0.06 to 0.03) and a slightly warmer steel tint so the plates read grey, not ice blue, dark boots (0.2) and calves (0.3) and mid-light
thighs (0.55) with a light front plate. LOW: the dark joint gaps and the unshaded lights are the same, so LOW gained the same way (0.105 against CURRENT's 0.027 on the mean, 0.184 against 0.156).

### What v4 changed (the owner's items, in order)

1. **Helmet.** One smooth ellipsoid shell (12 sides, 3 rings per half; v3 was a box) with a cyan visor band that follows the shell around the front and the sides (ends at plus and minus 74
   degrees, the height falls off toward the ends so the corners are angled) over a dark bezel. **No mouth slot**: the jaw is a smooth steel ellipsoid with two small slits on each side.
   Kept: the sensor pod on the right only, the dorsal fin with a cyan stripe. The cheek plates are gone. From the front it reads as a helmet with a visor, not a face. Caveat: a round dome with a
   wide band is generic "trooper helmet"; the originality is in the fin, the pod, the side slits and the angled ends; nothing else was taken from anywhere.
2. **Chest.** Layered plates: two pectoral plates in a V (tilted 19 degrees) over a lower plate, all chamfered shells with zero crease; an off-white core housing with a dark ring and the cyan hexagon
   core inset; a panel line; harness straps over the shoulders (two thin dark bars on the yoke). The bone is now a clean off-white (`LookDevWarden.BONE_TINT` pulls the cream of the palette bone to neutral;
   the right pauldron top reads off-white, not tan). No flat beige slab.
3. **Legs.** Thighs are steel cylinders with rounded ends (mid-light steel), a light front plate with a cyan trim, dark only in the joint gap; mid steel calves; light greaves with the trim; dark boots.
   The lower body now reads as part of one soldier.
4. **Back panel.** Two cyan cells sunk behind a proud steel frame (spine, top, bottom, a middle slat); each cell has a brighter core (the cells are dimmed through the vertex colour of the unshaded
   accent material, which now takes vertex colour). Still the biggest lit shape (0.14 m2 of cell facing the camera, plus the brighter cores); exists on LOW.
5. **Specular.** Steel specular 0.26 to 0.12, roughness 0.55 to 0.62: no white blobs on the pauldrons at 3x.
6. **Reload.** Magazine drop skipped (not cheap: the magazine is part of the weapon mesh and the hand targets would need a second weapon part and a pose state); the reload pose is as in v3.
7. **Legibility.** See the table.

Also: triangles 2,466 with the pistol and 2,490 with the SMG (budget 2,500; v3 2,448 and 2,472), 11 mesh instances, no new draw, light, pass or shader branch, so no new frame-cost measurement (round 3's
numbers hold: the shader only gained constants). `ShaderWarmup` now draws the hard-surface materials at boot (see the recipe). `look_dev_compare.gd` has a `--jpg=<quality>` flag.

### Is v4 good enough to freeze?

**Yes for the rollout, with the honest limits below.** It reads as a heavy armoured trooper in every view at 3x, the helmet reads as a helmet, the lower body is armour, the colours are neutral grey and
cyan with one clean off-white, the edges are smooth, and at 1x it is back at CURRENT's level of legibility with no clipping on any tier. What is still weak: (1) at 1x it is **not** clearly more
legible than CURRENT (pixel contrast 0.208 against 0.203) and the figure is pale: a light grey figure on an amber pad, with the enemies' pale plates just as bright; the next lever that does not touch the
palette is an outline (rejected by the owner) or a larger figure; (2) the helmet is a smooth dome with a band, safe but plain; the sensor pod and the side slits carry the identity; (3) the thighs are still
capsules (with a plate on the front), the knees small, the boots rounded slabs; (4) the cyan panel cells are flat unshaded colour inside a framed recess; (5) the chest core and the harness straps are small
and hidden by the arms in the front view; (6) the reload is a tilt, not a magazine drop; (7) LOW is a little flatter than MID and HIGH (no fill, no rim); (8) the old enemies are boxy and unaliased next to a smooth
Warden until the rollout.

## Applying the look to other actors

This is the recipe for the rollout (turret, the four enemy archetypes, the Hulk). It was written when the Warden was frozen (v4). The look
is: smooth, rounded hard-surface geometry; ambient occlusion and edge wear baked into the vertex colours; a soft lighting ramp, a thin cyan
rim and a camera-side fill in one shared shader (MID and HIGH); cyan (or later red) lights that are part of the mesh; a value structure that
reads at 55 px. Everything is procedural and deterministic. The Warden code is the worked example: `src/view/actors/look_dev_warden.gd`
(legs, torso), `look_dev_head.gd` (helmet, pauldrons), `look_dev_gear.gd` (arms, pack, weapons), `warden_parts.gd` (dressing),
`warden_view.gd`, `warden_motion.gd`.

### 1. The kit (all in `src/view/kit/`)

| Piece | What it is for |
|---|---|
| `MeshBuilder` (`mesh_builder.gd`) | One merged `ArrayMesh`, one surface per material id. `tint` multiplies the vertex colour of everything added next (rgb at most 1: see the traps). `begin_part()` starts a shape (the AO bake skips self-occlusion inside a part). `add_occluder(centre, radius)` registers a sphere (use it for neighbours that are separate meshes). `add_tri(...)` writes a triangle with explicit smooth normals and an edge-wear value. `recentre(pivot)` moves the origin of a part. `use_colors` is switched on by the bake. |
| `LookDevShapes` | `bevel_box` (44 triangles; `plate` true gives a 30 triangle shell with no bottom face, for plates that sit on a body; `soft` 0 is the zero-crease default), `limb` (smooth tapered tube; `round_ends` 1 for rounded ends; `cap_a`/`cap_b` false where it disappears into armour), `ellipsoid` (`upper_only` for domes), `curved_plate`, `frame_along(a, b, t, offset, up)` (a frame along a segment: pass `Vector3.FORWARD` as `up` for a leg or the plate ends up behind the limb), `facing(dir)` (a basis whose +Y is `dir`, for plates that face a direction). |
| `LookDevRound` | `rounded_box` (108 triangles, every edge a quarter cylinder, analytic normals): for the big masses (body, head block, boots). |
| `LookDevBake` | `ao(mb, strength, reach, sky, ground_y, foot_dark, foot_h, skip_roles)`: bakes analytic ambient occlusion from the occluder spheres into rgb (once per mesh, at build time) plus a sky and a ground term; call it once at the end of a builder; skip the emissive role. `gradient_y` for a vertical value ramp. |
| `LookDevStyle` | The look switch (`CURRENT`, `STYLISED`, `STYLISED_PLUS`), the per-tier gates, `value_gain`, `fill_strength`, `rim_strength`, `accent_energy`, and the anti-aliasing switch (`msaa_samples`, `apply_aa`). **Every behaviour of the look is decided here by (look, tier); do not test tiers elsewhere.** |
| `LookDevMat` | The shared materials: `surface(role, look, tier)` returns the material for a role (`ceramic`, `gunmetal`, `dark_frame`, `emit_cyan`; anything else is the plain MatLib material). MID and HIGH: a `ShaderMaterial` on `look_dev_actor.gdshader`. LOW: a `StandardMaterial3D` that only shows the vertex colours (the gain is in its albedo). `accent_color(energy)`, `warm_materials(look)`, `refresh()` (after `MatLib.configure`). |
| `look_dev_actor.gdshader` | Soft ramp, cool shade tint, desaturated light, cyan fresnel rim from above, camera-side fill, edge wear, optional detail texture (PLUS). Mobile safe: opaque, no discard, no screen or depth texture, one `light()`. Per-material uniforms only; **nothing is per instance**. |
| `LookDevTex` | The 128 px detail texture (STYLISED_PLUS only). |

### 2. Building a part (the pattern to copy)

1. A static builder per mesh in a new file `src/view/actors/look_dev_<actor>.gd` (stay under the 400 line cap; the Warden needed four files).
   Local frame: the origin at the feet or at the joint the node rotates about; forward is -Z.
2. Per shape: set `mb.tint` first (a value at most 1, with a small helper per actor: `_steel(k)`, `_suit(k)`, `_bone(k)` in `LookDevWarden`), then call
   the shape. Use `LookDevRound.rounded_box` for the big masses and `bevel_box` (zero crease, bevel 0.03 to 0.05) for plates, `limb` with 8 to 10 sides
   for tubes and `ellipsoid` for domes. No bare 90 degree corners on anything that shows at 3x.
3. Register occluders for neighbours that are separate meshes (`_ghosts` in `look_dev_warden.gd`), then `LookDevBake.ao(...)` once, then `mb.build()`.
4. Emissive parts: `mb.tint = Color.WHITE`, `mb.begin_part()`, then `mb.box(...)` / `mb.cylinder(...)` with `emit_cyan`. They exist on LOW because they are mesh,
   not shader. A tint below 1 on the emissive role dims it (the back panel has dim cells and bright cores).
5. Register the mesh in `ActorMeshes` (`warden_part(part, look)` is the pattern): CURRENT returns the old builder; any other look returns a cached styled mesh
   under a separate key. The budget is `ActorMeshes.TRI_BUDGET` (one test asserts it).
6. Hard-surface colour plan that worked: a value structure, not colours. Light neutral steel for the plates that face the camera (tint 0.8 to 1.0 times the
   gain), mid steel for the lower mass (0.3 to 0.6), near black only in joint gaps and under plates (0.1), one clean off-white (the `ceramic` role with
   `LookDevWarden.BONE_TINT`, never cream) and large cyan lights. Avoid values near the floor's value (about 0.5 luma on the pad): mid grey on a mid
   ground disappears (this was v2's failure).

### 3. How the look swap works, single instance versus pooled actors

- **Single instance (the Warden).** `WardenParts.apply(look, tier)` swaps `mesh` and the surface override materials on fixed nodes; nothing is created or freed.
  Extra nodes (arms, pack, antenna, cable) are shown only in the styled looks. Secondary motion (springs, IK, breathing) is Warden-only and costs a few transforms.
- **The enemies and the turret are NOT MultiMeshes.** `EnemyPool` allocates 108 pooled `EnemyActor`s (50, 24, 32, 2), each one `MeshInstance3D` that shares ONE
  `ArrayMesh` per kind (`ActorMeshes.enemy(id)`); only the blob shadows and the health bars are `MultiMeshInstance3D`s. What applies to the pooled actors:
  - Vertex colours (AO, tint, wear) are in the shared mesh: **zero per-instance cost**, the same vertex buffer for all 50 skitters.
  - Materials are shared per (role, look, tier class); set them once with `set_surface_override_material` when the pool is built, and loop the pool when
    the look changes (swap `mesh.mesh` and the overrides: no allocation). Never make a material per instance.
  - The hit flash is `material_override`, which wins over surface overrides, so the flash keeps working unchanged. `ActorContrast` (High Contrast) builds
    its variants from the plain MatLib materials as surface overrides: it must be extended to build variants of the look materials (a `ShaderMaterial` copy
    with a higher rim or value gain) or High Contrast will silently bring the old look back.
  - A pooled actor is one merged mesh posed by whole-mesh transforms (`ActorMotion`): do not split an enemy into parts (108 actors times 4 nodes is 430
    nodes and draws). The Warden's springs, IK, extras and muzzle light do not apply.
  - If a kind is ever moved to a `MultiMesh`: the baked vertex colours still apply (leave `use_colors` of the MultiMesh off, or the instance colour multiplies on
    top), the shared `ShaderMaterial` works on a `MultiMeshInstance3D`, but the hit flash needs per-instance data (a `flash` instance uniform that the shader does not have yet).
- **Cost to expect.** The Warden (one instance, 11 nodes) measured at +0.1 to +0.3 ms on the iGPU. For 108 instances the fill cost of the shader is
  what to measure, not the triangles: run `docs/reports/lookdev/measure.ps1` (50 enemies, `hold50`) before and after, 3 runs per cell, LOW, MID and HIGH.

### 4. Triangle budgets (guidance, to be confirmed by the measurement above)

The Warden is 2,500 (2,466 with the pistol, 2,490 with the SMG; one instance). Triangles that are sub-pixel at 1x are waste, so spend them where 3x shows an edge
(the silhouette: heads, shoulders, rounded masses) and not on the hidden sides. Proposal for the pooled actors, which draw up to 50 at once: skitter 450 (now 300),
hollow warden and rusher 500 (now 400), turret 600 (now 300), Hulk 1,500 (now 900, two instances). The 2.1k extra primitives of the Warden were not
measurable on the iGPU; 50 skitters at +150 triangles each is +7.5k and must be measured. Keep at most 3 surfaces per mesh (`ActorMeshes.MAX_SURFACES`).

### 5. Tier gating (LookDevStyle is the only place)

| | LOW | MID | HIGH |
|---|---|---|---|
| Geometry and baked vertex colours (AO, wear, tint) | yes | yes | yes |
| Value gain | in the material albedo | shader | shader |
| Ramp, rim, edge wear, fill | no | yes | yes |
| Detail texture, bloom (PLUS only) | no | yes | yes; muzzle light (PLUS only) HIGH only |
| Cyan lights (unshaded mesh surface) | yes | yes | yes |
| MSAA (hard-surface looks only; CURRENT 0) | 0 | 2x | 4x (see README round 3: **needs a phone check**) |

Rule: a new gate is a function in `LookDevStyle` with a test in `look_dev_style_test.gd`. `CURRENT` must return "off" for every gate. LOW must still read
(parity): the LOW material has the gain and the lights and loses only the ramp, the rim and the fill.

### 6. The CURRENT-unchanged test pattern

`look_dev_meshes_test.gd` holds a `BASELINE` table: for every CURRENT mesh the triangle count, the vertex count, the surface count and an FNV-1a hash of the
material names, vertices, normals and indices (`LookDevTestKit.mesh_hash`), plus "no vertex colours". Copy the pattern for each new actor: capture the table
**before** touching the actor (a test run prints nothing on success, so record the numbers from a first failing run or a script), then assert that `ActorMeshes.<actor>(CURRENT)`
still matches. Styled meshes go under separate cache keys, so the CURRENT meshes cannot change by accident. Also assert: budget, at most 3 surfaces, palette
roles only, vertex colours in range, determinism (two builds hash equal), and the edge statistics of `look_dev_edges_test.gd` (facet angle on smooth edges, hard-edge share).

### 7. The legibility scorer (acceptance at the real camera)

`--hide-warden` (sandbox) draws the same deterministic frame without the Warden; `src/debug/look_dev_legibility.gd` scores a capture pair: Warden pixels = the pixels
that differ, ring = background 3 to 9 px outside, `contrast`, `pixel contrast`, `clipped`, `white`. For a new actor add a `--hide-<actor>` flag next to `hide_warden` in
`debug_args.gd` and `look_dev_sandbox.gd` and pass `--box=x,y,w,h` of its screen position. Always capture both halves with `--msaa=0`. Acceptance used for the Warden:
mean-luma contrast and pixel contrast at least CURRENT's on HIGH, MID and LOW, and at most 5 percent clipped pixels. Commands:
`Godot --headless --path <project> --script res://src/debug/look_dev_legibility.gd -- --without=<png> --box=215,1402,100,80 --with=LABEL|<png> [--dump=<dir>]`.

### 8. Traps (all of these cost a round)

1. **An unshaded `StandardMaterial3D` ignores its emission.** It outputs the albedo only. The glow is the albedo times the energy; set `albedo_color`, not `emission_energy_multiplier`.
   (Rounds 1 and 2 set an emission energy that did nothing, and the PLUS bloom never worked.)
2. **Vertex colours are 8 bit unorm and clamp at 1.** A tint above 1 does nothing. Lift values with `value_gain` (the shader uniform, or the LOW material's albedo), and use tints only for lighter and darker.
3. **The shared-material cache.** `LookDevMat.surface()` returns one instance per (role, look, shaded class) and repaints it on every call; never edit a returned material for one actor
   (it changes all of them), and call `LookDevMat.refresh()` after `MatLib.configure`.
4. **`frame_along` needs an `up` vector for legs.** The default `Vector3.UP` puts the thigh and shin plates behind the limb when the knee is bent; pass `Vector3.FORWARD`.
5. **Winding is resolved from the normals** (`MeshBuilder._tri`): a wrong normal gives an inside-out face, not an error. This is also why the open-corner bevel boxes
   (`closed` false) showed dark notches: use `closed` true, or `plate` for shells.
6. **Shading crease.** A chamfer strip whose border normals lean toward the neighbour face (`soft` above 0) shows a crease; `soft` 0 is smooth. Stacked domes need the same side count or the seam zigzags.
7. **The specular used the raw (warm) light colour**, which turned dark parts copper; the shader now uses the desaturated light for both diffuse and specular.
8. **Mid grey on a mid ground.** Legibility is |value - ground|: the pad is about 0.5 luma. Go clearly lighter or clearly darker, not mid.
9. **Clipping is measured on any channel**: a bluish light steel clips its blue channel first. Keep the plate gain where `clipped` stays under 5 percent.
10. **The warm-up must use the Warden's vertex format.** A pipeline is keyed by the vertex format; the warm-up quads of the styled materials carry a vertex colour (`ShaderWarmup.attach(..., lit)`).
11. **`.gd.uid` files are committed**, and every new `class_name` needs an import before a headless script can see it.
12. **Do not call the model by a franchise name, copy its colours or silhouette** (public repo): "heavy-armour trooper archetype" only.

### 9. Boot wiring and warm-up

- Set the look once at boot, before the battle view is built: `LookDevStyle.set_current(look)` (look = `LookDevStyle.Look.STYLISED` or `STYLISED_PLUS`; default CURRENT),
  **before `BattleView.setup`**. `ActorLayer` reads it when the Warden view binds (`WardenView.bind` calls `set_look(LookDevStyle.current())`), and since v4 `ArenaView`
  also starts in `LookDevStyle.current()`, so glow, the tier MSAA and the warm-up follow without a second call. `ActorLayer.set_look(look)` and `ArenaView.set_look(look)`
  switch at run time (`src/debug/view_sandbox.gd` shows the pair).
- The warm-up: `ArenaView._ready` calls `ShaderWarmup.attach(self, center, extra, LookDevMat.warm_materials(_look))`, so the hard-surface materials are drawn once during the boot
  screen. If the look is chosen after `ArenaView` is built, call `LookDevMat.warm_materials(look)` and attach a `ShaderWarmup` with it.

## Round 5: actor rollout (W3-D)

The Warden is frozen (v4); this round rolls the same look out to the rest of the battlefield so it is coherent: the auto turret, the three
pooled enemies (Skitter, Hollow Warden, Rusher) and the Siege Hulk. The look is still hard-surface, not cel shaded and not cartoon: rounded and
bevelled forms, ambient occlusion and weathering baked in the vertex colours, a soft ramp, a thin rim and emissive accents. New direction from
the owner during the round: the gritty look of `docs/handoff/04_VISUAL_REFERENCES/topdown_approved.png` is the target for the enemies, the turret
and the Hulk ("the closer we get, the greater your success"). Original and procedural only: nothing was traced or copied from that image, no concept
image is used as a texture, nothing from any franchise. The image shows skull-like faces with two eyes; that is NOT reproduced (GDD: one red optic, never
a skull, never several eyes).
The shipped game boots with `STYLISED` (`GameViewSettings.SHIPPED_LOOK`), so this is what the player now sees; `--look=current` keeps every old mesh
byte-identical (hash-pinned, see Tests).

### What is new

| Piece | Where | What it does |
|---|---|---|
| `LookActorsStyle` | `src/view/kit/look_actors_style.gd` | The gates of the rollout: `enabled(look)`, `grit_enabled(look, tier)`, `warm_rim_strength`, `optic_energy` (above 1 only where `LookDevStyle.glow_enabled`, and only in the red channel), `optic_color`, and `shaded(look, tier, small)`: the Skitter and the Rusher (40 of the 50 at hold50, 40 to 60 px tall) take the baked material on every tier (measured, see Measurements). `rollout_override` (sandbox `--rollout=0`) keeps the actors in CURRENT while the Warden is styled: the state of main before this task, used to measure what the rollout costs. |
| `LookActorsGrit` | `src/view/kit/look_actors_grit.gd` | Weathering baked into the vertex colours at build time: hash-noise dirt blotches, grime climbing from the ground, warm oil stains, soft chips (vertex alpha = bare metal), the red light spill of the optic on the plates around it. Deterministic, free at run time. |
| `LookActorsKit` | `src/view/kit/look_actors_kit.gd` | Colour plan (`frame(k)` dark gunmetal, `plate(k)` neutral off-white), `limb2`, `cone`, the single optic (`optic`: a bright emissive band that follows the head, a dim halo band under it and a dark bezel band, all in the existing surfaces) and `finish` (AO bake, grit, spill, build). |
| `LookActorsMat` + `look_actors_enemy.gdshader` | `src/view/kit/` | Shared enemy materials per (role, look, shaded class). MID and HIGH, Hollow Warden and Hulk only (the Skitter and the Rusher take the LOW material on every tier, see `LookActorsStyle.shaded`): a sibling of the Warden's shader (the Warden's is untouched) with a warm orange rim and bounce instead of the cyan rim, per-pixel grit (speckle, scratches, gravity streaks, chips) and panel seams on near axis-aligned faces, all from hash noise, no texture. LOW: a `StandardMaterial3D` that shows the baked vertex colours only. The optic is an unshaded `StandardMaterial3D` that takes the vertex colour (so the halo and bezel dim it). |
| `LookActorsSkitter`, `LookActorsHollow`, `LookActorsRusher`, `LookActorsHulk`, `LookActorsTurret` | `src/view/actors/` | The meshes (see below). |
| `ActorMeshes.enemy_look(id, look)`, `turret_part(part, look)` | `src/view/actors/actor_meshes.gd` | CURRENT (or a switched-off rollout) returns the old mesh; the hard-surface looks return a cached styled mesh under a separate key. `TRI_BUDGET` raised on purpose. |
| `EnemyActor.apply_look`, `EnemyPool.set_look`, `ActorLayer.set_look/set_quality`, `TurretView.apply_look` | `src/view/actors/` | The 108 pooled `MeshInstance3D`s still share ONE `ArrayMesh` per kind and ONE material per (kind surface, look, tier class); a look or tier change swaps `mesh.mesh` and the surface overrides in place (nothing is created or freed). The hit flash is a `material_override` and wins over them, unchanged. |
| `ActorContrast.variant_for(role, look, tier)` | `src/view/actors/actor_contrast.gd` | High Contrast twins of the look materials (shader twin with a stronger warm rim, fill and value gain; baked twin with the emission lift on LOW; a hotter optic). Without it High Contrast would silently have brought the old look back. |
| Warm-up | `LookDevMat.warm_materials` (two added lines with the `refresh` hook) | Appends `LookActorsMat.warm_materials(look)`: the enemy shader and baked variants, the optic and `flash_white` (the hit flash is drawn over a coloured vertex format, so it needs its own pipeline), drawn once by the existing `ShaderWarmup` during the boot screen. `LookDevMat.refresh()` also repaints the enemy materials. |
| Debug | `src/debug/` | Sandbox flags `--focus=warden\|skitter\|hollow_warden\|rusher\|siege_hulk\|turret` (the close-up and the solo cameras follow that actor; `LookActorsFocus`) `--rollout=0\|1` and `--small-baked=0\|1` (measurement switches); `--tune=e_<uniform>:<v>` reaches the enemy shader only. |

Existing kit and view files that were edited (all additive, no signature changed): `look_dev_mat.gd` (two lines: warm-up list and refresh hook),
`actor_meshes.gd`, `actor_layer.gd`, `enemy_actor.gd`, `enemy_pool.gd`, `turret_view.gd`, `actor_contrast.gd`, `debug_args.gd`, `look_dev_sandbox.gd`.


### The five actors

All five are original designs drawn from scratch in code, deterministic, with at most 3 surfaces per mesh, baked ambient occlusion, dirt, chips and the
optic light spill in the vertex colours, a hunched forward lean built into the three small machines (inside the old sim footprint, view only) and asymmetric
damage so no two halves match. The single red optic is the identity of every enemy: a bright emissive band that follows the head, on a dark bezel, with a dim
halo band around it (no skull, no pair of eyes; the head is dark with a narrow pale crest so the red reads against it from above and from the front).

| Actor | Triangles (budget) | Design |
|---|---|---|
| Skitter | 336 (450) | A low, hunched crawler: a pitched dark thorax under three overlapping pale shell plates with dark gaps, a dark helm with the optic band on its upper front, two raised mantis forelimbs with pale claws, four digitigrade legs. **Footprint**: the old legs spread 1.32 m wide and piled up at 50 enemies; the new feet stay within 0.4 m of the centre (0.77 m wide, farthest vertex 0.56 m against 1.10 m before), so individual machines separate at hold50. Damage: the rear left leg is broken at the shin, the left forelimb hangs bent. |
| Hollow Warden | 466 (500) | A heavy, hunched biped, upper body leaning forward 11 degrees: a broad tapered chest on a dark frame, a half-width pale chest slab (the left half is gone), a big plated right shoulder dome and a bare frame stub on the left, a small dark helm sunk between the shoulders with the visor bar, thigh plates, long arms (a heavy plated ram on the right, a thin clawed arm on the left). |
| Rusher | 436 (500) | A lean sprinter with the torso pitched 34 degrees forward, reverse-jointed legs, forward-reaching arms with blades, three swept-back dorsal spines (the third is snapped) and a dim red glow strip along the spine (a secondary light, dimmer than the optic, not an eye). The left blade is broken and the left shoulder plate is missing. |
| Siege Hulk | 1,494 (1,500) | The heaviest and most menacing machine: a pitched dark frame under rounded off-white armour, two huge shoulder blocks with layered plates and swept spikes (the left plate is cracked off its block, one spike is broken), pillar forearms ending in big fists with knuckle spikes, short hind legs, a domed back with two exhaust stacks and cables, a dark helm sunk between the shoulders with the optic band, and a red core in a dark housing on the chest (visible from the front and the three-quarter view; GDD: "red chest core"). Same pivot and pitch as the old mesh, so the footprint is unchanged. |
| Turret | 538 (600, base plus head) | A very dark gunmetal tripod with a slewing ring and a yawing gun head: armour plates in the Warden's clean off-white, a mantlet, twin shrouded barrels ending exactly at `HeroMeshes.TURRET_MUZZLE` (the tracers and shots leave from the same place), a side ammo box, an antenna, a cyan sensor lens and a cyan status strip. Friendly colours only (cyan, never red). Uses the Warden's shared materials (`LookDevMat`). |


### Gap list against the owner's target (`topdown_approved.png`), final

Written after every capture round (rounds 1 to 4 fixed the largest gaps first: the beige "balloon" heads, a tiny optic, flat plates; round 5 the panels, grit and the turret).
What is still different, largest first:

1. **Detail density.** The target actors carry hundreds of small parts: hydraulics, cables, vents, bolts, hands with fingers, layered plates. Ours are 430 to 1,500 triangles of
   rounded forms with procedural panel seams, chips and streaks. At the real camera the swarm reads well; in the three-quarter view the Hollow Warden and the Rusher still read as
   stylised hard-surface robots, with tube limbs and block hands, not as the weathered machines of the image.
2. **Material.** The target is chipped paint over dark metal, rust, oil, wet grime. Ours: baked dirt, edge wear and chips (every tier) plus, on MID and HIGH, per-pixel speckle, scratches,
   gravity streaks and panel seams. LOW has the baked part only (flatter). No wetness, no reflections, no emissive grime.
3. **Light.** The target has strong orange fire light on the plates. Ours: a warm orange rim and a warm bounce in the enemy shader (MID and HIGH), no new light node, so the orange is
   an edge accent, weak at 1x. The red optic has a dark bezel and a geometric halo band; a real glow halo needs bloom (the optic goes above 1 in the red channel only when
   `LookDevStyle.glow_enabled`, so it blooms red, never white, if W3-E switches bloom on; without bloom it is a hot saturated red).
4. **Poses.** The target enemies are hunched, long-limbed, predatory. The Skitter, Hollow Warden and Rusher have a forward lean built in, but their limbs are rigid and symmetrical in motion
   (`ActorMotion` moves the whole mesh); no limb animation.
5. **Hulk.** Menacing and clearly the heaviest (spiked shoulders, knuckle spikes, red chest core, red optic, exhaust stacks), but it is a chunkier, simpler mech than the image: no pistons or
   cables between the plates, the forearm pillars are plain cylinders.
6. **Turret.** Very dark metal with clean off-white plates, twin shrouded barrels, an ammo box, cyan lights. The image's turret is dark metal with amber parts; amber is the core's colour and
   cyan is the friendly accent here, so the turret has no amber. Simpler than the image.
7. **Camera.** The image is a perspective view at about 40 to 50 degrees. The shipped camera is orthographic at 60 degrees: roofs dominate, faces and optics are seen less. Judged from both
   the shipped camera and the three-quarter solo views (`--view=three`, `front`, `side`, `back`).
8. **Not reproduced on purpose.** Skull-like faces and paired eyes (GDD lore guard).


### Measurements (desktop Intel Iris Plus iGPU, NOT phone numbers; the machine was shared)

Same method as the earlier rounds (`look_dev_sandbox`, the real arena and camera, 50 enemies at `hold50`, or the `boss` scenario: the Hulk and 14 escorts, rendered in a 1080x1920
SubViewport, vsync off, `Engine.max_fps = 0`, four 5-second `[PERF]` windows per run after a discarded warm-up window), with every configuration of a cell interleaved
(cur, sty0, sty, cur, sty0, sty, ...), 2 runs per cell (3 on HIGH hold50), **one measure.lock held around every single run**. Three configurations per cell:
`CURRENT` (nothing styled; the shipped baseline), `styled Warden only` (`--rollout=0`: the Warden in STYLISED and the turret and enemies in CURRENT, i.e. what main was before this task,
with the tier MSAA) and `STYLISED` (this task: the whole battlefield). The cost of the rollout is the last minus the middle column; CURRENT to STYLISED also contains the per-tier MSAA of the
look (MID 2x, HIGH 4x: +2 to +3 ms, W3-C round 3), which this task did not add.

| Scenario, tier | CURRENT frame_ms | styled Warden only | STYLISED (rollout) | **rollout cost** | vs CURRENT | draws (cur / styled) | primitives (cur / Warden only / rollout) |
|---|---|---|---|---|---|---|---|
| hold50 LOW | 5.77 (6.05, 5.49) | 5.56 (5.91, 5.21) | 5.84 (5.59, 6.09) | **+0.28** | +0.07 | 92 / 99 | 26.6k / 28.7k / 36.5k |
| hold50 MID | 10.09 (9.77, 10.42) | 12.11 (12.12, 12.09) | 13.84 (13.81, 13.86) | **+1.73** | +3.75 | 92 / 99 | 26.7k / 28.8k / 36.6k |
| hold50 HIGH | 13.30 (12.72, 14.47, 12.71) | 16.06 (15.91, 16.20, 16.09) | 17.02 (16.53, 17.30, 17.22) | **+0.96** | +3.72 | 98 / 105 | 38.6k / 40.7k / 48.5k |
| boss LOW | 5.26 (5.41, 5.12) | 5.19 (5.11, 5.27) | 5.14 (5.15, 5.13) | **-0.05** | -0.12 | 57 / 64 | 17.4k / 19.5k / 23.1k |
| boss MID | 9.69 (9.42, 9.95) | 11.59 (11.31, 11.86) | 12.72 (12.54, 12.90) | **+1.13** | +3.03 | 57 / 64 | 17.4k / 19.5k / 23.1k |
| boss HIGH | 12.73 (12.67, 12.79) | 15.18 (15.51, 14.84) | 16.80 (16.79, 16.81) | **+1.62** | +4.07 | 63 / 70 | 29.3k / 31.4k / 35.0k |

Honest reading:

- **LOW costs nothing measurable** (+0.28 ms at hold50, inside the run-to-run spread; the budget was +0.3). LOW has no shader: geometry and baked vertex colours only.
- **HIGH hold50 +0.96 ms** is at the +1.0 ms limit, **MID hold50 +1.73 ms and the boss scenes +1.1 (MID) and +1.6 ms (HIGH) are over it.** Draw calls are the same with and without the rollout
  (the 108 pooled instances already existed; they just wear 3-surface meshes), so the cost is fill and primitives: the swarm goes from 28.8k to 36.6k primitives (MID) and the boss scene gets the
  big Hulk. The three earlier runs of this round on the same code but with the first geometry (432 to 1,494 triangles, all kinds on the shader) were +1.4 to +2.6 ms on HIGH hold50.
- **What I did to get under the limit** (each step measured, HIGH hold50, 3 interleaved rounds, rollout cost against the styled Warden only: 15.72 ms; rows `w3d_d`, `w3d_e`): the first
  version cost +2.6 ms (one noisy pass) and about +1.4 ms (the clean window); (1) the Skitter and the Rusher (40 of the 50, 40 to 60 px tall) take the baked vertex-colour material on every tier
  instead of the shader (`LookActorsStyle.shaded`): +1.19 ms against +1.36 ms with the shader on all kinds, so the shader fill is only about 0.2 ms; with the grit, streaks and seams switched off
  (shader uniforms to 0) the saving was 0.3 ms; (2) fewer sides on the limbs, heads and shells of the three small kinds (Skitter 430 to 336 triangles, Rusher 464 to 436, Hollow Warden 490 to 466:
  -3.6k primitives at hold50): +1.08 ms; then the final clean matrix above: +0.96 ms. So most of the remaining cost is primitive and MSAA work on tiny triangles, not shader ALU. Further levers, not
  taken because each costs looks: fewer triangles in the Skitter again, baked material for the Hollow Warden on MID, no MSAA on HIGH
  (`LookDevStyle.MSAA_HIGH`, +4.2 ms by itself, owned by W3-C and the owner), or a LOD swap to the CURRENT meshes beyond a screen size.
- **Noise.** The same configuration varies by 0.3 to 1.8 ms between runs and drifts up over a window on this machine; the first passes of this round (rows `w3d_*` without `_final`, also in
  `measurements.csv`) were taken while the owner's game window and W3-E were using the same GPU (the lock was held by someone else for most of the time, and the coordinator exported an APK from 21:13 to
  21:17 with the lock free: none of the final rows below fall in that window), and were up to 2 times slower (CURRENT HIGH 14.7 to 16.8 ms against 12.7 to 13.3 ms in the final rows). Treat
  differences under about 0.5 ms as noise; the columns of one row are interleaved runs of the same minute, which is why the rollout cost is more reliable than the absolute times.
- **One-time build cost** (not per frame): the five styled meshes (AO bake, weathering, build) take about 150 ms in GDScript on this desktop CPU (`ACTOR_BUILD_MS`: Hulk 70, the others 7 to 18 each;
  it was 200 ms before the grit bake got a position cache) at the first use of a hard-surface look, plus the Warden's 75 ms; a phone is several times slower, so this belongs behind the boot screen
  (the pool is built in `ActorLayer.setup`, before the first frame; the warm-up draws the new materials once afterwards).


### Tests

`tools\check.ps1` (layer lint, import, compile with warnings as errors, every suite) is the gate; the new suites are `look_actors_meshes_test.gd` (13 tests) and
`look_actors_view_test.gd` (12 tests), helpers in `look_actors_test_kit.gd` (`LookActorsTestKit`; every new class is prefixed `LookActors`).
What they pin:

- **CURRENT byte-identical**: the hash table `BASELINE` of `look_dev_meshes_test.gd` already covered every actor (skitter, hollow warden, rusher, siege hulk, turret, base,
  head); `look_actors_meshes_test.gd` repeats the pins through the new accessors *after* every styled mesh has been built, and checks that CURRENT returns the very same
  mesh instances (and that a switched-off rollout does too).
- **Budgets**: every styled mesh within `TRI_BUDGET` (printed as `ACTOR_TRIS`), at most 3 surfaces, palette roles only (enemies: gunmetal, ceramic, emit_red; turret: gunmetal,
  ceramic, emit_cyan).
- **Palette roles and the optic**: on every enemy exactly one full-bright red piece (the optic; the Rusher's spine strip and the Hulk's chest core are dimmer), no red piece with a
  mirror image across the body axis (no second eye), no cyan; the turret has cyan and never red.
- **Vertex colours**: in range, darker in the creases than on the open plates, weathered (relative spread), edge wear present.
- **Determinism**: two builds hash equal. **Footprint**: the Skitter is at most one slot wide, every enemy reaches no farther from its centre than the old mesh did, heights follow
  the content, silhouettes stay different, the Hulk's footprint is at least 4 Hollow Wardens, the turret's barrels end at `TURRET_MUZZLE`. **Build time** is printed (`ACTOR_BUILD_MS`).
- **View**: 108 pooled instances share one mesh per kind and one material per (kind, surface); the hit flash still wins and leaves the overrides in place; the look switch swaps and
  restores; 50 look and tier switches grow neither nodes nor materials nor resources; High Contrast twins (shader, baked, optic) and the way back; tier gating; the optic is above 1
  only with glow and only in the red channel; the warm-up list; the turret view; pooled enemies still turn to face their movement direction.

### How to reproduce the images and the numbers

```
# solo cameras and close-ups of one actor (add --solo to hide the others; --view=front|three|side|back; --zoom=<f> is the top-down close-up)
Godot --path <project> res://src/debug/look_dev_sandbox.tscn -- --look=stylised --quality=2 --scenario=hold50 --focus=skitter --view=three --solo
# the cost of the rollout alone: the Warden styled, the actors in CURRENT (what main was before this task)
Godot --path <project> res://src/debug/look_dev_sandbox.tscn -- --look=stylised --rollout=0 ...
# every enemy kind on the shader instead of the baked material for the small ones
... --small-baked=0
```

`measure.ps1` (this folder) is the base of the measurement; the runs of this round used the same loop with a lock file around every single run (`C:\dev\tower-two-wt\measure.lock`), configurations
interleaved, rows in `measurements.csv` (tags `w3d_*`).


### Images

All in `rollout_actors/` (15 files, 2.45 MB together), sheets only (no full-frame captures; the captures stay in the build directory), JPG quality 0.85, every capture through `tools/capture.ps1` (`CAPTURE OK`,
`renderer=mobile/vulkan`, Intel Iris Plus), HIGH tier unless stated, the same simulation frame (240 frames = 4 s) for CURRENT and STYLISED, every image opened and looked at. Left is CURRENT, right is
STYLISED unless a label says otherwise.

| File | What it shows |
|---|---|
| `r5_1_game_hold10.jpg`, `r5_1_game_hold28.jpg`, `r5_1_game_hold50.jpg`, `r5_1_game_boss.jpg` | The real game camera at 1x pixels (a crop of the 1080x2400 capture around the fight), CURRENT | STYLISED at 10, 28 and 50 enemies and at the boss scene. |
| `r5_2_close_enemies.jpg` | The three pooled enemies at 7x to 11x zoom (a 2x crop of the top-down close-up, `--focus=<kind> --zoom=...`, i.e. far larger than the 3x of the brief so that the surface is visible): Skitter, Hollow Warden, Rusher, CURRENT | STYLISED. |
| `r5_3a_close_hulk.jpg`, `r5_3b_close_turret.jpg` | The Hulk (2.4x) and the turret (8x, in a 2x sheet), top-down close-ups, CURRENT | STYLISED. |
| `r5_4_angles_<actor>.jpg` | Front, three-quarter, side and back low perspective cameras (`--view=...`) of the Skitter, Hollow Warden, Rusher, Hulk and turret (STYLISED): the check for the three-quarter camera the owner likes. |
| `r5_5_tiers.jpg` | STYLISED at LOW, MID and HIGH (hold50, 1x). |
| `r5_6_swarm_before_after.jpg` | The hold50 swarm at 2x, CURRENT | STYLISED: the Skitters no longer pile up. |
| `r5_7_high_contrast.jpg` | STYLISED normal | High Contrast (hold50, 1x). |

What I saw (honest):

- **1x, the shipped camera.** The swarm is now countable: every Skitter is a pale segmented shell with a dark head and a red band, dark spidery legs inside its own slot, where CURRENT is a pile of
  overlapping boxes and legs. The Hollow Warden reads as a heavy biped with a pale slab and a bulky shoulder, the Rusher as a forward-leaning sprinter, the Hulk as a spiked grey mass with a red band
  on its head. The plates are neutral off-white over dark frames (the old ones were cream), the optic is the brightest and most saturated thing on each machine. The warm orange of the
  target is hardly visible at this size.
- **3x.** Rounded forms, dark bezels around the optics, edge wear, dirt blotches, panel seams (MID and HIGH), the Hulk's knuckle spikes and shoulder layers, the turret's barrels and ammo box.
  Also visible: it is still a stylised hard-surface look (see the gap list): flat-ish plates, tube limbs.
- **Three-quarter and side (`r5_4_*`).** The optic is readable from the front and the side on every enemy; the silhouettes stay different (Skitter: low spider; Hollow: upright slab; Rusher: bent over;
  Hulk: wide, spiked, red core; turret: tripod with twin barrels). The Hulk has a strong front (the red hex core in a dark housing between the shoulders) and side (the shoulder block and the
  pillar arm); the turret's front is the mantlet and the lens. The Hollow Warden and the Rusher are the weakest from the side (tube limbs, block hands).
- **At 1x the STYLISED enemies are darker than CURRENT's pale boxes** (neutral off-white plates over dark frames, instead of cream-white boxes): against the dark floor they carry a little less brightness, and the red optics do more of the counting. This is the price of the grey-white and dark-frame palette of the target.
- **The turret's three-quarter view is partly hidden** by a foreground arena barrier and a tracer of its own shot (the low camera sits on the pad); front, side and back are clean.
- **Tiers.** LOW keeps the shapes, the baked dirt and the optics, with a flatter surface and no warm rim. MID and HIGH add the ramp, rim and grit on the big machines.
- **High Contrast.** Nearly the same as normal at 1x: a hotter optic and a stronger rim on the plates; the effect is subtle.

### Assessment (honest)

- **Better than CURRENT, clearly, at every distance**: individual machines separate at hold50, the optic is a strong, single identity, the Hulk is the heaviest thing on the field, and the
  battlefield is now coherent with the Warden (rounded hard-surface forms, baked occlusion, cool dark frames, clean plates).
- **Still far from the owner's target image** in detail and mood (gap list above): it is a stylised hard-surface rollout, not weathered concept art. The biggest levers left, in order: a
  warm orange light that really lights the plates (a pooled warm light or an emissive-rim pass on the enemies, which needs W3-E's lighting), more small parts on the Hulk and the Hollow Warden
  (cables, pistons, hands), and limb animation (`ActorMotion` moves the whole mesh).
- **Cost** is a real but modest +0.3 (LOW), +1.0 to +1.7 (MID and HIGH) ms on this iGPU on top of the styled Warden; phone numbers are NOT RUN (no phone, the emulator cannot present Vulkan frames).

### Known defects

1. The Hollow Warden and the Rusher read as stylised robots from the side: tube limbs and block hands; no hands or fingers, no cables or pistons.
2. The optic halo is a dim geometric band, not light: no glow on the plates around it except a baked red tint of the nearest vertices; real halo needs bloom (works red-only if switched on).
3. Panel seams are triplanar on near axis-aligned faces; on rotated plates (the Rusher's torso, the pitched Hulk frame) fewer faces qualify, so the seams are uneven there; they are subtle at 1x.
4. The Skitter and the Rusher use the baked material on MID and HIGH (cost): no warm rim, ramp or grit on them; only the baked dirt and chips. They look like the LOW tier.
5. The Rusher's "spark trail" of the old mesh (two red quads on the ground behind it) is not in the styled mesh (they were flat red rectangles); a spark trail is a VFX job (W3-E / VfxLayer).
6. The turret has no amber (amber is the core's colour, cyan the friendly accent); it is dark metal with clean plates and cyan lights.
7. `ActorMotion` poses the whole mesh, so the broken leg of the Skitter, the claw of the Rusher and so on never move on their own.
8. Rollout cost on MID (hold50 +1.7 ms, boss +1.1) and on HIGH (boss +1.6 ms) is over the 1 ms guidance; the levers are listed under Measurements.
9. The one-time mesh build (about 150 ms desktop) happens at the first use of the look; on a phone it is several times that and has to sit behind the boot screen.
10. No phone or emulator check (NOT RUN).

### What the next agent needs

- Everything of this round is in `LookActors*` files plus the edits listed above; a new enemy follows the Warden recipe and `LookActorsKit` (colour plan, `optic`, `finish`).
- To change the cost: `LookActorsStyle.shaded` (which kinds use the shader), `LookActorsMat` (shader parameters per role), `ActorMeshes.TRI_BUDGET` and the builders' side counts.
- To add bloom for the optics: `LookDevStyle.glow_enabled` already decides; `LookActorsStyle.optic_energy` puts the red channel above 1 only then.
- Boot wiring needs nothing new: `GameViewSettings` sets the look before `BattleView.setup`; the warm-up list is `LookDevMat.warm_materials` (called by `ArenaView._ready`, not mine).
- ARCH 8 and WORK_PLAN 6 (docs, not mine) need the new budgets and the warm-up list: see the report of this task.
