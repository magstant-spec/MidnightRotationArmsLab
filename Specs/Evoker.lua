local addonName, addon = ...

-- Devastation Evoker (Method 12.1.5; Scalecommander and Flameshaper).
-- Essence is a readable secondary resource. Empowered spells are recommended
-- at the button level; choose the rank the guide calls for (rank 1 on ST,
-- rank matched to enemy count in AoE).
addon:RegisterSpecProfile({
    key = "DEVASTATION_EVOKER",
    class = "EVOKER",
    specID = 1467,
    specName = "Devastation",
    label = "Devastation",
    melee = false,
    aoeThreshold = 4, -- Pyre over Disintegrate on 4+ stacked enemies
    primaryPower = 0,
    primaryName = "Mana",
    secondaryPower = 19, -- Essence
    secondaryName = "Essence",
    rangeSpells = { "livingFlame", "azureStrike" },

    spells = {
        deepBreath = { "Deep Breath", self = true },
        dragonrage = { "Dragonrage", major = true, self = true },
        tipTheScales = { "Tip the Scales", self = true },
        fireBreath = { "Fire Breath", self = true },
        eternitySurge = "Eternity Surge",
        disintegrate = "Disintegrate",
        pyre = "Pyre",
        livingFlame = "Living Flame",
        azureStrike = "Azure Strike",
        azureSweep = "Azure Sweep",
        unboundFlame = "Unbound Flame",
    },

    buffs = {
        dragonrage = { duration = 18, castBy = { "dragonrage" }, auras = { "Dragonrage" } },
    },

    procs = {
        essenceBurst = { auras = { "Essence Burst" }, glow = { "disintegrate", "pyre" } },
    },

    prepare = function(s)
        s.canSpend = s:proc("essenceBurst") or s:resourceAtLeast(3, true)
    end,

    st = {
        { "deepBreath", hero = "Scalecommander" },
        { "dragonrage" },
        { "tipTheScales", when = function(s) return s:buffUp("dragonrage") and s:ready("fireBreath") end },
        { "fireBreath", when = function(s) return not s:cdBelow("dragonrage", 4, false) or s:buffUp("dragonrage") or not s:known("dragonrage") end },
        { "eternitySurge", when = function(s) return not s:cdBelow("dragonrage", 4, false) or s:buffUp("dragonrage") or not s:known("dragonrage") end },
        { "disintegrate", when = function(s) return s.canSpend end },
        { "unboundFlame" },
        { "azureSweep" },
        { "livingFlame" },
        { "azureStrike" },
    },

    aoe = {
        { "deepBreath", hero = "Scalecommander" },
        { "tipTheScales" },
        { "dragonrage" },
        { "eternitySurge" },
        { "fireBreath" },
        { "disintegrate", hero = "Scalecommander", when = function(s) return s.canSpend and not s:lastCast("disintegrate") end, note = "Mass Disintegrate" },
        { "pyre", when = function(s) return s.canSpend end },
        { "azureSweep" },
        { "azureStrike" },
        { "livingFlame" },
    },
})

-- Augmentation Evoker (Method 12.1.5). Prescience and Ebon Might are
-- recommended as buttons; pick Prescience targets yourself (or use a
-- mouseover/focus macro).
addon:RegisterSpecProfile({
    key = "AUGMENTATION_EVOKER",
    class = "EVOKER",
    specID = 1473,
    specName = "Augmentation",
    label = "Augmentation",
    melee = false,
    aoeThreshold = 99, -- one priority for all target counts
    primaryPower = 0,
    primaryName = "Mana",
    secondaryPower = 19,
    secondaryName = "Essence",
    rangeSpells = { "livingFlame", "azureStrike" },

    spells = {
        prescience = { "Prescience", self = true },
        ebonMight = { "Ebon Might", self = true },
        breathOfEons = { "Breath of Eons", major = true, self = true },
        tipTheScales = { "Tip the Scales", self = true },
        fireBreath = { "Fire Breath", self = true },
        upheaval = "Upheaval",
        eruption = "Eruption",
        livingFlame = "Living Flame",
        azureStrike = "Azure Strike",
        timeSkip = { "Time Skip", major = true, self = true },
    },

    buffs = {
        ebonMight = { duration = 10, castBy = { "ebonMight" }, extendBy = { eruption = 2 }, auras = { "Ebon Might" } },
    },

    procs = {
        essenceBurst = { auras = { "Essence Burst" }, glow = { "eruption" } },
    },

    st = {
        { "prescience" },
        { "ebonMight", when = function(s) return s:buff("ebonMight") <= 4 end },
        { "breathOfEons" },
        { "tipTheScales", when = function(s) return s:ready("fireBreath") end },
        { "fireBreath" },
        { "upheaval" },
        { "timeSkip", when = function(s) return not s:ready("fireBreath") and not s:ready("upheaval") end },
        { "eruption", when = function(s) return s:buffUp("ebonMight") end },
        { "livingFlame" },
        { "azureStrike" },
    },
})
