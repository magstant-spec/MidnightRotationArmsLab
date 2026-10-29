local addonName, addon = ...

-- ---------------------------------------------------------------------------
-- Data-driven spec engine (0.5.0)
--
-- Each DPS spec that does not have a hand-written engine in Engine.lua is
-- described by a profile (see Specs\*.lua): its spells, inferred DoTs/buffs,
-- proc signals and ordered priority lists. The engine evaluates the active
-- profile every tick using only signals Midnight still exposes in combat:
--   * spell usability, cooldown isActive and cast-based cooldown estimates
--   * proc glows (overlay API + glow events) on the spender buttons
--   * the player's own successful casts (DoT/buff windows, counters)
--   * secondary resources (combo points, chi, holy power, shards, essence,
--     arcane charges, runes), and a usability-derived band for primary power
--   * readable target health when available
-- Unknown values are passed to profile conditions as nil so each entry can
-- decide how to treat missing information.
-- ---------------------------------------------------------------------------

local SE = {}
addon.SpecEngine = SE

local playerClass = select(2, UnitClass("player"))
local PowerType = Enum and Enum.PowerType or {}

SE.profiles = {}
SE.profilesByName = {}

local resolvedCache = {}
local talentCache = {}
local costCache = {}
local dotExpiry = {}       -- dotExpiry[key][unitKey] = expiresAt
local buffExpiry = {}      -- buffExpiry[key] = expiresAt
local counters = {}        -- counters[key] = { value =, at = }
local lastCastAt = {}      -- lastCastAt[key] = time
local lastCastKey = nil
local lastCastKeyAt = 0
local activeProfileKey = nil

local function I()
    return addon.EngineInternals
end

local function IsSecret(value)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        return ok and secret == true
    end
    return false
end

local function SafeNumber(value)
    if type(value) ~= "number" or IsSecret(value) then
        return nil
    end
    local ok = pcall(function() return value + 0 end)
    return ok and value or nil
end

-- ---------------------------------------------------------------------------
-- Profile registration
-- ---------------------------------------------------------------------------

