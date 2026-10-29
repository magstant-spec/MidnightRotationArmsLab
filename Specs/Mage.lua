local addonName, addon = ...

-- Arcane Mage (Method 12.1.5; Spellslinger and Sunfury). Arcane Charges are
-- a readable secondary resource. Arcane Salvo and Cumulative Power stacks are
-- read from the Arcane Barrage / Prismatic Bolt button counts when the client
-- shows them; otherwise the stack conditions fall back to proc glows.
addon:RegisterSpecProfile({
    key = "ARCANE_MAGE",
    class = "MAGE",
    specID = 62,
    specName = "Arcane",
    label = "Arcane",
    melee = false,
    aoeThreshold = 3,
    primaryPower = 0,
    primaryName = "Mana",
    secondaryPower = 16, -- Arcane Charges
    secondaryName = "Arcane Charges",
    rangeSpells = { "arcaneBlast", "arcaneBarrage" },

    spells = {
        arcaneSurge = { "Arcane Surge", major = true },
        touchOfTheMagi = "Touch of the Magi",
        arcaneMissiles = "Arcane Missiles",
        arcaneBarrage = "Arcane Barrage",
        prismaticBolt = "Prismatic Bolt",
        arcaneOrb = { "Arcane Orb", self = true },
        arcanePulse = { "Arcane Pulse", self = true },
        arcaneBlast = "Arcane Blast",
        arcaneExplosion = { "Arcane Explosion", self = true },
    },

    procs = {
        clearcasting = { auras = { "Clearcasting" }, glow = { "arcaneMissiles" } },
        arcaneSoul = { auras = { "Arcane Soul" }, glow = { "arcaneBarrage" } },
    },

    prepare = function(s)
        s.cc = s:proc("clearcasting")
        s.salvo = s:castCount("arcaneBarrage")
        s.cumulative = s:castCount("prismaticBolt")
        s.salvoAtLeast = function(n, unknown)
            if s.salvo == nil then return unknown == true end
            return s.salvo >= n
        end
        s.salvoBelow = function(n, unknown)
            if s.salvo == nil then return unknown == true end
            return s.salvo < n
        end
        s.cumulativeAtLeast = function(n)
            return s.cumulative ~= nil and s.cumulative >= n
        end
        s.needCharges = s:resourceBelow(4, false)
    end,

    st = {
        { "arcaneSurge" },
        { "touchOfTheMagi", when = function(s) return s:lastCast("arcaneBarrage") or s:since("arcaneSurge") < 6 end },
        -- Spellslinger
        { "prismaticBolt", hero = "Spellslinger", when = function(s) return not s.cc or s.cumulativeAtLeast(6) end },
        { "arcaneBarrage", hero = "Spellslinger", when = function(s) return s.salvoAtLeast(20, false) or s:since("arcaneSurge") < 2 end },
        { "arcaneMissiles", hero = "Spellslinger", when = function(s) return s.cc and s.salvoBelow(15, true) end },
        -- Sunfury
        { "arcaneMissiles", hero = "Sunfury", when = function(s) return s.cc and s.salvoBelow(12, true) end },
        { "arcaneBarrage", hero = "Sunfury", when = function(s) return s:proc("arcaneSoul") end },
        { "prismaticBolt", hero = "Sunfury", when = function(s) return s.cumulativeAtLeast(8) and not s:proc("arcaneSoul") end },
        { "arcaneBarrage", hero = "Sunfury", when = function(s) return s.salvoAtLeast(25, false) or (s.cc and s.salvoAtLeast(12, false)) end },
        -- shared
        { "prismaticBolt" },
        { "arcaneOrb", when = function(s) return s.needCharges end },
        { "arcanePulse", when = function(s) return s.needCharges end },
        { "arcaneMissiles", when = function(s) return s.cc end },
        { "arcaneBlast" },
    },

    aoe = {
        { "arcaneSurge" },
        { "touchOfTheMagi", when = function(s) return s:lastCast("arcaneBarrage") or s:since("arcaneSurge") < 6 end },
        { "prismaticBolt", hero = "Spellslinger", when = function(s) return not s.cc or s.cumulativeAtLeast(6) end },
        { "arcaneOrb", hero = "Spellslinger" },
        { "arcaneBarrage", hero = "Spellslinger", when = function(s) return s.salvoAtLeast(20, false) or s:since("arcaneSurge") < 2 end },
        { "arcaneMissiles", hero = "Spellslinger", when = function(s) return s.cc and s.salvoBelow(15, true) end },
        { "arcaneMissiles", hero = "Sunfury", when = function(s) return s.cc and s.salvoBelow(12, true) end },
        { "arcaneBarrage", hero = "Sunfury", when = function(s) return s:proc("arcaneSoul") end },
        { "prismaticBolt", hero = "Sunfury", when = function(s) return s.cumulativeAtLeast(8) and not s:proc("arcaneSoul") end },
        { "arcaneBarrage", hero = "Sunfury", when = function(s) return s.salvoAtLeast(25, false) or (s.cc and s.salvoAtLeast(12, false)) end },
        { "prismaticBolt" },
        { "arcaneOrb" },
        { "arcanePulse", when = function(s) return s.needCharges end },
        { "arcaneMissiles", when = function(s) return s.cc end },
        { "arcaneBlast" },
        { "arcaneExplosion" },
    },
})

