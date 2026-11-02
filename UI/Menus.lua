-- Menus.lua: /raidpower, the Options > AddOns entry, the Esc game-menu button (on by default, a toggle on the
-- Appearance page), the addon compartment and key-binding labels.
local _, RP = ...

local St = RP.Style

-- Key bindings (Bindings.xml) -------------------------------------------------------------------------------
_G.BINDING_HEADER_RAIDPOWER = "RaidPower"
_G["BINDING_NAME_CLICK RaidPowerSmartButton:LeftButton"] = "Smart Buff (cast next buff)"
_G.BINDING_NAME_RAIDPOWER_TOGGLE = "Open / close RaidPower"

-- Slash command ---------------------------------------------------------------------------------------------
local function Help()
    RP.Print("/raidpower - open the window")
    RP.Print("/raidpower auto - auto-assign   |   /raidpower report - report missing buffs")
    RP.Print("/raidpower lock | unlock - lock bars   |   /raidpower reset - reset bar positions")
    RP.Print("/raidpower show | hide - show or hide the bars")
end

SLASH_RAIDPOWER1 = "/raidpower"
SlashCmdList.RAIDPOWER = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then RP.ToggleWindow()
    elseif msg == "auto" then RP.RunAutoAssign()
    elseif msg == "report" then RP.ReportMissing()
    elseif msg == "lock" then RP.Set("locked", true); RP.Print("Bars locked.")
    elseif msg == "unlock" then RP.Set("locked", false); RP.Print("Bars unlocked: drag their headers.")
    elseif msg == "reset" then RP.ResetPositions()
    elseif msg == "hide" then RP.hiddenByUser = true; RP.RequestRefresh(true)
    elseif msg == "show" then RP.hiddenByUser = false; RP.RequestRefresh(true)
    elseif msg == "debug" then RP.DebugDump()
    else Help() end
end

function RP.DebugDump()
    local plan = RP.MyPlan()
    RP.Print(("v%s · %s · roster %d · auras hidden: %s · combat: %s"):format(RP.VERSION, plan.class or "?", #RP.roster,
        tostring(RP.AurasHidden()), tostring(InCombatLockdown())))
    local known = {}
    for k in pairs(plan.known or {}) do known[#known + 1] = k end
    table.sort(known)
    RP.Print("known: " .. (#known > 0 and table.concat(known, ", ") or "none"))
    local s = RP.state
    if s then
        RP.Print(("tiles: %d blessings, %d group rows, %d self, smart queue %d"):format(#s.blessings, #s.groupRows, #s.selfTiles, #s.smart))
        for i, e in ipairs(s.smart) do
            if i > 5 then break end
            RP.Print(("  %d. %s -> %s (%s)"):format(i, RP.SpellName(e.spellG), e.m and e.m.who or "?", e.rank == 0 and "missing" or "expiring"))
        end
    end
end

-- Options > AddOns -------------------------------------------------------------------------------------------
local function OpenFromSettings()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    C_Timer.After(0, function() RP.ToggleWindow("overview") end)
end

local function BuildSettingsPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "RaidPower"
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(St.LOGO)
    logo:SetSize(64, 64)
    logo:SetPoint("TOPLEFT", 20, -20)
    local title = St.Text(panel, 30, "bold")
    title:SetPoint("LEFT", logo, "RIGHT", 14, 8)
    title:SetText("RAID|c" .. RP.AccentHex() .. "POWER|r")
    local sub = St.Text(panel, 13, "body")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetTextColor(St.MUTED[1], St.MUTED[2], St.MUTED[3])
    sub:SetText("Universal raid buff manager · version " .. RP.VERSION)
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(220, 32)
    open:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -24)
    open:SetText("Open RaidPower")
    open:SetScript("OnClick", OpenFromSettings)
    local menuCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    menuCheck:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -4, -16)
    local label = St.Text(panel, 13, "body")
    label:SetPoint("LEFT", menuCheck, "RIGHT", 4, 0)
    label:SetText("Show a RaidPower button in the game menu (Esc)")
    menuCheck:SetScript("OnShow", function(self) self:SetChecked(RP.S.gameMenu) end)
    menuCheck:SetScript("OnClick", function(self) RP.Set("gameMenu", self:GetChecked() and true or false) end)
    local tip = St.Text(panel, 12, "body")
    tip:SetPoint("TOPLEFT", menuCheck, "BOTTOMLEFT", 4, -16)
    tip:SetTextColor(St.FAINT[1], St.FAINT[2], St.FAINT[3])
    tip:SetText("Type /raidpower to open it any time. All settings live in the RaidPower window.")
    local category = Settings.RegisterCanvasLayoutCategory(panel, "RaidPower")
    Settings.RegisterAddOnCategory(category)
    RP.settingsCategory = category
end

-- Esc game menu -----------------------------------------------------------------------------------------------
local menuButton
local NUDGE = 0.002

local function MenuLabel()
    return "Raid|c" .. RP.AccentHex() .. "Power|r"
end

local function MenuClicked()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    HideUIPanel(GameMenuFrame)
    RP.ToggleWindow("overview")
end

local function ButtonText(b)
    local t = b.GetText and b:GetText()
    return type(t) == "string" and t or ""
end

local function Added(menu)
    menuButton = nil
    if not RP.S.gameMenu then return end
    menuButton = MainMenuFrameMixin.AddButton(menu, MenuLabel(), MenuClicked)
end

-- Sit right after Options, below any other addon buttons placed there (Naowh, Ellesmere).
local function Placed(menu)
    if not (menuButton and menuButton:IsShown()) then return end
    local options
    for _, child in ipairs({ menu:GetChildren() }) do
        if child ~= menuButton and child.layoutIndex and ButtonText(child) == GAMEMENU_OPTIONS then options = child end
    end
    if not options then return end
    local last, foreign = options.layoutIndex, false
    for _, child in ipairs({ menu:GetChildren() }) do
        local li = child.layoutIndex
        if child ~= menuButton and child:IsShown() and li and li > options.layoutIndex and li < options.layoutIndex + 0.5 then
            if li > last then last = li end
            foreign = true
        end
    end
    menuButton.layoutIndex = last + NUDGE
    menuButton.topPadding = (not foreign) and 20 or nil
    if menu.MarkDirty then menu:MarkDirty() end
end

local function HookGameMenu()
    if not (GameMenuFrame and GameMenuFrame.InitButtons and MainMenuFrameMixin and MainMenuFrameMixin.AddButton) then return false end
    hooksecurefunc(GameMenuFrame, "InitButtons", Added)
    GameMenuFrame:HookScript("OnShow", Placed)
    return true
end

-- Addon compartment (minimap addon list) ------------------------------------------------------------------------
function _G.RaidPower_OnCompartmentClick() RP.ToggleWindow() end
function _G.RaidPower_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button or UIParent, "ANCHOR_LEFT")
    GameTooltip:SetText("RaidPower")
    GameTooltip:AddLine("Click to open. /raidpower", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end
function _G.RaidPower_OnCompartmentLeave() GameTooltip:Hide() end

function RP.InitMenus()
    BuildSettingsPanel()
    if not HookGameMenu() then
        RP.On("ADDON_LOADED", function() if not RP.gameMenuHooked then RP.gameMenuHooked = HookGameMenu() end end)
    else
        RP.gameMenuHooked = true
    end
end
