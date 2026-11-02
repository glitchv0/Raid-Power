-- PageOverview.lua: every member's buffs at a glance, by group, with totals per buff.
local _, RP = ...

local St, W = RP.Style, RP.Widgets
local view = "group"

-- Columns: one per buff anyone in the group can give, in a stable order.
local function Columns()
    local cols, seen = {}, {}
    local classes = {}
    for _, m in ipairs(RP.roster) do classes[m.class] = true end
    for _, f in ipairs(RP.FAMILIES) do
        if f.scope == "group" and classes[f.class] and (not f.optional or RP.CharDB.familyOn[f.key]) then
            cols[#cols + 1] = { key = f.key, label = f.label, icon = RP.SpellIcon(f.single[1]), fam = f }
            seen[f.key] = true
        end
    end
    for _, b in ipairs(RP.BLESSINGS) do
        for _, p in ipairs(RP.Buffers("PALADIN")) do
            local plan = p.plan
            if plan and plan.pal and not seen[b.key] then
                for _, k in pairs(plan.pal.classes or {}) do
                    if k == b.key then seen[b.key] = true end
                end
                if seen[b.key] then cols[#cols + 1] = { key = b.key, label = b.label, icon = RP.SpellIcon(b.ranks[1]), bless = true } end
            end
        end
    end
    for _, p in ipairs(RP.Buffers("PALADIN")) do
        if p.plan and p.plan.pal and p.plan.pal.salv and not seen.salvation then
            seen.salvation = true
            cols[#cols + 1] = { key = "salvation", label = "Salvation", icon = RP.SpellIcon(1038), salv = true }
        end
    end
    return cols
end

local function Expects(m, col)
    if col.fam then return not (col.fam.skip and col.fam.skip[m.class]) end
    if col.salv then return not m.tank end
    if col.bless then
        for _, p in ipairs(RP.Buffers("PALADIN")) do
            if p.plan and RP.BlessingFor(p.plan, m) == col.key then return true end
        end
        return false
    end
    return false
end

local function Cell(m, col)
    if not Expects(m, col) then return "na" end
    if not RP.IsAvailable(m) then return "oor" end
    local rank = RP.Rank(m, col.key)
    if rank == nil then return "unk" end
    if rank == RP.RANK_MISSING then return "bad" end
    if rank == RP.RANK_EXPIRING then return "warn" end
    return "ok"
end

function RP.MissingCount()
    local cols = Columns()
    local n = 0
    for _, m in ipairs(RP.roster) do
        for _, c in ipairs(cols) do
            if Cell(m, c) == "bad" then n = n + 1 break end
        end
    end
    return n
end

local function Build(f)
    RP.PageHeader(f, "Raid overview")
    f.seg = W.Segmented(f, { { "group", "By group" }, { "missing", "Missing only" } },
        function() return view end, function(v) view = v; RP.pages.overview.refresh(f) end, 96)
    f.seg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -120, 2)
    f.report = W.Button(f, "Report missing", 110)
    f.report:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 2)
    f.report:SetScript("OnClick", function() RP.ReportMissing() end)

    f.sums = {}
    for i = 1, 8 do
        local s = CreateFrame("Frame", nil, f)
        s:SetSize(86, 46)
        St.Skin(s, St.PANEL2)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetSize(22, 22); s.icon:SetPoint("LEFT", 7, 0); s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        s.v = St.Text(s, 16, "bold")
        s.v:SetPoint("TOPLEFT", s.icon, "TOPRIGHT", 6, 3)
        s.mbg = St.Tex(s, "ARTWORK", { 0.165, 0.18, 0.21, 1 })
        s.mbg:SetHeight(3); s.mbg:SetPoint("BOTTOMLEFT", s.icon, "BOTTOMRIGHT", 6, 0); s.mbg:SetPoint("RIGHT", -7, 0)
        s.m = St.Tex(s, "OVERLAY", St.OK)
        s.m:SetHeight(3); s.m:SetPoint("LEFT", s.mbg, "LEFT")
        W.AttachTooltip(s, function(self) return self.tip, nil end)
        s:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * 92, -36)
        f.sums[i] = s
    end

    f.cards = {}
    for g = 1, 8 do
        local c = CreateFrame("Frame", nil, f)
        c:SetSize(176, 128)
        St.Skin(c, St.PANEL2)
        c.title = St.Text(c, 13, "bold")
        c.title:SetPoint("TOPLEFT", 9, -8)
        c.title:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
        c.state = St.Text(c, 13, "bold")
        c.state:SetPoint("TOPRIGHT", -9, -8)
        c.rows = {}
        for r = 1, 5 do
            local row = CreateFrame("Frame", nil, c)
            row:SetSize(160, 18)
            row:SetPoint("TOPLEFT", 8, -28 - (r - 1) * 19)
            row.name = St.Text(row, 12, "body")
            row.name:SetPoint("LEFT")
            row.name:SetWidth(80)
            row.name:SetJustifyH("LEFT")
            row.dots = {}
            for d = 1, 8 do
                local dot = St.Tex(row, "ARTWORK", St.OK, 1)
                dot:SetSize(8, 8)
                dot:SetPoint("RIGHT", row, "RIGHT", -(8 - d) * 10 - 1, 0)
                local edge = St.Tex(row, "ARTWORK", { 0, 0, 0, 1 }, 0)
                edge:SetPoint("TOPLEFT", dot, -1, 1); edge:SetPoint("BOTTOMRIGHT", dot, 1, -1)
                row.dots[d] = { dot = dot, edge = edge }
            end
            c.rows[r] = row
        end
        local col, line = (g - 1) % 4, math.floor((g - 1) / 4)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", col * 184, -94 - line * 136)
        f.cards[g] = c
    end
    f.legend = St.Text(f, 11, "body")
    f.legend:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.legend:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
    f.empty = St.Text(f, 14, "body")
    f.empty:SetPoint("CENTER", 0, -20)
    f.empty:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
