local addonName, addon = ...

-- Affliction Warlock (Method 12.1.5; Hellcaller and Soul Harvester). Soul
-- Shards are readable; DoTs are inferred from casts on the current target.
addon:RegisterSpecProfile({
    key = "AFFLICTION_WARLOCK",
    class = "WARLOCK",
    specID = 265,
    specName = "Affliction",
    label = "Affliction",
    melee = false,
    aoeThreshold = 3,
    primaryPower = 0,
    primaryName = "Mana",
    secondaryPower = 7, -- Soul Shards
    secondaryName = "Soul Shards",
    rangeSpells = { "agony", "shadowBolt" },

    spells = {
        haunt = "Haunt",
        agony = "Agony",
        corruption = { "Corruption", "Wither" },
        unstableAffliction = "Unstable Affliction",
        summonDarkglare = { "Summon Darkglare", major = true, self = true },
        malevolence = { "Malevolence", self = true },
        darkHarvest = "Dark Harvest",
        maleficGrasp = "Malefic Grasp",
        drainSoul = { "Drain Soul", "Shadow Bolt" },
        shadowBolt = "Shadow Bolt",
        seedOfCorruption = "Seed of Corruption",
    },

    dots = {
        agony = { duration = 18, castBy = { "agony" }, auras = { "Agony" } },
        corruption = { duration = 14, castBy = { "corruption", "seedOfCorruption" }, auras = { "Corruption", "Wither" } },
        haunt = { duration = 18, castBy = { "haunt" }, auras = { "Haunt" } },
    },

    prepare = function(s)
        s.dotsUp = s:dotUp("agony") and s:dotUp("corruption")
        s.harvestAt = s:hero("Soul Harvester") and 1 or 0
    end,

    st = {
        { "haunt" },
        { "corruption", when = function(s) return s:refreshable("corruption") end },
        { "agony", when = function(s) return s:refreshable("agony") end },
        { "summonDarkglare", when = function(s) return s.dotsUp end },
        { "malevolence", hero = "Hellcaller", when = function(s) return s:resourceAtLeast(3, true) end },
        { "unstableAffliction", when = function(s) return s:resourceAtLeast(1, true) end },
        { "darkHarvest", when = function(s) return s:resourceBelow(s.harvestAt + 1, true) end },
        { "maleficGrasp" },
        { "drainSoul" },
        { "shadowBolt" },
    },

    aoe = {
        { "agony", when = function(s) return s:refreshable("agony") end },
        { "haunt" },
        { "summonDarkglare" },
        { "malevolence", hero = "Hellcaller" },
        { "seedOfCorruption", when = function(s) return s:resourceAtLeast(1, true) end },
        { "darkHarvest", when = function(s) return s:resourceBelow(1, true) end },
        { "corruption", when = function(s) return s:refreshable("corruption") end },
        { "drainSoul" },
        { "shadowBolt" },
    },
})

-- Demonology Warlock (Icy Veins Midnight Season 1; Diabolist and Soul
-- Harvester). Wild Imps are counted from Hand of Gul'dan casts and consumed
-- by Implosion / Power Siphon; Demonic Core comes from the Demonbolt glow.
addon:RegisterSpecProfile({
    key = "DEMONOLOGY_WARLOCK",
    class = "WARLOCK",
    specID = 266,
    specName = "Demonology",
    label = "Demonology",
    melee = false,
    aoeThreshold = 3,
    primaryPower = 0,
    primaryName = "Mana",
    secondaryPower = 7,
    secondaryName = "Soul Shards",
    rangeSpells = { "shadowBolt", "demonbolt" },

    spells = {
        summonFelguard = { "Summon Felguard", self = true },
        grimoireImpLord = { "Grimoire: Imp Lord", self = true },
        grimoireFelRavager = { "Grimoire: Fel Ravager", self = true },
        summonDemonicTyrant = { "Summon Demonic Tyrant", major = true, self = true },
        summonDoomguard = { "Summon Doomguard", major = true, self = true },
        powerSiphon = { "Power Siphon", self = true },
        implosion = "Implosion",
        callDreadstalkers = "Call Dreadstalkers",
        handOfGuldan = "Hand of Gul'dan",
        demonbolt = "Demonbolt",
        infernalBolt = "Infernal Bolt",
        shadowBolt = "Shadow Bolt",
    },

    procs = {
        demonicCore = { auras = { "Demonic Core" }, glow = { "demonbolt" } },
    },

    counters = {
        wildImps = {
            gain = { handOfGuldan = 3 },
            spend = { implosion = "all", powerSiphon = 2 },
            max = 12,
            expire = 20,
        },
    },

    prepare = function(s)
        s.imps = s:counter("wildImps")
        s.core = s:proc("demonicCore")
    end,

    precombat = {
        { "summonFelguard", when = function(s) return not s:hasPet() end },
    },

    st = {
        { "summonFelguard", when = function(s) return not s:hasPet() end },
        { "grimoireImpLord" },
        { "grimoireFelRavager" },
        { "summonDemonicTyrant" },
        { "summonDoomguard" },
        { "powerSiphon", when = function(s) return s.imps >= 2 and not s.core end },
        { "implosion", when = function(s) return s.imps >= 6 and s.cleave end },
        { "callDreadstalkers" },
        { "handOfGuldan", when = function(s) return s:resourceAtLeast(4, false) end },
        { "demonbolt", when = function(s) return s.core end },
        { "infernalBolt", when = function(s) return s:resourceBelow(3, true) end },
        { "handOfGuldan", when = function(s) return s:resourceAtLeast(3, true) end },
        { "shadowBolt" },
    },
})

