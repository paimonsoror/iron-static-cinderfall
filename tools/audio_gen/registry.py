"""Every sound recipe of the project in one ordered table, and the ids that may exceed 1.5 s.

Order = the 29 legacy ids of ARCH 10 (voices.py), then the variety ids in the order of VARIETY_SPEC 12.1 by group
(Weapons, Enemies, Bosses, Events, UI). A later task adds its recipes to the group file and nothing here changes
except the import of a new group file.
"""
from __future__ import annotations

import random
from typing import Callable

import voices
import voices_enemies
import voices_events
import voices_ui
import voices_weapons

Recipe = Callable[[random.Random], list[float]]

LEGACY_COUNT = len(voices.RECIPES)

VARIETY_GROUPS: tuple[dict[str, Recipe], ...] = (
    voices_weapons.RECIPES,
    voices_enemies.RECIPES,
    voices_events.RECIPES,
    voices_ui.RECIPES,
)

VARIETY_RECIPES: dict[str, Recipe] = {}
for _group in VARIETY_GROUPS:
    VARIETY_RECIPES.update(_group)

RECIPES: dict[str, Recipe] = {**voices.RECIPES, **VARIETY_RECIPES}

# Sounds allowed to run longer than gen.MAX_SFX_SECONDS. `lance_charge` (SPEC 12.1, 3 s rising) joins in task V4-A.
STINGERS = voices.STINGERS
