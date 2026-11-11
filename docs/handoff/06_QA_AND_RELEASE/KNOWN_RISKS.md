# Risks / mitigations
- **50-enemy density vs five-minute duration**: authored schedule is a hypothesis; run DPS simulations and adjust spawn cadence/enemy HP before visual tuning.
- **50 agents on mobile**: spatial hash, flow field/cached navigation, low-frequency steering, object pooling, limited collision, animation LOD; profile on hardware.
- **Camera angle**: top-down reference image is not an exact orthographic projection; calibrate in engine for real portrait viewport and test UI overlap.
- **Canon ambiguity**: Cinder is ASH-07; event name and defender designation pending lore owner approval; do not mislabel relay.
- **Engine compatibility**: original Godot version and plugins may change; verify source and licensing.
- **Concept art**: not deployable assets; generated images can have noncanonical labels/weapon unlocks; do not copy UI pixels.
- **Accessibility**: tiny enemies at high camera angle; compensate with strong silhouette, emissive optics, VFX limits, optional high-contrast/reduced-flash modes.
