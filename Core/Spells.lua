-- Spells.lua: which ranks you know, the spell to cast, names and icons.
local _, RP = ...

local QUESTION = 134400

local function Known(id)
    if not id then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known == true then return true end
        if ok then return false end
    end
    if IsPlayerSpell then return IsPlayerSpell(id) == true end
    if IsSpellKnown then return IsSpellKnown(id) == true end
    return false
end
RP.Known = Known

-- Highest known rank from a lowest-first list.
function RP.Highest(ids)
    if not ids then return nil end
    for i = #ids, 1, -1 do
        if Known(ids[i]) then return ids[i] end
    end
end

function RP.KnowsAny(ids)
    return RP.Highest(ids) ~= nil
end

function RP.SpellName(id)
    if not id then return "?" end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if not name and GetSpellInfo then name = GetSpellInfo(id) end
    return name or ("spell " .. id)
end

-- Icons by path for spells a client may not resolve yet (and the UI never shows a question mark for them).
local ICON_FALLBACK = {
    [1038] = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
    [25895] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSalvation",
    [20911] = "Interface\\Icons\\Spell_Nature_LightningShield",
    [25899] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSanctuary",
    [976] = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    [27683] = "Interface\\Icons\\Spell_Holy_PrayerofShadowProtection",
    [27681] = "Interface\\Icons\\Spell_Holy_PrayerofSpirit",
    [14752] = "Interface\\Icons\\Spell_Holy_DivineSpirit",
}

function RP.SpellIcon(id)
    if not id then return QUESTION end
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
    return icon or ICON_FALLBACK[id] or QUESTION
end
RP.QUESTION = QUESTION

function RP.ItemCount(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
    return GetItemCount and GetItemCount(id) or 0
end

function RP.HasAnyItem(ids)
    for _, id in ipairs(ids or {}) do
        if RP.ItemCount(id) > 0 then return true end
    end
    return false
end

-- Group version of a family/blessing if known and its reagent is carried.
function RP.GroupSpell(entry)
    local list = entry.group or entry.greater
    local id = RP.Highest(list)
    if not id then return nil end
    if entry.greater then
        return RP.ItemCount(RP.SYMBOL_OF_KINGS) > 0 and id or nil
    end
    if entry.reagents and not RP.HasAnyItem(entry.reagents) then return nil end
    return id
end

function RP.SingleSpell(entry)
    return RP.Highest(entry.single or entry.ranks)
end

-- Self-buff: the option a click casts (the saved choice if known, else the first known).
function RP.SelfOption(def)
    local choice = RP.CharDB and RP.CharDB.selfChoice and RP.CharDB.selfChoice[def.key]
    if def.options then
        if choice and def.options[choice] and RP.KnowsAny(def.options[choice].ids) then
            return def.options[choice], choice
        end
        for i, opt in ipairs(def.options) do
            if RP.KnowsAny(opt.ids) then return opt, i end
        end
    end
end

-- What the player's own class can give: { familyKey = true, blessingKey = true, ... }
function RP.KnownBuffs()
    local known = {}
    for _, f in ipairs(RP.FAMILIES) do
        if RP.KnowsAny(f.single) or RP.KnowsAny(f.group) then known[f.key] = true end
    end
    for _, b in ipairs(RP.BLESSINGS) do
        if RP.KnowsAny(b.ranks) or RP.KnowsAny(b.greater) then known[b.key] = true end
    end
    if RP.KnowsAny(RP.SALVATION.ranks) then known.salvation = true end
    for _, a in ipairs(RP.AURAS) do
        if RP.KnowsAny(a.ranks) then known["aura:" .. a.key] = true end
    end
    return known
end

-- Class icon (round crest) texture + coords.
RP.CLASS_ICON_FILE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
function RP.SetClassIcon(tex, class)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        tex:SetTexture(RP.CLASS_ICON_FILE)
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        tex:SetTexture("Interface\\Icons\\ClassIcon_" .. (class or "warrior"):lower())
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

function RP.ClassName(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

function RP.ClassHex(class)
    local c = RP.CLASS_COLORS[class] or { 1, 1, 1 }
    return string.format("ff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end
