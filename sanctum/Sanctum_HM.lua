--[[
    Sanctum_HM.lua
    Sanctum of Rebirth Hard Mode Script v2.2.0
    
    Full automation including:
    - War's Retreat preparation (bank, altar, bonfire, adrenaline)
    - Instance entry
    - Boss fights (Vermyx, Kezalam, Nakatra)
    - Death's Office recovery (AG Pattern)
]]

local API = require("api")

-- Load modules (from sanctum folder)
local scriptPath = "sanctum."
local SanctumTimer = require(scriptPath .. "SanctumTimer")
local SanctumRotationManager = require(scriptPath .. "SanctumRotationManager")
local SanctumPrayerManager = require(scriptPath .. "SanctumPrayerManager")
local SanctumMechanics = require(scriptPath .. "SanctumMechanics")
local SanctumConsumables = require(scriptPath .. "SanctumConsumables")
local SanctumVariable = require(scriptPath .. "SanctumVariable")
local SanctumGUI = require(scriptPath .. "SanctumGUI")

API.Write_fake_mouse_do(false)
API.TurnOffMrHasselhoff(false)

local VERSION = "2.2.0"
local debug = true

local function debugLog(msg)
    if debug then
        print("[SANCTUM]: " .. msg)
    end
end

local function Report(msg)
    print("[SANCTUM]: " .. msg)
end

-- Forward declaration for detectLocation (defined later, used in enterInstance)
local detectLocation

-- ========================================
-- CONFIGURATION
-- ========================================

local Config = {
    -- Boss IDs
    VERMYX = SanctumMechanics.IDs.VERMYX,
    VERMYX_COILSPAWN = SanctumMechanics.IDs.VERMYX_COILSPAWN,
    KEZALAM = SanctumMechanics.IDs.KEZALAM,
    MOON_OBELISK_1 = 31101,
    MOON_OBELISK_2 = 31102,
    NAKATRA = SanctumMechanics.IDs.NAKATRA,
    VOLATILE_SCARAB = SanctumMechanics.IDs.VOLATILE_SCARAB,
    
    -- War's Retreat IDs
    BANK_CHEST = 114750,
    ALTAR = 114748,
    BONFIRE = {114757, 114758, 114759},
    BONFIRE_BUFF = 10931,
    ADRENALINE_CRYSTAL = 114749,
    SANCTUM_PORTAL = 130662,
    SANCTUM_ENTRANCE = {130744, 1007, 9632},
    EXTERNAL_LOOT_CHEST = 130663,
    
    -- Death's Office
    DEATH_NPC_ID = 27299,
    
    -- Thresholds
    HEALTH_EAT_PERCENT = 60,
    HEALTH_EMERGENCY_PERCENT = 25,
    PRAYER_RESTORE_PERCENT = 30,
    
    -- Buff IDs
    DARKNESS_BUFF = 30122,
    OVERLOAD_BUFFS = {49039, 33210, 52453, 26093},
    INVOKE_DEATH_BUFF = 30101,

    -- Scripture Buff IDs (for deactivation after kills)
    SCRIPTURE_BUFFS = {
        {id = 52117, name = "Scripture of Wen"},
        {id = 51814, name = "Scripture of Jas"},
        {id = 52494, name = "Scripture of Ful"},
    },
    
    -- Settings
    startWithFullAdrenaline = true,
}

-- States
local States = {
    IDLE = 0,
    CHECKING_EXTERNAL_CHEST = 1,
    BANKING = 2,
    USING_ALTAR = 3,
    USING_BONFIRE = 4,
    USING_ADRENALINE = 5,
    ENTERING_PORTAL = 6,
    ENTERING_INSTANCE = 7,
    CROSSING_GAP_VERMYX = 8,
    FIGHTING_VERMYX = 9,
    VERMYX_COMPLETE = 10,
    TRANSITIONING_TO_KEZALAM = 11,
    CROSSING_LEDGE_KEZALAM = 12,
    FIGHTING_KEZALAM = 13,
    KEZALAM_COMPLETE = 14,
    TRANSITIONING_TO_NAKATRA = 15,
    CROSSING_GAP_NAKATRA = 16,
    FIGHTING_NAKATRA = 17,
    NAKATRA_COMPLETE = 18,
    TELEPORTING_OUT = 19,
    DEATH_RECOVERY = 20,
    -- Mid-run resupply (after Kezalam, before Nakatra)
    RESUPPLY_TELEPORT_OUT = 21,
    RESUPPLY_BANKING = 22,
    RESUPPLY_ALTAR = 23,
    RESUPPLY_ADRENALINE = 24,
    RESUPPLY_ENTER_PORTAL = 25,
    RESUPPLY_ENTER_INSTANCE = 26,
}

-- ========================================
-- STATE TRACKING
-- ========================================

local State = {
    currentState = States.IDLE,
    runsCompleted = 0,
    vermyxKilled = false,
    kezalamKilled = false,
    nakatraKilled = false,
    preBuildVermyx = false,
    preBuildKezalam = false,
    preBuildNakatra = false,
    hasActiveInstance = false,
    needsExternalChestCheck = true,
    bonfireActive = false,
    bonfireExpireTime = 0,
}

local deathState = {
    step = nil,
    stepTick = 0,
    isRecovering = false
}

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

local Utils = {}

function Utils.isIdle()
    local moving = API.ReadPlayerMovin2() or false
    local animation = API.ReadPlayerAnim() or -1
    return not moving and animation == 0
end

function Utils.waitForIdle(maxTicks)
    maxTicks = maxTicks or 20
    local ticks = 0
    while ticks < maxTicks and API.Read_LoopyLoop() do
        if Utils.isIdle() then return true end
        API.RandomSleep2(600, 100, 200)
        ticks = ticks + 1
    end
    return false
end

function Utils.isAtWarsRetreat()
    local playerPos = API.PlayerCoord()
    return playerPos.x > 3250 and playerPos.x < 3350 and playerPos.y > 10080 and playerPos.y < 10180
end

---Deactivate any active scriptures (Ful, Wen, Jas)
function Utils.deactivateScriptures()
    for _, scripture in ipairs(Config.SCRIPTURE_BUFFS) do
        if API.Buffbar_GetIDstatus(scripture.id, false).found then
            print("[Cleanup] Deactivating " .. scripture.name)
            API.DoAction_Ability(scripture.name, 1, API.OFF_ACT_GeneralInterface_route, true)
            API.RandomSleep2(100, 50, 50)
            return true
        end
    end
    return false
end

---Cleanup after boss kill - deactivate prayers and scriptures
function Utils.postKillCleanup()
    print("[Cleanup] Deactivating prayers and scriptures...")

    -- Deactivate all prayers
    SanctumPrayerManager.deactivate()
    API.RandomSleep2(100, 50, 50)

    -- Deactivate any active scripture
    Utils.deactivateScriptures()
    API.RandomSleep2(100, 50, 50)

    print("[Cleanup] Complete!")
end

-- ========================================
-- DEATH'S OFFICE RECOVERY (AG Pattern)
-- ========================================

local DeathRecovery = {}

function DeathRecovery.isAtDeathsOffice()
    local deathNPC = API.GetAllObjArrayInteract({Config.DEATH_NPC_ID}, 50, {1})
    if deathNPC and #deathNPC > 0 then return true end
    if API.IsInDeathOffice then return API.IsInDeathOffice() end
    return false
end

