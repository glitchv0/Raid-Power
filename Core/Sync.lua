-- Sync.lua: plans shared between everyone in the group running RaidPower.
-- Messages are parsed as data; only codes RaidPower knows are kept, and only the leader, an assistant, or anyone
-- when the target turned on Free assignment, may set someone else's plan. Nothing is sent in combat.
local _, RP = ...

local PREFIX = "RAIDPOWER"
local SEP = "^"
local PROTOCOL = "1"
RP.SYNC_PREFIX = PREFIX

-- Encoding -----------------------------------------------------------------------------------------------
local function KnownCodes(known)
    local out = {}
    for _, f in ipairs(RP.FAMILIES) do if known[f.key] then out[#out + 1] = f.code end end
    for _, b in ipairs(RP.BLESSINGS) do if known[b.key] then out[#out + 1] = "b" .. b.code end end
    if known.salvation then out[#out + 1] = "bv" end
    for _, a in ipairs(RP.AURAS) do if known["aura:" .. a.key] then out[#out + 1] = "a" .. a.code end end
    return table.concat(out, ",")
end

local function ParseKnown(s)
    local known = {}
    for code in (s or ""):gmatch("[^,]+") do
        local first, rest = code:sub(1, 1), code:sub(2)
        if #code == 1 and RP.FAMILY_BY_CODE[code] then
            known[RP.FAMILY_BY_CODE[code].key] = true
        elseif first == "b" and rest == "v" then
            known.salvation = true
        elseif first == "b" and RP.BLESS_BY_CODE[rest] then
            known[RP.BLESS_BY_CODE[rest].key] = true
        elseif first == "a" and RP.AURA_BY_CODE[rest] then
            known["aura:" .. RP.AURA_BY_CODE[rest].key] = true
        end
    end
    return known
end

local function EncodeBody(plan)
    local groups = {}
    for _, f in ipairs(RP.FAMILIES) do
        local g = plan.groups and plan.groups[f.key]
        if f.scope == "group" and type(g) == "string" and g:match("^[01]+$") and #g == 8 then
            groups[#groups + 1] = f.code .. "=" .. g
        end
    end
    local pal = {}
    for i, class in ipairs(RP.CLASSES) do
        local key = plan.pal and plan.pal.classes and plan.pal.classes[class]
        pal[i] = (key and RP.BLESS_BY_KEY[key] and RP.BLESS_BY_KEY[key].code) or "-"
    end
    local aura = plan.pal and plan.pal.aura and RP.AURA_BY_KEY[plan.pal.aura]
    local totems = {}
    for _, e in ipairs(RP.TOTEM_ELEMENTS) do
        if plan.totems and plan.totems[e] then totems[#totems + 1] = e .. "=" .. plan.totems[e] end
    end
    local flags = (plan.auto and "A" or "") .. (plan.free and "F" or "") .. ((plan.thorns == "none") and "N" or "")
    return table.concat({
        table.concat(groups, ","), table.concat(pal), aura and aura.code or "-",
        (plan.pal and plan.pal.salv) and "1" or "0", table.concat(totems, ","), flags,
    }, SEP)
end

local VALID_TOTEM = {}
for e, list in pairs(RP.TOTEMS) do
    VALID_TOTEM[e] = {}
    for _, t in ipairs(list) do VALID_TOTEM[e][t.key] = true end
end

local function DecodeBody(parts, i, plan)
    plan.groups = plan.groups or {}
    for pair in (parts[i] or ""):gmatch("[^,]+") do
        local code, g = pair:match("^(%a)=([01]+)$")
        local f = code and RP.FAMILY_BY_CODE[code]
        if f and #g == 8 then plan.groups[f.key] = g end
    end
    plan.pal = plan.pal or {}
    plan.pal.classes = {}
    local pal = parts[i + 1] or ""
    for k, class in ipairs(RP.CLASSES) do
        local c = pal:sub(k, k)
        if RP.BLESS_BY_CODE[c] then plan.pal.classes[class] = RP.BLESS_BY_CODE[c].key end
    end
    local a = RP.AURA_BY_CODE[parts[i + 2] or ""]
    plan.pal.aura = a and a.key or nil
    plan.pal.salv = parts[i + 3] == "1"
    plan.totems = {}
    for pair in (parts[i + 4] or ""):gmatch("[^,]+") do
        local e, t = pair:match("^(%a+)=(%a+)$")
        if e and VALID_TOTEM[e] and VALID_TOTEM[e][t] then plan.totems[e] = t end
    end
    local flags = parts[i + 5] or ""
    plan.auto = flags:find("A", 1, true) ~= nil
    plan.free = flags:find("F", 1, true) ~= nil
    plan.thorns = flags:find("N", 1, true) and "none" or "tanks"
    return plan
end

local function EncodeOverrides(plan)
    local chunks, cur = {}, {}
    for guid, key in pairs(plan.pal and plan.pal.players or {}) do
        local code = key == "none" and "-" or (RP.BLESS_BY_KEY[key] and RP.BLESS_BY_KEY[key].code)
        if code and guid:match("^Player%-[%w%-]+$") then
            cur[#cur + 1] = guid .. "=" .. code
            if #cur >= 8 then chunks[#chunks + 1] = table.concat(cur, ";"); cur = {} end
        end
    end
    if #cur > 0 or #chunks == 0 then chunks[#chunks + 1] = table.concat(cur, ";") end
    return chunks
end

local function DecodeOverrides(s, into)
    for pair in (s or ""):gmatch("[^;]+") do
        local guid, code = pair:match("^(Player%-[%w%-]+)=(.)$")
        if guid then
            if code == "-" then into[guid] = "none"
            elseif RP.BLESS_BY_CODE[code] then into[guid] = RP.BLESS_BY_CODE[code].key end
        end
    end
end

-- Sending ----------------------------------------------------------------------------------------------
local function Channel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local outbox = {}   -- kind -> message (latest wins), flushed out of combat
local function Flush()
    if InCombatLockdown() then return end
    local ch = Channel()
    if not ch then wipe(outbox) return end
    for kind, list in pairs(outbox) do
        outbox[kind] = nil
        for _, msg in ipairs(list) do C_ChatInfo.SendAddonMessage(PREFIX, msg, ch) end
    end
end
local FlushSoon = RP.Debouncer(0.5, Flush)

local function Queue(kind, msgs)
    outbox[kind] = msgs
    if InCombatLockdown() then
        RP.AfterCombat("sync-flush", Flush)
    else
        FlushSoon()
    end
end

function RP.BroadcastPlan()
    if not IsInGroup() then return end
    local plan = RP.MyPlan()
    local msgs = { table.concat({ "P", PROTOCOL, RP.VERSION, plan.class or "?", KnownCodes(plan.known or {}), EncodeBody(plan) }, SEP) }
    if plan.class == "PALADIN" then
        local chunks = EncodeOverrides(plan)
        for i, c in ipairs(chunks) do msgs[#msgs + 1] = table.concat({ "O", i, #chunks, c }, SEP) end
    end
    Queue("plan", msgs)
end
RP.BroadcastSoon = RP.Debouncer(1, RP.BroadcastPlan)

function RP.AskPlans()
    if not IsInGroup() then return end
    Queue("hello", { table.concat({ "H", PROTOCOL, RP.VERSION }, SEP) })
end

-- Leader/assist (or anyone for a Free-assignment player) sets another player's plan.
function RP.SendPlanFor(who, plan)
    if who == RP.PlayerName() then return end
    local msgs = { table.concat({ "S", who, EncodeBody(plan) }, SEP) }
    if plan.class == "PALADIN" then
        local chunks = EncodeOverrides(plan)
        for i, c in ipairs(chunks) do msgs[#msgs + 1] = table.concat({ "Q", who, i, #chunks, c }, SEP) end
    end
    Queue("set:" .. who, msgs)
end

-- Receiving ---------------------------------------------------------------------------------------------
local pendingOverrides = {}

local function Received(prefix, msg, channel, sender)
    if prefix ~= PREFIX or type(msg) ~= "string" or #msg > 255 then return end
    local who = RP.NormalizeSender(sender)
    if not who or who == RP.PlayerName() then return end
    if not RP.byWho[who] then return end   -- only group members
    local parts = {}
    for p in (msg .. SEP):gmatch("(.-)%" .. SEP) do parts[#parts + 1] = p end
    local kind = parts[1]
    if kind == "H" then
        RP.versions[who] = parts[3]
        RP.BroadcastSoon()
    elseif kind == "P" then
        local class = parts[4]
        if not RP.CLASS_INDEX[class] or RP.byWho[who].class ~= class then return end
        local plan = RP.plans[who] or {}
        plan.class = class
        plan.known = ParseKnown(parts[5])
        DecodeBody(parts, 6, plan)
        plan.pal.players = plan.pal.players or {}
        RP.plans[who], RP.planAt[who], RP.versions[who] = plan, GetTime(), parts[3]
        RP.Fire("RP_PLANS_CHANGED", who)
    elseif kind == "O" then
        local i, n = tonumber(parts[2]), tonumber(parts[3])
        if not (i and n and n <= 10) then return end
        local plan = RP.plans[who]
        if not plan then return end
        pendingOverrides[who] = (i == 1) and {} or (pendingOverrides[who] or {})
        DecodeOverrides(parts[4], pendingOverrides[who])
        if i == n then
            plan.pal.players = pendingOverrides[who]
            pendingOverrides[who] = nil
            RP.Fire("RP_PLANS_CHANGED", who)
        end
    elseif kind == "S" or kind == "Q" then
        if parts[2] ~= RP.PlayerName() then return end
        if not RP.MayEdit(who, RP.PlayerName()) then return end
        local plan = RP.MyPlan()
        if kind == "S" then
            local wasPal = plan.pal and plan.pal.players
            DecodeBody(parts, 3, plan)
            plan.pal.players = wasPal or {}
            plan.auto = false
            RP.CharDB.planned = true
            RP.Print(("%s updated your assignments."):format(RP.ShortName(who)))
        else
            local i, n = tonumber(parts[3]), tonumber(parts[4])
            if not (i and n and n <= 10) then return end
            local key = "self:" .. who
            pendingOverrides[key] = (i == 1) and {} or (pendingOverrides[key] or {})
            DecodeOverrides(parts[5], pendingOverrides[key])
            if i == n then
                plan.pal.players = pendingOverrides[key]
                pendingOverrides[key] = nil
            end
        end
        RP.lastChange = { by = who, at = GetTime() }
        RP.Fire("RP_PLANS_CHANGED", RP.PlayerName())
        RP.BroadcastSoon()
    end
end

function RP.InitSync()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
    RP.On("CHAT_MSG_ADDON", Received)
end

function RP.PruneSync()
    for who in pairs(RP.plans) do
        if not RP.byWho[who] then RP.plans[who], RP.planAt[who], RP.versions[who] = nil, nil, nil end
    end
end

-- Exposed for presets.
RP.EncodePlanBody, RP.DecodePlanBody = EncodeBody, DecodeBody
RP.SyncSep = SEP
