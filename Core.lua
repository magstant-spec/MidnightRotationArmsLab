local addonName, addon = ...

local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 180,
    y = -140,
    scale = 1,
    alpha = 1,
    locked = false,
    keybindOnly = false,
    recommendMajorCooldowns = true,
    assistedFallback = true,
    burstMode = false,
    burstWindowSeconds = 20,
    burstPotionName = "Potion of Recklessness",
    targetCountOverride = 0,
    traceEnabled = false,
    traceMaxEntries = 6000,
    fontPath = "Fonts\\FRIZQT__.TTF",
    fontSize = 28,
}

local SETTINGS_VERSION = 7

local actionBarPrefixes = {
    "Action",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarLeft",
    "MultiBarRight",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
}

local bindingActionPrefixes = {
    Action = "ACTIONBUTTON",
    MultiBarBottomLeft = "MULTIACTIONBAR1BUTTON",
    MultiBarBottomRight = "MULTIACTIONBAR2BUTTON",
    MultiBarRight = "MULTIACTIONBAR3BUTTON",
    MultiBarLeft = "MULTIACTIONBAR4BUTTON",
    MultiBar5 = "MULTIACTIONBAR5BUTTON",
    MultiBar6 = "MULTIACTIONBAR6BUTTON",
    MultiBar7 = "MULTIACTIONBAR7BUTTON",
}

local clickButtonAttributeSuffixes = {
    LeftButton = { "1", "LeftButton", "-LeftButton", "-1" },
    RightButton = { "2", "RightButton", "-RightButton", "-2" },
    MiddleButton = { "3", "MiddleButton", "-MiddleButton", "-3" },
    Button4 = { "4", "Button4", "-Button4", "-4" },
    Button5 = { "5", "Button5", "-Button5", "-5" },
}

local fontAliases = {
    friz = "Fonts\\FRIZQT__.TTF",
    arial = "Fonts\\ARIALN.TTF",
    ["arial narrow"] = "Fonts\\ARIALN.TTF",
    arialn = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF",
    skurri = "Fonts\\SKURRI.TTF",
}

addon.bindingBySpell = {}
addon.bindingByBaseSpell = {}
addon.bindingBySpellName = {}
addon.bindingByItem = {}
addon.bindingByItemName = {}
addon.bindingPriorityBySpell = {}
addon.bindingPriorityByBaseSpell = {}
addon.bindingPriorityBySpellName = {}
addon.bindingPriorityByItem = {}
addon.bindingPriorityByItemName = {}
addon.actionSlotsBySpell = {}
addon.actionSlotsByBaseSpell = {}
addon.actionButtonsBySpell = {}
addon.actionButtonsByBaseSpell = {}
addon.actionSpellIDsByName = {}
addon.actionItemIDsByName = {}
addon.eventFrame = CreateFrame("Frame")

local BINDING_PRIORITY_MACRO_NAME = 5
local BINDING_PRIORITY_DIRECT_SPELL = 30
local BINDING_PRIORITY_MACRO_BODY = 40
local BINDING_PRIORITY_MACRO_PRIMARY = 50

local function WipeTable(tbl)
    if tbl then
        wipe(tbl)
    end
end

local function NormalizeSpellLookupName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    return name:lower():gsub("[%s%p_]+", "")
end

local function TrimText(text)
    if type(text) ~= "string" then
        return nil
    end

    return text:match("^%s*(.-)%s*$")
end

local function ResolveSpellIDByName(spellName)
    spellName = TrimText(spellName)
    if not spellName or spellName == "" or tonumber(spellName) then
        return nil
    end

    spellName = spellName:gsub("^!+", "")
    spellName = TrimText(spellName)
    if not spellName or spellName == "" then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellName)
        if ok and spellInfo and type(spellInfo.spellID) == "number" and spellInfo.spellID > 0 then
            return spellInfo.spellID
        end
    end

    if GetSpellInfo then
        local ok, spellNameResult, spellRank, spellIcon, castTime, minRange, maxRange, spellID = pcall(GetSpellInfo, spellName)
        if ok and type(spellID) == "number" and spellID > 0 then
            return spellID
        end
    end

    return nil
end

local function ResolveItemIDByName(itemName)
    itemName = TrimText(itemName)
    if not itemName or itemName == "" then
        return nil
    end

    local itemID = tonumber(itemName)
        or tonumber(itemName:match("item:(%d+)"))
    if itemID and itemID > 0 then
        return itemID
    end

    if C_Item and C_Item.GetItemInfoInstant then
        local ok, resolvedItemID = pcall(C_Item.GetItemInfoInstant, itemName)
        if ok and type(resolvedItemID) == "number" and resolvedItemID > 0 then
            return resolvedItemID
        end
    end

    if GetItemInfoInstant then
        local ok, resolvedItemID = pcall(GetItemInfoInstant, itemName)
        if ok and type(resolvedItemID) == "number" and resolvedItemID > 0 then
            return resolvedItemID
        end
    end

    return nil
end

local function StripMacroConditionals(text)
    text = TrimText(text)
    if not text or text == "" then
        return nil
    end

    while text:match("^%b[]") do
        text = TrimText(text:gsub("^%b[]%s*", "", 1))
        if not text or text == "" then
            return nil
        end
    end

    return text
end

local function StripMacroItemText(text)
    text = StripMacroConditionals(text)
    if not text or text == "" then
        return nil
    end

    text = text:gsub("^item:", "")
    return TrimText(text)
end

local function StripCastSequenceOptions(text)
    text = StripMacroConditionals(text)
    if not text or text == "" then
        return nil
    end

    while true do
        local option, rest = text:match("^(%S+)%s+(.+)$")
        if option and option:find("=", 1, true) then
            text = StripMacroConditionals(rest)
        else
            return text
        end
    end
end

local function IsMacroSpellCommand(command)
    return command == "cast"
        or command == "use"
        or command == "spell"
        or command == "castsequence"
        or command == "castsequence!"
        or command == "castrandom"
        or command == "userandom"
end

local function AddSpellID(spellIDs, seenSpellIDs, spellID)
    if type(spellID) ~= "number" or spellID <= 0 or seenSpellIDs[spellID] then
        return
    end

    seenSpellIDs[spellID] = true
    table.insert(spellIDs, spellID)
end

local function AddSpellEntry(spellEntries, entryIndexBySpellID, spellID, bindingPriority)
    if type(spellID) ~= "number" or spellID <= 0 then
        return
    end

    bindingPriority = tonumber(bindingPriority) or 0

    local existingIndex = entryIndexBySpellID[spellID]
    if existingIndex then
        local existingEntry = spellEntries[existingIndex]
        if existingEntry and bindingPriority > (existingEntry.bindingPriority or 0) then
            existingEntry.bindingPriority = bindingPriority
        end
        return
    end

    entryIndexBySpellID[spellID] = #spellEntries + 1
    table.insert(spellEntries, {
        spellID = spellID,
        bindingPriority = bindingPriority,
    })
end

local function AddSpellNameEntry(spellEntries, spellName, bindingPriority)
    spellName = TrimText(spellName)
    if type(spellEntries) ~= "table" or not spellName or spellName == "" or tonumber(spellName) then
        return
    end

    spellName = spellName:gsub("^!+", "")
    spellName = TrimText(spellName)
    if not spellName or spellName == "" then
        return
    end

    table.insert(spellEntries, {
        spellName = spellName,
        bindingPriority = tonumber(bindingPriority) or 0,
    })
end

local function AddItemEntry(itemEntries, entryIndexByItemID, itemID, itemName, bindingPriority)
    if type(itemEntries) ~= "table" then
        return
    end

    itemID = tonumber(itemID)
    bindingPriority = tonumber(bindingPriority) or 0
    if itemID and itemID > 0 then
        local existingIndex = entryIndexByItemID[itemID]
        if existingIndex then
            local existingEntry = itemEntries[existingIndex]
            if existingEntry and bindingPriority > (existingEntry.bindingPriority or 0) then
                existingEntry.bindingPriority = bindingPriority
            end
            if existingEntry and type(itemName) == "string" and itemName ~= "" then
                existingEntry.itemName = itemName
            end
            return
        end

        entryIndexByItemID[itemID] = #itemEntries + 1
        table.insert(itemEntries, {
            itemID = itemID,
            itemName = itemName,
            bindingPriority = bindingPriority,
        })
        return
    end

    itemName = TrimText(itemName)
    if itemName and itemName ~= "" then
        table.insert(itemEntries, {
            itemName = itemName,
            bindingPriority = bindingPriority,
        })
    end
end

local function AddMacroSpellByName(spellIDs, seenSpellIDs, spellName)
    spellName = StripMacroConditionals(spellName)
    if not spellName or spellName == "" then
        return
    end

    AddSpellID(spellIDs, seenSpellIDs, ResolveSpellIDByName(spellName))
end

local function AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, spellName, bindingPriority)
    spellName = StripMacroConditionals(spellName)
    if not spellName or spellName == "" then
        return
    end

    AddSpellEntry(spellEntries, entryIndexBySpellID, ResolveSpellIDByName(spellName), bindingPriority)
    AddSpellNameEntry(spellEntries, spellName, bindingPriority)
end

local function AddMacroItemEntryByName(itemEntries, entryIndexByItemID, itemName, bindingPriority)
    itemName = StripMacroItemText(itemName)
    if not itemName or itemName == "" then
        return
    end

    AddItemEntry(itemEntries, entryIndexByItemID, ResolveItemIDByName(itemName), itemName, bindingPriority)
end

local function BuildSpellIDList(spellEntries)
    local spellIDs = {}
    if type(spellEntries) ~= "table" then
        return spellIDs
    end

    for _, entry in ipairs(spellEntries) do
        if type(entry) == "table" and type(entry.spellID) == "number" then
            table.insert(spellIDs, entry.spellID)
        end
    end

    return spellIDs
end

local function GetMacroIDFromToken(macroToken)
    if type(macroToken) == "number" and macroToken > 0 then
        return macroToken
    end

    macroToken = TrimText(macroToken)
    if not macroToken or macroToken == "" then
        return nil
    end

    local macroID = tonumber(macroToken)
    if macroID and macroID > 0 then
        return macroID
    end

    if GetMacroIndexByName then
        local ok, resolvedMacroID = pcall(GetMacroIndexByName, macroToken)
        if ok and type(resolvedMacroID) == "number" and resolvedMacroID > 0 then
            return resolvedMacroID
        end
    end

    return nil
end

local function GetMacroInfoSafe(macroID)
    if not GetMacroInfo then
        return nil, nil, nil
    end

    local ok, macroName, macroIcon, macroBody = pcall(GetMacroInfo, macroID)
    if ok then
        return macroName, macroIcon, macroBody
    end

    return nil, nil, nil
end

local function GetMacroBodyText(macroID)
    if GetMacroBody then
        local ok, macroBody = pcall(GetMacroBody, macroID)
        if ok and type(macroBody) == "string" and macroBody ~= "" then
            return macroBody
        end
    end

    local _, _, macroBody = GetMacroInfoSafe(macroID)
    if type(macroBody) == "string" and macroBody ~= "" then
        return macroBody
    end

    return nil
end

local function GetMacroPrimarySpell(macroID)
    if not GetMacroSpell then
        return nil
    end

    local ok, macroSpell = pcall(GetMacroSpell, macroID)
    if ok then
        return macroSpell
    end

    return nil
end

local function GetMacroPrimaryItem(macroID)
    if not GetMacroItem then
        return nil
    end

    local ok, itemName, itemLink = pcall(GetMacroItem, macroID)
    if not ok then
        return nil
    end

    return itemLink or itemName
end

local function AppendSpellEntries(spellEntries, entryIndexBySpellID, entries)
    if type(entries) ~= "table" then
        return
    end

    for _, entry in ipairs(entries) do
        if type(entry) == "table" then
            AddSpellEntry(spellEntries, entryIndexBySpellID, entry.spellID, entry.bindingPriority)
            AddSpellNameEntry(spellEntries, entry.spellName, entry.bindingPriority)
        end
    end
end

local function AppendItemEntries(itemEntries, entryIndexByItemID, entries)
    if type(entries) ~= "table" then
        return
    end

    for _, entry in ipairs(entries) do
        if type(entry) == "table" then
            AddItemEntry(itemEntries, entryIndexByItemID, entry.itemID, entry.itemName, entry.bindingPriority)
        end
    end
end

local function AddActionSlotSpellEntries(spellEntries, entryIndexBySpellID, slot, bindingPriority)
    if not GetActionSpell or type(slot) ~= "number" or slot <= 0 then
        return
    end

    local ok, spellName, spellSubName, spellID = pcall(GetActionSpell, slot)
    if not ok then
        return
    end

    if type(spellID) == "number" and spellID > 0 then
        AddSpellEntry(spellEntries, entryIndexBySpellID, spellID, bindingPriority)
    elseif type(spellName) == "number" and spellName > 0 then
        AddSpellEntry(spellEntries, entryIndexBySpellID, spellName, bindingPriority)
    end

    if type(spellName) == "string" and spellName ~= "" then
        AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, spellName, bindingPriority)
    end

    if type(spellSubName) == "string" and spellSubName ~= "" then
        AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, spellSubName, bindingPriority)
    end
end

local function AddMacroBodySpellEntries(spellEntries, entryIndexBySpellID, macroBody, bindingPriority)
    if type(macroBody) ~= "string" or macroBody == "" then
        return
    end

    for rawLine in macroBody:gmatch("[^\r\n]+") do
        local command, arguments = rawLine:match("^%s*/([%a]+!?)[%s,]*(.*)$")
        command = command and command:lower()
        if command and IsMacroSpellCommand(command) then
            local isSequence = command == "castsequence" or command == "castsequence!"
                or command == "castrandom" or command == "userandom"
            for clause in (arguments or ""):gmatch("[^;]+") do
                local spellText = isSequence and StripCastSequenceOptions(clause) or StripMacroConditionals(clause)
                if spellText and spellText ~= "" then
                    if isSequence then
                        for sequenceSpell in spellText:gmatch("[^,]+") do
                            AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, sequenceSpell, bindingPriority)
                        end
                    else
                        AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, spellText, bindingPriority)
                    end
                end
            end
        end
    end
