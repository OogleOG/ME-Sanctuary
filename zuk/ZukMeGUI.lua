--- @module 'zuk.ZukMeGUI'
--- @version 1.0.0
--- ImGui-based GUI for ZukMe script

local API = require("api")

local ZukMeGUI = {}

------------------------------------------
--# STATE MANAGEMENT
------------------------------------------

ZukMeGUI.open = true
ZukMeGUI.started = false
ZukMeGUI.paused = false
ZukMeGUI.stopped = false
ZukMeGUI.cancelled = false
ZukMeGUI.warnings = {}
ZukMeGUI.selectConfigTab = true
ZukMeGUI.selectInfoTab = false
ZukMeGUI.selectWarningsTab = false

------------------------------------------
--# CONFIGURATION STATE
------------------------------------------

ZukMeGUI.config = {
    hasZukCape = false,
    useBook = true,
    useExcal = true,
    useElvenShard = true,
    usePoison = true,
    ringSwitch = "Occultist's ring",
    adrenPotName = "Super adrenaline",
    foodName = "blubber jellyfish",
    foodPotName = "Guthix rest",
    restoreName = "Super restore",
    overloadName = "Elder overload",
    brewName = "Saradomin brew",
    necroPrayerIndex = 0,    -- 0 = Sorrow, 1 = Ruination
    bookIndex = 0,           -- 0 = Wen, 1 = Jas, 2 = Ful
}

-- Dropdown option lists
local NECRO_PRAYER_OPTIONS = { "Sorrow", "Ruination" }
local BOOK_OPTIONS = { "Scripture of Wen", "Scripture of Jas", "Scripture of Ful" }

------------------------------------------
--# INFERNO THEME COLORS
------------------------------------------

local INFERNO = {
    dark   = { 0.08, 0.05, 0.02 },
    medium = { 0.30, 0.12, 0.04 },
    light  = { 0.55, 0.22, 0.08 },
    bright = { 0.75, 0.35, 0.10 },
    glow   = { 1.00, 0.55, 0.15 },
}

local STATE_COLORS = {
    ["Fighting"]          = { 1.0, 0.4, 0.3 },
    ["Kill Complete"]     = { 0.3, 0.85, 0.45 },
    ["Teleporting"]       = { 0.6, 0.9, 1.0 },
    ["At War's"]          = { 0.3, 0.8, 0.4 },
    ["Entering Fight"]    = { 0.5, 0.7, 0.9 },
    ["Dead"]              = { 0.5, 0.5, 0.5 },
    ["Idle"]              = { 0.7, 0.7, 0.7 },
    ["Paused"]            = { 1.0, 0.8, 0.2 },
}

------------------------------------------
--# CONFIG FILE MANAGEMENT
------------------------------------------

local CONFIG_DIR = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\configs\\"
local CONFIG_PATH = CONFIG_DIR .. "zukme.config.json"

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
        HasZukCape = cfg.hasZukCape,
        UseBook = cfg.useBook,
        UseExcal = cfg.useExcal,
        UseElvenShard = cfg.useElvenShard,
        UsePoison = cfg.usePoison,
        RingSwitch = cfg.ringSwitch,
        AdrenPotName = cfg.adrenPotName,
        FoodName = cfg.foodName,
        FoodPotName = cfg.foodPotName,
        RestoreName = cfg.restoreName,
        OverloadName = cfg.overloadName,
        BrewName = cfg.brewName,
        NecroPrayerIndex = cfg.necroPrayerIndex,
        BookIndex = cfg.bookIndex,
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
    API.printlua("ZukMe config saved", 0, false)
end

------------------------------------------
--# PUBLIC FUNCTIONS
------------------------------------------

function ZukMeGUI.reset()
    ZukMeGUI.open = true
    ZukMeGUI.started = false
    ZukMeGUI.paused = false
    ZukMeGUI.stopped = false
    ZukMeGUI.cancelled = false
    ZukMeGUI.warnings = {}
    ZukMeGUI.selectConfigTab = true
    ZukMeGUI.selectInfoTab = false
    ZukMeGUI.selectWarningsTab = false
end

