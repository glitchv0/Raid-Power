-- PageAssign.lua: who buffs what. Paladins per class (with per-player exceptions), priests/mages/druids per
-- group, shamans per totem element. Changes sync; the leader and assists may edit every row.
local _, RP = ...

local St, W = RP.Style, RP.Widgets
local tab = nil
local ROW_H, NAME_W = 40, 190
local TABS = {
    { "PALADIN", "Paladin" }, { "PRIEST", "Priest" }, { "MAGE", "Mage" }, { "DRUID", "Druid" }, { "SHAMAN", "Shaman" },
}

-- Rows to show: buffers present (you included). Solo or nobody of that class: just you if you are one.
local function RowsFor(class)
    local rows = RP.Buffers(class)
    return rows
end

local function Editable(who)
    return RP.MayEdit(RP.PlayerName(), who)
end

-- Get a writable plan for `who` and commit it afterwards.
local function EditPlan(who)
    local me = RP.PlayerName()
    if who == me then return RP.MyPlan() end
    local p = RP.plans[who]
    if not p then
        p = { class = RP.byWho[who] and RP.byWho[who].class, groups = {}, pal = { classes = {}, players = {} }, totems = {} }
        RP.plans[who] = p
    end
    p.groups = p.groups or {}
    p.pal = p.pal or { classes = {}, players = {} }
    p.pal.classes = p.pal.classes or {}
    p.pal.players = p.pal.players or {}
    p.totems = p.totems or {}
    return p
end

local function Commit(who, plan)
    local me = RP.PlayerName()
    plan.auto = false
    if who == me then
        RP.CharDB.planned = true
        RP.BroadcastSoon()
    else
        RP.SendPlanFor(who, plan)
    end
    RP.lastChange = { by = me, at = GetTime() }
    RP.RequestRefresh()
    RP.pages.assign.refresh(RP.pages.assign.frame)
end
RP.CommitPlan = Commit

-- Cells ------------------------------------------------------------------------------------------------------
local function IconCell(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local edge = St.Tex(b, "BACKGROUND", { 0, 0, 0, 1 })
    edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(St.WHITE); hl:SetAllPoints(); hl:SetVertexColor(1, 1, 1, 0.15)
    b.mark = St.Text(b, 10, "bold", "OVERLAY", "OUTLINE")
    b.mark:SetPoint("BOTTOMRIGHT", 2, -2)
    return b
end

local function SetCellIcon(b, tex, on)
    b.icon:SetTexture(tex or RP.QUESTION)
    b.icon:SetDesaturated(not on)
    b.icon:SetVertexColor(on and 1 or 0.35, on and 1 or 0.35, on and 1 or 0.35)
end

-- Header ------------------------------------------------------------------------------------------------------
local function Build(f)
    RP.PageHeader(f, "Assignments")
    f.tabs = {}
    local x = 0
    for i = #TABS, 1, -1 do
        local t = TABS[i]
        local b = CreateFrame("Button", nil, f)
        b:SetSize(86, 26)
        St.Skin(b, { 0.09, 0.1, 0.12, 1 })
        b.bg = St.Tex(b, "BACKGROUND", { 0, 0, 0, 0 }, 1)
        b.bg:SetPoint("TOPLEFT", 1, -1); b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", 7, 0)
        RP.SetClassIcon(b.icon, t[1])
        b.text = St.Text(b, 12, "hdr")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
        b.text:SetText(t[2]:upper())
        b.class = t[1]
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -x, 2)
        x = x + 88
        b:SetScript("OnClick", function() tab = t[1]; RP.pages.assign.refresh(f) end)
        f.tabs[#f.tabs + 1] = b
    end

    f.grid = CreateFrame("Frame", nil, f)
    f.grid:SetPoint("TOPLEFT", 0, -40)
    f.grid:SetPoint("BOTTOMRIGHT", 0, 64)
    f.headers, f.rows = {}, {}

    f.auto = W.Button(f, "Auto-assign", 110, true)
    f.auto:SetPoint("BOTTOMLEFT", 0, 30)
    f.auto:SetScript("OnClick", function() RP.RunAutoAssign() end)
    W.AttachTooltip(f.auto, "Auto-assign", "Splits groups and blessings between everyone present. The leader and assists apply it to all buffers; anyone else only to themselves (everyone running auto mode lands on the same split).")
    f.clear = W.Button(f, "Clear", 70)
    f.clear:SetPoint("LEFT", f.auto, "RIGHT", 8, 0)
    f.clear:SetScript("OnClick", function() RP.ClearAssignments(tab) end)
    f.refreshBtn = W.Button(f, "Ask for plans", 110)
    f.refreshBtn:SetPoint("LEFT", f.clear, "RIGHT", 8, 0)
    f.refreshBtn:SetScript("OnClick", function() RP.AskPlans(); RP.BroadcastPlan() end)
    f.announce = W.Button(f, "Announce", 96)
    f.announce:SetPoint("BOTTOMRIGHT", 0, 30)
    f.announce:SetScript("OnClick", function() RP.Announce(tab) end)

    f.freeLabel = St.Text(f, 11, "body")
    f.freeLabel:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    f.freeLabel:SetText("Let anyone edit my assignments")
    f.free = W.Toggle(f, function() return RP.MyPlan().free end, function(v)
        RP.MyPlan().free = v; RP.BroadcastSoon()
    end)
    f.free:SetPoint("RIGHT", f.announce, "LEFT", -12, 0)
    f.freeLabel:SetPoint("RIGHT", f.free, "LEFT", -8, 0)

    f.hint = St.Text(f, 11, "body")
    f.hint:SetPoint("BOTTOMLEFT", 0, 4)
    f.hint:SetPoint("BOTTOMRIGHT", 0, 4)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetWordWrap(true)
    f.hint:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])

    f.empty = St.Text(f.grid, 14, "body")
    f.empty:SetPoint("CENTER")
    f.empty:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
