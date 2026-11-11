# Art direction — production contract
**Visual DNA**: photoreal-leaning cinematic industrial sci-fi, seen from high top-down/isometric, NOT cartoon/painterly. Wet concrete, corrugated steel, oxidized pipes, industrial gantries, crates, shipping containers, concrete barriers, damaged cables, steam, haze, firelight. Keep terrain uncluttered enough to track 50 moving silhouettes.

**Palette**: ally cyan #39C9DB; amber #F1A34A; hostile red #D94D4D; obsidian #101820; gunmetal #6C7882; bone ceramic #D8D3C5. Cyan = friendly; red = CHORUS; amber = core/resources; never violate meanings. Add icon/shape redundancies for accessibility.

**Composition**: core and Warden anchored on left, hostile mass approaches from right/top-right; game world dominates viewport. 55–65° down angle, orthographic preferred. Avoid cinematic low-angle hero framing during play; reserve that for splash/menus. Boss readable at reduced mobile scale. Limit UI to essential resources/abilities; no fake weapon cards.

**Materials/lighting**: one main directional light, mostly baked/stationary illumination, selective emissives; reflections should be approximated for Mobile renderer. Control particle and alpha-overdraw budgets. No expensive screen-space GI or cinematic depth of field during combat. Damage numbers and muzzle flash capped/pooled.

**Modeling**: modular kit, low-to-medium poly mobile meshes, shared atlases, LODs, rigs with small animation sets. Unique silhouettes for Skitter, Hollow Warden, Rusher, Siege Hulk. Warden must have upper-body yaw/pitch pivot. Animations are presentation only.

**Reference precedence**: `topdown_approved.png` is the current layout/camera target; `environment_mood.png` informs lighting/materials; `armory_style.png` informs UI styling only. Any illegible/misspelled text in generated concepts is NOT canon or binding.
