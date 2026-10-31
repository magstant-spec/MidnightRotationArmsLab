local addonName, addon = ...

-- ---------------------------------------------------------------------------
-- /midrotlab rageprobe (0.5.2)
--
-- Records, for one combat, which rage-related signals Midnight still exposes:
-- raw rage, rage percent, power-change events, spell costs, usability flags,
-- attack speed and Blizzard's Assisted Highlight. Arm it out of combat, pull,
-- fight ~30 seconds, then leave combat (or run the command again) to get the
-- report in chat. The report is also saved to SavedVariables under
-- MidnightRotationArmsLabDB.rageProbe.
-- ---------------------------------------------------------------------------

local RAGE = (Enum and Enum.PowerType and Enum.PowerType.Rage) or 1
local MAX_SECONDS = 90

local PROBE_SPELLS = {
    { 184367, "Rampage" },
    { 190456, "Ignore Pain" },
    { 202168, "Impending Victory" },
    { 1715, "Hamstring" },
    { 12294, "Mortal Strike" },
    { 1464, "Slam" },
    { 845, "Cleave" },
    { 772, "Rend" },
    { 6343, "Thunder Clap" },
    { 1680, "Whirlwind" },
    { 5308, "Execute" },
    { 163201, "Execute" },
    { 280735, "Execute" },
}

local probe = nil
local sampler = nil
local frame = CreateFrame("Frame")

local function IsSecret(value)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        return ok and secret == true
    end
    return false
end

-- Returns the value if Lua can actually use it, else nil.
local function Readable(value)
    if value == nil or IsSecret(value) then
        return nil
    end
    local ok = pcall(function() return value + 0 end)
    return ok and value or nil
end

local function Tally(bucket, value)
    bucket.total = bucket.total + 1
    if Readable(value) ~= nil then
        bucket.readable = bucket.readable + 1
        bucket.last = value
    else
        bucket.secret = bucket.secret + 1
    end
end

local function NewBucket()
    return { total = 0, readable = 0, secret = 0 }
end

