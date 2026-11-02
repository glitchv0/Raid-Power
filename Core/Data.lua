-- Data.lua: every buff RaidPower knows, by spell ID (lowest rank first). Vanilla IDs, plus the Forever-only
-- IDs observed in shipping Forever addons (Fel Armor 403619, Water Shield 408510, Trueshot 1299346/1299348).
local _, RP = ...

RP.CLASSES = { "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "HUNTER", "DRUID", "SHAMAN", "PALADIN" }
RP.CLASS_INDEX = {}
for i, c in ipairs(RP.CLASSES) do RP.CLASS_INDEX[c] = i end

-- Buffer classes and the assignment tabs they get.
RP.BUFFER_CLASSES = { "PALADIN", "PRIEST", "MAGE", "DRUID", "SHAMAN" }

-- Group buffs, assigned per raid subgroup (scope "group") or per player (scope "tanks").
RP.FAMILIES = {
    { key = "fort", class = "PRIEST", scope = "group", code = "f", label = "Fortitude",
        single = { 1243, 1244, 1245, 2791, 10937, 10938 }, group = { 21562, 21564 }, reagents = { 17028, 17029 } },
    { key = "spirit", class = "PRIEST", scope = "group", code = "s", label = "Spirit",
        single = { 14752, 14818, 14819, 27841 }, group = { 27681 }, reagents = { 17029 },
        skip = { WARRIOR = true, ROGUE = true } },
    { key = "shadow", class = "PRIEST", scope = "group", code = "p", label = "Shadow Prot.", optional = true,
        single = { 976, 10957, 10958 }, group = { 27683 }, reagents = { 17029 } },
    { key = "int", class = "MAGE", scope = "group", code = "i", label = "Intellect",
        single = { 1459, 1460, 1461, 10156, 10157 }, group = { 23028 }, reagents = { 17020 },
        skip = { WARRIOR = true, ROGUE = true } },
    { key = "motw", class = "DRUID", scope = "group", code = "m", label = "Mark",
        single = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 }, group = { 21849, 21850 }, reagents = { 17021, 17026 } },
    { key = "thorns", class = "DRUID", scope = "tanks", code = "t", label = "Thorns",
        single = { 467, 782, 1075, 8914, 9756, 9910 } },
}

-- Paladin blessings (assigned per class, with per-player overrides). Codes travel in sync messages.
RP.BLESSINGS = {
    { key = "kings", code = "k", label = "Kings", ranks = { 20217 }, greater = { 25898 } },
    { key = "might", code = "m", label = "Might", ranks = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, greater = { 25782, 25916 } },
    { key = "wisdom", code = "w", label = "Wisdom", ranks = { 19742, 19850, 19852, 19853, 19854, 25290 }, greater = { 25894, 25918 } },
    { key = "light", code = "l", label = "Light", ranks = { 19977, 19978, 19979 }, greater = { 25890 } },
    { key = "sanctuary", code = "y", label = "Sanctuary", ranks = { 20911, 20912, 20913, 20914 }, greater = { 25899 } },
}
RP.SALVATION = { key = "salvation", code = "v", label = "Salvation", ranks = { 1038 }, greater = { 25895 } }
RP.SYMBOL_OF_KINGS = 21177

RP.AURAS = {
    { key = "devotion", code = "D", label = "Devotion", ranks = { 465, 10290, 643, 10291, 1032, 10292, 10293 } },
    { key = "retribution", code = "R", label = "Retribution", ranks = { 7294, 10298, 10299, 10300, 10301 } },
    { key = "concentration", code = "C", label = "Concentration", ranks = { 19746 } },
    { key = "shadowres", code = "S", label = "Shadow Res.", ranks = { 19876, 19895, 19896 } },
    { key = "frostres", code = "F", label = "Frost Res.", ranks = { 19888, 19897, 19898 } },
    { key = "fireres", code = "I", label = "Fire Res.", ranks = { 19891, 19899, 19900 } },
    { key = "sanctity", code = "T", label = "Sanctity", ranks = { 20218 } },
}
RP.FURY = { key = "fury", label = "Righteous Fury", ranks = { 25780 } }