end

local function Refresh(f)
    local cols = Columns()
    -- Totals.
    for i, s in ipairs(f.sums) do
        local col = cols[i]
        if col then
            local have, need = 0, 0
            for _, m in ipairs(RP.roster) do
                local st = Cell(m, col)
                if st ~= "na" then
                    need = need + 1
                    if st == "ok" or st == "warn" then have = have + 1 end
                end
            end
            s.icon:SetTexture(col.icon)
            s.v:SetText(("%d|cff555b66/%d|r"):format(have, need))
            local pct = need > 0 and have / need or 1
            s.m:SetWidth(math.max(0.01, pct * 44))
            local c = pct >= 1 and St.OK or (pct >= 0.8 and St.WARN or St.BAD)
            s.m:SetVertexColor(c[1], c[2], c[3], 1)
            s.tip = col.label
            s:Show()
        else
            s:Hide()
        end
    end
    -- Cards.
    local byGroup = {}
    for _, m in ipairs(RP.roster) do
        local g = m.subgroup or 1
        byGroup[g] = byGroup[g] or {}
        local missing = false
        for _, c in ipairs(cols) do if Cell(m, c) == "bad" then missing = true end end
        if view ~= "missing" or missing then table.insert(byGroup[g], m) end
    end
    local shown = 0
    for g, card in ipairs(f.cards) do
        local list = byGroup[g] or {}
        if #list == 0 and not (RP.groupsPresent[g] and view ~= "missing") then
            card:Hide()
        else
            shown = shown + 1
            card:Show()
            card.title:SetText("GROUP " .. g)
            local bad = 0
            for r, row in ipairs(card.rows) do
                local m = list[r]
                if m then
                    row:Show()
                    local c = RP.CLASS_COLORS[m.class]
                    row.name:SetText(RP.ShortName(m.who))
                    row.name:SetTextColor(c[1], c[2], c[3])
                    for d, dd in ipairs(row.dots) do
                        local col = cols[d]
                        if col then
                            local st = Cell(m, col)
                            if st == "bad" then bad = bad + 1 end
                            local sc = St.STATUS[st] or St.NA
                            dd.dot:SetVertexColor(sc[1], sc[2], sc[3], 1)
                            dd.dot:Show(); dd.edge:Show()
                        else
                            dd.dot:Hide(); dd.edge:Hide()
                        end
                    end
                else
                    row:Hide()
                end
            end
            if bad > 0 then
                card.state:SetText(bad .. " MISSING"); card.state:SetTextColor(St.BAD[1], St.BAD[2], St.BAD[3])
            else
                card.state:SetText("OK"); card.state:SetTextColor(St.OK[1], St.OK[2], St.OK[3])
            end
        end
    end
    f.empty:SetShown(shown == 0)
    f.empty:SetText(view == "missing" and "Nobody is missing anything." or "Nobody here yet.")
    local names = {}
    for _, c in ipairs(cols) do names[#names + 1] = c.label end
    f.legend:SetText(#names > 0 and ("Dot order: " .. table.concat(names, " · ") .. ".  Dark = not needed.") or "No buffers in your group.")
end

function RP.ReportMissing()
    local cols = Columns()
    local lines = {}
    for _, col in ipairs(cols) do
        local who = {}
        for _, m in ipairs(RP.roster) do
            if Cell(m, col) == "bad" then who[#who + 1] = RP.ShortName(m.who) end
        end
        if #who > 0 then lines[#lines + 1] = ("%s: %s"):format(col.label, table.concat(who, ", ")) end
    end
    if #lines == 0 then lines[1] = "Everyone is fully buffed." end
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
    for _, l in ipairs(lines) do
        local msg = "[RaidPower] Missing " .. l
        if #msg > 250 then msg = msg:sub(1, 247) .. "..." end
        if channel then SendChatMessage(msg, channel) else RP.Print(msg) end
    end
end

RP.RegisterPage("overview", { label = "Overview", section = "Raid", icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02", build = Build, refresh = Refresh })
