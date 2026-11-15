-- FriendMap world PvP leaderboard window.
--   Ranking tab: podium for the top 3, ranking bars, your own rank.
--   History tab: every kill of the week (killer, victim class + level, zone, time),
--                filtered to one member by clicking them in the ranking.
-- Opened by /fm top or the quick bar.
local FM = FriendMap

local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local MEDALS = {
    { 1, 0.82, 0.1 },    -- gold
    { 0.78, 0.8, 0.86 }, -- silver
    { 0.82, 0.5, 0.25 }, -- bronze
}
local GOLD = { 1, 0.82, 0 }
local W, H = 460, 610
local LIST_ROWS = 8
local HIST_ROWS, HIST_H = 12, 34

local frame

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function ClassColor(class)
    local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if c then return c.r, c.g, c.b end
    return 0.75, 0.75, 0.75
end

local function Hex(r, g, b) return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) end

local function SetClassIcon(tex, class)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        tex:SetTexture(CLASS_ICONS)
        tex:SetTexCoord(unpack(coords))
    else
        tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
end

local function ClassName(class)
    return class and (LOCALIZED_CLASS_NAMES_MALE or {})[class] or nil
end

local function Ago(t)
    local d = time() - (t or time())
    if d < 60 then return "just now" end
    if d < 3600 then return math.floor(d / 60) .. " min ago" end
    if d < 86400 then return math.floor(d / 3600) .. " h ago" end
    return math.floor(d / 86400) .. " d ago"
end

local function Panel(parent, a)
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.07, a or 0.85)
        f:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
    end
    return f
end