function DeathRecovery.handleDeathRecovery()
    if not deathState.step then
        deathState.step = 1
        deathState.stepTick = API.Get_tick()
        deathState.isRecovering = true
        print("[Death] Starting death recovery...")
    end
    
    local currentTick = API.Get_tick()
    local ticksWaited = currentTick - deathState.stepTick
    
    if deathState.step == 1 then
        print("[Death] Step 1: Waiting for respawn")
        if ticksWaited >= 6 and DeathRecovery.isAtDeathsOffice() then
            deathState.step = 2
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 2 then
        print("[Death] Step 2: Clicking Death NPC")
        if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route3, {Config.DEATH_NPC_ID}, 50) then
            deathState.step = 3
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 3 then
        local vbState = API.VB_FindPSettinOrder(2874).state
        print("[Death] Step 3: Waiting for interface, VB=" .. tostring(vbState))
        if vbState == 18 then
            deathState.step = 4
            deathState.stepTick = currentTick
        elseif ticksWaited >= 10 then
            deathState.step = 2
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 4 then
        print("[Death] Step 4: Clicking Reclaim")
        if API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1626, 47, -1, API.OFF_ACT_GeneralInterface_route) then
            deathState.step = 5
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 5 then
        if ticksWaited >= 3 then
            deathState.step = 6
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 6 then
        print("[Death] Step 6: Confirming")
        if API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1626, 72, -1, API.OFF_ACT_GeneralInterface_Choose_option) then
            deathState.step = 7
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 7 then
        if ticksWaited >= 2 then
            deathState.step = 8
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 8 then
        print("[Death] Step 8: Leaving")
        if API.DoAction_Interface(0x2e, 0xffffffff, 1, 1673, 14, -1, API.OFF_ACT_GeneralInterface_route) then
            deathState.step = 9
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 9 then
        if ticksWaited >= 3 then
            API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
            deathState.step = 10
            deathState.stepTick = currentTick
        end
        return false
        
    elseif deathState.step == 10 then
        if Utils.isAtWarsRetreat() then
            print("[Death] *** RECOVERY COMPLETE! ***")
            deathState.step = nil
            deathState.stepTick = 0
            deathState.isRecovering = false
            State.vermyxKilled = false
            State.kezalamKilled = false
            State.nakatraKilled = false
            State.preBuildVermyx = false
            State.preBuildKezalam = false
            State.preBuildNakatra = false
            State.hasActiveInstance = false
            return true
        end
        if ticksWaited >= 20 then
            API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
            deathState.stepTick = currentTick
        end
        return false
    end
    return false
end

-- ========================================
-- WAR'S RETREAT FUNCTIONS
-- ========================================

local WarsRetreat = {}

function WarsRetreat.checkExternalChest()
    if not State.needsExternalChestCheck then return true end
    print("[Wars] Checking external chest...")
    if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {Config.EXTERNAL_LOOT_CHEST}, 50) then
        API.RandomSleep2(2000, 400, 600)
        API.KeyboardPress2(0x1B, 100, 150)
        API.RandomSleep2(1000, 200, 300)
        State.needsExternalChestCheck = false
    end
    return true
end

function WarsRetreat.bank()
    print("[Wars] Banking...")
    if API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, {Config.BANK_CHEST}, 50) then
        API.RandomSleep2(3500, 500, 800)
        print("[Wars] Preset loaded!")
        return true
    end
    return false
end

function WarsRetreat.useAltar()
    -- Only use altar if prayer is not full
    local prayerPct = API.GetPrayPrecent() or 100
    if prayerPct >= 99 then
        print("[Wars] Prayer already full - skipping altar")
        return true
    end
    
    print("[Wars] Using Altar... (Prayer: " .. prayerPct .. "%)")
    if API.DoAction_Object1(0x3d, API.OFF_ACT_GeneralObject_route0, {Config.ALTAR}, 50) then
        API.RandomSleep2(3500, 500, 800)
        print("[Wars] Prayers restored!")
        return true
    end
    return false
end


function WarsRetreat.useBonfire()
    local buffStatus = API.Buffbar_GetIDstatus(Config.BONFIRE_BUFF, false)
    if buffStatus.found then
        print("[Wars] Bonfire buff active!")
        State.bonfireActive = true
        return true
    end
    
    print("[Wars] Using bonfire...")
    --if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {Config.BONFIRE}, 50) then
    Interact:Object("Campfire", "Warm hands", 20)
    API.RandomSleep2(1000, 200, 300)
    local maxWait = 20
    for i = 1, maxWait do
        if API.Buffbar_GetIDstatus(Config.BONFIRE_BUFF, false).found then
            print("[Wars] Bonfire buff confirmed!")
            State.bonfireActive = true
            return true
        end
        API.RandomSleep2(600, 100, 200)
    end
    return true
end

function WarsRetreat.useAdrenalineCrystal()
    if not Config.startWithFullAdrenaline then return true end
    local adren = API.GetAdrenalineFromInterface()
    if adren >= 100 then
        print("[Wars] Adrenaline at 100%!")
        return true
    end

    local surgeAbility = API.GetABs_name("Surge", false)
    local canSurge = surgeAbility and surgeAbility.enabled and surgeAbility.cooldown_timer <= 1
    
    print("[Wars] Using adrenaline crystal...")
    if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {Config.ADRENALINE_CRYSTAL}, 50) then
        API.RandomSleep2(2400, 400, 600)
            if canSurge then
                debugLog("Using Surge to get there quicker!")
                API.RandomSleep2(80, 30, 50)
                API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep(600, 50, 150)
                API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {Config.ADRENALINE_CRYSTAL}, 50)
            end 
        Utils.waitForIdle(25)
        API.RandomSleep2(1000, 200, 400)
        for i = 1, 20 do
            if API.GetAdrenalineFromInterface() >= 100 then
                print("[Wars] Adrenaline at 100%!")
                return true
            end
            API.RandomSleep2(600, 100, 200)
        end
        return true
    end
    return false
end


function WarsRetreat.enterPortal()
    print("[Wars] Entering portal...")
    if API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {Config.SANCTUM_PORTAL}, 50) then
        local timeout = 50
        while timeout > 0 do
            API.RandomSleep2(600, 50, 50)
            if API.PInArea(1010, 3, 9632, 3, 4) then
                print("[Wars] Arrived at Sanctum!")
                API.RandomSleep2(800, 800, 800)
                return true
            end
            timeout = timeout - 1
        end
        print("[Wars] Timed out waiting for arrival")
        return false
    end
    return false
end


-- function WarsRetreat.enterPortal()
--     print("[Wars] Entering portal...")
--     if API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {Config.SANCTUM_PORTAL}, 50) then
--         API.RandomSleep2(4500, 800, 1200)
--         print("[Wars] Arrived at Sanctum!")
--         return true
--     end
--     return false
-- end

local function stopScript()
    print("[Instance] No dialog detected - stopping script to prevent issues.")
    API.StopScript()
end

