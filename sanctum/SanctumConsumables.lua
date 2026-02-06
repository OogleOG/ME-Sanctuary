--[[
    SanctumConsumables.lua
    Handles eating, brewing, and prayer restoration for Sanctum bosses
    Supports combo eating (food + brew same tick)
]]

local API = require("api")

local SanctumConsumables = {}

-- Debug
local debug = true

local function debugLog(msg)
    if debug then
        print("[CONSUMABLES]: " .. msg)
    end
end

function SanctumConsumables.setDebug(enabled)
    debug = enabled
end

--[[
    ========================================
    CONFIGURATION
    ========================================
]]

-- HP thresholds
local HP_EAT_THRESHOLD = 6000      -- Eat food below this HP
local HP_BREW_THRESHOLD = 4000     -- Emergency brew below this HP
local HP_COMBO_THRESHOLD = 3500    -- Combo eat (food + brew) below this

-- Prayer threshold
local PRAYER_RESTORE_THRESHOLD = 30  -- Restore prayer below this %

-- Cooldowns (in ticks, 1 tick = 600ms)
local FOOD_COOLDOWN = 4            -- 3 ticks between food
local BREW_COOLDOWN = 3            -- Brews have separate cooldown
local RESTORE_COOLDOWN = 2         -- Restores have separate cooldown

-- Last use tracking
local lastFoodTick = 0
local lastBrewTick = 0
local lastRestoreTick = 0

--[[
    ========================================
    SUPPORTED CONSUMABLES (Ability Bar Names)
    ========================================
    These are the names as they appear on the ability bar
]]

-- Food abilities (in priority order)
local FOOD_ABILITIES = {
    "Sailfish",
    "Blue blubber jellyfish (2/3)",
    "Blue blubber jellyfish (1/3)",
    "Blue blubber jellyfish",
    "Green blubber jellyfish",
    "Green blubber jellyfish (2/3)",
    "Green blubber jellyfish (1/3)",
    "Rocktail",
    "Great white shark",
    "Shark",
    "Cavefish",
    "Eat Food",  -- Generic fallback
}

-- Brew abilities (can combo eat with food)
local BREW_ABILITIES = {
    "Super Saradomin brew",
    "Saradomin brew",
}

-- Prayer restore abilities
local RESTORE_ABILITIES = {
    "Super restore",
    "Prayer potion",
    "Prayer renewal",
    "Extreme prayer",
}

--[[
    ========================================
    UTILITY FUNCTIONS
    ========================================
]]

---Check if ability is available on action bar and off cooldown
---@param abilityName string
---@return boolean available, table|nil abilityInfo
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

---Use ability from action bar
---@param abilityName string
---@return boolean success
local function useAbility(abilityName)
    local ready, ab = isAbilityReady(abilityName)
    if ready then
        debugLog("Using ability: " .. abilityName)
        return API.DoAction_Ability(abilityName, 1, API.OFF_ACT_GeneralInterface_route)
    end
    return false
end

---Get current HP
---@return number
local function getCurrentHP()
    return API.GetHP_() or 0
end

---Get max HP
---@return number
local function getMaxHP()
    -- Calculate from percentage
    local hp = API.GetHP_() or 0
    local pct = API.GetHPrecent() or 100
    if pct <= 0 then return 10000 end
    return math.floor((hp / pct) * 100)
end

---Get current prayer percentage
---@return number 0-100
local function getPrayerPercent()
    return API.GetPrayPrecent() or 100
end

--[[
    ========================================
    EATING FUNCTIONS
    ========================================
]]

---Eat food if below threshold (uses ability bar)
---@return boolean true if ate food
function SanctumConsumables.eatFood()
    local currentTick = API.Get_tick()
    
    -- Check cooldown
    if currentTick - lastFoodTick < FOOD_COOLDOWN then
        return false
    end
    
    -- Check HP threshold
    local hp = getCurrentHP()
    if hp >= HP_EAT_THRESHOLD then
        return false
    end
    
    -- Try each food ability in priority order
    for _, foodName in ipairs(FOOD_ABILITIES) do
        local ready, ab = isAbilityReady(foodName)
        if ready then
            debugLog("Eating " .. foodName .. " (HP: " .. hp .. ")")
            if API.DoAction_Ability(foodName, 1, API.OFF_ACT_GeneralInterface_route) then
                lastFoodTick = currentTick
                return true
            end
        end
    end
    
    debugLog("No food available on ability bar!")
    return false
