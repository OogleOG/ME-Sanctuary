

local ScriptName = "MELib"
local Author = "Oogle"

local API = require("api")
local MELib = {}
MELib.VERSION = "2.0.0"

MELib.Utils = {}

function MELib.Utils.Sleep(min, max)
    max = max or min
    API.RandomSleep2(math.random(min, max), 0, 0)
end

function MELib.Utils.SleepTicks(ticks)
    API.RandomSleep2(ticks * 600, 100, 200)
end

function MELib.Utils.WaitUntil(condition, timeout, interval)
    timeout = timeout or 10000
    interval = interval or 100
    local start = os.clock() * 1000
    while (os.clock() * 1000 - start) < timeout do
        if condition() then return true end
        API.RandomSleep2(interval, 0, 50)
    end
    return false
end

function MELib.Utils.Log(msg)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), tostring(msg)))
end

function MELib.Utils.FormatNumber(n)
    local formatted = tostring(n)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

MELib.Player = {}

function MELib.Player.IsLoggedIn()
    return API.GetGameState2() == 3
end

function MELib.Player.GetTile()
    return API.PlayerCoord()
end

function MELib.Player.GetName()
    return API.GetLocalPlayerName()
end

function MELib.Player.IsMoving()
    return API.ReadPlayerMovin2()
end

function MELib.Player.IsAnimating(loops)
    return API.CheckAnim(loops or 1)
end

function MELib.Player.InCombat()
    return API.LocalPlayer_IsInCombat_() or API.GetInCombBit()
end

function MELib.Player.GetHP()
    return API.GetHP_()
end

function MELib.Player.GetMaxHP()
    return API.GetHPMax_()
end

function MELib.Player.GetHPPercent()
    return API.GetHPrecent()
end

function MELib.Player.GetPrayer()
    return API.GetPray_()
end

function MELib.Player.GetMaxPrayer()
    return API.GetPrayMax_()
end

function MELib.Player.GetPrayerPercent()
    return API.GetPrayPrecent()
end

function MELib.Player.GetAdrenaline()
    return API.GetAddreline_()
end

function MELib.Player.GetSummoning()
    return Familiars:GetSummoningPoints()
end

function MELib.Player.GetRunEnergy()
    return API.GetRunEnergy_()
end

function MELib.Player.IsRunOn()
    return API.GetRun()
end

function MELib.Player.ToggleRun()
    if not MELib.Player.IsRunOn() and MELib.Player.GetRunEnergy() > 0 then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1465, 4, -1, API.OFF_ACT_GeneralInterface_route)
    end
end

function MELib.Player.DistanceTo(tile)
    if tile.z then
        return API.Dist_FLPW(tile)
    end
    return API.Dist_FLP(tile)
end

function MELib.Player.IsNear(tile, range)
    return API.PInAreaW(tile, range)
end

function MELib.Player.GetWorld()
    return API.GetWorldNR()
end

function MELib.Player.IsMember()
    return API.IsMember()
end

MELib.Skills = {}

MELib.Skills.ATTACK = 0
MELib.Skills.DEFENCE = 2
MELib.Skills.STRENGTH = 4
MELib.Skills.HITPOINTS = 6
MELib.Skills.RANGED = 8
MELib.Skills.PRAYER = 10
MELib.Skills.MAGIC = 12
MELib.Skills.COOKING = 14
MELib.Skills.WOODCUTTING = 16
MELib.Skills.FLETCHING = 18
MELib.Skills.FISHING = 20
MELib.Skills.FIREMAKING = 22
MELib.Skills.CRAFTING = 24
MELib.Skills.SMITHING = 26
MELib.Skills.MINING = 28
MELib.Skills.HERBLORE = 30
MELib.Skills.AGILITY = 32
MELib.Skills.THIEVING = 34
MELib.Skills.SLAYER = 36
MELib.Skills.FARMING = 38
MELib.Skills.RUNECRAFTING = 40
MELib.Skills.HUNTER = 42
MELib.Skills.CONSTRUCTION = 44
MELib.Skills.SUMMONING = 46
MELib.Skills.DUNGEONEERING = 48
MELib.Skills.DIVINATION = 50
MELib.Skills.INVENTION = 52
MELib.Skills.ARCHAEOLOGY = 54
MELib.Skills.NECROMANCY = 56

