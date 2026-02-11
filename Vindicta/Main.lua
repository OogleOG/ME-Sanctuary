--[[
    Vindicta Normal Mode - Necromancy Script
    Version: 2.0
    
    Structure based on Rasial script pattern
    Uses Timer for proper cooldown management
    Uses RotationManager for ability sequencing
]]

local API = require("api")
local Timer = require("core.timer")
local Config = require("Vindicta.config")
local Rotation = require("Vindicta.rotation")

local version = "2.0"
local scriptStartTime = os.time()

--============================================================================
-- PLAYER STATE
--============================================================================

local Player = {
    state = {
        status = "INITIALIZING",
        location = "UNKNOWN",
        inCombat = false,
        phase = 1,
        animation = 0,
        moving = false,
    }
}

--============================================================================
-- UTILITY FUNCTIONS
--============================================================================

local function log(message)
    print("[VINDICTA]: " .. message)
end

local function getHealthPercent()
    local current = API.GetHP_()
    local max = API.GetHPMax_()
    if max == 0 then return 100 end
    return (current / max) * 100
end

local function getPrayerPercent()
    local current = API.GetPray_()
    local max = API.GetPrayMax_()
    if max == 0 then return 100 end
    return (current / max) * 100
end

local function getFreeSlots()
    return Inventory:Invfreecount()
end

--============================================================================
-- ARENA BOUNDS (dynamic based on fight start position)
--============================================================================

local function initializeArenaBounds()
    local playerPos = API.PlayerCoord()
    
    -- Player position = center of arena
    Config.Arena.center = playerPos
    
    -- Calculate bounds: center ± radius
    Config.Arena.minX = playerPos.x - Config.Arena.radius
    Config.Arena.maxX = playerPos.x + Config.Arena.radius
    Config.Arena.minY = playerPos.y - Config.Arena.radius
    Config.Arena.maxY = playerPos.y + Config.Arena.radius
    
    log("Arena center set at: " .. playerPos.x .. ", " .. playerPos.y)
    log("  Bounds X: " .. Config.Arena.minX .. " to " .. Config.Arena.maxX)
    log("  Bounds Y: " .. Config.Arena.minY .. " to " .. Config.Arena.maxY)
end

local function isWithinArena(x, y)
    -- If arena not initialized yet, allow any position
    if not Config.Arena.center then
        return true
    end
    return x >= Config.Arena.minX and x <= Config.Arena.maxX and
           y >= Config.Arena.minY and y <= Config.Arena.maxY
end

local function getArenaCenterTile(z)
    if not Config.Arena.center then
        return nil
    end
    return WPOINT.new(Config.Arena.center.x, Config.Arena.center.y, z)
end

--============================================================================
-- TIMERS
--============================================================================

