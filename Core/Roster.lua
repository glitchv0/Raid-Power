-- Roster.lua: the group as RaidPower sees it. Forever names carry a surname: UnitName gives the first name
-- only, UnitFullName and addon-message senders give the whole one, so players are keyed by full name.
local _, RP = ...

local Readable, Secret = RP.Readable, RP.Secret

RP.roster, RP.byWho, RP.byGuid, RP.groupsPresent = {}, {}, {}, {}

local function MyRealm()
    return GetNormalizedRealmName and GetNormalizedRealmName() or nil
end

function RP.FullName(unit)
    local name, realm = UnitFullName(unit)
    if not Readable(name) or name == "" then return nil end
    if Readable(realm) and realm ~= "" and realm ~= MyRealm() then return name .. "-" .. realm end
    return name
end

-- Normalise an addon-message sender to the same key as FullName.
function RP.NormalizeSender(sender)
    if not sender then return nil end
    local realm = MyRealm()
    if realm then
        local suffix = "-" .. realm
        if sender:sub(-#suffix) == suffix then return sender:sub(1, -#suffix - 1) end
    end
    return sender
end

function RP.PlayerName()
    RP.me = RP.FullName("player") or RP.me or UnitName("player")
    return RP.me
end

function RP.ShortName(who)
    if not who then return "?" end
    return (who:match("^(%S+)")) or who
end

local function IsTank(unit)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if Readable(role) and role == "TANK" then return true end
    if GetPartyAssignment then
        local ok, mt = pcall(GetPartyAssignment, "MAINTANK", unit)
        if ok and Readable(mt) and mt then return true end
    end
    return false
end
RP.IsTank = IsTank

function RP.CanLead(unit)
    if not IsInGroup() then return true end
    local lead = UnitIsGroupLeader(unit)
    local assist = IsInRaid() and UnitIsGroupAssistant(unit)
    if Secret(lead) or Secret(assist) then return false end
    return (lead or assist) and true or false
end

function RP.ScanRoster()
    local list, byWho, byGuid, groups = {}, {}, {}, {}
    local raid = IsInRaid()
    local n = raid and GetNumGroupMembers() or (GetNumSubgroupMembers() + 1)
    for i = 1, n do
        local unit
        if raid then unit = "raid" .. i elseif i == 1 then unit = "player" else unit = "party" .. (i - 1) end
        local who = RP.FullName(unit)
        local _, class = UnitClass(unit)
        local guid = UnitGUID(unit)
        if who and Readable(class) and class and Readable(guid) then
            local subgroup = 1
            if raid then
                local _, _, sg = GetRaidRosterInfo(i)
                if Readable(sg) and sg then subgroup = sg end
            end
            local m = {
                unit = unit, who = who, guid = guid, class = class, subgroup = subgroup,
                isPlayer = UnitIsUnit(unit, "player"), tank = IsTank(unit), index = #list + 1,
            }
            if m.isPlayer then RP.me = who end
            list[#list + 1] = m
            byWho[who] = m
            byGuid[guid] = m
            groups[subgroup] = true
        end
    end
    RP.roster, RP.byWho, RP.byGuid, RP.groupsPresent = list, byWho, byGuid, groups
    RP.inRaid = raid
    return list
end

function RP.IsAvailable(m)
    local unit = m.unit
    local connected = UnitIsConnected(unit)
    local dead = UnitIsDeadOrGhost(unit)
    if Secret(connected) or Secret(dead) then return true end
    return connected and not dead
end

function RP.InRange(m, spell)
    if m.isPlayer then return true end
    local visible = UnitIsVisible(m.unit)
    if Readable(visible) and not visible then return false end
    if not spell or not (C_Spell and C_Spell.IsSpellInRange) then return nil end
    local ok, r = pcall(C_Spell.IsSpellInRange, spell, m.unit)
    if not ok or Secret(r) then return nil end
    return r
end

-- Buffers present, by class: { PRIEST = { who, who }, ... } (yourself included).
function RP.BuffersByClass()
    local out = {}
    for _, m in ipairs(RP.roster) do
        out[m.class] = out[m.class] or {}
        table.insert(out[m.class], m.who)
    end
    for _, list in pairs(out) do table.sort(list) end
    return out
end