function ZukMeGUI.loadConfig()
    local saved = loadConfigFromFile()
    if not saved then return end

    local c = ZukMeGUI.config
    if type(saved.HasZukCape) == "boolean" then c.hasZukCape = saved.HasZukCape end
    if type(saved.UseBook) == "boolean" then c.useBook = saved.UseBook end
    if type(saved.UseExcal) == "boolean" then c.useExcal = saved.UseExcal end
    if type(saved.UseElvenShard) == "boolean" then c.useElvenShard = saved.UseElvenShard end
    if type(saved.UsePoison) == "boolean" then c.usePoison = saved.UsePoison end
    if type(saved.RingSwitch) == "string" then c.ringSwitch = saved.RingSwitch end
    if type(saved.AdrenPotName) == "string" then c.adrenPotName = saved.AdrenPotName end
    if type(saved.FoodName) == "string" then c.foodName = saved.FoodName end
    if type(saved.FoodPotName) == "string" then c.foodPotName = saved.FoodPotName end
    if type(saved.RestoreName) == "string" then c.restoreName = saved.RestoreName end
    if type(saved.OverloadName) == "string" then c.overloadName = saved.OverloadName end
    if type(saved.BrewName) == "string" then c.brewName = saved.BrewName end
    if type(saved.NecroPrayerIndex) == "number" then c.necroPrayerIndex = saved.NecroPrayerIndex end
    if type(saved.BookIndex) == "number" then c.bookIndex = saved.BookIndex end
end

function ZukMeGUI.getConfig()
    local c = ZukMeGUI.config
    return {
        hasZukCape = c.hasZukCape,
        useBook = c.useBook,
        useExcal = c.useExcal,
        useElvenShard = c.useElvenShard,
        usePoison = c.usePoison,
        ringSwitch = c.ringSwitch,
        adrenPotName = c.adrenPotName,
        foodName = c.foodName,
        foodPotName = c.foodPotName,
        restoreName = c.restoreName,
        overloadName = c.overloadName,
        brewName = c.brewName,
        necroPrayerName = NECRO_PRAYER_OPTIONS[c.necroPrayerIndex + 1] or "Sorrow",
        bookName = BOOK_OPTIONS[c.bookIndex + 1] or "Scripture of Wen",
    }
end

