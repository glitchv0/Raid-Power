-- Assign.lua: everyone's buff plans and Auto-assign.
-- A plan: { class, known = {key=true}, auto = bool, free = bool,
--   groups = { fort = "11111111", ... }   -- subgroup 1..8 coverage per group family
--   thorns = "tanks" | "none",
--   pal = { classes = { WARRIOR = "kings" }, players = { [guid] = "might" }, aura = "devotion", salv = bool },
--   totems = { earth = "soe", air = "windfury", water = "manaspring", fire = "frostres" } }
local _, RP = ...

RP.plans = {}       -- who -> plan (others, from sync)
RP.planAt = {}      -- who -> GetTime() of last update
RP.versions = {}    -- who -> addon version string

local ALL, NONE = "11111111", "00000000"
RP.ALL_GROUPS, RP.NO_GROUPS = ALL, NONE

function RP.MyPlan()
    local plan = RP.CharDB.plan
    local _, class = UnitClass("player")
    plan.class = class
    if not RP.knownCache then RP.knownCache = RP.KnownBuffs() end
    plan.known = RP.knownCache
    if plan.auto == nil then plan.auto = true end
    plan.groups = plan.groups or {}
    plan.pal = plan.pal or { classes = {}, players = {} }
    plan.pal.classes = plan.pal.classes or {}
    plan.pal.players = plan.pal.players or {}
    plan.totems = plan.totems or {}
    return plan
end

function RP.PlanOf(who)
    if who == RP.PlayerName() then return RP.MyPlan() end
    return RP.plans[who]
end

function RP.Covers(plan, famKey, subgroup)
    local s = plan and plan.groups and plan.groups[famKey]
    if type(s) ~= "string" then return false end
    return s:sub(subgroup, subgroup) == "1"
end

function RP.SetCover(plan, famKey, subgroup, on)
    local s = plan.groups[famKey]
    if type(s) ~= "string" or #s ~= 8 then s = NONE end
    plan.groups[famKey] = s:sub(1, subgroup - 1) .. (on and "1" or "0") .. s:sub(subgroup + 1)
end

-- The blessing a paladin's plan gives one member.
function RP.BlessingFor(plan, m)
    if not plan or not plan.pal then return nil end
    local k = plan.pal.players and plan.pal.players[m.guid]
    if k == "none" then return nil end
    return k or plan.pal.classes[m.class]
end

