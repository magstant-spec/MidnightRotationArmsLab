local addonName, addon = ...

-- Elemental Shaman (Method 12.1.5; Farseer and Stormbringer). Maelstrom is
-- hidden in combat; Master of the Elements is inferred from Lava Burst casts.
addon:RegisterSpecProfile({
    key = "ELEMENTAL_SHAMAN",
    class = "SHAMAN",
    specID = 262,
    specName = "Elemental",
    label = "Elemental",
    melee = false,
    aoeThreshold = 3,
    primaryPower = 11, -- Maelstrom
    primaryName = "Maelstrom",
    rangeSpells = { "lightningBolt", "flameShock" },

    spells = {
        stormkeeper = { "Stormkeeper", self = true },
        ancestralSwiftness = { "Ancestral Swiftness", self = true },
        ascendance = { "Ascendance", major = true, self = true },
        fireElemental = { "Fire Elemental", major = true, self = true },
        flameShock = "Flame Shock",
        voltaicBlaze = "Voltaic Blaze",
        elementalBlast = "Elemental Blast",
        earthShock = "Earth Shock",
        lavaBurst = "Lava Burst",
        lightningBolt = "Lightning Bolt",
        chainLightning = "Chain Lightning",
        earthquake = { "Earthquake", self = true },
    },

    dots = {
        flameShock = { duration = 18, castBy = { "flameShock", "voltaicBlaze" }, auras = { "Flame Shock" } },
    },

    buffs = {
        masterOfTheElements = { duration = 15, castBy = { "lavaBurst" },
            consumedBy = { "lightningBolt", "chainLightning", "elementalBlast", "earthShock", "earthquake" },
            auras = { "Master of the Elements" } },
        fireElemental = { duration = 30, castBy = { "fireElemental" } },
    },

    procs = {
        lavaSurge = { auras = { "Lava Surge" }, glow = { "lavaBurst" } },
    },

    prepare = function(s)
        s.motE = s:buffUp("masterOfTheElements")
        s.shockWindow = s:buffUp("fireElemental") and 3 or 6
        s.spender = s:known("elementalBlast") and "elementalBlast" or "earthShock"
        s.nearCap = s:powerDeficitBelow(15, false)
    end,

    st = {
        { "stormkeeper" },
        { "ancestralSwiftness" },
        { "ascendance" },
        { "fireElemental" },
        { "voltaicBlaze", when = function(s) return s:refreshable("flameShock", s.shockWindow) end },
        { "flameShock", when = function(s) return s:refreshable("flameShock", s.shockWindow) end },
        { "voltaicBlaze", cleave = true },
        { "elementalBlast", when = function(s) return s.nearCap end },
        { "earthShock", when = function(s) return s.nearCap end },
        { "lavaBurst", when = function(s) return not s.motE end },
        { "elementalBlast", when = function(s) return s.motE end },
        { "earthShock", when = function(s) return s.motE end },
        { "chainLightning", cleave = true },
        { "lightningBolt" },
        { "lavaBurst", when = function(s) return s:proc("lavaSurge") end },
    },

    aoe = {
        { "stormkeeper" },
        { "ancestralSwiftness" },
        { "voltaicBlaze" },
        { "ascendance" },
        { "fireElemental" },
        { "flameShock", when = function(s) return not s:dotUp("flameShock") end },
        { "lavaBurst", when = function(s) return s:proc("lavaSurge") end },
        { "earthquake" },
        { "elementalBlast", when = function(s) return s.nearCap end },
        { "chainLightning" },
    },
})

-- Enhancement Shaman (Method 12.1.5; Stormbringer and Totemic). Maelstrom
-- Weapon is a never-secret aura, so its stacks are read directly.
addon:RegisterSpecProfile({
    key = "ENHANCEMENT_SHAMAN",
    class = "SHAMAN",
    specID = 263,
    specName = "Enhancement",
    label = "Enhancement",
    melee = true,
    aoeThreshold = 2, -- Chain Lightning replaces Lightning Bolt
    primaryPower = 0,
    primaryName = "Mana",
    rangeSpells = { "stormstrike", "lavaLash" },

    spells = {
        voltaicBlaze = "Voltaic Blaze",
        ascendance = { "Ascendance", major = true, self = true },
        doomWinds = { "Doom Winds", major = true, self = true },
        surgingTotem = { "Surging Totem", self = true },
        sundering = "Sundering",
        crashLightning = { "Crash Lightning", self = true },
        stormstrike = { "Stormstrike", "Windstrike" },
        lavaLash = "Lava Lash",
        primordialStorm = "Primordial Storm",
        tempest = { "Tempest", overrideOf = "lightningBolt" },
        lightningBolt = "Lightning Bolt",
        chainLightning = "Chain Lightning",
    },

    buffs = {
        doomWinds = { duration = 8, castBy = { "doomWinds" }, auras = { "Doom Winds" } },
    },

    procs = {
        hotHand = { auras = { "Hot Hand" }, glow = { "lavaLash" } },
        mw5 = { glow = { "lightningBolt", "chainLightning" } },
    },

    prepare = function(s)
        local stacks = s:auraStacks("Maelstrom Weapon")
        s.mw = stacks
        s.mwAtLeast = function(n)
            if s.mw ~= nil then
                return s.mw >= n
            end
            -- Hidden: the spender glow appears from 5 stacks.
            return n <= 5 and s:proc("mw5")
        end
        s.spender = s.cleave and "chainLightning" or "lightningBolt"
    end,

    st = {
        { "voltaicBlaze" },
        { "surgingTotem", hero = "Totemic" },
        { "ascendance", hero = "Stormbringer" },
        { "sundering", hero = "Totemic" },
        { "lavaLash", hero = "Totemic", when = function(s) return s:proc("hotHand") end },
        { "doomWinds" },
        { "crashLightning" },
        { "primordialStorm", hero = "Totemic", when = function(s) return s.mwAtLeast(10) end },
        { "stormstrike", when = function(s) return s:buffUp("doomWinds") end },
        { "tempest", when = function(s) return s.mwAtLeast(10) end },
        { "chainLightning", cleave = true, when = function(s) return s.mwAtLeast(10) end },
        { "lightningBolt", when = function(s) return s.mwAtLeast(10) end },
        { "stormstrike", hero = "Stormbringer" },
        { "lavaLash" },
        { "stormstrike" },
        { "chainLightning", cleave = true, when = function(s) return s.mwAtLeast(5) end },
        { "lightningBolt", when = function(s) return s.mwAtLeast(5) end },
        { "sundering" },
    },
})
