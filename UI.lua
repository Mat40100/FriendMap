-- Simple management window: /fm
local FM = FriendMap
local MAX_ROWS = 8
local frame

local function Button(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 70, 22)
    b:SetText(text)
    return b
end

----------------------------------------------------------------------
-- Popups
----------------------------------------------------------------------
StaticPopupDialogs["FRIENDMAP_CREATE"] = {
    text = "Name of the new FriendMap group:",
    button1 = CREATE or "Create", button2 = CANCEL,
    hasEditBox = true, maxLetters = 24,
    OnAccept = function(self) local t = (self.editBox or self.EditBox):GetText(); FM:WithHardware(function() FM:CreateGroup(t) end) end,
    EditBoxOnEnterPressed = function(self) local t = self:GetText(); FM:WithHardware(function() FM:CreateGroup(t) end); self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["FRIENDMAP_JOIN"] = {
    text = "Paste a FriendMap share code (FMAP:...):",
    button1 = JOIN or "Join", button2 = CANCEL,
    hasEditBox = true, maxLetters = 80, editBoxWidth = 260,
    OnAccept = function(self) local t = (self.editBox or self.EditBox):GetText(); FM:WithHardware(function() FM:JoinGroup(FM:ParseShareCode(t)) end) end,
    EditBoxOnEnterPressed = function(self) local t = self:GetText(); FM:WithHardware(function() FM:JoinGroup(FM:ParseShareCode(t)) end); self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["FRIENDMAP_INVITE_NAME"] = {
    text = "Invite which player to |cffffd100%s|r?",
    button1 = INVITE or "Invite", button2 = CANCEL,
    hasEditBox = true, maxLetters = 48,
    OnAccept = function(self, g) FM:Invite(strtrim((self.editBox or self.EditBox):GetText()), g) end,
    EditBoxOnEnterPressed = function(self, g) FM:Invite(strtrim(self:GetText()), g); self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    OnShow = function(self)
        local eb = self.editBox or self.EditBox
        local target = UnitIsPlayer("target") and GetUnitName("target", true)
        if target then eb:SetText(target); eb:HighlightText() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["FRIENDMAP_COPY"] = {
    text = "Share code for |cffffd100%s|r\nCtrl+C to copy, then send it to your friends.\nThey join with /fm join <code>.",
    button1 = OKAY,
    hasEditBox = true, editBoxWidth = 300,
    OnShow = function(self, code)
        code = code or self.data
        local eb = self.editBox or self.EditBox
        eb:SetText(code); eb:HighlightText(); eb:SetFocus()
        eb:SetScript("OnTextChanged", function(e) if e:GetText() ~= code then e:SetText(code); e:HighlightText() end end)
    end,
    OnHide = function(self) (self.editBox or self.EditBox):SetScript("OnTextChanged", nil) end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["FRIENDMAP_LEAVE"] = {
    text = "Leave FriendMap group |cffffd100%s|r?",
    button1 = YES, button2 = NO,
    OnAccept = function(_, g) FM:LeaveGroup(g) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function FM:ShowCopyBox(g)
    StaticPopup_Show("FRIENDMAP_COPY", g.name, nil, self:GetShareCode(g))
end

----------------------------------------------------------------------
-- Main window
----------------------------------------------------------------------
local function Colored(name, class)
    local c = RAID_CLASS_COLORS[class or ""]
    return c and ("|c%s%s|r"):format(c.colorStr or "ffffffff", name) or name
end

local function MemberNames(g)
    local t = {}
    for _, m in pairs(FM.members[g.code] or {}) do t[#t + 1] = Colored(m.name, m.class) end
    table.sort(t)
    -- yourself first, when connected
    if FM:IsConnected(g) then
        table.insert(t, 1, Colored(UnitName("player") .. " (you)", select(2, UnitClass("player"))))
    end
    return #t > 0 and table.concat(t, ", ") or "|cff888888nobody online|r"
end

local function Build()
    frame = CreateFrame("Frame", "FriendMapFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(470, 190 + MAX_ROWS * 44)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    tinsert(UISpecialFrames, "FriendMapFrame")

    local title = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not frame.TitleText then title:SetPoint("TOP", 0, -5) end
    title:SetText("FriendMap " .. (FM.VERSION or ""))
    frame.title = title

    local create = Button(frame, "Create group", 110)
    create:SetPoint("TOPLEFT", 14, -32)
    create:SetScript("OnClick", function() StaticPopup_Show("FRIENDMAP_CREATE") end)

    local join = Button(frame, "Join with code", 110)
    join:SetPoint("LEFT", create, "RIGHT", 6, 0)
    join:SetScript("OnClick", function() StaticPopup_Show("FRIENDMAP_JOIN") end)

    local share = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    share:SetPoint("LEFT", join, "RIGHT", 12, 0)
    share:SetSize(24, 24)
    share.text = share.text or share.Text or share:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    share.text:SetPoint("LEFT", share, "RIGHT", 2, 0)
    share.text:SetText("Share my position")
    share:SetScript("OnClick", function(self)
        FriendMapDB.sharing = self:GetChecked() and true or false
        if not FriendMapDB.sharing then
            for _, g in ipairs(FriendMapDB.groups) do FM:SendToGroup(g, "BYE") end
        else
            FM:BroadcastPosition(true)
        end
    end)
    frame.share = share

    local pvp = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    pvp:SetPoint("TOPLEFT", share, "BOTTOMLEFT", 0, 4)
    pvp:SetSize(24, 24)
    pvp.text = pvp.text or pvp.Text or pvp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pvp.text:SetPoint("LEFT", pvp, "RIGHT", 2, 0)
    pvp.text:SetText("Announce my PvP fights")
    pvp:SetScript("OnClick", function(self) FriendMapDB.pvpAnnounce = self:GetChecked() and true or false end)
    frame.pvp = pvp

    local rallyOn = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    rallyOn:SetPoint("TOPLEFT", 12, -56)
    rallyOn:SetSize(24, 24)
    rallyOn.text = rallyOn.text or rallyOn.Text or rallyOn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rallyOn.text:SetPoint("LEFT", rallyOn, "RIGHT", 2, 0)
    rallyOn.text:SetText("Arrow to the rally point")
    rallyOn:SetScript("OnClick", function(self) FM:SetRallyArrow(self:GetChecked() and true or false) end)
    frame.rallyOn = rallyOn

    -- action bar: ping / help / rally / status
    local ping = Button(frame, "Ping here", 80)
    ping:SetPoint("TOPLEFT", 14, -86)
    ping:SetScript("OnClick", function() FM.SlashExtra.ping("") end)

    local help = Button(frame, "|cffff4444Help!|r", 60)
    help:SetPoint("LEFT", ping, "RIGHT", 4, 0)
    help:SetScript("OnClick", function() FM:SendHelp(false) end)

    local rally = Button(frame, "Rally here", 80)
    rally:SetPoint("LEFT", help, "RIGHT", 4, 0)
    rally:SetScript("OnClick", function() FM.SlashExtra.rally(IsShiftKeyDown() and "clear" or "") end)
    rally:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText("Set a rally point at your position\nShift-click: clear it"); GameTooltip:Show()
    end)
    rally:SetScript("OnLeave", GameTooltip_Hide)

    local st = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    st:SetSize(170, 20)
    st:SetPoint("LEFT", rally, "RIGHT", 12, 0)
    st:SetAutoFocus(false)
    st:SetMaxLetters(30)
    st:SetScript("OnEnterPressed", function(e) FM:SetStatus(e:GetText()); e:ClearFocus() end)
    st:SetScript("OnEscapePressed", function(e) e:SetText(FriendMapDB.status or ""); e:ClearFocus() end)
    local stl = st:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    stl:SetPoint("BOTTOMLEFT", st, "TOPLEFT", 0, 1)
    stl:SetText("My status (Enter to save)")
    frame.status = st

    local qb = Button(frame, "Quick bar", 80)
    qb:SetPoint("BOTTOMRIGHT", -12, 8)
    qb:SetScript("OnClick", function() FM:ToggleBarConfig() end)
    qb:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText("Choose the icons of your quick bar"); GameTooltip:Show()
    end)
    qb:SetScript("OnLeave", GameTooltip_Hide)

    local mb = Button(frame, "Members", 80)
    mb:SetPoint("RIGHT", qb, "LEFT", -4, 0)
    mb:SetScript("OnClick", function() FM:ToggleMembers() end)
    mb:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText("Every player seen in your groups"); GameTooltip:Show()
    end)
    mb:SetScript("OnLeave", GameTooltip_Hide)

    frame.top = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.top:SetPoint("TOPLEFT", 16, -116)
    frame.top:SetWidth(440)
    frame.top:SetJustifyH("LEFT")

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 16, 13)
    hint:SetText("Map: Alt+click = ping, Alt+Shift+click = rally, click a friend = arrow")

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOP", 0, -170)
    frame.empty:SetText("No groups yet. Create one or join with a code.")

    frame.rows = {}
    for i = 1, MAX_ROWS do
        local r = CreateFrame("Frame", nil, frame)
        r:SetSize(440, 40)
        r:SetPoint("TOPLEFT", 14, -142 - (i - 1) * 44)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0.08)

        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        r.name:SetPoint("TOPLEFT", 6, -4)
        r.name:SetWidth(200)
        r.name:SetJustifyH("LEFT")

        r.members = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.members:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        r.members:SetWidth(210)
        r.members:SetJustifyH("LEFT")
        r.members:SetWordWrap(false)

        r.leave = Button(r, "Leave", 52)
        r.leave:SetPoint("RIGHT", -4, 0)
        r.leave:SetScript("OnClick", function() StaticPopup_Show("FRIENDMAP_LEAVE", r.group.name, nil, r.group) end)

        r.invite = Button(r, "Invite", 52)
        r.invite:SetPoint("RIGHT", r.leave, "LEFT", -2, 0)
        r.invite:SetScript("OnClick", function() StaticPopup_Show("FRIENDMAP_INVITE_NAME", r.group.name, nil, r.group) end)

        r.link = Button(r, "Link", 46)
        r.link:SetPoint("RIGHT", r.invite, "LEFT", -2, 0)
        r.link:SetScript("OnClick", function() FM:PostLinkToChat(r.group) end)
        r.link:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText("Insert a clickable join link in chat"); GameTooltip:Show()
        end)
        r.link:SetScript("OnLeave", GameTooltip_Hide)

        r.code = Button(r, "Code", 46)
        r.code:SetPoint("RIGHT", r.link, "LEFT", -2, 0)
        r.code:SetScript("OnClick", function() FM:ShowCopyBox(r.group) end)
        r.code:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText("Show the share code to copy (Discord, etc.)"); GameTooltip:Show()
        end)
        r.code:SetScript("OnLeave", GameTooltip_Hide)

        frame.rows[i] = r
    end
