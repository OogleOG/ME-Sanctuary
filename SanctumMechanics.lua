
--[[
    SanctumMechanics.lua
    Full mechanics handling for all Sanctum bosses
    Based on Gate of Elid AOE avoidance pattern + transcript analysis
]]

local API = require("api")

local SanctumMechanics = {}

local SanctumVariable = require("sanctum.SanctumVariable")

-- Cooldown tracking
local avoidAOE_cooldown = 0
local mechanic_cooldown = 0
local attack_cooldown = 0

local hasUsedFreedom = false
local hasUsedResonance = false


-- Debug
local debug = true

local function debugLog(msg)
    if debug then
        print("[MECHANICS]: " .. msg)
    end
end

function SanctumMechanics.setDebug(enabled)
    debug = enabled
end

---Check if an ability is ready (exists, enabled, and off cooldown)
---@param abilityName string
---@return boolean ready
---@return table|nil abilityInfo
local function isAbilityReady(abilityName)
    local ab = API.GetABs_name(abilityName, false)
    if not ab then return false, nil end
    if not ab.id or ab.id <= 0 then return false, ab end
    if not ab.enabled then return false, ab end
    
    -- cooldown_timer must be exactly 0 to be ready
    local cd = ab.cooldown_timer or 999
    if cd ~= 0 then return false, ab end
    
    return true, ab
end

--[[
    ========================================
    CONFIGURATION - ALL IDS
    ========================================
]]

local IDs = {
    -- BOSSES
    VERMYX = 31098,
    VERMYX_COILSPAWN = 31099,
    KEZALAM = 31100,
    NAKATRA = 31103,
    
    -- VERMYX MECHANICS
    VERMYX_GAP = 130668,
    VERMYX_RANGED_ANIM = 36011,
    VERMYX_WYRMFIRE_ANIM = 36007,
    VERMYX_SOUL_BOMB_ANIM = 36016,
    VERMYX_MOONSTONE_ANIM = 36017,
    VERMYX_PROJECTILE = 8185,
    COILSPAWN_RANGED_ANIM = 36022,
    COILSPAWN_WYRMFIRE_ANIM = 36021,
    WYRMFIRE_TILE_SIDE = 8303,
    WYRMFIRE_TILE_MIDDLE = 8302,
    SOUL_BOMB_TILE = 8259,
    MOONSTONE_SHARD = 8257,
    MOONSTONE_OBJECT_1 = 31090,
    MOONSTONE_OBJECT_2 = 31093,
    MOONSTONE_OBJECT_3 = 31095,
    SCARAB_HEALER = 31096,
    CORRUPTED_SCARAB = 31096,
    REDIRECT_ARROW = 8345,
    
    -- KEZALAM MECHANICS
    KEZALAM_LEDGE = 130673,
    KEZALAM_PROJECTILE = 8182,
    KEZALAM_AA_ANIM = 36031,
    KEZALAM_MELEE_ANIM = 36028,
    MOONSTONE_OBELISK = {31101, 31102},
    VOLATILE_SCARAB = 31097,
    KEZALAM_WAVE = 8202, -- still need to implement this, we need to dodge this shit

    -- Kezalam Line Blast ("Paiiin") highlight IDs
    SB_LINE_HIGHLIGHT_1 = 8199,
    SB_LINE_HIGHLIGHT_2 = 8239,
    
    -- Kezalam SB (Sanctum Blast) Tile IDs
    SB_TILES = {8263, 8261, 8266},
    
    -- Kezalam Prison Wall NPCs
    PRISON_NPCS = {568, 31092, 31093, 31090, 31095, 31094, 11620, 31091},
    
    -- Kezalam Chat Callouts
    SB_TARGETED_UNDER = "Graaah",
    SB_TARGETED_SURROUND = "Kyaaa",
    SB_TARGETED_FAR = "Hrrrr",
    SB_SCATTERED = "Dhaaarken",
    SB_LINE = "Paiiin",
    SCARAB_SUMMON = "Erggg",
    
    -- NAKATRA MECHANICS
    NAKATRA_GAP = 130666,
    NAKATRA_ENTRANCE = 130665,
    
    -- SHARED
    SANCTUM_TREASURE = 130663,
    ARCHWAY = 130667,
}

SanctumMechanics.IDs = IDs


function SanctumMechanics.getBossHP(bossId)
    local bosses = API.GetAllObjArrayInteract({bossId}, 50, {1})
    if bosses and #bosses > 0 and bosses[1].Life then
        return bosses[1].Life
    end
    return 0
end

function SanctumMechanics.getBossHPPercent(bossId, maxHP)
    local currentHP = SanctumMechanics.getBossHP(bossId)
    if currentHP > 0 and maxHP > 0 then
        return (currentHP / maxHP) * 100
    end
    return 0
end

function SanctumMechanics.getVermyxPhase(isHardMode)
    local maxHP = isHardMode and SanctumMechanics.BossHP.VERMYX_HM or SanctumMechanics.BossHP.VERMYX_NM
    local hpPercent = SanctumMechanics.getBossHPPercent(IDs.VERMYX, maxHP)
    
    if hpPercent > SanctumMechanics.BossHP.VERMYX_P2_THRESHOLD then
        return 1
    elseif hpPercent > SanctumMechanics.BossHP.VERMYX_P3_THRESHOLD then
        return 2
    else
        return 3
    end
end

function SanctumMechanics.getKezalamPhase(isHardMode)
    local maxHP = isHardMode and SanctumMechanics.BossHP.KEZALAM_HM or SanctumMechanics.BossHP.KEZALAM_NM
    local hpPercent = SanctumMechanics.getBossHPPercent(IDs.KEZALAM, maxHP)
    
    if hpPercent > SanctumMechanics.BossHP.KEZALAM_P2_THRESHOLD then
        return 1
    elseif hpPercent > SanctumMechanics.BossHP.KEZALAM_P3_THRESHOLD then
        return 2
    else
        return 3
    end
end

function SanctumMechanics.getNakatraPhase(isHardMode)
    local maxHP = isHardMode and SanctumMechanics.BossHP.NAKATRA_HM or SanctumMechanics.BossHP.NAKATRA_NM
    local hpPercent = SanctumMechanics.getBossHPPercent(IDs.NAKATRA, maxHP)
    
    if hpPercent > SanctumMechanics.BossHP.NAKATRA_P2_THRESHOLD then
        return 1
    elseif hpPercent > SanctumMechanics.BossHP.NAKATRA_P3_THRESHOLD then
        return 2
    elseif hpPercent > SanctumMechanics.BossHP.NAKATRA_P4_THRESHOLD then
        return 3
    else
        return 4
    end
