--- @module 'fleshhatcher.FleshHatcherGUI'
--- @version 1.0.0
--- ImGui-based GUI for Flesh-hatcher Mhekarnahz script

local API = require("api")

local FleshHatcherGUI = {}

------------------------------------------
--# STATE MANAGEMENT
------------------------------------------

FleshHatcherGUI.open = true
FleshHatcherGUI.started = false
FleshHatcherGUI.paused = false
FleshHatcherGUI.stopped = false
FleshHatcherGUI.cancelled = false
FleshHatcherGUI.warnings = {}
FleshHatcherGUI.selectConfigTab = true
FleshHatcherGUI.selectInfoTab = false
FleshHatcherGUI.selectWarningsTab = false

------------------------------------------
--# CONFIGURATION STATE
------------------------------------------

FleshHatcherGUI.config = {
    startAtWars = true,
    teleportBetweenKills = false,
    campBoss = false,
}

------------------------------------------
--# CRIMSON THEME COLORS
------------------------------------------

local CRIMSON = {
    dark   = { 0.09, 0.06, 0.06 },
    medium = { 0.25, 0.08, 0.10 },
    light  = { 0.45, 0.15, 0.18 },
    bright = { 0.65, 0.25, 0.28 },
    glow   = { 0.90, 0.40, 0.40 },
}

local STATE_COLORS = {
    ["Banking"]           = { 0.3, 0.8, 0.4 },
    ["Altar"]             = { 0.3, 0.8, 0.4 },
    ["Entering Portal"]   = { 0.5, 0.7, 0.9 },
    ["Entering Instance"] = { 0.5, 0.7, 0.9 },
    ["Navigating"]        = { 0.6, 0.6, 0.8 },
    ["Fighting"]          = { 1.0, 0.4, 0.3 },
    ["Looting"]           = { 0.9, 0.75, 0.3 },
    ["Teleporting"]       = { 0.6, 0.9, 1.0 },
    ["Returning"]         = { 0.5, 0.8, 0.6 },
    ["Drinking Prayer"]   = { 0.3, 0.6, 0.9 },
    ["Dead"]              = { 0.5, 0.5, 0.5 },
    ["Idle"]              = { 0.7, 0.7, 0.7 },
    ["Paused"]            = { 1.0, 0.8, 0.2 },
    ["Waiting"]           = { 0.7, 0.7, 0.7 },
}

------------------------------------------
--# CONFIG FILE MANAGEMENT
------------------------------------------

local CONFIG_DIR = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\configs\\"
local CONFIG_PATH = CONFIG_DIR .. "fleshhatcher.config.json"

local function loadConfigFromFile()
    local file = io.open(CONFIG_PATH, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or not data then return nil end
    return data
end

local function saveConfigToFile(cfg)
    local data = {
        StartAtWars = cfg.startAtWars,
        TeleportBetweenKills = cfg.teleportBetweenKills,
        CampBoss = cfg.campBoss,
    }
    local ok, json = pcall(API.JsonEncode, data)
    if not ok or not json then
        API.printlua("Failed to encode config JSON", 4, false)
        return
    end
    os.execute('mkdir "' .. CONFIG_DIR:gsub("/", "\\") .. '" 2>nul')
    local file = io.open(CONFIG_PATH, "w")
    if not file then
        API.printlua("Failed to open config file for writing", 4, false)
        return
    end
    file:write(json)
    file:close()
    API.printlua("Config saved", 0, false)
end

------------------------------------------
--# PUBLIC FUNCTIONS
------------------------------------------

function FleshHatcherGUI.reset()
    FleshHatcherGUI.open = true
    FleshHatcherGUI.started = false
    FleshHatcherGUI.paused = false
    FleshHatcherGUI.stopped = false
    FleshHatcherGUI.cancelled = false
    FleshHatcherGUI.warnings = {}
    FleshHatcherGUI.selectConfigTab = true
    FleshHatcherGUI.selectInfoTab = false
    FleshHatcherGUI.selectWarningsTab = false
end

function FleshHatcherGUI.loadConfig()
    local saved = loadConfigFromFile()
    if not saved then return end

    local c = FleshHatcherGUI.config
    if type(saved.StartAtWars) == "boolean" then c.startAtWars = saved.StartAtWars end
    if type(saved.TeleportBetweenKills) == "boolean" then c.teleportBetweenKills = saved.TeleportBetweenKills end
    if type(saved.CampBoss) == "boolean" then c.campBoss = saved.CampBoss end
end

function FleshHatcherGUI.getConfig()
    local c = FleshHatcherGUI.config
    return {
        startAtWars = c.startAtWars,
        teleportBetweenKills = c.teleportBetweenKills,
        campBoss = c.campBoss,
    }
end

function FleshHatcherGUI.addWarning(msg)
    FleshHatcherGUI.warnings[#FleshHatcherGUI.warnings + 1] = msg
    if #FleshHatcherGUI.warnings > 50 then
        table.remove(FleshHatcherGUI.warnings, 1)
    end
end

function FleshHatcherGUI.clearWarnings()
    FleshHatcherGUI.warnings = {}
end

function FleshHatcherGUI.isPaused()
    return FleshHatcherGUI.paused
end

function FleshHatcherGUI.isStopped()
    return FleshHatcherGUI.stopped
end

function FleshHatcherGUI.isCancelled()
    return FleshHatcherGUI.cancelled
end

------------------------------------------
--# HELPER FUNCTIONS
------------------------------------------

local function row(label, value, lr, lg, lb, vr, vg, vb)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, lr or 1.0, lg or 1.0, lb or 1.0, 1.0)
    ImGui.TextWrapped(label)
    ImGui.PopStyleColor(1)
    ImGui.TableNextColumn()
    if vr then
        ImGui.PushStyleColor(ImGuiCol.Text, vr, vg, vb, 1.0)
        ImGui.TextWrapped(value)
        ImGui.PopStyleColor(1)
    else
        ImGui.TextWrapped(value)
    end
end

local function progressBar(progress, height, text, r, g, b)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, r * 0.7, g * 0.7, b * 0.7, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, r * 0.2, g * 0.2, b * 0.2, 0.8)
    ImGui.ProgressBar(progress, -1, height, text)
    ImGui.PopStyleColor(2)
