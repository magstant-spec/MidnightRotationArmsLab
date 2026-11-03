local addon = select(2, ...)

local playerClass = select(2, UnitClass("player"))
local resolvedSpellIDs = {}
local cooldownViewerSpellStates = {}
local cooldownViewerLastScanTime = 0
local combatStartedAt = nil
local furyOpenerBloodthirstDone = false
local furyOpenerBloodthirstCastAt = 0
local furyLastRampageCastAt = 0
local furyGeneratorCastsSinceRampage = 0
-- 0.5.1 hidden-rage estimate: Rampage becomes usable at exactly its cost (80),
-- so the time and generator casts since it became usable approximate how far
-- above 80 rage the player is.
local furyRampageUsableSince = 0
local furyLastRecklessnessCastAt = 0
local armsLastOverpowerCastAt = 0
local furyGeneratorsSinceRampageUsable = 0
local furyLastGeneratorCountedAt = 0
local furyAssumedEnrageExpiresAt = 0
local furyAssumedRecklessnessExpiresAt = 0
local armsLastColossusCastAt = 0
local armsLastBladestormCastAt = 0
local armsAssumedExecutionersPrecisionStacks = 0
local armsAssumedExecutionersPrecisionExpiresAt = 0
local armsLastExecutionersPrecisionExecuteAt = 0
local frostDKLastFrostwyrmsFuryCastAt = 0
local subtletyAssumedShadowDanceExpiresAt = 0
local subtletyAssumedShadowBladesExpiresAt = 0
local retCombatStartedAt = nil
local retOpenerBladeOfJusticeDone = false
local retOpenerBladeOfJusticeCastAt = 0
local retLastWakeOfAshesCastAt = 0
local retLastHammerOfLightCastAt = 0
local furyAssumedWhirlwindStacks = 0
local furyAssumedWhirlwindExpiresAt = 0
local recentDamageTargets = {}
local autoTargetBand = nil
local autoTargetCount = 1
local pendingAutoTargetBand = nil
local pendingAutoTargetBandSince = nil
local lastTargetCountWasAuto = false

local RAGE_POWER_TYPE = Enum and Enum.PowerType and Enum.PowerType.Rage or 1
local FOCUS_POWER_TYPE = Enum and Enum.PowerType and Enum.PowerType.Focus or 2
local RUNIC_POWER_TYPE = Enum and Enum.PowerType and Enum.PowerType.RunicPower or 6
local ENERGY_POWER_TYPE = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
local COMBO_POINTS_POWER_TYPE = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local Engine = {}
local RECENT_DAMAGE_TARGET_WINDOW = 4.0
local AUTO_TARGET_PROMOTE_DELAY = 0.25
local AUTO_TARGET_DEMOTE_DELAY = 1.00

local RET = {
    specID = 70,
    holyPowerType = Enum and Enum.PowerType and Enum.PowerType.HolyPower or 9,
    avengingWrath = 31884,
    crusade = 231895,
    executionSentence = 1260251,
    finalVerdict = 383328,
    templarsVerdict = 85256,
    divineStorm = 53385,
    wakeOfAshes = 453868,
    divineToll = 375576,
    hammerOfLight = 427453,
    hammerOfWrath = 1291678,
    bladeOfJustice = 404358,
    judgment = 406957,
    crusaderStrike = 35395,
    templarStrike = 407480,
    templarSlash = 406647,
    empyreanPowerAura = 326732,
    lightsDeliveranceAura = 433674,
    expurgationDebuff = 273473,
    divinePurposeAura = 223819,
    avengingWrathCandidates = { 31884, 231895 },
    executionSentenceCandidates = { 1260251, 343527, 267798 },
    finalVerdictCandidates = { 383328, 336872, 157048 },
    templarsVerdictCandidates = { 85256 },
    divineStormCandidates = { 53385 },
    wakeOfAshesCandidates = { 453868, 255991, 205273 },
    divineTollCandidates = { 375576, 304971 },
    hammerOfLightCandidates = { 427453 },
    hammerOfWrathCandidates = { 1291678, 24275 },
    bladeOfJusticeCandidates = { 404358, 184575 },
    judgmentCandidates = { 406957, 197277, 20271 },
    crusaderStrikeCandidates = { 35395 },
    templarStrikeCandidates = { 407480 },
    templarSlashCandidates = { 406647 },
}

local FROST_DK = {
    specID = 251,
    obliterate = 49020,
    frostStrike = 49143,
    howlingBlast = 49184,
    pillarOfFrost = 51271,
    empowerRuneWeapon = 47568,
    breathOfSindragosa = 152279,
    frostwyrmsFury = 279302,
    frostscythe = 207230,
    glacialAdvance = 194913,
    reapersMark = 439843,
    remorselessWinter = 196770,
    raiseDead = 46585,
    killingMachineAura = 51124,
    rimeAura = 59052,
}

local SUB_ROGUE = {
    specID = 261,
    stealth = 1784,
    vanish = 1856,
    backstab = 53,
    gloomblade = 200758,
    shadowstrike = 185438,
    eviscerate = 196819,
    shurikenStorm = 197835,
    blackPowder = 319175,
    shadowDance = 185313,
    shadowDanceAura = 185422,
    shadowBlades = 121471,
    secretTechnique = 280719,
    goremawsBite = 209782,
}

local RAMPAGE_SPELL_ID = 184367
local BLOODTHIRST_SPELL_ID = 23881
local EXECUTE_SPELL_ID = 5308
local RAGING_BLOW_SPELL_ID = 85288
local RECKLESSNESS_SPELL_ID = 1719
local AVATAR_SPELL_ID = 107574
local CHARGE_SPELL_ID = 100
local THUNDER_CLAP_SPELL_ID = 6343
local MORTAL_STRIKE_SPELL_ID = 12294
local OVERPOWER_SPELL_ID = 7384
local REND_SPELL_ID = 772
local SLAM_SPELL_ID = 1464
local HEROIC_STRIKE_SPELL_ID = 1269383
local HEROIC_STRIKE_ACTIONBAR_SPELL_ID = 1269380
local MASTER_OF_WARFARE_PROC_AURA_ID = 1269391
local MASTER_OF_WARFARE_STACK_AURA_ID = 1269394
local HEROIC_MIGHT_AURA_ID = 1292058
local CLEAVE_SPELL_ID = 845
local COLOSSUS_SMASH_SPELL_ID = 167105
local WARBREAKER_SPELL_ID = 262161
local SWEEPING_STRIKES_SPELL_ID = 260708
local KILL_COMMAND_SPELL_ID = 34026
local BARBED_SHOT_SPELL_ID = 217200
local BESTIAL_WRATH_SPELL_ID = 19574
local BEAST_CLEAVE_AURA_ID = 268877
local TWIN_FANGS_NPC_IDS = {
    [257361] = true, -- Vexhul
    [257368] = true, -- Ithraz
}
local TWIN_FANGS_NAMES = {
    ["Vexhul"] = true,
    ["Ithraz"] = true,
}

local WHIRLWIND_CANDIDATE_SPELL_IDS = { 190411, 85739, 1680, 385228 }

local MANUAL_MAJOR_COOLDOWN_SPELL_IDS = {
    [RECKLESSNESS_SPELL_ID] = true,
    [AVATAR_SPELL_ID] = true,
    [384318] = true, -- Thunderous Roar
    [228920] = true, -- Ravager
    [376079] = true, -- Champion's Spear
    [307865] = true, -- Spear of Bastion / Champion's Spear variants
    [BESTIAL_WRATH_SPELL_ID] = true, -- Bestial Wrath
    [227847] = true, -- Bladestorm
    [389774] = true,
    [446035] = true,
    [46924] = true,
    [RET.avengingWrath] = true,
    [RET.crusade] = true,
    [FROST_DK.pillarOfFrost] = true,
    [FROST_DK.empowerRuneWeapon] = true,
    [FROST_DK.breathOfSindragosa] = true,
    [FROST_DK.frostwyrmsFury] = true,
    [FROST_DK.reapersMark] = true,
    [FROST_DK.remorselessWinter] = true,
    [FROST_DK.raiseDead] = true,
    [SUB_ROGUE.vanish] = true,
    [SUB_ROGUE.shadowDance] = true,
    [SUB_ROGUE.shadowBlades] = true,
    [SUB_ROGUE.secretTechnique] = true,
    [SUB_ROGUE.goremawsBite] = true,
}

local BLACKLISTED_RECOMMENDATION_SPELL_IDS = {}
local BM_BEAST_CLEAVE_REFRESH_DURATION = 4.0
local BM_BESTIAL_WRATH_PREP_WINDOW = 3.0
local BM_SINGLE_TARGET_COBRA_FOCUS_THRESHOLD = 60
local BM_AOE_COBRA_FOCUS_THRESHOLD = 75
addon.bmAssumedBeastCleaveExpiresAt = addon.bmAssumedBeastCleaveExpiresAt or 0
addon.armsAssumedRendExpiresAt = addon.armsAssumedRendExpiresAt or 0

function addon:ResetResolvedSpellCache()
    wipe(resolvedSpellIDs)
    wipe(cooldownViewerSpellStates)
    cooldownViewerLastScanTime = 0
end

local function GetCurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or not GetSpecializationInfo then
        return nil
    end

    return GetSpecializationInfo(specIndex)
end

function addon:GetCurrentSpecName()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or not GetSpecializationInfo then
        return nil
    end

    local _, specName = GetSpecializationInfo(specIndex)
    return specName
end

function addon:IsPassiveSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    if C_Spell and C_Spell.IsSpellPassive then
        local ok, isPassive = pcall(C_Spell.IsSpellPassive, spellID)
        if ok then
            return isPassive == true
        end
    end

    if C_SpellBook and C_SpellBook.IsSpellPassive then
        local ok, isPassive = pcall(C_SpellBook.IsSpellPassive, spellID)
        if ok then
            return isPassive == true
        end
    end

    if IsPassiveSpell then
        local ok, isPassive = pcall(IsPassiveSpell, spellID)
        if ok then
            return isPassive == true
        end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and spellInfo and spellInfo.isPassive ~= nil then
            return spellInfo.isPassive == true
        end
    end

    return false
end

function addon:IsRecommendableSpell(spellID)
    return type(spellID) == "number"
        and spellID > 0
        and not self:IsPassiveSpell(spellID)
end

local function IsFuryWarrior()
    return playerClass == "WARRIOR" and GetCurrentSpecID() == 72
end

local function IsArmsWarrior()
    return playerClass == "WARRIOR" and GetCurrentSpecID() == 71
end

local function IsRetributionPaladin()
    return playerClass == "PALADIN" and GetCurrentSpecID() == RET.specID
end

local function IsBeastMasteryHunter()
    return playerClass == "HUNTER" and GetCurrentSpecID() == 253
end

local function IsFrostDeathKnight()
    return playerClass == "DEATHKNIGHT" and GetCurrentSpecID() == FROST_DK.specID
end

local function IsSubtletyRogue()
    return playerClass == "ROGUE" and GetCurrentSpecID() == SUB_ROGUE.specID
end

local function IsUsableNonSecretNumber(value)
    local ok, usable = pcall(function()
        return type(value) == "number" and value > 0
    end)

    return ok and usable == true
end

local function IsSafeNonSecretNumber(value)
    local ok, safe = pcall(function()
        return type(value) == "number" and (value >= 0 or value < 0)
    end)

    return ok and safe == true
end

local function SafeNumberOrDefault(value, defaultValue)
    if IsSafeNonSecretNumber(value) then
        return value
    end

    return defaultValue
end

local function IsSafeNumberAtLeast(value, threshold)
    local ok, isAtLeast = pcall(function()
        return type(value) == "number" and type(threshold) == "number" and value >= threshold
    end)

    return ok and isAtLeast == true
end


local function IsCooldownViewerInfoActive(info)
    if type(info) ~= "table" then
        return false
    end

    local okHasAura, hasAura = pcall(function()
        return info.hasAura == true or info.selfAura == true
    end)
    if okHasAura and hasAura then
        return true
    end

    local okIsActive, isActive = pcall(function()
        return info.isActive == true
    end)
    if okIsActive and isActive then
        return true
    end

    return false
end

local function AddCooldownViewerSpellState(spellID, isActive, categoryKey)
    if not IsUsableNonSecretNumber(spellID) then
        return
    end

    local state = cooldownViewerSpellStates[spellID]
    if not state then
        state = { seen = true, active = false, categories = {} }
        cooldownViewerSpellStates[spellID] = state
    end

    state.seen = true
    if categoryKey then
        state.categories[categoryKey] = true
    end
    if isActive then
        state.active = true
    end

    if C_SpellBook and C_SpellBook.FindBaseSpellByID then
        local okBase, baseSpellID = pcall(C_SpellBook.FindBaseSpellByID, spellID)
        if okBase and IsUsableNonSecretNumber(baseSpellID) and baseSpellID ~= spellID then
            local baseState = cooldownViewerSpellStates[baseSpellID]
            if not baseState then
                baseState = { seen = true, active = false, categories = {} }
                cooldownViewerSpellStates[baseSpellID] = baseState
            end

            baseState.seen = true
            if categoryKey then
                baseState.categories[categoryKey] = true
            end
            if isActive then
                baseState.active = true
            end
        end
    end
end

local function AddCooldownViewerInfoSpellStates(info, isActive, categoryKey)
    if type(info) ~= "table" then
        return
    end

    AddCooldownViewerSpellState(info.spellID, isActive, categoryKey)
    AddCooldownViewerSpellState(info.overrideSpellID, isActive, categoryKey)
    AddCooldownViewerSpellState(info.overrideTooltipSpellID, isActive, categoryKey)
    AddCooldownViewerSpellState(info.linkedSpellID, isActive, categoryKey)

    local linkedSpellIDs = info.linkedSpellIDs
    if type(linkedSpellIDs) == "table" then
        for _, linkedSpellID in ipairs(linkedSpellIDs) do
            AddCooldownViewerSpellState(linkedSpellID, isActive, categoryKey)
        end
    end
end

local function ScanCooldownViewerSpellStates()
    if not C_CooldownViewer
    or not C_CooldownViewer.GetCooldownViewerCategorySet
    or not C_CooldownViewer.GetCooldownViewerCooldownInfo
    then
        return cooldownViewerSpellStates
    end

    local now = GetTime()
    if (now - cooldownViewerLastScanTime) < 0.50 then
        return cooldownViewerSpellStates
    end

    cooldownViewerLastScanTime = now
    wipe(cooldownViewerSpellStates)

    local categoryEnum = Enum and Enum.CooldownViewerCategory
    if not categoryEnum then
        return cooldownViewerSpellStates
    end

    local categoryKeys = { "Essential", "Utility", "TrackedBuff", "TrackedBar" }
    for _, categoryKey in ipairs(categoryKeys) do
        local category = categoryEnum[categoryKey]
        if IsUsableNonSecretNumber(category) or category == 0 then
            local okSet, cooldownIDs = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, category, true)
            if okSet and type(cooldownIDs) == "table" then
                for _, cooldownID in ipairs(cooldownIDs) do
                    if IsUsableNonSecretNumber(cooldownID) then
                        local okInfo, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
                        if okInfo and type(info) == "table" then
                            AddCooldownViewerInfoSpellStates(info, IsCooldownViewerInfoActive(info), categoryKey)
                        end
                    end
                end
            end
        end
    end

    return cooldownViewerSpellStates
end

local function IsCooldownViewerSpellTracked(spellID)
    if not IsUsableNonSecretNumber(spellID) then
        return false
    end

    local state = ScanCooldownViewerSpellStates()[spellID]
    return state and state.seen == true
end

local function IsCooldownViewerSpellActive(spellID)
    if not IsUsableNonSecretNumber(spellID) then
        return false
    end

    local state = ScanCooldownViewerSpellStates()[spellID]
    return state and state.active == true
end

local function NormalizeTalentName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    return name:lower():gsub("[%s%p_]+", "")
end

local function GetActiveTalentConfigID()
    if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID then
        return nil
    end

    local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if ok and type(configID) == "number" and configID > 0 then
        return configID
    end

    return nil
end

function addon:GetActiveHeroTalentSpecID()
    if C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec then
        local ok, subTreeID = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
        if ok and type(subTreeID) == "number" and subTreeID > 0 then
            return subTreeID
        end
    end

    local configID = GetActiveTalentConfigID()
    if not configID
    or not C_Traits
    or not C_Traits.GetConfigInfo
    or not C_Traits.GetTreeNodes
    or not C_Traits.GetNodeInfo
    or not C_Traits.GetEntryInfo
    then
        return nil
    end

    local okConfig, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not okConfig or not configInfo or not configInfo.treeIDs then
        return nil
    end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local okNodes, treeNodes = pcall(C_Traits.GetTreeNodes, treeID)
        if okNodes and treeNodes then
            for _, nodeID in ipairs(treeNodes) do
                local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                local activeEntry = okNode and nodeInfo and nodeInfo.activeEntry
                if activeEntry and activeEntry.entryID and (activeEntry.rank or 0) > 0 then
                    local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, activeEntry.entryID)
                    if okEntry
                    and entryInfo
                    and not entryInfo.definitionID
                    and type(entryInfo.subTreeID) == "number"
                    and entryInfo.subTreeID > 0
                    then
                        return entryInfo.subTreeID
                    end
                end
            end
        end
    end

    return nil
end

function addon:GetActiveHeroTalentSpecName()
    local configID = GetActiveTalentConfigID()
    local subTreeID = self:GetActiveHeroTalentSpecID()
    if not configID or not subTreeID or not C_Traits or not C_Traits.GetSubTreeInfo then
        return nil
    end

    local ok, subTreeInfo = pcall(C_Traits.GetSubTreeInfo, configID, subTreeID)
    if ok and subTreeInfo and subTreeInfo.name and subTreeInfo.name ~= "" then
        return subTreeInfo.name
    end

    return nil
end

function addon:HasActiveHeroTalentName(expectedName)
    local expected = NormalizeTalentName(expectedName)
    local active = NormalizeTalentName(self:GetActiveHeroTalentSpecName())
    if not expected or not active then
        return false
    end

    return active == expected or active:find(expected, 1, true) ~= nil
end

local function IsSpellKnownInBook(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID)
        if ok and known == true then
            return known == true
        end
    end

    if addon.actionSlotsBySpell and addon.actionSlotsBySpell[spellID] then
        return true
    end

    local baseSpellID = addon.FindBaseSpellID and addon:FindBaseSpellID(spellID) or nil
    if baseSpellID and addon.actionSlotsByBaseSpell and addon.actionSlotsByBaseSpell[baseSpellID] then
        return true
    end

    return IsPlayerSpell and IsPlayerSpell(spellID) or false
end

local function IsSpellKnownByPlayer(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID)
        if ok and known == true then
            return true
        end
    end

    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok then
            return known == true
        end
    end

    return false
end

local function ResolveActionBarSpellIDByName(spellNames)
    if addon.GetActionSpellIDByName then
        local spellID = addon:GetActionSpellIDByName(spellNames)
        if type(spellID) == "number" and spellID > 0 then
            return spellID
        end
    end

    return nil
end

local function ResolveKnownSpellID(cacheKey, candidateSpellIDs, fallbackName)
    local cachedSpellID = cacheKey and resolvedSpellIDs[cacheKey]
    if IsSpellKnownInBook(cachedSpellID) then
        return cachedSpellID
    end

    if candidateSpellIDs then
        for _, candidateSpellID in ipairs(candidateSpellIDs) do
            if IsSpellKnownInBook(candidateSpellID) then
                if cacheKey then
                    resolvedSpellIDs[cacheKey] = candidateSpellID
                end
                return candidateSpellID
            end
        end
    end

    if fallbackName and C_Spell and C_Spell.GetSpellInfo then
        local ok, fallbackSpellID = pcall(function()
            local spellInfo = C_Spell.GetSpellInfo(fallbackName)
            return spellInfo and spellInfo.spellID
        end)
        if IsSpellKnownInBook(fallbackSpellID) then
            if cacheKey then
                resolvedSpellIDs[cacheKey] = fallbackSpellID
            end
            return fallbackSpellID
        end
    end

    return nil
end

local function GetCooldownViewerSpellName(spellID)
    if not IsUsableNonSecretNumber(spellID) or not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end

    local ok, spellName = pcall(function()
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        return spellInfo and spellInfo.name
    end)
    if ok and type(spellName) == "string" and spellName ~= "" then
        return spellName
    end

    return nil
end

local function ResolveCooldownViewerSpellByName(cacheKey, fallbackNames)
    local cachedSpellID = cacheKey and resolvedSpellIDs[cacheKey]
    if IsUsableNonSecretNumber(cachedSpellID) and IsCooldownViewerSpellTracked(cachedSpellID) then
        return cachedSpellID
    end

    if type(fallbackNames) == "string" then
        fallbackNames = { fallbackNames }
    end

    if type(fallbackNames) ~= "table" then
        return nil
    end

    local states = ScanCooldownViewerSpellStates()
    for _, fallbackName in ipairs(fallbackNames) do
        if type(fallbackName) == "string" and fallbackName ~= "" then
            local normalizedFallbackName = fallbackName:lower()
            for spellID, state in pairs(states) do
                if IsUsableNonSecretNumber(spellID) and state and state.seen == true then
                    local spellName = GetCooldownViewerSpellName(spellID)
                    if spellName and spellName:lower() == normalizedFallbackName then
                        if cacheKey then
                            resolvedSpellIDs[cacheKey] = spellID
                        end
                        return spellID
                    end
                end
            end
        end
    end

    return nil
end

local function GetUnitAuraInfo(spellOrName, unit, filter)
    unit = unit or "player"

    if type(spellOrName) == "number" then
        if unit == "player"
        and (not filter or filter == "HELPFUL")
        and C_UnitAuras
        and C_UnitAuras.GetPlayerAuraBySpellID
        then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellOrName)
            if aura then
                return aura
            end
        end

        if AuraUtil and AuraUtil.FindAuraBySpellID then
            local ok, aura = pcall(AuraUtil.FindAuraBySpellID, spellOrName, unit, filter)
            if ok and aura then
                return aura
            end
        end

        return nil
    end

    if type(spellOrName) == "string" and AuraUtil and AuraUtil.FindAuraByName then
        local ok, aura = pcall(AuraUtil.FindAuraByName, spellOrName, unit, filter)
        if ok and aura then
            return aura
        end
    end

    return nil
end

local function GetAuraRemainingTime(aura)
    if not aura then
        return 0
    end

    local ok, remaining = pcall(function()
        local expirationTime = aura.expirationTime
        if not expirationTime or expirationTime <= 0 then
            return 0
        end

        return math.max(0, expirationTime - GetTime())
    end)

    return ok and remaining or 0
end

local function GetAuraStackCount(aura)
    if not aura then
        return 0
    end

    local ok, count = pcall(function()
        return aura.applications or aura.charges or aura.count or 0
    end)

    return ok and SafeNumberOrDefault(count, 0) or 0
end

local function GetPlayerAuraRemainingByName(name)
    return GetAuraRemainingTime(GetUnitAuraInfo(name, "player", "HELPFUL"))
end

local function GetPlayerAuraStacksByName(name)
    return GetAuraStackCount(GetUnitAuraInfo(name, "player", "HELPFUL"))
end

local function GetPlayerAuraRemainingByID(spellID)
    return GetAuraRemainingTime(GetUnitAuraInfo(spellID, "player", "HELPFUL"))
end

local function GetPlayerAuraStacksByID(spellID)
    return GetAuraStackCount(GetUnitAuraInfo(spellID, "player", "HELPFUL"))
end

local function GetUnitAuraRemainingByName(name, unit, filter)
    return GetAuraRemainingTime(GetUnitAuraInfo(name, unit, filter or "HELPFUL"))
end

local function GetUnitAuraRemainingByID(spellID, unit, filter)
    return GetAuraRemainingTime(GetUnitAuraInfo(spellID, unit, filter or "HELPFUL"))
end


local function TargetDebuffRemainingByName(name)
    if type(name) ~= "string" or name == "" then
        return 0
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for _, filter in ipairs({ "HARMFUL|PLAYER", "PLAYER|HARMFUL", "HARMFUL" }) do
            for index = 1, 40 do
                local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "target", index, filter)
                if not ok or not aura then
                    break
                end

                if aura.name == name and (aura.sourceUnit == "player" or aura.sourceUnit == "pet" or aura.sourceUnit == "vehicle") then
                    return GetAuraRemainingTime(aura)
                end
            end
        end
    end

    if not UnitDebuff then
        return 0
    end

    local index = 1
    while true do
        local auraName, _, _, _, _, expirationTime, source = UnitDebuff("target", index, "HARMFUL")
        if type(auraName) == "table" then
            local aura = auraName
            if aura.name == name and (aura.sourceUnit == "player" or aura.sourceUnit == "pet" or aura.sourceUnit == "vehicle") then
                return GetAuraRemainingTime(aura)
            end
        elseif not auraName then
            break
        elseif auraName == name and (source == "player" or source == "pet" or source == "vehicle") then
            return GetAuraRemainingTime({ expirationTime = expirationTime })
        end

        index = index + 1
    end

    return 0
end

local function GetTargetDebuffRemaining(spellID, spellName)
    if UnitExists("target") and not UnitIsDead("target") then
        local aura = GetUnitAuraInfo(spellID, "target", "HARMFUL|PLAYER")
            or GetUnitAuraInfo(spellID, "target", "PLAYER|HARMFUL")

        local remaining = GetAuraRemainingTime(aura)
        if remaining > 0 then
            return remaining
        end

        if spellName then
            return TargetDebuffRemainingByName(spellName)
        end
    end

    return 0
end

-- 0.4.1 API workarounds ---------------------------------------------------
-- Midnight hides cooldown times, primary power and most aura data in combat,
-- but the player's own successful casts, cooldown isActive flags, the GCD
-- spell (61304) and spell usability remain readable. The helpers below rebuild
-- approximate state from those signals and degrade to the old behaviour when a
-- signal is unavailable.
local GCD_SPELL_ID = 61304
local OVERLAY_GLOW_EVENT_MAX_AGE = 15.0
local spellLastCastAt = {}
local spellLastCastAtByName = {}
local learnedCooldownDuration = {}
local cooldownEstimateUsed = {}
local overlayGlowEventShownAt = {}
local observedGlobalCooldown = nil

local function IsSecretValue(value)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        return ok and secret == true
    end

    return false
end

local function GetBaseSpellIDSafe(spellID)
    if type(spellID) ~= "number" or not C_SpellBook or not C_SpellBook.FindBaseSpellByID then
        return nil
    end

    local ok, baseSpellID = pcall(C_SpellBook.FindBaseSpellByID, spellID)
    if ok and IsSafeNonSecretNumber(baseSpellID) and baseSpellID ~= spellID then
        return baseSpellID
    end

    return nil
end

local function GetSpellNameForTracking(spellID)
    if type(spellID) ~= "number" then
        return nil
    end

    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and not IsSecretValue(name) then
            return name
        end
    end

    return nil
end

function Engine.RecordSpellCastForCooldown(spellID, spellName)
    if type(spellID) ~= "number" or spellID <= 0 or IsSecretValue(spellID) then
        return
    end

    local now = GetTime()
    spellLastCastAt[spellID] = now
    local baseSpellID = GetBaseSpellIDSafe(spellID)
    if baseSpellID then
        spellLastCastAt[baseSpellID] = now
    end

    local name = type(spellName) == "string" and spellName or GetSpellNameForTracking(spellID)
    if name then
        spellLastCastAtByName[name] = now
    end
end

function Engine.ClearSpellCastCooldownTracking()
    wipe(spellLastCastAt)
    wipe(spellLastCastAtByName)
    wipe(cooldownEstimateUsed)
end

local function GetLastCastTime(spellID)
    local castAt = spellLastCastAt[spellID]
    if castAt then
        return castAt
    end

    local baseSpellID = GetBaseSpellIDSafe(spellID)
    if baseSpellID and spellLastCastAt[baseSpellID] then
        return spellLastCastAt[baseSpellID]
    end

    local name = GetSpellNameForTracking(spellID)
    return name and spellLastCastAtByName[name] or nil
end

local function GetKnownCooldownDuration(spellID)
    local learned = learnedCooldownDuration[spellID]
    if learned then
        return learned
    end

    local getter = (C_Spell and C_Spell.GetSpellBaseCooldown) or GetSpellBaseCooldown
    if getter then
        local ok, cooldownMS = pcall(getter, spellID)
        if ok and IsSafeNonSecretNumber(cooldownMS) and cooldownMS > 2000 then
            return cooldownMS / 1000
        end
    end

    return nil
end

local observedCooldownDuration = {}

local function LearnCooldownDuration(spellID, duration)
    if IsSafeNonSecretNumber(duration) and duration > 2.0 then
        learnedCooldownDuration[spellID] = duration
    end
end

-- Returns an estimated remaining cooldown from our own cast timestamp, or nil
-- when we have not seen the spell cast or do not know its cooldown length.
local function EstimateCooldownRemainingFromCast(spellID)
    local castAt = GetLastCastTime(spellID)
    local duration = GetKnownCooldownDuration(spellID)
    if not castAt or not duration then
        return nil
    end

    return math.max(0, (castAt + duration) - GetTime())
end

function Engine.WasCooldownEstimated(spellID)
    return cooldownEstimateUsed[spellID] == true
end

function addon:SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(spellID)
    if type(spellID) == "number" and not IsSecretValue(spellID) then
        overlayGlowEventShownAt[spellID] = GetTime()
    end
end

function addon:SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(spellID)
    if type(spellID) == "number" and not IsSecretValue(spellID) then
        overlayGlowEventShownAt[spellID] = nil
    end
end

local function IsOverlayGlowEventActive(spellID)
    local shownAt = type(spellID) == "number" and overlayGlowEventShownAt[spellID] or nil
    if not shownAt then
        return false
    end

    if (GetTime() - shownAt) > OVERLAY_GLOW_EVENT_MAX_AGE then
        overlayGlowEventShownAt[spellID] = nil
        return false
    end

    return true
end

function Engine.IsOverlayGlowEventActive(spellID)
    return IsOverlayGlowEventActive(spellID)
end

local function IsSpellOverlayedSafe(spellID)
    if not spellID then
        return false
    end

    if IsOverlayGlowEventActive(spellID) then
        return true
    end

    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        local ok, active = pcall(C_SpellActivationOverlay.IsSpellOverlayed, spellID)
        if ok then
            return active == true
        end
    end

    if not IsSpellOverlayed then
        return false
    end

    local ok, active = pcall(IsSpellOverlayed, spellID)
    return ok and active == true
end