end

---Drink brew if below threshold (uses ability bar)
---@return boolean true if drank brew
function SanctumConsumables.drinkBrew()
    local currentTick = API.Get_tick()
    
    -- Check cooldown
    if currentTick - lastBrewTick < BREW_COOLDOWN then
        return false
    end
    
    -- Check HP threshold
    local hp = getCurrentHP()
    if hp >= HP_BREW_THRESHOLD then
        return false
    end
    
    -- Try each brew ability in priority order
    for _, brewName in ipairs(BREW_ABILITIES) do
        local ready, ab = isAbilityReady(brewName)
        if ready then
            debugLog("Drinking " .. brewName .. " (HP: " .. hp .. ")")
            if API.DoAction_Ability(brewName, 1, API.OFF_ACT_GeneralInterface_route) then
                lastBrewTick = currentTick
                return true
            end
        end
    end
    
    debugLog("No brews available on ability bar!")
    return false
end

---Combo eat (food + brew on same tick) for emergencies
---@return boolean true if combo ate
function SanctumConsumables.comboEat()
    local currentTick = API.Get_tick()
    
    -- Check HP threshold for combo
    local hp = getCurrentHP()
    if hp >= HP_COMBO_THRESHOLD then
        return false
    end
    
    debugLog("COMBO EATING! (HP: " .. hp .. ")")
    
    local ate = false
    local brewed = false
    
    -- Eat food first (if off cooldown)
    if currentTick - lastFoodTick >= FOOD_COOLDOWN then
        for _, foodName in ipairs(FOOD_ABILITIES) do
            local ready = isAbilityReady(foodName)
            if ready then
                if API.DoAction_Ability(foodName, 1, API.OFF_ACT_GeneralInterface_route) then
                    lastFoodTick = currentTick
                    ate = true
                    debugLog("Combo: Ate " .. foodName)
                    break
                end
            end
        end
    end
    
    -- Small delay then brew (brews can be used same tick as food)
    API.RandomSleep2(50, 10, 20)
    
    -- Drink brew (if off cooldown)
    if currentTick - lastBrewTick >= BREW_COOLDOWN then
        for _, brewName in ipairs(BREW_ABILITIES) do
            local ready = isAbilityReady(brewName)
            if ready then
                if API.DoAction_Ability(brewName, 1, API.OFF_ACT_GeneralInterface_route) then
                    lastBrewTick = currentTick
                    brewed = true
                    debugLog("Combo: Drank " .. brewName)
                    break
                end
            end
        end
    end
    
    return ate or brewed
end

---Restore prayer if below threshold (uses ability bar)
---@return boolean true if restored
function SanctumConsumables.restorePrayer()
    local currentTick = API.Get_tick()
    
    -- Check cooldown
    if currentTick - lastRestoreTick < RESTORE_COOLDOWN then
        return false
    end
    
    -- Check prayer threshold
    local prayerPct = getPrayerPercent()
    if prayerPct >= PRAYER_RESTORE_THRESHOLD then
        return false
    end
    
    -- Try each restore ability in priority order
    for _, restoreName in ipairs(RESTORE_ABILITIES) do
        local ready, ab = isAbilityReady(restoreName)
        if ready then
            debugLog("Drinking " .. restoreName .. " (Prayer: " .. prayerPct .. "%)")
            if API.DoAction_Ability(restoreName, 1, API.OFF_ACT_GeneralInterface_route) then
                lastRestoreTick = currentTick
                return true
            end
        end
    end
    
    debugLog("No prayer restores available on ability bar!")
    return false
end

--[[
    ========================================
    MAIN UPDATE FUNCTION
    ========================================
]]

---Main update - call every loop iteration
---Handles all consumable logic with priorities
---@return boolean true if any consumable was used
function SanctumConsumables.update()
    if not API.PlayerLoggedIn() then
        return false
    end
    
    local hp = getCurrentHP()
    local prayerPct = getPrayerPercent()
    
    -- Priority 1: Emergency combo eat if very low HP
    if hp < HP_COMBO_THRESHOLD then
        if SanctumConsumables.comboEat() then
            return true
        end
    end
    
    -- Priority 2: Eat food if low HP
    if hp < HP_EAT_THRESHOLD then
        if SanctumConsumables.eatFood() then
            return true
        end
        -- If no food, try brew
        if SanctumConsumables.drinkBrew() then
            return true
        end
    end
    
    -- Priority 3: Restore prayer if low
    if prayerPct < PRAYER_RESTORE_THRESHOLD then
        if SanctumConsumables.restorePrayer() then
            return true
        end
    end
    
    return false
