ScriptName = "Flesh-hatcher Mhekarnahz Killer"
Author = "MemoryError"
Version = "3.0"

local API = require("api")
local GUI = require("fleshhatcher.FleshHatcherGUI")

local Config = {
    BANK_CHEST   = 114750,
    ALTAR        = 114748,
    BOSS_PORTAL  = 114764,
    ENTRANCE     = 134744,
    LEDGE        = 134746,
    CORPSE       = 32508,
    BOSS_ID      = 30823,
    DEATH_ANIM   = 37206,
    MAX_FIGHT    = 300,
    EMERGENCY_HP = 20,
    ADREN_CRYSTAL = 114749,
    INSTANCE_EXPIRY_VARBIT = 9925,
    AOE_3X3      = 8279,
    AOE_OUTER    = 8916,
    AOE_MIDDLE   = 8919,
    AOE_INNER    = 8918,
    ARENA_SIZE   = 15,
    RETURN_PORTAL = 134748,
    PRAYER_POTION_IDS = {2434, 2436, 2438, 2440, 179, 181, 183, 185},
    SUPER_RESTORE_IDS = {3024, 3026, 3028, 3030, 23399, 23401, 23403, 23405},
    PRAYER_DRINK_THRESHOLD = 40,
    PRAYER_EMERGENCY_THRESHOLD = 10,
    SOULSPLIT_BUFF = 26033,
    RUINATION_BUFF = 30769,
    SORROW_BUFF   = 30771,
}

local Stats = {
    startTime     = os.time(),
    kills         = 0,
    deaths        = 0,
    killTimes     = {},
    killStartTime = 0,
    currentState  = "Idle",
    lastIdle      = os.time(),
}

local hasAttacked = false

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

local function buildGUIData()
    local bossHP, bossMaxHP = nil, nil

    if Stats.currentState == "Fighting" then
        local npcs = API.GetAllObjArrayInteract({Config.BOSS_ID}, 50, {1})
        for _, npc in ipairs(npcs) do
            if npc.Id == Config.BOSS_ID and npc.Health then
                bossHP = npc.Health
                bossMaxHP = npc.MaxHealth or 100000
                break
            end
        end
    end

    return {
        state        = Stats.currentState,
        kills        = Stats.kills,
        deaths       = Stats.deaths,
        runtime      = os.time() - Stats.startTime,
        killStartTime = Stats.killStartTime > 0 and Stats.killStartTime or nil,
        killTimes    = Stats.killTimes,
        fastestKill  = getKillStat(function(a, b) return a < b end),
        slowestKill  = getKillStat(function(a, b) return a > b end),
        averageKill  = getAverageKill(),
        bossHealth   = bossHP,
        bossMaxHealth = bossMaxHP,
    }
end


local Utils = {}

function Utils:antiIdle()
    if os.time() - Stats.lastIdle > 120 then
        API.DoRandomEvents()
        API.PIdle2()
        Stats.lastIdle = os.time()
    end
end

function Utils:emergencyCheck()
    if API.GetHPrecent() < Config.EMERGENCY_HP then
        GUI.addWarning("Emergency: HP critically low!")
        return true
    end
    return false
end

function Utils:isSoulsplitActive()
    return API.Buffbar_GetIDstatus(Config.SOULSPLIT_BUFF, false).id > 0
end

function Utils:isCurseActive()
    return API.Buffbar_GetIDstatus(Config.RUINATION_BUFF, false).id > 0
        or API.Buffbar_GetIDstatus(Config.SORROW_BUFF, false).id > 0
end

function Utils:togglePrayer(prayerId)
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1458, 40, prayerId, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(600, 200, 400)
end

function Utils:hasPrayerPots()
    return Inventory:ContainsAny(Config.SUPER_RESTORE_IDS) or Inventory:ContainsAny(Config.PRAYER_POTION_IDS)
end

function Utils:drinkPrayerPot()
    if Inventory:ContainsAny(Config.SUPER_RESTORE_IDS) then
        API.DoAction_Inventory2(Config.SUPER_RESTORE_IDS, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 200, 300)
        return true
    elseif Inventory:ContainsAny(Config.PRAYER_POTION_IDS) then
        API.DoAction_Inventory2(Config.PRAYER_POTION_IDS, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 200, 300)
        return true
    end
    return false
end