local function GetCooldownRemaining(spellID)
    if type(spellID) ~= "number" or spellID <= 0 or not C_Spell or not C_Spell.GetSpellCooldown then
        return math.huge
    end

    local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or not cooldownInfo then
        return math.huge
    end

    if cooldownInfo.isEnabled == false then
        return math.huge
    end

    if cooldownInfo.isActive == false or cooldownInfo.isOnGCD == true then
        -- The cooldown just came back while we were estimating it: the time
        -- since our cast is the real (talented/hasted) duration. Keep the
        -- longest one seen so early resets do not shorten it.
        if cooldownEstimateUsed[spellID] then
            local castAt = GetLastCastTime(spellID)
            local observed = castAt and (GetTime() - castAt) or nil
            if observed and observed > 2.0 and observed < 600
            and (observedCooldownDuration[spellID] == nil or observed > observedCooldownDuration[spellID])
            then
                observedCooldownDuration[spellID] = observed
                LearnCooldownDuration(spellID, observed)
            end
        end
        cooldownEstimateUsed[spellID] = nil
        return 0
    end

    local okRemaining, remaining = pcall(function()
        local startTime = cooldownInfo.startTime or 0
        local duration = cooldownInfo.duration or 0
        if startTime <= 0 or duration <= 0 then
            return 0
        end

        LearnCooldownDuration(spellID, duration)
        return math.max(0, (startTime + duration) - GetTime())
    end)

    if okRemaining then
        cooldownEstimateUsed[spellID] = nil
        return remaining
    end

    -- Midnight hides cooldown timestamps in combat, but isActive stays
    -- readable. Rebuild the remaining time from our own cast timestamp and the
    -- last cooldown length we saw out of combat (or the spell's base cooldown).
    -- isActive is still true here, so never report the spell as fully ready.
    local estimate = EstimateCooldownRemainingFromCast(spellID)
    if estimate then
        cooldownEstimateUsed[spellID] = true
        return math.max(estimate, 0.25)
    end

    cooldownEstimateUsed[spellID] = nil
    return math.huge
end

local function GetSpellChargesAvailable(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil, false
    end

    local function getSafeChargeCount(value)
        if IsSafeNonSecretNumber(value) then
            return value, true
        end

        return nil, false
    end

    if C_Spell and C_Spell.GetSpellCharges then
        local ok, chargeInfo = pcall(C_Spell.GetSpellCharges, spellID)
        if ok and chargeInfo then
            local okValue, currentCharges = pcall(function()
                if chargeInfo.currentCharges ~= nil then
                    return chargeInfo.currentCharges
                end
                if chargeInfo.charges ~= nil then
                    return chargeInfo.charges
                end
                return nil
            end)
            if okValue then
                local safeCharges, safeKnown = getSafeChargeCount(currentCharges)
                if safeKnown then
                    return safeCharges, true
                end
            end
        end
    end

    if GetSpellCharges then
        local ok, currentCharges = pcall(GetSpellCharges, spellID)
        if ok then
            local safeCharges, safeKnown = getSafeChargeCount(currentCharges)
            if safeKnown then
                return safeCharges, true
            end
        end
    end

    return nil, false
end

local function IsSpellReady(spellID, allowCooldownViewerTracked)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    if addon.IsRecommendableSpell and not addon:IsRecommendableSpell(spellID) then
        return false
    end

    local knownInBook = IsSpellKnownInBook(spellID)
    local trackedByCooldownViewer = allowCooldownViewerTracked and IsCooldownViewerSpellTracked(spellID)
    if not knownInBook and not trackedByCooldownViewer then
        return false
    end

    local lacksResource = false
    local unusableByCondition = false

    if C_Spell and C_Spell.IsSpellUsable then
        local ok, isUsable, notEnoughResource = pcall(C_Spell.IsSpellUsable, spellID)
        if ok then
            lacksResource = notEnoughResource == true
            unusableByCondition = isUsable == false and notEnoughResource ~= true
        end
    elseif IsUsableSpell then
        local ok, isUsable, notEnoughResource = pcall(IsUsableSpell, spellID)
        if ok then
            lacksResource = notEnoughResource == true
            unusableByCondition = isUsable == false and notEnoughResource ~= true
        end
    end

    if lacksResource or unusableByCondition then
        return false
    end

    if not C_Spell or not C_Spell.GetSpellCooldown then
        return knownInBook
    end

    local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or not cooldownInfo then
        return knownInBook
    end

    if cooldownInfo.isEnabled == false then
        return false
    end

    if cooldownInfo.isActive == false then
        return true
    end

    if cooldownInfo.isOnGCD == true then
        return true
    end

    local okNumeric, readyByTime = pcall(function()
        local startTime = cooldownInfo.startTime
        local duration = cooldownInfo.duration
        if not startTime or not duration then
            return false
        end

        if startTime <= 0 or duration <= 0 then
            return true
        end

        return ((startTime + duration) - GetTime()) <= 0.05
    end)

    if okNumeric then
        return readyByTime
    end

    return false
end

local function IsSpellInRangeForUnit(spellID, unit)
    if type(spellID) ~= "number" or spellID <= 0 or not unit or not UnitExists(unit) then
        return false
    end

    if not C_Spell or not C_Spell.IsSpellInRange then
        return true
    end

    local ok, inRange = pcall(C_Spell.IsSpellInRange, spellID, unit)
    if not ok then
        return true
    end

    return inRange ~= false
end

local function HasHostileLivingTarget()
    return UnitExists("target")
        and UnitCanAttack("player", "target")
        and not UnitIsDead("target")
end

local function IsUnitPowerSecret(unit, powerType)
    if not C_Secrets then
        return false
    end

    if C_Secrets.ShouldUnitPowerBeSecret then
        local okPower, isPowerSecret = pcall(C_Secrets.ShouldUnitPowerBeSecret, unit, powerType)
        if okPower and isPowerSecret then
            return true
        end
    end

    if C_Secrets.ShouldUnitPowerMaxBeSecret then
        local okPowerMax, isPowerMaxSecret = pcall(C_Secrets.ShouldUnitPowerMaxBeSecret, unit, powerType)
        if okPowerMax and isPowerMaxSecret then
            return true
        end
    end

    return false
end

local function IsUnitHealthSecret(unit)
    if not C_Secrets then
        return false
    end

    if C_Secrets.ShouldUnitHealthBeSecret then
        local okHealth, isHealthSecret = pcall(C_Secrets.ShouldUnitHealthBeSecret, unit)
        if okHealth and isHealthSecret then
            return true
        end
    end

    if C_Secrets.ShouldUnitHealthMaxBeSecret then
        local okHealthMax, isHealthMaxSecret = pcall(C_Secrets.ShouldUnitHealthMaxBeSecret, unit)
        if okHealthMax and isHealthMaxSecret then
            return true
        end
    end

    return false
end

local function GetApproxGlobalCooldown()
    -- Haste is secret in Midnight, but the GCD spell's cooldown is not. Read
    -- the real (hasted) GCD whenever one is running and remember it; fall back
    -- to a conservative 1.5 seconds until the first observation.
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, GCD_SPELL_ID)
        if ok and info then
            local okDuration, duration = pcall(function()
                local value = info.duration
                if type(value) == "number" and value >= 0.5 and value <= 1.5 then
                    return value
                end
                return nil
            end)
            if okDuration and duration then
                observedGlobalCooldown = duration
            end
        end
    end

    return observedGlobalCooldown or 1.5
end

function Engine.GetObservedGlobalCooldown()
    return observedGlobalCooldown
end

-- Rage is secret in combat, but C_Spell.IsSpellUsable still reports whether a
-- spell is short on resources. Comparing that answer across several rage
-- spells with known costs gives a band: rage >= low and rage < high.
local RAGE_BAND_PROBE_SPELL_IDS = {
    12294, -- Mortal Strike
    1464,  -- Slam
    845,   -- Cleave
    772,   -- Rend
    1680,  -- Whirlwind
    6343,  -- Thunder Clap
    190456, -- Ignore Pain
    1715,  -- Hamstring
    23881, -- Bloodthirst
    184367, -- Rampage
}
local rageCostCache = {}

local function GetCachedRageCost(spellID)
    local cached = rageCostCache[spellID]
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

    local okRead, rageCost = pcall(function()
        for _, entry in ipairs(costs) do
            if entry.type == RAGE_POWER_TYPE and type(entry.cost) == "number" and entry.cost > 0 then
                return entry.cost
            end
        end
        return false
    end)

    if not okRead then
        -- Costs were secret; try again later instead of caching a bad answer.
        return nil
    end

    rageCostCache[spellID] = rageCost
    return rageCost or nil
end

function Engine.ResetRageCostCache()
    wipe(rageCostCache)
end

function Engine.GetRageBand()
    local low, high = nil, nil
    if not C_Spell or not C_Spell.IsSpellUsable then
        return nil, nil
    end

    for _, spellID in ipairs(RAGE_BAND_PROBE_SPELL_IDS) do
        if IsSpellKnownInBook(spellID) then
            local cost = GetCachedRageCost(spellID)
            if cost then
                local ok, isUsable, notEnoughResource = pcall(C_Spell.IsSpellUsable, spellID)
                if ok then
                    if notEnoughResource == true then
                        high = high and math.min(high, cost) or cost
                    elseif isUsable == true then
                        low = low and math.max(low, cost) or cost
                    end
                end
            end
        end
    end

    return low, high
end

-- Blizzard's Assisted Highlight is computed by the client with full access to
-- hidden state, and its answer stays readable. Use it as a signal, a trace
-- reference and a last-resort fallback, never as the primary priority.
function Engine.GetAssistedCombatSuggestion()
    if not C_AssistedCombat or not C_AssistedCombat.GetNextCastSpell then
        return nil
    end

    local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell, false)
    if ok and IsSafeNonSecretNumber(spellID) and spellID > 0 then
        return spellID
    end

    return nil
end

function Engine.SpellIDsMatch(firstSpellID, secondSpellID)
    if type(firstSpellID) ~= "number" or type(secondSpellID) ~= "number" then
        return false
    end

    if firstSpellID == secondSpellID then
        return true
    end

    local firstBase = GetBaseSpellIDSafe(firstSpellID) or firstSpellID
    local secondBase = GetBaseSpellIDSafe(secondSpellID) or secondSpellID
    if firstBase == secondBase then
        return true
    end

    local firstName = GetSpellNameForTracking(firstSpellID)
    return firstName ~= nil and firstName == GetSpellNameForTracking(secondSpellID)
end

local function GetCurrentRage()
    if IsUnitPowerSecret("player", RAGE_POWER_TYPE) then
        return 0
    end

    local ok, currentRage = pcall(function()
        return UnitPower("player", RAGE_POWER_TYPE) or 0
    end)

    if not ok then
        return 0
    end

    return currentRage
end

local function GetCurrentFocus()
    if IsUnitPowerSecret("player", FOCUS_POWER_TYPE) then
        return 0
    end

    local ok, currentFocus = pcall(function()
        return UnitPower("player", FOCUS_POWER_TYPE) or 0
    end)

    if not ok then
        return 0
    end

    return currentFocus
end

local function GetCurrentRunicPower()
    if IsUnitPowerSecret("player", RUNIC_POWER_TYPE) then
        return 0
    end

    local ok, currentRunicPower = pcall(function()
        return UnitPower("player", RUNIC_POWER_TYPE) or 0
    end)

    return ok and SafeNumberOrDefault(currentRunicPower, 0) or 0
end

local function GetCurrentEnergy()
    if IsUnitPowerSecret("player", ENERGY_POWER_TYPE) then
        return 0
    end

    local ok, energy = pcall(UnitPower, "player", ENERGY_POWER_TYPE)
    return ok and SafeNumberOrDefault(energy, 0) or 0
end

local function GetCurrentComboPoints()
    if IsUnitPowerSecret("player", COMBO_POINTS_POWER_TYPE) then
        return 0
    end

    local ok, comboPoints = pcall(UnitPower, "player", COMBO_POINTS_POWER_TYPE)
    return ok and SafeNumberOrDefault(comboPoints, 0) or 0
end

local function GetMaximumComboPoints()
    if IsUnitPowerSecret("player", COMBO_POINTS_POWER_TYPE) or not UnitPowerMax then
        return 7
    end

    local ok, maximum = pcall(UnitPowerMax, "player", COMBO_POINTS_POWER_TYPE)
    return ok and math.max(1, SafeNumberOrDefault(maximum, 7)) or 7
end

local function GetReadyRuneCount()
    if not GetRuneCooldown then
        return 0, false
    end

    local readyRunes = 0
    for runeIndex = 1, 6 do
        local ok, _, _, runeReady = pcall(GetRuneCooldown, runeIndex)
        if not ok then
            return 0, false
        end
        if runeReady == true then
            readyRunes = readyRunes + 1
        end
    end

    return readyRunes, true
end

local function GetCurrentHolyPower()
    if IsUnitPowerSecret("player", RET.holyPowerType) then
        return 0
    end

    local ok, currentHolyPower = pcall(function()
        return UnitPower("player", RET.holyPowerType) or 0
    end)

    if not ok then
        return 0
    end

    return currentHolyPower
end

local function GetUnitHealthPercent(unit)
    if not UnitExists(unit) or UnitIsDead(unit) then
        return nil
    end

    if IsUnitHealthSecret(unit) then
        return nil
    end

    local ok, healthPercent = pcall(function()
        local maxHealth = UnitHealthMax(unit) or 0
        if maxHealth <= 0 then
            return nil
        end

        return (UnitHealth(unit) or 0) / maxHealth
    end)

    if not ok then
        return nil
    end

    return healthPercent
end


local function GetStrictSpellRangeResult(spellID, unit)
    if type(spellID) ~= "number" or spellID <= 0 or not unit or not UnitExists(unit) then
        return nil
    end

    if not C_Spell or not C_Spell.IsSpellInRange then
        return nil
    end

    local ok, inRange = pcall(C_Spell.IsSpellInRange, spellID, unit)
    if not ok then
        return nil
    end

    if inRange == true or inRange == 1 then
        return true
    end

    if inRange == false or inRange == 0 then
        return false
    end

    return nil
end


local function AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, spellID)
    if type(spellID) ~= "number" or spellID <= 0 or seenSpellIDs[spellID] then
        return
    end

    seenSpellIDs[spellID] = true
    table.insert(referenceSpellIDs, spellID)
end

local function BuildMeleeRangeReferenceSpellIDs(primaryReferenceSpellID)
    local referenceSpellIDs = {}
    local seenSpellIDs = {}

    if type(primaryReferenceSpellID) == "table" then
        for _, spellID in ipairs(primaryReferenceSpellID) do
            AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, spellID)
        end
    else
        AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, primaryReferenceSpellID)
    end

    AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, MORTAL_STRIKE_SPELL_ID)
    AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, OVERPOWER_SPELL_ID)
    AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, REND_SPELL_ID)
    AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, SLAM_SPELL_ID)
    AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, BLOODTHIRST_SPELL_ID)
    AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, RAGING_BLOW_SPELL_ID)
    AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, RAMPAGE_SPELL_ID)
    AddRangeReferenceSpellID(referenceSpellIDs, seenSpellIDs, EXECUTE_SPELL_ID)

    return referenceSpellIDs
end

local function PruneRecentDamageTargets(now)
    now = now or GetTime()
    for index = #recentDamageTargets, 1, -1 do
        local entry = recentDamageTargets[index]
        local seenAt = entry and entry.seenAt
        if type(seenAt) ~= "number" or (now - seenAt) > RECENT_DAMAGE_TARGET_WINDOW then
            table.remove(recentDamageTargets, index)
        end
    end
end

-- Combat-log damage tracking was removed in 0.4.1 because retail 12.x blocks
-- COMBAT_LOG_EVENT_UNFILTERED for addons. This count is therefore always zero
-- and nameplates are the only target-count source.
function Engine.GetRecentDamageTargetCount()
    PruneRecentDamageTargets()
    return #recentDamageTargets
end

local function IsAnyReferenceSpellInStrictRange(referenceSpellIDs, unit)
    local sawDefiniteOutOfRange = false

    for _, spellID in ipairs(referenceSpellIDs or {}) do
        local inRange = GetStrictSpellRangeResult(spellID, unit)
        if inRange == true then
            return true
        elseif inRange == false then
            sawDefiniteOutOfRange = true
        end
    end

    return false, sawDefiniteOutOfRange
end

local function IsTrainingDummyUnit(unit)
    if not unit or not UnitExists(unit) or not UnitName then
        return false
    end

    local ok, name = pcall(UnitName, unit)
    if not ok or type(name) ~= "string" then
        return false
    end

    return name:lower():find("training dummy", 1, true) ~= nil
end




function Engine.CountHostileTargetsInMeleeRange(referenceSpellID, includeUnknownRange)
    if not HasHostileLivingTarget() then
        return 0
    end

    PruneRecentDamageTargets()
    local referenceSpellIDs = BuildMeleeRangeReferenceSpellIDs(referenceSpellID)

    local count = 1
    local visibleCount = 1
    local seenUnits = { target = true }

    local function countAdditionalUnit(unit)
        if not unit
        or not UnitExists(unit)
        or not UnitCanAttack("player", unit)
        or UnitIsDead(unit)
        then
            return
        end

        if seenUnits[unit] then
            return
        end

        if UnitIsUnit and UnitIsUnit(unit, "target") then
            return
        end

        seenUnits[unit] = true
        visibleCount = visibleCount + 1

        local inMeleeRange, sawDefiniteOutOfRange = IsAnyReferenceSpellInStrictRange(referenceSpellIDs, unit)
        if not inMeleeRange then
            if not sawDefiniteOutOfRange
            and (includeUnknownRange == true or IsTrainingDummyUnit(unit))
            then
                count = count + 1
            end
            return
        end

        count = count + 1
    end

    for index = 1, 40 do
        countAdditionalUnit("nameplate" .. index)
    end

    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = plate.namePlateUnitToken
            if not unit and plate.UnitFrame then
                unit = plate.UnitFrame.unit or plate.UnitFrame.displayedUnit
            end

            countAdditionalUnit(unit)
        end
    end

    local recentDamageCount = Engine.GetRecentDamageTargetCount()
    return math.max(count, recentDamageCount), visibleCount, recentDamageCount
end

function Engine.IsBlacklistedRecommendation(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    local baseSpellID = addon.FindBaseSpellID and addon:FindBaseSpellID(spellID) or spellID
    return BLACKLISTED_RECOMMENDATION_SPELL_IDS[spellID] == true
        or BLACKLISTED_RECOMMENDATION_SPELL_IDS[baseSpellID] == true
end

function Engine.GetTargetCountOverride()
    local override = addon.db and tonumber(addon.db.targetCountOverride or 0) or 0
    if override and override > 0 then
        return math.min(20, math.max(1, override))
    end

    return 0
end

local function GetTargetCountBand(targetCount)
    targetCount = math.max(1, tonumber(targetCount) or 1)
    if targetCount >= 4 then
        return 3
    end
    if targetCount >= 2 then
        return 2
    end
    return 1
end

local function GetTargetBandLabel(targetCount)
    local band = GetTargetCountBand(targetCount)
    if band == 3 then
        return "AOE"
    end
    if band == 2 then
        return "Cleave"
    end
    return "ST"
end

function Engine.ResolveTargetCount(detectedTargetCount)
    local override = Engine.GetTargetCountOverride()
    if override > 0 then
        lastTargetCountWasAuto = false
        autoTargetBand = nil
        pendingAutoTargetBand = nil
        pendingAutoTargetBandSince = nil
        return override, "manual " .. GetTargetBandLabel(override)
    end

    local detected = math.min(20, math.max(1, tonumber(detectedTargetCount) or 1))
    local detectedBand = GetTargetCountBand(detected)
    local now = GetTime()

    if not lastTargetCountWasAuto or not autoTargetBand then
        autoTargetBand = GetTargetCountBand(1)
        autoTargetCount = 1
        pendingAutoTargetBand = nil
        pendingAutoTargetBandSince = nil
        lastTargetCountWasAuto = true
    end

    if detectedBand == autoTargetBand then
        autoTargetCount = detected
        pendingAutoTargetBand = nil
        pendingAutoTargetBandSince = nil
    else
        if pendingAutoTargetBand ~= detectedBand then
            pendingAutoTargetBand = detectedBand
            pendingAutoTargetBandSince = now
        end

        local delay = detectedBand > autoTargetBand and AUTO_TARGET_PROMOTE_DELAY or AUTO_TARGET_DEMOTE_DELAY
        if type(pendingAutoTargetBandSince) == "number" and (now - pendingAutoTargetBandSince) >= delay then
            autoTargetBand = detectedBand
            autoTargetCount = detected
            pendingAutoTargetBand = nil
            pendingAutoTargetBandSince = nil
        end
    end

    return autoTargetCount, "auto " .. GetTargetBandLabel(autoTargetCount)
end

function Engine.CanUseEnemySpell(spellID)
    return not Engine.IsBlacklistedRecommendation(spellID)
        and HasHostileLivingTarget()
        and IsSpellReady(spellID)
        and IsSpellInRangeForUnit(spellID, "target")
end

function Engine.CanUseSelfSpell(spellID)
    return not Engine.IsBlacklistedRecommendation(spellID)
        and IsSpellReady(spellID)
end

function Engine.ShouldRecommendMajorCooldowns()
    return addon.db and addon.db.recommendMajorCooldowns == true
end

function Engine.IsManualMajorCooldown(spellID)
    if Engine.ShouldRecommendMajorCooldowns() then
        return false
    end

    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    local baseSpellID = addon.FindBaseSpellID and addon:FindBaseSpellID(spellID) or spellID
    return MANUAL_MAJOR_COOLDOWN_SPELL_IDS[spellID] == true
        or MANUAL_MAJOR_COOLDOWN_SPELL_IDS[baseSpellID] == true
end

function addon:IsManualMajorCooldown(spellID)
    return Engine.IsManualMajorCooldown(spellID)
end

function Engine.CanRecommendEnemySpell(spellID)
    return not Engine.IsManualMajorCooldown(spellID) and Engine.CanUseEnemySpell(spellID)
end

function Engine.CanRecommendSelfSpell(spellID)
    return not Engine.IsManualMajorCooldown(spellID) and Engine.CanUseSelfSpell(spellID)
end

function Engine.IsSpellUsableStrict(spellID, allowCooldownViewerTracked)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    if not IsSpellKnownInBook(spellID)
    and not (allowCooldownViewerTracked and IsCooldownViewerSpellTracked(spellID))
    then
        return false
    end

    if C_Spell and C_Spell.IsSpellUsable then
        local ok, isUsable, notEnoughResource = pcall(C_Spell.IsSpellUsable, spellID)
        return ok and isUsable == true and notEnoughResource ~= true
    end

    if IsUsableSpell then
        local ok, isUsable, notEnoughResource = pcall(IsUsableSpell, spellID)
        return ok and isUsable == true and notEnoughResource ~= true
    end

    return false
end

function Engine.CanUseBMEnemySpell(spellID)
    return not Engine.IsBlacklistedRecommendation(spellID)
        and HasHostileLivingTarget()
        and IsSpellReady(spellID, true)
        and Engine.IsSpellUsableStrict(spellID, true)
        and IsSpellInRangeForUnit(spellID, "target")
end

function Engine.CanUseBMSelfSpell(spellID)
    return not Engine.IsBlacklistedRecommendation(spellID)
        and IsSpellReady(spellID, true)
        and Engine.IsSpellUsableStrict(spellID, true)
end

function Engine.CanRecommendBMSelfSpell(spellID)
    return not Engine.IsManualMajorCooldown(spellID) and Engine.CanUseBMSelfSpell(spellID)
end

RET.isAvailable = function(spellID, allowCooldownViewerTracked)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end

    if addon.IsRecommendableSpell and not addon:IsRecommendableSpell(spellID) then
        return false
    end

    if IsSpellKnownInBook(spellID) then
        return true
    end

    if allowCooldownViewerTracked then
        if C_Spell and C_Spell.IsSpellUsable then
            local ok, isUsable, notEnoughResource = pcall(C_Spell.IsSpellUsable, spellID)
            if ok and isUsable == true and notEnoughResource ~= true then
                return true
            end
        elseif IsUsableSpell then
            local ok, isUsable, notEnoughResource = pcall(IsUsableSpell, spellID)
            if ok and isUsable == true and notEnoughResource ~= true then
                return true
            end
        end

        if IsSpellOverlayedSafe(spellID) then
            return true
        end

        if addon.HasActionButtonProcGlowForSpell then
            local buttonGlow = addon:HasActionButtonProcGlowForSpell(spellID)
            return buttonGlow == true
        end
    end

    return false
end

function Engine.CanUseRetEnemySpell(spellID)
    if Engine.IsBlacklistedRecommendation(spellID)
    or not (addon.IsRecommendableSpell and addon:IsRecommendableSpell(spellID))
    or not HasHostileLivingTarget()
    or not IsSpellInRangeForUnit(spellID, "target")
    or not RET.isAvailable(spellID, true)
    then
        return false
    end

    if IsSpellReady(spellID, true) then
        return true
    end

    if type(spellID) ~= "number" or spellID <= 0 or not C_Spell or not C_Spell.IsSpellUsable or not C_Spell.GetSpellCooldown then
        return false
    end

    local okUsable, isUsable, notEnoughResource = pcall(C_Spell.IsSpellUsable, spellID)
    if not okUsable or isUsable ~= true or notEnoughResource == true then
        return false
    end

    local okCooldown, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
    if not okCooldown or not cooldownInfo or cooldownInfo.isEnabled == false then
        return false
    end

    if cooldownInfo.isActive == false or cooldownInfo.isOnGCD == true then
        return true
    end

    local okNumeric, readyByTime = pcall(function()
        local startTime = cooldownInfo.startTime
        local duration = cooldownInfo.duration
        if not startTime or not duration or startTime <= 0 or duration <= 0 then
            return true
        end

        return ((startTime + duration) - GetTime()) <= 0.05
    end)

    return okNumeric and readyByTime == true
end

function Engine.CanUseRetSelfSpell(spellID)
    if Engine.IsBlacklistedRecommendation(spellID)
    or not (addon.IsRecommendableSpell and addon:IsRecommendableSpell(spellID))
    or not RET.isAvailable(spellID, true)
    then
        return false
    end

    if IsSpellReady(spellID, true) then
        return true
    end

    if type(spellID) ~= "number" or spellID <= 0 or not C_Spell or not C_Spell.IsSpellUsable or not C_Spell.GetSpellCooldown then
        return false
    end

    local okUsable, isUsable, notEnoughResource = pcall(C_Spell.IsSpellUsable, spellID)
    if not okUsable or isUsable ~= true or notEnoughResource == true then
        return false
    end

    local okCooldown, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellID)
    if not okCooldown or not cooldownInfo or cooldownInfo.isEnabled == false then
        return false
    end

    if cooldownInfo.isActive == false or cooldownInfo.isOnGCD == true then
        return true
    end

    local okNumeric, readyByTime = pcall(function()
        local startTime = cooldownInfo.startTime
        local duration = cooldownInfo.duration
        if not startTime or not duration or startTime <= 0 or duration <= 0 then
            return true
        end

        return ((startTime + duration) - GetTime()) <= 0.05
    end)

    return okNumeric and readyByTime == true
end

function Engine.CanUseExecuteSpell(state)
    if not state or not state.spell or not state.spell.execute then
        return false
    end

    if state.executeStrictUsable ~= true then
        return false
    end

    if state.isArms == true then
        return true
    end

    -- Fury's raw spell usability can over-report Execute outside of real windows.
    -- Only trust a Sudden Death signal or a confirmed execute-range health check.
    return state.suddenDeathUp == true or state.executePhase == true
end

function Engine.GetSuddenDeathState(executeSpellID)
    -- Proc auras can have protected expiration times in Midnight.
    local auraByID = GetUnitAuraInfo(52437, "player", "HELPFUL") ~= nil
    local auraByAltID = GetUnitAuraInfo(280776, "player", "HELPFUL") ~= nil
    local auraByName = GetUnitAuraInfo("Sudden Death", "player", "HELPFUL") ~= nil
    local overlayByResolvedExecute = IsSpellOverlayedSafe(executeSpellID)
    local overlayByBaseExecute = IsSpellOverlayedSafe(EXECUTE_SPELL_ID)
    local overlayByFuryExecute = false
    local actionCount = 0
    local actionCountKnown = false
    local buttonGlow = false
    local buttonGlowKnown = false

    if addon.GetActionCountForSpell then
        actionCount, actionCountKnown = addon:GetActionCountForSpell(executeSpellID or EXECUTE_SPELL_ID)
    end

    if addon.HasActionButtonProcGlowForSpell then
        buttonGlow, buttonGlowKnown = addon:HasActionButtonProcGlowForSpell(executeSpellID or EXECUTE_SPELL_ID)
    end

    if IsFuryWarrior() then
        for _, variantSpellID in ipairs({ 280735, 280849 }) do
            overlayByFuryExecute = overlayByFuryExecute or IsSpellOverlayedSafe(variantSpellID)
            if addon.GetActionCountForSpell then
                local variantCount, variantCountKnown = addon:GetActionCountForSpell(variantSpellID)
                actionCount = math.max(actionCount, variantCount or 0)
                actionCountKnown = actionCountKnown or variantCountKnown
            end
            if addon.HasActionButtonProcGlowForSpell then
                local variantGlow, variantGlowKnown = addon:HasActionButtonProcGlowForSpell(variantSpellID)
                buttonGlow = buttonGlow or variantGlow
                buttonGlowKnown = buttonGlowKnown or variantGlowKnown
            end
        end
    end

    local actionCountSignal = actionCountKnown and actionCount > 0

    -- 0.6.2: the action-button glow stayed on for whole pulls in traces while
    -- the overlay API flipped exactly with Execute's usability. Only fall back
    -- to the button glow when the client has no overlay API.
    local overlayApiAvailable = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) ~= nil
        or IsSpellOverlayed ~= nil
    local glowSignal = buttonGlow and not overlayApiAvailable

    return {
        active = auraByID or auraByAltID or auraByName or overlayByResolvedExecute or overlayByBaseExecute or overlayByFuryExecute or actionCountSignal or glowSignal,
        auraByID = auraByID,
        auraByAltID = auraByAltID,
        auraByName = auraByName,
        overlayByResolvedExecute = overlayByResolvedExecute,
        overlayByBaseExecute = overlayByBaseExecute,
        overlayByFuryExecute = overlayByFuryExecute,
        actionCount = actionCount,
        actionCountKnown = actionCountKnown,
        actionCountSignal = actionCountSignal,
        buttonGlow = buttonGlow,
        buttonGlowKnown = buttonGlowKnown,
    }
end

function Engine.GetBloodbathSpellID()
    return ResolveActionBarSpellIDByName("Bloodbath")
        or ResolveKnownSpellID("BLOODBATH", { 335096 }, "Bloodbath")
end

function Engine.GetExecuteSpellID()
    return ResolveActionBarSpellIDByName("Execute")
        or ResolveKnownSpellID("EXECUTE", { 163201, 5308 }, "Execute")
end

function Engine.GetCrushingBlowSpellID()
    return ResolveActionBarSpellIDByName("Crushing Blow")
        or ResolveKnownSpellID("CRUSHING_BLOW", nil, "Crushing Blow")
end

function Engine.GetWhirlwindSpellID()
    return ResolveActionBarSpellIDByName("Whirlwind")
        or ResolveKnownSpellID("WHIRLWIND", WHIRLWIND_CANDIDATE_SPELL_IDS, "Whirlwind")
end

function Engine.HasImprovedWhirlwind()
    local improvedWhirlwindSpellID = ResolveKnownSpellID(
        "IMPROVED_WHIRLWIND",
        { 12950 },
        "Improved Whirlwind"
    )

    return IsSpellKnownInBook(improvedWhirlwindSpellID or 12950)
end

function Engine.HasWrathAndFury()
    local wrathAndFurySpellID = ResolveKnownSpellID(
        "WRATH_AND_FURY",
        { 392936 },
        "Wrath and Fury"
    )

    return IsSpellKnownInBook(wrathAndFurySpellID or 392936)
end

function Engine.HasDeepWounds()
    local deepWoundsSpellID = ResolveKnownSpellID(
        "DEEP_WOUNDS",
        { 115767 },
        "Deep Wounds"
    )

    return IsSpellKnownInBook(deepWoundsSpellID)
end

function Engine.HasTalentByName(cacheKey, candidateSpellIDs, talentName)
    local spellID = ResolveKnownSpellID(cacheKey, candidateSpellIDs, talentName)
    return IsSpellKnownInBook(spellID)
