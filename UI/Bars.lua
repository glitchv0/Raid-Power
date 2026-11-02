-- Bars.lua: the on-screen bars. Main bar (paladin blessings / group-buff rows), self-buff strip, Smart Buff.
-- Frames holding secure tiles are only built, moved, shown or hidden out of combat; in combat only their
-- textures and text change.
local _, RP = ...

local St, W = RP.Style, RP.Widgets
local PAD, HEADER, GAP = 8, 18, 6
local bars = {}
RP.bars = bars

-- Bar frames ---------------------------------------------------------------------------------------------
-- Defaults: Smart Buff above the main bar, self-buffs to its left, all clear of the action bars.
RP.DEFAULT_POS = {
    Main = { "TOP", "CENTER", 0, -150 },
    Smart = { "BOTTOM", "CENTER", 0, -140 },
    Self = { "BOTTOMRIGHT", "CENTER", -160, -140 },
}

-- Bars are never narrower than their header text.
local function FitWidth(bar, contentW)
    local headerW = bar.title:GetStringWidth() + bar.sub:GetStringWidth() + bar.right:GetStringWidth() + 40
    return math.max(contentW + PAD * 2, headerW)
end
local function SavePosition(frame)
    local point, _, rel, x, y = frame:GetPoint(1)
    RP.CharDB.positions[frame.rpKey] = { point, rel, x, y }
end

local function RestorePosition(frame, default)
    frame:ClearAllPoints()
    local p = RP.CharDB.positions[frame.rpKey]
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint(default[1], UIParent, default[2], default[3], default[4])
    end
end

local function NewBar(key, title, default)
    local f = CreateFrame("Frame", "RaidPower" .. key .. "Bar", UIParent)
    f.rpKey = key
    f:SetSize(120, 60)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    St.Skin(f, St.BG_HUD)
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT", 0, 0)
    h:SetPoint("TOPRIGHT", 0, 0)
    h:SetHeight(HEADER + 4)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function()
        if RP.S.locked or InCombatLockdown() then return end
        f:StartMoving()
    end)
    h:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        SavePosition(f)
    end)
    h:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then RP.ToggleWindow() end
    end)
    W.AttachTooltip(h, "RaidPower", "Drag to move (unless locked). Right-click: open RaidPower.")
    f.dot = St.Tex(h, "ARTWORK", St.Accent())
    f.dot:SetSize(6, 6)
    f.dot:SetPoint("TOPLEFT", PAD, -PAD - 3)
    f.title = St.Text(h, 12, "bold")
    f.title:SetPoint("LEFT", f.dot, "RIGHT", 6, 0)
    f.sub = St.Text(h, 12, "hdr")
    f.sub:SetPoint("LEFT", f.title, "RIGHT", 4, 0)
    f.sub:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    f.right = St.Text(h, 11, "hdr")
    f.right:SetPoint("TOPRIGHT", -PAD, -PAD + 1)
    f.right:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
    St.OnAccent(function(r, g, b)
        f.dot:SetVertexColor(r, g, b, 1)
        f.title:SetTextColor(r, g, b)
    end)
    f.title:SetText(title:upper())
    f.header = h
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", PAD, -(PAD + HEADER))
    f.labels = {}
    RestorePosition(f, default)
    f:Hide()
    bars[key] = f
    return f
end

local function Label(bar, i)
    local fs = bar.labels[i]
    if not fs then
        fs = St.Text(bar.content, 11, "hdr")
        bar.labels[i] = fs
    end
    fs:Show()
    return fs
end

local function HideLabels(bar, from)
    for i = from, #bar.labels do bar.labels[i]:Hide() end
end

-- Tiles by name (created on demand, out of combat) ----------------------------------------------------------
local function Tile(name, parent, size, kind)
    local b = _G[name]
    if not b then b = RP.CreateTile(name, parent, size, kind) end
    if b:GetParent() ~= parent then b:SetParent(parent) end
    if kind ~= "pill" then St.SetIconSize(b, size) else b:SetSize(size, math.floor(size * 0.8)) end
    b.rpUsed = true
    return b
end