function Utils:managePrayer()
    local prayPct = API.GetPrayPrecent()
    if prayPct <= Config.PRAYER_EMERGENCY_THRESHOLD then
        if not self:hasPrayerPots() then
            GUI.addWarning("Out of prayer potions and prayer critically low!")
            return "emergency"
        end
        self:drinkPrayerPot()
        return "drank"
    elseif prayPct <= Config.PRAYER_DRINK_THRESHOLD then
        if self:hasPrayerPots() then
            self:drinkPrayerPot()
            return "drank"
        end
    end
    return "ok"
end

function Utils:activateCurse()
    if self:isCurseActive() then return true end

    local sorrow = API.GetABs_name("Sorrow", true)
    local ruination = API.GetABs_name("Ruination", true)

    if sorrow.enabled then
        API.DoAction_Ability("Sorrow", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 200, 400)
        return true
    elseif ruination.enabled then
        API.DoAction_Ability("Ruination", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 200, 400)
        return true
    end

    GUI.addWarning("Neither Sorrow nor Ruination found on ability bar")
    return false
end

function Utils:deactivateCurse()
    if not self:isCurseActive() then return end

    local sorrow = API.GetABs_name("Sorrow", true)
    local ruination = API.GetABs_name("Ruination", true)

    if sorrow.enabled then
        API.DoAction_Ability("Sorrow", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 200, 400)
    elseif ruination.enabled then
        API.DoAction_Ability("Ruination", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 200, 400)
    end
end


local WarsRetreat = {}

function WarsRetreat:teleport()
    if not API.Read_LoopyLoop() then return false end
    Stats.currentState = "Teleporting"

    if Utils:isSoulsplitActive() then
        Utils:togglePrayer(35)
    end
    Utils:deactivateCurse()

    API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(3000, 1200, 1800)
    return true
end

function WarsRetreat:bank()
    if not API.Read_LoopyLoop() then return false end
    Stats.currentState = "Banking"

    hasAttacked = false -- reset attack state at the start of each kill cycle

    if not API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, {Config.BANK_CHEST}, 50) then
        GUI.addWarning("Failed to load preset")
        return false
    end

    API.RandomSleep2(3500, 500, 800)

    while API.Read_LoopyLoop() and API.GetHPrecent() < 100 do
        API.RandomSleep2(600, 100, 200)
    end

    return true
end

function WarsRetreat:altar()
    if not API.Read_LoopyLoop() then return false end
    if API.GetPrayPrecent() >= 100 then return true end

    Stats.currentState = "Altar"
    API.DoAction_Object1(0x3d, API.OFF_ACT_GeneralObject_route0, {Config.ALTAR}, 50)
    API.RandomSleep2(3500, 500, 800)
    return true
end

function WarsRetreat:adrenalineCrystal()
    if not API.Read_LoopyLoop() then return false end
    if tonumber(API.GetAdrenalineFromInterface()) >= 100 then return true end

    Stats.currentState = "Adrenaline Crystal"
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {Config.ADREN_CRYSTAL}, 50)
    API.RandomSleep2(2900, 100, 100)

    local surge = API.GetABs_name("Surge", true)
    if surge.enabled and surge.cooldown_timer <= 0 then
        API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(100, 50, 50)
    end

    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {Config.ADREN_CRYSTAL}, 50)
    API.RandomSleep2(1200, 50, 50)

    while API.Read_LoopyLoop() and tonumber(API.GetAdrenalineFromInterface()) < 100 do
        API.RandomSleep2(600, 100, 200)
    end

    return true
end

function WarsRetreat:enterPortal()
    if not API.Read_LoopyLoop() then return false end
    Stats.currentState = "Entering Portal"
    API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {Config.BOSS_PORTAL}, 50)
    API.RandomSleep2(2000, 500, 800)

    local timeout = os.time() + 30
    while API.Read_LoopyLoop() and os.time() < timeout do
        local objs = API.GetAllObjArrayInteract({Config.ENTRANCE}, 50, {0})
        for _, obj in ipairs(objs) do
            if obj.Id == Config.ENTRANCE then
                API.RandomSleep2(600, 200, 400)
                return true
            end
        end
        API.RandomSleep2(600, 100, 200)
    end

    GUI.addWarning("Timed out waiting for boss entrance")
    return false
end


local Boss = {}

