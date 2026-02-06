--[[
    SanctumTimer.lua
    Based on AG's timer.lua by Sonson
    Manages actions with cooldowns without using sleep
]]

local API = require("api")

---@class SanctumTimer
---@field name string
---@field cooldown integer
---@field useTicks boolean
---@field condition fun():boolean
---@field action function
---@field lastTriggered integer
---@field lastTime number
local SanctumTimer = {}
SanctumTimer.__index = SanctumTimer

local debug = false

function SanctumTimer:_debugLog(message)
    if debug then
        print("[TIMER]: " .. self.name .. " | " .. message)
    end
end

---Initialize a new timer
---@param config table
---@return SanctumTimer
function SanctumTimer.new(config)
    local self = setmetatable({}, SanctumTimer)
    
    if not config then
        print("[TIMER]: No config found when initializing.")
        API.Write_LoopyLoop(false)
        return self
    end
    
    self.name = config.name or "Unnamed Timer"
    self.cooldown = config.cooldown or 0
    self.useTicks = true
    if config.useTicks ~= nil then
        self.useTicks = config.useTicks
    end
    self.condition = config.condition or function() return true end
    self.action = config.action or function() return true end
    self.lastTriggered = 0
    self.lastTime = 0
    
    return self
end

---Check if timer can be triggered
---@param ... any arguments to pass to condition
---@return boolean
function SanctumTimer:canTrigger(...)
    local currentTick = API.Get_tick()
    local currentTime = os.clock() * 1000
    local delta = self.useTicks and (currentTick - self.lastTriggered) or (currentTime - self.lastTime)
    local args = {...}
    
    if #args == 0 then
        return (delta >= self.cooldown) and self.condition()
    end
    
    return (delta >= self.cooldown) and self.condition(table.unpack(args))
end

---Execute the action if timer can be triggered
---@param ... any arguments to pass to action
---@return boolean
function SanctumTimer:execute(...)
    local args = {...}
    
    if self:canTrigger(table.unpack(args)) then
        local success
        if #args == 0 then
            success = self.action()
        else
            success = self.action(table.unpack(args))
        end
        
        if success then
            self:_debugLog("Action successful")
            self.lastTriggered = API.Get_tick()
            self.lastTime = os.clock() * 1000
            return true
        end
    end
    
    return false
end

---Reset the timer
function SanctumTimer:reset()
    self.lastTriggered = 0
    self.lastTime = 0
end

return SanctumTimer