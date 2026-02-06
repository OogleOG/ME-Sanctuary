--- @module 'sanctum.SanctumGUI'
--- @version 1.0.0

local API = require("api")

local SanctumGUI = {}

SanctumGUI.open = true
SanctumGUI.started = false
SanctumGUI.paused = false
SanctumGUI.stopped = false
SanctumGUI.cancelled = false
SanctumGUI.warnings = {}
SanctumGUI.selectConfigTab = true
SanctumGUI.selectInfoTab = false
SanctumGUI.selectWarningsTab = false

SanctumGUI.config = {
    -- Health thresholds (raw HP values)
    healthFood = 6000,
    healthBrew = 4000,
    healthCombo = 3500,
    -- Prayer threshold (percentage)
    prayerRestore = 30,
    -- War's Retreat options
    startWithFullAdrenaline = true,
    -- Debug options
    debugMain = true,
    debugConsumables = false,
    debugRotation = false,
    debugMechanics = false,
    debugPrayer = false,
}

local TEAL = {
    dark   = { 0.06, 0.08, 0.10 },
    medium = { 0.08, 0.18, 0.25 },
    light  = { 0.15, 0.35, 0.45 },
    bright = { 0.25, 0.55, 0.65 },
    glow   = { 0.40, 0.80, 0.90 },
}

local STATE_COLORS = {
    ["War's Retreat"]     = { 0.3, 0.8, 0.4 },
    ["Banking"]           = { 0.3, 0.8, 0.4 },
    ["Altar"]             = { 0.3, 0.8, 0.4 },
    ["Bonfire"]           = { 0.3, 0.8, 0.4 },
    ["Adrenaline"]        = { 0.3, 0.8, 0.4 },
    ["Entering Portal"]   = { 0.5, 0.7, 0.9 },
    ["Entering Instance"] = { 0.5, 0.7, 0.9 },
    ["Vermyx"]            = { 1.0, 0.85, 0.2 },
    ["Kezalam"]           = { 1.0, 0.55, 0.2 },
    ["Nakatra"]           = { 1.0, 0.3, 0.3 },
    ["Transition"]        = { 0.6, 0.6, 0.8 },
    ["Looting"]           = { 0.4, 0.85, 0.9 },
    ["Teleporting"]       = { 0.6, 0.9, 1.0 },
    ["Dead"]              = { 0.5, 0.5, 0.5 },
    ["Death Recovery"]    = { 0.5, 0.5, 0.5 },
    ["Idle"]              = { 0.7, 0.7, 0.7 },
    ["Paused"]            = { 1.0, 0.8, 0.2 },
}

local HEALTH_COLORS = {
    high   = { 0.3, 0.85, 0.45 },
    medium = { 1.0, 0.75, 0.2 },
    low    = { 1.0, 0.3, 0.3 },
}

local CONFIG_DIR = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\configs\\"
local CONFIG_PATH = CONFIG_DIR .. "sanctum.config.json"

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
        HealthFood = cfg.healthFood,
        HealthBrew = cfg.healthBrew,
        HealthCombo = cfg.healthCombo,
        PrayerRestore = cfg.prayerRestore,
        StartWithFullAdrenaline = cfg.startWithFullAdrenaline,
        DebugMain = cfg.debugMain,
        DebugConsumables = cfg.debugConsumables,
        DebugRotation = cfg.debugRotation,
        DebugMechanics = cfg.debugMechanics,
        DebugPrayer = cfg.debugPrayer,
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

function SanctumGUI.reset()
    SanctumGUI.open = true
    SanctumGUI.started = false
    SanctumGUI.paused = false
    SanctumGUI.stopped = false
    SanctumGUI.cancelled = false
    SanctumGUI.warnings = {}
    SanctumGUI.selectConfigTab = true
    SanctumGUI.selectInfoTab = false
    SanctumGUI.selectWarningsTab = false
end

function SanctumGUI.loadConfig()
    local saved = loadConfigFromFile()
    if not saved then return end

    local c = SanctumGUI.config
    if type(saved.HealthFood) == "number" then c.healthFood = saved.HealthFood end
    if type(saved.HealthBrew) == "number" then c.healthBrew = saved.HealthBrew end
    if type(saved.HealthCombo) == "number" then c.healthCombo = saved.HealthCombo end
    if type(saved.PrayerRestore) == "number" then c.prayerRestore = saved.PrayerRestore end
    if type(saved.StartWithFullAdrenaline) == "boolean" then c.startWithFullAdrenaline = saved.StartWithFullAdrenaline end
    if type(saved.DebugMain) == "boolean" then c.debugMain = saved.DebugMain end
    if type(saved.DebugConsumables) == "boolean" then c.debugConsumables = saved.DebugConsumables end
    if type(saved.DebugRotation) == "boolean" then c.debugRotation = saved.DebugRotation end
    if type(saved.DebugMechanics) == "boolean" then c.debugMechanics = saved.DebugMechanics end
    if type(saved.DebugPrayer) == "boolean" then c.debugPrayer = saved.DebugPrayer end
end

