-- Tile.lua: a secure click-to-buff tile. Out of combat its queue is rebuilt right before every click (PreClick);
-- in combat a restricted snippet steps through the queue built before the pull, one target per click.
-- Left-click casts the group/greater version when it was worth it, right-click the single-target version,
-- Alt-click opens the tile's menu instead of casting.
local _, RP = ...

local St = RP.Style
RP.tiles = {}

local STEP = [[
    if IsAltKeyDown() then return false end
    local n = self:GetAttribute("rp-count") or 0
    if n == 0 then return false end
    local i = self:GetAttribute("rp-step") or 1
    if i > n then i = 1 end
    self:SetAttribute("rp-step", i + 1)
    local t = self:GetAttribute("rp-type" .. i) or "spell"
    self:SetAttribute("type", t)
    if t == "macro" then
        self:SetAttribute("macrotext", self:GetAttribute("rp-macro" .. i))
    else
        local kind = (button == "RightButton") and "s" or "g"
        self:SetAttribute("unit", self:GetAttribute("rp-unit" .. i))
        self:SetAttribute("spell", self:GetAttribute("rp-spell" .. kind .. i) or self:GetAttribute("rp-spellg" .. i))
    end
]]

local handler
local function Handler()
    if not handler then handler = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate") end
    return handler
end

local function PreClick(self)
    if not InCombatLockdown() and not IsAltKeyDown() then RP.RefreshNow(true) end
end

local function PostClick(self, button)
    if IsAltKeyDown() then
        if self.OnMenu and not InCombatLockdown() then self:OnMenu(button) end
        return
    end
    RP.lastCast = { unit = self:GetAttribute("unit"), spell = self:GetAttribute("spell"), at = GetTime(), tile = self }
end

-- kind: "tile" (icon) | "pill" (group number)
function RP.CreateTile(name, parent, size, kind, keyboard)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    if keyboard then
        b:RegisterForClicks("AnyDown")
        b:SetAttribute("useOnKeyDown", true)
    else
        b:RegisterForClicks("AnyUp")
        b:SetAttribute("useOnKeyDown", false)
    end
    b:SetAttribute("rp-count", 0)
    b:SetAttribute("type", "spell")
    SecureHandlerWrapScript(b, "OnClick", Handler(), STEP)
    b:SetScript("PreClick", PreClick)
    b:SetScript("PostClick", PostClick)
    b.kind = kind or "tile"
    if b.kind == "pill" then
        b:SetSize(size, math.floor(size * 0.8))
        local s = St.Skin(b, { 0.106, 0.122, 0.149, 1 }, true)
        b.skin = s
        b.num = St.Text(b, 13, "bold")
        b.num:SetPoint("CENTER", 0, 0)
        b.status = St.Tex(b, "OVERLAY", St.OK, 1)
        b.status:SetHeight(3)
        b.status:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
        b.status:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
        local sb = St.Tex(b, "OVERLAY", { 0, 0, 0, 1 }, 0)
        sb:SetPoint("TOPLEFT", b.status, -1, 1); sb:SetPoint("BOTTOMRIGHT", b.status, 1, -1)
        b.statusBorder = sb
        b.mineEdge = {}
        for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
            local t = St.Tex(b, "OVERLAY", St.Accent(), 2)
            t:SetPoint(p[1]); t:SetPoint(p[2])
            if p[3] then t:SetHeight(1) else t:SetWidth(1) end
            b.mineEdge[i] = t
        end
    else
        St.Icon(b, size)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture(St.WHITE)
        hl:SetAllPoints()
        hl:SetVertexColor(1, 1, 1, 0.12)
        local pushed = b:CreateTexture(nil, "OVERLAY")
        pushed:SetTexture(St.WHITE)
        pushed:SetAllPoints()
        pushed:SetVertexColor(0, 0, 0, 0.3)
        b:SetPushedTexture(pushed)
    end
    b:HookScript("OnEnter", function(self) RP.ShowFlyout(self) end)
    b:HookScript("OnLeave", function() RP.HideFlyout() end)
    RP.tiles[#RP.tiles + 1] = b
    return b
end

local function MacroFor(e)
    if e.item and e.weapon then return ("/use item:%d\n/use %d"):format(e.item, e.weapon) end
end

-- Push a queue into a tile's secure attributes (out of combat only).
function RP.SetTileQueue(b, queue)
    if InCombatLockdown() then return end
    local sig = {}
    for i, e in ipairs(queue or {}) do
        sig[i] = (e.unit or "") .. ":" .. (e.spellG or "") .. ":" .. (e.spellS or "") .. ":" .. (e.item or "")
    end
    local s = table.concat(sig, ";")
    if b.rpSig == s then
        b:SetAttribute("rp-step", 1)
        return
    end
    b.rpSig = s
    for i, e in ipairs(queue or {}) do
        local macro = MacroFor(e)
        if macro then
            b:SetAttribute("rp-type" .. i, "macro")
            b:SetAttribute("rp-macro" .. i, macro)
        else
            b:SetAttribute("rp-type" .. i, "spell")
            b:SetAttribute("rp-unit" .. i, e.unit)
            b:SetAttribute("rp-spellg" .. i, e.spellG)
            b:SetAttribute("rp-spells" .. i, e.spellS)
        end
    end
    b:SetAttribute("rp-count", queue and #queue or 0)
    b:SetAttribute("rp-step", 1)
    b.queue = queue
end

function RP.PaintPill(b, tile)
    local status = tile.status
    local c = St.STATUS[status] or St.OK
    if not tile.present then status = "na"; c = St.NA end
    b.status:SetVertexColor(c[1], c[2], c[3], 1)
    local dim = not (tile.mine and tile.present)
    b:SetAlpha(dim and 0.32 or 1)
    b.num:SetText(tile.group)
    if status == "bad" then b.num:SetTextColor(1, 0.82, 0.82)
    elseif status == "warn" then b.num:SetTextColor(1, 0.9, 0.7)
    else b.num:SetTextColor(St.TEXT[1], St.TEXT[2], St.TEXT[3]) end
    local r, g, bl = RP.Accent()
    for _, t in ipairs(b.mineEdge) do
        t:SetVertexColor(r, g, bl, 1)
        t:SetShown(tile.mine and tile.present)
    end
end
