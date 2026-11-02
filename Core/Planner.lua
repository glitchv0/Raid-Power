-- Planner.lua: turns your plan, the roster and everyone's auras into tiles: what you are responsible for,
-- its status, and the queue a click (or the Smart Buff key) walks through, most urgent first.
local _, RP = ...

local MISSING, EXPIRING, OK = 0, 1, 2
RP.RANK_MISSING, RP.RANK_EXPIRING, RP.RANK_OK = MISSING, EXPIRING, OK

local function Threshold(duration)
    local thr = RP.S.expiring or 300
    if duration and duration > 0 and duration < 1200 then thr = math.min(thr, math.max(10, duration * 0.15)) end
    return thr
end

-- Rank one member for one key: rank, remaining, has.
local function Rank(m, key)
    local has, left, duration = RP.BuffStatus(m, key)
    if has == nil then return nil end
    if not has then return MISSING, 0, false end
    if left and left < Threshold(duration) then return EXPIRING, left, true end
    return OK, left, true
end
RP.Rank = Rank

local function ByUrgency(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    if (a.left or math.huge) ~= (b.left or math.huge) then return (a.left or math.huge) < (b.left or math.huge) end
    return (a.m and a.m.index or 0) < (b.m and b.m.index or 0)
end
RP.ByUrgency = ByUrgency

local function NewTile(kind, key)
    return { kind = kind, key = key, members = {}, queue = {}, missing = 0, expiring = 0, unknown = 0,
        oor = 0, total = 0, shortest = nil }
end

-- Survey a set of members for `key`, filling tile stats and returning needers (sorted) and the best refresher.
local function Survey(tile, members, key, single)
    local needers, refresh = {}, nil
    local allInRange = true
    for _, m in ipairs(members) do
        if RP.IsAvailable(m) then
            tile.total = tile.total + 1
            local rank, left, has = Rank(m, key)
            local range = RP.InRange(m, single)
            if range == false then allInRange = false end
            local row = { m = m, rank = rank, left = left, range = range, has = has, key = key }
            tile.members[#tile.members + 1] = row
            if rank == nil then
                tile.unknown = tile.unknown + 1
            else
                if rank == MISSING then tile.missing = tile.missing + 1 end
                if rank == EXPIRING then tile.expiring = tile.expiring + 1 end
                if has and left and (not tile.shortest or left < tile.shortest) then tile.shortest = left end
                if rank == MISSING then tile.shortest = 0 end
                if range == false then
                    if rank < OK then tile.oor = tile.oor + 1 end
                elseif rank < OK then
                    needers[#needers + 1] = row
                elseif left and (not refresh or left < refresh.left) then
                    refresh = row
                end
            end
        end
    end
    table.sort(needers, ByUrgency)
    return needers, refresh, allInRange
end

local function Entry(row, spellG, spellS, tile)
    return { m = row.m, unit = row.m.unit, spellG = spellG, spellS = spellS or spellG, rank = row.rank or OK,
        left = row.left, tile = tile, key = row.key }
end

local function FillQueue(tile, needers, refresh, spellG, spellS, useGroup)
    if #needers > 0 then
        if useGroup then
            tile.queue[1] = Entry(needers[1], spellG, spellS, tile)
            tile.usesGroup = true
        else
            for _, row in ipairs(needers) do tile.queue[#tile.queue + 1] = Entry(row, spellS, spellS, tile) end
        end
    elseif refresh then
        tile.queue[1] = Entry(refresh, useGroup and spellG or spellS, spellS, tile)
    end
    tile.spell = (tile.queue[1] and tile.queue[1].spellG) or spellG or spellS
end

local function Status(tile)
    if tile.missing > 0 then
        if tile.oor >= tile.missing + tile.expiring and #tile.queue == 0 then return "oor" end
        return "bad"
    end
    if tile.expiring > 0 then return "warn" end
    if tile.total > 0 and tile.unknown == tile.total then return "unk" end
    return "ok"
end
RP.TileStatus = Status

local function MembersOf(filter)
    local out = {}
    for _, m in ipairs(RP.roster) do if filter(m) then out[#out + 1] = m end end
    return out
end

-- Group families --------------------------------------------------------------------------------------
local function GroupRows(plan, class)
    local rows = {}
    for _, f in ipairs(RP.FAMILIES) do
        if f.class == class and f.scope == "group" and RP.CharDB.familyOn[f.key] and RP.KnowsAny(f.single) then
            local single, group = RP.SingleSpell(f), RP.GroupSpell(f)
            local row = { fam = f, groups = {}, all = NewTile("family", f.key) }
            row.all.fam, row.all.spell = f, group or single
            for g = 1, 8 do
                local mine = RP.Covers(plan, f.key, g)
                local present = RP.groupsPresent[g]
                local tile = NewTile("group", f.key)
                tile.fam, tile.group, tile.mine, tile.present = f, g, mine, present
                if present then
                    local members = MembersOf(function(m) return m.subgroup == g and not (f.skip and f.skip[m.class]) end)
                    local needers, refresh, allIn = Survey(tile, members, f.key, single)
                    local useGroup = group and #needers >= (RP.S.groupMin or 3) and (allIn or not RP.S.waitRange)
                    FillQueue(tile, needers, refresh, group, single, useGroup)
                end
                tile.status = (present and mine) and Status(tile) or "na"
                row.groups[g] = tile
                if mine and present then
                    local all = row.all
                    all.missing, all.expiring = all.missing + tile.missing, all.expiring + tile.expiring
                    all.unknown, all.total, all.oor = all.unknown + tile.unknown, all.total + tile.total, all.oor + tile.oor
                    if tile.shortest and (not all.shortest or tile.shortest < all.shortest) then all.shortest = tile.shortest end
                    for _, e in ipairs(tile.queue) do
                        if e.rank < OK then all.queue[#all.queue + 1] = e end
                    end
                    for _, r in ipairs(tile.members) do all.members[#all.members + 1] = r end
                end
            end
            table.sort(row.all.queue, ByUrgency)
            if #row.all.queue == 0 then
                -- Nothing due: let the family icon refresh whoever has least left in your groups.
                local best
                for g = 1, 8 do
                    local t = row.groups[g]
                    if t.mine and t.present and t.queue[1] and (not best or ByUrgency(t.queue[1], best)) then best = t.queue[1] end
                end
                if best then row.all.queue[1] = best end
            end
            row.all.status = Status(row.all)
            rows[#rows + 1] = row
        end
    end
    return rows
end

-- Thorns on tanks ---------------------------------------------------------------------------------------
local function ThornsTile(plan)
    local f = RP.FAMILY_BY_KEY.thorns
    if not (RP.CharDB.familyOn.thorns and plan.thorns ~= "none" and RP.KnowsAny(f.single)) then return nil end
    local tanks = MembersOf(function(m) return m.tank end)
    if #tanks == 0 then return nil end
    local tile = NewTile("thorns", "thorns")
    tile.fam = f
    local single = RP.SingleSpell(f)
    local needers, refresh = Survey(tile, tanks, "thorns", single)
    FillQueue(tile, needers, refresh, single, single, false)
    tile.status = Status(tile)
    return tile
end

-- Paladin blessings ---------------------------------------------------------------------------------------
local function BlessingTiles(plan)
    local tiles = {}
    local present = {}
    for _, m in ipairs(RP.roster) do present[m.class] = true end
    for _, class in ipairs(RP.CLASSES) do
        if present[class] then
            local classKey = plan.pal.classes[class]
            local members = MembersOf(function(m) return m.class == class end)
            local tile = NewTile("blessing", classKey)
            tile.class = class
            -- Members grouped by the blessing this paladin gives them (class blessing or a personal override).
            local byKey, overrides = {}, false
            for _, m in ipairs(members) do
                local key = RP.BlessingFor(plan, m)
                if key and RP.BLESS_BY_KEY[key] then
                    byKey[key] = byKey[key] or {}
                    table.insert(byKey[key], m)
                    if key ~= classKey then overrides = true end
                end
            end
            local allNeeders, refresh = {}, nil
            for key, list in pairs(byKey) do
                local entry = RP.BLESS_BY_KEY[key]
                local single = RP.SingleSpell(entry)
                if single then
                    local needers, ref, allIn = Survey(tile, list, key, single)
                    local greater = key == classKey and not overrides and RP.GroupSpell(entry)
                    local useGreater = greater and #needers >= (RP.S.greaterMin or 2) and (allIn or not RP.S.waitRange)
                    for i, row in ipairs(needers) do
                        if useGreater and i > 1 then break end
                        allNeeders[#allNeeders + 1] = Entry(row, useGreater and greater or single, single, tile)
                    end
                    if ref and (not refresh or (ref.left or 0) < (refresh.left or 0)) then
                        refresh = Entry(ref, single, single, tile)
                    end
                end
            end
            table.sort(allNeeders, ByUrgency)
            tile.queue = allNeeders
            if #tile.queue == 0 and refresh then tile.queue[1] = refresh end
            local shown = classKey and RP.BLESS_BY_KEY[classKey]
            tile.spell = (tile.queue[1] and tile.queue[1].spellG) or (shown and RP.SingleSpell(shown))
            tile.icon = shown and RP.SpellIcon(shown.ranks[1]) or nil
            tile.status = classKey and Status(tile) or "na"
            tiles[#tiles + 1] = tile
        end
    end
    return tiles
end

local function SalvationTile(plan)
    if not (plan.pal.salv and RP.KnowsAny(RP.SALVATION.ranks)) then return nil end
    local tile = NewTile("salvation", "salvation")
    local entry = RP.SALVATION
    local single, greater = RP.SingleSpell(entry), RP.GroupSpell(entry)
    local queue = {}
    for _, class in ipairs(RP.CLASSES) do
        local list = MembersOf(function(m) return m.class == class and not m.tank end)
        local hasTank = #MembersOf(function(m) return m.class == class and m.tank end) > 0
        if #list > 0 then
            local needers, ref = Survey(tile, list, "salvation", single)
            local useGreater = greater and not hasTank and #needers >= (RP.S.greaterMin or 2)
            for i, row in ipairs(needers) do
                if useGreater and i > 1 then break end
                queue[#queue + 1] = Entry(row, useGreater and greater or single, single, tile)
            end
            if ref and not tile.refresh then tile.refresh = Entry(ref, single, single, tile) end
        end
    end
    table.sort(queue, ByUrgency)
    tile.queue = queue
    if #queue == 0 and tile.refresh then queue[1] = tile.refresh end
    tile.spell = (queue[1] and queue[1].spellG) or single
    tile.icon = RP.SpellIcon(entry.ranks[1])
    tile.status = Status(tile)
    return tile
end

-- Self-buffs ------------------------------------------------------------------------------------------------
local function PlayerMember()
    for _, m in ipairs(RP.roster) do if m.isPlayer then return m end end
end

local function WeaponIsWeapon(slot)
    local id = GetInventoryItemID("player", slot)
    if not id then return false end
    if slot == 17 and C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(id)
        return classID == 2
    end
    return true
end

local function SelfTiles(plan, class)
    local tiles = {}
    local me = PlayerMember()
    if not me then return tiles end
    for _, def in ipairs(RP.SELF[class] or {}) do
        if RP.SelfOn(def.key) then
            local tile = NewTile("self", def.key)
            tile.def = def
            local show = true
            if def.paladinAura then
                local key = plan.pal.aura
                if not (key and RP.AURA_BY_KEY[key] and RP.KnowsAny(RP.AURA_BY_KEY[key].ranks)) then
                    key = nil
                    for _, a in ipairs(RP.AURAS) do if RP.KnowsAny(a.ranks) then key = a.key break end end
                end
                if key then
                    local a = RP.AURA_BY_KEY[key]
                    tile.spell, tile.icon, tile.label = RP.Highest(a.ranks), RP.SpellIcon(a.ranks[1]), a.label
                    tile.trackKey = "aura:" .. key
                else
                    show = false
                end
            elseif def.items then
                if not WeaponIsWeapon(def.weapon) then show = false end
                local item
                for _, id in ipairs(def.items) do if RP.ItemCount(id) > 0 then item = id break end end
                tile.item = item
                tile.icon = item and (C_Item.GetItemIconByID and C_Item.GetItemIconByID(item)) or 132273
                if not item then show = false end
            else
                local opt = RP.SelfOption(def)
                if not opt then show = false end
                if def.tankOnly then
                    local mode = RP.CharDB.furyMode
                    if mode == "never" or (mode == "tank" and not me.tank) then show = false end
                end
                if opt then
                    tile.spell, tile.icon, tile.label = RP.Highest(opt.ids), RP.SpellIcon(opt.ids[1]), opt.label
                end
                tile.trackKey = "self:" .. def.key
                if def.weapon and not WeaponIsWeapon(def.weapon) then show = false end
            end
            if show then
                local rank, left
                if def.weapon then
                    local has, secs = RP.WeaponEnchant(def.weapon)
                    if has == nil then rank = nil
                    elseif not has then rank, left = MISSING, 0
                    elseif secs and secs < Threshold(1800) then rank, left = EXPIRING, secs
                    else rank, left = OK, secs end
                else
                    local has, l, duration, a = RP.BuffStatus(me, tile.trackKey)
                    if has and def.own and a and not a.mine and RP.Readable(a.mine) then has = false end
                    if has == nil then rank = nil
                    elseif not has then rank, left = MISSING, 0
                    elseif l and l < Threshold(duration) then rank, left = EXPIRING, l
                    else rank, left = OK, l end
                end
                tile.total = 1
                if rank == nil then tile.unknown = 1 end
                if rank == MISSING then tile.missing = 1 end
                if rank == EXPIRING then tile.expiring = 1 end
                tile.shortest = left
                local row = { m = me, rank = rank, left = left, key = tile.trackKey }
                tile.members[1] = row
                if rank and rank < OK then
                    tile.queue[1] = { m = me, unit = "player", spellG = tile.spell, spellS = tile.spell, item = tile.item,
                        weapon = def.weapon, rank = rank, left = left, tile = tile, self = true }
                end
                tile.status = Status(tile)
                tiles[#tiles + 1] = tile
            end
        end
    end
    return tiles
end

-- Build everything ---------------------------------------------------------------------------------------
function RP.BuildState()
    local plan = RP.MyPlan()
    local class = plan.class
    local state = { class = class, groupRows = {}, blessings = {}, selfTiles = {}, smart = {} }
    if class == "PALADIN" then
        state.blessings = BlessingTiles(plan)
        state.salvation = SalvationTile(plan)
    end
    state.groupRows = GroupRows(plan, class)
    if class == "DRUID" then state.thorns = ThornsTile(plan) end
    state.selfTiles = SelfTiles(plan, class)

    -- Smart Buff: everything due, group buffs before self-buffs, missing before expiring.
    local smart = {}
    local function Add(tile, weight)
        if not tile then return end
        for _, e in ipairs(tile.queue) do
            if e.rank < OK then e.weight = weight; smart[#smart + 1] = e end
        end
    end
    for _, t in ipairs(state.blessings) do Add(t, 1) end
    Add(state.salvation, 2)
    for _, row in ipairs(state.groupRows) do
        for g = 1, 8 do
            local t = row.groups[g]
            if t.mine and t.present then Add(t, 1) end
        end
    end
    Add(state.thorns, 2)
    for _, t in ipairs(state.selfTiles) do Add(t, 0) end
    table.sort(smart, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.weight ~= b.weight then return a.weight < b.weight end
        return ByUrgency(a, b)
    end)
    state.smart = smart
    RP.state = state
    return state
end

-- Overview: for every member, the buffs they should have and their state. -------------------------------
function RP.Expected(m)
    local out = {}
    local classes = {}
    for _, r in ipairs(RP.roster) do classes[r.class] = true end
    for _, f in ipairs(RP.FAMILIES) do
        if f.scope == "group" and classes[f.class] and not (f.skip and f.skip[m.class]) and (not f.optional or RP.CharDB.familyOn[f.key]) then
            out[#out + 1] = { key = f.key, label = f.label, icon = RP.SpellIcon(f.single[1]) }
        end
    end
    for _, b in ipairs(RP.Buffers("PALADIN")) do
        local key = b.plan and RP.BlessingFor(b.plan, m)
        if key and RP.BLESS_BY_KEY[key] then
            out[#out + 1] = { key = key, label = RP.BLESS_BY_KEY[key].label, icon = RP.SpellIcon(RP.BLESS_BY_KEY[key].ranks[1]), by = b.who }
        end
        if b.plan and b.plan.pal and b.plan.pal.salv and not m.tank then
            out[#out + 1] = { key = "salvation", label = "Salvation", icon = RP.SpellIcon(1038), by = b.who }
        end
    end
    return out
end