function MELib.Skills.GetLevel(skill)
    return API.GetSkillsTableSkill(skill)
end

function MELib.Skills.GetBoostedLevel(skill)
    return API.GetSkillsTableSkill(skill + 1)
end

function MELib.Skills.GetXP(skill)
    return API.GetSkillXP(skill)
end

function MELib.Skills.IsBoosted(skill)
    return MELib.Skills.GetBoostedLevel(skill) > MELib.Skills.GetLevel(skill)
end

function MELib.Skills.GetBoost(skill)
    return MELib.Skills.GetBoostedLevel(skill) - MELib.Skills.GetLevel(skill)
end

MELib.Inventory = {}

function MELib.Inventory.GetAll()
    return Inventory:GetItems()
end

function MELib.Inventory.Contains(item)
    return Inventory:Contains(item)
end

function MELib.Inventory.ContainsAll(items)
    return Inventory:ContainsAll(items)
end

function MELib.Inventory.ContainsAny(items)
    return Inventory:ContainsAny(items)
end

function MELib.Inventory.Count(item)
    return Inventory:GetItemAmount(item)
end

function MELib.Inventory.IsFull()
    return Inventory:IsFull()
end

function MELib.Inventory.IsEmpty()
    return Inventory:IsEmpty()
end

function MELib.Inventory.FreeSlots()
    return Inventory:FreeSpaces()
end

function MELib.Inventory.UsedSlots()
    return 28 - Inventory:FreeSpaces()
end

function MELib.Inventory.Use(item)
    return Inventory:Use(item)
end

function MELib.Inventory.UseOn(item1, item2)
    return Inventory:UseItemOnItem(item1, item2)
end

function MELib.Inventory.Drop(item)
    return Inventory:Drop(item)
end

function MELib.Inventory.Eat(item)
    return Inventory:Eat(item)
end

function MELib.Inventory.Equip(item)
    return Inventory:Equip(item)
end

function MELib.Inventory.Rub(item)
    return Inventory:Rub(item)
end

function MELib.Inventory.Note(item)
    return Inventory:NoteItem(item)
end

function MELib.Inventory.GetItem(item)
    return Inventory:GetItem(item)
end

function MELib.Inventory.GetSlot(slot)
    return Inventory:GetSlotData(slot)
end

function MELib.Inventory.IsItemSelected()
    return Inventory:IsItemSelected()
end

function MELib.Inventory.DoAction(item, action, offset)
    return Inventory:DoAction(item, action, offset)
end

MELib.Equipment = {}

MELib.Equipment.SLOT = {
    HEAD = 0,
    CAPE = 1,
    NECK = 2,
    MAINHAND = 3,
    BODY = 4,
    OFFHAND = 5,
    BOTTOM = 7,
    GLOVES = 9,
    BOOTS = 10,
    RING = 12,
    AMMO = 13,
    AURA = 14,
    POCKET = 15
}

function MELib.Equipment.GetAll()
    return Equipment:GetItems()
end

function MELib.Equipment.Contains(item)
    return Equipment:Contains(item)
end

function MELib.Equipment.ContainsAll(items)
    return Equipment:ContainsAll(items)
end

function MELib.Equipment.ContainsAny(items)
    return Equipment:ContainsAny(items)
end

function MELib.Equipment.Unequip(item)
    return Equipment:Unequip(item)
end

function MELib.Equipment.GetSlot(slot)
    return Equipment:GetSlotData(slot)
end

function MELib.Equipment.GetHelm()
    return Equipment:GetHelm()
end

function MELib.Equipment.GetCape()
    return Equipment:GetCape()
end

function MELib.Equipment.GetNeck()
    return Equipment:GetNeck()
