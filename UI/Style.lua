-- Style.lua: the look. Flat dark panels, 1px black border with a faint inner line, one accent colour,
-- Barlow Condensed for headers and numbers.
local _, RP = ...

local St = {}
RP.Style = St

St.FONT_HDR = RP.MEDIA .. "Fonts\\BarlowCondensed-SemiBold.ttf"
St.FONT_BOLD = RP.MEDIA .. "Fonts\\BarlowCondensed-Bold.ttf"
St.FONT_BODY = RP.MEDIA .. "Fonts\\Barlow-Medium.ttf"
St.WHITE = "Interface\\Buttons\\WHITE8X8"
St.LOGO = RP.MEDIA .. "Logo.tga"

St.BG = { 0.063, 0.071, 0.090, 1 }
St.BG_HUD = { 0.039, 0.043, 0.055, 0.86 }
St.PANEL2 = { 0.082, 0.094, 0.118, 1 }
St.LINE = { 1, 1, 1, 0.06 }
St.TEXT = { 0.91, 0.914, 0.925 }
St.MUTED = { 0.54, 0.56, 0.60 }
St.FAINT = { 0.33, 0.36, 0.40 }
St.OK = { 0.24, 0.86, 0.52 }
St.WARN = { 1.00, 0.69, 0.13 }
St.BAD = { 1.00, 0.30, 0.31 }
St.OOR = { 0.42, 0.45, 0.50 }
St.UNK = { 0.49, 0.54, 0.65 }
St.NA = { 0.17, 0.18, 0.21 }
St.STATUS = { ok = St.OK, warn = St.WARN, bad = St.BAD, oor = St.OOR, unk = St.UNK, na = St.NA }

function St.Font(fs, size, kind, flags)
    local path = (kind == "bold" and St.FONT_BOLD) or (kind == "body" and St.FONT_BODY) or St.FONT_HDR
    if not fs:SetFont(path, size, flags or "") then fs:SetFont(STANDARD_TEXT_FONT, size, flags or "") end
end

function St.Text(parent, size, kind, layer, flags)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    St.Font(fs, size, kind, flags)
    fs:SetTextColor(St.TEXT[1], St.TEXT[2], St.TEXT[3])
    fs:SetWordWrap(false)
    return fs
end

function St.Tex(parent, layer, color, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    t:SetTexture(St.WHITE)
    if color then t:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
    return t
end

-- 1px outer black border + faint inner line + background.
function St.Skin(frame, bg, noInner)
    if frame.rpSkin then return frame.rpSkin end
    local s = {}
    s.bg = St.Tex(frame, "BACKGROUND", bg or St.BG, -8)
    s.bg:SetAllPoints()
    local function Edge(color, inset, sub)
        local e = {}
        for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local t = St.Tex(frame, "BORDER", color, sub)
            if side == "TOP" or side == "BOTTOM" then
                t:SetHeight(1)
                t:SetPoint(side .. "LEFT", frame, side .. "LEFT", inset, side == "TOP" and -inset or inset)
                t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -inset, side == "TOP" and -inset or inset)
            else
                t:SetWidth(1)
                t:SetPoint("TOP" .. side, frame, "TOP" .. side, side == "LEFT" and inset or -inset, -inset)
                t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, side == "LEFT" and inset or -inset, inset)
            end
            e[i] = t
        end
        return e
    end
    s.outer = Edge({ 0, 0, 0, 1 }, 0, 1)
    if not noInner then s.inner = Edge(St.LINE, 1, 2) end
    frame.rpSkin = s
    return s
end

function St.Accent(alpha)
    local r, g, b = RP.Accent()
    return { r, g, b, alpha or 1 }
end

