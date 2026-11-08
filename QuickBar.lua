-- FriendMap quick bar: a small movable bar of icon buttons (help, ping, rally...).
-- Each player chooses which icons it shows in its settings (/fm bar).
local FM = FriendMap
local HBD = LibStub("HereBeDragons-2.0")

----------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------
local function NearestFriend()
    local best, bestDist
    for _, list in pairs(FM.members) do
        for _, m in pairs(list) do
            local d = FM:VectorTo(m.inst, m.x, m.y)
            if d and (not bestDist or d < bestDist) then best, bestDist = m, d end
        end
    end
    return best
end

FM.BarActions = {
    { key = "help", label = "Help!", icon = "Interface\\Icons\\Spell_Holy_LayOnHands",
      tip = "Call your groups for help", func = function() FM:SendHelp(false) end },
    { key = "ping", label = "Ping my position", icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
      tip = "Pulse a marker at your position on your friends' maps", func = function() FM.SlashExtra.ping("") end },
    { key = "rally", label = "Rally here", icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
      tip = "Set the rally point at your position", func = function() FM.SlashExtra.rally("") end },
    { key = "clearrally", label = "Clear rally point", icon = "Interface\\Icons\\Ability_Rogue_Feint",
      tip = "Remove the rally point", func = function() FM:ClearRally() end,
      active = function() return FM.rally ~= nil end },
    { key = "nearest", label = "Track nearest friend", icon = "Interface\\Icons\\Ability_Tracking",
      tip = "Arrow towards the closest friend", func = function()
          local m = NearestFriend()
          if m then FM:Track(m.name) else FM:Print("No friend on this continent.") end
      end },
    { key = "stoparrow", label = "Stop arrow", icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
      tip = "Stop tracking", func = function() FM:Track(nil) end,
      active = function() return FM.trackName ~= nil end },
    { key = "sharing", label = "Share my position (on/off)", icon = "Interface\\Icons\\Spell_Holy_MindVision",
      tip = "Toggle sharing your position", func = function() FM:Slash("share") end,
      active = function() return FriendMapDB.sharing end },
    { key = "pvp", label = "Announce PvP fights (on/off)", icon = "Interface\\Icons\\Ability_DualWield",
      tip = "Toggle announcing your world PvP fights", func = function() FM:Slash("pvp") end,
      active = function() return FriendMapDB.pvpAnnounce end },
    { key = "top", label = "PvP leaderboard", icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
      tip = "Show this week's world PvP kills", func = function() FM.SlashExtra.top() end },
    { key = "window", label = "Settings", icon = "Interface\\Icons\\INV_Misc_Gear_01",
      tip = "Open the FriendMap window (groups, options)", func = function() FM:ToggleUI() end },
}

local DEFAULT_ON = { help = true, rally = true, top = true, window = true }

local function DB()
    FriendMapDB.bar = FriendMapDB.bar or {}
    local b = FriendMapDB.bar
    if b.shown == nil then b.shown = true end
    if b.locked == nil then b.locked = false end
    if b.vertical == nil then b.vertical = false end
    b.size = b.size or 32
    if not b.buttons then
        b.buttons = {}
        for k, v in pairs(DEFAULT_ON) do b.buttons[k] = v end
    end
    return b
end

----------------------------------------------------------------------
-- The bar
----------------------------------------------------------------------
local bar = CreateFrame("Frame", "FriendMapQuickBar", UIParent, BackdropTemplateMixin and "BackdropTemplate")
bar:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
bar:SetClampedToScreen(true)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:Hide()
if bar.SetBackdrop then
    bar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    bar:SetBackdropColor(0, 0, 0, 0.6)
    bar:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
end
bar:SetScript("OnDragStart", function(self) if not DB().locked then self:StartMoving() end end)
bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    DB().pos = { p, rp, x, y }
end)
bar:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then FM:ToggleBarConfig() end
end)
bar.buttons = {}

local function MakeButton(i)
    local b = CreateFrame("Button", nil, bar)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("TOPLEFT", -1, 1)
    b.border:SetPoint("BOTTOMRIGHT", 1, -1)
    b.border:SetColorTexture(0, 0, 0, 0)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then FM:ToggleBarConfig() return end
        FM:WithHardware(self.action.func)
        FM:UpdateBar()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.action.label)
        GameTooltip:AddLine(self.action.tip, 1, 1, 1, true)
        GameTooltip:AddLine("Right-click: choose icons", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    -- drag the bar from any of its buttons
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function() if not DB().locked then bar:StartMoving() end end)
    b:SetScript("OnDragStop", function() bar:GetScript("OnDragStop")(bar) end)
    bar.buttons[i] = b
    return b
end

function FM:UpdateBar()
    local db = DB()
    if not db.shown then bar:Hide() return end
    local size, gap, pad = db.size, 4, 6
    local n = 0
    for _, a in ipairs(self.BarActions) do
        if db.buttons[a.key] then
            n = n + 1
            local b = bar.buttons[n] or MakeButton(n)
            b.action = a
            b:SetSize(size, size)
            b.icon:SetTexture(a.icon)
            b:ClearAllPoints()
            if db.vertical then
                b:SetPoint("TOP", bar, "TOP", 0, -pad - (n - 1) * (size + gap))
            else
                b:SetPoint("LEFT", bar, "LEFT", pad + (n - 1) * (size + gap), 0)
            end
            -- toggles look greyed out while off
            local on = not a.active or a.active()
            b.icon:SetDesaturated(not on)
            b.icon:SetAlpha(on and 1 or 0.5)
            b:Show()
        end
    end
    for i = n + 1, #bar.buttons do bar.buttons[i]:Hide() end
    if n == 0 then bar:Hide() return end
    local long = pad * 2 + n * size + (n - 1) * gap
    local short = size + pad * 2
    if db.vertical then bar:SetSize(short, long) else bar:SetSize(long, short) end
    bar:Show()