end

local function AddActionSlotItemEntries(itemEntries, entryIndexByItemID, slot, bindingPriority)
    if not GetActionInfo or type(slot) ~= "number" or slot <= 0 then
        return
    end

    local ok, actionType, id = pcall(GetActionInfo, slot)
    if ok and actionType == "item" and type(id) == "number" and id > 0 then
        AddItemEntry(itemEntries, entryIndexByItemID, id, nil, bindingPriority)
    end
end

local function AddMacroBodyItemEntries(itemEntries, entryIndexByItemID, macroBody, bindingPriority)
    if type(macroBody) ~= "string" or macroBody == "" then
        return
    end

    for rawLine in macroBody:gmatch("[^\r\n]+") do
        local command, arguments = rawLine:match("^%s*/([%a]+!?)[%s,]*(.*)$")
        command = command and command:lower()
        if command == "use" or command == "userandom" then
            local isSequence = command == "userandom"
            for clause in (arguments or ""):gmatch("[^;]+") do
                local itemText = isSequence and StripCastSequenceOptions(clause) or StripMacroItemText(clause)
                if itemText and itemText ~= "" then
                    if isSequence then
                        for sequenceItem in itemText:gmatch("[^,]+") do
                            AddMacroItemEntryByName(itemEntries, entryIndexByItemID, sequenceItem, bindingPriority)
                        end
                    else
                        AddMacroItemEntryByName(itemEntries, entryIndexByItemID, itemText, bindingPriority)
                    end
                end
            end
        end
    end
end

function addon:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff7fd4ffMidnightRotation ArmsLab|r: " .. tostring(message))
end

local function FormatBool(value)
    return value and "yes" or "no"
end

local function FormatSafeValue(value, fallback)
    local ok, text = pcall(function()
        if value == nil then
            return tostring(fallback or 0)
        end

        return tostring(value)
    end)

    if ok then
        return text
    end

    return tostring(fallback or "?")
end

local function RoundTraceNumber(value, decimals)
    if type(value) ~= "number" then
        return value
    end

    local multiplier = 10 ^ (decimals or 1)
    return math.floor(value * multiplier + 0.5) / multiplier
end

function addon:ApplyDefaults()
    MidnightRotationArmsLabDB = MidnightRotationArmsLabDB or {}
    self.db = MidnightRotationArmsLabDB

    for key, value in pairs(defaults) do
        if self.db[key] == nil then
            self.db[key] = value
        end
    end

    local previousSettingsVersion = type(self.db.settingsVersion) == "number" and self.db.settingsVersion or 0
    if previousSettingsVersion < SETTINGS_VERSION then
        self.db.recommendMajorCooldowns = true
        if previousSettingsVersion < 3 then
            self.db.locked = false
            self.db.x = 180
        end
        if previousSettingsVersion < 5 and (tonumber(self.db.targetCountOverride or 0) or 0) <= 0 then
            self.db.targetCountOverride = 1
        end
        if previousSettingsVersion < 6 and self.db.traceMaxEntries == 2000 then
            self.db.traceMaxEntries = 6000
        end
        if previousSettingsVersion < 7 then
            self.db.targetCountOverride = 0
        end
        self.db.settingsVersion = SETTINGS_VERSION
    end

    if type(self.db.rotationTrace) ~= "table" then
        self.db.rotationTrace = {}
    end

    if type(self.db.rotationTrace.entries) ~= "table" then
        self.db.rotationTrace.entries = {}
    end
end

function addon:ResolveFontPath(fontInput)
    if type(fontInput) ~= "string" then
        return nil
    end

    local trimmed = fontInput:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil
    end

    local alias = trimmed:lower()
    return fontAliases[alias] or trimmed
end

function addon:FindBaseSpellID(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end

    if C_SpellBook and C_SpellBook.FindBaseSpellByID then
        local ok, baseSpellID = pcall(C_SpellBook.FindBaseSpellByID, spellID)
        if ok and type(baseSpellID) == "number" and baseSpellID > 0 then
            return baseSpellID
        end
    end

    return spellID
end

function addon:NormalizeKeybind(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    key = key:gsub("ALT%-", "A-")
    key = key:gsub("CTRL%-", "C-")
    key = key:gsub("SHIFT%-", "S-")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("BUTTON", "M")
    key = key:gsub("MOUSEWHEELUP", "WU")
    key = key:gsub("MOUSEWHEELDOWN", "WD")
    key = key:gsub("MIDDLEMOUSE", "MMB")
    key = key:gsub("SPACE", "SPC")
    key = key:gsub("BACKSPACE", "BSP")
    key = key:gsub("INSERT", "INS")
    key = key:gsub("DELETE", "DEL")
    key = key:gsub("PAGEDOWN", "PGDN")
    key = key:gsub("PAGEUP", "PGUP")

    return key
end

function addon:GetMacroSpellIDs(macroID)
    return BuildSpellIDList(self:GetMacroSpellEntries(macroID))
end

function addon:GetMacroSpellEntries(macroID)
    local spellEntries = {}
    local entryIndexBySpellID = {}
    local spellIDs = {}
    local seenSpellIDs = {}
    macroID = GetMacroIDFromToken(macroID)

    if not macroID then
        return spellEntries
    end

    local function addMacroNameFallback()
        if #spellEntries > 0 or not GetMacroInfo then
            return
        end

        local macroName = GetMacroInfoSafe(macroID)
        if macroName then
            AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, macroName, BINDING_PRIORITY_MACRO_NAME)
        end
    end

    local macroSpell = GetMacroPrimarySpell(macroID)
    if type(macroSpell) == "number" then
        AddSpellEntry(spellEntries, entryIndexBySpellID, macroSpell, BINDING_PRIORITY_MACRO_PRIMARY)
        AddSpellID(spellIDs, seenSpellIDs, macroSpell)
    elseif type(macroSpell) == "string" then
        local macroSpellID = ResolveSpellIDByName(macroSpell)
        AddSpellEntry(spellEntries, entryIndexBySpellID, macroSpellID, BINDING_PRIORITY_MACRO_PRIMARY)
        AddSpellNameEntry(spellEntries, macroSpell, BINDING_PRIORITY_MACRO_PRIMARY)
        AddSpellID(spellIDs, seenSpellIDs, macroSpellID)
    end

    local macroBody = GetMacroBodyText(macroID)
    if type(macroBody) ~= "string" or macroBody == "" then
        addMacroNameFallback()
        return spellEntries
    end

    for rawLine in macroBody:gmatch("[^\r\n]+") do
        local command, arguments = rawLine:match("^%s*/([%a]+!?)[%s,]*(.*)$")
        command = command and command:lower()
        if command and IsMacroSpellCommand(command) then
            local isSequence = command == "castsequence" or command == "castsequence!"
                or command == "castrandom" or command == "userandom"
            for clause in (arguments or ""):gmatch("[^;]+") do
                local spellText = isSequence and StripCastSequenceOptions(clause) or StripMacroConditionals(clause)
                if spellText and spellText ~= "" then
                    if isSequence then
                        for sequenceSpell in spellText:gmatch("[^,]+") do
                            AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, sequenceSpell, BINDING_PRIORITY_MACRO_BODY)
                            AddMacroSpellByName(spellIDs, seenSpellIDs, sequenceSpell)
                        end
                    else
                        AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, spellText, BINDING_PRIORITY_MACRO_BODY)
                        AddMacroSpellByName(spellIDs, seenSpellIDs, spellText)
                    end
                end
            end
        end
    end

    addMacroNameFallback()
    return spellEntries
end

function addon:GetActionSpellEntries(slot)
    if not slot or slot <= 0 then
        return {}
    end

    local spellEntries = {}
    local entryIndexBySpellID = {}
    local actionType, id, subType = GetActionInfo(slot)
    if actionType == "spell" and subType ~= "assistedcombat" then
        AddSpellEntry(spellEntries, entryIndexBySpellID, id, BINDING_PRIORITY_DIRECT_SPELL)
        AddActionSlotSpellEntries(spellEntries, entryIndexBySpellID, slot, BINDING_PRIORITY_DIRECT_SPELL)
        return spellEntries
    end

    if actionType == "macro" and id then
        AppendSpellEntries(spellEntries, entryIndexBySpellID, self:GetMacroSpellEntries(id))

        if GetActionText then
            local ok, actionText = pcall(GetActionText, slot)
            if ok and type(actionText) == "string" and actionText ~= "" then
                AppendSpellEntries(spellEntries, entryIndexBySpellID, self:GetMacroSpellEntriesByToken(actionText))
            end
        end

        AddActionSlotSpellEntries(spellEntries, entryIndexBySpellID, slot, BINDING_PRIORITY_MACRO_PRIMARY)
        return spellEntries
    end

    AddActionSlotSpellEntries(spellEntries, entryIndexBySpellID, slot, BINDING_PRIORITY_DIRECT_SPELL)
    return spellEntries
end

function addon:GetMacroItemEntries(macroID)
    local itemEntries = {}
    local entryIndexByItemID = {}
    macroID = GetMacroIDFromToken(macroID)

    if not macroID then
        return itemEntries
    end

    local macroItem = GetMacroPrimaryItem(macroID)
    if macroItem then
        AddMacroItemEntryByName(itemEntries, entryIndexByItemID, macroItem, BINDING_PRIORITY_MACRO_PRIMARY)
    end

    local macroBody = GetMacroBodyText(macroID)
    AddMacroBodyItemEntries(itemEntries, entryIndexByItemID, macroBody, BINDING_PRIORITY_MACRO_BODY)
    return itemEntries
end

function addon:GetMacroItemEntriesByToken(macroToken)
    local macroID = GetMacroIDFromToken(macroToken)
    if macroID then
        return self:GetMacroItemEntries(macroID)
    end

    local itemEntries = {}
    local entryIndexByItemID = {}
    AddMacroItemEntryByName(itemEntries, entryIndexByItemID, macroToken, BINDING_PRIORITY_MACRO_NAME)
    return itemEntries
end

function addon:GetActionItemEntries(slot)
    if not slot or slot <= 0 then
        return {}
    end

    local itemEntries = {}
    local entryIndexByItemID = {}
    local actionType, id = GetActionInfo(slot)
    if actionType == "item" and type(id) == "number" and id > 0 then
        AddItemEntry(itemEntries, entryIndexByItemID, id, nil, BINDING_PRIORITY_DIRECT_SPELL)
        return itemEntries
    end

    if actionType == "macro" and id then
        AppendItemEntries(itemEntries, entryIndexByItemID, self:GetMacroItemEntries(id))

        if GetActionText then
            local ok, actionText = pcall(GetActionText, slot)
            if ok and type(actionText) == "string" and actionText ~= "" then
                AppendItemEntries(itemEntries, entryIndexByItemID, self:GetMacroItemEntriesByToken(actionText))
            end
        end

        AddActionSlotItemEntries(itemEntries, entryIndexByItemID, slot, BINDING_PRIORITY_MACRO_PRIMARY)
        return itemEntries
    end

    AddActionSlotItemEntries(itemEntries, entryIndexByItemID, slot, BINDING_PRIORITY_DIRECT_SPELL)
    return itemEntries
end

function addon:GetMacroSpellEntriesByToken(macroToken)
    local macroID = GetMacroIDFromToken(macroToken)
    if macroID then
        return self:GetMacroSpellEntries(macroID)
    end

    local spellEntries = {}
    local entryIndexBySpellID = {}
    AddMacroSpellEntryByName(spellEntries, entryIndexBySpellID, macroToken, BINDING_PRIORITY_MACRO_NAME)
    return spellEntries
end

function addon:GetSecureButtonSpellEntries(button, clickButton)
    if not button then
        return {}
    end

    if button.action and HasAction(button.action) then
        return self:GetActionSpellEntries(button.action)
    end

    if not button.GetAttribute then
        return {}
    end

    local function getAttribute(attributeName)
        local attributeNames = { attributeName }
        local suffixes = clickButton and clickButtonAttributeSuffixes[clickButton]
        if suffixes then
            for _, suffix in ipairs(suffixes) do
                table.insert(attributeNames, attributeName .. suffix)
            end
        end

        for _, candidateAttributeName in ipairs(attributeNames) do
            local ok, value = pcall(button.GetAttribute, button, candidateAttributeName)
            if ok and value ~= nil then
                return value
            end
        end

        return nil
    end

    local action = getAttribute("action") or getAttribute("action1")
    if type(action) == "number" and HasAction(action) then
        return self:GetActionSpellEntries(action)
    end

    local spell = getAttribute("spell") or getAttribute("spell1")
    if spell then
        local spellEntries = {}
        local entryIndexBySpellID = {}
        local spellID = tonumber(spell) or ResolveSpellIDByName(spell)
        AddSpellEntry(spellEntries, entryIndexBySpellID, spellID, BINDING_PRIORITY_DIRECT_SPELL)
        if type(spell) == "string" then
            AddSpellNameEntry(spellEntries, spell, BINDING_PRIORITY_DIRECT_SPELL)
        end
        return spellEntries
    end

    local macroToken = getAttribute("macro") or getAttribute("macro1")
    local macroEntries = self:GetMacroSpellEntriesByToken(macroToken)
    if #macroEntries > 0 then
        return macroEntries
    end

    local macroText = getAttribute("macrotext") or getAttribute("macrotext1")
    if type(macroText) == "string" and macroText ~= "" then
        local spellEntries = {}
        local entryIndexBySpellID = {}
        AddMacroBodySpellEntries(spellEntries, entryIndexBySpellID, macroText, BINDING_PRIORITY_MACRO_BODY)
        return spellEntries
    end

    return {}
end