end

function Engine.HasMassacre()
    return Engine.HasTalentByName("MASSACRE", nil, "Massacre")
end

function Engine.HasBroadStrokes()
    return Engine.HasTalentByName("BROAD_STROKES", nil, "Broad Strokes")
end

function Engine.HasDreadnaught()
    return Engine.HasTalentByName("DREADNAUGHT", nil, "Dreadnaught")
end

function Engine.HasCleave()
    return Engine.HasTalentByName("CLEAVE_TALENT", { CLEAVE_SPELL_ID }, "Cleave")
end

function Engine.HasRend()
    return Engine.HasTalentByName("REND_TALENT", { REND_SPELL_ID }, "Rend")
end

function Engine.HasBloodletting()
    return Engine.HasTalentByName("BLOODLETTING", nil, "Bloodletting")
end

function Engine.HasFervorOfBattle()
    return Engine.HasTalentByName("FERVOR_OF_BATTLE", nil, "Fervor of Battle")
end

function Engine.GetBladestormSpellID()
    return ResolveActionBarSpellIDByName("Bladestorm")
        or ResolveKnownSpellID("BLADESTORM", { 227847, 389774, 446035, 46924 }, "Bladestorm")
end

function Engine.HasBladestorm()
    local spellID = Engine.GetBladestormSpellID()
    return IsSpellKnownByPlayer(spellID)
        or IsSpellKnownInBook(spellID)
        or IsSpellKnownByPlayer(227847)
        or IsSpellKnownInBook(227847)
        or IsSpellKnownByPlayer(389774)
        or IsSpellKnownInBook(389774)
        or IsSpellKnownByPlayer(446035)
        or IsSpellKnownInBook(446035)
        or IsSpellKnownByPlayer(46924)
        or IsSpellKnownInBook(46924)
end

function Engine.GetOdynsFurySpellID()
    return ResolveActionBarSpellIDByName("Odyn's Fury")
        or ResolveKnownSpellID("ODYNS_FURY", { 385059 }, "Odyn's Fury")
end

function Engine.HasOdynsFury()
    local spellID = Engine.GetOdynsFurySpellID() or 385059
    return IsSpellKnownByPlayer(spellID)
        or IsSpellKnownByPlayer(385059)
end

function Engine.HasAvatar()
    return IsSpellKnownByPlayer(AVATAR_SPELL_ID)
end

function Engine.GetRavagerSpellID()
    return ResolveKnownSpellID("RAVAGER", { 228920 }, "Ravager")
end

function Engine.GetChampionsSpearSpellID()
    return ResolveKnownSpellID("CHAMPIONS_SPEAR", { 376079, 307865 }, "Champion's Spear")
end

function Engine.GetHeroicStrikeSpellID()
    return ResolveActionBarSpellIDByName("Heroic Strike")
        or ResolveKnownSpellID("HEROIC_STRIKE", { HEROIC_STRIKE_SPELL_ID, HEROIC_STRIKE_ACTIONBAR_SPELL_ID }, "Heroic Strike")
end

function Engine.GetDemolishSpellID()
    return ResolveKnownSpellID("DEMOLISH", nil, "Demolish")
end

function Engine.GetWreckingThrowSpellID()
    return ResolveActionBarSpellIDByName("Wrecking Throw")
        or ResolveKnownSpellID("WRECKING_THROW", nil, "Wrecking Throw")
end

function Engine.GetStormBoltSpellID()
    return ResolveActionBarSpellIDByName("Storm Bolt")
        or ResolveKnownSpellID("STORM_BOLT", { 107570 }, "Storm Bolt")
end

function Engine.GetBestialWrathSpellID()
    return ResolveCooldownViewerSpellByName("BESTIAL_WRATH_CV", "Bestial Wrath")
        or ResolveKnownSpellID("BESTIAL_WRATH", { BESTIAL_WRATH_SPELL_ID }, "Bestial Wrath")
end

function Engine.GetHunterKillCommandSpellID()
    return ResolveCooldownViewerSpellByName("HUNTER_KILL_COMMAND_CV", "Kill Command")
        or ResolveKnownSpellID("HUNTER_KILL_COMMAND", { 34026 }, "Kill Command")
end

function Engine.GetBarbedShotSpellID()
    return ResolveCooldownViewerSpellByName("BARBED_SHOT_CV", "Barbed Shot")
        or ResolveKnownSpellID("BARBED_SHOT", { 217200 }, "Barbed Shot")
end

function Engine.GetWildThrashSpellID()
    return ResolveCooldownViewerSpellByName("WILD_THRASH_CV", { "Wild Thrash", "Multi-Shot" })
        or ResolveKnownSpellID("WILD_THRASH", { 1264359 }, "Wild Thrash")
        or ResolveKnownSpellID("MULTI_SHOT", { 2643 }, "Multi-Shot")
end

function Engine.GetCobraShotSpellID()
    return ResolveCooldownViewerSpellByName("COBRA_SHOT_CV", "Cobra Shot")
        or ResolveKnownSpellID("COBRA_SHOT", { 193455 }, "Cobra Shot")
end

function Engine.GetSteadyShotSpellID()
    return ResolveCooldownViewerSpellByName("STEADY_SHOT_CV", "Steady Shot")
        or ResolveKnownSpellID("STEADY_SHOT", { 56641 }, "Steady Shot")
end

function Engine.GetBlackArrowSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Black Arrow")
        or ResolveCooldownViewerSpellByName("BLACK_ARROW_CV", "Black Arrow")
        or ResolveKnownSpellID("BLACK_ARROW", { 468037 }, "Black Arrow")
end

function Engine.GetWailingArrowSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Wailing Arrow")
        or ResolveCooldownViewerSpellByName("WAILING_ARROW_CV", "Wailing Arrow")
        or ResolveKnownSpellID("WAILING_ARROW", { 459808 }, "Wailing Arrow")
end

function Engine.GetAvengingWrathSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName({ "Crusade", "Avenging Wrath" })
        or ResolveKnownSpellID("AVENGING_WRATH", RET.avengingWrathCandidates, "Avenging Wrath")
        or ResolveKnownSpellID("CRUSADE", { RET.crusade }, "Crusade")
end

function Engine.GetExecutionSentenceSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Execution Sentence")
        or ResolveKnownSpellID("EXECUTION_SENTENCE", RET.executionSentenceCandidates, "Execution Sentence")
end

function Engine.GetFinalVerdictSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Final Verdict")
        or ResolveKnownSpellID("FINAL_VERDICT", RET.finalVerdictCandidates, "Final Verdict")
end

function Engine.GetTemplarsVerdictSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Templar's Verdict")
        or ResolveKnownSpellID("TEMPLARS_VERDICT", RET.templarsVerdictCandidates, "Templar's Verdict")
end

function Engine.GetRetSingleTargetSpenderSpellID()
    return Engine.GetFinalVerdictSpellID() or Engine.GetTemplarsVerdictSpellID()
end

function Engine.GetDivineStormSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Divine Storm")
        or ResolveKnownSpellID("DIVINE_STORM", RET.divineStormCandidates, "Divine Storm")
end

function Engine.GetWakeOfAshesSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Wake of Ashes")
        or ResolveKnownSpellID("WAKE_OF_ASHES", RET.wakeOfAshesCandidates, "Wake of Ashes")
end

function Engine.GetDivineTollSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Divine Toll")
        or ResolveKnownSpellID("DIVINE_TOLL", RET.divineTollCandidates, "Divine Toll")
end

function Engine.GetHammerOfLightSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Hammer of Light")
        or ResolveCooldownViewerSpellByName("HAMMER_OF_LIGHT_CV", "Hammer of Light")
        or ResolveKnownSpellID("HAMMER_OF_LIGHT", RET.hammerOfLightCandidates, "Hammer of Light")
end

function Engine.GetHammerOfWrathSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Hammer of Wrath")
        or ResolveCooldownViewerSpellByName("HAMMER_OF_WRATH_CV", "Hammer of Wrath")
        or ResolveKnownSpellID("HAMMER_OF_WRATH", RET.hammerOfWrathCandidates, "Hammer of Wrath")
end

function Engine.GetBladeOfJusticeSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Blade of Justice")
        or ResolveKnownSpellID("BLADE_OF_JUSTICE", RET.bladeOfJusticeCandidates, "Blade of Justice")
end

function Engine.GetJudgmentSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Judgment")
        or ResolveKnownSpellID("JUDGMENT", RET.judgmentCandidates, "Judgment")
end

function Engine.GetCrusaderStrikeSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Crusader Strike")
        or ResolveKnownSpellID("CRUSADER_STRIKE", RET.crusaderStrikeCandidates, "Crusader Strike")
end

function Engine.GetTemplarStrikeSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Templar Strike")
        or ResolveKnownSpellID("TEMPLAR_STRIKE", RET.templarStrikeCandidates, "Templar Strike")
end

function Engine.GetTemplarSlashSpellID()
    return addon.GetActionSpellIDByName and addon:GetActionSpellIDByName("Templar Slash")
        or ResolveKnownSpellID("TEMPLAR_SLASH", RET.templarSlashCandidates, "Templar Slash")
end

function Engine.HasRadiantGlory()
    return IsSpellKnownInBook(ResolveKnownSpellID("RADIANT_GLORY", nil, "Radiant Glory"))
end

function Engine.HasCrusadingStrikes()
    return IsSpellKnownInBook(ResolveKnownSpellID("CRUSADING_STRIKES", { 404542 }, "Crusading Strikes"))
        or IsSpellKnownInBook(ResolveKnownSpellID("CRUSADING_STRIKE", nil, "Crusading Strike"))
end

function Engine.IsCooldownViewerBeastCleaveActive()
    local beastCleaveSpellID = ResolveCooldownViewerSpellByName("BEAST_CLEAVE_CV", "Beast Cleave")
    return IsCooldownViewerSpellActive(beastCleaveSpellID) or IsCooldownViewerSpellActive(BEAST_CLEAVE_AURA_ID)
end

function Engine.GetBeastCleaveRemaining(cooldownViewerBeastCleaveActive)
    return math.max(
        GetPlayerAuraRemainingByID(BEAST_CLEAVE_AURA_ID),
        GetPlayerAuraRemainingByName("Beast Cleave"),
        GetUnitAuraRemainingByID(BEAST_CLEAVE_AURA_ID, "pet", "HELPFUL"),
        GetUnitAuraRemainingByName("Beast Cleave", "pet", "HELPFUL"),
        cooldownViewerBeastCleaveActive and BM_BEAST_CLEAVE_REFRESH_DURATION or 0
    )
end

function Engine.GetAssumedBeastCleaveRemaining()
    return math.max(0, (addon.bmAssumedBeastCleaveExpiresAt or 0) - GetTime())
end

function Engine.MarkBeastCleaveRefreshRecommended()
    addon.bmAssumedBeastCleaveExpiresAt = GetTime() + BM_BEAST_CLEAVE_REFRESH_DURATION
end

function addon:GetAssumedArmsRendRemaining()
    return math.max(0, (addon.armsAssumedRendExpiresAt or 0) - GetTime())
end

function addon:MarkArmsRendApplied()
    addon.armsAssumedRendExpiresAt = GetTime() + 12.0
end

function addon:ClearAssumedArmsRend()
    addon.armsAssumedRendExpiresAt = 0
end

function addon:ClearRecentArmsColossusCast()
    armsLastColossusCastAt = 0
end


function addon:GetAssumedArmsExecutionersPrecisionStacks()
    if armsAssumedExecutionersPrecisionExpiresAt <= GetTime() then
        armsAssumedExecutionersPrecisionStacks = 0
        armsAssumedExecutionersPrecisionExpiresAt = 0
    end

    return armsAssumedExecutionersPrecisionStacks
end

function addon:MarkArmsExecutionersPrecisionApplied()
    local now = GetTime()
    -- Midnight reports one Execute through both its cast spell and damage
    -- spell IDs (260798 and 281000) at the same instant. Treat that pair as
    -- one cast so the fallback does not jump directly from zero to two stacks.
    if armsLastExecutionersPrecisionExecuteAt > 0
    and (now - armsLastExecutionersPrecisionExecuteAt) < 0.20
    then
        return
    end

    armsLastExecutionersPrecisionExecuteAt = now
    if armsAssumedExecutionersPrecisionExpiresAt <= now then
        armsAssumedExecutionersPrecisionStacks = 0
    end

    armsAssumedExecutionersPrecisionStacks = math.min(2, armsAssumedExecutionersPrecisionStacks + 1)
    armsAssumedExecutionersPrecisionExpiresAt = now + 30.0
end

function addon:ClearAssumedArmsExecutionersPrecision()
    armsAssumedExecutionersPrecisionStacks = 0
    armsAssumedExecutionersPrecisionExpiresAt = 0
    armsLastExecutionersPrecisionExecuteAt = 0
end

function Engine.GetSpellNameSafe(spellID)
    if type(spellID) ~= "number" or spellID <= 0 or not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end

    local ok, spellName = pcall(function()
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        return spellInfo and spellInfo.name
    end)
    if ok and type(spellName) == "string" and spellName ~= "" then
        return spellName
    end

    return nil
end

function Engine.GetThunderBlastSpellID()
    return ResolveActionBarSpellIDByName("Thunder Blast")
        or ResolveKnownSpellID("THUNDER_BLAST", { 435222 }, "Thunder Blast")
end

local FURY_WHIRLWIND_STACKS = 4
local FURY_WHIRLWIND_BUFF_DURATION = 10.0
local FURY_ENRAGE_DURATION = 4.0
local FURY_RECKLESSNESS_DURATION = 24.0 -- 0.5.4: top Mythic logs show 24s windows (was 12)
local SUBTLETY_SHADOW_DANCE_DURATION = 6.0
local SUBTLETY_SHADOW_BLADES_DURATION = 20.0

function Engine.ResetFuryOpenerState(inCombat)
    combatStartedAt = inCombat and GetTime() or nil
    furyOpenerBloodthirstDone = false
    furyOpenerBloodthirstCastAt = 0
    furyLastRampageCastAt = 0
    furyGeneratorCastsSinceRampage = 0
    furyLastGeneratorCountedAt = 0
    furyRampageUsableSince = 0
    furyGeneratorsSinceRampageUsable = 0
    furyAssumedEnrageExpiresAt = 0
    furyAssumedRecklessnessExpiresAt = 0
    furyAssumedWhirlwindStacks = 0
    furyAssumedWhirlwindExpiresAt = 0
end

function Engine.ResetRetributionOpenerState(inCombat)
    retCombatStartedAt = inCombat and GetTime() or nil
    retOpenerBladeOfJusticeDone = false
    retOpenerBladeOfJusticeCastAt = 0
    retLastWakeOfAshesCastAt = 0
    retLastHammerOfLightCastAt = 0
end

function Engine.GetAssumedFuryWhirlwindStacks()
    if furyAssumedWhirlwindStacks <= 0 or GetTime() >= furyAssumedWhirlwindExpiresAt then
        furyAssumedWhirlwindStacks = 0
        furyAssumedWhirlwindExpiresAt = 0
        return 0
    end

    return furyAssumedWhirlwindStacks
end

function Engine.MarkFuryWhirlwindApplied()
    furyAssumedWhirlwindStacks = FURY_WHIRLWIND_STACKS
    furyAssumedWhirlwindExpiresAt = GetTime() + FURY_WHIRLWIND_BUFF_DURATION
end

function Engine.GetAssumedFuryEnrageRemaining()
    return math.max(0, furyAssumedEnrageExpiresAt - GetTime())
end

function Engine.GetAssumedFuryRecklessnessRemaining()
    return math.max(0, furyAssumedRecklessnessExpiresAt - GetTime())
end

function Engine.GetAssumedSubtletyShadowDanceRemaining()
    return math.max(0, subtletyAssumedShadowDanceExpiresAt - GetTime())
end

function Engine.GetAssumedSubtletyShadowBladesRemaining()
    return math.max(0, subtletyAssumedShadowBladesExpiresAt - GetTime())
end

function Engine.MarkFuryEnrageApplied()
    furyAssumedEnrageExpiresAt = GetTime() + FURY_ENRAGE_DURATION
end

function Engine.ConsumeAssumedFuryWhirlwindStack()
    if Engine.GetAssumedFuryWhirlwindStacks() <= 0 then
        return
    end

    furyAssumedWhirlwindStacks = math.max(0, furyAssumedWhirlwindStacks - 1)
    if furyAssumedWhirlwindStacks <= 0 then
        furyAssumedWhirlwindExpiresAt = 0
    end
end

function Engine.IsFuryWhirlwindSpell(spellID, spellName)
    if spellName == "Whirlwind" then
        return true
    end

    -- Mountain Thane cleaves through Thunder Clap / Thunder Blast instead of
    -- Whirlwind (top M+ Thane logs never cast Whirlwind).
    if (spellName == "Thunder Clap" or spellName == "Thunder Blast")
    and addon.IsFuryMountainThane and addon:IsFuryMountainThane()
    then
        return true
    end

    for _, whirlwindSpellID in ipairs(WHIRLWIND_CANDIDATE_SPELL_IDS) do
        if spellID == whirlwindSpellID then
            return true
        end
    end

    return false
end

function Engine.IsFuryWhirlwindConsumerSpell(spellID, spellName)
    if Engine.IsFuryWhirlwindSpell(spellID, spellName) then
        return false
    end

    return spellID == RAMPAGE_SPELL_ID
        or spellID == EXECUTE_SPELL_ID
        or spellID == Engine.GetExecuteSpellID()
        or spellID == RAGING_BLOW_SPELL_ID
        or spellID == Engine.GetCrushingBlowSpellID()
        or spellID == BLOODTHIRST_SPELL_ID
        or spellID == Engine.GetBloodbathSpellID()
        or spellID == Engine.GetOdynsFurySpellID()
        or spellID == Engine.GetWreckingThrowSpellID()
        or spellName == "Rampage"
        or spellName == "Execute"
        or spellName == "Raging Blow"
        or spellName == "Crushing Blow"
        or spellName == "Bloodthirst"
        or spellName == "Bloodbath"
        or spellName == "Odyn's Fury"
        or spellName == "Wrecking Throw"
end

function Engine.IsFuryBloodthirstSpell(spellID, spellName)
    return spellID == BLOODTHIRST_SPELL_ID
        or spellID == Engine.GetBloodbathSpellID()
        or spellName == "Bloodthirst"
        or spellName == "Bloodbath"
end

function Engine.IsFuryRampageSpell(spellID, spellName)
    return spellID == RAMPAGE_SPELL_ID
        or spellName == "Rampage"
end

function Engine.IsFuryOdynsFurySpell(spellID, spellName)
    return spellID == Engine.GetOdynsFurySpellID()
        or spellName == "Odyn's Fury"
end

function Engine.IsFuryRageGeneratorSpell(spellID, spellName)
    if Engine.IsFuryRampageSpell(spellID, spellName)
        or spellName == "Recklessness"
        or spellName == "Avatar"
        or spellName == "Wrecking Throw"
        or spellID == Engine.GetWreckingThrowSpellID()
    then
        return false
    end

    return Engine.IsFuryWhirlwindSpell(spellID, spellName)
        or Engine.IsFuryWhirlwindConsumerSpell(spellID, spellName)
        or spellID == Engine.GetThunderBlastSpellID()
        or spellID == THUNDER_CLAP_SPELL_ID
        or spellID == Engine.GetBladestormSpellID()
        or spellName == "Thunder Blast"
        or spellName == "Thunder Clap"
        or spellName == "Bladestorm"
end

function Engine.IsArmsColossusSpell(spellID, spellName)
    return spellID == COLOSSUS_SMASH_SPELL_ID
        or spellID == WARBREAKER_SPELL_ID
        or spellName == "Colossus Smash"
        or spellName == "Warbreaker"
end

function Engine.IsRetributionBladeOfJusticeSpell(spellID, spellName)
    return spellID == RET.bladeOfJustice
        or spellID == Engine.GetBladeOfJusticeSpellID()
        or spellName == "Blade of Justice"
end

function Engine.IsRetributionWakeOfAshesSpell(spellID, spellName)
    return spellID == RET.wakeOfAshes
        or spellID == Engine.GetWakeOfAshesSpellID()
        or spellName == "Wake of Ashes"
end

function Engine.IsRetributionHammerOfLightSpell(spellID, spellName)
    return spellID == RET.hammerOfLight
        or spellID == Engine.GetHammerOfLightSpellID()
        or spellName == "Hammer of Light"
end

function addon:PLAYER_REGEN_DISABLED()
    if IsFuryWarrior() then
        Engine.ResetFuryOpenerState(true)
    end

    if IsRetributionPaladin() then
        Engine.ResetRetributionOpenerState(true)
    end

end

function addon:PLAYER_REGEN_ENABLED()
    if addon.SpecEngine then
        addon.SpecEngine:OnCombatEnd()
    end
    Engine.ResetFuryOpenerState(false)
    Engine.ResetRetributionOpenerState(false)
    addon:ClearAssumedArmsRend()
    addon:ClearRecentArmsColossusCast()
end

function addon:PLAYER_TARGET_CHANGED()
    if addon.SpecEngine then
        addon.SpecEngine:OnTargetChanged()
    end
    addon:ClearAssumedArmsRend()
    addon:ClearRecentArmsColossusCast()
end

function addon:UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if unit ~= "player" then
        return
    end

    local spellName = Engine.GetSpellNameSafe(spellID)
    Engine.RecordSpellCastForCooldown(spellID, spellName)
    if addon.SpecEngine then
        addon.SpecEngine:OnSpellCast(spellID, spellName)
    end
    if addon.RecordSpellcastTrace then
        addon:RecordSpellcastTrace(spellID, spellName)
    end

    if IsFrostDeathKnight()
    and (spellID == FROST_DK.frostwyrmsFury or spellName == "Frostwyrm's Fury")
    then
        frostDKLastFrostwyrmsFuryCastAt = GetTime()
    end

    if IsSubtletyRogue() then
        if spellID == SUB_ROGUE.shadowDance or spellName == "Shadow Dance" then
            subtletyAssumedShadowDanceExpiresAt = GetTime() + SUBTLETY_SHADOW_DANCE_DURATION
        elseif spellID == SUB_ROGUE.shadowBlades or spellName == "Shadow Blades" then
            subtletyAssumedShadowBladesExpiresAt = GetTime() + SUBTLETY_SHADOW_BLADES_DURATION
        end
    end

    if IsArmsWarrior() and (spellID == REND_SPELL_ID or spellID == CLEAVE_SPELL_ID or spellName == "Rend" or spellName == "Cleave") then
        addon:MarkArmsRendApplied()
    end

    if IsArmsWarrior() and (spellID == MORTAL_STRIKE_SPELL_ID or spellName == "Mortal Strike") then
        addon:ClearAssumedArmsExecutionersPrecision()
    elseif IsArmsWarrior() and spellName == "Execute" then
        addon:MarkArmsExecutionersPrecisionApplied()
    end

    if IsArmsWarrior() and Engine.IsArmsColossusSpell(spellID, spellName) then
        armsLastColossusCastAt = GetTime()
    end

    if IsArmsWarrior() and spellName == "Overpower" then
        armsLastOverpowerCastAt = GetTime()
    end

    if IsArmsWarrior() and (spellName == "Bladestorm"
        or spellID == 227847
        or spellID == 389774
        or spellID == 446035
        or spellID == 46924)
    then
        armsLastBladestormCastAt = GetTime()
    end

    if IsRetributionPaladin() and Engine.IsRetributionBladeOfJusticeSpell(spellID, spellName) then
        retOpenerBladeOfJusticeDone = true
        retOpenerBladeOfJusticeCastAt = GetTime()
    end

    if IsRetributionPaladin() and Engine.IsRetributionWakeOfAshesSpell(spellID, spellName) then
        retLastWakeOfAshesCastAt = GetTime()
        retLastHammerOfLightCastAt = 0
    end

    if IsRetributionPaladin() and Engine.IsRetributionHammerOfLightSpell(spellID, spellName) then
        retLastHammerOfLightCastAt = GetTime()
    end

    if IsFuryWarrior() then
        if spellID == RECKLESSNESS_SPELL_ID or spellName == "Recklessness" then
            furyAssumedRecklessnessExpiresAt = GetTime() + FURY_RECKLESSNESS_DURATION
            furyLastRecklessnessCastAt = GetTime()
        end

        if Engine.IsFuryWhirlwindSpell(spellID, spellName) then
            Engine.MarkFuryWhirlwindApplied()
        elseif Engine.IsFuryWhirlwindConsumerSpell(spellID, spellName) then
            Engine.ConsumeAssumedFuryWhirlwindStack()
        end

        if Engine.IsFuryBloodthirstSpell(spellID, spellName) then
            furyOpenerBloodthirstDone = true
            furyOpenerBloodthirstCastAt = GetTime()
        end

        if Engine.IsFuryRampageSpell(spellID, spellName) then
            furyLastRampageCastAt = GetTime()
            furyGeneratorCastsSinceRampage = 0
            furyRampageUsableSince = 0
            furyGeneratorsSinceRampageUsable = 0
            Engine.MarkFuryEnrageApplied()
        elseif Engine.IsFuryOdynsFurySpell(spellID, spellName) then
            Engine.MarkFuryEnrageApplied()
        end

        if Engine.IsFuryRageGeneratorSpell(spellID, spellName) then
            local now = GetTime()
            -- Some abilities emit paired success events for one cast. Count
            -- at most one generator inside a single event burst.
            if now - furyLastGeneratorCountedAt >= 0.25 then
                furyGeneratorCastsSinceRampage = math.min(3, furyGeneratorCastsSinceRampage + 1)
                furyLastGeneratorCountedAt = now
                if furyRampageUsableSince > 0 then
                    furyGeneratorsSinceRampageUsable = math.min(5, furyGeneratorsSinceRampageUsable + 1)
                end
            end
        end
    end

end

function Engine.GetWarbreakerLikeSpellID()
    if IsSpellKnownInBook(WARBREAKER_SPELL_ID) then
        return WARBREAKER_SPELL_ID
    end

    if IsSpellKnownInBook(COLOSSUS_SMASH_SPELL_ID) then
        return COLOSSUS_SMASH_SPELL_ID
    end

    return nil
end

function addon:IsFuryMountainThane()
    if not IsFuryWarrior() then
        return false
    end

    if self:HasActiveHeroTalentName("Mountain Thane") then
        return true
    end

    return Engine.GetThunderBlastSpellID() ~= nil
end

function addon:IsFurySlayer()
    if not IsFuryWarrior() then
        return false
    end

    if self:HasActiveHeroTalentName("Slayer") then
        return true
    end

    if self:GetActiveHeroTalentSpecName() then
        return false
    end

    return not self:IsFuryMountainThane()
end

function addon:IsArmsColossus()
    if not IsArmsWarrior() then
        return false
    end

    if self:HasActiveHeroTalentName("Colossus") then
        return true
    end

    return Engine.GetDemolishSpellID() ~= nil
end

function addon:IsArmsSlayer()
    if not IsArmsWarrior() then
        return false
    end

    if self:HasActiveHeroTalentName("Slayer") then
        return true
    end

    if self:GetActiveHeroTalentSpecName() then
        return false
    end

    return not self:IsArmsColossus()
end

function addon:IsRetributionTemplar()
    if not IsRetributionPaladin() then
        return false
    end

    if self:HasActiveHeroTalentName("Templar") then
        return true
    end

    if self:GetActiveHeroTalentSpecName() then
        return false
    end

    return RET.isAvailable(Engine.GetHammerOfLightSpellID(), true)
end

function addon:IsRetributionHeraldOfTheSun()
    if not IsRetributionPaladin() then
        return false
    end

    if self:HasActiveHeroTalentName("Herald of the Sun") then
        return true
    end

    if self:GetActiveHeroTalentSpecName() then
        return false
    end

    return not self:IsRetributionTemplar()
end

function addon:GetRetributionHeroTalentName()
    if self:IsRetributionTemplar() then
        return "Templar"
    end

    if self:IsRetributionHeraldOfTheSun() then
        return "Herald of the Sun"
    end

    return self:GetActiveHeroTalentSpecName()
end

function addon:GetRetributionBuildName()
    if not IsRetributionPaladin() then
        return nil
    end

    if Engine.HasRadiantGlory() then
        return "Radiant Glory"
    end

    if RET.isAvailable(Engine.GetExecutionSentenceSpellID(), true) then
        return "Execution Sentence"
    end

    return nil
end

function addon:GetRetributionBuildAbbreviation()
    local buildName = self:GetRetributionBuildName()
    if buildName == "Radiant Glory" then
        return "RG"
    end

    if buildName == "Execution Sentence" then
        return "ES"
    end

    return nil
end

function addon:IsBeastMasteryPackLeader()
    return IsBeastMasteryHunter() and self:HasActiveHeroTalentName("Pack Leader")
end

function addon:IsBeastMasteryDarkRanger()
    return IsBeastMasteryHunter() and self:HasActiveHeroTalentName("Dark Ranger")
end

function addon:GetPaladinProfileLabel()
    if playerClass ~= "PALADIN" then
        return nil
    end

    local specID = GetCurrentSpecID()
    local specName = self:GetCurrentSpecName()
    if not specName or specName == "" then
        if specID == 65 then
            specName = "Holy"
        elseif specID == 66 then
            specName = "Protection"
        elseif specID == RET.specID then
            specName = "Retribution"
        else
            specName = "Paladin"
        end
    end

    local heroTalentName = addon:GetActiveHeroTalentSpecName()
    if IsRetributionPaladin() then
        heroTalentName = self:GetRetributionHeroTalentName()
    end

    if heroTalentName and heroTalentName ~= "" then
        local label = specName .. " - " .. heroTalentName
        local buildAbbreviation = IsRetributionPaladin() and self:GetRetributionBuildAbbreviation() or nil
        if buildAbbreviation then
            label = label .. " " .. buildAbbreviation
        end
        return label
    end

    return specName
end

function addon:GetProfileLabel()
    if IsSubtletyRogue() then
        local heroTalentName = self:GetActiveHeroTalentSpecName()
        if heroTalentName then
            return "Subtlety - " .. heroTalentName
        end

        return "Subtlety"
    end

    if IsFrostDeathKnight() then
        local heroTalentName = self:GetActiveHeroTalentSpecName()
        if heroTalentName then
            return "Frost - " .. heroTalentName
        end

        return "Frost"
    end

    if IsBeastMasteryHunter() then
        local heroTalentName = self:GetActiveHeroTalentSpecName()
        if heroTalentName then
            return "Beast Mastery - " .. heroTalentName
        end

        return "Beast Mastery"
    end

    if self:IsFuryMountainThane() then
        return "Fury - Mountain Thane"
    end

    if self:IsFurySlayer() then
        return "Fury - Slayer"
    end

    if self:IsArmsColossus() then
        return "Arms - Colossus"
    end

    if self:IsArmsSlayer() then
        return "Arms - Slayer"
    end

    local paladinProfileLabel = self:GetPaladinProfileLabel()
    if paladinProfileLabel then
        return paladinProfileLabel
    end

    if IsFuryWarrior() then
        return "Fury"
    end

    if IsArmsWarrior() then
        return "Arms"
    end

    if addon.SpecEngine then
        return addon.SpecEngine:GetProfileLabel()
    end

    return nil
end