end

function MELib.Equipment.GetMainhand()
    return Equipment:GetMainhand()
end

function MELib.Equipment.GetBody()
    return Equipment:GetBody()
end

function MELib.Equipment.GetOffhand()
    return Equipment:GetOffhand()
end

function MELib.Equipment.GetBottom()
    return Equipment:GetBottom()
end

function MELib.Equipment.GetGloves()
    return Equipment:GetGloves()
end

function MELib.Equipment.GetBoots()
    return Equipment:GetBoots()
end

function MELib.Equipment.GetRing()
    return Equipment:GetRing()
end

function MELib.Equipment.GetAmmo()
    return Equipment:GetAmmo()
end

function MELib.Equipment.GetAura()
    return Equipment:GetAura()
end

function MELib.Equipment.GetPocket()
    return Equipment:GetPocket()
end

function MELib.Equipment.IsEmpty()
    return Equipment:IsEmpty()
end

function MELib.Equipment.IsFull()
    return Equipment:IsFull()
end

function MELib.Equipment.IsOpen()
    return Equipment:IsOpen()
end

function MELib.Equipment.Open()
    return Equipment:OpenInterface()
end

function MELib.Equipment.GetItemXp(slot)
    return Equipment:GetItemXp(slot)
end

function MELib.Equipment.DoAction(item, action)
    return Equipment:DoAction(item, action)
end

MELib.Bank = {}

function MELib.Bank.IsOpen()
    return API.BankOpen2()
end

function MELib.Bank.Close()
    if MELib.Bank.IsOpen() then
        API.KeyboardPress2(0x1B, 60, 100)
        return MELib.Utils.WaitUntil(function() return not MELib.Bank.IsOpen() end, 2000)
    end
    return true
end

function MELib.Bank.GetItemStack(item)
    if type(item) == "string" then
        return API.BankGetItemStack_str(item)
    end
    return API.BankGetItemStack1(item)
end

function MELib.Bank.Contains(item, minStack)
    minStack = minStack or 1
    return MELib.Bank.GetItemStack(item) >= minStack
end

function MELib.Bank.DepositAll()
    if not MELib.Bank.IsOpen() then return false end
    return API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 517, 39, -1, API.OFF_ACT_GeneralInterface_route)
end

function MELib.Bank.DepositWornItems()
    if not MELib.Bank.IsOpen() then return false end
    return API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 517, 42, -1, API.OFF_ACT_GeneralInterface_route)
end

function MELib.Bank.DepositBOB()
    if not MELib.Bank.IsOpen() then return false end
    return API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 517, 44, -1, API.OFF_ACT_GeneralInterface_route)
end

function MELib.Bank.Withdraw(item, amount)
    if not MELib.Bank.IsOpen() then return false end
    
    local action = 1
    if amount == "All" or amount == "all" then
        action = 8
    elseif amount == 5 then
        action = 3
    elseif amount == 10 then
        action = 4
    elseif type(amount) == "number" and amount > 1 then
        action = 6
    end
    
    if type(item) == "string" then
        API.DoAction_Bank_str(item, action, API.OFF_ACT_GeneralInterface_route)
    else
        API.DoAction_Bank(item, action, API.OFF_ACT_GeneralInterface_route)
    end
    
    if action == 6 then
        API.RandomSleep2(600, 100, 200)
        API.TypeString(tostring(amount))
        API.RandomSleep2(100, 50, 100)
        API.KeyboardPress2(0x0D, 60, 100)
    end
    
    return true
end

function MELib.Bank.Deposit(item, amount)
    if not MELib.Bank.IsOpen() then return false end
    
    local action = 1
    if amount == "All" or amount == "all" then
        action = 8
    elseif amount == 5 then
        action = 3
    elseif amount == 10 then
        action = 4
    elseif type(amount) == "number" and amount > 1 then
        action = 6
    end
    
    API.DoAction_Bank_Inv(item, action, API.OFF_ACT_GeneralInterface_route2)
    
    if action == 6 then
        API.RandomSleep2(600, 100, 200)
        API.TypeString(tostring(amount))
        API.RandomSleep2(100, 50, 100)
        API.KeyboardPress2(0x0D, 60, 100)
    end
    
    return true
