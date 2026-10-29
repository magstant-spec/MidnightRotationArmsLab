local addonName, addon = ...

-- Havoc Demon Hunter (Method 12.1.5; Aldrachi Reaver and Fel-Scarred lists).
-- Demon form is detected from the Chaos Strike -> Annihilation override, which
-- stays readable in combat.
addon:RegisterSpecProfile({
    key = "HAVOC_DH",
    class = "DEMONHUNTER",
    specID = 577,
    specName = "Havoc",
    label = "Havoc",
    melee = true,
    aoeThreshold = 3,
    primaryPower = 17, -- Fury
    primaryName = "Fury",
    rangeSpells = { "chaosStrike", "bladeDance" },

    spells = {
        theHunt = { "The Hunt", major = true },
        reaversGlaive = "Reaver's Glaive",
        essenceBreak = "Essence Break",
        vengefulRetreat = { "Vengeful Retreat", self = true },
        eyeBeam = { "Eye Beam", self = true },
        abyssalGaze = { "Abyssal Gaze", overrideOf = "eyeBeam" },
        metamorphosis = { "Metamorphosis", major = true },
        bladeDance = { "Blade Dance", self = true },
        deathSweep = { "Death Sweep", overrideOf = "bladeDance" },
        chaosStrike = "Chaos Strike",
        annihilation = { "Annihilation", overrideOf = "chaosStrike" },
        immolationAura = { "Immolation Aura", self = true },
        consumingFire = { "Consuming Fire", overrideOf = "immolationAura" },
        felblade = "Felblade",
        throwGlaive = "Throw Glaive",
    },

    prepare = function(s)
        s.meta = s:known("annihilation") or s:known("deathSweep")
        local charges = s:charges("immolationAura")
        s.immoCapped = charges ~= nil and charges >= 2
    end,

    st = {
        -- Aldrachi Reaver
        { "theHunt", hero = "Aldrachi Reaver", when = function(s) return not s:ready("reaversGlaive") end },
        { "reaversGlaive", hero = "Aldrachi Reaver" },
        -- Fel-Scarred
        { "immolationAura", hero = "Fel-Scarred", when = function(s) return s.immoCapped end, note = "2 charges" },
        -- shared core
        { "essenceBreak" },
        { "vengefulRetreat", when = function(s) return s:ready("eyeBeam") end, note = "pair with Eye Beam" },
        { "eyeBeam" },
        { "deathSweep" },
        { "annihilation", hero = "Fel-Scarred", note = "Demonsurge" },
        { "theHunt", hero = "Fel-Scarred" },
        { "metamorphosis", when = function(s) return not s.meta and (s.aoe and not s:ready("eyeBeam") or not s.aoe) end },
        { "abyssalGaze" },
        { "consumingFire" },
        { "annihilation" },
        { "bladeDance" },
        { "chaosStrike" },
        { "immolationAura" },
        { "felblade" },
        { "throwGlaive" },
    },
})