-- Buffers present for a class, sorted, with their plans (nil plan = not running RaidPower).
function RP.Buffers(class)
    local out = {}
    for _, m in ipairs(RP.roster) do
        if m.class == class then out[#out + 1] = { who = m.who, m = m, plan = RP.PlanOf(m.who) } end
    end
    table.sort(out, function(a, b) return a.who < b.who end)
    return out
end

local function KnowsKey(buffer, key)
    local plan = buffer.plan
    if not plan or not plan.known or not next(plan.known) then
        -- No addon (or not yet answered): assume the basics, not talents.
        return key ~= "spirit" and key ~= "sanctuary" and key ~= "aura:concentration" and key ~= "aura:sanctity"
    end
    return plan.known[key] == true
end
RP.KnowsKey = KnowsKey

local function PresentGroups()
    local list = {}
    for g = 1, 8 do if RP.groupsPresent[g] then list[#list + 1] = g end end
    if #list == 0 then list[1] = 1 end
    return list
end

-- Split `groups` across `n` buffers as evenly as possible, contiguous.
local function Split(groups, n, i)
    local out = {}
    local per = #groups / n
    local first, last = math.floor((i - 1) * per) + 1, math.floor(i * per)
    for k = first, last do out[#out + 1] = groups[k] end
    return out
end

local function GroupString(list)
    local t = { "0", "0", "0", "0", "0", "0", "0", "0" }
    for _, g in ipairs(list) do t[g] = "1" end
    return table.concat(t)
end

-- Compute plans for every buffer of every class present. Deterministic: every client given the same roster
-- and the same known spells produces the same split, so "auto" plans agree without a leader.
function RP.AutoAssign()
    local result = {}
    local groups = PresentGroups()
    local function PlanFor(b)
        result[b.who] = result[b.who] or RP.Copy(b.plan or {})
        local p = result[b.who]
        p.groups = p.groups or {}
        p.pal = p.pal or {}
        p.pal.classes, p.pal.players = {}, p.pal.players or {}
        p.totems = p.totems or {}
        p.class = b.m.class
        return p
    end

    -- Group families.
    for _, f in ipairs(RP.FAMILIES) do
        if f.scope == "group" then
            local all, able = RP.Buffers(f.class), {}
            for _, b in ipairs(all) do
                local p = PlanFor(b)
                p.groups[f.key] = NONE
                if KnowsKey(b, f.key) then able[#able + 1] = b end
            end
            local on = not f.optional or (RP.CharDB.familyOn[f.key] == true)
            if on then
                for i, b in ipairs(able) do PlanFor(b).groups[f.key] = GroupString(Split(groups, #able, i)) end
            end
        end
    end

    -- Paladins: per class, most wanted blessing first, each to the free paladin who knows the fewest.
    local pals = RP.Buffers("PALADIN")
    for _, b in ipairs(pals) do PlanFor(b) end
    if #pals > 0 then
        local function KnownCount(b)
            local n = 0
            for _, bl in ipairs(RP.BLESSINGS) do if KnowsKey(b, bl.key) then n = n + 1 end end
            return n
        end
        local order = {}
        for _, b in ipairs(pals) do order[#order + 1] = b end
        table.sort(order, function(a, c)
            local ka, kc = KnownCount(a), KnownCount(c)
            if ka ~= kc then return ka < kc end
            return a.who < c.who
        end)
        for _, class in ipairs(RP.CLASSES) do
            local used = {}
            for _, key in ipairs(RP.BLESS_PRIORITY[class]) do
                for _, b in ipairs(order) do
                    if not used[b.who] and KnowsKey(b, key) then
                        used[b.who] = true
                        result[b.who].pal.classes[class] = key
                        break
                    end
                end
            end
        end
        -- Salvation: one paladin, the first who knows it. Auras: one each, in order.
        local salvGiven = false
        for _, b in ipairs(pals) do
            local p = result[b.who]
            p.pal.salv = false
            if not salvGiven and KnowsKey(b, "salvation") then p.pal.salv, salvGiven = true, true end
        end
        local auraUsed = {}
        for _, b in ipairs(pals) do
            local p = result[b.who]
            p.pal.aura = nil
            for _, a in ipairs(RP.AURAS) do
                if not auraUsed[a.key] and KnowsKey(b, "aura:" .. a.key) then
                    auraUsed[a.key], p.pal.aura = true, a.key
                    break
                end
            end
        end
    end

    -- Shamans: suggest a default totem set, different air/water per shaman where possible.
    local shams = RP.Buffers("SHAMAN")
    for i, b in ipairs(shams) do
        local p = PlanFor(b)
        p.totems = p.totems or {}
        p.totems.earth = p.totems.earth or "soe"
        p.totems.air = p.totems.air or ((i % 2 == 1) and "windfury" or "goa")
        p.totems.water = p.totems.water or "manaspring"
        p.totems.fire = p.totems.fire or "frostres"
    end
    return result
end

-- Apply the auto plan to yourself only (used while your plan is in "auto" mode).
function RP.ApplyAutoToSelf()
    local me = RP.PlayerName()
    local plan = RP.MyPlan()
    if not plan.auto then return false end
    local result = RP.AutoAssign()
    local mine = result[me]
    if not mine then return false end
    local changed = false
    for k, v in pairs(mine.groups or {}) do
        if plan.groups[k] ~= v then plan.groups[k] = v; changed = true end
    end
    if plan.class == "PALADIN" then
        for _, class in ipairs(RP.CLASSES) do
            if plan.pal.classes[class] ~= mine.pal.classes[class] then
                plan.pal.classes[class] = mine.pal.classes[class]; changed = true
            end
        end
        if plan.pal.salv ~= mine.pal.salv then plan.pal.salv = mine.pal.salv; changed = true end
        if plan.pal.aura ~= mine.pal.aura then plan.pal.aura = mine.pal.aura; changed = true end
    end
    if plan.class == "SHAMAN" then
        for _, e in ipairs(RP.TOTEM_ELEMENTS) do
            if not plan.totems[e] and mine.totems[e] then plan.totems[e] = mine.totems[e]; changed = true end
        end
    end
    return changed
end

-- May `editor` change `target`'s plan?
function RP.MayEdit(editorWho, targetWho)
    if editorWho == targetWho then return true end
    local tp = RP.PlanOf(targetWho)
    if tp and tp.free then return true end
    local em = RP.byWho[editorWho]
    return em ~= nil and RP.CanLead(em.unit)
end
