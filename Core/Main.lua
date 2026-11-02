-- Main.lua: start-up, events and the refresh loop.
local ADDON, RP = ...

local refreshPending, rescanPending, fullPending = false, false, false

function RP.RefreshNow(fromClick)
    if not RP.ready then return end
    if rescanPending or fromClick then
        rescanPending = false
        RP.ScanAll()
    end
    local state = RP.BuildState()
    RP.PaintBars(state)
    if not fromClick then RP.RefreshWindow() end
end

local function RunRefresh()
    refreshPending = false
    local full = fullPending
    fullPending = false
    if full then rescanPending = true end
    RP.RefreshNow()
end

-- full: also rescan auras. Raids batch more.
function RP.RequestRefresh(full)
    if full then fullPending = true end
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(IsInRaid() and 0.5 or 0.15, RunRefresh)
end

local function RosterChanged()
    RP.ScanRoster()
    RP.PruneSync()
    if RP.ApplyAutoToSelf() then RP.BroadcastSoon() end
    RP.RequestRefresh(true)
end
local RosterSoon = RP.Debouncer(0.3, RosterChanged)
local AskSoon = RP.Debouncer(2, function() RP.AskPlans(); RP.BroadcastPlan() end)

-- Events ---------------------------------------------------------------------------------------------------------
RP.On("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    RP.InitDB()
end)

RP.On("PLAYER_LOGIN", function()
    if not RP.DB then RP.InitDB() end
    RP.PlayerName()
    RP.CreateBars()
    RP.InitSync()
    RP.InitMenus()
    RP.ScanRoster()
    RP.MyPlan()
    RP.ApplyAutoToSelf()
    RP.ready = true
    rescanPending = true
    RP.RefreshNow()
    if IsInGroup() then AskSoon() end
    -- Timers tick down without events; range changes silently. 1s repaint, 3s rescan out of combat.
    local n = 0
    C_Timer.NewTicker(1, function()
        n = n + 1
        if n % 3 == 0 and not RP.InCombat() then rescanPending = true end
        RP.RefreshNow()
    end)
end)

RP.On("PLAYER_ENTERING_WORLD", function()
    RP.PlayerName()
    RosterSoon()
end)

RP.On("GROUP_ROSTER_UPDATE", function()
    RosterSoon()
    AskSoon()
end)

RP.On("PLAYER_ROLES_ASSIGNED", RosterSoon)

RP.On("UNIT_AURA", function()
    if not RP.ready then return end
    rescanPending = true
    RP.RequestRefresh()
end)

local function SpellsChanged()
    RP.knownCache = nil
    RP.MyPlan()
    if RP.ApplyAutoToSelf() then end
    RP.BroadcastSoon()
    RP.RequestRefresh(true)
end
RP.On("SPELLS_CHANGED", RP.Debouncer(1, SpellsChanged))

RP.On("BAG_UPDATE_DELAYED", function() RP.RequestRefresh() end)
RP.On("PLAYER_EQUIPMENT_CHANGED", function() RP.RequestRefresh(true) end)
RP.On("UNIT_INVENTORY_CHANGED", function(unit) if unit == "player" then RP.RequestRefresh(true) end end)
RP.On("PLAYER_REGEN_ENABLED", function() RP.RequestRefresh(true) end)
RP.On("PLAYER_REGEN_DISABLED", function() RP.RequestRefresh() end)
RP.On("UPDATE_BINDINGS", function() RP.RequestRefresh() end)

RP.On("RP_PLANS_CHANGED", function(who)
    if who ~= RP.PlayerName() and RP.ApplyAutoToSelf() then RP.BroadcastSoon() end
    RP.RequestRefresh()
end)

RP.On("RP_SETTING", function()
    RP.RequestRefresh(true)
end)

-- While auras are hidden (combat), assume our own successful casts landed. ----------------------------------------
local DURATION_GUESS = 1800
RP.On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" or RP.Secret(spellID) then return end
    local last = RP.lastCast
    if not (last and last.spell and GetTime() - last.at < 3) then return end
    local key = RP.SPELL_FAMILY[spellID]
    if not key then return end
    if RP.AurasHidden() then
        local target
        for _, m in ipairs(RP.roster) do if last.unit and UnitIsUnit(m.unit, last.unit) then target = m end end
        if target then
            if RP.GROUP_SPELL[spellID] then
                local blessing = RP.BLESS_BY_KEY[key] ~= nil
                for _, m in ipairs(RP.roster) do
                    if (blessing and m.class == target.class) or (not blessing and m.subgroup == target.subgroup) then
                        RP.NoteCast(m, key, DURATION_GUESS)
                    end
                end
            else
                RP.NoteCast(target, key, DURATION_GUESS)
            end
        end
    end
    RP.lastCast = nil
    rescanPending = true
    RP.RequestRefresh()
end)
