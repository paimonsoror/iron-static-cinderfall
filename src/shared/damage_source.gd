class_name DamageSource
extends RefCounted
## Who dealt damage or a kill (ARCH 4). Turret source = TURRET_0 + pad index. Append only (VARIETY_SPEC 13.2).

enum Id { WARDEN = 0, TURRET_0 = 1, TURRET_1 = 2, WARDEN_OFFHAND = 3, CORE = 4, STRIKE = 5, HAZARD = 6 }

const COUNT := 7
