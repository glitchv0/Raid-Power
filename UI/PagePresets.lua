-- PagePresets.lua: save and load the group's assignments (by player name) for a raid.
local _, RP = ...

local St, W = RP.Style, RP.Widgets

local function Snapshot()
    local plans = {}
    for _, m in ipairs(RP.roster) do
        local p = RP.PlanOf(m.who)
        if p and m.class and (m.class == "PALADIN" or m.class == "PRIEST" or m.class == "MAGE" or m.class == "DRUID" or m.class == "SHAMAN") then
            plans[m.who] = { class = m.class, body = RP.EncodePlanBody(p), players = RP.Copy(p.pal and p.pal.players or {}) }
        end
    end
    return plans
end

function RP.SavePreset(name)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "")
    if not name or name == "" then return end
    RP.DB.presets[name] = { saved = time(), plans = Snapshot() }
    RP.Print(("Saved preset %q."):format(name))
end

function RP.LoadPreset(name)
    local preset = RP.DB.presets[name]
    if not preset then return end
    local me = RP.PlayerName()
    local applied, skipped = 0, 0
    for who, saved in pairs(preset.plans or {}) do
        if RP.byWho[who] and RP.MayEdit(me, who) then
            local p = (who == me) and RP.MyPlan() or RP.plans[who] or { class = saved.class }
            local parts = {}
            for s in (saved.body .. RP.SyncSep):gmatch("(.-)%" .. RP.SyncSep) do parts[#parts + 1] = s end
            local known = p.known
            RP.DecodePlanBody(parts, 1, p)
            p.known = known
            p.pal.players = RP.Copy(saved.players or {})
            p.auto = false
            if who == me then RP.BroadcastSoon() else RP.plans[who] = p; RP.SendPlanFor(who, p) end
            applied = applied + 1
        else
            skipped = skipped + 1
        end
    end
    preset.used = time()
    RP.RequestRefresh(true)
    RP.Print(("Loaded %q: %d players set%s."):format(name, applied, skipped > 0 and (", " .. skipped .. " not here or not editable") or ""))
end

local function Summary(preset)
    local counts = {}
    for _, p in pairs(preset.plans or {}) do counts[p.class] = (counts[p.class] or 0) + 1 end
    local parts = {}
    for _, c in ipairs({ "PALADIN", "PRIEST", "MAGE", "DRUID", "SHAMAN" }) do
        if counts[c] then parts[#parts + 1] = counts[c] .. " " .. RP.CLASS_SHORT[c] end
    end
    return table.concat(parts, " · ")
end

local function Build(f)
    RP.PageHeader(f, "Presets")
    f.input = CreateFrame("EditBox", nil, f)
    f.input:SetSize(200, 24)
    f.input:SetPoint("TOPRIGHT", -128, 2)
    f.input:SetAutoFocus(false)
    f.input:SetTextInsets(8, 8, 0, 0)
    St.Skin(f.input, { 0.09, 0.1, 0.12, 1 })
    St.Font(f.input, 12, "body")
    f.input:SetTextColor(1, 1, 1)
    f.input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.ph = St.Text(f.input, 12, "body")
    f.ph:SetPoint("LEFT", 8, 0)
    f.ph:SetText("Preset name, e.g. MC - 3 pally")
    f.ph:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
    f.input:SetScript("OnTextChanged", function(self) f.ph:SetShown(self:GetText() == "") end)
    local save = W.Button(f, "Save current", 116, true)
    save:SetPoint("TOPRIGHT", 0, 2)
    local function DoSave()
        RP.SavePreset(f.input:GetText())
        f.input:SetText(""); f.input:ClearFocus()
        RP.pages.presets.refresh(f)
    end
    save:SetScript("OnClick", DoSave)
    f.input:SetScript("OnEnterPressed", DoSave)

    f.head = {}
    for i, h in ipairs({ { "NAME", 0 }, { "BUFFERS", 260 }, { "SAVED", 460 } }) do
        local t = St.Text(f, 11, "hdr")
        t:SetPoint("TOPLEFT", h[2], -44)
        t:SetText(h[1])
        t:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
        f.head[i] = t
    end
    f.rows = {}
    f.empty = St.Text(f, 13, "body")
    f.empty:SetPoint("TOPLEFT", 0, -80)
    f.empty:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    f.empty:SetText("No presets yet. Set up assignments, name it above and press Save current.")
    local hint = St.Text(f, 11, "body")
    hint:SetPoint("BOTTOMLEFT", 0, 4)
    hint:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
    hint:SetText("Presets are saved by player name. Loading only sets players who are here and whom you may edit (you, or everyone as leader/assist).")
end

local function Refresh(f)
    local names = {}
    for name in pairs(RP.DB.presets) do names[#names + 1] = name end
    table.sort(names)
    for i, name in ipairs(names) do
        local preset = RP.DB.presets[name]
        local r = f.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, f)
            r:SetHeight(34)
            r.line = St.Tex(r, "BACKGROUND", St.LINE)
            r.line:SetHeight(1); r.line:SetPoint("BOTTOMLEFT"); r.line:SetPoint("BOTTOMRIGHT")
            r.name = St.Text(r, 13, "bold"); r.name:SetPoint("LEFT", 0, 0)
            r.buffers = St.Text(r, 12, "body"); r.buffers:SetPoint("LEFT", 260, 0)
            r.saved = St.Text(r, 12, "body"); r.saved:SetPoint("LEFT", 460, 0)
            r.saved:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
            r.load = W.Button(r, "Load", 64, true); r.load:SetPoint("RIGHT", -72, 0)
            r.del = W.Button(r, "Delete", 64); r.del:SetPoint("RIGHT", 0, 0)
            f.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -60 - (i - 1) * 36)
        r:SetPoint("TOPRIGHT", 0, -60 - (i - 1) * 36)
        r.name:SetText(name)
        r.buffers:SetText(Summary(preset))
        r.saved:SetText(preset.saved and date("%b %d, %H:%M", preset.saved) or "")
        r.load:SetScript("OnClick", function() RP.LoadPreset(name) end)
        r.del:SetScript("OnClick", function() RP.DB.presets[name] = nil; RP.pages.presets.refresh(f) end)
        r:Show()
    end
    for i = #names + 1, #f.rows do f.rows[i]:Hide() end
    f.empty:SetShown(#names == 0)
end

RP.RegisterPage("presets", { label = "Presets", section = "Setup", icon = "Interface\\Icons\\INV_Misc_Book_09", build = Build, refresh = Refresh })
