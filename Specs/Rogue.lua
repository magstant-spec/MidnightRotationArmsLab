local addonName, addon = ...

-- Assassination Rogue (Method 12.1.5). Combo points are readable; bleed
-- timers are inferred from your own casts per target.
addon:RegisterSpecProfile({
    key = "ASSASSINATION_ROGUE",
    class = "ROGUE",
    specID = 259,
    specName = "Assassination",
    label = "Assassination",
    melee = true,
    aoeThreshold = 2, -- Fan of Knives builds on 2+
    primaryPower = 3, -- Energy
    primaryName = "Energy",
    secondaryPower = 4, -- Combo Points
    secondaryName = "Combo Points",
    rangeSpells = { "mutilate", "garrote" },

    spells = {
        stealth = { "Stealth", self = true },
        garrote = "Garrote",
        rupture = "Rupture",
        mutilate = "Mutilate",
        ambush = "Ambush",
        envenom = "Envenom",
        deathmark = { "Deathmark", major = true },
        kingsbane = "Kingsbane",
        vanish = { "Vanish", major = true, self = true },
        crimsonTempest = { "Crimson Tempest", self = true },
        fanOfKnives = { "Fan of Knives", self = true },
    },

    dots = {
        garrote = { duration = 18, castBy = { "garrote" }, auras = { "Garrote" } },
        rupture = { duration = 24, castBy = { "rupture" }, auras = { "Rupture" } },
        crimsonTempest = { duration = 14, castBy = { "crimsonTempest" }, auras = { "Crimson Tempest" } },
    },

    buffs = {
        deathmark = { duration = 16, castBy = { "deathmark" } },
    },

    procs = {
        darkestNight = { auras = { "Darkest Night", "The Darkest Night" }, glow = { "envenom" } },
    },

    prepare = function(s)
        local threshold = s:proc("darkestNight") and 7 or 5
        if s.secondaryMax and s.secondaryMax < threshold then
            threshold = s.secondaryMax
        end
        s.finisher = s:resourceAtLeast(threshold)
        s.bleedsUp = s:dotUp("garrote") and s:dotUp("rupture")
    end,

    precombat = {
        { "stealth", when = function(s) return not s:stealthed() end },
    },

    st = {
        { "garrote", when = function(s) return s:refreshable("garrote") end },
        { "rupture", when = function(s) return s.finisher and s:refreshable("rupture") end },
        { "deathmark", when = function(s) return s.bleedsUp end },
        { "kingsbane", when = function(s) return s:buffUp("deathmark") or not s:cdBelow("deathmark", 20, false) end },
        { "vanish", when = function(s) return s:buffUp("deathmark") and s:ready("garrote") end, note = "Improved Garrote" },
        { "envenom", when = function(s) return s.finisher end },
        { "ambush" },
        { "mutilate" },
    },

    aoe = {
        { "garrote", when = function(s) return s:refreshable("garrote") end },
        { "rupture", when = function(s) return s.finisher and s:refreshable("rupture") end },
        { "deathmark", when = function(s) return s.bleedsUp end },
        { "kingsbane", when = function(s) return s:buffUp("deathmark") or not s:cdBelow("deathmark", 20, false) end },
        { "vanish", when = function(s) return s:buffUp("deathmark") and s:ready("garrote") end },
        { "crimsonTempest", when = function(s) return s:refreshable("crimsonTempest") and not s.finisher end, note = "spread bleeds" },
        { "envenom", when = function(s) return s.finisher end },
        { "fanOfKnives" },
        { "mutilate" },
    },
})

-- Outlaw Rogue (Icy Veins Midnight Season 1). Roll the Bones stage is hidden,
-- so it is re-rolled when the inferred buff window is down.
addon:RegisterSpecProfile({
    key = "OUTLAW_ROGUE",
    class = "ROGUE",
    specID = 260,
    specName = "Outlaw",
    label = "Outlaw",
    melee = true,
    aoeThreshold = 2, -- Blade Flurry at 2+
    primaryPower = 3,
    primaryName = "Energy",
    secondaryPower = 4,
    secondaryName = "Combo Points",
    rangeSpells = { "sinisterStrike" },

    spells = {
        stealth = { "Stealth", self = true },
        rollTheBones = { "Roll the Bones", self = true },
        keepItRolling = { "Keep It Rolling", self = true },
        adrenalineRush = { "Adrenaline Rush", major = true, self = true },
        killingSpree = "Killing Spree",
        bladeRush = "Blade Rush",
        bladeFlurry = { "Blade Flurry", self = true },
        sinisterStrike = "Sinister Strike",
        pistolShot = "Pistol Shot",
        betweenTheEyes = "Between the Eyes",
        dispatch = "Dispatch",
        ambush = "Ambush",
    },

    buffs = {
        rollTheBones = { duration = 30, castBy = { "rollTheBones" } },
        bladeFlurry = { duration = 10, castBy = { "bladeFlurry" }, auras = { "Blade Flurry" } },
    },

    procs = {
        opportunity = { auras = { "Opportunity" }, glow = { "pistolShot" } },
    },

    prepare = function(s)
        local threshold = s:hero("Fatebound") and 5 or 6
        if s.secondaryMax and s.secondaryMax < threshold then
            threshold = s.secondaryMax
        end
        s.finisher = s:resourceAtLeast(threshold)
    end,

    precombat = {
        { "stealth", when = function(s) return not s:stealthed() end },
    },

    st = {
        { "rollTheBones", when = function(s) return not s:buffUp("rollTheBones") or s:lastCast("keepItRolling") end },
        { "keepItRolling", when = function(s) return s:buffUp("rollTheBones") end },
        { "bladeFlurry", cleave = true, when = function(s) return s:buff("bladeFlurry") < 2 end },
        { "adrenalineRush" },
        { "killingSpree" },
        { "bladeRush" },
        { "betweenTheEyes", when = function(s) return s.finisher end },
        { "dispatch", when = function(s) return s.finisher end },
        { "ambush" },
        { "pistolShot", when = function(s) return s:proc("opportunity") end },
        { "sinisterStrike" },
    },
})