function WarsRetreat.enterInstance()
    print("[Instance] Clicking Sanctum entrance...")
    API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, Config.SANCTUM_ENTRANCE, 10)
    API.RandomSleep2(2000, 2000, 2000)
    
    if not API.Check_Dialog_Open() then
        print("[Instance] No dialog detected, stopping.")
        stopScript()
        return false
    end

    -- Try resume-instance path first
    if API.DoDialog_Option("Yes") then --or API.DoDialog_Option("continue") then
        print("[Instance] Existing instance detected, resuming.")
        --API.KeyboardPress(1, 60, 110)
        API.KeyboardPress(1, 800, 800)
    else
        print("[Instance] Fresh instance, selecting Hard Mode.")
        API.KeyboardPress(2, 800, 800)
    end
    
    -- Wait for instance to load
    API.RandomSleep2(3000, 3000, 3000)
    
    -- Detect where we ended up
    local location = detectLocation()
    print("[Instance] Post-entry location: " .. location)
    
    -- Update state based on where we ended up
    if location == "LOOT_ROOM" then
        print("[Instance] At loot room - continued existing instance!")
        State.vermyxKilled = true
        local kezalamLedge = API.GetAllObjArrayInteract({SanctumMechanics.IDs.KEZALAM_LEDGE}, 100, {12})
        if kezalamLedge and #kezalamLedge > 0 then
            State.kezalamKilled = false
        else
            local nakatraGap = API.GetAllObjArrayInteract({SanctumMechanics.IDs.NAKATRA_GAP}, 100, {12})
            State.kezalamKilled = (nakatraGap and #nakatraGap > 0)
        end
        State.nakatraKilled = false
        
    elseif location == "KEZALAM_LEDGE" or location == "KEZALAM_ARENA" then
        print("[Instance] At Kezalam - Vermyx was killed")
        State.vermyxKilled = true
        State.kezalamKilled = false
        State.nakatraKilled = false
        
    elseif location == "NAKATRA_ENTRANCE" or location == "NAKATRA_ARENA" then
        print("[Instance] At Nakatra - Vermyx and Kezalam killed")
        State.vermyxKilled = true
        State.kezalamKilled = true
        State.nakatraKilled = false
        
    elseif location == "VERMYX_ENTRANCE" or location == "VERMYX_ARENA" then
        print("[Instance] At Vermyx - fresh instance")
        State.vermyxKilled = false
        State.kezalamKilled = false
        State.nakatraKilled = false
        
    elseif location == "TRANSITION" then
        print("[Instance] At transition area")
        State.vermyxKilled = true
        State.kezalamKilled = false
        State.nakatraKilled = false
    end
    
    State.hasActiveInstance = true
    State.preBuildVermyx = false
    State.preBuildKezalam = false
    State.preBuildNakatra = false
    print("[Instance] Instance entered!")
    return true
end

function WarsRetreat.teleportOut()
    -- Cleanup: Deactivate prayers and scriptures before teleporting
    Utils.postKillCleanup()

    print("[Teleport] Returning to Wars...")
    API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route, true)
    API.RandomSleep2(3000, 600, 900)
    Utils.waitForIdle(50)
    API.RandomSleep2(2000, 400, 600)
    State.hasActiveInstance = false
    State.needsExternalChestCheck = true
    return true
end

-- ========================================
-- ROTATIONS
-- ========================================

local BossRotation = SanctumRotationManager.new({
    name = "Boss DPS",
    rotation = {
        { label = "Vulnerability bomb", type = "Inventory", wait = 0 },
        { label = "Improvise", type = "Improvise", spend = true, wait = 3 },
    }
})

local AddRotation = SanctumRotationManager.new({
    name = "Add Kill",
    rotation = {{ label = "Improvise", type = "Improvise", spend = false, wait = 3 }}
})

local Obelisk1Rotation = SanctumRotationManager.new({
    name = "Obelisk 1",
    rotation = SanctumRotationManager.createObelisk1Rotation()
})

local Obelisk2Rotation = SanctumRotationManager.new({
    name = "Obelisk 2",
    rotation = SanctumRotationManager.createObelisk2Rotation()
})

-- ========================================
-- TIMERS
-- ========================================

local Timers = {}

-- Consumables handled by SanctumConsumables module now
-- Supports: Multiple foods, Super Sara Brews (combo eat), Super Restores

Timers.darkness = SanctumTimer.new({
    name = "Darkness", cooldown = 30, useTicks = true,
    condition = function()
        local buff = API.Buffbar_GetIDstatus(Config.DARKNESS_BUFF, false)
        if not buff.found then return true end
        return API.Bbar_ConvToSeconds(buff) < 30
    end,
    action = function()
        return API.DoAction_Ability("Darkness", 1, API.OFF_ACT_GeneralInterface_route)
    end
})

-- ========================================
-- PREBUILD
-- ========================================

local function hasOverload()
    -- Check the actual overload buff ID
    local buff = API.Buffbar_GetIDstatus(26093, false)
    if buff.found then return true end
    
    -- Also check other overload variants
    for _, buffId in ipairs(Config.OVERLOAD_BUFFS) do
        local b = API.Buffbar_GetIDstatus(buffId, false)
        if b.found then return true end
    end
    return false
end

-- Track last overload attempt to prevent spam
local lastOverloadAttempt = 0

local function useOverload()
    if hasOverload() then return true end
    
    -- Prevent spam - only try once every 10 seconds
    local currentTime = os.time()
    if currentTime - lastOverloadAttempt < 10 then
        return false
    end
    lastOverloadAttempt = currentTime
    
    -- Try different overload types by NAME (AG script method)
    local overloadNames = {
        "Elder overload salve",
        "Supreme overload salve",
        "Overload salve",
        "Supreme overload",
        "Elder overload",
        "Holy overload",
        "Overload"
    }
    
    Report("Drinking overload...")
    for _, overloadName in ipairs(overloadNames) do
        if API.DoAction_Inventory3(overloadName, 0, 1, API.OFF_ACT_GeneralInterface_route) then
            Report("Used " .. overloadName .. "!")
            API.RandomSleep2(600, 100, 150)
            return true
        end
    end
    
    Report("No overload found in inventory!")
    return false
end

