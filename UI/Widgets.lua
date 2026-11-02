-- Widgets.lua: small styled controls for the main window (buttons, toggles, segmented controls, sliders,
-- dropdown menus, tooltips). All insecure: they never touch protected frames.
local _, RP = ...

local St = RP.Style
local W = {}
RP.Widgets = W

function W.Tooltip(owner, title, body)
    if not RP.S.tooltips then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title, 1, 1, 1)
    if body then GameTooltip:AddLine(body, St.MUTED[1], St.MUTED[2], St.MUTED[3], true) end
    GameTooltip:Show()
end

function W.AttachTooltip(frame, title, body)
    frame:HookScript("OnEnter", function(self)
        local t, b = title, body
        if type(t) == "function" then t, b = t(self) end
        if t then W.Tooltip(self, t, b) end
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function W.Button(parent, text, width, primary)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, 24)
    local s = St.Skin(b, { 0.114, 0.129, 0.157, 1 })
    b.label = St.Text(b, 13, "hdr")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text:upper())
    b.primary = primary
    local function Paint(hover)
        if b.primary then
            local r, g, bl = RP.Accent()
            local k = hover and 1.1 or 1
            s.bg:SetVertexColor(math.min(1, r * k), math.min(1, g * k), math.min(1, bl * k), 1)
            b.label:SetTextColor(0.08, 0.08, 0.08)
        else
            local v = hover and 0.145 or 0.114
            s.bg:SetVertexColor(v, v + 0.016, v + 0.043, 1)
            b.label:SetTextColor(0.87, 0.89, 0.9)
        end
    end
    b:SetScript("OnEnter", function() Paint(true) end)
    b:SetScript("OnLeave", function() Paint(false) end)
    St.OnAccent(function() Paint(false) end)
    b.SetLabel = function(self, t) self.label:SetText(t:upper()) end
    return b
end

function W.Toggle(parent, get, set)
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(30, 16)
    local s = St.Skin(t, { 0.169, 0.188, 0.224, 1 }, true)
    t.knob = St.Tex(t, "ARTWORK", { 0.53, 0.53, 0.53, 1 })
    t.knob:SetSize(10, 10)
    function t:Refresh()
        local on = get()
        t.knob:ClearAllPoints()
        if on then
            local r, g, b = RP.Accent()
            s.bg:SetVertexColor(r, g, b, 1)
            t.knob:SetVertexColor(0.07, 0.07, 0.07, 1)
            t.knob:SetPoint("RIGHT", -3, 0)
        else
            s.bg:SetVertexColor(0.169, 0.188, 0.224, 1)
            t.knob:SetVertexColor(0.53, 0.53, 0.53, 1)
            t.knob:SetPoint("LEFT", 3, 0)
        end
    end
    t:SetScript("OnClick", function()
        set(not get())
        t:Refresh()
    end)
    St.OnAccent(function() t:Refresh() end)
    t:Refresh()
    return t
end

-- Segmented control: options = { { value, label }, ... }
function W.Segmented(parent, options, get, set, width)
    local f = CreateFrame("Frame", nil, parent)
    St.Skin(f, { 0.09, 0.1, 0.12, 1 })
    local segW = width or 64
    f:SetSize(segW * #options, 24)
    f.items = {}
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(segW, 22)
        b:SetPoint("LEFT", f, "LEFT", (i - 1) * segW + 1, 0)
        b.bg = St.Tex(b, "BACKGROUND", { 0, 0, 0, 0 }, 1)
        b.bg:SetAllPoints()
        b.text = St.Text(b, 12, "hdr")
        b.text:SetPoint("CENTER")
        b.text:SetText(tostring(opt[2]):upper())
        b.value = opt[1]
        b:SetScript("OnClick", function() set(opt[1]); f:Refresh() end)
        if opt[3] then W.AttachTooltip(b, opt[2], opt[3]) end
        f.items[i] = b
    end
    function f:Refresh()
        local v = get()
        local r, g, bl = RP.Accent()
        for _, b in ipairs(f.items) do
            if b.value == v then
                b.bg:SetVertexColor(r, g, bl, 0.22)
                b.text:SetTextColor(1, 1, 1)
            else
                b.bg:SetVertexColor(0, 0, 0, 0)
                b.text:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
            end
        end
    end
    St.OnAccent(function() f:Refresh() end)
    f:Refresh()
    return f
end

function W.Slider(parent, minV, maxV, step, get, set, fmt)
    local f = CreateFrame("Slider", nil, parent)
    f:SetSize(140, 14)
    f:SetOrientation("HORIZONTAL")
    f:SetMinMaxValues(minV, maxV)
    f:SetValueStep(step)
    f:SetObeyStepOnDrag(true)
    local track = St.Tex(f, "BACKGROUND", { 0.169, 0.188, 0.224, 1 })
    track:SetHeight(4)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT")
    f.fill = St.Tex(f, "ARTWORK", St.Accent())
    f.fill:SetHeight(4)
    f.fill:SetPoint("LEFT", track, "LEFT")
    local thumb = f:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(St.WHITE)
    thumb:SetSize(10, 12)
    thumb:SetVertexColor(1, 1, 1, 1)
    f:SetThumbTexture(thumb)
    f.value = St.Text(f, 13, "hdr")
    f.value:SetPoint("RIGHT", f, "LEFT", -8, 0)
    local function Update(v)
        local pct = (v - minV) / (maxV - minV)
        f.fill:SetWidth(math.max(1, pct * f:GetWidth()))
        f.value:SetText(fmt and fmt(v) or tostring(v))
    end
    f:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        Update(v)
        if v ~= get() then set(v) end
    end)
    St.OnAccent(function(r, g, b) f.fill:SetVertexColor(r, g, b, 1) end)
    f:SetValue(get())
    Update(get())
    return f