function addon:GetSecureButtonItemEntries(button, clickButton)
    if not button then
        return {}
    end

    if button.action and HasAction(button.action) then
        return self:GetActionItemEntries(button.action)
    end

    if not button.GetAttribute then
        return {}
    end

    local function getAttribute(attributeName)
        local attributeNames = { attributeName }
        local suffixes = clickButton and clickButtonAttributeSuffixes[clickButton]
        if suffixes then
            for _, suffix in ipairs(suffixes) do
                table.insert(attributeNames, attributeName .. suffix)
            end
        end

        for _, candidateAttributeName in ipairs(attributeNames) do
            local ok, value = pcall(button.GetAttribute, button, candidateAttributeName)
            if ok and value ~= nil then
                return value
            end
        end

        return nil
    end

    local action = getAttribute("action") or getAttribute("action1")
    if type(action) == "number" and HasAction(action) then
        return self:GetActionItemEntries(action)
    end

    local item = getAttribute("item") or getAttribute("item1")
    if item then
        local itemEntries = {}
        local entryIndexByItemID = {}
        AddMacroItemEntryByName(itemEntries, entryIndexByItemID, item, BINDING_PRIORITY_DIRECT_SPELL)
        return itemEntries
    end

    local macroToken = getAttribute("macro") or getAttribute("macro1")
    local macroEntries = self:GetMacroItemEntriesByToken(macroToken)
    if #macroEntries > 0 then
        return macroEntries
    end

    local macroText = getAttribute("macrotext") or getAttribute("macrotext1")
    if type(macroText) == "string" and macroText ~= "" then
        local itemEntries = {}
        local entryIndexByItemID = {}
        AddMacroBodyItemEntries(itemEntries, entryIndexByItemID, macroText, BINDING_PRIORITY_MACRO_BODY)
        return itemEntries
    end

    return {}
end

function addon:GetActionSpellIDs(slot)
    return BuildSpellIDList(self:GetActionSpellEntries(slot))
end

function addon:GetActionSpellID(slot)
    local spellIDs = self:GetActionSpellIDs(slot)
    return spellIDs and spellIDs[1] or nil
end

function addon:GetBindingActionForButton(prefix, index, button)
    if button and type(button.bindingAction) == "string" and button.bindingAction ~= "" then
        return button.bindingAction
    end

    local bindingPrefix = bindingActionPrefixes[prefix]
    if not bindingPrefix then
        return nil
    end

    return bindingPrefix .. tostring(index)
end

function addon:RememberBinding(spellID, keybind, bindingPriority)
    if type(spellID) ~= "number" or spellID <= 0 then
        return
    end

    local normalized = self:NormalizeKeybind(keybind)
    if not normalized or normalized == "" then
        return
    end

    bindingPriority = tonumber(bindingPriority) or 0
    local baseSpellID = self:FindBaseSpellID(spellID)
    local existingPriority = self.bindingPriorityBySpell[spellID]
    if existingPriority and existingPriority > bindingPriority then
        return
    end

    self.bindingBySpell[spellID] = normalized
    self.bindingPriorityBySpell[spellID] = bindingPriority

    if baseSpellID then
        local existingBasePriority = self.bindingPriorityByBaseSpell[baseSpellID]
        if existingBasePriority and existingBasePriority > bindingPriority then
            return
        end

        self.bindingByBaseSpell[baseSpellID] = normalized
        self.bindingPriorityByBaseSpell[baseSpellID] = bindingPriority
    end

    if self.RememberSpellNameForSpellID then
        self:RememberSpellNameForSpellID(spellID, normalized, bindingPriority)
    end
end

function addon:RememberSpellNameBinding(spellName, keybind, bindingPriority)
    local normalizedName = NormalizeSpellLookupName(spellName)
    if not normalizedName then
        return
    end

    local normalizedKeybind = self:NormalizeKeybind(keybind)
    if not normalizedKeybind or normalizedKeybind == "" then
        return
    end

    bindingPriority = tonumber(bindingPriority) or 0
    local existingPriority = self.bindingPriorityBySpellName[normalizedName]
    if existingPriority and existingPriority > bindingPriority then
        return
    end

    self.bindingBySpellName[normalizedName] = normalizedKeybind
    self.bindingPriorityBySpellName[normalizedName] = bindingPriority
end

function addon:RememberSpellNameForSpellID(spellID, keybind, bindingPriority)
    if type(spellID) ~= "number" or spellID <= 0 or not C_Spell or not C_Spell.GetSpellInfo then
        return
    end

    local function rememberName(candidateSpellID)
        if type(candidateSpellID) ~= "number" or candidateSpellID <= 0 then
            return
        end

        local ok, spellInfo = pcall(C_Spell.GetSpellInfo, candidateSpellID)
        if ok and spellInfo and spellInfo.name then
            self:RememberSpellNameBinding(spellInfo.name, keybind, bindingPriority)
        end
    end

    rememberName(spellID)
    rememberName(self:FindBaseSpellID(spellID))
end

function addon:RememberActionSlot(spellID, slot)
    if type(spellID) ~= "number" or spellID <= 0 or type(slot) ~= "number" or slot <= 0 then
        return
    end

    local baseSpellID = self:FindBaseSpellID(spellID)

    self.actionSlotsBySpell[spellID] = self.actionSlotsBySpell[spellID] or {}
    self.actionSlotsBySpell[spellID][slot] = true

    if baseSpellID then
        self.actionSlotsByBaseSpell[baseSpellID] = self.actionSlotsByBaseSpell[baseSpellID] or {}
        self.actionSlotsByBaseSpell[baseSpellID][slot] = true
    end
end

function addon:RememberActionButton(spellID, button)
    if type(spellID) ~= "number" or spellID <= 0 or not button then
        return
    end

    local baseSpellID = self:FindBaseSpellID(spellID)

    self.actionButtonsBySpell[spellID] = self.actionButtonsBySpell[spellID] or {}
    self.actionButtonsBySpell[spellID][button] = true

    if baseSpellID then
        self.actionButtonsByBaseSpell[baseSpellID] = self.actionButtonsByBaseSpell[baseSpellID] or {}
        self.actionButtonsByBaseSpell[baseSpellID][button] = true
    end
end

function addon:RememberActionSpellName(spellID)
    if type(spellID) ~= "number" or spellID <= 0 or not C_Spell or not C_Spell.GetSpellInfo then
        return
    end

    local function rememberNameForID(candidateSpellID, actionSpellID)
        if type(candidateSpellID) ~= "number" or candidateSpellID <= 0 then
            return
        end

        local ok, spellInfo = pcall(C_Spell.GetSpellInfo, candidateSpellID)
        local normalizedName = ok and spellInfo and NormalizeSpellLookupName(spellInfo.name)
        if normalizedName and not self.actionSpellIDsByName[normalizedName] then
            self.actionSpellIDsByName[normalizedName] = actionSpellID or spellID
        end
    end

    rememberNameForID(spellID, spellID)
    rememberNameForID(self:FindBaseSpellID(spellID), spellID)
end

function addon:RememberItemNameBinding(itemName, keybind, bindingPriority)
    local normalizedName = NormalizeSpellLookupName(itemName)
    if not normalizedName then
        return
    end

    local normalizedKeybind = self:NormalizeKeybind(keybind)
    if not normalizedKeybind or normalizedKeybind == "" then
        return
    end

    bindingPriority = tonumber(bindingPriority) or 0
    local existingPriority = self.bindingPriorityByItemName[normalizedName]
    if existingPriority and existingPriority > bindingPriority then
        return
    end

    self.bindingByItemName[normalizedName] = normalizedKeybind
    self.bindingPriorityByItemName[normalizedName] = bindingPriority
end

