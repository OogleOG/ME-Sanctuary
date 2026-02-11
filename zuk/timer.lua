API = require("api")
---@class Timer
---@field timers table<string, number>
---@field tasks table<string, {executeTime: number, func: function}>
local Timer = {
  timers = {},
  tasks = {},
}

function Timer:getTimerCount()
  -- loop through all the timers and count how many there are
  local count = 0
  for _, _ in pairs(self.timers) do
    count = count + 1
  end
  return count
end

function Timer:shouldRun(name)
  if not self.timers[name] then
    return true
  end
  return os.clock() >= self.timers[name]
end

--- should run if none of the timers that start with the given name are shouldRun
function Timer:shouldRunStartsWith(name)
  for timerName, _ in pairs(self.timers) do
    if string.find(timerName, name) and not self:shouldRun(timerName) then
      return false
    end
  end
  return true
end

function Timer:shouldRunWithBaseDelay(name, baseDelay)
  if not self.timers[name] then
    self:createSleep(name, baseDelay)
    return false
  end
  return os.clock() >= self.timers[name]
end

function Timer:shouldRunWithRandomBaseDelay(name, minMs, maxMs)
  if not self.timers[name] then
    self:randomThreadedSleep(name, minMs, maxMs)
    return false
  end
  return os.clock() >= self.timers[name]
end

function Timer:randomThreadedSleep(name, minMs, maxMs)
  local randomDuration = math.random(minMs, maxMs)
  return self:createSleep(name, randomDuration)
end

function Timer:createSleep(name, duration)
  duration = duration / 1000
  local time = os.clock() + duration
  self.timers[name] = time
  return time
end

--- Schedule a task to be executed after a specified delay
---@param name string: The name of the task
---@param delay number: The delay in milliseconds
---@param func function: The function to execute
function Timer:scheduleTask(name, delay, func)
  local executeTime = os.clock() + (delay / 1000)
  self.tasks[name] = { executeTime = executeTime, func = func }
end

-- - Run scheduled tasks that are due
function Timer:runScheduledTasks()
  local currentTime = os.clock()
  local toRemove = {}
  for name, task in pairs(self.tasks) do
    if currentTime >= task.executeTime then
      task.func()
      table.insert(toRemove, name)
    end
  end
  for _, name in ipairs(toRemove) do
    self.tasks[name] = nil
  end
end

return Timer