function ZukMeGUI.addWarning(msg)
    ZukMeGUI.warnings[#ZukMeGUI.warnings + 1] = msg
    if #ZukMeGUI.warnings > 50 then
        table.remove(ZukMeGUI.warnings, 1)
    end
end

function ZukMeGUI.clearWarnings()
    ZukMeGUI.warnings = {}
end

function ZukMeGUI.isPaused()
    return ZukMeGUI.paused
end

function ZukMeGUI.isStopped()
    return ZukMeGUI.stopped
end

function ZukMeGUI.isCancelled()
    return ZukMeGUI.cancelled
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
    ImGui.PushStyleColor(ImGuiCol.Text, INFERNO.glow[1], INFERNO.glow[2], INFERNO.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.70, 0.55, 0.35, 1.0)
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
            ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.5)
            ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.5)
            row("Zuk Cape", cfg.hasZukCape and "Yes" or "No")
            row("Prayer", NECRO_PRAYER_OPTIONS[cfg.necroPrayerIndex + 1] or "Sorrow")
            row("Scripture", cfg.useBook and (BOOK_OPTIONS[cfg.bookIndex + 1] or "Wen") or "Disabled")
            row("Excalibur", cfg.useExcal and "Yes" or "No")
            row("Elven Shard", cfg.useElvenShard and "Yes" or "No")
            row("Poison", cfg.usePoison and "Yes" or "No")
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
        ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.15, 0.05, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.2, 0.08, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.7, 0.25, 0.1, 1.0)
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
    flavorText("Configure your gear and consumable options.")
    ImGui.Spacing()

    local capeChanged, capeVal = ImGui.Checkbox("Has Zuk Cape (Igneous Kal-Mor)##cape", cfg.hasZukCape)
    if capeChanged then cfg.hasZukCape = capeVal end

    local bookChanged, bookVal = ImGui.Checkbox("Use Scripture Book##book", cfg.useBook)
    if bookChanged then cfg.useBook = bookVal end

    local excalChanged, excalVal = ImGui.Checkbox("Use Enhanced Excalibur##excal", cfg.useExcal)
    if excalChanged then cfg.useExcal = excalVal end

    local elvenChanged, elvenVal = ImGui.Checkbox("Use Elven Ritual Shard##elven", cfg.useElvenShard)
    if elvenChanged then cfg.useElvenShard = elvenVal end

    local poisonChanged, poisonVal = ImGui.Checkbox("Use Weapon Poison##poison", cfg.usePoison)
    if poisonChanged then cfg.usePoison = poisonVal end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === PRAYER & BOOK ===
    sectionHeader("Prayer & Book")
    ImGui.Spacing()

    ImGui.TextWrapped("Necro Prayer")
    local prayerChanged, prayerIdx = ImGui.Combo("##necroPrayer", cfg.necroPrayerIndex, NECRO_PRAYER_OPTIONS, #NECRO_PRAYER_OPTIONS)
    if prayerChanged then cfg.necroPrayerIndex = prayerIdx end

    if cfg.useBook then
        ImGui.TextWrapped("Scripture Book")
        local bkChanged, bkIdx = ImGui.Combo("##bookSelect", cfg.bookIndex, BOOK_OPTIONS, #BOOK_OPTIONS)
        if bkChanged then cfg.bookIndex = bkIdx end
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- === ITEM NAMES ===
    sectionHeader("Item Names")
    flavorText("Partial name matching. Adjust to match your inventory.")
    ImGui.Spacing()

    ImGui.TextWrapped("Ring Switch")
    local ringChanged, ringVal = ImGui.InputText("##ring", cfg.ringSwitch, 64)
    if ringChanged then cfg.ringSwitch = ringVal end

    ImGui.TextWrapped("Adrenaline Potion")
    local adrenChanged, adrenVal = ImGui.InputText("##adren", cfg.adrenPotName, 64)
    if adrenChanged then cfg.adrenPotName = adrenVal end

    ImGui.TextWrapped("Food")
    local foodChanged, foodVal = ImGui.InputText("##food", cfg.foodName, 64)
    if foodChanged then cfg.foodName = foodVal end

    ImGui.TextWrapped("Food Potion")
    local fpChanged, fpVal = ImGui.InputText("##foodpot", cfg.foodPotName, 64)
    if fpChanged then cfg.foodPotName = fpVal end

    ImGui.TextWrapped("Restore Potion")
    local restChanged, restVal = ImGui.InputText("##restore", cfg.restoreName, 64)
    if restChanged then cfg.restoreName = restVal end

    ImGui.TextWrapped("Overload Potion")
    local ovlChanged, ovlVal = ImGui.InputText("##overload", cfg.overloadName, 64)
    if ovlChanged then cfg.overloadName = ovlVal end

    ImGui.TextWrapped("Brew (empty to disable)")
    local brewChanged, brewVal = ImGui.InputText("##brew", cfg.brewName, 64)
    if brewChanged then cfg.brewName = brewVal end

    ImGui.PopItemWidth()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Start button (inferno themed)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.55, 0.20, 0.05, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.70, 0.30, 0.08, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.85, 0.40, 0.10, 1.0)
    if ImGui.Button("Start ZukMe##start", -1, 32) then
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
    if ZukMeGUI.paused then stateText = "Paused" end
    local sc = STATE_COLORS[stateText] or { 0.7, 0.7, 0.7 }
    ImGui.PushStyleColor(ImGuiCol.Text, sc[1], sc[2], sc[3], 1.0)
    ImGui.TextWrapped(stateText)
    ImGui.PopStyleColor(1)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Wave display
    if data.wave and data.wave > 0 then
        local waveText = string.format("Wave %d / 18", data.wave)
        local wavePct = data.wave / 18
        progressBar(wavePct, 22, waveText, INFERNO.glow[1], INFERNO.glow[2], INFERNO.glow[3])
        ImGui.Spacing()
    end

    -- Player HP bar
    local hpPct = API.GetHPrecent() / 100
    local hr, hg, hb = 1.0, 0.3, 0.3
    if hpPct > 0.6 then hr, hg, hb = 0.3, 0.85, 0.45
    elseif hpPct > 0.3 then hr, hg, hb = 1.0, 0.75, 0.2 end
    progressBar(hpPct, 20, string.format("HP: %d%%", API.GetHPrecent()), hr, hg, hb)

    ImGui.Spacing()

    -- Player Prayer bar
    local prayPct = API.GetPrayPrecent() / 100
    progressBar(prayPct, 20, string.format("Prayer: %d%%", API.GetPrayPrecent()), 0.3, 0.6, 0.9)

    ImGui.Spacing()

    -- Adrenaline bar
    local adrenPct = API.GetAddreline_() / 100
    progressBar(adrenPct, 20, string.format("Adrenaline: %d%%", API.GetAddreline_()), 0.9, 0.7, 0.2)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Stats table
    if ImGui.BeginTable("##stats", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.4)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.6)

        row("Kills", tostring(data.kills or 0))
        row("Deaths", tostring(data.deaths or 0))

        -- Kills per hour
        local runtime = data.runtime or 0
        local kph = 0
        if runtime > 0 and (data.kills or 0) > 0 then
            kph = math.floor(((data.kills or 0) / runtime) * 3600)
        end
        row("Kills/Hour", tostring(kph))

        -- Current kill timer
        if data.killStartTime and data.killStartTime > 0 then
            local elapsed = os.time() - data.killStartTime
            row("Kill Timer", formatTime(elapsed), 1.0, 1.0, 1.0, 1.0, 0.8, 0.3)
        end

        ImGui.EndTable()
    end

    -- Kill times
    if data.killTimes and #data.killTimes > 0 then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if ImGui.BeginTable("##killtimes", 2) then
            ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.4)
            ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.6)

            row("Fastest Kill", data.fastestKill or "--", 1.0, 1.0, 1.0, 0.3, 0.85, 0.45)
            row("Slowest Kill", data.slowestKill or "--", 1.0, 1.0, 1.0, 1.0, 0.5, 0.3)
            row("Average Kill", data.averageKill or "--")

            ImGui.EndTable()
        end

        -- Recent kills
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