local function KnownProbeSpells()
    local list = {}
    local seenNames = {}
    for _, entry in ipairs(PROBE_SPELLS) do
        local spellID, name = entry[1], entry[2]
        local known = false
        if IsPlayerSpell then
            local ok, result = pcall(IsPlayerSpell, spellID)
            known = ok and result == true
        end
        if not known and C_SpellBook and C_SpellBook.IsSpellInSpellBook then
            local ok, result = pcall(C_SpellBook.IsSpellInSpellBook, spellID)
            known = ok and result == true
        end
        if known and not seenNames[name .. spellID] then
            seenNames[name .. spellID] = true
            list[#list + 1] = { id = spellID, name = name }
        end
    end
    return list
end

local function ReadRageCost(spellID)
    if not C_Spell or not C_Spell.GetSpellPowerCost then
        return nil, "no API"
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok then
        return nil, "error"
    end
    if type(costs) ~= "table" then
        return nil, "none"
    end
    local okRead, cost = pcall(function()
        for _, entry in ipairs(costs) do
            if entry.type == RAGE then
                return entry.cost
            end
        end
        return false
    end)
    if not okRead then
        return nil, "secret"
    end
    if cost == false then
        return nil, "no rage cost"
    end
    if Readable(cost) == nil then
        return nil, "secret"
    end
    return cost, nil
end

local function StartRecording()
    probe.recording = true
    probe.startedAt = GetTime()
    probe.lastCastAt = 0
    probe.casts = 0
    probe.powerEvents = 0
    probe.powerEventsNoCast = 0
    probe.powerTypeReadable = 0
    probe.powerTypeSecret = 0
    probe.unitPower = NewBucket()
    probe.unitPowerPercent = NewBucket()
    probe.attackSpeed = NewBucket()
    probe.secretFlag = { yes = 0, no = 0 }
    probe.assisted = { total = 0, rampage = 0, names = {} }
    probe.spells = {}
    for _, spell in ipairs(probe.armedSpells or KnownProbeSpells()) do
        local cost, why = spell.cost, spell.why
        if cost == nil and why == nil then
            cost, why = ReadRageCost(spell.id)
        end
        probe.spells[#probe.spells + 1] = {
            id = spell.id,
            name = spell.name,
            costOutOfCombat = cost,
            costOutOfCombatWhy = why,
            costInCombat = nil,
            costInCombatWhy = nil,
            usableFlips = 0,
            lastUsable = nil,
            flagReadable = 0,
            flagSecret = 0,
        }
    end
    addon:Print("Rage probe: recording. Fight for ~30 seconds, then leave combat or type /midrotlab rageprobe again.")
end

local function Sample()
    if not probe or not probe.recording then
        return
    end

    local okPower, power = pcall(UnitPower, "player", RAGE)
    Tally(probe.unitPower, okPower and power or nil)

    if UnitPowerPercent then
        local okPct, pct = pcall(UnitPowerPercent, "player", RAGE)
        Tally(probe.unitPowerPercent, okPct and pct or nil)
    end

    if C_Secrets and C_Secrets.ShouldUnitPowerBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldUnitPowerBeSecret, "player", RAGE)
        if ok and secret == true then
            probe.secretFlag.yes = probe.secretFlag.yes + 1
        else
            probe.secretFlag.no = probe.secretFlag.no + 1
        end
    end

    if UnitAttackSpeed then
        local ok, mainHand = pcall(UnitAttackSpeed, "player")
        Tally(probe.attackSpeed, ok and mainHand or nil)
    end

    for _, spell in ipairs(probe.spells) do
        if C_Spell and C_Spell.IsSpellUsable then
            local ok, usable, noResource = pcall(C_Spell.IsSpellUsable, spell.id)
            if ok then
                if type(noResource) == "boolean" and not IsSecret(noResource) then
                    spell.flagReadable = spell.flagReadable + 1
                else
                    spell.flagSecret = spell.flagSecret + 1
                end
                local nowUsable = usable == true and noResource ~= true
                if spell.lastUsable ~= nil and spell.lastUsable ~= nowUsable then
                    spell.usableFlips = spell.usableFlips + 1
                end
                spell.lastUsable = nowUsable
            end
        end
        if spell.costInCombat == nil and spell.costInCombatWhy == nil and UnitAffectingCombat("player") then
            local cost, why = ReadRageCost(spell.id)
            spell.costInCombat = cost
            spell.costInCombatWhy = why
        end
    end

    if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
        local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell, false)
        if ok and Readable(spellID) then
            probe.assisted.total = probe.assisted.total + 1
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or tostring(spellID)
            probe.assisted.names[name] = (probe.assisted.names[name] or 0) + 1
            if name == "Rampage" then
                probe.assisted.rampage = probe.assisted.rampage + 1
            end
        end
    end

    if (GetTime() - probe.startedAt) > MAX_SECONDS then
        addon:FinishRageProbe("time limit")
    end
end

local function Percent(part, whole)
    if not whole or whole == 0 then
        return "n/a"
    end
    return string.format("%d%%", math.floor(part / whole * 100 + 0.5))
end

local function BucketText(bucket)
    if bucket.total == 0 then
        return "not available"
    end
    if bucket.readable == 0 then
        return string.format("HIDDEN (0/%d samples readable)", bucket.total)
    end
    return string.format("READABLE in %s of %d samples (last %s)", Percent(bucket.readable, bucket.total), bucket.total, tostring(bucket.last))
end

