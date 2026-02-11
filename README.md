# ME-Sanctuary

A collection of RuneScape 3 PvM automation scripts built for the MemoryError Lua scripting engine. Each script handles full boss-kill cycles including War's Retreat preparation, combat rotations, mechanic avoidance, prayer management, and death recovery.

All scripts use the **Necromancy** combat style.

## Scripts

### Sanctum of Rebirth — Hard Mode

Full automation for the Sanctum of Rebirth dungeon on Hard Mode, fighting all three bosses sequentially.

**Bosses:**
- **Vermyx, Brood Mother** — Handles moonstone dodging, soul bombs, wyrmfire breath, soul rush redirects, scarab healer killing, and phase transitions
- **Kezalam, the Wanderer** — Handles moonstone obelisk phases (Invoke Death + Death Guard EoF spec), sanctum blasts, line blasts, prison mechanic (Freedom → Resonance → Surge), and volatile scarabs
- **Nakatra** — Handles "Prepare for Death" lethal mechanic (Devotion / Reflect + Vitality fallback), magic and ranged prayer flicking

**Features:**
- PVME-based Necromancy rotation with ability improvisation (necrosis stacks, residual souls, Living Death)
- Automatic prayer flicking based on incoming projectile detection
- Consumable management with combo eating and configurable HP thresholds
- Mid-run resupply between Kezalam and Nakatra
- Death's Office recovery with automatic item reclaim
- War's Retreat preparation (bank, altar, bonfire, adrenaline crystal)
- ImGui GUI with configuration, runtime stats, kill timers, and debug logging

**Files:** `sanctum/Sanctum_HM.lua` + 7 module files

---

### Flesh-hatcher Mhekarnahz

Boss killer for the Flesh-hatcher Mhekarnahz encounter with support for banking between kills or camping at the boss.

**Features:**
- AoE mechanic avoidance (3x3, outer, middle, inner telegraphs) using free-tile pathfinding
- Camp boss mode — loop kills without banking via return portal
- Prayer potion / super restore management with emergency teleport
- Prayer toggle safety (checks buff status before toggling to avoid deactivation)
- Distance-based surge to ledge
- ImGui GUI with config save/load

**Files:** `fleshhatcher/FleshHatcher.lua`, `fleshhatcher/FleshHatcherGUI.lua`

---

### Vindicta — Normal Mode

Necromancy script for Vindicta (God Wars Dungeon 2) on Normal Mode with timer-based cooldown management and ability rotation sequencing.

**Files:** `Vindicta/Main.lua`, `Vindicta/Config.lua`, `Vindicta/Rotation.lua`

---

### Vindicta — Hard Mode

Hard Mode variant with phase-specific prayer handling:
- Phase 1 (Vindicta alone) — Soul Split
- Phase 2 (Gorvek + Vindicta) — Soul Split
- Phase 3 (Gorvek alone) — Deflect Melee

**Files:** `VindictaHM/main.lua`, `VindictaHM/config.lua`, `VindictaHM/rotation.lua`

---

### TzKal-Zuk

Zuk encounter automation with prayer flicking, overload management, scripture of Wen/Jas/Ful support, and configurable gear options (Zuk cape, Elven Shard, Excalibur).

**Files:** `zuk/ZukMe.lua`, `zuk/ZukMeGUI.lua`, `zuk/prayer_flicker.lua`, `zuk/timer.lua`

---

## Shared Libraries

| File | Description |
|------|-------------|
| `MELib.lua` | Shared utility library — sleep helpers, player state checks, HP/adrenaline/prayer accessors, inventory helpers, buff management, and combat utilities |

## Requirements

- MemoryError Lua scripting engine with `api.lua`
- RuneScape 3 client
- Necromancy combat style with appropriate gear (T95+ recommended for Sanctum HM)
- Abilities and consumables placed on action bars as required by each script

## License

[MIT](LICENSE)
