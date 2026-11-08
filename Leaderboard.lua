-- FriendMap world PvP leaderboard window: podium for the top 3, ranking bars,
-- your own rank, and the latest kills. Opened by /fm top or the quick bar.
local FM = FriendMap

local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14|t"
local MEDALS = {
    { 1, 0.82, 0.1 },    -- gold
    { 0.78, 0.8, 0.86 }, -- silver
    { 0.82, 0.5, 0.25 }, -- bronze
}
local LIST_ROWS, FEED_ROWS = 7, 7
local W = 380

local frame

local function ClassColor(class)
    local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if c then return c.r, c.g, c.b end
    return 0.85, 0.85, 0.85
end

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

local function Ago(t)
    local d = time() - (t or time())
    if d < 60 then return "just now" end
    if d < 3600 then return math.floor(d / 60) .. " min ago" end
    if d < 86400 then return math.floor(d / 3600) .. " h ago" end
    return math.floor(d / 86400) .. " d ago"
end

local function Panel(parent)
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0.08, 0.08, 0.1, 0.85)
        f:SetBackdropBorderColor(0.35, 0.3, 0.2, 1)
    end
    return f
end

----------------------------------------------------------------------
-- Podium card
----------------------------------------------------------------------
local function Card(parent, rank, height)
    local c = Panel(parent)
    c:SetSize(108, height)
    local m = MEDALS[rank]
    c.glow = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.glow:SetPoint("TOPLEFT", 4, -4)
    c.glow:SetPoint("BOTTOMRIGHT", -4, 4)
    c.glow:SetColorTexture(m[1], m[2], m[3], 0.08)
    if c.SetBackdropBorderColor then c:SetBackdropBorderColor(m[1], m[2], m[3], 0.9) end

    c.medal = c:CreateTexture(nil, "ARTWORK")
    c.medal:SetSize(24, 24)
    c.medal:SetPoint("TOP", 0, -8)
    c.medal:SetTexture(DISC)
    c.medal:SetVertexColor(m[1], m[2], m[3])
    c.rank = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.rank:SetPoint("CENTER", c.medal)
    c.rank:SetText(rank)
    c.rank:SetTextColor(0.1, 0.08, 0.02)

    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(rank == 1 and 44 or 36, rank == 1 and 44 or 36)
    c.icon:SetPoint("TOP", c.medal, "BOTTOM", 0, -6)
    c.ring = c:CreateTexture(nil, "BORDER")
    c.ring:SetPoint("CENTER", c.icon)
    c.ring:SetSize(c.icon:GetWidth() + 6, c.icon:GetHeight() + 6)
    c.ring:SetTexture(DISC)
    c.ring:SetVertexColor(m[1], m[2], m[3], 0.9)

    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("TOP", c.icon, "BOTTOM", 0, -6)
    c.name:SetWidth(100)
    c.name:SetWordWrap(false)

    c.count = c:CreateFontString(nil, "OVERLAY", rank == 1 and "GameFontNormalHuge" or "GameFontNormalLarge")
    c.count:SetPoint("BOTTOM", 0, 20)
    c.count:SetTextColor(m[1], m[2], m[3])
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.label:SetPoint("TOP", c.count, "BOTTOM", 0, -1)
    c.label:SetText("kills")
    return c
end

local function FillCard(c, e)
    if not e then
        c.icon:SetTexture(nil)
        c.icon:SetColorTexture(0.15, 0.15, 0.15, 1)
        c.name:SetText("|cff666666-|r")
        c.count:SetText("")
        c.label:Hide()
        c:SetAlpha(0.6)
        return
    end
    c:SetAlpha(1)
    c.label:Show()
    local class = FM:KillerClass(e.name)
    SetClassIcon(c.icon, class)
    c.name:SetText(e.name)
    c.name:SetTextColor(ClassColor(class))
    c.count:SetText(e.n)
end

