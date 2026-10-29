local addonName, addon = ...

-- Balance Druid (Method 12.1.5; Keeper of the Grove and Elune's Chosen).
-- Astral Power is hidden in combat; spenders rely on usability and the
-- Starweaver / Touch the Cosmos glows on Starsurge and Starfall.
addon:RegisterSpecProfile({
    key = "BALANCE_DRUID",
    class = "DRUID",
    specID = 102,
    specName = "Balance",
    label = "Balance",
    melee = false,
    aoeThreshold = 2, -- Starfall replaces Starsurge from 2 targets
    primaryPower = 8, -- Astral Power
    primaryName = "Astral Power",
    rangeSpells = { "wrath", "moonfire" },

    spells = {
        moonfire = "Moonfire",
        sunfire = "Sunfire",
        wrath = "Wrath",
        starfire = "Starfire",
        starsurge = "Starsurge",
        starfall = { "Starfall", self = true },
        furyOfElune = "Fury of Elune",
        forceOfNature = { "Force of Nature", self = true },
        celestialAlignment = { "Celestial Alignment", "Incarnation: Chosen of Elune", major = true, self = true },
        convoke = { "Convoke the Spirits", major = true, self = true },
        solarEclipse = { "Solar Eclipse", self = true },
        lunarEclipse = { "Lunar Eclipse", self = true },
        moonkinForm = { "Moonkin Form", self = true },
    },

    dots = {
        moonfire = { duration = 22, castBy = { "moonfire" }, auras = { "Moonfire" } },
        sunfire = { duration = 18, castBy = { "sunfire" }, auras = { "Sunfire" } },
    },

    buffs = {
        eclipse = { duration = 15, castBy = { "solarEclipse", "lunarEclipse", "celestialAlignment" },
            auras = { "Eclipse (Solar)", "Eclipse (Lunar)", "Solar Eclipse", "Lunar Eclipse" } },
        alignment = { duration = 15, castBy = { "celestialAlignment" },
            auras = { "Celestial Alignment", "Incarnation: Chosen of Elune" } },
        forceOfNature = { duration = 10, castBy = { "forceOfNature" } },
    },

    procs = {
        starweaver = { auras = { "Starweaver's Warp", "Starweaver's Weft", "Touch the Cosmos" }, glow = { "starfall", "starsurge" } },
    },

    prepare = function(s)
        s.eclipseUp = s:buffUp("eclipse")
        s.alignmentUp = s:buffUp("alignment")
        s.lunarFiller = s.targets >= 4 or s:hero("Elune's Chosen")
    end,

    precombat = {
        { "moonkinForm", when = function(s) return GetShapeshiftFormID and GetShapeshiftFormID() ~= 31 end },
    },

    st = {
        { "moonfire", when = function(s) return s:refreshable("moonfire") end },
        { "sunfire", when = function(s) return s:refreshable("sunfire") end },
        { "forceOfNature", when = function(s) return s.eclipseUp or s.alignmentUp end },
        { "furyOfElune", when = function(s) return s.eclipseUp or s:buffUp("forceOfNature") end },
        { "celestialAlignment" },
        { "convoke", when = function(s) return s.alignmentUp end },
        { "solarEclipse", when = function(s) return not s.eclipseUp and not s.lunarFiller end },
        { "lunarEclipse", when = function(s) return not s.eclipseUp and s.lunarFiller end },
        { "starfall", when = function(s) return s:proc("starweaver") end },
        { "starsurge" },
        { "wrath", when = function(s) return not s.lunarFiller end },
        { "starfire" },
        { "wrath" },
    },

    aoe = {
        { "moonfire", when = function(s) return s:refreshable("moonfire") end },
        { "sunfire", when = function(s) return s:refreshable("sunfire") end },
        { "celestialAlignment", when = function(s) return not s.eclipseUp end },
        { "furyOfElune" },
        { "forceOfNature" },
        { "convoke", when = function(s) return s.alignmentUp end },
        { "lunarEclipse", when = function(s) return not s.eclipseUp and s.lunarFiller end },
        { "solarEclipse", when = function(s) return not s.eclipseUp and not s.lunarFiller end },
        { "starfall", when = function(s) return s:proc("starweaver") end },
        { "starfall" },
        { "starfire", when = function(s) return s.lunarFiller end },
        { "wrath" },
        { "starfire" },
    },
})

-- Feral Druid (Method 12.1.5; Wildstalker and Druid of the Claw).
addon:RegisterSpecProfile({
    key = "FERAL_DRUID",
    class = "DRUID",
    specID = 103,
    specName = "Feral",
    label = "Feral",
    melee = true,
    aoeThreshold = 2,
    primaryPower = 3, -- Energy
    primaryName = "Energy",
    secondaryPower = 4, -- Combo Points
    secondaryName = "Combo Points",
    rangeSpells = { "shred", "rake" },

    spells = {
        catForm = { "Cat Form", self = true },
        prowl = { "Prowl", self = true },
        tigersFury = { "Tiger's Fury", self = true },
        berserk = { "Berserk", "Incarnation: Avatar of Ashamane", major = true, self = true },
        feralFrenzy = "Feral Frenzy",
        franticFrenzy = "Frantic Frenzy",
        convoke = { "Convoke the Spirits", major = true, self = true },
        ferociousBite = "Ferocious Bite",
        rip = "Rip",
        primalWrath = { "Primal Wrath", self = true },
        shred = "Shred",
        rake = "Rake",
        moonfire = "Moonfire",
        swipe = { "Swipe", "Brutal Slash", self = true },
    },

    dots = {
        rake = { duration = 15, castBy = { "rake" }, auras = { "Rake" } },
        rip = { duration = 24, castBy = { "rip", "primalWrath" }, auras = { "Rip" } },
        moonfire = { duration = 16, castBy = { "moonfire" }, auras = { "Moonfire" } },
    },

    buffs = {
        tigersFury = { duration = 10, castBy = { "tigersFury" }, auras = { "Tiger's Fury" } },
        berserk = { duration = 15, castBy = { "berserk" }, auras = { "Berserk", "Incarnation: Avatar of Ashamane" } },
    },

    procs = {
        apex = { auras = { "Apex Predator's Craving" }, glow = { "ferociousBite" } },
        suddenAmbush = { auras = { "Sudden Ambush" }, glow = { "shred", "rake" } },
        clearcasting = { auras = { "Clearcasting" }, glow = { "swipe" } },
    },

    prepare = function(s)
        s.finisher = s:resourceAtLeast(5)
        s.convokeReady = s:dotUp("rip") and s:dot("rip") > 4 and s:buffUp("tigersFury")
            and (s:buffUp("berserk") or s:talent("Ashamane's Guidance"))
    end,

    precombat = {
        { "catForm", when = function(s) return GetShapeshiftFormID and GetShapeshiftFormID() ~= 1 end },
        { "prowl", when = function(s) return not s:stealthed() end },
    },

    st = {
        { "tigersFury" },
        { "berserk" },
        { "feralFrenzy", when = function(s) return s:resourceBelow(3, true) end },
        { "convoke", when = function(s) return s.convokeReady end },
        { "ferociousBite", when = function(s) return s:proc("apex") end },
        { "rip", when = function(s) return s.finisher and s:refreshable("rip") end },
        { "ferociousBite", when = function(s) return s.finisher and s:powerAtLeast(50, true) end },
        { "shred", when = function(s) return s:proc("suddenAmbush") end },
        { "rake", when = function(s) return s:refreshable("rake") end },
        { "moonfire", talent = "Lunar Inspiration", when = function(s) return s:refreshable("moonfire") end },
        { "shred", when = function(s) return not s.finisher end },
        { "shred" },
    },

    aoe = {
        { "tigersFury" },
        { "berserk" },
        { "franticFrenzy" },
        { "feralFrenzy", when = function(s) return s:resourceBelow(3, true) end },
        { "convoke", when = function(s) return s.convokeReady end },
        { "ferociousBite", when = function(s) return s:proc("apex") end },
        { "primalWrath", when = function(s) return s.finisher and s:dot("rip") < 6.5 end },
        { "ferociousBite", when = function(s) return s.finisher and s:powerAtLeast(50, true) end },
        { "swipe", hero = "Druid of the Claw", when = function(s) return s:buffUp("berserk") end },
        { "swipe", when = function(s) return s:proc("clearcasting") end },
        { "rake", when = function(s) return s:refreshable("rake") end },
        { "swipe" },
        { "shred" },
    },
})
