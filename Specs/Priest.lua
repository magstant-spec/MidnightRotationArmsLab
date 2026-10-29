local addonName, addon = ...

-- Shadow Priest (Method 12.1.5; Archon and Voidweaver). DoT timers are
-- inferred from your own casts per target; Insanity is hidden in combat so
-- the "about to cap" spend uses the usability band.
addon:RegisterSpecProfile({
    key = "SHADOW_PRIEST",
    class = "PRIEST",
    specID = 258,
    specName = "Shadow",
    label = "Shadow",
    melee = false,
    aoeThreshold = 3,
    primaryPower = 13, -- Insanity
    primaryName = "Insanity",
    rangeSpells = { "mindBlast", "shadowWordPain" },

    spells = {
        shadowform = { "Shadowform", self = true },
        shadowWordPain = "Shadow Word: Pain",
        vampiricTouch = "Vampiric Touch",
        tentacleSlam = "Tentacle Slam",
        halo = { "Halo", self = true },
        voidform = { "Voidform", major = true, self = true },
        powerInfusion = { "Power Infusion", major = true, self = true },
        shadowWordMadness = "Shadow Word: Madness",
        mindBlast = "Mind Blast",
        voidBlast = { "Void Blast", overrideOf = "mindBlast" },
        mindFlay = "Mind Flay",
        mindFlayInsanity = { "Mind Flay: Insanity", overrideOf = "mindFlay" },
        shadowWordDeath = "Shadow Word: Death",
        voidVolley = "Void Volley",
        voidTorrent = "Void Torrent",
    },

    dots = {
        swp = { duration = 21, castBy = { "shadowWordPain" }, auras = { "Shadow Word: Pain" } },
        vt = { duration = 21, castBy = { "vampiricTouch", "tentacleSlam" }, auras = { "Vampiric Touch" } },
        madness = { duration = 6, castBy = { "shadowWordMadness" }, auras = { "Shadow Word: Madness" } },
    },

    buffs = {
        entropicRift = { duration = 8, castBy = { "voidTorrent" }, auras = { "Entropic Rift" } },
    },

    procs = {
        shadowform = { auras = { "Shadowform", "Voidform" } },
    },

    prepare = function(s)
        s.madnessUp = s:dotUp("madness")
    end,

    precombat = {
        { "shadowform", when = function(s) return not s:proc("shadowform") end },
    },

    st = {
        { "shadowWordPain", talent = "Invoked Nightmare", when = function(s) return not s:dotUp("swp") end },
        { "tentacleSlam", when = function(s) return not s:dotUp("vt") end },
        { "vampiricTouch", when = function(s) return s:refreshable("vt") end },
        { "halo", hero = "Archon" },
        { "voidform" },
        { "powerInfusion" },
        { "shadowWordMadness", when = function(s) return s:refreshable("madness", 2) or s:powerAtLeast(80, false) end },
        { "voidVolley", hero = "Voidweaver" },
        { "voidBlast", hero = "Voidweaver", when = function(s) return s.madnessUp or (s:buffUp("entropicRift") and s:buff("entropicRift") < 2) end },
        { "voidTorrent", hero = "Voidweaver" },
        { "mindBlast" },
        { "tentacleSlam" },
        { "mindFlayInsanity", hero = "Archon", when = function(s) return s.madnessUp end },
        { "shadowWordDeath", when = function(s) return s:hpBelow(0.2) end },
        { "voidVolley" },
        { "voidBlast" },
        { "mindFlay" },
    },

    aoe = {
        { "tentacleSlam", when = function(s) return not s:dotUp("vt") end },
        { "vampiricTouch", when = function(s) return s:refreshable("vt") end },
        { "shadowWordPain", talent = "Invoked Nightmare", when = function(s) return not s:dotUp("swp") end },
        { "halo", hero = "Archon" },
        { "voidform" },
        { "powerInfusion" },
        { "shadowWordMadness", when = function(s) return s:refreshable("madness", 2) or s:powerAtLeast(80, false) end },
        { "voidVolley" },
        { "voidBlast", hero = "Voidweaver", when = function(s) return s.madnessUp end },
        { "voidTorrent", hero = "Voidweaver" },
        { "tentacleSlam" },
        { "mindBlast" },
        { "mindFlayInsanity", when = function(s) return s.madnessUp end },
        { "shadowWordDeath", when = function(s) return s:hpBelow(0.2) end },
        { "mindFlay" },
    },
})
