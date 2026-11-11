# IRON STATIC: CINDERFALL — BUILD HANDOFF v2.0
**Prepared 2026-11-10 · Design/implementation package · NOT a compiled game**

## START HERE
1. Read `00_START_HERE/AGENT_MASTER_PROMPT.md` and `00_START_HERE/DECISION_LOG.md`.
2. Read `01_PRODUCT_AND_LORE/GAME_DESIGN.md`, `02_TECHNICAL/ARCHITECTURE.md`, and `03_DATA/*.json`.
3. Study `04_VISUAL_REFERENCES/REFERENCE_INDEX.md` and the bundled PNGs; these are **concept art only**, not game textures/models.
4. Read `06_QA_AND_RELEASE/ACCEPTANCE_MATRIX.md`; deliver evidence for each gate.
5. Inspect the upstream original Iron Static repo before coding. Never modify it unless authorized.

**Precedence**: `00_START_HERE/DECISION_LOG.md` > this package's v2 design/architecture/data > `07_SOURCE_CONTEXT/LEGACY_TECH_SPEC_v1.md` > concept-art text. The old spec contains superseded 3-lane camera/wave assumptions. Do not silently follow those.

**Scope**: one offline, five-wave portrait Android vertical slice, cinematic optimized 3D high top-down/isometric, stationary auto-firing defender, up to 50 simultaneous hostiles, in-run upgrades, turret, EMP/shield/overdrive, Siege Hulk, local progression, tests and APK.

**Important**: The existing repository's current state, exact Godot/export tool versions, and asset rights have NOT been independently validated as part of this package. Agent must inspect and report findings. No test, build, or performance outcome is claimed here.
