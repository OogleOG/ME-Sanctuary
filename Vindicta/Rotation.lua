--[[
    Vindicta Necromancy Rotation
    Based on PVME Entry Level rotation (15-16 second kills)
    
    PVME Rotation Flow:
    At Wars: Living Death → 100% Adrenaline → Conjure Army → Enter Portal
    Inside: Command Ghost → Invoke Death → Surge+Dive to spawn
    Fight: Split Soul → Command Skeleton → Bloat → Death Skulls → Touch of Death → Improvise
]]

local API = require("api")
local RotationManager = require("core.rotation_manager")
local Config = require("Vindicta.config")

local Rotation = {}

--============================================================================
-- ABILITY HELPER FUNCTIONS
--============================================================================

-- Check if ability exists and is off cooldown
local function isReady(abilityName)
    local ab = API.GetABs_name1(abilityName)
    if ab and ab.enabled and ab.cooldown_timer <= 1 then
        return true
    end
    return false
end

-- Get ability info
local function getAbility(abilityName)
    return API.GetABs_name1(abilityName)
end

--============================================================================
-- BUFF/STACK FUNCTIONS
--============================================================================

local function hasConjures()
    local skeleton = getAbility("Command Skeleton Warrior")
    local ghost = getAbility("Command Vengeful Ghost")
    local zombie = getAbility("Command Putrid Zombie")
    return (skeleton and skeleton.enabled) or (ghost and ghost.enabled) or (zombie and zombie.enabled)
end

local function getNecrosisStacks()
    local buff = API.Buffbar_GetIDstatus(Config.Buffs.necrosis, false)
    return buff.found and buff.text_int or 0
end

local function getSoulStacks()
    local buff = API.Buffbar_GetIDstatus(Config.Buffs.soulStacks, false)
    return buff.found and buff.text_int or 0
end

local function hasLivingDeath()
    local buff = API.Buffbar_GetIDstatus(Config.Buffs.livingDeath, false)
    return buff.found
end

local function hasSplitSoul()
    local buff = API.Buffbar_GetIDstatus(Config.Buffs.splitSoul, false)
    return buff.found
end

local function getAdrenaline()
    return API.GetAdrenalineFromInterface()
end

--============================================================================
-- OPENER ROTATION (Inside Instance - assumes Living Death already active)
-- PVME: Split Soul → Command Skeleton → Bloat → Death Skulls → Touch → Improvise
--============================================================================

Rotation.opener = RotationManager.new({
    name = "Vindicta Opener",
    rotation = {
        -- Split Soul first
        {
            label = "Split Soul",
            type = "Ability",
            wait = 3,
            condition = function() return not hasSplitSoul() and isReady("Split Soul") end
        },
        -- Command Skeleton
        {
            label = "Command Skeleton Warrior",
            type = "Ability",
            wait = 3,
            condition = function()
                local ab = getAbility("Command Skeleton Warrior")
                return ab and ab.enabled and ab.cooldown_timer <= 1
            end
        },
        -- Bloat
        {
            label = "Bloat",
            type = "Ability",
            wait = 3,
            condition = function() return isReady("Bloat") end
        },
        -- Death Skulls (main damage during Living Death)
        {
            label = "Death Skulls",
            type = "Ability",
            wait = 3,
            condition = function() return getAdrenaline() >= 60 and isReady("Death Skulls") end,
            replacementLabel = "Soul Sap"
        },
        -- Touch of Death
        {
            label = "Touch of Death",
            type = "Ability",
            wait = 3,
            condition = function() return isReady("Touch of Death") end
        },
        -- Finger of Death (high necrosis dump)
        {
            label = "Finger of Death",
            type = "Ability",
            wait = 3,
            condition = function() return getNecrosisStacks() >= 6 and isReady("Finger of Death") end,
            replacementLabel = "Soul Sap"
        },
        -- Command Ghost for debuff
        {
            label = "Command Vengeful Ghost",
            type = "Ability",
            wait = 3,
            condition = function()
                local ab = getAbility("Command Vengeful Ghost")
                return ab and ab.enabled and ab.cooldown_timer <= 1
            end
        },
        -- Volley if stacks
        {
            label = "Volley of Souls",
            type = "Ability",
            wait = 3,
            condition = function() return getSoulStacks() >= 5 and isReady("Volley of Souls") end,
            replacementLabel = "Soul Sap"
        }
    }
})