local function activateSoulSplit()
    ----------------------------------------------------------------
    -- 1) Ensure Soul Split prayer is active
    ----------------------------------------------------------------
    local SOUL_SPLIT_BUFF_ID = 26033 -- Soul Split buff ID

    local soulSplitBuff = API.Buffbar_GetIDstatus(SOUL_SPLIT_BUFF_ID, false)
    if not soulSplitBuff.found then
        Report("Activating Soul Split prayer...")
        API.DoAction_Ability("Soul Split", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(300, 60, 90)
    end
    return true
end


-- ========================================
-- SCRIPTURE HANDLING
-- ========================================

local Scripture = {
    data = {
        scriptureOfJas = { name = "Scripture of Jas", itemId = 51814, buffId = 51814 },
        scriptureOfWen = { name = "Scripture of Wen", itemId = 52117, buffId = 52117 },
        scriptureOfFul = { name = "Scripture of Ful", itemId = 52494, buffId = 52494 },
        scriptureOfAmascut = { name = "Scripture of Amascut", itemId = 57126, buffId = 57126 },
    },
    equipped = nil,
    isEquipped = false,
    hasBuffActive = false,
}

function Scripture.checkEquipped()
    Scripture.equipped = nil
    Scripture.isEquipped = false

    for _, scriptureData in pairs(Scripture.data) do
        if API.Container_Get_s(94, scriptureData.itemId).item_id > 0 then
            Scripture.equipped = scriptureData
            Scripture.isEquipped = true
            debugLog("Scripture equipped: " .. scriptureData.name)
            return true
        end
    end
    return false
end

function Scripture.enable()
    if not Scripture.isEquipped or not Scripture.equipped then
        Scripture.checkEquipped()
        if not Scripture.isEquipped then return false end
    end

    local book = Scripture.equipped
    local bookAbility = API.GetABs_name1(book.name)
    Scripture.hasBuffActive = API.Buffbar_GetIDstatus(book.buffId, false).found

    if bookAbility and bookAbility.enabled and not Scripture.hasBuffActive then
        API.DoAction_Ability(book.name, 1, API.OFF_ACT_GeneralInterface_route)
        debugLog("Enabling Scripture: " .. book.name)
        Scripture.hasBuffActive = true
        API.RandomSleep2(100, 50, 50)
        return true
    end
    return false
end

local function activateScripture()
    return Scripture.enable()
end

local function necroAbilitySetup()
     local abilities = {"Conjure Undead Army", "Life Transfer", 
                   "Command Vengeful Ghost", "Split Soul", "Augmented enhanced Excalibur","Invoke Death", "Command Skeleton Warrior"}
    for _, ability in ipairs(abilities) do
        local ab = API.GetABs_name(ability, false)
     if ab and ab.enabled then
            API.DoAction_Ability(ability, 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(1800, 200, 300)
        end
    end
end

local function doPrebuildVermyx()
    if State.preBuildVermyx then return true end
    API.RandomSleep2(1200, 1200, 1200)
    Report("Starting prebuild...")
    activateSoulSplit()
    useOverload()
    necroAbilitySetup()
    activateScripture()
    SanctumVariable.CrossedGapPosition = WPOINT.new(API.PlayerCoord().x, API.PlayerCoord().y + 1, API.PlayerCoord().z)
    Report("Crossed gap position: " .. tostring(SanctumVariable.CrossedGapPosition.x) .. ", " .. tostring(SanctumVariable.CrossedGapPosition.y) .. ", " .. tostring(SanctumVariable.CrossedGapPosition))
    SanctumVariable.CentralPosition = WPOINT.new(SanctumVariable.CrossedGapPosition.x, SanctumVariable.CrossedGapPosition.y + 7, SanctumVariable.CrossedGapPosition.z)
    Report("Central position: " .. tostring(SanctumVariable.CentralPosition.x) .. ", " .. tostring(SanctumVariable.CentralPosition.y) .. ", " .. tostring(SanctumVariable.CentralPosition.z))
    Report("Prebuild complete!")
    State.preBuildVermyx = true
    return true
    end


local function doPrebuildKezalam()
    if State.preBuildKezalam then return true end
    Report("Starting prebuild...")
    activateSoulSplit()
    useOverload()
    necroAbilitySetup()
    activateScripture()
    SanctumVariable.CrossedGapPosition = WPOINT.new(API.PlayerCoord().x, API.PlayerCoord().y + 1, API.PlayerCoord().z)
    Report("Crossed gap position: " .. tostring(SanctumVariable.CrossedGapPosition.x) .. ", " .. tostring(SanctumVariable.CrossedGapPosition.y) .. ", " .. tostring(SanctumVariable.CrossedGapPosition.z))
    SanctumVariable.CentralPosition = WPOINT.new(SanctumVariable.CrossedGapPosition.x + 10, SanctumVariable.CrossedGapPosition.y, SanctumVariable.CrossedGapPosition.z)
    Report("Central position: " .. tostring(SanctumVariable.CentralPosition.x) .. ", " .. tostring(SanctumVariable.CentralPosition.y) .. ", " .. tostring(SanctumVariable.CentralPosition.z))

    API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route, false)

    API.RandomSleep2(100, 0, 0)

    API.DoAction_Dive_Tile(WPOINT.new(SanctumVariable.CentralPosition.x + 6, SanctumVariable.CentralPosition.y, SanctumVariable.CentralPosition.z))
    API.RandomSleep2(100, 0, 0)

    State.preBuildKezalam = true
    Report("Prebuild complete!")
    return true
end

local function doPrebuildNakatra()
    if State.preBuildNakatra then return true end
    Report("Starting prebuild...")
    activateSoulSplit()
    useOverload()
    necroAbilitySetup()
    activateScripture()
    SanctumVariable.CrossedGapPosition = WPOINT.new(API.PlayerCoord().x, API.PlayerCoord().y + 1, API.PlayerCoord().z)
    Report("Crossed gap position: " .. tostring(SanctumVariable.CrossedGapPosition.x) .. ", " .. tostring(SanctumVariable.CrossedGapPosition.y) .. ", " .. tostring(SanctumVariable.CrossedGapPosition.z))
    SanctumVariable.CentralPosition = WPOINT.new(SanctumVariable.CrossedGapPosition.x, SanctumVariable.CrossedGapPosition.y + 7, SanctumVariable.CrossedGapPosition.z)
    Report("Central position: " .. tostring(SanctumVariable.CentralPosition.x) .. ", " .. tostring(SanctumVariable.CentralPosition.y) .. ", " .. tostring(SanctumVariable.CentralPosition.z))
    State.preBuildNakatra = true
    Report("Prebuild complete!")
    return true
end

-- ========================================
-- FIGHT HANDLERS
-- ========================================

local function handleVermyxFight()
    local allObjects = API.ReadAllObjectsArray({-1}, {-1}, {})
    local dodging = false

    local treasure = API.GetAllObjArrayInteract({SanctumMechanics.IDs.SANCTUM_TREASURE}, 20, {0})
    if treasure and #treasure > 0 then
        Report("*** VERMYX KILLED ***")
        State.vermyxKilled = true
        --SanctumMechanics.lootTreasure() -- we aren't going to bother with looting, we will just loot build the loot in the treasure chest
        SanctumMechanics.useArchway()
        return true
    end
    
    -- Priority 1: Boss animation detection (moonstone spawn) - must be FIRST
    if SanctumMechanics.Vermyx.handleMoonstoneSpawn() then dodging = true end
    
    -- Priority 2: Active mechanics
    if not dodging and SanctumMechanics.Vermyx.handleSoulRush(allObjects) then dodging = true end
    if not dodging and SanctumMechanics.Vermyx.handleSoulBomb(allObjects) then dodging = true end
    if not dodging and SanctumMechanics.Vermyx.handleWyrmfire(allObjects) then dodging = true end
    if not dodging and SanctumMechanics.Vermyx.handleMoonstones(allObjects) then dodging = true end
    if not dodging and SanctumMechanics.Vermyx.handlePhaseTransition() then dodging = true end
    --if not dodging and SanctumMechanics.Vermyx.handleScarabHealers(allObjects) then dodging = true end --unnecessary during vermyx
    
    -- Refresh overload if needed
    if not hasOverload() then useOverload() end
    
    -- Handle eating, brewing, and prayer restoration
    SanctumConsumables.update()
    SanctumPrayerManager.update()
    Timers.darkness:execute()
    
    if not dodging then
        SanctumMechanics.attackNPC(Config.VERMYX)
        BossRotation:execute()
    end
    return false
end

local function handleKezalamFight()
    local allObjects = API.ReadAllObjectsArray({-1}, {-1}, {})
    local dodging = false
    
    local boss = API.GetAllObjArrayInteract({Config.KEZALAM}, 50, {1})

    local treasure = API.GetAllObjArrayInteract({SanctumMechanics.IDs.SANCTUM_TREASURE}, 20, {0})
    if treasure and #treasure > 0 then
        Report("*** KEZALAM KILLED ***")
        API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {treasure[1].ID}, 20)
        API.RandomSleep2(1800, 1800, 1800) -- wait for chest to open so we can then teleport out immediately after looting
        State.kezalamKilled = true
        return true
    end
    
    if boss and #boss > 0 then
        local hp = boss[1].HP or 100
        if hp > 100 then hp = (hp / (boss[1].Max_health or 900000)) * 100 end
        SanctumMechanics.Kezalam.updatePhase(hp)
    end
    
    if not boss or #boss == 0 then
        return false
    end

    -- print("ANIMATION: " .. boss[1].Anim)
    
    if boss[1].Anim ~= 36038 and SanctumMechanics.Kezalam.state.isMoonObeliskPhase then
        print("Obelisk is now over, go back to normal fight mode.")
            local boss = API.FindNPCbyName("Kezalam, the Wanderer", 20)
            if not boss then return false end
            local bossTile = boss.Tile_XYZ

            print("[Kezalam] Moving to center position")
            API.DoAction_Dive_Tile(WPOINT.new(bossTile.x + 3, bossTile.y, bossTile.z))
            API.RandomSleep2(600, 600, 600)
            API.DoAction_Tile(WPOINT.new(bossTile.x + 5, bossTile.y, bossTile.z))
            API.RandomSleep2(600, 600, 600)
            SanctumMechanics.Kezalam.state.isMoonObeliskPhase = false
            SanctumMechanics.Kezalam.state.isHandlingObelisks = false
    end

    -- Detect moon obelisk phase trigger (animation 36038)
    if boss[1].Anim == 36038 and not SanctumMechanics.Kezalam.state.isMoonObeliskPhase then
        SanctumMechanics.Kezalam.state.isMoonObeliskPhase = true
        SanctumMechanics.Kezalam.state.obeliskPhaseNumber = (SanctumMechanics.Kezalam.state.obeliskPhaseNumber or 0) + 1
        SanctumMechanics.Kezalam.state.returningToCenter = false
        print("[Kezalam] Moon Obelisk Phase " .. SanctumMechanics.Kezalam.state.obeliskPhaseNumber .. " started!")
    end

    print("moonphase: " .. tostring(SanctumMechanics.Kezalam.state.isMoonObeliskPhase))
    print("INTERACTING WITH: " .. API.ReadLpInteracting().Name)
    
    if not dodging and SanctumMechanics.Kezalam.handleVolatileScarabs() then dodging = true end
    if not dodging and SanctumMechanics.Kezalam.handlePrison() then dodging = true end
    if not dodging and SanctumMechanics.Kezalam.handleSanctumBlast(allObjects) then dodging = true end
    if not dodging and SanctumMechanics.Kezalam.handleLineBlast(allObjects) then dodging = true end

    -- After any dodge, always return to optimal position (boss + 5 tiles east)
    -- But wait for line blast tiles to fully clear first
    if dodging
        and not SanctumMechanics.Kezalam.state.inPrison
        and not SanctumMechanics.Kezalam.state.isHandlingScarabs
        and not SanctumMechanics.Kezalam.state.isMoonObeliskPhase
    then
        -- Check if line blast tiles are still active - don't walk back into them
        local freshObjects = API.ReadAllObjectsArray({-1}, {-1}, {})
        local remainingBlast = SanctumMechanics.Kezalam.getLineBlastTiles(freshObjects)
        if remainingBlast and #remainingBlast > 0 then
            debugLog("[Kezalam] Line blast still active (" .. #remainingBlast .. " tiles), waiting before returning")
            return false
        end

        local boss2 = API.FindNPCbyName("Kezalam, the Wanderer", 20)
        if boss2 then
            local bt = boss2.Tile_XYZ
            local optimalTile = WPOINT.new(bt.x + 5, bt.y, bt.z)
            local playerPos = API.PlayerCoord()
            local distToOptimal = math.abs(playerPos.x - optimalTile.x) + math.abs(playerPos.y - optimalTile.y)
            if distToOptimal > 1 then
                debugLog("[Kezalam] Returning to optimal position after dodge")
                API.DoAction_Tile(optimalTile)
                API.RandomSleep2(800, 800, 800)
            end
        end
    end

    -- Handle eating, brewing, and prayer restoration
    SanctumConsumables.update()
    SanctumPrayerManager.update()
    Timers.darkness:execute()

    -- Moon Obelisk Phase Logic
    if SanctumMechanics.Kezalam.state.isMoonObeliskPhase then
        local obeliskPhase = SanctumMechanics.Kezalam.state.obeliskPhaseNumber or 1
        local targetObeliskId = (obeliskPhase == 1) and Config.MOON_OBELISK_1 or Config.MOON_OBELISK_2
        local activeObeliskRotation = (obeliskPhase == 1) and Obelisk1Rotation or Obelisk2Rotation

        -- Re-query obelisk fresh (the top-of-function query may be stale/empty if obelisk hasn't spawned yet)
        local currentObelisks = API.GetAllObjArrayInteract({targetObeliskId}, 100, {1})

        -- Check if the current obelisk is dead
        if not currentObelisks or #currentObelisks == 0 then
            print("[Kezalam] Obelisk " .. obeliskPhase .. " is dead! Returning to center...")
            print("[Kezalam] Current Target: " .. API.ReadLpInteracting().Name)
            SanctumMechanics.Kezalam.state.isHandlingObelisks = false  -- Clear flag

            -- Reset scarab tracking for next obelisk phase
            SanctumMechanics.Kezalam.state.obeliskScarabSpawnTime = nil
            SanctumMechanics.Kezalam.state.obeliskScarabPowerburstUsed = false

            -- PVME: Use Life Transfer as soon as pillar is dead
            local lifeTransfer = API.GetABs_name("Life Transfer", false)
            if lifeTransfer and lifeTransfer.enabled and lifeTransfer.cooldown_timer <= 1 then
                API.DoAction_Ability("Life Transfer", 1, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(100, 50, 50)
                print("[Kezalam] Used Life Transfer after obelisk death")
            end

            -- Reset obelisk rotations for next use
            Obelisk1Rotation:reset()
            Obelisk2Rotation:reset()

            local centerPos = SanctumVariable.CentralPosition
            if not centerPos then
                print("[Kezalam] No CentralPosition set, ending obelisk phase")
                SanctumMechanics.Kezalam.state.isMoonObeliskPhase = false
                SanctumMechanics.Kezalam.state.returningToCenter = false
                return false
            end

            local playerPos = API.PlayerCoord()
            local distToCenter = math.sqrt((playerPos.x - centerPos.x)^2 + (playerPos.y - centerPos.y)^2)

            if distToCenter <= 3 then
                print("[Kezalam] Returned to center, resuming Kezalam fight!")
                SanctumMechanics.Kezalam.state.isMoonObeliskPhase = false
                SanctumMechanics.Kezalam.state.returningToCenter = false
            else
                -- Move toward CentralPosition
                if not SanctumMechanics.Kezalam.state.returningToCenter then
                    SanctumMechanics.Kezalam.state.returningToCenter = true
                    print("[Kezalam] Moving to center position (dist: " .. string.format("%.1f", distToCenter) .. ")")
                    API.DoAction_Dive_Tile(WPOINT.new(centerPos.x + 3, centerPos.y, centerPos.z))
                    API.RandomSleep2(200, 50, 400)
                end
                API.DoAction_Tile(WPOINT.new(centerPos.x + 5, centerPos.y, centerPos.z))
                -- API.RandomSleep2(600, 600, 600)
            end
            return false
        end

        -- Obelisk is still alive - set flag and attack it
        SanctumMechanics.Kezalam.state.isHandlingObelisks = true

        -- Check for Volatile Scarabs during obelisk phase - use Powerburst of Vitality to survive explosion
        local obeliskScarabs = API.GetAllObjArrayInteract({Config.VOLATILE_SCARAB}, 30, {1})
        if obeliskScarabs and #obeliskScarabs > 0 then
            -- Scarabs detected - record spawn time if not already tracked
            if not SanctumMechanics.Kezalam.state.obeliskScarabSpawnTime then
                SanctumMechanics.Kezalam.state.obeliskScarabSpawnTime = os.time()
                SanctumMechanics.Kezalam.state.obeliskScarabPowerburstUsed = false
                print("[Kezalam] Volatile Scarabs detected during obelisk phase!")
            end

            -- Use Powerburst of Vitality 2-3 seconds after spawn (before explosion)
            local timeSinceSpawn = os.time() - SanctumMechanics.Kezalam.state.obeliskScarabSpawnTime
            if timeSinceSpawn >= 2 and not SanctumMechanics.Kezalam.state.obeliskScarabPowerburstUsed then
                -- Check if Powerburst is available and use it
                local powerburst = API.GetABs_name1("Powerburst of vitality")
                if powerburst and powerburst.enabled and powerburst.cooldown_timer <= 1 then
                    API.DoAction_Ability("Powerburst of vitality", 1, API.OFF_ACT_GeneralInterface_route)
                    API.RandomSleep2(100, 50, 50)
                    SanctumMechanics.Kezalam.state.obeliskScarabPowerburstUsed = true
                    print("[Kezalam] Used Powerburst of Vitality to survive scarab explosion!")
                else
                    -- Try inventory if not on action bar
                    if API.DoAction_Inventory3("Powerburst of vitality", 0, 1, API.OFF_ACT_GeneralInterface_route) then
                        SanctumMechanics.Kezalam.state.obeliskScarabPowerburstUsed = true
                        print("[Kezalam] Used Powerburst of Vitality (from inventory) to survive scarab explosion!")
                    end
                end
            end
        else
            -- Scarabs cleared - reset tracking
            if SanctumMechanics.Kezalam.state.obeliskScarabSpawnTime then
                SanctumMechanics.Kezalam.state.obeliskScarabSpawnTime = nil
                SanctumMechanics.Kezalam.state.obeliskScarabPowerburstUsed = false
            end
        end

        local currentTarget = API.ReadLpInteracting().Name
        local attacking = API.GetInCombBit
        print("[Kezalam] Current Target: " .. currentTarget)
        if currentTarget ~= "Moonstone Obelisk" then
            print("[Kezalam] Switching to Obelisk " .. obeliskPhase)
            API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {targetObeliskId}, 50)
            API.RandomSleep2(800, 800, 800)
            if not attacking then
                API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route, false)
                API.RandomSleep2(300, 300, 300)
                API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {targetObeliskId}, 50)
            end
            -- Reset the rotation when first targeting the obelisk
            --activeObeliskRotation:reset()
            --API.RandomSleep2(1000, 1000, 1000)
            return false
        end

        -- Already targeting obelisk - execute the PVME obelisk rotation
        if not dodging then
            activeObeliskRotation:execute()
        end
        return false
    end

    -- Ensure we're at optimal position (boss+5) when not doing any mechanics
    if not dodging
        and not SanctumMechanics.Kezalam.state.inPrison
        and not SanctumMechanics.Kezalam.state.isHandlingScarabs
    then
        local possBoss = API.FindNPCbyName("Kezalam, the Wanderer", 20)
        if possBoss then
            local bt = possBoss.Tile_XYZ
            local optimalTile = WPOINT.new(bt.x + 5, bt.y, bt.z)
            local playerPos = API.PlayerCoord()
            local distToOptimal = math.abs(playerPos.x - optimalTile.x) + math.abs(playerPos.y - optimalTile.y)
            if distToOptimal > 1 then
                debugLog("[Kezalam] Out of position (dist: " .. distToOptimal .. "), moving to boss+5")
                API.DoAction_Tile(optimalTile)
                API.RandomSleep2(600, 600, 600)
            end
        end
    end

    -- Normal Kezalam combat
    if not dodging and not SanctumMechanics.Kezalam.state.inPrison then
        SanctumMechanics.attackNPC(Config.KEZALAM)
    end
    if not dodging then
        BossRotation:execute()
    end
    return false