function Engine.BuildWarriorState()
    if not (IsFuryWarrior() or IsArmsWarrior()) then
        return nil
    end

    local executeSpellID = Engine.GetExecuteSpellID()
    local bloodbathSpellID = Engine.GetBloodbathSpellID()
    local crushingBlowSpellID = Engine.GetCrushingBlowSpellID()
    local whirlwindSpellID = Engine.GetWhirlwindSpellID()
    local bladestormSpellID = Engine.GetBladestormSpellID()
    local odynsFurySpellID = Engine.GetOdynsFurySpellID()
    local ravagerSpellID = Engine.GetRavagerSpellID()
    local championSpearSpellID = Engine.GetChampionsSpearSpellID()
    local heroicStrikeSpellID = Engine.GetHeroicStrikeSpellID()
    local demolishSpellID = Engine.GetDemolishSpellID()
    local thunderBlastSpellID = Engine.GetThunderBlastSpellID()
    local warbreakerLikeSpellID = Engine.GetWarbreakerLikeSpellID()
    local wreckingThrowSpellID = Engine.GetWreckingThrowSpellID()
    local stormBoltSpellID = Engine.GetStormBoltSpellID()
    local gcd = GetApproxGlobalCooldown()
    local targetHealthPercent = GetUnitHealthPercent("target")
    local assistedSuggestion = Engine.GetAssistedCombatSuggestion()
    local rageEstimate = nil
    if addon.RageModel then
        local okEstimate, estimate = pcall(addon.RageModel.Update, addon.RageModel)
        rageEstimate = okEstimate and estimate or nil
    end
    local rageBandLow, rageBandHigh = nil, nil
    if IsUnitPowerSecret("player", RAGE_POWER_TYPE) then
        rageBandLow, rageBandHigh = Engine.GetRageBand()
    end
    local inCombat = UnitAffectingCombat("player") == true
    if inCombat and not combatStartedAt then
        combatStartedAt = GetTime()
    elseif not inCombat then
        combatStartedAt = nil
    end
    local combatTime = inCombat and combatStartedAt and math.max(0, GetTime() - combatStartedAt) or nil

    local ragingBlowLikeSpellID = nil
    if Engine.CanUseEnemySpell(crushingBlowSpellID) then
        ragingBlowLikeSpellID = crushingBlowSpellID
    elseif Engine.CanUseEnemySpell(RAGING_BLOW_SPELL_ID) then
        ragingBlowLikeSpellID = RAGING_BLOW_SPELL_ID
    else
        ragingBlowLikeSpellID = crushingBlowSpellID or RAGING_BLOW_SPELL_ID
    end

    local bloodthirstLikeSpellID = nil
    if Engine.CanUseEnemySpell(bloodbathSpellID) then
        bloodthirstLikeSpellID = bloodbathSpellID
    elseif Engine.CanUseEnemySpell(BLOODTHIRST_SPELL_ID) then
        bloodthirstLikeSpellID = BLOODTHIRST_SPELL_ID
    else
        bloodthirstLikeSpellID = bloodbathSpellID or BLOODTHIRST_SPELL_ID
    end

    local rangeReferenceSpellIDs = nil
    if IsArmsWarrior() then
        rangeReferenceSpellIDs = {
            MORTAL_STRIKE_SPELL_ID,
            OVERPOWER_SPELL_ID,
            REND_SPELL_ID,
            SLAM_SPELL_ID,
            executeSpellID,
            warbreakerLikeSpellID,
        }
    else
        rangeReferenceSpellIDs = {
            bloodthirstLikeSpellID,
            bloodbathSpellID,
            ragingBlowLikeSpellID,
            crushingBlowSpellID,
            RAMPAGE_SPELL_ID,
            executeSpellID,
            thunderBlastSpellID,
        }
    end

    local detectedTargetCount, visibleHostileTargetCount, recentDamageTargetCount =
        Engine.CountHostileTargetsInMeleeRange(rangeReferenceSpellIDs, IsFuryWarrior())
    local targetCountOverride = Engine.GetTargetCountOverride()
    local targetCount, targetCountSource = Engine.ResolveTargetCount(detectedTargetCount)

    local thunderBlastCharges, thunderBlastChargesKnown = GetSpellChargesAvailable(thunderBlastSpellID)
    local overpowerCharges, overpowerChargesKnown = GetSpellChargesAvailable(OVERPOWER_SPELL_ID)
    local suddenDeathState = Engine.GetSuddenDeathState(executeSpellID)
    local suddenDeathUp = suddenDeathState.active
    local hasMassacre = Engine.HasMassacre()
    local hasDeepWounds = Engine.HasDeepWounds()
    local hasBroadStrokes = Engine.HasBroadStrokes()
    local hasDreadnaught = Engine.HasDreadnaught()
    local hasCleave = Engine.HasCleave()
    local hasRend = Engine.HasRend()
    local hasBloodletting = Engine.HasBloodletting()
    local hasFervorOfBattle = Engine.HasFervorOfBattle()
    local hasMassExecution = Engine.HasTalentByName("MASS_EXECUTION", nil, "Mass Execution")
    local hasOdynsFury = IsFuryWarrior() and Engine.HasOdynsFury()
    local hasBladestorm = Engine.HasBladestorm()
    local hasAvatar = Engine.HasAvatar()
    local recklessnessRemaining = math.max(
        GetPlayerAuraRemainingByID(RECKLESSNESS_SPELL_ID),
        GetPlayerAuraRemainingByName("Recklessness"),
        Engine.GetAssumedFuryRecklessnessRemaining()
    )
    local avatarRemaining = math.max(
        GetPlayerAuraRemainingByID(AVATAR_SPELL_ID),
        GetPlayerAuraRemainingByName("Avatar")
    )
    local suddenDeathStacks = math.max(
        GetPlayerAuraStacksByID(52437),
        GetPlayerAuraStacksByID(280776),
        GetPlayerAuraStacksByName("Sudden Death"),
        suddenDeathState.actionCount or 0
    )
    if suddenDeathUp and suddenDeathStacks <= 0 then
        suddenDeathStacks = 1
    end
    local executeUsable = executeSpellID
        and IsSpellReady(executeSpellID)
        and IsSpellInRangeForUnit(executeSpellID, "target")
        and Engine.IsSpellUsableStrict(executeSpellID)
    local executePhaseThreshold = hasMassacre and 0.35 or 0.20
    local executePhase = type(targetHealthPercent) == "number" and targetHealthPercent <= executePhaseThreshold
    local heroicStrikeActionCount = 0
    local heroicStrikeActionCountKnown = false
    local heroicStrikeOverrideActionCount = 0
    local heroicStrikeOverrideActionCountKnown = false
    local heroicStrikeButtonGlow = false
    local heroicStrikeButtonGlowKnown = false
    local heroicStrikeOverrideButtonGlow = false
    local heroicStrikeOverrideButtonGlowKnown = false
    local slamActionCount = 0
    local slamActionCountKnown = false
    local slamButtonGlow = false
    local slamButtonGlowKnown = false
    if addon.GetActionCountForSpell then
        heroicStrikeActionCount, heroicStrikeActionCountKnown = addon:GetActionCountForSpell(heroicStrikeSpellID)
        heroicStrikeOverrideActionCount, heroicStrikeOverrideActionCountKnown = addon:GetActionCountForSpell(HEROIC_STRIKE_ACTIONBAR_SPELL_ID)
        slamActionCount, slamActionCountKnown = addon:GetActionCountForSpell(SLAM_SPELL_ID)
    end
    if addon.HasActionButtonProcGlowForSpell then
        heroicStrikeButtonGlow, heroicStrikeButtonGlowKnown = addon:HasActionButtonProcGlowForSpell(heroicStrikeSpellID)
        heroicStrikeOverrideButtonGlow, heroicStrikeOverrideButtonGlowKnown = addon:HasActionButtonProcGlowForSpell(HEROIC_STRIKE_ACTIONBAR_SPELL_ID)
        slamButtonGlow, slamButtonGlowKnown = addon:HasActionButtonProcGlowForSpell(SLAM_SPELL_ID)
    end
    local heroicStrikeActionCountSignal = heroicStrikeActionCountKnown and heroicStrikeActionCount > 0
    local heroicStrikeOverrideActionCountSignal = heroicStrikeOverrideActionCountKnown and heroicStrikeOverrideActionCount > 0
    local slamActionCountSignal = slamActionCountKnown and slamActionCount > 0
    local masterOfWarfareProcUp = GetPlayerAuraRemainingByID(MASTER_OF_WARFARE_PROC_AURA_ID) > 0
        or GetPlayerAuraRemainingByName("Master of Warfare") > 0
        or IsSpellOverlayedSafe(heroicStrikeSpellID)
        or IsSpellOverlayedSafe(HEROIC_STRIKE_ACTIONBAR_SPELL_ID)
        or IsSpellOverlayedSafe(SLAM_SPELL_ID)
        or heroicStrikeActionCountSignal
        or heroicStrikeButtonGlow == true
        or heroicStrikeOverrideActionCountSignal
        or heroicStrikeOverrideButtonGlow == true
        or slamActionCountSignal
        or slamButtonGlow == true
    local masterOfWarfareStackUp = GetPlayerAuraRemainingByID(MASTER_OF_WARFARE_STACK_AURA_ID) > 0
    local heroicMightUp = GetPlayerAuraRemainingByID(HEROIC_MIGHT_AURA_ID) > 0
        or GetPlayerAuraRemainingByName("Heroic Might") > 0

    if IsFuryWarrior() then
        -- Resource-only usability (ignores range), so walking out of melee does
        -- not reset the estimate.
        if Engine.IsSpellUsableStrict(RAMPAGE_SPELL_ID) then
            if furyRampageUsableSince <= 0 then
                furyRampageUsableSince = GetTime()
                furyGeneratorsSinceRampageUsable = 0
            end
        else
            furyRampageUsableSince = 0
            furyGeneratorsSinceRampageUsable = 0
        end
    end

        return {
        hasTarget = HasHostileLivingTarget(),
        inCombat = inCombat,
        combatTime = combatTime,
        openerBloodthirstDone = furyOpenerBloodthirstDone or not combatTime or combatTime > 8.0,
        openerBloodthirstCastAt = furyOpenerBloodthirstCastAt,
        recentRampageCast = furyLastRampageCastAt > 0 and (GetTime() - furyLastRampageCastAt) <= math.max(3.0, (gcd or 1.5) + 1.0),
        rampageCastThisCombat = furyLastRampageCastAt > 0,
        furyGeneratorCastsSinceRampage = furyGeneratorCastsSinceRampage,
        furyRampageUsableFor = furyRampageUsableSince > 0 and (GetTime() - furyRampageUsableSince) or 0,
        furyGeneratorsSinceRampageUsable = furyGeneratorsSinceRampageUsable,
        isFury = IsFuryWarrior(),
        isArms = IsArmsWarrior(),
        isFurySlayer = addon:IsFurySlayer(),
        isFuryMountainThane = addon:IsFuryMountainThane(),
        isArmsColossus = addon:IsArmsColossus(),
        isArmsSlayer = addon:IsArmsSlayer(),
        targetCount = targetCount,
        detectedTargetCount = detectedTargetCount,
        visibleHostileTargetCount = visibleHostileTargetCount,
        recentDamageTargetCount = recentDamageTargetCount,
        targetCountOverride = targetCountOverride,
        targetCountSource = targetCountSource,
        isAOE = targetCount > 1,
        isCleave = targetCount >= 2 and targetCount <= 3,
        isTwoTarget = targetCount == 2,
        isLargeAOE = targetCount > 3,
        targetHealthKnown = type(targetHealthPercent) == "number",
        targetHealthPercent = targetHealthPercent,
        executePhase = executePhase,
        executeStrictUsable = executeUsable == true,
        rageKnown = not IsUnitPowerSecret("player", RAGE_POWER_TYPE),
        rage = GetCurrentRage(),
        rageBandLow = rageBandLow,
        rageBandHigh = rageBandHigh,
        rageEstimate = rageEstimate,
        assistedSuggestion = assistedSuggestion,
        resourceName = "Rage",
        resourceKnown = not IsUnitPowerSecret("player", RAGE_POWER_TYPE),
        resource = GetCurrentRage(),
        gcd = gcd,
        enrageRemaining = math.max(
            GetPlayerAuraRemainingByID(184362),
            GetPlayerAuraRemainingByName("Enrage"),
            Engine.GetAssumedFuryEnrageRemaining()
        ),
        recklessnessUp = recklessnessRemaining > 0,
        recklessnessRemaining = recklessnessRemaining,
        avatarUp = avatarRemaining > 0,
        avatarRemaining = avatarRemaining,
        hackAndSlashUp = GetPlayerAuraRemainingByName("Hack and Slash") > 0
            or IsSpellOverlayedSafe(crushingBlowSpellID)
            or IsSpellOverlayedSafe(RAGING_BLOW_SPELL_ID),
        recklessnessCooldown = GetCooldownRemaining(RECKLESSNESS_SPELL_ID),
        avatarCooldown = hasAvatar and GetCooldownRemaining(AVATAR_SPELL_ID) or 0,
        odynsFuryCooldown = hasOdynsFury and GetCooldownRemaining(odynsFurySpellID) or 0,
        bladestormCooldown = GetCooldownRemaining(bladestormSpellID),
        bladestormUp = (armsLastBladestormCastAt > 0 and (GetTime() - armsLastBladestormCastAt) <= 6.0)
            or GetUnitAuraInfo("Bladestorm", "player", "HELPFUL") ~= nil
            or GetUnitAuraInfo(bladestormSpellID, "player", "HELPFUL") ~= nil
            or GetUnitAuraInfo(227847, "player", "HELPFUL") ~= nil
            or GetUnitAuraInfo(46924, "player", "HELPFUL") ~= nil,
        hasAvatar = hasAvatar,
        hasOdynsFury = hasOdynsFury,
        hasBladestorm = hasBladestorm,
        hasImprovedWhirlwind = Engine.HasImprovedWhirlwind(),
        hasWrathAndFury = Engine.HasWrathAndFury(),
        hasMassacre = hasMassacre,
        hasDeepWounds = hasDeepWounds,
        hasBroadStrokes = hasBroadStrokes,
        hasDreadnaught = hasDreadnaught,
        hasCleave = hasCleave,
        hasRend = hasRend,
        hasBloodletting = hasBloodletting,
        hasFervorOfBattle = hasFervorOfBattle,
        hasMassExecution = hasMassExecution,
        hasRavager = ravagerSpellID ~= nil and IsSpellKnownInBook(ravagerSpellID),
        hasHeroicStrike = heroicStrikeSpellID ~= nil and IsSpellKnownInBook(heroicStrikeSpellID),
        masterOfWarfareUp = masterOfWarfareProcUp,
        masterOfWarfareProcUp = masterOfWarfareProcUp,
        masterOfWarfareStackUp = masterOfWarfareStackUp,
        heroicMightUp = heroicMightUp,
        hasCollateralDamage = Engine.HasTalentByName("COLLATERAL_DAMAGE", nil, "Collateral Damage"),
        hasDemolish = demolishSpellID ~= nil and IsSpellKnownInBook(demolishSpellID),
        whirlwindStacks = math.max(
            GetPlayerAuraStacksByID(85739),
            GetPlayerAuraStacksByName("Whirlwind"),
            GetPlayerAuraStacksByName("Improved Whirlwind"),
            GetPlayerAuraStacksByName("Meat Cleaver"),
            Engine.GetAssumedFuryWhirlwindStacks()
        ),
        assumedWhirlwindStacks = Engine.GetAssumedFuryWhirlwindStacks(),
        thunderBlastStacks = GetPlayerAuraStacksByID(435615),
        thunderBlastRemaining = math.max(
            GetPlayerAuraRemainingByID(435615),
            GetPlayerAuraRemainingByName("Thunder Blast")
        ),
        thunderBlastCharges = thunderBlastCharges or 0,
        thunderBlastChargesKnown = thunderBlastChargesKnown,
        overpowerCharges = overpowerCharges or 0,
        overpowerChargesKnown = overpowerChargesKnown,
        rendRemaining = math.max(GetTargetDebuffRemaining(REND_SPELL_ID, "Rend"), addon:GetAssumedArmsRendRemaining()),
        recentColossusSmashCast = armsLastColossusCastAt > 0 and (GetTime() - armsLastColossusCastAt) <= math.max(3.0, (gcd or 1.5) + 1.0),
        colossusSmashRemaining = math.max(
            GetTargetDebuffRemaining(208086, "Colossus Smash"),
            GetTargetDebuffRemaining(COLOSSUS_SMASH_SPELL_ID, "Colossus Smash")
        ),
        executionersPrecisionStacks = math.max(
            GetPlayerAuraStacksByID(386633),
            GetPlayerAuraStacksByName("Executioner's Precision"),
            addon:GetAssumedArmsExecutionersPrecisionStacks()
        ),
        colossalMightStacks = GetPlayerAuraStacksByName("Colossal Might"),
        collateralDamageStacks = GetPlayerAuraStacksByName("Collateral Damage"),
        suddenDeathUp = suddenDeathUp,
        suddenDeathStacks = suddenDeathStacks,
        suddenDeathAuraByID = suddenDeathState.auraByID,
        suddenDeathAuraByAltID = suddenDeathState.auraByAltID,
        suddenDeathAuraByName = suddenDeathState.auraByName,
        suddenDeathOverlayByExecute = suddenDeathState.overlayByResolvedExecute,
        suddenDeathOverlayByBaseExecute = suddenDeathState.overlayByBaseExecute,
        suddenDeathOverlayByFuryExecute = suddenDeathState.overlayByFuryExecute,
        suddenDeathActionCount = suddenDeathState.actionCount,
        suddenDeathActionCountKnown = suddenDeathState.actionCountKnown,
        suddenDeathActionCountSignal = suddenDeathState.actionCountSignal,
        suddenDeathButtonGlow = suddenDeathState.buttonGlow,
        suddenDeathButtonGlowKnown = suddenDeathState.buttonGlowKnown,
        heroicStrikeActionCount = heroicStrikeActionCount,
        heroicStrikeActionCountKnown = heroicStrikeActionCountKnown,
        heroicStrikeActionCountSignal = heroicStrikeActionCountSignal,
        heroicStrikeOverrideActionCount = heroicStrikeOverrideActionCount,
        heroicStrikeOverrideActionCountKnown = heroicStrikeOverrideActionCountKnown,
        heroicStrikeOverrideActionCountSignal = heroicStrikeOverrideActionCountSignal,
        heroicStrikeButtonGlow = heroicStrikeButtonGlow,
        heroicStrikeButtonGlowKnown = heroicStrikeButtonGlowKnown,
        heroicStrikeOverrideButtonGlow = heroicStrikeOverrideButtonGlow,
        heroicStrikeOverrideButtonGlowKnown = heroicStrikeOverrideButtonGlowKnown,
        slamActionCount = slamActionCount,
        slamActionCountKnown = slamActionCountKnown,
        slamActionCountSignal = slamActionCountSignal,
        slamButtonGlow = slamButtonGlow,
        slamButtonGlowKnown = slamButtonGlowKnown,
        battlelordUp = GetPlayerAuraRemainingByName("Battlelord") > 0 or IsSpellOverlayedSafe(MORTAL_STRIKE_SPELL_ID),
        battlelordStacks = GetPlayerAuraStacksByName("Battlelord"),
        fierceFollowthroughUp = GetPlayerAuraRemainingByName("Fierce Followthrough") > 0,
        opportunistUp = GetPlayerAuraRemainingByName("Opportunist") > 0 or IsSpellOverlayedSafe(OVERPOWER_SPELL_ID),
        opportunistStacks = GetPlayerAuraStacksByName("Opportunist"),
        imminentDemiseStacks = GetPlayerAuraStacksByName("Imminent Demise"),
        executionerStacks = GetPlayerAuraStacksByName("Executioner"),
        sweepingStrikesUp = GetPlayerAuraRemainingByID(SWEEPING_STRIKES_SPELL_ID) > 0,
        spell = {
            charge = CHARGE_SPELL_ID,
            execute = executeSpellID,
            bloodbath = bloodbathSpellID,
            bloodthirst = BLOODTHIRST_SPELL_ID,
            bloodthirstLike = bloodthirstLikeSpellID,
            crushingBlow = crushingBlowSpellID,
            ragingBlow = RAGING_BLOW_SPELL_ID,
            ragingBlowLike = ragingBlowLikeSpellID,
            whirlwind = whirlwindSpellID,
            bladestorm = bladestormSpellID,
            odynsFury = odynsFurySpellID,
            ravager = ravagerSpellID,
            championSpear = championSpearSpellID,
            heroicStrike = heroicStrikeSpellID,
            demolish = demolishSpellID,
            thunderBlast = thunderBlastSpellID,
            warbreakerLike = warbreakerLikeSpellID,
            wreckingThrow = wreckingThrowSpellID,
            stormBolt = stormBoltSpellID,
        },
    }
end

local function ResolveFrostDeathKnightSpell(cacheKey, spellID, spellName)
    return ResolveActionBarSpellIDByName(spellName)
        or ResolveKnownSpellID(cacheKey, { spellID }, spellName)
end

local function ResolveSubtletyRogueSpell(cacheKey, spellID, spellName)
    return ResolveActionBarSpellIDByName(spellName)
        or ResolveKnownSpellID(cacheKey, spellID and { spellID } or nil, spellName)
end

function Engine.BuildSubtletyRogueState()
    if not IsSubtletyRogue() then
        return nil
    end

    local spell = {
        stealth = ResolveSubtletyRogueSpell("SUB_STEALTH", SUB_ROGUE.stealth, "Stealth"),
        vanish = ResolveSubtletyRogueSpell("SUB_VANISH", SUB_ROGUE.vanish, "Vanish"),
        backstab = ResolveSubtletyRogueSpell("SUB_BACKSTAB", SUB_ROGUE.backstab, "Backstab"),
        gloomblade = ResolveSubtletyRogueSpell("SUB_GLOOMBLADE", SUB_ROGUE.gloomblade, "Gloomblade"),
        shadowstrike = ResolveSubtletyRogueSpell("SUB_SHADOWSTRIKE", SUB_ROGUE.shadowstrike, "Shadowstrike"),
        eviscerate = ResolveSubtletyRogueSpell("SUB_EVISCERATE", SUB_ROGUE.eviscerate, "Eviscerate"),
        shurikenStorm = ResolveSubtletyRogueSpell("SUB_SHURIKEN_STORM", SUB_ROGUE.shurikenStorm, "Shuriken Storm"),
        blackPowder = ResolveSubtletyRogueSpell("SUB_BLACK_POWDER", SUB_ROGUE.blackPowder, "Black Powder"),
        shadowDance = ResolveSubtletyRogueSpell("SUB_SHADOW_DANCE", SUB_ROGUE.shadowDance, "Shadow Dance"),
        shadowBlades = ResolveSubtletyRogueSpell("SUB_SHADOW_BLADES", SUB_ROGUE.shadowBlades, "Shadow Blades"),
        secretTechnique = ResolveSubtletyRogueSpell("SUB_SECRET_TECHNIQUE", SUB_ROGUE.secretTechnique, "Secret Technique"),
        goremawsBite = ResolveSubtletyRogueSpell("SUB_GOREMAWS_BITE", SUB_ROGUE.goremawsBite, "Goremaw's Bite"),
        coupDeGrace = ResolveSubtletyRogueSpell("SUB_COUP_DE_GRACE", nil, "Coup de Grace"),
    }

    local detectedTargetCount, visibleHostileTargetCount, recentDamageTargetCount =
        Engine.CountHostileTargetsInMeleeRange({ spell.shadowstrike, spell.gloomblade, spell.backstab, spell.shurikenStorm })
    local targetCountOverride = Engine.GetTargetCountOverride()
    local targetCount, targetCountSource = Engine.ResolveTargetCount(detectedTargetCount)
    local comboPointsKnown = not IsUnitPowerSecret("player", COMBO_POINTS_POWER_TYPE)
    local energyKnown = not IsUnitPowerSecret("player", ENERGY_POWER_TYPE)
    local shadowDanceCharges, shadowDanceChargesKnown = GetSpellChargesAvailable(spell.shadowDance)
    local stealthed = GetPlayerAuraRemainingByName("Stealth") > 0
        or GetPlayerAuraRemainingByName("Vanish") > 0
    if IsStealthed then
        local ok, active = pcall(IsStealthed)
        stealthed = stealthed or (ok and active == true)
    end

    return {
        profileType = "SUBTLETY_ROGUE",
        hasTarget = HasHostileLivingTarget(),
        inCombat = UnitAffectingCombat("player") == true,
        isSubtletyRogue = true,
        isSubtletyDeathstalker = addon:HasActiveHeroTalentName("Deathstalker"),
        isSubtletyTrickster = addon:HasActiveHeroTalentName("Trickster"),
        targetCount = targetCount,
        detectedTargetCount = detectedTargetCount,
        visibleHostileTargetCount = visibleHostileTargetCount,
        recentDamageTargetCount = recentDamageTargetCount,
        targetCountOverride = targetCountOverride,
        targetCountSource = targetCountSource,
        isAOE = targetCount >= 2,
        isCleave = targetCount >= 2 and targetCount <= 3,
        isTwoTarget = targetCount == 2,
        isLargeAOE = targetCount >= 4,
        gcd = GetApproxGlobalCooldown(),
        energyKnown = energyKnown,
        energy = GetCurrentEnergy(),
        resourceName = "Energy",
        resourceKnown = energyKnown,
        resource = GetCurrentEnergy(),
        comboPointsKnown = comboPointsKnown,
        comboPoints = GetCurrentComboPoints(),
        maximumComboPoints = GetMaximumComboPoints(),
        stealthed = stealthed,
        shadowDanceUp = GetPlayerAuraRemainingByID(SUB_ROGUE.shadowDanceAura) > 0
            or GetPlayerAuraRemainingByName("Shadow Dance") > 0
            or Engine.GetAssumedSubtletyShadowDanceRemaining() > 0,
        shadowDanceRemaining = math.max(
            GetPlayerAuraRemainingByID(SUB_ROGUE.shadowDanceAura),
            GetPlayerAuraRemainingByName("Shadow Dance"),
            Engine.GetAssumedSubtletyShadowDanceRemaining()
        ),
        shadowBladesUp = GetPlayerAuraRemainingByID(SUB_ROGUE.shadowBlades) > 0
            or GetPlayerAuraRemainingByName("Shadow Blades") > 0
            or Engine.GetAssumedSubtletyShadowBladesRemaining() > 0,
        coupDeGraceUp = GetPlayerAuraRemainingByName("Coup de Grace") > 0
            or IsSpellOverlayedSafe(spell.coupDeGrace)
            or IsSpellOverlayedSafe(spell.eviscerate),
        darkestNightUp = GetPlayerAuraRemainingByName("The Darkest Night") > 0
            or GetPlayerAuraRemainingByName("Darkest Night") > 0,
        quietusCelerisUp = GetPlayerAuraRemainingByName("Quietus Celeris") > 0,
        shadowDanceCharges = SafeNumberOrDefault(shadowDanceCharges, 0),
        shadowDanceChargesKnown = shadowDanceChargesKnown == true,
        spell = spell,
    }
end

function Engine.BuildFrostDeathKnightState()
    if not IsFrostDeathKnight() then
        return nil
    end

    local spell = {
        obliterate = ResolveFrostDeathKnightSpell("FROST_DK_OBLITERATE", FROST_DK.obliterate, "Obliterate"),
        frostStrike = ResolveFrostDeathKnightSpell("FROST_DK_FROST_STRIKE", FROST_DK.frostStrike, "Frost Strike"),
        howlingBlast = ResolveFrostDeathKnightSpell("FROST_DK_HOWLING_BLAST", FROST_DK.howlingBlast, "Howling Blast"),
        pillarOfFrost = ResolveFrostDeathKnightSpell("FROST_DK_PILLAR", FROST_DK.pillarOfFrost, "Pillar of Frost"),
        empowerRuneWeapon = ResolveFrostDeathKnightSpell("FROST_DK_ERW", FROST_DK.empowerRuneWeapon, "Empower Rune Weapon"),
        breathOfSindragosa = ResolveFrostDeathKnightSpell("FROST_DK_BREATH", FROST_DK.breathOfSindragosa, "Breath of Sindragosa"),
        frostwyrmsFury = ResolveFrostDeathKnightSpell("FROST_DK_FROSTWYRM", FROST_DK.frostwyrmsFury, "Frostwyrm's Fury"),
        frostscythe = ResolveFrostDeathKnightSpell("FROST_DK_FROSTSCYTHE", FROST_DK.frostscythe, "Frostscythe"),
        glacialAdvance = ResolveFrostDeathKnightSpell("FROST_DK_GLACIAL_ADVANCE", FROST_DK.glacialAdvance, "Glacial Advance"),
        reapersMark = ResolveFrostDeathKnightSpell("FROST_DK_REAPERS_MARK", FROST_DK.reapersMark, "Reaper's Mark"),
        remorselessWinter = ResolveFrostDeathKnightSpell("FROST_DK_REMORSELESS_WINTER", FROST_DK.remorselessWinter, "Remorseless Winter"),
        raiseDead = ResolveFrostDeathKnightSpell("FROST_DK_RAISE_DEAD", FROST_DK.raiseDead, "Raise Dead"),
    }

    local detectedTargetCount, visibleHostileTargetCount, recentDamageTargetCount =
        Engine.CountHostileTargetsInMeleeRange({ spell.obliterate, spell.frostStrike, spell.frostscythe })
    local targetCountOverride = Engine.GetTargetCountOverride()
    local targetCount, targetCountSource = Engine.ResolveTargetCount(detectedTargetCount)
    local runicPowerKnown = not IsUnitPowerSecret("player", RUNIC_POWER_TYPE)
    local readyRunes, readyRunesKnown = GetReadyRuneCount()
    local empowerRuneWeaponCharges, empowerRuneWeaponChargesKnown = GetSpellChargesAvailable(spell.empowerRuneWeapon)
    local killingMachineStacks = math.max(
        GetPlayerAuraStacksByID(FROST_DK.killingMachineAura),
        GetPlayerAuraStacksByName("Killing Machine")
    )
    if killingMachineStacks <= 0
    and (IsSpellOverlayedSafe(spell.obliterate) or IsSpellOverlayedSafe(spell.frostscythe))
    then
        killingMachineStacks = 1
    end

    local rimeUp = GetPlayerAuraRemainingByID(FROST_DK.rimeAura) > 0
        or GetPlayerAuraRemainingByName("Rime") > 0
        or IsSpellOverlayedSafe(spell.howlingBlast)

    return {
        profileType = "FROST_DEATH_KNIGHT",
        hasTarget = HasHostileLivingTarget(),
        inCombat = UnitAffectingCombat("player") == true,
        isFrostDeathKnight = true,
        isFrostDeathbringer = addon:HasActiveHeroTalentName("Deathbringer"),
        targetCount = targetCount,
        detectedTargetCount = detectedTargetCount,
        visibleHostileTargetCount = visibleHostileTargetCount,
        recentDamageTargetCount = recentDamageTargetCount,
        targetCountOverride = targetCountOverride,
        targetCountSource = targetCountSource,
        isAOE = targetCount >= 3,
        isCleave = targetCount == 2,
        isTwoTarget = targetCount == 2,
        isLargeAOE = targetCount >= 4,
        gcd = GetApproxGlobalCooldown(),
        runicPowerKnown = runicPowerKnown,
        runicPower = GetCurrentRunicPower(),
        resourceName = "Runic Power",
        resourceKnown = runicPowerKnown,
        resource = GetCurrentRunicPower(),
        readyRunes = readyRunes,
        readyRunesKnown = readyRunesKnown,
        killingMachineStacks = killingMachineStacks,
        rimeUp = rimeUp,
        exterminateUp = GetPlayerAuraRemainingByName("Exterminate") > 0,
        pillarOfFrostUp = GetPlayerAuraRemainingByID(FROST_DK.pillarOfFrost) > 0
            or GetPlayerAuraRemainingByName("Pillar of Frost") > 0,
        pillarOfFrostRemaining = math.max(
            GetPlayerAuraRemainingByID(FROST_DK.pillarOfFrost),
            GetPlayerAuraRemainingByName("Pillar of Frost")
        ),
        breathOfSindragosaUp = GetPlayerAuraRemainingByID(FROST_DK.breathOfSindragosa) > 0
            or GetPlayerAuraRemainingByName("Breath of Sindragosa") > 0,
        recentFrostwyrmsFuryCast = frostDKLastFrostwyrmsFuryCastAt > 0
            and (GetTime() - frostDKLastFrostwyrmsFuryCastAt) < 40.0,
        empowerRuneWeaponCharges = SafeNumberOrDefault(empowerRuneWeaponCharges, 0),
        empowerRuneWeaponChargesKnown = empowerRuneWeaponChargesKnown == true,
        spell = spell,
    }
