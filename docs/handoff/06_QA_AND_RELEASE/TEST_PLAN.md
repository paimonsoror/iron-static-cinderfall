# Automated test plan
**Unit:** seeded RNG consistency; threat ordering and stable ties; firing cadence and magazine/reload; armor math; damage clamp; kill-once Scrap; exact purchase cost and double-tap idempotency; max turret slots; cooldown tick timing; pause freeze; state transitions; save schema validation and recovery.

**Integration:** run five waves seeded with dummy visuals; cap 50 living entities with queued spawn preservation; no wave completes while pending/alive > 0; enemy attack ring; simultaneous boss+escorts clearance; victory/defeat reward granted once; repeat run clean reset.

**Stress:** 50 live enemies, continuous pathing, pooled spawn/death churn; 10-minute headless sim; no NaN/infinite positions; no stuck state > configured recovery; identical event hashes for same seed/commands; varied seed sweep.

**On-device:** 5-minute session portrait; touch safe area; pause/resume; background/resume; sound and reduced flash; performance at 10/28/50 enemies; thermal after repeated runs; UI under display cutouts.

**Acceptance**: attach raw logs and commands, do not substitute visual-only screenshots for gameplay proof.