end

local function handleNakatraFight()
    -- Handle eating, brewing, and prayer restoration
    SanctumConsumables.update()
    SanctumPrayerManager.update()
    Timers.darkness:execute()
    
    SanctumMechanics.attackNPC(Config.NAKATRA)
    BossRotation:execute()
    
    local treasure = API.GetAllObjArrayInteract({SanctumMechanics.IDs.SANCTUM_TREASURE}, 50, {12})
    if treasure and #treasure > 0 then
        Report("*** NAKATRA KILLED ***")
        SanctumMechanics.lootTreasure()
        State.nakatraKilled = true
        return true
    end
    return false
end

-- ========================================
-- LOCATION DETECTION
-- ========================================

detectLocation = function()
    if DeathRecovery.isAtDeathsOffice() then return "DEATHS_OFFICE" end
    if Utils.isAtWarsRetreat() then return "WARS_RETREAT" end
    
    -- CRITICAL: Check ALL gaps/ledges BEFORE any boss NPCs!
    -- You can see bosses from the entrance areas, so gaps must be checked first
    
    -- Vermyx gap (entrance) - check this FIRST before Vermyx boss
    local vermyxGap = API.GetAllObjArrayInteract({SanctumMechanics.IDs.VERMYX_GAP}, 100, {12})
    if vermyxGap and #vermyxGap > 0 then 
        print("[Location] Found Vermyx gap - at VERMYX_ENTRANCE")
        return "VERMYX_ENTRANCE" 
    end
    
    -- Kezalam ledge - check BEFORE Kezalam boss
    local ledge = API.GetAllObjArrayInteract({SanctumMechanics.IDs.KEZALAM_LEDGE}, 100, {12})
    if ledge and #ledge > 0 then 
        print("[Location] Found Kezalam ledge - at KEZALAM_LEDGE")
        return "KEZALAM_LEDGE" 
    end
    
    -- Nakatra gap - check BEFORE Nakatra boss
    local nakaGap = API.GetAllObjArrayInteract({SanctumMechanics.IDs.NAKATRA_GAP}, 100, {12})
    if nakaGap and #nakaGap > 0 then 
        print("[Location] Found Nakatra gap - at NAKATRA_ENTRANCE")
        return "NAKATRA_ENTRANCE" 
    end
    
    -- Loot room (treasure chest)
    local treasure = API.GetAllObjArrayInteract({SanctumMechanics.IDs.SANCTUM_TREASURE}, 20, {0})
    if treasure and #treasure > 0 then return "LOOT_ROOM" end
    
    -- Transition archway
    local archway = API.GetAllObjArrayInteract({SanctumMechanics.IDs.ARCHWAY}, 20, {0})
    if archway and #archway > 0 then return "TRANSITION" end
    
    -- NOW check for boss NPCs (only if no gaps/ledges found)
    local vermyx = API.GetAllObjArrayInteract({Config.VERMYX}, 50, {1})
    if vermyx and #vermyx > 0 then return "VERMYX_ARENA" end
    
    local kezalam = API.GetAllObjArrayInteract({Config.KEZALAM}, 50, {1})
    if kezalam and #kezalam > 0 then return "KEZALAM_ARENA" end
    
    local nakatra = API.GetAllObjArrayInteract({Config.NAKATRA}, 50, {1})
    if nakatra and #nakatra > 0 then return "NAKATRA_ARENA" end
    
    local portal = API.GetAllObjArrayInteract({Config.SANCTUM_PORTAL}, 50, {12})
    if portal and #portal > 0 then return "WARS_RETREAT" end
    
    return "UNKNOWN"