function Boss:enterInstance()
    if not API.Read_LoopyLoop() then return false end
    Stats.currentState = "Entering Instance"

    API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {Config.ENTRANCE}, 50)
    API.RandomSleep2(1500, 800, 1200)

    API.KeyboardPress2(0x32, 150, 200)
    API.RandomSleep2(1200, 600, 900)

    if not API.GetInterfaceOpenBySize(1591) then
        API.RandomSleep2(1500, 600, 900)
    end

    if API.GetInterfaceOpenBySize(1591) then
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1591, 60, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1800, 800, 1200)
    else
        GUI.addWarning("Instance interface did not open")
        return false
    end

    return true
end

function Boss:navigate()
    if not API.Read_LoopyLoop() then return false end
    Stats.currentState = "Navigating"

    local surge = API.GetABs_name("Surge", true)
    if surge.enabled and surge.cooldown_timer <= 0 then
        local playerPos = API.PlayerCoord()
        local ledges = API.GetAllObjArrayInteract({Config.LEDGE}, 50, {0})
        local shouldSurge = true
        for _, obj in ipairs(ledges) do
            if obj.Id == Config.LEDGE and obj.Tile_XYZ then
                local dx = playerPos.x - obj.Tile_XYZ.x
                local dy = playerPos.y - obj.Tile_XYZ.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= 5 then
                    shouldSurge = false
                end
                break
            end
        end
        if shouldSurge then
            API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(0, 400, 600)
        end
    end

    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {Config.LEDGE}, 50)
    API.RandomSleep2(2600, 1800, 2800)

    if not Utils:isSoulsplitActive() then
        Utils:togglePrayer(35)
    end
    Utils:activateCurse()

    return true
end

function Boss:findAlive()
    local npcs = API.GetAllObjArrayInteract({Config.BOSS_ID}, 50, {1})
    for _, npc in ipairs(npcs) do
        if npc.Id == Config.BOSS_ID and (not npc.Health or npc.Health > 0) then
            return npc
        end
    end
    return nil
end


local Mechanics = {}
Mechanics.lastDodgeTick = 0

