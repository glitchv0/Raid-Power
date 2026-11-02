-- Window.lua: the main RaidPower window (/raidpower): title bar, sidebar navigation, pages, footer.
local _, RP = ...

local St, W = RP.Style, RP.Widgets
local WIDTH, HEIGHT, NAV = 960, 590, 190
RP.pages = {}
local pageOrder = {}
local win

function RP.RegisterPage(id, def)
    def.id = id
    RP.pages[id] = def
    pageOrder[#pageOrder + 1] = def
end

local function NavButton(parent, def)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(30)
    b.bg = St.Tex(b, "BACKGROUND", { 1, 1, 1, 0 }, 1)
    b.bg:SetAllPoints()
    b.bar = St.Tex(b, "ARTWORK", St.Accent())
    b.bar:SetPoint("TOPLEFT", 0, -6); b.bar:SetPoint("BOTTOMLEFT", 0, 6); b.bar:SetWidth(2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("LEFT", 10, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.icon:SetTexture(def.icon)
    local edge = St.Tex(b, "BORDER", { 0, 0, 0, 1 })
    edge:SetPoint("TOPLEFT", b.icon, -1, 1); edge:SetPoint("BOTTOMRIGHT", b.icon, 1, -1)
    b.text = St.Text(b, 12, "body")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 9, 0)
    b.text:SetText(def.label)
    b.badgeBg = St.Tex(b, "ARTWORK", St.BAD)
    b.badge = St.Text(b, 11, "bold")
    b.badge:SetPoint("RIGHT", -10, 0)
    b.badgeBg:SetPoint("TOPLEFT", b.badge, -5, 1); b.badgeBg:SetPoint("BOTTOMRIGHT", b.badge, 5, -1)
    b.badgeBg:Hide(); b.badge:Hide()
    b:SetScript("OnEnter", function(self) if not self.on then self.bg:SetVertexColor(1, 1, 1, 0.04) end end)
    b:SetScript("OnLeave", function(self) if not self.on then self.bg:SetVertexColor(1, 1, 1, 0) end end)
    b:SetScript("OnClick", function() RP.ShowPage(def.id) end)
    function b:SetOn(on)
        self.on = on
        local r, g, bl = RP.Accent()
        self.bar:SetVertexColor(r, g, bl, 1)
        self.bar:SetShown(on)
        self.bg:SetVertexColor(r, g, bl, on and 0.18 or 0)
        self.text:SetTextColor(on and 1 or 0.78, on and 1 or 0.79, on and 1 or 0.81)
    end
    St.OnAccent(function() b:SetOn(b.on) end)
    return b
end

local function Build()
    win = CreateFrame("Frame", "RaidPowerWindow", UIParent)
    win:SetSize(WIDTH, HEIGHT)
    win:SetPoint("CENTER")
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    St.Skin(win, St.BG)
    table.insert(UISpecialFrames, "RaidPowerWindow")

    -- Title bar.
    local tb = CreateFrame("Frame", nil, win)
    tb:SetPoint("TOPLEFT", 1, -1); tb:SetPoint("TOPRIGHT", -1, -1); tb:SetHeight(44)
    tb:EnableMouse(true)
    tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnDragStart", function() win:StartMoving() end)
    tb:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
    local tbg = St.Tex(tb, "BACKGROUND", { 1, 1, 1, 0.025 })
    tbg:SetAllPoints()
    local tline = St.Tex(tb, "BORDER", St.LINE)
    tline:SetHeight(1); tline:SetPoint("BOTTOMLEFT"); tline:SetPoint("BOTTOMRIGHT")
    local logo = tb:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(St.LOGO)
    logo:SetSize(26, 26)
    logo:SetPoint("LEFT", 12, 0)
    local t1 = St.Text(tb, 20, "bold")
    t1:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    St.OnAccent(function() t1:SetText("RAID|c" .. RP.AccentHex() .. "POWER|r") end)
    win.ctx = St.Text(tb, 12, "body")
    win.ctx:SetPoint("LEFT", t1, "RIGHT", 10, -1)
    win.ctx:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    local close = CreateFrame("Button", nil, tb)
    close:SetSize(26, 26)
    close:SetPoint("RIGHT", -10, 0)
    close.t = St.Text(close, 16, "bold")
    close.t:SetPoint("CENTER")
    close.t:SetText("×")
    close.t:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    close:SetScript("OnEnter", function() close.t:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() close.t:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3]) end)
    close:SetScript("OnClick", function() win:Hide() end)

    -- Sidebar.
    local nav = CreateFrame("Frame", nil, win)
    nav:SetPoint("TOPLEFT", 1, -45); nav:SetPoint("BOTTOMLEFT", 1, 29); nav:SetWidth(NAV)
    local nbg = St.Tex(nav, "BACKGROUND", { 0, 0, 0, 0.18 })
    nbg:SetAllPoints()
    local nline = St.Tex(nav, "BORDER", St.LINE)
    nline:SetWidth(1); nline:SetPoint("TOPRIGHT"); nline:SetPoint("BOTTOMRIGHT")
    win.navButtons = {}
    local y, lastSection = -10, nil
    for _, def in ipairs(pageOrder) do
        if def.section ~= lastSection then
            local s = St.Text(nav, 11, "hdr")
            s:SetPoint("TOPLEFT", 18, y - 8)
            s:SetText(def.section:upper())
            s:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
            y = y - 26
            lastSection = def.section
        end
        local b = NavButton(nav, def)
        b:SetPoint("TOPLEFT", 8, y); b:SetPoint("TOPRIGHT", -8, y)
        y = y - 32
        win.navButtons[def.id] = b
    end

    -- Pages container.
    win.body = CreateFrame("Frame", nil, win)
    win.body:SetPoint("TOPLEFT", NAV + 17, -59)
    win.body:SetPoint("BOTTOMRIGHT", -16, 41)

    -- Footer.
    local ft = CreateFrame("Frame", nil, win)
    ft:SetPoint("BOTTOMLEFT", 1, 1); ft:SetPoint("BOTTOMRIGHT", -1, 1); ft:SetHeight(28)
    local fline = St.Tex(ft, "BORDER", St.LINE)
    fline:SetHeight(1); fline:SetPoint("TOPLEFT"); fline:SetPoint("TOPRIGHT")
    win.ver = St.Text(ft, 11, "body")
    win.ver:SetPoint("LEFT", 12, 0)
    win.ver:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
    win.ver:SetText("RaidPower " .. RP.VERSION)
    win.syncDot = St.Tex(ft, "ARTWORK", St.OK)
    win.syncDot:SetSize(7, 7)
    win.syncDot:SetPoint("LEFT", win.ver, "RIGHT", 16, 0)
    win.sync = St.Text(ft, 11, "body")
    win.sync:SetPoint("LEFT", win.syncDot, "RIGHT", 6, 0)
    win.sync:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    win.change = St.Text(ft, 11, "body")
    win.change:SetPoint("LEFT", win.sync, "RIGHT", 16, 0)
    win.change:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])

    win:SetScript("OnShow", function() RP.RefreshWindow() end)
    win:Hide()