end

--[[
    ========================================
    UTILITY FUNCTIONS
    ========================================
]]

function SanctumMechanics.getObjectsFromTable(allObjects, objType, objId)
    local results = {}
    local type2 = 9001
    if objType == 0 then type2 = 12 end
    if objType == 12 then type2 = 0 end
    
    if allObjects and #allObjects > 0 then
        for _, obj in pairs(allObjects) do
            if (obj.Type == objType or obj.Type == type2) and obj.Id == objId then
                results[#results + 1] = obj
            end
        end
    end
    
    return #results > 0 and results or nil
end

function SanctumMechanics.getCoordsFromTable(allObjects, objType, objId)
    local coords = {}
    local objects = SanctumMechanics.getObjectsFromTable(allObjects, objType, objId)
    
    if objects then
        for _, obj in pairs(objects) do
            coords[#coords + 1] = obj.Tile_XYZ
        end
    end
    
    return coords
end

function SanctumMechanics.getObjectFromTable(allObjects, objType, objId)
    local objects = SanctumMechanics.getObjectsFromTable(allObjects, objType, objId)
    return objects and objects[1] or nil
end

function SanctumMechanics.getNPCFromTable(allObjects, objType, objId)
    local objects = SanctumMechanics.getObjectsFromTable(allObjects, objType, objId)
    if objects then
        for _, obj in pairs(objects) do
            if obj.Life and obj.Life > 1 then
                return obj
            end
        end
    end
    return nil
end

function SanctumMechanics.isOnDangerTile(dangerTiles, dangerRadius)
    if not dangerTiles or #dangerTiles == 0 then
        return false
    end
    
    local playerPos = API.PlayerCoord()
    
    for _, tile in ipairs(dangerTiles) do
        local dist = math.abs(playerPos.x - tile.x) + math.abs(playerPos.y - tile.y)
        if dist <= dangerRadius then
            return true
        end
    end
    
    return false
end

---Check if a specific tile is blocked by moonstone
---@param x number
---@param y number
---@param moonstoneTiles table
---@return boolean
function SanctumMechanics.isTileBlocked(x, y, moonstoneTiles)
    if not moonstoneTiles or #moonstoneTiles == 0 then
        return false
    end
    
    for _, moon in ipairs(moonstoneTiles) do
        if moon.x == x and moon.y == y then
            return true
        end
    end
    
    return false
end

---Find a safe tile avoiding moonstones
---@param startX number
---@param startY number
---@param moonstoneTiles table
---@param preferredDir string "west", "east", "north", "south"
---@param distance number
---@return number|nil x
---@return number|nil y
function SanctumMechanics.findSafeTile(startX, startY, moonstoneTiles, preferredDir, distance)
    local directions = {
        west = {-1, 0},
        east = {1, 0},
        north = {0, 1},
        south = {0, -1},
    }
    
    local order = {"west", "east", "south", "north"}
    
    -- Put preferred direction first
    if preferredDir and directions[preferredDir] then
        for i, dir in ipairs(order) do
            if dir == preferredDir then
                table.remove(order, i)
                table.insert(order, 1, preferredDir)
                break
            end
        end
    end
    
    -- Try each direction
    for _, dir in ipairs(order) do
        local dx, dy = directions[dir][1], directions[dir][2]
        local targetX = startX + (dx * distance)
        local targetY = startY + (dy * distance)
        
        -- Check if target and path are clear
        local pathClear = true
        for step = 1, distance do
            local checkX = startX + (dx * step)
            local checkY = startY + (dy * step)
            if SanctumMechanics.isTileBlocked(checkX, checkY, moonstoneTiles) then
                pathClear = false
                break
            end
        end
        
        if pathClear then
            return targetX, targetY
        end
    end
    
    return nil, nil
end

function SanctumMechanics.avoidAOE(dangerTiles, radius, searchRadius, useDive, blockedTiles)
    local currentTick = API.Get_tick()
    
    if currentTick - avoidAOE_cooldown < 4 then
        return false
    end
    
    if not dangerTiles or #dangerTiles == 0 then
        return false
    end
    
    -- Convert danger tiles to WPOINT format
    local wpointTiles = {}
    for _, tile in ipairs(dangerTiles) do
        if tile.x and tile.y then
            wpointTiles[#wpointTiles + 1] = WPOINT.new(tile.x, tile.y, tile.z or 0)
        elseif tile.Tile_XYZ then
            wpointTiles[#wpointTiles + 1] = tile.Tile_XYZ
        else
            wpointTiles[#wpointTiles + 1] = tile
        end
    end
    
    -- Convert blocked tiles to WPOINT format (e.g., moonstones)
    local wpointBlocked = {}
    if blockedTiles and #blockedTiles > 0 then
        for _, tile in ipairs(blockedTiles) do
            if tile.x and tile.y then
                wpointBlocked[#wpointBlocked + 1] = WPOINT.new(tile.x, tile.y, tile.z or 0)
            elseif tile.Tile_XYZ then
                wpointBlocked[#wpointBlocked + 1] = tile.Tile_XYZ
            else
                wpointBlocked[#wpointBlocked + 1] = tile
            end
        end
    end
    
    local freeTiles = API.Math_FreeTiles(wpointTiles, radius, searchRadius, wpointBlocked)
    
    if freeTiles and #freeTiles > 0 then
        local targetTile = freeTiles[1]
        debugLog("Avoiding AOE -> " .. targetTile.x .. ":" .. targetTile.y)
        
        if useDive then
            local diveReady = isAbilityReady("Dive")
            if diveReady then
                API.DoAction_Dive_Tile(WPOINT.new(targetTile.x, targetTile.y, 0))
                avoidAOE_cooldown = currentTick
                return true
            end
        end
        
        API.DoAction_Tile(WPOINT.new(targetTile.x, targetTile.y, 0))
        avoidAOE_cooldown = currentTick
        return true
    end
    
    return false
end

--[[
    ========================================
    VERMYX MECHANICS
    ========================================
]]

local Vermyx = {}

-- State tracking
Vermyx.state = {
    soulRushActive = false,
    moonstoneAnimDetected = false,
    moonstoneAnimTick = 0,
    moonstoneDirection = "west",  -- Alternates: west, east, west, east...
    moonstoneCount = 0,           -- Track how many moonstone sets we've dodged
}

local WYRMFIRE_RADIUS = 9

---Cross gap to Vermyx arena
function Vermyx.crossGap()
    debugLog("Crossing gap to Vermyx")
    API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1200, 200, 300)
    
    if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {IDs.VERMYX_GAP}, 50) then
        API.RandomSleep2(5000, 500, 800)
        return true
    end
    return false
end

---Check if boss is doing moonstone spawn animation (36017)
---When we see this, we need to move close to boss so moonstones spawn near boss
---@return boolean
function Vermyx.checkBossMoonstoneAnimation()
    local boss = API.GetAllObjArrayInteract({IDs.VERMYX}, 50, {1})
    if boss and #boss > 0 then
        local anim = boss[1].Anim
        if anim == IDs.VERMYX_MOONSTONE_ANIM then
            return true
        end
    end
    return false
end

---Handle boss moonstone spawn animation - dodge in alternating direction
---Uses findSafeTile to avoid existing moonstones
---@return boolean true if we handled the mechanic
function Vermyx.handleMoonstoneSpawn()
    local currentTick = API.Get_tick()
    
    -- Check if boss is doing moonstone spawn animation
    if Vermyx.checkBossMoonstoneAnimation() then
        if not Vermyx.state.moonstoneAnimDetected then
            Vermyx.state.moonstoneAnimDetected = true
            Vermyx.state.moonstoneAnimTick = currentTick
            
            -- Get player position and existing moonstones
            local playerPos = API.PlayerCoord()
            local allObjects = API.ReadAllObjectsArray({-1}, {-1}, {})
            local moonstoneTiles = Vermyx.getMoonstoneTiles(allObjects)
            
            -- Use findSafeTile to get a safe position avoiding moonstones
            local safeX, safeY = SanctumMechanics.findSafeTile(
                playerPos.x, 
                playerPos.y, 
                moonstoneTiles, 
                Vermyx.state.moonstoneDirection, 
                2
            )
            
            if safeX and safeY then
                debugLog("MOONSTONE ANIM - Moving to safe tile: " .. safeX .. "," .. safeY .. " (count: " .. Vermyx.state.moonstoneCount .. ")")
                --API.DoAction_Tile(WPOINT.new(safeX, safeY, 0))
                API.DoAction_Tile(WPOINT.new(safeX, safeY, 0))
            else
                -- No safe tile found in cardinal directions, try diagonal
                debugLog("No cardinal safe tile - trying diagonal escape")
                local diagX = playerPos.x + 2
                local diagY = playerPos.y - 2
                if not SanctumMechanics.isTileBlocked(diagX, diagY, moonstoneTiles) then
                    --API.DoAction_Tile(WPOINT.new(diagX, diagY, 0))
                    API.DoAction_Tile(WPOINT.new(diagX, diagY, 0))
                else
                    diagX = playerPos.x - 2
                    if not SanctumMechanics.isTileBlocked(diagX, diagY, moonstoneTiles) then
                        --API.DoAction_Tile(WPOINT.new(diagX, diagY, 0))
                        API.DoAction_Tile(WPOINT.new(diagX, diagY, 0))
                    else
                        debugLog("WARNING: All escape routes blocked!")
                    end
                end
            end
            
            API.RandomSleep2(400, 50, 100)
            return true
        end
        return false
    end
    
    -- After animation ends, flip direction for next time and step back south
    if Vermyx.state.moonstoneAnimDetected then
        if currentTick - Vermyx.state.moonstoneAnimTick > 3 then
            -- Flip direction for NEXT moonstone
            if Vermyx.state.moonstoneDirection == "west" then
                Vermyx.state.moonstoneDirection = "east"
            else
                Vermyx.state.moonstoneDirection = "west"
            end
            
            Vermyx.state.moonstoneCount = Vermyx.state.moonstoneCount + 1
            debugLog("Moonstones spawned (#" .. Vermyx.state.moonstoneCount .. ") - Next direction: " .. Vermyx.state.moonstoneDirection)
            Vermyx.state.moonstoneAnimDetected = false
            
            -- Step back south to fighting position, avoiding moonstones
            local playerPos = API.PlayerCoord()
            local allObjects = API.ReadAllObjectsArray({-1}, {-1}, {})
            local moonstoneTiles = Vermyx.getMoonstoneTiles(allObjects)
            
            local safeX, safeY = SanctumMechanics.findSafeTile(SanctumVariable.CrossedGapPosition.x, SanctumVariable.CrossedGapPosition.y, moonstoneTiles, "northeast", 3)
            if safeX and safeY then
                API.DoAction_Tile(WPOINT.new(SanctumVariable.CrossedGapPosition.x, SanctumVariable.CrossedGapPosition.y, SanctumVariable.CrossedGapPosition.z))
            else
                debugLog("South blocked by moonstone - staying in position")
            end
            
            API.RandomSleep2(600, 50, 100)
            return true
        end
    end
    
    return false
end

---Get all Moonstone tiles (persistent obstacles)
function Vermyx.getMoonstoneTiles(allObjects)
    local moonstoneTiles = {}
    
    local moonstone_checks = {
        {type = 4, id = IDs.MOONSTONE_SHARD},
        {type = 12, id = IDs.MOONSTONE_OBJECT_1},
        {type = 12, id = IDs.MOONSTONE_OBJECT_2},
        {type = 12, id = IDs.MOONSTONE_OBJECT_3},
        {type = 1, id = IDs.MOONSTONE_OBJECT_1},
        {type = 1, id = IDs.MOONSTONE_OBJECT_2},
        {type = 1, id = IDs.MOONSTONE_OBJECT_3},
    }
    
    for _, check in ipairs(moonstone_checks) do
        local objects = SanctumMechanics.getObjectsFromTable(allObjects, check.type, check.id)
        if objects then
            for _, obj in ipairs(objects) do
                local x = obj.Tile_XYZ and obj.Tile_XYZ.x or obj.x
                local y = obj.Tile_XYZ and obj.Tile_XYZ.y or obj.y
                if x and y then
                    moonstoneTiles[#moonstoneTiles + 1] = {x = x, y = y}
                end
            end
        end
    end
    
    return moonstoneTiles
end

function Vermyx.handleSoulBomb(allObjects)
    local soulBombTiles = SanctumMechanics.getCoordsFromTable(allObjects, 4, IDs.SOUL_BOMB_TILE)

    if not soulBombTiles or #soulBombTiles == 0 then
        return false
    end

    local playerPos = API.PlayerCoord()

    for _, tile in ipairs(soulBombTiles) do
        local dist = math.abs(playerPos.x - tile.x) + math.abs(playerPos.y - tile.y)
        if dist <= 2 then
            debugLog("Soul Bomb under player - dodging!")
            
            local moonstoneTiles = Vermyx.getMoonstoneTiles(allObjects)
            local escapeTile = Vermyx.findClearEscapeTile(playerPos, tile, moonstoneTiles, soulBombTiles)
            
            if escapeTile then
                if API.isAbilityAvailable("Dive") then
                    debugLog("Diving to " .. escapeTile.x .. "," .. escapeTile.y)
                    API.DoAction_Dive_Tile(escapeTile)
                else
                    debugLog("Walking to " .. escapeTile.x .. "," .. escapeTile.y)
                    API.DoAction_Tile(escapeTile)
                end
                API.RandomSleep2(300, 50, 100)
                return true
            else
                debugLog("WARNING: No safe escape from Soul Bomb!")
            end
        end
    end

    return false
end

function Vermyx.findClearEscapeTile(playerPos, bombTile, moonstoneTiles, bombTiles)
    local directions = {
        {x = 0, y = -3},  -- south
        {x = 0, y = 3},   -- north
        {x = -3, y = 0},  -- west
        {x = 3, y = 0},   -- east
        {x = -3, y = -3}, -- southwest
        {x = 3, y = -3},  -- southeast
        {x = -3, y = 3},  -- northwest
        {x = 3, y = 3},   -- northeast
    }
    
    for _, dir in ipairs(directions) do
        local targetX = playerPos.x + dir.x
        local targetY = playerPos.y + dir.y
        
        if Vermyx.isPathClear(playerPos, targetX, targetY, moonstoneTiles) and
           not Vermyx.isTileInList(targetX, targetY, bombTiles) then
            return WPOINT.new(targetX - 3, targetY, playerPos.z)
        end
    end
    
    return nil
end

function Vermyx.isPathClear(playerPos, targetX, targetY, blockedTiles)
    local stepX = targetX > playerPos.x and 1 or (targetX < playerPos.x and -1 or 0)
    local stepY = targetY > playerPos.y and 1 or (targetY < playerPos.y and -1 or 0)
    local steps = math.max(math.abs(targetX - playerPos.x), math.abs(targetY - playerPos.y))
    
    for i = 1, steps do
        local checkX = playerPos.x + (stepX * i)
        local checkY = playerPos.y + (stepY * i)
        if Vermyx.isTileInList(checkX, checkY, blockedTiles) then
            return false
        end
    end
    
    return true
end

function Vermyx.isTileInList(x, y, tileList)
    for _, tile in ipairs(tileList) do
        if tile.x == x and tile.y == y then
            return true
        end
    end
    return false
end

---Handle standing on moonstone - step in alternating direction, checking for blocked tiles
function Vermyx.handleMoonstones(allObjects)
    local moonstoneTiles = Vermyx.getMoonstoneTiles(allObjects)
    
    if not moonstoneTiles or #moonstoneTiles == 0 then
        return false
    end
    
    local playerPos = API.PlayerCoord()
    
    for _, tile in ipairs(moonstoneTiles) do
        -- Check if we're standing exactly on moonstone OR within 1 tile
        local dist = math.abs(playerPos.x - tile.x) + math.abs(playerPos.y - tile.y)
        if dist <= 1 then
            -- Use findSafeTile to get a valid escape route
            local safeX, safeY = SanctumMechanics.findSafeTile(
                playerPos.x, 
                playerPos.y, 
                moonstoneTiles, 
                Vermyx.state.moonstoneDirection, 
                1
            )
            
            if safeX and safeY then
                debugLog("Stepping to safe tile: " .. safeX .. "," .. safeY)
                API.DoAction_Tile(WPOINT.new(safeX, safeY, 0))
            else
                -- All cardinal blocked - try diagonal
                local diagOffsets = {{1, 1}, {-1, 1}, {1, -1}, {-1, -1}}
                for _, offset in ipairs(diagOffsets) do
                    local diagX = playerPos.x + offset[1]
                    local diagY = playerPos.y + offset[2]
                    if not SanctumMechanics.isTileBlocked(diagX, diagY, moonstoneTiles) then
                        debugLog("Stepping diagonal: " .. diagX .. "," .. diagY)
                        API.DoAction_Tile(WPOINT.new(diagX, diagY, 0))
                        break
                    end
                end
            end
            
            API.RandomSleep2(400, 50, 100)
            return true
        end
    end
    
    return false
end

---Handle Wyrmfire mechanic (19x19 AoE breath)
-- Danger zone is 9 tiles from center, so we need to be 10+ tiles away to be safe
local dodgedWyrmFire = false
function Vermyx.handleWyrmfire(allObjects)
    if not SanctumVariable.CentralPosition.x or not SanctumVariable.CentralPosition.y then
        debugLog("CentralPosition not initialized yet, skipping wyrmfire handling")
        return false
    end

    local allFireTiles = API.GetAllObjArray1({ 8303, 8302 }, 120, {4})

    if #allFireTiles == 0 then
        if dodgedWyrmFire then
            dodgedWyrmFire = false
        end
        return false
    end

    local playerPos = API.PlayerCoord()
    local moonstoneTiles = Vermyx.getMoonstoneTiles(allObjects)

    -- Define the 3 potential fire tile positions
    local westernFirePosition = {x = SanctumVariable.CentralPosition.x - 13, y = SanctumVariable.CentralPosition.y, z = SanctumVariable.CentralPosition.z}
    local easternFirePosition = {x = SanctumVariable.CentralPosition.x + 12, y = SanctumVariable.CentralPosition.y, z = SanctumVariable.CentralPosition.z}
    local centerFirePosition = {x = SanctumVariable.CentralPosition.x, y = SanctumVariable.CentralPosition.y, z = SanctumVariable.CentralPosition.z}

    debugLog("Player position: " .. playerPos.x .. ", " .. playerPos.y)
    debugLog("Fire tiles detected: " .. #allFireTiles)
    for i, fireTile in ipairs(allFireTiles) do
        debugLog("Fire tile " .. i .. ": " .. math.floor(fireTile.Tile_XYZ.x) .. ", " .. math.floor(fireTile.Tile_XYZ.y))
    end

    local playerOnFire = false
    -- Check which of the 3 potential fire tiles are actually active
    local fireAtWestern = false
    local fireAtEastern = false
    local fireAtCenter = false

    for _, fireTile in ipairs(allFireTiles) do
        local fireX = math.floor(fireTile.Tile_XYZ.x)
        local fireY = math.floor(fireTile.Tile_XYZ.y)

        -- Check if player is standing on this fire tile
        if fireX == playerPos.x and fireY == playerPos.y then
            playerOnFire = true
        end

        -- Check western position
        if fireX == westernFirePosition.x and fireY == westernFirePosition.y then
            fireAtWestern = true
            debugLog("Fire detected at WESTERN position")
        end

        -- Check eastern position
        if fireX == easternFirePosition.x and fireY == easternFirePosition.y then
            fireAtEastern = true
            debugLog("Fire detected at EASTERN position")
        end

        -- Check center position
        if fireX == centerFirePosition.x and fireY == centerFirePosition.y then
            fireAtCenter = true
            debugLog("Fire detected at CENTER position")
        end
    end

    local moveX = SanctumVariable.CentralPosition.x
    local moveY = SanctumVariable.CentralPosition.y

    -- Determine escape route based on which fire tile is active and player distance
    if fireAtCenter then
        -- Fire at center - move diagonal based on player's position relative to center
        if playerPos.x < SanctumVariable.CentralPosition.x then
            moveX = SanctumVariable.CentralPosition.x - 15
        else
            moveX = SanctumVariable.CentralPosition.x + 15
        end
        moveY = SanctumVariable.CentralPosition.y - 7
        debugLog("Fire at CENTER - player at relative X: " .. (playerPos.x - SanctumVariable.CentralPosition.x) .. ", moving to " .. moveX .. ", " .. moveY)
        playerOnFire = true
    elseif fireAtWestern then
        -- Fire at western position
        local distanceToFireX = math.abs(playerPos.x - westernFirePosition.x)

        if distanceToFireX < 10 then
            -- Too close - move to center position
            moveX = SanctumVariable.CentralPosition.x
            moveY = SanctumVariable.CentralPosition.y
            debugLog("Fire at WESTERN - player distance (" .. distanceToFireX .. ") < 10, moving to center")
            playerOnFire = true
        else
            -- Far enough - stay in place or move minimally
            debugLog("Fire at WESTERN - player distance (" .. distanceToFireX .. ") >= 10, safe distance")
            dodgedWyrmFire = true
            return false
        end

    elseif fireAtEastern then
        -- Fire at eastern position
        local distanceToFireX = math.abs(playerPos.x - easternFirePosition.x)

        if distanceToFireX < 10 then
            -- Too close - move to center position
            moveX = SanctumVariable.CentralPosition.x
            moveY = SanctumVariable.CentralPosition.y
            debugLog("Fire at EASTERN - player distance (" .. distanceToFireX .. ") < 10, moving to center")
            playerOnFire = true
        else
            -- Far enough - stay in place or move minimally
            debugLog("Fire at EASTERN - player distance (" .. distanceToFireX .. ") >= 10, safe distance")
            dodgedWyrmFire = true
            return false
        end
    end

    debugLog("Wyrmfire escape target: " .. moveX .. ", " .. moveY)

    if not dodgedWyrmFire and playerOnFire then
        -- Check abilities using helper
        local surgeReady = isAbilityReady("Surge")
        local diveReady = isAbilityReady("Dive")

        -- ALWAYS start walking immediately
        API.DoAction_Tile(WPOINT.new(moveX, moveY, 0))
        API.RandomSleep2(1200, 50, 50)

        -- Then use mobility abilities if available
        if diveReady then
            debugLog("Using Dive to escape wyrmfire")
            API.RandomSleep2(100, 50, 50)
            API.DoAction_Dive_Tile(WPOINT.new(moveX, moveY, 0))
        elseif surgeReady then
            debugLog("Using Surge to escape wyrmfire")
            API.RandomSleep2(100, 50, 50)
            API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
        else
            debugLog("Walking to escape wyrmfire (no mobility available)")
        end
        if not fireAtCenter then
            API.RandomSleep2(400, 100, 150)
        else
            print("long sleep")
            if API.FindNPCbyName("Vermyx, Brood Mother",50).Anim == 36018 then
                API.RandomSleep2(1200,1200,1200)
            end
        end
        
        dodgedWyrmFire = true
        return true
    end
    return false
end

local phaseEast = false
local phaseWest = false
function Vermyx.handlePhaseTransition() 
    local vermyxHealth = API.FindNPCbyName("Vermyx, Brood Mother",50).Life
    if vermyxHealth == 450000 and not phaseEast then
        API.DoAction_Tile(WPOINT.new(SanctumVariable.CentralPosition.x-13, SanctumVariable.CentralPosition.y,SanctumVariable.CentralPosition.z))
        phaseEast = true
        return true
    elseif vermyxHealth == 300000 and not phaseWest then
        API.DoAction_Tile(WPOINT.new(SanctumVariable.CentralPosition.x+13, SanctumVariable.CentralPosition.y,SanctumVariable.CentralPosition.z))
        phaseWest = true
        return true
    end
    return false
end

---Check if player has Residual Soul stacks
---@return number stacks (0 if none)
local function getResidualSoulStacks()
    local buffs = API.Buffbar_GetAllIDs()
    if buffs then
        for _, buff in ipairs(buffs) do
            -- Residual Soul buff ID is 30123
            if buff.id == 30123 then
                return buff.conv_text or 1
            end
        end
    end
    return 0
end

function Vermyx.handleScarabHealers()
    local scarabs = API.GetAllObjArrayInteract({IDs.SCARAB_HEALER}, 50, {1})

    if not scarabs or #scarabs == 0 then
        return false
    end

    for _, scarab in ipairs(scarabs) do
        if scarab.Life and scarab.Life > 0 then
            local soulStacks = getResidualSoulStacks()
            if soulStacks == 0 then
                debugLog("Scarab Healer detected but no soul stacks - waiting")
                return false
            end
            API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {IDs.SCARAB_HEALER}, 50)
            API.RandomSleep2(600, 100, 150)
            debugLog("Scarab Healer detected - using Soul Strike!")
            API.DoAction_Ability_check("Soul Strike", 1, API.OFF_ACT_GeneralInterface_route, true, true, true)
            return true
        end
    end

    return false
end

---Handle Soul Rush mechanic (follow arrows)
-- Can use Dive only if path is clear of moonstones AND dive is off cooldown
function Vermyx.handleSoulRush(allObjects)
    local arrowCoords = SanctumMechanics.getCoordsFromTable(allObjects, 4, IDs.REDIRECT_ARROW)
    
    if arrowCoords and #arrowCoords > 0 then
        if not Vermyx.state.soulRushActive then
            debugLog("Soul Rush started!")
        end
        Vermyx.state.soulRushActive = true
        
        -- Get closest arrow
        local playerPos = API.PlayerCoord()
        local closestArrow = arrowCoords[1]
        local closestDist = 9999
        
        for _, arrow in ipairs(arrowCoords) do
            local dist = math.abs(playerPos.x - arrow.x) + math.abs(playerPos.y - arrow.y)
            if dist < closestDist then
                closestDist = dist
                closestArrow = arrow
            end
        end
        
        -- Graphics objects have offset
        local targetX = closestArrow.x - 1
        local targetY = closestArrow.y - 1
        local targetTile = WPOINT.new(targetX, targetY, 0)
        
        -- Calculate distance to target
        local distToTarget = math.abs(playerPos.x - targetX) + math.abs(playerPos.y - targetY)
        
        debugLog("Soul Rush arrow -> " .. targetX .. ", " .. targetY .. " (dist: " .. distToTarget .. ")")
        
        -- If already at target, just wait
        if distToTarget <= 0 then
            debugLog("At arrow position - waiting")
            API.RandomSleep2(200, 50, 50)
            return true
        end
        
        -- Get moonstone tiles for blocking check
        local moonstoneTiles = Vermyx.getMoonstoneTiles(allObjects)
        
        -- Check if we can Dive (only if >8 tiles and no moonstones blocking)
        -- if distToTarget > 8 then
        --     -- Use helper to check Dive availability
        --     local diveReady = isAbilityReady("Dive")
            
        --     if diveReady then
        --         -- Check if any moonstones are blocking the path
        --         local pathBlocked = false
                
        --         if moonstoneTiles and #moonstoneTiles > 0 then
        --             -- Simple line check - see if any moonstone is roughly between us and target
        --             local minX = math.min(playerPos.x, targetX)
        --             local maxX = math.max(playerPos.x, targetX)
        --             local minY = math.min(playerPos.y, targetY)
        --             local maxY = math.max(playerPos.y, targetY)
                    
        --             for _, moon in ipairs(moonstoneTiles) do
        --                 -- Check if moonstone is in the bounding box between player and target
        --                 if moon.x >= minX - 1 and moon.x <= maxX + 1 and
        --                    moon.y >= minY - 1 and moon.y <= maxY + 1 then
        --                     pathBlocked = true
        --                     debugLog("Moonstone blocking dive path at " .. moon.x .. "," .. moon.y)
        --                     break
        --                 end
        --             end
        --         end
                
        --         if not pathBlocked then
        --             debugLog("Path clear - using Dive for Soul Rush")
        --             --API.DoAction_Dive_Tile(targetTile)
        --             API.RandomSleep2(0, 100, 150)
        --             return true
        --         else
        --             debugLog("Dive ready but path blocked - walking instead")
        --         end
        --     else
        --         debugLog("Dive not ready - walking instead")
        --     end
        -- end
        
        -- Just walk - pathfinding will route around moonstones
        API.DoAction_Tile(targetTile)
        API.RandomSleep2(300, 50, 100)
        return true
    else
        if Vermyx.state.soulRushActive then
            debugLog("Soul Rush complete!")
            Vermyx.state.soulRushActive = false
        end
    end
    
    return false
end

---Check if Soul Rush is active
function Vermyx.isSoulRushActive()
    return Vermyx.state.soulRushActive
end

---Return to center (1 tile north of moonstone)
function Vermyx.returnToCenter(allObjects)
    local moonstoneTiles = Vermyx.getMoonstoneTiles(allObjects)
    
    if not moonstoneTiles or #moonstoneTiles == 0 then
        debugLog("No moonstone found for center reference")
        return false
    end
    
    local targetX = moonstoneTiles[1].x
    local targetY = moonstoneTiles[1].y + 1
    
    -- Make sure target isn't on a moonstone
    if SanctumMechanics.isTileBlocked(targetX, targetY, moonstoneTiles) then
        targetY = targetY + 1  -- Try one more tile north
    end
    
    local playerPos = API.PlayerCoord()
    local dist = math.abs(playerPos.x - targetX) + math.abs(playerPos.y - targetY)
    
    if dist <= 2 then
        return false
    end
    
    debugLog("Returning to center: " .. targetX .. ", " .. targetY)
    API.DoAction_Tile(WPOINT.new(targetX, targetY, 0))
    API.RandomSleep2(1200, 200, 300)
    
    return true
end

---Reset state
function Vermyx.resetState()
    Vermyx.state.soulRushActive = false
    Vermyx.state.moonstoneAnimDetected = false
    Vermyx.state.moonstoneAnimTick = 0
    Vermyx.state.moonstoneDirection = "west"  -- Start with west
    Vermyx.state.moonstoneCount = 0
end

SanctumMechanics.Vermyx = Vermyx

--[[
    ========================================
    KEZALAM MECHANICS
    ========================================
]]

local Kezalam = {}

Kezalam.state = {
    phase = 1,
    obelisk1Killed = false,
    obelisk2Killed = false,
    obelisksActive = false,
    inPrison = false,
    lastChatCheck = 0,
    bossPosition = nil,
    isHandlingScarabs = false,
    isHandlingObelisk = false,
    useFreedom = false,
    useResonance = false,
    isMoonObeliskPhase = false,
    -- Sanctum Blast dodge state
    sbEvading = false,
    -- Obelisk phase scarab tracking (for Powerburst of Vitality timing)
    obeliskScarabSpawnTime = nil,
    obeliskScarabPowerburstUsed = false,
}

function Kezalam.jumpLedge()
    debugLog("Jumping down ledge to Kezalam")
    API.RandomSleep2(600, 200, 300)
    if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {IDs.KEZALAM_LEDGE}, 10) then
        API.RandomSleep2(2600, 2600, 2600)
        return true
    end
    return false
end
function Kezalam.getSBTiles(allObjects)
    local tiles = {}

    for _, tileId in ipairs(IDs.SB_TILES) do
        local found = SanctumMechanics.getCoordsFromTable(allObjects, 4, tileId)
        if found then
            for _, t in ipairs(found) do
                tiles[#tiles + 1] = t
            end
        end
    end

    --print("SB Tiles found: " .. #tiles)

    return tiles
end

function Kezalam.handleSanctumBlast(allObjects)

    if Kezalam.state.isHandlingObelisk or Kezalam.state.isMoonObeliskPhase then
        return false
    end

    local sbTiles = Kezalam.getSBTiles(allObjects)
    if not sbTiles then return false end

    local boss = API.FindNPCbyName("Kezalam, the Wanderer", 20)
    if not boss then return false end

    local bossTile = boss.Tile_XYZ
    local playerTile = API.PlayerCoord()

    if not SanctumMechanics.isOnDangerTile(sbTiles, 5) then
        return false
    end

    local targetTile = nil
    local defaultTile = WPOINT.new(bossTile.x + 5, bossTile.y, bossTile.z)

    for _, SB in ipairs(sbTiles) do
        local sbX, sbY = SB.x, SB.y
        local bossX, bossY = bossTile.x, bossTile.y
        if sbX == bossX + 6 or sbX == bossX + 7 then
            targetTile = WPOINT.new(bossX + 2, bossY, bossTile.z)
            print("Move tile 1")
        elseif sbX == bossX + 10 or sbX == bossX then
            targetTile = WPOINT.new(bossX + 5, bossY, bossTile.z)
            print("Move tile 2")
        elseif sbX == bossX + 12 then
            targetTile = WPOINT.new(playerTile.x, playerTile.y + 3, bossTile.z)
            print("Move tile 3")
        elseif sbY == bossY + 15 then
            targetTile = WPOINT.new(playerTile.x + 3, playerTile.y, bossTile.z)
            print("Move tile 4")
        end

        if targetTile then break end
    end

    if not targetTile then
        targetTile = defaultTile
        print("No matching blast tile, returning to default position")
    end

    API.DoAction_Tile(targetTile)

    local timeout = os.clock() + 1.5
    while os.clock() < timeout do
        local currentTile = API.PlayerCoord()
        local dist = math.abs(currentTile.x - targetTile.x) + math.abs(currentTile.y - targetTile.y)
        if dist <= 1 then
            return true
        end
        API.RandomSleep2(50, 10, 20)
    end

    return false
end

---Get line blast highlight tiles (IDs 8199 and 8239)
---@param allObjects table
---@return table tiles list of coordinates
function Kezalam.getLineBlastTiles(allObjects)
    local tiles = {}

    local found1 = SanctumMechanics.getCoordsFromTable(allObjects, 4, IDs.SB_LINE_HIGHLIGHT_1)
    if found1 then
        for _, t in ipairs(found1) do
            tiles[#tiles + 1] = t
        end
    end

    local found2 = SanctumMechanics.getCoordsFromTable(allObjects, 4, IDs.SB_LINE_HIGHLIGHT_2)
    if found2 then
        for _, t in ipairs(found2) do
            tiles[#tiles + 1] = t
        end
    end

    return tiles
end

---Handle "Paiiin" line blast mechanic
---Detects line orientation (horizontal/vertical) and dodges accordingly:
---  Horizontal line: uses same X-based boss-relative dodge as handleSanctumBlast
---  Vertical line: dodges by changing Y position (boss.y + 5)
---@param allObjects table
---@return boolean true if dodging
function Kezalam.handleLineBlast(allObjects)
    if Kezalam.state.isHandlingObelisk or Kezalam.state.isMoonObeliskPhase then
        return false
    end

    local lineTiles = Kezalam.getLineBlastTiles(allObjects)
    if not lineTiles or #lineTiles == 0 then
        return false
    end

    -- Check if player is actually on/near a danger tile
    if not SanctumMechanics.isOnDangerTile(lineTiles, 2) then
        return false
    end

    local boss = API.FindNPCbyName("Kezalam, the Wanderer", 20)
    if not boss then return false end

    local bossTile = boss.Tile_XYZ
    local playerTile = API.PlayerCoord()

    debugLog("LINE BLAST detected! " .. #lineTiles .. " danger tiles found")

    -- Determine line orientation by analyzing tile coordinate spread
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    for _, tile in ipairs(lineTiles) do
        if tile.x < minX then minX = tile.x end
        if tile.x > maxX then maxX = tile.x end
        if tile.y < minY then minY = tile.y end
        if tile.y > maxY then maxY = tile.y end
    end
    local xSpread = maxX - minX
    local ySpread = maxY - minY

    local targetTile = nil
    local bossX, bossY = bossTile.x, bossTile.y

    if xSpread > ySpread then
        -- HORIZONTAL line (extends along X) - dodge by changing Y
        -- Move to boss.y + 5 (or boss.y - 5 if we're already above the line)
        local lineY = math.floor((minY + maxY) / 2)
        if playerTile.y >= lineY then
            targetTile = WPOINT.new(bossX, bossY + 3, bossTile.z)
        else
            targetTile = WPOINT.new(bossX, bossY - 3, bossTile.z)
        end
        debugLog("Line blast is HORIZONTAL - dodging Y to " .. targetTile.y)
    else
        -- VERTICAL line (extends along Y) - dodge by changing Y
        -- Move to boss.y + 5 (or boss.y - 5 if we're already above the line)
        local lineX = math.floor((minX + maxX) / 2)
        if playerTile.x >= lineX then
            targetTile = WPOINT.new(bossX + 3, bossY, bossTile.z)
        else
            targetTile = WPOINT.new(bossX - 3, bossY - 5, bossTile.z)
        end
        debugLog("Line blast is VERTICAL - dodging X to " .. targetTile.x)
    end

    API.DoAction_Tile(targetTile)

    -- Wait until we've moved or timeout
    local timeout = os.clock() + 1.5
    while os.clock() < timeout do
        local currentPos = API.PlayerCoord()
        local dist = math.abs(currentPos.x - targetTile.x) + math.abs(currentPos.y - targetTile.y)
        if dist <= 1 then
            debugLog("Successfully dodged line blast")
            return true
        end
        API.RandomSleep2(50, 10, 20)
    end

    debugLog("Line blast dodge timed out")
    return true
end

function Kezalam.handlePrison()
    local prisons = API.GetAllObjArrayInteract(IDs.PRISON_NPCS, 10, {1})
    local prisonOrb = API.GetAllObjArray1({8187}, 50, {5})

    if prisons and #prisons == 8 and not Kezalam.state.inPrison then
        Kezalam.state.inPrison = true

    elseif Kezalam.state.inPrison and #prisons < 8 then
        hasUsedFreedom = false
        hasUsedResonance = false
        Kezalam.state.inPrison = false
        API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 900, 900)
        API.DoAction_Ability("Resonance", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 900, 900)
        API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {IDs.KEZALAM}, 10)
        API.RandomSleep2(700, 900, 900)
        API.DoAction_Ability("Surge", 1, API.OFF_ACT_GeneralInterface_route)
    end

    if Kezalam.state.inPrison then
        debugLog("*** PRISON DETECTED ***")
        Kezalam.state.inPrison = true

        if isAbilityReady("Freedom") then
            API.DoAction_Ability_check("Freedom", 1, API.OFF_ACT_GeneralInterface_route, true, true, true)
            -- Kezalam.state.useFreedom = true
        end

        --fall back, incase the prison doesn't break immediately, or if we miss the timing for the initial surge
        if #prisonOrb > 0 and not hasUsedResonance then
            print((prisonOrb[1].Tile_XYZ.z - API.PlayerCoord().z) .. "XYZdistanceXYZ")
            if isAbilityReady("Resonance") and prisonOrb[1].Tile_XYZ.z - API.PlayerCoord().z <= 3 then
                API.DoAction_Ability_check("Resonance", 1, API.OFF_ACT_GeneralInterface_route, true, true, true)
                Kezalam.state.useResonance = true
                hasUsedResonance = true
            end
        end

        local closest = prisons[1]
        local alreadyTargeting = false
        for _, id in ipairs(IDs.PRISON_NPCS) do
            if SanctumMechanics.isInCombatWith(id) then
                alreadyTargeting = true
                return true
            end
        end
        
        if not alreadyTargeting then
            API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {closest.Id}, 10)
        end
        
        return true
    else 
        return false
    end
end

function Kezalam.handleVolatileScarabs()
    -- Skip scarabs during obelisk phase - prioritise killing the obelisk first
    if Kezalam.state.isMoonObeliskPhase then
        return false
    end

    local scarabs = API.GetAllObjArrayInteract({IDs.VOLATILE_SCARAB}, 30, {1})

    if scarabs and #scarabs > 0 then
        debugLog("Volatile Scrab detected!")
        Kezalam.state.isHandlingScarabs = true
    end

    if Kezalam.state.isHandlingScarabs and #scarabs == 0 then
        debugLog("All Volatile Scarabs cleared!")
        API.DoAction_Dive_Tile(WPOINT.new(SanctumVariable.CentralPosition.x + 6, SanctumVariable.CentralPosition.y, SanctumVariable.CentralPosition.z))
        API.RandomSleep2(600, 600, 600)
        API.DoAction_Tile(WPOINT.new(SanctumVariable.CentralPosition.x + 6, SanctumVariable.CentralPosition.y, SanctumVariable.CentralPosition.z))
        API.RandomSleep2(1200, 1200, 1200)
        Kezalam.state.isHandlingScarabs = false
    end

    if not scarabs or #scarabs == 0 then
        return false
    end

    if  scarabs[1].Life > 0 then
        local soulStacks = getResidualSoulStacks()
        if soulStacks < 1 then
            debugLog("Volatile Scarab detected but no soul stacks - waiting - Stacks: " .. soulStacks)
            return false
        end

        API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {IDs.VOLATILE_SCARAB}, 30)
        API.RandomSleep2(600, 100, 150)
        debugLog("Volatile Scarab detected - using Soul Strike!")
        API.DoAction_Ability_check("Soul Strike", 1, API.OFF_ACT_GeneralInterface_route, true, true, true)

        return true
    end
    return false
end

function Kezalam.updatePhase(bossHPPercent)
    local oldPhase = Kezalam.state.phase
    
    if bossHPPercent > 60 then
        Kezalam.state.phase = 1
    elseif bossHPPercent > 30 then
        Kezalam.state.phase = 2
    else
        Kezalam.state.phase = 3
    end
    
    if oldPhase ~= Kezalam.state.phase then
        debugLog("Phase change: " .. oldPhase .. " -> " .. Kezalam.state.phase)
        return true
    end
    
    return false
end

function Kezalam.resetState()
    Kezalam.state.phase = 1
    Kezalam.state.obelisk1Killed = false
    Kezalam.state.obelisk2Killed = false
    Kezalam.state.obelisksActive = false
    Kezalam.state.inPrison = false
    Kezalam.state.bossPosition = nil
    Kezalam.state.sbEvading = false

    SanctumMechanics.Kezalam.state.isHandlingObelisks = false
    SanctumMechanics.Kezalam.state.obeliskPhaseNumber = 0
    SanctumMechanics.Kezalam.state.returningToCenter = false
end

SanctumMechanics.Kezalam = Kezalam

--[[
    ========================================
    NAKATRA MECHANICS
    ========================================
]]

local Nakatra = {}

function Nakatra.crossGap()
    debugLog("Crossing gap to Nakatra")
    if API.DoAction_Object1(0x39, API.OFF_ACT_GeneralObject_route0, {IDs.NAKATRA_GAP}, 50) then
        API.RandomSleep2(2000, 500, 500)
        return true
    end
    return false
end

SanctumMechanics.Nakatra = Nakatra

--[[
    ========================================
    GENERAL UTILITIES
    ========================================
]]

function SanctumMechanics.moveToTile(x, y, z)
    local playerPos = API.PlayerCoord()
    local dist = math.abs(playerPos.x - x) + math.abs(playerPos.y - y)
    
    if dist <= 2 then
        return true
    end
    
    z = z or 0
    
    if dist > 10 then
        local diveReady = isAbilityReady("Dive")
        if diveReady then
            debugLog("Diving to " .. x .. ", " .. y)
            API.DoAction_Dive_Tile(WPOINT.new(x, y, z))
            return true
        end
    end
    
    debugLog("Walking to " .. x .. ", " .. y)
    API.DoAction_Tile(WPOINT.new(x, y, z))
    return true
end

function SanctumMechanics.isInCombat()
    return API.LocalPlayer_IsInCombat_()
end

function SanctumMechanics.isInCombatWith(npcId)
    local target = API.ReadLpInteracting()
    if target and target.Id and target.Id == npcId then
        return true
    end
    return false
end

function SanctumMechanics.attackNPC(npcId)
    local currentTick = API.Get_tick()
    
    if currentTick - attack_cooldown < 10 then
        return false
    end
    
    if SanctumMechanics.isInCombatWith(npcId) then
        return false
    end
    
    debugLog("Attacking NPC " .. npcId)
    attack_cooldown = currentTick
    return API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {npcId}, 50)
end

function SanctumMechanics.lootTreasure()
    local chest = API.GetAllObjArrayInteract({IDs.SANCTUM_TREASURE}, 20, {0})
    if chest and #chest > 0 then
        debugLog("Looting treasure chest")
        API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {IDs.SANCTUM_TREASURE}, 50)
        API.RandomSleep2(2000, 300, 400)
        API.DoAction_Interface(0x24,0xffffffff,1,168,27,-1,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(500, 100, 200)
        return true
    end
    return false
end

function SanctumMechanics.useArchway()
    local archway = API.GetAllObjArrayInteract({IDs.ARCHWAY}, 20, {0})
    if archway and #archway > 0 then
        debugLog("Using archway to next boss")
        API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, {IDs.ARCHWAY}, 20)
        API.RandomSleep2(3000, 500, 800)
        return true
    end
    return false
end


return SanctumMechanics