end

-- ========================================
-- STATE MACHINE
-- ========================================

local function executeState()
    local state = State.currentState
    
    if DeathRecovery.isAtDeathsOffice() then
        Report("*** AT DEATH'S OFFICE ***")
        State.currentState = States.DEATH_RECOVERY
        state = States.DEATH_RECOVERY
    end
    
    if state == States.DEATH_RECOVERY then
        if DeathRecovery.handleDeathRecovery() then
            State.currentState = States.BANKING
        end
        return
    end
    
    if state == States.IDLE then
        local location = detectLocation()
        debugLog("Location: " .. location)
        
        if location == "WARS_RETREAT" then
            State.currentState = State.needsExternalChestCheck and States.CHECKING_EXTERNAL_CHEST or States.BANKING
        elseif location == "VERMYX_ENTRANCE" then
            State.currentState = States.CROSSING_GAP_VERMYX
        elseif location == "VERMYX_ARENA" then
            State.currentState = States.FIGHTING_VERMYX
        elseif location == "KEZALAM_LEDGE" then
            State.currentState = States.CROSSING_LEDGE_KEZALAM
        elseif location == "KEZALAM_ARENA" then
            State.currentState = States.FIGHTING_KEZALAM
        elseif location == "NAKATRA_ENTRANCE" then
            State.currentState = States.CROSSING_GAP_NAKATRA
        elseif location == "NAKATRA_ARENA" then
            State.currentState = States.FIGHTING_NAKATRA
        elseif location == "TRANSITION" then
            if State.vermyxKilled and not State.kezalamKilled then
                State.currentState = States.TRANSITIONING_TO_KEZALAM
            elseif State.kezalamKilled and not State.nakatraKilled then
                State.currentState = States.TRANSITIONING_TO_NAKATRA
            end
        elseif location == "LOOT_ROOM" then
            SanctumMechanics.lootTreasure()
        end
        
    elseif state == States.CHECKING_EXTERNAL_CHEST then
        if WarsRetreat.checkExternalChest() then State.currentState = States.BANKING end
        
    elseif state == States.BANKING then
        if WarsRetreat.bank() then State.currentState = States.USING_ALTAR end
        
    elseif state == States.USING_ALTAR then
        if WarsRetreat.useAltar() then State.currentState = States.USING_BONFIRE end
        
    elseif state == States.USING_BONFIRE then
        if WarsRetreat.useBonfire() then State.currentState = States.USING_ADRENALINE end
        
    elseif state == States.USING_ADRENALINE then
        if WarsRetreat.useAdrenalineCrystal() then State.currentState = States.ENTERING_PORTAL end
        
    elseif state == States.ENTERING_PORTAL then
        if WarsRetreat.enterPortal() then State.currentState = States.ENTERING_INSTANCE end
        
    elseif state == States.ENTERING_INSTANCE then
        if WarsRetreat.enterInstance() then
            -- After entering instance, route based on where we ended up
            local location = detectLocation()
            debugLog("Post-instance location: " .. location)
            
            if location == "LOOT_ROOM" then
                -- At a loot room from previous kill - loot first then continue
                SanctumMechanics.lootTreasure()
                -- After looting, detect where to go next
                if State.kezalamKilled then
                    State.currentState = States.TRANSITIONING_TO_NAKATRA
                elseif State.vermyxKilled then
                    State.currentState = States.TRANSITIONING_TO_KEZALAM
                else
                    State.currentState = States.CROSSING_GAP_VERMYX
                end
            elseif location == "KEZALAM_LEDGE" then
                State.currentState = States.CROSSING_LEDGE_KEZALAM
            elseif location == "KEZALAM_ARENA" then
                State.currentState = States.FIGHTING_KEZALAM
            elseif location == "NAKATRA_ENTRANCE" then
                State.currentState = States.CROSSING_GAP_NAKATRA
            elseif location == "NAKATRA_ARENA" then
                State.currentState = States.FIGHTING_NAKATRA
            elseif location == "VERMYX_ARENA" then
                State.currentState = States.FIGHTING_VERMYX
            elseif location == "TRANSITION" then
                -- At archway between areas
                if State.kezalamKilled then
                    State.currentState = States.TRANSITIONING_TO_NAKATRA
                elseif State.vermyxKilled then
                    State.currentState = States.TRANSITIONING_TO_KEZALAM
                else
                    State.currentState = States.CROSSING_GAP_VERMYX
                end
            else
                -- Default: start from beginning
                State.currentState = States.CROSSING_GAP_VERMYX
            end
        end
        
    elseif state == States.CROSSING_GAP_VERMYX then
        if SanctumMechanics.Vermyx.crossGap() then
            doPrebuildVermyx()
            State.currentState = States.FIGHTING_VERMYX
        end
        
    elseif state == States.FIGHTING_VERMYX then
        if handleVermyxFight() then State.currentState = States.VERMYX_COMPLETE end
        
    elseif state == States.VERMYX_COMPLETE then
        Report("Vermyx complete!")
        State.currentState = States.TRANSITIONING_TO_KEZALAM
        
    elseif state == States.TRANSITIONING_TO_KEZALAM then
        if SanctumMechanics.useArchway() then State.currentState = States.CROSSING_LEDGE_KEZALAM end
        
    elseif state == States.CROSSING_LEDGE_KEZALAM then
        if SanctumMechanics.Kezalam.jumpLedge() then
            API.RandomSleep2(1800,1800,1800)
            doPrebuildKezalam()
            SanctumMechanics.Kezalam.resetState()
            State.currentState = States.FIGHTING_KEZALAM
        end
        
    elseif state == States.FIGHTING_KEZALAM then
        if handleKezalamFight() then State.currentState = States.KEZALAM_COMPLETE end
        
    elseif state == States.KEZALAM_COMPLETE then
        Report("Kezalam complete! Teleporting to War's Retreat to resupply...")
        State.currentState = States.RESUPPLY_TELEPORT_OUT

    elseif state == States.RESUPPLY_TELEPORT_OUT then
        Utils.postKillCleanup()
        API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route, true)
        API.RandomSleep2(3000, 600, 900)
        Utils.waitForIdle(50)
        API.RandomSleep2(2000, 400, 600)
        Report("Back at War's Retreat for resupply")
        State.currentState = States.RESUPPLY_BANKING

    elseif state == States.RESUPPLY_BANKING then
        if WarsRetreat.bank() then State.currentState = States.RESUPPLY_ALTAR end

    elseif state == States.RESUPPLY_ALTAR then
        if WarsRetreat.useAltar() then State.currentState = States.RESUPPLY_ADRENALINE end

    elseif state == States.RESUPPLY_ADRENALINE then
        if WarsRetreat.useAdrenalineCrystal() then State.currentState = States.RESUPPLY_ENTER_PORTAL end

    elseif state == States.RESUPPLY_ENTER_PORTAL then
        if WarsRetreat.enterPortal() then State.currentState = States.RESUPPLY_ENTER_INSTANCE end

    elseif state == States.RESUPPLY_ENTER_INSTANCE then
        if WarsRetreat.enterInstance() then
            local location = detectLocation()
            Report("Re-entered instance at: " .. location)
            if location == "NAKATRA_ENTRANCE" then
                State.currentState = States.CROSSING_GAP_NAKATRA
            elseif location == "NAKATRA_ARENA" then
                State.currentState = States.FIGHTING_NAKATRA
            elseif location == "LOOT_ROOM" then
                SanctumMechanics.lootTreasure()
                State.currentState = States.TRANSITIONING_TO_NAKATRA
            elseif location == "TRANSITION" then
                State.currentState = States.TRANSITIONING_TO_NAKATRA
            else
                State.currentState = States.TRANSITIONING_TO_NAKATRA
            end
        end

    elseif state == States.TRANSITIONING_TO_NAKATRA then
        if SanctumMechanics.useArchway() then State.currentState = States.CROSSING_GAP_NAKATRA end
        
    elseif state == States.CROSSING_GAP_NAKATRA then
        if SanctumMechanics.Nakatra.crossGap() then
            doPrebuildNakatra()
            State.currentState = States.FIGHTING_NAKATRA
        end
        
    elseif state == States.FIGHTING_NAKATRA then
        if handleNakatraFight() then State.currentState = States.NAKATRA_COMPLETE end
        
    elseif state == States.NAKATRA_COMPLETE then
        Report("*** ALL BOSSES KILLED! ***")
        State.currentState = States.TELEPORTING_OUT
        
    elseif state == States.TELEPORTING_OUT then
        if WarsRetreat.teleportOut() then
            State.runsCompleted = State.runsCompleted + 1
            SanctumConsumables.reset()  -- Reset consumable cooldowns
            
            -- Log supplies status
            local status = SanctumConsumables.getStatus()
            print("========================================")
            print("RUN COMPLETE! Total: " .. State.runsCompleted)
            print("Supplies: Food=" .. tostring(status.hasFood) .. " Brews=" .. tostring(status.hasBrews) .. " Restores=" .. tostring(status.hasRestores))
            print("========================================")
            
            State.currentState = States.IDLE
        end
    end
