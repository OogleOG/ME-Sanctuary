--[[
    SanctumRotationManager.lua
    Based on PVME Sanctum HM Solo Necromancy guide
    Handles ability rotations for Sanctum bosses
    
    Step types:
    - "Ability": Cast ability by name
    - "Inventory": Use item from inventory
    - "Custom": Execute custom function
    - "Improvise": Use best available ability (Necromancy)
]]

local API = require("api")
local SanctumTimer = require("sanctum.SanctumTimer")
local SanctumMechanics = require("sanctum.SanctumMechanics")

local SanctumRotationManager = {}
SanctumRotationManager.__index = SanctumRotationManager

local debug = true

SanctumRotationManager.adrenalinePotions = {
    "Adrenaline potion",
    "Super adrenaline potion",
    "Adrenaline renewal potion",
    "Replenishment potion",
    "Enhanced replenishment potion"
}

-- Equipment IDs
SanctumRotationManager.deathGuardIds = {55524, 55532, 55540, 55528, 55536, 55544}
SanctumRotationManager.omniGuardIds = {55484} --, 55480}
SanctumRotationManager.soulbornLanternIds = {55482, 55485}
SanctumRotationManager.essenceFinalityIds = {50467, 51063}

-- Equipment state
SanctumRotationManager.hasEssenceOfFinality = false
SanctumRotationManager.hasDeathGuardEquipped = false
SanctumRotationManager.hasOmniGuardEquipped = false
SanctumRotationManager.hasSoulboundLanternEquipped = false
SanctumRotationManager.residualSoulsMax = 5

function SanctumRotationManager.checkNecklaceType()
    SanctumRotationManager.hasEssenceOfFinalityEquipped = Equipment:Contains("Essence of Finality amulet (black)")
    SanctumRotationManager.hasConjurerAmuletEquipped = Equipment:Contains("Conjurer's raising amulet")
end

-- Check for equipped weapon type
function SanctumRotationManager.checkWeaponType()
    SanctumRotationManager.hasDeathGuardEquipped = false
    SanctumRotationManager.hasOmniGuardEquipped = false
    SanctumRotationManager.hasSoulboundLanternEquipped = false
    SanctumRotationManager.residualSoulsMax = 5

    local equippedItems = API.Container_Get_all(94)
    for i = 1, #equippedItems do
        local itemId = equippedItems[i].item_id

        for j = 1, #SanctumRotationManager.deathGuardIds do
            if itemId == SanctumRotationManager.deathGuardIds[j] then
                SanctumRotationManager.hasDeathGuardEquipped = true
                SanctumRotationManager.debugLog("Death Guard equipped")
                break
            end
        end

        for k = 1, #SanctumRotationManager.omniGuardIds do
            if itemId == SanctumRotationManager.omniGuardIds[k] then
                SanctumRotationManager.hasOmniGuardEquipped = true
                SanctumRotationManager.debugLog("Omni Guard equipped")
                break
            end
        end

        for l = 1, #SanctumRotationManager.soulbornLanternIds do
            if itemId == SanctumRotationManager.soulbornLanternIds[l] then
                SanctumRotationManager.hasSoulboundLanternEquipped = true
                SanctumRotationManager.residualSoulsMax = 5
                SanctumRotationManager.debugLog("Soulbound Lantern equipped")
                break
            end
        end

    end
end

-- Check all equipment (call this on init or when equipment changes)
function SanctumRotationManager.checkEquipment()
    SanctumRotationManager.checkWeaponType()
end

-- Track cooldowns for certain abilities
local lastBloatTime = 0
local lastLordOfBonesTime = 0
local lastSplitSoulTime = 0

function SanctumRotationManager.debugLog(message)
    if debug then
        print("[ROTATION]: " .. message)
    end
end

function SanctumRotationManager.setDebug(enabled)
    debug = enabled
end

---Create a new rotation manager
---@param config table {name: string, rotation: table[]}
---@return SanctumRotationManager
function SanctumRotationManager.new(config)
    local self = setmetatable({}, SanctumRotationManager)
    
    self.name = config.name or "Unnamed Rotation"
    self.rotation = config.rotation or {}
    self.index = 1
    self.improvising = false
    self.trailing = false
    
    self.timer = SanctumTimer.new({
        name = self.name .. " Timer",
        cooldown = 0,
        useTicks = true,
        condition = function() return true end,
        action = function() return true end
    })
    
    return self