local Timers = {
    -- Food timer (every 2 ticks minimum between eats)
    food = Timer.new({
        name = "Food Timer",
        cooldown = 2,
        useTicks = true,
        condition = function() return getHealthPercent() < Config.Combat.eatAtPercent end,
        action = function()
            for _, food in ipairs(Config.Food) do
                if Inventory:InvItemcount(food.id) > 0 then
                    API.DoAction_Inventory1(food.id, 0, 1, API.OFF_ACT_GeneralInterface_route)
                    log("Eating: " .. food.name)
                    return true
                end
            end
            return false
        end
    }),
    
    -- Prayer potion timer
    prayerPotion = Timer.new({
        name = "Prayer Potion Timer",
        cooldown = 2,
        useTicks = true,
        condition = function() return getPrayerPercent() < Config.Combat.prayerDrinkPercent end,
        action = function()
            for _, pot in ipairs(Config.PrayerPotions) do
                for _, id in ipairs(pot.ids) do
                    if Inventory:InvItemcount(id) > 0 then
                        API.DoAction_Inventory1(id, 0, 1, API.OFF_ACT_GeneralInterface_route)
                        log("Drinking: " .. pot.name)
                        return true
                    end
                end
            end
            return false
        end
    }),
    
    -- Target timer (every 5 ticks)
    target = Timer.new({
        name = "Target Timer",
        cooldown = 5,
        useTicks = true,
        condition = function() return Player.state.inCombat and not API.IsTargeting() end,
        action = function()
            API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, Config.Boss.ids, 50)
            return true
        end
    }),
    
    -- Fire avoidance (check frequently, react quickly)
    fire = Timer.new({
        name = "Fire Timer",
        cooldown = 1, -- Check every tick
        useTicks = true,
        condition = function()
            local fire = API.GetAllObjArray1({Config.Boss.fireObjectId}, 2, {0, 12})
            return fire and #fire > 0
        end,
        action = function()
            local playerPos = API.PlayerCoord()
            local safeTile = nil
            
            -- Directions to try (prioritize sides, then diagonals)
            local directions = {
                {x = 5, y = 0},   -- East
                {x = -5, y = 0},  -- West
                {x = 0, y = 5},   -- North
                {x = 0, y = -5},  -- South
                {x = 4, y = 4},   -- NE
                {x = -4, y = 4},  -- NW
                {x = 4, y = -4},  -- SE
                {x = -4, y = -4}, -- SW
            }
            
            -- Find a safe tile within arena bounds
            for _, dir in ipairs(directions) do
                local testX = playerPos.x + dir.x
                local testY = playerPos.y + dir.y
                
                -- Check if tile is within arena bounds
                if isWithinArena(testX, testY) then
                    local testTile = WPOINT.new(testX, testY, playerPos.z)
                    -- Check no fire at this tile
                    local fireAtTile = API.GetAllObjArray2({Config.Boss.fireObjectId}, 2, {0, 12}, testTile)
                    if not fireAtTile or #fireAtTile == 0 then
                        safeTile = testTile
                        break
                    end
                end
            end
            
            -- Fallback to center of arena if no safe tile found
            if not safeTile then
                safeTile = getArenaCenterTile(playerPos.z)
                if not safeTile then
                    -- If arena not initialized, just move +5 x
                    safeTile = WPOINT.new(playerPos.x - 5, playerPos.y - 5, playerPos.z)
                end
            end
            
            -- Try Dive first
            local diveAB = API.GetABs_name("Dive", true)
            if diveAB and diveAB.cooldown_timer and diveAB.cooldown_timer <= 0 then
                log("Diving away from fire!")
                API.DoAction_Dive_Tile(safeTile)
                API.RandomSleep2(100, 50, 50)
                API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, Config.Boss.ids, 50)
                return true
            end
            
            -- Try Surge if Dive not available
            local surgeAB = API.GetABs_name("Surge", true)
            if surgeAB and surgeAB.cooldown_timer and surgeAB.cooldown_timer <= 0 then
                log("Surging away from fire!")
                API.DoAction_Tile(safeTile)
                API.RandomSleep2(50, 25, 25)
                API.DoAction_Ability_Direct(surgeAB, 1, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(100, 50, 50)
                API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, Config.Boss.ids, 50)
                return true
            end
            
            -- Just run if no mobility
            API.DoAction_Tile(safeTile)
            return true
        end
    }),
    
    -- Surge/Dive to boss when far away (Phase 2 teleport)
    surgeToBoss = Timer.new({
        name = "Surge To Boss Timer",
        cooldown = 3,
        useTicks = true,
        condition = function()
            local boss = API.GetAllObjArray1(Config.Boss.ids, 50, {1})
            if boss and #boss > 0 then
                local playerPos = API.PlayerCoord()
                local bossPos = WPOINT.new(boss[1].Tile_XYZ.x, boss[1].Tile_XYZ.y, boss[1].Tile_XYZ.z)
                local distance = API.Math_DistanceW(playerPos, bossPos)
                return distance > 8
            end
            return false
        end,
        action = function()
            local boss = API.GetAllObjArray1(Config.Boss.ids, 50, {1})
            if not boss or #boss == 0 then return false end
            
            local bossPos = WPOINT.new(boss[1].Tile_XYZ.x, boss[1].Tile_XYZ.y, boss[1].Tile_XYZ.z)
            
            -- Try Surge first
            local surgeAB = API.GetABs_name("Surge", true)
            if surgeAB and surgeAB.cooldown_timer and surgeAB.cooldown_timer <= 0 then
                log("Surging to boss!")
                API.DoAction_Tile(bossPos)
                API.RandomSleep2(50, 25, 25)
                API.DoAction_Ability_Direct(surgeAB, 1, API.OFF_ACT_GeneralInterface_route)
                return true
            end
            
            -- Try Dive
            local diveAB = API.GetABs_name("Dive", true)
            if diveAB and diveAB.cooldown_timer and diveAB.cooldown_timer <= 0 then
                log("Diving to boss!")
                API.DoAction_Dive_Tile(bossPos)
                return true
            end
            
            return false
        end
    }),
    
    -- Loot timer
    loot = Timer.new({
        name = "Loot Timer",
        cooldown = 3,
        useTicks = true,
        condition = function() return true end,
        action = function()
            API.DoAction_LootAll_Button()
            return true
        end
    })
}