end

local function sectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, CRIMSON.glow[1], CRIMSON.glow[2], CRIMSON.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.65, 0.55, 0.55, 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function formatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    end
    return string.format("%d", n)
end

local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

------------------------------------------
--# TAB DRAWING FUNCTIONS
------------------------------------------

local function drawConfigTab(cfg, gui)
    if gui.started then
        -- Show summary and control buttons when running
        local statusText = gui.paused and "PAUSED" or "Running"
        local statusColor = gui.paused and { 1.0, 0.8, 0.2 } or { 0.4, 0.8, 0.4 }
        ImGui.PushStyleColor(ImGuiCol.Text, statusColor[1], statusColor[2], statusColor[3], 1.0)
        ImGui.TextWrapped(statusText)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
        ImGui.Separator()

        if ImGui.BeginTable("##cfgsummary", 2) then
            ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.4)
            ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.6)
            row("Start at War's", cfg.startAtWars and "Yes" or "No")
            row("Teleport Between", cfg.teleportBetweenKills and "Yes" or "No")
            row("Camp Boss", cfg.campBoss and "Yes" or "No")
            ImGui.EndTable()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Pause/Resume button
        if gui.paused then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.5, 0.2, 0.2)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.25, 0.65, 0.25, 0.35)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.75, 0.15, 0.5)
            if ImGui.Button("Resume Script##resume", -1, 28) then
                gui.paused = false
            end
            ImGui.PopStyleColor(3)
        else
            ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 0.4, 0.4, 0.2)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.4, 0.4, 0.35)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.5, 0.5)
            if ImGui.Button("Pause Script##pause", -1, 28) then
                gui.paused = true
            end
            ImGui.PopStyleColor(3)
        end

        ImGui.Spacing()

        -- Stop button
        ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.15, 0.15, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.2, 0.2, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.7, 0.25, 0.25, 1.0)
        if ImGui.Button("Stop Script##stop", -1, 28) then
            gui.stopped = true
        end
        ImGui.PopStyleColor(3)
        return
    end

    -- Pre-start configuration
    ImGui.PushItemWidth(-1)

    -- === GENERAL SETTINGS ===
    sectionHeader("General Settings")
    flavorText("Configure your kill loop preferences.")
    ImGui.Spacing()

    local warsChanged, warsVal = ImGui.Checkbox("Start at War's Retreat##startwars", cfg.startAtWars)
    if warsChanged then cfg.startAtWars = warsVal end

    local teleChanged, teleVal = ImGui.Checkbox("Teleport Between Kills##telebetween", cfg.teleportBetweenKills)
    if teleChanged then cfg.teleportBetweenKills = teleVal end

    local campChanged, campVal = ImGui.Checkbox("Camp Boss (don't bank between kills)##campboss", cfg.campBoss)
    if campChanged then cfg.campBoss = campVal end

    ImGui.PopItemWidth()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Start button (crimson themed)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.15, 0.15, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.65, 0.2, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.75, 0.25, 0.25, 1.0)
    if ImGui.Button("Start Flesh-hatcher##start", -1, 32) then
        saveConfigToFile(gui.config)
        gui.started = true
    end
    ImGui.PopStyleColor(3)

    ImGui.Spacing()

    -- Cancel button
    ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 0.4, 0.4, 0.2)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.4, 0.4, 0.35)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.5, 0.5)
    if ImGui.Button("Cancel##cancel", -1, 28) then
        gui.cancelled = true
    end
    ImGui.PopStyleColor(3)