function Mechanics:getCoordsFromObjects(allObjects, objType, objId)
    local coords = {}
    for _, obj in ipairs(allObjects) do
        if obj.Type == objType and obj.Id == objId and obj.Tile_XYZ then
            coords[#coords + 1] = obj.Tile_XYZ
        end
    end
    if #coords > 0 then return coords end
    return nil
end

function Mechanics:isPlayerInDanger(dangerTiles, radius)
    if not dangerTiles then return false end
    local playerPos = API.PlayerCoord()
    for _, tile in ipairs(dangerTiles) do
        if math.abs(playerPos.x - tile.x) + math.abs(playerPos.y - tile.y) <= radius then
            return true
        end
    end
    return false
end

function Mechanics:getBossPos()
    local npcs = API.GetAllObjArrayInteract({Config.BOSS_ID}, 50, {1})
    for _, npc in ipairs(npcs) do
        if npc.Id == Config.BOSS_ID and npc.Tile_XYZ then
            return npc.Tile_XYZ
        end
    end
    return nil
end

function Mechanics:moveToTile(tile)
    local currentTick = API.Get_tick()
    if currentTick - self.lastDodgeTick < 4 then return false end

    local dive = API.GetABs_name("Dive", true)
    if dive.enabled and dive.cooldown_timer <= 0 then
        API.DoAction_Dive_Tile(WPOINT.new(tile.x, tile.y, 0))
        self.lastDodgeTick = currentTick
        return true
    end

    API.DoAction_Tile(WPOINT.new(tile.x, tile.y, 0))
    self.lastDodgeTick = currentTick
    return true
end

function Mechanics:avoidAOE(dangerTiles, radius)
    local currentTick = API.Get_tick()
    if currentTick - self.lastDodgeTick < 4 then return false end
    if not dangerTiles then return false end

    local freeTiles = API.Math_FreeTiles(dangerTiles, radius, Config.ARENA_SIZE, {})
    if not freeTiles or #freeTiles == 0 then return false end

    return self:moveToTile(freeTiles[1])
end

function Mechanics:moveTowardBoss(bossPos, distance)
    local currentTick = API.Get_tick()
    if currentTick - self.lastDodgeTick < 4 then return false end
    if not bossPos then return false end

    local playerPos = API.PlayerCoord()
    local dx = bossPos.x - playerPos.x
    local dy = bossPos.y - playerPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 1 then return false end

    local nx = dx / dist
    local ny = dy / dist
    local targetX = math.floor(playerPos.x + nx * distance)
    local targetY = math.floor(playerPos.y + ny * distance)

    return self:moveToTile({x = targetX, y = targetY, z = 0})
end

function Mechanics:moveAwayFromBoss(bossPos, distance)
    local currentTick = API.Get_tick()
    if currentTick - self.lastDodgeTick < 4 then return false end
    if not bossPos then return false end

    local playerPos = API.PlayerCoord()
    local dx = playerPos.x - bossPos.x
    local dy = playerPos.y - bossPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 1 then
        dx, dy = 1, 0
        dist = 1
    end

    local nx = dx / dist
    local ny = dy / dist
    local targetX = math.floor(playerPos.x + nx * distance)
    local targetY = math.floor(playerPos.y + ny * distance)

    return self:moveToTile({x = targetX, y = targetY, z = 0})
end

function Mechanics:handleMechanics()
    local allObjects = API.ReadAllObjectsArray({4}, {-1}, {})
    if not allObjects or #allObjects == 0 then return false end

    local aoe3x3  = self:getCoordsFromObjects(allObjects, 4, Config.AOE_3X3)
    local outer    = self:getCoordsFromObjects(allObjects, 4, Config.AOE_OUTER)
    local middle   = self:getCoordsFromObjects(allObjects, 4, Config.AOE_MIDDLE)
    local inner    = self:getCoordsFromObjects(allObjects, 4, Config.AOE_INNER)

    -- 3x3 telegraph
    if aoe3x3 and self:isPlayerInDanger(aoe3x3, 2) then
        return self:avoidAOE(aoe3x3, 2)
    end

    -- Outer telegraph
    if outer and self:isPlayerInDanger(outer, 3) then
        return self:avoidAOE(outer, 3)
    end

    -- Middle telegraph
    if middle and self:isPlayerInDanger(middle, 2) then
        return self:avoidAOE(middle, 2)
    end

    -- Inner telegraph
    if inner and self:isPlayerInDanger(inner, 2) then
        return self:avoidAOE(inner, 2)
    end

    return false
end

function Boss:loot()
    Stats.currentState = "Looting"

    if Utils:isSoulsplitActive() then
        Utils:togglePrayer(35)
    end
    Utils:deactivateCurse()

    API.RandomSleep2(0, 400, 800)
    local corpses = API.GetAllObjArrayInteract({Config.CORPSE}, 50, {1})

    if #corpses == 0 then
        GUI.addWarning("No corpse found after kill #" .. Stats.kills)
        return
    end

    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, {Config.CORPSE}, 50)
    API.RandomSleep2(1200, 800, 1200)

    API.DoAction_Interface(0x24, 0xffffffff, 1, 168, 27, -1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1200, 400, 600)
end

function Boss:fight()
    if not API.Read_LoopyLoop() then return "emergency" end
    Stats.currentState = "Fighting"
    Stats.killStartTime = os.time()

    local fightStart = os.time()

    while API.Read_LoopyLoop() do
        if GUI.isStopped() then return "emergency" end

        while GUI.isPaused() and API.Read_LoopyLoop() do
            API.RandomSleep2(200, 50, 100)
        end

        if Utils:emergencyCheck() then return "emergency" end
        if os.time() - fightStart > Config.MAX_FIGHT then return "emergency" end

        -- Manage prayer potions during fight
        if Config.CAMP_BOSS then
            local prayerStatus = Utils:managePrayer()
            if prayerStatus == "emergency" then
                return "no_prayer"
            end
        end

        -- Handle mechanics first (highest priority)
        if Mechanics:handleMechanics() then
            API.RandomSleep2(600, 100, 200)
            -- Re-attack after dodging
            API.DoAction_NPC(0x29, API.OFF_ACT_AttackNPC_route, {Config.BOSS_ID}, 50)
            API.RandomSleep2(600, 100, 200)
        else
            local boss = self:findAlive()

            if hasAttacked and boss and boss.Anim == Config.DEATH_ANIM then
                local killDuration = os.time() - Stats.killStartTime
                Stats.kills = Stats.kills + 1
                Stats.killTimes[#Stats.killTimes + 1] = killDuration
                Stats.killStartTime = 0

                API.RandomSleep2(4000, 800, 1200)
                self:loot()
                return "kill"
            end

            if boss and not hasAttacked then
                API.DoAction_NPC(0x29, API.OFF_ACT_AttackNPC_route, {Config.BOSS_ID}, 50)
                API.RandomSleep2(1500, 300, 500)
                hasAttacked = true
            end

            Utils:antiIdle()
        end

        API.RandomSleep2(600, 100, 200)
    end

    return "emergency"
end

function Boss:returnViaPortal()
    if not API.Read_LoopyLoop() then return false end
    Stats.currentState = "Returning"

    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {Config.RETURN_PORTAL}, 50)
    API.RandomSleep2(3000, 1000, 1500)

    return true