-- thin gold line
local function Rule(parent, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetHeight(1)
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
    return t
end

----------------------------------------------------------------------
-- Podium card
----------------------------------------------------------------------
local function Card(parent, rank, height)
    local c = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    c:SetSize(128, height)
    local m = MEDALS[rank]
    if c.SetBackdrop then
        c:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        c:SetBackdropColor(0.06, 0.05, 0.05, 0.9)
        c:SetBackdropBorderColor(m[1], m[2], m[3], 1)
    end
    -- soft medal-coloured light rising from the bottom
    c.glow = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.glow:SetPoint("TOPLEFT", 4, -4)
    c.glow:SetPoint("BOTTOMRIGHT", -4, 4)
    c.glow:SetColorTexture(1, 1, 1, 1)
    if c.glow.SetGradient and CreateColor then
        c.glow:SetGradient("VERTICAL", CreateColor(m[1], m[2], m[3], 0.28), CreateColor(m[1], m[2], m[3], 0.02))
    else
        c.glow:SetColorTexture(m[1], m[2], m[3], 0.1)
    end
    c.hl = c:CreateTexture(nil, "HIGHLIGHT")
    c.hl:SetPoint("TOPLEFT", 4, -4)
    c.hl:SetPoint("BOTTOMRIGHT", -4, 4)
    c.hl:SetColorTexture(1, 1, 1, 0.06)

    c.medal = c:CreateTexture(nil, "ARTWORK")
    c.medal:SetSize(26, 26)
    c.medal:SetPoint("TOP", 0, -8)
    c.medal:SetTexture(DISC)
    c.medal:SetVertexColor(m[1], m[2], m[3])
    c.rank = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.rank:SetPoint("CENTER", c.medal, 0, 0)
    c.rank:SetText(rank)
    c.rank:SetTextColor(0.12, 0.08, 0.02)

    local size = rank == 1 and 50 or 40
    c.ring = c:CreateTexture(nil, "BORDER")
    c.ring:SetSize(size + 6, size + 6)
    c.ring:SetPoint("TOP", c.medal, "BOTTOM", 0, -4)
    c.ring:SetTexture(DISC)
    c.ring:SetVertexColor(m[1], m[2], m[3], 0.95)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(size, size)
    c.icon:SetPoint("CENTER", c.ring)

    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("TOP", c.ring, "BOTTOM", 0, -5)
    c.name:SetWidth(120)
    c.name:SetWordWrap(false)

    c.count = c:CreateFontString(nil, "OVERLAY", rank == 1 and "GameFontNormalHuge" or "GameFontNormalLarge")
    c.count:SetPoint("BOTTOM", 0, 22)
    c.count:SetTextColor(m[1], m[2], m[3])
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.label:SetPoint("TOP", c.count, "BOTTOM", 0, -2)

    c:SetScript("OnClick", function(self) if self.who then FM:ShowKillHistory(self.who) end end)
    c:SetScript("OnEnter", function(self)
        if not self.who then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.who)
        GameTooltip:AddLine("Click: see their kills", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", GameTooltip_Hide)
    return c
end

local function FillCard(c, e)
    c.who = e and e.name
    if not e then
        SetClassIcon(c.icon, nil)
        c.icon:SetDesaturated(true)
        c.name:SetText("|cff555555—|r")
        c.count:SetText("")
        c.label:SetText("")
        c:SetAlpha(0.45)
        return
    end
    c.icon:SetDesaturated(false)
    c:SetAlpha(1)
    local class = FM:KillerClass(e.name)
    SetClassIcon(c.icon, class)
    c.name:SetText(e.name)
    c.name:SetTextColor(ClassColor(class))
    c.count:SetText(e.n)
    c.label:SetText(("points  ·  |cffffffff%d|r K  |cffffffff%d|r A"):format(e.k or e.n, e.a or 0))
end

----------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------
local function Tab(parent, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(92, 24)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetPoint("BOTTOMLEFT")
    b.line:SetPoint("BOTTOMRIGHT")
    b.line:SetHeight(2)
    b.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText(text)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.08)
    function b:SetActive(on)
        self.bg:SetColorTexture(on and 0.35 or 0.1, on and 0.08 or 0.08, on and 0.06 or 0.08, on and 0.75 or 0.6)
        self.line:SetShown(on)
        self.text:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0 or 0.6)
    end
    return b
end

local function SelectTab(which)
    frame.tab = which
    frame.rankPage:SetShown(which == "rank")
    frame.histPage:SetShown(which == "hist")
    frame.seasonPage:SetShown(which == "season")
    frame.tabRank:SetActive(which == "rank")
    frame.tabHist:SetActive(which == "hist")
    frame.tabSeason:SetActive(which == "season")
    frame.viewSel:SetShown(which ~= "season")
    FM:RefreshLeaderboard()
end

----------------------------------------------------------------------
-- Build: frame + header
----------------------------------------------------------------------
local BuildRanking, BuildHistory, BuildSeasons, RefreshSeasons

local function Build()
    frame = CreateFrame("Frame", "FriendMapLeaderboard", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(W, H)
    frame:SetPoint("CENTER", -150, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "FriendMapLeaderboard")
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    -- header: dark red band fading to the right, gold underline
    local banner = frame:CreateTexture(nil, "ARTWORK")
    banner:SetPoint("TOPLEFT", 12, -12)
    banner:SetPoint("TOPRIGHT", -12, -12)
    banner:SetHeight(60)
    banner:SetColorTexture(1, 1, 1, 1)
    if banner.SetGradient and CreateColor then
        banner:SetGradient("HORIZONTAL", CreateColor(0.55, 0.06, 0.04, 0.9), CreateColor(0.18, 0.03, 0.03, 0.6))
    else
        banner:SetColorTexture(0.45, 0.05, 0.05, 0.6)
    end
    local under = Rule(frame, "OVERLAY")
    under:SetPoint("BOTTOMLEFT", banner)
    under:SetPoint("BOTTOMRIGHT", banner)
    under:SetHeight(2)
    under:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)

    local iconRing = frame:CreateTexture(nil, "OVERLAY")
    iconRing:SetSize(48, 48)
    iconRing:SetPoint("LEFT", banner, "LEFT", 10, 0)
    iconRing:SetTexture(DISC)
    iconRing:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    local icon = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    icon:SetSize(42, 42)
    icon:SetPoint("CENTER", iconRing)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
    if SetPortraitToTexture then SetPortraitToTexture(icon, "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01") end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", iconRing, "TOPRIGHT", 10, -6)
    title:SetText("World PvP Leaderboard")
    frame.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- tabs
    frame.tabRank = Tab(frame, "Ranking")
    frame.tabRank:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 6, -8)
    frame.tabHist = Tab(frame, "Kill history")
    frame.tabHist:SetPoint("LEFT", frame.tabRank, "RIGHT", 6, 0)
    frame.tabRank:SetScript("OnClick", function() SelectTab("rank") end)
    frame.tabHist:SetScript("OnClick", function() frame.filter = nil; SelectTab("hist") end)
    frame.tabSeason = Tab(frame, "Seasons")
    frame.tabSeason:SetPoint("LEFT", frame.tabHist, "RIGHT", 6, 0)
    frame.tabSeason:SetScript("OnClick", function() SelectTab("season") end)

    -- view: this week, or a running season
    local vs = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    vs:SetSize(150, 22)
    vs:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -2, -32)
    if vs.SetBackdrop then
        vs:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        vs:SetBackdropColor(0.1, 0.08, 0.05, 0.9)
        vs:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.7)
    end
    vs.text = vs:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vs.text:SetPoint("LEFT", 8, 0)
    vs.text:SetPoint("RIGHT", -16, 0)
    vs.text:SetWordWrap(false)
    vs.arrow = vs:CreateTexture(nil, "OVERLAY")
    vs.arrow:SetSize(14, 14)
    vs.arrow:SetPoint("RIGHT", -3, 0)
    vs.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    local vhl = vs:CreateTexture(nil, "HIGHLIGHT")
    vhl:SetPoint("TOPLEFT", 2, -2); vhl:SetPoint("BOTTOMRIGHT", -2, 2)
    vhl:SetColorTexture(1, 0.82, 0, 0.12)
    vs:SetScript("OnClick", function()
        frame.viewIdx = (frame.viewIdx or 1) % #frame.views + 1
        frame.filter = nil
        FM:RefreshLeaderboard()
    end)
    vs:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Click: switch between this week and the running seasons")
        GameTooltip:Show()
    end)
    vs:SetScript("OnLeave", GameTooltip_Hide)
    frame.viewSel = vs

    local tabLine = Rule(frame)
    tabLine:SetPoint("TOPLEFT", frame.tabRank, "BOTTOMLEFT", -6, 0)
    tabLine:SetPoint("RIGHT", banner, "RIGHT")

    local page = function()
        local p = CreateFrame("Frame", nil, frame)
        p:SetPoint("TOPLEFT", 16, -118)
        p:SetPoint("BOTTOMRIGHT", -16, 34)
        return p
    end
    frame.rankPage = page()
    frame.histPage = page()
    frame.seasonPage = page()
    BuildRanking(frame.rankPage)
    BuildHistory(frame.histPage)
    BuildSeasons(frame.seasonPage)

    local foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOM", 0, 18)
    foot:SetText("Kill: |cffff2020skull 8|r  |cffffd100yellow+ 5|r  |cff40ff40green 3|r  |cff9d9d9dgrey 2|r  ·  assist 1")

    SelectTab("rank")
