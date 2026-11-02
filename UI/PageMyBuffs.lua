-- PageMyBuffs.lua: what you give and which self-buffs to track, for the class you are playing.
local _, RP = ...

local St, W = RP.Style, RP.Widgets

local function Changed()
    RP.RequestRefresh(true)
end

local function Build(f)
    local _, class = UnitClass("player")
    local h = RP.PageHeader(f, "My buffs")
    local c = RP.CLASS_COLORS[class]
    local cls = St.Text(f, 20, "bold")
    cls:SetPoint("LEFT", h, "RIGHT", 8, 0)
    cls:SetText("· " .. RP.ClassName(class):upper())
    cls:SetTextColor(c[1], c[2], c[3])

    local colW = 360
    local left = W.Group(f, "Group buffs I give", colW, 260)
    left:SetPoint("TOPLEFT", 0, -36)
    local any = false
    for _, fam in ipairs(RP.FAMILIES) do
        if fam.class == class then
            any = true
            local key = fam.key
            left:Add(fam.label .. (fam.scope == "tanks" and " (tanks)" or ""), RP.KnowsAny(fam.single) and nil or "Not learned yet",
                W.Toggle(left, function() return RP.CharDB.familyOn[key] end, function(v) RP.CharDB.familyOn[key] = v; Changed() end))
        end
    end
    if class == "PALADIN" then
        any = true
        left:Add("Salvation for non-tanks", nil, W.Toggle(left, function() return RP.MyPlan().pal.salv end,
            function(v) RP.MyPlan().pal.salv = v; RP.MyPlan().auto = false; RP.BroadcastSoon(); Changed() end))
        left:Add("Greater Blessing when at least", "class members need it (needs Symbol of Kings)",
            W.Slider(left, 1, 5, 1, function() return RP.S.greaterMin end, function(v) RP.Set("greaterMin", v); Changed() end))
    end
    if any and class ~= "PALADIN" and class ~= "SHAMAN" then
        left:Add("Group spell when at least", "members of a group need it (needs reagents)",
            W.Slider(left, 1, 5, 1, function() return RP.S.groupMin end, function(v) RP.Set("groupMin", v); Changed() end))
    end
    if any then
        left:Add("Wait until everyone is in range", "before using a group / greater spell",
            W.Toggle(left, function() return RP.S.waitRange end, function(v) RP.Set("waitRange", v); Changed() end))
    else
        local none = St.Text(left, 12, "body")
        none:SetPoint("TOPLEFT", 12, -38)
        none:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
        none:SetText(class == "SHAMAN" and "Shamans plan totems on the Assignments page." or "Your class has no group buffs.\nRaidPower still tracks your self-buffs.")
        none:SetJustifyH("LEFT")
        none:SetWordWrap(true)
        none:SetWidth(colW - 24)
    end

    local right = W.Group(f, "Self-buffs to track", colW, 260)
    right:SetPoint("TOPLEFT", colW + 16, -36)
    for _, def in ipairs(RP.SELF[class] or {}) do
        local key = def.key
        local row = right:Add(def.label, def.items and "Uses the best poison you carry" or nil,
            W.Toggle(right, function() return RP.SelfOn(key) end, function(v) RP.CharDB.selfOn[key] = v; Changed() end))
        if def.options and #def.options > 1 then
            local pick = W.Button(row, "Choose", 70)
            pick:SetPoint("RIGHT", row.control, "LEFT", -10, 0)
            local function Label()
                local opt = RP.SelfOption(def)
                pick:SetLabel(opt and opt.label:gsub("^Aspect of the ", ""):gsub(" Armor$", ""):gsub(" Weapon$", ""):gsub(" Shield$", "") or "Choose")
            end
            Label()
            pick:SetScript("OnClick", function(self)
                local items = {}
                for i, opt in ipairs(def.options) do
                    local known = RP.KnowsAny(opt.ids)
                    items[#items + 1] = { text = opt.label .. (known and "" or " (not learned)"), icon = RP.SpellIcon(opt.ids[1]), disabled = not known,
                        checked = select(2, RP.SelfOption(def)) == i,
                        func = function() RP.CharDB.selfChoice[key] = i; Label(); Changed() end }
                end
                W.Menu(self, items, def.label)
            end)
        end
        if def.tankOnly then
            local seg = W.Segmented(row, { { "always", "Always" }, { "tank", "Tank" }, { "never", "Never" } },
                function() return RP.CharDB.furyMode end, function(v) RP.CharDB.furyMode = v; Changed() end, 52)
            seg:SetPoint("RIGHT", row.control, "LEFT", -10, 0)
        end
    end
    if not RP.SELF[class] then
        local none = St.Text(right, 12, "body")
        none:SetPoint("TOPLEFT", 12, -38)
        none:SetText("No self-buffs for this class.")
    end

    local timing = W.Group(f, "Timing", colW * 2 + 16, 108)
    timing:SetPoint("TOPLEFT", 0, -312)
    timing:Add("Warn when a long buff has less than", "Short buffs (Battle Shout, shields) warn at 15% of their duration",
        W.Slider(timing, 1, 15, 1, function() return math.floor((RP.S.expiring or 300) / 60) end,
            function(v) RP.Set("expiring", v * 60); Changed() end, function(v) return v .. " min" end))
    timing:Add("Show tooltips", nil, W.Toggle(timing, function() return RP.S.tooltips end, function(v) RP.Set("tooltips", v) end))
end

RP.RegisterPage("mine", { label = "My Buffs", section = "You", icon = "Interface\\Icons\\Spell_Holy_InnerFire", build = Build })