-- Destruction Warlock (Method 12.1.5; Hellcaller and Diabolist).
addon:RegisterSpecProfile({
    key = "DESTRUCTION_WARLOCK",
    class = "WARLOCK",
    specID = 267,
    specName = "Destruction",
    label = "Destruction",
    melee = false,
    aoeThreshold = 3,
    primaryPower = 0,
    primaryName = "Mana",
    secondaryPower = 7,
    secondaryName = "Soul Shards",
    rangeSpells = { "incinerate", "conflagrate" },

    spells = {
        immolate = { "Immolate", "Wither" },
        summonInfernal = { "Summon Infernal", major = true, self = true },
        malevolence = { "Malevolence", self = true },
        shadowburn = "Shadowburn",
        chaosBolt = "Chaos Bolt",
        ruination = { "Ruination", overrideOf = "chaosBolt" },
        soulFire = "Soul Fire",
        conflagrate = "Conflagrate",
        incinerate = "Incinerate",
        rainOfFire = { "Rain of Fire", self = true },
        cataclysm = "Cataclysm",
    },

    dots = {
        immolate = { duration = 18, castBy = { "immolate", "cataclysm" }, auras = { "Immolate", "Wither" } },
    },

    buffs = {
        backdraft = { duration = 10, castBy = { "conflagrate" }, consumedBy = { "incinerate", "chaosBolt", "soulFire" }, auras = { "Backdraft" } },
    },

    procs = {
        fiendishCruelty = { auras = { "Fiendish Cruelty" }, glow = { "shadowburn" } },
        demonicArt = { auras = { "Demonic Art: Pit Lord", "Demonic Art: Overlord", "Demonic Art: Mother of Chaos" }, glow = { "chaosBolt", "ruination" } },
    },

    prepare = function(s)
        s.shardsHigh = s:resourceAtLeast(4, false)
        s.rofTargets = s:hero("Diabolist") and 8 or 3
    end,

    st = {
        { "ruination", hero = "Diabolist" },
        { "chaosBolt", hero = "Diabolist", when = function(s) return s:proc("demonicArt") end },
        { "immolate", when = function(s) return s:refreshable("immolate") end },
        { "summonInfernal" },
        { "malevolence", hero = "Hellcaller" },
        { "cataclysm", cleave = true },
        { "shadowburn", when = function(s) return s:proc("fiendishCruelty") or (s.shardsHigh and s:hpBelow(0.2)) end },
        { "rainOfFire", when = function(s) return s.shardsHigh and s.targets >= s.rofTargets end },
        { "chaosBolt", when = function(s) return s.shardsHigh end },
        { "soulFire", when = function(s) return s:buffUp("backdraft") or not s:ready("conflagrate") end },
        { "conflagrate", when = function(s) return not s:buffUp("backdraft") end },
        { "incinerate" },
        { "chaosBolt", when = function(s) return s:resourceAtLeast(2, true) and s.targets < s.rofTargets end },
    },
})
