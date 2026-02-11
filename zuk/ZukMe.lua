local API = require("api")
local TIMER = require("zuk.timer")
local PrayerFlicker = require("zuk.prayer_flicker")
local GUI = require("zuk.ZukMeGUI")

---------------------------------------------------------------------
--# CONFIG: Buff ID lookup tables
---------------------------------------------------------------------
local PRAYER_BUFF_IDS = {
  ["Sorrow"] = 30771,
  ["Ruination"] = 30769,
}

local BOOK_BUFF_IDS = {
  ["Scripture of Wen"] = 52117,
  ["Scripture of Jas"] = 51814,
  ["Scripture of Ful"] = 52494,
}

local OVERLOAD_BUFF_ID_MAP = {
  ["Elder overload"] = 49039,
  ["Supreme overload"] = 33210,
  ["Overload"] = 26093,
  ["Holy overload"] = 26093,
  ["Searing overload"] = 26093,
  ["Overload salve"] = 26093,
  ["Elder overload salve"] = 49039,
  ["Supreme overload salve"] = 33210,
}

local function resolveOverloadBuffId(name)
  for key, id in pairs(OVERLOAD_BUFF_ID_MAP) do
    if name:lower():find(key:lower(), 1, true) then
      return id
    end
  end
  return 49039
end

--- Applies GUI config values to global script variables
local function applyConfig(cfg)
  HAS_ZUK_CAPE = cfg.hasZukCape or false
  USE_BOOK = cfg.useBook or false
  USE_POISON = cfg.usePoison or false
  USE_EXCAL = cfg.useExcal or false
  USE_ELVEN_SHARD = cfg.useElvenShard or false
  OVERLOAD_NAME = cfg.overloadName or "Elder overload"
  OVERLOAD_BUFF_ID = resolveOverloadBuffId(OVERLOAD_NAME)
  NECRO_PRAYER_NAME = cfg.necroPrayerName or "Sorrow"
  NECRO_PRAYER_BUFF_ID = PRAYER_BUFF_IDS[NECRO_PRAYER_NAME] or 30771
  BOOK_NAME = cfg.bookName or "Scripture of Wen"
  BOOK_BUFF_ID = BOOK_BUFF_IDS[BOOK_NAME] or 52117
  SCRIPTURE_BUFF_IDS = { 52117, 51814, 52494 } -- Wen, Jas, Ful
  RESTORE_NAME = cfg.restoreName or "Super restore"
  FOOD_NAME = cfg.foodName or "blubber jellyfish"
  FOOD_POT_NAME = cfg.foodPotName or "Guthix rest"
  ADREN_POT_NAME = cfg.adrenPotName or "Super adrenaline"
  BREW_NAME = cfg.brewName or "Saradomin brew"
  RING_SWITCH = cfg.ringSwitch or "Occultist's ring"
end
---------------------------------------------------------------------
--# END CONFIG
---------------------------------------------------------------------

local TIMERS = {
  GCD = { -- global cooldown tracker
    name = "GCD",
    duration = 1600,
  },
  Vuln = { -- prevent vuln bomb spam
    name = "Vuln Bomb",
    duration = 1800,
  },
  Excal = { -- keep track of 5min cooldown instead of checking each time
    name = "Excal",
    duration = (1000 * 60 * 5) + 1,
  },
  Elven = { -- keep track of 5min cooldown instead of checking each time
    name = "Elven",
    duration = (1000 * 60 * 5) + 1,
  },
  Buffs = { -- check buffs every second
    name = "Buffs",
    duration = 1000,
  }
}

---------------------------------------------------------------------
--# SECTION: Constants used throughout the script
---------------------------------------------------------------------
--- @type WPOINT | nil
SAFESPOT_JAD = nil
--- @type WPOINT | nil
SAFESPOT_NORMAL = nil
ARENA_MIN_X = math.mininteger
ARENA_MAX_X = math.maxinteger
ARENA_MIN_Y = math.mininteger
ARENA_MAX_Y = math.maxinteger
LAST_CAST = os.clock()

REGULAR_WAVES = {
  [1] = true,
  [2] = true,
  [3] = true,
  [7] = true,
  [8] = true,
  [12] = true,
  [13] = true,
}
JAD_WAVES = {
  [6] = true,
  [11] = true,
  [16] = true,
}
CHALLENGE_WAVES = {
  [5] = true,
  [10] = true,
  [15] = true,
}
IGNEOUS_WAVES = {
  [4] = true,
  [9] = true,
  [14] = true,
}

POSSIBLE_TARGETS = {
  Hur = 28535,          -- basic meleer
  Igneous_Hur = 28537,  -- igneous hur
  Volatile_Hur = 28546, -- volatile hur (challenge wave)
  Mej = 28542,          -- basic mager
  Zek = 28543,          -- tier 2 mager
  Igneous_Mej = 28544,  -- igneous mej
  Mejkot = 28536,       -- tier 2 meleer
  Xil = 28538,          -- basic ranger
  Tok_Xil = 28539,      -- tier 2 ranger
  Igneous_Xil = 28540,  -- igneous xil
  Kih = 28545,          -- prayer drainer
  Jad = 28534,          -- jad
  Unbreakable = 28547,  -- unbreakable ket (challenge wave)
  Fatal_1 = 28548,      -- fatal 1 (challenge wave)
  Fatal_2 = 28549,      -- fatal 2 (challenge wave)
  Fatal_3 = 28550,      -- fatal 3 (challenge wave)
  Har_Aken = 28529,     -- har aken
}

ZUK_IDS = {
  DPS = 28526,   -- dps check zuk
  START = 28525, -- start instance
  FIGHT = 28527, -- main fight
  END = 28528,   -- kneeling zuk after successful kill
}

WAVE_TARGETS = {
  [1] = {
    [POSSIBLE_TARGETS.Kih] = { priority = 3 },
    [POSSIBLE_TARGETS.Hur] = { priority = 1 }
  },
  [2] = {
    [POSSIBLE_TARGETS.Kih] = { priority = 4 },
    [POSSIBLE_TARGETS.Xil] = { priority = 8 },
    [POSSIBLE_TARGETS.Hur] = { priority = 1 },
    [POSSIBLE_TARGETS.Mejkot] = { priority = 2 }
  },
  [3] = {
    [POSSIBLE_TARGETS.Kih] = { priority = 4 },
    [POSSIBLE_TARGETS.Xil] = { priority = 8 },
    [POSSIBLE_TARGETS.Mejkot] = { priority = 8 },
    [POSSIBLE_TARGETS.Hur] = { priority = 1 }
  },
  [4] = { -- igneous wave
    [POSSIBLE_TARGETS.Igneous_Hur] = { priority = 100 }
  },
  [5] = { -- challenge wave
    [POSSIBLE_TARGETS.Volatile_Hur] = { priority = 100 }
  },
  [6] = {
    [POSSIBLE_TARGETS.Jad] = { priority = 20 },
    [POSSIBLE_TARGETS.Kih] = { priority = 6 },
    [POSSIBLE_TARGETS.Xil] = { priority = 12 },
    [POSSIBLE_TARGETS.Mejkot] = { priority = 4 }
  },
  [7] = {
    [POSSIBLE_TARGETS.Kih] = { priority = 10 },
    [POSSIBLE_TARGETS.Xil] = { priority = 15 },
    [POSSIBLE_TARGETS.Mejkot] = { priority = 10 },
    [POSSIBLE_TARGETS.Mej] = { priority = 10 },
    [POSSIBLE_TARGETS.Tok_Xil] = { priority = 25 }
  },
  [8] = {
    [POSSIBLE_TARGETS.Xil] = { priority = 15 },
    [POSSIBLE_TARGETS.Mejkot] = { priority = 8 },
    [POSSIBLE_TARGETS.Mej] = { priority = 5 },
    [POSSIBLE_TARGETS.Tok_Xil] = { priority = 25 }
  },
  [9] = { -- igneous wave
    [POSSIBLE_TARGETS.Igneous_Xil] = { priority = 150 }
  },
  [10] = { -- challenge wave
    [POSSIBLE_TARGETS.Unbreakable] = { priority = 100 }
  },
  [11] = {
    [POSSIBLE_TARGETS.Jad] = { priority = 20 },
    [POSSIBLE_TARGETS.Kih] = { priority = 5 },
    [POSSIBLE_TARGETS.Mej] = { priority = 10 },
    [POSSIBLE_TARGETS.Mejkot] = { priority = 3 }
  },
  [12] = {
    [POSSIBLE_TARGETS.Kih] = { priority = 15 },
    [POSSIBLE_TARGETS.Mej] = { priority = 5 },
    [POSSIBLE_TARGETS.Tok_Xil] = { priority = 25 },
    [POSSIBLE_TARGETS.Zek] = { priority = 30 }
  },
  [13] = {
    [POSSIBLE_TARGETS.Mej] = { priority = 10 },
    [POSSIBLE_TARGETS.Tok_Xil] = { priority = 20 },
    [POSSIBLE_TARGETS.Zek] = { priority = 30 }
  },
  [14] = { -- igneous wave
    [POSSIBLE_TARGETS.Igneous_Mej] = { priority = 100 }
  },
  [15] = { -- challenge wave
    [POSSIBLE_TARGETS.Fatal_1] = { priority = 1 },
    [POSSIBLE_TARGETS.Fatal_2] = { priority = 1 },
    [POSSIBLE_TARGETS.Fatal_3] = { priority = 1 }
  },
  [16] = {
    [POSSIBLE_TARGETS.Jad] = { priority = 10 }
  },
  [17] = {
    [POSSIBLE_TARGETS.Har_Aken] = { priority = 1000 }
  },
  [18] = {
    [POSSIBLE_TARGETS.Igneous_Hur] = { priority = 10 },
    [POSSIBLE_TARGETS.Igneous_Xil] = { priority = 20 },
    [POSSIBLE_TARGETS.Igneous_Mej] = { priority = 30 }
  }
}

