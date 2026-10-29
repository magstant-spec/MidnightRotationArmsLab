local addonName, addon = ...

-- Unholy Death Knight (Icy Veins 12.0.5 priority; San'layn and Rider of the
-- Apocalypse share it). Lesser Ghoul stacks are hidden in combat, so they are
-- counted from Festering Strike / Scourge Strike casts.
addon:RegisterSpecProfile({
    key = "UNHOLY_DK",
    class = "DEATHKNIGHT",
    specID = 252,
    specName = "Unholy",
    label = "Unholy",
    melee = true,
    aoeThreshold = 3,
    primaryPower = 6, -- Runic Power
    primaryName = "Runic Power",
    secondaryPower = "RUNES",
    secondaryName = "Runes",
    rangeSpells = { "festeringStrike", "scourgeStrike", "clawingShadows" },

    spells = {
        outbreak = "Outbreak",
        putrefy = "Putrefy",
        festeringScythe = "Festering Scythe",
        festeringStrike = "Festering Strike",
        scourgeStrike = { "Scourge Strike", "Vampiric Strike" },
        clawingShadows = "Clawing Shadows",
        soulReaper = "Soul Reaper",
        deathCoil = "Death Coil",
        epidemic = "Epidemic",
        deathAndDecay = "Death and Decay",
        darkTransformation = { "Dark Transformation", major = true, self = true },
        armyOfTheDead = { "Army of the Dead", major = true, self = true },
        summonGargoyle = { "Summon Gargoyle", major = true },
        raiseDead = { "Raise Dead", self = true },
    },

    dots = {
        plague = { duration = 21, castBy = { "outbreak", "putrefy" }, auras = { "Virulent Plague", "Dread Plague" } },
    },

    buffs = {
        darkTransformation = { duration = 15, castBy = { "darkTransformation" }, auras = { "Dark Transformation" } },
    },

    procs = {
        suddenDoom = { auras = { "Sudden Doom" }, glow = { "deathCoil", "epidemic" } },
        reaping = { glow = { "soulReaper" } },
    },

    counters = {
        lesserGhoul = {
            gain = { festeringStrike = 2, festeringScythe = 2 },
            spend = { scourgeStrike = 1, clawingShadows = 1 },
            max = 6,
            expire = 30,
        },
    },

    prepare = function(s)
        s.dt = s:buffUp("darkTransformation")
        s.ghouls = s:counter("lesserGhoul")
    end,

    precombat = {
        { "raiseDead", when = function(s) return not s:hasPet() end, note = "summon ghoul" },
    },

    st = {
        { "raiseDead", when = function(s) return not s:hasPet() end },
        { "putrefy", when = function(s) return not s:dotUp("plague") end, note = "plagues missing" },
        { "outbreak", when = function(s) return s:refreshable("plague") end },
        { "festeringScythe" },
        { "armyOfTheDead" },
        { "darkTransformation" },
        { "summonGargoyle", when = function(s) return s.dt end },
        { "soulReaper", when = function(s) return (s.dt and s:hpBelow(0.35)) or s:proc("reaping") end },
        { "deathCoil", when = function(s) return s:proc("suddenDoom") or s:powerAtLeast(80) end },
        { "putrefy", when = function(s) return s.dt and s:hpAbove(0.35, true) end },
        { "festeringStrike", when = function(s) return s.ghouls < 3 end },
        { "scourgeStrike", when = function(s) return s.ghouls >= 1 end },
        { "clawingShadows", when = function(s) return s.ghouls >= 1 end },
        { "deathCoil" },
        { "festeringStrike" },
        { "scourgeStrike" },
        { "clawingShadows" },
    },

    aoe = {
        { "raiseDead", when = function(s) return not s:hasPet() end },
        { "putrefy", when = function(s) return not s:dotUp("plague") end, note = "plagues missing" },
        { "outbreak", when = function(s) return s:refreshable("plague") end },
        { "festeringScythe" },
        { "armyOfTheDead" },
        { "darkTransformation" },
        { "deathAndDecay", notHero = "San'layn" },
        { "deathAndDecay", hero = "San'layn", when = function(s) return s.targets >= 3 end },
        { "summonGargoyle", when = function(s) return s.dt end },
        { "soulReaper", when = function(s) return (s.dt and s:hpBelow(0.35)) or s:proc("reaping") end },
        { "epidemic", when = function(s) return s:proc("suddenDoom") or s:powerAtLeast(80) end },
        { "putrefy", when = function(s) return s.dt end },
        { "festeringStrike", when = function(s) return s.ghouls < 3 end },
        { "scourgeStrike", when = function(s) return s.ghouls >= 1 end },
        { "clawingShadows", when = function(s) return s.ghouls >= 1 end },
        { "epidemic" },
        { "deathCoil" },
        { "festeringStrike" },
        { "scourgeStrike" },
        { "clawingShadows" },
    },
})