end

function FM:RefreshUI()
    if not frame or not frame:IsShown() then return end
    frame.share:SetChecked(FriendMapDB.sharing)
    frame.pvp:SetChecked(FriendMapDB.pvpAnnounce)
    frame.rallyOn:SetChecked(not FriendMapDB.rallyArrowOff)
    local newer = FriendMapDB.newestVersion and FM.IsNewer and FM:IsNewer(FriendMapDB.newestVersion, FM.VERSION)
    frame.title:SetText("FriendMap " .. (FM.VERSION or "") .. (newer and ("  |cff00ff00(" .. FriendMapDB.newestVersion .. " available: /fm update)|r") or ""))
    if not frame.status:HasFocus() then frame.status:SetText(FriendMapDB.status or "") end
    local top = FM.Leaderboard and FM:Leaderboard(5) or {}
    local parts = {}
    for i, e in ipairs(top) do parts[i] = ("%s %d"):format(e.name, e.n) end
    frame.top:SetText("|cffff8800PvP points this week:|r " .. (#parts > 0 and table.concat(parts, ", ") or "none yet"))
    local groups = FriendMapDB.groups
    frame.empty:SetShown(#groups == 0)
    for i, r in ipairs(frame.rows) do
        local g = groups[i]
        r.group = g
        if g then
            local status = self:IsConnected(g) and "" or " |cffff5555(connecting...)|r"
            r.name:SetText(("%s |cff888888(%d online)|r%s"):format(g.name, self:OnlineCount(g), status))
            r.members:SetText(MemberNames(g))
            r:Show()
        else
            r:Hide()
        end
    end
end

function FM:ToggleUI()
    if not frame then Build() end
    if FM.needJoin then FM.needJoin = false; FM:WithHardware(function() FM:EnsureChannels() end) end
    frame:SetShown(not frame:IsShown())
    self:RefreshUI()
end
