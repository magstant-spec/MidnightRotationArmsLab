local addonName, addon = ...

-- Windwalker Monk (Method 12.1.5; Conduit of the Celestials and Shado-Pan).
-- Chi is a readable secondary resource. comboStrikes stops the same ability
-- from being recommended twice in a row (Mastery: Combo Strikes).
addon:RegisterSpecProfile({
    key = "WINDWALKER_MONK",
    class = "MONK",
    specID = 269,
    specName = "Windwalker",
    label = "Windwalker",
    melee = true,
    comboStrikes = true,
    aoeThreshold = 3,
    primaryPower = 3, -- Energy
    primaryName = "Energy",
    secondaryPower = 12, -- Chi
    secondaryName = "Chi",
    rangeSpells = { "tigerPalm", "blackoutKick" },

    spells = {
        tigerPalm = "Tiger Palm",
        invokeXuen = { "Invoke Xuen, the White Tiger", major = true },
        zenith = { "Zenith", major = true, self = true },
        zenithStomp = { "Zenith Stomp", self = true },
        strikeOfTheWindlord = "Strike of the Windlord",
        fistsOfFury = "Fists of Fury",
        risingSunKick = "Rising Sun Kick",
        rushingWindKick = "Rushing Wind Kick",
        whirlingDragonPunch = { "Whirling Dragon Punch", self = true },
        celestialConduit = { "Celestial Conduit", self = true },
        blackoutKick = "Blackout Kick",
        spinningCraneKick = { "Spinning Crane Kick", self = true },
    },

    buffs = {
        zenith = { duration = 15, castBy = { "zenith" }, auras = { "Zenith" } },
    },

    procs = {
        comboBreaker = { auras = { "Blackout Kick!", "Combo Breaker" }, glow = { "blackoutKick" } },
        danceOfChiJi = { auras = { "Dance of Chi-Ji" }, glow = { "spinningCraneKick" } },
    },

    prepare = function(s)
        s.zen = s:buffUp("zenith")
        s.xuenFar = not s:cdBelow("invokeXuen", 10, false)
    end,

    st = {
        { "invokeXuen" },
        { "zenith" },
        { "whirlingDragonPunch", hero = "Shado-Pan" },
        { "whirlingDragonPunch", hero = "Conduit of the Celestials", when = function(s) return s.xuenFar end },
        { "celestialConduit", hero = "Conduit of the Celestials" },
        { "zenithStomp", when = function(s) return s:resourceBelow(2, false) or (s.zen and s:buff("zenith") < 2) end },
        { "strikeOfTheWindlord" },
        { "tigerPalm", when = function(s) return s:resourceBelow(3, false) and s:cdBelow("fistsOfFury", 1, false) end, note = "Chi for Fists" },
        { "fistsOfFury" },
        { "rushingWindKick" },
        { "risingSunKick" },
        { "blackoutKick", when = function(s) return s:proc("comboBreaker") end },
        { "spinningCraneKick", when = function(s) return s.zen and (s:resourceAtLeast(5) or s:proc("danceOfChiJi")) end },
        { "tigerPalm", when = function(s) return s:resourceBelow(2, true) end },
        { "spinningCraneKick", when = function(s) return s:proc("danceOfChiJi") end },
        { "spinningCraneKick", when = function(s) return s.cleave and s:lastCast("fistsOfFury") end },
        { "tigerPalm", when = function(s) local d = s:resourceDeficit() return d == nil or d >= 2 end },
        { "blackoutKick" },
        { "tigerPalm", allowRepeat = true },
    },

    aoe = {
        { "invokeXuen" },
        { "zenith" },
        { "whirlingDragonPunch", when = function(s) return s:hero("Shado-Pan") or s.xuenFar end },
        { "strikeOfTheWindlord", when = function(s) return s:hero("Shado-Pan") or s.xuenFar end },
        { "celestialConduit", hero = "Conduit of the Celestials" },
        { "zenithStomp", when = function(s) return s:resourceBelow(2, false) or (s.zen and s:buff("zenith") < 2) end },
        { "tigerPalm", when = function(s) return s:resourceBelow(3, false) and s:cdBelow("fistsOfFury", 1, false) end },
        { "fistsOfFury" },
        { "spinningCraneKick", when = function(s) return s:lastCast("fistsOfFury") or s:proc("danceOfChiJi") end },
        { "risingSunKick", when = function(s) return s:cdBelow("whirlingDragonPunch", 2, false) end, note = "enable WDP" },
        { "rushingWindKick" },
        { "spinningCraneKick", when = function(s) return s.zen and s.targets >= 5 end },
        { "spinningCraneKick" },
        { "blackoutKick", when = function(s) return s:proc("comboBreaker") end },
        { "tigerPalm", when = function(s) return s:resourceBelow(5, true) and not s.zen end },
        { "risingSunKick" },
        { "blackoutKick" },
        { "tigerPalm", allowRepeat = true },
    },
})