end

local function drawInfoTab(data)
    -- State display
    local stateText = data.state or "Idle"
    if FleshHatcherGUI.paused then stateText = "Paused" end
    local sc = STATE_COLORS[stateText] or { 0.7, 0.7, 0.7 }
    ImGui.PushStyleColor(ImGuiCol.Text, sc[1], sc[2], sc[3], 1.0)
    ImGui.TextWrapped(stateText)
    ImGui.PopStyleColor(1)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Player HP bar (LIVE)
    local hpPct = API.GetHPrecent() / 100
    local hr, hg, hb = 1.0, 0.3, 0.3
    if hpPct > 0.6 then hr, hg, hb = 0.3, 0.85, 0.45
    elseif hpPct > 0.3 then hr, hg, hb = 1.0, 0.75, 0.2 end
    progressBar(hpPct, 20, string.format("HP: %d%%", API.GetHPrecent()), hr, hg, hb)

    ImGui.Spacing()

    -- Player Prayer bar (LIVE)
    local prayPct = API.GetPrayPrecent() / 100
    progressBar(prayPct, 20, string.format("Prayer: %d%%", API.GetPrayPrecent()), 0.3, 0.6, 0.9)

    ImGui.Spacing()

    -- Adrenaline bar (LIVE)
    local adrenPct = API.GetAddreline_() / 100
    progressBar(adrenPct, 20, string.format("Adrenaline: %d%%", API.GetAddreline_()), 0.9, 0.7, 0.2)

    -- Boss health bar (LIVE - only when boss data available)
    if data.bossHealth and data.bossMaxHealth and data.bossHealth > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        local pct = math.max(0, math.min(1, data.bossHealth / data.bossMaxHealth))
        local healthPercent = (data.bossHealth / data.bossMaxHealth) * 100
        local healthText = string.format("Mhekarnahz: %s / %s  (%.1f%%)",
            formatNumber(data.bossHealth),
            formatNumber(data.bossMaxHealth),
            healthPercent)
        progressBar(pct, 28, healthText, CRIMSON.glow[1], CRIMSON.glow[2], CRIMSON.glow[3])
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Stats table (LIVE)
    if ImGui.BeginTable("##stats", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.4)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.6)

        row("Kills", tostring(data.kills or 0))
        row("Deaths", tostring(data.deaths or 0))

        -- Kills per hour (LIVE calculated)
        local runtime = data.runtime or 0
        local kph = 0
        if runtime > 0 and (data.kills or 0) > 0 then
            kph = math.floor(((data.kills or 0) / runtime) * 3600)
        end
        row("Kills/Hour", tostring(kph))

        -- Current kill timer (LIVE)
        if data.killStartTime and data.killStartTime > 0 then
            local elapsed = os.time() - data.killStartTime
            row("Kill Timer", formatTime(elapsed), 1.0, 1.0, 1.0, 1.0, 0.8, 0.3)
        end

        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Kill times
    if ImGui.BeginTable("##killtimes", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.4)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.6)

        row("Fastest Kill", data.fastestKill or "--", 1.0, 1.0, 1.0, 0.3, 0.85, 0.45)
        row("Slowest Kill", data.slowestKill or "--", 1.0, 1.0, 1.0, 1.0, 0.5, 0.3)
        row("Average Kill", data.averageKill or "--")

        ImGui.EndTable()
    end

    -- Recent kills
    if data.killTimes and #data.killTimes > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.BeginTable("##recentkills", 2) then
            ImGui.TableSetupColumn("kc", ImGuiTableColumnFlags.WidthStretch, 0.3)
            ImGui.TableSetupColumn("killtime", ImGuiTableColumnFlags.WidthStretch, 0.7)

            sectionHeader("Recent Kills")
            row("Kill", "Duration", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)

            for i = math.max(1, #data.killTimes - 4), #data.killTimes do
                local killTime = data.killTimes[i]
                row(string.format("[%d]", i), formatTime(killTime), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
            end

            ImGui.EndTable()
        end
    end
end

local function drawWarningsTab(gui)
    if #gui.warnings == 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.65, 1.0)
        ImGui.TextWrapped("No warnings.")
        ImGui.PopStyleColor(1)
        return
    end

    for _, warning in ipairs(gui.warnings) do
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.75, 0.2, 1.0)
        ImGui.TextWrapped("! " .. warning)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.45, 0.1, 0.8)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.65, 0.55, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.8, 0.7, 0.1, 1.0)
    if ImGui.Button("Dismiss Warnings##clear", -1, 25) then
        gui.warnings = {}
    end
    ImGui.PopStyleColor(3)