local function HideUnused(prefix)
    for _, b in ipairs(RP.tiles) do
        if not b.rpUsed and b:GetName() and b:GetName():find(prefix, 1, true) == 1 then
            b:Hide()
            RP.SetTileQueue(b, {})
        end
    end
end

-- Layout ---------------------------------------------------------------------------------------------------
local function ClassLabel(fs, class)
    local c = RP.CLASS_COLORS[class]
    fs:SetText(RP.CLASS_SHORT[class]:upper())
    fs:SetTextColor(c[1], c[2], c[3])
end

local function LayoutMain(state)
    local bar = bars.Main
    local size = RP.S.iconSize
    local compact = RP.S.layout == "compact"
    local labels = RP.S.classLabels and not compact
    for _, b in ipairs(RP.tiles) do b.rpUsed = nil end
    local li = 1
    local x, y, maxX = 0, 0, 0
    local rowH = size + (labels and 18 or 8)
    bar.map = {}

    local function Place(b, data, px, py)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar.content, "TOPLEFT", px, py)
        b:Show()
        b.data = data
        bar.map[#bar.map + 1] = b
    end

    local cls = state.class
    if cls == "PALADIN" then
        local selfByKey = {}
        for _, t in ipairs(state.selfTiles) do selfByKey[t.key] = t end
        local head = {}
        if selfByKey.aura then head[#head + 1] = { "RaidPowerAura", selfByKey.aura, "AURA" } end
        if selfByKey.fury then head[#head + 1] = { "RaidPowerFury", selfByKey.fury, "FURY" } end
        if state.salvation then head[#head + 1] = { "RaidPowerSalv", state.salvation, "SALV" } end
        local vertical = RP.S.palVertical
        for _, h in ipairs(head) do
            local b = Tile(h[1], bar.content, size)
            Place(b, h[2], x, y)
            if labels and not vertical then
                local fs = Label(bar, li); li = li + 1
                fs:ClearAllPoints(); fs:SetPoint("TOP", b, "BOTTOM", 0, -6)
                fs:SetText(h[3]); fs:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
            end
            if vertical then y = y - (size + 10) else x = x + size + GAP end
        end
        if #head > 0 then
            if vertical then y = y - 6 else x = x + 8 end
        end
        for i, t in ipairs(state.blessings) do
            local b = Tile("RaidPowerClass" .. i, bar.content, size)
            Place(b, t, x, y)
            St.ClassCorner(b, t.class)
            if labels then
                local fs = Label(bar, li); li = li + 1
                fs:ClearAllPoints()
                if vertical then fs:SetPoint("LEFT", b, "RIGHT", 8, 0) else fs:SetPoint("TOP", b, "BOTTOM", 0, -6) end
                ClassLabel(fs, t.class)
            end
            if vertical then y = y - (size + 10) else x = x + size + GAP end
            maxX = math.max(maxX, x)
        end
        if vertical then
            maxX = size + (labels and 40 or 0)
            y = y + 10 - size
            y = y - (size + 6)
        else
            maxX = math.max(maxX, x)
            y = y - rowH
        end
        x = 0
    end

    -- Group families.
    if #state.groupRows > 0 then
        if compact then
            for _, row in ipairs(state.groupRows) do
                local b = Tile("RaidPowerFam" .. row.fam.key, bar.content, size)
                Place(b, row.all, x, y)
                x = x + size + GAP
            end
            if state.thorns then
                local b = Tile("RaidPowerThorns", bar.content, size)
                Place(b, state.thorns, x, y)
                x = x + size + GAP
            end
            maxX = math.max(maxX, x)
            y = y - (size + 10)
        else
            local small = math.max(24, math.floor(size * 0.7))
            local pill = 28
            for _, row in ipairs(state.groupRows) do
                local fs = Label(bar, li); li = li + 1
                fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", bar.content, "TOPLEFT", 0, y - (small / 2 - 5))
                fs:SetText(row.fam.label:upper()); fs:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
                local b = Tile("RaidPowerFam" .. row.fam.key, bar.content, small)
                Place(b, row.all, 74, y)
                local px = 74 + small + 8
                for g = 1, 8 do
                    local p = Tile("RaidPowerPill" .. row.fam.key .. g, bar.content, pill, "pill")
                    Place(p, row.groups[g], px, y - math.floor((small - pill * 0.8) / 2))
                    px = px + pill + 4
                end
                maxX = math.max(maxX, px)
                y = y - (small + 12)
            end
            if state.thorns then
                local fs = Label(bar, li); li = li + 1
                fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", bar.content, "TOPLEFT", 0, y - (small / 2 - 5))
                fs:SetText("THORNS"); fs:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
                local b = Tile("RaidPowerThorns", bar.content, small)
                Place(b, state.thorns, 74, y)
                maxX = math.max(maxX, 74 + small)
                y = y - (small + 12)
            end
        end
    end
    HideLabels(bar, li)
    HideUnused("RaidPowerAura"); HideUnused("RaidPowerFury"); HideUnused("RaidPowerSalv")
    HideUnused("RaidPowerClass"); HideUnused("RaidPowerFam"); HideUnused("RaidPowerPill"); HideUnused("RaidPowerThorns")
    local w, h = math.max(maxX - GAP, 100), -y - 4
    local sub = cls == "PALADIN" and "· blessings" or "· group buffs"
    bar.title:SetText(RP.ClassName(cls):upper())
    bar.sub:SetText(sub)
    bar.right:SetText(RP.inRaid and ("Raid · %d"):format(#RP.roster) or (IsInGroup() and "Party" or "Solo"))
    bar.content:SetSize(w, h)
    bar:SetSize(FitWidth(bar, w), h + PAD * 2 + HEADER)
    bar.hasContent = #bar.map > 0
end

local function LayoutSelf(state)
    local bar = bars.Self
    local size = RP.S.iconSize
    for _, b in ipairs(RP.tiles) do if (b:GetName() or ""):find("RaidPowerSelf", 1, true) then b.rpUsed = nil end end
    bar.map = {}
    local x = 0
    local i = 0
    for _, t in ipairs(state.selfTiles) do
        local onMain = state.class == "PALADIN" and (t.key == "aura" or t.key == "fury") and RP.S.layout ~= "smart"
        if not onMain then
            i = i + 1
            local b = Tile("RaidPowerSelf" .. i, bar.content, size)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", bar.content, "TOPLEFT", x, 0)
            b:Show()
            b.data = t
            bar.map[#bar.map + 1] = b
            x = x + size + GAP
        end
    end
    HideUnused("RaidPowerSelf")
    local w = math.max(x - GAP, 60)
    bar.title:SetText("SELF")
    bar.sub:SetText("· buffs")
    bar.right:SetText("")
    bar.content:SetSize(w, size + 6)
    bar:SetSize(FitWidth(bar, w), size + 6 + PAD * 2 + HEADER)
    bar.hasContent = #bar.map > 0
end

-- Smart Buff ------------------------------------------------------------------------------------------------
local function LayoutSmart()
    local bar = bars.Smart
    local b = _G.RaidPowerSmartButton
    if not b then
        b = RP.CreateTile("RaidPowerSmartButton", bar.content, 40, "tile", true)
        b.isSmart = true
        b.action = St.Text(bar.content, 15, "bold")
        b.action:SetPoint("TOPLEFT", b, "TOPRIGHT", 10, -3)
        b.detail = St.Text(bar.content, 11, "body")
        b.detail:SetPoint("TOPLEFT", b.action, "BOTTOMLEFT", 0, -3)
        b.detail:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
        b.keyBg = St.Tex(bar.content, "ARTWORK", St.Accent())
        b.key = St.Text(bar.content, 11, "bold")
        b.key:SetTextColor(0.07, 0.07, 0.07)
        b.key:SetPoint("RIGHT", bar.content, "RIGHT", -4, 0)
        b.keyBg:SetPoint("TOPLEFT", b.key, -4, 2); b.keyBg:SetPoint("BOTTOMRIGHT", b.key, 4, -2)
        St.OnAccent(function(r, g, bl) b.keyBg:SetVertexColor(r, g, bl, 1) end)
        b.grad = St.Tex(bar, "BACKGROUND", St.Accent(0.18), -7)
        b.grad:SetAllPoints()
        if b.grad.SetGradient and CreateColor then
            local r, g, bl = RP.Accent()
            pcall(b.grad.SetGradient, b.grad, "HORIZONTAL", CreateColor(r, g, bl, 0.20), CreateColor(r, g, bl, 0))
        end
        St.OnAccent(function(r, g, bl)
            if b.grad.SetGradient and CreateColor then
                pcall(b.grad.SetGradient, b.grad, "HORIZONTAL", CreateColor(r, g, bl, 0.20), CreateColor(r, g, bl, 0))
            end
        end)
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", bar.content, "TOPLEFT", 0, 0)
    b:Show()
    bar.content:SetSize(280, 40)
    bar:SetSize(280 + PAD * 2, 40 + PAD * 2 + HEADER)
    bar.title:SetText("SMART BUFF")
    bar.sub:SetText("")
    bar.map = { b }
    bar.hasContent = true
end

function RP.SmartKey()
    local key = GetBindingKey and GetBindingKey("CLICK RaidPowerSmartButton:LeftButton")
    return key and GetBindingText and GetBindingText(key, true) or key
end

-- Visibility ----------------------------------------------------------------------------------------------------
local function GroupAllowed()
    if IsInRaid() then return true end
    if IsInGroup() then return RP.S.showParty end
    return RP.S.showSolo
end

local function AnyDue(state)
    return state and #state.smart > 0
end

local function ApplyVisibility(state)
    if InCombatLockdown() then return end
    local allowed = GroupAllowed() and not RP.hiddenByUser
    local due = AnyDue(state)
    local hideDone = RP.S.hideWhenDone and not due
    local mode = RP.S.layout
    bars.Main:SetShown(allowed and mode ~= "smart" and bars.Main.hasContent and not hideDone)
    bars.Self:SetShown(allowed and RP.S.selfShown and mode ~= "smart" and bars.Self.hasContent and not hideDone)
    bars.Smart:SetShown(allowed and (RP.S.smartShown or mode == "smart") and not hideDone)
    -- Smart Buff docks under the main bar unless set to float.
    if not RP.S.smartSeparate and bars.Main:IsShown() then
        bars.Smart:ClearAllPoints()
        bars.Smart:SetPoint("TOPLEFT", bars.Main, "BOTTOMLEFT", 0, -6)
        bars.Smart.docked = true
    elseif bars.Smart.docked then
        RestorePosition(bars.Smart, RP.DEFAULT_POS.Smart)
        bars.Smart.docked = false
    end
end

-- Public: layout (out of combat) and paint (any time) -------------------------------------------------------------
function RP.LayoutBars(state)
    if InCombatLockdown() then
        RP.AfterCombat("layout", function() RP.LayoutBars(RP.BuildState()) end)
        return
    end
    for _, bar in pairs(bars) do bar:SetScale(RP.S.scale or 1) end
    LayoutMain(state)
    LayoutSelf(state)
    LayoutSmart()
    ApplyVisibility(state)
    RP.layoutSig = RP.LayoutSignature(state)
end

-- What the layout depends on: if it changes, tiles must be rebuilt (out of combat).
function RP.LayoutSignature(state)
    local parts = { state.class, RP.S.layout, RP.S.iconSize, tostring(RP.S.classLabels), tostring(RP.S.palVertical) }
    for _, t in ipairs(state.blessings) do parts[#parts + 1] = t.class end
    parts[#parts + 1] = state.salvation and "S" or "-"
    for _, r in ipairs(state.groupRows) do parts[#parts + 1] = r.fam.key end
    parts[#parts + 1] = state.thorns and "T" or "-"
    for _, t in ipairs(state.selfTiles) do parts[#parts + 1] = t.key end
    return table.concat(parts, ",")
end

local function PaintTile(b, t)
    if not t then return end
    if b.kind == "pill" then
        RP.PaintPill(b, t)
    else
        local icon = t.icon or (t.spell and RP.SpellIcon(t.spell)) or (t.fam and RP.SpellIcon(t.fam.single[1])) or RP.QUESTION
        b.ic.tex:SetTexture(icon)
        St.Paint(b, t.status or "ok", t.missing + (t.status == "warn" and t.expiring or 0), t.shortest)
    end
    if not InCombatLockdown() then RP.SetTileQueue(b, t.queue) end
end

local function PaintSmart(state)
    local b = _G.RaidPowerSmartButton
    if not b then return end
    local e = state.smart[1]
    if e then
        b.ic.tex:SetTexture(e.item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.item) or RP.SpellIcon(e.spellG))
        local target = e.self and "" or (" → " .. RP.ShortName(e.m.who))
        if e.tile and e.tile.kind == "group" and RP.GROUP_SPELL[e.spellG] then target = " → Group " .. e.tile.group end
        if e.tile and e.tile.kind == "blessing" and RP.GROUP_SPELL[e.spellG] then target = " → " .. RP.ClassName(e.tile.class) end
        local name = e.item and (C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.item)) or RP.SpellName(e.spellG)
        b.action:SetText((name or "?") .. target)
        local missing = 0
        for _, s in ipairs(state.smart) do if s.rank == RP.RANK_MISSING then missing = missing + 1 end end
        b.detail:SetText(("%d missing · %d queued"):format(missing, #state.smart))
        St.Paint(b, e.rank == RP.RANK_MISSING and "bad" or "warn", nil, nil, false)
    else
        b.ic.tex:SetTexture(RP.SpellIcon(20217) ~= RP.QUESTION and St.LOGO or St.LOGO)
        b.ic.tex:SetTexCoord(0, 1, 0, 1)
        b.action:SetText("All buffed")
        b.detail:SetText("Nothing due right now")
        St.Paint(b, "ok", nil, nil, false)
    end
    if e then b.ic.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    local key = RP.SmartKey()
    b.key:SetText(key or "")
    b.keyBg:SetShown(key ~= nil)
    if not InCombatLockdown() then RP.SetTileQueue(b, state.smart) end
end

function RP.PaintBars(state)
    if not state then return end
    if not InCombatLockdown() and RP.layoutSig ~= RP.LayoutSignature(state) then
        RP.LayoutBars(state)
    end
    for _, bar in pairs(bars) do
        for _, b in ipairs(bar.map or {}) do
            if not b.isSmart then
                -- Re-bind data from the fresh state by tile role.
                PaintTile(b, RP.TileData(b, state))
            end
        end
    end
    PaintSmart(state)
    -- Header context.
    local n = 0
    for _, t in ipairs(state.blessings) do n = n + t.missing end
    bars.Main.right:SetText(RP.inRaid and ("Raid · %d"):format(#RP.roster) or (IsInGroup() and "Party" or "Solo"))
    -- Fading.
    local fade = RP.S.fadeOOC and not RP.InCombat() and #state.smart == 0
    for _, bar in pairs(bars) do bar:SetAlpha(fade and 0.4 or 1) end
    ApplyVisibility(state)
    if RP.flyoutOwner and RP.flyoutOwner:IsMouseOver() then RP.ShowFlyout(RP.flyoutOwner) end
end

-- Map a tile frame back to its data in a new state, by its name.
function RP.TileData(b, state)
    local name = b:GetName() or ""
    local selfByKey = {}
    for _, t in ipairs(state.selfTiles) do selfByKey[t.key] = t end
    if name == "RaidPowerAura" then return selfByKey.aura end
    if name == "RaidPowerFury" then return selfByKey.fury end
    if name == "RaidPowerSalv" then return state.salvation end
    if name == "RaidPowerThorns" then return state.thorns end
    local i = name:match("^RaidPowerClass(%d+)$")
    if i then return state.blessings[tonumber(i)] end
    local fk = name:match("^RaidPowerFam(%a+)$")
    if fk then
        for _, r in ipairs(state.groupRows) do if r.fam.key == fk then return r.all end end
    end
    local pk, g = name:match("^RaidPowerPill(%a+)(%d)$")
    if pk then
        for _, r in ipairs(state.groupRows) do if r.fam.key == pk then return r.groups[tonumber(g)] end end
    end
    local si = name:match("^RaidPowerSelf(%d+)$")
    if si then
        local idx = 0
        for _, t in ipairs(state.selfTiles) do
            local onMain = state.class == "PALADIN" and (t.key == "aura" or t.key == "fury") and RP.S.layout ~= "smart"
            if not onMain then
                idx = idx + 1
                if idx == tonumber(si) then return t end
            end
        end
    end
    return b.data
end

-- Flyout: who is (not) buffed, on hover. Display only, so it also works in combat. -------------------------------
local flyout
local function Flyout()
    if flyout then return flyout end
    flyout = CreateFrame("Frame", "RaidPowerFlyout", UIParent)
    flyout:SetFrameStrata("TOOLTIP")
    St.Skin(flyout, St.BG)
    flyout.title = St.Text(flyout, 13, "bold")
    flyout.title:SetPoint("TOPLEFT", 8, -7)
    flyout.right = St.Text(flyout, 12, "hdr")
    flyout.right:SetPoint("TOPRIGHT", -8, -7)
    flyout.right:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    flyout.line = St.Tex(flyout, "ARTWORK", St.LINE)
    flyout.line:SetHeight(1)
    flyout.line:SetPoint("TOPLEFT", 6, -24); flyout.line:SetPoint("TOPRIGHT", -6, -24)
    flyout.rows = {}
    flyout.hint = St.Text(flyout, 10, "body")
    flyout.hint:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
    flyout:Hide()
    return flyout
end

local function FlyRow(i)
    local f = Flyout()
    local r = f.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, f)
        r:SetHeight(18)
        r.name = St.Text(r, 12, "body")
        r.name:SetPoint("LEFT", 4, 0)
        r.time = St.Text(r, 13, "hdr")
        r.time:SetPoint("RIGHT", -4, 0)
        r.barBg = St.Tex(r, "ARTWORK", { 1, 1, 1, 0.07 })
        r.barBg:SetSize(46, 2)
        r.barBg:SetPoint("RIGHT", r.time, "LEFT", -6, 0)
        r.bar = St.Tex(r, "OVERLAY", St.OK)
        r.bar:SetHeight(2)
        r.bar:SetPoint("LEFT", r.barBg, "LEFT")
        f.rows[i] = r
    end
    r:Show()
    return r
end

local TILE_TITLE = {
    blessing = function(t) return RP.ClassName(t.class), t.key and RP.BLESS_BY_KEY[t.key] and RP.BLESS_BY_KEY[t.key].label or "No blessing" end,
    salvation = function() return "Salvation", "non-tanks" end,
    group = function(t) return "Group " .. t.group, t.fam.label end,
    family = function(t) return t.fam.label, "your groups" end,
    thorns = function() return "Thorns", "tanks" end,
    self = function(t) return t.label or t.def.label, "self" end,
}

function RP.ShowFlyout(owner)
    local t = owner.isSmart and nil or RP.TileData(owner, RP.state or {})
    local f = Flyout()
    RP.flyoutOwner = owner
    if owner.isSmart then
        local state = RP.state
        if not state then return end
        f.title:SetText("SMART BUFF")
        f.right:SetText(#state.smart .. " due")
        local n = 0
        for i, e in ipairs(state.smart) do
            if i > 12 then break end
            n = i
            local r = FlyRow(i)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, -28 - (i - 1) * 18); r:SetPoint("TOPRIGHT", -4, -28 - (i - 1) * 18)
            local c = RP.CLASS_COLORS[e.m.class] or { 1, 1, 1 }
            r.name:SetText(RP.SpellName(e.spellG) .. "  |c" .. RP.ClassHex(e.m.class) .. RP.ShortName(e.m.who) .. "|r")
            r.name:SetTextColor(St.TEXT[1], St.TEXT[2], St.TEXT[3])
            r.time:SetText(e.rank == RP.RANK_MISSING and "MISSING" or RP.FormatTime(e.left))
            local sc = e.rank == RP.RANK_MISSING and St.BAD or St.WARN
            r.time:SetTextColor(sc[1], sc[2], sc[3])
            r.bar:Hide(); r.barBg:Hide()
            local _ = c
        end
        for i = n + 1, #f.rows do f.rows[i]:Hide() end
        f.hint:SetText("Bind a key: Key Bindings > AddOns > RaidPower")
        f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", 8, -32 - n * 18)
        f:SetSize(260, 48 + n * 18)
    else
        if not t or not t.members then f:Hide() return end
        local fn = TILE_TITLE[t.kind]
        local title, right = "RaidPower", ""
        if fn then title, right = fn(t) end
        f.title:SetText(title:upper())
        if t.class then
            local c = RP.CLASS_COLORS[t.class]
            f.title:SetTextColor(c[1], c[2], c[3])
        else
            f.title:SetTextColor(St.TEXT[1], St.TEXT[2], St.TEXT[3])
        end
        f.right:SetText(right or "")
        local rows = {}
        for _, r in ipairs(t.members) do rows[#rows + 1] = r end
        table.sort(rows, function(a, b)
            local ra, rb = a.rank or 3, b.rank or 3
            if ra ~= rb then return ra < rb end
            return a.m.who < b.m.who
        end)
        local n = 0
        for i, row in ipairs(rows) do
            if i > 15 then break end
            n = i
            local r = FlyRow(i)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, -28 - (i - 1) * 18); r:SetPoint("TOPRIGHT", -4, -28 - (i - 1) * 18)
            local c = RP.CLASS_COLORS[row.m.class] or { 1, 1, 1 }
            r.name:SetText(RP.ShortName(row.m.who) == row.m.who and row.m.who or row.m.who)
            r.name:SetTextColor(c[1], c[2], c[3])
            r.bar:Show(); r.barBg:Show()
            local status, text
            if row.range == false and (row.rank or 2) < 2 then
                status, text = "oor", "OUT OF RANGE"
            elseif row.rank == nil then
                status, text = "unk", "?"
            elseif row.rank == RP.RANK_MISSING then
                status, text = "bad", "MISSING"
            elseif row.rank == RP.RANK_EXPIRING then
                status, text = "warn", RP.FormatTime(row.left)
            else
                status, text = "ok", row.left and RP.FormatTime(row.left) or "ON"
            end
            local sc = St.STATUS[status]
            r.time:SetText(text)
            r.time:SetTextColor(status == "ok" and 1 or sc[1], status == "ok" and 1 or sc[2], status == "ok" and 1 or sc[3])
            r.bar:SetVertexColor(sc[1], sc[2], sc[3], 1)
            local pct = 0
            if row.left and row.rank and row.rank > 0 then pct = math.min(1, row.left / 3600) end
            if row.rank == RP.RANK_OK and not row.left then pct = 1 end
            r.bar:SetWidth(math.max(0.01, pct * 46))
            r.bar:SetShown(pct > 0)
            r:SetAlpha(status == "oor" and 0.5 or 1)
        end
        for i = n + 1, #f.rows do f.rows[i]:Hide() end
        local hint = "Left: cast · Right: single · Alt-click: options"
        if t.kind == "self" then hint = "Click: cast" end
        f.hint:SetText(hint)
        f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", 8, -32 - n * 18)
        f:SetSize(230, 48 + n * 18)
    end
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", owner, "TOP", 0, 10)
    f:SetScale(RP.S.scale or 1)
    f:Show()
end

function RP.HideFlyout()
    RP.flyoutOwner = nil
    if flyout then flyout:Hide() end
end

-- Construction ---------------------------------------------------------------------------------------------------
function RP.CreateBars()
    NewBar("Main", "RaidPower", RP.DEFAULT_POS.Main)
    NewBar("Self", "Self", RP.DEFAULT_POS.Self)
    NewBar("Smart", "Smart Buff", RP.DEFAULT_POS.Smart)
end

function RP.ResetPositions()
    if InCombatLockdown() then return end
    wipe(RP.CharDB.positions)
    RestorePosition(bars.Main, RP.DEFAULT_POS.Main)
    RestorePosition(bars.Self, RP.DEFAULT_POS.Self)
    RestorePosition(bars.Smart, RP.DEFAULT_POS.Smart)
end