local tmp_ids = {}
for _, id in pairs(POSSIBLE_TARGETS) do
  table.insert(tmp_ids, id)
end

ALL_POSSIBLE_TARGET_IDS = tmp_ids


FIGHT_STATE = {
  --- @type AllObject | nil
  target = nil,              -- active target
  --- @type Target_data | nil
  targetInfo = nil,          -- active target info
  wave = 0,                  -- current wave
  isNormalWave = false,      -- normal wave
  isIgneousWave = false,     -- igneous wave
  isJadWave = false,         -- jad wave
  isChallengeWave = false,   -- challenge wave
  isPizzaPhase = false,      -- zuk fight pizza phase
  zukDpsCheckActive = false, -- if we are currently in a 50k dps check for zuk
  --- @type AllObject | nil
  lastClickedTarget = nil,   -- used for moving to igneous Mej domes or pizza phase targets
  movingToTarget = false,    -- used for moving to igneous Mej domes or pizza phase targets
}
---------------------------------------------------------------------
--# END SECTION: Constants used throughout the script
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: Farming loop state tracking
---------------------------------------------------------------------
SCRIPT_PHASE = {
  FIGHTING = "FIGHTING",
  KILL_COMPLETE = "KILL_COMPLETE",
  TELEPORTING = "TELEPORTING",
  AT_WARS = "AT_WARS",
  ENTERING_FIGHT = "ENTERING_FIGHT",
}

WARS_STEP = {
  USE_ALTAR = 1,
  LOAD_PRESET = 2,
  USE_CRYSTAL = 3,
  ENTER_PORTAL = 4,
}

ENTER_STEP = {
  WALK_TO_ZUK = 1,
  CHALLENGE_ZUK = 2,
  HANDLE_INTERFACE = 3,
}

local currentPhase = SCRIPT_PHASE.FIGHTING
local currentWarsStep = WARS_STEP.USE_ALTAR
local currentEnterStep = ENTER_STEP.WALK_TO_ZUK
local killCount = 0
---------------------------------------------------------------------
--# END SECTION: Farming loop state tracking
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: Targeting related functions
---------------------------------------------------------------------
local function areTargetsAlive(targets)
  local npcs = API.GetAllObjArray1(targets, 40, { 1 })
  if #npcs == 0 then
    return false
  end

  for _, npc in ipairs(npcs) do
    if npc.Life > 0 then
      return true
    end
  end

  return false
end

local function extraActionButtonVisible()
  return API.VB_FindPSettinOrder(10254).state == 3
end

local function doExtraActionButton()
  API.logWarn("Clicking extra action button")
  API.DoAction_Interface(0x2e, 0xffffffff, 1, 743, 1, -1, API.OFF_ACT_GeneralInterface_route)
  return API.DoAction_Interface(0x2e, 0xffffffff, 1, 743, 1, -1, API.OFF_ACT_GeneralInterface_route)
end

local function needsTarget()
  local target = API.ReadLpInteracting()
  local targetInfo = API.ReadTargetInfo99(false)
  return (target == nil or
        target.Id == 0)
      and
      (targetInfo == nil or
        (targetInfo.Hitpoints <= 0 and (
          targetInfo.Target_Name:match("^%s*$") or
          targetInfo.Target_Name:gsub("^%s*(.-)%s*$", "%1") == "" or
          targetInfo.Target_Name == "Tap to find target")))
end

local function getHighestPriorityTarget()
  local wave = FIGHT_STATE.wave
  if wave < 1 or wave > 18 then return nil end
  local waveTargets = WAVE_TARGETS[wave]
  local ids = {}
  --- @type AllObject | nil
  local bestTarget = nil
  local bestScore = math.huge -- lowest score is best

  for id, _ in pairs(waveTargets) do
    table.insert(ids, id)
  end

  --- @type AllObject[]
  local npcs = API.GetAllObjArray1(ids, 30, { 1 })

  for _, npc in ipairs(npcs) do
    if npc.Life > 0 then
      local animFactor = npc.Anim > 0 and 2 or 1
      -- score targets based on priority, distance from player, and animation
      local score = npc.Distance / (waveTargets[npc.Id].priority * animFactor)
      if score < bestScore then
        bestScore = score
        bestTarget = npc
      end
    end
  end

  return bestTarget
end

local function currentlyTargeting(targetId, targetName)
  local currentTarget = API.ReadLpInteracting().Id or nil
  local currentTargetName = API.ReadTargetInfo99(false).Target_Name or nil
  return currentTarget == targetId or currentTargetName == targetName
end

local function findNextBestTarget()
  -- Target Zuk if the extra action button is showing
  if extraActionButtonVisible() then
    if FIGHT_STATE.wave == 18 then
      return API.GetAllObjArrayFirst({ ZUK_IDS.FIGHT }, 40, { 1 })
    else
      return API.GetAllObjArrayFirst({ ZUK_IDS.DPS }, 40, { 1 })
    end
  end

  if FIGHT_STATE.wave == 18 then
    local zuk = API.GetAllObjArrayFirst({ ZUK_IDS.FIGHT }, 40, { 1 })
    -- Switch pizza phase targets as they spawn
    if FIGHT_STATE.isPizzaPhase then
      local igneousMej = POSSIBLE_TARGETS.Igneous_Mej
      local igneousHur = POSSIBLE_TARGETS.Igneous_Hur
      local igneousXil = POSSIBLE_TARGETS.Igneous_Xil
      if zuk.Anim == 34505 and areTargetsAlive({ igneousHur, igneousMej, igneousXil }) and needsTarget() then
        return getHighestPriorityTarget()
      end
      if areTargetsAlive({ igneousMej }) and not currentlyTargeting(igneousMej, "Igneous TzekHaar-Mej") then
        return API.GetAllObjArrayFirst({ igneousMej }, 40, { 1 })
      elseif areTargetsAlive({ igneousXil }) and
          not currentlyTargeting(igneousXil, "Igneous TzekHaar-Xil") and
          not areTargetsAlive({ igneousMej }) then
        return API.GetAllObjArrayFirst({ igneousXil }, 40, { 1 })
      elseif areTargetsAlive({ igneousHur }) and
          not currentlyTargeting(igneousHur, "Igneous TzekHaar-Hur") and
          not areTargetsAlive({ igneousMej, igneousXil }) then
        return API.GetAllObjArrayFirst({ igneousHur }, 40, { 1 })
      else
        return nil
      end
    end
    return zuk
  end

  -- Target Har Aken if surfaced, otherwise build adren off zuk
  if FIGHT_STATE.wave == 17 then
    if areTargetsAlive({ POSSIBLE_TARGETS.Har_Aken }) then
      return API.GetAllObjArrayFirst({ POSSIBLE_TARGETS.Har_Aken }, 40, { 1 })
    elseif areTargetsAlive({ 28530, 28531 }) and not areTargetsAlive({ POSSIBLE_TARGETS.Har_Aken }) then
      return API.GetAllObjArrayFirst({ ZUK_IDS.DPS }, 40, { 1 })
    end
  end

  -- Target the highest priority target for most waves
  return getHighestPriorityTarget()
end

--- @param target AllObject | nil
local function attackTarget(target)
  if target ~= nil then
    if API.DoAction_NPC__Direct(0x2a, API.OFF_ACT_AttackNPC_route, target) then
      API.logWarn("Attacking target " .. target.Name .. " with ID " .. target.Id)
    end
    API.RandomSleep2(600, 300, 300)
    return true
  end
  return false
end