--============================================================================
-- MAIN ROTATION (Improvise - priority based ability selection)
--============================================================================

Rotation.main = RotationManager.new({
    name = "Vindicta Main",
    rotation = {
        {
            label = "Necromancy",
            type = "Improvise",
            style = "Necromancy",
            spend = false,
            wait = 3
        }
    }
})

--============================================================================
-- LIVING DEATH ROTATION (when Living Death buff is active)
-- Priority: Death Skulls > Finger of Death > Touch > Volley > Commands > Soul Sap
--============================================================================

Rotation.livingDeath = RotationManager.new({
    name = "Vindicta Living Death",
    rotation = {
        -- Death Skulls spam during Living Death
        {
            label = "Death Skulls",
            type = "Ability",
            wait = 3,
            condition = function() return getAdrenaline() >= 60 and isReady("Death Skulls") end,
            replacementLabel = "Finger of Death"
        },
        -- Finger of Death
        {
            label = "Finger of Death",
            type = "Ability",
            wait = 3,
            condition = function() return isReady("Finger of Death") end,
            replacementLabel = "Touch of Death"
        },
        -- Touch of Death
        {
            label = "Touch of Death",
            type = "Ability",
            wait = 3,
            condition = function() return isReady("Touch of Death") end
        },
        -- Volley if 4+ stacks
        {
            label = "Volley of Souls",
            type = "Ability",
            wait = 3,
            condition = function() return getSoulStacks() >= 4 and isReady("Volley of Souls") end,
            replacementLabel = "Soul Sap"
        },
        -- Command Skeleton
        {
            label = "Command Skeleton Warrior",
            type = "Ability",
            wait = 3,
            condition = function()
                local ab = getAbility("Command Skeleton Warrior")
                return ab and ab.enabled and ab.cooldown_timer <= 1
            end
        },
        -- Soul Sap filler
        {
            label = "Soul Sap",
            type = "Ability",
            wait = 3,
            condition = function() return isReady("Soul Sap") end
        },
        -- Command Ghost
        {
            label = "Command Vengeful Ghost",
            type = "Ability",
            wait = 3,
            condition = function()
                local ab = getAbility("Command Vengeful Ghost")
                return ab and ab.enabled and ab.cooldown_timer <= 1
            end
        },
        -- Another Death Skulls if available
        {
            label = "Death Skulls",
            type = "Ability",
            wait = 3,
            condition = function() return getAdrenaline() >= 60 and isReady("Death Skulls") end,
            replacementLabel = "Soul Sap"
        }
    }
})

--============================================================================
-- STATE
--============================================================================

Rotation.state = {
    openerComplete = false,
    inLivingDeath = false,
    currentRotation = "Opener"
}

--============================================================================
-- EXECUTE
--============================================================================

function Rotation.execute()
    -- Update Living Death status
    Rotation.state.inLivingDeath = hasLivingDeath()
    
    -- Opener phase (run once per kill)
    if not Rotation.state.openerComplete then
        Rotation.state.currentRotation = "Opener"
        local result = Rotation.opener:execute()
        if Rotation.opener.index > #Rotation.opener.rotation then
            Rotation.state.openerComplete = true
            Rotation.main:reset()
        end
        return result
    end
    
    -- Living Death phase (spam Death Skulls)
    if Rotation.state.inLivingDeath then
        Rotation.state.currentRotation = "Living Death"
        local result = Rotation.livingDeath:execute()
        if Rotation.livingDeath.index > #Rotation.livingDeath.rotation then
            Rotation.livingDeath:reset()
        end
        return result
    end
    
    -- Main rotation (Improvise)
    Rotation.state.currentRotation = "Main"
    return Rotation.main:execute()
end

--============================================================================
-- RESET
--============================================================================

function Rotation.reset()
    Rotation.opener:reset()
    Rotation.main:reset()
    Rotation.livingDeath:reset()
    Rotation.state.openerComplete = false
    Rotation.state.inLivingDeath = false
    Rotation.state.currentRotation = "Opener"
end

--============================================================================
-- GET CURRENT NAME
--============================================================================

function Rotation.getCurrentName()
    return Rotation.state.currentRotation
end

return Rotation