end

function MELib.Bank.LoadPreset(preset)
    if not MELib.Bank.IsOpen() then return false end
    local keys = {49, 50, 51, 52, 53, 54, 55, 56, 57, 48}
    if keys[preset] then
        API.KeyboardPress2(keys[preset], 60, 100)
        return true
    end
    return false
end

function MELib.Bank.EnterPin(pin)
    return API.DoBankPin(pin)
end

MELib.Combat = {}

function MELib.Combat.InCombat()
    return API.LocalPlayer_IsInCombat_() or API.GetInCombBit()
end

function MELib.Combat.HasTarget()
    return API.IsTargeting()
end

function MELib.Combat.GetTargetHealth()
    return API.GetTargetHealth()
end

function MELib.Combat.Eat(food)
    return Inventory:Eat(food)
end

function MELib.Combat.Drink(potion)
    return Inventory:Use(potion)
end

function MELib.Combat.UseAbility(name, exact)
    local ability = API.GetABs_name(name, exact or true)
    if ability and ability.id > 0 and ability.enabled and ability.cooldown_timer == 0 then
        return API.DoAction_Ability_Direct(ability, 1, API.OFF_ACT_GeneralInterface_route)
    end
    return false
end

function MELib.Combat.UseAbilityById(id)
    local ability = API.GetABs_id(id)
    if ability and ability.id > 0 and ability.enabled and ability.cooldown_timer == 0 then
        return API.DoAction_Ability_Direct(ability, 1, API.OFF_ACT_GeneralInterface_route)
    end
    return false
end

function MELib.Combat.IsAbilityReady(name, exact)
    local ability = API.GetABs_name(name, exact or true)
    if ability and ability.id > 0 then
        return ability.enabled and ability.cooldown_timer == 0
    end
    return false
end

function MELib.Combat.GetAbilityCooldown(name, exact)
    local ability = API.GetABs_name(name, exact or true)
    if ability and ability.id > 0 then
        return ability.cooldown_timer
    end
    return -1
end

function MELib.Combat.GetAbility(name, exact)
    return API.GetABs_name(name, exact or true)
end

function MELib.Combat.GetAbilityById(id)
    return API.GetABs_id(id)
end

function MELib.Combat.ToggleQuickPrayers()
    API.DoAction_Button_QP()
end

function MELib.Combat.QuickPrayersActive()
    return API.GetQuickPray()
end

function MELib.Combat.SetAutoRetaliate()
    return API.DoAction_Button_AR()
end

MELib.Buffs = {}

function MELib.Buffs.GetAll()
    return API.Buffbar_GetAllIDs()
end

function MELib.Buffs.Has(buffId)
    local buff = API.Buffbar_GetIDstatus(buffId, false)
    return buff.id > 0
end

function MELib.Buffs.Get(buffId)
    return API.Buffbar_GetIDstatus(buffId, false)
end

function MELib.Buffs.GetDuration(buffId)
    local buff = API.Buffbar_GetIDstatus(buffId, false)
    if buff.id > 0 then
        return buff.conv_text or 0
    end
    return -1
end

function MELib.Buffs.GetAllDebuffs()
    return API.DeBuffbar_GetAllIDs()
end

function MELib.Buffs.HasDebuff(debuffId)
    local debuff = API.DeBuffbar_GetIDstatus(debuffId, false)
    return debuff.id > 0
end

function MELib.Buffs.GetDebuff(debuffId)
    return API.DeBuffbar_GetIDstatus(debuffId, false)
end

MELib.NPC = {}

function MELib.NPC.Find(npc, distance)
    distance = distance or 50
    local ids = type(npc) == "table" and npc or {npc}
    local npcs = API.GetAllObjArray1(ids, distance, {1})
    if #npcs > 0 then return API.Math_SortAODist(npcs) end
    return nil