--============================================================================
-- PRAYER MANAGEMENT (one-time activation, not a timer)
--============================================================================

local prayersActivated = false

local function activatePrayers()
    if prayersActivated then return end
    
    log("Activating prayers...")
    API.DoAction_Ability(Config.Prayers.soulSplit.name, 1, API.OFF_ACT_GeneralInterface_route, true)
    API.RandomSleep2(100, 50, 50)
    API.DoAction_Ability(Config.Prayers.ruination.name, 1, API.OFF_ACT_GeneralInterface_route, true)
    
    prayersActivated = true
end

local function resetPrayers()
    prayersActivated = false
end

--============================================================================
-- LOCATION DETECTION
--============================================================================

local function isAtWarsRetreat()
    local bankChest = API.GetAllObjArray1({Config.WarsRetreat.bankChestId}, 30, {0})
    local altar = API.GetAllObjArray1({Config.WarsRetreat.altarId}, 30, {0})
    return (bankChest and #bankChest > 0) or (altar and #altar > 0)
end

local function isInBossRoom()
    local boss = API.GetAllObjArray1(Config.Boss.ids, 50, {1})
    return boss and #boss > 0
end

local function getBoss()
    local boss = API.GetAllObjArray1(Config.Boss.ids, 50, {1})
    return boss and boss[1] or nil
end

local function updateLocation()
    if isAtWarsRetreat() then
        Player.state.location = "Wars Retreat"
    elseif isInBossRoom() then
        Player.state.location = "Boss Room"
    else
        Player.state.location = "Transit"
    end
end

--============================================================================
-- DISCORD WEBHOOK (using Utils pattern)
--============================================================================

local function escapeJson(str)
    if not str then return nil end
    return str:gsub("\\", "\\\\")
             :gsub('"', '\\"')
             :gsub("\n", "\\n")
             :gsub("\r", "\\r")
             :gsub("\t", "\\t")
end

local function sendDiscordWebhook(rareName)
    if not Config.Discord.enabled or Config.Discord.webhookUrl == "" then
        return false
    end
    
    local runtime = os.time() - scriptStartTime
    local hours = math.floor(runtime / 3600)
    local minutes = math.floor((runtime % 3600) / 60)
    local seconds = runtime % 60
    local runtimeStr = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    
    local killsPerHour = 0
    if runtime > 0 then
        killsPerHour = math.floor((Config.Variables.killCount / runtime) * 3600)
    end
    
    local payload = {
        embeds = {
            {
                title = escapeJson("Vindicta Rare Drop!"),
                description = escapeJson("**" .. rareName .. "**"),
                color = Config.Discord.embedColor,
                thumbnail = {url = Config.Discord.thumbnailUrl},
                fields = {
                    {name = escapeJson("Kill Count"), value = escapeJson(tostring(Config.Variables.killCount)), inline = true},
                    {name = escapeJson("Kills/hr"), value = escapeJson(tostring(killsPerHour)), inline = true},
                    {name = escapeJson("Runtime"), value = escapeJson(runtimeStr), inline = true}
                },
                footer = {text = escapeJson("Vindicta Script v" .. version)}
            }
        }
    }
    
    local jsonPayload = API.JsonEncode(payload)
    local commandPayload = jsonPayload:gsub('"', '\\"')
    
    local command = 'curl.exe -X POST -H "Content-Type: application/json" ' ..
                    '-d "' .. commandPayload .. '" ' ..
                    '"' .. Config.Discord.webhookUrl .. '"'
    
    os.execute(command)
    log("Discord webhook sent for: " .. rareName)
    return true
end

--============================================================================
-- LOOT HANDLING
--============================================================================

local function isRareDrop(itemId)
    for _, rare in ipairs(Config.RareDrops) do
        if rare.id == itemId then
            return true, rare.name
        end
    end
    return false, nil
end

local function findRareOnGround()
    local items = API.ReadAllObjectsArray({3}, {-1}, {})
    for _, item in ipairs(items or {}) do
        local isRare, name = isRareDrop(item.Id)
        if isRare then
            return item, name
        end
    end
    return nil, nil
end

local function eatForSpace()
    for _, food in ipairs(Config.Food) do
        if Inventory:InvItemcount(food.id) > 0 then
            API.DoAction_Inventory1(food.id, 0, 1, API.OFF_ACT_GeneralInterface_route)
            log("Eating to make space for rare!")
            API.RandomSleep2(600, 100, 100)
            return true
        end
    end
    return false
end

local function handleRareLoot()
    local rareItem, rareName = findRareOnGround()
    if rareItem then
        log("*** RARE DROP: " .. rareName .. " ***")
        
        -- Send Discord webhook
        sendDiscordWebhook(rareName)
        
        -- Track the rare
        table.insert(Config.LootedRares, {
            name = rareName,
            runtime = API.ScriptRuntimeString(),
            killCount = Config.Variables.killCount
        })
        
        -- Make space if needed
        if getFreeSlots() < 1 then
            eatForSpace()
        end
        
        -- Loot the rare
        if getFreeSlots() >= 1 then
            API.DoAction_Object_Direct(0x29, API.OFF_ACT_Pickup_route, rareItem)
            API.RandomSleep2(600, 100, 100)
            return true
        end
    end
    return false
end

local function lootAllItems()
    -- Use area loot button
    API.DoAction_LootAll_Button()
end

--============================================================================
-- WARS RETREAT FUNCTIONS
--============================================================================

local function loadPreset()
    local bankChest = API.GetAllObjArray1({Config.WarsRetreat.bankChestId}, 30, {12})
    if bankChest and #bankChest > 0 then
        API.DoAction_Object_Direct(0x33, API.OFF_ACT_GeneralObject_route3, bankChest[1])
        return true
    end
    return false
end

local function useAltar()
    if getPrayerPercent() >= 99 then return true end
    local altar = API.GetAllObjArray1({Config.WarsRetreat.altarId}, 30, {12})
    if altar and #altar > 0 then
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route0, altar[1])
        return true
    end
    return false
