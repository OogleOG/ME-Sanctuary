--[[
    Vindicta Configuration
]]

local API = require("api")

local Config = {}

Config.Boss = {
    phase1Id = 22459,           -- Vindicta alone
    phase2Id = 22460,           -- Gorvek and Vindicta
    ids = {22459, 22460},       -- Both phases for targeting
    phaseAnimation = 28253,     -- Animation when phasing to P2
    fireObjectId = 101908,      -- Fire line to avoid
}


Config.WarsRetreat = {
    bankChestId = 114750,
    altarId = 114748,
    adrenalineCrystalId = 114749,
    vindictaPortalId = 114785,
}

Config.Instance = {
    thresholdId = 101909,
    thresholdType = 12,
    barrierId = 101910,
    interfaceId = 1591,
    hardModeCheckbox = 82,
    createButton = 72,
    useHardMode = false,
}

Config.Arena = {
    radius = 8,  -- Arena extends 8 tiles in each direction from center
    center = nil, --
}

Config.Combat = {
    killsBeforeBank = 5,
    minFreeSlots = 3,
    eatAtPercent = 50,
    emergencyEatPercent = 30,
    prayerDrinkPercent = 30,
}

Config.Prayers = {
    soulSplit = {name = "Soul Split", varbit = 16767},
    ruination = {name = "Ruination", varbit = 53281},
}

Config.Food = {
    {name = "Sailfish", id = 42986},
    {name = "1/2 blue blubber jellyfish", id = 42271},
    {name = "2/3 blue blubber jellyfish", id = 42269},
    {name = "Blue blubber jellyfish", id = 42267},
    {name = "Shark", id = 385}
}

Config.PrayerPotions = {
    {name = "Super restore flask", ids = {23399, 23401, 23403, 23405, 23407, 23409}},
    {name = "Prayer flask", ids = {23243, 23245, 23247, 23249, 23251, 23253}}
}

Config.RareDrops = {
    {id = 37045, name = "Crest of Zaros"},
    {id = 37046, name = "Dragon Rider Lance"},
    {id = 37047, name = "Zarosian essence"},
    {id = 48027, name = "Vindicta's crest"},
    {id = 37043, name = "Dormant anima core helm"},
    {id = 37042, name = "Dormant anima core body"},
    {id = 37044, name = "Dormant anima core legs"},
    {id = 29434, name = "Imbued blade slice"},       -- Pet item
    {id = 29435, name = "Glimmering scale"},         -- Pet item
}

Config.LootIds = {
    -- 100% drops
    21778,  -- Dragon bones (single)
    
    -- Unique drops
    37045,  -- Crest of Zaros
    37046,  -- Dragon Rider Lance
    37047,  -- Zarosian essence
    37043,  -- Dormant anima core helm
    37042,  -- Dormant anima core body
    37044,  -- Dormant anima core legs
    
    -- Stone spirits
    44806,  -- Drakolith stone spirit
    44808,  -- Orichalcite stone spirit
    44812,  -- Necrite stone spirit
    44810,  -- Phasmatite stone spirit
    
    -- Gems
    1618,   -- Uncut diamond
    1632,   -- Uncut dragonstone
    
    -- Other drops
    383,    -- Raw shark
    995,    -- Coins
    5303,   -- Dwarf weed seed
    1514,   -- Magic logs (noted)
    21778,  -- Dragon bones (noted)
    1748,   -- Black dragonhide
    47260,  -- Large plated rune salvage
    
    -- Tertiary
    385,    -- Shark
    29434,  -- Imbued blade slice (pet)
    29435,  -- Glimmering scale (pet)
    
    -- Rare drop table commons
    1632,   -- Uncut dragonstone
    985,    -- Tooth half of key
    987,    -- Loop half of key
    47264,  -- Huge plated rune salvage
    47240,  -- Small bladed orikalkum salvage
    24723,  -- Catalytic anima stone
    8781,   -- Teak plank
    1377,   -- Dragon helm
    1305,   -- Dragon longsword
    2366,   -- Shield left half
    1249,   -- Dragon spear
    1516,   -- Yew logs
    3025,   -- Super restore (4)
    2434,   -- Prayer potion (4)
    15272,  -- Raw rocktail
    8783,   -- Mahogany plank
    5316,   -- Magic seed
    1445,   -- Water talisman
    1392,   -- Battlestaff
    51858,  -- Hardened dragon bones
    9193,   -- Onyx bolt tips
    68995,  -- Ciku seed
    53111,  -- Golden dragonfruit seed
    566,    -- Soul rune
    44828,  -- Light animica stone spirit
    44826,  -- Dark animica stone spirit
    70548,  -- Primal stone spirit
    989,    -- Crystal key
    239,    -- White berries
    4286,   -- Ectoplasm
    47246,  -- Medium spiky orikalkum salvage
    47274,  -- Large blunt necronium salvage
    2016,   -- Wine of Saradomin
}

Config.Discord = {
    webhookUrl = "", -- Set your webhook URL here
    enabled = false, -- Set to true to enable webhook notifications
    embedColor = 0x9B59B6, -- Purple color for Vindicta
    thumbnailUrl = "https://runescape.wiki/images/thumb/Gorvek_and_Vindicta.png/200px-Gorvek_and_Vindicta.png",
    username = "Vindicta"
}


Config.Buffs = {
    necrosis = 30101,
    soulStacks = 30123,
    livingDeath = 48532,
    splitSoul = 48899,
}


Config.Variables = {
    killCount = 0,
    tripKills = 0,
    deathCount = 0,
    fightStartTime = 0,
    currentPhase = 1,
}

Config.TrackedKills = {}
Config.LootedRares = {}

return Config