end

function MELib.NPC.FindByName(name, distance)
    distance = distance or 50
    local names = type(name) == "table" and name or {name}
    local npcs = API.GetAllObjArrayInteract_str(names, distance, {1})
    if #npcs > 0 then return API.Math_SortAODist(npcs) end
    return nil
end

function MELib.NPC.FindAll(npc, distance)
    distance = distance or 50
    local ids = type(npc) == "table" and npc or {npc}
    return API.GetAllObjArray1(ids, distance, {1})
end

function MELib.NPC.Exists(npc, distance)
    return MELib.NPC.Find(npc, distance) ~= nil
end

function MELib.NPC.Interact(name, action, distance)
    return Interact:NPC(name, action, distance or 60)
end

function MELib.NPC.Attack(npc, distance)
    distance = distance or 20
    local ids = type(npc) == "table" and npc or {npc}
    return API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, ids, distance, true, 100)
end

function MELib.NPC.AttackByName(name, distance)
    distance = distance or 20
    local names = type(name) == "table" and name or {name}
    return API.DoAction_NPC_str(0x2a, API.OFF_ACT_AttackNPC_route, names, distance, true, 100)
end

function MELib.NPC.TalkTo(npc, distance)
    distance = distance or 20
    local ids = type(npc) == "table" and npc or {npc}
    return API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, ids, distance, true, 0)
end

function MELib.NPC.InteractDirect(npcObject, action, route)
    action = action or 0x29
    route = route or API.OFF_ACT_InteractNPC_route
    return API.DoAction_NPC__Direct(action, route, npcObject)
end

MELib.Objects = {}

function MELib.Objects.Find(obj, distance)
    distance = distance or 50
    local ids = type(obj) == "table" and obj or {obj}
    local objs = API.GetAllObjArray1(ids, distance, {0, 12})
    if #objs > 0 then return API.Math_SortAODist(objs) end
    return nil
end

function MELib.Objects.FindByName(name, distance)
    distance = distance or 50
    local names = type(name) == "table" and name or {name}
    local objs = API.GetAllObjArrayInteract_str(names, distance, {0, 12})
    if #objs > 0 then return API.Math_SortAODist(objs) end
    return nil
end

function MELib.Objects.FindAll(obj, distance)
    distance = distance or 50
    local ids = type(obj) == "table" and obj or {obj}
    return API.GetAllObjArray1(ids, distance, {0, 12})
end

function MELib.Objects.Exists(obj, distance)
    return MELib.Objects.Find(obj, distance) ~= nil
end

function MELib.Objects.Interact(name, action, distance)
    return Interact:Object(name, action, distance or 60)
end

function MELib.Objects.InteractById(obj, distance)
    distance = distance or 20
    local ids = type(obj) == "table" and obj or {obj}
    return API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, ids, distance)
end

function MELib.Objects.InteractDirect(objObject, action, route)
    action = action or 0x29
    route = route or API.OFF_ACT_GeneralObject_route0
    return API.DoAction_Object_Direct(action, route, objObject)
end

MELib.GroundItems = {}

function MELib.GroundItems.Find(item, distance)
    distance = distance or 50
    local ids = type(item) == "table" and item or {item}
    local items = API.GetAllObjArray1(ids, distance, {3})
    if #items > 0 then return API.Math_SortAODist(items) end
    return nil
end

function MELib.GroundItems.FindAll(item, distance)
    distance = distance or 50
    local ids = type(item) == "table" and item or {item}
    return API.GetAllObjArray1(ids, distance, {3})
end

function MELib.GroundItems.Exists(item, distance)
    return MELib.GroundItems.Find(item, distance) ~= nil
end

function MELib.GroundItems.Loot(item, distance)
    distance = distance or 20
    local ids = type(item) == "table" and item or {item}
    return API.DoAction_G_Items1(0x29, ids, distance)
end