end

function Engine.BuildBeastMasteryHunterState()
    if not IsBeastMasteryHunter() then
        return nil
    end

    local killCommandSpellID = Engine.GetHunterKillCommandSpellID()
    local barbedShotSpellID = Engine.GetBarbedShotSpellID()
    local bestialWrathSpellID = Engine.GetBestialWrathSpellID()
    local wildThrashSpellID = Engine.GetWildThrashSpellID()
    local cobraShotSpellID = Engine.GetCobraShotSpellID()
    local steadyShotSpellID = Engine.GetSteadyShotSpellID()
    local blackArrowSpellID = Engine.GetBlackArrowSpellID()
    local wailingArrowSpellID = Engine.GetWailingArrowSpellID()
    local cooldownViewerBeastCleaveActive = Engine.IsCooldownViewerBeastCleaveActive()
    local detectedTargetCount, visibleHostileTargetCount, recentDamageTargetCount = Engine.CountHostileTargetsInMeleeRange(wildThrashSpellID or killCommandSpellID or cobraShotSpellID)
    local targetCountOverride = Engine.GetTargetCountOverride()
    local targetCount, targetCountSource = Engine.ResolveTargetCount(detectedTargetCount)
    local gcd = GetApproxGlobalCooldown()
    local focusKnown = not IsUnitPowerSecret("player", FOCUS_POWER_TYPE)
    local focus = GetCurrentFocus()
    local killCommandCharges, killCommandChargesKnown = GetSpellChargesAvailable(killCommandSpellID)
    local barbedShotCharges, barbedShotChargesKnown = GetSpellChargesAvailable(barbedShotSpellID)

    if killCommandSpellID ~= KILL_COMMAND_SPELL_ID
    and (not killCommandChargesKnown or not IsSafeNumberAtLeast(killCommandCharges, 1))
    then
        local fallbackCharges, fallbackChargesKnown = GetSpellChargesAvailable(KILL_COMMAND_SPELL_ID)
        if fallbackChargesKnown then
            killCommandCharges = fallbackCharges
            killCommandChargesKnown = fallbackChargesKnown
        end
    end

    if barbedShotSpellID ~= BARBED_SHOT_SPELL_ID
    and (not barbedShotChargesKnown or not IsSafeNumberAtLeast(barbedShotCharges, 1))
    then
        local fallbackCharges, fallbackChargesKnown = GetSpellChargesAvailable(BARBED_SHOT_SPELL_ID)
        if fallbackChargesKnown then
            barbedShotCharges = fallbackCharges
            barbedShotChargesKnown = fallbackChargesKnown
        end
    end

    killCommandChargesKnown = killCommandChargesKnown and IsSafeNonSecretNumber(killCommandCharges)
    barbedShotChargesKnown = barbedShotChargesKnown and IsSafeNonSecretNumber(barbedShotCharges)
    killCommandCharges = SafeNumberOrDefault(killCommandCharges, 0)
    barbedShotCharges = SafeNumberOrDefault(barbedShotCharges, 0)

    return {
        profileType = "BEAST_MASTERY_HUNTER",
        hasTarget = HasHostileLivingTarget(),
        isBeastMasteryHunter = true,
        isBeastMasteryPackLeader = addon:IsBeastMasteryPackLeader(),
        isBeastMasteryDarkRanger = addon:IsBeastMasteryDarkRanger(),
        targetCount = targetCount,
        detectedTargetCount = detectedTargetCount,
        visibleHostileTargetCount = visibleHostileTargetCount,
        recentDamageTargetCount = recentDamageTargetCount,
        targetCountOverride = targetCountOverride,
        targetCountSource = targetCountSource,
        isAOE = targetCount > 1,
        isCleave = targetCount >= 2 and targetCount <= 3,
        isTwoTarget = targetCount == 2,
        isLargeAOE = targetCount > 3,
        targetHealthKnown = type(GetUnitHealthPercent("target")) == "number",
        targetHealthPercent = GetUnitHealthPercent("target"),
        gcd = gcd,
        focusKnown = focusKnown,
        focus = focus,
        resourceName = "Focus",
        resourceKnown = focusKnown,
        resource = focus,
        killCommandCharges = killCommandCharges,
        killCommandChargesKnown = killCommandChargesKnown,
        barbedShotCharges = barbedShotCharges,
        barbedShotChargesKnown = barbedShotChargesKnown,
        beastCleaveRemaining = math.max(Engine.GetBeastCleaveRemaining(cooldownViewerBeastCleaveActive), Engine.GetAssumedBeastCleaveRemaining()),
        bestialWrathRemaining = math.max(GetPlayerAuraRemainingByID(bestialWrathSpellID), GetPlayerAuraRemainingByName("Bestial Wrath")),
        cobraFangStacks = GetPlayerAuraStacksByName("Cobra Fang"),
        witheringFireRemaining = GetPlayerAuraRemainingByName("Withering Fire"),
        deathblowRemaining = GetPlayerAuraRemainingByName("Deathblow"),
        howlOfThePackLeaderRemaining = GetPlayerAuraRemainingByName("Howl of the Pack Leader"),
        natureAllyRemaining = GetPlayerAuraRemainingByName("Nature's Ally"),
        killCommandActionGlow = IsSpellOverlayedSafe(killCommandSpellID),
        bestialWrathCooldown = GetCooldownRemaining(bestialWrathSpellID),
        killCommandCooldown = GetCooldownRemaining(killCommandSpellID),
        wildThrashCooldown = GetCooldownRemaining(wildThrashSpellID),
        cooldownViewerBestialWrath = IsCooldownViewerSpellTracked(bestialWrathSpellID),
        cooldownViewerKillCommand = IsCooldownViewerSpellTracked(killCommandSpellID),
        cooldownViewerBarbedShot = IsCooldownViewerSpellTracked(barbedShotSpellID),
        cooldownViewerWildThrash = IsCooldownViewerSpellTracked(wildThrashSpellID),
        cooldownViewerCobraShot = IsCooldownViewerSpellTracked(cobraShotSpellID),
        cooldownViewerSteadyShot = IsCooldownViewerSpellTracked(steadyShotSpellID),
        cooldownViewerBlackArrow = IsCooldownViewerSpellTracked(blackArrowSpellID),
        cooldownViewerWailingArrow = IsCooldownViewerSpellTracked(wailingArrowSpellID),
        cooldownViewerBeastCleaveActive = cooldownViewerBeastCleaveActive,
        spell = {
            killCommand = killCommandSpellID,
            barbedShot = barbedShotSpellID,
            bestialWrath = bestialWrathSpellID,
            cobraShot = cobraShotSpellID,
            wildThrash = wildThrashSpellID,
            steadyShot = steadyShotSpellID,
            blackArrow = blackArrowSpellID,
            wailingArrow = wailingArrowSpellID,
        },
    }
end

function Engine.BuildRetributionPaladinState()
    if not IsRetributionPaladin() then
        return nil
    end

    local avengingWrathSpellID = Engine.GetAvengingWrathSpellID()
    local executionSentenceSpellID = Engine.GetExecutionSentenceSpellID()
    local singleTargetSpenderSpellID = Engine.GetRetSingleTargetSpenderSpellID()
    local divineStormSpellID = Engine.GetDivineStormSpellID()
    local wakeOfAshesSpellID = Engine.GetWakeOfAshesSpellID()
    local divineTollSpellID = Engine.GetDivineTollSpellID()
    local hammerOfLightSpellID = Engine.GetHammerOfLightSpellID()
    local hammerOfWrathSpellID = Engine.GetHammerOfWrathSpellID()
    local bladeOfJusticeSpellID = Engine.GetBladeOfJusticeSpellID()
    local judgmentSpellID = Engine.GetJudgmentSpellID()
    local crusaderStrikeSpellID = Engine.GetCrusaderStrikeSpellID()
    local templarStrikeSpellID = Engine.GetTemplarStrikeSpellID()
    local templarSlashSpellID = Engine.GetTemplarSlashSpellID()
    local targetHealthPercent = GetUnitHealthPercent("target")
    local inCombat = UnitAffectingCombat("player") == true
    if inCombat and not retCombatStartedAt then
        retCombatStartedAt = GetTime()
    elseif not inCombat then
        retCombatStartedAt = nil
    end
    local combatTime = inCombat and retCombatStartedAt and math.max(0, GetTime() - retCombatStartedAt) or nil
    local detectedTargetCount, visibleHostileTargetCount, recentDamageTargetCount = Engine.CountHostileTargetsInMeleeRange(
        templarStrikeSpellID or crusaderStrikeSpellID or divineStormSpellID or bladeOfJusticeSpellID
    )
    local targetCountOverride = Engine.GetTargetCountOverride()
    local targetCount, targetCountSource = Engine.ResolveTargetCount(detectedTargetCount)
    local holyPowerKnown = not IsUnitPowerSecret("player", RET.holyPowerType)
    local holyPower = GetCurrentHolyPower()
    local hasTwoTargetAOETalents = IsSpellKnownInBook(ResolveKnownSpellID(
            "TEMPEST_OF_THE_LIGHTBRINGER",
            nil,
            "Tempest of the Lightbringer"
        ))
        and not IsSpellKnownInBook(ResolveKnownSpellID("JURISDICTION", nil, "Jurisdiction"))
    local isAOE = targetCount >= 2
    local bladeOfJusticeCharges, bladeOfJusticeChargesKnown = GetSpellChargesAvailable(bladeOfJusticeSpellID)
    local hammerOfWrathCharges, hammerOfWrathChargesKnown = GetSpellChargesAvailable(hammerOfWrathSpellID)
    local bladeActionGlow, bladeActionGlowKnown = false, false
    local hammerActionGlow, hammerActionGlowKnown = false, false
    local divineStormActionGlow, divineStormActionGlowKnown = false, false

    if addon.HasActionButtonProcGlowForSpell then
        bladeActionGlow, bladeActionGlowKnown = addon:HasActionButtonProcGlowForSpell(bladeOfJusticeSpellID or RET.bladeOfJustice)
        hammerActionGlow, hammerActionGlowKnown = addon:HasActionButtonProcGlowForSpell(hammerOfWrathSpellID or RET.hammerOfWrath)
        divineStormActionGlow, divineStormActionGlowKnown = addon:HasActionButtonProcGlowForSpell(divineStormSpellID or RET.divineStorm)
    end

    local artOfWarStacks = GetPlayerAuraStacksByName("Art of War")
    local artOfWarAuraUp = GetPlayerAuraRemainingByName("Art of War") > 0
    if artOfWarAuraUp and artOfWarStacks <= 0 then
        artOfWarStacks = 1
    end
    local bladeOfJusticeOverlay = IsSpellOverlayedSafe(bladeOfJusticeSpellID or RET.bladeOfJustice)
    local hammerOfWrathOverlay = IsSpellOverlayedSafe(hammerOfWrathSpellID or RET.hammerOfWrath)
    local lightDeliveranceStacks = math.max(
        GetPlayerAuraStacksByID(RET.lightsDeliveranceAura),
        GetPlayerAuraStacksByName("Light's Deliverance")
    )
    local avengingWrathRemaining = math.max(
        GetPlayerAuraRemainingByID(avengingWrathSpellID or RET.avengingWrath),
        GetPlayerAuraRemainingByID(RET.crusade),
        GetPlayerAuraRemainingByName("Avenging Wrath"),
        GetPlayerAuraRemainingByName("Crusade")
    )
    local hammerOfLightGlow, hammerOfLightGlowKnown = false, false
    if addon.HasActionButtonProcGlowForSpell then
        hammerOfLightGlow, hammerOfLightGlowKnown = addon:HasActionButtonProcGlowForSpell(hammerOfLightSpellID or RET.hammerOfLight)
    end

    return {
        profileType = "RETRIBUTION_PALADIN",
        activeSpecID = GetCurrentSpecID(),
        activeSpecName = addon:GetCurrentSpecName(),
        activeHeroTalentName = addon:GetRetributionHeroTalentName(),
        retributionBuildName = addon:GetRetributionBuildName(),
        hasTarget = HasHostileLivingTarget(),
        inCombat = inCombat,
        combatTime = combatTime,
        openerBladeOfJusticeDone = retOpenerBladeOfJusticeDone or not combatTime or combatTime > ((GetApproxGlobalCooldown() or 1.5) + 1.0),
        openerBladeOfJusticeCastAt = retOpenerBladeOfJusticeCastAt,
        isRetributionPaladin = true,
        isRetributionTemplar = addon:IsRetributionTemplar(),
        isRetributionHeraldOfTheSun = addon:IsRetributionHeraldOfTheSun(),
        targetCount = targetCount,
        detectedTargetCount = detectedTargetCount,
        visibleHostileTargetCount = visibleHostileTargetCount,
        recentDamageTargetCount = recentDamageTargetCount,
        targetCountOverride = targetCountOverride,
        targetCountSource = targetCountSource,
        isAOE = isAOE,
        isCleave = targetCount >= 2 and targetCount <= 3,
        isTwoTarget = targetCount == 2,
        isLargeAOE = targetCount > 3,
        targetHealthKnown = type(targetHealthPercent) == "number",
        targetHealthPercent = targetHealthPercent,
        executePhase = type(targetHealthPercent) == "number" and targetHealthPercent <= 0.20,
        gcd = GetApproxGlobalCooldown(),
        holyPowerKnown = holyPowerKnown,
        holyPower = holyPower,
        resourceName = "Holy Power",
        resourceKnown = holyPowerKnown,
        resource = holyPower,
        hasRadiantGlory = Engine.HasRadiantGlory(),
        hasCrusadingStrikes = Engine.HasCrusadingStrikes(),
        hasTwoTargetAOETalents = hasTwoTargetAOETalents,
        avengingWrathRemaining = avengingWrathRemaining,
        recentWakeOfAshesCast = retLastWakeOfAshesCastAt > 0 and (GetTime() - retLastWakeOfAshesCastAt) <= 20.0,
        recentHammerOfLightCast = retLastHammerOfLightCastAt > 0 and (GetTime() - retLastHammerOfLightCastAt) <= 20.0,
        executionSentenceRemaining = GetTargetDebuffRemaining(executionSentenceSpellID or RET.executionSentence, "Execution Sentence"),
        expurgationRemaining = GetTargetDebuffRemaining(RET.expurgationDebuff, "Expurgation"),
        judgmentRemaining = GetTargetDebuffRemaining(judgmentSpellID or RET.judgment, "Judgment"),
        bladeOfJusticeCharges = bladeOfJusticeCharges or 0,
        bladeOfJusticeChargesKnown = bladeOfJusticeChargesKnown,
        hammerOfWrathCharges = hammerOfWrathCharges or 0,
        hammerOfWrathChargesKnown = hammerOfWrathChargesKnown,
        artOfWarStacks = artOfWarStacks,
        artOfWarUp = artOfWarAuraUp
            or bladeOfJusticeOverlay
            or hammerOfWrathOverlay
            or bladeActionGlow
            or hammerActionGlow,
        artOfWarBladeUp = artOfWarAuraUp or bladeOfJusticeOverlay or bladeActionGlow or (bladeOfJusticeChargesKnown == true and (bladeOfJusticeCharges or 0) >= 2),
        artOfWarHammerUp = hammerOfWrathOverlay or hammerActionGlow,
        hammerOfWrathWindow = (type(targetHealthPercent) == "number" and targetHealthPercent <= 0.20)
            or avengingWrathRemaining > (GetApproxGlobalCooldown() or 1.0)
            or hammerOfWrathOverlay
            or hammerActionGlow,
        artOfWarBladeActionGlow = bladeActionGlow,
        artOfWarBladeActionGlowKnown = bladeActionGlowKnown,
        artOfWarHammerActionGlow = hammerActionGlow,
        artOfWarHammerActionGlowKnown = hammerActionGlowKnown,
        empyreanPowerUp = GetPlayerAuraRemainingByID(RET.empyreanPowerAura) > 0
            or GetPlayerAuraRemainingByName("Empyrean Power") > 0
            or IsSpellOverlayedSafe(divineStormSpellID or RET.divineStorm)
            or divineStormActionGlow,
        empyreanLegacyUp = GetPlayerAuraRemainingByName("Empyrean Legacy") > 0,
        divineArbiterUp = GetPlayerAuraRemainingByName("Divine Arbiter") > 0,
        empyreanPowerActionGlow = divineStormActionGlow,
        empyreanPowerActionGlowKnown = divineStormActionGlowKnown,
        divinePurposeUp = GetPlayerAuraRemainingByID(RET.divinePurposeAura) > 0
            or GetPlayerAuraRemainingByName("Divine Purpose") > 0,
        lightDeliveranceStacks = lightDeliveranceStacks,
        lightDeliveranceReady = lightDeliveranceStacks >= 50
            or GetPlayerAuraRemainingByName("Light's Deliverance") > 0
            or IsSpellOverlayedSafe(hammerOfLightSpellID or RET.hammerOfLight)
            or hammerOfLightGlow,
        hammerOfLightActionGlow = hammerOfLightGlow,
        hammerOfLightActionGlowKnown = hammerOfLightGlowKnown,
        avengingWrathCooldown = GetCooldownRemaining(avengingWrathSpellID),
        executionSentenceCooldown = GetCooldownRemaining(executionSentenceSpellID),
        wakeOfAshesCooldown = GetCooldownRemaining(wakeOfAshesSpellID),
        divineTollCooldown = GetCooldownRemaining(divineTollSpellID),
        spell = {
            avengingWrath = avengingWrathSpellID,
            executionSentence = executionSentenceSpellID,
            singleTargetSpender = singleTargetSpenderSpellID,
            divineStorm = divineStormSpellID,
            wakeOfAshes = wakeOfAshesSpellID,
            divineToll = divineTollSpellID,
            hammerOfLight = hammerOfLightSpellID,
            hammerOfWrath = hammerOfWrathSpellID,
            bladeOfJustice = bladeOfJusticeSpellID,
            judgment = judgmentSpellID,
            crusaderStrike = crusaderStrikeSpellID,
            templarStrike = templarStrikeSpellID,
            templarSlash = templarSlashSpellID,
        },
    }
end




function Engine.HasThunderBlastAtLeast(state, minimumCharges)
    if not state or not state.spell or not state.spell.thunderBlast then
        return false
    end

    if not Engine.CanUseEnemySpell(state.spell.thunderBlast) then
        return false
    end

    if (state.thunderBlastStacks or 0) >= (minimumCharges or 1) then
        return true
    end

    if state.thunderBlastChargesKnown == false then
        return minimumCharges <= 1
    end

    return (state.thunderBlastCharges or 0) >= (minimumCharges or 1)
end


function Engine.GetFuryHackAndSlashStrike(state)
    if not state or not state.hackAndSlashUp then
        return nil
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.crushingBlow) then
        return state.spell.crushingBlow
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlow) then
        return state.spell.ragingBlow
    end

    return nil
end

function Engine.GetFuryBloodbathLikeRecommendation(state)
    if not state or not state.spell then
        return nil
    end

    if Engine.CanUseEnemySpell(state.spell.bloodbath) then
        return state.spell.bloodbath
    end

    -- Bloodbath is a temporary Bloodthirst replacement during Recklessness.
    -- Prefer the resolved replacement button, then fall back to base Bloodthirst.
    local bloodthirstFallback = state.spell.bloodthirstLike or state.spell.bloodthirst or BLOODTHIRST_SPELL_ID
    if state.recklessnessUp == true and Engine.CanUseEnemySpell(bloodthirstFallback) then
        return {
            type = "spell",
            spellID = bloodthirstFallback,
            name = "Bloodbath",
        }
    end

    return nil
end

function Engine.RecommendFuryBloodbathDuringRecklessness(state)
    if not state or state.recklessnessUp ~= true then
        return nil
    end

    return Engine.GetFuryBloodbathLikeRecommendation(state)
end

function Engine.ShouldUseMountainThaneThunderBlastHigh(state)
    if not state or not state.spell then
        return false
    end

    return Engine.HasThunderBlastAtLeast(state, 2)
        or ((state.thunderBlastRemaining or 0) > 0 and (state.thunderBlastRemaining or 0) <= 2.0 and Engine.CanUseEnemySpell(state.spell.thunderBlast))
        or (state.avatarUp == true and (state.avatarRemaining or 0) <= 2.0 and Engine.CanUseEnemySpell(state.spell.thunderBlast))
end

function Engine.NeedsWhirlwindBuff(state)
    return state.isAOE
        and state.hasImprovedWhirlwind
        and state.whirlwindStacks <= 0
        and Engine.CanUseEnemySpell(state.spell.whirlwind)
end




function Engine.CanRecommendFuryOdynsFury(state)
    return state
        and state.hasOdynsFury == true
        and state.spell
        and Engine.CanRecommendEnemySpell(state.spell.odynsFury)
end

function Engine.CanRecommendWarriorAvatar(state)
    return state
        and state.hasAvatar == true
        and Engine.CanRecommendSelfSpell(AVATAR_SPELL_ID)
end

function Engine.CanUseWarriorAvatar(state)
    return state
        and state.hasAvatar == true
        and Engine.CanUseSelfSpell(AVATAR_SPELL_ID)
end

function Engine.CanRecommendWarriorBladestorm(state)
    return state
        and state.hasBladestorm == true
        and state.spell
        and Engine.ShouldRecommendMajorCooldowns()
        and HasHostileLivingTarget()
        and Engine.CanRecommendSelfSpell(state.spell.bladestorm)
end



function Engine.GetModeLabel(state)
    if not state then
        return nil
    end

    if state.isLargeAOE == true then
        return "AOE"
    end
    if state.isCleave == true then
        return "CLEAVE"
    end
    return "ST"
end


local ARMS_REND_REFRESH_WINDOW = 4.0
local ARMS_COOLDOWN_SYNC_WINDOW = 3.0 -- 0.4.1: was 10.0; tightened once cast-based cooldown estimates made it reachable in combat
local ARMS_SLAYER_COOLDOWN_SYNC_WINDOW = 2.5
local ARMS_COMBAT_OPENER_WINDOW = 8.0

function Engine.IsArmsColossusSmashUp(state)
    return (state.colossusSmashRemaining or 0) > 0
        or state.recentColossusSmashCast == true
end

function Engine.IsArmsColossusReadySoon(colossusCooldown, state, window)
    local cooldown = tonumber(colossusCooldown) or math.huge
    return cooldown <= (window or state.gcd or 1.5)
end

function Engine.IsArmsSweepingStrikesDown()
    return GetPlayerAuraRemainingByID(SWEEPING_STRIKES_SPELL_ID) <= 0
end

function addon:ShouldUseArmsSweepingStrikes(state)
    return state.isAOE
        and Engine.CanUseSelfSpell(SWEEPING_STRIKES_SPELL_ID)
        and Engine.IsArmsSweepingStrikesDown()
end

function addon:HasArmsSuddenDeathStacks(state, minimumStacks)
    if not addon:HasReliableArmsSuddenDeathProc(state) then
        return false
    end

    local stacks = state.suddenDeathStacks or 0
    if stacks <= 0 then
        return (minimumStacks or 1) <= 1
    end

    return stacks >= (minimumStacks or 1)
end

function addon:ShouldSpendArmsSuddenDeathCapped(state)
    return addon:HasArmsSuddenDeathStacks(state, 2)
        and Engine.CanUseExecuteSpell(state)
end

function addon:ShouldSpendArmsSuddenDeath(state)
    return addon:HasArmsSuddenDeathStacks(state, 1)
        and Engine.CanUseExecuteSpell(state)
end

function addon:ShouldSpendArmsSlayerExecutioner(state, minimumStacks)
    return state
        and state.isArmsSlayer == true
        and (state.executionerStacks or 0) >= (minimumStacks or 4)
        and Engine.CanUseExecuteSpell(state)
end

function addon:HasReliableArmsSuddenDeathProc(state)
    return state
        and (
            state.suddenDeathAuraByID == true
            or state.suddenDeathAuraByAltID == true
            or state.suddenDeathAuraByName == true
            or state.suddenDeathOverlayByExecute == true
            or state.suddenDeathOverlayByBaseExecute == true
            or state.suddenDeathOverlayByFuryExecute == true
            or state.suddenDeathActionCountSignal == true
            or addon:HasAssistedArmsSuddenDeathSignal(state)
        )
end

-- With target health readable and outside execute range, Arms can only use
-- Execute through Sudden Death, so Blizzard suggesting Execute confirms a proc.
-- With health hidden the suggestion cannot separate a proc from execute range,
-- so it is ignored there.
function addon:HasAssistedArmsSuddenDeathSignal(state)
    return state ~= nil
        and state.assistedSuggestion ~= nil
        and state.targetHealthKnown == true
        and state.executePhase ~= true
        and state.executeStrictUsable == true
        and Engine.SpellIDsMatch(state.assistedSuggestion, (state.spell and state.spell.execute) or EXECUTE_SPELL_ID)
end

function addon:HasArmsOverpowerCharges(state, minimumCharges)
    return state.overpowerChargesKnown == true
        and (state.overpowerCharges or 0) >= (minimumCharges or 1)
end

function addon:ShouldUseArmsOpportunistOverpower(state, minimumStacks)
    local requiredStacks = minimumStacks or 2
    return state
        and (
            (state.opportunistStacks or 0) >= requiredStacks
            or (requiredStacks <= 2 and state.opportunistUp == true)
        )
        and Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID)
end


function addon:CanUseArmsExecuteAtRage(state, rageThreshold)
    if not Engine.CanUseExecuteSpell(state) then
        return false
    end

    if addon:HasReliableArmsSuddenDeathProc(state) then
        return true
    end

    if state.rageKnown ~= true then
        -- Rage is hidden. Use the usability-derived band where it is decisive:
        -- a spell costing <= threshold that is short on rage proves we are
        -- below the threshold; a usable spell costing >= threshold proves we
        -- are above it. Otherwise fall back to plain Execute usability.
        local threshold = rageThreshold or 75
        if state.rageBandHigh and state.rageBandHigh <= threshold then
            return false
        end

        if state.rageBandLow and state.rageBandLow >= threshold then
            return true
        end

        if type(state.rageEstimate) == "number" then
            return state.rageEstimate >= threshold
        end

        return state.executeStrictUsable == true
    end

    return (state.rage or 0) >= (rageThreshold or 75)
end



function addon:CanUseArmsRavagerBeforeColossus(state, colossusCooldown)
    return Engine.CanRecommendEnemySpell(state.spell.ravager)
        and Engine.IsArmsColossusReadySoon(colossusCooldown, state, 2.0)
end







-- Method Warrior priorities for Midnight Season 2. These override the older
-- experimental Warrior branches above so all Warrior profiles follow Method's
-- listed order exactly where the guide gives a concrete priority.
















-- Fury priority based on Wowhead's Slayer ST/AoE rotation text. This separates
-- cooldown windows, restores Odyn's Fury, uses Whirlwind to maintain AoE cleave,
-- and keeps Execute in both Sudden Death and execute-range slots.
function Engine.IsFuryCooldownWindow(state)
    return state and (state.recklessnessUp == true or state.avatarUp == true)
end

-- 0.5.9: the #1 Ula'tek Mythic Fury log (Archon/Warcraft Logs, 9:50 kill)
-- cast 12 Recklessness and 12 Bladestorm, every Bladestorm 1-14s after a
-- Recklessness and never before one. Hold Bladestorm for Recklessness unless
-- cooldown recommendations are off, Recklessness is unknown, or it is overdue.
function Engine.ShouldHoldFuryBladestormForRecklessness(state)
    if not state or Engine.IsFuryCooldownWindow(state) then
        return false
    end

    if not Engine.ShouldRecommendMajorCooldowns() or not IsSpellKnownInBook(RECKLESSNESS_SPELL_ID) then
        return false
    end

    if furyLastRecklessnessCastAt <= 0 then
        -- Recklessness not used yet this fight: it is next anyway.
        return Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID)
    end

    return (GetTime() - furyLastRecklessnessCastAt) <= 55
end

function Engine.ShouldFuryDelayBladestormForCooldowns(state)
    if not state or Engine.IsFuryCooldownWindow(state) then
        return false
    end

    -- 0.5.8: Recklessness' real cooldown is hidden and shortened by rage
    -- spent; top logs and the 2026-10-31 trace show it returning 40-46s after
    -- the previous cast. Hold Bladestorm / Odyn's Fury in that band so they
    -- land 1-2 GCDs after Recklessness, as top players do.
    if furyLastRecklessnessCastAt > 0 and Engine.ShouldRecommendMajorCooldowns() then
        local sinceReck = GetTime() - furyLastRecklessnessCastAt
        if sinceReck >= 36 and sinceReck <= 48 then
            return true
        end
    end

    local syncWindow = math.max(3.0, (state.gcd or 1.5) + 1.0)
    if Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID) or (state.recklessnessCooldown or math.huge) <= syncWindow then
        return true
    end

    if state.hasAvatar == true and (Engine.CanRecommendWarriorAvatar(state) or (state.avatarCooldown or math.huge) <= syncWindow) then
        return true
    end

    return false
end

function Engine.ShouldFuryUseSuddenDeathExecute(state)
    return state
        and state.suddenDeathUp == true
        and Engine.CanUseExecuteSpell(state)
end

function Engine.ShouldFuryRampageAtHighRage(state, threshold)
    if not state or not Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
        return false
    end

    if state.rageKnown == true then
        return (state.rage or 0) >= (threshold or 100)
    end

    -- 0.5.3: running rage estimate (RageModel.lua), anchored to exact rage
    -- costs whenever a spender's "not enough rage" flag flips.
    if type(state.rageEstimate) == "number" then
        return state.rageEstimate >= (threshold or 100)
    end

    -- Rage is hidden in combat. Rampage turns usable at 80 rage, so treat the
    -- player as at/above 100 once a rage generator has been cast since that
    -- moment, or once Rampage has sat usable for a while (auto-attacks alone
    -- add ~20 rage within ~1.5s, faster during Recklessness).
    if (state.furyGeneratorsSinceRampageUsable or 0) >= 1 then
        return true
    end

    local usableFor = state.furyRampageUsableFor or 0
    local waitSeconds = Engine.IsFuryCooldownWindow(state) and 0.75 or 1.5
    if usableFor >= waitSeconds then
        return true
    end

    -- Older fallback kept for safety.
    return state.recklessnessUp == true and (state.furyGeneratorCastsSinceRampage or 0) >= 2
end

function Engine.ShouldFuryRampageBeforeBladestorm(state)
    return Engine.CanRecommendWarriorBladestorm(state)
        and state.recentRampageCast ~= true
        and Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID)