-- Fire Mage (Method 12.1.5). Hot Streak shows as a Pyroblast/Flamestrike
-- glow. Heating Up has no glow and is hidden in combat, so Fire Blast is
-- recommended inside Combustion and while banking charges cannot be detected;
-- outside Combustion, press Fire Blast yourself on Heating Up.
addon:RegisterSpecProfile({
    key = "FIRE_MAGE",
    class = "MAGE",
    specID = 63,
    specName = "Fire",
    label = "Fire",
    melee = false,
    aoeThreshold = 5, -- Flamestrike on 5+
    primaryPower = 0,
    primaryName = "Mana",
    rangeSpells = { "fireball", "scorch" },

    spells = {
        combustion = { "Combustion", major = true, self = true },
        fireBlast = "Fire Blast",
        pyroblast = "Pyroblast",
        flamestrike = { "Flamestrike", self = true },
        fireball = { "Fireball", "Frostfire Bolt" },
        scorch = "Scorch",
        meteor = { "Meteor", self = true },
        phoenixFlames = "Phoenix Flames",
    },

    buffs = {
        combustion = { duration = 12, castBy = { "combustion" }, auras = { "Combustion" } },
    },

    procs = {
        hotStreak = { auras = { "Hot Streak!" }, glow = { "pyroblast", "flamestrike" } },
        pyroclasm = { auras = { "Pyroclasm" } },
        heatingUp = { auras = { "Heating Up" } },
    },

    prepare = function(s)
        s.combust = s:buffUp("combustion")
        s.hot = s:proc("hotStreak")
        local combustCd = s:cd("combustion")
        s.combustSoon = combustCd ~= nil and combustCd > 0 and combustCd <= 4
    end,

    st = {
        { "combustion" },
        { "meteor", when = function(s) return s.combust or not s:cdBelow("combustion", 30, false) end },
        { "pyroblast", when = function(s) return s.hot and not s.combustSoon end, note = "Hot Streak" },
        { "fireBlast", when = function(s) return s.combust and not s.hot end },
        { "scorch", when = function(s) return s.combust and not s.hot end },
        { "pyroblast", when = function(s) return s:proc("pyroclasm") and (s.combust and s:buff("combustion") <= 4 or not s.combust) end, note = "Pyroclasm" },
        { "fireBlast", when = function(s) return s:proc("heatingUp") and not s.hot end, note = "Heating Up" },
        { "phoenixFlames" },
        { "scorch", when = function(s) return s:hpBelow(0.3) end },
        { "fireball" },
    },

    aoe = {
        { "combustion" },
        { "meteor" },
        { "flamestrike", when = function(s) return s.hot and not s.combustSoon end, note = "Hot Streak" },
        { "fireBlast", when = function(s) return s.combust and not s.hot end },
        { "scorch", when = function(s) return s.combust and not s.hot end },
        { "fireBlast", when = function(s) return s:proc("heatingUp") and not s.hot end },
        { "phoenixFlames" },
        { "fireball" },
    },
})

-- Frost Mage (Method 12.1.5; Spellslinger and Frostfire). Brain Freeze and
-- Fingers of Frost glow on Flurry and Ice Lance; Icicles are never secret.
addon:RegisterSpecProfile({
    key = "FROST_MAGE",
    class = "MAGE",
    specID = 64,
    specName = "Frost",
    label = "Frost",
    melee = false,
    aoeThreshold = 3,
    primaryPower = 0,
    primaryName = "Mana",
    rangeSpells = { "frostbolt", "iceLance" },

    spells = {
        icyVeins = { "Icy Veins", major = true, self = true },
        frozenOrb = { "Frozen Orb", self = true },
        glacialSpike = "Glacial Spike",
        iceLance = "Ice Lance",
        flurry = "Flurry",
        rayOfFrost = "Ray of Frost",
        frostbolt = { "Frostbolt", "Frostfire Bolt" },
        cometStorm = "Comet Storm",
        blizzard = { "Blizzard", self = true },
    },

    procs = {
        brainFreeze = { auras = { "Brain Freeze" }, glow = { "flurry" } },
        fingersOfFrost = { auras = { "Fingers of Frost" }, glow = { "iceLance" } },
        freezingRain = { auras = { "Freezing Rain" }, glow = { "blizzard" } },
        thermalVoid = { auras = { "Thermal Void" } },
    },

    prepare = function(s)
        s.bf = s:proc("brainFreeze")
        s.fof = s:proc("fingersOfFrost")
        s.tv = s:proc("thermalVoid")
    end,

    st = {
        { "icyVeins" },
        -- Frostfire
        { "glacialSpike", hero = "Frostfire" },
        { "cometStorm", hero = "Frostfire", when = function(s) return s:lastCast("glacialSpike") end },
        -- shared
        { "blizzard", hero = "Spellslinger", aoe = true, when = function(s) return s:proc("freezingRain") end },
        { "flurry", when = function(s) return s.bf and not s.tv end },
        { "iceLance", when = function(s) return s.fof and s:lastCast("flurry") end, note = "2x FoF / Flurry follow-up" },
        { "frozenOrb" },
        { "glacialSpike", hero = "Spellslinger" },
        { "iceLance", when = function(s) return s.fof end },
        { "rayOfFrost", hero = "Frostfire", when = function(s) return s.aoe end },
        { "flurry" },
        { "rayOfFrost", hero = "Spellslinger" },
        { "glacialSpike" },
        { "frostbolt" },
        { "rayOfFrost" },
    },
})
