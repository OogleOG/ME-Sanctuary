--[[
    SanctumPrayerManager.lua
    Based on proven Sanctum prayer flicking logic
    Handles prayer flicking for all 3 Sanctum bosses
]]

local API = require("api")

local SanctumPrayerManager = {}

-- State tracking
local state = {
    prayerOn = false,
    distPray = 2,
    firstTime = true,
    counter = 0,
    tickOn = false,
}

-- Boss and projectile IDs
local IDs = {
    -- Vermyx
    VERMYX_BOSS = 31098,
    VERMYX_BOSS2 = 31099,
    VERMYX_RANGED_PROJ = 8185,
    
    -- Kezalam
    KEZALAM_BOSS = 31100,
    KEZALAM_MAGIC_PROJ = 8182,
    KEZALAM_ATTACK_ANIM = 36028,
    KEZALAM_MAGIC_ANIM = 36031,
    
    -- Nakatra
    NAKATRA_BOSS = 31103,
    NAKATRA_MAGIC_PROJ = 8182,
    NAKATRA_RANGED_PROJ = 8185,
}

-- Prayer buff IDs
local PRAYER_BUFFS = {
    SOUL_SPLIT = 26033,
    DEFLECT_MELEE = 26040,
    DEFLECT_MAGIC = 26041,
    DEFLECT_RANGED = 26044,
    SORROW = 30814,      -- Sorrow curse buff
    RUINATION = 30815,   -- Ruination curse buff (T99)
}

-- Track if damage prayer is active
local damagePrayerActive = false

---Activate Sorrow or Ruination (damage curse)
local function activateDamagePrayer()
    -- Check if already have Ruination or Sorrow active
    if API.Buffbar_GetIDstatus(PRAYER_BUFFS.RUINATION, false).found then
        damagePrayerActive = true
        return
    end
    if API.Buffbar_GetIDstatus(PRAYER_BUFFS.SORROW, false).found then
        damagePrayerActive = true
        return
    end
    
    -- Try Ruination first (T99), then Sorrow (T95)
    if not damagePrayerActive then
        -- Try Ruination
        local ruinResult = API.DoAction_Ability("Ruination", 1, API.OFF_ACT_GeneralInterface_route)
        if ruinResult then
            print("[Prayer] Activated Ruination")
            damagePrayerActive = true
            return
        end
        -- Try Sorrow
        local sorrowResult = API.DoAction_Ability("Sorrow", 1, API.OFF_ACT_GeneralInterface_route)
        if sorrowResult then
            print("[Prayer] Activated Sorrow")
            damagePrayerActive = true
            return
        end
    end
end

---Activate Deflect Ranged if not already active
local function prayRange()
    if API.Buffbar_GetIDstatus(PRAYER_BUFFS.DEFLECT_RANGED, false).found then
        return
    end
    API.DoAction_Ability("Deflect Ranged", 1, API.OFF_ACT_GeneralInterface_route)
end

---Activate Deflect Magic if not already active
local function prayMage()
    if API.Buffbar_GetIDstatus(PRAYER_BUFFS.DEFLECT_MAGIC, false).found then
        return
    end
    API.DoAction_Ability("Deflect Magic", 1, API.OFF_ACT_GeneralInterface_route)
end

---Activate Deflect Melee if not already active
local function prayMelee()
    if API.Buffbar_GetIDstatus(PRAYER_BUFFS.DEFLECT_MELEE, false).found then
        return
    end
    API.DoAction_Ability("Deflect Melee", 1, API.OFF_ACT_GeneralInterface_route)
end

---Activate Soul Split if not already active
local function praySoulSplit()
    if API.Buffbar_GetIDstatus(PRAYER_BUFFS.SOUL_SPLIT, false).found then
        return
    end
    API.DoAction_Ability("Soul Split", 1, API.OFF_ACT_GeneralInterface_route)
end

---Handle Vermyx prayer flicking (Ranged projectiles)
local function handleVermyxPrayer()
    local objects = API.GetAllObjArray1({IDs.VERMYX_RANGED_PROJ}, 30, {5})
    
    if objects[1] == nil then
        if state.prayerOn then
            state.prayerOn = false
            state.distPray = 2
            state.firstTime = true
            praySoulSplit()
        end
        return
    end
    
    if state.prayerOn then return end
    
    local dist = math.floor(objects[1].Distance)
    
    if state.firstTime then
        state.firstTime = false
        if dist >= 9 then
            state.distPray = 5
        elseif dist >= 8 then
            state.distPray = 4
        elseif dist >= 7 then
            state.distPray = 3
        elseif dist <= 2 then
            state.distPray = -1
        end
    end
    
    if state.distPray == -1 then
        state.counter = state.counter + 1
    end
    
    if dist > state.distPray and state.counter < 6 then
        return
    end
    
    state.prayerOn = true
    state.counter = 0
    
    if objects[1].Id == IDs.VERMYX_RANGED_PROJ then
        prayRange()
    end