end

local function useAdrenalineCrystal()
    if API.GetAdrenalineFromInterface() >= 100 then return true end
    -- Already interacting with crystal
    if API.ReadPlayerAnim() == 27668 then return false end
    -- Try type 12 first (interactive objects), then type 0
    local crystal = API.GetAllObjArray1({Config.WarsRetreat.adrenalineCrystalId}, 30, {12})
    if not crystal or #crystal == 0 then
        crystal = API.GetAllObjArray1({Config.WarsRetreat.adrenalineCrystalId}, 30, {0})
    end
    if crystal and #crystal > 0 then
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route0, crystal[1])
    end
    return false
end

local function teleportToVindicta()
    local portal = API.GetAllObjArray1({Config.WarsRetreat.vindictaPortalId}, 30, {0})
    if portal and #portal > 0 then
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route0, portal[1])
        return true
    end
    return false
end

--============================================================================
-- INSTANCE FUNCTIONS
--============================================================================

local function clickThreshold()
    local threshold = API.GetAllObjArray1({Config.Instance.thresholdId}, 30, {12})
    if threshold and #threshold > 0 then
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route0, threshold[1])
        return true
    end
    threshold = API.GetAllObjArray1({Config.Instance.thresholdId}, 30, {12})
    if threshold and #threshold > 0 then
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route0, threshold[1])
        return true
    end
    return false
end

local function clickBarrier()
    local barrier = API.GetAllObjArray1({Config.Instance.barrierId}, 30, {0})
    if barrier and #barrier > 0 then
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route0, barrier[1])
        return true
    end
    barrier = API.GetAllObjArray1({Config.Instance.barrierId}, 30, {12})
    if barrier and #barrier > 0 then
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route0, barrier[1])
        return true
    end
    return false
end

local function isInstanceInterfaceOpen()
    local vb = API.VB_FindPSettinOrder(2874)
    return vb.state == 589832 or vb.state == 18 or vb.state == 425992 or vb.state == 13
end

--============================================================================
-- COMBAT HANDLING
--============================================================================

local function handleCombat()
    local boss = getBoss()
    if not boss then
        Player.state.inCombat = false
        return false
    end
    
    Player.state.inCombat = true
    Player.state.phase = (boss.Id == Config.Boss.phase2Id) and 2 or 1
    
    -- Activate prayers once at start of fight
    activatePrayers()
    
    -- Fire avoidance (highest priority)
    Timers.fire:execute()

        -- Health management
    Timers.food:execute()
    Timers.prayerPotion:execute()
    
    -- Surge to boss if far (Phase 2 teleport)
    Timers.surgeToBoss:execute()
    
    -- Targeting
    Timers.target:execute()
    
    -- Ability rotation (handled by RotationManager with its own timer)
    Rotation.execute()
    
    return true