end

function Engine.RecommendFurySlayerBladestormSequence(state, allowRampagePrep)
    if not Engine.CanRecommendWarriorBladestorm(state) or Engine.ShouldFuryDelayBladestormForCooldowns(state) then
        return nil
    end

    if allowRampagePrep == true and Engine.ShouldFuryRampageBeforeBladestorm(state) then
        return RAMPAGE_SPELL_ID
    end

    return state.spell.bladestorm
end
function Engine.RecommendFuryOpener(state, includeBladestorm)
    if not state or state.isFury ~= true then
        return nil, false
    end

    if state.inCombat ~= true then
        if Engine.CanRecommendEnemySpell(state.spell and state.spell.charge or CHARGE_SPELL_ID) then
            return state.spell and state.spell.charge or CHARGE_SPELL_ID, true
        end

        return nil, true
    end

    local combatTime = state.combatTime
    if type(combatTime) ~= "number" or combatTime > 8.0 then
        return nil, false
    end

    -- Bloodthirst is the first in-combat action after Charge. Its successful
    -- cast event advances the opener before cooldowns are recommended.
    local bloodthirstSpellID = state.spell and (state.spell.bloodthirst or state.spell.bloodthirstLike)
    if state.openerBloodthirstDone ~= true and Engine.CanUseEnemySpell(bloodthirstSpellID) then
        return bloodthirstSpellID, true
    end

    if Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID) then
        return RECKLESSNESS_SPELL_ID, true
    end

    if Engine.CanRecommendWarriorAvatar(state) then
        return AVATAR_SPELL_ID, true
    end

    if state.recentRampageCast ~= true and Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
        return RAMPAGE_SPELL_ID, true
    end

    if includeBladestorm == true and Engine.CanRecommendWarriorBladestorm(state) then
        return state.spell.bladestorm, true
    end

    return nil, false
end

-- Fury Slayer single target, rebuilt from top raid logs (Archon 12.1.5:
-- Vashnik Mythic 11 parses, Ula'tek Mythic 9 and Heroic 13). Top players spend
-- Rampage every time it is usable, alternate Rampage / Crushing Blow inside the
-- 24s Recklessness window, and use Bladestorm and Odyn's Fury on cooldown
-- (Bladestorm ~1-2 GCDs into Recklessness, Odyn's Fury shortly after).
function Engine.RecommendFurySlayerSingleTarget(state)
    local inWindow = Engine.IsFuryCooldownWindow(state)

    if not inWindow then
        if Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID) then
            return RECKLESSNESS_SPELL_ID
        end

        if Engine.CanRecommendWarriorAvatar(state) then
            return AVATAR_SPELL_ID
        end
    elseif state.avatarUp ~= true and Engine.CanRecommendWarriorAvatar(state) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
        return RAMPAGE_SPELL_ID
    end

    -- 0.6.2 (WoWAnalyzer): Execute with Sudden Death or in execute range goes
    -- ahead of Bladestorm, Odyn's Fury and Crushing Blow, above all inside
    -- Recklessness where Crushing Blow was starving it.
    if Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    -- Bladestorm and Odyn's Fury on cooldown; outside Recklessness, hold them
    -- briefly only if Recklessness is about to come back.
    local burstSlot = inWindow or not Engine.ShouldFuryDelayBladestormForCooldowns(state)

    if Engine.CanRecommendWarriorBladestorm(state) and not Engine.ShouldHoldFuryBladestormForRecklessness(state) then
        return state.spell.bladestorm
    end

    if burstSlot and Engine.CanRecommendFuryOdynsFury(state) then
        return state.spell.odynsFury
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.crushingBlow) then
        return state.spell.crushingBlow
    end

    if Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlow) then
        return state.spell.ragingBlow
    end

    local bloodbathRecommendation = Engine.GetFuryBloodbathLikeRecommendation(state)
    if bloodbathRecommendation then
        return bloodbathRecommendation
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.bloodthirst) then
        return state.spell.bloodthirst
    end

    -- 0.6.3: no Whirlwind filler on a single target (Slayer ST logs do not
    -- use it; Whirlwind is only for the cleave buff in AoE).

    return nil
end

-- 0.5.6 Fury Slayer AoE, rebuilt from top Mythic+ logs (Archon, Murder Row
-- high keys, 16 runs, 88% Slayer, 12.1.5): keep the Improved Whirlwind buff
-- up (Whirlwind every ~3-4 casts), spend Rampage whenever usable (often twice
-- in a row), Odyn's Fury then Bladestorm on cooldown, then Crushing Blow /
-- Execute / Raging Blow / Bloodbath / Bloodthirst.
function Engine.RecommendFurySlayerAOE(state)
    local inWindow = Engine.IsFuryCooldownWindow(state)

    if Engine.NeedsWhirlwindBuff(state) then
        return state.spell.whirlwind
    end

    if not inWindow then
        if Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID) then
            return RECKLESSNESS_SPELL_ID
        end

        if Engine.CanRecommendWarriorAvatar(state) then
            return AVATAR_SPELL_ID
        end
    elseif state.avatarUp ~= true and Engine.CanRecommendWarriorAvatar(state) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
        return RAMPAGE_SPELL_ID
    end

    local burstSlot = inWindow or not Engine.ShouldFuryDelayBladestormForCooldowns(state)
    if burstSlot and Engine.CanRecommendFuryOdynsFury(state) then
        return state.spell.odynsFury
    end

    if Engine.CanRecommendWarriorBladestorm(state) and not Engine.ShouldHoldFuryBladestormForRecklessness(state) then
        return state.spell.bladestorm
    end

    if Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.crushingBlow) then
        return state.spell.crushingBlow
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlow) then
        return state.spell.ragingBlow
    end

    local bloodbathRecommendation = Engine.GetFuryBloodbathLikeRecommendation(state)
    if bloodbathRecommendation then
        return bloodbathRecommendation
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.bloodthirst) then
        return state.spell.bloodthirst
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.whirlwind) then
        return state.spell.whirlwind
    end

    return nil
end
-- 0.5.5 Slayer opener from top raid logs (Archon, Ula'tek Heroic 13 parses and
-- Mythic 9 parses, 12.1.5): Charge, Recklessness within the first GCD, then the
-- normal priority (Rampage if usable > Bladestorm > Odyn's Fury > ...).
-- Vashnik's later Recklessness (7-11s) was fight-specific (adds).
-- Mountain Thane keeps the older shared opener.
function Engine.RecommendFurySlayerOpener(state)
    if not state or state.isFury ~= true then
        return nil, false
    end

    if state.inCombat ~= true then
        if Engine.CanRecommendEnemySpell(state.spell and state.spell.charge or CHARGE_SPELL_ID) then
            return state.spell and state.spell.charge or CHARGE_SPELL_ID, true
        end
        return nil, true
    end

    local combatTime = state.combatTime
    if type(combatTime) ~= "number" or combatTime > 8.0 then
        return nil, false
    end

    if state.isAOE and Engine.NeedsWhirlwindBuff(state) then
        return state.spell.whirlwind, true
    end

    -- Mythic+ pulls (Archon, Murder Row high keys): Whirlwind buff, Raging
    -- Blow / Bloodthirst into the first Rampage, then Recklessness.
    if state.isAOE and state.rampageCastThisCombat ~= true then
        if Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
            return RAMPAGE_SPELL_ID, true
        end
        if Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlow) then
            return state.spell.ragingBlow, true
        end
        local bloodthirstSpellID = state.spell and (state.spell.bloodthirst or state.spell.bloodthirstLike)
        if Engine.CanUseEnemySpell(bloodthirstSpellID) then
            return bloodthirstSpellID, true
        end
    end

    if Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID) then
        return RECKLESSNESS_SPELL_ID, true
    end

    if Engine.CanRecommendWarriorAvatar(state) then
        return AVATAR_SPELL_ID, true
    end

    return nil, false
end

function Engine.RecommendFurySlayer(state)
    local openerSpellID, openerHandled = Engine.RecommendFurySlayerOpener(state)
    if openerHandled then
        return openerSpellID
    end

    if state.isAOE then
        return Engine.RecommendFurySlayerAOE(state)
    end

    return Engine.RecommendFurySlayerSingleTarget(state)
end

function Engine.NeedsFuryCleaveBuff(state)
    return state
        and state.isAOE == true
        and state.hasImprovedWhirlwind == true
        and (state.whirlwindStacks or 0) <= 0
end

function Engine.ShouldFuryRampageToRefreshEnrage(state)
    if not state or not Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
        return false
    end

    local enrageRemaining = state.enrageRemaining or 0
    if enrageRemaining <= 0 then
        return state.recentRampageCast ~= true
    end

    return enrageRemaining <= (state.gcd or 1.5)
end

function Engine.ShouldFuryRampageHighOrExpiring(state)
    return Engine.ShouldFuryRampageAtHighRage(state, 100)
        or Engine.ShouldFuryRampageToRefreshEnrage(state)
end

function Engine.RecommendFuryMountainThaneSingleTarget(state)
    if Engine.IsFuryCooldownWindow(state) then
        if state.avatarUp ~= true and Engine.CanRecommendWarriorAvatar(state) then
            return AVATAR_SPELL_ID
        end

        if Engine.ShouldFuryRampageHighOrExpiring(state) then
            return RAMPAGE_SPELL_ID
        end

        if Engine.ShouldUseMountainThaneThunderBlastHigh(state) then
            return state.spell.thunderBlast
        end

        local bloodbathRecommendation = Engine.RecommendFuryBloodbathDuringRecklessness(state)
        if bloodbathRecommendation then
            return bloodbathRecommendation
        end

        local hackAndSlashSpellID = Engine.GetFuryHackAndSlashStrike(state)
        if hackAndSlashSpellID then
            return hackAndSlashSpellID
        end

        if Engine.CanUseEnemySpell(state.spell and state.spell.bloodbath) then
            return state.spell.bloodbath
        end

        if state.recklessnessUp == true and Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
            return RAMPAGE_SPELL_ID
        end

        if state.avatarUp == true and Engine.CanUseEnemySpell(state.spell and state.spell.thunderBlast) then
            return state.spell.thunderBlast
        end

        if Engine.CanRecommendFuryOdynsFury(state) then
            return state.spell.odynsFury
        end

        if Engine.CanUseEnemySpell(state.spell and state.spell.crushingBlow) then
            return state.spell.crushingBlow
        end

        if Engine.CanUseEnemySpell(state.spell and state.spell.thunderBlast) then
            return state.spell.thunderBlast
        end

        if Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
            return RAMPAGE_SPELL_ID
        end

        if Engine.CanUseEnemySpell(state.spell and state.spell.bloodthirstLike) then
            return state.spell.bloodthirstLike
        end

        if Engine.CanUseExecuteSpell(state) then
            return state.spell.execute
        end

        if Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlowLike) then
            return state.spell.ragingBlowLike
        end

        if Engine.CanUseEnemySpell(THUNDER_CLAP_SPELL_ID) then
            return THUNDER_CLAP_SPELL_ID
        end

        return nil
    end

    -- The Thane opener uses Odyn's Fury before Recklessness/Avatar so the
    -- already busy cooldown window is not delayed by another long GCD.
    if (state.combatTime or math.huge) <= 8.0 and Engine.CanRecommendFuryOdynsFury(state) then
        return state.spell.odynsFury
    end

    if Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID) then
        return RECKLESSNESS_SPELL_ID
    end

    if Engine.CanRecommendWarriorAvatar(state) then
        return AVATAR_SPELL_ID
    end

    if Engine.ShouldFuryRampageHighOrExpiring(state) then
        return RAMPAGE_SPELL_ID
    end

    if Engine.ShouldUseMountainThaneThunderBlastHigh(state) then
        return state.spell.thunderBlast
    end

    local hackAndSlashSpellID = Engine.GetFuryHackAndSlashStrike(state)
    if hackAndSlashSpellID then
        return hackAndSlashSpellID
    end

    if Engine.CanRecommendFuryOdynsFury(state) then
        return state.spell.odynsFury
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.thunderBlast) then
        return state.spell.thunderBlast
    end

    if Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
        return RAMPAGE_SPELL_ID
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.bloodthirstLike) then
        return state.spell.bloodthirstLike
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlowLike) then
        return state.spell.ragingBlowLike
    end

    if Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(THUNDER_CLAP_SPELL_ID) then
        return THUNDER_CLAP_SPELL_ID
    end


    return nil
end

-- 0.5.7 Fury Mountain Thane AoE, rebuilt from top Mythic+ logs (Archon, Ruby
-- Life Pools high keys, 17 runs, 65% Mountain Thane, 12.1.5): Thunder Clap
-- keeps the cleave buff, Bloodthirst before Raging Blow while building, first
-- Rampage before Odyn's Fury -> Recklessness, then a burst loop of Rampage
-- (whenever usable) / Thunder Blast / Bloodbath / Crushing Blow.
function Engine.RecommendFuryMountainThaneAOE(state)
    local inWindow = Engine.IsFuryCooldownWindow(state)
    local thunderClapSpellID = THUNDER_CLAP_SPELL_ID

    if Engine.NeedsFuryCleaveBuff(state) and Engine.CanUseEnemySpell(thunderClapSpellID) then
        return thunderClapSpellID
    end

    -- Pull start: build into the first Rampage before spending cooldowns.
    local pullStart = (state.combatTime or math.huge) <= 12.0 and state.rampageCastThisCombat ~= true
    if pullStart then
        if Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
            return RAMPAGE_SPELL_ID
        end
        if Engine.CanUseEnemySpell(state.spell and state.spell.bloodthirstLike) then
            return state.spell.bloodthirstLike
        end
        if Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlowLike) then
            return state.spell.ragingBlowLike
        end
    end

    if not inWindow then
        -- Odyn's Fury goes out just before Recklessness.
        if Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID) and Engine.CanRecommendFuryOdynsFury(state) then
            return state.spell.odynsFury
        end

        if Engine.CanRecommendSelfSpell(RECKLESSNESS_SPELL_ID) then
            return RECKLESSNESS_SPELL_ID
        end

        if Engine.CanRecommendWarriorAvatar(state) then
            return AVATAR_SPELL_ID
        end
    elseif state.avatarUp ~= true and Engine.CanRecommendWarriorAvatar(state) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID) then
        return RAMPAGE_SPELL_ID
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.thunderBlast) then
        return state.spell.thunderBlast
    end

    if inWindow then
        if Engine.CanUseEnemySpell(state.spell and state.spell.bloodbath) then
            return state.spell.bloodbath
        end

        if Engine.CanUseEnemySpell(state.spell and state.spell.crushingBlow) then
            return state.spell.crushingBlow
        end
    end

    if Engine.CanRecommendFuryOdynsFury(state) and not Engine.ShouldFuryDelayBladestormForCooldowns(state) then
        return state.spell.odynsFury
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.bloodthirstLike) then
        return state.spell.bloodthirstLike
    end

    if Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlowLike) then
        return state.spell.ragingBlowLike
    end

    if Engine.CanUseEnemySpell(thunderClapSpellID) then
        return thunderClapSpellID
    end

    return nil
end
function Engine.RecommendFuryMountainThane(state)
    if state.isAOE and state.inCombat == true then
        return Engine.RecommendFuryMountainThaneAOE(state)
    end

    local openerSpellID, openerHandled = Engine.RecommendFuryOpener(state, true)
    if openerHandled then
        return openerSpellID
    end

    if state.isAOE then
        return Engine.RecommendFuryMountainThaneAOE(state)
    end

    return Engine.RecommendFuryMountainThaneSingleTarget(state)
end

-- Arms priority based on Wowhead's Midnight 12.1 Arms rotation page.
function addon:IsArmsColossusReady(state, colossusCooldown)
    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return true
    end

    return Engine.IsArmsColossusReadySoon(colossusCooldown, state, state.gcd or 1.5)
end

function addon:CanUseArmsWowheadAvatar(state, colossusCooldown)
    return Engine.CanRecommendWarriorAvatar(state)
        and (
            Engine.IsArmsColossusSmashUp(state)
            or addon:IsArmsColossusReady(state, colossusCooldown)
            or (tonumber(colossusCooldown) or math.huge) <= ARMS_COOLDOWN_SYNC_WINDOW
        )
end

function addon:RecommendArmsWowheadCleaveRefresh(state, maxRemaining, requireColossusReady, colossusCooldown)
    if not state or state.hasCleave ~= true or (state.rendRemaining or 0) > (maxRemaining or ARMS_REND_REFRESH_WINDOW) then
        return nil
    end

    if requireColossusReady == true and not addon:IsArmsColossusReady(state, colossusCooldown) then
        return nil
    end

    if Engine.CanUseEnemySpell(CLEAVE_SPELL_ID) then
        return CLEAVE_SPELL_ID
    end

    return nil
end

function addon:RecommendArmsWowheadRendRefresh(state, maxRemaining, requireColossusReady, colossusCooldown)
    if not state or state.hasRend ~= true or (state.rendRemaining or 0) > (maxRemaining or ARMS_REND_REFRESH_WINDOW) then
        return nil
    end

    if requireColossusReady == true and not addon:IsArmsColossusReady(state, colossusCooldown) then
        return nil
    end

    if state.hasCleave == true and Engine.CanUseEnemySpell(CLEAVE_SPELL_ID) then
        return CLEAVE_SPELL_ID
    end

    return nil
end

function addon:CanUseArmsWowheadHeroicStrike(state)
    return addon:GetArmsWowheadHeroicStrikeRecommendation(state) ~= nil
end

function addon:HasArmsHeroicStrikeProcSignal(state)
    return state
        and state.masterOfWarfareUp == true
        and (
            state.heroicStrikeButtonGlow == true
            or state.heroicStrikeActionCountSignal == true
            or state.heroicStrikeOverrideButtonGlow == true
            or state.heroicStrikeOverrideActionCountSignal == true
            or state.slamButtonGlow == true
            or state.slamActionCountSignal == true
            or IsSpellOverlayedSafe(state.spell and state.spell.heroicStrike)
            or IsSpellOverlayedSafe(HEROIC_STRIKE_ACTIONBAR_SPELL_ID)
            or IsSpellOverlayedSafe(SLAM_SPELL_ID)
        )
end

local function CanUseArmsHeroicStrikeSpell(spellID)
    if Engine.IsBlacklistedRecommendation(spellID)
    or not HasHostileLivingTarget()
    or not IsSpellReady(spellID, true)
    then
        return false
    end

    local inRange = IsSpellInRangeForUnit(spellID, "target")
        or IsSpellInRangeForUnit(SLAM_SPELL_ID, "target")
        or IsSpellInRangeForUnit(MORTAL_STRIKE_SPELL_ID, "target")
    if not inRange then
        return false
    end

    if C_Spell and C_Spell.IsSpellUsable then
        local ok, isUsable, notEnoughResource = pcall(C_Spell.IsSpellUsable, spellID)
        return ok and isUsable == true and notEnoughResource ~= true
    end

    if IsUsableSpell then
        local ok, isUsable, notEnoughResource = pcall(IsUsableSpell, spellID)
        return ok and isUsable == true and notEnoughResource ~= true
    end

    return false
end

function addon:GetArmsWowheadHeroicStrikeRecommendation(state)
    if not state or not state.spell then
        return nil
    end

    if CanUseArmsHeroicStrikeSpell(state.spell.heroicStrike) then
        return state.spell.heroicStrike
    end

    if CanUseArmsHeroicStrikeSpell(HEROIC_STRIKE_ACTIONBAR_SPELL_ID) then
        return {
            type = "spell",
            spellID = HEROIC_STRIKE_ACTIONBAR_SPELL_ID,
            keybindSpellID = SLAM_SPELL_ID,
            iconSpellID = state.spell.heroicStrike or HEROIC_STRIKE_SPELL_ID,
            name = "Heroic Strike",
        }
    end

    if addon:HasArmsHeroicStrikeProcSignal(state) and Engine.CanUseEnemySpell(SLAM_SPELL_ID) then
        return {
            type = "spell",
            spellID = SLAM_SPELL_ID,
            keybindSpellID = SLAM_SPELL_ID,
            iconSpellID = state.spell.heroicStrike or SLAM_SPELL_ID,
            name = "Heroic Strike",
        }
    end

    return nil
end

function addon:RecommendArmsWowheadOpener(state)
    if not state or state.isArms ~= true or state.inCombat == true then
        return nil
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.charge or CHARGE_SPELL_ID) then
        return state.spell and state.spell.charge or CHARGE_SPELL_ID
    end

    return nil
end

function addon:RecommendArmsWowheadCombatOpener(state, colossusCooldown, colossusUp)
    if not state
    or state.isArms ~= true
    or state.inCombat ~= true
    or type(state.combatTime) ~= "number"
    or state.combatTime > ARMS_COMBAT_OPENER_WINDOW
    then
        return nil
    end

    -- Slayer AoE already follows the guide's opener order in its regular
    -- priority: Sweeping Strikes, early Cleave, Avatar, Colossus Smash.
    if state.isAOE == true and state.isArmsSlayer == true then
        return nil
    end

    if state.isAOE ~= true then
        -- The top Mythic Vashnik reference opens with Cleave/Rend setup, then
        -- Colossus Smash, Avatar, a conditional Execute, and Bladestorm. Keep
        -- Cleave eligible for the full opener window because it can be briefly
        -- unavailable during Charge's opening GCD.
        -- Once Colossus Smash is down, the top log goes straight to Execute /
        -- Bladestorm rather than refreshing Cleave.
        if colossusUp then
            local earlyPostColossus = addon:RecommendArmsSlayerPostColossus(state, colossusUp)
            if earlyPostColossus then
                return earlyPostColossus
            end
        end

        local cleaveSetupSpellID = addon:RecommendArmsWowheadCleaveRefresh(state, 10.0, false, colossusCooldown)
            or addon:RecommendArmsWowheadRendRefresh(state, 10.0, false, colossusCooldown)
        if cleaveSetupSpellID then
            return cleaveSetupSpellID
        end

        -- 0.6.0 opener from the #1 Ula'tek Mythic Arms log: Charge, Cleave,
        -- Overpower, Avatar, Colossus Smash, Execute, Bladestorm.
        local overpowerThisCombat = combatStartedAt ~= nil and armsLastOverpowerCastAt >= combatStartedAt
        if not overpowerThisCombat
        and not colossusUp
        and Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID)
        and (addon:CanUseArmsWowheadAvatar(state, colossusCooldown)
            or Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike))
        then
            return OVERPOWER_SPELL_ID
        end

        if addon:CanUseArmsWowheadAvatar(state, colossusCooldown) then
            return AVATAR_SPELL_ID
        end

        if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
            return state.spell.warbreakerLike
        end

        local postColossus = addon:RecommendArmsSlayerPostColossus(state, colossusUp)
        if postColossus then
            return postColossus
        end

        if addon:ShouldSpendArmsSuddenDeathCapped(state) then
            return state.spell.execute
        end

        -- The opener helper returns before the regular Slayer priority, so it
        -- needs the capped Executioner's Precision rule as well.
        if (state.executionersPrecisionStacks or 0) >= 2
        and Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID)
        then
            return MORTAL_STRIKE_SPELL_ID
        end

        if (state.imminentDemiseStacks or 0) < 3
        and Engine.CanRecommendWarriorBladestorm(state)
        and Engine.CanUseExecuteSpell(state)
        and (
            state.executePhase == true
            or addon:ShouldSpendArmsSuddenDeath(state)
            or addon:ShouldSpendArmsSlayerExecutioner(state, 4)
        )
        then
            return state.spell.execute
        end

        if colossusUp and Engine.CanRecommendWarriorBladestorm(state) then
            return state.spell.bladestorm
        end

        return nil
    end

    if addon:CanUseArmsRavagerBeforeColossus(state, colossusCooldown) then
        return state.spell.ravager
    end

    if addon:CanUseArmsWowheadAvatar(state, colossusCooldown) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return state.spell.warbreakerLike
    end

    if colossusUp and Engine.CanRecommendWarriorBladestorm(state) then
        return state.spell.bladestorm
    end

    return nil
end
function addon:RecommendArmsWowheadCooldowns(state, colossusCooldown, colossusUp, includeBladestorm)
    if addon:CanUseArmsWowheadAvatar(state, colossusCooldown) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return state.spell.warbreakerLike
    end

    if includeBladestorm ~= false and colossusUp and Engine.CanRecommendWarriorBladestorm(state) then
        return state.spell.bladestorm
    end

    return nil
end

-- 0.6.0: the #1 Ula'tek Mythic Arms log used 16 Bladestorms in 10 minutes,
-- right after Colossus Smash when both were ready but otherwise on cooldown
-- (several went out 6-7s before the next Colossus Smash).
function addon:ShouldUseArmsSlayerBladestorm(state, colossusCooldown, colossusUp)
    return state ~= nil and Engine.CanRecommendWarriorBladestorm(state)
end

-- Colossus Smash -> (proc Execute) -> Bladestorm, as in the top log.
function addon:RecommendArmsSlayerPostColossus(state, colossusUp)
    if not colossusUp or not Engine.CanRecommendWarriorBladestorm(state) then
        return nil
    end

    if state.recentColossusSmashCast == true and Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    return state.spell.bladestorm
end

-- 0.6.0: the #1 Ula'tek Mythic Arms log casts nothing during Bladestorm (no
-- Storm Bolt all fight, Wrecking Throw only on adds), and Slayer's Bladestorm
-- triggers its own Mortal Strikes. Recommend nothing while it channels.
function addon:RecommendArmsBladestormChannelUtility(state)
    return nil
end

function addon:RecommendArmsWowheadSlayerSingleTarget(state, colossusCooldown, colossusUp)
    -- 0.4.1: aligned with Method's Midnight 12.1.5 general priority:
    -- Rend > Avatar > Colossus Smash > Execute (2 Sudden Death) > Heroic Strike
    -- > Mortal Strike > Execute (1 Sudden Death) > Overpower > Slam.
    -- Cleave remains the only Rend application (user rule since 0.1.166).
    local cleaveSpellID = addon:RecommendArmsWowheadCleaveRefresh(state, 2.0, false, colossusCooldown)
    if cleaveSpellID then
        return cleaveSpellID
    end

    -- Major cooldowns sit directly under Rend so they no longer drift behind
    -- several rotational GCDs each cycle. Both respect /midrotlab cooldowns.
    if addon:CanUseArmsWowheadAvatar(state, colossusCooldown) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return state.spell.warbreakerLike
    end

    local postColossus = addon:RecommendArmsSlayerPostColossus(state, colossusUp)
    if postColossus then
        return postColossus
    end

    if addon:ShouldSpendArmsSuddenDeathCapped(state) or addon:ShouldSpendArmsSlayerExecutioner(state, 4) then
        return state.spell.execute
    end

    if addon:CanUseArmsWowheadHeroicStrike(state) then
        return addon:GetArmsWowheadHeroicStrikeRecommendation(state)
    end

    if Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    if addon:ShouldUseArmsSlayerBladestorm(state, colossusCooldown, colossusUp) then
        return state.spell.bladestorm
    end

    -- Outside execute range Arms Execute is only usable through Sudden Death,
    -- so plain usability is the single-stack proc spend (covers hidden auras).
    if addon:ShouldSpendArmsSuddenDeath(state) or Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if addon:ShouldUseArmsOpportunistOverpower(state, 2) then
        return OVERPOWER_SPELL_ID
    end

    cleaveSpellID = addon:RecommendArmsWowheadCleaveRefresh(state, 5.0, true, colossusCooldown)
        or addon:RecommendArmsWowheadRendRefresh(state, 5.0, true, colossusCooldown)
    if cleaveSpellID then
        return cleaveSpellID
    end

    if Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID) then
        return OVERPOWER_SPELL_ID
    end

    if Engine.CanUseEnemySpell(state.spell.wreckingThrow) then
        return state.spell.wreckingThrow
    end

    if Engine.CanUseEnemySpell(SLAM_SPELL_ID) then
        return SLAM_SPELL_ID
    end

    return nil
end
function addon:RecommendArmsWowheadSlayerExecute(state, colossusCooldown, colossusUp)
    -- 0.4.1: aligned with Method's Midnight 12.1.5 execute priority:
    -- Heroic Strike > Colossus Smash > Execute (2 Sudden Death / 4 Executioner)
    -- > Mortal Strike (2 Executioner's Precision) > Execute (1 Sudden Death or
    -- 40+ rage) > Overpower (below 40 rage). Plain Mortal Strike is no longer
    -- spent ahead of Execute here; it is only a late filler.
    local cleaveSpellID = addon:RecommendArmsWowheadCleaveRefresh(state, 2.0, false, colossusCooldown)
    if cleaveSpellID then
        return cleaveSpellID
    end

    if addon:CanUseArmsWowheadHeroicStrike(state) then
        return addon:GetArmsWowheadHeroicStrikeRecommendation(state)
    end

    if addon:CanUseArmsWowheadAvatar(state, colossusCooldown) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return state.spell.warbreakerLike
    end

    local postColossus = addon:RecommendArmsSlayerPostColossus(state, colossusUp)
    if postColossus then
        return postColossus
    end

    if addon:ShouldSpendArmsSuddenDeathCapped(state) or addon:ShouldSpendArmsSlayerExecutioner(state, 4) then
        return state.spell.execute
    end

    if (state.executionersPrecisionStacks or 0) >= 2 and Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    if addon:ShouldUseArmsSlayerBladestorm(state, colossusCooldown, colossusUp) then
        return state.spell.bladestorm
    end

    if addon:ShouldSpendArmsSuddenDeath(state) or addon:CanUseArmsExecuteAtRage(state, 40) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID) then
        return OVERPOWER_SPELL_ID
    end

    if Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    if Engine.CanUseEnemySpell(state.spell.wreckingThrow) then
        return state.spell.wreckingThrow
    end

    if Engine.CanUseEnemySpell(SLAM_SPELL_ID) then
        return SLAM_SPELL_ID
    end

    return nil
end
function addon:RecommendArmsWowheadColossusSingleTarget(state, colossusCooldown, colossusUp)
    if (state.colossalMightStacks or 0) < 10 and Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    local rendSpellID = addon:RecommendArmsWowheadCleaveRefresh(state, 10.0, true, colossusCooldown)
        or addon:RecommendArmsWowheadRendRefresh(state, 10.0, true, colossusCooldown)
    if rendSpellID then
        return rendSpellID
    end

    if addon:CanUseArmsRavagerBeforeColossus(state, colossusCooldown) then
        return state.spell.ravager
    end

    if addon:CanUseArmsWowheadAvatar(state, colossusCooldown) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return state.spell.warbreakerLike
    end

    if colossusUp and Engine.CanUseEnemySpell(state.spell and state.spell.demolish) then
        return state.spell.demolish
    end

    if addon:CanUseArmsWowheadHeroicStrike(state) then
        return addon:GetArmsWowheadHeroicStrikeRecommendation(state)
    end

    if addon:ShouldSpendArmsSuddenDeathCapped(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    if addon:ShouldSpendArmsSuddenDeath(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID) then
        return OVERPOWER_SPELL_ID
    end

    rendSpellID = addon:RecommendArmsWowheadCleaveRefresh(state, 5.0, false, colossusCooldown)
        or addon:RecommendArmsWowheadRendRefresh(state, 5.0, false, colossusCooldown)
    if rendSpellID then
        return rendSpellID
    end

    if Engine.CanUseEnemySpell(SLAM_SPELL_ID) then
        return SLAM_SPELL_ID
    end

    return nil
end
function addon:RecommendArmsWowheadColossusExecute(state, colossusCooldown, colossusUp)
    if addon:CanUseArmsRavagerBeforeColossus(state, colossusCooldown) then
        return state.spell.ravager
    end

    if addon:CanUseArmsWowheadAvatar(state, colossusCooldown) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return state.spell.warbreakerLike
    end

    if addon:CanUseArmsWowheadHeroicStrike(state) then
        return addon:GetArmsWowheadHeroicStrikeRecommendation(state)
    end

    if colossusUp and Engine.CanUseEnemySpell(state.spell and state.spell.demolish) then
        return state.spell.demolish
    end

    if Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    if addon:ShouldSpendArmsSuddenDeath(state) or addon:CanUseArmsExecuteAtRage(state, 75) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID) then
        return OVERPOWER_SPELL_ID
    end

    if state.hasDeepWounds == true and Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(SLAM_SPELL_ID) then
        return SLAM_SPELL_ID
    end

    return nil