end

---Handle Kezalam prayer flicking (Magic projectiles + Melee animation)
local function handleKezalamPrayer()
    local objects = API.GetAllObjArray1({IDs.KEZALAM_MAGIC_PROJ}, 30, {5})
    local anim = API.GetAllObjArray1({IDs.KEZALAM_BOSS}, 20, {1})
    
    -- Check for melee attack animation
    if anim[1] ~= nil then
        if anim[1].Anim == IDs.KEZALAM_ATTACK_ANIM then
            if not state.tickOn then
                state.prayerOn = true
                state.tickOn = true
                prayMelee()
            end
        end
    end
    
    -- No projectile - return to Soul Split
    if objects[1] == nil then
        if state.prayerOn then
            state.prayerOn = false
            state.tickOn = false
            state.distPray = 1
            state.firstTime = true
            praySoulSplit()
        end
        return
    end
    
    if state.prayerOn then return end
    
    state.prayerOn = true
    
    -- Don't flick if attacking Moonstone Obelisk
    local interacting = API.ReadLpInteracting()
    local moonstone = interacting and interacting.Name == "Moonstone Obelisk"
    
    if objects[1].Id == IDs.KEZALAM_MAGIC_PROJ and not moonstone then
        prayMage()
    end
end

---Handle Nakatra prayer flicking (Magic + Ranged projectiles)
local function handleNakatraPrayer()
    local objects = API.GetAllObjArray1({IDs.NAKATRA_MAGIC_PROJ, IDs.NAKATRA_RANGED_PROJ}, 30, {5})
    
    if objects[1] == nil then
        if state.prayerOn then
            state.prayerOn = false
            state.distPray = 2
            state.firstTime = true
            praySoulSplit()
        end
        return
    end
    
    if state.prayerOn then return end
    
    local dist = math.floor(objects[1].Distance)
    
    if state.firstTime then
        state.firstTime = false
        if dist >= 9 then
            state.distPray = 5
        elseif dist >= 8 then
            state.distPray = 4
        elseif dist >= 7 then
            state.distPray = 3
        elseif dist <= 2 then
            state.distPray = -1
        end
    end
    
    if state.distPray == -1 then
        state.counter = state.counter + 1
    end
    
    if dist > state.distPray and state.counter < 6 then
        return
    end
    
    state.prayerOn = true
    state.counter = 0
    
    if objects[1].Id == IDs.NAKATRA_RANGED_PROJ then
        prayRange()
    elseif objects[1].Id == IDs.NAKATRA_MAGIC_PROJ then
        prayMage()
    end
end

---Main update function - call every tick
function SanctumPrayerManager.update()
    if not API.PlayerLoggedIn() or API.GetPrayPrecent() <= 0 then
        return
    end
    
    -- Always ensure damage prayer (Sorrow/Ruination) is active
    activateDamagePrayer()
    
    local boss = API.GetAllObjArray1({
        IDs.VERMYX_BOSS, 
        IDs.VERMYX_BOSS2, 
        IDs.KEZALAM_BOSS, 
        IDs.NAKATRA_BOSS
    }, 30, {1})
    
    if boss[1] == nil then
        return
    end
    
    if boss[1].Id == IDs.VERMYX_BOSS or boss[1].Id == IDs.VERMYX_BOSS2 then
        handleVermyxPrayer()
    elseif boss[1].Id == IDs.KEZALAM_BOSS then
        handleKezalamPrayer()
    elseif boss[1].Id == IDs.NAKATRA_BOSS then
        handleNakatraPrayer()
    end
end

---Reset prayer state
function SanctumPrayerManager.reset()
    state.prayerOn = false
    state.distPray = 2
    state.firstTime = true
    state.counter = 0
    state.tickOn = false
end

---Force Soul Split
function SanctumPrayerManager.forceSoulSplit()
    praySoulSplit()
end

---Force deactivate all prayers
function SanctumPrayerManager.deactivate()
    API.DoAction_Interface(0xc350, 0xffffffff, 1, 1464, 50, -1, API.OFF_ACT_GeneralInterface_route)
end

---Check if currently defending (prayer active)
---@return boolean
function SanctumPrayerManager.isDefending()
    return state.prayerOn
end

-- Expose IDs for external use
SanctumPrayerManager.IDs = IDs
SanctumPrayerManager.PRAYER_BUFFS = PRAYER_BUFFS

return SanctumPrayerManager