-- Devourer Demon Hunter (Method 12.1.5; Annihilator and Void-Scarred).
-- Soul counts come from the button count on Reap/Consume when readable;
-- otherwise the soul thresholds fall back to plain usability.
addon:RegisterSpecProfile({
    key = "DEVOURER_DH",
    class = "DEMONHUNTER",
    specID = 1480,
    specName = "Devourer",
    label = "Devourer",
    melee = false,
    aoeThreshold = 3,
    primaryPower = 17, -- Fury
    primaryName = "Fury",
    rangeSpells = { "consume", "voidRay" },

    spells = {
        consume = "Consume",
        devour = { "Devour", overrideOf = "consume" },
        reap = "Reap",
        cull = { "Cull", overrideOf = "reap" },
        eradicate = { "Eradicate", overrideOf = "reap" },
        voidRay = "Void Ray",
        collapsingStar = "Collapsing Star",
        voidMetamorphosis = { "Void Metamorphosis", major = true, self = true },
        soulImmolation = { "Soul Immolation", self = true },
        voidblade = "Voidblade",
        hungeringSlash = "Hungering Slash",
        reapersToll = "Reaper's Toll",
        pierceTheVeil = "Pierce the Veil",
        predatorsWake = "Predator's Wake",
        theHunt = { "The Hunt", major = true },
        vengefulRetreat = { "Vengeful Retreat", self = true },
    },

    procs = {
        soulburst = { auras = { "Soulburst" }, glow = { "consume", "devour" } },
        voidstep = { auras = { "Voidstep" }, glow = { "vengefulRetreat" } },
        momentOfCraving = { auras = { "Moment of Craving" }, glow = { "reap", "cull", "eradicate" } },
    },

    prepare = function(s)
        s.meta = s:known("devour") or s:known("cull")
        s.souls = s:castCount("reap") or s:castCount("cull")
        s.soulsAtLeast = function(n)
            if s.souls == nil then
                return true
            end
            return s.souls >= n
        end
    end,

    st = {
        -- Annihilator
        { "consume", hero = "Annihilator", when = function(s) return not s.meta and s:proc("soulburst") end },
        { "voidRay", hero = "Annihilator", when = function(s) return not s.meta and s:ready("voidMetamorphosis") end, note = "before Meta" },
        { "voidMetamorphosis", hero = "Annihilator" },
        { "devour", hero = "Annihilator", when = function(s) return s:proc("soulburst") end },
        { "eradicate", hero = "Annihilator", when = function(s) return s.soulsAtLeast(4) end },
        { "cull", hero = "Annihilator", when = function(s) return s.soulsAtLeast(4) end },
        { "reap", hero = "Annihilator", when = function(s) return not s.meta and s.soulsAtLeast(4) end },
        { "collapsingStar", hero = "Annihilator" },
        { "voidRay", hero = "Annihilator" },
        -- Void-Scarred
        { "consume", hero = "Void-Scarred", when = function(s) return s:proc("soulburst") end },
        { "reap", hero = "Void-Scarred", when = function(s) return not s.meta and s.soulsAtLeast(4) end },
        { "soulImmolation", hero = "Void-Scarred", when = function(s) return not s.meta end },
        { "voidblade", hero = "Void-Scarred", when = function(s) return not s.meta and s:cdBelow("voidMetamorphosis", 3, true) end },
        { "theHunt", hero = "Void-Scarred", when = function(s) return not s.meta and s:cdBelow("voidMetamorphosis", 3, true) end },
        { "voidMetamorphosis", hero = "Void-Scarred" },
        { "cull", hero = "Void-Scarred", when = function(s) return s.soulsAtLeast(4) end },
        { "reapersToll", hero = "Void-Scarred" },
        { "hungeringSlash", hero = "Void-Scarred" },
        { "vengefulRetreat", hero = "Void-Scarred", when = function(s) return s:proc("voidstep") end },
        { "pierceTheVeil", hero = "Void-Scarred" },
        { "predatorsWake", hero = "Void-Scarred" },
        { "voidRay", hero = "Void-Scarred" },
        { "collapsingStar", hero = "Void-Scarred" },
        -- shared tail
        { "devour" },
        { "consume" },
        { "soulImmolation", when = function(s) return not s.meta end },
    },

    aoe = {
        { "consume", when = function(s) return s:proc("soulburst") end },
        { "devour", when = function(s) return s:proc("soulburst") end },
        { "voidRay", when = function(s) return not s.meta and s:ready("voidMetamorphosis") end, note = "before Meta" },
        { "voidMetamorphosis" },
        { "collapsingStar", hero = "Annihilator" },
        { "reapersToll", hero = "Void-Scarred" },
        { "eradicate", when = function(s) return s:proc("momentOfCraving") or s.soulsAtLeast(8) end },
        { "cull", when = function(s) return s:proc("momentOfCraving") or s.soulsAtLeast(8) end },
        { "voidRay" },
        { "hungeringSlash", hero = "Void-Scarred" },
        { "vengefulRetreat", hero = "Void-Scarred", when = function(s) return s:proc("voidstep") end },
        { "pierceTheVeil", hero = "Void-Scarred" },
        { "predatorsWake", hero = "Void-Scarred" },
        { "collapsingStar" },
        { "cull", when = function(s) return s.soulsAtLeast(4) end },
        { "reap", when = function(s) return s.soulsAtLeast(4) end },
        { "soulImmolation", when = function(s) return not s.meta end },
        { "devour" },
        { "consume" },
    },
})