end

-- ========================================
-- GUI HELPERS
-- ========================================

local STATE_NAMES = {
    [States.IDLE] = "Idle",
    [States.CHECKING_EXTERNAL_CHEST] = "War's Retreat",
    [States.BANKING] = "Banking",
    [States.USING_ALTAR] = "Altar",
    [States.USING_BONFIRE] = "Bonfire",
    [States.USING_ADRENALINE] = "Adrenaline",
    [States.ENTERING_PORTAL] = "Entering Portal",
    [States.ENTERING_INSTANCE] = "Entering Instance",
    [States.CROSSING_GAP_VERMYX] = "Vermyx",
    [States.FIGHTING_VERMYX] = "Vermyx",
    [States.VERMYX_COMPLETE] = "Looting",
    [States.TRANSITIONING_TO_KEZALAM] = "Transition",
    [States.CROSSING_LEDGE_KEZALAM] = "Kezalam",
    [States.FIGHTING_KEZALAM] = "Kezalam",
    [States.KEZALAM_COMPLETE] = "Looting",
    [States.TRANSITIONING_TO_NAKATRA] = "Transition",
    [States.CROSSING_GAP_NAKATRA] = "Nakatra",
    [States.FIGHTING_NAKATRA] = "Nakatra",
    [States.NAKATRA_COMPLETE] = "Looting",
    [States.TELEPORTING_OUT] = "Teleporting",
    [States.DEATH_RECOVERY] = "Death Recovery",
    [States.RESUPPLY_TELEPORT_OUT] = "Resupply",
    [States.RESUPPLY_BANKING] = "Resupply",
    [States.RESUPPLY_ALTAR] = "Resupply",
    [States.RESUPPLY_ADRENALINE] = "Resupply",
    [States.RESUPPLY_ENTER_PORTAL] = "Resupply",
    [States.RESUPPLY_ENTER_INSTANCE] = "Resupply",
}