end

local function handlePostKill()
    log("Boss defeated!")
    Config.Variables.killCount = Config.Variables.killCount + 1
    Config.Variables.tripKills = Config.Variables.tripKills + 1
    Player.state.inCombat = false
    
    -- Reset rotation and prayers for next kill
    Rotation.reset()
    resetPrayers()
    
    -- Wait for loot to appear
    API.RandomSleep2(1200, 200, 200)
    
    -- Handle rare drops first (checks for rares, sends webhook, loots them)
    handleRareLoot()
    
    -- Loot all other items
    lootAllItems()
    API.RandomSleep2(800, 200, 200)
    
    -- Second loot pass to make sure we got everything
    lootAllItems()
    API.RandomSleep2(600, 100, 100)
    
    -- Check if need to bank
    if Config.Variables.tripKills >= Config.Combat.killsBeforeBank or getFreeSlots() < Config.Combat.minFreeSlots then
        Player.state.status = "TELEPORT_TO_WARS"
    else
        Player.state.status = "WAIT_FOR_RESPAWN"
    end
end

--============================================================================
-- STATE MACHINE
--============================================================================

local function update()
    updateLocation()
    
    local status = Player.state.status
    
    if status == "INITIALIZING" then
        if Player.state.location == "Wars Retreat" then
            Player.state.status = "PREPARE_AT_WARS"
        elseif Player.state.location == "Boss Room" then
            Player.state.status = "FIGHTING"
        else
            Player.state.status = "TELEPORT_TO_WARS"
        end
        
    elseif status == "TELEPORT_TO_WARS" then
        log("Teleporting to Wars Retreat...")
        API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route, false)
        API.RandomSleep2(3000, 500, 500)
        Player.state.status = "PREPARE_AT_WARS"
        
    elseif status == "PREPARE_AT_WARS" then
        if Player.state.location ~= "Wars Retreat" then
            API.RandomSleep2(1000, 300, 300)
            return
        end
        
        Config.Variables.tripKills = 0
        
        log("Loading preset...")
        loadPreset()
        API.RandomSleep2(2000, 300, 300)
        
        log("Using altar...")
        useAltar()
        API.RandomSleep2(1500, 300, 300)
        
        log("Using adrenaline crystal...")
        while API.GetAdrenalineFromInterface() < 100 and API.Read_LoopyLoop() do
            useAdrenalineCrystal()
            API.RandomSleep2(2800, 100, 100)
        end
        
        -- PVME: Use Living Death at Wars before entering
        log("Activating Living Death...")
        API.DoAction_Ability("Living Death", 1, API.OFF_ACT_GeneralInterface_route, true)
        API.RandomSleep2(600, 100, 100)
        
        Player.state.status = "TELEPORT_TO_BOSS"
        
    elseif status == "TELEPORT_TO_BOSS" then
        log("Teleporting to Vindicta...")
        teleportToVindicta()
        API.RandomSleep2(2000, 300, 300)
        Player.state.status = "CLICK_THRESHOLD"
        
    elseif status == "WAIT_FOR_THRESHOLD" then
        -- Wait until threshold object is available
        local threshold = API.GetAllObjArray1({Config.Instance.thresholdId}, 30, {12})
        if not threshold or #threshold == 0 then
            threshold = API.GetAllObjArray1({Config.Instance.thresholdId}, 30, {12})
        end
        
        if threshold and #threshold > 0 then
            log("Threshold found, proceeding...")
            Player.state.status = "CLICK_THRESHOLD"
        end
        -- Otherwise keep waiting
        
    elseif status == "CLICK_THRESHOLD" then
        log("Clicking threshold...")
        clickThreshold()
        API.RandomSleep2(2800, 300, 300)
        Player.state.status = "CLICK_BARRIER"
        
    elseif status == "CLICK_BARRIER" then
        log("Clicking barrier...")
        clickBarrier()
        API.RandomSleep2(2200, 300, 300)
        Player.state.status = "CONFIGURE_INSTANCE"
        
    elseif status == "CONFIGURE_INSTANCE" then
        if isInstanceInterfaceOpen() then
            -- PVME: Command Ghost while in interface
            log("Commanding Ghost...")
            API.DoAction_Ability("Command Vengeful Ghost", 1, API.OFF_ACT_GeneralInterface_route, true)
            API.RandomSleep2(300, 100, 100)
            
            log("Clicking start...")
            API.DoAction_Interface(0x24, 0xffffffff, 1, Config.Instance.interfaceId, 60, -1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(2000, 300, 300)
            Player.state.status = "ENTER_INSTANCE"
        else
            Player.state.status = "CLICK_BARRIER"
        end
        
    elseif status == "ENTER_INSTANCE" then
        -- PVME: Invoke Death while clicking barrier
        log("Invoking Death...")
        API.DoAction_Ability("Invoke Death", 1, API.OFF_ACT_GeneralInterface_route, true)
        API.RandomSleep2(300, 100, 100)
        
        log("Entering instance...")
        clickBarrier()
        API.RandomSleep2(1500, 300, 300)
        API.KeyboardPress2(0x31, 60, 100) -- Press 1
        API.RandomSleep2(1000, 200, 200)
        
        -- Conjure Army after entering instance
        log("Summoning conjures...")
        local conjureArmy = API.GetABs_name1("Conjure Undead Army")
        if conjureArmy and conjureArmy.enabled then
            API.DoAction_Ability("Conjure Undead Army", 1, API.OFF_ACT_GeneralInterface_route, true)
        else
            -- Individual conjures
            API.DoAction_Ability("Conjure Skeleton Warrior", 1, API.OFF_ACT_GeneralInterface_route, true)
            API.RandomSleep2(600, 100, 100)
            API.DoAction_Ability("Conjure Vengeful Ghost", 1, API.OFF_ACT_GeneralInterface_route, true)
            API.RandomSleep2(600, 100, 100)
            API.DoAction_Ability("Conjure Putrid Zombie", 1, API.OFF_ACT_GeneralInterface_route, true)
        end
        
        -- Initialize arena bounds - player position is now the center
        initializeArenaBounds()

        API.RandomSleep2(2800, 2800, 2800)

        -- Reset rotation for this kill
        Rotation.reset()
        Player.state.status = "FIGHTING"
        
    elseif status == "FIGHTING" then
        if not handleCombat() then
            handlePostKill()
        end
        
    elseif status == "WAIT_FOR_RESPAWN" then
        local boss = getBoss()
        if boss then
            Player.state.status = "FIGHTING"
        end
    end
end

--============================================================================
-- GUI
--============================================================================

local function drawGUI()
    local runtime = os.time() - scriptStartTime
    local hours = math.floor(runtime / 3600)
    local minutes = math.floor((runtime % 3600) / 60)
    local seconds = runtime % 60
    
    local killsPerHour = 0
    if runtime > 0 then
        killsPerHour = math.floor((Config.Variables.killCount / runtime) * 3600)
    end
    
    local raresCount = #Config.LootedRares
    
    API.DrawTable({
        {"Vindicta NM", "v" .. version},
        {"Status", Player.state.status},
        {"Location", Player.state.location},
        {"Rotation", Rotation.getCurrentName()},
        {"Phase", Player.state.phase == 1 and "Vindicta" or "Gorvek+Vindicta"},
        {"Trip Kills", Config.Variables.tripKills .. "/" .. Config.Combat.killsBeforeBank},
        {"Total Kills", Config.Variables.killCount},
        {"Kills/hr", tostring(killsPerHour)},
        {"Rares", tostring(raresCount)},
        {"Runtime", string.format("%02d:%02d:%02d", hours, minutes, seconds)},
        {"HP%", string.format("%.0f%%", getHealthPercent())},
        {"Prayer%", string.format("%.0f%%", getPrayerPercent())},
        {"Free Slots", tostring(getFreeSlots())}
    })
end

--============================================================================
-- MAIN LOOP
--============================================================================

log("Vindicta Normal Mode starting...")
log("Make sure you have:")
log("  - Necromancy abilities on action bar")
log("  - Soul Split and Ruination prayers")
log("  - Dive and Surge for fire dodging")
log("  - Wars Retreat portal configured")

API.Write_LoopyLoop(true)

while API.Read_LoopyLoop() do
    update()
    drawGUI()
    API.RandomSleep2(50, 25, 25) -- Short sleep like Rasial
end

log("Script stopped.")
log("Total kills: " .. Config.Variables.killCount)