-- Objects that repaint when the accent changes.
St.accentHooks = {}
function St.OnAccent(fn)
    St.accentHooks[#St.accentHooks + 1] = fn
    fn(RP.Accent())
end
RP.On("RP_SETTING", function(key)
    if key ~= "accent" then return end
    local r, g, b = RP.Accent()
    for _, fn in ipairs(St.accentHooks) do pcall(fn, r, g, b) end
end)

-- Icon with 7% crop, black border, status underline, timer, count badge, optional class corner.
function St.Icon(frame, size)
    frame:SetSize(size, size)
    local ic = {}
    ic.border = St.Tex(frame, "BACKGROUND", { 0, 0, 0, 1 })
    ic.border:SetPoint("TOPLEFT", -1, 1)
    ic.border:SetPoint("BOTTOMRIGHT", 1, -1)
    ic.tex = frame:CreateTexture(nil, "ARTWORK")
    ic.tex:SetAllPoints()
    ic.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ic.status = St.Tex(frame, "OVERLAY", St.OK, 1)
    ic.status:SetHeight(3)
    ic.status:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    ic.status:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
    ic.statusBorder = St.Tex(frame, "OVERLAY", { 0, 0, 0, 1 }, 0)
    ic.statusBorder:SetPoint("TOPLEFT", ic.status, "TOPLEFT", -1, 1)
    ic.statusBorder:SetPoint("BOTTOMRIGHT", ic.status, "BOTTOMRIGHT", 1, -1)
    ic.glow = St.Tex(frame, "BACKGROUND", { St.BAD[1], St.BAD[2], St.BAD[3], 0.45 }, -1)
    ic.glow:SetPoint("TOPLEFT", -3, 3)
    ic.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    ic.glow:Hide()
    local textLayer = CreateFrame("Frame", nil, frame)
    textLayer:SetAllPoints()
    textLayer:SetFrameLevel(frame:GetFrameLevel() + 3)
    ic.layer = textLayer
    ic.time = St.Text(textLayer, math.max(10, math.floor(size * 0.36)), "bold", "OVERLAY", "OUTLINE")
    ic.time:SetDrawLayer("OVERLAY", 7)
    ic.time:SetPoint("BOTTOM", 0, 1)
    ic.badgeBg = St.Tex(textLayer, "OVERLAY", St.BAD, 1)
    ic.badgeBg:SetSize(16, 15)
    ic.badgeBg:SetPoint("TOPRIGHT", 5, 6)
    ic.badgeEdge = St.Tex(textLayer, "OVERLAY", { 0, 0, 0, 1 }, 0)
    ic.badgeEdge:SetPoint("TOPLEFT", ic.badgeBg, -1, 1)
    ic.badgeEdge:SetPoint("BOTTOMRIGHT", ic.badgeBg, 1, -1)
    ic.badge = St.Text(textLayer, 11, "bold", "OVERLAY")
    ic.badge:SetDrawLayer("OVERLAY", 7)
    ic.badge:SetPoint("CENTER", ic.badgeBg, "CENTER", 0, 0)
    ic.badgeBg:Hide(); ic.badgeEdge:Hide(); ic.badge:Hide()
    ic.unk = St.Text(textLayer, math.floor(size * 0.45), "bold", "OVERLAY", "OUTLINE")
    ic.unk:SetDrawLayer("OVERLAY", 7)
    ic.unk:SetPoint("CENTER")
    ic.unk:SetText("?")
    ic.unk:Hide()
    frame.ic = ic
    return ic
end

function St.SetIconSize(frame, size)
    frame:SetSize(size, size)
    local ic = frame.ic
    St.Font(ic.time, math.max(10, math.floor(size * 0.36)), "bold", "OUTLINE")
    St.Font(ic.unk, math.floor(size * 0.45), "bold", "OUTLINE")
end

function St.ClassCorner(frame, class)
    local ic = frame.ic
    if not ic.cls then
        ic.clsBorder = St.Tex(ic.layer, "OVERLAY", { 0, 0, 0, 1 }, 0)
        ic.cls = ic.layer:CreateTexture(nil, "OVERLAY", nil, 1)
        ic.cls:SetSize(14, 14)
        ic.cls:SetPoint("TOPLEFT", ic.layer, "TOPLEFT", -2, 2)
        ic.clsBorder:SetPoint("TOPLEFT", ic.cls, -1, 1)
        ic.clsBorder:SetPoint("BOTTOMRIGHT", ic.cls, 1, -1)
    end
    if class then
        RP.SetClassIcon(ic.cls, class)
        ic.cls:Show(); ic.clsBorder:Show()
    else
        ic.cls:Hide(); ic.clsBorder:Hide()
    end
end

-- Paint an icon for a status: ok / warn / bad / oor / unk / na.
function St.Paint(frame, status, count, timeLeft, showTime)
    local ic = frame.ic
    local c = St.STATUS[status] or St.OK
    ic.status:SetVertexColor(c[1], c[2], c[3], 1)
    ic.glow:SetShown(status == "bad")
    local desat = status == "oor" or status == "na"
    ic.tex:SetDesaturated(desat)
    if status == "na" then ic.tex:SetVertexColor(0.35, 0.35, 0.35)
    elseif status == "oor" then ic.tex:SetVertexColor(0.55, 0.55, 0.55)
    elseif status == "unk" then ic.tex:SetVertexColor(0.7, 0.7, 0.75)
    else ic.tex:SetVertexColor(1, 1, 1) end
    ic.unk:SetShown(status == "unk")
    if count and count > 0 and (status == "bad" or status == "warn" or status == "oor") then
        ic.badge:SetText(count)
        local w = math.max(16, ic.badge:GetStringWidth() + 8)
        ic.badgeBg:SetWidth(w)
        local bc = status == "warn" and St.WARN or status == "oor" and St.OOR or St.BAD
        ic.badgeBg:SetVertexColor(bc[1], bc[2], bc[3], 1)
        ic.badge:SetTextColor(status == "warn" and 0.07 or 1, status == "warn" and 0.07 or 1, status == "warn" and 0.07 or 1)
        ic.badgeBg:Show(); ic.badgeEdge:Show(); ic.badge:Show()
    else
        ic.badgeBg:Hide(); ic.badgeEdge:Hide(); ic.badge:Hide()
    end
    if showTime ~= false and timeLeft and timeLeft > 0 and status ~= "unk" and status ~= "na" then
        ic.time:SetText(RP.FormatTime(timeLeft))
        if status == "warn" then ic.time:SetTextColor(St.WARN[1], St.WARN[2], St.WARN[3])
        elseif status == "bad" then ic.time:SetTextColor(1, 0.75, 0.75)
        else ic.time:SetTextColor(1, 1, 1) end
    else
        ic.time:SetText("")
    end
end