----------------------------------------------------------------------
-- Build
----------------------------------------------------------------------
local function Build()
    frame = CreateFrame("Frame", "FriendMapLeaderboard", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(W, 600)
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

    -- header
    local banner = frame:CreateTexture(nil, "ARTWORK")
    banner:SetPoint("TOPLEFT", 14, -14)
    banner:SetPoint("TOPRIGHT", -14, -14)
    banner:SetHeight(54)
    banner:SetColorTexture(0.45, 0.05, 0.05, 0.55)
    local shade = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    shade:SetPoint("BOTTOMLEFT", banner)
    shade:SetPoint("BOTTOMRIGHT", banner)
    shade:SetHeight(2)
    shade:SetColorTexture(1, 0.82, 0, 0.6)

    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(38, 38)
    icon:SetPoint("LEFT", banner, "LEFT", 10, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetText("World PvP Leaderboard")
    frame.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- podium: 2nd, 1st (taller), 3rd
    frame.cards = {}
    local podium = CreateFrame("Frame", nil, frame)
    podium:SetSize(W - 40, 170)
    podium:SetPoint("TOP", banner, "BOTTOM", 0, -10)
    frame.cards[1] = Card(podium, 1, 166)
    frame.cards[1]:SetPoint("BOTTOM", podium, "BOTTOM", 0, 0)
    frame.cards[2] = Card(podium, 2, 146)
    frame.cards[2]:SetPoint("BOTTOMRIGHT", frame.cards[1], "BOTTOMLEFT", -8, 0)
    frame.cards[3] = Card(podium, 3, 136)
    frame.cards[3]:SetPoint("BOTTOMLEFT", frame.cards[1], "BOTTOMRIGHT", 8, 0)

    -- your line
    frame.me = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.me:SetPoint("TOP", podium, "BOTTOM", 0, -10)

    -- ranks 4..
    local list = Panel(frame)
    list:SetPoint("TOPLEFT", 16, -270)
    list:SetPoint("TOPRIGHT", -16, -270)
    list:SetHeight(LIST_ROWS * 22 + 12)
    frame.rows = {}
    for i = 1, LIST_ROWS do
        local r = CreateFrame("Frame", nil, list)
        r:SetHeight(20)
        r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 22)
        r:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * 22)
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 0.82, 0, 0.12)
        r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.rank:SetPoint("LEFT", 4, 0)
        r.rank:SetWidth(22)
        r.rank:SetJustifyH("RIGHT")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", r.rank, "RIGHT", 6, 0)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.name:SetWidth(100)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.barBg = r:CreateTexture(nil, "BORDER")
        r.barBg:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
        r.barBg:SetPoint("RIGHT", -36, 0)
        r.barBg:SetHeight(10)
        r.barBg:SetColorTexture(1, 1, 1, 0.06)
        r.bar = r:CreateTexture(nil, "ARTWORK")
        r.bar:SetPoint("LEFT", r.barBg, "LEFT")
        r.bar:SetHeight(10)
        r.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        r.count = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.count:SetPoint("RIGHT", -4, 0)
        frame.rows[i] = r
    end
    frame.list = list

    -- latest kills
    local feedTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    feedTitle:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 2, -10)
    feedTitle:SetText("Latest kills")
    local feed = Panel(frame)
    feed:SetPoint("TOPLEFT", feedTitle, "BOTTOMLEFT", -2, -4)
    feed:SetPoint("RIGHT", list, "RIGHT")
    feed:SetHeight(FEED_ROWS * 17 + 10)
    frame.feed = {}
    for i = 1, FEED_ROWS do
        local l = feed:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 17)
        l:SetPoint("RIGHT", -8, 0)
        l:SetJustifyH("LEFT")
        l:SetWordWrap(false)
        frame.feed[i] = l
    end

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("CENTER", list)
    frame.empty:SetText("No kills yet this week.\nGo hunt some enemies!")

    local foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOM", 0, 16)
    foot:SetText("Synced across your FriendMap groups - resets every Monday")
end

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
function FM:RefreshLeaderboard()
    if not frame or not frame:IsShown() then return end
    local all = self:Leaderboard()
    local total = 0
    for _, e in ipairs(all) do total = total + e.n end
    frame.sub:SetText(("This week  ·  %d kill%s  ·  %d hunter%s"):format(total, total == 1 and "" or "s", #all, #all == 1 and "" or "s"))

    for i = 1, 3 do FillCard(frame.cards[i], all[i]) end

    local me, myRank, myN = UnitName("player"), nil, 0
    for i, e in ipairs(all) do if e.name == me then myRank, myN = i, e.n end end
    if myRank then
        frame.me:SetText(("You are |cffffd100#%d|r with |cffffd100%d|r kill%s"):format(myRank, myN, myN == 1 and "" or "s"))
    else
        frame.me:SetText("|cff888888You have no kills this week yet|r")
    end

    local max = all[1] and all[1].n or 1
    local barW = frame.rows[1].barBg:GetWidth()
    if not barW or barW <= 0 then barW = 150 end
    for i, r in ipairs(frame.rows) do
        local e = all[i + 3]
        if e then
            local class = self:KillerClass(e.name)
            r.rank:SetText(i + 3)
            SetClassIcon(r.icon, class)
            r.name:SetText(e.name)
            r.name:SetTextColor(ClassColor(class))
            local cr, cg, cb = ClassColor(class)
            r.bar:SetVertexColor(cr, cg, cb, 0.9)
            r.bar:SetWidth(math.max(2, barW * e.n / max))
            r.count:SetText(e.n)
            r.hl:SetShown(e.name == me)
            r:Show()
        else
            r:Hide()
        end
    end
    frame.empty:SetShown(#all == 0)
    frame.list:SetShown(#all > 3 or #all == 0)

    local log = self:KillLog()
    for i, l in ipairs(frame.feed) do
        local k = log[i]
        if k then
            local kr, kg, kb = ClassColor(self:KillerClass(k.killer))
            l:SetText(("%s |cff%02x%02x%02x%s|r  >  |cffff6666%s|r  |cff888888%s · %s|r"):format(
                SKULL, kr * 255, kg * 255, kb * 255, k.killer, k.victim or "?", k.zone or "?", Ago(k.at)))
        else
            l:SetText(i == 1 and "|cff666666Nothing yet.|r" or "")
        end
    end
end

function FM:ToggleLeaderboard()
    if not frame then Build() end
    frame:SetShown(not frame:IsShown())
    self:RefreshLeaderboard()
end

-- keep "x min ago" fresh while open
C_Timer.NewTicker(30, function() FM:RefreshLeaderboard() end)