function SanctumGUI.getConfig()
    local c = SanctumGUI.config
    return {
        healthFood = c.healthFood,
        healthBrew = c.healthBrew,
        healthCombo = c.healthCombo,
        prayerRestore = c.prayerRestore,
        startWithFullAdrenaline = c.startWithFullAdrenaline,
        debugMain = c.debugMain,
        debugConsumables = c.debugConsumables,
        debugRotation = c.debugRotation,
        debugMechanics = c.debugMechanics,
        debugPrayer = c.debugPrayer,
    }
end

function SanctumGUI.addWarning(msg)
    SanctumGUI.warnings[#SanctumGUI.warnings + 1] = msg
    if #SanctumGUI.warnings > 50 then
        table.remove(SanctumGUI.warnings, 1)
    end
end

function SanctumGUI.clearWarnings()
    SanctumGUI.warnings = {}
end

function SanctumGUI.isPaused()
    return SanctumGUI.paused
end

function SanctumGUI.isStopped()
    return SanctumGUI.stopped
end

function SanctumGUI.isCancelled()
    return SanctumGUI.cancelled
end

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

local function label(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.9, 0.9, 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function sectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, TEAL.glow[1], TEAL.glow[2], TEAL.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.55, 0.65, 0.70, 1.0)
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

local function getHealthColor(pct)
    return TEAL.glow
end

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
            row("Food Threshold", tostring(cfg.healthFood) .. " HP")
            row("Brew Threshold", tostring(cfg.healthBrew) .. " HP")
            row("Prayer Restore", tostring(cfg.prayerRestore) .. "%")
            row("Full Adrenaline", cfg.startWithFullAdrenaline and "Yes" or "No")
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

    -- === HEALTH THRESHOLDS ===
    sectionHeader("Health Thresholds")
    flavorText("HP values at which to eat food and use healing items.")
    ImGui.Spacing()

    label("Food Threshold (HP)")
    local foodChanged, foodVal = ImGui.SliderInt("##healthfood", cfg.healthFood, 0, 15000, "%d")
    if foodChanged then cfg.healthFood = foodVal end

    label("Brew Threshold (HP)")
    local brewChanged, brewVal = ImGui.SliderInt("##healthbrew", cfg.healthBrew, 0, 15000, "%d")
    if brewChanged then cfg.healthBrew = brewVal end

    label("Combo Eat Threshold (HP)")
    local comboChanged, comboVal = ImGui.SliderInt("##healthcombo", cfg.healthCombo, 0, 15000, "%d")
    if comboChanged then cfg.healthCombo = comboVal end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === PRAYER THRESHOLDS ===
    sectionHeader("Prayer Threshold")
    flavorText("When to restore prayer points.")
    ImGui.Spacing()

    label("Prayer Restore (%)")
    local prayChanged, prayVal = ImGui.SliderInt("##prayerrestore", cfg.prayerRestore, 0, 100, "%d%%")
    if prayChanged then cfg.prayerRestore = prayVal end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === WAR'S RETREAT OPTIONS ===
    sectionHeader("War's Retreat")
    flavorText("Pre-fight preparation options.")
    ImGui.Spacing()

    local adrenChanged, adrenVal = ImGui.Checkbox("Start with Full Adrenaline##fulladren", cfg.startWithFullAdrenaline)
    if adrenChanged then cfg.startWithFullAdrenaline = adrenVal end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === DEBUG OPTIONS ===
    sectionHeader("Debug Options")
    flavorText("Enable logging for troubleshooting.")
    ImGui.Spacing()

    local dbgMainChanged, dbgMainVal = ImGui.Checkbox("Main Script##debugmain", cfg.debugMain)
    if dbgMainChanged then cfg.debugMain = dbgMainVal end

    local dbgConsChanged, dbgConsVal = ImGui.Checkbox("Consumables##debugconsumables", cfg.debugConsumables)
    if dbgConsChanged then cfg.debugConsumables = dbgConsVal end

    local dbgRotChanged, dbgRotVal = ImGui.Checkbox("Rotation Manager##debugrotation", cfg.debugRotation)
    if dbgRotChanged then cfg.debugRotation = dbgRotVal end

    local dbgMechChanged, dbgMechVal = ImGui.Checkbox("Mechanics##debugmechanics", cfg.debugMechanics)
    if dbgMechChanged then cfg.debugMechanics = dbgMechVal end

    local dbgPrayerChanged, dbgPrayerVal = ImGui.Checkbox("Prayer Manager##debugprayer", cfg.debugPrayer)
    if dbgPrayerChanged then cfg.debugPrayer = dbgPrayerVal end

    ImGui.PopItemWidth()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Start button (teal themed)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.15, 0.45, 0.55, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.2, 0.55, 0.65, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.65, 0.75, 1.0)
    if ImGui.Button("Start Sanctum HM##start", -1, 32) then
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
    if SanctumGUI.paused then stateText = "Paused" end
    local sc = STATE_COLORS[stateText] or { 0.7, 0.7, 0.7 }
    ImGui.PushStyleColor(ImGuiCol.Text, sc[1], sc[2], sc[3], 1.0)
    ImGui.TextWrapped(stateText)
    ImGui.PopStyleColor(1)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Boss health bar
    if data.bossHealth and data.bossMaxHealth and data.bossHealth > 0 then
        local pct = math.max(0, math.min(1, data.bossHealth / data.bossMaxHealth))
        local hc = getHealthColor(pct)
        local bossName = data.currentBoss or "Boss"
        local healthPercent = (data.bossHealth / data.bossMaxHealth) * 100
        local healthText = string.format("%s: %s / %s  (%.2f%%)",
            bossName,
            formatNumber(data.bossHealth),
            formatNumber(data.bossMaxHealth),
            healthPercent)
        progressBar(pct, 28, healthText, hc[1], hc[2], hc[3])

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

    -- Info table
    if ImGui.BeginTable("##info", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.3)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.7)

        row("Location", data.location or "Unknown")
        row("Status", data.status or "Idle")
        if data.currentBoss then
            row("Current Boss", data.currentBoss)
        end
        if data.killTimer then
            row("Kill Timer", data.killTimer)
        end

        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Metrics section
    if ImGui.BeginTable("##metrics", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.3)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.7)

        row("Runs", string.format("%d (%s/hr)", data.runsCompleted or 0, data.runsPerHour or "0"))
        if data.gp then
            row("GP", string.format("%s (%s/hr)", formatNumber(data.gp or 0), formatNumber(data.gpPerHour or 0)))
        end

        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Kill times
    if ImGui.BeginTable("##killtimes", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.3)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.7)

        row("Fastest Run", data.fastestRun or "--", 1.0, 1.0, 1.0, 0.3, 0.85, 0.45)
        row("Slowest Run", data.slowestRun or "--", 1.0, 1.0, 1.0, 1.0, 0.5, 0.3)
        row("Average Run", data.averageRun or "--")

        ImGui.EndTable()
    end

    -- Recent runs
    if data.recentRuns and #data.recentRuns > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.BeginTable("##recentruns", 2) then
            ImGui.TableSetupColumn("run", ImGuiTableColumnFlags.WidthStretch, 0.3)
            ImGui.TableSetupColumn("duration", ImGuiTableColumnFlags.WidthStretch, 0.7)

            label("Recent Runs")

            row("Run", "Duration", 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)

            for i = math.max(1, #data.recentRuns - 4), #data.recentRuns do
                local run = data.recentRuns[i]
                row(string.format("[%s]", i), run.duration or "--", 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
            end

            ImGui.EndTable()
        end
    end

    -- Unique drops
    if data.uniquesLooted and #data.uniquesLooted > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Text, TEAL.glow[1], TEAL.glow[2], TEAL.glow[3], 1.0)
        ImGui.TextWrapped("Unique Drops")
        ImGui.PopStyleColor(1)

        for _, drop in ipairs(data.uniquesLooted) do
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
            ImGui.TextWrapped(drop[1])
            ImGui.PopStyleColor(1)
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

function SanctumGUI.draw(data)
    ImGui.SetNextWindowSize(360, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    -- Teal/Cyan Sanctum Theme
    ImGui.PushStyleColor(ImGuiCol.WindowBg, TEAL.dark[1], TEAL.dark[2], TEAL.dark[3], 0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, TEAL.medium[1] * 0.6, TEAL.medium[2] * 0.6, TEAL.medium[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, TEAL.medium[1], TEAL.medium[2], TEAL.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, TEAL.light[1], TEAL.light[2], TEAL.light[3], 0.4)
    ImGui.PushStyleColor(ImGuiCol.Tab, TEAL.medium[1] * 0.7, TEAL.medium[2] * 0.7, TEAL.medium[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, TEAL.light[1], TEAL.light[2], TEAL.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, TEAL.bright[1] * 0.7, TEAL.bright[2] * 0.7, TEAL.bright[3] * 0.7, 1.0)
    -- Frame/Input styling
    ImGui.PushStyleColor(ImGuiCol.FrameBg, TEAL.medium[1] * 0.5, TEAL.medium[2] * 0.5, TEAL.medium[3] * 0.5, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, TEAL.light[1] * 0.7, TEAL.light[2] * 0.7, TEAL.light[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, TEAL.bright[1] * 0.5, TEAL.bright[2] * 0.5, TEAL.bright[3] * 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, TEAL.bright[1], TEAL.bright[2], TEAL.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, TEAL.glow[1], TEAL.glow[2], TEAL.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, TEAL.glow[1], TEAL.glow[2], TEAL.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, TEAL.medium[1], TEAL.medium[2], TEAL.medium[3], 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, TEAL.light[1], TEAL.light[2], TEAL.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, TEAL.bright[1], TEAL.bright[2], TEAL.bright[3], 1.0)
    -- White text
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, 4)

    local titleText = "Sanctum HM - " .. API.ScriptRuntimeString() .. "###SanctumHM"
    local visible = ImGui.Begin(titleText, 0)

    if visible then
        local ok, err = pcall(drawContent, data, SanctumGUI)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Error: " .. tostring(err))
        end
    end

    ImGui.PopStyleVar(5)
    ImGui.PopStyleColor(17)
    ImGui.End()

    return SanctumGUI.open
end

return SanctumGUI