end

----------------------------------------------------------------------
-- Settings window
----------------------------------------------------------------------
local cfg

local function Check(parent, label, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c.text = c.text or c.Text or c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.text:SetText(label)
    c.get = get
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); FM:UpdateBar() end)
    return c
end

local function BuildConfig()
    cfg = CreateFrame("Frame", "FriendMapBarConfig", UIParent, "BasicFrameTemplateWithInset")
    cfg:SetSize(300, 164 + #FM.BarActions * 28)
    cfg:SetPoint("CENTER", 260, 0)
    cfg:SetFrameStrata("DIALOG")
    cfg:SetMovable(true)
    cfg:EnableMouse(true)
    cfg:RegisterForDrag("LeftButton")
    cfg:SetScript("OnDragStart", cfg.StartMoving)
    cfg:SetScript("OnDragStop", cfg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "FriendMapBarConfig")
    local title = cfg.TitleText or cfg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not cfg.TitleText then title:SetPoint("TOP", 0, -5) end
    title:SetText("FriendMap quick bar")

    cfg.checks = {}
    local y = -30
    local hdr = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT", 14, y)
    hdr:SetText("Icons to show")
    y = y - 20
    for _, a in ipairs(FM.BarActions) do
        local c = Check(cfg, "", function() return DB().buttons[a.key] end, function(v) DB().buttons[a.key] = v or nil end)
        c:SetPoint("TOPLEFT", 12, y)
        local ic = cfg:CreateTexture(nil, "ARTWORK")
        ic:SetSize(22, 22)
        ic:SetPoint("LEFT", c, "RIGHT", 2, 0)
        ic:SetTexture(a.icon)
        ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        c.text:ClearAllPoints()
        c.text:SetPoint("LEFT", ic, "RIGHT", 6, 0)
        c.text:SetText(a.label)
        table.insert(cfg.checks, c)
        y = y - 28
    end

    y = y - 6
    local hdr2 = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr2:SetPoint("TOPLEFT", 14, y)
    hdr2:SetText("Bar")
    y = y - 20
    local opts = {
        { "Show the bar", function() return DB().shown end, function(v) DB().shown = v end },
        { "Lock position", function() return DB().locked end, function(v) DB().locked = v end },
        { "Vertical", function() return DB().vertical end, function(v) DB().vertical = v end },
    }
    for i, o in ipairs(opts) do
        local c = Check(cfg, o[1], o[2], o[3])
        c:SetPoint("TOPLEFT", 12 + (i - 1) * 95, y)
        table.insert(cfg.checks, c)
    end
    y = y - 30

    local small = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
    small:SetSize(40, 20); small:SetText("-")
    small:SetPoint("TOPLEFT", 14, y)
    small:SetScript("OnClick", function() DB().size = math.max(20, DB().size - 4); FM:UpdateBar(); cfg.sizeText:SetText("Icon size: " .. DB().size) end)
    local big = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
    big:SetSize(40, 20); big:SetText("+")
    big:SetPoint("LEFT", small, "RIGHT", 4, 0)
    big:SetScript("OnClick", function() DB().size = math.min(56, DB().size + 4); FM:UpdateBar(); cfg.sizeText:SetText("Icon size: " .. DB().size) end)
    cfg.sizeText = cfg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cfg.sizeText:SetPoint("LEFT", big, "RIGHT", 8, 0)

    local defaults = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
    defaults:SetSize(90, 20); defaults:SetText("Default icons")
    defaults:SetPoint("TOPRIGHT", -14, y - 24)
    defaults:SetScript("OnClick", function()
        DB().buttons = {}
        for k, v in pairs(DEFAULT_ON) do DB().buttons[k] = v end
        FM:UpdateBar(); FM:RefreshBarConfig()
    end)

    local reset = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
    reset:SetSize(90, 20); reset:SetText("Reset position")
    reset:SetPoint("TOPRIGHT", -14, y)
    reset:SetScript("OnClick", function()
        DB().pos = nil
        bar:ClearAllPoints(); bar:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        DB().shown = true
        FM:UpdateBar(); FM:RefreshBarConfig()
    end)
end

function FM:RefreshBarConfig()
    if not cfg then return end
    for _, c in ipairs(cfg.checks) do c:SetChecked(c.get() and true or false) end
    cfg.sizeText:SetText("Icon size: " .. DB().size)
end

function FM:ToggleBarConfig()
    if not cfg then BuildConfig() end
    cfg:SetShown(not cfg:IsShown())
    self:RefreshBarConfig()
end

FM.SlashExtra.bar = function() FM:ToggleBarConfig() end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    local db = DB()
    if db.pos then
        bar:ClearAllPoints()
        bar:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
    end
    FM:UpdateBar()
end)
-- keep on/off looks in sync (sharing, rally, arrow...)
C_Timer.NewTicker(1, function() if bar:IsShown() then FM:UpdateBar() end end)