function ZukMeGUI.draw(data)
    ImGui.SetNextWindowSize(380, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    -- Inferno Theme
    ImGui.PushStyleColor(ImGuiCol.WindowBg, INFERNO.dark[1], INFERNO.dark[2], INFERNO.dark[3], 0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, INFERNO.medium[1] * 0.6, INFERNO.medium[2] * 0.6, INFERNO.medium[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, INFERNO.medium[1], INFERNO.medium[2], INFERNO.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, INFERNO.light[1], INFERNO.light[2], INFERNO.light[3], 0.4)
    ImGui.PushStyleColor(ImGuiCol.Tab, INFERNO.medium[1] * 0.7, INFERNO.medium[2] * 0.7, INFERNO.medium[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, INFERNO.light[1], INFERNO.light[2], INFERNO.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, INFERNO.bright[1] * 0.7, INFERNO.bright[2] * 0.7, INFERNO.bright[3] * 0.7, 1.0)
    -- Frame/Input styling
    ImGui.PushStyleColor(ImGuiCol.FrameBg, INFERNO.medium[1] * 0.5, INFERNO.medium[2] * 0.5, INFERNO.medium[3] * 0.5, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, INFERNO.light[1] * 0.7, INFERNO.light[2] * 0.7, INFERNO.light[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, INFERNO.bright[1] * 0.5, INFERNO.bright[2] * 0.5, INFERNO.bright[3] * 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, INFERNO.bright[1], INFERNO.bright[2], INFERNO.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, INFERNO.glow[1], INFERNO.glow[2], INFERNO.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, INFERNO.glow[1], INFERNO.glow[2], INFERNO.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, INFERNO.medium[1], INFERNO.medium[2], INFERNO.medium[3], 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, INFERNO.light[1], INFERNO.light[2], INFERNO.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, INFERNO.bright[1], INFERNO.bright[2], INFERNO.bright[3], 1.0)
    -- White text
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, 4)

    local titleText = "ZukMe - " .. API.ScriptRuntimeString() .. "###ZukMe"
    local visible = ImGui.Begin(titleText, 0)

    if visible then
        local ok, err = pcall(drawContent, data, ZukMeGUI)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Error: " .. tostring(err))
        end
    end

    ImGui.PopStyleVar(5)
    ImGui.PopStyleColor(17)
    ImGui.End()

    return ZukMeGUI.open
end

return ZukMeGUI