end


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

local function applyGUIConfig()
    local cfg = GUI.getConfig()
    Config.START_AT_WARS = cfg.startAtWars
    Config.TELEPORT_BETWEEN_KILLS = cfg.teleportBetweenKills
    Config.CAMP_BOSS = cfg.campBoss
end

local function startLiveGUI()
    GUI.selectInfoTab = true
    ClearRender()
    DrawImGui(function()
        if GUI.open then GUI.draw(buildGUIData()) end
    end)
end

local function handleFightFailure(result)
    Stats.deaths = Stats.deaths + 1
    Stats.killStartTime = 0

    if result == "no_prayer" then
        GUI.addWarning("Out of prayer potions, teleporting to bank")
    else
        GUI.addWarning("Fight failed, teleporting back")
    end

    WarsRetreat:teleport()
    API.RandomSleep2(0, 1200, 1800)
end

local function runBankCycle()
    if not WarsRetreat:bank() then
        GUI.addWarning("Failed to bank")
        API.RandomSleep2(0, 1000, 2000)
        return
    end

    WarsRetreat:altar()
    WarsRetreat:adrenalineCrystal()

    if not WarsRetreat:enterPortal() then
        GUI.addWarning("Failed to enter portal")
        API.RandomSleep2(0, 600, 1200)
        return
    end

    if not Boss:enterInstance() then
        GUI.addWarning("Failed to enter instance")
        API.RandomSleep2(0, 600, 800)
        return
    end

    Boss:navigate()

    local result = Boss:fight()
    if result ~= "kill" then
        handleFightFailure(result)
        return
    end

    WarsRetreat:teleport()
    API.RandomSleep2(0, 1200, 1800)
end

local function runCampCycle()
    -- Initial entry: bank, enter instance
    if not WarsRetreat:bank() then
        GUI.addWarning("Failed to bank")
        API.RandomSleep2(0, 1000, 2000)
        return
    end

    WarsRetreat:altar()
    WarsRetreat:adrenalineCrystal()

    if not WarsRetreat:enterPortal() then
        GUI.addWarning("Failed to enter portal")
        API.RandomSleep2(0, 600, 1200)
        return
    end

    if not Boss:enterInstance() then
        GUI.addWarning("Failed to enter instance")
        API.RandomSleep2(0, 600, 800)
        return
    end

    Boss:navigate()

    -- Camp loop: fight -> loot -> portal -> ledge -> fight again
    while API.Read_LoopyLoop() and not GUI.isStopped() do
        while GUI.isPaused() and API.Read_LoopyLoop() do
            API.RandomSleep2(200, 50, 100)
        end

        local result = Boss:fight()
        if result ~= "kill" then
            handleFightFailure(result)
            return
        end

        -- After looting, use return portal to go back to ledge area
        if not Boss:returnViaPortal() then
            GUI.addWarning("Failed to use return portal, teleporting out")
            WarsRetreat:teleport()
            API.RandomSleep2(0, 1200, 1800)
            return
        end

        -- Click ledge to re-enter the fight area
        hasAttacked = false
        Boss:navigate()
    end
end

local function runKillCycle()
    if Config.CAMP_BOSS then
        runCampCycle()
    else
        runBankCycle()
    end
end


Write_fake_mouse_do(false)

if not waitForGUIStart() then return end

applyGUIConfig()
startLiveGUI()

while API.Read_LoopyLoop() do
    if GUI.isStopped() then break end

    if GUI.isPaused() then
        Stats.currentState = "Paused"
        API.RandomSleep2(200, 50, 100)
    else
        runKillCycle()
    end
    
    API.RandomSleep2(100, 200, 400)
end

ClearRender()
