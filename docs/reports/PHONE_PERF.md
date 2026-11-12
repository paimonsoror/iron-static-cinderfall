# Phone measurements (Pixel 11 Pro Fold)

First real-device numbers, taken 2026-11-11 by the coordinator on the owner's phone (the Android emulator cannot present
Vulkan, so no earlier device number exists). One device, one run per row; NOT a certification. Re-measure after every
visual wave and before release.

## Device

| | |
|---|---|
| Model | Pixel 11 Pro Fold (`yogi`), Android 17 (SDK 37), Tensor G6 |
| GPU | ImgTec PowerVR C-Series CXTP-48-1536 MC1, Vulkan 1.4.317 |
| Screen used | outer panel 1080x2342, 390 dpi, up to 120 Hz (the game caps at 60) |
| Build | debug APK `com.normalexception.games.cinderfall.dev`, Mobile renderer (`renderer=mobile/vulkan`), main `74011e6` |

## Frame time at 50 living enemies (`--scenario=hold50 --debug-perf`, about 50 s per row, the first 2 PERF lines skipped)

Averages of the 5-second `[PERF]` windows. `p95` is the mean of the windows' 95th-percentile frame time.

| Setting | fps | frame_ms | p95_ms | draws | prims |
|---|---:|---:|---:|---:|---:|
| HIGH (`--quality=2`), MSAA 4x (shipped default) | 55.7 | 17.95 | 32.5 | 137 | 40.6k |
| HIGH, MSAA off | 56.2 | 17.80 | 30.1 | 137 | 40.6k |
| HIGH, MSAA 2x | 56.0 | 17.85 | 31.7 | 137 | 40.6k |
| HIGH, `--look=current` (the old blocky Warden) | 56.5 | 17.70 | 29.3 | 130 | 38.5k |
| MID (`--quality=1`), MSAA 2x (default) | 57.0 | 17.54 | 28.3 | 131 | 28.7k |
| MID, MSAA off | 57.2 | 17.49 | 26.8 | 131 | 28.7k |
| LOW (`--quality=0`) | 60.0 | 16.67 | 21.8 | 131 | 28.7k |

## What this says (and does not)

- MSAA is nearly free on this tile-based GPU (at most about 0.15 ms); on the dev laptop's iGPU it costs +2.9 ms (2x) and
  +4.2 ms (4x). The per-tier plan (LOW off, MID 2x, HIGH 4x) stands.
- The new hard-surface Warden look costs nothing measurable on the phone (17.95 against 17.70 ms is inside the noise).
- LOW holds a clean 60 fps. MID and HIGH sit near 56 fps with about 30 ms hitches every 20th frame, so they are just over
  the 16.7 ms budget. The limiter is not MSAA and not the look; LOW renders at 0.75 scale, so pixel count is the leading
  suspect (NOT yet proven: no GPU profile was taken). A render-scale option for MID and HIGH is the next experiment.
- The environment and character rollouts (W3-D, W3-E) will add cost: re-measure here before choosing the default tier.
- A full autoplay run (`--autoplay=greedy --seed=1`) finishes in 4:53 with VICTORY, 5/5 waves, core 704/1000 (71 percent),
  384 kills, +135 Recovered Data, the same outcome as the desktop run. No crash since the audio loop fix (`74011e6`).

## How to repeat

Debug builds read extra flags from `user://cinderfall_args.txt` (one line), so no rebuild is needed to change them:
`adb shell "run-as com.normalexception.games.cinderfall.dev sh -c 'echo --scenario=hold50 --debug-perf --quality=2 > files/cinderfall_args.txt'"`,
then force-stop and launch (`am start -n com.normalexception.games.cinderfall.dev/com.godot.game.GodotAppLauncher`) and read
`adb logcat -d -s godot:V | findstr PERF`. Delete the file afterwards. Screenshots: the foldable has two displays; use
`adb exec-out screencap -d <outer display id> -p` (list ids with `dumpsys SurfaceFlinger --display-id`), and check that the game is in the
foreground first.

## Not measured yet

Thermal throttling over a long session, battery drain, background and resume, safe areas on other devices, other GPUs
(Adreno, Mali), touch input by a human.