local function shouldStopTargetingZuk()
  if (FIGHT_STATE.target ~= nil and FIGHT_STATE.target.Id == ZUK_IDS.DPS) or
      (FIGHT_STATE.targetInfo ~= nil and FIGHT_STATE.targetInfo.Target_Name == "TzKal-Zuk") then
    return (FIGHT_STATE.isChallengeWave and areTargetsAlive(ALL_POSSIBLE_TARGET_IDS)) or
        (FIGHT_STATE.wave == 17 and areTargetsAlive({ POSSIBLE_TARGETS.Har_Aken })) or
        areTargetsAlive({ POSSIBLE_TARGETS.Igneous_Hur, POSSIBLE_TARGETS.Igneous_Mej, POSSIBLE_TARGETS.Igneous_Xil })
  end
end

local function shouldStopTargetingAken()
  if (FIGHT_STATE.target ~= nil and FIGHT_STATE.target.Id == POSSIBLE_TARGETS.Har_Aken) or
      (FIGHT_STATE.targetInfo ~= nil and FIGHT_STATE.targetInfo.Target_Name == "TzekHaar-Aken") then
    return areTargetsAlive({ 28530, 28531 }) and not areTargetsAlive({ POSSIBLE_TARGETS.Har_Aken })
  end
end

local function needsNewTarget()
  return needsTarget() or shouldStopTargetingZuk() or shouldStopTargetingAken()
end

--- @param target AllObject | nil
local function needToBeNextToTarget(target)
  if target == nil then return false end
  return target.Id == POSSIBLE_TARGETS.Igneous_Mej or
      (FIGHT_STATE.isPizzaPhase and
        (target.Id == POSSIBLE_TARGETS.Igneous_Hur or
          target.Id == POSSIBLE_TARGETS.Igneous_Xil))
end

--- @param target AllObject | nil
local function moveWithinAreaOfTarget(target)
  if target == nil then return end
  if FIGHT_STATE.lastClickedTarget ~= nil and
      FIGHT_STATE.lastClickedTarget.Unique_Id == target.Unique_Id then
    return
  end
  --- @type WPOINT
  local targetTile = WPOINT.new(math.floor(target.Tile_XYZ.x), math.floor(target.Tile_XYZ.y), 0)
  local tile = WPOINT.new(targetTile.x + math.random(-2, 2), targetTile.y + math.random(-2, 2), 0)
  if target.Distance > 10 then
    if API.DoAction_NPC__Direct(0x2a, API.OFF_ACT_AttackNPC_route, target) then
      API.RandomSleep2(1000, 200, 200)
      if API.DoAction_Ability_check("Surge", 1, API.OFF_ACT_GeneralInterface_route, true, true, true) then
        API.RandomSleep2(300, 200, 200)
        API.DoAction_Tile(tile)
      else
        API.RandomSleep2(300, 200, 200)
        API.DoAction_Tile(tile)
      end
    end
  else
    if API.DoAction_Tile(tile) then
      API.RandomSleep2(600, 200, 200)
    end
  end
  FIGHT_STATE.lastClickedTarget = target
  FIGHT_STATE.movingToTarget = true
end

local function withinAttackRange()
  local target = FIGHT_STATE.target
  if target ~= nil then
    local distance = API.Dist_FLP(target.Tile_XYZ)
    if distance <= 8 then
      return true
    end
  end
  return false
end

--- Potentially good target to activate death skulls or threads on
--- @param minTargets number
--- @param maxDist? number
--- @return boolean
local function worthSkullingOrThreading(minTargets, maxDist)
  maxDist = maxDist or 6
  local currTarget = FIGHT_STATE.target
  if currTarget == nil or currTarget.Id <= 0 then
    return false
  end
  local numTargets = 0
  --- @type AllObject[]
  local targets = API.GetAllObjArray1(ALL_POSSIBLE_TARGET_IDS, 40, { 1 })

  for _, target in ipairs(targets) do
    if target.Life > 0 and (API.Math_DistanceA(currTarget, target) / 512) <= maxDist then
      numTargets = numTargets + 1
    end
  end

  return numTargets >= minTargets
end

--- @param target AllObject | nil
--- @param range? number
local function surgeAttackTarget(target, range)
  range = range or 16
  if target ~= nil then
    if target.Distance > range then
      if attackTarget(target) then
        API.RandomSleep2(1000, 200, 200)
        if API.DoAction_Ability_check("Surge", 1, API.OFF_ACT_GeneralInterface_route, true, true, true) then
          API.RandomSleep2(300, 200, 200)
          return attackTarget(target)
        end
      end
    else
      return attackTarget(target)
    end
  end
end
---------------------------------------------------------------------
--# END SECTION: Targeting related functions
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: Buff helper functions
---------------------------------------------------------------------

--- Source: https://github.com/sonsonmagro/Sonsons-Rasial/blob/main/core/player_manager.lua#L437
--- Checks if the player has a specific buff
--- @param buffId number
--- @return {found: boolean, remaining: number}
local function getBuff(buffId)
  local buff = API.Buffbar_GetIDstatus(buffId, false)
  return { found = buff.found, remaining = (buff.found and API.Bbar_ConvToSeconds(buff)) or 0 }
end

--- Source: https://github.com/sonsonmagro/Sonsons-Rasial/blob/main/core/player_manager.lua#L445
--- Checks if the player has a specific debuff
--- @param debuffId number
--- @return {found: boolean, remaining: number}
local function getDebuff(debuffId)
  local debuff = API.DeBuffbar_GetIDstatus(debuffId, false)
  return { found = debuff.found or false, remaining = (debuff.found and API.Bbar_ConvToSeconds(debuff)) or 0 }
end

local function targetBloated()
  return API.VB_FindPSettinOrder(11303).state >> 5 & 0x1 == 1
end

local function targetVulned()
  return API.VB_FindPSettinOrder(896).state >> 29 & 0x1 == 1
end

local function targetDeathMarked()
  return API.VB_FindPSettinOrder(11303).state >> 7 & 0x1 == 1
end

local function invokeDeathActive()
  return getBuff(30100).found
end

local function inThreadsRotation()
  return API.Buffbar_GetIDstatus(30129, false).found
end

local function specAttackOnCooldown()
  return API.DeBuffbar_GetIDstatus(55524, false).found
end

local function necrosisStacks()
  return getBuff(30101).remaining or 0
end

local function soulStacks()
  return getBuff(30123).remaining or 0
end

local function onCooldown(abilityName)
  return API.GetABs_name(abilityName, true).cooldown_timer > 0
end

local function targetStunnedOrBound()
  return (API.VB_FindPSett(896).state >> 0 & 0x1 == 1) or
      (API.VB_FindPSett(896).state >> 1 & 0x1 == 1)
end

local function deathSkullsActive()
  return #API.GetAllObjArray1({ 7882 }, 12, { 5 }) > 0
end

local function zukStartFightAnimation()
  local zuk = API.GetAllObjArrayFirst({ ZUK_IDS.FIGHT }, 30, { 1 })
  return zuk ~= nil and ((zuk.Anim == 34518 or zuk.Anim == 34494) or zuk.Tile_XYZ.y > ARENA_MAX_Y)
end

local function getZukDpsCheckActive()
  local zuk = API.GetAllObjArrayFirst({ ZUK_IDS.DPS }, 30, { 1 })
  return zuk ~= nil and zuk.Anim == 34516
end

local function isPizzaPhaseActive()
  local zuk = API.GetAllObjArrayFirst({ ZUK_IDS.FIGHT }, 40, { 1 })
  return zuk.Anim == 34495 or zuk.Anim == 34501 or
      zuk.Anim == 34502 or zuk.Anim == 34505
end
---------------------------------------------------------------------
--# END SECTION: Buff helper functions
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: Using abilities and applying buffs
---------------------------------------------------------------------
--- @param abilityName string
--- @return boolean
local function useAbility(abilityName)
  if not API.Read_LoopyLoop() then return false end
  if needsNewTarget() then return false end
  local ability = API.GetABs_name(abilityName, true)
  if not ability or
      ability.enabled == false or
      ability.slot <= 0 or
      ability.cooldown_timer > 1 then
    return false
  end
  local stateTmp = API.VB_FindPSettinOrder(4501).state
  if API.DoAction_Ability(abilityName, 1, API.OFF_ACT_GeneralInterface_route, true) then
    local start = os.clock()
    local successful = true
    while LAST_GCD_STATE == stateTmp do
      local elapsed = os.clock() - start
      if elapsed >= 0.6 then
        successful = false
        break
      end
      LAST_GCD_STATE = API.VB_FindPSettinOrder(4501).state
      if LAST_GCD_STATE ~= stateTmp then
        successful = true
        break
      end
      API.RandomSleep2(5, 0, 0)
    end
    if not successful then
      API.logDebug("Failed to cast ability " .. abilityName .. ", recasting")
      return useAbility(abilityName)
    end
    local now = os.clock()
    local tickCasted = API.Get_tick()
    API.logDebug(string.format(
      "[CASTING] Successfully cast ability (%s) | DeltaT: %.5f s | Tick: %s",
      abilityName,
      now - LAST_CAST, tickCasted))
    LAST_CAST = now
    LAST_GCD_STATE = API.VB_FindPSettinOrder(4501).state
    TIMER:createSleep(TIMERS.GCD.name, TIMERS.GCD.duration)
    return true
  end
  API.logWarn(string.format("[CASTING] Failed to use ability (%s)", abilityName))
  return false
