local addonName, addon = ...

-- Marksmanship Hunter (Method 12.1.5; Dark Ranger and Sentinel). Precise
-- Shots and Deathblow are read from the spender glows.
addon:RegisterSpecProfile({
    key = "MARKSMANSHIP_HUNTER",
    class = "HUNTER",
    specID = 254,
    specName = "Marksmanship",
    label = "Marksmanship",
    melee = false,
    aoeThreshold = 3, -- Trick Shots
    primaryPower = 2, -- Focus
    primaryName = "Focus",
    rangeSpells = { "steadyShot", "aimedShot" },

    spells = {
        huntersMark = "Hunter's Mark",
        aimedShot = "Aimed Shot",
        blackArrow = "Black Arrow",
        explosiveShot = "Explosive Shot",
        volley = "Volley",
        trueshot = { "Trueshot", major = true, self = true },
        rapidFire = "Rapid Fire",
        wailingArrow = "Wailing Arrow",
        arcaneShot = "Arcane Shot",
        multiShot = "Multi-Shot",
        killShot = "Kill Shot",
        steadyShot = "Steady Shot",
        moonlightChakram = "Moonlight Chakram",
    },

    dots = {
        huntersMark = { duration = 3600, castBy = { "huntersMark" }, auras = { "Hunter's Mark" } },
    },

    buffs = {
        trueshot = { duration = 15, castBy = { "trueshot" }, auras = { "Trueshot" } },
        trickShots = { duration = 6, castBy = { "multiShot", "volley" }, consumedBy = { "aimedShot", "rapidFire" }, auras = { "Trick Shots" } },
    },

    procs = {
        preciseShots = { auras = { "Precise Shots" }, glow = { "arcaneShot", "multiShot", "killShot" } },
        deathblow = { auras = { "Deathblow" }, glow = { "blackArrow", "killShot" } },
    },

    prepare = function(s)
        s.precise = s:proc("preciseShots")
        s.trueshotUp = s:buffUp("trueshot")
        s.trick = s:buffUp("trickShots")
    end,

    precombat = {
        { "huntersMark", when = function(s) return not s:dotUp("huntersMark") end },
    },

    st = {
        -- Dark Ranger
        { "blackArrow", hero = "Dark Ranger", when = function(s) return s.precise or s:proc("deathblow") end },
        { "explosiveShot" },
        { "volley" },
        { "aimedShot", hero = "Dark Ranger", when = function(s) return s.trueshotUp or (not s.precise and s:ready("blackArrow")) end },
        { "trueshot" },
        -- Sentinel
        { "moonlightChakram", hero = "Sentinel", when = function(s) return s.trueshotUp and s:buff("trueshot") < 4 end },
        { "aimedShot", hero = "Sentinel", when = function(s) return s.trueshotUp and not s.precise end },
        { "rapidFire", hero = "Sentinel", when = function(s) return not s.precise or s.trueshotUp end },
        { "killShot", hero = "Sentinel", when = function(s) return s.precise end },
        -- shared
        { "rapidFire" },
        { "wailingArrow" },
        { "multiShot", when = function(s) return s.precise and s.cleave and s:talent("Aspect of the Hydra") end },
        { "arcaneShot", when = function(s) return s.precise end },
        { "aimedShot" },
        { "moonlightChakram", hero = "Sentinel" },
        { "killShot" },
        { "steadyShot" },
    },

    aoe = {
        { "explosiveShot" },
        { "volley" },
        { "aimedShot", hero = "Dark Ranger", when = function(s) return s.trick and not s.precise and s:ready("blackArrow") end },
        { "blackArrow", hero = "Dark Ranger", when = function(s) return s.precise or s:proc("deathblow") end },
        { "multiShot", when = function(s) return not s.trick end, note = "apply Trick Shots" },
        { "trueshot" },
        { "moonlightChakram", hero = "Sentinel", when = function(s) return s.trueshotUp and s:buff("trueshot") < 4 end },
        { "multiShot", hero = "Sentinel", when = function(s) return s.precise end },
        { "rapidFire", when = function(s) return s.trick end },
        { "wailingArrow" },
        { "multiShot", when = function(s) return s.precise end },
        { "aimedShot", when = function(s) return s.trick end },
        { "moonlightChakram", hero = "Sentinel" },
        { "multiShot" },
        { "steadyShot" },
    },
})

-- Survival Hunter (Method 12.1.5; Pack Leader and Sentinel). Tip of the Spear
-- is one of Midnight's never-secret auras, so its stacks are read directly.
addon:RegisterSpecProfile({
    key = "SURVIVAL_HUNTER",
    class = "HUNTER",
    specID = 255,
    specName = "Survival",
    label = "Survival",
    melee = true,
    aoeThreshold = 2,
    primaryPower = 2, -- Focus
    primaryName = "Focus",
    rangeSpells = { "raptorStrike" },

    spells = {
        huntersMark = "Hunter's Mark",
        killCommand = "Kill Command",
        wildfireBomb = "Wildfire Bomb",
        takedown = { "Takedown", major = true },
        boomstick = "Boomstick",
        moonlightChakram = "Moonlight Chakram",
        flamefangPitch = "Flamefang Pitch",
        raptorSwipe = "Raptor Swipe",
        raptorStrike = { "Raptor Strike", "Mongoose Bite" },
    },

    dots = {
        huntersMark = { duration = 3600, castBy = { "huntersMark" }, auras = { "Hunter's Mark" } },
    },

    procs = {
        howl = { auras = { "Howl of the Pack Leader" }, glow = { "killCommand" } },
        sentinelsMark = { auras = { "Sentinel's Mark" }, glow = { "wildfireBomb" } },
    },

    prepare = function(s)
        local tip = s:auraStacks("Tip of the Spear")
        s.tip = tip or 0
        s.tipKnown = tip ~= nil
    end,

    precombat = {
        { "huntersMark", when = function(s) return not s:dotUp("huntersMark") end },
    },

    st = {
        { "killCommand", hero = "Pack Leader", when = function(s) return s:proc("howl") end },
        { "killCommand", when = function(s) return s.tip < 3 end },
        { "wildfireBomb", hero = "Sentinel", when = function(s) return s:proc("sentinelsMark") end },
        { "takedown" },
        { "boomstick" },
        { "moonlightChakram", hero = "Sentinel" },
        { "wildfireBomb", hero = "Pack Leader", when = function(s) return s.tip > 0 end },
        { "flamefangPitch" },
        { "raptorSwipe", when = function(s) return s.tip > 0 end },
        { "raptorStrike" },
        { "killCommand" },
        { "wildfireBomb" },
    },

    aoe = {
        { "killCommand", hero = "Pack Leader", when = function(s) return s:proc("howl") end },
        { "killCommand", when = function(s) return s.tip < 3 end },
        { "boomstick" },
        { "wildfireBomb", hero = "Sentinel", when = function(s) return s:proc("sentinelsMark") end },
        { "takedown" },
        { "moonlightChakram", hero = "Sentinel" },
        { "flamefangPitch" },
        { "wildfireBomb" },
        { "raptorSwipe", when = function(s) return s.tip > 0 end },
        { "raptorStrike" },
        { "killCommand" },
    },
})