end

-- Option row inside a group box: label (+ description) on the left, control on the right.
function W.Row(parent, y, label, desc, control, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(30)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    row.label = St.Text(row, 12, "body")
    row.label:SetPoint("LEFT", 0, desc and 6 or 0)
    row.label:SetText(label)
    if desc then
        row.desc = St.Text(row, 10, "body")
        row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
        row.desc:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
        row.desc:SetText(desc)
    end
    local line = St.Tex(row, "BACKGROUND", St.LINE)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
    if control then
        control:SetParent(row)
        control:ClearAllPoints()
        control:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end
    row.control = control
    return row
end

-- Group box with an accent title.
function W.Group(parent, title, width, height)
    local g = CreateFrame("Frame", nil, parent)
    g:SetSize(width, height)
    St.Skin(g, St.PANEL2)
    g.title = St.Text(g, 15, "bold")
    g.title:SetPoint("TOPLEFT", 12, -10)
    g.title:SetText(title:upper())
    St.OnAccent(function(r, gg, b) g.title:SetTextColor(r, gg, b) end)
    g.nextY = -32
    function g:Add(label, desc, control)
        local row = W.Row(self, self.nextY, label, desc, control)
        self.nextY = self.nextY - 32
        return row
    end
    return g
end

-- Simple popup menu: items = { { text, func, checked, icon, disabled }, ... }
local menu
function W.Menu(owner, items, title)
    if not menu then
        menu = CreateFrame("Frame", "RaidPowerMenu", UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        St.Skin(menu, St.BG)
        menu.buttons = {}
        menu:EnableMouse(true)
        menu:SetScript("OnHide", function(self) self.owner = nil end)
        local closer = CreateFrame("Button", nil, menu)
        closer:SetFrameStrata("FULLSCREEN")
        closer:SetAllPoints(UIParent)
        closer:SetScript("OnClick", function() menu:Hide() end)
        closer:RegisterForClicks("AnyUp")
        menu.closer = closer
        menu.title = St.Text(menu, 12, "hdr")
        menu.title:SetPoint("TOPLEFT", 10, -8)
        menu.title:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    end
    if menu:IsShown() and menu.owner == owner then menu:Hide() return end
    menu.owner = owner
    for _, b in ipairs(menu.buttons) do b:Hide() end
    local top = -6
    if title then
        menu.title:SetText(title:upper()); menu.title:Show(); top = -26
    else
        menu.title:Hide()
    end
    local width = 160
    for i, item in ipairs(items) do
        local b = menu.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, menu)
            b:SetHeight(22)
            b.hl = St.Tex(b, "BACKGROUND", { 1, 1, 1, 0.06 }, 1)
            b.hl:SetAllPoints(); b.hl:Hide()
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(16, 16)
            b.icon:SetPoint("LEFT", 8, 0)
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.text = St.Text(b, 12, "body")
            b.check = St.Tex(b, "ARTWORK", St.Accent())
            b.check:SetSize(3, 14)
            b.check:SetPoint("LEFT", 2, 0)
            b:SetScript("OnEnter", function(self) self.hl:Show() end)
            b:SetScript("OnLeave", function(self) self.hl:Hide() end)
            menu.buttons[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, top)
        b:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, top)
        top = top - 22
        b.text:ClearAllPoints()
        if item.icon then
            b.icon:SetTexture(item.icon); b.icon:Show()
            b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        else
            b.icon:Hide()
            b.text:SetPoint("LEFT", 10, 0)
        end
        b.text:SetText(item.text)
        if item.disabled then b.text:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3]) else b.text:SetTextColor(St.TEXT[1], St.TEXT[2], St.TEXT[3]) end
        local r, g, bl = RP.Accent()
        b.check:SetVertexColor(r, g, bl, 1)
        b.check:SetShown(item.checked == true)
        width = math.max(width, b.text:GetStringWidth() + (item.icon and 44 or 24))
        b:SetScript("OnClick", function()
            menu:Hide()
            if not item.disabled and item.func then item.func() end
        end)
        b:Show()
    end
    menu:SetSize(width, -top + 6)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
    menu:Show()
end

function W.Label(parent, text, size, kind, color)
    local fs = St.Text(parent, size or 12, kind or "body")
    fs:SetText(text)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end