-- Blessing priority per class for Auto-assign (most wanted first).
RP.BLESS_PRIORITY = {
    WARRIOR = { "kings", "might", "light", "sanctuary" },
    ROGUE = { "kings", "might", "light", "sanctuary" },
    HUNTER = { "kings", "might", "wisdom", "light" },
    PRIEST = { "kings", "wisdom", "light", "sanctuary" },
    MAGE = { "kings", "wisdom", "light", "sanctuary" },
    WARLOCK = { "kings", "wisdom", "light", "sanctuary" },
    DRUID = { "kings", "wisdom", "might", "light" },
    SHAMAN = { "kings", "wisdom", "might", "light" },
    PALADIN = { "kings", "wisdom", "might", "light" },
}

-- Self-buffs per class. `options` are alternatives: any one of them counts as up; the chosen (or first known)
-- one is what a click casts. `weapon` families track temporary weapon enchants instead of auras.
RP.SELF = {
    WARRIOR = {
        { key = "battleShout", label = "Battle Shout", options = { { label = "Battle Shout", ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 } } } },
    },
    MAGE = {
        { key = "mageArmor", label = "Armor", options = {
            { label = "Mage Armor", ids = { 6117, 22782, 22783 } },
            { label = "Ice Armor", ids = { 7302, 7320, 10219, 10220 } },
            { label = "Frost Armor", ids = { 168, 7300, 7301 } } } },
    },
    WARLOCK = {
        { key = "lockArmor", label = "Armor", options = {
            { label = "Fel Armor", ids = { 403619 } },
            { label = "Demon Armor", ids = { 706, 1086, 11733, 11734, 11735 } },
            { label = "Demon Skin", ids = { 687, 696 } } } },
    },
    PRIEST = {
        { key = "innerFire", label = "Inner Fire", options = { { label = "Inner Fire", ids = { 588, 7128, 602, 1006, 10951, 10952 } } } },
    },
    HUNTER = {
        { key = "aspect", label = "Aspect", own = true, options = {
            { label = "Aspect of the Hawk", ids = { 13165, 14318, 14319, 14320, 14321, 14322, 25296 } },
            { label = "Aspect of the Monkey", ids = { 13163 } },
            { label = "Aspect of the Wild", ids = { 20043, 20190 } },
            { label = "Aspect of the Pack", ids = { 13159 } },
            { label = "Aspect of the Cheetah", ids = { 5118 } },
            { label = "Aspect of the Beast", ids = { 13161 } },
            { label = "Forever aspect", ids = { 1299445, 1299446, 1299447 } } } },
        { key = "trueshot", label = "Trueshot Aura", options = { { label = "Trueshot Aura", ids = { 19506, 20905, 20906, 1299346, 1299348 } } } },
    },
    SHAMAN = {
        { key = "shield", label = "Shield", options = {
            { label = "Lightning Shield", ids = { 324, 325, 905, 945, 8134, 10431, 10432 } },
            { label = "Water Shield", ids = { 408510 } } } },
        { key = "imbue", label = "Weapon Imbue", weapon = 16, options = {
            { label = "Windfury Weapon", ids = { 8232, 8235, 10486, 16362 } },
            { label = "Flametongue Weapon", ids = { 8024, 8027, 8030, 16339, 16341, 16342 } },
            { label = "Frostbrand Weapon", ids = { 8033, 8038, 10456, 16355, 16356 } },
            { label = "Rockbiter Weapon", ids = { 8017, 8018, 8019, 10399, 16314, 16315, 16316 } } } },
    },
    ROGUE = {
        { key = "poisonMH", label = "Main-hand Poison", weapon = 16, items = { 8928, 8927, 8926, 6950, 6949, 6947, 20844, 8985, 8984, 2893, 2892, 10922, 10921, 10920, 10918, 3776, 3775, 9186, 6951, 5237 } },
        { key = "poisonOH", label = "Off-hand Poison", weapon = 17, items = { 8928, 8927, 8926, 6950, 6949, 6947, 20844, 8985, 8984, 2893, 2892, 10922, 10921, 10920, 10918, 3776, 3775, 9186, 6951, 5237 } },
    },
    PALADIN = {
        { key = "aura", label = "Aura", paladinAura = true },
        { key = "fury", label = "Righteous Fury", tankOnly = true, options = { { label = "Righteous Fury", ids = { 25780 } } } },
    },
    DRUID = {
        { key = "omen", label = "Omen of Clarity", options = { { label = "Omen of Clarity", ids = { 16864 } } } },
    },
}