end

----------------------------------------------------------------------
-- Ranking page
----------------------------------------------------------------------
function BuildRanking(p)
    frame.cards = {}
    local podium = CreateFrame("Frame", nil, p)
    podium:SetSize(W - 40, 186)
    podium:SetPoint("TOP", 0, -4)
    frame.cards[1] = Card(podium, 1, 184)
    frame.cards[1]:SetPoint("BOTTOM", podium, "BOTTOM", 0, 0)
    frame.cards[2] = Card(podium, 2, 162)
    frame.cards[2]:SetPoint("BOTTOMRIGHT", frame.cards[1], "BOTTOMLEFT", -10, 0)
    frame.cards[3] = Card(podium, 3, 150)
    frame.cards[3]:SetPoint("BOTTOMLEFT", frame.cards[1], "BOTTOMRIGHT", 10, 0)

    -- your line, on a slim gold-tinted strip
    local strip = p:CreateTexture(nil, "BACKGROUND")
    strip:SetPoint("TOPLEFT", podium, "BOTTOMLEFT", 0, -8)
    strip:SetPoint("TOPRIGHT", podium, "BOTTOMRIGHT", 0, -8)
    strip:SetHeight(24)
    strip:SetColorTexture(1, 0.82, 0, 0.08)
    frame.me = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.me:SetPoint("CENTER", strip)

    local list = Panel(p)
    list:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -8)
    list:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, -8)
    list:SetHeight(LIST_ROWS * 25 + 12)
    frame.rows = {}
    for i = 1, LIST_ROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetHeight(23)
        r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 25)
        r:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * 25)
        r.zebra = r:CreateTexture(nil, "BACKGROUND")
        r.zebra:SetAllPoints()
        r.zebra:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
        r.me = r:CreateTexture(nil, "BACKGROUND", nil, 1)
        r.me:SetAllPoints()
        r.me:SetColorTexture(1, 0.82, 0, 0.14)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.07)
        r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.rank:SetPoint("LEFT", 2, 0)
        r.rank:SetWidth(24)
        r.rank:SetJustifyH("RIGHT")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", r.rank, "RIGHT", 8, 0)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetWidth(130)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.count:SetPoint("RIGHT", -6, 0)
        r.count:SetWidth(78)
        r.count:SetJustifyH("RIGHT")
        r.barBg = r:CreateTexture(nil, "BORDER")
        r.barBg:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
        r.barBg:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r.barBg:SetHeight(12)
        r.barBg:SetColorTexture(0, 0, 0, 0.5)
        r.bar = r:CreateTexture(nil, "ARTWORK")
        r.bar:SetPoint("LEFT", r.barBg, "LEFT")
        r.bar:SetHeight(12)
        r.bar:SetTexture(BAR)
        r.pts = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.pts:SetPoint("LEFT", r.barBg, "LEFT", 4, 0)
        r:SetScript("OnClick", function(self) if self.who then FM:ShowKillHistory(self.who) end end)
        frame.rows[i] = r
    end
    frame.list = list

    frame.empty = p:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    frame.empty:SetPoint("CENTER", list)
    frame.empty:SetText("No kills yet.\nGo hunt some enemies!")

    local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", list, "BOTTOM", 0, -6)
    hint:SetText("Click a player to see their kills")