end

-- Grid helpers -----------------------------------------------------------------------------------------------------
local function Header(f, i, x, text, class, icon)
    local h = f.headers[i]
    if not h then
        h = CreateFrame("Frame", nil, f.grid)
        h:SetSize(44, 36)
        h.icon = h:CreateTexture(nil, "ARTWORK")
        h.icon:SetSize(20, 20); h.icon:SetPoint("TOP", 0, 0)
        h.text = St.Text(h, 11, "hdr")
        h.text:SetPoint("TOP", h.icon, "BOTTOM", 0, -3)
        f.headers[i] = h
    end
    h:ClearAllPoints()
    h:SetPoint("TOP", f.grid, "TOPLEFT", x, 0)
    h:Show()
    if class then
        RP.SetClassIcon(h.icon, class)
        local c = RP.CLASS_COLORS[class]
        h.text:SetTextColor(c[1], c[2], c[3])
        h.icon:Show()
    elseif icon then
        h.icon:SetTexture(icon); h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); h.icon:Show()
        h.text:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    else
        h.icon:Hide()
        h.text:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    end
    h.text:SetText(text:upper())
    return h
end

local function Row(f, i)
    local r = f.rows[i]
    if not r then
        r = CreateFrame("Frame", nil, f.grid)
        r:SetHeight(ROW_H)
        r.line = St.Tex(r, "BACKGROUND", St.LINE)
        r.line:SetHeight(1); r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
        r.cls = r:CreateTexture(nil, "ARTWORK")
        r.cls:SetSize(24, 24); r.cls:SetPoint("LEFT", 2, 0)
        r.name = St.Text(r, 13, "body")
        r.name:SetPoint("TOPLEFT", r.cls, "TOPRIGHT", 8, 1)
        r.name:SetWidth(NAME_W - 40); r.name:SetJustifyH("LEFT")
        r.dot = St.Tex(r, "ARTWORK", St.OK)
        r.dot:SetSize(6, 6); r.dot:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5)
        r.sub = St.Text(r, 10, "body")
        r.sub:SetPoint("LEFT", r.dot, "RIGHT", 5, 0)
        r.sub:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
        r.cells = {}
        f.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f.grid, "TOPLEFT", 0, -40 - (i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", f.grid, "TOPRIGHT", 0, -40 - (i - 1) * ROW_H)
    r:Show()
    return r
end

local function RowInfo(r, b)
    local me = RP.PlayerName()
    RP.SetClassIcon(r.cls, b.m.class)
    local c = RP.CLASS_COLORS[b.m.class]
    r.name:SetText(b.who)
    r.name:SetTextColor(c[1], c[2], c[3])
    local status, color
    if b.who == me then
        status, color = "you · " .. ((b.plan and b.plan.auto) and "auto split" or "manual"), St.OK
    elseif b.plan then
        status, color = "synced · v" .. (RP.versions[b.who] or "?"), St.OK
        if b.plan.auto then status = status .. " · auto" end
    else
        status, color = "no RaidPower", St.FAINT
    end
    if not Editable(b.who) then status = status .. " · read-only" end
    r.sub:SetText(status)
    r.dot:SetVertexColor(color[1], color[2], color[3], 1)
end

local function Cell(r, k, size)
    local cell = r.cells[k]
    if not cell then
        cell = IconCell(r, size)
        r.cells[k] = cell
    end
    cell:SetSize(size, size)
    cell:Show()
    return cell
end

local function HideFrom(list, from)
    for i = from, #list do list[i]:Hide() end
end

local function HideCells(r, from)
    for k = from, #r.cells do r.cells[k]:Hide() end
end

-- Paladin -------------------------------------------------------------------------------------------------------------
local function BlessIcon(key)
    local e = key and RP.BLESS_BY_KEY[key]
    return e and RP.SpellIcon(e.ranks[1]) or "Interface\\Icons\\Spell_Holy_Dizzy"
end

local CYCLE = { "kings", "might", "wisdom", "light", "sanctuary" }

local function NextBlessing(b, current, dir)
    local list = {}
    for _, k in ipairs(CYCLE) do if RP.KnowsKey(b, k) then list[#list + 1] = k end end
    list[#list + 1] = false
    local idx = #list
    for i, k in ipairs(list) do if k == (current or false) then idx = i end end
    idx = ((idx - 1 + (dir or 1)) % #list) + 1
    return list[idx] or nil
end

local function PlayerMenu(cell, b, class)
    local items = {}
    local plan = EditPlan(b.who)
    for _, k in ipairs(CYCLE) do
        if RP.KnowsKey(b, k) then
            items[#items + 1] = { text = RP.BLESS_BY_KEY[k].label .. " for all " .. RP.ClassName(class), icon = BlessIcon(k),
                checked = plan.pal.classes[class] == k,
                func = function() plan.pal.classes[class] = k; Commit(b.who, plan) end }
        end
    end
    items[#items + 1] = { text = "No blessing", checked = plan.pal.classes[class] == nil,
        func = function() plan.pal.classes[class] = nil; Commit(b.who, plan) end }
    for _, m in ipairs(RP.roster) do
        if m.class == class then
            local cur = plan.pal.players[m.guid]
            local label = cur and (cur == "none" and "none" or RP.BLESS_BY_KEY[cur].label) or "class default"
            items[#items + 1] = { text = ("  %s: %s"):format(RP.ShortName(m.who), label), icon = cur and cur ~= "none" and BlessIcon(cur) or nil,
                func = function()
                    -- Cycle: class default -> each known blessing -> none -> class default
                    local order = { false }
                    for _, k in ipairs(CYCLE) do if RP.KnowsKey(b, k) then order[#order + 1] = k end end
                    order[#order + 1] = "none"
                    local idx = 1
                    for i, k in ipairs(order) do if k == (cur or false) then idx = i end end
                    local nxt = order[(idx % #order) + 1]
                    plan.pal.players[m.guid] = nxt or nil
                    Commit(b.who, plan)
                end }
        end
    end
    W.Menu(cell, items, RP.ClassName(class) .. " · exceptions below")
end

local function LayoutPaladin(f)
    local rows = RowsFor("PALADIN")
    local x0 = NAME_W + 22
    for i, class in ipairs(RP.CLASSES) do Header(f, i, x0 + (i - 1) * 46, RP.CLASS_SHORT[class], class) end
    Header(f, 10, x0 + 9 * 46 + 12, "Aura", nil, "Interface\\Icons\\Spell_Holy_DevotionAura")
    Header(f, 11, x0 + 10 * 46 + 18, "Salv", nil, RP.SpellIcon(1038))
    HideFrom(f.headers, 12)
    for ri, b in ipairs(rows) do
        local r = Row(f, ri)
        RowInfo(r, b)
        local plan = b.plan or {}
        local pal = plan.pal or { classes = {}, players = {} }
        local editable = Editable(b.who)
        for i, class in ipairs(RP.CLASSES) do
            local cell = Cell(r, i, 28)
            cell:ClearAllPoints()
            cell:SetPoint("CENTER", r, "LEFT", x0 + (i - 1) * 46, 0)
            local key = pal.classes and pal.classes[class]
            SetCellIcon(cell, BlessIcon(key), key ~= nil)
            local n = 0
            for _, k in pairs(pal.players or {}) do if k then n = n + 1 end end
            local exc = 0
            for guid in pairs(pal.players or {}) do
                local m = RP.byGuid[guid]
                if m and m.class == class then exc = exc + 1 end
            end
            cell.mark:SetText(exc > 0 and ("+" .. exc) or "")
            cell:SetScript("OnClick", function(self, button)
                if not editable then return end
                if button == "RightButton" then PlayerMenu(self, b, class) return end
                local p = EditPlan(b.who)
                p.pal.classes[class] = NextBlessing(b, p.pal.classes[class], IsShiftKeyDown() and -1 or 1)
                Commit(b.who, p)
            end)
            cell:SetScript("OnEnter", function(self)
                W.Tooltip(self, RP.ClassName(class) .. ": " .. (key and RP.BLESS_BY_KEY[key].label or "none"),
                    editable and "Click: next blessing (Shift: previous). Right-click: per-player exceptions." or "Read-only: only the leader or assists can change this.")
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        -- Aura
        local ac = Cell(r, 10, 28)
        ac:ClearAllPoints(); ac:SetPoint("CENTER", r, "LEFT", x0 + 9 * 46 + 12, 0)
        local a = pal.aura and RP.AURA_BY_KEY[pal.aura]
        SetCellIcon(ac, a and RP.SpellIcon(a.ranks[1]) or "Interface\\Icons\\Spell_Holy_DevotionAura", a ~= nil)
        ac.mark:SetText("")
        ac:SetScript("OnClick", function()
            if not editable then return end
            local p = EditPlan(b.who)
            local list = {}
            for _, au in ipairs(RP.AURAS) do if RP.KnowsKey(b, "aura:" .. au.key) then list[#list + 1] = au.key end end
            list[#list + 1] = false
            local idx = #list
            for i, k in ipairs(list) do if k == (p.pal.aura or false) then idx = i end end
            p.pal.aura = list[(idx % #list) + 1] or nil
            Commit(b.who, p)
        end)
        ac:SetScript("OnEnter", function(self) W.Tooltip(self, "Aura: " .. (a and a.label or "none"), "Click to cycle.") end)
        ac:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Salvation
        local sc = Cell(r, 11, 28)
        sc:ClearAllPoints(); sc:SetPoint("CENTER", r, "LEFT", x0 + 10 * 46 + 18, 0)
        SetCellIcon(sc, RP.SpellIcon(1038), pal.salv == true)
        sc.mark:SetText(pal.salv and "ON" or "")
        sc:SetScript("OnClick", function()
            if not editable then return end
            local p = EditPlan(b.who)
            p.pal.salv = not p.pal.salv
            Commit(b.who, p)
        end)
        sc:SetScript("OnEnter", function(self) W.Tooltip(self, "Salvation", "Gives Salvation to everyone who is not a tank. Click to toggle.") end)
        sc:SetScript("OnLeave", function() GameTooltip:Hide() end)
        HideCells(r, 12)
    end
    return #rows
end

-- Priest / Mage / Druid ----------------------------------------------------------------------------------------------------
local function LayoutGroups(f, class)
    local rows = RowsFor(class)
    local fams = {}
    for _, fam in ipairs(RP.FAMILIES) do if fam.class == class and fam.scope == "group" then fams[#fams + 1] = fam end end
    local x0 = NAME_W + 30
    local colW = class == "PRIEST" and 62 or 52
    for g = 1, 8 do Header(f, g, x0 + (g - 1) * colW + (#fams * 22) / 2 - 11, "Group " .. g) end
    local extra = 9
    if class == "DRUID" then Header(f, extra, x0 + 8 * colW + 20, "Thorns", nil, RP.SpellIcon(467)); extra = extra + 1 end
    HideFrom(f.headers, extra)
    for ri, b in ipairs(rows) do
        local r = Row(f, ri)
        RowInfo(r, b)
        local editable = Editable(b.who)
        local k = 0
        for g = 1, 8 do
            for fi, fam in ipairs(fams) do
                k = k + 1
                local cell = Cell(r, k, 20)
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", r, "LEFT", x0 + (g - 1) * colW + (fi - 1) * 22 - 11, 0)
                local on = RP.Covers(b.plan, fam.key, g)
                SetCellIcon(cell, RP.SpellIcon(fam.group and fam.group[1] or fam.single[1]), on)
                cell.mark:SetText("")
                cell:SetAlpha(RP.groupsPresent[g] and 1 or 0.45)
                cell:SetScript("OnClick", function()
                    if not editable then return end
                    local p = EditPlan(b.who)
                    RP.SetCover(p, fam.key, g, not RP.Covers(p, fam.key, g))
                    Commit(b.who, p)
                end)
                cell:SetScript("OnEnter", function(self)
                    W.Tooltip(self, ("%s · Group %d"):format(fam.label, g), on and "Covered by " .. RP.ShortName(b.who) .. ". Click to toggle." or "Not covered by " .. RP.ShortName(b.who) .. ". Click to toggle.")
                end)
                cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
        if class == "DRUID" then
            k = k + 1
            local cell = Cell(r, k, 22)
            cell:ClearAllPoints(); cell:SetPoint("CENTER", r, "LEFT", x0 + 8 * colW + 20, 0)
            local on = not (b.plan and b.plan.thorns == "none")
            SetCellIcon(cell, RP.SpellIcon(467), on)
            cell.mark:SetText(on and "T" or "")
            cell:SetScript("OnClick", function()
                if not editable then return end
                local p = EditPlan(b.who)
                p.thorns = (p.thorns == "none") and "tanks" or "none"
                Commit(b.who, p)
            end)
            cell:SetScript("OnEnter", function(self) W.Tooltip(self, "Thorns on tanks", "Click to toggle.") end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        HideCells(r, k + 1)
    end
    return #rows
end

-- Shaman ---------------------------------------------------------------------------------------------------------------------
local function LayoutShaman(f)
    local rows = RowsFor("SHAMAN")
    local x0 = NAME_W + 40
    for i, e in ipairs(RP.TOTEM_ELEMENTS) do Header(f, i, x0 + (i - 1) * 80, e) end
    HideFrom(f.headers, 5)
    for ri, b in ipairs(rows) do
        local r = Row(f, ri)
        RowInfo(r, b)
        local editable = Editable(b.who)
        for i, e in ipairs(RP.TOTEM_ELEMENTS) do
            local cell = Cell(r, i, 28)
            cell:ClearAllPoints(); cell:SetPoint("CENTER", r, "LEFT", x0 + (i - 1) * 80, 0)
            local cur = b.plan and b.plan.totems and b.plan.totems[e]
            local def
            for _, t in ipairs(RP.TOTEMS[e]) do if t.key == cur then def = t end end
            SetCellIcon(cell, def and RP.SpellIcon(def.id) or RP.SpellIcon(RP.TOTEMS[e][1].id), def ~= nil)
            cell.mark:SetText("")
            cell:SetScript("OnClick", function()
                if not editable then return end
                local p = EditPlan(b.who)
                local list = RP.TOTEMS[e]
                local idx = 0
                for k, t in ipairs(list) do if t.key == p.totems[e] then idx = k end end
                idx = idx + 1
                p.totems[e] = list[idx] and list[idx].key or nil
                Commit(b.who, p)
            end)
            cell:SetScript("OnEnter", function(self)
                W.Tooltip(self, e:gsub("^%l", string.upper) .. ": " .. (def and RP.SpellName(def.id) or "none"), "Click to cycle. Totems are a plan only; RaidPower does not track them.")
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        HideCells(r, 5)
    end
    return #rows
end

local HINTS = {
    PALADIN = "Click a cell to cycle its blessing (Shift-click: back). Right-click for per-player exceptions, e.g. the tank gets Kings instead of Salvation. Salvation stacks with blessings on Forever.",
    PRIEST = "Each group cell holds Fortitude · Spirit · Shadow Protection. Lit = this priest covers that group. Click to toggle.",
    MAGE = "Arcane Intellect / Brilliance per group. Auto-assign splits groups evenly between mages.",
    DRUID = "Mark / Gift of the Wild per group, plus Thorns on tanks.",
    SHAMAN = "Totems work per party: set which totem each shaman drops for each element. Plan only (not tracked).",
}

local function Refresh(f)
    if not tab then
        local _, class = UnitClass("player")
        tab = HINTS[class] and class or "PALADIN"
    end
    for _, b in ipairs(f.tabs) do
        local on = b.class == tab
        local r, g, bl = RP.Accent()
        b.bg:SetVertexColor(r, g, bl, on and 0.22 or 0)
        b.text:SetTextColor(on and 1 or St.MUTED[1], on and 1 or St.MUTED[2], on and 1 or St.MUTED[3])
    end
    local n
    if tab == "PALADIN" then n = LayoutPaladin(f)
    elseif tab == "SHAMAN" then n = LayoutShaman(f)
    else n = LayoutGroups(f, tab) end
    HideFrom(f.rows, n + 1)
    f.empty:SetShown(n == 0)
    f.empty:SetText(("No %s in your group."):format(RP.ClassName(tab):lower() .. "s"))
    if n == 0 then HideFrom(f.headers, 1) end
    f.hint:SetText(HINTS[tab])
    f.free:Refresh()
end

-- Actions ---------------------------------------------------------------------------------------------------------------------
function RP.RunAutoAssign()
    local me = RP.PlayerName()
    local result = RP.AutoAssign()
    local lead = RP.CanLead("player")
    for who, plan in pairs(result) do
        if who == me then
            local mine = RP.MyPlan()
            mine.groups = plan.groups
            mine.pal.classes = plan.pal.classes
            mine.pal.salv = plan.pal.salv
            mine.pal.aura = plan.pal.aura
            mine.totems = plan.totems
            mine.auto = true
            RP.BroadcastSoon()
        elseif lead or (RP.plans[who] and RP.plans[who].free) then
            local p = EditPlan(who)
            p.groups, p.pal.classes, p.pal.salv, p.pal.aura, p.totems = plan.groups, plan.pal.classes, plan.pal.salv, plan.pal.aura, plan.totems
            RP.SendPlanFor(who, p)
        end
    end
    RP.lastChange = { by = me, at = GetTime() }
    RP.RequestRefresh()
    if RP.pages.assign.frame then RP.pages.assign.refresh(RP.pages.assign.frame) end
    RP.Print(lead and "Auto-assigned everyone." or "Auto-assigned your share (only the leader or assists can set other players).")
end

function RP.ClearAssignments(class)
    for _, b in ipairs(RP.Buffers(class)) do
        if Editable(b.who) then
            local p = EditPlan(b.who)
            if class == "PALADIN" then
                p.pal.classes, p.pal.players, p.pal.salv, p.pal.aura = {}, {}, false, nil
            elseif class == "SHAMAN" then
                p.totems = {}
            else
                for _, fam in ipairs(RP.FAMILIES) do if fam.class == class and fam.scope == "group" then p.groups[fam.key] = RP.NO_GROUPS end end
            end
            Commit(b.who, p)
        end
    end
end

function RP.Announce(class)
    local lines = {}
    for _, b in ipairs(RP.Buffers(class)) do
        local p = b.plan
        if p then
            local parts = {}
            if class == "PALADIN" then
                local by = {}
                for _, c in ipairs(RP.CLASSES) do
                    local k = p.pal and p.pal.classes[c]
                    if k then by[k] = by[k] or {}; table.insert(by[k], RP.ClassName(c)) end
                end
                for _, bl in ipairs(RP.BLESSINGS) do
                    if by[bl.key] then parts[#parts + 1] = bl.label .. " (" .. table.concat(by[bl.key], ", ") .. ")" end
                end
                if p.pal and p.pal.salv then parts[#parts + 1] = "Salvation" end
                if p.pal and p.pal.aura then parts[#parts + 1] = RP.AURA_BY_KEY[p.pal.aura].label .. " Aura" end
            elseif class == "SHAMAN" then
                for _, e in ipairs(RP.TOTEM_ELEMENTS) do
                    local key = p.totems and p.totems[e]
                    for _, t in ipairs(RP.TOTEMS[e]) do if t.key == key then parts[#parts + 1] = RP.SpellName(t.id) end end
                end
            else
                for _, fam in ipairs(RP.FAMILIES) do
                    if fam.class == class and fam.scope == "group" then
                        local gs = {}
                        for g = 1, 8 do if RP.Covers(p, fam.key, g) and RP.groupsPresent[g] then gs[#gs + 1] = g end end
                        if #gs > 0 then parts[#parts + 1] = fam.label .. " G" .. table.concat(gs, ",") end
                    end
                end
            end
            if #parts > 0 then lines[#lines + 1] = RP.ShortName(b.who) .. ": " .. table.concat(parts, "; ") end
        end
    end
    if #lines == 0 then RP.Print("Nothing to announce.") return end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
    for _, l in ipairs(lines) do
        local msg = "[RaidPower] " .. l
        if #msg > 250 then msg = msg:sub(1, 247) .. "..." end
        if channel then SendChatMessage(msg, channel) else RP.Print(msg) end
    end
end

RP.RegisterPage("assign", { label = "Assignments", section = "Raid", icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings", build = Build, refresh = Refresh })