end

function RP.ShowPage(id)
    if not win then Build() end
    for pid, def in pairs(RP.pages) do
        if def.frame then def.frame:Hide() end
        win.navButtons[pid]:SetOn(pid == id)
    end
    local def = RP.pages[id]
    if not def.frame then
        def.frame = CreateFrame("Frame", nil, win.body)
        def.frame:SetAllPoints()
        def.build(def.frame)
    end
    def.frame:Show()
    RP.currentPage = id
    if def.refresh then def.refresh(def.frame) end
    RP.CharDB.lastPage = id
end

function RP.RefreshWindow()
    if not (win and win:IsShown()) then return end
    local def = RP.pages[RP.currentPage]
    if def and def.frame and def.refresh then def.refresh(def.frame) end
    -- Context line.
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local _, class = UnitClass("player")
    local role = RP.CanLead("player") and (IsInGroup() and " (lead/assist)" or "") or ""
    win.ctx:SetText(("· %s · %d in group · you are |c%s%s|r%s"):format(zone, #RP.roster, RP.ClassHex(class), RP.ClassName(class), role))
    -- Sync summary.
    local buffers, synced = 0, 0
    for _, m in ipairs(RP.roster) do
        if not m.isPlayer then
            local isBuffer = false
            for _, c in ipairs(RP.BUFFER_CLASSES) do if c == m.class then isBuffer = true end end
            if isBuffer then
                buffers = buffers + 1
                if RP.plans[m.who] then synced = synced + 1 end
            end
        end
    end
    if IsInGroup() then
        win.sync:SetText(("Synced with %d of %d other buffers"):format(synced, buffers))
        local c = synced == buffers and St.OK or St.WARN
        win.syncDot:SetVertexColor(c[1], c[2], c[3], 1)
    else
        win.sync:SetText("Solo · nothing to sync")
        win.syncDot:SetVertexColor(St.FAINT[1], St.FAINT[2], St.FAINT[3], 1)
    end
    if RP.lastChange then
        win.change:SetText(("Last change by %s · %ds ago"):format(RP.ShortName(RP.lastChange.by), GetTime() - RP.lastChange.at))
    else
        win.change:SetText("")
    end
    -- Overview badge: players missing something.
    local b = win.navButtons.overview
    if b and RP.MissingCount then
        local n = RP.MissingCount()
        b.badge:SetText(n); b.badge:SetShown(n > 0); b.badgeBg:SetShown(n > 0)
    end
end

function RP.ToggleWindow(page)
    if not win then Build() end
    if win:IsShown() and not page then win:Hide() return end
    win:Show()
    RP.ShowPage(page or RP.currentPage or RP.CharDB.lastPage or "overview")
end

function RP.Window() return win end

-- Shared page helpers ------------------------------------------------------------------------------------------
function RP.PageHeader(frame, title)
    local h = St.Text(frame, 20, "bold")
    h:SetPoint("TOPLEFT", 0, 0)
    h:SetText(title:upper())
    frame.heading = h
    return h
end