end

----------------------------------------------------------------------
-- History page
----------------------------------------------------------------------
function BuildHistory(p)
    -- filter bar
    local bar = Panel(p, 0.6)
    bar:SetPoint("TOPLEFT", 0, -2)
    bar:SetPoint("TOPRIGHT", 0, -2)
    bar:SetHeight(28)
    frame.filterText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.filterText:SetPoint("LEFT", 10, 0)
    local all = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    all:SetSize(90, 20)
    all:SetPoint("RIGHT", -5, 0)
    all:SetText("Show all")
    all:SetScript("OnClick", function() frame.filter = nil; FM:RefreshLeaderboard() end)
    frame.allBtn = all

    local box = Panel(p)
    box:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
    box:SetPoint("BOTTOMRIGHT", 0, 0)

    local scroll = CreateFrame("ScrollFrame", nil, box, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -5)
    scroll:SetPoint("BOTTOMRIGHT", -26, 5)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, HIST_H, function() FM:RefreshLeaderboard() end)
    end)
    frame.histScroll = scroll

    frame.hrows = {}
    for i = 1, HIST_ROWS do
        local r = CreateFrame("Button", nil, box)
        r:SetHeight(HIST_H - 2)
        r:SetPoint("TOPLEFT", 6, -5 - (i - 1) * HIST_H)
        r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
        r.zebra = r:CreateTexture(nil, "BACKGROUND")
        r.zebra:SetAllPoints()
        r.zebra:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.035 or 0)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)
        -- kind stripe: red = kill, orange = assist
        r.stripe = r:CreateTexture(nil, "ARTWORK")
        r.stripe:SetPoint("TOPLEFT")
        r.stripe:SetPoint("BOTTOMLEFT")
        r.stripe:SetWidth(3)
        -- victim portrait
        r.ring = r:CreateTexture(nil, "BORDER")
        r.ring:SetSize(28, 28)
        r.ring:SetPoint("LEFT", 9, 0)
        r.ring:SetTexture(DISC)
        r.vicon = r:CreateTexture(nil, "ARTWORK")
        r.vicon:SetSize(24, 24)
        r.vicon:SetPoint("CENTER", r.ring)
        r.lvl = r:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        r.lvl:SetPoint("BOTTOMRIGHT", r.ring, "BOTTOMRIGHT", 3, -2)
        -- line 1: victim, class + level
        r.victim = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.victim:SetPoint("TOPLEFT", r.ring, "TOPRIGHT", 8, 1)
        r.victim:SetJustifyH("LEFT")
        r.victim:SetWordWrap(false)
        r.badge = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.badge:SetPoint("TOPRIGHT", -6, -3)
        -- line 2: by killer · zone · time
        r.info = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.info:SetPoint("BOTTOMLEFT", r.ring, "BOTTOMRIGHT", 8, 0)
        r.info:SetPoint("RIGHT", -6, 0)
        r.info:SetJustifyH("LEFT")
        r.info:SetWordWrap(false)
        r.victim:SetPoint("RIGHT", r.badge, "LEFT", -6, 0)
        r:SetScript("OnClick", function(self) if self.killer then frame.filter = self.killer; FM:RefreshLeaderboard() end end)
        frame.hrows[i] = r
    end

    frame.histEmpty = box:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    frame.histEmpty:SetPoint("CENTER")