end
function addon:RecommendArmsWowheadSlayerAOE(state, colossusCooldown, colossusUp)
    if addon:ShouldUseArmsSweepingStrikes(state) then
        return SWEEPING_STRIKES_SPELL_ID
    end

    if (state.rendRemaining or 0) <= (state.gcd or 1.5)
    and state.hasCleave == true
    and Engine.CanUseEnemySpell(CLEAVE_SPELL_ID)
    then
        return CLEAVE_SPELL_ID
    end

    if Engine.CanRecommendWarriorAvatar(state) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return state.spell.warbreakerLike
    end

    if Engine.CanUseEnemySpell(CLEAVE_SPELL_ID) and (state.collateralDamageStacks or 0) >= 3 then
        return CLEAVE_SPELL_ID
    end

    if Engine.CanRecommendWarriorBladestorm(state) then
        return state.spell.bladestorm
    end

    if addon:ShouldSpendArmsSuddenDeathCapped(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(CLEAVE_SPELL_ID) then
        return CLEAVE_SPELL_ID
    end

    if addon:HasArmsOverpowerCharges(state, 2) and Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID) then
        return OVERPOWER_SPELL_ID
    end

    if addon:ShouldSpendArmsSuddenDeath(state) then
        return state.spell.execute
    end

    if Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID) then
        return OVERPOWER_SPELL_ID
    end

    if Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    if Engine.CanUseEnemySpell(SLAM_SPELL_ID) then
        return SLAM_SPELL_ID
    end

    return nil
end
function addon:RecommendArmsWowheadColossusAOE(state, colossusCooldown, colossusUp)
    if addon:ShouldUseArmsSweepingStrikes(state) then
        return SWEEPING_STRIKES_SPELL_ID
    end

    if addon:CanUseArmsRavagerBeforeColossus(state, colossusCooldown) then
        return state.spell.ravager
    end

    if addon:CanUseArmsWowheadAvatar(state, colossusCooldown) then
        return AVATAR_SPELL_ID
    end

    if Engine.CanRecommendEnemySpell(state.spell and state.spell.warbreakerLike) then
        return state.spell.warbreakerLike
    end

    if colossusUp and Engine.CanRecommendWarriorBladestorm(state) then
        return state.spell.bladestorm
    end

    if Engine.CanUseEnemySpell(CLEAVE_SPELL_ID) then
        return CLEAVE_SPELL_ID
    end

    if (state.colossalMightStacks or 0) < 10 and Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    if Engine.CanUseEnemySpell(state.spell and state.spell.demolish) then
        return state.spell.demolish
    end

    if Engine.CanUseEnemySpell(OVERPOWER_SPELL_ID) then
        return OVERPOWER_SPELL_ID
    end

    if Engine.CanUseEnemySpell(MORTAL_STRIKE_SPELL_ID) then
        return MORTAL_STRIKE_SPELL_ID
    end

    if addon:ShouldSpendArmsSuddenDeathCapped(state) then
        return state.spell.execute
    end

    if addon:ShouldSpendArmsSuddenDeath(state) then
        return state.spell.execute
    end

    if Engine.CanUseExecuteSpell(state) then
        return state.spell.execute
    end

    if Engine.CanUseEnemySpell(SLAM_SPELL_ID) then
        return SLAM_SPELL_ID
    end

    return nil
end
function Engine.RecommendArmsColossus(state)
    local openerSpellID = addon:RecommendArmsWowheadOpener(state)
    if openerSpellID then
        return openerSpellID
    end

    local colossusCooldown = GetCooldownRemaining(state.spell and state.spell.warbreakerLike or COLOSSUS_SMASH_SPELL_ID)
    local colossusUp = Engine.IsArmsColossusSmashUp(state)
    local combatOpenerSpellID = addon:RecommendArmsWowheadCombatOpener(state, colossusCooldown, colossusUp)
    if combatOpenerSpellID then
        return combatOpenerSpellID
    end

    if state.isAOE then
        return addon:RecommendArmsWowheadColossusAOE(state, colossusCooldown, colossusUp)
    end

    if state.executePhase or (state.targetHealthKnown ~= true and state.executeStrictUsable == true) then
        return addon:RecommendArmsWowheadColossusExecute(state, colossusCooldown, colossusUp)
    end

    return addon:RecommendArmsWowheadColossusSingleTarget(state, colossusCooldown, colossusUp)
end

function Engine.RecommendArmsSlayer(state)
    local channelUtilitySpellID = addon:RecommendArmsBladestormChannelUtility(state)
    if channelUtilitySpellID then
        return channelUtilitySpellID
    end

    local openerSpellID = addon:RecommendArmsWowheadOpener(state)
    if openerSpellID then
        return openerSpellID
    end

    local colossusCooldown = GetCooldownRemaining(state.spell and state.spell.warbreakerLike or COLOSSUS_SMASH_SPELL_ID)
    local colossusUp = Engine.IsArmsColossusSmashUp(state)
    local combatOpenerSpellID = addon:RecommendArmsWowheadCombatOpener(state, colossusCooldown, colossusUp)
    if combatOpenerSpellID then
        return combatOpenerSpellID
    end

    if state.isAOE then
        return addon:RecommendArmsWowheadSlayerAOE(state, colossusCooldown, colossusUp)
    end

    -- When health is hidden, Sudden Death can make Execute usable well before
    -- execute phase. Keep the normal ST priority (including Rend upkeep) for
    -- a confirmed proc; only use usability as the phase fallback without one.
    local suddenDeathProc = addon:HasReliableArmsSuddenDeathProc(state)
    if state.executePhase
    or (state.targetHealthKnown ~= true and state.executeStrictUsable == true and not suddenDeathProc)
    then
        return addon:RecommendArmsWowheadSlayerExecute(state, colossusCooldown, colossusUp)
    end

    return addon:RecommendArmsWowheadSlayerSingleTarget(state, colossusCooldown, colossusUp)
end
function Engine.HasKillCommandCharges(state, minimumCharges)
    return state.killCommandChargesKnown == true
        and IsSafeNumberAtLeast(state.killCommandCharges, minimumCharges or 1)
end

function Engine.HasBarbedShotCharges(state, minimumCharges)
    return state.barbedShotChargesKnown == true
        and IsSafeNumberAtLeast(state.barbedShotCharges, minimumCharges or 1)
end


function Engine.CanUseBarbedShotWithCharge(state)
    return Engine.HasBarbedShotCharges(state, 1)
        and Engine.CanUseBMEnemySpell(state.spell.barbedShot)
end

function Engine.ShouldUseBeastMasteryCobraShot(state, focusThreshold)
    if not Engine.CanUseBMEnemySpell(state.spell.cobraShot) then
        return false
    end

    local gcd = state.gcd or 1.5
    if (state.killCommandCooldown or math.huge) <= gcd then
        return false
    end

    if state.isAOE and (state.wildThrashCooldown or math.huge) <= gcd then
        return false
    end

    if state.focusKnown == false then
        return true
    end

    return (state.focus or 0) >= (focusThreshold or (state.isAOE and BM_AOE_COBRA_FOCUS_THRESHOLD or BM_SINGLE_TARGET_COBRA_FOCUS_THRESHOLD))
end


function Engine.ShouldUseBeastMasteryBestialWrath(state, requireBeastCleave)
    if not Engine.CanRecommendBMSelfSpell(state.spell.bestialWrath) then
        return false
    end

    if requireBeastCleave
    and (state.beastCleaveRemaining or 0) <= 0
    and Engine.CanUseBMEnemySpell(state.spell.wildThrash)
    then
        return false
    end

    return not (state.barbedShotChargesKnown == true
        and (state.barbedShotCharges or 0) > 1
        and Engine.CanUseBarbedShotWithCharge(state))
end

function Engine.IsBeastMasteryKillCommandEmpowered(state)
    return (state.howlOfThePackLeaderRemaining or 0) > 0
        or (state.natureAllyRemaining or 0) > 0
        or state.killCommandActionGlow == true
end

function Engine.ShouldUseBeastMasteryKillCommand(state, allowUnempowered)
    if not Engine.CanUseBMEnemySpell(state.spell.killCommand) then
        return false
    end

    if Engine.IsBeastMasteryKillCommandEmpowered(state) then
        return true
    end

    if Engine.HasKillCommandCharges(state, 2) then
        return true
    end

    return allowUnempowered == true
end

function Engine.RecommendBeastMasteryHunterPackLeaderSingleTarget(state)
    if Engine.HasBarbedShotCharges(state, 2) and Engine.CanUseBarbedShotWithCharge(state) then
        return state.spell.barbedShot
    end

    if Engine.ShouldUseBeastMasteryBestialWrath(state, false) then
        return state.spell.bestialWrath
    end

    if (state.howlOfThePackLeaderRemaining or 0) > 0 and Engine.CanUseBMEnemySpell(state.spell.killCommand) then
        return state.spell.killCommand
    end

    if Engine.ShouldUseBeastMasteryKillCommand(state, false) then
        return state.spell.killCommand
    end

    if (state.cobraFangStacks or 0) >= 3 and Engine.CanUseBMEnemySpell(state.spell.cobraShot) then
        return state.spell.cobraShot
    end

    if Engine.CanUseBarbedShotWithCharge(state) then
        return state.spell.barbedShot
    end

    if Engine.ShouldUseBeastMasteryCobraShot(state, BM_SINGLE_TARGET_COBRA_FOCUS_THRESHOLD) then
        return state.spell.cobraShot
    end

    if Engine.CanUseBMEnemySpell(state.spell.steadyShot) then
        return state.spell.steadyShot
    end

    return nil
end

function Engine.RecommendBeastMasteryHunterPackLeaderAOE(state)
    if Engine.HasBarbedShotCharges(state, 2) and Engine.CanUseBarbedShotWithCharge(state) then
        return state.spell.barbedShot
    end

    if (state.beastCleaveRemaining or 0) > 0 and Engine.ShouldUseBeastMasteryBestialWrath(state, true) then
        return state.spell.bestialWrath
    end

    if Engine.CanUseBMEnemySpell(state.spell.wildThrash) then
        Engine.MarkBeastCleaveRefreshRecommended()
        return state.spell.wildThrash
    end

    if Engine.ShouldUseBeastMasteryBestialWrath(state, false) then
        return state.spell.bestialWrath
    end

    if Engine.ShouldUseBeastMasteryKillCommand(state, true) then
        return state.spell.killCommand
    end

    if (state.cobraFangStacks or 0) > 0 and (state.beastCleaveRemaining or 0) > 0 and Engine.CanUseBMEnemySpell(state.spell.cobraShot) then
        return state.spell.cobraShot
    end

    if Engine.CanUseBarbedShotWithCharge(state) then
        return state.spell.barbedShot
    end

    if Engine.ShouldUseBeastMasteryCobraShot(state, BM_AOE_COBRA_FOCUS_THRESHOLD) then
        return state.spell.cobraShot
    end

    if Engine.CanUseBMEnemySpell(state.spell.steadyShot) then
        return state.spell.steadyShot
    end

    return nil
end

function Engine.RecommendBeastMasteryHunterDarkRangerSingleTarget(state)
    if Engine.HasBarbedShotCharges(state, 2) and (state.bestialWrathCooldown or math.huge) < ((state.gcd or 1.5) * 2) and Engine.CanUseBarbedShotWithCharge(state) then
        return state.spell.barbedShot
    end

    if Engine.ShouldUseBeastMasteryBestialWrath(state, false) then
        return state.spell.bestialWrath
    end

    if (state.witheringFireRemaining or 0) > 0 and (state.killCommandCooldown or math.huge) > (state.gcd or 1.5) and Engine.CanUseBMEnemySpell(state.spell.blackArrow) then
        return state.spell.blackArrow
    end

    if Engine.ShouldUseBeastMasteryKillCommand(state, false) then
        return state.spell.killCommand
    end

    if (state.witheringFireRemaining or 0) <= ((state.gcd or 1.5) * 2) and Engine.CanUseBMEnemySpell(state.spell.wailingArrow) then
        return state.spell.wailingArrow
    end

    if (state.cobraFangStacks or 0) > 3 and Engine.CanUseBMEnemySpell(state.spell.cobraShot) then
        return state.spell.cobraShot
    end

    if Engine.CanUseBMEnemySpell(state.spell.blackArrow) then
        return state.spell.blackArrow
    end

    if Engine.CanUseBarbedShotWithCharge(state) then
        return state.spell.barbedShot
    end

    if Engine.ShouldUseBeastMasteryCobraShot(state, BM_SINGLE_TARGET_COBRA_FOCUS_THRESHOLD) then
        return state.spell.cobraShot
    end

    if Engine.CanUseBMEnemySpell(state.spell.steadyShot) then
        return state.spell.steadyShot
    end

    return nil
end

function Engine.RecommendBeastMasteryHunterDarkRangerAOE(state)
    if (state.beastCleaveRemaining or 0) <= 0 and Engine.CanUseBMEnemySpell(state.spell.blackArrow) then
        return state.spell.blackArrow
    end

    if (state.beastCleaveRemaining or 0) > 0 and Engine.ShouldUseBeastMasteryBestialWrath(state, true) then
        return state.spell.bestialWrath
    end

    if Engine.CanUseBMEnemySpell(state.spell.wildThrash) then
        Engine.MarkBeastCleaveRefreshRecommended()
        return state.spell.wildThrash
    end

    if Engine.ShouldUseBeastMasteryKillCommand(state, false) then
        return state.spell.killCommand
    end

    if Engine.HasBarbedShotCharges(state, 2) and Engine.CanUseBarbedShotWithCharge(state) then
        return state.spell.barbedShot
    end

    if (state.witheringFireRemaining or 0) > 0 and Engine.CanUseBMEnemySpell(state.spell.blackArrow) then
        return state.spell.blackArrow
    end

    if (state.witheringFireRemaining or 0) <= ((state.gcd or 1.5) * 2) and Engine.CanUseBMEnemySpell(state.spell.wailingArrow) then
        return state.spell.wailingArrow
    end

    if Engine.CanUseBarbedShotWithCharge(state) then
        return state.spell.barbedShot
    end

    if Engine.CanUseBMEnemySpell(state.spell.blackArrow) then
        return state.spell.blackArrow
    end

    if Engine.ShouldUseBeastMasteryCobraShot(state, BM_AOE_COBRA_FOCUS_THRESHOLD) then
        return state.spell.cobraShot
    end

    if Engine.CanUseBMEnemySpell(state.spell.steadyShot) then
        return state.spell.steadyShot
    end

    return nil
end

function Engine.RecommendBeastMasteryHunter(state)
    if state.isBeastMasteryDarkRanger then
        if state.isAOE then
            return Engine.RecommendBeastMasteryHunterDarkRangerAOE(state)
        end

        return Engine.RecommendBeastMasteryHunterDarkRangerSingleTarget(state)
    end

    if state.isAOE then
        return Engine.RecommendBeastMasteryHunterPackLeaderAOE(state)
    end

    return Engine.RecommendBeastMasteryHunterPackLeaderSingleTarget(state)
end

function Engine.CanRecommendRetSelfSpell(spellID)
    return not Engine.IsManualMajorCooldown(spellID) and Engine.CanUseRetSelfSpell(spellID)
end

function Engine.CanUseRetSpender(state, spellID, minimumHolyPower, allowEmpyreanPower)
    if not Engine.CanUseRetEnemySpell(spellID) then
        return false
    end

    if state.holyPowerKnown == false then
        return true
    end

    if (state.holyPower or 0) >= (minimumHolyPower or 3) then
        return true
    end

    if state.divinePurposeUp then
        return true
    end

    return allowEmpyreanPower == true
        and spellID == state.spell.divineStorm
        and state.empyreanPowerUp == true
end

function Engine.CanUseRetGeneratorWithoutOvercap(state, spellID, generatedHolyPower)
    if not Engine.CanUseRetEnemySpell(spellID) then
        return false
    end

    if state.holyPowerKnown == false then
        return true
    end

    return (state.holyPower or 0) <= (5 - (generatedHolyPower or 1))
end

function Engine.CanUseRetHammerOfLight(state)
    return state
        and state.spell
        and (
            (state.recentWakeOfAshesCast == true and state.recentHammerOfLightCast ~= true)
            or state.lightDeliveranceReady == true
            or state.hammerOfLightActionGlow == true
        )
        and Engine.CanUseRetEnemySpell(state.spell.hammerOfLight)
end


function Engine.GetRetHighSpenderThreshold(state)
    return state and state.hasCrusadingStrikes and 4 or 5
end


function Engine.CanUseRetHammerOfWrath(state)
    return state
        and state.hammerOfWrathWindow == true
        and Engine.CanUseRetGeneratorWithoutOvercap(state, state.spell and state.spell.hammerOfWrath, 1)
end

function Engine.HasRetHolyPower(state, minimumHolyPower)
    if not state or state.holyPowerKnown == false then
        return true
    end

    return (state.holyPower or 0) >= (minimumHolyPower or 3)
end

function Engine.CanUseRetMethodSpender(state, spellID, minimumHolyPower, allowEmpyreanPower)
    if not Engine.CanUseRetEnemySpell(spellID) then
        return false
    end

    if Engine.HasRetHolyPower(state, minimumHolyPower) then
        return true
    end

    return allowEmpyreanPower == true
        and spellID == state.spell.divineStorm
        and state.empyreanPowerUp == true
end

function Engine.RecommendRetMethodWakeAndToll(state)
    if Engine.CanUseRetGeneratorWithoutOvercap(state, state.spell.wakeOfAshes, 3) then
        return state.spell.wakeOfAshes
    end

    if Engine.CanUseRetGeneratorWithoutOvercap(state, state.spell.divineToll, 1) then
        return state.spell.divineToll
    end

    return nil
end

function Engine.RecommendRetMethodJudgmentOrHammer(state)
    if (state.judgmentRemaining or 0) <= (state.gcd or 1.5)
    and Engine.CanUseRetEnemySpell(state.spell.judgment)
    then
        return state.spell.judgment
    end

    if Engine.CanUseRetHammerOfWrath(state) then
        return state.spell.hammerOfWrath
    end

    if Engine.CanUseRetEnemySpell(state.spell.judgment) then
        return state.spell.judgment
    end

    return nil
end

function Engine.RecommendRetMeleeFiller(state)
    if Engine.CanUseRetEnemySpell(state.spell.templarSlash) then
        return state.spell.templarSlash
    end

    if Engine.CanUseRetEnemySpell(state.spell.templarStrike) then
        return state.spell.templarStrike
    end

    return nil
end

function Engine.RecommendRetMethodCooldowns(state)
    if not state.hasRadiantGlory
    and Engine.CanRecommendRetSelfSpell(state.spell.avengingWrath)
    then
        return state.spell.avengingWrath
    end

    if Engine.CanUseRetEnemySpell(state.spell.executionSentence) then
        return state.spell.executionSentence
    end

    return nil
end

function Engine.RecommendRetOpener(state)
    if not state or state.inCombat ~= true then
        return nil
    end

    if state.openerBladeOfJusticeDone ~= true
    and Engine.CanUseRetGeneratorWithoutOvercap(state, state.spell.bladeOfJustice, 1)
    then
        return state.spell.bladeOfJustice
    end

    return nil
end





function Engine.CanUseRetBladeOfJusticeWithArtOfWar(state, requireAvengingWrathDown)
    if requireAvengingWrathDown == true and (state.avengingWrathRemaining or 0) > (state.gcd or 1.5) then
        return false
    end

    return state.artOfWarBladeUp == true
        or (state.artOfWarStacks or 0) >= 1
        or (state.bladeOfJusticeChargesKnown == true and (state.bladeOfJusticeCharges or 0) >= 2)
end

function Engine.CanUseRetHammerOfWrathAtTwoCharges(state)
    return state.hammerOfWrathChargesKnown == true
        and (state.hammerOfWrathCharges or 0) >= 2
        and Engine.CanUseRetHammerOfWrath(state)
end



function Engine.RecommendRetributionTemplarSingleTarget(state)
    local spenderSpellID = state.spell.singleTargetSpender
    local openerSpellID = Engine.RecommendRetOpener(state)
    if openerSpellID then
        return openerSpellID
    end

    local cooldownSpellID = Engine.RecommendRetMethodCooldowns(state)
    if cooldownSpellID then
        return cooldownSpellID
    end

    if Engine.CanUseRetHammerOfLight(state) then
        return state.spell.hammerOfLight
    end

    if state.divineArbiterUp
    and Engine.CanUseRetMethodSpender(state, state.spell.divineStorm, 5, true)
    then
        return state.spell.divineStorm
    end

    if Engine.CanUseRetMethodSpender(state, spenderSpellID, Engine.GetRetHighSpenderThreshold(state), false) then
        return spenderSpellID
    end

    local generatorSpellID = Engine.RecommendRetMethodWakeAndToll(state)
    if generatorSpellID then
        return generatorSpellID
    end

    if Engine.CanUseRetBladeOfJusticeWithArtOfWar(state, false)
    and Engine.CanUseRetGeneratorWithoutOvercap(state, state.spell.bladeOfJustice, 1)
    then
        return state.spell.bladeOfJustice
    end

    if state.divineArbiterUp
    and Engine.CanUseRetSpender(state, state.spell.divineStorm, 3, true)
    then
        return state.spell.divineStorm
    end

    if Engine.CanUseRetMethodSpender(state, spenderSpellID, 4, true) then
        return spenderSpellID
    end

    if Engine.CanUseRetEnemySpell(state.spell.bladeOfJustice) then
        return state.spell.bladeOfJustice
    end

    local judgmentOrHammerSpellID = Engine.RecommendRetMethodJudgmentOrHammer(state)
    if judgmentOrHammerSpellID then
        return judgmentOrHammerSpellID
    end

    if Engine.CanUseRetSpender(state, spenderSpellID, 3, true) then
        return spenderSpellID
    end

    return Engine.RecommendRetMeleeFiller(state)
end

function Engine.RecommendRetributionTemplarAOE(state)
    local openerSpellID = Engine.RecommendRetOpener(state)
    if openerSpellID then
        return openerSpellID
    end

    local cooldownSpellID = Engine.RecommendRetMethodCooldowns(state)
    if cooldownSpellID then
        return cooldownSpellID
    end

    if Engine.CanUseRetHammerOfLight(state) then
        return state.spell.hammerOfLight
    end

    if state.divineArbiterUp
    and Engine.CanUseRetMethodSpender(state, state.spell.singleTargetSpender, 5, false)
    then
        return state.spell.singleTargetSpender
    end

    if Engine.CanUseRetMethodSpender(state, state.spell.divineStorm, Engine.GetRetHighSpenderThreshold(state), false) then
        return state.spell.divineStorm
    end

    local generatorSpellID = Engine.RecommendRetMethodWakeAndToll(state)
    if generatorSpellID then
        return generatorSpellID
    end

    if Engine.CanUseRetBladeOfJusticeWithArtOfWar(state, false)
    and Engine.CanUseRetGeneratorWithoutOvercap(state, state.spell.bladeOfJustice, 1)
    then
        return state.spell.bladeOfJustice
    end

    if state.divineArbiterUp
    and Engine.CanUseRetSpender(state, state.spell.singleTargetSpender, 3, true)
    then
        return state.spell.singleTargetSpender
    end

    if Engine.CanUseRetMethodSpender(state, state.spell.divineStorm, 4, true) then
        return state.spell.divineStorm
    end

    if Engine.CanUseRetEnemySpell(state.spell.bladeOfJustice) then
        return state.spell.bladeOfJustice
    end

    local judgmentOrHammerSpellID = Engine.RecommendRetMethodJudgmentOrHammer(state)
    if judgmentOrHammerSpellID then
        return judgmentOrHammerSpellID
    end

    if Engine.CanUseRetSpender(state, state.spell.divineStorm, 3, true) then
        return state.spell.divineStorm
    end

    return Engine.RecommendRetMeleeFiller(state)
end

function Engine.RecommendRetributionHeraldSingleTarget(state)
    local spenderSpellID = state.spell.singleTargetSpender
    local openerSpellID = Engine.RecommendRetOpener(state)
    if openerSpellID then
        return openerSpellID
    end

    local cooldownSpellID = Engine.RecommendRetMethodCooldowns(state)
    if cooldownSpellID then
        return cooldownSpellID
    end

    if state.divineArbiterUp
    and Engine.CanUseRetMethodSpender(state, state.spell.divineStorm, 5, true)
    then
        return state.spell.divineStorm
    end

    if Engine.CanUseRetMethodSpender(state, spenderSpellID, Engine.GetRetHighSpenderThreshold(state), false) then
        return spenderSpellID
    end

    local generatorSpellID = Engine.RecommendRetMethodWakeAndToll(state)
    if generatorSpellID then
        return generatorSpellID
    end

    if Engine.CanUseRetBladeOfJusticeWithArtOfWar(state, true)
    and Engine.CanUseRetGeneratorWithoutOvercap(state, state.spell.bladeOfJustice, 1)
    then
        return state.spell.bladeOfJustice
    end

    if Engine.CanUseRetHammerOfWrathAtTwoCharges(state) then
        return state.spell.hammerOfWrath
    end

    if state.divineArbiterUp
    and Engine.CanUseRetSpender(state, state.spell.divineStorm, 3, true)
    then
        return state.spell.divineStorm
    end

    if Engine.CanUseRetMethodSpender(state, spenderSpellID, 4, true) then
        return spenderSpellID
    end

    if Engine.CanUseRetHammerOfWrath(state) then
        return state.spell.hammerOfWrath
    end

    if Engine.CanUseRetEnemySpell(state.spell.bladeOfJustice) then
        return state.spell.bladeOfJustice
    end

    if Engine.CanUseRetEnemySpell(state.spell.judgment) then
        return state.spell.judgment
    end

    if Engine.CanUseRetSpender(state, spenderSpellID, 3, true) then
        return spenderSpellID
    end

    return Engine.RecommendRetMeleeFiller(state)
end

function Engine.RecommendRetributionHeraldAOE(state)
    local openerSpellID = Engine.RecommendRetOpener(state)
    if openerSpellID then
        return openerSpellID
    end

    local cooldownSpellID = Engine.RecommendRetMethodCooldowns(state)
    if cooldownSpellID then
        return cooldownSpellID
    end

    if state.divineArbiterUp
    and Engine.CanUseRetSpender(state, state.spell.singleTargetSpender, 3, true)
    then
        return state.spell.singleTargetSpender
    end

    if Engine.CanUseRetMethodSpender(state, state.spell.divineStorm, Engine.GetRetHighSpenderThreshold(state), false) then
        return state.spell.divineStorm
    end

    local generatorSpellID = Engine.RecommendRetMethodWakeAndToll(state)
    if generatorSpellID then
        return generatorSpellID
    end

    if Engine.CanUseRetHammerOfWrathAtTwoCharges(state) then
        return state.spell.hammerOfWrath
    end

    if Engine.CanUseRetBladeOfJusticeWithArtOfWar(state, true)
    and Engine.CanUseRetGeneratorWithoutOvercap(state, state.spell.bladeOfJustice, 1)
    then
        return state.spell.bladeOfJustice
    end

    if state.divineArbiterUp
    and Engine.CanUseRetSpender(state, state.spell.singleTargetSpender, 3, true)
    then
        return state.spell.singleTargetSpender
    end

    if Engine.CanUseRetMethodSpender(state, state.spell.divineStorm, 4, true) then
        return state.spell.divineStorm
    end

    if Engine.CanUseRetHammerOfWrath(state) then
        return state.spell.hammerOfWrath
    end

    if Engine.CanUseRetEnemySpell(state.spell.bladeOfJustice) then
        return state.spell.bladeOfJustice
    end

    if Engine.CanUseRetEnemySpell(state.spell.judgment) then
        return state.spell.judgment
    end

    if Engine.CanUseRetSpender(state, state.spell.divineStorm, 3, true) then
        return state.spell.divineStorm
    end

    return Engine.RecommendRetMeleeFiller(state)
end

function Engine.RecommendRetributionTemplar(state)
    if state.isAOE then
        return Engine.RecommendRetributionTemplarAOE(state)
    end

    return Engine.RecommendRetributionTemplarSingleTarget(state)
end

function Engine.RecommendRetributionHeraldOfTheSun(state)
    if state.isAOE then
        return Engine.RecommendRetributionHeraldAOE(state)
    end

    return Engine.RecommendRetributionHeraldSingleTarget(state)
end

function Engine.RecommendFrostDeathKnight(state)
    local runeSpender = state.isAOE and state.spell.frostscythe or state.spell.obliterate
    local runicPowerSpender = state.isAOE and state.spell.glacialAdvance or state.spell.frostStrike

    -- Fall back gracefully when a talent replacement is not selected.
    if not runeSpender then
        runeSpender = state.spell.obliterate
    end
    if not runicPowerSpender then
        runicPowerSpender = state.spell.frostStrike
    end

    if state.empowerRuneWeaponChargesKnown
    and (state.empowerRuneWeaponCharges or 0) >= 2
    and Engine.CanRecommendSelfSpell(state.spell.empowerRuneWeapon)
    then
        return state.spell.empowerRuneWeapon
    end

    if state.isFrostDeathbringer and Engine.CanRecommendEnemySpell(state.spell.reapersMark) then
        return state.spell.reapersMark
    end

    if Engine.CanRecommendSelfSpell(state.spell.remorselessWinter) then
        return state.spell.remorselessWinter
    end

    if Engine.CanRecommendSelfSpell(state.spell.pillarOfFrost) then
        return state.spell.pillarOfFrost
    end

    if state.pillarOfFrostUp and Engine.CanRecommendSelfSpell(state.spell.breathOfSindragosa) then
        return state.spell.breathOfSindragosa
    end

    if state.pillarOfFrostUp
    and Engine.CanRecommendEnemySpell(state.spell.frostwyrmsFury)
    and (
        state.recentFrostwyrmsFuryCast ~= true
        or (state.pillarOfFrostRemaining or 0) <= 3.0
    )
    then
        return state.spell.frostwyrmsFury
    end

    if state.pillarOfFrostUp and Engine.CanRecommendSelfSpell(state.spell.raiseDead) then
        return state.spell.raiseDead
    end

    if ((state.killingMachineStacks or 0) >= 2 or state.exterminateUp)
    and Engine.CanUseEnemySpell(runeSpender)
    then
        return runeSpender
    end

    if state.rimeUp and Engine.CanUseEnemySpell(state.spell.howlingBlast) then
        return state.spell.howlingBlast
    end

    if state.breathOfSindragosaUp ~= true
    and state.runicPowerKnown
    and (state.runicPower or 0) >= 80
    and Engine.CanUseEnemySpell(runicPowerSpender)
    then
        return runicPowerSpender
    end

    if (state.killingMachineStacks or 0) >= 1 and Engine.CanUseEnemySpell(runeSpender) then
        return runeSpender
    end

    if state.pillarOfFrostUp ~= true and Engine.CanRecommendSelfSpell(state.spell.empowerRuneWeapon) then
        return state.spell.empowerRuneWeapon
    end

    if state.breathOfSindragosaUp ~= true and Engine.CanUseEnemySpell(runicPowerSpender) then
        return runicPowerSpender
    end

    if Engine.CanUseEnemySpell(runeSpender) then
        return runeSpender
    end

    if Engine.CanUseEnemySpell(state.spell.howlingBlast) then
        return state.spell.howlingBlast
    end

    return nil