function addon:FinishRageProbe(reason)
    if not probe then
        return
    end

    if not probe.recording then
        probe = nil
        frame:UnregisterAllEvents()
        self:Print("Rage probe cancelled before combat started.")
        return
    end

    probe.recording = false
    frame:UnregisterAllEvents()

    local seconds = GetTime() - probe.startedAt
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
    end

    add(string.format("Rage probe report (%.0fs in combat, %d of your casts, ended: %s)", seconds, probe.casts, reason or "manual"))
    add("Rage when armed (out of combat): " .. tostring(probe.startRage or "hidden"))
    add("UnitPower rage: " .. BucketText(probe.unitPower))
    add("UnitPowerPercent rage: " .. BucketText(probe.unitPowerPercent))
    add(string.format("ShouldUnitPowerBeSecret said secret: %d, not secret: %d", probe.secretFlag.yes, probe.secretFlag.no))
    add(string.format("Rage-change events: %d fired (%.1f/s); %d not near one of your casts (likely auto-attacks or damage taken); power type readable %d / secret %d",
        probe.powerEvents, probe.powerEvents / math.max(1, seconds), probe.powerEventsNoCast, probe.powerTypeReadable, probe.powerTypeSecret))
    add("Attack speed: " .. BucketText(probe.attackSpeed))

    for _, spell in ipairs(probe.spells) do
        local costText = spell.costOutOfCombat and tostring(spell.costOutOfCombat) or ("? (" .. tostring(spell.costOutOfCombatWhy) .. ")")
        local combatCost = spell.costInCombat and tostring(spell.costInCombat) or ("? (" .. tostring(spell.costInCombatWhy or "not sampled") .. ")")
        add(string.format("  %s (%d): cost %s out of combat / %s in combat; usable flips %d; short-on-rage flag readable %d / secret %d",
            spell.name, spell.id, costText, combatCost, spell.usableFlips, spell.flagReadable, spell.flagSecret))
    end

    local topNames = {}
    for name, count in pairs(probe.assisted.names) do
        topNames[#topNames + 1] = { name = name, count = count }
    end
    table.sort(topNames, function(a, b) return a.count > b.count end)
    local parts = {}
    for index = 1, math.min(5, #topNames) do
        parts[#parts + 1] = topNames[index].name .. " " .. topNames[index].count
    end
    add(string.format("Assisted Highlight: %d readable suggestions; Rampage %d; top: %s",
        probe.assisted.total, probe.assisted.rampage, #parts > 0 and table.concat(parts, ", ") or "none (is Assisted Highlight enabled?)"))

    for _, line in ipairs(lines) do
        self:Print(line)
    end

    if self.db then
        self.db.rageProbe = {
            recordedAt = date and date("%Y-%m-%d %H:%M:%S") or nil,
            lines = lines,
        }
    end
    self:Print("Saved to SavedVariables (rageProbe). /reload to write it to disk.")
    probe = nil
end

frame:SetScript("OnEvent", function(_, event, unit, powerType)
    if not probe then
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        if not probe.recording then
            StartRecording()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if probe.recording then
            addon:FinishRageProbe("left combat")
        end
        return
    end

    if not probe.recording then
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        probe.casts = probe.casts + 1
        probe.lastCastAt = GetTime()
        return
    end

    if (event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE") and unit == "player" then
        if type(powerType) == "string" and not IsSecret(powerType) then
            probe.powerTypeReadable = probe.powerTypeReadable + 1
            if powerType ~= "RAGE" then
                return
            end
        else
            probe.powerTypeSecret = probe.powerTypeSecret + 1
        end
        probe.powerEvents = probe.powerEvents + 1
        if (GetTime() - (probe.lastCastAt or 0)) > 0.3 then
            probe.powerEventsNoCast = probe.powerEventsNoCast + 1
        end
    end
end)

function addon:RageProbeCommand()
    if probe then
        self:FinishRageProbe("manual")
        return
    end

    probe = { recording = false }
    local okPower, power = pcall(UnitPower, "player", RAGE)
    probe.startRage = okPower and Readable(power) or nil
    -- Read costs now, while out of combat, before Midnight can hide them.
    probe.armedSpells = KnownProbeSpells()
    for _, spell in ipairs(probe.armedSpells) do
        spell.cost, spell.why = ReadRageCost(spell.id)
    end

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    -- UNIT_POWER_FREQUENT fires for each change; UNIT_POWER_UPDATE is the
    -- throttled version. Register only the frequent one to avoid double counts.
    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")

    if not sampler then
        sampler = C_Timer.NewTicker(0.25, Sample)
    end

    if UnitAffectingCombat("player") then
        StartRecording()
    else
        self:Print("Rage probe armed. Pull a target dummy; recording starts when combat starts.")
    end
end