end

--[[
    ========================================
    CONFIGURATION FUNCTIONS
    ========================================
]]

---Set HP threshold for eating food
---@param threshold number
function SanctumConsumables.setEatThreshold(threshold)
    HP_EAT_THRESHOLD = threshold
    debugLog("Eat threshold set to " .. threshold)
end

---Set HP threshold for drinking brews
---@param threshold number
function SanctumConsumables.setBrewThreshold(threshold)
    HP_BREW_THRESHOLD = threshold
    debugLog("Brew threshold set to " .. threshold)
end

---Set HP threshold for combo eating
---@param threshold number
function SanctumConsumables.setComboThreshold(threshold)
    HP_COMBO_THRESHOLD = threshold
    debugLog("Combo threshold set to " .. threshold)
end

---Set prayer restore threshold (percentage)
---@param threshold number 0-100
function SanctumConsumables.setPrayerThreshold(threshold)
    PRAYER_RESTORE_THRESHOLD = threshold
    debugLog("Prayer restore threshold set to " .. threshold .. "%")
end

---Add a custom food ability to the list
---@param abilityName string
---@param priority number|nil position in list (1 = highest priority)
function SanctumConsumables.addFood(abilityName, priority)
    if priority then
        table.insert(FOOD_ABILITIES, priority, abilityName)
    else
        table.insert(FOOD_ABILITIES, abilityName)
    end
    debugLog("Added food ability: " .. abilityName)
end

---Add a custom brew ability to the list
---@param abilityName string
---@param priority number|nil position in list (1 = highest priority)
function SanctumConsumables.addBrew(abilityName, priority)
    if priority then
        table.insert(BREW_ABILITIES, priority, abilityName)
    else
        table.insert(BREW_ABILITIES, abilityName)
    end
    debugLog("Added brew ability: " .. abilityName)
end

---Add a custom restore ability to the list
---@param abilityName string
---@param priority number|nil position in list (1 = highest priority)
function SanctumConsumables.addRestore(abilityName, priority)
    if priority then
        table.insert(RESTORE_ABILITIES, priority, abilityName)
    else
        table.insert(RESTORE_ABILITIES, abilityName)
    end
    debugLog("Added restore ability: " .. abilityName)
end

--[[
    ========================================
    STATUS FUNCTIONS
    ========================================
]]

---Check if we have any food on ability bar
---@return boolean
function SanctumConsumables.hasFood()
    for _, foodName in ipairs(FOOD_ABILITIES) do
        local ab = API.GetABs_name(foodName, false)
        if ab and ab.id > 0 and ab.enabled then
            return true
        end
    end
    return false
end

---Check if we have any brews on ability bar
---@return boolean
function SanctumConsumables.hasBrews()
    for _, brewName in ipairs(BREW_ABILITIES) do
        local ab = API.GetABs_name(brewName, false)
        if ab and ab.id > 0 and ab.enabled then
            return true
        end
    end
    return false
end

---Check if we have any restores on ability bar
---@return boolean
function SanctumConsumables.hasRestores()
    for _, restoreName in ipairs(RESTORE_ABILITIES) do
        local ab = API.GetABs_name(restoreName, false)
        if ab and ab.id > 0 and ab.enabled then
            return true
        end
    end
    return false
end

---Get current supplies status
---@return table {hasFood, hasBrews, hasRestores, hp, hpPercent, prayer}
function SanctumConsumables.getStatus()
    local hp = getCurrentHP()
    local maxHp = getMaxHP()
    return {
        hasFood = SanctumConsumables.hasFood(),
        hasBrews = SanctumConsumables.hasBrews(),
        hasRestores = SanctumConsumables.hasRestores(),
        hp = hp,
        hpPercent = math.floor((hp / maxHp) * 100),
        prayer = getPrayerPercent(),
    }
end

---Check if we're dangerously low on supplies
---@return boolean
function SanctumConsumables.isLowSupplies()
    local status = SanctumConsumables.getStatus()
    return not status.hasFood and not status.hasBrews
end

---Reset cooldowns (call when fight ends/resets)
function SanctumConsumables.reset()
    lastFoodTick = 0
    lastBrewTick = 0
    lastRestoreTick = 0
    debugLog("Cooldowns reset")
end

return SanctumConsumables