end

local function manageBuffs()
  if not TIMER:shouldRun(TIMERS.Buffs.name) then return end

  local prayer = API.GetPray_()
  local hp = API.GetHP_()
  local overload = getBuff(OVERLOAD_BUFF_ID)
  local necroPrayer = getBuff(NECRO_PRAYER_BUFF_ID)
  local bookActive = false
  if USE_BOOK then
    for _, id in ipairs(SCRIPTURE_BUFF_IDS) do
      if getBuff(id).found then bookActive = true break end
    end
  end
  local poison = getBuff(30095)
  local darkness = getBuff(30122)
  local boneShield = API.GetABs_name("Greater Bone Shield", true)

  if boneShield.action == "Activate" then
    if useAbility("Greater Bone Shield") then
      API.RandomSleep2(300, 200, 200)
    end
  end

  if USE_EXCAL and TIMER:shouldRun(TIMERS.Excal.name) then
    local excalOnCooldown = getDebuff(14632).found
    if not excalOnCooldown and API.GetHP_() < math.random(5500, 7500) then
      if API.DoAction_Inventory3("Excalibur", 0, 1, API.OFF_ACT_GeneralInterface_route) then
        TIMER:createSleep(TIMERS.Excal.name, TIMERS.Excal.duration)
      end
    end
  end

  if USE_ELVEN_SHARD and TIMER:shouldRun(TIMERS.Elven.name) then
    local shardOnCooldown = getDebuff(43358).found
    if not shardOnCooldown and API.GetPray_() < math.random(500, 700) then
      if API.DoAction_Inventory3("elven ritual shard", 0, 1, API.OFF_ACT_GeneralInterface_route) then
        TIMER:createSleep(TIMERS.Elven.name, TIMERS.Elven.duration)
      end
    end
  end

  if hp < math.random(2500, 5000) then
    if API.DoAction_Ability_check(FOOD_NAME, 1, API.OFF_ACT_GeneralInterface_route, true, true, false) then
      API.RandomSleep2(60, 10, 10)
      if BREW_NAME ~= "" and Inventory:InvItemcount_String(BREW_NAME) > 0 then
        API.DoAction_Inventory3(BREW_NAME, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(60, 10, 10)
      end
      API.DoAction_Ability_check(FOOD_POT_NAME, 1, API.OFF_ACT_GeneralInterface_route, true, true, false)
    end
  end

  if not darkness.found or (darkness.found and darkness.remaining <= math.random(10, 120)) then
    if useAbility("Darkness") then
      API.RandomSleep2(300, 200, 200)
    end
  end

  if prayer < math.random(200, 400) or API.GetSkillsTableSkill(6) < 99 then
    if API.DoAction_Inventory3(RESTORE_NAME, 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
    end
  end

  if not overload.found or (overload.found and overload.remaining > 1 and overload.remaining < math.random(30)) then
    if API.DoAction_Inventory3(OVERLOAD_NAME, 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
    end
  end

  if USE_POISON and not poison.found or (poison.found and poison.remaining > 1 and poison.remaining < math.random(30)) then
    if API.DoAction_Inventory3("Weapon poison", 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
    end
  end

  if not necroPrayer.found and prayer > 50 then
    if API.DoAction_Ability(NECRO_PRAYER_NAME, 1, API.OFF_ACT_GeneralInterface_route, true) then
      API.RandomSleep2(300, 200, 200)
    end
  end

  if USE_BOOK and not bookActive then
    if API.DoAction_Ability(BOOK_NAME, 1, API.OFF_ACT_GeneralInterface_route, true) then
      API.RandomSleep2(300, 200, 200)
    end
  end

  TIMER:createSleep(TIMERS.Buffs.name, TIMERS.Buffs.duration)
end
---------------------------------------------------------------------
--# END SECTION: Using abilities and applying buffs
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: Combat rotations
---------------------------------------------------------------------
local function buildAdrenRotationBeforeZuk()
  if Inventory:Contains(RING_SWITCH) then
    if Inventory:Equip(RING_SWITCH) then
      API.RandomSleep2(400, 200, 50)
      return
    end
  end

  if not targetDeathMarked() and not invokeDeathActive() then
    if useAbility("Invoke Death") then return end
  end

  if useAbility("Conjure Undead Army") then return end
  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function buildAdrenRotation()
  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function waveClearRotation()
  if not targetDeathMarked() and not invokeDeathActive() and
      API.ReadTargetInfo99(false).Hitpoints >= 20000 then
    if useAbility("Invoke Death") then return end
  end

  if worthSkullingOrThreading(2, 4) and not deathSkullsActive() and
      soulStacks() >= 2 then
    if useAbility("Threads of Fate") then return end
  end

  if worthSkullingOrThreading(3) and HAS_ZUK_CAPE then
    if useAbility("Death Skulls") then return end
  end

  if FIGHT_STATE.targetInfo.Hitpoints >= 20000 and not targetBloated() then
    if useAbility("Bloat") then return end
  end

  if FIGHT_STATE.targetInfo.Hitpoints >= 10000 and soulStacks() >= 3 then
    if useAbility("Volley of Souls") then return end
  end

  if FIGHT_STATE.targetInfo.Hitpoints >= 10000 and necrosisStacks() >= 6 then
    if useAbility("Finger of Death") then return end
  end

  if FIGHT_STATE.targetInfo.Hitpoints >= 10000 and necrosisStacks() >= 1 and
      necrosisStacks() <= 5 and not specAttackOnCooldown() then
    if useAbility("Weapon Special Attack") then return end
  end

  if useAbility("Conjure Undead Army") then return end
  if useAbility("Command Vengeful Ghost") then return end
  if useAbility("Command Skeleton Warrior") then return end
  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function threadsRotation()
  if not inThreadsRotation() then
    if useAbility("Threads of Fate") then return end
  end

  if soulStacks() >= 2 then
    if useAbility("Volley of Souls") then return end
  end

  if necrosisStacks() >= 1 and
      necrosisStacks() <= 5 and not specAttackOnCooldown() then
    if useAbility("Weapon Special Attack") then return end
  end

  if useAbility("Soul Sap") then return end

  if necrosisStacks() >= 6 then
    if useAbility("Finger of Death") then return end
  end

  if useAbility("Command Vengeful Ghost") then return end
  if useAbility("Command Skeleton Warrior") then return end
  if useAbility("Touch of Death") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function stunRotation()
  if not targetDeathMarked() and not invokeDeathActive() and
      API.ReadTargetInfo99(false).Hitpoints >= 20000 then
    if useAbility("Invoke Death") then return end
  end

  if not specAttackOnCooldown() and not targetStunnedOrBound() then
    if useAbility("Weapon Special Attack") then return end
  end

  if not targetStunnedOrBound() then
    if useAbility("Soul Strike") then return end
  end

  if not targetStunnedOrBound() then
    if useAbility("Soul Sap") then return end
  end

  if not targetBloated() then
    if useAbility("Bloat") then return end
  end

  if necrosisStacks() >= 4 then
    if useAbility("Finger of Death") then return end
  end

  if useAbility("Command Vengeful Ghost") then return end
  if useAbility("Command Skeleton Warrior") then return end
  if useAbility("Touch of Death") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function thresholdRotation()
  if not targetDeathMarked() and not invokeDeathActive() and
      API.ReadTargetInfo99(false).Hitpoints >= 20000 then
    if useAbility("Invoke Death") then return end
  end

  if not targetBloated() then
    if useAbility("Bloat") then return end
  end

  if necrosisStacks() >= 6 then
    if useAbility("Finger of Death") then return end
  end

  if necrosisStacks() >= 4 and not targetBloated() then
    if useAbility("Finger of Death") then return end
  end

  if FIGHT_STATE.targetInfo.Hitpoints > 20000 and
      not targetBloated() then
    if useAbility("Spectral Scythe") then return end
  end

  if FIGHT_STATE.targetInfo.Hitpoints > 5000 and
      necrosisStacks() >= 1 and necrosisStacks() <= 5 and
      not specAttackOnCooldown() then
    if useAbility("Weapon Special Attack") then return end
  end

  if soulStacks() >= 2 then
    if useAbility("Volley of Souls") then return end
  end

  if useAbility("Conjure Undead Army") then return end
  if useAbility("Command Vengeful Ghost") then return end
  if useAbility("Command Skeleton Warrior") then return end
  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function challenge2Rotation()
  if not targetVulned() and TIMER:shouldRun(TIMERS.Vuln.name) then
    if Inventory:Contains("Vulnerability bomb") then
      if API.DoAction_Inventory3("Vulnerability bomb", 0, 1, API.OFF_ACT_GeneralInterface_route) then
        API.RandomSleep2(300, 200, 200)
        TIMER:createSleep(TIMERS.Vuln.name, TIMERS.Vuln.duration)
        return
      end
    end
  end

  if API.GetAdrenalineFromInterface() < 60 and not getDebuff(26094).found then
    if API.DoAction_Inventory3(ADREN_POT_NAME, 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
      return
    end
  end

  if not targetDeathMarked() and not invokeDeathActive() then
    if useAbility("Invoke Death") then return end
  end

  if useAbility("Death Skulls") then return end

  if necrosisStacks() >= 6 then
    if useAbility("Finger of Death") then return end
  end

  if soulStacks() >= 3 then
    if useAbility("Volley of Souls") then return end
  end

  if not specAttackOnCooldown() then
    if useAbility("Weapon Special Attack") then return end
  end

  if useAbility("Finger of Death") then return end

  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function challenge3Rotation()
  if API.GetAdrenalineFromInterface() < 100 and not getDebuff(26094).found then
    if API.DoAction_Inventory3(ADREN_POT_NAME, 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
      return
    end
  end

  -- Use barricade if devotion/resonance are not active
  if not getBuff(14222).found and onCooldown("Devotion") then
    if useAbility("Barricade") then return end
  end

  -- Use resonance if barricade/devotion not active
  if not getBuff(14228).found and not getBuff(21665).found then
    if useAbility("Resonance") then return end
  end

  -- Use devotion if barricade/resonance not active
  if not getBuff(14222).found and not getBuff(14228).found then
    if useAbility("Devotion") then return end
  end

  -- Use powerburst if devotion/resonance are not active and barricade didn't trigger
  if not getBuff(14222).found and onCooldown("Devotion") and
      not getBuff(14228).found and not getDebuff(48960).found then
    if API.DoAction_Inventory3("Powerburst of vitality", 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
      return
    end
  end

  -- Otherwise build adren off fatals
  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function zukDpsCheckRotation()
  if Inventory:Contains(RING_SWITCH) then
    if Inventory:Equip(RING_SWITCH) then
      API.RandomSleep2(500, 200, 50)
      return
    end
  end

  if not targetVulned() and TIMER:shouldRun(TIMERS.Vuln.name) then
    if Inventory:Contains("Vulnerability bomb") then
      if API.DoAction_Inventory3("Vulnerability bomb", 0, 1, API.OFF_ACT_GeneralInterface_route) then
        API.RandomSleep2(300, 200, 200)
        TIMER:createSleep(TIMERS.Vuln.name, TIMERS.Vuln.duration)
        return
      end
    end
  end

  if useAbility("Death Skulls") then return end

  if soulStacks() >= 3 then
    if useAbility("Volley of Souls") then return end
  end

  if necrosisStacks() >= 6 and not deathSkullsActive() then
    if useAbility("Finger of Death") then return end
  end

  if not targetBloated() and not deathSkullsActive() then
    if useAbility("Bloat") then return end
  end

  if not specAttackOnCooldown() and not deathSkullsActive() then
    if useAbility("Weapon Special Attack") then return end
  end

  if useAbility("Command Vengeful Ghost") then return end
  if useAbility("Command Skeleton Warrior") then return end
  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function zukFightRotation()
  local zuk = API.GetAllObjArrayFirst({ ZUK_IDS.FIGHT }, 30, { 1 })

  if getDebuff(30096).found or getDebuff(26103).found then -- geothermal burn or stunn
    if useAbility("Freedom") then return end
  end

  if zuk.Anim == 34499 then
    if useAbility("Resonance") then return end
  end

  if zuk.Anim == 34493 then
    if useAbility("Anticipation") then return end
  end

  if not targetVulned() and TIMER:shouldRun(TIMERS.Vuln.name) then
    if Inventory:Contains("Vulnerability bomb") then
      if API.DoAction_Inventory3("Vulnerability bomb", 0, 1, API.OFF_ACT_GeneralInterface_route) then
        TIMER:createSleep(TIMERS.Vuln.name, TIMERS.Vuln.duration)
        return
      end
    end
  end

  if API.GetAdrenalineFromInterface() < 60 and not getDebuff(26094).found then
    if API.DoAction_Inventory3(ADREN_POT_NAME, 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
      return
    end
  end

  if not targetDeathMarked() and not invokeDeathActive() then
    if useAbility("Invoke Death") then return end
  end

  if useAbility("Living Death") then return end
  if useAbility("Death Skulls") then return end

  if not targetBloated() and onCooldown("Living Death") then
    if useAbility("Bloat") then return end
  end

  if necrosisStacks() >= 6 and onCooldown("Living Death") then
    if useAbility("Finger of Death") then return end
  end

  if soulStacks() >= 3 and onCooldown("Living Death") then
    if useAbility("Volley of Souls") then return end
  end

  if not specAttackOnCooldown() and onCooldown("Living Death")
      and necrosisStacks() >= 1 and necrosisStacks() <= 5 then
    if useAbility("Weapon Special Attack") then return end
  end

  if useAbility("Conjure Undead Army") then return end
  if useAbility("Command Vengeful Ghost") then return end
  if useAbility("Command Skeleton Warrior") then return end
  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function harAkenRotation()
  if not targetVulned() and TIMER:shouldRun(TIMERS.Vuln.name) then
    if Inventory:Contains("Vulnerability bomb") then
      if API.DoAction_Inventory3("Vulnerability bomb", 0, 1, API.OFF_ACT_GeneralInterface_route) then
        TIMER:createSleep(TIMERS.Vuln.name, TIMERS.Vuln.duration)
        return
      end
    end
  end

  if API.GetAdrenalineFromInterface() < 60 and not getDebuff(26094).found then
    if API.DoAction_Inventory3(ADREN_POT_NAME, 0, 1, API.OFF_ACT_GeneralInterface_route) then
      API.RandomSleep2(300, 200, 200)
      return
    end
  end

  if not targetDeathMarked() and not invokeDeathActive() then
    if useAbility("Invoke Death") then return end
  end

  if useAbility("Split Soul") then return end

  if FIGHT_STATE.targetInfo.Hitpoints > 60000 then
    if useAbility("Death Skulls") then return end
  end

  if not targetBloated() then
    if useAbility("Bloat") then return end
  end

  if necrosisStacks() >= 6 then
    if useAbility("Finger of Death") then return end
  end

  if soulStacks() >= 3 then
    if useAbility("Volley of Souls") then return end
  end

  if not specAttackOnCooldown() and necrosisStacks() >= 1 and necrosisStacks() <= 5 then
    if useAbility("Weapon Special Attack") then return end
  end

  if useAbility("Conjure Undead Army") then return end
  if useAbility("Command Vengeful Ghost") then return end
  if useAbility("Command Skeleton Warrior") then return end
  if useAbility("Touch of Death") then return end
  if useAbility("Soul Sap") then return end
  if useAbility("Basic<nbsp>Attack") then return end
end

local function doRotation()
  if not TIMER:shouldRun(TIMERS.GCD.name) then return end

  if inThreadsRotation() then
    return threadsRotation()
  elseif FIGHT_STATE.wave == 18 then
    if FIGHT_STATE.isPizzaPhase then
      if areTargetsAlive({ POSSIBLE_TARGETS.Igneous_Xil, POSSIBLE_TARGETS.Igneous_Mej }) then
        return thresholdRotation()
      elseif areTargetsAlive({ POSSIBLE_TARGETS.Igneous_Hur }) then
        return stunRotation()
      else
        return zukFightRotation()
      end
    elseif zukStartFightAnimation() then
      return buildAdrenRotationBeforeZuk()
    else
      return zukFightRotation()
    end
  elseif FIGHT_STATE.wave == 17 then
    if areTargetsAlive({ POSSIBLE_TARGETS.Har_Aken }) then
      return harAkenRotation()
    else
      return buildAdrenRotation()
    end
  elseif FIGHT_STATE.isIgneousWave then
    if areTargetsAlive({ POSSIBLE_TARGETS.Igneous_Hur }) then
      return stunRotation()
    elseif areTargetsAlive({ POSSIBLE_TARGETS.Igneous_Xil, POSSIBLE_TARGETS.Igneous_Mej }) then
      return thresholdRotation()
    elseif extraActionButtonVisible() then
      return buildAdrenRotation()
    elseif FIGHT_STATE.zukDpsCheckActive then
      return zukDpsCheckRotation()
    else
      return buildAdrenRotation()
    end
  elseif areTargetsAlive({ POSSIBLE_TARGETS.Volatile_Hur }) then -- Challenge wave 1
    return threadsRotation()
  elseif areTargetsAlive({ POSSIBLE_TARGETS.Unbreakable }) then  -- Challenge wave 2
    return challenge2Rotation()
  elseif areTargetsAlive({ POSSIBLE_TARGETS.Fatal_1 }) then      -- Challenge wave 3
    return challenge3Rotation()
  elseif FIGHT_STATE.isNormalWave or FIGHT_STATE.isJadWave then
    return waveClearRotation()
  end
end
---------------------------------------------------------------------
--# END SECTION: Combat rotations
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: What to pray and when
---------------------------------------------------------------------
--- @type PrayerConfig
local PRAYER_CONFIG = {
  defaultPrayer = PrayerFlicker.CURSES.SOUL_SPLIT,
  threats = {
    {
      name = "Meleers alive",
      type = "Conditional",
      prayer = PrayerFlicker.CURSES.DEFLECT_MELEE,
      condition = function()
        return areTargetsAlive({ POSSIBLE_TARGETS.Hur, POSSIBLE_TARGETS.Igneous_Hur,
          POSSIBLE_TARGETS.Kih, POSSIBLE_TARGETS.Mejkot, POSSIBLE_TARGETS.Unbreakable })
      end,
      priority = 1,
      duration = 1,
      delay = 0
    },
    {
      name = "Basic Magers alive",
      type = "Conditional",
      prayer = PrayerFlicker.CURSES.DEFLECT_MAGIC,
      condition = function()
        return areTargetsAlive({ POSSIBLE_TARGETS.Mej })
      end,
      priority = 3,
      duration = 1,
      delay = 0
    },
    {
      name = "Tier 2 Magers alive",
      type = "Conditional",
      prayer = PrayerFlicker.CURSES.DEFLECT_MAGIC,
      condition = function()
        return areTargetsAlive({ POSSIBLE_TARGETS.Zek })
      end,
      priority = 6,
      duration = 1,
      delay = 0
    },
    {
      name = "Rangers alive",
      type = "Conditional",
      prayer = PrayerFlicker.CURSES.DEFLECT_RANGED,
      condition = function()
        return areTargetsAlive({ POSSIBLE_TARGETS.Xil, POSSIBLE_TARGETS.Tok_Xil,
          POSSIBLE_TARGETS.Igneous_Xil })
      end,
      priority = 5,
      duration = 1,
      delay = 0
    },
    {
      name = "Jad ranged attack",
      type = "Animation",
      range = 40,
      prayer = PrayerFlicker.CURSES.DEFLECT_RANGED,
      npcId = POSSIBLE_TARGETS.Jad,
      id = 16202,
      priority = 11,
      delay = 0,
      duration = 2
    },
    {
      name = "Jad magic attack",
      type = "Animation",
      range = 40,
      prayer = PrayerFlicker.CURSES.DEFLECT_MAGIC,
      npcId = POSSIBLE_TARGETS.Jad,
      id = 16195,
      priority = 10,
      delay = 0,
      duration = 2
    },
    {
      name = "Jad melee attack",
      type = "Animation",
      range = 40,
      prayer = PrayerFlicker.CURSES.DEFLECT_MELEE,
      npcId = POSSIBLE_TARGETS.Jad,
      id = 16204,
      priority = 15,
      delay = 0,
      duration = 1
    },
    {
      name = "Zuk melee attack",
      type = "Animation",
      range = 40,
      prayer = PrayerFlicker.CURSES.DEFLECT_MELEE,
      npcId = ZUK_IDS.FIGHT,
      id = { 34496, 34497, 34498 },
      priority = 100,
      delay = 0,
      duration = 1
    },
    {
      name = "Zuk mage attack/damage",
      type = "Animation",
      range = 40,
      prayer = PrayerFlicker.CURSES.DEFLECT_MAGIC,
      npcId = ZUK_IDS.FIGHT,
      id = { 34501, 34499 },
      priority = 200,
      delay = 0,
      duration = 1
    },
    {
      name = "Fatal challenge range attack",
      type = "Projectile",
      range = 10,
      prayer = PrayerFlicker.CURSES.DEFLECT_RANGED,
      id = 7603,
      priority = 10,
      delay = 1,
      duration = 1
    },
    {
      name = "Fatal challenge magic attack",
      type = "Projectile",
      range = 10,
      prayer = PrayerFlicker.CURSES.DEFLECT_MAGIC,
      id = 7602,
      priority = 10,
      delay = 1,
      duration = 1
    }
  }
}
---------------------------------------------------------------------
--# END SECTION: What to pray and when
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: General fight stuff
---------------------------------------------------------------------
local function findArenaCoords()
  --- @type AllObject | nil
  local zuk = API.GetAllObjArrayFirst({ ZUK_IDS.DPS }, 40, { 1 })
  if zuk ~= nil then
    local zukX = math.floor(zuk.Tile_XYZ.x)
    local zukY = math.floor(zuk.Tile_XYZ.y)
    print("Finding arena coords for " .. tostring(zukX) .. ", " .. tostring(zukY))
    SAFESPOT_JAD = WPOINT.new(zukX - 8, zukY - 14, 0)
    SAFESPOT_NORMAL = WPOINT.new(zukX + 9, zukY - 21, 0)
    ARENA_MIN_X = zukX - 15
    ARENA_MAX_X = zukX + 15
    ARENA_MAX_Y = zukY - 4
    ARENA_MIN_Y = zukY - 35
    return true
  end
  return false
end

--- @param safespot WPOINT
local function goToSafespot(safespot)
  local playerPos = API.PlayerCoord()
  if playerPos.x == safespot.x and playerPos.y == safespot.y then
    return
  end
  if API.DoAction_Tile(safespot) then
    API.RandomSleep2(600, 200, 200)
    if API.Dist_FLPW(safespot) > 12 then
      if API.DoAction_Ability_check("Surge", 1, API.OFF_ACT_GeneralInterface_route, true, true, true) then
        API.RandomSleep2(600, 200, 200)
        API.DoAction_Tile(safespot)
      end
    end
    API.WaitUntilMovingEnds(4, 2)
  end
end

--- @param zuk AllObject
local function standingOnQuakeSpot(zuk)
  --- @type AllObject[]
  local quakeSpots = API.GetAllObjArray1({ 7450 }, 20, { 4 })
  local quakeCoords = {}
  if #quakeSpots == 0 then
    return nil
  end
  for _, spot in ipairs(quakeSpots) do
    table.insert(quakeCoords, spot.Tile_XYZ)
  end
  local safeTiles = API.Math_FreeTiles(quakeCoords, 2, 10, { zuk.Tile_XYZ }, true)
  if #safeTiles > 0 then
    return safeTiles[1]
  end
  return nil
end

local function standingOnLavaBlob()
  local blockedTileIds = { 121912, 121913, 121914, 121915, 121916, 121917, 121918 }
  --- @type AllObject[]
  local blockedTiles = API.GetAllObjArray1(blockedTileIds, 5, { 12 })
  --- @type AllObject[]
  local blobs = API.GetAllObjArray1({ 7585 }, 5, { 4 })
  if #blobs == 0 then
    return nil
  end
  local blobCoords = {}
  local blockedCoords = {}
  for _, spot in ipairs(blobs) do
    table.insert(blobCoords, spot.Tile_XYZ)
  end
  for _, spot in ipairs(blockedTiles) do
    table.insert(blockedCoords, spot.Tile_XYZ)
  end
  local safeTiles = API.Math_FreeTiles(blobCoords, 1, 8, blockedCoords, false)
  if #safeTiles == 0 then
    return nil
  else
    for _, tile in ipairs(safeTiles) do
      local tileX = math.floor(tile.x)
      local tileY = math.floor(tile.y)
      if tileX >= ARENA_MIN_X and tileX <= ARENA_MAX_X and tileY >= ARENA_MIN_Y and tileY <= ARENA_MAX_Y then
        return tile
      end
    end
  end
end

local function getCurrentWave()
  local wave = API.VB_FindPSettinOrder(10949).state + 1
  --- Weirdly, the wave is 0-indexed in the game, so we need to add 1 to it
  --- Also, it switches from 0 to -1 at start of instance, so we need to check for that too
  if wave > 0 then
    return wave
  else
    return 1
  end
end

-- Place to execute logic when the wave changes
local function onWaveChange(newWave)
  if newWave ~= 18 then
    if Inventory:Contains(23643) then -- equip tokkul zo ring if not equipped
      Inventory:Equip(23643)
      API.RandomSleep2(300, 100, 50)
    end
  end
end

local function updateFightState()
  local currWave = getCurrentWave()
  if FIGHT_STATE.wave ~= currWave then
    onWaveChange(currWave)
  end
  FIGHT_STATE.wave = currWave
  FIGHT_STATE.target = API.ReadLpInteracting()
  FIGHT_STATE.targetInfo = API.ReadTargetInfo99(false)
  FIGHT_STATE.isNormalWave = REGULAR_WAVES[currWave] or false
  FIGHT_STATE.isIgneousWave = IGNEOUS_WAVES[currWave] or false
  FIGHT_STATE.isJadWave = JAD_WAVES[currWave] or false
  FIGHT_STATE.isChallengeWave = CHALLENGE_WAVES[currWave] or false
  FIGHT_STATE.zukDpsCheckActive = getZukDpsCheckActive()
  FIGHT_STATE.isPizzaPhase = isPizzaPhaseActive()
end
---------------------------------------------------------------------
--# END SECTION: General fight stuff
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: War's Retreat farming loop functions
---------------------------------------------------------------------
local function isAtWarsRetreat()
  local pos = API.PlayerCoord()
  return math.abs(pos.x - 3295) <= 30 and math.abs(pos.y - 10137) <= 30
end

local function teleportToWarsRetreat()
  API.logWarn("Teleporting to War's Retreat")
  return API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route, true)
end

local function loadLastPresetFromBank()
  API.logWarn("Loading last preset from bank")
  return Interact:Object("Bank chest", "Load Last Preset from", 30)
end

local function useAltarOfWar()
  API.logWarn("Praying at Altar of War")
  return Interact:Object("Altar of War", "Pray", 30)
end

local function useAdrenalineCrystal()
  API.logWarn("Channeling Adrenaline crystal")
  return Interact:Object("Adrenaline crystal", "Channel", 30)
end

local function enterBossPortal()
  API.logWarn("Entering Zuk boss portal")
  return API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, { 122070 }, 50)
end

local function resetForNewKill()
  API.logWarn("Resetting fight state for new kill")
  SAFESPOT_JAD = nil
  SAFESPOT_NORMAL = nil
  ARENA_MIN_X = math.mininteger
  ARENA_MAX_X = math.maxinteger
  ARENA_MIN_Y = math.mininteger
  ARENA_MAX_Y = math.maxinteger
  FIGHT_STATE.target = nil
  FIGHT_STATE.targetInfo = nil
  FIGHT_STATE.wave = 0
  FIGHT_STATE.isNormalWave = false
  FIGHT_STATE.isIgneousWave = false
  FIGHT_STATE.isJadWave = false
  FIGHT_STATE.isChallengeWave = false
  FIGHT_STATE.isPizzaPhase = false
  FIGHT_STATE.zukDpsCheckActive = false
  FIGHT_STATE.lastClickedTarget = nil
  FIGHT_STATE.movingToTarget = false
end

local function warsPreparation()
  if currentWarsStep == WARS_STEP.USE_ALTAR then
    if API.GetPray_() >= API.GetSkillsTableSkill(6) then
      currentWarsStep = WARS_STEP.LOAD_PRESET
    elseif useAltarOfWar() then
      API.RandomSleep2(3000, 300, 300)
      currentWarsStep = WARS_STEP.LOAD_PRESET
    end

  elseif currentWarsStep == WARS_STEP.LOAD_PRESET then
    if loadLastPresetFromBank() then
      API.RandomSleep2(2000, 300, 300)
      currentWarsStep = WARS_STEP.USE_CRYSTAL
    end

  elseif currentWarsStep == WARS_STEP.USE_CRYSTAL then
    if API.GetAdrenalineFromInterface() >= 100 then
      currentWarsStep = WARS_STEP.ENTER_PORTAL
    else
      if useAdrenalineCrystal() then
        API.RandomSleep2(2800, 200, 200)
      end
    end

  elseif currentWarsStep == WARS_STEP.ENTER_PORTAL then
    if enterBossPortal() then
      API.RandomSleep2(3000, 500, 500)
      currentPhase = SCRIPT_PHASE.ENTERING_FIGHT
      currentEnterStep = ENTER_STEP.WALK_TO_ZUK
      currentWarsStep = WARS_STEP.USE_ALTAR
    end
  end
end
local function isNearZukNpc()
  local pos = API.PlayerCoord()
  return math.abs(pos.x - 992) <= 5 and math.abs(pos.y - 426) <= 5
end

local function walkToZukNpc()
  API.logWarn("Walking to Zuk NPC")
  return API.DoAction_WalkerW(WPOINT.new(992, 426, 3))
end

local function challengeZuk()
  API.logWarn("Challenging Zuk")
  return API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route2, { 28525 }, 50)
end

local function handleZukInterface()
  if API.Check_Dialog_Open() then
    API.logWarn("Dialog open - clicking Yes to resume previous instance")
    API.DoDialog_Option("Yes")
    API.KeyboardPress(1, 60, 110)
    return true
  end
  local vb = API.VB_FindPSettinOrder(2874)
  if vb.state == 18 then
    API.logWarn("Instance interface open - clicking Start")
    return API.DoAction_Interface(0x24, 0xffffffff, 1, 1591, 60, -1, API.OFF_ACT_GeneralInterface_route)
  end
  return false
end

local function enteringFightPreparation()
  if currentEnterStep == ENTER_STEP.WALK_TO_ZUK then
    if isNearZukNpc() then
      currentEnterStep = ENTER_STEP.CHALLENGE_ZUK
    elseif not API.ReadPlayerMovin2() then
      walkToZukNpc()
      API.RandomSleep2(1500, 300, 300)
    end

  elseif currentEnterStep == ENTER_STEP.CHALLENGE_ZUK then
    if challengeZuk() then
      API.RandomSleep2(2000, 500, 500)
      currentEnterStep = ENTER_STEP.HANDLE_INTERFACE
    end

  elseif currentEnterStep == ENTER_STEP.HANDLE_INTERFACE then
    if handleZukInterface() then
      API.RandomSleep2(3000, 500, 500)
      currentPhase = SCRIPT_PHASE.FIGHTING
      currentEnterStep = ENTER_STEP.WALK_TO_ZUK
      API.logWarn("Entered fight instance - starting fight")
    end
  end
end

---------------------------------------------------------------------
--# END SECTION: War's Retreat farming loop functions
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: GUI data builder and stats tracking
---------------------------------------------------------------------
local Stats = {
  startTime     = os.time(),
  kills         = 0,
  deaths        = 0,
  killTimes     = {},
  killStartTime = 0,
}

local function formatTime(seconds)
  return string.format("%02d:%02d:%02d",
    math.floor(seconds / 3600),
    math.floor((seconds % 3600) / 60),
    seconds % 60)
end

local function getKillStat(compareFn)
  if #Stats.killTimes == 0 then return nil end
  local result = Stats.killTimes[1]
  for i = 2, #Stats.killTimes do
    if compareFn(Stats.killTimes[i], result) then result = Stats.killTimes[i] end
  end
  return formatTime(result)
end

local function getAverageKill()
  if #Stats.killTimes == 0 then return nil end
  local total = 0
  for _, t in ipairs(Stats.killTimes) do total = total + t end
  return formatTime(math.floor(total / #Stats.killTimes))
end

local function getGUIState()
  if GUI.isPaused() then return "Paused" end
  if currentPhase == SCRIPT_PHASE.FIGHTING then return "Fighting" end
  if currentPhase == SCRIPT_PHASE.KILL_COMPLETE then return "Kill Complete" end
  if currentPhase == SCRIPT_PHASE.TELEPORTING then return "Teleporting" end
  if currentPhase == SCRIPT_PHASE.AT_WARS then return "At War's" end
  if currentPhase == SCRIPT_PHASE.ENTERING_FIGHT then return "Entering Fight" end
  return "Idle"
end

local function buildGUIData()
  return {
    state         = getGUIState(),
    wave          = FIGHT_STATE.wave or 0,
    kills         = Stats.kills,
    deaths        = Stats.deaths,
    runtime       = os.time() - Stats.startTime,
    killStartTime = Stats.killStartTime > 0 and Stats.killStartTime or nil,
    killTimes     = Stats.killTimes,
    fastestKill   = getKillStat(function(a, b) return a < b end),
    slowestKill   = getKillStat(function(a, b) return a > b end),
    averageKill   = getAverageKill(),
  }
end
---------------------------------------------------------------------
--# END SECTION: GUI data builder and stats tracking
---------------------------------------------------------------------

---------------------------------------------------------------------
--# SECTION: GUI startup and main loop
---------------------------------------------------------------------

-- Wait for user to configure and press Start in the GUI
local function waitForGUIStart()
  GUI.reset()
  GUI.loadConfig()

  ClearRender()
  DrawImGui(function()
    if GUI.open then GUI.draw({}) end
  end)

  while API.Read_LoopyLoop() and not GUI.started do
    if not GUI.open or GUI.isCancelled() then
      ClearRender()
      return false
    end
    API.RandomSleep2(100, 50, 0)
  end

  return API.Read_LoopyLoop()
end

local function startLiveGUI()
  GUI.selectInfoTab = true
  ClearRender()
  DrawImGui(function()
    if GUI.open then GUI.draw(buildGUIData()) end
  end)
end

-- Main initialization
API.Write_fake_mouse_do(false)
API.SetDrawLogs(true)

if not waitForGUIStart() then return end

-- Apply user config from GUI
applyConfig(GUI.getConfig())

local prayerFlicker = PrayerFlicker.new(PRAYER_CONFIG)
API.SetMaxIdleTime(9)

-- Switch to live info tab
startLiveGUI()
Stats.startTime = os.time()

-- Detect initial state
if isAtWarsRetreat() then
  currentPhase = SCRIPT_PHASE.AT_WARS
  API.logWarn("Starting at War's Retreat - preparing for fight")
end

while API.Read_LoopyLoop() do
  -- Check GUI stop/pause
  if GUI.isStopped() then break end

  if GUI.isPaused() then
    API.RandomSleep2(200, 50, 100)
    goto continue
  end

  ----- WAR'S RETREAT PREPARATION PHASE -----
  if currentPhase == SCRIPT_PHASE.AT_WARS then
    warsPreparation()
    API.RandomSleep2(300, 100, 0)
    goto continue
  end

  if currentPhase == SCRIPT_PHASE.TELEPORTING then
    if isAtWarsRetreat() then
      currentPhase = SCRIPT_PHASE.AT_WARS
      resetForNewKill()
    end
    API.RandomSleep2(1000, 200, 0)
    goto continue
  end

  if currentPhase == SCRIPT_PHASE.ENTERING_FIGHT then
    enteringFightPreparation()
    API.RandomSleep2(300, 100, 0)
    goto continue
  end

  ----- KILL COMPLETE - TELEPORT BACK -----
  if currentPhase == SCRIPT_PHASE.KILL_COMPLETE then
    API.RandomSleep2(2000, 500, 500)
    if teleportToWarsRetreat() then
      currentPhase = SCRIPT_PHASE.TELEPORTING
      API.RandomSleep2(5000, 500, 500)
    end
    goto continue
  end

  ----- FIGHTING PHASE -----
  -- Track kill start time
  if currentPhase == SCRIPT_PHASE.FIGHTING and Stats.killStartTime == 0 and FIGHT_STATE.wave > 0 then
    Stats.killStartTime = os.time()
  end

  -- Check if Zuk is dead (kill complete)
  if areTargetsAlive({ ZUK_IDS.END }) then
    killCount = killCount + 1
    Stats.kills = Stats.kills + 1
    if Stats.killStartTime > 0 then
      Stats.killTimes[#Stats.killTimes + 1] = os.time() - Stats.killStartTime
      Stats.killStartTime = 0
    end
    API.logWarn("Kill #" .. killCount .. " complete! Preparing to farm again.")
    currentPhase = SCRIPT_PHASE.KILL_COMPLETE
    goto continue
  end

  -- Check if player died
  if #API.GetAllObjArray1({ 27299 }, 25, { 1 }) > 0 then
    API.logWarn("Player died! Teleporting to War's Retreat to re-gear.")
    Stats.deaths = Stats.deaths + 1
    Stats.killStartTime = 0
    currentPhase = SCRIPT_PHASE.KILL_COMPLETE
    goto continue
  end

  -- Update current state of stuff
  updateFightState()

  -- Find safespots and arena boundaries
  if SAFESPOT_JAD == nil then
    findArenaCoords()
  end

  -- Go to safespot at start of waves
  if not areTargetsAlive(ALL_POSSIBLE_TARGET_IDS) then
    if (FIGHT_STATE.isJadWave or FIGHT_STATE.isNormalWave) and SAFESPOT_JAD ~= nil then
      goToSafespot(SAFESPOT_JAD)
    end
  end

  -- Update buffs and overheads
  manageBuffs()
  prayerFlicker:update()

  -- Handle Zuk fight mechanics
  if FIGHT_STATE.wave == 18 then
    local zuk = API.GetAllObjArrayFirst({ ZUK_IDS.FIGHT }, 40, { 1 })
    local searDebuff = getDebuff(30721)
    if zuk == nil then goto continue end
    local avoidQuakeTile = standingOnQuakeSpot(zuk)

    -- Remove sear debuff
    if searDebuff.found then
      if searDebuff.remaining >= 15 then
        if API.DoAction_Ability_check("Surge", 1, API.OFF_ACT_GeneralInterface_route, true, true, true) then
          API.RandomSleep2(600, 200, 100)
        end
      elseif searDebuff.remaining < 15 and not API.ReadPlayerMovin2() then
        if API.DoAction_TileF(FFPOINT.new(zuk.Tile_XYZ.x, zuk.Tile_XYZ.y + (searDebuff.remaining / 2), 0)) then
          API.logWarn("[SEAR] Moving to remove sear debuff")
          API.Sleep_tick(1)
        end
      end
      -- Avoid quake tiles
    elseif avoidQuakeTile ~= nil then
      if API.DoAction_Ability_check("Surge", 1, API.OFF_ACT_GeneralInterface_route, true, true, true) then
        API.logWarn("[QUAKE] Surged away from quake spot " .. avoidQuakeTile.x .. ", " .. avoidQuakeTile.y)
      else
        if API.DoAction_TileF(avoidQuakeTile) then
          API.logWarn("[QUAKE] Moving away from quake tile")
        end
      end
      API.Sleep_tick(2)
    end
  end

  -- Handle Har Aken wave mechanics
  if FIGHT_STATE.wave == 17 then
    local avoidBlobTile = standingOnLavaBlob()
    if avoidBlobTile ~= nil then
      if API.DoAction_TileF(avoidBlobTile) then
        API.logInfo("Avoiding lava blob")
        API.Sleep_tick(2)
      end
    end
  end

  -- Handle moving to igneous Mej domes or pizza phase targets
  if FIGHT_STATE.movingToTarget and FIGHT_STATE.lastClickedTarget ~= nil then
    if API.PInAreaF2(FIGHT_STATE.lastClickedTarget.Tile_XYZ, 3) then
      attackTarget(FIGHT_STATE.lastClickedTarget)
      FIGHT_STATE.movingToTarget = false
    else
      goto continue
    end
  end

  -- Handle targeting
  if needsNewTarget() or FIGHT_STATE.isPizzaPhase then
    local nextTarget = findNextBestTarget()
    if needToBeNextToTarget(nextTarget) then
      moveWithinAreaOfTarget(nextTarget)
      goto continue
    else
      surgeAttackTarget(nextTarget)
    end
  end

  -- Handle extra action button (UI action, not gated by GCD)
  if extraActionButtonVisible() then
    if FIGHT_STATE.isIgneousWave then
      local adren = API.GetAdrenalineFromInterface()
      if adren >= (HAS_ZUK_CAPE and 80 or 100) then
        -- Use Split Soul first if possible, then press button regardless
        API.DoAction_Ability("Split Soul", 1, API.OFF_ACT_GeneralInterface_route, true)
        API.RandomSleep2(600, 200, 100)
        doExtraActionButton()
        API.RandomSleep2(600, 200, 200)
        -- Retry if it didn't register
        if extraActionButtonVisible() then
          doExtraActionButton()
          API.RandomSleep2(600, 200, 200)
        end
      end
    elseif FIGHT_STATE.wave == 18 and FIGHT_STATE.isPizzaPhase
        and not areTargetsAlive({ POSSIBLE_TARGETS.Igneous_Xil, POSSIBLE_TARGETS.Igneous_Mej, POSSIBLE_TARGETS.Igneous_Hur }) then
      doExtraActionButton()
      API.RandomSleep2(600, 200, 200)
      -- Retry if it didn't register
      if extraActionButtonVisible() then
        doExtraActionButton()
        API.RandomSleep2(600, 200, 200)
      end
    end
  end

  -- Do ability rotation
  if API.GetInCombBit() and withinAttackRange() then
    doRotation()
  end

  ::continue::
  API.RandomSleep2(30, 10, 0)
end

ClearRender()