function MELib.GroundItems.LootArea(item, distance, tile, radius)
    distance = distance or 20
    radius = radius or 5
    local ids = type(item) == "table" and item or {item}
    return API.DoAction_Loot_w(ids, distance, tile, radius)
end

MELib.Interface = {}

function MELib.Interface.IsOpen(interfaceId)
    return API.GetInterfaceOpenBySize(interfaceId)
end

function MELib.Interface.DialogueOpen()
    return API.Compare2874Status(8, false) or API.Compare2874Status(9, false)
end

function MELib.Interface.SelectOption(num)
    local keys = {49, 50, 51, 52, 53}
    if keys[num] then
        API.KeyboardPress2(keys[num], 60, 100)
        return true
    end
    return false
end

function MELib.Interface.Continue()
    API.KeyboardPress2(32, 60, 100)
end

function MELib.Interface.Close()
    API.KeyboardPress2(0x1B, 60, 100)
end

function MELib.Interface.WaitFor(interfaceId, timeout)
    return MELib.Utils.WaitUntil(function()
        return MELib.Interface.IsOpen(interfaceId)
    end, timeout or 5000)
end

function MELib.Interface.LootWindowOpen()
    return API.LootWindowOpen_2()
end

function MELib.Interface.LootAll()
    if MELib.Interface.LootWindowOpen() then
        return API.DoAction_LootAll_Button()
    end
    return false
end

function MELib.Interface.CloseLootWindow()
    if MELib.Interface.LootWindowOpen() then
        API.DoAction_Loot_w_Close()
    end
end

MELib.Movement = {}

function MELib.Movement.WalkTo(tile)
    if tile.z then
        return API.DoAction_WalkerW(tile)
    end
    return API.DoAction_WalkerF(tile)
end

function MELib.Movement.WalkToAndWait(tile, tolerance, timeout)
    tolerance = tolerance or 2
    timeout = timeout or 10000
    MELib.Movement.WalkTo(tile)
    return MELib.Utils.WaitUntil(function()
        return MELib.Player.DistanceTo(tile) <= tolerance
    end, timeout)
end

function MELib.Movement.IsMoving()
    return API.ReadPlayerMovin2()
end

function MELib.Movement.WaitUntilStopped(timeout)
    return MELib.Utils.WaitUntil(function()
        return not MELib.Movement.IsMoving()
    end, timeout or 10000)
end

function MELib.Movement.Surge()
    return MELib.Combat.UseAbility("Surge")
end

function MELib.Movement.Escape()
    return MELib.Combat.UseAbility("Escape")
end

function MELib.Movement.BladedDive(tile)
    return API.DoAction_Dive_Tile(tile, 0)
end

function MELib.Movement.ClickTile(tile)
    if tile.z then
        return API.DoAction_Tile(tile)
    end
    return API.DoAction_TileF(tile)
end

MELib.Familiar = {}

function MELib.Familiar.IsSummoned()
    return Familiars:HasFamiliar()
end

function MELib.Familiar.IsSummonedVB()
    return Familiars:HasFamiliar2()
end

function MELib.Familiar.HasBOB()
    return Familiars:HasFamiliarBOB()
end

function MELib.Familiar.GetName()
    return Familiars:GetName()
end

function MELib.Familiar.GetTimeRemaining()
    return Familiars:GetTimeRemaining()
end

function MELib.Familiar.CanRenew()
    return Familiars:CanRenew()
end

function MELib.Familiar.GetSpellPoints()
    return Familiars:GetSpellPoints()
end

function MELib.Familiar.GetSummoningPoints()
    return Familiars:GetSummoningPoints()
end

function MELib.Familiar.GetHealth()
    return Familiars:GetHealth()
end

function MELib.Familiar.GetMaxHealth()
    return Familiars:GetHealthMax()
end

function MELib.Familiar.CastSpecial()
    return Familiars:CastSpecialAttack()
end

function MELib.Familiar.StorageFreeSlots()
    return Familiars:Storage_FreeAm()
end