-- Shaman totems: shown on the assignment page so shamans can split elements per group (plan only, not tracked).
RP.TOTEMS = {
    earth = { { key = "soe", id = 8075 }, { key = "stoneskin", id = 8071 }, { key = "tremor", id = 8143 } },
    air = { { key = "windfury", id = 8512 }, { key = "goa", id = 8835 }, { key = "tranquil", id = 25908 },
        { key = "natureres", id = 10595 }, { key = "grounding", id = 8177 } },
    water = { { key = "manaspring", id = 5675 }, { key = "healing", id = 5394 }, { key = "poison", id = 8166 },
        { key = "disease", id = 8170 }, { key = "fireres", id = 8184 } },
    fire = { { key = "frostres", id = 8181 }, { key = "searing", id = 3599 }, { key = "flametongue", id = 8227 } },
}
RP.TOTEM_ELEMENTS = { "earth", "air", "water", "fire" }

RP.CLASS_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, ROGUE = { 1.00, 0.96, 0.41 }, PRIEST = { 1.00, 1.00, 1.00 },
    MAGE = { 0.41, 0.80, 0.94 }, WARLOCK = { 0.58, 0.51, 0.79 }, HUNTER = { 0.67, 0.83, 0.45 },
    DRUID = { 1.00, 0.49, 0.04 }, SHAMAN = { 0.00, 0.44, 0.87 }, PALADIN = { 0.96, 0.55, 0.73 },
}
RP.CLASS_SHORT = { WARRIOR = "War", ROGUE = "Rog", PRIEST = "Pri", MAGE = "Mag", WARLOCK = "Lck",
    HUNTER = "Hun", DRUID = "Dru", SHAMAN = "Sha", PALADIN = "Pal" }

-- Indexes ---------------------------------------------------------------------------------------------
RP.FAMILY_BY_KEY, RP.FAMILY_BY_CODE = {}, {}
RP.BLESS_BY_KEY, RP.BLESS_BY_CODE = {}, {}
RP.AURA_BY_KEY, RP.AURA_BY_CODE = {}, {}
RP.SPELL_FAMILY = {}   -- spellID -> tracking key (family key, blessing key, "salvation", aura key, self key)
RP.GROUP_SPELL = {}    -- spellID -> true for group/greater versions

local function Track(ids, key, group)
    for _, id in ipairs(ids or {}) do
        RP.SPELL_FAMILY[id] = key
        if group then RP.GROUP_SPELL[id] = true end
    end
end

for _, f in ipairs(RP.FAMILIES) do
    RP.FAMILY_BY_KEY[f.key], RP.FAMILY_BY_CODE[f.code] = f, f
    Track(f.single, f.key); Track(f.group, f.key, true)
end
for _, b in ipairs(RP.BLESSINGS) do
    RP.BLESS_BY_KEY[b.key], RP.BLESS_BY_CODE[b.code] = b, b
    Track(b.ranks, b.key); Track(b.greater, b.key, true)
end
RP.BLESS_BY_KEY.salvation = RP.SALVATION
Track(RP.SALVATION.ranks, "salvation"); Track(RP.SALVATION.greater, "salvation", true)
for _, a in ipairs(RP.AURAS) do
    RP.AURA_BY_KEY[a.key], RP.AURA_BY_CODE[a.code] = a, a
    Track(a.ranks, "aura:" .. a.key)
end
for _, list in pairs(RP.SELF) do
    for _, s in ipairs(list) do
        for _, opt in ipairs(s.options or {}) do Track(opt.ids, "self:" .. s.key) end
    end
end