function addon:GetItemNameSafe(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return nil
    end

    if C_Item and C_Item.GetItemInfo then
        local ok, itemName = pcall(C_Item.GetItemInfo, itemID)
        if ok and type(itemName) == "string" and itemName ~= "" then
            return itemName
        end
    end

    if GetItemInfo then
        local ok, itemName = pcall(GetItemInfo, itemID)
        if ok and type(itemName) == "string" and itemName ~= "" then
            return itemName
        end
    end

    return nil
end

function addon:RememberItemBinding(itemID, itemName, keybind, bindingPriority)
    itemID = tonumber(itemID)
    local normalized = self:NormalizeKeybind(keybind)
    if not normalized or normalized == "" then
        return
    end

    bindingPriority = tonumber(bindingPriority) or 0
    if itemID and itemID > 0 then
        local existingPriority = self.bindingPriorityByItem[itemID]
        if existingPriority and existingPriority > bindingPriority then
            return
        end

        self.bindingByItem[itemID] = normalized
        self.bindingPriorityByItem[itemID] = bindingPriority
        itemName = itemName or self:GetItemNameSafe(itemID)
    end

    self:RememberItemNameBinding(itemName, normalized, bindingPriority)
end

function addon:RememberActionItemName(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return
    end

    local itemName = self:GetItemNameSafe(itemID)
    local normalizedName = NormalizeSpellLookupName(itemName)
    if normalizedName and not self.actionItemIDsByName[normalizedName] then
        self.actionItemIDsByName[normalizedName] = itemID
    end
end

function addon:RememberBindingsForItemEntries(itemEntries, keybind)
    if type(itemEntries) ~= "table" then
        return
    end

    for _, itemEntry in ipairs(itemEntries) do
        self:RememberItemBinding(itemEntry and itemEntry.itemID, itemEntry and itemEntry.itemName, keybind, itemEntry and itemEntry.bindingPriority)
    end
end

function addon:RememberBindingsForSpellEntries(spellEntries, keybind)
    if type(spellEntries) ~= "table" then
        return
    end

    for _, spellEntry in ipairs(spellEntries) do
        local spellID = spellEntry and spellEntry.spellID
        local spellName = spellEntry and spellEntry.spellName
        if spellID then
            self:RememberBinding(spellID, keybind, spellEntry.bindingPriority)
        end
        if spellName then
            self:RememberSpellNameBinding(spellName, keybind, spellEntry.bindingPriority)
        end
    end
end

function addon:ScanBindingCommands()
    if not GetNumBindings or not GetBinding then
        return
    end

    local bindingCount = GetNumBindings()
    if type(bindingCount) ~= "number" or bindingCount <= 0 then
        return
    end

    for bindingIndex = 1, bindingCount do
        local bindingAction, key1, key2, key3, key4 = GetBinding(bindingIndex)
        if type(bindingAction) == "string" and bindingAction ~= "" then
            local spellEntries = nil
            local itemEntries = nil
            local macroToken = bindingAction:match("^MACRO%s+(.+)$")
            if macroToken then
                spellEntries = self:GetMacroSpellEntriesByToken(macroToken)
                itemEntries = self:GetMacroItemEntriesByToken(macroToken)
            end

            if not spellEntries then
                local spellName = bindingAction:match("^SPELL%s+(.+)$")
                if spellName then
                    spellEntries = {}
                    local entryIndexBySpellID = {}
                    AddSpellEntry(spellEntries, entryIndexBySpellID, ResolveSpellIDByName(spellName), BINDING_PRIORITY_DIRECT_SPELL)
                    AddSpellNameEntry(spellEntries, spellName, BINDING_PRIORITY_DIRECT_SPELL)
                end
            end

            if not spellEntries then
                local buttonName, clickButton = bindingAction:match("^CLICK%s+([^:]+):(.+)$")
                local button = buttonName and _G[buttonName]
                if button then
                    spellEntries = self:GetSecureButtonSpellEntries(button, clickButton)
                    itemEntries = self:GetSecureButtonItemEntries(button, clickButton)
                end
            end

            if spellEntries and #spellEntries > 0 then
                self:RememberBindingsForSpellEntries(spellEntries, key1)
                self:RememberBindingsForSpellEntries(spellEntries, key2)
                self:RememberBindingsForSpellEntries(spellEntries, key3)
                self:RememberBindingsForSpellEntries(spellEntries, key4)
            end

            if itemEntries and #itemEntries > 0 then
                self:RememberBindingsForItemEntries(itemEntries, key1)
                self:RememberBindingsForItemEntries(itemEntries, key2)
                self:RememberBindingsForItemEntries(itemEntries, key3)
                self:RememberBindingsForItemEntries(itemEntries, key4)
            end
        end
    end
end

function addon:ScanActionBars()
    WipeTable(self.bindingBySpell)
    WipeTable(self.bindingByBaseSpell)
    WipeTable(self.bindingBySpellName)
    WipeTable(self.bindingByItem)
    WipeTable(self.bindingByItemName)
    WipeTable(self.bindingPriorityBySpell)
    WipeTable(self.bindingPriorityByBaseSpell)
    WipeTable(self.bindingPriorityBySpellName)
    WipeTable(self.bindingPriorityByItem)
    WipeTable(self.bindingPriorityByItemName)
    WipeTable(self.actionSlotsBySpell)
    WipeTable(self.actionSlotsByBaseSpell)
    WipeTable(self.actionButtonsBySpell)
    WipeTable(self.actionButtonsByBaseSpell)
    WipeTable(self.actionSpellIDsByName)
    WipeTable(self.actionItemIDsByName)

    for _, prefix in ipairs(actionBarPrefixes) do
        for index = 1, 12 do
            local button = _G[prefix .. "Button" .. index]
            if button and button.action and HasAction(button.action) then
                local spellEntries = self:GetActionSpellEntries(button.action)
                local itemEntries = self:GetActionItemEntries(button.action)
                local bindingAction = self:GetBindingActionForButton(prefix, index, button)
                local key1, key2, key3, key4 = nil, nil, nil, nil
                if bindingAction then
                    key1, key2, key3, key4 = GetBindingKey(bindingAction)
                    self:RememberBindingsForSpellEntries(spellEntries, key1)
                    self:RememberBindingsForSpellEntries(spellEntries, key2)
                    self:RememberBindingsForSpellEntries(spellEntries, key3)
                    self:RememberBindingsForSpellEntries(spellEntries, key4)
                    self:RememberBindingsForItemEntries(itemEntries, key1)
                    self:RememberBindingsForItemEntries(itemEntries, key2)
                    self:RememberBindingsForItemEntries(itemEntries, key3)
                    self:RememberBindingsForItemEntries(itemEntries, key4)
                end

                for _, spellEntry in ipairs(spellEntries) do
                    local spellID = spellEntry and spellEntry.spellID
                    if spellID and bindingAction then
                        self:RememberBinding(spellID, key1 or key2 or key3 or key4, spellEntry.bindingPriority)
                    end

                    if spellID then
                        self:RememberActionSlot(spellID, button.action)
                        self:RememberActionButton(spellID, button)
                        self:RememberActionSpellName(spellID)
                    end
                end

                for _, itemEntry in ipairs(itemEntries) do
                    local itemID = itemEntry and itemEntry.itemID
                    if itemID and bindingAction then
                        self:RememberItemBinding(itemID, itemEntry.itemName, key1 or key2 or key3 or key4, itemEntry.bindingPriority)
                    end

                    if itemID then
                        self:RememberActionItemName(itemID)
                    end
                end
            end
        end
    end

    -- EllesmereUI Action Bars uses its own EABButton frames. Index its action
    -- slots for spell resolution and proc counts without reading btn.action,
    -- which can be protected while in combat.
    if _G.EABButton1 then
        for slot = 1, 180 do
            if HasAction(slot) then
                local actionType, spellID, subType = GetActionInfo(slot)
                local spellEntries = nil
                if actionType == "spell" and subType ~= "assistedcombat" then
                    spellEntries = { { spellID = spellID } }
                elseif actionType == "macro" then
                    spellEntries = self:GetActionSpellEntries(slot)
                end

                if spellEntries then
                    for _, spellEntry in ipairs(spellEntries) do
                        local actionSpellID = spellEntry and spellEntry.spellID
                        if actionSpellID then
                            self:RememberActionSlot(actionSpellID, slot)
                            self:RememberActionSpellName(actionSpellID)
                        end
                    end
                end

                local bindingAction = nil
                if slot >= 13 and slot <= 24 then
                    bindingAction = "EUI_BAR9_BUTTON" .. (slot - 12)
                elseif slot >= 109 and slot <= 120 then
                    bindingAction = "EUI_BAR10_BUTTON" .. (slot - 108)
                end

                if bindingAction then
                    local key1, key2, key3, key4 = GetBindingKey(bindingAction)
                    if spellEntries then
                        self:RememberBindingsForSpellEntries(spellEntries, key1)
                        self:RememberBindingsForSpellEntries(spellEntries, key2)
                        self:RememberBindingsForSpellEntries(spellEntries, key3)
                        self:RememberBindingsForSpellEntries(spellEntries, key4)
                    end
                    local itemEntries = self:GetActionItemEntries(slot)
                    self:RememberBindingsForItemEntries(itemEntries, key1)
                    self:RememberBindingsForItemEntries(itemEntries, key2)
                    self:RememberBindingsForItemEntries(itemEntries, key3)
                    self:RememberBindingsForItemEntries(itemEntries, key4)
                end
            end
        end
    end

    self:ScanBindingCommands()
end

function addon:GetActionSpellIDByName(spellNames)
    if type(spellNames) == "string" then
        spellNames = { spellNames }
    end

    if type(spellNames) ~= "table" then
        return nil
    end

    for _, spellName in ipairs(spellNames) do
        local normalizedName = NormalizeSpellLookupName(spellName)
        local spellID = normalizedName and self.actionSpellIDsByName[normalizedName]
        if type(spellID) == "number" and spellID > 0 then
            return spellID
        end
    end

    return nil
end

function addon:GetActionItemIDByName(itemNames)
    if type(itemNames) == "string" then
        itemNames = { itemNames }
    end

    if type(itemNames) ~= "table" then
        return nil
    end

    for _, itemName in ipairs(itemNames) do
        local normalizedName = NormalizeSpellLookupName(itemName)
        local itemID = normalizedName and self.actionItemIDsByName[normalizedName]
        if type(itemID) == "number" and itemID > 0 then
            return itemID, itemName
        end
    end

    return nil
end

local function AddLookupSpellName(lookupNames, spellID)
    if type(spellID) ~= "number" or spellID <= 0 or not C_Spell or not C_Spell.GetSpellInfo then
        return
    end

    local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
    local normalizedName = ok and spellInfo and NormalizeSpellLookupName(spellInfo.name)
    if normalizedName then
        lookupNames[normalizedName] = true
    end
end

local function SpellEntriesMatchLookup(spellEntries, spellID, baseSpellID, lookupNames)
    if type(spellEntries) ~= "table" then
        return false
    end

    for _, spellEntry in ipairs(spellEntries) do
        local entrySpellID = spellEntry and spellEntry.spellID
        if type(entrySpellID) == "number" and entrySpellID > 0 then
            local entryBaseSpellID = addon.FindBaseSpellID and addon:FindBaseSpellID(entrySpellID) or entrySpellID
            if entrySpellID == spellID or entrySpellID == baseSpellID or entryBaseSpellID == spellID or entryBaseSpellID == baseSpellID then
                return true
            end
        end

        local normalizedName = NormalizeSpellLookupName(spellEntry and spellEntry.spellName)
        if normalizedName and lookupNames[normalizedName] then
            return true
        end
    end

    return false
end

local function FirstNormalizedKeybind(self, key1, key2, key3, key4)
    return self:NormalizeKeybind(key1)
        or self:NormalizeKeybind(key2)
        or self:NormalizeKeybind(key3)
        or self:NormalizeKeybind(key4)
end

function addon:FindBindingCommandKeybindForSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 or not GetNumBindings or not GetBinding then
        return nil
    end

    local baseSpellID = self:FindBaseSpellID(spellID)
    local lookupNames = {}
    AddLookupSpellName(lookupNames, spellID)
    AddLookupSpellName(lookupNames, baseSpellID)

    local bindingCount = GetNumBindings()
    if type(bindingCount) ~= "number" or bindingCount <= 0 then
        return nil
    end

    for bindingIndex = 1, bindingCount do
        local bindingAction, key1, key2, key3, key4 = GetBinding(bindingIndex)
        if type(bindingAction) == "string" and bindingAction ~= "" then
            local matched = false
            local macroToken = bindingAction:match("^MACRO%s+(.+)$")
            if macroToken then
                matched = SpellEntriesMatchLookup(self:GetMacroSpellEntriesByToken(macroToken), spellID, baseSpellID, lookupNames)
            end

            if not matched then
                local spellName = bindingAction:match("^SPELL%s+(.+)$")
                local normalizedSpellName = NormalizeSpellLookupName(spellName)
                matched = normalizedSpellName and lookupNames[normalizedSpellName]
            end

            if not matched then
                local buttonName, clickButton = bindingAction:match("^CLICK%s+([^:]+):(.+)$")
                local button = buttonName and _G[buttonName]
                if button then
                    matched = SpellEntriesMatchLookup(self:GetSecureButtonSpellEntries(button, clickButton), spellID, baseSpellID, lookupNames)
                end
            end

            if matched then
                local keybind = FirstNormalizedKeybind(self, key1, key2, key3, key4)
                if keybind then
                    return keybind
                end
            end
        end
    end

    return nil
end

function addon:FindVisibleActionButtonKeybindForSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end

    local baseSpellID = self:FindBaseSpellID(spellID)
    local lookupNames = {}
    AddLookupSpellName(lookupNames, spellID)
    AddLookupSpellName(lookupNames, baseSpellID)

    -- Prefer the spell currently shown on a visible button. This matters for
    -- Rogue stealth paging, where cached spell/name maps can contain both the
    -- normal and stealth pages even though only one binding is active.
    for _, prefix in ipairs(actionBarPrefixes) do
        for index = 1, 12 do
            local button = _G[prefix .. "Button" .. index]
            local visible = false
            if button and button.IsShown then
                local ok, shown = pcall(button.IsShown, button)
                visible = ok and shown == true
            end

            if visible and button.action and HasAction(button.action) then
                local entries = self:GetActionSpellEntries(button.action)
                if SpellEntriesMatchLookup(entries, spellID, baseSpellID, lookupNames) then
                    local bindingAction = self:GetBindingActionForButton(prefix, index, button)
                    if bindingAction then
                        local key1, key2, key3, key4 = GetBindingKey(bindingAction)
                        local keybind = FirstNormalizedKeybind(self, key1, key2, key3, key4)
                        if keybind then
                            return keybind
                        end
                    end
                end
            end
        end
    end

    -- Ellesmere replaces the visible Blizzard action buttons with protected
    -- EABButton frames. Their secure action attribute tracks the live page
    -- (including Rogue stealth pages), while the binding attribute retains
    -- the physical command assigned to that button. Resolve both together so
    -- the recommendation uses the key for the action the player can see.
    for index = 1, 12 do
        local button = _G["EABButton" .. index]
        if button then
            local visible = false
            if button.IsShown then
                local ok, shown = pcall(button.IsShown, button)
                visible = ok and shown == true
            end

            if visible and button.GetAttribute then
                local actionOK, actionSlot = pcall(button.GetAttribute, button, "action")
                if actionOK then
                    local slotOK, numericSlot = pcall(tonumber, actionSlot)
                    actionSlot = slotOK and numericSlot or nil
                else
                    actionSlot = nil
                end
                if actionSlot and actionSlot > 0 then
                    local entriesOK, entries = pcall(self.GetActionSpellEntries, self, actionSlot)
                    if entriesOK and SpellEntriesMatchLookup(entries, spellID, baseSpellID, lookupNames) then
                        local bindingAction = nil
                        local bindingOK, binding = pcall(button.GetAttribute, button, "binding")
                        if bindingOK and type(binding) == "string" and binding ~= "" then
                            bindingAction = binding
                        elseif type(button.commandName) == "string" and button.commandName ~= "" then
                            bindingAction = button.commandName
                        end

                        if bindingAction then
                            local keyOK, key1, key2, key3, key4 = pcall(GetBindingKey, bindingAction)
                            if keyOK then
                                local keybind = FirstNormalizedKeybind(self, key1, key2, key3, key4)
                                if keybind then
                                    return keybind
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

function addon:GetKeybindText(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end

    local visibleKeybind = self:FindVisibleActionButtonKeybindForSpell(spellID)
    if visibleKeybind then
        return visibleKeybind
    end

    local baseSpellID = self:FindBaseSpellID(spellID)
    local keybind = self.bindingBySpell[spellID] or self.bindingByBaseSpell[baseSpellID]
    if keybind then
        return keybind
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local function getKeybindBySpellName(candidateSpellID)
            if type(candidateSpellID) ~= "number" or candidateSpellID <= 0 then
                return nil
            end

            local ok, spellInfo = pcall(C_Spell.GetSpellInfo, candidateSpellID)
            local normalizedName = ok and spellInfo and NormalizeSpellLookupName(spellInfo.name)
            return normalizedName and self.bindingBySpellName[normalizedName]
        end

        keybind = getKeybindBySpellName(spellID) or getKeybindBySpellName(baseSpellID)
        if keybind then
            return keybind
        end
    end

    return self:FindBindingCommandKeybindForSpell(spellID)
end

function addon:GetItemKeybindText(itemID, itemName)
    itemID = tonumber(itemID)
    local keybind = itemID and self.bindingByItem[itemID] or nil
    if keybind then
        return keybind
    end

    local normalizedName = NormalizeSpellLookupName(itemName or (itemID and self:GetItemNameSafe(itemID)))
    return normalizedName and self.bindingByItemName[normalizedName] or nil
end

function addon:GetItemIconSafe(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return nil
    end

    if C_Item and C_Item.GetItemIconByID then
        local ok, iconID = pcall(C_Item.GetItemIconByID, itemID)
        if ok and iconID then
            return iconID
        end
    end

    if GetItemIcon then
        local ok, iconID = pcall(GetItemIcon, itemID)
        if ok and iconID then
            return iconID
        end
    end

    return nil
end

function addon:GetItemCountSafe(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return 0
    end

    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(C_Item.GetItemCount, itemID, false, false)
        if ok and type(count) == "number" then
            return count
        end
    end

    if GetItemCount then
        local ok, count = pcall(GetItemCount, itemID, false, false)
        if ok and type(count) == "number" then
            return count
        end
    end

    return 0
end

function addon:IsItemUsableSafe(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return false
    end

    if C_Item and C_Item.IsUsableItem then
        local ok, usable = pcall(C_Item.IsUsableItem, itemID)
        if ok then
            return usable == true
        end
    end

    if IsUsableItem then
        local ok, usable = pcall(IsUsableItem, itemID)
        if ok then
            return usable == true
        end
    end

    return true
end

function addon:IsItemReady(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or self:GetItemCountSafe(itemID) <= 0 or not self:IsItemUsableSafe(itemID) then
        return false
    end

    local startTime, duration, enabled = 0, 0, 1
    if C_Item and C_Item.GetItemCooldown then
        local ok, start, dur, en = pcall(C_Item.GetItemCooldown, itemID)
        if ok then
            startTime, duration, enabled = start or 0, dur or 0, en or 1
        end
    elseif GetItemCooldown then
        local ok, start, dur, en = pcall(GetItemCooldown, itemID)
        if ok then
            startTime, duration, enabled = start or 0, dur or 0, en or 1
        end
    end

    if enabled == 0 then
        return false
    end

    if startTime <= 0 or duration <= 0 then
        return true
    end

    return ((startTime + duration) - GetTime()) <= 0.05
end

local function AddRawLookupSpellName(lookupNames, spellName)
    local normalizedName = NormalizeSpellLookupName(spellName)
    if normalizedName then
        lookupNames[normalizedName] = true
    end
end

local function TextMatchesLookup(text, lookupNames)
    local normalizedText = NormalizeSpellLookupName(text)
    if not normalizedText or type(lookupNames) ~= "table" then
        return false
    end

    if lookupNames[normalizedText] then
        return true
    end

    for lookupName in pairs(lookupNames) do
        if lookupName ~= "" and normalizedText:find(lookupName, 1, true) then
            return true
        end
    end

    return false
end

local function FormatDebugValue(value)
    if value == nil then
        return "nil"
    end

    local text = tostring(value):gsub("[\r\n]+", "\\n")
    if #text > 56 then
        return text:sub(1, 53) .. "..."
    end

    return text
end

local function FormatDebugKeybinds(self, key1, key2, key3, key4)
    return self:NormalizeKeybind(key1)
        or self:NormalizeKeybind(key2)
        or self:NormalizeKeybind(key3)
        or self:NormalizeKeybind(key4)
        or "none"
end

local function FormatDebugSpellEntries(spellEntries)
    if type(spellEntries) ~= "table" or #spellEntries == 0 then
        return "none"
    end

    local parts = {}
    for entryIndex, spellEntry in ipairs(spellEntries) do
        if entryIndex > 6 then
            table.insert(parts, "...")
            break
        end

        local entryParts = {}
        local spellID = spellEntry and spellEntry.spellID
        if type(spellID) == "number" then
            local spellName = nil
            if C_Spell and C_Spell.GetSpellInfo then
                local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
                spellName = ok and spellInfo and spellInfo.name or nil
            end
            table.insert(entryParts, tostring(spellID) .. (spellName and (":" .. spellName) or ""))
        end
        if spellEntry and spellEntry.spellName then
            table.insert(entryParts, '"' .. tostring(spellEntry.spellName) .. '"')
        end
        table.insert(parts, table.concat(entryParts, "/"))
    end

    return table.concat(parts, ", ")
end

local function AddDebugAttributeName(attributeNames, seenAttributeNames, attributeName)
    if attributeName and not seenAttributeNames[attributeName] then
        seenAttributeNames[attributeName] = true
        table.insert(attributeNames, attributeName)
    end
end

local function BuildDebugAttributeNames(attributeName, clickButton)
    local attributeNames = {}
    local seenAttributeNames = {}
    AddDebugAttributeName(attributeNames, seenAttributeNames, attributeName)

    local suffixes = clickButton and clickButtonAttributeSuffixes[clickButton]
    if suffixes then
        for _, suffix in ipairs(suffixes) do
            AddDebugAttributeName(attributeNames, seenAttributeNames, attributeName .. suffix)
        end
    end

    return attributeNames
end

local function DescribeSecureButtonForDebug(button, clickButton)
    if not button then
        return "button=nil"
    end

    local parts = {}
    if button.action ~= nil then
        local actionText = "field.action=" .. FormatDebugValue(button.action)
        if GetActionInfo and HasAction and HasAction(button.action) then
            local actionType, id, subType = GetActionInfo(button.action)
            actionText = actionText .. "/" .. FormatDebugValue(actionType) .. "/" .. FormatDebugValue(id) .. "/" .. FormatDebugValue(subType)
        end
        table.insert(parts, actionText)
    end

    if button.GetAttribute then
        for _, attributeName in ipairs({ "type", "action", "spell", "macro", "macrotext" }) do
            for _, candidateAttributeName in ipairs(BuildDebugAttributeNames(attributeName, clickButton)) do
                local ok, value = pcall(button.GetAttribute, button, candidateAttributeName)
                if ok and value ~= nil then
                    table.insert(parts, candidateAttributeName .. "=" .. FormatDebugValue(value))
                end
            end
        end
    end

    if #parts == 0 then
        return "attrs=none"
    end

    return table.concat(parts, "; ")
end

function addon:PrintBindingDump(targetText)
    targetText = TrimText(targetText)
    if not targetText or targetText == "" then
        self:Print("Usage: /mrlab binddump charge")
        return
    end

    local spellID = tonumber(targetText) or ResolveSpellIDByName(targetText)
    local baseSpellID = spellID and self:FindBaseSpellID(spellID) or nil
    local lookupNames = {}
    AddLookupSpellName(lookupNames, spellID)
    AddLookupSpellName(lookupNames, baseSpellID)
    AddRawLookupSpellName(lookupNames, targetText)

    local currentKeybind = spellID and self:GetKeybindText(spellID) or nil
    self:Print(string.format(
        "Bind dump for %s: spellID=%s base=%s current=%s",
        targetText,
        tostring(spellID or "nil"),
        tostring(baseSpellID or "nil"),
        tostring(currentKeybind or "none")
    ))

    if not GetNumBindings or not GetBinding then
        self:Print("Binding dump unavailable: binding API missing.")
        return
    end

    local printed = 0
    local bindingCount = GetNumBindings()
    for bindingIndex = 1, bindingCount do
        local bindingAction, key1, key2, key3, key4 = GetBinding(bindingIndex)
        if type(bindingAction) == "string" and bindingAction ~= "" then
            local keybind = FormatDebugKeybinds(self, key1, key2, key3, key4)
            local matched = false
            local shouldPrint = false
            local details = nil
            local spellEntries = nil

            local macroToken = bindingAction:match("^MACRO%s+(.+)$")
            if macroToken then
                local macroID = GetMacroIDFromToken(macroToken)
                local macroName, macroBody = nil, nil
                if macroID and GetMacroInfo then
                    local ok, resolvedMacroName, _, resolvedMacroBody = pcall(GetMacroInfo, macroID)
                    if ok then
                        macroName = resolvedMacroName
                        macroBody = resolvedMacroBody
                    end
                end
                spellEntries = self:GetMacroSpellEntriesByToken(macroToken)
                matched = SpellEntriesMatchLookup(spellEntries, spellID, baseSpellID, lookupNames)
                shouldPrint = matched or TextMatchesLookup(macroToken, lookupNames) or TextMatchesLookup(macroName, lookupNames) or TextMatchesLookup(macroBody, lookupNames)
                details = string.format(
                    "macro token=%s id=%s name=%s entries=%s",
                    FormatDebugValue(macroToken),
                    tostring(macroID or "nil"),
                    FormatDebugValue(macroName),
                    FormatDebugSpellEntries(spellEntries)
                )
            end

            if not details then
                local spellName = bindingAction:match("^SPELL%s+(.+)$")
                if spellName then
                    matched = TextMatchesLookup(spellName, lookupNames)
                    shouldPrint = matched
                    details = "spell name=" .. FormatDebugValue(spellName)
                end
            end

            if not details then
                local buttonName, clickButton = bindingAction:match("^CLICK%s+([^:]+):(.+)$")
                local button = buttonName and _G[buttonName]
                if buttonName then
                    spellEntries = button and self:GetSecureButtonSpellEntries(button, clickButton) or {}
                    matched = SpellEntriesMatchLookup(spellEntries, spellID, baseSpellID, lookupNames)
                    shouldPrint = matched or printed < 16
                    details = string.format(
                        "click button=%s click=%s exists=%s entries=%s %s",
                        FormatDebugValue(buttonName),
                        FormatDebugValue(clickButton),
                        button and "yes" or "no",
                        FormatDebugSpellEntries(spellEntries),
                        DescribeSecureButtonForDebug(button, clickButton)
                    )
                end
            end

            if shouldPrint and printed < 24 then
                printed = printed + 1
                self:Print(string.format(
                    "Bind %d key=%s match=%s action=%s | %s",
                    bindingIndex,
                    keybind,
                    matched and "yes" or "no",
                    FormatDebugValue(bindingAction),
                    details or "unknown"
                ))
            end
        end
    end

    if printed == 0 then
        self:Print("No matching macro/spell/click bindings found for " .. targetText .. ".")
    elseif printed >= 24 then
        self:Print("Bind dump stopped after 24 lines.")
    end
end
function addon:GetActionCountForSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return 0, false
    end

    local baseSpellID = self:FindBaseSpellID(spellID)
    local slotSet = self.actionSlotsBySpell[spellID] or self.actionSlotsByBaseSpell[baseSpellID]
    local buttonSet = self.actionButtonsBySpell[spellID] or self.actionButtonsByBaseSpell[baseSpellID]
    if not slotSet and not buttonSet then
        return 0, false
    end

    local highestCount = 0
    local foundAnySource = false

    if buttonSet then
        for button in pairs(buttonSet) do
            foundAnySource = true
            local countRegion = button.Count
            if countRegion then
                local okCount, numericText = pcall(function()
                    local text = countRegion:GetText()
                    if type(text) ~= "string" or text == "" or text == "0" then
                        return 0
                    end

                    return tonumber(text) or 1
                end)
                if okCount and type(numericText) == "number" then
                    local okCompare, isHigher = pcall(function()
                        return numericText > highestCount
                    end)
                    if okCompare and isHigher then
                        highestCount = numericText
                    end
                end
            end
        end

        if highestCount > 0 then
            return highestCount, true
        end
    end

    if not slotSet then
        return 0, foundAnySource
    end

    for slot in pairs(slotSet) do
        foundAnySource = true
        local ok, count = pcall(GetActionCount, slot)
        if ok and type(count) == "number" then
            local okCompare, isHigher = pcall(function()
                return count > highestCount
            end)
            if okCompare and isHigher then
                highestCount = count
            end
        end
    end

    return highestCount, foundAnySource
end

function addon:HasActionButtonProcGlowForSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false, false
    end

    -- EllesmereUI paints its own action-button glow from this API.
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        local ok, overlayed = pcall(C_SpellActivationOverlay.IsSpellOverlayed, spellID)
        if ok and overlayed == true then
            return true, true
        end
    end

    local baseSpellID = self:FindBaseSpellID(spellID)
    local buttonSet = self.actionButtonsBySpell[spellID] or self.actionButtonsByBaseSpell[baseSpellID]
    if not buttonSet then
        return false, false
    end

    local foundButton = false

    for button in pairs(buttonSet) do
        foundButton = true

        local glowRegions = {
            button.SpellActivationAlert,
            button.SpellHighlightTexture,
            button.SpellHighlight,
        }

        for _, region in ipairs(glowRegions) do
            if region and region.IsShown then
                local okShown, isShown = pcall(region.IsShown, region)
                if okShown and isShown then
                    return true, true
                end
            end
        end
    end

    return false, foundButton
end

function addon:ResetPosition()
    self.db.point = defaults.point
    self.db.relativePoint = defaults.relativePoint
    self.db.x = defaults.x
    self.db.y = defaults.y

    if self.UpdateAnchor then
        self:UpdateAnchor()
    end
end

function addon:RefreshActionState()
    if self.ResetResolvedSpellCache then
        self:ResetResolvedSpellCache()
    end

    self:ScanActionBars()
    self:UpdateRecommendation()
end

function addon:RefreshPagedActionState()
    -- Stealth and bonus-bar events can fire just before the replacement page
    -- has finished updating. Refresh now and once more on the next short tick
    -- so Shadowstrike and its currently visible keybind replace the normal
    -- builder mapping without waiting for the one-second background scan.
    self:RefreshActionState()
    C_Timer.After(0.05, function()
        addon:RefreshActionState()
    end)
end

function addon:PrintDebugSnapshot()
    if not self.GetDebugSnapshot then
        self:Print("Debug snapshot unavailable.")
        return
    end

    local snapshot = self:GetDebugSnapshot() or {}
    local recommendation = snapshot.recommendationSpellName or "none"
    local profileLabel = snapshot.profileLabel or "Unknown"
    local targetHealthText = "?"
    local targetsText = string.format(
        "%s auto (%s in melee, %s visible, %s recent)",
        tostring(snapshot.targetCount or 0),
        tostring(snapshot.detectedTargetCount or 0),
        tostring(snapshot.visibleHostileTargetCount or 0),
        tostring(snapshot.recentDamageTargetCount or 0)
    )

    if type(snapshot.targetHealthPercent) == "number" then
        targetHealthText = string.format("%.0f%%", snapshot.targetHealthPercent * 100)
    end

    if type(snapshot.detectedTargetCount) == "number"
    and type(snapshot.targetCountOverride) == "number"
    and snapshot.targetCountOverride > 0
    then
        targetsText = string.format(
            "%d (%d in melee, %d visible, %d recent, manual %d)",
            snapshot.targetCount,
            snapshot.detectedTargetCount,
            snapshot.visibleHostileTargetCount or 0,
            snapshot.recentDamageTargetCount or 0,
            snapshot.targetCountOverride
        )
    end

    local resourceName = snapshot.resourceName or "Rage"
    local function FormatSeconds(value, estimated)
        if type(value) ~= "number" then
            return "?"
        end
        if value == math.huge then
            return "hidden"
        end
        return string.format("%.1f%s", value, estimated and "~" or "")
    end
    local apiLine = string.format(
        "API: Bliz=%s | BlizMatch=%s | BlizSD=%s | RageBand=%s-%s | GCD=%s | CS=%s | Avatar=%s | BS=%s | SDGlowEvt=%s | AssistFallback=%s",
        tostring(snapshot.assistedSuggestionName or snapshot.assistedSuggestion or "none"),
        FormatBool(snapshot.assistedMatch),
        FormatBool(snapshot.assistedSuddenDeathSignal),
        tostring(snapshot.rageBandLow or "?"),
        tostring(snapshot.rageBandHigh or "?"),
        type(snapshot.observedGcd) == "number" and string.format("%.2f", snapshot.observedGcd) or "1.5(default)",
        FormatSeconds(snapshot.colossusCooldown, snapshot.colossusCooldownEstimated),
        FormatSeconds(snapshot.avatarCooldown, snapshot.avatarCooldownEstimated),
        FormatSeconds(snapshot.bladestormCooldown, snapshot.bladestormCooldownEstimated),
        FormatBool(snapshot.executeGlowEvent),
        FormatBool(self.db and self.db.assistedFallback ~= false)
    )
    self:Print(
        string.format(
            "Profile=%s | Spec=%s | Tree=%s | Mode=%s | Rec=%s | Target=%s | Targets=%s | HP=%s | %s=%s | %sKnown=%s",
            profileLabel,
            snapshot.activeSpecName or "?",
            snapshot.activeHeroTalentName or "none",
            snapshot.mode or "?",
            recommendation,
            FormatBool(snapshot.hasTarget),
            targetsText,
            targetHealthText,
            resourceName,
            tostring(snapshot.resource or snapshot.rage or 0),
            resourceName,
            FormatBool(snapshot.resourceKnown or snapshot.rageKnown)
        )
    )
    self:Print(apiLine)
    if snapshot.genericSpecKey then
        self:Print(string.format("Spec: %s | Why=%s%s", snapshot.genericSpecKey, tostring(snapshot.genericReason or "none"), snapshot.genericError and (" | Error=" .. snapshot.genericError) or ""))
    end

    if snapshot.profileType == "BEAST_MASTERY_HUNTER" then
        self:Print(
            string.format(
                "BM: Pack=%s | Dark=%s | BWRem=%.1f | WF=%.1f | DB=%.1f | Howl=%.1f | NA=%.1f | KCGlow=%s",
                FormatBool(snapshot.isBeastMasteryPackLeader),
                FormatBool(snapshot.isBeastMasteryDarkRanger),
                tonumber(snapshot.bestialWrathRemaining or 0) or 0,
                tonumber(snapshot.witheringFireRemaining or 0) or 0,
                tonumber(snapshot.deathblowRemaining or 0) or 0,
                tonumber(snapshot.howlOfThePackLeaderRemaining or 0) or 0,
                tonumber(snapshot.natureAllyRemaining or 0) or 0,
                FormatBool(snapshot.killCommandActionGlow)
            )
        )
        self:Print(
            string.format(
                "Ready: BW=%s | KC=%s (%s known=%s) | Barbed=%s (%s known=%s) | WT=%s | BA=%s | Wail=%s | Cobra=%s | Steady=%s | BC=%.1f | CDV: BW=%s KC=%s Barbed=%s WT=%s BA=%s Wail=%s BC=%s",
                FormatBool(snapshot.canBestialWrath),
                FormatBool(snapshot.canKillCommand),
                FormatSafeValue(snapshot.killCommandCharges, 0),
                FormatBool(snapshot.killCommandChargesKnown),
                FormatBool(snapshot.canBarbedShot),
                FormatSafeValue(snapshot.barbedShotCharges, 0),
                FormatBool(snapshot.barbedShotChargesKnown),
                FormatBool(snapshot.canWildThrash),
                FormatBool(snapshot.canBlackArrow),
                FormatBool(snapshot.canWailingArrow),
                FormatBool(snapshot.canCobraShot),
                FormatBool(snapshot.canSteadyShot),
                tonumber(snapshot.beastCleaveRemaining or 0) or 0,
                FormatBool(snapshot.cooldownViewerBestialWrath),
                FormatBool(snapshot.cooldownViewerKillCommand),
                FormatBool(snapshot.cooldownViewerBarbedShot),
                FormatBool(snapshot.cooldownViewerWildThrash),
                FormatBool(snapshot.cooldownViewerBlackArrow),
                FormatBool(snapshot.cooldownViewerWailingArrow),
                FormatBool(snapshot.cooldownViewerBeastCleaveActive)
            )
        )
        return
    end

    if snapshot.profileType == "RETRIBUTION_PALADIN" then
        self:Print(
            string.format(
                "Ret: Build=%s | Templar=%s | Herald=%s | RadiantGlory=%s | Crusading=%s | Combat=%.1f | OpenerBoJ=%s | WakeRecent=%s | HoLRecent=%s | AoW=%s/%s | BoJ=%s known=%s | HoW=%s known=%s | HoWWindow=%s | DA=%s | EmpLegacy=%s | Empyrean=%s | DP=%s | LD=%s stacks=%s",
                snapshot.retributionBuildName or "default",
                FormatBool(snapshot.isRetributionTemplar),
                FormatBool(snapshot.isRetributionHeraldOfTheSun),
                FormatBool(snapshot.hasRadiantGlory),
                FormatBool(snapshot.hasCrusadingStrikes),
                tonumber(snapshot.combatTime or 0) or 0,
                FormatBool(snapshot.openerBladeOfJusticeDone),
                FormatBool(snapshot.recentWakeOfAshesCast),
                FormatBool(snapshot.recentHammerOfLightCast),
                FormatBool(snapshot.artOfWarUp),
                tostring(snapshot.artOfWarStacks or 0),
                tostring(snapshot.bladeOfJusticeCharges or 0),
                FormatBool(snapshot.bladeOfJusticeChargesKnown),
                tostring(snapshot.hammerOfWrathCharges or 0),
                FormatBool(snapshot.hammerOfWrathChargesKnown),
                FormatBool(snapshot.hammerOfWrathWindow),
                FormatBool(snapshot.divineArbiterUp),
                FormatBool(snapshot.empyreanLegacyUp),
                FormatBool(snapshot.empyreanPowerUp),
                FormatBool(snapshot.divinePurposeUp),
                FormatBool(snapshot.lightDeliveranceReady),
                FormatSafeValue(snapshot.lightDeliveranceStacks, 0)
            )
        )
        self:Print(
            string.format(
                "Ready: AW=%s | ES=%s | Spender=%s | DS=%s | Wake=%s | DT=%s | HoL=%s | HoW=%s | BoJ=%s | Judge=%s | TS=%s/%s | CS=%s",
                FormatBool(snapshot.canAvengingWrath),
                FormatBool(snapshot.canExecutionSentence),
                FormatBool(snapshot.canSingleTargetSpender),
                FormatBool(snapshot.canDivineStorm),
                FormatBool(snapshot.canWakeOfAshes),
                FormatBool(snapshot.canDivineToll),
                FormatBool(snapshot.canHammerOfLight),
                FormatBool(snapshot.canHammerOfWrath),
                FormatBool(snapshot.canBladeOfJustice),
                FormatBool(snapshot.canJudgment),
                FormatBool(snapshot.canTemplarStrike),
                FormatBool(snapshot.canTemplarSlash),
                FormatBool(snapshot.canCrusaderStrike)
            )
        )
        return
    end

    if snapshot.isFury then
        self:Print(
            string.format(
                "Fury: Slayer=%s | Thane=%s | Enrage=%.1f | Reck=%.1f/%.1f | AvatarTalent=%s | Avatar=%.1f/%.1f | HnS=%s | OdynTalent=%s | Odyn=%.1f | Blade=%.1f | Combat=%.1f | RecentRampage=%s | OpenerBT=%s | BTAt=%.1f | Count=%s",
                FormatBool(snapshot.isFurySlayer),
                FormatBool(snapshot.isFuryMountainThane),
                tonumber(snapshot.enrageRemaining or 0) or 0,
                tonumber(snapshot.recklessnessRemaining or 0) or 0,
                tonumber(snapshot.recklessnessCooldown or 0) or 0,
                FormatBool(snapshot.hasAvatar),
                tonumber(snapshot.avatarCooldown or 0) or 0,
                tonumber(snapshot.avatarRemaining or 0) or 0,
                FormatBool(snapshot.hackAndSlashUp),
                FormatBool(snapshot.hasOdynsFury),
                tonumber(snapshot.odynsFuryCooldown or 0) or 0,
                tonumber(snapshot.bladestormCooldown or 0) or 0,
                tonumber(snapshot.combatTime or 0) or 0,
                FormatBool(snapshot.recentRampageCast),
                FormatBool(snapshot.openerBloodthirstDone),
                tonumber(snapshot.openerBloodthirstCastAt or 0) or 0,
                snapshot.targetCountSource or "?"
            )
        )
    end

    if snapshot.isArms then
        self:Print(
            string.format(
                "Arms: Colossus=%s | Slayer=%s | Mass=%s | DW=%s | BS=%s | ME=%s | Rend=%s %.1f | CSRecent=%s | Ravager=%s | Bladestorm=%s | HS=%s | FoB=%s | MoW=%s | MoWProc=%s | MoWStack=%s | HMight=%s | Cleave=%s | Collateral=%s | Demolish=%s | OP=%s known=%s | EP=%s | BL=%s | Opp=%s | Exe=%s | ID=%s | Count=%s",
                FormatBool(snapshot.isArmsColossus),
                FormatBool(snapshot.isArmsSlayer),
                FormatBool(snapshot.hasMassacre),
                FormatBool(snapshot.hasDeepWounds),
                FormatBool(snapshot.hasBroadStrokes),
                FormatBool(snapshot.hasMassExecution),
                FormatBool(snapshot.hasRend),
                tonumber(snapshot.rendRemaining or 0) or 0,
                FormatBool(snapshot.recentColossusSmashCast),
                FormatBool(snapshot.hasRavager),
                FormatBool(snapshot.hasBladestorm),
                FormatBool(snapshot.hasHeroicStrike),
                FormatBool(snapshot.hasFervorOfBattle),
                FormatBool(snapshot.masterOfWarfareUp),
                FormatBool(snapshot.masterOfWarfareProcUp),
                FormatBool(snapshot.masterOfWarfareStackUp),
                FormatBool(snapshot.heroicMightUp),
                FormatBool(snapshot.hasCleave),
                FormatBool(snapshot.hasCollateralDamage),
                FormatBool(snapshot.hasDemolish),
                tostring(snapshot.overpowerCharges or 0),
                FormatBool(snapshot.overpowerChargesKnown),
                tostring(snapshot.executionersPrecisionStacks or 0),
                tostring(snapshot.battlelordStacks or 0),
                tostring(snapshot.opportunistStacks or 0),
                tostring(snapshot.executionerStacks or 0),
                tostring(snapshot.imminentDemiseStacks or 0),
                snapshot.targetCountSource or "?"
            )
        )
    end
    self:Print(
        string.format(
            "SD=%s | SDGlow=%s | SDGlowKnown=%s | SDOverlayFury=%s | SDCount=%s | SDCountKnown=%s | SDCountOn=%s | HSGlow=%s | HSCount=%s | HSCountOn=%s | HSOvGlow=%s | HSOvCount=%s | HSOvCountOn=%s | SlamGlow=%s | SlamCount=%s | SlamCountOn=%s | ExecuteUsable=%s | ExecutePhase=%s | HPKnown=%s",
            FormatBool(snapshot.suddenDeathUp),
            FormatBool(snapshot.suddenDeathButtonGlow),
            FormatBool(snapshot.suddenDeathButtonGlowKnown),
            FormatBool(snapshot.suddenDeathOverlayByFuryExecute),
            tostring(snapshot.suddenDeathActionCount or 0),
            FormatBool(snapshot.suddenDeathActionCountKnown),
            FormatBool(snapshot.suddenDeathActionCountSignal),
            FormatBool(snapshot.heroicStrikeButtonGlow),
            tostring(snapshot.heroicStrikeActionCount or 0),
            FormatBool(snapshot.heroicStrikeActionCountSignal),
            FormatBool(snapshot.heroicStrikeOverrideButtonGlow),
            tostring(snapshot.heroicStrikeOverrideActionCount or 0),
            FormatBool(snapshot.heroicStrikeOverrideActionCountSignal),
            FormatBool(snapshot.slamButtonGlow),
            tostring(snapshot.slamActionCount or 0),
            FormatBool(snapshot.slamActionCountSignal),
            FormatBool(snapshot.executeStrictUsable),
            FormatBool(snapshot.executePhase),
            FormatBool(snapshot.targetHealthKnown)
        )
    )
    self:Print(
        string.format(
            "Cooldowns: Reck=%s | Avatar=%s | IWW=%s | W&F=%s | Blade=%s | WW=%s/%s | TBStacks=%s | TBCharges=%s | TBKnown=%s",
            FormatBool(snapshot.recklessnessUp),
            FormatBool(snapshot.avatarUp),
            FormatBool(snapshot.hasImprovedWhirlwind),
            FormatBool(snapshot.hasWrathAndFury),
            FormatBool(snapshot.hasBladestorm),
            tostring(snapshot.whirlwindStacks or 0),
            tostring(snapshot.assumedWhirlwindStacks or 0),
            tostring(snapshot.thunderBlastStacks or 0),
            tostring(snapshot.thunderBlastCharges or 0),
            FormatBool(snapshot.thunderBlastChargesKnown)
        )
    )
    self:Print(
        string.format(
            "Ready: Rampage=%s Execute=%s HeroicStrike=%s Bloodbath=%s Bloodthirst=%s BloodthirstLike=%s CrushingBlow=%s RagingBlow=%s ThunderBlast=%s OdynsFury=%s Bladestorm=%s WreckingThrow=%s Whirlwind=%s",
            FormatBool(snapshot.canRampage),
            FormatBool(snapshot.canExecute),
            FormatBool(snapshot.canHeroicStrike),
            FormatBool(snapshot.canBloodbath),
            FormatBool(snapshot.canBloodthirst),
            FormatBool(snapshot.canBloodthirstLike),
            FormatBool(snapshot.canCrushingBlow),
            FormatBool(snapshot.canRagingBlow),
            FormatBool(snapshot.canThunderBlast),
            FormatBool(snapshot.canOdynsFury),
            FormatBool(snapshot.canBladestorm),
            FormatBool(snapshot.canWreckingThrow),
            FormatBool(snapshot.canWhirlwind)
        )
    )
end

function addon:GetTargetCountStatusText()
    local targets = tonumber(self.db and self.db.targetCountOverride or 0) or 0
    if targets <= 0 then
        return "Target mode: AUTO (1 ST, 2-3 Cleave, 4+ AOE)"
    end

    local mode = targets >= 4 and "AOE" or (targets >= 2 and "Cleave" or "ST")
    return string.format("Target mode: manual %s (%d)", mode, targets)
end

function addon:EnsureRotationTraceStore()
    if not self.db then
        return nil
    end

    if type(self.db.rotationTrace) ~= "table" then
        self.db.rotationTrace = {}
    end

    local trace = self.db.rotationTrace
    if type(trace.entries) ~= "table" then
        trace.entries = {}
    end

    return trace
end

function addon:GetRotationTraceElapsed()
    local trace = self:EnsureRotationTraceStore()
    if not trace or type(trace.startedAtTime) ~= "number" then
        return 0
    end

    return RoundTraceNumber(GetTime() - trace.startedAtTime, 2)
end

function addon:ClearRotationTrace()
    local trace = self:EnsureRotationTraceStore()
    if not trace then
        return
    end

    wipe(trace.entries)
    trace.startedAt = nil
    trace.startedAtTime = nil
    trace.stoppedAt = nil
    trace.profileAtStart = nil
    trace.version = nil
    trace.droppedEntries = nil
    self.lastTraceRecommendationKey = nil
    self.lastTraceRecommendationAt = nil
end

function addon:StartRotationTrace()
    local trace = self:EnsureRotationTraceStore()
    if not trace then
        self:Print("Trace unavailable: SavedVariables not initialized.")
        return
    end

    self:ClearRotationTrace()
    trace = self:EnsureRotationTraceStore()
    trace.startedAt = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime())
    trace.startedAtTime = GetTime()
    trace.profileAtStart = self:GetProfileLabel()
    trace.version = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version") or nil
    self.db.traceEnabled = true
    self:Print("Rotation trace started. Run your dungeon/raid, then use /midrotlab trace stop and /reload to save it.")
end

function addon:StopRotationTrace()
    local trace = self:EnsureRotationTraceStore()
    if trace then
        trace.stoppedAt = date and date("%Y-%m-%d %H:%M:%S") or tostring(GetTime())
        trace.elapsed = self:GetRotationTraceElapsed()
    end

    if self.db then
        self.db.traceEnabled = false
    end

    local count = trace and trace.entries and #trace.entries or 0
    self:Print(string.format(
        "Rotation trace stopped with %d entries (%d older entries dropped). Use /reload so WoW writes it to SavedVariables.",
        count,
        trace and trace.droppedEntries or 0
    ))
end

function addon:GetRotationTraceStatusText()
    local trace = self:EnsureRotationTraceStore()
    local count = trace and trace.entries and #trace.entries or 0
    local enabled = self.db and self.db.traceEnabled == true
    return string.format(
        "Trace is %s. Entries=%d/%d. Dropped=%d. Started=%s.",
        enabled and "running" or "stopped",
        count,
        tonumber(self.db and self.db.traceMaxEntries or 6000) or 6000,
        trace and trace.droppedEntries or 0,
        trace and tostring(trace.startedAt or "never") or "never"
    )
end

function addon:RecordRotationTrace(entry)
    if not self.db or self.db.traceEnabled ~= true or type(entry) ~= "table" then
        return
    end

    local trace = self:EnsureRotationTraceStore()
    if not trace then
        return
    end

    entry.t = self:GetRotationTraceElapsed()
    entry.clock = date and date("%H:%M:%S") or nil
    table.insert(trace.entries, entry)

    local maxEntries = tonumber(self.db.traceMaxEntries or 6000) or 6000
    maxEntries = math.max(100, math.min(10000, maxEntries))
    while #trace.entries > maxEntries do
        table.remove(trace.entries, 1)
        trace.droppedEntries = (trace.droppedEntries or 0) + 1
    end
end

function addon:RecordRecommendationTrace(spellID, profileLabel, modeLabel)
    if not self.db or self.db.traceEnabled ~= true or not self.GetDebugSnapshot then
        return
    end

    if UnitAffectingCombat("player") ~= true and not self:HasHostileTarget() then
        return
    end

    local now = GetTime()
    local snapshot = self:GetDebugSnapshot() or {}
    local recommendationID = type(spellID) == "table" and spellID.spellID or spellID
    local recommendationName = type(spellID) == "table" and spellID.name or nil
    if not recommendationName and recommendationID and C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, recommendationID)
        if ok then
            recommendationName = name
        end
    end
    recommendationName = recommendationName or snapshot.recommendationSpellName or "none"
    recommendationID = recommendationID or snapshot.recommendationSpellID
    local key = table.concat({
        tostring(recommendationID or "none"),
        tostring(snapshot.profileLabel or profileLabel or "?"),
        tostring(snapshot.mode or modeLabel or "?"),
        tostring(snapshot.targetCount or 0),
    }, "|")

    if key == self.lastTraceRecommendationKey
    and type(self.lastTraceRecommendationAt) == "number"
    and (now - self.lastTraceRecommendationAt) < 1.0
    then
        return
    end

    self.lastTraceRecommendationKey = key
    self.lastTraceRecommendationAt = now

    self:RecordRotationTrace({
        kind = "recommendation",
        rec = recommendationName,
        recID = recommendationID,
        recType = type(spellID) == "table" and spellID.type or snapshot.recommendationType,
        profile = snapshot.profileLabel or profileLabel,
        mode = snapshot.mode or modeLabel,
        targets = snapshot.targetCount,
        targetSource = snapshot.targetCountSource,
        targetOverride = snapshot.targetCountOverride,
        detectedTargets = snapshot.detectedTargetCount,
        visibleTargets = snapshot.visibleHostileTargetCount,
        recentTargets = snapshot.recentDamageTargetCount,
        resource = snapshot.resourceKnown == false and "hidden" or snapshot.resource,
        rage = snapshot.rageKnown == false and "hidden" or snapshot.rage,
        holyPower = snapshot.holyPowerKnown == false and "hidden" or snapshot.holyPower,
        runicPower = snapshot.runicPowerKnown == false and "hidden" or snapshot.runicPower,
        energy = snapshot.energyKnown == false and "hidden" or snapshot.energy,
        comboPoints = snapshot.comboPointsKnown == false and "hidden" or snapshot.comboPoints,
        comboPointMax = snapshot.maximumComboPoints,
        stealth = snapshot.stealthed == true,
        dance = snapshot.shadowDanceUp == true,
        danceRemains = RoundTraceNumber(snapshot.shadowDanceRemaining, 1),
        blades = snapshot.shadowBladesUp == true,
        coup = snapshot.coupDeGraceUp == true,
        darkestNight = snapshot.darkestNightUp == true,
        runes = snapshot.readyRunesKnown == false and "hidden" or snapshot.readyRunes,
        km = snapshot.killingMachineStacks,
        rime = snapshot.rimeUp == true,
        exterminate = snapshot.exterminateUp == true,
        pillar = snapshot.pillarOfFrostUp == true,
        pillarRemains = RoundTraceNumber(snapshot.pillarOfFrostRemaining, 1),
        breath = snapshot.breathOfSindragosaUp == true,
        recentFrostwyrm = snapshot.recentFrostwyrmsFuryCast == true,
        enrage = RoundTraceNumber(snapshot.enrageRemaining, 1),
        reck = snapshot.recklessnessUp == true,
        avatar = snapshot.avatarUp == true,
        rampageGenerators = snapshot.furyGeneratorCastsSinceRampage,
        rampageUsableFor = RoundTraceNumber(snapshot.furyRampageUsableFor, 2),
        rampageGenSinceUsable = snapshot.furyGeneratorsSinceRampageUsable,
        ww = snapshot.whirlwindStacks,
        sd = snapshot.suddenDeathStacks,
        sdUp = snapshot.suddenDeathUp == true,
        sdAura = snapshot.suddenDeathAuraByID == true
            or snapshot.suddenDeathAuraByAltID == true
            or snapshot.suddenDeathAuraByName == true,
        sdOverlay = snapshot.suddenDeathOverlayByExecute == true
            or snapshot.suddenDeathOverlayByBaseExecute == true
            or snapshot.suddenDeathOverlayByFuryExecute == true,
        sdCount = snapshot.suddenDeathActionCount,
        sdCountOn = snapshot.suddenDeathActionCountSignal == true,
        sdGlow = snapshot.suddenDeathButtonGlow == true,
        executeUsable = snapshot.executeStrictUsable == true,
        inCombat = snapshot.inCombat == true,
        mow = snapshot.masterOfWarfareUp == true,
        mowProc = snapshot.masterOfWarfareProcUp == true,
        mowStack = snapshot.masterOfWarfareStackUp == true,
        hMight = snapshot.heroicMightUp == true,
        hsGlow = snapshot.heroicStrikeButtonGlow == true,
        hsCount = snapshot.heroicStrikeActionCount,
        hsCountOn = snapshot.heroicStrikeActionCountSignal == true,
        hsOvGlow = snapshot.heroicStrikeOverrideButtonGlow == true,
        hsOvCount = snapshot.heroicStrikeOverrideActionCount,
        hsOvCountOn = snapshot.heroicStrikeOverrideActionCountSignal == true,
        slamGlow = snapshot.slamButtonGlow == true,
        slamCount = snapshot.slamActionCount,
        slamCountOn = snapshot.slamActionCountSignal == true,
        executePhase = snapshot.executePhase == true,
        ep = snapshot.executionersPrecisionStacks,
        hp = RoundTraceNumber(snapshot.targetHealthPercent, 3),
        rend = RoundTraceNumber(snapshot.rendRemaining, 1),
        cs = RoundTraceNumber(snapshot.colossusSmashRemaining, 1),
        spec = snapshot.genericSpecKey,
        specWhy = snapshot.genericReason,
        specErr = snapshot.genericError,
        -- 0.4.1 API-workaround probes
        bliz = snapshot.assistedSuggestionName or snapshot.assistedSuggestion,
        blizMatch = snapshot.assistedMatch == true,
        blizFallback = snapshot.assistedFallbackSpellID ~= nil and recommendationID == snapshot.assistedFallbackSpellID,
        blizSd = snapshot.assistedSuddenDeathSignal == true,
        rageLo = snapshot.rageBandLow,
        rageHi = snapshot.rageBandHigh,
        gcd = RoundTraceNumber(snapshot.observedGcd, 3),
        csCd = (snapshot.colossusCooldown == math.huge and "hidden" or RoundTraceNumber(snapshot.colossusCooldown, 1)),
        csCdEst = snapshot.colossusCooldownEstimated == true,
        avatarCd = (snapshot.avatarCooldown == math.huge and "hidden" or RoundTraceNumber(snapshot.avatarCooldown, 1)),
        avatarCdEst = snapshot.avatarCooldownEstimated == true,
        bsCd = (snapshot.bladestormCooldown == math.huge and "hidden" or RoundTraceNumber(snapshot.bladestormCooldown, 1)),
        bsCdEst = snapshot.bladestormCooldownEstimated == true,
        sdGlowEvt = snapshot.executeGlowEvent == true,
        hasCleave = snapshot.hasCleave == true,
        ready = {
            rampage = snapshot.canRampage == true,
            execute = snapshot.canExecute == true,
            bladestorm = snapshot.canBladestorm == true,
            odynsFury = snapshot.canOdynsFury == true,
            whirlwind = snapshot.canWhirlwind == true,
            bloodbath = snapshot.canBloodbath == true,
            bloodthirst = snapshot.canBloodthirst == true,
            bloodthirstLike = snapshot.canBloodthirstLike == true,
            crushingBlow = snapshot.canCrushingBlow == true,
            ragingBlow = snapshot.canRagingBlow == true,
            thunderBlast = snapshot.canThunderBlast == true,
            cleave = snapshot.canCleave == true,
            obliterate = snapshot.canObliterate == true,
            frostStrike = snapshot.canFrostStrike == true,
            howlingBlast = snapshot.canHowlingBlast == true,
            frostscythe = snapshot.canFrostscythe == true,
            glacialAdvance = snapshot.canGlacialAdvance == true,
            reapersMark = snapshot.canReapersMark == true,
            pillarOfFrost = snapshot.canPillarOfFrost == true,
            empowerRuneWeapon = snapshot.canEmpowerRuneWeapon == true,
            breathOfSindragosa = snapshot.canBreathOfSindragosa == true,
            frostwyrmsFury = snapshot.canFrostwyrmsFury == true,
            remorselessWinter = snapshot.canRemorselessWinter == true,
            raiseDead = snapshot.canRaiseDead == true,
            backstab = snapshot.canBackstab == true,
            gloomblade = snapshot.canGloomblade == true,
            shadowstrike = snapshot.canShadowstrike == true,
            eviscerate = snapshot.canEviscerate == true,
            shurikenStorm = snapshot.canShurikenStorm == true,
            blackPowder = snapshot.canBlackPowder == true,
            shadowDance = snapshot.canShadowDance == true,
            shadowBlades = snapshot.canShadowBlades == true,
            secretTechnique = snapshot.canSecretTechnique == true,
            goremawsBite = snapshot.canGoremawsBite == true,
            coupDeGrace = snapshot.canCoupDeGrace == true,
        },
    })
end

function addon:RecordSpellcastTrace(spellID, spellName)
    if not self.db or self.db.traceEnabled ~= true then
        return
    end

    self:RecordRotationTrace({
        kind = "cast",
        spell = spellName or tostring(spellID or "unknown"),
        spellID = spellID,
        profile = self:GetProfileLabel(),
    })
end

function addon:HasHostileTarget()
    return UnitExists("target")
        and UnitCanAttack("player", "target")
        and not UnitIsDead("target")
end

function addon:GetBurstWindowSeconds()
    local windowSeconds = tonumber(self.db and self.db.burstWindowSeconds or 20) or 20
    return math.min(60, math.max(5, windowSeconds))
end

function addon:UpdateBurstTargetWindow()
    if not self.db
    or self.db.burstMode ~= true
    or not self:HasHostileTarget()
    or UnitAffectingCombat("player") ~= true
    then
        self.burstTargetGUID = nil
        self.burstTargetStartedAt = nil
        return
    end

    local now = GetTime()
    local targetGUID = UnitGUID and UnitGUID("target") or nil
    if self.burstTargetGUID ~= targetGUID then
        self.burstTargetGUID = targetGUID
        self.burstTargetStartedAt = now
    end
end

function addon:IsBurstWindowActive()
    local now = GetTime()
    local windowSeconds = self:GetBurstWindowSeconds()

    if type(self.manualBurstUntil) == "number" and self.manualBurstUntil > now then
        return self:HasHostileTarget()
    end

    self:UpdateBurstTargetWindow()
    if not self.db or self.db.burstMode ~= true or type(self.burstTargetStartedAt) ~= "number" then
        return false
    end

    return self:HasHostileTarget() and (now - self.burstTargetStartedAt) <= windowSeconds
end

function addon:GetBurstModeStatusText()
    local automatic = self.db and self.db.burstMode == true
    local active = self:IsBurstWindowActive()
    local potionName = self.db and self.db.burstPotionName or "Potion of Recklessness"

    return string.format(
        "Burst mode is %s. Current burst window is %s. Potion=%s.",
        automatic and "enabled" or "disabled",
        active and "active" or "inactive",
        potionName
    )
end

function addon:ArmManualBurstWindow()
    self.manualBurstUntil = GetTime() + self:GetBurstWindowSeconds()
end

function addon:GetBurstPotionCandidates()
    local candidates = {}
    local configuredPotion = self.db and self.db.burstPotionName
    if type(configuredPotion) == "string" and configuredPotion ~= "" then
        table.insert(candidates, configuredPotion)
    end

    table.insert(candidates, "Potion of Recklessness")
    table.insert(candidates, "Light's Potential")
    table.insert(candidates, "Draught of Rampant Abandon")
    return candidates
end

function addon:GetBurstPotionItem()
    local candidates = self:GetBurstPotionCandidates()
    local actionItemID, actionItemName = self:GetActionItemIDByName(candidates)
    if actionItemID then
        return actionItemID, self:GetItemNameSafe(actionItemID) or actionItemName
    end

    for _, itemName in ipairs(candidates) do
        local itemID = ResolveItemIDByName(itemName)
        if itemID then
            return itemID, self:GetItemNameSafe(itemID) or itemName
        end
    end

    return nil
end

function addon:GetBurstPotionRecommendation()
    if not self:IsBurstWindowActive() then
        return nil
    end

    local itemID, itemName = self:GetBurstPotionItem()
    if not itemID or not self:IsItemReady(itemID) then
        return nil
    end

    return {
        type = "item",
        itemID = itemID,
        name = itemName or "Combat Potion",
    }
end

function addon:HandleSlash(message)
    local rawInput = type(message) == "string" and message:match("^%s*(.-)%s*$") or ""
    local input = rawInput:lower()
    local scaleValue = input:match("^scale%s+([%d%.]+)$")
    local fontSizeValue = input:match("^fontsize%s+([%d%.]+)$")
    local cooldownsValue = input:match("^cooldowns%s+(on)$") or input:match("^cooldowns%s+(off)$") or input:match("^cooldowns%s+(toggle)$")
    local targetsValue = input:match("^targets%s+(auto)$")
        or input:match("^targets%s+(st)$")
        or input:match("^targets%s+(cleave)$")
        or input:match("^targets%s+(aoe)$")
        or input:match("^targets%s+(%d+)$")
    local burstValue = input:match("^burst%s+(on)$") or input:match("^burst%s+(off)$") or input:match("^burst%s+(now)$")
    local traceValue = input:match("^trace%s+(start)$")
        or input:match("^trace%s+(stop)$")
        or input:match("^trace%s+(status)$")
        or input:match("^trace%s+(clear)$")
    local potionValue = rawInput:match("^[Pp][Oo][Tt][Ii][Oo][Nn]%s+(.+)$")
    local fontValue = rawInput:match("^font%s+(.+)$")
    local bindDumpValue = rawInput:match("^[Bb][Ii][Nn][Dd][Dd][Uu][Mm][Pp]%s+(.+)$")
        or rawInput:match("^[Bb][Ii][Nn][Dd]%s+(.+)$")

    if input == "unlock" then
        self.db.locked = false
        self:UpdateFrameState()
        self:Print("Frame unlocked.")
        return
    end

    if input == "lock" then
        self.db.locked = true
        self:UpdateFrameState()
        self:Print("Frame locked.")
        return
    end

    if input == "keybind" then
        self.db.keybindOnly = true
        self:UpdateRecommendation()
        self:Print("Keybind-only mode enabled.")
        return
    end

    if input == "icon" then
        self.db.keybindOnly = false
        self:UpdateRecommendation()
        self:Print("Icon mode enabled.")
        return
    end

    if input == "cooldowns" then
        cooldownsValue = "toggle"
    end

    if cooldownsValue then
        if cooldownsValue == "toggle" then
            self.db.recommendMajorCooldowns = not self.db.recommendMajorCooldowns
        else
            self.db.recommendMajorCooldowns = cooldownsValue == "on"
        end

        self:UpdateRecommendation()
        self:Print("Major cooldown recommendations " .. (self.db.recommendMajorCooldowns and "enabled." or "disabled."))
        return
    end

    if input == "burst" then
        self:Print(self:GetBurstModeStatusText())
        self:Print("Usage: /midrotlab burst on|off|now")
        return
    end

    if burstValue then
        if burstValue == "on" then
            self.db.burstMode = true
            self:UpdateBurstTargetWindow()
        elseif burstValue == "off" then
            self.db.burstMode = false
            self.manualBurstUntil = nil
            self.burstTargetGUID = nil
            self.burstTargetStartedAt = nil
        elseif burstValue == "now" then
            self:ArmManualBurstWindow()
        end

        self:UpdateRecommendation()
        self:Print(self:GetBurstModeStatusText())
        return
    end

    if input == "trace" then
        self:Print(self:GetRotationTraceStatusText())
        self:Print("Usage: /midrotlab trace start|stop|status|clear")
        return
    end

    if traceValue then
        if traceValue == "start" then
            self:StartRotationTrace()
        elseif traceValue == "stop" then
            self:StopRotationTrace()
        elseif traceValue == "status" then
            self:Print(self:GetRotationTraceStatusText())
        elseif traceValue == "clear" then
            self:ClearRotationTrace()
            if self.db then
                self.db.traceEnabled = false
            end
            self:Print("Rotation trace cleared.")
        end
        return
    end

    if input == "potion" then
        self:Print("Current burst potion: " .. tostring(self.db.burstPotionName or "Potion of Recklessness"))
        self:Print("Usage: /midrotlab potion Potion of Recklessness")
        return
    end

    if potionValue then
        potionValue = potionValue:match("^%s*(.-)%s*$")
        if not potionValue or potionValue == "" then
            self:Print("Potion name cannot be empty.")
            return
        end

        self.db.burstPotionName = potionValue
        self:ScanActionBars()
        self:UpdateRecommendation()
        self:Print("Burst potion set to " .. potionValue .. ".")
        return
    end

    if input == "targets" then
        self:Print(self:GetTargetCountStatusText())
        self:Print("Usage: /midrotlab auto|st|cleave|aoe, or /midrotlab targets auto|1-20")
        return
    end

    if input == "auto" then
        self.db.targetCountOverride = 0
        self:UpdateRecommendation()
        self:Print(self:GetTargetCountStatusText())
        return
    end

    if input == "st" then
        self.db.targetCountOverride = 1
        self:UpdateRecommendation()
        self:Print(self:GetTargetCountStatusText())
        return
    end

    if input == "cleave" then
        self.db.targetCountOverride = 2
        self:UpdateRecommendation()
        self:Print(self:GetTargetCountStatusText())
        return
    end

    if input == "aoe" then
        self.db.targetCountOverride = 4
        self:UpdateRecommendation()
        self:Print(self:GetTargetCountStatusText())
        return
    end

    if targetsValue then
        if targetsValue == "auto" then
            self.db.targetCountOverride = 0
            self:UpdateRecommendation()
            self:Print(self:GetTargetCountStatusText())
            return
        elseif targetsValue == "st" then
            self.db.targetCountOverride = 1
            self:UpdateRecommendation()
            self:Print(self:GetTargetCountStatusText())
            return
        elseif targetsValue == "cleave" then
            self.db.targetCountOverride = 2
            self:UpdateRecommendation()
            self:Print(self:GetTargetCountStatusText())
            return
        elseif targetsValue == "aoe" then
            self.db.targetCountOverride = 4
            self:UpdateRecommendation()
            self:Print(self:GetTargetCountStatusText())
            return
        end

        local numericTargets = tonumber(targetsValue)
        if not numericTargets or numericTargets < 1 or numericTargets > 20 then
            self:Print("Target mode must be auto, ST, Cleave, AOE, or a number from 1 to 20.")
            return
        end

        self.db.targetCountOverride = numericTargets
        self:UpdateRecommendation()
        self:Print(self:GetTargetCountStatusText())
        return
    end

    if input == "reset" then
        self:ResetPosition()
        self:Print("Frame position reset.")
        return
    end

    if input == "scale" then
        self:Print(string.format("Current scale: %.2f", tonumber(self.db.scale or 1) or 1))
        self:Print("Usage: /midrotlab scale 1.0")
        return
    end

    if scaleValue then
        local numericScale = tonumber(scaleValue)
        if not numericScale or numericScale < 0.5 or numericScale > 3 then
            self:Print("Scale must be between 0.5 and 3.0.")
            return
        end

        self.db.scale = numericScale
        self:UpdateFrameState()
        self:Print(string.format("Scale set to %.2f", numericScale))
        return
    end

    if input == "fontsize" then
        self:Print(string.format("Current font size: %d", tonumber(self.db.fontSize or 28) or 28))
        self:Print("Usage: /midrotlab fontsize 28")
        return
    end

    if fontSizeValue then
        local numericFontSize = tonumber(fontSizeValue)
        if not numericFontSize or numericFontSize < 10 or numericFontSize > 96 then
            self:Print("Font size must be between 10 and 96.")
            return
        end

        self.db.fontSize = numericFontSize
        if self.UpdateFonts then
            self:UpdateFonts()
        end
        self:Print(string.format("Font size set to %d", numericFontSize))
        return
    end

    if input == "font" then
        self:Print("Usage: /midrotlab font friz|arial|arial narrow|morpheus|skurri")
        self:Print("You can also pass a raw font path.")
        return
    end

    if fontValue then
        local resolvedFontPath = self:ResolveFontPath(fontValue)
        if not resolvedFontPath then
            self:Print("Invalid font value.")
            return
        end

        local previousFontPath = self.db.fontPath
        self.db.fontPath = resolvedFontPath

        if self.UpdateFonts and self:UpdateFonts() then
            self:Print("Font updated.")
            return
        end

        self.db.fontPath = previousFontPath
        if self.UpdateFonts then
            self:UpdateFonts()
        end
        self:Print("That font could not be applied.")
        return
    end

    if bindDumpValue then
        self:PrintBindingDump(bindDumpValue)
        return
    end

    if input == "dump" then
        self:PrintDebugSnapshot()
        return
    end

    local assistValue = input:match("^assist%s+(on)$") or input:match("^assist%s+(off)$")
    if input == "assist" or assistValue then
        if assistValue then
            self.db.assistedFallback = assistValue == "on"
        else
            self.db.assistedFallback = self.db.assistedFallback == false
        end
        self:UpdateRecommendation()
        self:Print("Blizzard Assisted Highlight fallback " .. (self.db.assistedFallback ~= false and "enabled." or "disabled."))
        return
    end

    self:Print("Commands: /midrotlab lock, unlock, keybind, icon, cooldowns [on|off|toggle], assist [on|off], burst on|off|now, potion <name>, auto, st, cleave, aoe, targets N, trace start|stop|status|clear, reset, scale <0.5-3.0>, fontsize <10-96>, font <name>, dump, binddump <spell>")
end

function addon:UpdateRecommendation()
    if not self.DisplayRecommendation or not self.GetRecommendation then
        return
    end

    local spellID, profileLabel, modeLabel = self:GetRecommendation()
    if self.RecordRecommendationTrace then
        self:RecordRecommendationTrace(spellID, profileLabel, modeLabel)
    end
    self:DisplayRecommendation(spellID, profileLabel, modeLabel)
end

function addon:PLAYER_LOGIN()
    self:ApplyDefaults()
    self:CreateUI()
    self:UpdateAnchor()
    self:UpdateFrameState()
    self:ScanActionBars()
    self:UpdateRecommendation()

    self.ticker = C_Timer.NewTicker(0.25, function()
        addon:UpdateRecommendation()
    end)

    self.scanTicker = C_Timer.NewTicker(1.00, function()
        addon:ScanActionBars()
    end)

    SLASH_MIDNIGHTROTATIONARMSLAB1 = "/midrotlab"
    SLASH_MIDNIGHTROTATIONARMSLAB2 = "/mrlab"
    SlashCmdList.MIDNIGHTROTATIONARMSLAB = function(msg)
        addon:HandleSlash(msg)
    end

    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.eventFrame:RegisterEvent("SPELLS_CHANGED")
    self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self.eventFrame:RegisterEvent("UPDATE_MACROS")
    self.eventFrame:RegisterEvent("UPDATE_BINDINGS")
    self.eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    self.eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    self.eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    self.eventFrame:RegisterEvent("UPDATE_STEALTH")
    -- Proc glow events are a second Sudden Death / Heroic Strike signal next to
    -- the polled overlay API (0.4.1). Missing or secret payloads are ignored.
    pcall(self.eventFrame.RegisterEvent, self.eventFrame, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    pcall(self.eventFrame.RegisterEvent, self.eventFrame, "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

end

function addon:SPELLS_CHANGED()
    self:RefreshActionState()
end

function addon:PLAYER_SPECIALIZATION_CHANGED(unit)
    if unit == "player" then
        self:RefreshActionState()
    end
end

function addon:TRAIT_CONFIG_UPDATED()
    self:RefreshActionState()
end

function addon:UPDATE_MACROS()
    self:RefreshActionState()
end

function addon:UPDATE_BINDINGS()
    self:RefreshActionState()
end

function addon:ACTIONBAR_SLOT_CHANGED()
    self:RefreshActionState()
end

function addon:ACTIONBAR_PAGE_CHANGED()
    self:RefreshPagedActionState()
end

function addon:UPDATE_BONUS_ACTIONBAR()
    self:RefreshPagedActionState()
end

function addon:UPDATE_STEALTH()
    self:RefreshPagedActionState()
end

addon.eventFrame:SetScript("OnEvent", function(_, event, ...)
    local method = addon[event]
    if method then
        method(addon, ...)
    end
end)

addon.eventFrame:RegisterEvent("PLAYER_LOGIN")
-- Retail 12.x blocks normal addons from registering COMBAT_LOG_EVENT_UNFILTERED.

