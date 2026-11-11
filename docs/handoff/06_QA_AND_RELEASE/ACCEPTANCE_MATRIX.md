# Definition of done / test matrix
| ID | Requirement | Verification |
|---|---|---|
| A01 | Project opens/imports in chosen Godot 4.x | headless import exit 0 |
| A02 | Offline Android debug APK launches portrait | physical device launch video |
| A03 | Warden fixed; auto targets and shoots; no manual aim/move | input test + gameplay capture |
| A04 | High top-down 55–65° continuous arena | camera inspector + screenshot |
| A05 | Hostiles spawn right/top-right, navigate toward core | seeded simulation + visual |
| A06 | 50 living enemies supported; pending spawn queue preserves all | headless load test + device benchmark |
| A07 | Five waves and Siege Hulk boss complete correctly | deterministic end-to-end run |
| A08 | Four enemy archetypes have distinct behavior | unit tests and capture |
| A09 | Scrap awarded exactly once per kill | duplicate death unit test |
| A10 | Pistol → SMG, damage/rate/piercing purchases correct | economy tests |
| A11 | Up to 2 turrets; no third purchase | boundary tests |
| A12 | EMP, shield, overdrive cooldown/effects correct | fixed tick tests |
| A13 | Pause freezes simulation and cooldowns | state tests |
| A14 | Core 0 defeats; full wave 5 clearance wins | integration tests |
| A15 | Save persists rewards exactly once; corrupt backup recoverable | filesystem tests + restart |
| A16 | Portrait HUD safe area, 48dp tap targets, legible text | on-device visual/accessibility audit |
| A17 | Color/material consistency with visual bible | approved screenshot review |
| A18 | FPS target measured on physical Android with 50 enemies | device/OS/build + p50/p95 frame time |
| A19 | No network, ads, accounts, IAP or unapproved permissions | manifest + runtime review |
| A20 | Source, scripts, tests, asset licenses, APK, logs delivered | release checklist |

**Release evidence**: `TEST_REPORT.md`, `PERFORMANCE_REPORT.md`, `KNOWN_ISSUES.md`, `ASSET_LICENSES.csv`, `BUILD_INSTRUCTIONS.md`, screenshots and debug APK checksum. Mark unavailable physical-device testing as **NOT RUN**, never PASS.