end

---Use an ability from the action bar
---@param name string ability name
---@return boolean
function SanctumRotationManager:_useAbility(name)
    local ability = API.GetABs_name(name, false)
    if ability then
        SanctumRotationManager.debugLog("Using ability: " .. name)
        if API.DoAction_Ability(name, 1, API.OFF_ACT_GeneralInterface_route, true) then
            return true
        end
    else
        SanctumRotationManager.debugLog("Ability " .. name .. " not found - skipping")
        return true
    end
    return false
end

---Use an item from inventory
---@param itemName string
---@return boolean
function SanctumRotationManager:_useInventory(itemName)
    return API.DoAction_Inventory3(itemName, 0, 1, API.OFF_ACT_GeneralInterface_route)
end

---Get buff status
---@param buffId number
---@return table {found: boolean, remaining: number}
function SanctumRotationManager:getBuff(buffId)
    local buff = API.Buffbar_GetIDstatus(buffId, false)
    return {
        found = buff.found,
        remaining = buff.found and API.Bbar_ConvToSeconds(buff) or 0
    }
end

---Get debuff status on target
---@param debuffId number
---@return table {found: boolean, remaining: number}
function SanctumRotationManager:getDebuff(debuffId)
    local debuff = API.DeBuffbar_GetIDstatus(debuffId, false)
    return {
        found = debuff.found,
        remaining = debuff.found and API.Bbar_ConvToSeconds(debuff) or 0
    }
end

---Check if target has Bloat debuff
---@return boolean
local function checkBloated()
    if API.ReadTargetInfo99(false).Hitpoints ~= 0 then
        local buffStack = API.ReadTargetInfo99(true).Buff_stack
        for _, buff in ipairs(buffStack) do
            if buff == 30098 then
                return true
            end
        end
    end
    return false
end

---Check if we have Split Soul active
---@return boolean
local function hasSplitSoul()
    return API.Buffbar_GetIDstatus(30116, false).found
end

---Check if Weapon Special Attack is on cooldown (debuff 55480 active)
---@return boolean true if spec is available (not on cooldown)
local function canUseWeaponSpec()
    return not API.DeBuffbar_GetIDstatus(55480, false).found
end

---Check if we have Invoke Death mark on target
---@return boolean
local function hasDeathMark()
    local debuff = API.DeBuffbar_GetIDstatus(30080, false)
    return debuff.found
end

---Check if Vengeance buff is active (pending reflect)
---@return boolean
local function hasVengeanceBuff()
    return API.Buffbar_GetIDstatus(14423, false).found
end

---Check if Ingenuity of the Humans buff is active
---@return boolean
local function hasIngenuityBuff()
    return API.Buffbar_GetIDstatus(1521, false).found
end

---Check if Living Death is active
---@return boolean
local function hasLivingDeath()
    return API.Buffbar_GetIDstatus(30078, false).found
end

---Get necrosis stacks
---@return number
local function getNecrosisStacks()
    return tonumber(API.Buffbar_GetIDstatus(30101, false).conv_text) or 0
end

---Get residual soul stacks
---@return number
local function getSoulStacks()
    return tonumber(API.Buffbar_GetIDstatus(30123, false).conv_text) or 0
end

---Get ability info helper
---@param name string
---@return table {ready: boolean, enabled: boolean, cooldown: number}
local function getAbility(name)
    local ab = API.GetABs_name1(name)
    if not ab then
        return {ready = false, enabled = false, cooldown = 999}
    end
    return {
        ready = ab.cooldown_timer <= 1 and ab.enabled,
        enabled = ab.enabled,
        cooldown = ab.cooldown_timer
    }
end

--[[
    ========================================
    PVME ROTATION DEFINITIONS
    ========================================
    Based on: https://pvme.io/pvme-guides/rs3-full-boss-guides/sanctum/sanctum-hm-solo-necromancy/
]]