end

----------------------------------------------------------------------
-- Seasons page: per group, the running season / proposal and past seasons
----------------------------------------------------------------------
local SEA_ROWS, SEA_H = 15, 26

function BuildSeasons(p)
    local box = Panel(p)
    box:SetAllPoints()
    local scroll = CreateFrame("ScrollFrame", nil, box, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -5)
    scroll:SetPoint("BOTTOMRIGHT", -26, 5)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, SEA_H, function() FM:RefreshLeaderboard() end)
    end)
    frame.seaScroll = scroll
    frame.srows = {}
    for i = 1, SEA_ROWS do
        local r = CreateFrame("Frame", nil, box)
        r:SetHeight(SEA_H - 2)
        r:SetPoint("TOPLEFT", 6, -5 - (i - 1) * SEA_H)
        r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 8, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r.btn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.btn:SetSize(96, 20)
        r.btn:SetPoint("RIGHT", -2, 0)
        r.btn2 = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.btn2:SetSize(70, 20)
        r.btn2:SetPoint("RIGHT", r.btn, "LEFT", -4, 0)
        r.text:SetPoint("RIGHT", r.btn2, "LEFT", -4, 0)
        frame.srows[i] = r
    end
end

local MEDAL_TXT = { "|cffffd100", "|cffc7cbd8", "|cffd18040" }

