-- PageAppearance.lua: bar style, visibility, accent colour, the Esc-menu button.
local _, RP = ...

local St, W = RP.Style, RP.Widgets

local function Set(key)
    return function(v) RP.Set(key, v); RP.RequestRefresh(true) end
end
local function Get(key)
    return function() return RP.S[key] end
end

local function Swatches(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(4 * 26, 20)
    f.items = {}
    for i, name in ipairs(RP.ACCENT_ORDER) do
        local c = RP.ACCENTS[name]
        local b = CreateFrame("Button", nil, f)
        b:SetSize(20, 20)
        b:SetPoint("LEFT", (i - 1) * 26, 0)
        St.Skin(b, { c[1], c[2], c[3], 1 }, true)
        b.sel = St.Tex(b, "OVERLAY", { 1, 1, 1, 1 })
        b.sel:SetPoint("BOTTOMLEFT", 0, -4); b.sel:SetPoint("BOTTOMRIGHT", 0, -4); b.sel:SetHeight(2)
        b:SetScript("OnClick", function() RP.Set("accent", name); f:Refresh() end)
        W.AttachTooltip(b, name:gsub("^%l", string.upper), nil)
        f.items[name] = b
    end
    function f:Refresh()
        for name, b in pairs(f.items) do b.sel:SetShown(RP.S.accent == name) end
    end
    f:Refresh()
    return f
end

local function Build(f)
    RP.PageHeader(f, "Appearance")
    local unlock = W.Button(f, "Reset positions", 120)
    unlock:SetPoint("TOPRIGHT", 0, 2)
    unlock:SetScript("OnClick", function() RP.ResetPositions() end)

    local colW = 360
    local bars = W.Group(f, "Bars", colW, 360)
    bars:SetPoint("TOPLEFT", 0, -36)
    bars:Add("Layout", nil, W.Segmented(bars, { { "full", "Full", "Every tile, group pills and labels" },
        { "compact", "Compact", "One icon per buff" }, { "smart", "Smart only", "Just the Smart Buff button" } },
        Get("layout"), Set("layout"), 84))
    bars:Add("Icon size", nil, W.Slider(bars, 24, 48, 2, Get("iconSize"), Set("iconSize")))
    bars:Add("Scale", nil, W.Slider(bars, 0.6, 1.6, 0.05, Get("scale"), Set("scale"), function(v) return ("%.0f%%"):format(v * 100) end))
    bars:Add("Class labels", nil, W.Toggle(bars, Get("classLabels"), Set("classLabels")))
    bars:Add("Paladin bar vertical", "Classic PallyPower column", W.Toggle(bars, Get("palVertical"), Set("palVertical")))
    bars:Add("Self-buff strip", nil, W.Toggle(bars, Get("selfShown"), Set("selfShown")))
    bars:Add("Smart Buff button", nil, W.Toggle(bars, Get("smartShown"), Set("smartShown")))
    bars:Add("Smart Buff floats on its own", "Off: docks under the main bar", W.Toggle(bars, Get("smartSeparate"), Set("smartSeparate")))
    bars:Add("Lock bars", nil, W.Toggle(bars, Get("locked"), Set("locked")))
    bars:Add("Accent colour", nil, Swatches(bars))

    local vis = W.Group(f, "Visibility", colW, 220)
    vis:SetPoint("TOPLEFT", colW + 16, -36)
    vis:Add("Show when solo", nil, W.Toggle(vis, Get("showSolo"), Set("showSolo")))
    vis:Add("Show in a party", nil, W.Toggle(vis, Get("showParty"), Set("showParty")))
    vis:Add("Hide when everything is buffed", "Out of combat only", W.Toggle(vis, Get("hideWhenDone"), Set("hideWhenDone")))
    vis:Add("Fade when nothing is due", nil, W.Toggle(vis, Get("fadeOOC"), Set("fadeOOC")))
    vis:Add("Button in the game menu (Esc)", "Opens RaidPower", W.Toggle(vis, Get("gameMenu"), Set("gameMenu")))

    local keys = W.Group(f, "Key binding", colW, 124)
    keys:SetPoint("TOPLEFT", colW + 16, -268)
    local t = St.Text(keys, 12, "body")
    t:SetPoint("TOPLEFT", 12, -36)
    t:SetPoint("RIGHT", -12, 0)
    t:SetJustifyH("LEFT")
    t:SetWordWrap(true)
    t:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    t:SetText("Bind Smart Buff in Options > Keybindings > AddOns > RaidPower. Every press casts the next most urgent buff you owe. In combat it steps through the list made before the pull.")
    keys.text = t
end

RP.RegisterPage("look", { label = "Appearance", section = "Setup", icon = "Interface\\Icons\\Spell_Nature_Tranquility", build = Build })