end

local function drawContent(data, gui)
    if ImGui.BeginTabBar("##maintabs", 0) then
        local configFlags = gui.selectConfigTab and ImGuiTabItemFlags.SetSelected or 0
        gui.selectConfigTab = false
        if ImGui.BeginTabItem("Config###config", nil, configFlags) then
            ImGui.Spacing()
            drawConfigTab(gui.config, gui)
            ImGui.EndTabItem()
        end

        if gui.started then
            local infoFlags = gui.selectInfoTab and ImGuiTabItemFlags.SetSelected or 0
            gui.selectInfoTab = false
            if ImGui.BeginTabItem("Info###info", nil, infoFlags) then
                ImGui.Spacing()
                drawInfoTab(data)
                ImGui.EndTabItem()
            end
        end

        if #gui.warnings > 0 then
            local warningLabel = "Warnings (" .. #gui.warnings .. ")###warnings"
            local warnFlags = gui.selectWarningsTab and ImGuiTabItemFlags.SetSelected or 0
            if ImGui.BeginTabItem(warningLabel, nil, warnFlags) then
                gui.selectWarningsTab = false
                ImGui.Spacing()
                drawWarningsTab(gui)
                ImGui.EndTabItem()
            end
        end

        ImGui.EndTabBar()
    end
end

------------------------------------------
--# MAIN DRAW FUNCTION
------------------------------------------

function FleshHatcherGUI.draw(data)
    ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    -- Crimson Theme
    ImGui.PushStyleColor(ImGuiCol.WindowBg, CRIMSON.dark[1], CRIMSON.dark[2], CRIMSON.dark[3], 0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, CRIMSON.medium[1] * 0.6, CRIMSON.medium[2] * 0.6, CRIMSON.medium[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, CRIMSON.medium[1], CRIMSON.medium[2], CRIMSON.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, CRIMSON.light[1], CRIMSON.light[2], CRIMSON.light[3], 0.4)
    ImGui.PushStyleColor(ImGuiCol.Tab, CRIMSON.medium[1] * 0.7, CRIMSON.medium[2] * 0.7, CRIMSON.medium[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, CRIMSON.light[1], CRIMSON.light[2], CRIMSON.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, CRIMSON.bright[1] * 0.7, CRIMSON.bright[2] * 0.7, CRIMSON.bright[3] * 0.7, 1.0)
    -- Frame/Input styling
    ImGui.PushStyleColor(ImGuiCol.FrameBg, CRIMSON.medium[1] * 0.5, CRIMSON.medium[2] * 0.5, CRIMSON.medium[3] * 0.5, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, CRIMSON.light[1] * 0.7, CRIMSON.light[2] * 0.7, CRIMSON.light[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, CRIMSON.bright[1] * 0.5, CRIMSON.bright[2] * 0.5, CRIMSON.bright[3] * 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, CRIMSON.bright[1], CRIMSON.bright[2], CRIMSON.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, CRIMSON.glow[1], CRIMSON.glow[2], CRIMSON.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, CRIMSON.glow[1], CRIMSON.glow[2], CRIMSON.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, CRIMSON.medium[1], CRIMSON.medium[2], CRIMSON.medium[3], 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, CRIMSON.light[1], CRIMSON.light[2], CRIMSON.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, CRIMSON.bright[1], CRIMSON.bright[2], CRIMSON.bright[3], 1.0)
    -- White text
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, 4)

    local titleText = "Flesh-hatcher - " .. API.ScriptRuntimeString() .. "###FleshHatcher"
    local visible = ImGui.Begin(titleText, 0)

    if visible then
        local ok, err = pcall(drawContent, data, FleshHatcherGUI)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Error: " .. tostring(err))
        end
    end

    ImGui.PopStyleVar(5)
    ImGui.PopStyleColor(17)
    ImGui.End()

    return FleshHatcherGUI.open
end

return FleshHatcherGUI