---Pre-build rotation (before engaging boss)
---@return table rotation steps
function SanctumRotationManager.createPrebuildRotation()
    return {
        {label = "Invoke Death", type = "Ability", wait = 3},
        {label = "Conjure Undead Army", type = "Ability", wait = 3},
        {label = "Life Transfer", type = "Ability", wait = 3},
        {label = "Command Vengeful Ghost", type = "Ability", wait = 3},
        {label = "Split Soul", type = "Ability", wait = 3},
        {label = "Command Skeleton Warrior", type = "Ability", wait = 3},
    }
end

---Vermyx Phase 1 opener
---@return table rotation steps
function SanctumRotationManager.createVermyxP1Rotation()
    return {
        -- Vuln bomb opener
        {label = "Death Skulls", type = "Ability", wait = 3},
        {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        {label = "Bloat", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Touch of Death", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Weapon Special Attack", type = "Ability", wait = 3,
            condition = canUseWeaponSpec,
            replacementLabel = "Soul Sap"}, -- Omniguard
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        -- Build on Coilspawn
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Divert", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Touch of Death", type = "Ability", wait = 3},
        {label = "Living Death", type = "Ability", wait = 3},
        {label = "Touch of Death", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Command Skeleton Warrior", type = "Ability", wait = 3},
        -- Improvise remainder
        {label = "Improvise", type = "Improvise", spend = true, wait = 3},
    }
end

---Vermyx Phase 2 (Living Death active)
---@return table rotation steps
function SanctumRotationManager.createVermyxP2Rotation()
    return {
        {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        {label = "Death Skulls", type = "Ability", wait = 3},
        {label = "Touch of Death", type = "Ability", wait = 3},
        {label = "Finger of Death", type = "Ability", wait = 3,
            condition = function() return getNecrosisStacks() >= 6 end,
            replacementLabel = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Volley of Souls", type = "Ability", wait = 3,
            condition = function() return getSoulStacks() >= 4 end,
            replacementLabel = "Soul Sap"},
        {label = "Finger of Death", type = "Ability", wait = 3,
            condition = function() return getNecrosisStacks() >= 6 end,
            replacementLabel = "Basic<nbsp>Attack"},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Touch of Death", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Split Soul", type = "Ability", wait = 3},
        {label = "Command Skeleton Warrior", type = "Ability", wait = 3},
        {label = "Improvise", type = "Improvise", spend = true, wait = 3},
    }
end

---Vermyx Phase 3 (finish)
---@return table rotation steps
function SanctumRotationManager.createVermyxP3Rotation()
    return {
        {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        {label = "Death Skulls", type = "Ability", wait = 3},
        {label = "Bloat", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Finger of Death", type = "Ability", wait = 3,
            condition = function() return getNecrosisStacks() >= 6 end,
            replacementLabel = "Basic<nbsp>Attack"},
        {label = "Touch of Death", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Volley of Souls", type = "Ability", wait = 3,
            condition = function() return getSoulStacks() >= 4 end,
            replacementLabel = "Soul Sap"},
        {label = "Weapon Special Attack", type = "Ability", wait = 3,
            condition = canUseWeaponSpec,
            replacementLabel = "Soul Sap"}, -- Omniguard
        {label = "Command Putrid Zombie", type = "Ability", wait = 3},
        {label = "Improvise", type = "Improvise", spend = true, wait = 3},
    }
end

---Check if Essence of Finality spec is available (debuff 55524 = Death Guard spec cooldown)
---@return boolean true if EoF spec can be used
local function canUseEoFSpec()
    return not API.DeBuffbar_GetIDstatus(55524, false).found
end

---Kezalam Obelisk 1 rotation (T95)
---Based on PVME: Invoke Death → Death Guard EoF spec → Volley of Souls → Soul Sap → Necro Auto
---Use Life Transfer as soon as pillar is dead (handled in fight logic)
---@return table rotation steps
function SanctumRotationManager.createObelisk1Rotation()
    return {
        {label = "Invoke Death", type = "Ability", wait = 3},
        {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        -- Use Essence of Finality directly (assumes EoF is on action bar with Death Guard spec stored)
        -- This matches Arch-Glacor script pattern - no amulet swapping needed
        {label = "Essence of Finality", type = "Ability", wait = 3,
            condition = canUseEoFSpec,
            replacementLabel = "Volley of Souls"},
        {label = "Volley of Souls", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Finger of Death", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        -- After obelisk dies, Life Transfer is handled in the fight handler
        {label = "Improvise", type = "Improvise", spend = true, wait = 3},
    }
end

---Kezalam Obelisk 2 rotation (T95)
---Based on PVME: Invoke Death → Soul Sap → Touch of Death → Necro Auto → Finger of Death → Death Skulls
---@return table rotation steps
function SanctumRotationManager.createObelisk2Rotation()
    return {
        {label = "Invoke Death", type = "Ability", wait = 3},
        {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Touch of Death", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Finger of Death", type = "Ability", wait = 3},
        {label = "Death Skulls", type = "Ability", wait = 3},
        {label = "Soul Sap", type = "Ability", wait = 3},
        {label = "Volley of Souls", type = "Ability", wait = 3},
        {label = "Basic<nbsp>Attack", type = "Ability", wait = 3},
        {label = "Improvise", type = "Improvise", spend = true, wait = 3},
    }
end

---Improvise best Necromancy ability based on PVME guide priorities
---@param spend boolean whether to spend adrenaline on big abilities
---@return string ability name
function SanctumRotationManager:_improvise(spend)
    local targetInfo = API.ReadTargetInfo99(true)
    local targetHealth = (targetInfo and targetInfo.Hitpoints) or 0
    local adrenaline = tonumber(API.GetAdrenalineFromInterface()) or 0
    local health = tonumber(API.GetHP_()) or 0
    local necrosisStacks = getNecrosisStacks()
    local soulStacks = getSoulStacks()
    local livingDeath = hasLivingDeath()
    local splitSoulActive = hasSplitSoul()
    local ability = "Soul Sap"

    local function canUseDefensive(name, requiredAdren)
    local ab = getAbility(name)
    local adrenaline = tonumber(API.GetAdrenalineFromInterface()) or 0

    if not ab.enabled then return false end
    if ab.cooldown > 1 then return false end
    if requiredAdren and adrenaline < requiredAdren then return false end

    return true
    end

    --[[local healthPercent = (health / API.GetHPMax_()) * 100

    -- Resonance: predictable single-hit sustain
    if healthPercent < 65 and canUseDefensive("Resonance", 0) then
        ability = "Resonance"

    -- Debilitate: reduces incoming damage, cheap & long
    elseif healthPercent < 70 and canUseDefensive("Debilitate", 0) then
        ability = "Debilitate"

    -- Reflect: sustained pressure or multi-hit
    elseif healthPercent < 60 and canUseDefensive("Reflect", 0) then
        ability = "Reflect"

    -- Devotion: LAST RESORT (costly, but powerful)
    elseif healthPercent < 50 and canUseDefensive("Devotion", 50) then
        ability = "Devotion"
    end]]--
    
    SanctumRotationManager.debugLog("[IMPROV] HP: " .. targetHealth .. " Adren: " .. adrenaline .. " Necrosis: " .. necrosisStacks .. " Souls: " .. soulStacks)

    -- Off-GCD: Vengeance + Ingenuity of the Humans combo
    -- Vengeance reflects 75% of next hit taken back to attacker (30s CD, capped at 8,000)
    -- IotH cast LAST so its 6s 100% hit chance buff carries into the next offensive ability
    if not hasVengeanceBuff() then
        local veng = getAbility("Vengeance")
        if veng and veng.ready then
            API.DoAction_Ability("Vengeance", 1, API.OFF_ACT_GeneralInterface_route, true)
            API.RandomSleep2(100, 50, 50)
            SanctumRotationManager.debugLog("[IMPROV] Cast Vengeance (off-GCD)")
        end
    end
    if not hasIngenuityBuff() then
        local ioth = getAbility("Ingenuity of the Humans")
        if ioth and ioth.ready then
            API.DoAction_Ability("Ingenuity of the Humans", 1, API.OFF_ACT_GeneralInterface_route, true)
            API.RandomSleep2(100, 50, 50)
            SanctumRotationManager.debugLog("[IMPROV] Cast Ingenuity of the Humans (off-GCD)")
        end
    end

    -- Off-GCD: Adrenaline renewal during Living Death
    if livingDeath then
        if not API.DeBuffbar_GetIDstatus(26094, false).found then
            for _, potionName in ipairs(SanctumRotationManager.adrenalinePotions) do
                local adrenPot = getAbility(potionName)
                if adrenPot.ready then
                    API.DoAction_Ability(potionName, 1, API.OFF_ACT_GeneralInterface_route)
                    API.RandomSleep2(100, 50, 50)
                    break
                end
            end
        end
    end
    -- Note: Equipment swapping removed - using Arch-Glacor pattern
    -- Assumes Weapon Special Attack and Essence of Finality are on action bar

    --[Obelisk rotations]
    -- Obelisk Burst Rotation (high priority burst damage)
    --[Obelisk rotations]
    if SanctumMechanics.Kezalam.state.isHandlingObelisks then
        local invokeDeath = getAbility("Invoke Death")
        local deathSkulls = getAbility("Death Skulls")
        local bloat = getAbility("Bloat")
        local fingerOfDeath = getAbility("Finger of Death")
        local volley = getAbility("Volley of Souls")
        local soulSap = getAbility("Soul Sap")
        local touchOfDeath = getAbility("Touch of Death")
        local necrosia = getAbility("Necrosia")
        
        -- Use buff ID directly (30101 is Invoke Death buff)
        if invokeDeath and invokeDeath.ready and not API.Buffbar_GetIDstatus(30101, false).found then
            return "Invoke Death"
        end
        
        if deathSkulls and deathSkulls.ready and adrenaline >= 60 then
            return "Death Skulls"
        end
        
        if bloat and bloat.ready and not checkBloated() then
            return "Bloat"
        end
        
        if fingerOfDeath and fingerOfDeath.ready and necrosisStacks >= 5 then
            return "Finger of Death"
        end

        -- Use soulStacks not residualSouls (residualSouls doesn't exist)
        if volley and volley.ready and soulStacks >= 3 then
            return "Volley of Souls"
        end
        
        if touchOfDeath and touchOfDeath.ready then
            return "Touch of Death"
        end

        if soulSap and soulSap.ready then
            return "Soul Sap"
        end
        
        -- Fixed variable name from necrosis to necrosia
        if necrosia and necrosia.ready and soulStacks >= 5 then
            return "Necrosia"
        end
        
        return "Soul Sap"
    end
        
    --[[
        LIVING DEATH ROTATION (from PVME)
        Priority: Death Skulls > Touch of Death (for adren) > Finger of Death (6+ necrosis) > Volley > auto
    ]]
    if livingDeath then
        local skulls = getAbility("Death Skulls")
        local touch = getAbility("Touch of Death")
        local finger = getAbility("Finger of Death")
        local volley = getAbility("Volley of Souls")
        local cmdSkel = getAbility("Command Skeleton Warrior")
        local soulSap = getAbility("Soul Sap")
        local resonance = getAbility("Resonance")
        local freedom = getAbility("Freedom")
        
        if soulSap.ready and SanctumMechanics.Kezalam.state.isHandlingScarabs then
            ability = "Soul Sap"
        elseif resonance.ready and SanctumMechanics.Kezalam.state.useResonance then
            ability = "Resonance"
        elseif freedom.ready and SanctumMechanics.Kezalam.state.useFreedom then
            SanctumMechanics.Kezalam.state.useFreedom = false
            ability = "Freedom"
        -- Death Skulls is top priority during Living Death (12s CD during LD)
        elseif skulls.ready and adrenaline >= 60 then
            ability = "Death Skulls"
        -- Touch of Death for adrenaline if Skulls on CD
        elseif touch.ready and (adrenaline < 60 or skulls.cooldown > 8) then
            ability = "Touch of Death"
        -- Finger of Death with 6+ necrosis stacks
        elseif finger.enabled and necrosisStacks >= 6 then
            ability = "Finger of Death"
        -- Volley of Souls with 5 soul stacks
        elseif volley.enabled and soulStacks >= 5 then
            ability = "Volley of Souls"
        -- Command Skeleton for extra damage
        elseif cmdSkel.ready then
            ability = "Command Skeleton Warrior"
        -- Necro auto as filler
        else
            ability = "Basic<nbsp>Attack"
        end
    else
        --[[
            NORMAL ROTATION (from PVME)
            Priority: 
            1. Living Death (if 100% adren and spend mode)
            2. Split Soul (before big damage)
            3. Death Skulls (60+ adren)
            4. Bloat (if not applied)
            5. Death Guard EOF (high burst)
            6. Omniguard spec (burst)
            7. Volley of Souls (4+ souls)
            8. Finger of Death (6+ necrosis)
            9. Touch of Death
            10. Command abilities
            11. Soul Sap (builder)
        ]]
        local livingDeathAb = getAbility("Living Death")
        local splitSoul = getAbility("Split Soul")
        local skulls = getAbility("Death Skulls")
        local bloat = getAbility("Bloat")
        local deathGuard = getAbility("Death Guard")
        local omniGuard = getAbility("Omni Guard")
        local weaponspec = getAbility("Weapon Special Attack")
        local essenceOfFinality = getAbility("Essence of Finality")
        local volley = getAbility("Volley of Souls")
        local finger = getAbility("Finger of Death")
        local touch = getAbility("Touch of Death")
        local cmdSkel = getAbility("Command Skeleton Warrior")
        local cmdGhost = getAbility("Command Vengeful Ghost")
        local cmdZombie = getAbility("Command Putrid Zombie")
        local conjure = getAbility("Conjure Undead Army")
        local lifeTransfer = getAbility("Life Transfer")
        local lordOfBones = getAbility("Invoke Lord of Bones")
        local soulSap = getAbility("Soul Sap")
        local resonance = getAbility("Resonance")
        local freedom = getAbility("Freedom")
        local invokeDeath = getAbility("Invoke Death")
        
        if soulSap.ready and SanctumMechanics.Kezalam.state.isHandlingScarabs then
            ability = "Soul Sap"
        elseif resonance.ready and SanctumMechanics.Kezalam.state.useResonance then
            SanctumMechanics.Kezalam.state.useResonance = false
            ability = "Resonance"
        elseif freedom.ready and SanctumMechanics.Kezalam.state.useFreedom then
            SanctumMechanics.Kezalam.state.useFreedom = false
            ability = "Freedom"
        -- Living Death if we have 100% and want to spend
        elseif spend and livingDeathAb.ready and adrenaline >= 100 and targetHealth > 50000 then
            ability = "Living Death"
        -- Split Soul before burst damage (if not active, 60s CD)
        elseif splitSoul.ready and not splitSoulActive and targetHealth > 30000 and (os.time() - lastSplitSoulTime >= 55) then
            ability = "Split Soul"
            lastSplitSoulTime = os.time()
        -- Death Skulls with 60+ adrenaline
        elseif skulls.ready and adrenaline >= 60 then
            ability = "Death Skulls"
        -- Bloat if target not bloated
        elseif bloat.ready and not checkBloated() and targetHealth > 30000 and (os.time() - lastBloatTime >= 18) then
            ability = "Bloat"
            lastBloatTime = os.time()
        -- Volley of Souls with 4+ stacks
        elseif volley.enabled and soulStacks >= 4 then
            ability = "Volley of Souls"
        -- Finger of Death with 6+ necrosis
        elseif finger.enabled and necrosisStacks >= 6 then
            ability = "Finger of Death"
        -- Weapon Special Attack (Omniguard spec) - matches Arch-Glacor pattern
        -- Check debuff 55480 (weapon spec cooldown) and necrosis stacks
        elseif API.GetABs_name1("Weapon Special Attack").enabled and not API.DeBuffbar_GetIDstatus(55480, false).found and necrosisStacks >= 4 then
            ability = "Weapon Special Attack"
            SanctumRotationManager.debugLog("[IMPROV]: Normal - Weapon Special Attack")
        -- Essence of Finality (Death Guard spec stored) - matches Arch-Glacor pattern
        -- Check debuff 55524 (EoF/Death Guard spec cooldown)
        elseif API.GetABs_name1("Essence of Finality").enabled and not API.DeBuffbar_GetIDstatus(55524, false).found and necrosisStacks >= 4 then
            ability = "Essence of Finality"
            SanctumRotationManager.debugLog("[IMPROV]: Normal - Essence of Finality")
        -- Touch of Death (strong basic)
        elseif touch.ready then
            ability = "Touch of Death"
        -- Command Skeleton Warrior
        elseif cmdSkel.ready then
            ability = "Command Skeleton Warrior"
        -- Command Vengeful Ghost
        elseif cmdGhost.ready then
            ability = "Command Vengeful Ghost"
        -- Conjure Army if not up
        elseif conjure.ready then
            ability = "Conjure Undead Army"
        -- Soul Sap as default builder
        elseif soulSap.ready then
            ability = "Soul Sap"
        else
            ability = "Basic<nbsp>Attack"
        end
    end
    
    SanctumRotationManager.debugLog("[IMPROV] Selected: " .. ability)
    return ability
end

---Execute the next step in the rotation
---@return boolean
function SanctumRotationManager:execute()
    if self.index > #self.rotation then
        SanctumRotationManager.debugLog("Rotation complete: " .. self.name)
        return false
    end
    
    if not self.timer:canTrigger() then
        return false
    end
    
    local step = self.rotation[self.index]
    SanctumRotationManager.debugLog("Step " .. self.index .. ": " .. step.label)
    
    step.type = step.type or "Ability"
    if step.useTicks == nil then
        step.useTicks = true
    end
    step.wait = step.wait or (step.useTicks and 3 or 1800)
    
    local shouldAdvance = true
    
    -- Check condition
    if step.condition and not step.condition() then
        SanctumRotationManager.debugLog("Condition not met for: " .. step.label)
        
        if step.replacementAction then
            if step.replacementAction() then
                SanctumRotationManager.debugLog("Replacement action executed")
            end
            self.timer:reset()
            self.timer.cooldown = step.replacementWait or step.wait
            self.timer.useTicks = step.useTicks
            self.timer:execute()
            self.index = self.index + 1
            return true
        elseif step.replacementLabel then
            if self:_useAbility(step.replacementLabel) then
                SanctumRotationManager.debugLog("Replacement ability: " .. step.replacementLabel)
            end
            self.timer:reset()
            self.timer.cooldown = step.replacementWait or step.wait
            self.timer.useTicks = step.useTicks
            self.timer:execute()
            self.index = self.index + 1
            return true
        else
            self.index = self.index + 1
            return false
        end
    end
    
    -- Execute based on type
    if step.type == "Ability" then
        if self:_useAbility(step.label) then
            SanctumRotationManager.debugLog("Ability cast: " .. step.label)
        end
    elseif step.type == "Inventory" then
        if self:_useInventory(step.label) then
            SanctumRotationManager.debugLog("Used inventory: " .. step.label)
        end
    elseif step.type == "Custom" and step.action then
        local success = step.action()
        if not success then
            shouldAdvance = false
        end
    elseif step.type == "Improvise" then
        local ability = self:_improvise(step.spend)
        self:_useAbility(ability)
    end
    
    -- Update timer
    self.timer:reset()
    self.timer.cooldown = step.wait
    self.timer.useTicks = step.useTicks
    self.timer:execute()
    
    -- Advance (except for Improvise which loops)
    if shouldAdvance and step.type ~= "Improvise" then
        self.index = self.index + 1
    end
    
    return true
end

---Check if rotation is complete
---@return boolean
function SanctumRotationManager:isComplete()
    return self.index > #self.rotation
end

---Reset the rotation
function SanctumRotationManager:reset()
    self.index = 1
    self.improvising = false
    self.trailing = false
    self.timer:reset()
end

---Get current step index
---@return number
function SanctumRotationManager:getCurrentIndex()
    return self.index
end

---Set step index
---@param index number
function SanctumRotationManager:setIndex(index)
    self.index = index
end

return SanctumRotationManager