end

function Engine.GetSubtletyBuilderRecommendation(state, spellID)
    return spellID
end

function Engine.RecommendSubtletyRogue(state)
    local comboPoints = state.comboPoints or 0
    local finisherThreshold = math.max(5, (state.maximumComboPoints or 7) - 1)
    local builder = state.isAOE and state.spell.shurikenStorm or state.spell.shadowstrike
    local finisher = state.isAOE and state.spell.blackPowder or state.spell.eviscerate
    local outsideDanceBuilder = state.spell.gloomblade or state.spell.backstab
    local empoweredFinisher = state.spell.coupDeGrace
    if not Engine.CanUseEnemySpell(empoweredFinisher) then
        empoweredFinisher = state.spell.eviscerate
    end

    if state.inCombat ~= true and state.stealthed ~= true and Engine.CanUseSelfSpell(state.spell.stealth) then
        return state.spell.stealth
    end

    if state.stealthed and Engine.CanUseEnemySpell(builder) then
        return Engine.GetSubtletyBuilderRecommendation(state, builder)
    end

    -- Both hero trees consume their empowered finisher immediately. Trickster
    -- always uses Eviscerate for Coup de Grace, including in AoE.
    if (state.coupDeGraceUp or state.darkestNightUp)
    and comboPoints >= finisherThreshold
    and Engine.CanUseEnemySpell(empoweredFinisher)
    then
        return empoweredFinisher
    end

    if Engine.CanRecommendEnemySpell(state.spell.goremawsBite) then
        return state.spell.goremawsBite
    end

    local secretTechniqueReady = Engine.CanRecommendEnemySpell(state.spell.secretTechnique)
    if state.shadowDanceUp ~= true and secretTechniqueReady then
        local shouldDance = state.isSubtletyTrickster and comboPoints >= finisherThreshold
            or state.isSubtletyDeathstalker and comboPoints <= 2
        if shouldDance and Engine.CanRecommendSelfSpell(state.spell.shadowDance) then
            return state.spell.shadowDance
        end
    end

    if state.shadowDanceUp and state.shadowBladesUp ~= true
    and Engine.CanRecommendSelfSpell(state.spell.shadowBlades)
    then
        return state.spell.shadowBlades
    end

    if state.shadowDanceUp and comboPoints >= finisherThreshold and secretTechniqueReady then
        return state.spell.secretTechnique
    end

    if comboPoints >= finisherThreshold and Engine.CanUseEnemySpell(finisher) then
        return finisher
    end

    if state.shadowDanceUp and Engine.CanUseEnemySpell(builder) then
        return Engine.GetSubtletyBuilderRecommendation(state, builder)
    end

    if state.isAOE and Engine.CanUseEnemySpell(state.spell.shurikenStorm) then
        return state.spell.shurikenStorm
    end

    -- Never fall back to the normal builder during Stealth or Shadow Dance.
    -- Shadowstrike can be briefly unavailable during the GCD/energy update;
    -- showing Gloomblade in that gap wastes the limited Dance window and can
    -- also point at a binding that is not present on the stealth page.
    if state.shadowDanceUp ~= true
    and state.stealthed ~= true
    and Engine.CanUseEnemySpell(outsideDanceBuilder)
    then
        return outsideDanceBuilder
    end

    return nil
end

function Engine.GetRecommendationForState(state, profileLabel)
    if not state or not state.hasTarget then
        return nil, profileLabel
    end

    if state.isGenericSpec and addon.SpecEngine then
        return addon.SpecEngine:Recommend(state), profileLabel
    end

    if state.isBeastMasteryHunter then
        return Engine.RecommendBeastMasteryHunter(state), profileLabel
    end

    if state.isFrostDeathKnight then
        return Engine.RecommendFrostDeathKnight(state), profileLabel
    end

    if state.isSubtletyRogue then
        return Engine.RecommendSubtletyRogue(state), profileLabel
    end

    if state.isRetributionTemplar then
        return Engine.RecommendRetributionTemplar(state), profileLabel
    end

    if state.isRetributionHeraldOfTheSun then
        return Engine.RecommendRetributionHeraldOfTheSun(state), profileLabel
    end

    if state.isFuryMountainThane then
        return Engine.RecommendFuryMountainThane(state), profileLabel
    end

    if state.isFurySlayer then
        return Engine.RecommendFurySlayer(state), profileLabel
    end

    if state.isArmsColossus then
        return Engine.RecommendArmsColossus(state), profileLabel
    end

    if state.isArmsSlayer then
        return Engine.RecommendArmsSlayer(state), profileLabel
    end

    if state.isFury then
        return Engine.RecommendFurySlayer(state), profileLabel
    end

    if state.isArms then
        return Engine.RecommendArmsColossus(state), profileLabel
    end

    return nil, profileLabel
end

function Engine.GetBurstRecommendation(state)
    if not state
    or not addon.IsBurstWindowActive
    or addon:IsBurstWindowActive() ~= true
    then
        return nil
    end

    local potionRecommendation = addon.GetBurstPotionRecommendation and addon:GetBurstPotionRecommendation() or nil
    if potionRecommendation then
        return potionRecommendation
    end

    if (state.isFury or state.isArms) and Engine.ShouldRecommendMajorCooldowns() then
        if Engine.CanUseSelfSpell(RECKLESSNESS_SPELL_ID) then
            return RECKLESSNESS_SPELL_ID
        end

        if Engine.CanUseWarriorAvatar(state) then
            return AVATAR_SPELL_ID
        end
    end

    return nil
end

function Engine.GetRecommendationSpellID(recommendation)
    if type(recommendation) == "table" then
        return recommendation.spellID
    end

    return recommendation
end

function Engine.GetRecommendationName(recommendation)
    if type(recommendation) == "table" then
        return recommendation.name
    end

    return Engine.GetSpellNameSafe(recommendation)
end

function addon:GetRecommendation()
    local state = Engine.BuildWarriorState()
        or Engine.BuildSubtletyRogueState()
        or Engine.BuildFrostDeathKnightState()
        or Engine.BuildBeastMasteryHunterState()
        or Engine.BuildRetributionPaladinState()
        or (addon.SpecEngine and addon.SpecEngine:BuildState())
    local profileLabel = self:GetProfileLabel()
    local modeLabel = Engine.GetModeLabel(state)
    local burstRecommendation = Engine.GetBurstRecommendation(state)
    if burstRecommendation then
        return burstRecommendation, profileLabel, modeLabel
    end

    local recommendationSpellID = Engine.GetRecommendationForState(state, profileLabel)
    if recommendationSpellID == nil then
        local fallbackSpellID = Engine.GetAssistedFallback(state)
        if fallbackSpellID then
            self.lastAssistedFallbackAt = GetTime()
            return fallbackSpellID, profileLabel, modeLabel
        end
    end

    return recommendationSpellID, profileLabel, modeLabel
end

-- Fill otherwise-empty in-combat recommendations with Blizzard's Assisted
-- Highlight suggestion when it is usable now. Disabled with /midrotlab assist off.
function Engine.GetAssistedFallback(state)
    if not state or state.hasTarget ~= true or not UnitAffectingCombat or not UnitAffectingCombat("player") then
        return nil
    end

    if addon.db and addon.db.assistedFallback == false then
        return nil
    end

    if UnitChannelInfo then
        local ok, channelName = pcall(UnitChannelInfo, "player")
        if ok and channelName then
            return nil
        end
    end

    local spellID = state.assistedSuggestion or Engine.GetAssistedCombatSuggestion()
    if not spellID or Engine.IsBlacklistedRecommendation(spellID) then
        return nil
    end

    if Engine.IsManualMajorCooldown(spellID) and not Engine.ShouldRecommendMajorCooldowns() then
        return nil
    end

    if Engine.CanUseEnemySpell(spellID) or Engine.CanUseSelfSpell(spellID) then
        return spellID
    end

    return nil
end

function addon:GetDebugSnapshot()
    local state = Engine.BuildWarriorState()
        or Engine.BuildSubtletyRogueState()
        or Engine.BuildFrostDeathKnightState()
        or Engine.BuildBeastMasteryHunterState()
        or Engine.BuildRetributionPaladinState()
        or (addon.SpecEngine and addon.SpecEngine:BuildState())
    local profileLabel = self:GetProfileLabel()
    local recommendation = Engine.GetBurstRecommendation(state) or Engine.GetRecommendationForState(state, profileLabel)
    local recommendationSpellID = Engine.GetRecommendationSpellID(recommendation)

    if not state then
        return {
            profileLabel = profileLabel,
            mode = nil,
            activeSpecID = GetCurrentSpecID(),
            activeSpecName = addon:GetCurrentSpecName(),
            activeHeroTalentName = addon:GetActiveHeroTalentSpecName(),
            recommendationSpellID = recommendationSpellID,
            recommendationSpellName = Engine.GetRecommendationName(recommendation),
            recommendationType = type(recommendation) == "table" and recommendation.type or "spell",
        }
    end

    return {
        profileLabel = profileLabel,
        profileType = state.profileType,
        isFrostDeathKnight = state.isFrostDeathKnight,
        isFrostDeathbringer = state.isFrostDeathbringer,
        isSubtletyRogue = state.isSubtletyRogue,
        isSubtletyDeathstalker = state.isSubtletyDeathstalker,
        isSubtletyTrickster = state.isSubtletyTrickster,
        isFury = state.isFury,
        isFurySlayer = state.isFurySlayer,
        isFuryMountainThane = state.isFuryMountainThane,
        isArms = state.isArms,
        isArmsColossus = state.isArmsColossus,
        isArmsSlayer = state.isArmsSlayer,
        isCleave = state.isCleave,
        activeSpecID = state.activeSpecID or GetCurrentSpecID(),
        activeSpecName = state.activeSpecName or self:GetCurrentSpecName(),
        activeHeroTalentName = state.activeHeroTalentName or self:GetActiveHeroTalentSpecName(),
        retributionBuildName = state.retributionBuildName,
        mode = Engine.GetModeLabel(state),
        recommendationSpellID = recommendationSpellID,
        recommendationSpellName = Engine.GetRecommendationName(recommendation),
        recommendationType = type(recommendation) == "table" and recommendation.type or "spell",
        hasTarget = state.hasTarget,
        targetCount = state.targetCount,
        detectedTargetCount = state.detectedTargetCount,
        visibleHostileTargetCount = state.visibleHostileTargetCount,
        recentDamageTargetCount = state.recentDamageTargetCount,
        targetCountOverride = state.targetCountOverride,
        targetCountSource = state.targetCountSource,
        resourceName = state.resourceName,
        resource = state.resource,
        resourceKnown = state.resourceKnown,
        rageKnown = state.rageKnown,
        rage = state.rage,
        focusKnown = state.focusKnown,
        focus = state.focus,
        runicPowerKnown = state.runicPowerKnown,
        runicPower = state.runicPower,
        energyKnown = state.energyKnown,
        energy = state.energy,
        comboPointsKnown = state.comboPointsKnown,
        comboPoints = state.comboPoints,
        maximumComboPoints = state.maximumComboPoints,
        stealthed = state.stealthed,
        shadowDanceUp = state.shadowDanceUp,
        shadowDanceRemaining = state.shadowDanceRemaining,
        shadowBladesUp = state.shadowBladesUp,
        coupDeGraceUp = state.coupDeGraceUp,
        darkestNightUp = state.darkestNightUp,
        quietusCelerisUp = state.quietusCelerisUp,
        shadowDanceCharges = state.shadowDanceCharges,
        shadowDanceChargesKnown = state.shadowDanceChargesKnown,
        readyRunes = state.readyRunes,
        readyRunesKnown = state.readyRunesKnown,
        killingMachineStacks = state.killingMachineStacks,
        rimeUp = state.rimeUp,
        exterminateUp = state.exterminateUp,
        pillarOfFrostUp = state.pillarOfFrostUp,
        pillarOfFrostRemaining = state.pillarOfFrostRemaining,
        breathOfSindragosaUp = state.breathOfSindragosaUp,
        recentFrostwyrmsFuryCast = state.recentFrostwyrmsFuryCast,
        empowerRuneWeaponCharges = state.empowerRuneWeaponCharges,
        empowerRuneWeaponChargesKnown = state.empowerRuneWeaponChargesKnown,
        holyPowerKnown = state.holyPowerKnown,
        holyPower = state.holyPower,
                enrageRemaining = state.enrageRemaining,
        recklessnessUp = state.recklessnessUp,
        recklessnessRemaining = state.recklessnessRemaining,
        avatarUp = state.avatarUp,
        genericSpecKey = state.genericSpecKey,
        genericReason = state.genericReason,
        genericError = state.genericError,
        assistedSuggestion = state.assistedSuggestion,
        assistedSuggestionName = state.assistedSuggestion and Engine.GetSpellNameSafe(state.assistedSuggestion) or nil,
        assistedMatch = state.assistedSuggestion ~= nil
            and recommendationSpellID ~= nil
            and Engine.SpellIDsMatch(state.assistedSuggestion, recommendationSpellID),
        assistedFallbackSpellID = recommendation == nil and Engine.GetAssistedFallback(state) or nil,
        assistedSuddenDeathSignal = state.isArms == true and addon:HasAssistedArmsSuddenDeathSignal(state) or false,
        rageBandLow = state.rageBandLow,
        rageBandHigh = state.rageBandHigh,
        rageEstimate = state.rageEstimate,
        observedGcd = Engine.GetObservedGlobalCooldown(),
        colossusCooldown = state.isArms == true
            and GetCooldownRemaining(state.spell and state.spell.warbreakerLike or COLOSSUS_SMASH_SPELL_ID)
            or nil,
        colossusCooldownEstimated = Engine.WasCooldownEstimated(state.spell and state.spell.warbreakerLike or COLOSSUS_SMASH_SPELL_ID),
        avatarCooldownEstimated = Engine.WasCooldownEstimated(AVATAR_SPELL_ID),
        bladestormCooldownEstimated = Engine.WasCooldownEstimated(state.spell and state.spell.bladestorm),
        executeGlowEvent = Engine.IsOverlayGlowEventActive(state.spell and state.spell.execute)
            or Engine.IsOverlayGlowEventActive(EXECUTE_SPELL_ID),
        recklessnessCooldown = state.recklessnessCooldown,
        avatarCooldown = state.avatarCooldown,
        avatarRemaining = state.avatarRemaining,
        hackAndSlashUp = state.hackAndSlashUp,
        odynsFuryCooldown = state.odynsFuryCooldown,
        bladestormCooldown = state.bladestormCooldown,
        hasOdynsFury = state.hasOdynsFury,
        inCombat = state.inCombat,
        combatTime = state.combatTime,
        openerBladeOfJusticeDone = state.openerBladeOfJusticeDone,
        openerBladeOfJusticeCastAt = state.openerBladeOfJusticeCastAt,
        openerBloodthirstDone = state.openerBloodthirstDone,
        openerBloodthirstCastAt = state.openerBloodthirstCastAt,
        recentRampageCast = state.recentRampageCast,
        furyGeneratorCastsSinceRampage = state.furyGeneratorCastsSinceRampage,
        furyRampageUsableFor = state.furyRampageUsableFor,
        furyGeneratorsSinceRampageUsable = state.furyGeneratorsSinceRampageUsable,
        isRetributionTemplar = state.isRetributionTemplar,
        isRetributionHeraldOfTheSun = state.isRetributionHeraldOfTheSun,
        hasRadiantGlory = state.hasRadiantGlory,
        hasCrusadingStrikes = state.hasCrusadingStrikes,
        hasTwoTargetAOETalents = state.hasTwoTargetAOETalents,
        avengingWrathRemaining = state.avengingWrathRemaining,
        recentWakeOfAshesCast = state.recentWakeOfAshesCast,
        recentHammerOfLightCast = state.recentHammerOfLightCast,
        executionSentenceRemaining = state.executionSentenceRemaining,
        expurgationRemaining = state.expurgationRemaining,
        judgmentRemaining = state.judgmentRemaining,
        artOfWarUp = state.artOfWarUp,
        artOfWarStacks = state.artOfWarStacks,
        bladeOfJusticeCharges = state.bladeOfJusticeCharges,
        bladeOfJusticeChargesKnown = state.bladeOfJusticeChargesKnown,
        hammerOfWrathCharges = state.hammerOfWrathCharges,
        hammerOfWrathChargesKnown = state.hammerOfWrathChargesKnown,
        hammerOfWrathWindow = state.hammerOfWrathWindow,
        artOfWarBladeActionGlow = state.artOfWarBladeActionGlow,
        artOfWarBladeActionGlowKnown = state.artOfWarBladeActionGlowKnown,
        artOfWarHammerActionGlow = state.artOfWarHammerActionGlow,
        artOfWarHammerActionGlowKnown = state.artOfWarHammerActionGlowKnown,
        empyreanPowerUp = state.empyreanPowerUp,
        empyreanLegacyUp = state.empyreanLegacyUp,
        divineArbiterUp = state.divineArbiterUp,
        empyreanPowerActionGlow = state.empyreanPowerActionGlow,
        empyreanPowerActionGlowKnown = state.empyreanPowerActionGlowKnown,
        divinePurposeUp = state.divinePurposeUp,
        lightDeliveranceStacks = state.lightDeliveranceStacks,
        lightDeliveranceReady = state.lightDeliveranceReady,
        hammerOfLightActionGlow = state.hammerOfLightActionGlow,
        hammerOfLightActionGlowKnown = state.hammerOfLightActionGlowKnown,
        beastCleaveRemaining = state.beastCleaveRemaining,
        bestialWrathCooldown = state.bestialWrathCooldown,
        killCommandCharges = state.killCommandCharges,
        killCommandChargesKnown = state.killCommandChargesKnown,
        barbedShotCharges = state.barbedShotCharges,
        barbedShotChargesKnown = state.barbedShotChargesKnown,
        hasImprovedWhirlwind = state.hasImprovedWhirlwind,
        hasWrathAndFury = state.hasWrathAndFury,
        hasMassacre = state.hasMassacre,
        hasDeepWounds = state.hasDeepWounds,
        hasBroadStrokes = state.hasBroadStrokes,
        hasDreadnaught = state.hasDreadnaught,
        hasCleave = state.hasCleave,
        hasRend = state.hasRend,
        hasBloodletting = state.hasBloodletting,
        hasFervorOfBattle = state.hasFervorOfBattle,
        hasMassExecution = state.hasMassExecution,
        hasRavager = state.hasRavager,
        hasHeroicStrike = state.hasHeroicStrike,
        masterOfWarfareUp = state.masterOfWarfareUp,
        masterOfWarfareProcUp = state.masterOfWarfareProcUp,
        masterOfWarfareStackUp = state.masterOfWarfareStackUp,
        heroicMightUp = state.heroicMightUp,
        heroicStrikeActionCount = state.heroicStrikeActionCount,
        heroicStrikeActionCountKnown = state.heroicStrikeActionCountKnown,
        heroicStrikeActionCountSignal = state.heroicStrikeActionCountSignal,
        heroicStrikeOverrideActionCount = state.heroicStrikeOverrideActionCount,
        heroicStrikeOverrideActionCountKnown = state.heroicStrikeOverrideActionCountKnown,
        heroicStrikeOverrideActionCountSignal = state.heroicStrikeOverrideActionCountSignal,
        heroicStrikeButtonGlow = state.heroicStrikeButtonGlow,
        heroicStrikeButtonGlowKnown = state.heroicStrikeButtonGlowKnown,
        heroicStrikeOverrideButtonGlow = state.heroicStrikeOverrideButtonGlow,
        heroicStrikeOverrideButtonGlowKnown = state.heroicStrikeOverrideButtonGlowKnown,
        slamActionCount = state.slamActionCount,
        slamActionCountKnown = state.slamActionCountKnown,
        slamActionCountSignal = state.slamActionCountSignal,
        slamButtonGlow = state.slamButtonGlow,
        slamButtonGlowKnown = state.slamButtonGlowKnown,
        hasCollateralDamage = state.hasCollateralDamage,
        hasDemolish = state.hasDemolish,
        hasAvatar = state.hasAvatar,
        hasBladestorm = state.hasBladestorm,
        suddenDeathUp = state.suddenDeathUp,
        suddenDeathStacks = state.suddenDeathStacks,
        overpowerCharges = state.overpowerCharges,
        overpowerChargesKnown = state.overpowerChargesKnown,
        rendRemaining = state.rendRemaining,
        colossusSmashRemaining = state.colossusSmashRemaining,
        recentColossusSmashCast = state.recentColossusSmashCast,
        colossalMightStacks = state.colossalMightStacks,
        collateralDamageStacks = state.collateralDamageStacks,
        executionersPrecisionStacks = state.executionersPrecisionStacks,
        battlelordStacks = state.battlelordStacks,
        fierceFollowthroughUp = state.fierceFollowthroughUp,
        opportunistStacks = state.opportunistStacks,
        imminentDemiseStacks = state.imminentDemiseStacks,
        executionerStacks = state.executionerStacks,
        sweepingStrikesUp = state.sweepingStrikesUp,
        suddenDeathAuraByID = state.suddenDeathAuraByID,
        suddenDeathAuraByAltID = state.suddenDeathAuraByAltID,
        suddenDeathAuraByName = state.suddenDeathAuraByName,
        suddenDeathOverlayByExecute = state.suddenDeathOverlayByExecute,
        suddenDeathOverlayByBaseExecute = state.suddenDeathOverlayByBaseExecute,
        suddenDeathOverlayByFuryExecute = state.suddenDeathOverlayByFuryExecute,
        suddenDeathActionCount = state.suddenDeathActionCount,
        suddenDeathActionCountKnown = state.suddenDeathActionCountKnown,
        suddenDeathActionCountSignal = state.suddenDeathActionCountSignal,
        suddenDeathButtonGlow = state.suddenDeathButtonGlow,
        suddenDeathButtonGlowKnown = state.suddenDeathButtonGlowKnown,
        executePhase = state.executePhase,
        executeStrictUsable = state.executeStrictUsable,
        targetHealthKnown = state.targetHealthKnown,
        targetHealthPercent = state.targetHealthPercent,
        whirlwindStacks = state.whirlwindStacks,
        assumedWhirlwindStacks = state.assumedWhirlwindStacks,
        thunderBlastStacks = state.thunderBlastStacks,
        thunderBlastCharges = state.thunderBlastCharges,
        thunderBlastChargesKnown = state.thunderBlastChargesKnown,
        canCharge = Engine.CanUseEnemySpell(CHARGE_SPELL_ID),
        canHeroicStrike = addon:CanUseArmsWowheadHeroicStrike(state),
        canCleave = Engine.CanUseEnemySpell(CLEAVE_SPELL_ID),
        canRampage = Engine.CanUseEnemySpell(RAMPAGE_SPELL_ID),
        canExecute = Engine.CanUseExecuteSpell(state),
        canBloodbath = Engine.CanUseEnemySpell(state.spell and state.spell.bloodbath),
        canBloodthirst = Engine.CanUseEnemySpell(state.spell and state.spell.bloodthirst),
        canBloodthirstLike = Engine.CanUseEnemySpell(state.spell and state.spell.bloodthirstLike),
        canRecklessness = Engine.CanUseSelfSpell(RECKLESSNESS_SPELL_ID),
        canAvatar = Engine.CanUseWarriorAvatar(state),
        canKillCommand = Engine.CanUseBMEnemySpell(state.spell and state.spell.killCommand),
        canBarbedShot = Engine.CanUseBMEnemySpell(state.spell and state.spell.barbedShot),
        canBestialWrath = Engine.CanUseBMSelfSpell(state.spell and state.spell.bestialWrath),
        canWildThrash = Engine.CanUseBMEnemySpell(state.spell and state.spell.wildThrash),
        canCobraShot = Engine.CanUseBMEnemySpell(state.spell and state.spell.cobraShot),
        canSteadyShot = Engine.CanUseBMEnemySpell(state.spell and state.spell.steadyShot),
        canAvengingWrath = Engine.CanUseRetSelfSpell(state.spell and state.spell.avengingWrath),
        canExecutionSentence = Engine.CanUseRetEnemySpell(state.spell and state.spell.executionSentence),
        canSingleTargetSpender = Engine.CanUseRetEnemySpell(state.spell and state.spell.singleTargetSpender),
        canDivineStorm = Engine.CanUseRetEnemySpell(state.spell and state.spell.divineStorm),
        canWakeOfAshes = Engine.CanUseRetEnemySpell(state.spell and state.spell.wakeOfAshes),
        canDivineToll = Engine.CanUseRetEnemySpell(state.spell and state.spell.divineToll),
        canHammerOfLight = Engine.CanUseRetHammerOfLight(state),
        canHammerOfWrath = Engine.CanUseRetHammerOfWrath(state),
        canBladeOfJustice = Engine.CanUseRetEnemySpell(state.spell and state.spell.bladeOfJustice),
        canJudgment = Engine.CanUseRetEnemySpell(state.spell and state.spell.judgment),
        canTemplarStrike = Engine.CanUseRetEnemySpell(state.spell and state.spell.templarStrike),
        canTemplarSlash = Engine.CanUseRetEnemySpell(state.spell and state.spell.templarSlash),
        canCrusaderStrike = false,
        cooldownViewerBestialWrath = state.cooldownViewerBestialWrath,
        cooldownViewerKillCommand = state.cooldownViewerKillCommand,
        cooldownViewerBarbedShot = state.cooldownViewerBarbedShot,
        cooldownViewerWildThrash = state.cooldownViewerWildThrash,
        cooldownViewerCobraShot = state.cooldownViewerCobraShot,
        cooldownViewerSteadyShot = state.cooldownViewerSteadyShot,
        cooldownViewerBeastCleaveActive = state.cooldownViewerBeastCleaveActive,
        cooldownViewerBlackArrow = state.cooldownViewerBlackArrow,
        cooldownViewerWailingArrow = state.cooldownViewerWailingArrow,
        isBeastMasteryPackLeader = state.isBeastMasteryPackLeader,
        isBeastMasteryDarkRanger = state.isBeastMasteryDarkRanger,
        bestialWrathRemaining = state.bestialWrathRemaining,
        witheringFireRemaining = state.witheringFireRemaining,
        deathblowRemaining = state.deathblowRemaining,
        howlOfThePackLeaderRemaining = state.howlOfThePackLeaderRemaining,
        natureAllyRemaining = state.natureAllyRemaining,
        killCommandActionGlow = state.killCommandActionGlow,
        canBlackArrow = Engine.CanUseBMEnemySpell(state.spell and state.spell.blackArrow),
        canWailingArrow = Engine.CanUseBMEnemySpell(state.spell and state.spell.wailingArrow),
        canCrushingBlow = Engine.CanUseEnemySpell(state.spell and state.spell.crushingBlow),
        canRagingBlow = Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlow),
        canRagingBlowLike = Engine.CanUseEnemySpell(state.spell and state.spell.ragingBlowLike),
        canWreckingThrow = Engine.CanUseEnemySpell(state.spell and state.spell.wreckingThrow),
        canWhirlwind = Engine.CanUseEnemySpell(state.spell and state.spell.whirlwind),
        canThunderBlast = Engine.CanUseEnemySpell(state.spell and state.spell.thunderBlast),
        canOdynsFury = state.hasOdynsFury == true and Engine.CanUseEnemySpell(state.spell and state.spell.odynsFury),
        canBladestorm = Engine.CanRecommendWarriorBladestorm(state),
        canObliterate = Engine.CanUseEnemySpell(state.spell and state.spell.obliterate),
        canFrostStrike = Engine.CanUseEnemySpell(state.spell and state.spell.frostStrike),
        canHowlingBlast = Engine.CanUseEnemySpell(state.spell and state.spell.howlingBlast),
        canFrostscythe = Engine.CanUseEnemySpell(state.spell and state.spell.frostscythe),
        canGlacialAdvance = Engine.CanUseEnemySpell(state.spell and state.spell.glacialAdvance),
        canReapersMark = Engine.CanUseEnemySpell(state.spell and state.spell.reapersMark),
        canPillarOfFrost = Engine.CanUseSelfSpell(state.spell and state.spell.pillarOfFrost),
        canEmpowerRuneWeapon = Engine.CanUseSelfSpell(state.spell and state.spell.empowerRuneWeapon),
        canBreathOfSindragosa = Engine.CanUseSelfSpell(state.spell and state.spell.breathOfSindragosa),
        canFrostwyrmsFury = Engine.CanUseEnemySpell(state.spell and state.spell.frostwyrmsFury),
        canRemorselessWinter = Engine.CanUseSelfSpell(state.spell and state.spell.remorselessWinter),
        canRaiseDead = Engine.CanUseSelfSpell(state.spell and state.spell.raiseDead),
        canBackstab = Engine.CanUseEnemySpell(state.spell and state.spell.backstab),
        canGloomblade = Engine.CanUseEnemySpell(state.spell and state.spell.gloomblade),
        canShadowstrike = Engine.CanUseEnemySpell(state.spell and state.spell.shadowstrike),
        canEviscerate = Engine.CanUseEnemySpell(state.spell and state.spell.eviscerate),
        canShurikenStorm = Engine.CanUseEnemySpell(state.spell and state.spell.shurikenStorm),
        canBlackPowder = Engine.CanUseEnemySpell(state.spell and state.spell.blackPowder),
        canShadowDance = Engine.CanUseSelfSpell(state.spell and state.spell.shadowDance),
        canShadowBlades = Engine.CanUseSelfSpell(state.spell and state.spell.shadowBlades),
        canSecretTechnique = Engine.CanUseEnemySpell(state.spell and state.spell.secretTechnique),
        canGoremawsBite = Engine.CanUseEnemySpell(state.spell and state.spell.goremawsBite),
        canCoupDeGrace = Engine.CanUseEnemySpell(state.spell and state.spell.coupDeGrace),
    }
end

-- Shared helpers for SpecEngine.lua (data-driven spec profiles, 0.5.0).
addon.EngineInternals = {
    Engine = Engine,
    GetCooldownRemaining = GetCooldownRemaining,
    GetSpellChargesAvailable = GetSpellChargesAvailable,
    IsSpellKnownInBook = IsSpellKnownInBook,
    ResolveActionBarSpellIDByName = ResolveActionBarSpellIDByName,
    HasHostileLivingTarget = HasHostileLivingTarget,
    IsUnitPowerSecret = IsUnitPowerSecret,
    IsSpellOverlayedSafe = IsSpellOverlayedSafe,
    GetUnitHealthPercent = GetUnitHealthPercent,
    GetApproxGlobalCooldown = GetApproxGlobalCooldown,
    GetPlayerAuraRemainingByName = GetPlayerAuraRemainingByName,
    GetPlayerAuraStacksByName = GetPlayerAuraStacksByName,
    HasPlayerAuraByName = function(name)
        return GetUnitAuraInfo(name, "player", "HELPFUL") ~= nil
    end,
    TargetDebuffRemainingByName = TargetDebuffRemainingByName,
    GetReadyRuneCount = GetReadyRuneCount,
    IsTrainingDummyUnit = IsTrainingDummyUnit,
}