local function SeasonLines(self)
    local lines = {}
    local function add(l) lines[#lines + 1] = l end
    for _, g in ipairs(FriendMapDB.groups or {}) do
        local st = self.SeasonState(g.code)
        add({ head = true, text = "|cffffd100" .. g.name .. "|r" })
        if st.cur then
            local left = math.max(0, math.ceil((st.cur.finish - time()) / 86400))
            add({ text = ("|cff40ff40Running|r  %s -> %s  |cff999999(%d day%s left, by %s)|r"):format(
                    date("%d/%m", st.cur.start), self:DateText(st.cur.finish), left, left == 1 and "" or "s", st.cur.by or "?"),
                  btn = "Ranking", fn = function()
                      for i, v in ipairs(frame.views) do if v.code == g.code then frame.viewIdx = i end end
                      SelectTab("rank")
                  end })
        elseif st.prop then
            local yes, need = self.SeasonVotes(st.prop)
            local mine = st.prop.by == self:MyName()
            local l = { text = ("|cffffaa44Proposed|r by %s until %s  |cff999999(%d/%d accepted)|r"):format(
                st.prop.by, self:DateText(st.prop.finish), yes, need) }
            if not mine and not st.prop.voted then
                l.btn, l.fn = "Accept", function() self:VoteSeason(g.code, true) end
                l.btn2, l.fn2 = "Decline", function() self:VoteSeason(g.code, false) end
            elseif st.prop.voted then
                l.text = l.text .. (st.prop.voted == "Y" and "  |cff40ff40you accepted|r" or "  |cffff6060you declined|r")
            end
            add(l)
        else
            add({ text = "|cff888888No season running.|r", btn = "New season", fn = function() self:AskProposeSeason(g.code) end })
        end
        for i, h in ipairs(st.history) do
            local podium = {}
            for j = 1, 3 do
                local e = h.top and h.top[j]
                if e then podium[#podium + 1] = ("%s%d.|r %s %s(%d)|r"):format(MEDAL_TXT[j], j, e.name, MEDAL_TXT[j], e.n) end
            end
            add({ text = ("|cffccccccSeason %d|r  %s -> %s   %s"):format(#st.history - i + 1, date("%d/%m", h.start),
                date("%d/%m", h.finish), #podium > 0 and table.concat(podium, "  ") or "|cff888888no kills|r"),
                  btn = "Standings", fn = function()
                      self:Print(("|cffffd100%s - season %s -> %s|r"):format(g.name, self:DateText(h.start), self:DateText(h.finish)))
                      for j, e in ipairs(h.top or {}) do
                          self:Print(("  %d. %s - %d points (%d K, %d A)"):format(j, e.name, e.n, e.k or 0, e.a or 0))
                      end
                  end })
        end
    end
    if #lines == 0 then add({ text = "|cff888888Join or create a group to play seasons.|r" }) end
    return lines
end

function RefreshSeasons(self)
    local lines = SeasonLines(self)
    FauxScrollFrame_Update(frame.seaScroll, #lines, SEA_ROWS, SEA_H)
    local off = FauxScrollFrame_GetOffset(frame.seaScroll)
    for i, r in ipairs(frame.srows) do
        local l = lines[i + off]
        if l then
            r.text:SetText(l.text)
            r.text:SetFontObject(l.head and "GameFontNormal" or "GameFontHighlightSmall")
            r.bg:SetColorTexture(l.head and 0.45 or 1, l.head and 0.08 or 1, l.head and 0.05 or 1, l.head and 0.35 or 0.02)
            r.btn:SetShown(l.btn ~= nil)
            if l.btn then r.btn:SetText(l.btn); r.btn:SetScript("OnClick", l.fn) end
            r.btn2:SetShown(l.btn2 ~= nil)
            if l.btn2 then r.btn2:SetText(l.btn2); r.btn2:SetScript("OnClick", l.fn2) end
            r:Show()
        else
            r:Hide()
        end
    end
end

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
local function RefreshRanking(self, all)
    for i = 1, 3 do FillCard(frame.cards[i], all[i]) end

    local me, myRank, mine = FM:MyName(), nil, nil
    for i, e in ipairs(all) do if e.name == me then myRank, mine = i, e end end
    if myRank then
        frame.me:SetText(("You are |cffffd100#%d|r with |cffffd100%d|r points  |cff999999(%d kill%s, %d assist%s)|r"):format(myRank, mine.n,
            mine.k, mine.k == 1 and "" or "s", mine.a, mine.a == 1 and "" or "s"))
    else
        frame.me:SetText("|cff888888You have no kills here yet|r")
    end

    local max = all[1] and all[1].n or 1
    local barW = frame.rows[1].barBg:GetWidth()
    if not barW or barW <= 0 then barW = 160 end
    for i, r in ipairs(frame.rows) do
        local e = all[i + 3]
        r.who = e and e.name
        if e then
            local class = self:KillerClass(e.name)
            local cr, cg, cb = ClassColor(class)
            r.rank:SetText(i + 3)
            SetClassIcon(r.icon, class)
            r.name:SetText(e.name)
            r.name:SetTextColor(cr, cg, cb)
            r.bar:SetVertexColor(cr, cg, cb, 0.85)
            r.bar:SetWidth(math.max(2, barW * e.n / max))
            r.pts:SetText(e.n)
            r.count:SetText(("|cffffffff%d|r K  |cffffffff%d|r A"):format(e.k, e.a))
            r.me:SetShown(e.name == me)
            r:Show()
        else
            r:Hide()
        end
    end
    frame.empty:SetShown(#all == 0)
    frame.list:SetShown(#all > 3 or #all == 0)
end

local function RefreshHistory(self)
    local log = {}
    for _, e in ipairs(self:KillLog(frame.view)) do
        if not frame.filter or e.killer == frame.filter then log[#log + 1] = e end
    end
    if frame.filter then
        local class = self:KillerClass(frame.filter)
        local k, a = 0, 0
        for _, e in ipairs(log) do if e.kind == "A" then a = a + 1 else k = k + 1 end end
        frame.filterText:SetText(("%s%s|r  |cff999999- %d kill%s, %d assist%s|r"):format(Hex(ClassColor(class)), frame.filter,
            k, k == 1 and "" or "s", a, a == 1 and "" or "s"))
        frame.allBtn:Show()
    else
        frame.filterText:SetText(("All members  |cff999999- %d kill%s|r"):format(#log, #log == 1 and "" or "s"))
        frame.allBtn:Hide()
    end

    FauxScrollFrame_Update(frame.histScroll, #log, HIST_ROWS, HIST_H)
    local off = FauxScrollFrame_GetOffset(frame.histScroll)
    for i, r in ipairs(frame.hrows) do
        local e = log[i + off]
        r.killer = e and e.killer
        if e then
            local vr, vg, vb = ClassColor(e.vc)
            SetClassIcon(r.vicon, e.vc)
            r.ring:SetVertexColor(vr, vg, vb, e.vc and 1 or 0.4)
            r.lvl:SetText(e.vl or "")
            local what = ClassName(e.vc)
            local detail = what and (" |cff999999level %s %s|r"):format(e.vl or "??", what)
                or (e.vl and (" |cff999999level %d|r"):format(e.vl) or "")
            r.victim:SetText(Hex(vr, vg, vb) .. (e.victim or "?") .. "|r" .. detail)
            local assist = e.kind == "A"
            r.stripe:SetColorTexture(assist and 1 or 0.9, assist and 0.6 or 0.15, assist and 0.2 or 0.1, 1)
            local pts = FM.EventPoints(e)
            local TIERS = { S = "|cffff2020", Y = "|cffffd100", G = "|cff40ff40", X = "|cff9d9d9d" }
            r.badge:SetText(assist and "|cffffaa44ASSIST +1|r" or ((TIERS[e.c] or "|cffff4433") .. "KILL +" .. pts .. "|r"))
            local kr, kg, kb = ClassColor(self:KillerClass(e.killer))
            r.info:SetText(("by %s%s|r  ·  %s  ·  %s"):format(Hex(kr, kg, kb), e.killer, e.zone or "?", Ago(e.at)))
            r:Show()
        else
            r:Hide()
        end
    end
    frame.histEmpty:SetText(#log == 0 and "No kills yet." or "")
end

-- this week + every running season
local function Views()
    local list = { { label = "This week" } }
    for _, g in ipairs(FriendMapDB.groups or {}) do
        local v = FM:SeasonView(g.code)
        if v then
            v.label = "Season: " .. g.name
            v.until_ = v.season.finish
            list[#list + 1] = v
        end
    end
    return list
end

function FM:RefreshLeaderboard()
    if not frame or not frame:IsShown() then return end
    local prev = frame.views and frame.views[frame.viewIdx or 1]
    frame.views = Views()
    -- keep the same view selected if it still exists
    frame.viewIdx = 1
    for i, v in ipairs(frame.views) do
        if prev and v.code and v.code == prev.code then frame.viewIdx = i end
    end
    local view = frame.views[frame.viewIdx]
    frame.view = view.code and view or nil
    frame.viewSel.text:SetText((#frame.views > 1 and "|cffffd100" or "|cffaaaaaa") .. view.label .. "|r")
    frame.viewSel:SetEnabled(#frame.views > 1)
    frame.viewSel.arrow:SetShown(#frame.views > 1)

    local all = self:Leaderboard(nil, frame.view)
    local kills, assists = 0, 0
    for _, e in ipairs(all) do kills = kills + (e.k or 0); assists = assists + (e.a or 0) end
    local head = view.until_ and ("Season until " .. self:DateText(view.until_)) or "This week"
    if frame.tab == "season" then head = "Seasons of your groups" end
    frame.sub:SetText(("%s  ·  |cffffffff%d|r kill%s  ·  |cffffffff%d|r assist%s  ·  |cffffffff%d|r hunter%s"):format(head,
        kills, kills == 1 and "" or "s", assists, assists == 1 and "" or "s", #all, #all == 1 and "" or "s"))
    if frame.tab == "hist" then RefreshHistory(self)
    elseif frame.tab == "season" then RefreshSeasons(self)
    else RefreshRanking(self, all) end
end

function FM:ShowKillHistory(name)
    if not frame then Build() end
    frame.filter = name
    frame:Show()
    FauxScrollFrame_SetOffset(frame.histScroll, 0)
    frame.histScroll:SetVerticalScroll(0)
    SelectTab("hist")
end

function FM:ToggleSeasons()
    if not frame then Build() end
    frame:Show()
    SelectTab("season")
end

function FM:ToggleLeaderboard()
    if not frame then Build() end
    frame:SetShown(not frame:IsShown())
    self:RefreshLeaderboard()
end

FM.SlashExtra = FM.SlashExtra or {}
FM.SlashExtra.kills = function(rest) FM:ShowKillHistory(rest ~= "" and FM:FullName(rest) or nil) end

-- keep "x min ago" fresh while open
C_Timer.NewTicker(30, function() FM:RefreshLeaderboard() end)