local function NormalizeSpellDef(key, def)
    if type(def) == "string" then
        def = { def }
    end

    local names = {}
    for _, value in ipairs(def) do
        if type(value) == "string" then
            names[#names + 1] = value
        end
    end
    if def.names then
        for _, value in ipairs(def.names) do
            names[#names + 1] = value
        end
    end

    def.names = names
    def.key = key
    return def
end

function addon:RegisterSpecProfile(profile)
    if type(profile) ~= "table" or not profile.key then
        return
    end

    profile.spells = profile.spells or {}
    for key, def in pairs(profile.spells) do
        profile.spells[key] = NormalizeSpellDef(key, def)
    end

    profile.dots = profile.dots or {}
    profile.buffs = profile.buffs or {}
    profile.procs = profile.procs or {}
    profile.counters = profile.counters or {}
    profile.aoeThreshold = profile.aoeThreshold or 3

    -- name -> key reverse map for cast tracking
    profile.nameToKey = {}
    for key, def in pairs(profile.spells) do
        for _, name in ipairs(def.names) do
            profile.nameToKey[name] = profile.nameToKey[name] or key
        end
    end

    if profile.specID then
        SE.profiles[profile.specID] = profile
    end
    if profile.class and profile.specName then
        SE.profilesByName[profile.class .. ":" .. profile.specName] = profile
    end
end

function SE:InvalidateCaches()
    wipe(resolvedCache)
    wipe(talentCache)
end

function SE:GetActiveProfile()
    if not GetSpecialization or not GetSpecializationInfo then
        return nil
    end

    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end

    local specID, specName = GetSpecializationInfo(specIndex)
    local profile = (specID and self.profiles[specID])
        or (specName and self.profilesByName[playerClass .. ":" .. specName])
    if profile and profile.class ~= playerClass then
        return nil
    end

    if profile and activeProfileKey ~= profile.key then
        activeProfileKey = profile.key
        self:InvalidateCaches()
        wipe(dotExpiry)
        wipe(buffExpiry)
        wipe(counters)
        wipe(lastCastAt)
    end

    return profile
end

-- ---------------------------------------------------------------------------
-- Spell resolution (by name, so Midnight spell ID changes do not break it)
-- ---------------------------------------------------------------------------

local function GetSpellIDByName(name)
    if not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    if ok and type(info) == "table" then
        return SafeNumber(info.spellID)
    end
    return nil
end

local function GetSpellNameByID(spellID)
    if not spellID or not C_Spell or not C_Spell.GetSpellName then
        return nil
    end
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    if ok and type(name) == "string" and not IsSecret(name) then
        return name
    end
    return nil
end

local function GetOverrideSpellID(spellID)
    if not spellID or not C_Spell or not C_Spell.GetOverrideSpell then
        return spellID
    end
    local ok, overrideID = pcall(C_Spell.GetOverrideSpell, spellID)
    overrideID = ok and SafeNumber(overrideID) or nil
    return overrideID or spellID
end

local function IsKnown(spellID)
    local internals = I()
    if internals and internals.IsSpellKnownInBook(spellID) then
        return true
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known == true then
            return true
        end
    end
    return false
end

local function ResolveBase(def)
    for _, id in ipairs(def.ids or {}) do
        if IsKnown(id) then
            return id
        end
    end

    for _, name in ipairs(def.names) do
        local id = GetSpellIDByName(name)
        if id and IsKnown(id) then
            return id
        end
    end

    local internals = I()
    if internals and internals.ResolveActionBarSpellIDByName then
        local id = internals.ResolveActionBarSpellIDByName(def.names)
        if id then
            return id
        end
    end

    return nil
end

-- Returns the castable spell ID for a profile key, or nil when unavailable.
-- Keys with overrideOf are only available while the base spell is currently
-- transformed into one of the listed names (e.g. Chaos Strike -> Annihilation).
function SE:ResolveSpell(profile, key)
    local def = profile.spells[key]
    if not def then
        return nil
    end

    if def.overrideOf then
        local baseID = self:ResolveSpell(profile, def.overrideOf)
        if not baseID then
            return nil
        end
        local currentID = GetOverrideSpellID(baseID)
        local currentName = GetSpellNameByID(currentID)
        for _, name in ipairs(def.names) do
            if currentName == name then
                return currentID
            end
        end
        return nil
    end

    local cached = resolvedCache[key]
    if cached == nil then
        cached = ResolveBase(def) or false
        resolvedCache[key] = cached
    end

    if not cached then
        return nil
    end

    return GetOverrideSpellID(cached)
end

function SE:HasTalent(name)
    local cached = talentCache[name]
    if cached ~= nil then
        return cached
    end

    local id = GetSpellIDByName(name)
    local known = id ~= nil and IsKnown(id) or false
    talentCache[name] = known
    return known
end

-- ---------------------------------------------------------------------------
-- Readiness checks
-- ---------------------------------------------------------------------------

local function SpellHasRange(spellID)
    if C_Spell and C_Spell.SpellHasRange then
        local ok, hasRange = pcall(C_Spell.SpellHasRange, spellID)
        if ok and type(hasRange) == "boolean" then
            return hasRange
        end
    end
    return false
end

local function IsUsableNow(spellID)
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable, noResource = pcall(C_Spell.IsSpellUsable, spellID)
        if ok then
            return usable == true and noResource ~= true, noResource == true
        end
    end
    return false, false
end

local function IsOffCooldown(spellID)
    if not C_Spell or not C_Spell.GetSpellCooldown then
        return true
    end
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or not info then
        return true
    end
    local okRead, ready = pcall(function()
        if info.isEnabled == false then
            return false
        end
        if info.isActive == false or info.isOnGCD == true then
            return true
        end
        local startTime, duration = info.startTime, info.duration
        if not startTime or not duration or startTime <= 0 or duration <= 0 then
            return true
        end
        return (startTime + duration - GetTime()) <= 0.1
    end)
    if okRead then
        return ready
    end
    -- Times are secret; isActive was true, so the spell is cooling down.
    return false
end

local function IsInRangeOfTarget(spellID)
    if not C_Spell or not C_Spell.IsSpellInRange then
        return true
    end
    local ok, inRange = pcall(C_Spell.IsSpellInRange, spellID, "target")
    if not ok then
        return true
    end
    return inRange ~= false
end

-- ---------------------------------------------------------------------------
-- Resources
-- ---------------------------------------------------------------------------

local function ReadPower(powerType)
    if powerType == nil then
        return nil
    end
    local internals = I()
    if internals and internals.IsUnitPowerSecret("player", powerType) then
        return nil
    end
    local ok, value = pcall(UnitPower, "player", powerType)
    return ok and SafeNumber(value) or nil
end

local function ReadPowerMax(powerType)
    if powerType == nil or not UnitPowerMax then
        return nil
    end
    local ok, value = pcall(UnitPowerMax, "player", powerType)
    return ok and SafeNumber(value) or nil
end

local function GetPowerCost(spellID, powerType)
    local cacheKey = spellID .. ":" .. tostring(powerType)
    local cached = costCache[cacheKey]
    if cached ~= nil then
        return cached or nil
    end
    if not C_Spell or not C_Spell.GetSpellPowerCost then
        return nil
    end
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or type(costs) ~= "table" then
        return nil
    end
    local okRead, cost = pcall(function()
        for _, entry in ipairs(costs) do
            if entry.type == powerType and type(entry.cost) == "number" and entry.cost > 0 then
                return entry.cost
            end
        end
        return false
    end)
    if not okRead then
        return nil
    end
    costCache[cacheKey] = cost
    return cost or nil
end

-- ---------------------------------------------------------------------------
-- Target count for ranged specs: hostile, in-combat nameplates in range of the
-- reference spell. Melee specs reuse Engine's melee counter.
-- ---------------------------------------------------------------------------

local function CountRangedTargets(referenceSpellID)
    local internals = I()
    if not internals or not internals.HasHostileLivingTarget() then
        return 0
    end

    local count = 1
    local seen = { target = true }
    local function consider(unit)
        if not unit or seen[unit] or not UnitExists(unit) then
            return
        end
        seen[unit] = true
        if not UnitCanAttack("player", unit) or UnitIsDead(unit) then
            return
        end
        local okSame, same = pcall(function() return UnitIsUnit(unit, "target") == true end)
        if okSame and same then
            return
        end
        local okCombat, inCombat = pcall(function() return UnitAffectingCombat(unit) == true end)
        if okCombat and not inCombat and not internals.IsTrainingDummyUnit(unit) then
            return
        end
        if referenceSpellID and C_Spell and C_Spell.IsSpellInRange then
            local ok, inRange = pcall(C_Spell.IsSpellInRange, referenceSpellID, unit)
            if ok and inRange == false then
                return
            end
        end
        count = count + 1
    end

    for index = 1, 40 do
        consider("nameplate" .. index)
    end

    return count
end

-- ---------------------------------------------------------------------------
-- Cast tracking (called from Engine's UNIT_SPELLCAST_SUCCEEDED)
-- ---------------------------------------------------------------------------

local function TargetUnitKey()
    local ok, guid = pcall(UnitGUID, "target")
    if ok and type(guid) == "string" and not IsSecret(guid) then
        return guid
    end
    return "target"
end

local function ApplyDot(dotKey, dot)
    dotExpiry[dotKey] = dotExpiry[dotKey] or {}
    local unitKey = TargetUnitKey()
    local now = GetTime()
    local duration = dot.duration or 15
    local remaining = math.max(0, (dotExpiry[dotKey][unitKey] or 0) - now)
    -- Pandemic: carry over up to 30% of the base duration.
    dotExpiry[dotKey][unitKey] = now + duration + math.min(remaining, duration * 0.3)
end

local function ListContains(list, value)
    if type(list) == "string" then
        return list == value
    end
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

function SE:OnSpellCast(spellID, spellName)
    local profile = self:GetActiveProfile()
    if not profile then
        return
    end

    local name = spellName or GetSpellNameByID(spellID)
    local key = name and profile.nameToKey[name] or nil
    if not key then
        return
    end

    local now = GetTime()
    lastCastAt[key] = now
    lastCastKey = key
    lastCastKeyAt = now

    for dotKey, dot in pairs(profile.dots) do
        if ListContains(dot.castBy, key) then
            ApplyDot(dotKey, dot)
        end
    end

    for buffKey, buff in pairs(profile.buffs) do
        if ListContains(buff.castBy, key) then
            buffExpiry[buffKey] = now + (buff.duration or 10)
        end
        if buff.consumedBy and ListContains(buff.consumedBy, key) then
            buffExpiry[buffKey] = 0
        end
        if buff.extendBy and buff.extendBy[key] and (buffExpiry[buffKey] or 0) > now then
            buffExpiry[buffKey] = buffExpiry[buffKey] + buff.extendBy[key]
        end
    end

    for counterKey, counter in pairs(profile.counters) do
        local entry = counters[counterKey] or { value = 0, at = 0 }
        if counter.expire and entry.at > 0 and (now - entry.at) > counter.expire then
            entry.value = 0
        end
        local delta = counter.gain and counter.gain[key]
        if delta then
            entry.value = math.min(counter.max or 99, entry.value + delta)
            entry.at = now
        end
        local spend = counter.spend and counter.spend[key]
        if spend then
            entry.value = spend == "all" and 0 or math.max(0, entry.value - spend)
            entry.at = now
        end
        counters[counterKey] = entry
    end
end

function SE:OnTargetChanged()
    for _, units in pairs(dotExpiry) do
        units.target = nil
    end
end

function SE:OnCombatEnd()
    wipe(counters)
end

-- ---------------------------------------------------------------------------
-- State object passed to profile conditions
-- ---------------------------------------------------------------------------

local State = {}
State.__index = State

-- Castable spell ID for a key (nil if not known/talented).
function State:id(key)
    local cached = self._ids[key]
    if cached == nil then
        cached = SE:ResolveSpell(self.profile, key) or false
        self._ids[key] = cached
    end
    return cached or nil
end

function State:known(key)
    return self:id(key) ~= nil
end

-- Usable now: known, resources, cooldown, range/target, cooldown toggle.
function State:ready(key)
    local cached = self._ready[key]
    if cached ~= nil then
        return cached
    end

    local result = false
    local spellID = self:id(key)
    local def = self.profile.spells[key]
    local internals = I()
    if spellID and def then
        local engine = internals.Engine
        local majorBlocked = def.major and not engine.ShouldRecommendMajorCooldowns()
        if not majorBlocked and not engine.IsBlacklistedRecommendation(spellID) then
            local usable = IsUsableNow(spellID)
            if usable and IsOffCooldown(spellID) then
                if def.self or not SpellHasRange(spellID) then
                    result = true
                else
                    result = internals.HasHostileLivingTarget() and IsInRangeOfTarget(spellID)
                end
            end
        end
    end

    self._ready[key] = result
    return result
end

-- Remaining cooldown in seconds (estimated from casts when hidden), or nil.
function State:cd(key)
    local spellID = self:id(key)
    if not spellID then
        return nil
    end
    if IsOffCooldown(spellID) then
        return 0
    end
    local remaining = I().GetCooldownRemaining(spellID)
    if remaining == math.huge then
        return nil
    end
    return remaining
end

function State:cdBelow(key, seconds, unknownDefault)
    local remaining = self:cd(key)
    if remaining == nil then
        return unknownDefault == true
    end
    return remaining <= seconds
end

-- Current charges if readable (out of combat), else nil.
function State:charges(key)
    local spellID = self:id(key)
    if not spellID then
        return nil
    end
    local count, known = I().GetSpellChargesAvailable(spellID)
    if known then
        return count
    end
    return nil
end

-- Proc signal: real aura (when readable), overlay glow on any listed spell, or
-- an inferred buff window.
function State:proc(key)
    local cached = self._procs[key]
    if cached ~= nil then
        return cached
    end

    local proc = self.profile.procs[key]
    local internals = I()
    local result = false
    if proc then
        for _, auraName in ipairs(proc.auras or {}) do
            if internals.HasPlayerAuraByName(auraName) then
                result = true
                break
            end
        end
        if not result then
            for _, spellKey in ipairs(proc.glow or {}) do
                local spellID = self:id(spellKey)
                if spellID and internals.IsSpellOverlayedSafe(spellID) then
                    result = true
                    break
                end
            end
        end
        if not result and proc.window then
            result = self:buff(proc.window) > 0
        end
    end

    self._procs[key] = result
    return result
end

-- Inferred/real buff remaining seconds.
function State:buff(key)
    local buff = self.profile.buffs[key]
    local remaining = 0
    if buff then
        local internals = I()
        for _, auraName in ipairs(buff.auras or {}) do
            remaining = math.max(remaining, internals.GetPlayerAuraRemainingByName(auraName))
        end
        remaining = math.max(remaining, (buffExpiry[key] or 0) - self.now)
    end
    return math.max(0, remaining)
end

function State:buffUp(key)
    return self:buff(key) > 0
end

-- Inferred/real debuff remaining on the current target.
function State:dot(key)
    local dot = self.profile.dots[key]
    if not dot then
        return 0
    end
    local internals = I()
    local remaining = 0
    for _, auraName in ipairs(dot.auras or {}) do
        remaining = math.max(remaining, internals.TargetDebuffRemainingByName(auraName))
    end
    local units = dotExpiry[key]
    if units then
        remaining = math.max(remaining, (units[self.targetKey] or 0) - self.now)
    end
    return math.max(0, remaining)
end

function State:dotUp(key)
    return self:dot(key) > 0
end

-- Missing or inside the pandemic window (30% of base duration by default).
function State:refreshable(key, window)
    local dot = self.profile.dots[key]
    local threshold = window or ((dot and dot.duration or 15) * 0.3)
    return self:dot(key) <= threshold
end

function State:counter(key)
    local counter = self.profile.counters[key]
    local entry = counters[key]
    if not counter or not entry then
        return 0
    end
    if counter.expire and (self.now - entry.at) > counter.expire then
        return 0
    end
    return entry.value
end

function State:since(key)
    local castAt = lastCastAt[key]
    if not castAt then
        return math.huge
    end
    return self.now - castAt
end

function State:lastCast(key)
    return lastCastKey == key and (self.now - lastCastKeyAt) < 3
end

-- Count shown on a spell's action button (souls, stacks, charges); nil if hidden.
function State:castCount(key)
    local spellID = self:id(key)
    if not spellID or not C_Spell or not C_Spell.GetSpellCastCount then
        return nil
    end
    local ok, count = pcall(C_Spell.GetSpellCastCount, spellID)
    return ok and SafeNumber(count) or nil
end

-- Stacks of a player aura that Midnight keeps readable (Maelstrom Weapon,
-- Icicles, Tip of the Spear, ...); nil when the aura data is hidden.
function State:auraStacks(auraName)
    local internals = I()
    if internals.GetPlayerAuraRemainingByName(auraName) <= 0 and not internals.HasPlayerAuraByName(auraName) then
        return 0
    end
    local stacks = internals.GetPlayerAuraStacksByName(auraName)
    return SafeNumber(stacks)
end

function State:stealthed()
    if IsStealthed then
        local ok, stealthed = pcall(IsStealthed)
        return ok and stealthed == true
    end
    return false
end

function State:hasPet()
    return UnitExists("pet") == true and not UnitIsDead("pet")
end

function State:channeling()
    if not UnitChannelInfo then
        return nil
    end
    local ok, name = pcall(UnitChannelInfo, "player")
    if ok and type(name) == "string" and not IsSecret(name) then
        return name
    end
    return nil
end

function State:talent(name)
    return SE:HasTalent(name)
end

function State:hero(name)
    return addon:HasActiveHeroTalentName(name)
end

-- Primary power: exact when readable, otherwise a usability band.
function State:power()
    return self.primary
end

function State:powerAtLeast(amount, unknownDefault)
    if self.primary then
        return self.primary >= amount
    end
    if self.primaryLow and self.primaryLow >= amount then
        return true
    end
    if self.primaryHigh and self.primaryHigh <= amount then
        return false
    end
    return unknownDefault == true
end

function State:powerDeficitBelow(amount, unknownDefault)
    if self.primary and self.primaryMax then
        return (self.primaryMax - self.primary) < amount
    end
    return unknownDefault == true
end

-- Secondary resource (combo points, chi, shards, ...); nil when unreadable.
function State:resource()
    return self.secondary
end

function State:resourceAtLeast(amount, unknownDefault)
    if self.secondary == nil then
        return unknownDefault == true
    end
    return self.secondary >= amount
end

function State:resourceBelow(amount, unknownDefault)
    if self.secondary == nil then
        return unknownDefault == true
    end
    return self.secondary < amount
end

function State:resourceDeficit()
    if self.secondary == nil or self.secondaryMax == nil then
        return nil
    end
    return self.secondaryMax - self.secondary
end

-- Target health fraction checks; nil-safe.
function State:hpBelow(fraction, unknownDefault)
    if self.targetHealth == nil then
        return unknownDefault == true
    end
    return self.targetHealth <= fraction
end

function State:hpAbove(fraction, unknownDefault)
    if self.targetHealth == nil then
        return unknownDefault == true
    end
    return self.targetHealth > fraction
end

-- ---------------------------------------------------------------------------
-- State construction
-- ---------------------------------------------------------------------------

function SE:BuildState()
    local profile = self:GetActiveProfile()
    if not profile then
        return nil
    end

    local internals = I()
    if not internals then
        return nil
    end

    local engine = internals.Engine

    -- Talent swaps out of combat do not always fire the events the shared
    -- cache listens to; re-resolve names every few seconds while idle.
    local now = GetTime()
    if not UnitAffectingCombat("player") and (now - (self.lastIdleInvalidate or 0)) > 5 then
        self.lastIdleInvalidate = now
        self:InvalidateCaches()
    end

    local s = setmetatable({
        profile = profile,
        now = GetTime(),
        _ids = {},
        _ready = {},
        _procs = {},
    }, State)

    s.targetKey = TargetUnitKey()

    -- Target count
    local referenceIDs = {}
    for _, key in ipairs(profile.rangeSpells or {}) do
        local id = s:id(key)
        if id then
            referenceIDs[#referenceIDs + 1] = id
        end
    end

    local detected = 0
    if internals.HasHostileLivingTarget() then
        if profile.melee then
            detected = engine.CountHostileTargetsInMeleeRange(referenceIDs)
        else
            detected = CountRangedTargets(referenceIDs[1])
        end
    end
    local targetCount, targetSource = engine.ResolveTargetCount(detected)
    targetCount = targetCount or detected

    s.targets = targetCount
    s.aoe = targetCount >= profile.aoeThreshold
    s.cleave = targetCount >= 2
    s.gcd = internals.GetApproxGlobalCooldown()
    s.inCombat = UnitAffectingCombat("player") == true
    s.targetHealth = internals.GetUnitHealthPercent("target")

    -- Primary power
    local primaryType = profile.primaryPower
    s.primary = ReadPower(primaryType)
    s.primaryMax = ReadPowerMax(primaryType)
    if s.primary == nil and primaryType ~= nil then
        for _, def in pairs(profile.spells) do
            local spellID = s:id(def.key)
            if spellID then
                local cost = GetPowerCost(spellID, primaryType)
                if cost then
                    local usable, noResource = IsUsableNow(spellID)
                    if noResource then
                        s.primaryHigh = s.primaryHigh and math.min(s.primaryHigh, cost) or cost
                    elseif usable then
                        s.primaryLow = s.primaryLow and math.max(s.primaryLow, cost) or cost
                    end
                end
            end
        end
    end

    -- Secondary resource
    if profile.secondaryPower == "RUNES" then
        local runes, known = internals.GetReadyRuneCount()
        s.secondary = known and runes or nil
        s.secondaryMax = 6
    elseif profile.secondaryPower ~= nil then
        s.secondary = ReadPower(profile.secondaryPower)
        s.secondaryMax = ReadPowerMax(profile.secondaryPower)
    end

    s.assistedSuggestion = engine.GetAssistedCombatSuggestion()

    if profile.prepare then
        local ok, err = pcall(profile.prepare, s)
        if not ok then
            s.genericError = tostring(err)
        end
    end

    local hasTarget = internals.HasHostileLivingTarget()
    local heroName = addon:GetActiveHeroTalentSpecName()

    -- Fields read by the shared UI, trace and dump code.
    s.profileType = "GENERIC_SPEC"
    s.isGenericSpec = true
    s.genericSpecKey = profile.key
    s.hasTarget = hasTarget
    s.targetCount = targetCount
    s.detectedTargetCount = detected
    s.targetCountSource = targetSource
    s.targetCountOverride = engine.GetTargetCountOverride()
    s.isAOE = s.aoe
    s.isCleave = s.cleave and not s.aoe
    s.isLargeAOE = s.aoe
    s.resourceName = profile.secondaryName or profile.primaryName
    s.resourceKnown = (profile.secondaryPower and s.secondary ~= nil) or (s.primary ~= nil)
    s.resource = profile.secondaryPower and s.secondary or s.primary
    s.activeHeroTalentName = heroName
    s.targetHealthKnown = s.targetHealth ~= nil
    s.targetHealthPercent = s.targetHealth

    return s
end

local function EntryApplies(s, entry)
    if entry.aoe == true and not s.aoe then
        return false
    end
    if entry.aoe == false and s.aoe then
        return false
    end
    if entry.cleave == true and not s.cleave then
        return false
    end
    if entry.st == true and s.cleave then
        return false
    end
    if entry.hero and not s:hero(entry.hero) then
        return false
    end
    if entry.notHero and s:hero(entry.notHero) then
        return false
    end
    if entry.talent and not s:talent(entry.talent) then
        return false
    end
    if entry.notTalent and s:talent(entry.notTalent) then
        return false
    end
    if entry.combat == true and not s.inCombat then
        return false
    end
    return true
end

local function EvaluateList(s, list, listName)
    local comboStrikes = s.profile.comboStrikes == true
    for index, entry in ipairs(list or {}) do
        local key = entry[1]
        local repeatBlocked = comboStrikes and entry.allowRepeat ~= true and s:lastCast(key)
        if not repeatBlocked and EntryApplies(s, entry) and s:ready(key) then
            local ok, pass = true, true
            if entry.when then
                ok, pass = pcall(entry.when, s)
            end
            if ok and pass then
                s.genericReason = string.format("%s#%d %s%s", listName, index, key, entry.note and (" (" .. entry.note .. ")") or "")
                return s:id(key)
            elseif not ok then
                s.genericError = tostring(pass)
            end
        end
    end
    return nil
end

function SE:Recommend(s)
    if not s or not s.profile then
        return nil
    end

    local profile = s.profile
    if profile.precombat and not s.inCombat then
        local spellID = EvaluateList(s, profile.precombat, "pre")
        if spellID then
            return spellID
        end
    end

    local listName = s.aoe and "aoe" or "st"
    local list = s.aoe and (profile.aoe or profile.st) or profile.st
    local spellID = EvaluateList(s, list, listName)
    if spellID then
        return spellID
    end

    if profile.fallback then
        return EvaluateList(s, profile.fallback, "fill")
    end

    s.genericReason = "none"
    return nil
end

function SE:GetProfileLabel()
    local profile = self:GetActiveProfile()
    if not profile then
        return nil
    end
    local heroName = addon:GetActiveHeroTalentSpecName()
    if heroName then
        return profile.label .. " - " .. heroName
    end
    return profile.label
end

-- Invalidate name resolution whenever the shared engine rebuilds its caches
-- (spellbook, talents or spec changed).
if hooksecurefunc and addon.ResetResolvedSpellCache then
    hooksecurefunc(addon, "ResetResolvedSpellCache", function()
        SE:InvalidateCaches()
    end)
end

SE.PowerType = PowerType
