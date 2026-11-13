"""Every sound recipe of the project in one ordered table, the ids that may exceed 1.5 s and the ids a voice loops.

Order = the 29 legacy ids of ARCH 10 (voices.py), then the 60 variety ids in the order of VARIETY_SPEC 12.1 by group
(Weapons, Enemies, Bosses, Events, UI); each group file lists its recipes in the order of the table.
"""
from __future__ import annotations

import random
from typing import Callable

import voices
import voices_bosses
import voices_enemies
import voices_events
import voices_ui
import voices_weapons

Recipe = Callable[[random.Random], list[float]]

LEGACY_COUNT = len(voices.RECIPES)

VARIETY_GROUPS: tuple[dict[str, Recipe], ...] = (
    voices_weapons.RECIPES,
    voices_enemies.RECIPES,
    voices_bosses.RECIPES,
    voices_events.RECIPES,
    voices_ui.RECIPES,
)

VARIETY_RECIPES: dict[str, Recipe] = {}
for _group in VARIETY_GROUPS:
    VARIETY_RECIPES.update(_group)

RECIPES: dict[str, Recipe] = {**voices.RECIPES, **VARIETY_RECIPES}

# Sounds allowed to run longer than gen.MAX_SFX_SECONDS (up to gen.MAX_STINGER_SECONDS): the three stingers, the Lance
# Platform's three-second charge (SPEC 12.1: "stinger class") and the two-second Static Front bed.
STINGERS = voices.STINGERS + ("lance_charge", "static_front")

# Sounds that a held voice loops (AudioHeldVoices). They are checked for a seamless wrap instead of zero edges.
HELD_LOOPS = voices_weapons.HELD_LOOPS