local BOSS_NAMES = {
    [States.CROSSING_GAP_VERMYX] = "Vermyx",
    [States.FIGHTING_VERMYX] = "Vermyx",
    [States.CROSSING_LEDGE_KEZALAM] = "Kezalam",
    [States.FIGHTING_KEZALAM] = "Kezalam",
    [States.CROSSING_GAP_NAKATRA] = "Nakatra",
    [States.FIGHTING_NAKATRA] = "Nakatra",
}

local BOSS_MAX_HEALTH = {
    Vermyx = 600000,
    Kezalam = 900000,
    Nakatra = 750000,
}

-- Run time tracking
local runStartTime = nil
local runTimes = {}

local function buildGUIData()
    local stateName = STATE_NAMES[State.currentState] or "Unknown"
    local bossName = BOSS_NAMES[State.currentState]
    local bossHealth, bossMaxHealth = nil, nil

    -- Get boss HP if fighting
    if State.currentState == States.FIGHTING_VERMYX then
        local boss = API.GetAllObjArrayInteract({Config.VERMYX}, 50, {1})
        if boss and #boss > 0 then
            bossHealth = boss[1].HP or 0
            bossMaxHealth = boss[1].Max_health or BOSS_MAX_HEALTH.Vermyx
        end
    elseif State.currentState == States.FIGHTING_KEZALAM then
        local boss = API.GetAllObjArrayInteract({Config.KEZALAM}, 50, {1})
        if boss and #boss > 0 then
            bossHealth = boss[1].HP or 0
            bossMaxHealth = boss[1].Max_health or BOSS_MAX_HEALTH.Kezalam
        end
    elseif State.currentState == States.FIGHTING_NAKATRA then
        local boss = API.GetAllObjArrayInteract({Config.NAKATRA}, 50, {1})
        if boss and #boss > 0 then
            bossHealth = boss[1].HP or 0
            bossMaxHealth = boss[1].Max_health or BOSS_MAX_HEALTH.Nakatra
        end
    end

    -- Calculate runs per hour
    local runsPerHour = "0"
    local runtime = API.ScriptRuntime()
    if runtime and runtime > 0 and State.runsCompleted > 0 then
        local rph = (State.runsCompleted / runtime) * 3600
        runsPerHour = string.format("%.1f", rph)
    end

    -- Kill timer
    local killTimer = nil
    if runStartTime and (State.currentState == States.FIGHTING_VERMYX or
        State.currentState == States.FIGHTING_KEZALAM or
        State.currentState == States.FIGHTING_NAKATRA or
        State.currentState == States.CROSSING_GAP_VERMYX or
        State.currentState == States.CROSSING_LEDGE_KEZALAM or
        State.currentState == States.CROSSING_GAP_NAKATRA or
        State.currentState == States.VERMYX_COMPLETE or
        State.currentState == States.KEZALAM_COMPLETE or
        State.currentState == States.TRANSITIONING_TO_KEZALAM or
        State.currentState == States.TRANSITIONING_TO_NAKATRA or
        State.currentState == States.RESUPPLY_TELEPORT_OUT or
        State.currentState == States.RESUPPLY_BANKING or
        State.currentState == States.RESUPPLY_ALTAR or
        State.currentState == States.RESUPPLY_ADRENALINE or
        State.currentState == States.RESUPPLY_ENTER_PORTAL or
        State.currentState == States.RESUPPLY_ENTER_INSTANCE) then
        local elapsed = os.time() - runStartTime
        killTimer = string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60)
    end

    -- Run time stats
    local fastestRun, slowestRun, averageRun = nil, nil, nil
    if #runTimes > 0 then
        local fastest, slowest, total = runTimes[1], runTimes[1], 0
        for _, t in ipairs(runTimes) do
            if t < fastest then fastest = t end
            if t > slowest then slowest = t end
            total = total + t
        end
        local avg = total / #runTimes
        fastestRun = string.format("%02d:%02d", math.floor(fastest / 60), fastest % 60)
        slowestRun = string.format("%02d:%02d", math.floor(slowest / 60), slowest % 60)
        averageRun = string.format("%02d:%02d", math.floor(avg / 60), math.floor(avg) % 60)
    end

    -- Recent runs
    local recentRuns = {}
    for i = math.max(1, #runTimes - 4), #runTimes do
        local t = runTimes[i]
        recentRuns[#recentRuns + 1] = {
            duration = string.format("%02d:%02d", math.floor(t / 60), t % 60)
        }
    end

    return {
        state = stateName,
        location = stateName,
        status = stateName,
        currentBoss = bossName,
        bossHealth = bossHealth,
        bossMaxHealth = bossMaxHealth,
        runsCompleted = State.runsCompleted,
        runsPerHour = runsPerHour,
        killTimer = killTimer,
        fastestRun = fastestRun,
        slowestRun = slowestRun,
        averageRun = averageRun,
        recentRuns = recentRuns,
    }
end

-- ========================================
-- MAIN
-- ========================================

print("========================================")
print("   Sanctum of Rebirth HM v" .. VERSION)
print("========================================")
print("Features: Wars Retreat, Death Recovery, All 3 Bosses")

-- GUI: Pre-start configuration
SanctumGUI.reset()
SanctumGUI.loadConfig()

ClearRender()
DrawImGui(function()
    if SanctumGUI.open then
        SanctumGUI.draw({})
    end
end)

print("Waiting for configuration...")

while API.Read_LoopyLoop() and not SanctumGUI.started do
    if not SanctumGUI.open then
        print("GUI closed before start")
        ClearRender()
        return
    end
    if SanctumGUI.isCancelled() then
        print("Script cancelled by user")
        ClearRender()
        return
    end
    API.RandomSleep2(100, 50, 0)
end

-- GUI: Apply configuration
local guiConfig = SanctumGUI.getConfig()
SanctumConsumables.setEatThreshold(guiConfig.healthFood)
SanctumConsumables.setBrewThreshold(guiConfig.healthBrew)
SanctumConsumables.setComboThreshold(guiConfig.healthCombo)
SanctumConsumables.setPrayerThreshold(guiConfig.prayerRestore)
SanctumConsumables.setDebug(guiConfig.debugConsumables)
Config.startWithFullAdrenaline = guiConfig.startWithFullAdrenaline
debug = guiConfig.debugMain

print("Configuration applied! Starting...")

-- GUI: Runtime rendering
DrawImGui(function()
    if SanctumGUI.open then
        SanctumGUI.draw(buildGUIData())
    end
end)
SanctumGUI.selectInfoTab = true

while API.Read_LoopyLoop() do
    if SanctumGUI.isStopped() then
        print("Script stopped by user")
        break
    end

    if API.PlayerLoggedIn() and not SanctumGUI.isPaused() then
        -- Track run start time
        if not runStartTime and (State.currentState == States.CROSSING_GAP_VERMYX or State.currentState == States.FIGHTING_VERMYX) then
            runStartTime = os.time()
        end

        executeState()

        -- Track run completion
        if State.currentState == States.TELEPORTING_OUT and runStartTime then
            local elapsed = os.time() - runStartTime
            runTimes[#runTimes + 1] = elapsed
            runStartTime = nil
        end
    end
    API.RandomSleep2(100, 50, 50)
end

ClearRender()
print("Script stopped. Runs: " .. State.runsCompleted)
