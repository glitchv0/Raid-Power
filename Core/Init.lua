-- Init.lua: the addon namespace, small helpers and the event hub.
local ADDON, RP = ...
_G.RaidPower = RP

RP.NAME = ADDON
do
    -- The release packager replaces @project-version@ in the TOC; a raw checkout shows "dev".
    local v = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
    if not v or v == "" or v:find("@", 1, true) then v = "dev" end
    RP.VERSION = v:gsub("^v", "")
end
RP.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

-- Secret values (Forever / modern clients) -------------------------------------------------------
local issecret = _G.issecretvalue
function RP.Secret(v)
    return issecret ~= nil and issecret(v) == true
end

function RP.Readable(v)
    return v ~= nil and not RP.Secret(v)
end

-- Auras on group members can be withdrawn in combat and at boss pulls (before InCombatLockdown()).
function RP.AurasHidden()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, hidden = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and hidden == true then return true end
    end
    return false
end

-- Printing ------------------------------------------------------------------------------------------
local PREFIX = "|cfff5b942Raid|rPower: "
function RP.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

-- Tables --------------------------------------------------------------------------------------------
function RP.Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = RP.Copy(v) end
    return out
end

function RP.Merge(dst, defaults)
    for k, v in pairs(defaults) do
        if dst[k] == nil then
            dst[k] = RP.Copy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            RP.Merge(dst[k], v)
        end
    end
    return dst
end

function RP.FormatTime(sec)
    if not sec or sec ~= sec or sec == math.huge then return "" end
    if sec <= 0 then return "0:00" end
    if sec >= 3600 then return string.format("%dh", math.floor(sec / 3600 + 0.5)) end
    if sec >= 600 then return string.format("%dm", math.floor(sec / 60 + 0.5)) end
    return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

-- Event hub -----------------------------------------------------------------------------------------
local hub = CreateFrame("Frame")
local handlers = {}
RP.eventFrame = hub

function RP.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        if not event:find("^RP_") then hub:RegisterEvent(event) end
    end
    table.insert(handlers[event], fn)
end

function RP.Fire(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end

hub:SetScript("OnEvent", function(_, event, ...) RP.Fire(event, ...) end)

-- Debounce: run fn once, `delay` seconds after the last request.
function RP.Debouncer(delay, fn)
    local pending = false
    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, function()
            pending = false
            fn()
        end)
    end
end

-- Work that must wait for combat to end (secure attribute changes).
local afterCombat = {}
function RP.AfterCombat(key, fn)
    if not InCombatLockdown() then fn() return end
    afterCombat[key] = fn
end
RP.On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(afterCombat) do
        afterCombat[key] = nil
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end)

function RP.InCombat()
    return InCombatLockdown() or RP.combatStarting == true
end
RP.On("PLAYER_REGEN_DISABLED", function() RP.combatStarting = true end)
RP.On("PLAYER_REGEN_ENABLED", function() RP.combatStarting = false end)