function MELib.Familiar.StorageContains(item)
    return Familiars:Storage_Contains(item)
end

function MELib.Familiar.StorageGetItems()
    return Familiars:Storage_List()
end

function MELib.Familiar.IsStorageOpen()
    return Familiars:Storage_InterfaceOpen()
end

function MELib.Familiar.OpenStorage()
    return Familiars:SwitchToStorage()
end

function MELib.Familiar.GiveAll()
    return Familiars:GiveAllBurden()
end

function MELib.Familiar.TakeAll()
    return Familiars:TakeAllBurden()
end

function MELib.Familiar.TakeItem(item)
    return Familiars:Storage_InterfaceTake(item)
end

function MELib.Familiar.Call()
    return API.DoAction_Button_FO(0)
end

function MELib.Familiar.Dismiss()
    return API.DoAction_Button_FO(4)
end

function MELib.Familiar.Renew()
    return API.DoAction_Button_FO(7)
end

MELib.GrandExchange = {}

function MELib.GrandExchange.IsOpen()
    return GrandExchange:IsOpen()
end

function MELib.GrandExchange.Close()
    return GrandExchange:Close()
end

function MELib.GrandExchange.GetSlotData(slot)
    return GrandExchange:GetSlotData(slot)
end

function MELib.GrandExchange.GetAllSlots()
    return GrandExchange:GetAllSlotData()
end

function MELib.GrandExchange.Buy(itemId, quantity, price)
    if not MELib.GrandExchange.IsOpen() then return false end
    GrandExchange:OpenNextAvailableSlot()
    API.RandomSleep2(300, 100, 200)
    GrandExchange:SelectItem(itemId)
    API.RandomSleep2(300, 100, 200)
    if quantity then GrandExchange:SetQuantity(quantity) end
    if price then GrandExchange:SetPrice(price) end
    API.RandomSleep2(200, 50, 100)
    return GrandExchange:ConfirmOrder()
end

function MELib.GrandExchange.FindOrder(itemId)
    return GrandExchange:FindOrder(itemId)
end

function MELib.GrandExchange.CancelOrder(slot)
    return GrandExchange:CancelOrder(slot)
end

MELib.Item = {}

function MELib.Item.Get(item, tradeable)
    return Item:Get(item, tradeable)
end

function MELib.Item.GetAll(name, partialMatch)
    return Item:GetAll(name, partialMatch or false)
end

MELib.Varbit = {}

function MELib.Varbit.Get(id)
    local vb = API.VB_FindPSettinOrder(id)
    if vb then return vb.state end
    return 0
end

function MELib.Varbit.GetBit(id, pos)
    return API.VB_GetBit(id, pos)
end

function MELib.Varbit.IsBitSet(id, pos)
    return API.VB_GetBit(id, pos) == 1
end

MELib.Chat = {}

function MELib.Chat.GetMessages(count)
    return API.GetChatMessage(0, count or 10)
end

function MELib.Chat.Contains(text, count)
    local messages = MELib.Chat.GetMessages(count or 10)
    for _, msg in ipairs(messages) do
        if string.find(msg:lower(), text:lower()) then return true end
    end
    return false
end

function MELib.Chat.Type(text)
    API.TypeString(text)
end

function MELib.Chat.Send(text)
    API.TypeString(text)
    API.KeyboardPress2(0x0D, 60, 100)
end

MELib.Area = {}

function MELib.Area.InArea(x1, y1, x2, y2, floor)
    local pos = API.PlayerCoord()
    if floor and pos.z ~= floor then return false end
    return pos.x >= x1 and pos.x <= x2 and pos.y >= y1 and pos.y <= y2
end

function MELib.Area.InRadius(tile, radius)
    return MELib.Player.DistanceTo(tile) <= radius
end

MELib.Death = {}

function MELib.Death.HasItemsToReclaim()
    return API.HasDeathItemsReclaim()
end

function MELib.Death.IsInDeathOffice()
    return API.IsInDeathOffice()
end

return MELib
