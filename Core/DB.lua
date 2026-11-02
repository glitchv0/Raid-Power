-- DB.lua: saved settings. RaidPowerDB is account-wide, RaidPowerCharDB per character.
local _, RP = ...

RP.ACCENTS = {
    gold = { 0.961, 0.725, 0.259 },
    teal = { 0.047, 0.824, 0.624 },
    blue = { 0.000, 0.569, 0.929 },
    violet = { 0.655, 0.545, 0.980 },
}
RP.ACCENT_ORDER = { "gold", "teal", "blue", "violet" }

local ACCOUNT_DEFAULTS = {
    settings = {
        accent = "gold",
        gameMenu = true,        -- RaidPower button in the Esc game menu
        scale = 1.0,
        iconSize = 36,
        layout = "full",        -- full | compact | smart
        classLabels = true,
        showSolo = true,
        showParty = true,
        hideWhenDone = false,
        fadeOOC = false,
        expiring = 300,         -- seconds left that count as "expiring" for long buffs
        groupMin = 3,           -- members of a subgroup needing a buff before a group spell is used
        greaterMin = 2,         -- class members needing a blessing before a Greater Blessing is used
        waitRange = false,      -- only use group/greater spells when everyone is in range
        tooltips = true,
        palVertical = false,
        smartSeparate = true,   -- Smart Buff floats on its own instead of sitting under the bar
        smartShown = true,
        selfShown = true,
        locked = false,
    },
    presets = {},
}

local CHAR_DEFAULTS = {
    plan = {
        groups = { fort = "11111111", spirit = "11111111", shadow = "00000000", int = "11111111", motw = "11111111" },
        thorns = "tanks",
        pal = { classes = {}, players = {}, aura = nil, salv = false },
        totems = {},
        free = false,
    },
    familyOn = { fort = true, spirit = true, shadow = false, int = true, motw = true, thorns = true },
    selfOn = {},
    selfChoice = {},
    furyMode = "tank",   -- always | tank | never
    positions = {},
    planned = false,     -- true once a plan was set by auto-assign, a leader or the user
}

function RP.InitDB()
    RaidPowerDB = RaidPowerDB or {}
    RaidPowerCharDB = RaidPowerCharDB or {}
    RP.Merge(RaidPowerDB, ACCOUNT_DEFAULTS)
    RP.Merge(RaidPowerCharDB, CHAR_DEFAULTS)
    RP.DB, RP.CharDB = RaidPowerDB, RaidPowerCharDB
    RP.S = RaidPowerDB.settings
end

function RP.Get(key) return RP.S[key] end

function RP.Set(key, value)
    if RP.S[key] == value then return end
    RP.S[key] = value
    RP.Fire("RP_SETTING", key, value)
end

function RP.Accent()
    local c = RP.ACCENTS[RP.S and RP.S.accent or "gold"] or RP.ACCENTS.gold
    return c[1], c[2], c[3]
end

function RP.AccentHex()
    local r, g, b = RP.Accent()
    return string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function RP.SelfOn(key, def)
    local v = RP.CharDB.selfOn[key]
    if v == nil then return def ~= false end
    return v
end
